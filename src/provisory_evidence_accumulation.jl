using Flipping
using LsqFit
using StatsPlots

##colors
c9090 = RGBA(108/255,218/255,165/255)#RGBA(181/255,94/255,50/255)
c9030 = RGBA(23/255,116/255,206/255)#RGBA(181/255,73/255,144/255)
c3030 = RGBA(181/255,94/255,51/255)#RGBA(111/255,108/255,166/255)
gr(grid=false,background_color = RGBA(1,1,1,1))
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
function rec_lr_with_uncertainty(n_fail, Prew, Psw, α; E1 = 0)
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

function fit_protocol(n_fail, Prew, Psw; E1 = 0, step = 0.1)
    ydata = Pcorrect(n_fail, Prew, Psw; E1 = E1) #evidence accumulation of n_fail consecutive omissions ::array
    xdata = 0:size(ydata,1)-1
    p0 = [0.5, 0.5] # initialization of parameters
    fit = curve_fit(expon, xdata, ydata, p0)
    x = 0.0:step:n_fail
    (collect(x),expon(x,fit.param))
end
##
c = fit_protocol(4,0.8,0.4)
c
##
plot(fit_protocol(4,0.8,0.4))
##
colorscheme = Dict("80/40" =>RGB(0/255, 158/255, 115/255),
    "60/30" => RGB(86/255, 180/255, 233/255),
    "40/20" => RGB(230/255, 159/255, 0/255))
##
gr(grid=false,background_color = RGBA(1,1,1,1), linewidth = 3)
plt = plot(0:1:9,Pcorrect(10, 0.4, 0.2),#plot(fit_protocol(5,0.8,0.4; step = 1),
    xlabel = "Consecutive failures",
    ylabel =  "Probability of current side high",
    label = "40/20",
    color = colorscheme["40/20"])


plot!(plt, 0:1:6,Pcorrect(7, 0.6, 0.3),
    label= "60/30",
    color = colorscheme["60/30"])

plot!(plt, 0:1:4,Pcorrect(5, 0.8, 0.4),
    label = "80/40",
    color = colorscheme["80/40"])

Plots.abline!(plt,0,0.15,
    label = "example threshold 15%",
    color = :black)

Plots.abline!(plt,0,0.05,label = "example threshold 5%",
    linestyle = :dash, color = :black)
xticks!(plt,0:1:9)



##
dir = "/Volumes/GoogleDrive/My Drive/Flipping/shared docs pietro dario/lab meeting 3-02-2020/inference qualitative observations"
f = joinpath(dir,"updated_inference.pdf")
savefig(plt,f)
##
plt = plot(fit_protocol(10,0.3,0.15),
    xticks = 0:10,
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
