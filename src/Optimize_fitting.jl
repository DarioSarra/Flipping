function evidencepertrial(p, leave::Bool, failure_index)
    param = p[1]*(exp(-(failure_index*p[2])) + p[3])
    return -log(exp(-param)+1) - !leave * param
end

leaves, failure_indices = # from data
soa = StructArray((leaves, failure_indices))
cm = countmap(soa)

function evidenceofdatasmart(p, leaves, failure_indices)
    soa = StructArray((leaves, failure_indices))
    cm = countmap(soa)
    evidenceofdatasmart(p, cm)
end

function evidenceofdatasmart(p, cm)
    sum(n*evidencepertrial(p, value...) for (value, n) in cm)
end

using Optim

optimize(p -> -evidenceofdatasmart(p, cm), [1,1,1])

using StatsBase

countmap(rand(1:10, 100))
