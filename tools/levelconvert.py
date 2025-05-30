#!/usr/bin/env python3
import json, glob, os, sys

# -------------------------------------
# Parse the level data definition file
# -------------------------------------

define_file = open("src/leveldata.inc")
define_lines = [x.strip() for x in define_file.readlines()]
define_file.close()

available_singles = set()
available_rectangles = set()
available_nybble = [set(), set(), set(), set()]
available_state = None
available_special = {} # Uses a Python function to handle it
has_metadata = {} # Uses a Python function to insert metadata

# Per-level global state
teleport_destinations = {}
door_level_teleport_list = [] # List of levels, for doors that lead to other levels
vertical_level = False
horizontal_tall_level = False

for line in define_lines:
	if not len(line): # Skip empty lines
		continue
	if line == '.enum LO': # Start processing
		available_state = 0
	if line.startswith('.macro'): # The enums are done
		break
	if available_state == None:
		continue

	# Record the level commands it finds
	if available_state == 0:
		if line.startswith("S_"):
			available_singles.add(line[2:])
		if line.startswith("R_"):
			available_rectangles.add(line[2:])
	elif not line.startswith("."):
		available_nybble[available_state-1].add(line)
	if line.startswith(".enum LN"):
		available_state = int(line[-1])

def is_available_nybble(id):
	for s in available_nybble:
		if id in s:
			return True
	return False

def which_nybble_list(id):
	for i, v in enumerate(available_nybble):
		if id in v:
			return i+1

# -------------------------------------
# Parse the level JSON files
# -------------------------------------

class Rect(object):
	def __init__(self, j, z=None):
		self.type = j['Id']
		self.x = j['X']
		self.y = j['Y']
		self.z = z
		self.w = j['W']
		self.h = j['H']
		self.xflip = 'XFlip' in j
		self.yflip = 'YFlip' in j
		self.extra = ''
		if 'Extra' in j:
			self.extra = j['Extra']

	def __repr__(self):
		return '%s %d,%d %dx%d' % (self.type, self.x, self.y, self.w, self.h)

	def overlaps(self, other):
		if self.x > (other.x+other.w-1):
			return False
		if (self.x+self.w-1) < other.x:
			return False
		if self.y > (other.y+other.h-1):
			return False
		if (self.y+self.h-1) < other.y:
			return False
		return True

def encode_slope(r, offset):
	ratio = r.w / r.h
	y = r.y

	lr = 'R'
	if not r.xflip:
		lr = 'L'

	# Currently do not encode a height
	if ratio == 1:
		return "LObjN LO::Slope%s_Steep, %d, %d, %d, %d" % (lr, offset, y, r.w-1, 0), 3
	elif ratio == 2:
		return "LObjN LO::Slope%s_Medium, %d, %d, %d, %d" % (lr, offset, y, r.w//2-1, 0), 3
	elif ratio == 4:
		return "LObjN LO::Slope%s_Gradual, %d, %d, %d, %d" % (lr, offset, y, r.w//4-1, 0), 3
	else:
		print("Unhandled slope ratio %f" % ratio)
available_special['LedgeSlope'] = encode_slope

def add_import(s):
	if s in all_imports:
		return
	all_imports.add(s)
	outfile.write('.import %s\n' % s)

def write_column_data(data):
	b = data.count(',')
	data = "LWriteCol "+data
	if b < 3:
		return data, b
	else:
		return data, b+1 # One more byte for the byte count

def encode_sign(r, extra):
	symbol = 'DialogScene_' + extra
	add_import(symbol)
	return write_column_data("<%s, >%s, ^%s" % (symbol, symbol, symbol))

def encode_door(r, extra):
	dashes = extra.split('-')
	if len(dashes) == 2: # A-B two-way door
		if dashes[1] in teleport_destinations:
			d = teleport_destinations[dashes[1]]
			return write_column_data("%d, %d" % (d[1], d[0])) # Y and then X
		else:
			sys.exit("Teleport destination "+dashes[1]+" not found")
	elif len(dashes) == 1: # Level door
		if extra not in door_level_teleport_list:
			door_level_teleport_list.append(extra)
		return write_column_data("$20, %d ;%s" % (door_level_teleport_list.index(extra), extra)) # level number
	sys.exit("Invalid door: "+extra)
	return (""), 0

has_metadata['Sign'] = encode_sign
has_metadata['DialogPoint'] = encode_sign
has_metadata['DoorTwoWay'] = encode_door
has_metadata['DoorTop'] = encode_door

def convert_layer(layer):
	if vertical_level: # Sort by Y coordinate
		layer = sorted(layer, key=lambda r: r.y)
	else:              # Sort by X coordinate
		layer = sorted(layer, key=lambda r: r.x)

	# Check if any reordering needs to happen
	for i, r1 in enumerate(layer):
		for j in range(i):
			r2 = layer[j]
			if r1.overlaps(r2) and r1.z < r2.z:
				layer[i], layer[j] = layer[j], layer[i]

	# Adjust slopes here, because adjusting them in encode_slope wouldn't play nice with vertical levels
	for r in layer:
		if r.type == 'LedgeSlope':
			if not r.xflip:
				r.y += r.h - 1

	# Vertical levels swap the meaning of X and Y
	if vertical_level:
		for r in layer:
			r.x, r.y = r.y, r.x

	byte_count, column, output = 0, 0, []
	y_extension = False # For tracking when to toggle the Y extension

	# Process each rectangle
	for r in layer:
		offset = r.x - column
		column = r.x

		if offset >= 0 and offset <= 15: # Within normal range
			pass
		elif offset >= -16 and offset <= -1:
			output.append('LXMinus16')
			offset += 16
			byte_count += 1
		elif offset >= 16 and offset <= 31:
			output.append('LXPlus16')
			offset -= 16
			byte_count += 1
		else: # Just directly set the right column then
			output.append('LSetX %d' % r.x)
			offset = 0
			column = r.x
			byte_count += 2

		if (not y_extension and r.y >= 32) or (y_extension and r.y < 32):
			output.append("LToggleYExtension")
			byte_count += 1
			y_extension = not y_extension
		r.y &= 31

		# Decide the smallest way to represent this rectangle
		if r.type in available_special:
			o, s = available_special[r.type](r, offset)
			output.append(o)
			byte_count += s
		elif r.w == 1 and r.h == 1 and r.type in available_singles:
			output.append("LObj  LO::S_%s, %d, %d" % (r.type, offset, r.y))
			byte_count += 2
		elif r.w == 1 and r.h == 1: # I think LSByteRef is slightly faster than using a Wide command with a width of 1 block
			output.append("LSByteRef BlockByteReference::%s, %d, %d" % (r.type, offset, r.y))
			byte_count += 3
		elif r.w <= 16 and r.h <= 16 and r.type in available_rectangles:
			output.append("LObjN LO::R_%s, %d, %d, %d, %d" % (r.type, offset, r.y, r.w-1, r.h-1))
			byte_count += 3
		elif r.w <= 16 and r.h == 1 and is_available_nybble(r.type):
			which = which_nybble_list(r.type)
			output.append("LObjN LO::Wide%d, %d, %d, %d, LN%d::%s" % (which, offset, r.y, r.w-1, which, r.type))
			byte_count += 3
		elif r.w == 1 and r.h <= 16 and is_available_nybble(r.type):
			which = which_nybble_list(r.type)
			output.append("LObjN LO::Tall%d, %d, %d, %d, LN%d::%s" % (which, offset, r.y, r.h-1, which, r.type))
			byte_count += 3
		elif r.w <= 16 and r.h <= 16: # I think LRByteRef is slightly faster than using a Rect command
			output.append("LRByteRef BlockByteReference::%s, %d, %d, %d, %d" % (r.type, offset, r.y, r.w-1, r.h-1))
			byte_count += 4
		elif r.w <= 256 and r.h <= 16 and is_available_nybble(r.type):
			which = which_nybble_list(r.type)
			output.append("LObjN LO::Rect%d, %d, %d, %d, LN%d::%s, %d" % (which, offset, r.y, r.h-1, which, r.type, r.w-1))
			byte_count += 4
		elif r.w <= 256 and r.h <= 256:
			output.append("LHByteRef BlockByteReference::%s, %d, %d, %d, %d" % (r.type, offset, r.y, r.w-1, r.h-1))
			byte_count += 5
		# TODO: Use LSCustom and LRCustom for blocks that LSByteRef and LRByteRef don't work on (that is, anything that isn't in the byte reference table)
		# but right now the level editor only shows blocks that are in that table anyway.
#		elif r.w == 1 and r.h == 1:
#			output.append("LSCustom Block::%s, %d, %d" % (r.type, offset, r.y))
#			byte_count += 4
#		elif r.w <= 16 and r.h <= 16:
#			output.append("LRCustom Block::%s, %d, %d, %d, %d" % (r.type, offset, r.y, r.w-1, r.h-1))
#			byte_count += 5
		else:
			print("Unhandled rectangle: %s" % r)

		# Encode metadata if it's present
		if (r.type in has_metadata) and len(r.extra):
			o, s = has_metadata[r.type](r, r.extra)
			output.append(o)
			byte_count += s

	return output, byte_count

all_levels = []
all_imports = set()

outfile = open("src/leveldata.s", "w")
outfile.write('; This is automatically generated. Edit level JSON files instead\n')
outfile.write('.include "snes.inc"\n')
outfile.write('.include "actorenum.s"\n')
outfile.write('.include "graphicsenum.s"\n')
outfile.write('.include "paletteenum.s"\n')
outfile.write('.include "backgroundenum.s"\n')
outfile.write('.include "blockenum.s"\n')
outfile.write('.include "color_math_settings_enum.s"\n')
outfile.write('.include "leveldata.inc"\n\n')
outfile.write('.segment "LevelBank1"\n\n')

for f in glob.glob("levels/*.json"):
	teleport_destinations.clear()

	plain_name = os.path.splitext(os.path.basename(f))[0]
	all_levels.append(plain_name)
	outfile.write(".export level_%s\n" % plain_name)
	outfile.write("level_%s:\n" % plain_name)

	level_file = open(f)
	level_text = level_file.read()
	level_file.close()
	level_json = json.loads(level_text)

	num_layers = len(level_json["Layers"])
	vertical_level = level_json["Meta"]["Width"] == 32 and level_json["Meta"]["Height"] > 32
	horizontal_tall_level = level_json["Meta"]["Width"] > 32 and level_json["Meta"]["Height"] > 32

	if (level_json["Meta"]["Width"] > 256) or (level_json["Meta"]["Height"] > 256) or (horizontal_tall_level and level_json["Meta"]["Height"] > 64):
		sys.exit(f+" has an invalid level shape")

	foreground = []
	secondary = []
	for z, v in enumerate(level_json["Layers"][0]["Data"]):
		foreground.append(Rect(v, z))
	if level_json["Layers"][1]["Type"] == "Rectangle":
		for z, v in enumerate(level_json["Layers"][1]["Data"]):
			secondary.append(Rect(v, z))
		actors = [Rect(x) for x in level_json["Layers"][2]["Data"]]
		control = [Rect(x) for x in level_json["Layers"][3]["Data"]]
	else:
		actors = [Rect(x) for x in level_json["Layers"][1]["Data"]]
		control = [Rect(x) for x in level_json["Layers"][2]["Data"]]

	# Find teleport destinations
	for r in foreground:
		if r.type in ['DoorTop', 'DoorTwoWay']:
			dashes = r.extra.split("-")
			if len(dashes) == 2 and len(dashes[0]):
				teleport_destinations[dashes[0]] = (r.x, r.y+2)
	for r in control:
		if r.type == 'TELEPORT_DESTINATION':
			teleport_destinations[r.extra] = (r.x, r.y)

	# ---------------------------------
	player_x, player_y, player_dir = 5, 5, False
	total_level_size = 33

	boundaries = 0;
	def set_boundary_at(screen, boundaries):
		if screen < 1:
			return
		if screen > 16:
			return
		bit = 1 << 16-screen
		return boundaries | bit

	# Apply some control commands
	control_commands = []
	for r in control:
		if r.type == 'PLAYER_START_R' or r.type == 'PLAYER_START_L':
			player_x = r.x
			player_y = r.y+1
			player_dir = r.type[-1] == 'L'
		if r.type == 'SCROLL_LOCK':
			screen = (r.x//16);
			if r.x&15 == 15:
				boundaries = set_boundary_at(screen+1, boundaries);
			else:
				boundaries = set_boundary_at(screen, boundaries);
		if r.type == 'LEVEL_EFFECT':
			control_commands.append('.byt LSpecialCmd, LevelSpecialConfig::%s' % r.extra)
			total_level_size += 2 + r.extra.count(',')
			if r.extra == 'ActorListInRAM':
				control_commands.append('.byt %d' % len(actors))
				total_level_size += 1

    # Write the header
	outfile.write('  .byt %d|0\n' % (0x80 if player_dir else 0)) # Music and starting direction
	outfile.write('  .byt %d\n' % (player_y if vertical_level else player_x))
	outfile.write('  .byt %d\n' % (player_x if vertical_level else player_y))
	flags = 0x00 + vertical_level*0x01 + horizontal_tall_level*0x02
	for flag in level_json["Header"]["Flags"]:
		if flag == "TwoLayerLevel": # Probably pull it from the layer count instead
			flags |= 0x80
		elif flag == "TwoLayerInteraction":
			flags |= 0x40
		elif flag == "ForegroundLayerThree":
			flags |= 0x20
		elif flag == "VerticalScrolling":
			flags |= 0x10
	# In order: two-layer, two-layer interaction, foreground layer 3, vertical scrolling, unused, unused, level shape, level shape

	outfile.write('  .byt $%.2x\n' % flags)
	outfile.write('  .word %s\n' % level_json["Header"]["BGColor"])
	if level_json["Header"]["Background"]:
		outfile.write('  .byt LevelBackground::%s\n' % level_json["Header"]["Background"])
	else:
		outfile.write('  .byt 255\n') # No background

	outfile.write('  .byt ColorMathSettings::%s\n' % level_json["Header"].get("ColorMath", "Default"))

	outfile.write('  .addr .loword(level_%s_sp)\n' % plain_name)
	#outfile.write('  .dbyt %d\n\n' % boundaries)
	for i in range(8):
		if (len(level_json["Header"]["SpriteGFX"]) > i) and level_json["Header"]["SpriteGFX"][i]:
			outfile.write('  .byt GraphicsUpload::%s\n' % level_json["Header"]["SpriteGFX"][i])
		else:
			outfile.write('  .byt 255\n')
	outfile.write('\n')

	for i in range(8):
		if (len(level_json["Header"]["BGPalette"]) > i) and level_json["Header"]["BGPalette"][i]:
			outfile.write('  .byt Palette::%s\n' % level_json["Header"]["BGPalette"][i])
		else:
			outfile.write('  .byt 255\n')
	outfile.write('\n')

	for i in level_json["Header"]["GFXUpload"]:
		outfile.write('  .byt GraphicsUpload::%s\n' % i)
		total_level_size += 1
	outfile.write('  .byt 255\n')

	outfile.write('  .addr .loword(level_%s_fg)\n\n' % plain_name)

	# Write the foreground data
	fg_data, fg_size = convert_layer(foreground)
	total_level_size += fg_size
	outfile.write("level_%s_fg:\n" % plain_name)
	for c in control_commands:
		outfile.write("  %s\n" % c)
	for line in fg_data:
		outfile.write("  %s\n" % line)
	if secondary != []:
		outfile.write("  .byt LSpecialCmd, LevelSpecialConfig::AlternateBuffer\n")
		total_level_size += 2

		# Write the secondary foreground data
		fg_data, fg_size = convert_layer(secondary)
		total_level_size += fg_size
		for line in fg_data:
			outfile.write("  %s\n" % line)
	outfile.write("  LFinished\n\n")

	# Vertical levels swap the X and Y fields
	if vertical_level:
		for actor in actors:
			actor.x, actor.y = actor.y, actor.x

	# Write the actor data
	actors = sorted(actors, key=lambda r: r.x)
	if len(actors) > 256:
		print("Warning: Level %s has %d actors, which is over the limit (256)" % (plain_name, len(actors)))
	outfile.write("level_%s_sp:\n" % plain_name)
	for actor in actors:
		if len(actor.extra):
			outfile.write("  LSpr Actor::%s, %d, %d, %d, %s\n" % (actor.type, (1 if actor.xflip else 0), actor.x, actor.y, actor.extra))
		else:
			outfile.write("  LSpr Actor::%s, %d, %d, %d\n" % (actor.type, (1 if actor.xflip else 0), actor.x, actor.y))
		total_level_size += 4
	outfile.write("  .byt 255\n\n")

	outfile.write("\n")
	print("Total size: %d (%s)" % (total_level_size, plain_name))

outfile.write('.segment "C_BlockInteraction"\n')
outfile.write('.export DoorLevelTeleportList\nDoorLevelTeleportList:\n')
for level in door_level_teleport_list:
	outfile.write('.faraddr level_%s\n' % level)
outfile.close()

# Nothing seems to use the below enum, so don't generate it
## Generate the enum in a separate file
#outfile = open("src/levelenum.s", "w")
#outfile.write('; This is automatically generated. Edit level JSON files instead\n')
#outfile.write('.enum Level\n')
#for b in all_levels:
#	outfile.write('  %s\n' % b)
#outfile.write('.endenum\n\n')
