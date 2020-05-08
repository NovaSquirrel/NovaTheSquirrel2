#!/usr/bin/env python3
import xml.etree.ElementTree as ET # phone home
import glob, os

outfile = open("src/m7leveldata.s", "w")
outfile.write('; This is automatically generated. Edit mode 7 level Tiled maps instead\n')
outfile.write('.include "snes.inc"\n')
outfile.write('.segment "Mode7Game"\n\n')

all_m7pointers = []

for f in sorted(glob.glob("m7levels/*.tmx")):
	plain_name = os.path.splitext(os.path.basename(f))[0]
	compressed_name = os.path.splitext(f)[0]+'.lz4'

	outfile.write('.export M7Level_%s\n' % plain_name)
	outfile.write('M7Level_%s:\n' % plain_name)
	all_m7pointers.append("M7Level_%s" % plain_name)

	tree = ET.parse(f)
	root = tree.getroot()

	start_x, start_y = 5, 5
	start_dir = 0

	# Parse the map file
	for e in root:
		if e.tag == 'layer':
			# Parse tile layers
			for d in e: # Go through the layer's data
				if d.tag == 'properties':
					for p in d:
						pass
				elif d.tag == 'data':
					pass # Handled by a separate pass
		elif e.tag == 'objectgroup':
			# Parse object layers
			if e.attrib['name'].lower() == 'meta':
				for cmd in e:
					x = int(cmd.attrib['x'])//16
					y = int(cmd.attrib['y'])//16
					name = cmd.attrib['name']
					if name.lower() == 'playerstart':
						start_x, start_y = x, y

						assert cmd[0].tag == 'properties'
						assert cmd[0][0].tag == 'property'
						assert cmd[0][0].attrib['name'] == 'Direction'
						start_dir = ['N', 'W', 'S', 'E'].index(cmd[0][0].attrib['value'])

	# Write the level data
	outfile.write('  .byt %d, %d ; X and Y\n' % (start_x, start_y))
	outfile.write('  .byt %d ; Start direction\n' % (start_dir))
	outfile.write('  .incbin "../%s"\n' % compressed_name.replace('\\', '/'))

	outfile.write('\n')
outfile.close()
