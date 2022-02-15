from encodesong import encode_song
from encodebrr import encode_brr

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
					self.songs[which] = TrackerSong()
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
						self.used_instruments.add(row.instrument)
		self.instrument_remap = {} # Dict for remapping to the combined list

class TrackerSong:
	def __init__(self):
		self.props  = {}
		self.chans  = [{}, {}, {}, {}, {}, {}, {}, {}]
		self.speeds = {}
		self.markers = set()
		self.last_row = 0

	def set(self, field, text):
		self.props[field] = text if field == 'Name' else int(text)

class TrackerInstrument:
	def __init__(self):
		self.props = {}
	def set(self, field, text):
		if field == 'Name' or field == 'SourceData':
			self.props[field] = text
		else:
			self.props[field] = int(text)
	def adsr_string(self):
		return '$%.2x, $%.2x' % (0x80|self.props['EnvAR']|(self.props['EnvDR']<<4), self.props['EnvSR']|(self.props['EnvSL']<<5))

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
					m.instrument_remap[used] = i
					break
			else:
				m.instrument_remap[used] = len(combined_instruments)
				combined_instruments.append(data)
		export_songs = {}
		for song in m.songs:
			if song != None and song.chans != [{}, {}, {}, {}, {}, {}, {}, {}]:
				export_songs[song.props['Name']] = encode_song(m, song)

	# Write the processed information
	out = open(outfile, 'w')
	out.write('SampleADSR:\n')
	for i in combined_instruments:
		out.write('  .byte %s\n' % i.adsr_string())
	out.write('.align 256\n')
	out.write('SampleDirectory:\n')
	for i in range(len(combined_instruments)):
		out.write('  .addr instrument_addr_%d, instrument_loop_%d\n' % (i, i))

	out.write('.pushseg\n')
	out.write('.segment "SongData"\n')
	for name, data in export_songs.items():
		out.write('song_%s:\n' % name)
		out.write('	.byte %d\n' % len(data))
		for i in range(len(data)):
			out.write('\t.addr song_%s_ch%d\n' % (name, i))
		for i, channel in enumerate(data):
			out.write('song_%s_ch%d:\n' % (name, i))
			print(len(channel))
			out.write(':\t.byt %s\n' % ', '.join([str(x) for x in channel]))
	out.write('.popseg\n')

	out.close()

	#out = open(outenum, 'w')
	#for
	#out.close()

export_files('gss_data.s', 'gss_enum.s', ['SimpleBeat.gsm'])#, 'SimpleBeat.gsm'])
