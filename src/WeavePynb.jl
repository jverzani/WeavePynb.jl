module WeavePynb

## TODO: evaluate cells (atleast have that option)

using JSON, Mustache, Markdown


include("markdown-additions.jl")
include("evalit.jl")


export markdownToPynb ##, markdownToLaTex




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
    newblocks = Any[]
    added_gadfly_preamble = false

    out = Markdown.parse_file(fname)
    for i in 1:length(out.content)
        cell = Dict()
        cell["metadata"] = Dict()
        cell["prompt_number"] = i
        
        if isa(out.content[i], Markdown.BlockCode)
            ## Code Blocks are evaluated and their last value is added to the output
            ## this is different from IJulia, but similar.
            ## There are issues with Gadfly graphics (need the script...)
            ## and PyPlot, where we need an invocation to manage the figures
            
            txt = out.content[i].code
            result = process_block(txt)
            
            cell["cell_type"] = "code"
            cell["collapsed"] = "false"
            cell["languge"] = "python"
            cell["input"] = txt
            

            ## Special case the graphics outputs...
            if string(typeof(result)) == "FramedPlot"
                cell["outputs"] = [render_winston(result)]
            elseif  string(typeof(result)) == "XXPlot"
                if !added_gadfly_preamble
                    ## XXX this is *not* working, needed to figure out preamble... XXX
                    const snapsvgjs = Pkg.dir("Compose", "data", "snap.svg-min.js")
                    preamble = Dict()
                    preamble["metadata"] = Dict()
                    preamble["output_type"] = "display_data"
#                    preamble["html"] = [script]
                    cell["outputs"] = [preamble, render_gadfly(result)]
                    cell["outputs"] = []
                    added_gadfly_preamble = true
                else
                    ## cell["outputs"] = [render_gadfly(result)]
                    cell["outputs"] = []
                end
            elseif string(typeof(result)) == "Figure"
                "Must do gcf() for last line"
                cell["outputs"] = [render_pyplot(result)]
                cell["input"] = join(split(txt, "\n")[1:(end-1)], "\n") ## trim last line which is gcf()
            else
                tmp = Dict()
                tmp["metdata"] =Dict()
                tmp["output_type"] = "pyout"
                tmp[:text] = [sprint(io -> writemime(io, bestmime(result), result))]
                cell["outputs"] = [tmp]
            end
            
        else
            cell["cell_type"] = "markdown"
            cell["source"] = sprint(io -> tohtml(io, out.content[i]))
        end
        if !haskey(cell, "skip")
            push!(newblocks, JSON.json(cell))
        end
    end
    

    ## return string
    Mustache.render(ipynb_tpl, {"TITLE" => "TITLE", "CELLS" => join(newblocks, ",\n")})

   
end

## latexcode

# ## mustache template for LaTex
# latex_tpl = """
# \\documentclass{article}
# \\usepackage{geometry}
# \\usepackage{amsmath}
# \\usepackage{hyperref}
# \\begin{document}
# {{{body}}}
# \\end{document}
# """
#include("WeaveLatex.jl")


end # module
