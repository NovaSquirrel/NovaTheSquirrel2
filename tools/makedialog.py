#!/usr/bin/env python3
# Automatically converts dialog scripts to the game's native format
from nts2shared import *

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
