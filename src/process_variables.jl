"""
`session_info`
"""

function session_info(filepath::String)
    sessionREGEX = match(r"[a-zA-Z]{2}\d+_\d{6}[a-z]{1}",filepath); #the result is a regex object with several info
    if isempty(sessionREGEX.match)
        sessionREGEX = match(r"[a-zA-Z]{1}\d+_\d{6}",filepath);
        if isempty(sessionREGEX.match)
            println(filepath)
            return missing, missing, missing
        else
            session = sessionREGEX.match;
        end
    else
        session = sessionREGEX.match;
    end
    mouse, giorno = split(session,"_")[1:2]
    day = "20"*giorno[1:end-1]
    # String and string are not the same thing don't change them
    mouse = String(mouse)
    day = string(day)
    daily_session = string(giorno[end])
    session = String(session)
    return mouse, day, daily_session, session
end

"""
`get_protocollo(df)`

Python preprocessing creates a Boolean vector to distinguish between 2 Protocollo
relative Gamma and Probability are infered by the respective GammaVec and ProbVec
"""
function get_protocollo(df)
    ProtName = String[]
    for i in 1:size(df,1)
        #in the original data protocol are labeled either 0 or 1
        #this function collapse the respective gamma and prob in a string
        if df[i,:Protocollo] == 0
            curr_prot = string(df[i,:ProbVec0],"/",df[i,:GamVec0])
            push!(ProtName,curr_prot)
        elseif df[i,:Protocollo] == 1
            curr_prot = string(df[i,:ProbVec1],"/",df[i,:GamVec1])
            push!(ProtName,curr_prot)
        end
    end
    #ProtName = categorical(ProtName)
    return ProtName
end

"""
`get_hierarchy`
Return a vector indicating how many consecutive falses or trues
preceded an event
"""

function nextcount(count::T, rewarded) where {T <: Number}
    if rewarded
        count > 0 ? count + 1 : one(T)
    else
        count < 0 ? count - 1 : -one(T)
    end
end
signedcount(v::AbstractArray{Bool}) = accumulate(nextcount, v;init=0.0)
get_hierarchy(v) = lag(signedcount(v), default = NaN)


"""
`create_exp_calendar`
Method1: recount days of experiment
Method2: recount days according to changes in a manipulation
days is a Symbol  for the column that stores the actual days
"""
function create_exp_calendar(df::AbstractDataFrame,days::Symbol)
    lista = sort!(union(df[:,days]))
    Exp_day = Array{Int64,1}()
    Day = []
    for (n,d) in enumerate(lista)
        push!(Exp_day,Int64(n))
        push!(Day,d)
    end
    x = DataFrame(Exp_Day = Exp_day, Day = Day)
    #x[!,days] = Day
    return x
end

function create_exp_calendar(df::AbstractDataFrame,days::Symbol,manipulation::Symbol)
    x = by(df,days) do dd
        DataFrame(Manipulation = join(unique(dd[:, :Protocol]),"*"),
        Flexi = length(union(dd[:,:Protocol])) == 2)
    end
    what = string(manipulation)
    new_name = Symbol(what*"_Day")
    reordered = sortperm(x,(days))
    x = x[reordered,:]
    x[!,new_name] = Flipping.count_series(x[:,:Manipulation])
    return x
end
"""
`add_exp_calendar`
"""
function add_exp_calendar(df,exp_calendar,protocol_calendar)
    df = join(df, exp_calendar, on = [:MouseID,:Day], kind = :inner,makeunique=true);
    df = join(df, protocol_calendar, on = [:MouseID,:Day], kind = :inner,makeunique=true);
    mask = occursin.(String.(names(df)),"_1")
    for x in[names(df)[mask]]
        DataFrames.select!(df,DataFrames.Not(x))
        #deletecols!(pokes, x)
    end
    return df
end
