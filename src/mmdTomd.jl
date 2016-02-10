function mmd_to_md(fname::AbstractString; kwargs...)

    bname = basename(fname)
    ismatch(r"\.mmd$", bname) || error("this is for mmd template files")
    bname = replace(bname, r"\.mmd$", "")

    jl = replace(fname,".mmd",".jl")
    md = replace(fname,".mmd",".md")
    mmd = fname

    
    ## do this only if md file older than either .mmd or .jl
    if !isfile(md) || (mtime(mmd) > mtime(md)) | (mtime(jl) > mtime(md))
        include("$bname.jl")

        tpl = Mustache.template_from_file(fname)
    
        io = open(md, "w")
        write(io, Mustache.render(tpl, Main.(symbol(bname))))
        close(io)
    end
                     
end
