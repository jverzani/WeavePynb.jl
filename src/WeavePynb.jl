module WeavePynb

using JSON, Mustache

export markdownToPynb

## From Judo.pandoc
function pandoc(input::String, infmt::Symbol, outfmt::Symbol, args::String...)
    cmd = ByteString["pandoc",
                     "--from=$(string(infmt))",
                     "--to=$(string(outfmt))"]
    for arg in args
        push!(cmd, arg)
    end
    pandoc_out, pandoc_in, proc = readandwrite(Cmd(cmd))
    write(pandoc_in, input)
    close(pandoc_in)
    readall(pandoc_out)
end


## mustache template
   tpl = """
{"metadata": {
 "language": "Julia",
 "name": "{{{TITLE}}}"
  },
 "nbformat": 3,
 "nbformat_minor": 0,
 "worksheets": [
  {
   "cells": [
     {{{CELLS}}}
    ],
   "metadata": {}
  }]
}
"""

function markdownToPynb(fname::String)
    dirnm, basenm = dirname(fname), basename(fname)
    newnm = replace(fname, r"[.].*", ".ipynb")
    out = mdToPynb(readall(fname))
    io = open(newnm, "w")
    write(io, out)
    close(io)
end
    
function mdToPynb(infn::String)
    metadata, document = JSON.parse(pandoc(infn, :markdown, :json))
    newblocks = Any[]
    
    for block in document
        cell = Dict()
        cell["metadata"] = Dict()
        if haskey(block, "CodeBlock")
            cell["cell_type"] = "code"
            cell["collapsed"] = "false"
            cell["input"] = block["CodeBlock"][2]
            cell["languge"] = "python"
            cell["outputs"] = []
        else
            cell["cell_type"] = "markdown"
            processed_document = [block]
            jsonout_path, jsonout = mktemp()
            JSON.print(jsonout, {metadata, processed_document})
            flush(jsonout)
            close(jsonout)
            output = pandoc(readall(jsonout_path), :json, :markdown)
            rm(jsonout_path)
            cell["source"] = output 
        end
        push!(newblocks, JSON.json(cell))
    end
    
    ## return string
    Mustache.render(tpl, {"TITLE" => "TITLE", "CELLS" => join(newblocks, ",\n")})

end
end # module
