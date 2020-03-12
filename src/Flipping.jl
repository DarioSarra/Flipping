module Flipping
using Reexport
using Statistics
@reexport using DataFrames
@reexport using FileIO
@reexport using CSVFiles
@reexport using GLM
@reexport using StatsBase
@reexport using JuliaDBMeta
@reexport using NaNMath
@reexport using ShiftedArrays
@reexport using IterableTables
@reexport using IndexedTables
using TextParse
using JLD2
using StaticArrays
using DSP
using Dates

include("class.jl")
include("utilities.jl")
include("recorded_info.jl")
include("process_varibles.jl")
include("process_pokes.jl")
include("process_bouts.jl")
include("process_streaks.jl")
include("process_sessions.jl")
#include("pokes_streaks.jl")
include("saving&loading.jl")
include("searchfile.jl")



export process_pokes,process_streaks, create_exp_dataframes
export get_data, create_DataIndex,check_fiberlocation
export PhotometryStructure, verify_names, listvalues, convertin_DB
export process_pokes,process_streaks, process_sessions, concat_data!
export get_hierarchy, pharm,gen
export adjust_matfile, adjust_logfile, sliding_f0
export read_log, compress_analog, find_events, observe_pokes,check_burst
export process_photo, add_streaks,check_accordance!,ghost_buster
export carica, create_processed_files, combine_PhotometryStructures




end #module
