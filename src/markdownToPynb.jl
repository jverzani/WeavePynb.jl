## mustache template for ipynb
ipynb_tpl = mt"""
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


## graphs. Don't want to dispatch, as packages are loaded in module, not global..
function render_winston(img)
    ## need a cell
    out = Dict()
    out["metadata"] = Dict()
    out["output_type"] = "pyout"
    out["png"] = stringmime("image/png", img)
    out
end

function render_gadfly(img)
    ## need a cell
    
    out = Dict()
    out["metadata"] = Dict()
    out["output_type"] = "display_data"
    x = sprint(io -> tohtml(io, img))
    x = split(x, "\n")
    x = map(a -> a*"\n", x)
    out["html"] = x
    out
end

function render_pyplot(img)
    out = Dict()
    out["metadata"] = Dict()
    out["output_type"] = "pyout"
    out["png"] = stringmime("image/png", img)
    img[:clear]()
    out
end


## Main function to take a jmd file and turn into a ipynb file
function markdownToPynb(fname::String)
    
    dirnm, basenm = dirname(fname), basename(fname)
    newnm = replace(fname, r"[.].*", ".ipynb")
    out = mdToPynb(fname)
    
    io = open(newnm, "w")
    write(io, out)
    close(io)
end

"""

Parses a markdown file into a ipynb file

Tries to handle graphics, but isn't perfect:

* Winston graphics work as expected

* PyPlot graphics have idiosyncracies:

- basic usage requires a call of `gcf()` as last entry of  a cell. This will *also* call clear on the figure, so that 
any subsequent figures are added to a new canvas

- for 3d usage, this is not the case. The 3d graphics use a different backend and the display is different.

* `Gadfly` graphics are not (yet) supported, though this should be addressed .

"""

function mdToPynb(fname::String)

    m = make_module()
    
    newblocks = Any[]
    added_gadfly_preamble = false

    process_block("using WeavePynb, LaTeXStrings", m)
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
            result = process_block(txt, m)

            
            cell["cell_type"] = "code"
            cell["collapsed"] = false
            cell["languge"] = "python"
            cell["input"] = txt
            

            ## special cases: questions and graphical output
            if isa(result, Nothing)
                cell["outputs"] = []
            elseif isa(result, Question)
                # shove in an empty cell
                cell["input"] = ""
                cell["outputs"] = []
            elseif isa(result, Verbatim) 
                "Do not execute input, show as is"
                cell["input"] = result.x
                cell["outputs"] = []
            elseif string(typeof(result)) == "FramedPlot"
                ## Winston graphics
                cell["outputs"] = [render_winston(result)]
            elseif  string(typeof(result)) == "Plot"
                ## Gadfly graphics
                if !added_gadfly_preamble
                    ## XXX this is *not* working, needed to figure out preamble... XXX
                    ## Seems like injecting <script> failes.
                    const gadfly_preamble = joinpath(dirname(@__FILE__), "..", "tpl", "gadfly-preamble.js")
                    script = "<script>$(readall(gadfly_preamble))</script>"
                    preamble = Dict()
                    preamble["metadata"] = Dict()
                    preamble["output_type"] = "display_data"
                    preamble["html"] = [script]
                    added_gadfly_preamble = true

                    cell["outputs"] = [preamble, render_gadfly(result)]
                else
                    cell["outputs"] = [render_gadfly(result)]
                    ##cell["outputs"] = []
                end
                
            elseif string(typeof(result)) == "Figure"
                ## *basic* PyPlot graphics.
                "Must do gcf() for last line"
                cell["outputs"] = [render_pyplot(result)]
                if ismatch(r"gcf\(\)$", txt)
                    cell["input"] = join(split(txt, "\n")[1:(end-1)], "\n") ## trim last line which is gcf()
                else
                    cell["input"] = txt ## trim last line which is gcf()
                end
            else
                tmp = Dict()
                tmp["metdata"] =Dict()
                mtype =  bestmime(result)
                tmp["output_type"] = "pyout"
                outtype = ifelse(ismatch(r"latex", string(mtype)), "latex", "text")
                output = ""
                try 
                    output =  [sprint(io -> writemime(io, mtype, result))]
                catch e
                end
                tmp[outtype] =output

                cell["outputs"] = [tmp]
            end
            
        else
            cell["cell_type"] = "markdown"
            cell["source"] = sprint(io -> tohtml(io, out.content[i]))
        end

        push!(newblocks, JSON.json(cell))
    end
    

    ## return string
    Mustache.render(ipynb_tpl, {"TITLE" => "TITLE", "CELLS" => join(newblocks, ",\n")})

   
end
