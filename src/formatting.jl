## formatting conveniences

"markdown can leave wrapping p's"
function strip_p(txt)
    if ismatch(r"^<p>", txt)
        txt = replace(replace(txt, r"^<p>", ""), r"</p>$", "")
    end
    txt
end

function md(x)
    out = sprint(io ->  writemime(io, "text/html", Markdown.parse(string(x))))
    strip_p(out)
end

""" 
Hide output and input, but execute cell.

Examples
```
2 + 2
Invisible()
```
"""
type Invisible
end

""" 
Show output as HTML

Examples
```
HTMLoutput("<em>em</em>")
```

"""
type HTMLoutput
    x
end
Base.writemime(io::IO, ::MIME"text/plain", x::HTMLoutput) = print(io, """<div>$(x.x)</div>""")
Base.writemime(io::IO, ::MIME"text/html", x::HTMLoutput) = print(io, x.x)



"""
Show as input, but do not execute.
Examples:
```
Verbatim("This will print, but not be executed")
```
"""
type Verbatim
    x
end
Base.writemime(io::IO, ::MIME"text/plain", x::Verbatim) = print(io, """<pre class="sourceCode julia">$(x.x)</pre>""")
Base.writemime(io::IO, ::MIME"text/html", x::Verbatim) = print(io, x.x)


"""
Hide input, but show output

Examples
```
x = 2 + 2
Outputonly(x)
```
"""
type Outputonly
    x
end

## Bootstrap things
abstract Bootstrap
Base.writemime(io::IO, ::MIME"text/html", x::Bootstrap) = print(io, """$(x.x)""")

type Alert <: Bootstrap
    x
    d::Dict
end

### An alert
function alert(txt; kwargs...)
    d = Dict()
    for (k,v) in kwargs
        d[k] = v
    end
    Alert(txt, d)
end

warning(txt; kwargs...) = alert(txt, class="warning", kwargs...)
note(txt; kwargs...) = alert(txt, class="info", kwargs...)


function Base.writemime(io::IO, ::MIME"text/html", x::Alert)
    cls = haskey(x.d,:class) ? x.d[:class] : "success"
    txt = sprint(io -> writemime(io, "text/html", Markdown.parse(x.x)))
    tpl = """
<div class="alert alert-$cls" role="alert">$txt</div>
"""
    
    print(io, tpl)
end






type Example <: Bootstrap
    x
    d::Dict
end

## use nm="name" to pass along name
function example(txt; kwargs...)
 d = Dict()
    for (k,v) in kwargs
        d[k] = v
    end
    Example(txt, d)
end


function Base.writemime(io::IO, ::MIME"text/html", x::Example)
    nm = haskey(x.d,:nm) ? " <small>$(x.d[:nm])</small>" : ""
    txt = sprint(io -> writemime(io, "text/html", Markdown.parse(x.x)))
    tpl = """
<div class="alert alert-danger" role="alert">
  <span class="glyphicon glyphicon-th" aria-hidden="true"></span>
  <span class="text-uppercase">example:</span>$nm$txt
</div>
"""
    
    print(io, tpl)
end


type Popup <: Bootstrap
    x
    title
    icon
    label
end

"""

Create a button to toggle the display of more detail.

Can modify text, title, icon and label (for the button)

The text, title, and label can use Markdown.

LaTeX markup does not work, as MathJax rendering is not supported in the popup.

"""
popup(x; title=" ", icon="share-alt", label=" ") = Popup(x, title, icon, label)

popup_html_tpl=mt"""
<button type="button" class="btn btn-sm" aria-label="Left Align"
  data-toggle="popover"
  title='{{{title}}}'
  data-html=true
  data-content='{{{body}}}'
>
  <span class="glyphicon glyphicon-{{icon}}" aria-hidden="true"></span>{{#button_label}} {{{button_label}}}{{/button_label}}
</button>
"""

function Base.writemime(io::IO, ::MIME"text/html", x::Popup)
    d = Dict()
    d["title"] = sprint(io -> writemime(io, "text/html", Markdown.parse(x.title)))
    d["icon"] = x.icon
    label = sprint(io -> writemime(io, "text/html", Markdown.parse(x.label)))
    d["button_label"] = strip_p(label)
    d["body"] = sprint(io -> writemime(io, "text/html", Markdown.parse(x.x)))
    println(d)
    Mustache.render(io, popup_html_tpl, d)
end



"""

Way to convert rectangular gird of values into a table

"""
type Table <: Bootstrap
    x
end
table(x) = Table(x)

table_html_tpl=mt"""
<div class="table-responsive">
  <table class="table table-hover">
  {{{:nms}}}
  {{{:body}}}                                                                         
  </table>
</div>
"""


function Base.writemime(io::IO, ::MIME"text/html", x::Table)
    d = Dict()
    d[:nms] = "<tr><th>$(join(map(string, names(x.x)), "</th><th>"))</th></tr>\n"
    bdy = ""
    for i in 1:size(x.x)[1]
        bdy = bdy * "<tr>"
        for j in 1:size(x.x)[2]
            bdy = bdy * "<td>$(md(x.x[i,j]))</td>"
        end
        bdy = bdy * "</tr>\n"
    end
    d[:body] = bdy
    Mustache.render(io, table_html_tpl, d)
end
