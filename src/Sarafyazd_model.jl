##
"""
IDEAL OBSERVER MODEL: Probability of switch compared to no switch at poke k after consecutive failures
k = consecutive failure
C = estimated state (L or R, turned in High and Low as in being already in the rewarded side)
Pr = probability

Qk💠 = Pr(Ck+1 ≠ Ck|t[k0:k],C[k0:k]) / Pr(Ck+1 = Ck|t[k0:k],C[k0:k]) {P(switch)/P(no switch)}

i = trial
t = confidence, depends on
    yi =  p of correct discrimination(ABSENT IN THE Flipping)  equal to Prew; they used the subjective psychometric function
    λi =  p of transition at trial i given the hazard of Psw

P of not reward (in absence of switch) = λk0 +  Σ[i = k0:k](λi(Π[j = k0:i-1])) / Π[i = k0:k](1 - yi)(1 - λi)

CONFIDENCE-BASED MODEL
χΣ = trial by trial evidence for a switch, increment with a magnitude dipendent on the expected accuracy (confidence)
    it has a gaussian distribution at each trial with μχ and σχ  such that CBM was equal to IOM for 1B-Er. σχ grows linearly
    with the number of error trial (failures) (σ²χ for N failure = N σχ of first error)
Θ = threshold

Making CBM close to IOM
    Qk🌸 = P(χΣ > = Θ) \ P(χΣ < Θ) = Integral(Θ,inf)(N(μχ,σχ)dχΣ) / 1 - Integral(Θ,inf)(N(μχ,σχ)dχΣ) = Qk💠

    REARRANGED IN
    Integral(-inf, Θ) (N(μχ,σχ)dχΣ) = 1 - (Qk💠 / 1 - Qk💠)

α = perseverance factor

being μχΣ fixed by the IOM and its relationship with σχΣ the model can be reduced to 2 parameter σχΣ and α Ψ = {σχΣ, α}
probability of switch become

    p(Xy/n = SW|ψ) Integral(θ,inf) (N(α(μχ),σχ)dχΣ)
"""
##
using QuadGK
using Distributions
using Optim
using FileIO
using DataFrames
using StatsBase
using StatsFuns
using StructArrays
using Plots
import Flipping.nextcount
using LinearAlgebra
##
quadgk(f, a,b,c...; rtol=sqrt(eps), atol=0, maxevals=10^7, order=7, norm=norm)
fun(x) = exp(x)
quadgk(fun,-1.0,1.0)

plot(pdf.(Normal(), -1.0:0.2:1.0))

rand(Normal(1,0.5))
#########

function χ(p, leave::Bool, fail)
    failure_index = Int64(fail) + 1
    μ,σ = p
    if σ < 0
        return 10000000
    else
        store = Vector{Float64}(undef,failure_index)
        for i in 1:length(failure_index)
            store[i] = rand(Normal(μ,i*σ))
        end
        accumulation = Base.accumulate(+,store)
        result = accumulation[end]
        return - log(exp(-result)+1) - !leave * result
    end
end

function smart_data_evidence(p, leaves, failure_indices)
    soa = StructArray((leaves, failure_indices))
    cm = countmap(soa)
    smart_data_evidence(p, cm)
end

function smart_data_evidence(p, cm)
    sum(n*χ(p, value...) for (value, n) in cm)
end
###############
function failure_idx(count::T, rewarded) where {T <: Number}
    if rewarded
        count = 0.0
    else
        count + 1.0
    end
end
###############

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
#################
any(isnan.(filtered[:,:LastPoke]))
any(isnan.(filtered[:,:FailuresIdx]))
#################
coll =by(filtered,[:Protocol,:Wall,:MouseID]) do dd
    leaves = dd[:,:LastPoke]
    failures_indices = dd[:,:FailuresIdx]
    ϵ = 10^(-2)
    res = optimize(p -> -smart_data_evidence(p, leaves, failures_indices) + ϵ*norm(p)^2, [1.0,1.0])
    mins = Optim.minimizer(res)
    DataFrame(Mu_G = mins[1], Sigma_N = mins[2])
    #DataFrame(Inverse_Temp = mins[1], Integration = mins[2])
end
println(describe(coll))
f = plot(; legend = :bottomright)
param_plot(coll,:Wall,[:Mu_G,:Sigma_N])
###############
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
