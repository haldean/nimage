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

import math

type
    Filter* {. pure .} = enum
        none = 0
        sub = 1
        up = 2
        average = 3
        paeth = 4

proc paethpredict(a, b, c: int): int =
    let
        p = a + b - c
        pa = abs(p - a)
        pb = abs(p - b)
        pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c

proc unapply*(
        filter: Filter, bpp: int,
        scanline: var seq[uint8], last_scanline: seq[uint8]) =
    if filter == Filter.none:
        return
    for i, v in scanline:
        var left, up, corner: int
        if i - bpp < 0:
            left = 0
            corner = 0
        else:
            left = int(scanline[i - bpp])
        if isNil(last_scanline):
            corner = 0
            up = 0
        else:
            up = int(last_scanline[i])
            if i - bpp >= 0:
                corner = int(last_scanline[i - bpp])
        case filter
        of Filter.sub:
            scanline[i] = uint8((int(v) + left) mod 256)
        of Filter.up:
            scanline[i] = uint8((int(v) + up) mod 256)
        of Filter.average:
            let avg = int(floor((left + up) / 2))
            scanline[i] = uint8((int(v) + avg) mod 256)
        of Filter.paeth:
            let pp = paethpredict(left, up, corner)
            scanline[i] = uint8((int(v) + pp) mod 256)
        of Filter.none: discard
        else:
            raise newException(ValueError, "no support for filter " & $filter)

proc apply*(bpp: int, scanline: var seq[uint8], last_scanline: seq[uint8]): seq[uint8] =
    let filter = Filter(scanline[0])
    var result = newSeq[uint8](scanline.len)
    for i, v in scanline:
        if i == 0:
            result[i] = v
            continue
        case filter
        of Filter.none:
            result[i] = v
        else:
            raise newException(ValueError, "no support for filter " & $filter)
