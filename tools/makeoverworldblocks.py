# Like makeblocks.py but for the overworld.
# I should probably figure out how to share code between them,
# to keep them from becoming out of sync if nothing else

# Helper functions
def separateFirstWord(text, lowercaseFirst=True):
	space = text.find(" ")
	command = text
	arg = ""
	if space >= 0:
		command = text[0:space]
		arg = text[space+1:]
	if lowercaseFirst:
		command = command.lower()
	return (command, arg)

def parseNumber(number):
	if number in aliases:
		return parseNumber(aliases[number])
	if number.startswith("$"):
		return int(number[1:], 16)
	return int(number)

def parseTile(tile):
	""" Parse the nametable value for one tile """
	global default_palette, default_base
	value = default_base

	if tile.find(":") >= 0: # Base override
		split = tile.split(":")
		value = parseNumber(split[0])
		tile = split[1]
	value = value//32      # Divide by the bytes per tile to get tile number

	if tile.endswith("v"): # Vertical flip
		value |= 0x8000
		tile = tile[:-1]
	if tile.endswith("h"): # Horizontal flip
		value |= 0x4000
		tile = tile[:-1]
	if tile.endswith("_"): # No-op separator
		tile = tile[:-1]

	if priority:
		value |= 0x2000
	# Palette
	value |= default_palette << 10

	# Read the tile number in the format of x,y starting from the specified base
	if tile.find(",") >= 0:
		split = [parseNumber(s) for s in tile.split(",")]
		value += split[0]+split[1]*16
	else:
		value += parseNumber(tile)
	return value


# Globals
aliases = {}
default_palette = 0
default_base = 0
block = None
priority = False
all_blocks = []

# Read and process the file
with open("tools/overworldblocks.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

def saveBlock():
	if block == None:
		return
	all_blocks.append(block)

# Nametable format:
# Bit 0-9   - Character Number (000h-3FFh)
# Bit 10-12 - Palette Number   (0-7)
# Bit 13    - BG Priority      (0=Lower, 1=Higher)
# Bit 14    - X-Flip           (0=Normal, 1=Mirror horizontally)
# Bit 15    - Y-Flip           (0=Normal, 1=Mirror vertically)

for line in text:
	if not len(line):
		continue
	if line.startswith("#"): # comment
		continue
	if line.startswith("+"): # new block
		saveBlock()
		# Reset to prepare for the new block
		priority = False
		block = {"name": line[1:], "tiles": []}
		continue
	word, arg = separateFirstWord(line)
	# Miscellaneous directives
	if word == "alias":
		name, value = separateFirstWord(arg)
		aliases[name] = value

	# Tile info shared with several blocks
	elif word == "base":
		default_base = parseNumber(arg)
	elif word == "palette":
		default_palette = parseNumber(arg)

	# Specifying tiles and tile attributes
	elif word == "priority":
		priority = True
	elif word == "no_priority":
		priority = False
	elif word == "t": # add tiles
		split = arg.split(" ")
		for tile in split:
			block["tiles"].append(parseTile(tile))
	elif word == "q": # add four tiles at once
		tile = parseTile(arg)
		block["tiles"] = [tile, tile+1, tile+16, tile+17]

# Save the last one
saveBlock()

# Generate the output that's actually usable in the game
outfile = open("src/overworldblockdata.s", "w")

outfile.write('; This is automatically generated. Edit "overworldblocks.txt" instead\n')
outfile.write('.export OWBlockTopLeft, OWBlockTopRight, OWBlockBottomLeft, OWBlockBottomRight\n')
outfile.write('\n.segment "Overworld"\n\n')

# Block appearance information
corners = ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]
for corner in range(len(corners)):
	outfile.write(".proc OWBlock%s\n" % corners[corner])
	for b in all_blocks:
		outfile.write('  .word $%.4x ; %s\n' % (b['tiles'][corner], b['name']))
	outfile.write(".endproc\n\n")
outfile.close()

# Generate the enum in a separate file
outfile = open("src/overworldblockenum.s", "w")
outfile.write('; This is automatically generated. Edit "overworldblocks.txt" instead\n')
outfile.write('.enum OverworldBlock\n')
block_counter = 0
for b in all_blocks:
	outfile.write('  %s = %d\n' % (b['name'], block_counter))
	block_counter += 1
outfile.write('.endenum\n\n')