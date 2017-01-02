using LaTeXStrings
using Mustache

## utils




latex_tpl = mt"""
\documentclass[12pt]{article}
\usepackage[fleqn]{amsmath}     %puts eqns to left, not centered
\usepackage{color}
\definecolor{light-gray}{gray}{0.15}
\definecolor{darker-gray}{gray}{0.05}
\usepackage{fancyvrb}
\usepackage{graphicx}
\usepackage{hyperref}
\usepackage{geometry}
\begin{document}
{{{txt}}}
\end{document}
"""

## Main function to take a jmd file and turn into a latex questions file
function markdownToLaTeX(fname::AbstractString, use_template=true)
    dirnm, basenm = dirname(fname), basename(fname)
    basenm = replace(basenm, r"\.md$", "")
    newnm = basenm * ".tex"

    if !isdir(basenm)
        println("mkdir $basenm")
        mkdir(basenm)
    end

    out = mdToLaTeX(fname, basenm, use_template)

    
    
    io = open(joinpath(basenm, newnm), "w")
    write(io, out)
    close(io)
end

function code_input(buf, txt)
    println(buf, "\\begin{Verbatim}[framesep=1mm,frame=leftline,fontfamily=courier,formatcom=\\color{darker-gray}]")
    println(buf, txt)
    println(buf, "\\end{Verbatim}")
end


function code_output(buf, txt)
    println(buf, "\\begin{Verbatim}[framesep=3mm,frame=leftline, fontfamily=courier, fontshape=it,formatcom=\\color{darker-gray}]")
    println(buf, txt)
    println(buf, "\\end{Verbatim}")
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

function mdToLaTeX(fname::AbstractString, outdir, use_template=true)

    m = make_module()
    buf = IOBuffer()

    process_block("using WeavePynb, LaTeXStrings, Plots; gr()", m) #pyplot()
    safeeval(m, parse("macro q_str(x)  \"\\\\verb@\$x@\" end"))
    
    out = Markdown.parse_file(fname, flavor=Markdown.julia)
    for i in 1:length(out.content)
        println("processing $i ...")
        println(out.content[i])
        println("...")
        if isa(out.content[i], Markdown.Code)
            ## Code Blocks are evaluated and their last value is added to the output
            ## If the value is of type Question, the we display differently

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

            
#            txt = out.content[i].code
#            result = process_block(txt, m)
            ## special cases: questions and graphical output
            if result == nothing
                code_input(buf, txt)
            elseif isa(result, Question)
                println(buf, "     ")
                writemime(buf, "application/x-latex", result)
            elseif string(typeof(result)) == "FramedPlot"
                ## Winston graphics
                println("Handle winston graphics")
                code_input(buf, txt)
                
            elseif  string(typeof(result)) == "Plot"
                println("Handle gadfly graphics")
                code_input(buf, txt)                

                imgnm = randstring() * ".png"
                png(result, joinpath(outdir, imgnm))

                println(buf, """\\n\\includegraphics{$imgnm}\\n""")
                
            elseif string(typeof(result)) == "Figure"
                println("Handler PyPlot graphics")
                code_input(buf, txt)                                

            elseif isa(result, Plots.Plot)
                code_input(buf, txt)                                                

                imgnm = "fig_" * randstring() * ".png"
                png(result, joinpath(outdir, imgnm))
                println("write to $imgnm")
                println(buf, """\\includegraphics[width=0.8\\textwidth]{$imgnm}""")
                println(buf, " ")
            else
                if length(txt) > 0
                    mtype =  bestmime(result)
                    outtype = ifelse(ismatch(r"latex", string(mtype)), "latex", "text")
                    code_input(buf, txt)
                    if string(WeavePynb.bestmime(result)) == "text/plain"
                      println(buf, "\\begin{Verbatim}[framesep=3mm,frame=leftline, fontshape=it,formatcom=\\color{darker-gray}]")                
                      writemime(buf, mtype, result)
                      println(buf, "")
                      println(buf, "\\end{Verbatim}")
                      println(buf, " ")
                else
                    println("------>"); println(result)
                      writemime(buf, mtype, result)
                    end
                end
            end
            
        else
            try
                ## Headers...
                println(buf, header(out.content[i]))
                println(buf, "")
            catch e
                tmp = IOBuffer()
                #                [Markdown.print_inline(tmp, content) for content in out.content[i].content]
                writemime(tmp, "text/latex", out.content[i])
                txt = takebuf_string(tmp)
                println(ismatch(r"newline", txt))
                txt = replace(txt, "\\newline", "")
                println("~~~~")
                println(txt)
                println("~~~~")                
                txt = replace(txt, "<br/>", "\\newline") # hack for newlines...
                println(buf, txt) #markdown_to_latex(txt))
                println(buf, "")
            end
        end
    end
    
    txt = takebuf_string(buf)
    ## return string
    if use_template
        Mustache.render(latex_tpl, Dict("TITLE" => "TITLE", "txt" => txt))
    else
        txt
    end
end




"""
  Helper function to allow the md file to be a Mustache template.
  Expects a file `fname.jl` which defines a module `fname`.

  XXX Needs work XXX
"""
function mmd_to_latexq(fname::AbstractString; force::Bool=false, kwargs...)
    bname = basename(fname)
    ismatch(r"\.mmd$", bname) || error("this is for mmd template files")
    bname = replace(bname, r"\.mmd$", "")

    jl = replace(fname,".mmd",".jl")
    tex = replace(fname,".mmd",".tex")
    mmd = fname
    md = "$bname.md"
    
    ## do this only if html file older than either .mmd or .jl
    if force || (!isfile(tex) || (mtime(mmd) > mtime(tex)) | (mtime(jl) > mtime(tex)))
        include("$bname.jl")

        tpl = Mustache.template_from_file(fname)
    
        io = open(md, "w")
        write(io, Mustache.render(tpl, Main.(symbol(bname))))
        close(io)

        markdownToLaTeXQ(md; kwargs...)
    end
end
export mmd_to_latexq
