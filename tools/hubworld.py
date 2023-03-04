#!/usr/bin/env python3
# encodes the Nova the Squirrel 2 hub world into a format the game can use
import PIL, sys, os
from PIL import Image

def tile_hflip(ts): # Takes a list of pixels
	out = []
	for i in range(64):
		out.append(ts[i^7])
	return tuple(out)

def tile_vflip(ts): # Takes a list of pixels
	out = []
	for i in range(64):
		out.append(ts[i^(7 << 3)])
	return tuple(out)

def tile_hvflip(ts): # Takes a list of pixels
	out = []
	for i in range(64):
		out.append(ts[i^63])
	return tuple(out)

def tile_bytes(ts): # Takes a list of palette indexes
	# First get the data for each plane
	plane_data = []
	for plane in range(4):
		p = []
		for row in range(8):
			rowbyte = 0
			for column in range(8):
				# Get the actual binary value
				nybble = ts[row*8+column]
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
	return bytes(a+b)

def convert_map(fg_filename, bg_filename, attribute_filename, pal_filename, metatile_filename, solidmap_filename, chr_filename):
	fg_image = Image.open(fg_filename).convert('RGBA')
	bg_image = Image.open(bg_filename).convert('RGBA')
	pal_image = Image.open(pal_filename).convert('RGBA')
	attrib_image = Image.open(attribute_filename).convert('RGBA')

	assert pal_image.width == 16
	assert pal_image.height == 8

	# Find out what palettes are available
	palette_sets = [set() for _ in range(8)] # For determining which colors are correct
	palette_lists = [[] for _ in range(8)]   # For getting color indexes to use
	for palette_id in range(8):
		for palette_index in range(16):
			pixel = pal_image.getpixel((palette_index, palette_id))
			palette_sets[palette_id].add(pixel)
			palette_lists[palette_id].append(pixel)

	# Convert the layers
	tile_data    = [] # Actual byte data per-tile
	tile_palette = [] # Intended palette for each tile
	tile_lookup  = {} # Indexed by tuple of pixels, gets index for tile_data
	metatile_data = []
	metatile_maps = [[], []]

	for layer_num, layer in enumerate((fg_image, bg_image)):
		layer_width_in_tiles = layer.width // 8
		layer_height_in_tiles = layer.height // 8
		tilemap_data = [ [0]*layer_height_in_tiles for _ in range(layer_width_in_tiles)]

		for tile_y in range(layer_height_in_tiles):
			for tile_x in range(layer_width_in_tiles):
				tile_pixels = tuple(layer.crop((tile_x*8, tile_y*8, tile_x*8+8, tile_y*8+8)).getdata())

				tile_priority = False
				if layer_num == 0:
					attrib_r, attrib_g, attrib_b, attrib_a = attrib_image.getpixel((tile_x*8, tile_y*8))
					if attrib_b == 255:
						tile_priority = True

				hflip = False
				vflip = False
				if   (which_tile := tile_lookup.get(tile_pixels)) != None:
					pass
				elif (which_tile := tile_lookup.get(tile_hflip(tile_pixels))) != None:
					hflip = True
				elif (which_tile := tile_lookup.get(tile_vflip(tile_pixels))) != None:
					vflip = True
				elif (which_tile := tile_lookup.get(tile_hvflip(tile_pixels))) != None:
					hflip = True
					vflip = True
				else:
					# Get all the colors used in this tile
					colors_in_tile = set()
					for pixel in tile_pixels:
						colors_in_tile.add(pixel)
					# Which palette has all these colors?
					for palette_id in range(8):
						if palette_sets[palette_id].issuperset(colors_in_tile):
							which_tile = len(tile_data)

							palette = palette_lists[palette_id]
							tile_data.append(tile_bytes([palette.index(x) for x in tile_pixels]))
							tile_palette.append(palette_id)

							tile_lookup[tile_pixels] = which_tile
							break
					else:
						print("Couldn't find palette for tile at %d, %d in %s" % (tile_x, tile_y, "BG" if layer_num else "FG"))
						sys.exit()
				tilemap_data[tile_x][tile_y] = which_tile | (tile_priority*0x2000) | (hflip*0x4000) | (vflip*0x8000) | (tile_palette[which_tile]<<10)

		# Pack the tilemaps into metatiles
		for metatile_x in range(layer_width_in_tiles // 2):
			for metatile_y in range(layer_height_in_tiles // 2):
				metatile_contents = (
					tilemap_data[metatile_x*2+0][metatile_y*2+0],
					tilemap_data[metatile_x*2+1][metatile_y*2+0],
					tilemap_data[metatile_x*2+0][metatile_y*2+1],
					tilemap_data[metatile_x*2+1][metatile_y*2+1]
				)
				try:
					metatile_id = metatile_data.index(metatile_contents)
				except ValueError:
					metatile_id = len(metatile_data)
					metatile_data.append(metatile_contents)
				metatile_id *= 2
				metatile_maps[layer_num].append(bytes([metatile_id & 255, metatile_id >> 8]))

	print("Tile count: %d" % len(tile_data))
	print("Metatile count: %d" % len(metatile_data))

	# Write the output files

	meta_out = open(metatile_filename, 'wb')
	for i in range(4):
		for metatile in metatile_data:
			meta_out.write(bytes([metatile[i] & 255, metatile[i] >> 8]))
	meta_out.close()

	layer_width_in_tiles = fg_image.width // 8
	layer_height_in_tiles = fg_image.height // 8
	solid_out = open(solidmap_filename, 'wb')
	for tile_y in range(layer_height_in_tiles):
		for tile_x in range(layer_width_in_tiles // 8):
			x_base = tile_x * 8
			b = 0
			for i in range(8):
				attrib_r, attrib_g, attrib_b, attrib_a = attrib_image.getpixel(((x_base + i)*8, tile_y*8))
				if attrib_r == 255:
					b |= 1 << i
			solid_out.write(bytes([b]))
	solid_out.close()

	pal_out = open(os.path.splitext(pal_filename)[0]+'.bin', 'wb')
	for palette in palette_lists:
		for color in palette:
			value = (color[0]//8) | ((color[1]//8)<<5) | ((color[2]//8)<<10)
			pal_out.write(bytes([value & 255, value >> 8]))
	pal_out.close()

	fg_out = open(os.path.splitext(fg_filename)[0]+'.bin', 'wb')
	for tile in metatile_maps[0]:
		fg_out.write(tile)
	fg_out.close()

	bg_out = open(os.path.splitext(bg_filename)[0]+'.bin', 'wb')
	for tile in metatile_maps[1]:
		bg_out.write(tile)
	bg_out.close()

	chr_out = open(chr_filename, 'wb')
	for tile in tile_data:
		chr_out.write(tile)
	chr_out.close()

	attrib_image.close()
	pal_image.close()
	bg_image.close()
	fg_image.close()

convert_map("hubworld/fg.png", "hubworld/bg.png", "hubworld/attribute.png", "hubworld/palettes.png", "hubworld/metatiles.bin", "hubworld/solidmap.bin", "hubworld/hubworld.chrsfc")
