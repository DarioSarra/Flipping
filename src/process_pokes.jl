"""
`process_pokes`
"""

function process_pokes(filepath::String)
    curr_data = FileIO.load(filepath) |> DataFrame
    if !in(:Poke,names(curr_data))
        DataFrames.rename!(curr_data, names(curr_data)[1] => :Poke) #change poke counter name
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
                curr_data[!,x] = parse.(Bool,curr_data[!,x])
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
            DataFrames.select!(curr_data,DataFrames.Not(x))
        end
        if !iscolumn(curr_data,:StimFreq)
            curr_data[!,:StimFreq] .= 10000
        end
        curr_data[!,:StimFreq] = [a == 10000 ? 25 : a  for a in curr_data[!,:StimFreq]]
        curr_data[!,:Box] .= "Box0"
    elseif iscolumn(curr_data,:Prwd)
        curr_data[!,:Protocol] = string.(curr_data[!,:Prwd],'/',curr_data[!,:Ptrs])
        curr_data[!,:Box] = "Box".*string.(curr_data[:,:Box])
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
    curr_data[!,:LastPoke] .= false
    by(curr_data,:Streak) do dd
        dd[:,:Poke_within_Streak] = count_sequence(dd[!,:Poke])
        dd[:,:Pre_Interpoke] =  dd[!,:PokeIn] .-lag(dd[!,:PokeOut],default = missing)
        dd[:,:Post_Interpoke] = lead(dd[!,:PokeIn],default = missing).- dd[!,:PokeOut]
        dd[:,:Poke_Hierarchy] = Flipping.get_hierarchy(dd[!,:Reward])
        dd.LastPoke[end] = true
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
