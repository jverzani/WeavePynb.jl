module WeavePynb

## TODO: evaluate cells (atleast have that option)

using JSON, Mustache, Markdown


include("markdown-additions.jl")
include("evalit.jl")


export markdownToPynb, markdownToLaTex




## mustache template for ipynb
   ipynb_tpl = """
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

## mustache template for LaTex
latex_tpl = """
\\documentclass{article}
\\usepackage{geometry}
\\usepackage{amsmath}
\\usepackage{hyperref}
\\begin{document}
{{{body}}}
\\end{document}
"""

## Main function to take a jmd file and turn into a ipynb file
function markdownToPynb(fname::String)
    dirnm, basenm = dirname(fname), basename(fname)
    newnm = replace(fname, r"[.].*", ".ipynb")
    out = mdToPynb(fname)
    
    io = open(newnm, "w")
    write(io, out)
    close(io)
end
    
function mdToPynb(fname::String)
    out = Markdown.parse_file(fname)
    for i in 1:length(out.content)
        cell = Dict()
        cell["metadata"] = Dict()

        if isa(out.content[i], Markdown.BlockCode)
            txt = out.content[i].code
            res = process_block(txt)
            ## XXX Graphics XXX
            cell["cell_type"] = "code"
            cell["collapsed"] = "false"
            cell["languge"] = "python"
            cell["input"] = txt
            cell["outputs"] = [res]
        else
            cell["cell_type"] = "html"
            cell["source"] = sprint(io -> tohtml(io, out.content[i].content)
        end
        if !haskey(cell, "skip")
            push!(newblocks, JSON.json(cell))
        end
    end
    

    ## return string
    Mustache.render(ipynb_tpl, {"TITLE" => "TITLE", "CELLS" => join(newblocks, ",\n")})

   
end

## latexcode
#include("WeaveLatex.jl")


end # module
