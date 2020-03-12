"""
`process_streaks`
"""

function process_streaks(df::DataFrames.AbstractDataFrame; photometry = false)
    dayly_vars_list = [:MouseID, :Gen, :Drug, :Day, :Daily_Session, :Box, :Stim_Day, :Condition, :ExpDay, :Area, :Session];
    booleans=[:Reward,:Stim,:Wall,:Correct,:Stim_Day]#columns to convert to Bool
    for x in booleans
        df[!,x] = eltype(df[!,x]) == Bool ? df[!,x] : occursin.("true",df[!,x],)
    end
    streak_table = by(df, :Streak) do dd
        dt = DataFrame(
        Num_pokes = size(dd,1),
        Num_Rewards = length(findall(dd[!,:Reward].==1)),
        Start_Reward = dd[1,:Reward],
        Last_Reward = findlast(dd[!,:Reward] .== 1).== nothing ? 0 : findlast(dd[!,:Reward] .== 1),
        Prev_Reward = findlast(dd[!,:Reward] .== 1).== nothing ? 0 : findprev(dd[!,:Reward] .==1, findlast(dd[!,:Reward] .==1)-1),
        Trial_duration = (dd[end,:PokeOut]-dd[1,:PokeIn]),
        Start = (dd[1,:PokeIn]),
        Stop = (dd[end,:PokeOut]),
        Pre_Interpoke = size(dd,1) > 1 ? maximum(skipmissing(dd[!,:Pre_Interpoke])) : missing,
        Post_Interpoke = size(dd,1) > 1 ? maximum(skipmissing(dd[!,:Post_Interpoke])) : missing,
        PokeSequence = [SVector{size(dd,1),Bool}(dd[!,:Reward])],
        Stim = dd[1,:Stim],
        StimFreq = dd[1,:StimFreq],
        Wall = dd[1,:Wall],
        Protocol = dd[1,:Protocol],
        Correct_start = dd[1,:Correct],
        Correct_leave = !dd[end,:Correct],
        Block = dd[1,:Block],
        Streak_within_Block = dd[1,:Streak_within_Block],
        Side = dd[1,:Side],
        ReverseStreak = dd[1,:ReverseStreak]
        )
        for s in dayly_vars_list
            if s in names(df)
                dt[!,s] .= df[1, s]
            end
        end
        return dt
    end
    streak_table[!,:Prev_Reward] = [x .== nothing ? 0 : x for x in streak_table[:,:Prev_Reward]]
    streak_table[!,:AfterLast] = streak_table[!,:Num_pokes] .- streak_table[!,:Last_Reward];
    streak_table[!,:BeforeLast] = streak_table[!,:Last_Reward] .- streak_table[!,:Prev_Reward].-1;
    prov = lead(streak_table[!,:Start],default = 0.0) .- streak_table[!,:Stop];
    streak_table[!,:Travel_to] = [x.< 0 ? 0 : x for x in prov]
    if photometry
        frames = by(df, :Streak) do df
            dd = DataFrame(
            In = df[1,:In],
            Out = df[end,:Out],
            LR_In = findlast(df[:Reward])==0 ? NaN : df[findlast(df[:Reward]),:In],
            LR_Out = findlast(df[:Reward])==0 ? NaN : df[findlast(df[:Reward]),:Out]
            )
        end
        streak_table[:In] = frames[:In]
        streak_table[:Out] = frames[:Out]
        streak_table[:LR_In] = frames[:LR_In]
        streak_table[:LR_Out] = frames[:LR_Out]
    end

    return streak_table
end
