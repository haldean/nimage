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

import filter
import math
import nimage
import stream
import unsigned
import zlib

type
    ColorType = enum
        gray = 0
        rgb = 2
        palette = 3
        graya = 4
        rgba = 6
    PngImage = object of Image
        depth: uint8
        colorType: ColorType
        interlaced: uint8
        palette: array[0..255, NColor]

proc `$`(x: PngImage): string =
    return ("(img w " & $x.width & " h " & $x.height & " depth " & $x.depth &
            " colorType " & $x.colorType & ")")

const
    PNG_HEADER = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    DEBUG = false

proc zuncompress(data: seq[uint8]): string =
    let size = len(data)
    var zdata_str = newString(size)
    for i in 0..size-1:
        zdata_str[i] = char(data[i])
    let zdata = cstring(zdata_str)
    for mul in 2..6:
        # Need to use var for the size guess so we can take its address
        var
            unzip_size_guess = (1 shl mul) * size
            uncompressed_str = newString(unzip_size_guess)
        # Warning! You can't use len(zdata) here, because the string can have null
        # bytes inside which cause an incorrect string length calculation.
        let res = zlib.uncompress(
            uncompressed_str,
            addr unzip_size_guess,
            zdata,
            size)
        if res == zlib.Z_OK:
            uncompressed_str.setLen(unzip_size_guess)
            return uncompressed_str
        if res != zlib.Z_BUF_ERROR:
            raise newException(ValueError, "zlib returned error " & $res)
    raise newException(ValueError, "decompress too large; grew by more than 64x")

proc itostr(val: int32): string {.inline.} =
    ## Converts an integer to a four-character string, assuming each octet in
    ## the integer is a valid ASCII char.
    var result = ""
    for i in 0..3:
        result.add(char((val shr (8 * (3 - i))) and 0xFF))
    return result

template ifromstr(s: string): int32 =
    ## Gets the integer representation of a 4-character string. This does the
    ## safe-ish equivalent of "*((int*)(c_str))" in C. This does not check the
    ## bounds on its inputs!
    (int32(s[0]) shl 24 or int32(s[1]) shl 16 or
     int32(s[2]) shl  8 or int32(s[3]))

proc load_ihdr(img: ptr PngImage, chunkData: seq[uint8]) =
    var buf = newByteStream(chunkData)
    img.width = buf.readInt32
    img.height = buf.readInt32
    img.depth = buf.read
    img.colorType = ColorType(buf.read)
    let
        compression = buf.read
        filter = buf.read
    img.interlaced = buf.read
    if compression != 0:
        raise newException(ValueError, "unknown compression type " & $compression)
    if filter != 0:
        raise newException(ValueError, "unknown filter type " & $filter)
    if img.interlaced != 0:
        raise newException(ValueError, "unsupported interlace type " & $img.interlaced)
    if img.depth != 8:
        raise newException(ValueError, "unsupported color depth " & $img.depth)

## Returns the bytes per pixel for the given image
proc bpp(img: PngImage): int =
    let d = int(int(img.depth) / 8)
    # We only support multiple-of-8 image depths
    assert(d * 8 == int(img.depth))
    case img.colorType
    of gray:    return d
    of rgb:     return 3 * d
    of palette: return d
    of graya:   return 2 * d
    of rgba:    return 4 * d
proc bpp(img: ptr PngImage): int = bpp(img[])

proc read_gray(stream: var Stream): NColor =
    let g = uint32(stream.read)
    return NColor(0xFF000000'u32 or (uint32(g) shl 16) or (uint32(g) shl 8) or g)

proc read_rgb(stream: var Stream): NColor =
    let r = uint32(stream.read)
    let g = uint32(stream.read)
    let b = uint32(stream.read)
    return NColor(0xFF000000'u32 or (uint32(r) shl 16) or (uint32(g) shl 8) or b)

proc read_palette(stream: var Stream, img: ptr PngImage): NColor =
    return img.palette[stream.read]

proc load_idat(img: ptr PngImage, chunkData: seq[uint8]) =
    let uncompressed = zuncompress(chunkData)
    when DEBUG: echo("  decompressed to " & $len(uncompressed) & " bytes")
    let scanlines = int(len(uncompressed) / (img.width * img.bpp + 1))
    assert(scanlines * (img.width * img.bpp + 1) == len(uncompressed))
    var r, c: int
    var buf = newStringStream(uncompressed)
    if img.data.isNil:
        img.data = newSeq[NColor](scanlines * img.width)
    else:
        img.data.setLen(img.data.len + (scanlines * img.width))
    var last_scanline: seq[uint8]
    while r < scanlines:
        let filter = Filter(buf.read)
        # read the scanline so we can unapply filters before reading colors
        var scanline = newSeq[uint8](img.width * img.bpp)
        for i in 0..img.width * img.bpp - 1:
            scanline[i] = buf.read
        filter.unapply(img.bpp, scanline, last_scanline)
        var scanBuf = newByteStream(scanline)
        while c < img.width:
            var color: NColor
            case img.colorType
            of gray:
                color = scanBuf.read_gray()
            of rgb:
                color = scanBuf.read_rgb()
            of palette:
                color = scanBuf.read_palette(img)
            else:
                raise newException(ValueError, "can't decode color type " & $img.colorType)
            img[][r, c] = color
            c += 1
        last_scanline = scanline
        r += 1

proc load_plte(img: ptr PngImage, chunkData: seq[uint8]): int =
    let colors = int(chunkData.len / 3)
    assert(colors * 3 == chunkData.len)
    var buf = newByteStream(chunkData)
    for i in img.palette.low..img.palette.high:
        if buf.more:
            img.palette[i] = read_rgb(buf)
        else:
            img.palette[i] = NColor(0)
    return colors

proc load_png*(buf: var Stream): Image =
    var result: PngImage
    for i in 0..len(PNG_HEADER) - 1:
        if not buf.more:
            raise newException(
                ValueError, "file too short; only " & $i & " bytes long")
        var fheader = buf.read
        if uint8(PNG_HEADER[i]) != fheader:
            raise newException(
                ValueError,
                "header bytes did not match at position " & $i &
                " header: " & $PNG_HEADER[i] & " file: " & $fheader)
    var idats = newSeq[seq[uint8]]()
    var lastType = 0
    while buf.more:
        let
            chunkLen = buf.readInt32
            chunkType = buf.readInt32
            chunkData = buf.read(chunkLen)
            crc = buf.readInt32
        when DEBUG:
            if chunkType != lastType:
                echo("chunk type " & itostr(chunkType) & " len " & $chunkLen)
                lastType = chunkType
        case chunkType
        of ifromstr("IHDR"):
            load_ihdr(addr(result), chunkData)
            when DEBUG: echo("  after ihdr: " & $result)
        of ifromstr("PLTE"):
            let colors = load_plte(addr(result), chunkData)
            when DEBUG: echo("  color count: " & $colors)
        of ifromstr("IDAT"):
            idats.add(chunkData)
        of ifromstr("IEND"):
            discard
        else:
            when DEBUG: echo("unknown chunk type " & itostr(chunkType))
    var idat_len = 0
    for i, v in idats:
        idat_len += v.len
    var idat = newSeq[uint8](idat_len)
    var last_i = 0
    for i, v in idats:
        copyMem(addr(idat[last_i]), addr(idats[i][0]), v.len)
        last_i += v.len
    load_idat(addr(result), idat)
    when DEBUG:
        echo("loaded image " & $result)
    return result
