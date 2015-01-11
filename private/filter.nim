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
import unsigned

import private/png

type
    Filter* {. pure .} = enum
        none = 0
        sub = 1
        up = 2
        average = 3
        paeth = 4

template wmod(v, m: int): int =
    ## Calculates v % m with sign wraparound, ensuring that the return value is in
    ## [0, m). wmod(v, m) for -m < v < 0 is equal to m - v.
    if v mod m < 0: (v mod m) + m else: v mod m

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
        filter: Filter, bpp: int, scanline: var string, last_scanline: string) =
    if filter == Filter.none:
        return
    for i, v in scanline:
        var left, up, corner: int
        if i - bpp >= 0:
            left = int(scanline[i - bpp])
        if not isNil(last_scanline):
            up = int(last_scanline[i])
            if i - bpp >= 0:
                corner = int(last_scanline[i - bpp])
        case filter
        of Filter.sub:
            scanline[i] = char(wmod(int(v) + left, 256))
        of Filter.up:
            scanline[i] = char(wmod(int(v) + up, 256))
        of Filter.average:
            let avg = int(floor((left + up) / 2))
            scanline[i] = char(wmod(int(v) + avg, 256))
        of Filter.paeth:
            let pp = paethpredict(left, up, corner)
            scanline[i] = char(wmod(int(v) + pp, 256))
        of Filter.none: discard
        else:
            raise newException(ValueError, "no support for filter " & $filter)

proc apply*(
        filter: Filter; bpp: int; scanline, last_scanline: string;
        res: var string) =
    assert(res.len == scanline.len)
    for i, v in scanline:
        var left, up, corner: int
        if i - bpp >= 0:
            left = int(scanline[i - bpp])
        if not isNil(last_scanline):
            up = int(last_scanline[i])
            if i - bpp >= 0:
                corner = int(last_scanline[i - bpp])
        case filter
        of Filter.none:
            res[i] = v
        of Filter.sub:
            res[i] = char(wmod(int(v) - left, 256))
        of Filter.up:
            res[i] = char(wmod(int(v) - up, 256))
        of Filter.average:
            let avg = int(floor((left + up) / 2))
            res[i] = char(wmod(int(v) - avg, 256))
        of Filter.paeth:
            let pp = paethpredict(left, up, corner)
            res[i] = char(wmod(int(v) - pp, 256))
        else:
            raise newException(ValueError, "no support for filter " & $filter)

proc choose_filter*(img: PngImage; scanline, last_scanline: string): Filter =
    if img.depth < 8'u8 or img.colorType == palette:
        return Filter.none
    var scores: array[low(Filter)..high(Filter), uint32]
    var buf = newString(scanline.len)
    for f in Filter:
        f.apply(img.bpp, scanline, last_scanline, buf)
        scores[f] = 0
        for i, v in buf:
            scores[f] += uint32(v)
    var
        min_score = uint32(scanline.len) * 256
        min_f = Filter.none
    for f, score in scores:
        if score < min_score:
            min_score = score
            min_f = f
    return min_f
