## from Markdown.jl

import Base: display, show

graph_types = AbstractString["Plot", "FramedPlot"]

function tohtml(io::IO, m::MIME"text/html", x)
  show(io, m, x)
end

function tohtml(io::IO, m::MIME"text/latex", x)
  show(io, m, x)
end

function tohtml(io::IO, m::MIME"text/plain", x)
  show(io, m, x)
end

function tohtml(io::IO, m::MIME"image/png", img)
  print(io, """<img src="data:image/png;base64,""")
  print(io, stringmime(m, img))
  print(io, "\" />")
end

function tohtml(m::MIME"image/svg+xml", img)
    sprint(io -> show(io, m, img))
end

# Display infrastructure


function bestmime(val)
  for mime in ("text/html",  "text/latex", "application/x-latex", "image/svg+xml", "image/png", "text/plain")
    mimewritable(mime, val) && return MIME(Symbol(mime))
  end
  error("Cannot render $val to Markdown.")
end

tohtml(io::IO, x) = tohtml(io, bestmime(x), x)


##################################################
## write mime methods

function with_environment(f, io, tag)
  print(io, "\\begin{$tag}")
  f()
  print(io, "\\end{$tag}")
end


function with_delimiter(f, io, tag)
  print(io, "$tag")
  f()
  print(io, "$tag")
end

#XXXshow(io::IO, ::MIME"text/latex", md::Markdown.Content) =
#  show(io, "text/plain", md)

##XXX function show(io::IO, mime::MIME"text/latex", block::Markdown.Block)
##   for md in block.content[1:end-1]
##     show(io::IO, mime, md)
##     println(io)
##   end
##   show(io::IO, mime, block.content[end])
## end

function show{l}(io::IO, mime::MIME"text/latex", header::Markdown.Header{l})
    txt = join(header.text)
    if l == 1 
        print(io, "\\section{$(txt)}")
    end
    if l == 2
        print(io, "\\subsection{$(txt)}")
    end
    if l > 2
        print(io, "\\subsubsection{$(txt)}")
    end
end

"heuristic to identify code blocks"
const block_code_re = r"^\n.*\n$"
is_blockcode(content) = isa(content, Markdown.Code) && ismatch(block_code_re, content.code)
#function show(io::IO, ::MIME"text/latex", code::Markdown.BlockCode)
function show(io::IO, ::MIME"text/latex", code::Markdown.Code)
println((code.code, is_blockcode(code)))
  if is_blockcode(code)
    with_delimiter(io, "verbatim") do
      print(io, code.code)
    end
  else
    txt = code.code
    txt = replace(txt, "^", "\\^{}")
    txt = replace(txt, "_", "\\_{}")
    txt = replace(txt, "#", "\\#")
    txt = replace(txt, "@", "\\@")
    print(io, "\\texttt{$(txt)}")
  end
end

#function show(io::IO, ::MIME"text/latex", code::Markdown.InlineCode)
#    print(io, "\\texttt{$(code.code)}")
#end

function show(io::IO, ::MIME"text/latex", md::Markdown.Paragraph)
    println(io, "\\newline")
    for md in md.content
      show(io, "text/latex", md)
    end
end

function show(io::IO, ::MIME"text/latex", md::Markdown.BlockQuote)
  with_environment(io, "quotation") do
    for item in md.content
        show(io, "text/latex", item)
    end
  end
end

function show(io::IO, ::MIME"text/latex", md::Markdown.List)
    with_environment(io, md.ordered < 0 ? "enumerate" : "itemize") do
    for item in md.items
        print(io, "\\item ")
        [show(io, "text/latex", i) for i in item]
    end
  end
end

# Inline elements

##XXX function show(io::IO, ::MIME"text/latex", md::Markdown.Plain)
##   print(io, md.text)
## end

function show(io::IO, ::MIME"text/latex", md::Markdown.Bold)
    print(io, "\\textbf{$(join(md.text))}")
end

function show(io::IO, ::MIME"text/latex", md::Markdown.Italic)
    print(io, "\\textit{$(join(md.text))}")
end

function show(io::IO, ::MIME"text/latex", code::Markdown.Image)
    print(io, "\\includegraphics{$(code.url)}")
end

# function show(io::IO, ::MIME"text/latex", md::Markdown.Image)
#   print(io, """<img src="$(md.url)" alt="$(md.alt)"></img>""")
# end

function show(io::IO, ::MIME"text/latex", md::Markdown.Link)
    print(io, "\\href{$(md.url)}{$(join(md.text))}")
end


function show(io::IO, ::MIME"text/latex", md::Markdown.LaTeX)
  ## Hack, we use $$~ ~$$ to mark these up, so if we see ~..~ wrapping
  ## we add in ...
  txt = md.formula
  if ismatch(r"^~.*", txt)
    print(io, "\n")
    show(io, "text/latex", L"$$")
    show(io, "text/latex",  txt[2:(end-1)])
    show(io, "text/latex", L"$$")
    print(io, "\n")
  else
    show(io, "text/plain", md)
  end
end


function show(io::IO, ::MIME"text/html", md::Markdown.LaTeX)
  ## Hack, we use $$~ ~$$ to mark these up, so if we see ~..~ wrapping
  ## we add in ...
  txt = md.formula
  if ismatch(r"^~.*", txt)
    print(io, "\n")
    show(io, "text/latex", L"$$")
    show(io, "text/latex",  txt[2:(end-1)])
    show(io, "text/latex", L"$$")
    print(io, "\n")
  else
    show(io, "text/plain", md)
  end
end


function show{T <: AbstractString}(io::IO, ::MIME"text/latex", md::T)
   print(io, md)
end

function Base.show(io::IO, ::MIME"text/latex", x::Alert)
print(io, "XXX")
end
