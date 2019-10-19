"""
`iscolumn`
"""
function iscolumn(df::DataFrames.AbstractDataFrame,what::Symbol)
    if in(what,names(df))
        return true
    else
        return false
    end
end

"""
`count_sequence`
count when along an array the value of i+1 is different from i
"""
function count_sequence(series::AbstractArray)
    v_count = [1]
    count = 1
    for i = 2:size(series,1)
        if series[i] == series[i-1]
            count = count
        else
            count = count+1
        end
        push!(v_count,count)
    end
    return v_count
end

"""
"count_series"
useful to count an ordered series of categorical values, wheter they are the same or
they change
"""
function count_trues(count::T, same) where {T <: Number}
    if same
        count+1
    else
        1
    end
end

function check_series(x)
    Vector = [false]
    for i = 2:size(x,1)
        push!(Vector,x[i] == x[i-1] ? true : false)
    end
    return Vector
end

function count_series(vector)
    x = check_series(vector)
    res = accumulate(count_trues,x;init=0)
    return res
end

"""
"checktype"
check if a column supposed to be boolean is a string and convert it
"""

function checktype(v::AbstractArray)
    eltype(v) == Bool ? v : occursin(r"ue","True")
end

function checktype(t::IndexedTables.AbstractIndexedTable,booleans::AbstractArray)
    for x in booleans
        println(x)
        t = setcol(t,x,checktype((column(t,x))))
    end
    return t
end


"""
"by_summary"
retrieve the first value of a column from a table split by by
"""
function by_summary(df::IndexedTables.IndexedTable,by,x::Symbol)
    # JuliaDB.groupby(NamedTuple{(x,)}(t-> getindex(t,1),),df,by,select = x)
    # JuliaDBMeta.@groupby df by {MouseID = cols(x)[1]}
    t = JuliaDB.groupby(t-> getindex(t,1),df,by,select = x)
    JuliaDB.rename(t,(colnames(t)[end]=>x))
end


function by_summary(df::IndexedTables.IndexedTable,by,x::AbstractArray{Symbol})
    summary_table = table((a=[1],b=[2]))
    for (i,c) in enumerate(x)
        if c in colnames(df)
            if i == 1
                summary_table = by_summary(df,by,c)
            else
                ongoing = by_summary(df,by,c)
                summary_table = join(summary_table, ongoing, lkey = by, rkey = by)
            end
        end
    end
    return summary_table
end
