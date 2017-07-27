"""

Convert XXX.mmd + XXX.jl into a XXX.md file.
This allows values in XXX.jl to be inserted into the mustache template XXX.mmd to
dynamically render an md file. Examples of use include randomizing questions, including fancy graphics, ...

If converting into many formats this should only be run once, as otherwise the different formats will possible differences when randomization is involved.

"""
function mmd_to_md(fname::AbstractString; kwargs...)

    bname = basename(fname)
    ismatch(r"\.mmd$", bname) || error("this is for mmd template files")
    bname = replace(bname, r"\.mmd$", "")

    jl = replace(fname,".mmd",".jl")
    md = replace(fname,".mmd",".md")
    mmd = fname

    
    ## do this only if md file older than either .mmd or .jl
    if !isfile(md) || (mtime(mmd) > mtime(md)) || (mtime(jl) > mtime(md))
        include("$bname.jl")

        tpl = Mustache.template_from_file(fname)
    
        io = open(md, "w")
        write(io, Mustache.render(tpl, getfield(Main,Symbol(bname))))
        close(io)
    end
                     
end
