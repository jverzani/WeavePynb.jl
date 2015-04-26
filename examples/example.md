# header 1

This is a sample for using `WeavePynb`.

## Typography

Some of this should work: **bold**, *emphasize*, *italicize* (_underscores_ are not parsed)

As should some LaTeX: $\sin(x^2)$

$$
\sin^2(x)+ \cos^2(x) = 1
$$

Itemize:

* one
* two
* three

> what does quoting
> do?

four space indent does not do work

For html only display, some bootstrap/HTML stuff can be used, but how will this render in LaTeX?

<div class="alert">
  <button type="button" class="close" data-dismiss="alert">&times;</button>
  <strong>Warning!</strong> Best check yo self, you're not looking too good.
</div>

## Julia code

Code blocks should render inline. The last expression evaluated is displayed. There is no support for side effects, such as printing.

```
2 + 2
```

```
sin(1:10)
```

```
using SymPy
x,y,a,b,c = symbols("x,y,a,b,c", real=true)
x^2
```

### Graphics

Graphics embed as figures

```
using Winston
Winston.plot(sin, 0, 2pi)
```

Using `Gadfly` is similar. Using `PyPlot` requires a final call of `gcf()`, so that a `Figure` is returned. (This is not necessary for 3D graphics.)

### Questions

There is support for questions

What is one?

```
radioq([L"\alpha", "**a**", "1"], 3, hint="The number, not the letters")
```

Approximation for $\pi$:

```
numericq(3.14, 1e-2)
```


True of false: I like this:

```
booleanq(true)
```

For latex code there is support for

* short questions that are "graded" by a regular expression:</br>

Spell the character $\alpha$:

```
shortq("alpha", "spell greek letter")
```


* long questions<br/>

Expound on the meaning of life

```
longq("The meaning of life", "Some answer propmpt")
```
