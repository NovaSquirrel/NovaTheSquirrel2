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

# Don't think I'm really using numbers yet?
def parseNumber(number):
	if number in aliases:
		return parseNumber(aliases[number])
	if number.startswith("$"):
		return int(number[1:], 16)
	return int(number)

# Globals
aliases = {}
actor = None
all_objects = []
all_particles = []
all_subroutines = []

# Read and process the file
with open("tools/actors.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

def saveActor():
	if actor == None:
		return
	# Put it in the appropriate list
	if actor["particle"]:
		all_particles.append(actor)
	else:
		all_objects.append(actor)

for line in text:
	if not len(line):
		continue
	if line.startswith("#"): # comment
		continue
	if line.startswith("+"): # new actor
		saveActor()
		# Reset to prepare for the new actor
		priority = False
		actor = {"name": line[1:], "particle": False, "size": [16, 16], "run": "ActorNothing", "draw": "ActorNothing", "flags": [], "gfx": None, "pal": None, "essential": False, "secondary": False}
		continue
	word, arg = separateFirstWord(line)
	# Miscellaneous directives
	if word == "alias":
		name, value = separateFirstWord(arg)
		aliases[name] = value

	# Attributes
	elif word == "size":
		actor["size"] = arg.split("x")
	elif word == "flag":
		actor["flags"] = arg.split()
	elif word in ["gfx", "pal"]:
		actor[word] = arg
	elif word in ["run", "draw"]:
		actor[word] = arg
		all_subroutines.append(arg)
	elif word in ["essential", "secondary", "particle"]:
		actor[word] = True

# Save the last one
saveActor()

#######################################

# Generate the output that's actually usable in the game
outfile = open("src/actordata.s", "w")

outfile.write('; This is automatically generated. Edit "actors.txt" instead\n')
outfile.write('.include "snes.inc"\n.include "actorenum.s"\n.include "global.inc"\n.include "graphicsenum.s"\n.include "paletteenum.s"\n')

outfile.write('.export ObjectFlags, ObjectBank, ObjectRun, ObjectDraw, ObjectWidth, ObjectHeight, ObjectPalette, ObjectGraphic\n')
outfile.write('.export ParticleRun, ParticleDraw\n')

outfile.write('.import %s\n' % str(", ".join(all_subroutines)))
outfile.write('\n.segment "ActorData"\n\n')

outfile.write('.proc ObjectFlags\n')
for b in all_objects:
	if b["essential"]:
		b["flags"].append("Essential")
	elif b["secondary"]:
		b["flags"].append("Secondary")
	else:
		b["flags"].append("Primary")
	outfile.write('  .word %s\n' % " | ".join(["ObjectFlag::"+f for f in b["flags"]]))
outfile.write('.endproc\n\n')

# no-operation routine
outfile.write(".proc ActorNothing\n  rtl\n.endproc\n\n")

# Objects
outfile.write('.proc ObjectDraw\n  .addr .loword(ActorNothing)\n')
for b in all_objects:
	outfile.write('  .addr .loword(%s)\n' % b["draw"])
outfile.write('.endproc\n\n')

outfile.write('.proc ObjectRun\n  .addr .loword(ActorNothing)\n')
for b in all_objects:
	outfile.write('  .addr .loword(%s)\n' % b["run"])
outfile.write('.endproc\n\n')

outfile.write('.proc ObjectBank\n  .byt ^ActorNothing, ^ActorNothing\n')
for b in all_objects:
	outfile.write('  .byt ^%s, ^%s\n' % (b["run"], b["draw"]))
outfile.write('.endproc\n\n')

outfile.write('.proc ObjectWidth\n  .word 0\n')
for b in all_objects:
	outfile.write('  .word %s<<4 ; %s\n' % (b["size"][0], b["name"]))
outfile.write('.endproc\n\n')

outfile.write('.proc ObjectHeight\n  .word 0\n')
for b in all_objects:
	outfile.write('  .word %s<<4 ; %s\n' % (b["size"][1], b["name"]))
outfile.write('.endproc\n\n')

outfile.write('.proc ObjectGraphic\n  .word $ffff\n')
for b in all_objects:
	if b["gfx"]:
		outfile.write('  .word GraphicsUpload::%s\n' % (b["gfx"]))
	else:
		outfile.write('  .word $ffff\n')
outfile.write('.endproc\n\n')

outfile.write('.proc ObjectPalette\n  .word $ffff\n')
for b in all_objects:
	if b["pal"]:
		outfile.write('  .word Palette::%s\n' % (b["pal"]))
	else:
		outfile.write('  .word $ffff\n')
outfile.write('.endproc\n\n')

# Particles
outfile.write('.proc ParticleDraw\n  .addr .loword(ActorNothing)\n')
for b in all_particles:
	outfile.write('  .addr .loword(%s)\n' % b["draw"])
outfile.write('.endproc\n\n')

outfile.write('.proc ParticleRun\n  .addr .loword(ActorNothing)\n')
for b in all_particles:
	outfile.write('  .addr .loword(%s)\n' % b["run"])
outfile.write('.endproc\n\n')





outfile.close()

# Generate the enum in a separate file
outfile = open("src/actorenum.s", "w")
outfile.write('; This is automatically generated. Edit "actors.txt" instead\n')
outfile.write('.enum Object\n  Empty\n')
for b in all_objects:
	outfile.write('  %s\n' % b['name'])
outfile.write('.endenum\n\n')

outfile.write('.enum Particle\n  Empty\n')
for b in all_particles:
	outfile.write('  %s\n' % b['name'])
outfile.write('.endenum\n\n')

outfile.close()
