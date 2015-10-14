"""
This tries to add questions to the markdown files

The rendering of the questions depends on the output:

* html: make self-grading questions using JavaScript
* latex: hide the questions
* ipynb: hide the questions
* questions: use idiosyncratic dcf-style markup for questions

"""
nothing

using Mustache, LaTeXStrings
import Base: writemime

abstract Question


MaybeString = Union{ASCIIString, AbstractString, Void}

type Numericq <: Question
    val::Real
    tol::Real
    reminder
    answer_text::MaybeString
    m::Real
    M::Real
    units
    hint
end

type Radioq <: Question
    choices::Vector
    answer::Int
    reminder::AbstractString
    answer_text::MaybeString
    values
    labels
    hint
    inline::Bool
    
end


type Multiq <: Question
    choices::Vector
    answer::Vector{Int}
    reminder::AbstractString
    answer_text::MaybeString
    values
    labels
    answers
    hint
    inline::Bool
end

type Shortq <: Question
    answer
    reminder::AbstractString
    answer_text::MaybeString
    hint
end

type Longq <: Question
    reminder::AbstractString
    answer_text::MaybeString
    hint
    rows::Int
    cols::Int
end

"""
A numeric question graded with a tolerance

Arguments:
* `val::Real` answer
* `tol::Real` tolerance. Answer is right if `|ans - val| <= tol`
* `reminder` a reminder as to what question is, student may see
* `answer_text`: reminder of what answer is, student does not see
* `hint`: a possible hint for the student
* `units`: a string holding the units, if specified.

Returns an object of type `Question`.
"""
function numericq(val, tol=1e-3, reminder="", args...; hint::AbstractString="", units::AbstractString="")
    answer_text= "[$(round(val-tol,3)), $(round(val+tol,3))]"
    Numericq(val, tol, reminder, answer_text, val-tol, val+tol, units, hint)
end

numericq(val::Int; kwargs...) = numericq(val, 0; kwargs...)
"""
Multiple choice question

Arguments:
* `choices`: vector of choices. 
* `answer`: index of correct choice
* `inline::Bool`: hint to render inline (or not) if supported

Example
```
radioq(["beta", L"\beta", "`beta`"], 2, hint="which is the Greek symbol")
```
"""
function radioq(choices, answer, reminder="", answer_text=nothing;  hint::AbstractString="", inline::Bool=(hint!=""),
                keep_order::Bool=false)
    values = join(1:length(choices), " | ")
    labels = map(markdown_to_latex,choices) |> x -> map(chomp, x) |> x -> join(x, " | ")
    ind = collect(1:length(choices))
    !keep_order && shuffle!(ind)
    
    Radioq(choices[ind], findfirst(ind, answer), reminder, answer_text, values[ind], labels[ind], hint, inline)
end

"""
True of false questions

"""
function booleanq(ans::Bool, reminder="", answer_text=nothing;labels::Vector=["true", "false"], hint::AbstractString="", inline::Bool=true) 
    choices = labels[1:2]
    ans = 2 - ans
    radioq(choices, ans, reminder, answer_text; hint=hint, inline=inline, keep_order=true)
end

"""

`yesnoq("yes")` or `yesnoq(true)`

"""
yesnoq(ans::AbstractString) = radioq(["Yes", "No"], ans == "yes" ? 1 : 2, keep_order=true)
yesnoq(ans::Bool) = yesnoq(ans ? "yes" : "no")

function multiq(choices, answer, reminder="", answer_text=nothing; hint::AbstractString="", inline::Bool=false)
    values = join(1:length, " | ")
    labels =  map(markdown_to_latex, choices) |> x -> map(chomp, x) |> x -> join(x, " | ")
    answers = join(answer, " | ")
    Multiq(choices, answer, reminder, answer_text,
           values, labels, answers,
           hint,
           inline
           )
end

function shortq(answer, reminder="", answer_text=nothing;hint::AbstractString="")   
    Shortq(answer, reminder, answer_text, hint)
end

function longq(reminder="", answer_text=nothing;hint::AbstractString="", rows=3, cols=60)    
    Longq(reminder, answer_text, hint, rows, cols)
end


export numericq, radioq, booleanq, yesnoq, shortq, longq, multiq



## we have different display mechanisms based on the output type

## application/x-latex
latex_templates=Dict()

latex_templates["Numericq"] = mt"""
\\begin{answer}
    type: numeric
    reminder: {{{reminder}}}
    answer: [{{m}}, {{M}}]
    {{#answer_text}}answer_text: {{{answer_text}}} {{/answer_text}}
\\end{answer}
"""

latex_templates["Radioq"] = mt"""
\\begin{answer}
type: radio
reminder: {{{reminder}}}
values: {{{values}}}
labels: {{{labels}}}
answer: {{{answer}}}
{{#answer_text}}answer_text: {{{answer_text}}} {{/answer_text}}
\\end{answer}
"""


latex_templates["Multiq"] = mt"""
\\begin{answer}
type: checkbox
reminder: {{{reminder}}}
values: {{{values}}}
labels: {{{labels}}}
answer: {{{answer}}}
{{#answer_text}}answer_text: {{{answer_text}}} {{/answer_text}}
\\end{answer}
"""


latex_templates["Shortq"] =  mt"""
\\begin{answer}
type: shorttext
reminder: {{{reminder}}}
answer: {{{answer}}}
{{#answer_text}}answer_text: {{{answer_text}}} {{/answer_text}}
\\end{answer}
"""

latex_templates["Longq"] = mt"""
\\begin{answer}
type: longtext
reminder: {{{reminder}}}
{{#answer_text}}answer_text: {{{answer_text}}} {{/answer_text}}
rows: {{{rows}}}
cols: {{{cols}}}
\\end{answer}
"""

function writemime(io::IO, m::MIME"application/x-latexq", x::Question)
    Mustache.render(io, latex_templates[string(typeof(x))],x)
end




## text/html
html_templates=Dict()


html_templates["Numericq"] = mt"""
<form name='WeaveQuestion' data-id='{{ID}}' data-controltype='{{TYPE}}'>
<div class='form-group {{status}}'>
<div class='controls'>
{{{form}}}
{{#hint}}
<span class='help-inline'><i id='{{ID}}_hint' class='icon-gift'></i></span>
<script>$('#{{ID}}_hint').tooltip({title:'{{{hint}}}', html:true, placement:'right'});</script>
{{/hint}}

<div class="input-group">
<input id="{{ID}}" type="number" class="form-control">
{{#units}}<span class="input-group-addon">{{{units}}}</span>{{/units}}
</div>
  
<div id='{{ID}}_message'></div>
</div>
</div>
</form>
<script text='text/javascript'>
$('{{{selector}}}').on('change', function() {
  correct = {{{correct}}};

  if(correct) {
     $('#{{ID}}_message').html('<div class="alert alert-success"><span class="glyphicon glyphicon-thumbs-up">&nbsp;Correct</span></div>');
  } else {
     $('#{{ID}}_message').html('<div class="alert alert-danger"><span class="glyphicon glyphicon-thumbs-down">&nbsp;Incorrect</span></div>');
  }
});
</script>
"""

function writemime(io::IO, m::MIME"text/html", x::Numericq)
    d = Dict()
    d["ID"] = randstring()
    d["TYPE"] = "numeric"
    d["selector"] = "#" * d["ID"]
    d["status"] = ""
    d["hint"] = ""# x.hint
    d["units"] = x.units
    d["correct"] = "Math.abs(this.value - $(x.val)) <= $(x.tol)"
    println(d)
    out =  Mustache.render(html_templates["Numericq"], d)
    println(out)
    Mustache.render(io, html_templates["Numericq"], d)
end


html_templates["Radioq"] = mt"""
{{#items}}
<div class="radio">
<label class='radio{{inline}}'>
  <input type='radio' name='radio_{{ID}}' value='{{value}}'>
  {{{label}}}
</label>
</div>
{{/items}}

"""

html_templates["question_tpl"] = mt"""
<form name="WeaveQuestion" data-id="{{ID}}" data-controltype="{{TYPE}}">
<div class="form-group {{status}}">
{{{form}}}
{{#hint}}
<span class="help-inline"><span id="{{ID}}_hint" class="glyphicon glyphicon-gift"></span></span>
<script>$("#{{ID}}_hint").tooltip({title:"{{{hint}}}", html:true, placement:"right"});</script>
{{/hint}}
<div id="{{ID}}_message"></div>
</div>
</form>
<script text="text/javascript">
{{{script}}}
</script>
"""


html_templates["script_tpl"] = mt"""
$("{{{selector}}}").on("change", function() {
  correct = {{{correct}}};

  if(correct) {
     $("#{{ID}}_message").html("<div class='alert alert-success'><span class='glyphicon glyphicon-thumbs-up'>&nbsp;Correct</span></div>");
  } else {
     $("#{{ID}}_message").html("<div class='alert alert-warning'><span class='glyphicon glyphicon-thumbs-down'>&nbsp;Incorrect</span></div>");
  }
});
"""


function markdown(x)
    length(x) == 0 && return("")
    x = Markdown.parse(x)
    x = sprint(io -> WeavePynb.tohtml(io, x))
    x[4:end-4]                  # strip out <p></p>
end


function writemime(io::IO, m::MIME"text/html", x::Radioq)
    ID = randstring()

    tpl = mt"""
    {{#items}}
    <div   class="radio{{inline}}"> 
    <label>
      <input type="radio" name="radio_{{ID}}" value="{{value}}">{{{label}}}
    </label>
    </div>
    {{/items}}
"""


choices = map(string, x.choices)
println(x.choices)
println(choices)
    items = Dict[]
    ## make items
    for i in 1:length(choices)
        item = Dict("no"=>i,
                "label"=>markdown(choices[i]), 
                "value"=>i
                )
        push!(items, item)
    end

    script = Mustache.render(html_templates["script_tpl"],
                             Dict("ID"=>ID, 
                              "selector"=>"input:radio[name='radio_$ID']",
                              "correct"=>"this.value == $(x.answer)"))
    
    form = Mustache.render(tpl, Dict("ID"=>ID, "items"=>items,
                                 "inline" => x.inline ? " inline" : ""
                                 ))

    Mustache.render(io, html_templates["question_tpl"],
    Dict("form"=>form, "script"=>script, 
         "TYPE"=>"radio",
         "ID"=>ID, "hint"=>markdown(x.hint)))

end




function writemime(io::IO, m::MIME"text/html", x::Question)
     println(io, "Question type $(typeof(x)) is not supported in this format")
end


