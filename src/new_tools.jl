export process_pokes,process_streaks, create_exp_dataframe

"""
`process_pokes`
"""

function process_pokes(filepath::String)
    curr_data = FileIO.load(filepath) |> DataFrame
    if !in(:Poke,names(curr_data))
        DataFrames.rename!(curr_data, Symbol("") => :Poke) #change poke counter name
    end
    if in(:delta,names(curr_data))
        DataFrames.rename!(curr_data, :delta => :Delta)
    end
    curr_data[!,:Poke] = curr_data[!,:Poke].+1
    start_time = curr_data[1,:PokeIn]
    curr_data[!,:PokeIn] = curr_data[!,:PokeIn] .- start_time
    curr_data[!,:PokeOut] = curr_data[!,:PokeOut] .- start_time
    curr_data[!,:PokeDur] = curr_data[!,:PokeOut] - curr_data[!,:PokeIn]
    if !iscolumn(curr_data,:Wall)
        curr_data[:Wall] = zeros(size(curr_data,1))
    end
    booleans=[:Reward,:Side,:SideHigh,:Stim,:Wall]#columns to convert to Bool
    for x in booleans
        if curr_data[1,x] isa AbstractString
            try
                curr_data[x] = parse.(Bool,curr_data[x])#Bool.(curr_data[x])
            catch
                continue
            end
        elseif curr_data[1,x] isa Real
            curr_data[!,x] = Bool.(curr_data[:,x])
        end
    end
    curr_data[!,:Side] = [a ? "L" : "R" for a in curr_data[!,:Side]]
    if iscolumn(curr_data,:ProbVec0)
        integers=[:Protocollo,:ProbVec0,:ProbVec1,:GamVec0,:GamVec1,:Delta]; #columns to convert to Int64
        for x in integers
            curr_data[!,x] = Int64.(curr_data[!,x])
        end
        curr_data[!,:Protocol] = Flipping.get_protocollo(curr_data)
        for x in[:ProbVec0,:ProbVec1,:GamVec0,:GamVec1,:Protocollo]
            deletecols!(curr_data, x)
        end
        if !iscolumn(curr_data,:StimFreq)
            curr_data[!,:StimFreq] = repeat([50],size(curr_data,1))
        end
        curr_data[!,:StimFreq] = [a == 50 ? 25 : a  for a in curr_data[:Stim]]
        curr_data[!,:Box] .= 0
    elseif iscolumn(curr_data,:Prwd)
        curr_data[!,:Protocol] = string.(curr_data[!,:Prwd],'/',curr_data[!,:Ptrs])
    end
    mouse, day, daily_session, session = session_info(filepath)
    curr_data[!,:MouseID] .= mouse
    curr_data[!,:Day] .= parse(Int64,day)
    curr_data[!,:Daily_Session] .= daily_session
    curr_data[!,:Session] .= session
    curr_data[!,:Gen] = Flipping.gen.(curr_data[:,:MouseID])
    curr_data[!,:Drug] = Flipping.pharm.(curr_data[:,:Day])
    curr_data[!,:Stim_Day] .= length(findall(curr_data[:,:Stim])) == 0 ? false : true
    curr_data[!,:Streak] = count_sequence(curr_data[:,:Side])
    curr_data[!,:ReverseStreak] = reverse(curr_data[:,:Streak])
    curr_data[!,:Poke_within_Streak] .= 0
    curr_data[!,:Poke_Hierarchy] .= 0.0
    curr_data[!,:Poke_within_Streak] = Vector{Union{Float64,Missing}}(undef,size(curr_data,1))
    curr_data[!,:Pre_Interpoke] = Vector{Union{Float64,Missing}}(undef,size(curr_data,1))
    curr_data[!,:Post_Interpoke] = Vector{Union{Float64,Missing}}(undef,size(curr_data,1))
    by(curr_data,:Streak) do dd
        dd[:,:Poke_within_Streak] = count_sequence(dd[!,:Poke])
        dd[:,:Pre_Interpoke] =  dd[!,:PokeIn] .-lag(dd[!,:PokeOut],default = missing)
        dd[:,:Post_Interpoke] = lead(dd[!,:PokeIn],default = missing).- dd[!,:PokeOut]
        dd[:,:Poke_Hierarchy] = Flipping.get_hierarchy(dd[!,:Reward])
    end
    curr_data[!,:Block] = count_sequence(curr_data[!,:Wall])
    curr_data[!,:Streak_within_Block] .= 0
    by(curr_data,:Block) do dd
        dd[:,:Streak_within_Block] = count_sequence(dd[!,:Side])
    end
    curr_data[!,:SideHigh] = [x ? "L" : "R" for x in curr_data[!,:SideHigh]]
    curr_data[!,:Correct] = curr_data[!,:Side] .== curr_data[!,:SideHigh]
    return curr_data
end

"""
`process_streaks`
"""

function process_streaks(df::DataFrames.AbstractDataFrame; photometry = false)
    dayly_vars_list = [:MouseID, :Gen, :Drug, :Day, :Daily_Session, :Box, :Stim_Day, :Condition, :ExpDay, :Area, :Session];
    booleans=[:Reward,:Side,:SideHigh,:Stim,:Wall,:Correct,:Stim_Day]#columns to convert to Bool
    for x in booleans
        df[!,x] = eltype(df[!,x]) == Bool ? df[!,x] : occursin.("true",df[!,x],)
    end
    streak_table = by(df, :Streak) do dd
        dt = DataFrame(
        Num_pokes = size(dd,1),
        Num_Rewards = length(findall(dd[!,:Reward].==1)),
        Start_Reward = dd[1,:Reward],
        Last_Reward = findlast(dd[!,:Reward] .== 1).== nothing ? 0 : findlast(dd[!,:Reward] .== 1),
        Prev_Reward = findlast(dd[!,:Reward] .== 1).== nothing ? 0 : findprev(dd[!,:Reward] .==1, findlast(dd[!,:Reward] .==1)-1),
        Trial_duration = (dd[end,:PokeOut]-dd[1,:PokeIn]),
        Start = (dd[1,:PokeIn]),
        Stop = (dd[end,:PokeOut]),
        Pre_Interpoke = size(dd,1) > 1 ? maximum(skipmissing(dd[!,:Pre_Interpoke])) : missing,
        Post_Interpoke = size(dd,1) > 1 ? maximum(skipmissing(dd[!,:Post_Interpoke])) : missing,
        PokeSequence = [SVector{size(dd,1),Bool}(dd[!,:Reward])],
        Stim = dd[1,:Stim],
        StimFreq = dd[1,:StimFreq],
        Wall = dd[1,:Wall],
        Protocol = dd[1,:Protocol],
        Correct_start = dd[1,:Correct],
        Correct_leave = !dd[end,:Correct],
        Block = dd[1,:Block],
        Streak_within_Block = dd[1,:Streak_within_Block],
        Side = dd[1,:Side],
        ReverseStreak = dd[1,:ReverseStreak]
        )
        for s in dayly_vars_list
            if s in names(df)
                dt[!,s] .= df[1, s]
            end
        end
        return dt
    end
    streak_table[!,:Prev_Reward] = [x .== nothing ? 0 : x for x in streak_table[:Prev_Reward]]
    streak_table[:AfterLast] = streak_table[:Num_pokes] .- streak_table[:Last_Reward];
    streak_table[:BeforeLast] = streak_table[:Last_Reward] .- streak_table[:Prev_Reward].-1;
    prov = lead(streak_table[:Start],default = 0.0) .- streak_table[:Stop];
    streak_table[:Travel_to]  = [x.< 0 ? 0 : x for x in prov]
    if photometry
        frames = by(df, :Streak) do df
            dd = DataFrame(
            In = df[1,:In],
            Out = df[end,:Out],
            LR_In = findlast(df[:Reward])==0 ? NaN : df[findlast(df[:Reward]),:In],
            LR_Out = findlast(df[:Reward])==0 ? NaN : df[findlast(df[:Reward]),:Out]
            )
        end
        streak_table[:In] = frames[:In]
        streak_table[:Out] = frames[:Out]
        streak_table[:LR_In] = frames[:LR_In]
        streak_table[:LR_Out] = frames[:LR_Out]
    end

    return streak_table
end

"""
`process_sessions`
"""

function process_sessions(DataIndex::DataFrames.AbstractDataFrame)
    c=0
    b=0
    pokes = []
    streaks = []
    for i=1:size(DataIndex,1)
        #print(i," ")
        path = DataIndex[i,:Bhv_Path]
        session = DataIndex[i,:Session]
        filetosave = DataIndex[i,:Preprocessed_Path]
        if ~isfile(filetosave)
            pokes_data = process_pokes(path)
            FileIO.save(filetosave,pokes_data)
            streaks_data = process_streaks(pokes_data)
            b=b+1
        else
            pokes_data = FileIO.load(filetosave)|> DataFrame
            booleans=[:Reward,:Stim,:Wall,:Correct,:Stim_Day]#columns to convert to Bool removed :Side,:SideHigh
            for x in booleans
                pokes_data[x] = eltype(pokes_data[x]) == Bool ? pokes_data[x] : occursin.(pokes_data[x],"true")
            end
            streaks_data = process_streaks(pokes_data)
            c=c+1
        end
        if isempty(pokes)
            pokes = pokes_data
            streaks = streaks_data
        else
            try
                append!(pokes, pokes_data)
                append!(streaks, streaks_data)
            catch
                append!(pokes, pokes_data[:, names(pokes)])
                append!(streaks, streaks_data[:, names(streaks)])
            end
        end
    end
    println("Existing file = ",c," Preprocessed = ",b)
    return pokes, streaks
end

"""
`create_exp_dataframes`
"""

function create_exp_dataframes(DataIndex::DataFrames.AbstractDataFrame)
    exp_dir = DataIndex[1,:Saving_Path]
    pokes, streaks = process_sessions(DataIndex)
    exp_calendar = by(pokes,:MouseID) do dd
        Flipping.create_exp_calendar(dd,:Day)
    end
    protocol_calendar = by(pokes,:MouseID) do dd
        Flipping.create_exp_calendar(dd,:Day,:Protocol)
    end
    pokes = join(pokes, exp_calendar, on = [:MouseID,:Day], kind = :inner,makeunique=true);
    pokes = join(pokes, protocol_calendar, on = [:MouseID,:Day], kind = :inner,makeunique=true);
    mask = occursin.(String.(names(pokes)),"_1")
    for x in[names(pokes)[mask]]
        DataFrames.select!(pokes,DataFrames.Not(x))
        #deletecols!(pokes, x)
    end
    pokes = Flipping.check_fiberlocation(pokes,exp_dir)
    filetosave = joinpath(exp_dir,"pokes"*splitdir(exp_dir)[end]*".jld2")
    @save filetosave pokes
    filetosave = joinpath(exp_dir,"pokes"*splitdir(exp_dir)[end]*".csv")
    CSVFiles.save(filetosave,pokes)
    streaks = join(streaks, exp_calendar, on = [:MouseID,:Day], kind = :inner,makeunique=true);
    streaks = join(streaks, protocol_calendar, on = [:MouseID,:Day], kind = :inner,makeunique=true);
    mask = occursin.(String.(names(streaks)),"_1")
    for x in[names(streaks)[mask]]
        DataFrames.select!(streaks,DataFrames.Not(x))
        #deletecols!(streaks, x)
    end
    streaks = Flipping.check_fiberlocation(streaks,exp_dir)
    filetosave = joinpath(exp_dir,"streaks"*splitdir(exp_dir)[end]*".jld2")
    @save filetosave streaks
    simple = DataFrames.select(streaks,DataFrames.Not(:PokeSequence))
    filetosave = joinpath(exp_dir,"streaks"*splitdir(exp_dir)[end]*".csv")
    CSVFiles.save(filetosave,simple)
    return pokes, streaks, DataIndex
end

function create_exp_dataframes(Directory_path::String,Exp_type::String,Exp_name::String, Mice_suffix::String)
    DataIndex = Flipping.find_behavior(Directory_path, Exp_type, Exp_name,Mice_suffix)
    create_exp_dataframes(DataIndex)
end


function create_exp_dataframes(Raw_data_dir::String)
    DataIndex = Flipping.find_behavior(Raw_data_dir)
    create_exp_dataframes(DataIndex)
end
