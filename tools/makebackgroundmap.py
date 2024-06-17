#!/usr/bin/env python3
# convert PNG backgrounds to Nova the Squirrel 2 background maps
import PIL, sys, os
from PIL import Image
from pathlib import Path
from nts2shared import *

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
		out.append(ts[i^(7 << 3)])
	return ''.join(out)

def tilestring_bytes(ts, bpp):
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
		if bpp == 4:
			b.append(plane_data[2][i])
			b.append(plane_data[3][i])
	return a+b

def convert(f):
	# Name of the background is the filename with path and extension taken out
	name = os.path.splitext(os.path.basename(f))[0]
	#print("Name "+name)

	# Palette to use
	palette_base = 1
	# Tile number the background tiles start at
	tile_number_base = 256

	tile_bpp = 4
	tile_priority = False

	# If there's a config file, read it and let it override the defaults
	text_filename = Path(f).with_suffix('.txt')
	if text_filename.is_file():
		with open(text_filename) as config_file:
			for line in config_file.readlines():
				line = line.rstrip()
				word, arg = separateFirstWord(line)

				if word == 'tile_base':
					tile_number_base = parseNumber(arg)
				elif word == 'palette_base':
					palette_base = parseNumber(arg)
				elif word == '2bpp':
					tile_bpp = 2
					palette_base = 0 # Assume this means we're using mode 1 too
				elif word == 'priority':
					tile_priority = True
				else:
					print("Unrecognized config word: "+word)
	# Base value for a tilemap value
	tile_base = (palette_base << 10) | (tile_priority * 0x2000) | tile_number_base

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
					tile_data = imtile.getdata()

					# For 2bpp backgrounds, try to guess the palette number for the tile and strip it from the tile's data
					tile_palette = None
					if tile_bpp == 2:
						tile_data = list(tile_data)
						warning_shown = False
						for i in range(64):
							pixel = tile_data[i]
							if pixel % 4 != 0: # Ignore transparent pixels
								if not warning_shown and tile_palette != None and tile_palette != pixel // 4:
									print("Ambiguous palette at tile %d,%d" % (screenw*32+tw, screenh*32+th))
									warning_shown = True
								tile_palette = pixel // 4
							tile_data[i] = pixel % 4
					if tile_palette == None: # If it's an empty tile, default to palette zero
						tile_palette = 0

					tilestring = ''.join(['%x' % p for p in tile_data])

#					if tilestring in all_solid:
#						row.append((palette_base<<10) | all_solid.index(tilestring))
#						continue

					# If a tile is already present as-is, just use it
					if tilestring in all_tiles:
						row.append(tile_base + all_tiles.index(tilestring) + (tile_palette << 10))
						continue

					# Test for tiles that can be saved with flips
					tilestring_h = tilestring_hflip(tilestring)
					if tilestring_h in all_tiles:
						row.append(0x4000 + tile_base + all_tiles.index(tilestring_h) + (tile_palette << 10))
						flips += 1
						continue
					tilestring_v = tilestring_vflip(tilestring)
					if tilestring_v in all_tiles:
						row.append(0x8000 + tile_base + all_tiles.index(tilestring_v) + (tile_palette << 10))
						flips += 1
						continue
					tilestring_hv = tilestring_hflip(tilestring_v)
					if tilestring_hv in all_tiles:
						row.append(0xc000 + tile_base + all_tiles.index(tilestring_hv) + (tile_palette << 10))
						flips += 1
						continue

					all_tiles.append(tilestring)
					row.append(tile_base + all_tiles.index(tilestring) + (tile_palette << 10))

				background_tilemap.append(row)

	print("Tiles used: %d" % len(all_tiles))
	print("Tiles saved by flips: %d" % flips)

	im.close()

	# Write the characters
	outfile = open("backgrounds/%s.chrsfc" % name, "wb")
	temp = []
	for tile in all_tiles:
		temp += tilestring_bytes(tile, tile_bpp)
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

print("Converting "+sys.argv[1])
convert(sys.argv[1])
