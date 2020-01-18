# Automatically packs ca65 segments into banks
import glob, os, subprocess, operator, sys

if len(sys.argv) < 4:
	print("Syntax: philip_banks.py New.cfg Old.cfg List.o Of.o Objects.o")
	sys.exit(-1)

bank_max_size = 0x8000
bank_count    = 32

all_segments  = {}               # for counting up how big each segment is
bank_sizes    = [0] * bank_count # sizes in each bank
bank_segments = []               # segments in each bank
for i in range(bank_count):
	bank_segments.append([])

# Get information about the segments
ignore_segments     = set() # Segments not to try and pack
static_rom_segments = set() # ROM segments that go in specific banks
static_rom_seg_bank = {}    # bank each of the above goes in
original_config_start, original_config_end = None, None
with open(sys.argv[2]) as f:
	# Open ld65 config, reduce it to just the segments
	original_config = f.read()
	segment_index = original_config.index('SEGMENTS {')
	data = original_config[segment_index+10:]
	data = data[:data.index('}')]

	# Save the original config so the new lines can be spliced into it
	auto_bank_marker = "# Insert automatic banks here"
	ending_index = original_config.index(auto_bank_marker, segment_index)
	original_config_start = original_config[:ending_index]
	original_config_end   = original_config[ending_index+len(auto_bank_marker):]

	# Parse the segments
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
			static_rom_seg_bank[name] = int(info['load'][3:], 16)
		ignore_segments.add(name)

# Count up the sizes of all segments
for i in range(len(sys.argv) - 3):
	f = sys.argv[i+3]
	process = subprocess.Popen(["od65", "--dump-segsize", f], stdout=subprocess.PIPE)
	(output, err) = process.communicate()
	exit_code = process.wait()

	output = output.decode("utf-8")
	output = output[output.index('Segment sizes:')+14:].split()
	for i in range(len(output)//2):
		name = output[i*2+0].rstrip(':')
		if name in ignore_segments and name not in static_rom_segments:
			continue
		size = int(output[i*2+1])
		if name in all_segments:
			all_segments[name] += size
		else:
			all_segments[name] = size

# Add the static bank segments in first
for name in static_rom_segments:
	if name in all_segments:
		bank_sizes[static_rom_seg_bank[name]] += all_segments[name]
#		print("%s goes in %d, is %d and it's now %d" % (name, static_rom_seg_bank[name], all_segments[name], bank_sizes[static_rom_seg_bank[name]]))
		del all_segments[name]

# Pack the segments into banks
while bool(all_segments):
	# Find biggest segment
	biggest = max(all_segments.items(), key=operator.itemgetter(1))[0]
	size = all_segments[biggest]

	# Put it in the first bank it can go in, if it's not empty
	if size:
		for i in range(1, bank_count): # Skip bank zero until I figure out what's causing bank overflows
			if bank_sizes[i]+size <= bank_max_size:
				bank_sizes[i] += size
				bank_segments[i].append(biggest)
				break
		else:
			print("Can't fit "+biggest+"!")
	del all_segments[biggest]

#for i in range(bank_count):
#	print(i)
#	print(bank_sizes[i])
#	print(bank_segments[i])

# Write out the spliced linker config file
with open(sys.argv[1], 'w') as f:
	f.write(original_config_start)
	f.write('\n  # Automatically placed segments\n')
	for bank in range(bank_count):
		for segment in bank_segments[bank]:
			f.write("  %s: load = ROM%.2x, type = ro;\n" % (segment, bank))
	f.write(original_config_end)

# Print total ROM space used
total_used = sum(bank_sizes)
print("ROM usage: %.2fKB or %.2f%%" % (total_used/1024, 100*total_used/(bank_max_size*bank_count)))
