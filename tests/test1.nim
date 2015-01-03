import nimage
import stream
import png

var buf = newFileStream("tests/test1.png")
discard load_png(buf)
