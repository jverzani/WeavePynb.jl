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
    sprint(io -> writemime(io, m, img))
end

# Display infrastructure


function bestmime(val)
  for mime in ("text/html",  "text/latex", "application/x-latex", "image/svg+xml", "image/png", "text/plain")
    mimewritable(mime, val) && return MIME(symbol(mime))
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

writemime(io::IO, ::MIME"text/latex", md::Markdown.Content) =
  writemime(io, "text/plain", md)

function writemime(io::IO, mime::MIME"text/latex", block::Markdown.Block)
  for md in block.content[1:end-1]
    writemime(io::IO, mime, md)
    println(io)
  end
  writemime(io::IO, mime, block.content[end])
end

function writemime{l}(io::IO, mime::MIME"text/latex", header::Markdown.Header{l})
    if l == 1 
        print(io, "\\section{$(header.text)}")
    end
    if l == 2
        print(io, "\\subsection{$(header.text)}")
    end
    if l > 2
        print(io, "\\subsubsection{$(header.text)}")
    end
end

function writemime(io::IO, ::MIME"text/latex", code::Markdown.BlockCode)
    with_delimiter(io, "verbatim") do
        print(io, code.code)
    end
end

function writemime(io::IO, ::MIME"text/latex", code::Markdown.InlineCode)
    print(io, "\\textt{$(code.code)}")
end

function writemime(io::IO, ::MIME"text/latex", md::Markdown.Paragraph)
    println(io, "\\newline")
    for md in md.content
      writemime(io, "text/latex", md)
    end
end

function writemime(io::IO, ::MIME"text/latex", md::Markdown.BlockQuote)
  with_environment(io, "quotation") do
    writemime(io, "text/latex", Markdown.Block(md.content))
  end
end

function writemime(io::IO, ::MIME"text/latex", md::Markdown.List)
    with_environment(io, md.ordered ? "enumerate" : "itemize") do
    for item in md.content
        print(io, "\\item ")
        writemime(io, "text/latex", item)
    end
  end
end

# Inline elements

function writemime(io::IO, ::MIME"text/latex", md::Markdown.Plain)
  print(io, md.text)
end

function writemime(io::IO, ::MIME"text/latex", md::Markdown.Bold)
    print(io, "\\textbf{$(md.text)}")
end

function writemime(io::IO, ::MIME"text/latex", md::Markdown.Italic)
    print(io, "\\textit{$(md.text)}")
end

function writemime(io::IO, ::MIME"text/latex", md::Markdown.Image)
  print(io, """<img src="$(md.url)" alt="$(md.alt)"></img>""")
end

function writemime(io::IO, ::MIME"text/latex", md::Markdown.Link)
    print(io, "\\url{$(md.url)}{$(md.text)}")
end

