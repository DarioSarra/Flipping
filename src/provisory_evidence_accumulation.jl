using Flipping
using LsqFit
using GroupedErrors
using StatsPlots

##colors
c9090 = RGBA(108/255,218/255,165/255)#RGBA(181/255,94/255,50/255)
c9030 = RGBA(23/255,116/255,206/255)#RGBA(181/255,73/255,144/255)
c3030 = RGBA(181/255,94/255,51/255)#RGBA(111/255,108/255,166/255)
gr(grid=false,background_color = RGBA(0.8,0.8,0.8,1))
##
#probability that the state has change after n_fail consecutive failures
function rec_lr(n_fail, Prew, Psw; E1=0)
    #= estimate P(depleted) / P(rich); as a ratio not conditioned probability
    n_fail = number of pokes
    Prew = probability of reward
    Psw = probability of state transition
    E1 = first evidence need to be given been calculated recursively
    after a reward the evidence of P(depleted) / P(rich) = 0
    =#
    Es = zeros(n_fail)
    Es[1] = E1
    for i = 2:n_fail
        Es[i] = (Es[i-1]+Psw)/((1-Prew)*(1-Psw))
    end
    return Es
end
function rec_lr_with_uncertainty(n_fail, Prew, Psw, α; E1 = 1)
    #n_fail = numero di poke
    #Prew = probabilitá reward
    #Psw = probabilitá di transizione
    #E1= la prima evidenza deve essere assegnata perché la probabilitaá è calcolata in maniera ricorsiva
    #α = uncertainty
    Es = zeros(n_fail)
    Es[1] = E1
    for i = 2:n_fail
        Es[i] = (Es[i-1]+Psw)/((1-Prew)*(1-Psw))*α + (1-α)
    end
    return Es
end
#Probability of being in the correct side after n_fail consecutive failures, requires to compute rec_lr
function Pwrong(evidence_accumulation)
    # x = pdpl / prich; x è la stima ottenuta dalla funzione rec_lr
    # x*(1-pdpl)  = pdpl
    # x - x*pdpl = pdpl
    # x = pdpl + x*pdpl
    # x = pdpl(1+x)
    # x/(1+x) = pdpl
    evidence_accumulation ./ (1 .+ evidence_accumulation)
end

function Pwrong_with_uncertainty(n_fail, Prew, Psw, α; E1 = 0)
    evidence_accumulation = rec_lr(n_fail, Prew, Psw, E1, α)
    evidence_accumulation ./ (1 .+ evidence_accumulation)
end

function Pwrong(n_fail, Prew, Psw; E1 = 0)
    evidence_accumulation = rec_lr(n_fail, Prew, Psw; E1 = E1)
    evidence_accumulation ./ (1 .+ evidence_accumulation)
end

function Pcorrect(n_fail, Prew, Psw; E1 = 0)
    1 .- Pwrong(n_fail, Prew, Psw; E1 = E1)
end
@. expon(x,p) = p[1]*exp(x*p[2]) ## model for an exponent for fitting
inverse_exp(y,p) = (log(y/p[1]))*1/p[2] ## model for an inverse exponent

function fit_protocol(prot)
    xdata = 0:size(prot,1)-1
    ydata = prot #evidence accumulation of n_fail consecutive omissions ::array
    p0 = [0.5, 0.5] # initialization of parameters
    fit = curve_fit(expon, xdata, ydata, p0)
end

function fit_protocol(n_fail, Prew, Psw; E1 = 1)
    ydata = Pcorrect(n_fail, Prew, Psw; E1 = 1) #evidence accumulation of n_fail consecutive omissions ::array
    xdata = 0:size(ydata,1)-1
    p0 = [0.5, 0.5] # initialization of parameters
    fit = curve_fit(expon, xdata, ydata, p0)
    x = 0.0:0.1:n_fail
    (collect(x),expon(x,fit.param))
end
##
c = fit_protocol(4,0.8,0.4)
c
##
plot(fit_protocol(4,0.8,0.4))
##
plt = plot(fit_protocol(10,0.6,0.3),
    xticks = 1:10,
    xlabel = "Consecutive failures",
    ylabel =  "Probability of current side high",
    label="60/30")
plot!(plt, fit_protocol(10,0.3,0.15),label="40/20")
Plots.abline!(plt,0,0.05,label = "hypothetical threshold to leave")
##
plt = plot(fit_protocol(10,0.3,0.15),
    xticks = 1:10,
    title  = "Evidence accumulation",
    xlabel = "Evidence",
    ylabel =  "Latent state accumulation P(correct)",
    color = :black,
    legend = false,
    linewidth = 3,
    tickfont = font(:Bookman,12),
    background_color = RGBA(1,1,1,0)
    )
##
savefig(plt,"/home/beatriz/mainen.flipping.5ht@gmail.com/Flipping/Datasets/example.png")
##
Plots.abline!(plt,0,0.15,linewidth = 3,
    color = :black,
    annotations=(5, 0.18, text("Latent threshold", :left)))
savefig(plt,"/home/beatriz/mainen.flipping.5ht@gmail.com/Flipping/Datasets/example2.png")
##
Plots.abline!(plt,0,0.05,linewidth = 3,
    color = :blue)
savefig(plt,"/home/beatriz/mainen.flipping.5ht@gmail.com/Flipping/Datasets/example3.png")
##
plot!(fit_protocol(10,0.2,0.1),
    linewidth = 3,
    color = :blue)
savefig(plt,"/home/beatriz/mainen.flipping.5ht@gmail.com/Flipping/Datasets/example4.png")
