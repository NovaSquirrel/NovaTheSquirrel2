import xml.etree.ElementTree as ET # phone home
import sys, os

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
							row.append(tile)
						map_data.append(row)

	for row in map_data:
		outfile.write(bytes(row))
	outfile.close()
