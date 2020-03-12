"""
`SwitchEvidenceAccumulation_uncertainty(events, Prew, Psw, α; E1 = 0)`
events = Vector of Boolean indicating rewards or failures
Prew = P of reward
#Psw = P of switch
E1 = Evidence are calculated recursively, the first has to be given.
    After a reward the evidence of siwtch is 0
α = uncertainty,
"""

function SwitchEvidenceAccumulation_uncertainty(n_fail, Prew, Psw, α; E1 = 0)
    #n_fail = number of pokes
    #Prew = P of reward
    #Psw = P of switch
    #E1 = Evidence are calculated recursively, the first has to be given. After a reward the evidence of siwtch is 0
    #α = uncertainty
    Es = zeros(n_fail)
    Es[1] = E1
    for i = 2:n_fail
        Es[i] = (Es[i-1]+Psw)/((1-Prew)*(1-Psw))*α + (1-α)
    end
    return Es
end
