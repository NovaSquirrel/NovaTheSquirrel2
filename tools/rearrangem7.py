#!/usr/bin/env python3
# Rearranges the Mode 7 tileset images so that the four tiles that make up a block are sequential
import PIL, sys
from PIL import Image

im = Image.open("tools/M7Tileset.png")
out = im.copy()

for row in range(im.height//16):
	base_y = row * 16
	for col in range(im.width//32):
		base_x1 = col*16
		base_x2 = col*16 + im.width//2
		out_x   = col*32

		out.paste(im.crop((base_x1, base_y+0,  base_x1+16, base_y+8)),    (out_x,    base_y))
		out.paste(im.crop((base_x1, base_y+8,  base_x1+16, base_y+16)),   (out_x+16, base_y))
		out.paste(im.crop((base_x2, base_y+0,  base_x2+16, base_y+8)),    (out_x,    base_y+8))
		out.paste(im.crop((base_x2, base_y+8,  base_x2+16, base_y+16)),   (out_x+16, base_y+8))

out.save("tools/M7TilesetRearranged.png")
