type ImageFile
    f
    caption
end
ImageFile(f) = ImageFile(f, "")

"""

Take an image file and encode it
"""

gif_to_data_tpl = """
<div class="well well-sm">
  <figure>
    <img src="data:image/gif;base64, {{{:data}}}"/>
    <figcaption>{{{:caption}}}</figcaption>
  </figure>
</div>

"""

function gif_to_data(imgfile::AbstractString, caption="")
    data = base64encode(readall(imgfile))
    Mustache.render(gif_to_data_tpl, data=data, caption=md(caption))
end

function gif_to_data(img, caption="")
    imgfile = tempname() * ".gif"
    io = open(imgfile, "w")
    writemime(io, "image/png", img)
    close(io)
    gif_to_data(imgfile, caption)
end
