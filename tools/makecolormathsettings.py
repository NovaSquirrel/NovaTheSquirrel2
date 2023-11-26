#!/usr/bin/env python3
from nts2shared import *

# Globals
entry = None
all_entries = []

# Read and process the file
with open("tools/color_math_settings.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

def saveEntry():
	if entry == None:
		return
	all_entries.append(entry)

def layerToBit(name):
	layers = ("1", "2", "3", "4", "OBJ", "BGCOLOR")
	return 1 << layers.index(name.strip().upper())

for line in text:
	if not len(line):
		continue
	if line.startswith("#"): # comment
		continue
	if line.startswith("+"): # new item
		saveEntry()
		# Reset to prepare for the new entry
		entry = {"name": line[1:], "mode": "1", "main": 0, "sub": 0, "cgadsub": 0, "options": 2}
		continue
	word, arg = separateFirstWord(line)

	# Attributes
	if word == "mode":
		entry[word] = arg
	elif word == "main":
		for a in arg.split(","):
			entry["main"] |= layerToBit(a)
	elif word == "sub":
		for a in arg.split(","):
			entry["sub"] |= layerToBit(a)
	elif word == "math":
		for a in arg.split(","):
			entry["cgadsub"] |= layerToBit(a)

	elif word == "coldata=bgcolor":
		entry["options"] |= 0x01
	elif word == "fixed_color_only":
		entry["options"] &= ~0x02
	elif word == "sub_screen_hires":
		entry["options"] |= 0x08

	elif word == "halve":
		entry["cgadsub"] |= 0x40
	elif word == "subtract":
		entry["cgadsub"] |= 0x80
	elif word == "average":
		entry["cgadsub"] |= 0xC0

# Save the last one
saveEntry()

#######################################

# Generate the output that's actually usable in the game
outfile = open("src/color_math_settings.s", "w")

outfile.write('; This is automatically generated. Edit "color_math_settings.txt" instead\n')
outfile.write('.include "snes.inc"\n')

outfile.write('.export ColorMathTableBGMODE, ColorMathTableBLENDMAIN, ColorMathTableBLENDSUB, ColorMathTableCGADSUB, ColorMathTableOptions\n\n')

outfile.write('.proc ColorMathTableBGMODE\n')
for b in all_entries:
	outfile.write('  .byt %s ; %s\n' % (b["mode"], b["name"]))
outfile.write('.endproc\n\n')

outfile.write('.proc ColorMathTableBLENDMAIN\n')
for b in all_entries:
	outfile.write('  .byt $%.2x ; %s\n' % (b["main"], b["name"]))
outfile.write('.endproc\n\n')

outfile.write('.proc ColorMathTableBLENDSUB\n')
for b in all_entries:
	outfile.write('  .byt $%.2x ; %s\n' % (b["sub"], b["name"]))
outfile.write('.endproc\n\n')

outfile.write('.proc ColorMathTableCGADSUB\n')
for b in all_entries:
	outfile.write('  .byt $%.2x ; %s\n' % (b["cgadsub"], b["name"]))
outfile.write('.endproc\n\n')

outfile.write('.proc ColorMathTableOptions\n')
for b in all_entries:
	outfile.write('  .byt $%.2x ; %s\n' % (b["options"], b["name"]))
outfile.write('.endproc\n')

outfile.close()

#######################################

# Generate the enum in a separate file
outfile = open("src/color_math_settings_enum.s", "w")
outfile.write('; This is automatically generated. Edit "color_math_settings.txt" instead\n')
outfile.write('.enum ColorMathSettings\n')
for b in all_entries:
	outfile.write('  %s\n' % b['name'])
outfile.write('.endenum\n')

outfile.close()
