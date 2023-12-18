#!/usr/bin/env python3
import os, sys

def find_path_from_name(name):
	filename = None
	for tryfile in ["tilesets4/%s.chrsfc", "tilesets2/%s.chrgb", "tilesets4/lz4/%s.chrsfc.lz4",
		"tilesets2/lz4/%s.chrgb.lz4", "tilesetsX/%s.chr", "backgrounds/%s.chrsfc", "backgrounds/%s.namsfc"]:
		if os.path.isfile(tryfile % name):
			if filename != None:
				print("Error: graphic %s exists in more than one format")
				sys.exit()
			filename = tryfile % name
	if filename == None:
		print("Error: graphic %s does not exist" % name)
		sys.exit()
	return filename

def file_size_from_name(name):
	return os.path.getsize(find_path_from_name(name))

# Get the input file
with open("tools/gfxlist.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

all_graphics = []

# Interpret every line in the file
for line in text:
	if not len(line):
		continue
	split = line.split()

	# Parse the line
	address = int(split[0], 16)
	name = split[1]

	do_define = False
	map_tile_number_offset = 0
	for option in split[2:]:
		if option == "define":
			do_define = True
		# Look for parameters that have 
		option_equ = option.split('=')
		if len(option_equ) == 2:
			if   option_equ[0] == 'add_size_to_load_address':
				address += file_size_from_name(option_equ[1]) // 2
			elif option_equ[0] == 'add_size_to_map_tiles_2bpp':
				map_tile_number_offset = file_size_from_name(option_equ[1]) // 16
			elif option_equ[0] == 'add_size_to_map_tiles_4bpp':
				map_tile_number_offset = file_size_from_name(option_equ[1]) // 32

			elif option_equ[0] == 'sub_size_from_load_address':
				address -= file_size_from_name(option_equ[1]) // 2
			elif option_equ[0] == 'sub_size_from_map_tiles_2bpp':
				map_tile_number_offset = -file_size_from_name(option_equ[1]) // 16
			elif option_equ[0] == 'sub_size_from_map_tiles_4bpp':
				map_tile_number_offset = -file_size_from_name(option_equ[1]) // 32

	# Look to see if the resource exists as a 2bpp or 4bpp image
	filename = find_path_from_name(name)

	# Process the line
	graphic = {}
	graphic['name'] = name
	graphic['address'] = address
	graphic['filename'] = "../%s" % filename
	graphic['original_filename'] = filename
	graphic['size'] = os.path.getsize(filename)
	graphic['lz4'] = filename.endswith('lz4')
	graphic['define'] = do_define
	graphic['map_tile_number_offset'] = map_tile_number_offset
	all_graphics.append(graphic)
all_graphics = sorted(all_graphics, key=lambda g: g['size'], reverse=True) 

# -------------------------------------

# Bank information
banks_free = {}
banks_files = {}
ordered_files = []
for bank in ["D_Graphics1", "D_Graphics2", "D_Graphics3", "D_Graphics4"]:
	banks_free[bank] = 0x8000 * 2
	banks_files[bank] = []

for graphic in all_graphics:
	# Select a bank to put it in
	# This is actually the bin packing problem, which is very difficult,
	# but I don't care about optimal efficiency so I'll just find the first bank the item will fit in. ("first fit decreasing")
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
	if f['lz4']:
		f['size'] = 0xffff # Mark it as lz4 compressed
	outfile.write('  .word $%.4x, $%.4x\n' % (f['address'], f['size']))
outfile.write('.endproc\n')

# Write out each individual bank
for key, value in banks_files.items():
	outfile.write('\n.segment "%s"\n' % key)
	for f in value:
		if f['define']:
			outfile.write('.export File_%s\n' % f['name'])
		if f['map_tile_number_offset'] == 0:
			outfile.write('File_%s:\n  .incbin "%s"\n' % (f['name'], f['filename']))
		else:
			# Have to modify the data, so include it inline instead of an incbin
			offset = f['map_tile_number_offset']
			outfile.write('File_%s:\n' % f['name'])
			with open(f['original_filename'], 'rb') as included_file:
				original_data = included_file.read()
				new_data = []
				for i in range(0, len(original_data)//2):
					value = original_data[i*2] + (original_data[i*2+1] << 8)
					new_data.append("$%x" % (value + offset))
				outfile.write('  .word %s\n\n' % ','.join(new_data))

outfile.close()

# Do the enum in a separate file because I can't export enums
outfile = open("src/graphicsenum.s", "w")
outfile.write('; This is automatically generated. Edit "gfxlist.txt" instead\n')
outfile.write('.enum GraphicsUpload\n')
for f in ordered_files:
	outfile.write('  %s\n' % f['name'])
outfile.write('.endenum\n\n')
outfile.close()
