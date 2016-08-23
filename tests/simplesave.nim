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

import ../nimage
import streams
import strfmt

proc main() =
    let w = 2
    let h = 2
    var img1 = createImage(w, h)
    for i in 0..h-1:
        for j in 0..w-1:
            img1[i, j] = NColor(0xFF0000FF)
    img1[0, 0] = NColor(0x98765432)
    img1[0, 1] = NColor(0xABAD1DEA)
    img1[1, 1] = NColor(0xABCDEFFF)
    var out1 = newFileStream("test.png", fmWrite)
    img1.savePng(out1)
    out1.close()
    var in1 = newFileStream("test.png", fmRead)
    var img2 = loadPng(in1)
    in1.close()
    for i in 0..h-1:
        for j in 0..w-1:
            echo(fmt("{},{}: pre {} post {}", i, j, $img1[i,j], $img2[i,j]))
            assert(img1[i,j] == img2[i,j])
    echo("Success.")

when isMainModule:
    main()
