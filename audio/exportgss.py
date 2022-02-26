from encodesong import encode_song
from encodebrr import encode_brr
import sys
LocalPrefix = "L_" # This prefix marks an instrument as using a local sample
StreamingEnabled = False
StreamingOffset = 9 if StreamingEnabled else 0

if len(sys.argv) < 3:
	print("Syntax: exportgss.py data.s enum.s List.gss Of.gss Songs.gss")
	sys.exit(-1)

class TrackerModule:
	def __init__(self, filename):
		self.instruments = [None] * 99
		self.songs = [None] * 99

		# Start parsing the file
		f = open(filename, 'r')
		section = None
		song    = None
		for n in f.readlines():
			n = n.strip()

			if n.startswith('[') and n.endswith(']'):
				section = n[1:-1]
				song = None
				if section.startswith('Song'):
					num = int(section[4:])
					song = self.songs[num]
			elif n.startswith('Instrument'):
				if n[11].isdigit():
					which = int(n[10:12])
					field = n[12:].split('=')
				else:
					which = int(n[10])
					field = n[11:].split('=')
				if not self.instruments[which]:
					self.instruments[which] = TrackerInstrument()
				self.instruments[which].set(field[0], field[1])
			elif n.startswith('Song'):
				if n[5].isdigit():
					which = int(n[4:6])
					field = n[6:].split('=')
				else:
					which = int(n[4])
					field = n[5:].split('=')
				if not self.songs[which]:
					self.songs[which] = TrackerSong(self)
				self.songs[which].set(field[0], field[1])
			elif song:
				if len(n) >= 87:
					# RRRR SSC#3iiVVEvvC#3iiVVEvvC#3iiVVEvvC#3iiVVEvvC#3iiVVEvvC#3iiVVEvvC#3iiVVEvvC#3iiVVEvv
					row = int(n[0:4])
					if song.last_row < row:
						song.last_row = row
					if n[4] == '*': # Song marker
						song.markers.add(row)
					if n[5:7].isnumeric():
						song.speeds[row] = int(n[0:2])
					for c in range(8):
						data = n[7+c*10 : 17+c*10]
						if data == '..........':
							continue
						song.chans[c][row] = TrackerData(data)
		f.close()

		#######################################################
		# Process the parsed file
		#######################################################
		self.used_instruments = set()
		for song in self.songs:
			if song == None:
				continue
			for c in song.chans:
				for r,row in c.items():
					if row.instrument != None:
						if self.instruments[row.instrument].is_local():
							song.local_instruments.add(row.instrument)
						else:
							self.used_instruments.add(row.instrument)
		self.instrument_remap = {} # Dict for remapping to the combined list

class TrackerSong:
	def __init__(self, module):
		self.props  = {}
		self.chans  = [{}, {}, {}, {}, {}, {}, {}, {}]
		self.speeds = {}
		self.markers = set()
		self.last_row = 0
		self.module = module
		self.local_instruments = set() # Which instrument numbers are local
		self.output_local_instruments = set() # Which local instruments to output from the wider set
		self.instrument_remap = {} # Copied from the module's remap, but has local instruments in it

	def set(self, field, text):
		self.props[field] = text if field == 'Name' else int(text)

	def is_not_empty(self):
		return self.chans != [{}, {}, {}, {}, {}, {}, {}, {}]

	def is_sound_effect(self):
		return bool(self.props['Effect'])

	def write_to_file(self, f, base):
		data = encode_song(self, base)
		# Write the header
		f.write('\t.byte %d\n' % len(data))
		for i in range(len(data)):
			f.write('\t.addr @song_ch%d+%s\n' % (i,base))
		# Write the actual song data
		for i, channel in enumerate(data):
			f.write('@song_ch%d:\n' % i)
			f.write(':\t.byt %s\n' % ', '.join([str(x) for x in channel]))
		return 1+2*len(data)+sum([len(x) for x in data])

class TrackerInstrument:
	def __init__(self):
		self.props = {}
		self.brr_size = None
		self.brr_loop = None
		self.brr_data = None

	def set(self, field, text):
		if field == 'Name' or field == 'SourceData':
			self.props[field] = text
		else:
			self.props[field] = int(text)

	def adsr_string(self):
		return '$%.2x, $%.2x' % (0x80|self.props['EnvAR']|(self.props['EnvDR']<<4), self.props['EnvSR']|(self.props['EnvSL']<<5))

	def is_local(self):
		return self.props['Name'].startswith(LocalPrefix)

	def brr_string(self):
		return ', '.join(['$'+self.brr_data[x*2:(x+1)*2] for x in range(self.brr_size)])

	def encode_as_brr(self):
		if self.brr_size: # Already done
			return
		encoded = encode_brr(self)
		self.brr_size = int(encoded[0])
		self.brr_loop = int(encoded[1])
		if self.brr_loop == -1:
			self.brr_loop = 0
		self.brr_data = encoded[2]

class TrackerData:
	def __init__(self, text):
		# C#3iiVVEvv		
		self.note       = text[0:3]        if text[0:3]  != '...' else None # C  is note (# sharp)
		self.instrument = int(text[3:5])-1 if text[3:5]  != '..'  else None # ii is the instrument number, 1..99
		self.volume     = int(text[5:7])   if text[5:7]  != '..'  else None # VV is the volume, 0..99 (lowest to highest)
		self.effect     = text[7]          if text[7]    != '.'   else None # E  is the effect name
		self.param      = int(text[8:10])  if text[8:10] != '..'  else None # vv is the effect value, only editable if the effect is specified

def export_files(outfile, outenum, files):
	modules = [TrackerModule(f) for f in files]

	# Combine instruments from the different modules
	combined_instruments = []
	for m in modules:
		for used in m.used_instruments:
			data = m.instruments[used]
			for i, v in enumerate(combined_instruments):
				if v.props == data.props:
					m.instrument_remap[used] = i + StreamingOffset
					break
			else:
				m.instrument_remap[used] = len(combined_instruments) + StreamingOffset
				data.encode_as_brr() # Prepare
				combined_instruments.append(data)

	# Combine songs/effects from the different modules
	combined_songs = []
	combined_effects = []
	for m in modules:
		for song in m.songs:
			if song != None and song.is_not_empty():
				if song.is_sound_effect():
					combined_effects.append(song)
				else:
					combined_songs.append(song)

	# Set up local instruments
	all_local_instruments = []
	for s in combined_songs:
		s.instrument_remap = s.module.instrument_remap.copy()
		for local in s.local_instruments:
			instrument_data = s.module.instruments[local]
			instrument_data.encode_as_brr()
			s.instrument_remap[local] = len(all_local_instruments) + len(combined_instruments) + StreamingOffset
			s.output_local_instruments.add(len(all_local_instruments)) 
			all_local_instruments.append(instrument_data)
	for s in combined_effects:
		s.instrument_remap = s.module.instrument_remap

	#############################################
	# Write the processed information
	#############################################
	out = open(outfile, 'w')

	# Step 1. Directories
	out.write('.include "snesgss.inc"\n')
	out.write('GSS_SampleADSR = * - %d\n' % (StreamingOffset*2))
	for i in combined_instruments:
		out.write('\t.byte %s\n' % i.adsr_string())
	for i in all_local_instruments:
		out.write('\t.byte %s\n' % i.adsr_string())
	out.write('GSS_SoundEffectDirectory:\n')
	for i in range(len(combined_effects)):
		out.write('\t.addr sound_effect_%d\n' % i)
	out.write('\tSOUND_EFFECT_COUNT = %d\n' % len(combined_effects))
	out.write('.align 256\n')
	out.write('GSS_SampleDirectory:\n')
	if StreamingEnabled:
		for i in range(1,9):
			out.write('\t.addr streamData%d, streamData%d\n' % (i, i))
		out.write('\t.addr streamSync, streamSync\n')
	for i, data in enumerate(combined_instruments):
		out.write('\t.addr instrument_addr_%d, instrument_addr_%d+%d\n' % (i, i, data.brr_loop))
	for i, data in enumerate(all_local_instruments):
		out.write('\t.addr local_instrument_addr_%d+GSS_MusicUploadAddress, local_instrument_addr_%d+%d+GSS_MusicUploadAddress\n' % (i, i, data.brr_loop))

	# Step 2. Sound effects and instrument data
	sound_effect_bytes_total = 0
	print('-Sound effects-')
	for i, data in enumerate(combined_effects):
		out.write('sound_effect_%d:\n' % i)		
		b = data.write_to_file(out, '0')
		print('%s:\t%d' % (data.props['Name'], b))
		sound_effect_bytes_total += b
	print('Total:\t%d\n' % sound_effect_bytes_total)

	brr_already_written = {}
	sample_bytes_total = 0
	print('-Global samples-')
	for i, data in enumerate(combined_instruments):
		if data.brr_data in brr_already_written:
			out.write('instrument_addr_%d = instrument_addr_%d ; %s\n' % (i, brr_already_written[data.brr_data], data.props['Name']))
			print('%s: 0 (reused)' % data.props['Name'])
		else:
			out.write('instrument_addr_%d: ;%s\n' % (i, data.props['Name']))
			out.write('  .byte %s\n' % data.brr_string())
			print('%s:\t%d' % (data.props['Name'], data.brr_size))
			sample_bytes_total += data.brr_size
	print('Total:\t%d\n' % sample_bytes_total)

	out.write('GSS_MusicUploadAddress:\n')

	out.write('.pushseg\n')
	out.write('.segment "SongData"\n')
	out.write('SongDirectory:\n')
	# Song directory
	for i, data in enumerate(combined_songs):
		out.write('\t.addr .loword(song_%d), song_%d_end - song_%d\n' % (i, i, i))

	# Actual data for song directory
	song_bytes_total = 0
	print('-Songs-')
	for i, data in enumerate(combined_songs):
		out.write('song_%d:\n' % i)
		out.write('.org 0\n')
		b = data.write_to_file(out, 'GSS_MusicUploadAddress')
		# Write local samples if there are any
		sample_bytes = 0
		for j in data.output_local_instruments:
			instrument_data = all_local_instruments[j]
			out.write('local_instrument_addr_%d: ;%s\n' % (j, instrument_data.props['Name']))
			out.write('  .byte %s\n' % instrument_data.brr_string())
			sample_bytes += instrument_data.brr_size
		out.write('.reloc\n')
		out.write('song_%d_end:\n' % i)
		print('%s: %d music + %d sample = %d' % (data.props['Name'], b, sample_bytes, b+sample_bytes))
		song_bytes_total += b
		song_bytes_total += sample_bytes
	print('Total: %d\n' % song_bytes_total)
	out.write('.popseg\n')
	out.close()

	#############################################
	# Write the enum file
	#############################################

	out = open(outenum, 'w')
	out.write('.enum Music\n')
	for i in combined_songs:
		out.write('\t%s\n' % i.props['Name'])
	out.write('.endenum\n\n')

	out.write('.enum SoundEffect\n')
	for i in combined_effects:
		out.write('\t%s\n' % i.props['Name'])
	out.write('.endenum\n')

	out.close()

export_files(sys.argv[1], sys.argv[2], sys.argv[3:])
