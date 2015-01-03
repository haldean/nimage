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

import streams

type
    ByteStreamObj = object of StreamObj
        data*: seq[uint8]
        pos: int
    ByteStream = ref ByteStreamObj

proc bsClose(s: Stream) =
    var bs = ByteStream(s)
    bs.data = nil

proc bsAtEnd(s: Stream): bool =
    let bs = ByteStream(s)
    return bs.pos >= bs.data.len

proc bsSetPos(s: Stream; pos: int) =
    var bs = ByteStream(s)
    bs.pos = clamp(pos, 0, bs.data.high)

proc bsGetPos(s: Stream): int =
    let bs = ByteStream(s)
    return bs.pos

proc bsRead(s: Stream; buf: pointer; buflen: int): int =
    var bs = ByteStream(s)
    result = min(buflen, bs.data.len - bs.pos)
    if result > 0:
        copyMem(buf, addr(bs.data[bs.pos]), result)
        bs.pos += result

proc bsWrite(s: Stream; buf: pointer; buflen: int) =
    var bs = ByteStream(s)
    if buflen <= 0:
        return
    if bs.pos + buflen > bs.data.len:
        bs.data.setLen(bs.pos + buflen)
    copyMem(addr(bs.data[bs.pos]), buf, buflen)
    bs.pos += buflen

proc newByteStream*(bytes: seq[uint8]): ByteStream =
    new(result)
    result.data = bytes
    result.pos = 0
    result.closeImpl = bsClose
    result.atEndImpl = bsAtEnd
    result.setPositionImpl = bsSetPos
    result.getPositionImpl = bsGetPos
    result.readDataImpl = bsRead
    result.writeDataImpl = bsWrite
