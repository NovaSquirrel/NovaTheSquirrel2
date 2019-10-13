import json, glob, os

# -------------------------------------
# Parse the level data definition file
# -------------------------------------

define_file = open("src/leveldata.inc")
define_lines = [x.strip() for x in define_file.readlines()]
define_file.close()

available_singles = set()
available_rectangles = set()
available_nybble = [set(), set(), set()]
available_state = None
available_special = {} # Uses a Python function to handle it

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
	for i in range(len(available_nybble)):
		if id in available_nybble[i]:
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
			self.extra = j

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
		y += r.h - 1

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

def convert_layer(layer):
	# Sort by X coordinate
	layer = sorted(layer, key=lambda r: r.x)

	# Check if any reordering needs to happen
	for i in range(len(layer)):
		r1 = layer[i]
		for j in range(i):
			r2 = layer[j]
			if r1.overlaps(r2) and r1.z < r2.z:
				layer[i], layer[j] = layer[j], layer[i]

	byte_count, column, output = 0, 0, []

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
			output.append('LSetX')
			offset = 0
			column = r.x
			byte_count += 2

		# Decide the smallest way to represent this rectangle
		if r.type in available_special:
			o, s = available_special[r.type](r, offset)
			output.append(o)
			byte_count += s
		elif r.w == 1 and r.h == 1 and r.type in available_singles:
			output.append("LObj  LO::S_%s, %d, %d" % (r.type, offset, r.y))
			byte_count += 2
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
		elif r.w <= 256 and r.h <= 16 and is_available_nybble(r.type):
			which = which_nybble_list(r.type)
			output.append("LObjN LO::Rect%d, %d, %d, %d, LN%d::%s, %d" % (which, offset, r.y, r.h-1, which, r.type, r.w-1))
			byte_count += 4
		elif r.w == 1 and r.h == 1:
			output.append("LSCustom Block::%s, %d, %d" % (r.type, offset, r.y))
			byte_count += 2
		elif r.w <= 16 and r.h <= 16:
			output.append("LRCustom Block::%s, %d, %d, %d, %d" % (r.type, offset, r.y, r.w-1, r.h-1))
			byte_count += 3
		else:
			print("Unhandled rectangle: %s" % r)

	return output, byte_count

all_levels = []

outfile = open("src/leveldata.s", "w")
outfile.write('; This is automatically generated. Edit level JSON files instead\n')
outfile.write('.include "snes.inc"\n')
outfile.write('.include "actorenum.s"\n')
outfile.write('.include "graphicsenum.s"\n')
outfile.write('.include "paletteenum.s"\n')
outfile.write('.include "blockenum.s"\n')
outfile.write('.include "leveldata.inc"\n\n')
outfile.write('.segment "LevelBank1"\n\n')

for f in glob.glob("levels/*.json"):
	plain_name = os.path.splitext(os.path.basename(f))[0]
	all_levels.append(plain_name)
	outfile.write(".export level_%s\n" % plain_name)
	outfile.write("level_%s:\n" % plain_name)

	level_file = open(f)
	level_text = level_file.read()
	level_file.close()
	level_json = json.loads(level_text)

	num_layers = len(level_json["Layers"])

	foreground = []
	for z in range(len(level_json["Layers"][0]["Data"])):
		foreground.append(Rect(level_json["Layers"][0]["Data"][z], z))
	actors = [Rect(x) for x in level_json["Layers"][1]["Data"]]
	control = [Rect(x) for x in level_json["Layers"][2]["Data"]]

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

    # Write the header
	outfile.write('  .byt %d|0\n' % (0x80 if player_dir else 0)) # Music and starting direction
	outfile.write('  .byt %d\n' % player_x)
	outfile.write('  .byt %d\n' % player_y)
	outfile.write('  .byt 0\n') # flags
	outfile.write('  .word %s\n' % level_json["Header"]["BGColor"])
	if level_json["Header"]["Background"]:
		outfile.write('  .word %s\n' % level_json["Header"]["Background"])
	else:
		outfile.write('  .word $ffff\n')
	outfile.write('  .addr .loword(level_%s_sp)\n' % plain_name)
	outfile.write('  .dbyt %d\n\n' % boundaries)
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
	for line in fg_data:
		outfile.write("  %s\n" % line)
	outfile.write("  LFinished\n\n")

	# Write the actor data
	actors = sorted(actors, key=lambda r: r.x)
	outfile.write("level_%s_sp:\n" % plain_name)
	for actor in actors:
		if len(actor.extra):
			outfile.write("  LSpr Actor::%s, %d, %d, %d, %s\n" % (actor.type, (1 if actor.xflip else 0), actor.x, actor.y, actor.extra))
		else:
			outfile.write("  LSpr Actor::%s, %d, %d, %d\n" % (actor.type, (1 if actor.xflip else 0), actor.x, actor.y))
		total_level_size += 4
	outfile.write("  .byt 255\n\n")

	outfile.write("\n")
	print("Total size: %d" % total_level_size)
outfile.close()

# Generate the enum in a separate file
outfile = open("src/levelenum.s", "w")
outfile.write('; This is automatically generated. Edit level JSON files instead\n')
outfile.write('.enum Level\n')
for b in all_levels:
	outfile.write('  %s\n' % b)
outfile.write('.endenum\n\n')
