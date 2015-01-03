import colors

type
    Index* = tuple[row: int, col: int]
    Image* = object of TObject
        width*: int
        height*: int
        data: seq[Color] # Data is stored in row-major format

proc get_index(img: Image, idx: Index): int = idx.row * img.width + idx.col

proc `[]`*(img: Image, idx: Index): Color =
    return img.data[img.get_index(idx)]

proc `[]=`*(img: var Image, idx: Index, val: Color) =
    img.data[img.get_index(idx)] = val

proc create_image*(width, height: int): Image =
    let data = newSeq[Color](width * height)
    return Image(width: width, height: height, data: data)
