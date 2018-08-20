## From Juno

import Base: iterate

# An iterator for the parse function: parsit(source) will iterate over the
# expressiosn in a string.
mutable struct ParseIt
    value::AbstractString
end


function parseit(value::AbstractString)
    ParseIt(value)
end

function Base.iterate(it::ParseIt)
    pos = 1
    iterate(it, pos)
#    (ex,newpos) = Meta.parse(it.value, 1)
#    ((it.value[1:(newpos-1)], ex), newpos)
end
   
function Base.iterate(it::ParseIt, pos)
    if pos > length(it.value)
        nothing
    else
        (ex,newpos) = Meta.parse(it.value, pos)
        ((it.value[pos:(newpos-1)], ex), newpos)
    end
end

# function start(it::ParseIt)
#     1
# end


# function next(it::ParseIt, pos)
#     (ex,newpos) = Meta.parse(it.value, pos)
#     ((it.value[pos:(newpos-1)], ex), newpos)
# end


# function done(it::ParseIt, pos)
#     pos > length(it.value)
# end


# A special dummy module in which a documents code is executed.
module WeaveSandbox
end

"""

Make a module of a given name.

"""
function make_module(nm=randstring())
    nm = "Z"*uppercase(nm)
    eval(Meta.parse("module " * nm * " end"))
    eval(Meta.parse(nm))
end

struct DisplayError
    x
end
Base.show(io::IO, ::MIME"text/plain", e::DisplayError) = println(io, e.x)

# Evaluate an expression and return its result and a string.
safeeval(m, ex::Nothing) = nothing
function safeeval(m, ex::Union{Number,Symbol, Expr})
    try
        res = Core.eval(m, ex)

        
    catch e
        printstyled("Error with evaluating $ex: $(string(e))\n", color=:red)
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
