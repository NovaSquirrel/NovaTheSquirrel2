#!/usr/bin/env python3
from nts2shared import *

# Globals
block = None
all_blocks = []
all_classes = set()
all_interaction_procs = set()
all_interaction_sets = []

# Read and process the file
with open("tools/m7blocks.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

def saveBlock():
	if block == None:
		return
	if block['interaction'] != {}:
		# If there is already a interaction set that matches, use that one
		# otherwise add a new one
		if block['interaction'] not in all_interaction_sets:
			all_interaction_sets.append(block['interaction'])
		block['interaction_set'] = all_interaction_sets.index(block['interaction']) + 1 # + 1 because zero is no interaction

	all_blocks.append(block)

for line in text:
	if not len(line):
		continue
	if line.startswith("#"): # comment
		continue
	if line.startswith("+"): # new block
		saveBlock()
		# Reset to prepare for the new block
		priority = False
		block = {"name": line[1:], "solid": False, "solid_air": False, "show_barrier": False, \
		  "solid_block": False, "solid_creature": False, "tiles": [], "interaction": {}, "interaction_set": 0, "class": "None"}
		continue
	word, arg = separateFirstWord(line)
	# Miscellaneous directives
	if word == "alias":
		name, value = separateFirstWord(arg)
		aliases[name] = value

	elif word == "when": #Behaviors
		arg = arg.split(", ")

		# Aliases for selecting multiple interaction types at once
		if arg[0] == "Enter":
			arg[0] = ("StepOn", "JumpOn")
		elif arg[0] == "Exit":
			arg[0] = ("StepOff", "JumpOff")
		else:
			arg[0] = (arg[0],)

		for i in arg[0]:
			block["interaction"][i] = arg[1]
		all_interaction_procs.add(arg[1])
	elif word == "class":
		block["class"] = arg
		all_classes.add(arg)

	# Specifying tiles and tile attributes
	elif word == "impassable":
		block['solid'] = True
		block['solid_air'] = True
		block['solid_block'] = True
		block['show_barrier'] = True
	elif word in ["solid", "solid_air", "solid_block", "solid_creature", "show_barrier"]:
		block[word] = True
	elif word == "t": # add tiles
		split = arg.split(" ")
		for tile in split:
			block["tiles"].append(parseMetatileTile(tile, 0, 0, 0))
	elif word == "q": # add four tiles at once
		tile = parseMetatileTile(arg, 0, 0, 0)
		block["tiles"] = [tile, tile+1, tile+16, tile+17]
	elif word == "w": # add four tiles at once, but wide
		tile = parseMetatileTile(arg, 0, 0, 0)
		block["tiles"] = [tile, tile+1, tile+2, tile+3]

# Save the last one
saveBlock()

# Generate the output that's actually usable in the game
outfile = open("src/mode7/m7blockdata.s", "w")

outfile.write('; This is automatically generated. Edit "blocks.txt" instead\n')
outfile.write('.include "m7blockenum.s"\n\n')
outfile.write('.export M7BlockTopLeft, M7BlockTopRight, M7BlockBottomLeft, M7BlockBottomRight\n')
outfile.write('.export M7BlockFlags, M7BlockInteractionSet, M7BlockInteractionStepOn, M7BlockInteractionStepOff, M7BlockInteractionBump, M7BlockInteractionJumpOn, M7BlockInteractionJumpOff, M7BlockInteractionTouching\n')
outfile.write('.import %s\n' % str(", ".join(all_interaction_procs)))
outfile.write('\n.segment "C_Mode7Game"\n\n') # Put it in the game segment

# Block appearance information
corners = ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]
for corner, cornername in enumerate(corners):
	outfile.write(".proc M7Block%s\n" % cornername)
	for b in all_blocks:
		outfile.write('  .byt $%.2x ; %s\n' % (b['tiles'][corner], b['name']))
	outfile.write(".endproc\n\n")

# Write block interaction information
outfile.write('.proc M7BlockFlags\n')
for b in all_blocks:
	flags = 0
	if b['solid']:
		flags |= 1
	if b['solid_air']:
		flags |= 2
	if b['solid_block']:
		flags |= 4
	if b['solid_creature']:
		flags |= 8
	if b['show_barrier']:
		flags |= 16
	outfile.write('  .byt %d ; %s\n' % (flags, b['name']))
outfile.write('.endproc\n\n')

outfile.write('.proc M7BlockInteractionSet\n')
for b in all_blocks:
	outfile.write('  .byt %d ; %s\n' % (b['interaction_set'], b['name']))
outfile.write('.endproc\n\n')

outfile.write(".proc M7BlockNothing\n  rts\n.endproc\n\n")

print("Interaction sets: %d" % len(all_interaction_sets))

# Write all interaction type tables corresponding to each interaction set
interaction_types = ["StepOn", "StepOff", "Bump", "JumpOn", "JumpOff", "Touching"]
for interaction in interaction_types:
	outfile.write(".export M7BlockInteraction%s\n" % interaction)
	outfile.write(".proc M7BlockInteraction%s\n" % interaction)
	outfile.write('  .addr .loword(M7BlockNothing-1)\n') # Empty interaction set
	for b in all_interaction_sets:
		if interaction in b:
			outfile.write('  .addr .loword(%s-1)\n' % b[interaction])
		else:
			outfile.write('  .addr .loword(M7BlockNothing-1)\n')
	outfile.write(".endproc\n\n")

outfile.close()

# Generate the enum in a separate file
outfile = open("src/mode7/m7blockenum.s", "w")
outfile.write('; This is automatically generated. Edit "m7blocks.txt" instead\n')
outfile.write('.enum Mode7Block\n')
for b in all_blocks:
	outfile.write('  %s\n' % (b['name']))
outfile.write('.endenum\n\n')

# Generate the class enum
outfile.write('.enum Mode7BlockClass\n')
outfile.write('  None\n')
for b in all_classes:
	outfile.write('  %s\n' % b)
outfile.write('.endenum\n\n')

outfile.close()
