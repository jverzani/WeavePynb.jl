# WeavePynb

[![Build Status](https://travis-ci.org/jverzani/WeavePynb.jl.png)](https://travis-ci.org/jverzani/WeavePynb.jl)


Simple package to convert markdown files to IJulia notebooks. The main
function is `markdownToPynb(file_name::String)` which writes to
`file_name.ipynb` a notebook with unevaluated cells.

This package needs the `pandoc` program to be installed.
