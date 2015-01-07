nimage: pure-Nim image decoding
===

`nimage` is an attempt to provide a nice, Nim-ish API over the process of
encoding and decoding images. Right now, as far as I can tell, the only real
image decoding and encoding available for Nim are wrappers around C libraries
that are notorious for being difficult to use (looking at you, libpng). To that
end, this seeks to provide a nice API that takes advantage of Nim's sugary
goodness for image loading and saving.

Current status
---

### Decoding

`nimage` can currently read PNG images from streams. It only implements the
handling of critical chunks, which means that all ancillary chunks (containing
colorspace data, metadata, etc.) are lost in loading. Only PNG images with 8-bit
color depth are supported; in practice, this is most PNG images, but there are a
non-negligable number of PNG images that `nimage` just can't import right now.

### Encoding

`nimage` can currently write 8-bit RGBA PNG images. It doesn't support
interlacing, predictive filtering or paletting.

To see what's coming up, check out the [Github issues][0] for this project.

License
---
`nimage` is provided under the new-BSD three-clause license. The text of this
license is included in [LICENSE][1] as well as at the top of every source
file.

Contributing
---
Contributions via pull request are much appreciated! I especially would like
help with things marked `help-wanted` in the [issues][0].

[0]: http://github.com/haldean/nimage/issues
[1]: https://github.com/haldean/nimage/blob/master/LICENSE
