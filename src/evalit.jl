## From Juno

import Base: start, next, done

# An iterator for the parse function: parsit(source) will iterate over the
# expressiosn in a string.
type ParseIt
    value::String
end


function parseit(value::String)
    ParseIt(value)
end


function start(it::ParseIt)
    1
end


function next(it::ParseIt, pos)
    (ex,newpos) = Base.parse(it.value, pos)
    ((it.value[pos:(newpos-1)], ex), newpos)
end


function done(it::ParseIt, pos)
    pos > length(it.value)
end


# A special dummy module in which a documents code is executed.
module WeaveSandbox
end

"""

Make a module of a given name.

"""
function make_module(nm=randstring())
    nm = "Z"*uppercase(nm)
    eval(parse("module " * nm * " end"))
    eval(parse(nm))
end

type DisplayError
    x
end
Base.writemime(io::IO, ::MIME"text/plain", e::DisplayError) = println(io, e.x)


# Evaluate an expression and return its result and a string.
function safeeval(m, ex::Union(Number,Symbol, Expr))
    try
        eval(m, ex)
    catch e
        print_with_color(:red, "Error with evaluating $ex: $(string(e))\n")
        DisplayError(string(e))
    end
end

function process_block(text, m = WeaveSandbox)
    result = ""
    for (cmd, ex) in parseit(strip(text))
        result = safeeval(m, ex)
    end
    result
end
