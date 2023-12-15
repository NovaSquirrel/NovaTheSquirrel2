#!/usr/bin/env python3
# Automatic ca65 bank picker
# Copyright 2020-2023 NovaSquirrel
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty provided
# the copyright notice and this notice are preserved in all source
# code copies.  This file is offered as-is, without any warranty.
#
import glob, os, subprocess, operator, sys

# Configuration
reserve_banks = 0     # Do not do anything with the first N banks
reserve_banks_end = 0 # Do not do anything with the last N banks
code_segment_prefix = "C_"
slow_segment_prefix = "D_"
bank_zero_segment = "bankzero"

# Read configuration from the command line
def helpText():
	print("Syntax: uncle_fill.py board:banks New.cfg Old.cfg List.o Of.o Objects.o")
	print("Board can be lorom, hirom, exhirom or unrom")
	sys.exit(-1)

# Defaults configuration
code_bank_max_size = 0x8000
hirom = False
exhirom = False
snes = True
nes = False
unrom = False

if len(sys.argv) < 5:
	helpText()
board = sys.argv[1].split(':')
if len(board) < 2:
	helpText()
# SNES
if board[0].lower() == 'lorom':
	hirom = False
	bank_max_size  = 0x8000
	header_bank = 0
elif board[0].lower() == 'hirom':
	hirom = True
	bank_max_size  = 0x8000 * 2
	header_bank = 0
elif board[0].lower() == 'exhirom':
	hirom = True
	exhirom = True
	bank_max_size  = 0x8000 * 2
	header_bank = 64
# NES
elif board[0].lower() == 'unrom':
	unrom = True
	snes = False
	nes = True
	bank_max_size = 0x4000
	code_bank_max_size = 0x4000
	reserve_banks = 0
	reserve_banks_end = 1
else:
	helpText()
bank_count = int(board[1])

# -------------------------------------

code_segment_names = ("code", "snesheader", bank_zero_segment)
def isCodeSegment(name):
	return name.lower() in code_segment_names or name.startswith(code_segment_prefix)
def isSlowSegment(name):
	return name.startswith(slow_segment_prefix)

# Input status:
all_segment_sizes      = {}      # For counting up how big each segment is
all_segment_alignments = {}      # The maximum alignment for each segment, to go in the ld65 config
# Output status:
bank_sizes    = [0] * bank_count # Amount of bytes currently used in each bank
bank_segments = []               # Segments placed in each bank
for i in range(bank_count):
	bank_segments.append([])

# Get information about the segments
ignore_segments     = set() # Segments not to try and pack
static_rom_segments = set() # ROM segments that go in specific banks
static_rom_seg_bank = {}    # bank each of the above goes in

# Text from original config template:
original_config_before_memory = None
original_config_middle = None
original_config_after_segments = None

with open(sys.argv[3]) as f:
	original_config = f.read()

	# Get segments from ld65 config, so they can be parsed
	segment_index = original_config.index('SEGMENTS {')
	data = original_config[segment_index+10:]
	data = data[:data.index('}')]

	# We're using special comment markers to indicate where to insert memory areas and segments
	auto_memory_marker  = "# Insert automatic memory here"
	auto_segment_marker = "# Insert automatic segments here"

	# Find the places to insert the new stuff
	split = original_config.split(auto_memory_marker)
	original_config_before_memory = split[0]
	split = split[1].split(auto_segment_marker)
	original_config_middle = split[0]
	original_config_after_segments = split[1]

	# Parse the segments in the original linker config's segment section
	for line in data.split(';'):
		if line.isspace():
			continue
		# Strip out comments and spaces
		segment = ''
		comment = False
		for char in line:
			if char == '#':
				comment = True
			elif char == '\n':
				comment = False
			elif char == ' ':
				pass
			elif not comment:
				segment += char
		if segment == '':
			continue

		# Parse the segment and its options
		colon = segment.index(':')
		name = segment[:colon]
		info = {}
		for params in segment[colon+1:].split(','):
			key, value = params.split('=')
			info[key] = value
		# If it loads in ROM, it's not dynamically allocated, but still takes up space in the bank specified
		if info['load'].startswith('ROM'):
			static_rom_segments.add(name)
			static_rom_seg_bank[name] = int(info['load'][3:].rstrip("_code"))
		ignore_segments.add(name)

###############################################################################
# Figure out the size and alignment of each segment
###############################################################################

# Count up the sizes of all segments using od65
process = subprocess.Popen(["od65", "--dump-segments"] + sys.argv[4:], stdout=subprocess.PIPE)
(od65_output, err) = process.communicate()
exit_code = process.wait()
od65_output = [x for x in od65_output.decode("utf-8").splitlines()]

this_segment_name  = None
this_segment_size  = None
this_segment_align = None

def align_and_add(address, alignment, add):
	if address % alignment == 0:
		return address + add
	return address + (alignment - (address % alignment)) + add

def record_segment_info():
	global this_segment_name
	if this_segment_name == None:
		return
	# Pad forward to satisfy the per-object file alignment
	total_size = all_segment_sizes.get(this_segment_name, 0)
	all_segment_sizes[this_segment_name] = align_and_add(total_size, this_segment_align, this_segment_size)
	# Keep track of the maximum align used across all the object files
	all_segment_alignments[this_segment_name] = max(this_segment_align, all_segment_alignments.get(this_segment_name, 1))
	this_segment_name = None

for line in od65_output:
	words = [_.strip() for _ in line.split(":")]
	if len(words) != 2:
		print("Format from od65 not as expected")
		sys.exit(-1)
	key, value = words

	if key == 'Name':
		record_segment_info()
		value = value.strip('"')
		if value in ignore_segments and value not in static_rom_segments: # If it's defined but not in ROM, it's probably RAM
			this_segment_name = None # <-- So that record_segment_info() won't consider the segment valid
		else:
			this_segment_name = value
		this_segment_size = 0
		this_segment_align = 0
	elif key == 'Size':
		this_segment_size = int(value)
	elif key == 'Alignment':
		this_segment_align = int(value)
record_segment_info()

###############################################################################
# Add the static bank segments' sizes in first
###############################################################################
dynamic_segments = all_segment_sizes.copy()

for name in static_rom_segments:
	if name in all_segment_sizes:
		bank_sizes[static_rom_seg_bank[name]] += all_segment_sizes[name]
		bank_segments[static_rom_seg_bank[name]].append(name)
#		print("%s goes in %d, is %d and it's now %d" % (name, static_rom_seg_bank[name], all_segment_sizes[name], bank_sizes[static_rom_seg_bank[name]]))
		del dynamic_segments[name]

###############################################################################
# Split segments into code and data
###############################################################################

code_segments = {}
data_segments = {}
slow_segments = {}

for key,value in dynamic_segments.items():
	if isCodeSegment(key):
		code_segments[key] = value
	elif isSlowSegment(key) and exhirom:
		slow_segments[key] = value
	else:
		data_segments[key] = value

###############################################################################
# Pack the code segments into banks
###############################################################################
def fitSegments(which, max_bank_size, first_allowed_bank, allowed_bank_count, slow=False):
	for biggest, size in sorted(which.items(), key=lambda x: x[1], reverse=True):
		# Put it in the first bank it can go in, if it's not empty
		if size:
			for i in range(first_allowed_bank, allowed_bank_count):
				size_if_added = align_and_add(bank_sizes[i], all_segment_alignments[biggest], size)
				if size_if_added <= max_bank_size:
					bank_sizes[i] = size_if_added
					bank_segments[i].append(biggest)
					break
			else:
				if slow: # Retry in the fast areas if there's no room in the slow areas
					for i in range(reserve_banks, 64):
						size_if_added = align_and_add(bank_sizes[i], all_segment_alignments[biggest], size)
						if size_if_added <= max_bank_size:
							bank_sizes[i] = size_if_added
							bank_segments[i].append(biggest)
							break
					else:
						print("Can't fit bank "+biggest+"!")
						sys.exit(-1)
				else:
					print("Can't fit bank "+biggest+"!")
					sys.exit(-1)

# Place anything that should go in the header bank first, to guarantee room for it
for segment in code_segments:
	if segment.lower() == bank_zero_segment:
		size = code_segments[segment]
		bank_sizes[header_bank] += size
		bank_segments[header_bank].append(segment)
		del code_segments[segment]
		break

fitSegments(code_segments, code_bank_max_size, reserve_banks, bank_count if hirom else min(64, bank_count))
fitSegments(slow_segments, bank_max_size,      64,            bank_count, slow=True)
fitSegments(data_segments, bank_max_size,      reserve_banks, bank_count)

#for i in range(bank_count):
#	print(i)
#	print(bank_sizes[i])
#	print(bank_segments[i])

###############################################################################
# Write out the spliced linker config file
###############################################################################
with open(sys.argv[2], 'w') as f:
	f.write(original_config_before_memory)

	f.write('\n  # Automatically placed memory\n')
	for bank in range(reserve_banks, bank_count-reserve_banks_end):

		if snes:
			start = 0x800000 + (bank * 0x10000)
			if hirom:
				if start >= 0xC00000: # Should run from C0 to FF then 40 to 7D
					start -= 0xC00000
				code_size = sum([all_segment_sizes[name] for name in bank_segments[bank] if isCodeSegment(name)])
				data_size = sum([all_segment_sizes[name] for name in bank_segments[bank] if not isCodeSegment(name)])

				f.write("  ROM%d: start = $%x, type = ro, size = $%x, fill = yes;\n" % (bank, start + 0x400000, bank_max_size - code_size))
				if code_size:
					f.write("  ROM%d_code: start = $%x, type = ro, size = $%x, fill = yes;\n" % (bank, start + 0x10000 - code_size, code_size))
			else:
				f.write("  ROM%d: start = $%x, type = ro, size = $%x, fill = yes;\n" % (bank, start, bank_max_size))
		elif nes:
			f.write("  ROM%d: start = $8000, type = ro, size = $%x, fill = yes, bank=%d;\n" % (bank, bank_max_size, bank))
		
	f.write(original_config_middle)

	f.write('\n  # Automatically placed segments\n')
	for bank in range(bank_count):
		for segment in bank_segments[bank]:
			if segment not in static_rom_segments:
				line = "  %s: load = ROM%d%s, type = ro" % (segment, bank, "_code" if (isCodeSegment(segment) and hirom) else "")
				if all_segment_alignments[segment] > 1:
					line += ", align = %d" % all_segment_alignments[segment]
				f.write(line + ";\n")

	f.write(original_config_after_segments)

# Print total ROM space used
total_used = sum(bank_sizes)
print("ROM usage: %.2fKB or %.2f%%" % (total_used/1024, 100*total_used/(bank_max_size*bank_count)))
