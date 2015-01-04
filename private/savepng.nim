# Copyright (c) 2015, Haldean Brown
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# * Neither the name of nimage nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import image
import streams
import strfmt
import unsigned

import private/filter
import private/png
import private/zutil

proc to_png(img: Image): ref PngImage =
    new(result)
    result.width = img.width
    result.height = img.height
    result.data = img.data
    result.depth = 8
    result.colorType = rgba
    result.interlaced = 0

proc write_header(buf: Stream) =
    for v in PNG_HEADER:
        buf.write(uint8(v))

proc write_chunk(buf: Stream; chunktype: string; chunk: string) =
    buf.write(int32(chunk.len))
    buf.write(chunktype)
    buf.write(chunk)
    buf.write(zcrc(chunk))

proc write_IHDR(buf: Stream, img: ref PngImage) =
    var chunk = newStringStream()
    chunk.write(int32(img.width))
    chunk.write(int32(img.height))
    chunk.write(img.depth)
    chunk.write(uint8(img.colorType))
    chunk.write(0'u8) # zlib compression
    chunk.write(0'u8) # default filter
    chunk.write(0'u8) # not interlaced
    buf.write_chunk("IHDR", chunk.data)

proc write_IDAT(buf: Stream, img: ref PngImage) =
    var chunk = newStringStream()
    if img.bpp != 4:
        raise newException(ValueError, "only 4 BPP images are supported")
    let sl_len = img.width * img.bpp
    var last_scanline: seq[uint8]
    for r in 0..img.height-1:
        var scanline = newSeq[uint8](sl_len + 1)
        scanline[0] = uint8(Filter.none)
        copyMem(addr(scanline[1]), addr(img.data[img.width * r]), sl_len)
        let filtered = filter.apply(img.bpp, scanline, last_scanline)
        last_scanline = scanline
        chunk.writeData(addr(scanline[0]), len(scanline))
    var compressed = zcompress(chunk.data)
    buf.write_chunk("IDAT", compressed)

proc write_IEND(buf: Stream) =
    buf.write_chunk("IEND", "")

proc save_png*(img: Image, buf: Stream) =
    var img = to_png(img)
    buf.write_header()
    buf.write_IHDR(img)
    buf.write_IDAT(img)
    buf.write_IEND()
