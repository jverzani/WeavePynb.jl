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
   "file_extension": ".jl",
   "mimetype": "application/julia",
   "name": "julia",
   "version": "1.3"
  },
 "kernelspec": {
   "display_name": "Julia 1.3",
   "language": "julia",
   "name": "julia-1.3"
  }

 },
 "nbformat": 4,
 "nbformat_minor": 2

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
    data = base64encode(read(imgfile, String))

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



function render_plotly(img)
    ## need a cell
    info("render plotly")
    imgfile = tempname()
    png(img, imgfile)
    data = base64encode(read(imgfile, String))

    out = Dict()
    out["data"] = Dict()
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

function render_gr(img)
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
    newnm = replace(fname, r"[.].*" => ".ipynb")
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

    #    process_block("using WeavePynb, LaTeXStrings, Plots; pyplot()", m)
    process_block("using WeavePynb, LaTeXStrings, Plots; gr()", m)
    safeeval(m, Meta.parse("macro q_str(x)  \"`\$x`\" end"))

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

            ## For graphics, we *now* use `GR`. This requires a flagging
            ## of `figure` when opening a code block. Otherwise, we get
            ## world age issues, as of v0.6.0

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



            cell["cell_type"] = "code"
            cell["execution_count"] = 1
            #cell["collapsed"] = false
            #cell["language"] = "python"
            #            cell["input"] = txt
            cell["source"] = [txt]



            println("Type of result: $(typeof(result))")

            if result == nothing
                cell["outputs"] = []
            elseif isa(result, Question)
                println("Process a question...")
                if isa(result, WeavePynb.Radioq)
                    # shove in an empty cell
                    #                cell["input"] = ""
#                    cell["outputs"] = []
                    tmp = Mustache.render(md_templates["Radioq"], items=["&#10054; $i" for i in result.labels])
                    cell["cell_type"] = "markdown"
                    cell["source"] = tmp
                    delete!(cell, "execution_count")
                else
                    continue
                end

            elseif isa(result, Verbatim)
                "Do not execute input, show as is"
                #                cell["input"] = result.x
                #                cell["outputs"] = []
                cell["cell_type"] = "markdown"
                cell["source"] = "<pre>$(result.x)</pre>"
                delete!(cell, "execution_count")
                ## We should be able to do this, but instead we now get World Age issues
            elseif isa(result, Plots.Plot)
#                if false  # XXX this has issues?
                    tmp = tempname()*".png"
                    Base.invokelatest(png, result, tmp)

                    dpi = 120
                    cell["outputs"] = [Dict(
                                            "output_type" => "execute_result",
                                            "execution_count" => 1,
                                            "data" => Dict("text/plain" => "Plot(...)",
                                                           "image/png" => base64encode(read(tmp, String))
                                                           #"image/png" => out
                                                           ),
                                       "metadata" => Dict("image/png" => Dict("width"=>5*dpi, "height"=>4*dpi))
                    )]
#                else
#                    cell["outputs"] = []
#                end

                # elseif string(typeof(result)) == "FramedPlot"
            #     ## Winston graphics
            #     cell["outputs"] = [render_winston(result)]
            # elseif  isa(result, Plots.Plot)
            #     # if isa(result, Plots.Plot{Plots.GadflyBackend})
            #     #     ## Gadfly graphics
            #     #     if !added_gadfly_preamble
            #     #         ## XXX this is *not* working, needed to figure out preamble... XXX
            #     #         ## Seems like injecting <script> failes.
            #     #         const gadfly_preamble = joinpath(dirname(@__FILE__), "..", "tpl", "gadfly-preamble.js")
                #     #         script = "<script>$(readstring(gadfly_preamble))</script>"
            #     #         added_gadfly_preamble = true
            #     #     end
            #     #     cell["outputs"] = [render_gadfly(result)]
            #     # else
            #         if  isa(result, Plots.Plot{Plots.PlotlyBackend})
            #         cell["outputs"] = [render_plotly(result)]
            #     end
            # elseif string(typeof(result)) == "Figure"
            #     ## *basic* PyPlot graphics.
            #     "Must do gcf() for last line"
            #     cell["outputs"] = [render_pyplot(result)]
            #     if ismatch(r"gcf\(\)$", txt)
            #         cell["input"] = join(split(txt, "\n")[1:(end-1)], "\n") ## trim last line which is gcf()
            #     else
            #         cell["input"] = txt ## trim last line which is gcf()
            #     end
            else
                ## Catch all
                tmp = Dict()
                tmp["metadata"] =Dict()
                mtype =  bestmime(result)
                tmp["output_type"] = "execute_result"
                tmp["execution_count"] = 1
                #                outtype = ifelse(ismatch(r"latex", string(mtype)), "latex", "text")
                outtype = ifelse(occursin(r"latex", string(mtype)), "text/latex", "text/plain")
                    output = ""
                try
                    output =  [sprint(io -> Base.invokelatest(show, io, mtype, result))]
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



            cell["source"] = sprint(io -> Markdown.html(io, out.content[i]))
        end

println("xxxxx")
cell["source"] == String[""] && println("XXXXXXX")
#        println("Source is ", cell["source"])



        push!(newblocks, JSON.json(cell))
    end
println("Here it is.....")
@show ipynb_tpl
    ## return string
    Mustache.render(ipynb_tpl, Dict("TITLE" => "TITLE", "CELLS" => join(newblocks, ",\n")))


end
