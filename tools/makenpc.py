# Convert png NPC pictures to SNES format and create enums
import PIL, glob, os, json
from PIL import Image

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

infofile = open("npc/npc.json")
info = json.load(infofile)
infofile.close()

all_palettes_compare = [] # Holds stringified versions of the palettes
all_palettes_actual = []  # Holds actual palette values
all_npc = {}

for name, data in info.items():
	# Name of the portrait is the filename with path and extension taken out
	im = Image.open('npc/'+data['graphic'])

	encoded_tile_list = []
	encoded_tile_positions = []
	width_in_tiles = im.width//8
	height_in_tiles = im.height//8
	# Find and convert all non-empty tiles
	for th in range(height_in_tiles):
		for tw in range(width_in_tiles):
			imtile = im.crop((tw*8, th*8, tw*8+8, th*8+8))
			tile = tile_to_bytes(imtile.getdata())
			if tile != [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]:
				encoded_tile_list.append(tile)
				encoded_tile_positions.append((tw-width_in_tiles+2, th-height_in_tiles))

	# Read palette
	pal = im.getpalette()[3:]
	triplets = []
	for i in range(15):
		r = pal.pop(0)
		g = pal.pop(0)
		b = pal.pop(0)
		triplets.append((r,g,b))
	triplets_string = str(triplets)

	palette_use = None

	# Is it a new palette? Add it to the list
	if triplets_string not in all_palettes_compare:
		all_palettes_compare.append(triplets_string)
		all_palettes_actual.append(triplets)
		palette_use = len(all_palettes_compare) - 1
	else:
		palette_use = all_palettes_compare.index(triples_string)

	# Add character to the list
	character = {
		'tile_data': encoded_tile_list,
		'tile_pos': encoded_tile_positions,
		'palette': palette_use
	}
	all_npc[name] = character
	im.close()

# Export everything
outfile = open("src/dialog_npc_data.s", "w")
outfile.write('; This is automatically generated. Edit "npc" directory instead\n')
outfile.write('.include "snes.inc"\n')
outfile.write('.include "global.inc"\n')
outfile.write('.segment "DialogNPC"\n')
outfile.write('.export DialogNPCDirectory, DialogNPCPalettes\n\n')

# Write the directory
outfile.write('.proc DialogNPCDirectory\n')
for character in all_npc:
	outfile.write('  .addr DialogNPC_%s\n' % (character))
outfile.write('.endproc\n\n')

# Write the actual character data
for character, data in all_npc.items():
	outfile.write('.proc DialogNPC_%s\n' % character)
	# Write the palette for the NPC
	outfile.write('  ; Palette\n')
	outfile.write('  .byt %d\n' % data['palette'])
	outfile.write('  ; Tile positions\n')
	outfile.write("  .addr TileData\n")
	for position in data['tile_pos']:
		outfile.write("  .byt <%d, <%d\n" % (position[0]*8, position[1]*8))
	outfile.write("  .byt 255, 255\n")
	outfile.write("TileData:\n")
	outfile.write("  .word 32*%d\n" % len(data['tile_data']))

	for tile in data['tile_data']:
		outfile.write('  .byt %s\n' % ', '.join(['$%.2x' % n for n in tile]))
	outfile.write('.endproc\n\n')

outfile.write('.proc DialogNPCPalettes\n')
for palette in all_palettes_actual:
	outfile.write("  ; ---\n")
	for triplet in palette:
		outfile.write("  .word RGB8(%d, %d, %d)\n" % (triplet[0],triplet[1],triplet[2]))
	outfile.write("  .word 0 ; Dummy\n");
outfile.write('.endproc\n\n')
outfile.close()

# Do the enum in a separate file because I can't export enums
outfile = open("src/dialog_npc_enum.s", "w")
outfile.write('; This is automatically generated. Edit "npc" directory instead\n')
outfile.write('.enum DialogNPC\n')
for character in all_npc:
	outfile.write('  %s\n' % (character))
outfile.write('.endenum\n\n')
outfile.close()
