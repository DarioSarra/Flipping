
"""
`gen`

look for a list of genotypes from the MouseID
"""
function gen(str; dir = joinpath(dirname(@__DIR__), "genotypes"))
    genotype = "missing"
    for file in readdir(dir)
        if endswith(file, ".csv")
            df = FileIO.load(joinpath(dir, file)) |> DataFrame
            n = names(df)[1]
            if str in df[!,n]
                genotype = string(n)
            end
        end
    end
    genotype
end

"""
`pharm`
"""
function pharm(str; dir = joinpath(dirname(@__DIR__), "pharmacology"))
    drug = "missing"
    for file in readdir(dir)
        if endswith(file, ".csv")
            df = FileIO.load(joinpath(dir, file)) |> DataFrame
            n = names(df)[1]
            if str in df[!,n]
                drug = String(n)
            end
        end
    end
    return drug
end
