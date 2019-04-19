import os, sys

# Get the input file
with open("tools/gfxlist.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

# Bank information
banks_free = {}
banks_files = {}
ordered_files = []
for bank in ["Graphics1", "Graphics2"]:
	banks_free[bank] = 0x8000
	banks_files[bank] = []

# Interpret every line in the file
for line in text:
	if not len(line):
		continue
	split = line.split()

	# Parse the line
	address = int(split[0], 16)
	name = split[1]

	# Look to see if the resource exists as a 2bpp or 4bpp image
	filename = ""
	for tryfile in ["tilesets4/%s.chrsfc", "tilesets2/%s.chrgb"]:
		if os.path.isfile(tryfile % name):
			if len(filename):
				print("Error: graphic %s exists in more than one format")
				sys.exit()
			filename = tryfile % name
	if not len(filename):
		print("Error: graphic %s does not exist" % name)
		sys.exit()

	# Process the line
	graphic = {}
	graphic['name'] = name
	graphic['address'] = address
	graphic['filename'] = "../%s" % filename
	graphic['size'] = os.path.getsize(filename)
	
	# Select a bank to put it in
	# This is actually the bin packing problem, which is very difficult,
	# but I don't care about optimal efficiency so I'll just find the first bank the item will fit in.
	# Eventually I'll make it so that files can just straddle two banks.
	bank = None
	for key, val in banks_free.items():
		if val >= graphic['size']:
			bank = key
			break
	if bank == None:
		print("Error: graphics banks overflow!")
		sys.exit()

	banks_free[bank] -= graphic['size']
	banks_files[bank].append(graphic)
	ordered_files.append(graphic)

# Now write out the output file
outfile = open("src/graphics.s", "w")
outfile.write('; This is automatically generated. Edit "gfxlist.txt" instead\n')
outfile.write('.segment "CODE"\n')
outfile.write('.export GraphicsDirectory\n\n')

# Write the file directory
outfile.write('; Pointer, destination address, and then size\n')
outfile.write('.proc GraphicsDirectory\n')
for f in ordered_files:
	outfile.write('  .faraddr File_%s\n' % f['name'])
	outfile.write('  .word $%.4x>>1, $%.4x\n' % (f['address'], f['size']))
outfile.write('.endproc\n')

# Write out each individual bank
for key, value in banks_files.items():
	outfile.write('\n.segment "%s"\n' % key)
	for f in value:
		outfile.write('File_%s:\n  .incbin "%s"\n' % (f['name'], f['filename']))

outfile.close()

# Do the enum in a separate file because I can't export enums
outfile = open("src/graphicsenum.s", "w")
outfile.write('; This is automatically generated. Edit "gfxlist.txt" instead\n')
outfile.write('.enum GraphicsUpload\n')
for f in ordered_files:
	outfile.write('  %s\n' % f['name'])
outfile.write('.endenum\n\n')
outfile.close()
