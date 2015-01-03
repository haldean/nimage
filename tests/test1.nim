import nimage
import stream
import png

proc main() =
    var buf2 = newFileStream("tests/bttf.png")
    discard load_png(buf2)
    var buf1 = newFileStream("tests/test1.png")
    discard load_png(buf1)

when isMainModule:
    main()
