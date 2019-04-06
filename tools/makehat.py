#!/usr/bin/env python3
from contextlib import closing
import sys
import random
import array
import wave

def save_wave_as_mono16(filename, freq, data):
    data = array.array('h', (min(max(s, -32767), 32767) for s in data))
    little = array.array('H', b'\x01\x00')[0] == 1
    if not little:
        data.byteswap()
    with closing(wave.open(filename, "wb")) as outfp:
        outfp.setnchannels(1)
        outfp.setsampwidth(2)
        outfp.setframerate(freq)
        outfp.writeframes(data.tobytes())

def main(argv=None):
    argv = argv or sys.argv
    outfilename = argv[1]
    
    rands = [random.randrange(2) * (1600 - i) * (1600 - i) for i in range(1600)]
    rands.extend([0])
    rands = [int(round((b - a) / 128)) for a, b in zip(rands, rands[1:])]
    save_wave_as_mono16(outfilename, 16744, rands)

if __name__=='__main__':
    main()
