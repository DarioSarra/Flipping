using Optim
using FileIO
using DataFrames
using StatsBase
using StatsFuns
using StructArrays
using Plots
import Flipping.nextcount
##
function evidencepertrial(p, leave::Bool, failure_index)
    param = p[1]*(exp(-(failure_index*p[2])) + p[3])
    return - log(exp(-param)+1) - !leave * param
end

function evidenceofdatasmart(p, leaves, failure_indices)
    soa = StructArray((leaves, failure_indices))
    cm = countmap(soa)
    evidenceofdatasmart(p, cm)
end

function evidenceofdatasmart(p, cm)
    sum(n*evidencepertrial(p, value...) for (value, n) in cm)
end
function simulate(x, p1, p2, p3)
    param = p1*(exp(-(x*p2)) + p3)
    1 / (1 + exp(-param))
end
##
filename = "/home/beatriz/mainen.flipping.5ht@gmail.com/Flipping/Datasets/Stimulations/DRN_Opto_Flipping/pokesDRN_Opto_Flipping.csv"
data = FileIO.load(filename) |> DataFrame
data[!,:LastPoke] .= false
data[!,:FailuresIdx] .= 0.0
by(data,[:Session,:Streak]) do dd
    dd.LastPoke[end] = true
    dd[:,:FailuresIdx] = accumulate(nextcount, occursin.(dd.Reward,"true");init=0.0)
end
checkpoint = by(data,:Session) do d
    d.PokeIn[1] == d.PokeIn[2]
end
any(checkpoint[:,2])
println(describe(data))
# coll = DataFrame(Temp = Float64[], Integration = Float64[], Cost = Float64[])
##
coll =by(data,[:Protocol,:Wall]) do dd
    leaves = dd[:,:LastPoke]
    failures_indices = dd[:,:FailuresIdx]
    res = optimize(p -> -evidenceofdatasmart(p, leaves, failures_indices), [1.0,1.0,1.0])
    mins = Optim.minimizer(res)
    DataFrame(Inverse_Temp = mins[1], Integration = mins[2], Cost = mins[3])
    # push!(coll,Tuple(Optim.minimizer(res)))
end
x = collect(5:-1:-10)
f = plot(;xflip = true, legend = :topleft)
p_df = DataFrame(x = collect(x))
for r in eachrow(coll)
    p_df[:,Symbol(r[:Protocol])] = simulate.(x,r[:Inverse_Temp],r[:Integration],r[:Cost])
end
sort!(p_df,:x; rev = true)
for p in 2:size(p_df,2)
    plot!(p_df[:,1],p_df[:,p],label = names(p_df)[p])
end
f
####################
function check_double(that)
    checkpoint = by(that,:Session) do d
        d.PokeIn[1] == d.PokeIn[2]
    end
    return checkpoint[findall(checkpoint[:,2]),:]
end
checkpoint[findall(checkpoint[:,2]),:]
####################
