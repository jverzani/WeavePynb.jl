## mustache template for ipynb
ipynb_tpl_v3 = mt"""
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
  }
]
}
"""

ipynb_tpl_v4 = mt"""
{
  "cells": [
     {{{CELLS}}}
    ],
 "metadata": {
  "language_info": {
   "name": "julia",
   "version": "0.4"
  },
 "kernelspec": {
   "display_name": "Julia 0.4.0",
   "language": "julia",
   "name": "julia-0.4"
  }

 },
 "nbformat": 4,
 "nbformat_minor": 0

}
"""

not_needed = """
 
"""

const ipynb_tpl = ipynb_tpl_v4

## graphs. Don't want to dispatch, as packages are loaded in module, not global..
function render_winston(img)
    ## need a cell
    out = Dict()
    out["metadata"] = Dict()
    out["output_type"] = "execute_result"
    out["png"] = stringmime("image/png", img)
    out
end

function render_gadfly(img)
    ## need a cell
    info("render gadfly")
    imgfile = tempname()
    open(imgfile, "w") do io
        draw(PNG(io, 5inch, inch), img)
    end
    data = base64encode(readall(imgfile))
    
    out = Dict()
#    out["metadata"] = Dict()
    out["data"] = Dict()
#    x = sprint(io -> tohtml(io, img))
#    x = split(x, "\n")
#    x = map(a -> a*"\n", x)
    #out["html"] = x
    out["data"]["image/png"] = data
    out["data"]["text/plain"] = ["Plot(...)"]
    out
end

function render_pyplot(img)
    info("render pyplot")
    out = Dict()
    out["metadata"] = Dict()
    out["output_type"] = "execute_result"
    out["png"] = stringmime("image/png", img)
    img[:clear]()
    out
end


## Main function to take a jmd file and turn into a ipynb file
function markdownToPynb(fname::AbstractString)
    
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

function mdToPynb(fname::AbstractString)

    m = make_module()
    
    newblocks = Any[]
    added_gadfly_preamble = false

    process_block("using WeavePynb, LaTeXStrings", m)
    out = Markdown.parse_file(fname,  flavor=Markdown.julia)
    for i in 1:length(out.content)
        cell = Dict()
        cell["metadata"] = Dict()
##        cell["prompt_number"] = i

        
        if isa(out.content[i], Markdown.Code)
            println("==== Block Code ====")
            println(out.content[i])
            ## Code Blocks are evaluated and their last value is added to the output
            ## this is different from IJulia, but similar.
            ## There are issues with Gadfly graphics (need the script...)
            ## and PyPlot, where we need an invocation to manage the figures


 txt = out.content[i].code
            lang = out.content[i].language

            ## we need to set
            ## nocode, noeval, noout
            langs = map(lstrip, split(lang, ","))
            
            docode, doeval, doout = true, true, true
            if "nocode" in langs
                docode = false
            end
            if "verbatim" in langs || "noeval" in langs
                doeval, doout = false, false
            end
            if "noout" in langs
                doout = false
            end
            
            
            ## language is used to pass in arguments
            result = nothing
            if doeval
                result = process_block(txt, m)
            end

            !docode && (txt = "")            

            ## txt = out.content[i].code
            ## lang = out.content[i].language
            ## if lang == "" || lang == "j" || lang == "julia"
            ##     result = process_block(txt, m)
            ## else
            ##     result = nothing
            ## end

            
            cell["cell_type"] = "code"
            cell["execution_count"] = nothing
            #cell["collapsed"] = false
            #cell["language"] = "python"
            #            cell["input"] = txt
            cell["source"] = [txt]
            

           
            println("Type of result: $(typeof(result))")
            
            if result == nothing
                cell["outputs"] = []
            elseif isa(result, Question)
                println("Process a question...")
                continue
                # shove in an empty cell
#                cell["input"] = ""
                cell["outputs"] = []
                cell["source"] = []
            elseif isa(result, Plots.Plot)
                tmp = tempname()
                io = open(tmp, "w")
                writemime(io, MIME("image/png"), result)
                close(io)

                dpi = 120
                cell["outputs"] = [Dict(
                                        "output_type" => "execute_result",
                                        "execution_count" => nothing,
                                       "data" => Dict("text/plain" => "Plot(...)",
                                                      "image/png" => base64encode(readall(tmp))
                                                      ),
                                       "metadata" => Dict("image/png" => Dict("width"=>5*dpi, "height"=>4*dpi))  
                                       )]
            elseif isa(result, Verbatim) 
                "Do not execute input, show as is"
#                cell["input"] = result.x
#                cell["outputs"] = []
                cell["cell_type"] = "markdown"
                cell["source"] = "<pre>$(result.x)</pre>"
                delete!(cell, "execution_count")
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

                    res = render_gadfly(result)
#                    push!(res["data"]["image/svg+xml"], script)
#                    preamble = Dict()
#                    preamble["metadata"] = Dict()
#                    preamble["output_type"] = "display_data"
#                    preamble["html"] = [script]
                    added_gadfly_preamble = true

                    cell["outputs"] = [res]
                else
                    cell["outputs"] = [render_gadfly(result)]
                    ##cell["outputs"] = []
                end
#                cell["output_type"] = "execute_reult"
                
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
                tmp["metadata"] =Dict()
                mtype =  bestmime(result)
                tmp["output_type"] = "execute_result"
                tmp["execution_count"] = nothing
                #                outtype = ifelse(ismatch(r"latex", string(mtype)), "latex", "text")
                outtype = ifelse(ismatch(r"latex", string(mtype)), "text/latex", "text/plain")
                output = ""
                try 
                    output =  [sprint(io -> writemime(io, mtype, result))]
                catch e
                end
                tmp["data"] = Dict()
                tmp["data"][outtype] = collect(output)
                
                cell["outputs"] = [tmp]
            end
            
        else
            cell["cell_type"] = "markdown"
            BigHeader = Union{Markdown.Header{1},Markdown.Header{2}}
            if isa(out.content[i], Markdown.Header)
                d = Dict()
                d["internals"] = Dict()
                if isa(out.content[i], BigHeader)
                    d["internals"]["slide_helper"] = "subslide_end"
                end
                d["internals"]["slide_type"] = "subslide"
                d["slide_helper"]="slide_end"
                d["slideshow"] = Dict()
                d["slideshow"]["slide_type"] = isa(out.content[i], BigHeader) ? "slide" : "subslide"
                cell["metadata"] = d
            end

            result = out.content[i]
            println("process"); println(result); println(bestmime(result)); println("----")
            
            

            cell["source"] = sprint(io -> Markdown.html(io, out.content[i]))
        end

        push!(newblocks, JSON.json(cell))
    end
    

    ## return string
    Mustache.render(ipynb_tpl, Dict("TITLE" => "TITLE", "CELLS" => join(newblocks, ",\n")))

   
end
