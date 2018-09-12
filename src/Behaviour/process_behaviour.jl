# include("tools.jl")
# include("searchfile.jl")

export process_pokes,create_pokes_dataframe, create_streak_dataframe

"""
`create_DataIndex`
create a Dataframe to identify the raw files to processed it has 2 methods, find files in run_task_photo/raw_data
or takes all the files in a folder
"""
function create_DataIndex(bhv::Array{Any,1})
    string_search = match.(r"[a-zA-Z]{2}\d+_\d{6}",bhv)
    mask = string_search.!= nothing
    string_search = string_search[mask]
    bhv = bhv[mask]
    string_result = [res.match for res in string_search if res !== nothing]
    DataIndex = DataFrame(Bhv_Path = bhv)
    DataIndex[:Session] = String.(string_result.*".csv")
    DataIndex[:MouseID] = String.([split(t,"_")[1] for t in DataIndex[:Session]])
    DataIndex[:Day] = String.(["20"*split(t,"_")[2] for t in DataIndex[:Session]])
    return DataIndex
end



"""
`find_behavior`

Function that deals with the type of preprocessing Single exp folder or raw data folder
"""

function find_behavior(Directory_path)
    Dir = replace(Directory_path,basename(Directory_path),"")
    saving_path = joinpath(Dir*"/Bhv/")
    if !ispath(saving_path)
        mkdir(saving_path)
    end
    bhv = get_data(Directory_path);
    DataIndex = create_DataIndex(bhv);
    DataIndex[:Preprocessed_Path] = saving_path.*DataIndex[:Session]
    return DataIndex
end

function find_behavior(Directory_path::String, Exp_type::String,Exp_name::String, Mice_suffix ::String)
    rawdata_path = joinpath(Directory_path*"run_task_photo/raw_data")
    saving_path = joinpath(Directory_path*"Datasets/"*Exp_type*"/"*Exp_name*"/Bhv/")
    if !ispath(saving_path)
        mkdir(saving_path)
    end
    bhv = get_data(rawdata_path);
    DataIndex = create_DataIndex(bhv);
    DataIndex[:Preprocessed_Path] = saving_path.*DataIndex[:Session]
    return DataIndex
end



"""
`process_pokes`

Function that adjust the csv file created by python
it takes the path of a session file as argument and return a DataFrame of the session
"""
function process_pokes(bhv_files::String)
    curr_data= FileIO.load(bhv_files)|> DataFrame
    rename!(curr_data, Symbol("") => :Poke_n) #change poke counter name
    curr_data[:Poke_n]= curr_data[:Poke_n].+1
    start_time = curr_data[1,:PokeIn]
    curr_data[:PokeIn] = curr_data[:PokeIn] .- start_time
    curr_data[:PokeOut] = curr_data[:PokeOut] .- start_time
    booleans=[:Reward,:Side,:SideHigh,:Stim] #columns to convert to Bool
    integers=[:Protocollo,:ProbVec0,:ProbVec1,:GamVec0,:GamVec1,:delta] #columns to convert to Int64
    convert2Bool(curr_data,booleans)
    convert2Int(curr_data,integers)
    mouse, day, session = get_BHVmousedate(bhv_files)
    curr_data[:Poke_h] = get_hierarchy(curr_data,:Reward)
    curr_data[:PokeDur] = curr_data[:PokeOut]-curr_data[:PokeIn]
    curr_data[:MouseID] = mouse
    curr_data[:Day] = parse(Int64,day)
    curr_data[:Session] = session
    try
        genotype = gen.(curr_data[:MouseID])
        curr_data[:Gen] = genotype
    catch
        println("Missing genotype info ", session," ",curr_data[:MouseID],)
    end
    curr_data[:Drug] = pharm.(curr_data[:Day])
    curr_data[:Protocol] = get_protocollo(curr_data)#create a columns with a unique string to distinguish protocols
    curr_data[:Streak_n] = get_sequence(curr_data,:Side)
    curr_data[:InterPoke] = 0.0
    by(curr_data,:Streak_n) do dd
        dd[:InterPoke] = get_shifteddifference(dd,:PokeIn,:PokeOut)
    end
    curr_data[:StreakStart] = get_streakstart(curr_data)
    curr_data[:StreakCount]=get_sequence(curr_data,:Poke_n,:Streak_n)
    curr_data[:Correct] = get_correct(curr_data)
    try
        curr_data[:Block] = get_sequence(curr_data,:Wall) #enumerates the blocks
    catch
        curr_data[:Wall] = zeros(size(curr_data,1))
        curr_data[:Block] = get_sequence(curr_data,:Wall)
    end
    convert2Bool(curr_data,[:Wall])
    curr_data[:BlockCount] = get_sequence(curr_data,:Streak_n,:Block,:Correct)
    curr_data[:ReverseStreak_n] = reverse(curr_data[:Streak_n])
    curr_data[:LastBlock] = get_last(curr_data,:Block)
    for x in[:ProbVec0,:ProbVec1,:GamVec0,:GamVec1,:Protocollo]
        delete!(curr_data, x)
    end
    return curr_data
end

function process_pokes(DataIndex::DataFrames.AbstractDataFrame)
    c=0
    b=0
    for i=1:size(DataIndex,1)
        path = DataIndex[i,:Bhv_Path]
        session = DataIndex[i,:Session]
        filetosave = DataIndex[i,:Preprocessed_Path]
        if ~isfile(filetosave)
            data = process_pokes(path)
            FileIO.save(filetosave,data)
            b=b+1
        else
            c=c+1
        end
    end
    println("Existing file = ",c," Preprocessed = ",b)
    return DataIndex
end


"""
`process_streaks`
From the pokes dataframe creates one for streaks
"""
function process_streaks(data::DataFrames.AbstractDataFrame; photometry = false)
    columns_list = [:Side, :Stim, :Correct, :Condition, :Protocol, :Block,
        :LastBlock, :BlockCount, :ReverseStreak_n, :Wall, :ExpDay, :Area, :Gen, :Drug];
    println("Missing Columns $(setdiff(columns_list, names(data)))")
    data[:Reward] = eltype(data[:Reward]) == Bool ? data[:Reward] : contains.(data[:Reward],"true")
    data[:Stim] = eltype(data[:Stim]) == Bool ? data[:Stim] : contains.(data[:Stim],"true")
    streak_table = by(data, [:Day, :MouseID, :Streak_n,]) do df
        dd = DataFrame(
        Num_pokes = size(df,1),
        Num_Rewards = length(find(df[:Reward].==1)),
        Start_Reward = df[1,:Reward],
        Last_Reward = findlast(df[:Reward] .==1),
        Prev_Reward = findprev(df[:Reward] .==1, findlast(df[:Reward] .==1)-1),
        Trial_duration = (df[:PokeOut][end]-df[:PokeIn][1]),
        Start = (df[1,:PokeIn]),
        Stop = (df[end,:PokeOut]),
        Session2 = df[1,:MouseID]*"_"*string(df[:Day][1]),
        Session = df[1,:Session],
        InterPoke = maximum(df[:InterPoke]),
        PokeSequence = [SVector{size(df,1),Bool}(df[:Reward])]
        )
        for s in columns_list
            if s in names(df)
                dd[s] = df[1, s]
            end
        end
        return dd
    end
    streak_table[:AfterLast] = streak_table[:Num_pokes] - streak_table[:Last_Reward];
    streak_table[:BeforeLast] = streak_table[:Last_Reward] - streak_table[:Prev_Reward]-1;
    sort!(streak_table, [order(:Session), order(:Streak_n)])
    #travel duration
    streak_table[:Travel_duration] = 0.0
    by(streak_table,:Session) do dd
        a = dd[:Start][2:end] - dd[:Stop][1:end-1];
        dd[1:end-1,:Travel_duration] = a;
    end
    delete!(streak_table, [:Start,:Stop])
    if streak_table[:Session] == streak_table[:Session2]
        delete!(streak_table, :Session2)
    end
    if photometry
        frames = by(data, [:Session, :Streak_n,]) do df
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
`create_exp_dataframes`

join all the preprocessed pokes dataframe in a single dataframe and process streaks save it all
"""
function create_exp_dataframes(Raw_data_dir)
    DataIndex = find_behavior(Raw_data_dir)
    DataIndex = process_pokes(DataIndex)
    pokes = concat_data!(DataIndex[:Preprocessed_Path])
    #pokes = check_fiberlocation(pokes,Exp_name)
    mask = contains.(String.(names(pokes)),"_1")
    for x in[names(pokes)[mask]]
        delete!(pokes, x)
    end
    save_dir = replace(Raw_data_dir,basename(Raw_data_dir),"")
    filetosave = joinpath(save_dir,"pokes.jld2")
    @save filetosave pokes
    # filetosave = Directory_path*"Datasets/"*Exp_type*"/"*Exp_name*"/pokes"*Exp_name*".csv"
    # FileIO.save(filetosave,pokes)
    streaks = process_streaks(pokes)
    #streaks = check_fiberlocation(streaks,Exp_name)
    mask = contains.(String.(names(streaks)),"_1")
    for x in[names(streaks)[mask]]
        delete!(streaks, x)
    end
    filetosave = joinpath(save_dir,"streaks.jld2")
    @save filetosave streaks
    # filetosave = Directory_path*"Datasets/"*Exp_type*"/"*Exp_name*"/streaks"*Exp_name*".csv"
    # FileIO.save(filetosave,streaks)
    return pokes, streaks, DataIndex
end

function create_exp_dataframes(Directory_path::String,Exp_type::String,Exp_name::String, Mice_suffix::String)
    DataIndex = find_behavior(Directory_path, Exp_type, Exp_name,Mice_suffix)
    DataIndex = process_pokes(DataIndex)
    pokes = concat_data!(DataIndex[:Preprocessed_Path])
    pokes = check_fiberlocation(pokes,Exp_name)
    mask = contains.(String.(names(pokes)),"_1")
    for x in[names(pokes)[mask]]
        delete!(pokes, x)
    end
    filetosave = Directory_path*"Datasets/"*Exp_type*"/"*Exp_name*"/pokes"*Exp_name*".jld2"
    @save filetosave pokes
    # filetosave = Directory_path*"Datasets/"*Exp_type*"/"*Exp_name*"/pokes"*Exp_name*".csv"
    # FileIO.save(filetosave,pokes)
    streaks = process_streaks(pokes)
    streaks = check_fiberlocation(streaks,Exp_name)
    mask = contains.(String.(names(streaks)),"_1")
    for x in[names(streaks)[mask]]
        delete!(streaks, x)
    end
    filetosave = Directory_path*"Datasets/"*Exp_type*"/"*Exp_name*"/streaks"*Exp_name*".jld2"
    @save filetosave streaks
    # filetosave = Directory_path*"Datasets/"*Exp_type*"/"*Exp_name*"/streaks"*Exp_name*".csv"
    # FileIO.save(filetosave,streaks)
    return pokes, streaks, DataIndex
end
