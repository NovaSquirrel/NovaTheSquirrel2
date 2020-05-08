#!/usr/bin/env python3
# Convert png palettes to SNES palettes
import PIL, glob, os
from PIL import Image

palettes = {}
variable_palettes = {}

for f in glob.glob("palettes/*.png"):
	# Name of the palette is the filename with path and extension taken out
	name = os.path.splitext(os.path.basename(f))[0]
	palettes[name] = []

	im = Image.open(f)
	pal = im.getpalette()[3:]
	# Read out 15 colors
	for i in range(15):
		r = pal.pop(0)
		g = pal.pop(0)
		b = pal.pop(0)
		line = "  .word RGB8(%d, %d, %d)\n" % (r,g,b)
		palettes[name].append(line)
	im.close()

for f in glob.glob("palettes/variable/*.png"):
	# Name of the palette is the filename with path and extension taken out
	name = os.path.splitext(os.path.basename(f))[0]
	variable_palettes[name] = []

	im = Image.open(f)
	pal = im.getpalette()
	# Use width to find the number of colors
	for i in range(im.width):
		r = pal.pop(0)
		g = pal.pop(0)
		b = pal.pop(0)
		line = "  .word RGB8(%d, %d, %d)\n" % (r,g,b)
		variable_palettes[name].append(line)
	im.close()

# Output the palettes; regular ones don't use a directory because everything is 30 bytes long
# But the variable ones do!

outfile = open("src/palettedata.s", "w")
outfile.write('; This is automatically generated. Edit "palettes" directory instead\n')
outfile.write('.include "snes.inc"\n')
outfile.write('.segment "PaletteData"\n')
outfile.write('.export PaletteList, VariablePaletteDirectory, VariablePaletteData\n\n')
outfile.write('.proc PaletteList\n')
for pal, data in palettes.items():
	outfile.write('  ; %s\n' % pal)
	for line in data:
		outfile.write(line)
outfile.write('.endproc\n\n')

outfile.write('.segment "VariablePaletteData"\n')
outfile.write('.proc VariablePaletteData\n')
for pal, data in variable_palettes.items():
	outfile.write('%s:\n' % pal)
	outfile.write('  .byt %d\n' % len(data))
	for line in data:
		outfile.write(line)
outfile.write('.endproc\n\n')

outfile.write('.proc VariablePaletteDirectory\n')
for pal, data in variable_palettes.items():
	outfile.write('  .word .loword(VariablePaletteData::%s - VariablePaletteData) \n' % pal)
outfile.write('.endproc\n\n')
outfile.close()

# Do the enum in a separate file because I can't export enums
outfile = open("src/paletteenum.s", "w")
outfile.write('; This is automatically generated. Edit "palettes" directory instead\n')
outfile.write('.enum Palette\n')
for pal in palettes:
	outfile.write('  %s\n' % pal)
outfile.write('.endenum\n\n')

outfile.write('.enum VariablePalette\n')
for pal in variable_palettes:
	outfile.write('  %s\n' % pal)
outfile.write('.endenum\n\n')
outfile.close()
