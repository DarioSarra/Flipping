module Flipping
using Reexport
@reexport using Statistics
@reexport using DataFrames
# @reexport using MAT
@reexport using FileIO
@reexport using CSVFiles
@reexport using GLM
@reexport using TextParse
@reexport using ShiftedArrays
@reexport using IterableTables
@reexport using IndexedTables
@reexport using JLD2
@reexport using StaticArrays
@reexport using DSP
@reexport using StatsBase
@reexport using JuliaDBMeta
@reexport using NaNMath
@reexport using Dates

include("class.jl")
include("utilities.jl")
include("recorded_info.jl")
include("process_varibles.jl")
include("pokes_streaks.jl")
include("saving&loading.jl")
include("searchfile.jl")




export PhotometryStructure, verify_names, listvalues, convertin_DB
export process_pokes,process_streaks, process_sessions, concat_data!
export get_hierarchy, pharm,gen
export get_data, create_DataIndex, create_exp_dataframes,check_fiberlocation
export adjust_matfile, adjust_logfile, sliding_f0
export read_log, compress_analog, find_events, observe_pokes,check_burst
export process_photo, add_streaks,check_accordance!,ghost_buster
export carica, create_processed_files, combine_PhotometryStructures




end #module
