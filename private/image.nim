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

import strfmt
import unsigned

type
    ## A color in RGBA format, 8 bits per sample. For example, 50% red, 100%
    ## green, 0% blue, 100% alpha would be `NColor(0x80FF00FF)`.
    NColor* = distinct uint32
    ImageObj* = object of RootObj
        width*: int
        height*: int
        data*: seq[NColor] # Data is stored in row-major format
    Image* = ref ImageObj

# NColor implementation

proc `$`*(color: NColor): string =
    return fmt("{:08X}", uint32(color))

proc `==`*(c1, c2: NColor): bool =
    return uint32(c1) == uint32(c2)

# Image implementation

proc get_index(img: Image; row, col: int): int = row * img.width + col

proc `[]`*(img: Image; row, col: int): NColor =
    return img.data[img.get_index(row, col)]

proc `[]=`*(img: Image; row, col: int; val: NColor) =
    img.data[img.get_index(row, col)] = val

proc create_image*(width, height: int): Image =
    let data = newSeq[NColor](width * height)
    return Image(width: width, height: height, data: data)
