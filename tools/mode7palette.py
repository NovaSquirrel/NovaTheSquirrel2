#!/usr/bin/env python3
# Convert the palette for the Mode 7 tileset image specifically
import PIL
from PIL import Image

outfile = open("src/m7palettedata.s", "w")
outfile.write('; This is automatically generated. Edit "M7Tileset.png" instead\n')

outfile.write('.proc Mode7Palette\n')

im = Image.open("tilesetsX/M7Tileset.png")
pal = im.getpalette()[3:]
# Read out 90 colors
for i in range(90):
	r = pal.pop(0)
	g = pal.pop(0)
	b = pal.pop(0)
	outfile.write("  .word RGB8(%d, %d, %d)\n" % (r,g,b))
im.close()

outfile.write('.endproc\n')
outfile.close()
