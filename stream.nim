type
    Stream* = object of RootObj
    FileStream* = object of Stream
        f: File
    ByteStream* = object of Stream
        bytes: seq[uint8]
        loc: int

# Minimum interface for streams
method read*(stream: var Stream): uint8 =
    discard

method more*(stream: Stream): bool =
    return false

# FileStream implementation
proc newFileStream*(fname: string): FileStream =
    return FileStream(f: open(fname))

method read*(stream: var FileStream): uint8 =
    return uint8(stream.f.readChar)

method more*(stream: FileStream): bool =
    return not stream.f.endOfFile

# ByteStream implementation
proc newByteStream*(bytes: seq[uint8]): ByteStream =
    return ByteStream(bytes: bytes, loc: 0)

method read*(stream: var ByteStream): uint8 =
    let val = stream.bytes[stream.loc]
    stream.loc = stream.loc + 1
    return val

method more*(stream: ByteStream): bool =
    return stream.loc < len(stream.bytes)

# Convenience methods built out of base interface
method readInt32*(stream: var Stream): int32 =
    ## Reads a 32-bit integer from the stream in big-endian form
    var i = 0
    while i < 4 and stream.more:
        result = (result shl 8) or int32(stream.read)
        i += 1
    if i != 4:
        raise newException(EOutOfRange, "stream ran out before integer was read")
