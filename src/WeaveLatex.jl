

## turn jmd file into latex
function markdownToLaTex(fname::String)
    dirnm, basenm = dirname(fname), basename(fname)
    newnm = replace(fname, r"[.].*", ".tex")
    out = mdToLatex(readall(fname))

    io = open(newnm, "w")
    write(io, out)
    close(io)
end
  

## Main function to take a jmd file and turn into a ipynb file
function markdownToPynb(fname::String;tidy::Bool=true)
    dirnm, basenm = dirname(fname), basename(fname)
    newnm = replace(fname, r"[.].*", ".ipynb")
    out = mdToPynb(readall(fname))
    
    io = open(newnm, "w")
    write(io, out)
    close(io)
    tidy && tidyipynb(newnm)
end
      

import Base.parse


# A special module in which a documents code is executed.
module WeaveSandbox
   ## inject some functions
   using Mustache

numericq_tpl = """
\\begin{answer}
    type: numeric
    reminder: {{{reminder}}}
    answer: [{{m}}, {{M}}]
{{#answer_text}}answer_text: {{{answer_text}}} {{/answer_text}}
\\end{answer}
"""

radioq_tpl = """
\\begin{answer}
type: radio
reminder: {{{reminder}}}
values: {{{values}}}
labels: {{{labels}}}
answer: {{{answer}}}
\\end{answer}
"""


multiq_tpl = """
\\begin{answer}
type: checkbox
reminder: {{{reminder}}}
values: {{{values}}}
labels: {{{labels}}}
answer: {{{answer}}}
\\end{answer}
"""


shortq_tpl = """
\\begin{answer}
type: shorttext
reminder: {{{reminder}}}
answer: {{{answer}}}
{{#answer_text}}answer_text: {{{answer_text}}} {{/answer_text}}
\\end{answer}
"""

longq_tpl = """
\\begin{answer}
type: longtext
reminder: {{{reminder}}}
{{#answer_text}}answer_text: {{{answer_text}}} {{/answer_text}}
rows: {{{rows}}}
cols: {{{cols}}}
\\end{answer}
"""

function numericq(val, tol=1e-3, reminder="", answer_text=nothing)
   Mustache.render(numericq_tpl, {"reminder"=>reminder,
                                  "answer_text"=>answer_text,
                                  "m"=>val-tol,
                                  "M"=>val+tol
                                  })
end


function radioq(choices, answer, reminder="", answer_text=nothing)
   Mustache.render(radioq_tpl, {"reminder"=>reminder,
                                  "answer_text"=>answer_text,
                                  "values" => join(1:length(choices), " | "),
                                  "labels" => join(choices, " | "),
                                  "answer" => answer
                                  })
end
booleanq(ans::Bool, reminder="", answer_text=nothing) = radioq(["True", "False"], 2 - int(ans), reminder, answer_text)

## multi choice
function multiq(choices, answer, reminder="", answer_text=nothing)
   Mustache.render(multiq_tpl, {"reminder"=>reminder,
                                  "answer_text"=>answer_text,
                                  "values" => join(1:length(choices), " | "),
                                  "labels" => join(choices, " | "),
                                  "answer" => join(answer, " | ")
                                  })
end

function shortq(answer, reminder="", answer_text=nothing)
     Mustache.render(shortq_tpl, {"reminder"=>reminder,
                                  "answer_text"=>answer_text,
                                  "answer" => answer
                                  })
end

function longq(reminder="", answer_text=nothing;rows=3,cols=60)
     Mustache.render(longq_tpl, {"reminder"=>reminder,
                                  "answer_text"=>answer_text,
                                 "rows" => rows,
                                 "cols" => cols
                                  })
end


    # Output
    MIME_OUTPUT = Array(Tuple, 0)
    emit(mime, data) = push!(MIME_OUTPUT, (mime, data))
end

# An iterator for the parse function: parsit(source) will iterate over the
# expressiosn in a string.
type ParseIt
    value::String
end

## iterate over (cmd, expr)
parseit(value::String) = ParseIt(value)

import Base: start, next, done
start(it::ParseIt) = 1
function next(it::ParseIt, pos)
    (ex,newpos) = Base.parse(it.value, pos)
    ((it.value[pos:(newpos-1)], ex), newpos)
end
done(it::ParseIt, pos) = pos > length(it.value)


# Execute a block of julia code, capturing its output.
function execblock_julia(source)
    out = Any[]

    for (cmd, expr) in parseit(strip(source))
        result = try 
            eval(WeaveSandbox, expr) 
        catch e
            println("Error with $cmd")
        end
        push!(out, (cmd, expr, result))
    end
    

    if length(WeaveSandbox.MIME_OUTPUT) > 0
        mime, output = pop!(WeaveSandbox.MIME_OUTPUT)
        mime, convert(Vector{Uint8}, output), out
    end

    out #[(txt, expr, output)]
end



function mdToLatex(infn::String)
    metadata, document = JSON.parse(pandoc(infn, :markdown, :json))

    buf = IOBuffer()
    println(buf, """
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
""")
 
    for block in document
        cell = Dict()
        cell["metadata"] = Dict()

        if isa(block, Dict) && haskey(block, "CodeBlock")
            if length(block["CodeBlock"][1][2]) > 0 && block["CodeBlock"][1][2][1] == "julia"
                input = block["CodeBlock"][2]
                println("\nProcessing: $input")
                out = execblock_julia(input)
                input = out[end][3]
                println(buf, input)
            else
                input = block["CodeBlock"][2]
                if length(input) > 0
                    println(buf, "\n")
                    println(buf, "\\begin{verbatim}")
                    println(buf, input)
                    println(buf, "\\end{verbatim}")
                end
            end
        else
            processed_document = [block]
            jsonout_path, jsonout = mktemp()
            JSON.print(jsonout, {metadata, processed_document})
            flush(jsonout)
            close(jsonout)
            output = pandoc(readall(jsonout_path), :json, :latex)
            rm(jsonout_path)
            println(buf, output)
        end
    end
    
     println(buf,"""
\\end{document}
""")
 
    takebuf_string(buf)
   
end
