#!/usr/bin/env python3
import xml.etree.ElementTree as ET # phone home
import sys, os

# Get tileset info
tileset_tree = ET.parse("m7levels/tiles/M7Tileset.tsx")
tileset_root = tileset_tree.getroot()
name_for_tiled_id = {}
for t in tileset_root:
	if t.tag == 'tile':
		assert t[0].tag == 'properties'
		for p in t[0]: # properties
			assert p.tag == 'property'
			if p.attrib['name'] == 'Name':
				name_for_tiled_id[int(t.attrib['id'])] = p.attrib['value']

# Get the block enum
define_file = open("src/mode7/m7blockenum.s")
define_lines = [x.strip() for x in define_file.readlines()]
define_file.close()
id_for_block = {}
block_count = 0
in_enum = False
for i in define_lines:
	if i.strip() == '.enum Mode7Block':
		in_enum = True
	elif i.strip() == '.endenum':
		in_enum = False
	elif in_enum:
		id_for_block[i.strip()] = block_count
		block_count += 1

if len(sys.argv) != 3:
	print("m7levelconvert.py input.tmx output.bin")
else:
	outfile = open(sys.argv[2], "wb")
	tree = ET.parse(sys.argv[1])
	root = tree.getroot()

	map_width  = int(root.attrib['width'])
	map_height = int(root.attrib['height'])
	map_data   = []

	# Parse the map file
	for e in root:
		if e.tag == 'layer':
			# Parse tile layers
			for d in e: # Go through the layer's data
				if d.tag == 'properties':
					for p in d:
						pass
				elif d.tag == 'data':
					assert d.attrib['encoding'] == 'csv'
					for line in [x for x in d.text.splitlines() if len(x)]:
						row = []
						for t in line.split(','):
							if not len(t):
								continue
							tile = max(0, int(t)-1)

							if tile in name_for_tiled_id and name_for_tiled_id[tile] in id_for_block:
								row.append(id_for_block[name_for_tiled_id[tile]])
							else:
								print(name_for_tiled_id[tile] + " not found in enum")
								row.append(0)
						map_data.append(row)

	for row in map_data:
		outfile.write(bytes(row))
	outfile.close()
