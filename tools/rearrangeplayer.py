#!/usr/bin/env python3
# The purpose of this script is to rearrange the frames of a player animation
# so that the 32x32 player animation frame (made of four 16x16 tiles)
# can be uploaded and used with two DMAs.
import PIL, sys
from PIL import Image

if len(sys.argv) != 3:
	print("rearrangeplayer.py input.png output.png")
else:
	im = Image.open(sys.argv[1])
	out = im.copy()

	for frame in range(im.height//32):
		base = frame*32
		out.paste(im.crop((0, base+16, 32, base+16+8)), (0, base+8))
		out.paste(im.crop((0, base+8,  32, base+8+8)),  (0, base+16))
		out.paste(im.crop((0, base+24, 32, base+24+8)), (0, base+24))
		print("frame "+str(frame))

	out.save(sys.argv[2])
