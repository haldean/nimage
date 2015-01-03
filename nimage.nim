import colors
import unsigned

type
    NColor* = distinct uint32
    Index* = tuple[row: int, col: int]
    Image* = object of RootObj
        width*: int
        height*: int
        data*: seq[NColor] # Data is stored in row-major format

proc get_index(img: Image; row, col: int): int = row * img.width + col

proc `[]`*(img: Image; row, col: int): NColor =
    return img.data[img.get_index(row, col)]

proc `[]=`*(img: var Image; row, col: int; val: NColor) =
    img.data[img.get_index(row, col)] = val

proc create_image*(width, height: int): Image =
    let data = newSeq[NColor](width * height)
    return Image(width: width, height: height, data: data)
