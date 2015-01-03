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

import zlib

proc zuncompress*(data: seq[uint8]): string =
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
