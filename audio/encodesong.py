# Effect
DELAY      = "GSS::DELAY"
NOTE       = "GSS::NOTE"
KEYOFF     = "GSS::KEYOFF"
LONGDELAY  = "GSS::LONGDELAY"
VOLUME     = "GSS::VOLUME"
PAN        = "GSS::PAN"
DETUNE     = "GSS::DETUNE"
SLIDE      = "GSS::SLIDE"
PORTAMENTO = "GSS::PORTAMENTO"
VIBRATO    = "GSS::VIBRATO"
REFERENCE  = "GSS::REFERENCE"
INSTRUMENT = "GSS::INSTRUMENT"
LOOP       = "GSS::LOOP"
MAX_ROWS = 10000

class TrackerData:
	def __init__(self):
		self.note = None
		self.instrument = None
		self.volume = None
		self.effect = None
		self.param = None

def encode_song(song, base):
	# Clean up the song
	song.chans = [x for x in song.chans if x != {}]

	# Expand repeating sections
	for channel in song.chans:
		section_start = 0
		section_end = 0
		repeat = False
		repeat_row = 0

		for row in range(song.props['Length']+1):
			if row in song.markers:
				section_start = section_end
				section_end = row
				repeat = False
			if row in channel:
				if channel[row].effect == 'R':
					repeat = True
					repeat_row = section_start
			if repeat:
				if repeat_row in channel:
					n = TrackerData()
					channel[row] = n

					m = channel[repeat_row]
					n.note = m.note
					n.instrument = m.instrument
					n.volume = m.volume # Added, not in original
					if m.effect != 'R':
						n.effect = m.effect
						n.param = m.param
				repeat_row += 1
				if repeat_row >= section_end:
					repeat_row = section_start
	song_cleanup(song)

	return [encode_song_channel(song, data, base) for data in song.chans]

def encode_song_channel(song, data, base):
	b = []                  # bytes for the channel
	keyoff_gap_duration = 2 # number of frames between keyoff and keyon, to prevent clicks

	speed = 20
	speed_acc = 0
	ins_change = -1
	ins_last = 1
	insert_gap = False
	effect = 0
	effect_volume = 255
	value = 0
	key_is_on = False
	porta_active = False
	start_row = 0

	length = song.props['Length']
	loop_start = song.props['LoopStart']
	loop_index = None # which index in b the loop goes back to
	looped_song = (loop_start != 0) or (length != MAX_ROWS-1)

	if not looped_song:
		# if loop markers are in the default positions, loop the song on the next to the last non-empty row, making it seem to be not looped
		length = song.last_row+1+2;
		loop_start = length-1

	for row in range(length):
		change = False

		if row == loop_start or row == start_row: # break the ongoing delays at the start and loop points
			delay_compile(b, speed_acc)
			speed_acc=0
		if row == start_row:
			if row: # Not used?
				inst_change = inst_last
				change = True
		if row == loop_start: 
			loop_index = len(b)
		if row in song.speeds:
			speed = song.speeds[row]

		if row in data:
			n = data[row]

			if n.instrument != None:
				ins_change = n.instrument
				ins_last = ins_change
			if n.effect != None and n.param != None:
				effect = n.effect
				value  = n.param
				change = True
			if n.volume != None:
				effect_volume = n.volume
				change = True
			if n.note:
				change = True

			if change:
				if effect == 'P':
					porta_active = bool(value) # detect portamento early to prevent inserting the keyoff gap
				if note_not_blank_or_keyoff(n.note) and key_is_on and (not porta_active) and speed_acc >= keyoff_gap_duration:
					# if it is a note (not keyoff) and there is enough empty space, insert keyoff with a gap before keyon
					speed_acc -= keyoff_gap_duration
					insert_gap = True
				else:
					insert_gap = False
				delay_compile(b, speed_acc)
				speed_acc = 0

				if n.note == '---':
					b.append(KEYOFF)
					key_is_on = False
				if effect == 'T':
					b.append(DETUNE)
					b.append(value)
					effect = 0
				if effect == 'D':
					b.append(SLIDE)
					b.append(-value)
					effect = 0
				if effect == 'U':
					b.append(SLIDE)
					b.append(value)
					effect = 0
				if effect == 'P':
					b.append(PORTAMENTO)
					b.append(value)
					effect = 0
				if effect == 'V':
					b.append(VIBRATO)
					b.append(value//10%10)|((value%10)<<4) #rearrange decimal digits into hex nibbles, in reversed order
					effect = 0
				if effect == 'S':
					b.append(PAN)
					b.append(value*256//100) #recalculate 0..50..99 to 0..128..255
					effect = 0
				new_note_keyoff = bool(key_is_on and insert_gap and (not porta_active))

				if (n.note == None or n.note == '---') and effect_volume != 255:
					# volume, only insert it here when there is no new note with preceding keyoff, otherwise insert it after keyoff
					b.append(VOLUME)
					b.append(round(effect_volume * 1.29)) # rescale 0..99 to 0..127
					effect_volume = 255
				if note_not_blank_or_keyoff(n.note):
					if new_note_keyoff:
						b.append(KEYOFF)
						delay_compile(b, keyoff_gap_duration)
						key_is_on = False
					if ins_change != -1:
						b.append(INSTRUMENT)
						b.append(song.instrument_remap[ins_change])
						ins_change = -1
					if effect_volume != 255: #volume, inserted after keyoff to prevent clicks
						b.append(VOLUME)
						b.append(round(effect_volume*1.29))
						effect_volume = 255
					b.append(NOTE+'+%d'%note_to_number(n.note))
					key_is_on = True
		speed_acc += speed

	# -----------------------------------------------------
	if loop_start in data:
		n = data[loop_start]

		if note_not_blank_or_keyoff(n.note):
			# if there is a new note at the loop point, prevent click by inserting a keyoff with gap just at the end of the channel
			speed_acc -= keyoff_gap_duration
		delay_compile(b, speed_acc)

		if note_not_blank_or_keyoff(n.note):
			b.append(KEYOFF)
			delay_compile(b, keyoff_gap_duration)

	# Try compressing it now
	b.insert(loop_index, 'LOOP')
	return min([channel_compress(b, loop_index, ref_len, looped_song, base) for ref_len in range(3, 20+1)], key=lambda x: len(x))

def command_length(command):
	lengths = {
		DELAY: 0,
		NOTE: 0,
		KEYOFF: 0,
		LONGDELAY: 2,
		VOLUME: 1,
		PAN: 1,
		DETUNE: 1,
		SLIDE: 1,
		PORTAMENTO: 1,
		VIBRATO: 1,
		INSTRUMENT: 1,
	}
	for k,v in lengths.items():
		if command.startswith(k):
			return v
	print("Error in command_length (%s)" % command)
	return 0

def grab_n_commands(b, length):
	b = b.copy()
	commands = []
	for i in range(length):
		if b == []:
			break
		c = b.pop(0)
		if c == 'LOOP':
			break
		commands.append(c)
		for i in range(command_length(c)):
			commands.append(b.pop(0))
	return commands, b

# https://stackoverflow.com/a/58267576
def find_list_in_list(txt, pat):
    M = len(pat) 
    N = len(txt) 

    # create lps[] that will hold the longest prefix suffix  
    # values for pattern 
    lps = [0]*M 
    j = 0 # index for pat[] 

    # Preprocess the pattern (calculate lps[] array) 
    computeLPSArray(pat, M, lps) 

    i = 0 # index for txt[] 
    while i < N: 
        if pat[j] == txt[i]: 
            i += 1
            j += 1

        if j == M: 
            return i-j

        # mismatch after j matches 
        elif i < N and pat[j] != txt[i]: 
            # Do not match lps[0..lps[j-1]] characters, 
            # they will match anyway 
            if j != 0: 
                j = lps[j-1] 
            else: 
                i += 1
    return -1

def computeLPSArray(pat, M, lps): 
    len = 0 # length of the previous longest prefix suffix 

    lps[0] # lps[0] is always 0 
    i = 1

    # the loop calculates lps[i] for i = 1 to M-1 
    while i < M: 
        if pat[i]== pat[len]: 
            len += 1
            lps[i] = len
            i += 1
        else: 
            # This is tricky. Consider the example. 
            # AAACAAAA and i = 7. The idea is similar  
            # to search step. 
            if len != 0: 
                len = lps[len-1] 

                # Also, note that we do not increment i here 
            else: 
                lps[i] = 0
                i += 1

def channel_compress(b, loop_index, ref_max, looped_song, base):
	out = []
	b = b.copy()
	loop_index = 0

	while len(b):
		if b[0] == 'LOOP':
			loop_index = len(out)
			b.pop(0)
			continue

		# Try matching decreasing amounts of commands
		length = ref_max
		while length >= 5:
			match_against, new_b = grab_n_commands(b, length)
			index = find_list_in_list(out, match_against)
			if index != -1:
				out.append(REFERENCE)
				out.append('<(:- +%d+%s)'%(index,base))
				out.append('>(:- +%d+%s)'%(index,base))
				out.append(len(match_against))
				b = new_b
				break
			length -= 1
		else:
			c, b = grab_n_commands(b, 1)
			for d in c:
				out.append(d)

	out.append(LOOP)
	out.append('<(:- +%d+%s)'%(loop_index,base))
	out.append('>(:- +%d+%s)'%(loop_index,base))
	return out

def delay_compile(b, delay):
	max_short_wait = 148 # max duration of the one-byte delay
	while delay:
		if delay < max_short_wait*2: # can be encoded as one or two one-byte delays
			if delay >= max_short_wait:
				b.append(DELAY+'+%d'%max_short_wait)
				delay -= max_short_wait
			else:
				b.append(DELAY+'+%d'%delay)
				delay = 0
		else:
			if delay >= 65535:
				b.append(LONGDELAY)
				b.append(255)
				b.append(255)
				delay -= 65535
			else:
				b.append(LONGDELAY)
				b.append(delay&255)
				b.append(delay>>8)
				delay = 0

def note_to_number(note):
	scale = ['C-', 'C#', 'D-', 'D#', 'E-', 'F-', 'F#', 'G-', 'G#', 'A-', 'A#', 'B-']
	#+1 is to copy a SNESGSS bug(?) where it's treating the notes as starting at 150 instead of 149
	return scale.index(note[0:2]) + (int(note[2])*12+1)

def note_not_blank_or_keyoff(note):
	return note != None and note != '---'

def song_cleanup(song):
	for channel in song.chans:
		prev_ins = -1
		prev_vol = -1

		for row in range(song.last_row + 1):
			if row in channel:
				n = channel[row]

				if n.instrument != None:
					if n.instrument != prev_ins:
						prev_ins = n.instrument
					else:
						n.instrument = None
				if n.volume != prev_vol:
					if n.volume != None:
						prev_vol = n.volume
				else:
					n.volume = None

			# set instrument and volume at the loop point, just in case
			if row == song.props['LoopStart'] and song.props['LoopStart'] > 0:
				# deal with how the row might not exist
				if row in channel:
					n = channel[row]
				else:
					n = TrackerData()
					channel[row] = n
				if n.instrument == None and prev_ins > 0:
					n.instrument = prev_ins
				if prev_vol >= 0:
					n.volume = prev_vol
