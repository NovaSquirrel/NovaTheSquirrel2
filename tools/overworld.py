import xml.etree.ElementTree as ET # phone home
import glob, os

tilesets = {}
tilesets['tiles/Background.tsx'] = {}
tilesets['tiles/Path.tsx'] = {}
tilesets['tiles/Sprites.tsx'] = {}

# Read the tileset files for the ID
for f in tilesets:
	tree = ET.parse('overworlds/'+f)
	root = tree.getroot()
	for e in root:
		if e.tag != "tile":
			continue
		id = e.attrib['id']
		assert e[0].tag == 'properties'
		assert e[0][0].tag == 'property'
		tilesets[f][id] = e[0][0].attrib['value']

for f in glob.glob("overworlds/*.tmx"):
	tree = ET.parse(f)
	root = tree.getroot()

	map_width  = int(root.attrib['width'])
	map_height = int(root.attrib['height'])

	# Keep track of the mapping between the tile numbers and different tilesets
	tileset_first = []
	tileset_data  = []

	# Find what tileset a tile belongs to, and the offset within it
	def identify_tile(tilenum):
		if tilenum > 0:
			for i in range(len(tileset_first)):
				if tilenum >= tileset_first[i]:
					within = str(tilenum-tileset_first[i])
					if within in tileset_data[i]:
						return tileset_data[i][within]
					else:
						return None
		return None

	# The two map layers
	map_bg   = []
	map_path = []

	# Parse the map file
	for e in root:
		if e.tag == 'tileset':
			# Keep track of what tile numbers belong to what tile sheets
			tileset_first.insert(0, int(e.attrib['firstgid']))
			tileset_data.insert(0, tilesets[e.attrib['source']])
		elif e.tag == 'layer':
			# Parse tile layers
			map_out = map_bg if e.attrib['name'].lower() == 'background' else map_path
			assert e[0].attrib['encoding'] == 'csv'
			for line in [x for x in e[0].text.splitlines() if len(x)]:
				row = []
				for t in line.split(','):
					if not len(t):
						continue
					row.append(identify_tile(int(t)))
				map_out.append(row)
		elif e.tag == 'objectgroup':
			# Parse object layers
			if e.attrib['name'].lower() == 'level markers':
				for level in e:
					x = int(level.attrib['x'])//16
					y = int(level.attrib['y'])//16
					assert level[0].tag == 'properties'
					assert level[0][0].tag == 'property'
					destination = level[0][0].attrib['value']
					print("%d %d %s" % (x, y, destination))

			elif e.attrib['name'].lower() == 'sprites':
				pass
	print(map_bg)
	print(map_path)
