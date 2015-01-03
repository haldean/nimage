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

