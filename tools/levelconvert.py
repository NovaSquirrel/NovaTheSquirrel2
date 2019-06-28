import json
import glob

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

	if ratio == 1:
		return "LObjN LO::Slope%s_Steep, %d, %d, %d, %d" % (lr, offset, y, r.w-1, r.h-1), 3
	elif ratio == 2:
		return "LObjN LO::Slope%s_Medium, %d, %d, %d, %d" % (lr, offset, y, r.w//2-1, r.h-1), 3
	elif ratio == 4:
		return "LObjN LO::Slope%s_Gradual, %d, %d, %d, %d" % (lr, offset, y, r.w//4-1, r.h-1), 3
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

	for l in output:
		print(l)

	return output


for f in glob.glob("levels/*.json"):
	level_file = open(f)
	level_text = level_file.read()
	level_file.close()
	level_json = json.loads(level_text)

	num_layers = len(level_json["Layers"])

	foreground = []
	for z in range(len(level_json["Layers"][0]["Data"])):
		foreground.append(Rect(level_json["Layers"][0]["Data"][z], z))
	sprites = [Rect(x) for x in level_json["Layers"][1]["Data"]]
	control = [Rect(x) for x in level_json["Layers"][2]["Data"]]

	convert_layer(foreground)

	print(foreground)

