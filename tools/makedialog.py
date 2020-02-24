# Automatically converts dialog scripts to the game's native format
"""
Dialog commands:
{Say ACTOR CHARACTER PORTRAIT}
{Narrate}
{FG}
{UploadGFX}
{UploadPal}
{Call}
{Return}
{End}
{Background BG Palette}

Text commands:
{C1} {C2} {C3}
{wide}
{big}
{x X}
{xy X Y}
"""

SpecialChars = {
	"curlyl":     ord("{"),
	"curlyr":     ord("}"),
	"buttona":    0x80,
	"buttonb":    0x81,
	"buttonx":    0x82,
	"buttony":    0x83,
	"arrowup":    0x84,
	"arrowdown":  0x85,
	"arrowleft":  0x86,
	"arrowright": 0x87,
	"heart":      0x88,
	"heartfull":  0x89,
	"copyright":  0x8a,
	"registered": 0x8b,
	"trademark":  0x8c,
	"star":       0x8d,
	"check":      0x8e,
	"eyes":       0x8f,
	"buttonl":    0x90,
	"buttonr":    0x91,
	"smile":      0x92,
	"frown":      0x93,
	"mad":        0x94,
	"meh":        0x95,
	"thumbsup":   0x96,
	"thumbsdown": 0x97,
	"think":      0x98,
	"flipsmiley": 0x99,
	"pawprint":   0x9a
}

DialogScenePrefix = 'DialogScene_'
import_list = set()

def EncodeTextbox(scene, text):
	TC = 'TextCommand::'
	first = True
	for line in text:
		if not first:
			scene.bytes.append(TC+'EndLine')
		first = False

		i = 0
		while i < len(line):
			c = line[i]
			if c == '{':
				right = line.find('}', i)
				args = line[i+1:right].split()
				command = args[0].lower()
				if command in SpecialChars:
					scene.bytes.append(TC+'ExtendedChar')
					scene.bytes.append(str(SpecialChars[command]))
				elif command == 'c1':
					scene.bytes.append(TC+'Color1')
				elif command == 'c2':
					scene.bytes.append(TC+'Color2')
				elif command == 'c3':
					scene.bytes.append(TC+'Color3')
				elif command == 'big':
					scene.bytes.append(TC+'BigText')
				elif command == 'wide':
					scene.bytes.append(TC+'WideText')
				elif command == 'setx':
					scene.bytes.append(TC+'SetX')
					scene.bytes.append(args[1])
				elif command == 'setxy':
					scene.bytes.append(TC+'SetXY')
					scene.bytes.append(args[1])
					scene.bytes.append(args[2])
				elif command == 'callasm':
					scene.bytes.append(TC+'CallASM')
					scene.bytes.append('<'+args[1])
					scene.bytes.append('>'+args[1])
					scene.bytes.append('^'+args[1])
					import_list.add(args[1])
				i = right
			else:
				scene.bytes.append(str(ord(c)))
			i += 1

class DialogScene(object):
	def __init__(self, name):
		self.name = name
		self.bytes = []
		self.commands = []
	def finish(self):
		DC = 'DialogCommand::'
		TC = 'TextCommand::'
		chainable_commands = ['say', 'narrate', 'fg', 'uploadgfx', 'uploadpal']

		# Chain the same-name commands together
		chains = []
		this_chain = None
		for command in self.commands:
			if (this_chain == None) or \
			(this_chain[0][0] != command[0]) or \
			(this_chain[0][0] not in chainable_commands):
				this_chain = [command]
				chains.append(this_chain)
			else:
				this_chain.append(command)
		# Now process each chain
		for chain in chains:
			first = chain[0]
			c = first[0]

			if c == 'say':
				previous = None
				for part in chain:
					# [Say ActorSlot CharacterID PortraitNum]
					slot = part[1]
					character = part[2]
					portraitnum = part[3]

					if previous == None or previous[1] != part[1]:
						if previous != None:
							self.bytes.append(TC+'EndText')
						self.bytes.append(DC+'Portrait')
						self.bytes.append('Portrait::%s+%s' % (character, portraitnum))
					elif previous[2] == part[2] and previous[3] == part[3]: # Same portrait
						self.bytes.append(TC+'EndPage')
					else: # New portrait, same slot
						self.bytes.append(TC+'Portrait')
						self.bytes.append('Portrait::%s+%s' % (character, portraitnum))
					EncodeTextbox(self, part[-1])
					previous = part
				self.bytes.append(TC+'EndText')

			elif c == 'narrate':
				first = True
				for part in chain:
					if first:
						self.bytes.append(DC+'Narrate')
					else:
						self.bytes.append(TC+'EndPage')
					EncodeTextbox(self, part[-1])
					first = False
				self.bytes.append(TC+'EndText')

			elif c == 'fg':
				self.bytes.append(DC+'SceneMetatiles')
				for i in range(len(chain)):
					part = chain[i]
					metatile = 'Block::'+part[1] # Get the block name

					# Set the required flags
					if len(part) >= 3 and part[2] != '1':
						metatile += '|MT_Repeat'
					if len(part) == 4:
						metatile += '|MT_Reposition'
					if i == len(chain)-1:
						metatile += '|MT_Finish'

					# Add in that metatile
					self.bytes.append('<('+metatile+')')
					self.bytes.append('>('+metatile+')')

					if len(part) == 4: # Reposition
						position = part[3].split(',')
						self.bytes.append('%s|(%s<<4)' % tuple(position))
					if len(part) >= 3 and part[2] != '1': # Length
						size = part[2].split(',')
						if len(size) == 3: # Go down
							self.bytes.append('128|%s|(%s<<4)' % (size[0], size[1]))
						elif len(size) == 2:
							self.bytes.append('%s|(%s<<4)' % tuple(size))
						else:
							self.bytes.append(size[0])

			elif c == 'uploadgfx':
				self.bytes.append(DC+'UploadGraphics')
				for part in chain:
					self.bytes.append('GraphicsUpload::'+part[1])
				self.bytes.append('255')

			elif c == 'uploadpal':
				self.bytes.append(DC+'UploadPalettes')
				for part in chain:
					self.bytes.append('Palette::'+part[1])
				self.bytes.append('255')

			elif c == 'callasm':
				self.bytes.append(DC+'CallAsm')
				self.bytes.append('<'+first[1])
				self.bytes.append('>'+first[1])
				self.bytes.append('^'+first[1])
				import_list.add(first[1])

			elif c == 'call':
				self.bytes.append(DC+'Call')
				self.bytes.append('<'+DialogScenePrefix+first[1])
				self.bytes.append('>'+DialogScenePrefix+first[1])
				self.bytes.append('^'+DialogScenePrefix+first[1])

			elif c == 'return':
				self.bytes.append(DC+'Return')

			elif c == 'end':
				self.bytes.append(DC+'End')

			elif c == 'actor':
				self.bytes.append(DC+'PutNPC')
				# [Actor Slot CharacterID X,Y L/R]
				if len(first) == 5 and first[4] == 'L':
					self.bytes.append(first[1]+'|64') # Flip
				else:
					self.bytes.append(first[1])
				self.bytes.append('DialogNPC::'+first[2])
				position = first[3].split(',')
				self.bytes.append(position[0]+'+32')
				self.bytes.append(position[1]+'+104')

			elif c == 'background':
				self.bytes.append(DC+'Background2bpp')
				self.bytes.append('GraphicsUpload::'+first[1])
				self.bytes.append('VariablePalette::'+first[2])

#######################################

dialogfile = open("story/dialog.txt", "r")
dialoglines = dialogfile.readlines()
dialogfile.close()

all_scenes = {}
current_scene = None
current_text = None
text_mode = False
for line in dialoglines:
	line = line.strip()
	if line.startswith('#'):	
		continue
	elif line.startswith('--- '):
		if current_scene:
			current_scene.finish()
		name = line[4:]
		current_scene = DialogScene(name)
		all_scenes[name] = current_scene
		continue
	if text_mode:
		if line == '{-}':
			text_mode = False
		else:
			current_text.append(line)
	elif line.startswith('{'):
		line = line[1:-1]
		split = line.split()
		split[0] = split[0].lower()
		if split[0] in ['say', 'narrate']:
			text_mode = True
			current_text = []
			split.append(current_text)
		current_scene.commands.append(split)
if current_scene:
	current_scene.finish()


outfile = open("src/dialog_text_data.s", "w")
outfile.write('; This is automatically generated. Edit "story/dialog.txt" instead\n')
outfile.write('.include "snes.inc"\n')
outfile.write('.include "global.inc"\n')
outfile.write('.include "graphicsenum.s"\n')
outfile.write('.include "dialog_npc_enum.s"\n')
outfile.write('.include "paletteenum.s"\n')
outfile.write('.include "blockenum.s"\n')
outfile.write('.include "portraitenum.s"\n')
outfile.write('.include "vwf.inc"\n')
if len(import_list):
	outfile.write('.import %s\n' % ', '.join(list(import_list)))
outfile.write('MT_Reposition = $0001\nMT_Repeat     = $4000\nMT_Finish     = $8000\n\n')
outfile.write('.segment "DialogText"\n')
for name, data in all_scenes.items():
	outfile.write('.export '+DialogScenePrefix+'%s\n' % name)
	outfile.write(DialogScenePrefix+'%s:\n' % name)
	outfile.write('  .byt %s\n\n' % ', '.join(data.bytes))
#	print(name)
#	print(data.bytes)
#	print(len(data.bytes))
outfile.close()
