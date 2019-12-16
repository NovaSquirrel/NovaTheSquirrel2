# Convert png portraits to SNES format and create enums
import PIL, glob, os
from PIL import Image

portraits = {}
portrait_count = 0

# Convert a tile (in the form of a list of pixel values) to bytes
def tile_to_bytes(raw):
	# First get the data for each plane
	plane_data = []
	for plane in range(4):
		p = []
		for row in range(8):
			rowbyte = 0
			for column in range(8):
				# Get the actual binary value
				nybble = raw[row*8+column]
				# Extract the desired bit from it
				if nybble & (1 << plane):
					rowbyte |= 1 << (7-column)
			p.append(rowbyte)
		plane_data.append(p)

	# Interleave the planes together
	a,b = [], []
	for i in range(8):
		a.append(plane_data[0][i])
		a.append(plane_data[1][i])
		b.append(plane_data[2][i])
		b.append(plane_data[3][i])
	return a+b

for f in glob.glob("portraits/*.png"):
	# Name of the portrait is the filename with path and extension taken out
	name = os.path.splitext(os.path.basename(f))[0]

	im = Image.open(f)
	rearrange = im.copy()

	count = im.height // 32

	# Rearrange the image so that the tiles are better suited to displaying with 16x16 sprites
	for frame in range(count):
		base = frame*32
		rearrange.paste(im.crop((0, base+16, 32, base+16+8)), (0, base+8))
		rearrange.paste(im.crop((0, base+8,  32, base+8+8)),  (0, base+16))
		rearrange.paste(im.crop((0, base+24, 32, base+24+8)), (0, base+24))

	portraits[name] = {'index': portrait_count, 'data': []}
	portrait_count += count

	# Get the pixel data and convert it to tiles
	for th in range(im.height // 8):
		row = []
		for tw in range(im.width // 8):
			imtile = rearrange.crop((tw*8, th*8, tw*8+8, th*8+8))
			portraits[name]['data'].append(tile_to_bytes(imtile.getdata()))

	# Read palette but don't do anything with it yet
	pal = im.getpalette()[3:]
	for i in range(15):
		r = pal.pop(0)
		g = pal.pop(0)
		b = pal.pop(0)

	im.close()


# Output the portraits ; don't use a directory because everything is the same size
outfile = open("src/portraitdata.s", "w")
outfile.write('; This is automatically generated. Edit "portraits" directory instead\n')
outfile.write('.include "snes.inc"\n')
outfile.write('.segment "Portraits"\n')
outfile.write('.export PortraitData\n\n')
outfile.write('.proc PortraitData\n')

for pic, data in portraits.items():
	outfile.write('  ; %s\n' % pic)
	for tile in data['data']:
		outfile.write('  .byt %s\n' % ', '.join(['$%.2x' % n for n in tile]))	
outfile.write('.endproc\n')
outfile.close()


# Do the enum in a separate file because I can't export enums
outfile = open("src/portraitenum.s", "w")
outfile.write('; This is automatically generated. Edit "portraits" directory instead\n')
outfile.write('.enum Portrait\n')
for pic in portraits:
	outfile.write('  %s = %d\n' % (pic, portraits[pic]['index']))
outfile.write('.endenum\n\n')
outfile.close()
