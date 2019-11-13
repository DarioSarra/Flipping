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
    β,λ,c = p
    param = β*(1 - c*exp(-(λ*failure_index)))
    # - param only if event doesn't occur
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

probability(p, failure_index) = exp(evidencepertrial(p, true, failure_index))

map(t -> probability(p, t), 1:10)
########
function D_evidencepertrial(p, leave::Bool, failure_index)
    β,λ,c = p
    param = β*(exp(-(λ*failure_index))-c)
    # - param only if event doesn't occur
    return - log(exp(-param)+1) - !leave * param
end

function D_evidenceofdatasmart(p, leaves, failure_indices)
    soa = StructArray((leaves, failure_indices))
    cm = countmap(soa)
    D_evidenceofdatasmart(p, cm)
end

function D_evidenceofdatasmart(p, cm)
    sum(n*D_evidencepertrial(p, value...) for (value, n) in cm)
end

########
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
    dd[:,:FailuresIdx] = accumulate(failure_idx, occursin.(dd.Reward,"true");init=0.0)
end
checkpoint = by(data,:Session) do d
    d.PokeIn[1] == d.PokeIn[2]
end
any(checkpoint[:,2])
println(describe(data))
# coll = DataFrame(Temp = Float64[], Integration = Float64[], Cost = Float64[])
##
using LinearAlgebra
filtered = filter(t -> t[:Protocol].!="45/15", data)
##
coll =by(filtered,[:Protocol,:Wall,:MouseID]) do dd
    leaves = dd[:,:LastPoke]
    failures_indices = dd[:,:FailuresIdx]
    ϵ = 10^(-2)
    res = optimize(p -> -evidenceofdatasmart(p, leaves, failures_indices) + ϵ*norm(p)^2, [1.0,1.0,1.0])
    mins = Optim.minimizer(res)
    D_res = optimize(p -> -D_evidenceofdatasmart(p, leaves, failures_indices) + ϵ*norm(p)^2, [1.0,1.0,1.0])
    D_mins = Optim.minimizer(D_res)
    DataFrame(Inverse_Temp = mins[1], Integration = mins[2], Cost = mins[3],
    D_Inverse_Temp = D_mins[1], D_Integration = D_mins[2], D_Cost = D_mins[3])
end
describe(coll)
f = plot(; legend = :bottomright)

for r in eachrow(coll)
    p = [r[:Inverse_Temp],r[:Integration],r[:Cost]]
    plot!(0:10,map(t -> probability(p, t), 0:10),label = r[:Protocol]*string(r[:Wall]))
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
###################

sort!(coll,[:MouseID,:Protocol,:Wall])
z = []
for par in [:Inverse_Temp, :Integration, :Cost,:D_Inverse_Temp, :D_Integration, :D_Cost]
    idxs = occursin.("true",coll[:,:Wall])
    o = scatter(coll[.!idxs,par],coll[idxs,par],
    group = coll[idxs,:MouseID],
    legend = false,
    xlabel = "no barrier",
    ylabel = "barrier",
    title = string(par),
    markersize = 1)
    axis_list = (xlims(o)...,ylims(o)...)
    Plots.abline!(1,0)
    push!(z,o)
end

plot(z...)
Plots.abline!(1,0)
z
#####
function param_plot(df::AbstractDataFrame,split_var::Symbol,params::Union{Tuple,AbstractVector};groups = :MouseID)
    z = []
    sort!(df, [groups,split_var])
    dof = union(df[:,split_var])
    idxs_x = df[:,split_var].== dof[1]
    idxs_y = df[:,split_var].== dof[end]
    for par in params
        o = scatter(df[idxs_x,par],df[idxs_y,par],
        group = df[idxs_x,groups],
        legend = false,
        xlabel = dof[1],
        ylabel = dof[end],
        title = string(par),
        markersize = 1)
        Plots.abline!(1,0)
        push!(z,o)
    end
    plot(z...)
end

#####
param_plot(coll,:Protocol,(:Inverse_Temp, :Integration, :Cost))
#####
describe(coll)
using StatPlots
##
P_int = @df coll boxplot(:Protocol,:Integration,xlabel = "Protocol", ylabel = "Integration")
P_inv = @df coll boxplot(:Protocol,:Inverse_Temp, xlabel = "Protocol", ylabel = "Inverse_Temp")
P_costo = @df coll boxplot(:Protocol,:Cost, xlabel = "Protocol", ylabel = "Cost")
W_int = @df coll boxplot(:Wall,:Integration, xlabel = "Wall", ylabel = "Integration")
W_inv = @df coll boxplot(:Wall,:Inverse_Temp, xlabel = "Wall", ylabel = "Inverse_Temp")
W_costo = @df coll boxplot(:Wall,:Cost, xlabel = "Wall", ylabel = "Cost");
##
plot(P_int,
    P_inv,
    P_costo,
    W_int,
    W_inv,
    W_costo,legend = false)
