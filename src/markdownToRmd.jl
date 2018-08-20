## Convert julia mmd/md file into an Rmd file with julia code prepocessed
## TODO

##            code eval output
## .           o   o    o
## nocode      x   o    o
## noeval      o   x    x       (verbatim)
## noout       o   o    x
## Idea is we can mark our code fences as above and suppress the code, output or evaluation

## Helpers
rmd_code_chunk(buf, txt) =  println(buf, """

```{r eval=FALSE}
$txt

```
                                    """)


function rmd_output_chunk(buf, res)
    if VERSION >= v"0.5.0"
        tmpbuf = IOBuffer()
        context = IOContext(tmpbuf,multiline=true,limit=true)    
        show(context, bestmime(res), res)
        out = String(take!(tmpbuf))
    else
        out = sprint(io -> show(io,  bestmime(res), res))
    end
    out = join(["## "*r for r in split(out, "\n")], "\n")

    println(buf, """

```{r eval=FALSE}
$out
```
""")
end


## for raw html, we need to strip out initial white space
function trim_white(tmp)
    tmp = split(tmp, "\n")
    tmp = join(map(lstrip, tmp), "\n")
end


## Main function to take a jmd file and turn into an Rmd file
function markdownToRmd(fname::AbstractString; TITLE="", kwargs...)
    
    dirnm, basenm = dirname(fname), basename(fname)
    newnm = replace(fname, r"[.].*" => ".Rmd")
    out = mdToRmd(fname; TITLE=TITLE, kwargs...)
    
    io = open(newnm, "w")
    write(io, out)
    close(io)
end

"""

Convert a markdown file into an Rmd file.

Processes `Question` types, graphical output of `Winston`, `Gadfly`,
and `PyPlot`. For the latter, one should call `gcf()` as the last
expressions in a cell block.

Markdown idiosyncracies:
* there is no `_underscore_` or `__double underscore__`
* for sections, best not to skip 2 or more lines, as they can get wrapped in `<p></p>` tags and not show
* Can use LaTeX markup

"""
function mdToRmd(fname::AbstractString; TITLE="", kwargs...)
    m = make_module()
    safeeval(m, Meta.parse("using LaTeXStrings, Plots; plotly()"))
    safeeval(m, Meta.parse("macro q_str(x)  \"`\$x`\" end"))
    
    process_block("using WeavePynb, LaTeXStrings", m)
    
    buf = IOBuffer()
    
    out = Markdown.parse_file(fname, flavor=Markdown.julia)
    
    for i in 1:length(out.content)
        ##println(out.content[i])
        if isa(out.content[i], Markdown.Code)
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
            
            if isa(result, Outputonly)
                txt = ""
                result = result.x
            end

            ## special cases
            ## hsould use dispatch here, but we don't....
            if result == nothing
                "Do not show output, just input"
                txt = replace(txt, r"\nnothing$" => "") ## trim off trailing "nothing"
                docode && length(txt) > 0 && rmd_code_chunk(buf, txt)
            elseif isa(result, Invisible)
                "Do not show output or input"
                nothing
            elseif isa(result, HTMLoutput) 
                "Do not execute input, show as is"
                txt = ""
                tmp = sprint(io -> show(io, "text/plain", result))
                tmp = trim_white(tmp)
                doout && println(buf, tmp) #show(buf, "text/plain", result)
            elseif isa(result, Verbatim) 
                "Do not execute input, show as is"
                doout && show(buf, "text/plain", result)
            elseif isa(result, Bootstrap)
                "Show with Bootstrap formatting"
                doout && show(buf, "text/html", result)
            elseif isa(result, Question)
                "Show a question"
                tmp = sprint(io -> show(io, "text/html", result))
                tmp = trim_white(tmp)
                doout && println(buf, "\n", "----\n", "\n", tmp, "\n", "----\n", "\n")

            elseif isa(result, ImageFile)
                "show an image stored in a file, but embed"
                txt = ""
                img = gif_to_data(result.f, result.caption)
                doout && println(buf, trim_white(img))
            elseif isa(result, Plots.Plot)
                docode && length(txt) > 0 && rmd_code_chunk(buf, txt)
                
                if isa(result, Plots.Plot{Plots.PlotlyBackend})
                    Plots.prepare_output(result);
                    img= Plots.html_body(result)
                    img = trim_white(img)
                    doout && write(buf,  img)                    
                else
                    #                    img = stringmime("image/png", result.o)
                    imgfile = tempname() * ".png"
                    png(result, imgfile)
                    img = base64encode(readall(imgfile))
                    doout && println(buf, """<img alt="Embedded Image" src="data:image/png;base64,$img">""")
                end
            elseif string(typeof(result)) == "FramedPlot"
                length(txt) > 0 &&  rmd_code_chunk(buf, txt)
                img = stringmime("image/png", result)
                doout && println(buf, """<img alt="Embedded Image" src="data:image/png;base64,$img">""")
            elseif string(typeof(result)) == "Figure"
                "Must do gcf() for last line"
                if length(txt) > 0
                    txt1 = join(split(txt, "\n")[1:(end-1)], "\n") ## trim last line which is gcf()
                    docode &&   rmd_code_chunk(buf, txt)
                end
                img = stringmime("image/png", result)
                println(buf, """<img alt="Embedded Image" src="data:image/png;base64,$img">""")
            elseif string(typeof(result)) == "SymPy.Sym"
                length(txt) > 0 &&   rmd_code_chunk(buf, txt)

                rmd_output_chunk(buf, "... bug ...")
            else

                length(txt) > 0 &&   rmd_code_chunk(buf, txt)
                try
                    tmpbuf = IOBuffer()
                    if doout
                        rmd_output_chunk(tmpbuf, result)
                        println(buf, String(take!(tmpbuf))) 
                    end
                catch e
                                        rethrow(e)
                    ## no output
                end
            end
            
        else
           if isa(out.content[i], Markdown.LaTeX)
               Markdown.latex(buf, out.content[i])
           else
               ## we drill down
               #               println(sprint(io -> Markdown.plain(io, out.content[i])))
               println(buf, "")
               Markdown.plain(buf,  out.content[i])
           end
        end

        
    end

    body = String(take!(buf)) #takebuf_string(buf)

    ## return string
    D = Dict()
D[:Title] = TITLE
D[:day] = string(today())
    D[:style] = ""
    D[:body] = body
    for (k,v) in kwargs
        D[k] = v
    end
    Mustache.render(markdown_tpl, D)
end



"""
  Helper function to allow the md file to be a Mustache template.
  Expects a file `fname.jl` which defines a module `fname`.

  XXX Needs work XXX
"""
function mmd_to_rmd(fname::AbstractString; kwargs...)
    mmd_to_md(fname)

    bname = basename(fname)
    bname = replace(bname, r"\.mmd$" => "")
    markdownToRmd("$bname.md"; kwargs...)
end
export mmd_to_rmd


""" 
Template for an HTML page with embedded questions.

Takes the following  arguments in template for Mustache

:style -- optional additional style values
:BRAND_HREF -- for upper left corner of nav bar
:BRAND_NAME
:body -- filled in 

Uses Bootstrap styling and MathJaX for LaTeX markup.

"""
markdown_tpl = mt"""
{{{:body}}}
"""


# tufte = """
# title: "{{:Title}}"
# subtitle: "{{:SubTitle}}"
# author: "{{:Author}}"
# date: {{:day}}
# output:
#   tufte::tufte_html: default
#   tufte::tufte_handout:
#     citation_package: natbib
#     latex_engine: xelatex
#   tufte::tufte_book:
#     citation_package: natbib
#     latex_engine: xelatex
# {{#:bibfile}}bibliography: {{:bibfile}}.bib {{/:bibfile}}
# link-citations: yes
# """
