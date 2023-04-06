#!/usr/bin/env python3
# Convert the palette for the Mode 7 tileset image specifically

def getPNGPalette(filename):
	with open(filename, "rb") as im:
		magic = im.read(8)
		if magic != b'\x89\x50\x4e\x47\x0d\x0a\x1a\x0a':
			print("Error: %s is not a PNG" % filename)
			return None
		while True:
			length = int.from_bytes(im.read(4), 'big')
			chunk = im.read(4).decode('ascii')
			if chunk == 'PLTE':
				data = im.read(length)
				return [(int(data[x+0]), int(data[x+1]), int(data[x+2])) for x in range(0, len(data), 3)]
			elif chunk == 'IEND':
				print("Error: %s has no palette" % filename)
				return None # No palette data
			else:
				im.seek(length, 1) # Skip this chunk's data
			im.seek(4, 1) # Ignore the chunk's CRC

outfile = open("src/mode7/m7palettedata.s", "w")
outfile.write('; This is automatically generated. Edit "M7Tileset.png" instead\n')

outfile.write('.proc Mode7Palette\n')

im = getPNGPalette("tilesetsX/M7Tileset.png")
for i in im[1:]:
	outfile.write("  .word RGB8(%d, %d, %d)\n" % (i[0],i[1],i[2]))

outfile.write('.endproc\n')
outfile.close()
