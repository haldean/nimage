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

from private/image import nil

export image.Image, image.`[]`, image.`[]=`, image.create_image
export image.NColor, image.`==`, image.`$`

from private/png import nil

export png.ColorType

from private/loadpng import nil

export loadpng.load_png

from private/savepng import nil

export savepng.save_png, savepng.PngEncoderOpts, savepng.new_opts, savepng.default_opts

##[
Types
---------

.. code-block:: nimrod
  NColor* = distinct uint32

A color in RGBA format, 8 bits per sample. For example, 50% red, 100%
green, 0% blue, 100% alpha would be `NColor(0x80FF00FF)`.

.. code-block:: nimrod
  ImageObj* = object of RootObj
      width*: int
      height*: int
      data*: seq[NColor] # Data is stored in row-major format
  Image* = ref ImageObj

.. code-block:: nimrod  
  ColorType* = enum
    gray = 0
    rgb = 2
    palette = 3
    graya = 4
    rgba = 6

.. code-block:: nimrod
  PngEncoderOpts* = object
          colorType: ColorType

Procs
-----

.. code-block:: nimrod
  proc `[]`*(img: Image; row, col: int): NColor =
    return img.data[img.get_index(row, col)]

.. code-block:: nimrod
  proc `[]=`*(img: Image; row, col: int; val: NColor) =
    img.data[img.get_index(row, col)] = val

.. code-block:: nimrod
  proc create_image*(width, height: int): Image =
    let data = newSeq[NColor](width * height)
    return Image(width: width, height: height, data: data)

.. code-block:: nimrod
  proc `$`*(color: NColor): string =
    return fmt("{:08X}", uint32(color))

.. code-block:: nimrod
  proc `==`*(c1, c2: NColor): bool =
    return uint32(c1) == uint32(c2)

.. code-block:: nimrod
  proc default_opts*(): PngEncoderOpts =
    return PngEncoderOpts(colorType: rgba)

.. code-block:: nimrod
  proc new_opts*(colorType: ColorType): PngEncoderOpts =
    return PngEncoderOpts(colorType: colorType)
Create an encoder options struct for a given color type. Note that for
grayscale color types, the value in the red channel is taken as the
gray value; green and blue channels are ignored, and the alpha channel is
ignored for gray (but not graya).

.. code-block:: nimrod
  proc save_png*(img: Image, buf: Stream, opts: PngEncoderOpts) =
    let img = to_png(img, opts)
    buf.write_header()
    buf.write_IHDR(img)
    buf.write_IDAT(img)
    buf.write_IEND()

.. code-block:: nimrod
  proc save_png*(img: Image, buf: Stream) =
    save_png(img, buf, default_opts())

.. code-block:: nimrod
  proc load_png*(buf: Stream): Image =
    var result: PngImage
    new(result)
    if( buf==nil):echo "Nilbuffer"
    for i in 0..len(PNG_HEADER) - 1:
      if buf.atEnd:
        raise newException(
          ValueError, "file too short; only " & $i & " bytes long")
      var fheader = buf.readUint8
      if uint8(PNG_HEADER[i]) != fheader:
        raise newException(
          ValueError,
          "header bytes did not match at position " & $i &
          " header: " & $PNG_HEADER[i] & " file: " & $fheader)
    var idats = newSeq[string]()
    while not buf.atEnd:
      let
        chunkLen = buf.readNInt32
        chunkType = uint32(buf.readNInt32)
      when DEBUG: echo("chunk type " & itostr(chunkType) & " len " & $chunkLen)
      let
        chunkData = buf.read(chunkLen)
        crc = uint32(buf.readNInt32)
        chunkCrc = zcrc(itostr(chunkType), chunkData)
      if crc != chunkCrc:
        raise newException(
          ValueError,
          fmt("bad CRC; from file: {:08x}, from data: {:08x}", crc, chunkCrc))
      case chunkType
      of ifromstr("IHDR"):
        load_ihdr(result, chunkData)
        when DEBUG: echo("  after ihdr: " & $result)
      of ifromstr("PLTE"):
        when DEBUG:
          let colors = load_plte(result, chunkData)
          echo("  color count: " & $colors)
        else:
          discard load_plte(result, chunkData)
      of ifromstr("IDAT"):
        idats.add(chunkData)
      of ifromstr("IEND"):
        discard
      else:
        when DEBUG: echo("unknown chunk type " & itostr(chunkType))
    var idat_len = 0
    for i, v in idats:
      idat_len += v.len
    var idat = newString(idat_len)
    var last_i = 0
    for i, v in idats:
      copyMem(addr(idat[last_i]), addr(idats[i][0]), v.len)
      last_i += v.len
    load_idat(result, idat)
    when DEBUG:
      echo("loaded image " & $result)
    return result


]##