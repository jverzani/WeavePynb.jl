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


# Evaluate an expression and return its result and a string.
function safeeval(ex::Union(Symbol, Expr))
    try
        eval(WeaveSandbox, ex)
    catch e
        println("Error with evaluating $ex: $(string(e))")
    end
end

function process_block(text)
    result = ""
    for (cmd, ex) in parseit(strip(text))
        result = safeeval(ex)
    end
    result
end
