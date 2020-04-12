# Helper functions
def separateFirstWord(text, lowercaseFirst=True):
	space = text.find(" ")
	command = text
	arg = ""
	if space >= 0:
		command = text[0:space]
		arg = text[space+1:]
	if lowercaseFirst:
		command = command.lower()
	return (command, arg)

def parseNumber(number):
	if number in aliases:
		return parseNumber(aliases[number])
	if number.startswith("$"):
		return int(number[1:], 16)
	return int(number)

# Globals
aliases = {}
item = None
all_items = []
all_subroutines = []

# Read and process the file
with open("tools/items.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

def saveItem():
	if item == None:
		return
	all_items.append(item)

for line in text:
	if not len(line):
		continue
	if line.startswith("#"): # comment
		continue
	if line.startswith("+"): # new item
		saveItem()
		# Reset to prepare for the new actor
		item = {"name": line[1:], "run": "0", "display_name": "", "description": [], "level-only": False}
		continue
	word, arg = separateFirstWord(line)
	# Miscellaneous directives
	if word == "alias":
		name, value = separateFirstWord(arg)
		aliases[name] = value

	# Attributes
	elif word == "name":
		item["display_name"] = arg
#	elif word in ["run"]:
#		item[word] = arg
	elif word == "run":
		item["run"] = arg
		if arg not in all_subroutines:
			all_subroutines.append(arg)
	elif word in ["level-only"]:
		item[word] = True

# Save the last one
saveItem()

#######################################

# Generate the output that's actually usable in the game
outfile = open("src/itemdata.s", "w")

outfile.write('; This is automatically generated. Edit "items.txt" instead\n')
outfile.write('.include "snes.inc"\n.include "global.inc"\n')

outfile.write('.export ItemFlags, ItemRun, ItemName\n')

outfile.write('.import %s\n' % str(", ".join(all_subroutines)))
outfile.write('\n.segment "ItemData"\n\n')

outfile.write('.proc ItemFlags\n  .byt 0\n')
for b in all_items:
	value = 0
	if b["level-only"]:
		value |= 128
	outfile.write('  .byt %d ; %s\n' % (value, b["name"]))
outfile.write('.endproc\n\n')

outfile.write('.proc ItemRun\n  .addr 0\n')
for b in all_items:
	outfile.write('  .addr .loword(%s)\n' % b["run"])
outfile.write('.endproc\n\n')

outfile.write('.proc ItemName\n  .addr 0\n')
for b in all_items:
	outfile.write('  .addr .loword(ItemName_%s)\n' % b["name"])
outfile.write('.endproc\n\n')

for b in all_items:
	outfile.write('ItemName_%s:\n  .byt "%s", 0\n' % (b["name"], b["display_name"]))
outfile.write('\n')

outfile.close()


# Generate the enum in a separate file
outfile = open("src/itemenum.s", "w")
outfile.write('; This is automatically generated. Edit "items.txt" instead\n')
outfile.write('.enum InventoryItem\n  Empty\n')
for b in all_items:
	outfile.write('  %s\n' % b['name'])
outfile.write('.endenum\n\n')

outfile.close()
