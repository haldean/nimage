import nimage
import stream
import unsigned
import zlib

type
    PngImage = object of Image
        depth: uint8
        colorType: uint8

proc `$`(x: PngImage): string =
    return ("(img w " & $x.width & " h " & $x.height & " depth " & $x.depth &
            " colorType " & $x.colorType)

const
    PNG_HEADER = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    DEBUG = true

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
    img.colorType = buf.read

proc load_idat(img: ptr PngImage, chunkData: seq[uint8]) =
    var zdata_str = newString(len(chunkData))
    for i in 0..len(chunkData)-1:
        zdata_str[i] = char(chunkData[i])
    let zdata = cstring(zdata_str)
    let data = zlib.uncompress(zdata, len(chunkData))
    echo("  decompressed to " & $len(data) & " bytes")

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
    while buf.more:
        let
            chunkLen = buf.readInt32
            chunkType = buf.readInt32
            chunkTypeName = chunkType.itostr
        when DEBUG: echo("chunk type " & itostr(chunkType) & " len " & $chunkLen)
        var chunkData = newSeq[uint8](chunkLen)
        for i in 0..chunkLen-1:
            chunkData[i] = buf.read
        let crc = buf.readInt32
        case chunkType
        of ifromstr("IHDR"):
            load_ihdr(addr(result), chunkData)
        of ifromstr("IDAT"):
            load_idat(addr(result), chunkData)
        of ifromstr("IEND"):
            discard
        else:
            when DEBUG: echo("unknown chunk type " & itostr(chunkType))
    when DEBUG:
        echo("read image " & $result)
    return result
