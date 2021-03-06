## from Juno

# Super-simple pandoc interface.
function pandoc(infn, infmt::AbstractString, outfmt::AbstractString, args::AbstractString...)
    cmd = String["pandoc",
                     "--from=$(infmt)",
                     "--to=$(outfmt)"]
    for arg in args
        push!(cmd, arg)
    end

    read(pipeline(infn, Cmd(cmd)), String)
end

"""
Take a string in markdown and covert to LaTeX via pandoc
"""
function markdown_to_latex(txt)
    infn = tempname() * ".md"
    io = open(infn, "w"); print(io, txt); close(io)
    out = pandoc(infn, "markdown", "latex")
    rm(infn)
    out
end
