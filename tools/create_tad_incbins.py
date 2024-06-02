#!/usr/bin/env python3
import os, sys, json

project_name = sys.argv[1]
outfile_name = sys.argv[2]

if len(sys.argv) != 3:
	print("Syntax: create_tad_incbins.py example-project.terrificaudio incbins.s")
	sys.exit(-1)

with open(project_name) as f:
	project = json.load(f)

##################
# Create the file
outfile = open(outfile_name, "w")
outfile.write('; This is automatically generated. Edit the project file instead\n')
outfile.write('.segment "CODE"\n')
outfile.write('.export SongDirectory\n')
outfile.write('.exportzp SONG_COUNT\n\n')
outfile.write('SONG_COUNT = %d\n\n' % len(project["songs"]))

project_directory = os.path.dirname(project_name)
songs = []

#################
# Song directory
outfile.write('; Pointer, then data size\n')
outfile.write('.proc SongDirectory\n')
for n, song in enumerate(project["songs"]):
	path = os.path.splitext(os.path.dirname(project_name) + '/' + song['source'])[0] + '.bin'
	size = os.path.getsize(path)
	outfile.write('  .faraddr SongFile_%d ; %s\n' % (n, song['name']))
	outfile.write('  .word %s\n' % size)
	songs.append({
		"index": n,
		"path": path,
		"size": size,
	})
outfile.write('.endproc\n\n')

############################
# Pack the songs into banks
space_used_per_bank = [0]
songs_in_each_bank = [[]]

for song in sorted(songs, key=lambda x: x['size'], reverse=True):
	# Put it in the first bank it can go in, if it's not empty
	for i in range(len(space_used_per_bank)):
		if space_used_per_bank[i] + song['size'] <= 0xffff:
			space_used_per_bank[i] += song['size']
			songs_in_each_bank[i].append(song)
			break
	else:
		space_used_per_bank.append(song['size'])
		songs_in_each_bank.append([song])

##########
# Incbins

for i, songs in enumerate(songs_in_each_bank):
	outfile.write('.segment "SongBank_%d"\n' % (i+1))
	for song in songs:
		outfile.write('SongFile_%d: .incbin "../%s"\n' % (song["index"], song["path"]))
	outfile.write('\n')

outfile.close()
