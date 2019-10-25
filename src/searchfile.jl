"""
`get_data`

Functions to find the path to data files according to character pattern considering that each session is a subfolder
Get data revised: this version operate in 2 possible way,
in the first way it will looks for file names containing a specified string
in the second way use a symbol to refer to a dictionary and find the specified string
"""
#Method 1 inputs a directory and a string
function get_data(dirnames,what::String)
    location = String[] #array to load with all the paths corrisponding to researched file type
    if eltype(dirnames) == Char #in case only one folder is loaded the for loop would research in single character
        tool = String[]
        push!(tool,dirnames)
        dirnames = tool
    end
    for dirname in dirnames
        files = readdir(dirname)
        for file in files
            if occursin(Regex(what), file) && !occursin(Regex(".txt"), file)
                complete_filename = joinpath(dirname,file)
                push!(location,complete_filename)
            end
        end
    end
    return location
end
#Method 2 a directory and a symbol
function get_data(dirnames, kind::Symbol)
    #the dictionary refers the symbol in the input to a specific string to look for
    ext_dict = Dict(:bhv => "a.csv", :cam => ".mat", :log => "AI.csv")
    if !(kind in keys(ext_dict))
        error("Choose among $(keys(ext_dict))")
    end
    #once the string is identified the function call itself again with the first method
    return get_data(dirnames, ext_dict[kind])
end

function get_data(Dir::String)
    files = readdir(Dir)
    bhv = []
    for file in files
        if occursin(Regex(".csv"), file)
            complete_filename = joinpath(Dir,file)
            push!(bhv,complete_filename)
        end
    end
    return bhv
end

"""
`create_DataIndex`
create a Dataframe to identify the raw files to processed it has 2 methods, find files in run_task_photo/raw_data
or takes all the files in a folder
"""
function create_DataIndex(bhv)
    string_search = match.(r"[a-zA-Z]{2}\d+_\d{6}[a-z]{1}",bhv)
    mask = string_search.!= nothing #remove files where there wasn't a match
    string_search = string_search[mask]
    bhv = bhv[mask]
    string_result = [res.match for res in string_search if res !== nothing]
    DataIndex = DataFrame(Bhv_Path = bhv)
    DataIndex[!,:Session] = String.(string_result.*".csv")
    DataIndex[!,:MouseID] = String.([split(t,"_")[1] for t in DataIndex[:,:Session]])
    DataIndex[!,:Day] = String.(["20"*match.(r"\d{6}",t).match for t in DataIndex[:,:Session]])
    DataIndex[!,:Period] = String.([match.(r"[a-z]{1}",t).match for t in DataIndex[:,:Session]])
    return DataIndex
end


"""
`find_behavior`
Function that deals with the type of preprocessing Single exp folder or raw data folder

"""

function find_behavior(Directory_path)
    Dir = replace(Directory_path,basename(Directory_path)=>"")
    saving_path = joinpath(Directory_path,"Bhv")
    if !ispath(saving_path)
        mkdir(saving_path)
    end
    bhv = get_data(Directory_path);
    DataIndex = create_DataIndex(bhv);
    DataIndex[:Preprocessed_Path] = joinpath.(saving_path,DataIndex[:Session])
    results_path = joinpath(Directory_path,"Results")
    if !ispath(results_path)
        mkdir(results_path)
    end
    DataIndex[:Saving_path] = results_path
    return DataIndex
end

function find_behavior(Directory_path::String, Exp_type::String,Exp_name::String, Mice_suffix ::String; run_task = "run_task_photo")
    rawdata_path = joinpath(Directory_path,run_task,"raw_data")
    saving_path = joinpath(Directory_path,"Datasets",Exp_type,Exp_name)
    exp_dir = joinpath(Directory_path,"Datasets",Exp_type,Exp_name)
    if !ispath(saving_path)
        if !ispath(exp_dir)
            mkdir(exp_dir)
        end
        mkdir(saving_path)
    end
    bhv = get_data(rawdata_path, Mice_suffix);
    DataIndex = create_DataIndex(bhv);
    DataIndex[!,:Preprocessed_Path] = joinpath.(saving_path,"Bhv",DataIndex[:,:Session])
    DataIndex[!,:Saving_Path] .= saving_path
    return DataIndex
end


"""
`paths_dataframe`
Create a Dataframe to store paths of files to preprocess
"""
function paths_dataframe(bhv)
    behavior = DataFrame()
    mask = occursin.(bhv,"txt")
    bhv = bhv[mask]
    ##### extract date and mouse ID per session using get_mousedate (it works with a full path)
    MouseID = Vector{String}(undef, size(bhv,1))
    Day = Vector{String}(undef, size(bhv,1))
    Session = Vector{String}(undef, size(bhv,1))
    for i = 1:size(bhv,1)
        MouseID[i], Day[i], Session[i] = Flipping.get_BHVmousedate(bhv[i])
    end
    behavior = DataFrame(MouseID = MouseID)
    behavior[:Day] = Day #file properties are not reliable for the date of the session
    behavior[:Session] = Session.*".csv"
    behavior[:Bhv_Path] = bhv

    return behavior
end


"""
`createfilelist`
use get_data function to obtain all filenames of behaviour
"""
function createfilelist(Directory_path::String, Mice_suffix::String)
    bhv = get_data(Directory_path,:bhv)
    #use get_sessionname to select relevant session (for instance use exp naming code)
    bhv_session = map(t->get_sessionname(t,Mice_suffix),bhv)#to be changed for each dataframe
    # get_sessionname return a start result for sessions that don't match the criteria this can be used to prune irrelevant paths
    bhv = bhv[bhv_session.!="start"]
    bhv_session = bhv_session[bhv_session.!="start"]
    return bhv
end

"""
`get_sessionname(filepath, what::String)`
Use it to find the name of a session from a path, can accept a string or a symbol connected to a dict to find
file matching the requirements
"""
#this function extract the name of a session from a filepath according to a given character pattern
function get_sessionname(filepath, what::String)
    pathinfo = split(filepath,"/")
    sessionname = "start"
    for piece in pathinfo
        if occursin(Regex(what), string(piece))
            sessionname = piece
        end
    end
    sessionname = String(sessionname)
    return sessionname
end


# the second method allows to save experiment related character pattern in a dictionary
function get_sessionname(filepath, kind::Symbol)
    #the dictionary refers the symbol in the input to a specific string to look for
    ext_dict = Dict(:GcAMP => "170", :BilNac => "NB")
    if !(kind in keys(ext_dict))
        error("Choose among $(keys(ext_dict))")
    end
    #once the string is identified the function call itself again with the first method
    return get_sessionname(filepath, ext_dict[kind])
end

"""
`get_session`
Generalise version
"""
function get_session(filepath,what::String)
    a = get_sessionname(filepath,what)
    b = match(r"[a-zA-Z]{2}\d+",a)
    c = b.match
    if occursin(r"\d{8}",a)
        d = match(r"\d{8}",a)
        e = d.match
        e = e[3:8]
    else
        d = match(r"\d{6}",a)
        e = c.match
    end
    sessione = c*"_"*e
    return sessione
end

"""
`check_fiberlocation`

look for a dataset where fiberlocation across day is stored
"""

function check_fiberlocation(data,exp_dir)
    filetofind=joinpath(exp_dir,"FiberLocation.csv");
    if isfile(filetofind)
        fiberlocation = FileIO.load(filetofind) |>DataFrame;
        merged_data = join(data, fiberlocation, on = :Session, kind = :left,makeunique=true);
        println("found fibres location file, HAVE YOU UPDATED IT?")
        return merged_data
    else
        println("no fibres location file")
        return data
    end
end

function check_fiberlocation(data,Directory_path,Exp_name;run_task = "run_task_photo")
    exp_dir = joinpath(Directory_path,run_task,Exp_name)
    check_fiberlocation(data,exp_dir)
end
