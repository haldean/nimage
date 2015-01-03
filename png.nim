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

proc `$`(x: PngImage): string =
    return ("(img w " & $x.width & " h " & $x.height & " depth " & $x.depth &
            " colorType " & $x.colorType & ")")

const
    PNG_HEADER = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    DEBUG = true

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
        # read the scanline so we can apply filters before reading colors
        var scanline = newSeq[uint8](img.width * img.bpp)
        for i in 0..img.width * img.bpp - 1:
            scanline[i] = buf.read
        filter.apply(img.bpp, scanline, last_scanline)
        var scanBuf = newByteStream(scanline)
        while c < img.width:
            var color: NColor
            case img.colorType
            of gray:
                color = read_gray(scanBuf)
            of rgb:
                color = read_rgb(scanBuf)
            else:
                raise newException(ValueError, "can't decode color type " & $img.colorType)
            img[][r, c] = color
            c += 1
        last_scanline = scanline
        r += 1

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
    while buf.more:
        let
            chunkLen = buf.readInt32
            chunkType = buf.readInt32
            chunkData = buf.read(chunkLen)
            crc = buf.readInt32
        when DEBUG: echo("chunk type " & itostr(chunkType) & " len " & $chunkLen)
        case chunkType
        of ifromstr("IHDR"):
            load_ihdr(addr(result), chunkData)
            when DEBUG: echo("  after ihdr: " & $result)
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
        echo("read image " & $result)
    return result
