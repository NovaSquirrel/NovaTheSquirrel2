#!/usr/bin/env python3
# Automatically packs ca65 segments into banks, for a HiROM cartridge
import glob, os, subprocess, operator, sys
bank_count    = 16
bank_max_size = 0x8000 * 2
code_bank_max_size = 0x8000
reserve_banks = 1 # Do not do anything with the first N banks
code_segment_prefix = "C_"

if len(sys.argv) < 4:
	print("Syntax: uncle_fill.py New.cfg Old.cfg List.o Of.o Objects.o")
	sys.exit(-1)

def isCodeSegment(name):
	return name.lower() == "code" or name.startswith(code_segment_prefix)

# Prep some status information
all_segments  = {}               # For counting up how big each segment is
bank_sizes    = [0] * bank_count # Sizes in each bank
bank_segments = []               # Segments placed in each bank
for i in range(bank_count):
	bank_segments.append([])

# Get information about the segments
ignore_segments     = set() # Segments not to try and pack
static_rom_segments = set() # ROM segments that go in specific banks
static_rom_seg_bank = {}    # bank each of the above goes in
original_config_before_memory = None
original_config_middle = None
original_config_after_segments = None

with open(sys.argv[2]) as f:
	original_config = f.read()

	# Get segments from ld65 config, so they can be parsed
	segment_index = original_config.index('SEGMENTS {')
	data = original_config[segment_index+10:]
	data = data[:data.index('}')]

	# We're using special comment markers to indicate where to insert memory areas and segments
	auto_memory_marker = "# Insert automatic memory here"
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

		# Parse the segment and its options
		colon = segment.index(':')
		name = segment[:colon]
		info = {}
		for params in segment[colon+1:].split(','):
			key, value = params.split('=')
			info[key] = value
		# If it loads in ROM, it's not dynamically allocated, but takes up space in the bank specified
		if info['load'].startswith('ROM'):
			static_rom_segments.add(name)
			static_rom_seg_bank[name] = int(info['load'][3:].rstrip("_code"))
		ignore_segments.add(name)

# Count up the sizes of all segments using od65
process = subprocess.Popen(["od65", "--dump-segsize"] + sys.argv[3:], stdout=subprocess.PIPE)
(od65_output, err) = process.communicate()
exit_code = process.wait()
od65_output = [x for x in od65_output.decode("utf-8").splitlines() if x.startswith("    ")]
for line in od65_output:
	segment = line.split()
	name = segment[0].rstrip(':')
	if name in ignore_segments and name not in static_rom_segments:
		continue
	size = int(segment[1])
	if name in all_segments:
		all_segments[name] += size
	else:
		all_segments[name] = size

###############################################################################
# Add the static bank segments' sizes in first
###############################################################################
dynamic_segments = all_segments.copy()

for name in static_rom_segments:
	if name in all_segments:
		bank_sizes[static_rom_seg_bank[name]] += all_segments[name]
#		print("%s goes in %d, is %d and it's now %d" % (name, static_rom_seg_bank[name], all_segments[name], bank_sizes[static_rom_seg_bank[name]]))
		del dynamic_segments[name]

###############################################################################
# Split segments into code and data
###############################################################################

code_segments = {}
data_segments = {}

for key,value in dynamic_segments.items():
	if isCodeSegment(key):
		code_segments[key] = value
	else:
		data_segments[key] = value

###############################################################################
# Pack the code segments into banks
###############################################################################
def fitSegments(which, bankSize):
	while bool(which):
		# Find biggest segment
		biggest = max(which.items(), key=operator.itemgetter(1))[0]
		size = which[biggest]

		# Put it in the first bank it can go in, if it's not empty
		if size:
			for i in range(reserve_banks, bank_count): # Skip bank zero until I figure out what's causing bank overflows
				if bank_sizes[i]+size <= bankSize:
					bank_sizes[i] += size
					bank_segments[i].append(biggest)
					break
			else:
				print("Can't fit bank "+biggest+"!")
		del which[biggest]

fitSegments(code_segments, code_bank_max_size)
fitSegments(data_segments, bank_max_size)

#for i in range(bank_count):
#	print(i)
#	print(bank_sizes[i])
#	print(bank_segments[i])

###############################################################################
# Write out the spliced linker config file
###############################################################################
with open(sys.argv[1], 'w') as f:
	f.write(original_config_before_memory)

	f.write('\n  # Automatically placed memory\n')
	for bank in range(reserve_banks, bank_count):
		code_size = sum([all_segments[name] for name in bank_segments[bank] if isCodeSegment(name)])
		data_size = sum([all_segments[name] for name in bank_segments[bank] if not isCodeSegment(name)])

		start = 0x800000 + (bank * 0x10000)
		f.write("  ROM%d: start =  $%x, type = ro, size = $%x, fill = yes;\n" % (bank, start + 0x400000, bank_max_size - code_size))
		if code_size:
			f.write("  ROM%d_code: start =  $%x, type = ro, size = $%x, fill = yes;\n" % (bank, start + 0x10000 - code_size, code_size))

	f.write(original_config_middle)

	f.write('\n  # Automatically placed segments\n')
	for bank in range(bank_count):
		for segment in bank_segments[bank]:
			f.write("  %s: load = ROM%d%s, type = ro;\n" % (segment, bank, "_code" if isCodeSegment(segment) else ""))

	f.write(original_config_after_segments)

# Print total ROM space used
total_used = sum(bank_sizes)
print("ROM usage: %.2fKB or %.2f%%" % (total_used/1024, 100*total_used/(bank_max_size*bank_count)))
