## TODO

##            code eval output
## .           o   o    o
## nocode      x   o    o
## noeval      o   x    x       (verbatim)
## noout       o   o    x
## Idea is we can mark our code fences as above and suppress the code, output or evaluation


## override HTML esc of strings
Markdown.htmlinline(io::IO, md::AbstractString) = write(io, md)




## Main function to take a jmd file and turn into an HTML
function markdownToHTML(fname::AbstractString; TITLE="", kwargs...)
    
    dirnm, basenm = dirname(fname), basename(fname)
    newnm = replace(fname, r"[.].*", ".html")
    out = mdToHTML(fname; TITLE=TITLE, kwargs...)
    
    io = open(newnm, "w")
    write(io, out)
    close(io)
end

"""

Convert a markdown file into an HTML page.

Processes `Question` types, graphical output of `Winston`, `Gadfly`,
and `PyPlot`. For the latter, one should call `gcf()` as the last
expressions in a cell block.

Markdown idiosyncracies:
* there is no `_underscore_` or `__double underscore__`
* for sections, best not to skip 2 or more lines, as they can get wrapped in `<p></p>` tags and not show
* Can use LaTeX markup

"""
function mdToHTML(fname::AbstractString; TITLE="", kwargs...)

    m = make_module()
    safeeval(m, parse("using LaTeXStrings"))
    safeeval(m, parse("macro q_str(x)  \"`\$x`\" end"))
    buf = IOBuffer()
    added_gadfly_preamble = false
    
    process_block("using WeavePynb, LaTeXStrings", m)
    out = Markdown.parse_file(fname, flavor=Markdown.julia)

    for i in 1:length(out.content)
        println(out.content[i])
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
                txt = replace(txt, r"\nnothing$", "") ## trim off trailing "nothing"
                docode && length(txt) > 0 && println(buf, """<pre class="sourceCode julia">$txt</pre>""")
            elseif isa(result, Invisible)
                "Do not show output or input"
                nothing
            elseif isa(result, HTMLoutput) 
                "Do not execute input, show as is"
                txt = ""
                doout && writemime(buf, "text/plain", result)
            elseif isa(result, Verbatim) 
                "Do not execute input, show as is"
                doout && writemime(buf, "text/plain", result)
            elseif isa(result, Bootstrap)
                "Show with Bootstrap formatting"
                doout && writemime(buf, "text/html", result)
            elseif isa(result, Question)
                "Show a question"
                doout && writemime(buf, "text/html", result)
            elseif isa(result, ImageFile)
                "show an image stored in a file, but embed"
                txt = ""
                doout && println(buf, gif_to_data(result.f, result.caption))
            elseif isa(result, Plots.Plot)
                if isa(result, Plots.Plot{Plots.GadflyPackage})
                     docode && length(txt) > 0 && println(buf, """<pre class="sourceCode julia">$txt</pre>""")
                     if !added_gadfly_preamble
                       ## XXX print out JavaScript
                      added_gadfly_preamble = true
                     end
                     doout && writemime(buf, "text/html", result.o)
                 else
                      length(txt) > 0 && println(buf, """<pre class="sourceCode julia">$txt</pre>""")
                      img = stringmime("image/png", result.o)
                    doout && println(buf, """<img alt="Embedded Image" src="data:image/png;base64,$img">""")
                 end
            elseif string(typeof(result)) == "FramedPlot"
                length(txt) > 0 && println(buf, """<pre class="sourceCode julia">$txt</pre>""")
                img = stringmime("image/png", result)
                doout && println(buf, """<img alt="Embedded Image" src="data:image/png;base64,$img">""")
            elseif  string(typeof(result)) == "Plot"
                docode && length(txt) > 0 && println(buf, """<pre class="sourceCode julia">$txt</pre>""")
                if !added_gadfly_preamble
                    const snapsvgjs = Pkg.dir("Compose", "data", "snap.svg-min.js")
                    ## XXX print out JavaScript
                    added_gadfly_preamble = true
                end
                doout && writemime(buf, "text/html", result)
            elseif string(typeof(result)) == "Figure"
                "Must do gcf() for last line"
                if length(txt) > 0
                    txt1 = join(split(txt, "\n")[1:(end-1)], "\n") ## trim last line which is gcf()
                    docode && println(buf, """<pre class="sourceCode julia">$txt1</pre>""")
                end
                img = stringmime("image/png", result)
                println(buf, """<img alt="Embedded Image" src="data:image/png;base64,$img">""")
            else
                mtype =  bestmime(result)
                length(txt) > 0 && println(buf, """<pre class="sourceCode julia">$txt</pre>""")
                try
                    tmpbuf = IOBuffer()
                    if doout
                        if string(mtype) == "text/plain"                
                            println(tmpbuf, """<pre class="output">""")
                            writemime(tmpbuf, mtype, result)
                            println(tmpbuf, """</pre>""")
                        else
                            println(tmpbuf, """<div class="well well-sm">""")
                            writemime(tmpbuf, mtype, result)
                            println(tmpbuf, """</div>""")
                        end
                        println(buf, takebuf_string(tmpbuf))
                    end
                catch e
                    ## no output
                end
            end
            
        else
           if isa(out.content[i], Markdown.LaTeX)
               Markdown.latex(buf, out.content[i])
           else
             ## we drill down
               Markdown.html(buf,  out.content[i])
           end
        end

        
    end

    body = takebuf_string(buf)

    ## return string
    D = Dict()
    D[:Title] = TITLE
    D[:style] = ""
    D[:body] = body
    for (k,v) in kwargs
        D[k] = v
    end
    Mustache.render(html_tpl, D)
end



"""
  Helper function to allow the md file to be a Mustache template.
  Expects a file `fname.jl` which defines a module `fname`.

  XXX Needs work XXX
"""
function mmd_to_html(fname::AbstractString; kwargs...)
    bname = basename(fname)
    ismatch(r"\.mmd$", bname) || error("this is for mmd template files")
    bname = replace(bname, r"\.mmd$", "")

    jl = replace(fname,".mmd",".jl")
    hml = replace(fname,".mmd",".html")
    mmd = fname

    
    ## do this only if html file older than either .mmd or .jl
    if !isfile(hml) || (mtime(mmd) > mtime(hml)) | (mtime(jl) > mtime(hml))
        include("$bname.jl")

        tpl = Mustache.template_from_file(fname)
    
        io = open("$bname.md", "w")
        write(io, Mustache.render(tpl, Main.(symbol(bname))))
        close(io)

        markdownToHTML("$bname.md"; kwargs...)
    end
end
export mmd_to_html


""" 
Template for an HTML page with embedded questions.

Takes the following  arguments in template for Mustache

:style -- optional additional style values
:BRAND_HREF -- for upper left corner of nav bar
:BRAND_NAME
:body -- filled in 

Uses Bootstrap styling and MathJaX for LaTeX markup.

"""
html_tpl = mt"""

<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8"> 
    <meta name="viewport" content="width=device-width, initial-scale=1">




<link
  href="http://maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap.min.css"
  rel="stylesheet">

<style>
.julia {font-family: "Source Code Pro";
        color:#0033CC;
        }
body { padding-top: 60px; }
h5:before {content:"\2746\ ";}
h6:before {content:"\2742\ ";}
pre {display: block;}
</style>

<script src="http://code.jquery.com/jquery.js"></script>
<script src="http://maxcdn.bootstrapcdn.com/bootstrap/3.3.4/js/bootstrap.min.js"></script>

<!-- .julia:before {content: "julia> "} -->

<style>{{{:style}}}</style>



<script type="text/javascript"
  src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
</script>
<script>
MathJax.Hub.Config({
  tex2jax: {
    inlineMath: [ ["\$","\$"], ["\\(","\\)"]]
  },
  displayAlign: "left",
  displayIndent: "5%"
});
</script>

<script type="text/javascript">
$( document ).ready(function() {
  $("h1").each(function(index) { 
       var title = $( this ).text()
       $("#page_title").html("<strong>" + title + "</strong>");
       document.title = title
  });
  $( "h2" ).each(function( index ) {
    var nm =  $( this ).text();                                    
    var id = $.trim(nm).replace(/ /g,'');
    this.id = id
    $("#page_dropdown").append("<li><a href='#" + id + "'>" + nm + "</a></li>");
  });
  $('[data-toggle="popover"]').popover();  
});
</script>

</head>


<body data-spy="scroll" >

<nav class="navbar navbar-default  navbar-fixed-top">
  <div class="container-fluid">
    <!-- Brand and toggle get grouped for better mobile display -->
    <div class="navbar-header">
      <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#bs-example-navbar-collapse-1">
        <span class="sr-only">Toggle navigation</span>
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
      </button>
         {{#:BRAND_HREF}}<a class="navbar-brand" href="{{{:BRAND_HREF}}}">{{:BRAND_NAME}}</a>{{/:BRAND_HREF}}
    </div>

    <!-- Collect the nav links, forms, and other content for toggling -->
    <div class="collapse navbar-collapse" id="bs-example-navbar-collapse-1">
      <ul class="nav navbar-nav">
        <li><a href="#" id="page_title"></a></li>
      </ul>
      <ul class="nav navbar-nav navbar-right">
         <li class="dropdown">
           <a href="#" class="dropdown-toggle" data-toggle="dropdown" role="button" aria-expanded="false">
           Jump to... <span class="caret"></span></a>
          <ul class="dropdown-menu" role="menu" id="page_dropdown"></ul>
        </li>
      </ul>
    </div><!-- /.navbar-collapse -->
  </div><!-- /.container-fluid -->
</nav>

<header>
</header>

<div class="container-fluid">
  <div class="span10 offset1">
{{{:body}}}
  </div>
</div>  

</body>
</html>
"""

const snapsvgjs = Pkg.dir("Compose", "data", "snap.svg-min.js")
