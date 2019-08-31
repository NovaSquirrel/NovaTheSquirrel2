import xml.etree.ElementTree as ET # phone home
import glob, os

tilesets = {}
tilesets['tiles/Background.tsx'] = {}
tilesets['tiles/Path.tsx'] = {}
tilesets['tiles/Sprites.tsx'] = {}
all_overworlds = []

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

outfile = open("src/overworlddata.s", "w")
outfile.write('; This is automatically generated. Edit overworld Tiled maps instead\n')
outfile.write('.include "snes.inc"\n')
outfile.write('.include "actorenum.s"\n')
outfile.write('.include "graphicsenum.s"\n')
outfile.write('.include "paletteenum.s"\n')
outfile.write('.include "overworldblockenum.s"\n')
outfile.write('.segment "Overworld"\n\n')

for f in glob.glob("overworlds/*.tmx"):
	plain_name = os.path.splitext(os.path.basename(f))[0]
	all_overworlds.append(plain_name)

	outfile.write('Overworld_%s:\n' % plain_name)

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
	map_bg      = []
	map_path    = []
	map_sprites = []
	map_priority_sprites = []
	map_graphics = []
	map_palettes = []
	map_spritegraphics = []

	# Parse the map file
	for e in root:
		if e.tag == 'tileset':
			# Keep track of what tile numbers belong to what tile sheets
			tileset_first.insert(0, int(e.attrib['firstgid']))
			tileset_data.insert(0, tilesets[e.attrib['source']])
		elif e.tag == 'layer':
			# Parse tile layers
			map_out = map_bg if e.attrib['name'].lower() == 'background' else map_path

			for d in e: # Go through the layer's data
				if d.tag == 'properties':
					for p in d:
						if p.attrib['name'] == 'Graphics':
							map_graphics = p.attrib['value'].split()
						if p.attrib['name'] == 'Palettes':
							map_palettes = p.attrib['value'].split()
						if p.attrib['name'] == 'SpriteGraphics':
							map_spritegraphics = p.attrib['value'].split()
				elif d.tag == 'data':
					assert d.attrib['encoding'] == 'csv'
					for line in [x for x in d.text.splitlines() if len(x)]:
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
					for p in level[0]:
						if p.attrib['name'] == 'Directions':
							pass
						elif p.attrib['name'] == 'Level':
							destination = p.attrib['value']
							print("%d %d %s" % (x, y, destination))
			elif e.attrib['name'].lower() == 'sprites':
				for sprite in e:
					gid = int(sprite.attrib['gid'])
					xflip = (gid & 0x80000000) != 0
					yflip = (gid & 0x40000000) != 0
					gid   = gid & 0x0fffffff
					tile  = identify_tile(gid)
					priority = False
					if len(sprite):
						assert sprite[0].tag == 'properties'
						for property in sprite[0]:
							if property.attrib['name'] == 'Priority':
								priority = property.attrib['value'] == 'true'
					attribs = (64 if xflip else 0)|(128 if yflip else 0)
					data = (tile, int(sprite.attrib['x']), int(sprite.attrib['y'])-16, attribs)
					if priority:
						map_priority_sprites.append(data)
					else:
						map_sprites.append(data)

	# Sort by Y position
	map_sprites = sorted(map_sprites, key=lambda r: r[1])
	map_priority_sprites = sorted(map_priority_sprites, key=lambda r: r[1])

	# Find runs of the same block
	map_bg = sum(map_bg, []) # Flatten
	compressed_map = []
	for block in map_bg:
		# Make a new entry
		if len(compressed_map) == 0 or compressed_map[-1][0] != block or compressed_map[-1][1] == 127:
			compressed_map.append([block, 0])
		# The last entry was repeated once
		else:
			compressed_map[-1][1] = compressed_map[-1][1]+1

	# Output graphics used to the file
	outfile.write('  ; Graphics\n  .byt ')
	for graphic in map_graphics:
		outfile.write('GraphicsUpload::%s, ' % graphic)
	outfile.write('255\n')

	# Output palettes used to the file
	outfile.write('  ; Palettes\n  .byt ')
	for palette in map_palettes:
		outfile.write('Palette::%s, ' % palette)
	outfile.write('255\n')

	# Output sprite graphics used to the file
	outfile.write('  ; Sprite graphics\n  .byt ')
	for graphic in map_spritegraphics:
		outfile.write('GraphicsUpload::%s, ' % graphic)
	outfile.write('255\n')

	# Output sprite palettes used to the file
	outfile.write('  ; Sprite palettes\n  .byt ')
	for palette in map_spritegraphics:
		outfile.write('Palette::%s, ' % palette)
	outfile.write('255\n')

	# Output the map to the file
	outfile.write('  ; Compressed map\n  .byt ')
	for block in compressed_map:
		# Repeat?
		if block[1]:
			outfile.write('128|%d, ' % (block[1]-1))
		outfile.write('OverworldBlock::%s, ' % block[0])
	outfile.write('255\n')

	# Output the decorative priority sprites to the file
	outfile.write('  ; Decorative priority sprites\n  .byt ')
	for sprite in map_priority_sprites:
		outfile.write('OWDecoration::%s, %d, %d, %d, ' % sprite)
	outfile.write('255\n')

	# Output the decorative sprites to the file
	outfile.write('  ; Decorative regular sprites\n  .byt ')
	for sprite in map_sprites:
		outfile.write('OWDecoration::%s, %d, %d, %d, ' % sprite)
	outfile.write('255\n')



	outfile.write('\n\n')


outfile.write('.export Overworld_Pointers\n')
outfile.write('Overworld_Pointers:\n')
for ow in all_overworlds:
	outfile.write('  .addr $ffff & Overworld_%s\n' % ow)
outfile.close()
