using FileIO
using DataFrames
##
function failure_idx(count::T, rewarded) where {T <: Number}
    if rewarded
        count = 0.0
    else
        count + 1.0
    end
end
##
filename = "/home/beatriz/mainen.flipping.5ht@gmail.com/Flipping/Datasets/Stimulations/DRN_Opto_Flipping/pokesDRN_Opto_Flipping.csv"
data = FileIO.load(filename) |> DataFrame
data[!,:LastPoke] .= false
data[!,:FailuresIdx] .= 0.0
by(data,[:Session,:Streak]) do dd
    dd.LastPoke[end] = true
    dd[:,:FailuresIdx] = Base.accumulate(failure_idx, occursin.("true",dd.Reward);init=0.0)
end
checkpoint = by(data,:Session) do d
    d.PokeIn[1] == d.PokeIn[2]
end
any(checkpoint[:,2])
println(describe(data))
filtered = filter(t -> t[:Protocol].!="45/15", data)
##
"""
SCATTER OF MEAN ANS SD PER PROTOCOL AND BARRIER
"""
##
function scatter_mu_sd(df,var)
    μ = mean(select(df,var))
    σ = stderr(select(df,var))
    dict = OrderedDict(μ => σ)
end
