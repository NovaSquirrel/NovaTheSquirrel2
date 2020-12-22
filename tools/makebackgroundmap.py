#!/usr/bin/env python3
# convert PNG backgrounds to Nova the Squirrel 2 background maps
import PIL, sys, os
from PIL import Image
# Palette to use
palette_base = 7
# Tile number the background tiles start at
tile_number_base = 256

# Base value for a tilemap value
tile_base = (palette_base<<10) | tile_number_base

## Tiles that are completely solid
#all_solid = [("%x" % i) * 64 for i in range(16)]

def tilestring_hflip(ts):
	out = []
	for i in range(64):
		out.append(ts[i^7])
	return ''.join(out)

def tilestring_vflip(ts):
	out = []
	for i in range(64):
		out.append(ts[i^(7*8)])
	return ''.join(out)

def tilestring_bytes(ts):
	# First get the data for each plane
	plane_data = []
	for plane in range(4):
		p = []
		for row in range(8):
			rowbyte = 0
			for column in range(8):
				# Get the actual binary value
				nybble = int(ts[row*8+column],16)
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

def convert(f):
	# Name of the background is the filename with path and extension taken out
	name = os.path.splitext(os.path.basename(f))[0]
	print("Name "+name)

	im = Image.open(f)

	# Tiles saved by flipping or being solid
	flips = 0
	solids = 0

	# All tiles, to avoid duplicates
	all_tiles = []

	# Find the tiles used
	background_tilemap = []
	for screenh in range(im.height // 256):
		for screenw in range(im.width // 256):
			for th in range(32):
				row = []
				for tw in range(32):
					imtile = im.crop((screenw*256+tw*8, screenh*256+th*8, screenw*256+tw*8+8, screenh*256+th*8+8))
					tilestring = ''.join(['%x' % p for p in imtile.getdata()])

#					if tilestring in all_solid:
#						row.append((palette_base<<10) | all_solid.index(tilestring))
#						continue

					if tilestring in all_tiles:
						row.append(tile_base + all_tiles.index(tilestring))
						continue

					# Test for tiles that can be saved with flips
					tilestring_h = tilestring_hflip(tilestring)
					if tilestring_h in all_tiles:
						row.append(0x4000 + tile_base + all_tiles.index(tilestring_h))
						flips += 1
						continue
					tilestring_v = tilestring_vflip(tilestring)
					if tilestring_v in all_tiles:
						row.append(0x8000 + tile_base + all_tiles.index(tilestring_v))
						flips += 1
						continue
					tilestring_hv = tilestring_hflip(tilestring_v)
					if tilestring_hv in all_tiles:
						row.append(0xc000 + tile_base + all_tiles.index(tilestring_hv))
						flips += 1
						continue

					all_tiles.append(tilestring)
					row.append(tile_base + all_tiles.index(tilestring))

				background_tilemap.append(row)

	print("Tiles used: %d" % len(all_tiles))
	print("Tiles saved by flips: %d" % flips)

	im.close()

	# Write the characters
	outfile = open("backgrounds/%s.chrsfc" % name, "wb")
	temp = []
	for tile in all_tiles:
		temp += tilestring_bytes(tile)
	temp = bytes(temp)
	outfile.write(bytes(temp))
	outfile.close()

	# Write the tilemap
	outfile = open("backgrounds/Map%s.namsfc" % name, "wb")
	temp = []
	for row in background_tilemap:
		for tile in row:
			temp.append(tile & 255)
			temp.append((tile >> 8) & 255)
	outfile.write(bytes(temp))
	outfile.close()

print(sys.argv)
print("Converting "+sys.argv[1])
convert(sys.argv[1])
