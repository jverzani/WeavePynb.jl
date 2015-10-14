using LaTeXStrings
using Mustache

## utils




latex_tpl = mt"""
\\documentclass[12pt]{article}
\\usepackage[fleqn]{amsmath}     %puts eqns to left, not centered
\\usepackage{graphicx}
\\usepackage{hyperref}
\\begin{html}
<style>
pre {font-size: 1.2em; background-color: #EEF0F5;}
ul li {list-style-image: url(http://www.math.csi.cuny.edu/static/images/julia.png);}  
</style>
\\end{html}
\\begin{document}
{{{txt}}}
\\end{document}
"""

## Main function to take a jmd file and turn into a latex questions file
function markdownToLaTeXQ(fname::AbstractString)
    dirnm, basenm = dirname(fname), basename(fname)
    newnm = replace(fname, r"[.].*", ".tex")
    out = mdToLaTeXQ(fname)
    
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

function mdToLaTeXQ(fname::AbstractString)

    m = make_module()
    buf = IOBuffer()

    process_block("using WeavePynb, LaTeXStrings", m)
    out = Markdown.parse_file(fname)
    for i in 1:length(out.content)
        
        if isa(out.content[i], Markdown.BlockCode)
            ## Code Blocks are evaluated and their last value is added to the output
            ## If the value is of type Question, the we display differently
            txt = out.content[i].code
            result = process_block(txt, m)

            ## special cases: questions and graphical output
            if isa(result, Nothing)
                cell["outputs"] = []
            elseif isa(result, Question)
                println(buf, "")
                writemime(buf, "application/x-latexq", result)
            elseif string(typeof(result)) == "FramedPlot"
                ## Winston graphics
                println("Handle winston graphics")
                println(buf, "\\begin{verbatim}")
                println(buf, txt)
                println(buf, "\\end{verbatim}")

                println(buf, "\\begin{html}")
                img = stringmime("image/png", result)                
                println(buf, """\n<img alt="Embedded Image" src="data:image/png;base64,$img">\n""")
                println(buf, "\\end{html}")
                
            elseif  string(typeof(result)) == "Plot"
                println("Handle gadfly graphics")
                println(buf, "\\begin{verbatim}")
                println(buf, txt)
                println(buf, "\\end{verbatim}")

                
                println(buf, "\\begin{html}")
                img = stringmime("image/png", result)                
                println(buf, """\n<img alt="Embedded Image" src="data:image/png;base64,$img">\n""")
                println(buf, "\\end{html}")
                
            elseif string(typeof(result)) == "Figure"
                println("Handler PyPlot graphics")
                println(buf, "\\begin{verbatim}")
                println(buf, txt)
                println(buf, "\\end{verbatim}")

                println(buf, "\\begin{html}")
                img = stringmime("image/png", result)                
                println(buf, """\n<img alt="Embedded Image" src="data:image/png;base64,$img">\n""")
                println(buf, "\\end{html}")
                
            else
                if length(txt) > 0
                    mtype =  bestmime(result)
                    outtype = ifelse(ismatch(r"latex", string(mtype)), "latex", "text")
                    println(buf, "\\begin{verbatim}")
                    println(buf, txt)
                    println(buf, "\\end{verbatim}")
                    if string(WeavePynb.bestmime(result)) == "text/plain"
                      println(buf, "\\begin{verbatim}")                
                      writemime(buf, mtype, result)
                      println(buf, "\\end{verbatim}")
                    else
                      writemime(buf, mtype, result)
                    end
                end
            end
            
        else
            try
                ## Headers...
                print(buf, header(out.content[i]))
            catch e
                tmp = IOBuffer()
                #                [Markdown.print_inline(tmp, content) for content in out.content[i].content]
                writemime(tmp, "text/latex", out.content[i])
                txt = takebuf_string(tmp)
                println(txt)
                txt = replace(txt, "<br/>", "\\newline") # hack for newlines...
                print(buf, markdown_to_latex(txt))
            end
        end
    end
    
    txt = takebuf_string(buf)
    ## return string
    Mustache.render(latex_tpl, Dict("TITLE" => "TITLE", "txt" => txt))
end
