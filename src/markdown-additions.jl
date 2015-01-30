## from Markdown.jl

import Base: display, writemime

graph_types = String["Plot", "FramedPlot"]



function tohtml(io::IO, m::MIME"text/html", x)
  writemime(io, m, x)
end

function tohtml(io::IO, m::MIME"text/plain", x)
  writemime(io, m, x)
end

function tohtml(io::IO, m::MIME"image/png", img)
  print(io, """<img src="data:image/png;base64,""")
  print(io, stringmime(m, img))
  print(io, "\" />")
end

function tohtml(m::MIME"image/svg+xml", img)
  writemime(io, m, img)
end

# Display infrastructure

function bestmime(val)
  for mime in ("text/html", "text/latex", "application/x-latex", "image/svg+xml", "image/png", "text/plain")
    mimewritable(mime, val) && return MIME(symbol(mime))
  end
  error("Cannot render $val to Markdown.")
end

tohtml(io::IO, x) = tohtml(io, bestmime(x), x)



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
println(x)
    x = split(x, "\n")
#    x = (a -> a*"\n", x)
    out["html"] = x
    out
end

function render_pyplot(img)
    out = Dict()
    out["metadata"] = Dict()
    out["output_type"] = "pyout"
    out["png"] = stringmime("image/png", img)
    out
end

