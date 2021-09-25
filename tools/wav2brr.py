#!/usr/bin/env python3
#
# Wave to BRR converter
# Copyright 2016, 2021 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.

from contextlib import closing
import array, wave, sys, os, optparse
try:
    import numpy as np
except ImportError:
    using_numpy = False
else:
    using_numpy = True

def naive_convolve(fircoeffs, wavdata):
    lside = len(fircoeffs) - 1
    rside = len(fircoeffs) - lside
    return [sum(a * b
                for a, b in zip(fircoeffs[max(lside - i, 0):],
                                wavdata[max(i - lside, 0): i + rside]))
            for i in range(len(wavdata) + len(fircoeffs) - 1)]

convolve = np.convolve if using_numpy else naive_convolve

def convolve_test():
    fircoeffs = [1/16, 4/16, 6/16, 4/16, 1/16]
    data = [0, 1, 0, 0, 0, 1, 2, 3, 4, 5]
    print(naive_convolve(fircoeffs, data))
    print(list(np.convolve(fircoeffs, data)))

def load_wave_as_mono_s16(filename):
    little = array.array('H', b'\x01\x00')[0] == 1
    with closing(wave.open(filename, "rb")) as infp:
        bytedepth = infp.getsampwidth()
        if bytedepth not in (1, 2):
            raise ValueError("unsupported sampwidth")
        n_ch = infp.getnchannels()
        datatype = 'h' if bytedepth == 2 else 'B'
        freq = infp.getframerate()
        length = infp.getnframes()
        data = array.array(datatype, infp.readframes(length))
    if datatype == 'B':
        # Expand 8 to 16 bit
        data = array.array('h', ((c - 128) << 8 for c in data))
    elif not little:
        # 16-bit data is little-endian in the wave file; it needs to
        # be byteswapped for big-endian platforms
        data.byteswap()
    if n_ch > 1:
        # average all channels
        data = array.array('h', (int(round(sum(data[i:i + n_ch]) / n_ch))
                                 for i in range(0, len(data), n_ch)))
    return (freq, data)

def save_wave_as_mono_s16(filename, freq, data):
    data = array.array('h', (min(max(s, -32767), 32767) for s in data))
    little = array.array('H', b'\x01\x00')[0] == 1
    if not little:
        data.byteswap()
    with closing(wave.open(filename, "wb")) as outfp:
        outfp.setnchannels(1)
        outfp.setsampwidth(2)
        outfp.setframerate(freq)
        outfp.writeframes(data.tobytes())

def brr_preemphasize(wavdata):
    """Emphasize a sample's highs to compensate for S-DSP Gaussian interpolation."""
    preem = \
    [0.00417456, -0.017636, 0.03906008, -0.06200069, 0.07113042,
    -0.0255472, -0.26998287, 1.52160339, -0.26998287, -0.0255472,
    0.07113042, -0.06200069, 0.03906008, -0.017636, 0.00417456]
    return [int(round(s)) for s in convolve(preem, wavdata)[7:-7]]

def brr_deemphasize(wavdata):
    """Approximate the effect of Gaussian interpolation."""
    deem = \
    [372/2048, 1304/2048, 372/2048]
    return [int(round(s)) for s in convolve(deem, wavdata)[1:-1]]
    

brr_filters = [
    (0, 0),
    (0, 0.9375),
    (-0.9375, 1.90625),
    (-0.8125, 1.796875)
]

def enfilter(wav, coeffs, prevs=[], quant=None):
    """Calculates residuals from an IIR predictive filter.

wav: iterable of sample values
prevs: previous block of quantized and decoded samples
quant: None during test filtering; 2 to 4096 during encoding

"""
    prevs = list(prevs)[-len(coeffs):]
    if len(prevs) < len(coeffs):
        prevs = ([0] * len(coeffs) + prevs)[-len(coeffs):]
    out = []
    for c in wav:
        pred = sum(coeff * prev
                   for coeff, prev in zip(coeffs, prevs[-len(coeffs):]))
        rescaled = resid = (c - pred)
        if quant:
            resid = int(round(resid / quant))
            resid = max(-8, min(7, resid))
            rescaled = resid * quant
        out.append(resid)
        prevs.append(rescaled + pred)
    return out, prevs[-len(coeffs):]

def defilter(wav, coeffs, prevs=[], quant=1):
    """Applies an IIR predictive filter to residuals.

wav: block of unpacked residuals
prevs: previous block of decoded samples
quant: number by which all residuals shall be multiplied

"""
    prevs = list(prevs)[-len(coeffs):]
    if len(prevs) < len(coeffs):
        prevs = ([0] * len(coeffs) + prevs)[-len(coeffs):]
    out = []
    for resid in wav:
        rescaled = resid * quant
        pred = sum(coeff * prev
                   for coeff, prev in zip(coeffs, prevs[-len(coeffs):]))
        c = (rescaled + int(round(pred)))
        out.append(c)
        prevs.append(c)
    return out

CLIP_MAX = 32000

def encode_brr(wav, looped=False):
    prevs = []
    out = bytearray()
    for t in range(0, len(wav), 16):
        piece = wav[t:t + 16]

        # Occasionally, treble boost may cause a sample to clip.
        peak = max(abs(c) for c in piece)
        if peak > CLIP_MAX:
##            print("clip peak %d at time %d" % (peak, t))
            piece = [max(min(c, CLIP_MAX), -CLIP_MAX) for c in piece]

        if prevs:
            # Calculate the peak residual for this piece with
            # each filter, then choose the smallest
            trials = [max(abs(resid)
                          for resid in enfilter(piece, coeffs, prevs)[0])
                      for coeffs in brr_filters]
            peak, filterid = min((r, i) for (i, r) in enumerate(trials))
        else:
            # first block always uses filter 0
            peak = max(abs(resid) for resid in piece)
            filterid = 0

        logquant = 0
        while logquant < 12 and peak >= (7 << logquant):
            logquant += 1
        resids, prevs = enfilter(piece, brr_filters[filterid],
                                 prevs or [], 1 << (logquant + 0))
        resids.extend([0] * (16 - len(resids)))
        byte0 = (logquant << 4) | (filterid << 2)
        if t + 16 >= len(wav):
            byte0 = byte0 | (3 if looped else 1)
##        print("filter #%d, scale %d,\nresids %s\n%s"
##              % (filterid, 1 << logquant, repr(resids), repr(list(piece))))
        out.append(byte0)
        for i in range(0, len(resids), 2):
            hinibble = resids[i] & 0x0F
            lonibble = resids[i + 1] & 0x0F
            out.append((hinibble << 4) | lonibble)
    return bytes(out)

def decode_brr(brrdata):
    prevs = [0, 0]
    out = []
    for i in range(0, len(brrdata), 9):
        piece = bytes(brrdata[i:i + 9])
        logquant = piece[0] >> 4
        filterid = (piece[0] >> 2) & 0x03
        resids = [((b >> i & 0x0F) ^ 8) - 8
                  for b in piece[1:] for i in (4, 0)]
        decoded = defilter(resids, brr_filters[filterid],
                           prevs, 1 << (logquant + 0))
##        print("filter #%d, scale %d,\nresids %s\n%s"
##              % (filterid, 1 << logquant, repr(resids), repr(decoded)))
        out.extend(decoded)
        prevs = decoded
    return out

# Command line parsing and help #####################################
#
# Easy is hard.  It takes a lot of code and a lot of text to make a
# program self-documenting and resilient to bad input.

usageText = "usage: %prog [options] [-i] INFILE [-o] OUTFILE"
versionText = """wav2brr 0.04

Copyright 2014 Damian Yerrick
Copying and distribution of this file, with or without
modification, are permitted in any medium without royalty provided
the copyright notice and this notice are preserved in all source
code copies. This file is offered as-is, without any warranty.
"""
descriptionText = """
Audio converter for Super NES S-DSP.
"""

def parse_argv(argv):
    parser = optparse.OptionParser(usage=usageText, version=versionText,
                                   description=descriptionText)
    parser.add_option("-i", "--input", dest="infilename",
                      help="read from INFILE",
                      metavar="INFILE")
    parser.add_option("-o", "--output", dest="outfilename",
                      help="write output to OUTFILE",
                      metavar="OUTFILE")
    parser.add_option("-d", "--decompress",
                      action="store_true", dest="decompress", default=False,
                      help="decompress BRR to wave (default: compress wave to BRR)")
    parser.add_option("--emph", "--emphasize",
                      action="store_true", dest="emph", default=False,
                      help="read wave, write preemphasized (treble boosted) wave")
    parser.add_option("--deemph", "--deemphasize",
                      action="store_true", dest="deemph", default=False,
                      help="read wave, write deemphasized wave")
    parser.add_option("-r", "--rate", dest="rate",
                      metavar="RATE", type="int", default=None,
                      help="output wave sample rate in Hz "
                      "(default: 8372 for -d; input rate for --emph and --deeemph)")
    parser.add_option("--loop",
                      action="store_true", dest="loop", default=False,
                      help="set the BRR's loop bit")
    parser.add_option("--skip-filter",
                      action="store_true", dest="skipfilter", default=False,
                      help="skip (de)emphasis when (de)compressing")

    (options, pos) = parser.parse_args(argv[1:])

    if options.rate is not None and not 10 <= options.rate <= 128000:
        parser.error("output sample rate must be 10 to 128000 Hz")

    # Fill unfilled roles with positional arguments
    pos = iter(pos)
    try:
        options.infilename = options.infilename or next(pos)
    except StopIteration:
        parser.error("no input file; try %s --help"
                     % os.path.basename(sys.argv[0]))
    try:
        options.outfilename = options.outfilename or next(pos)
    except StopIteration:
        parser.error("no output file")

    # make sure no trailing arguments
    try:
        next(pos)
        parser.error("too many filenames")
    except StopIteration:
        pass
    return options

DEFAULT_RATE = 8372

def main(argv=None):
    opts = parse_argv(argv or sys.argv)
    if opts.emph:
        freq, wave = load_wave_as_mono_s16(opts.infilename)
        wave = brr_preemphasize(wave)
        save_wave_as_mono_s16(opts.outfilename, opts.rate or freq, wave)
    elif opts.deemph:
        freq, wave = load_wave_as_mono_s16(opts.infilename)
        wave = brr_deeemphasize(wave)
        save_wave_as_mono_s16(opts.outfilename, opts.rate or freq, wave)
    elif opts.decompress:
        with open(opts.infilename, 'rb') as infp:
            brrdata = infp.read()
        out = decode_brr(brrdata)
        if not opts.skipfilter:
            out = brr_deemphasize(out)
        save_wave_as_mono_s16(opts.outfilename, opts.rate or DEFAULT_RATE, out)
    else:
        freq, wave = load_wave_as_mono_s16(opts.infilename)
        if not opts.skipfilter:
            wave = brr_preemphasize(wave)
        brrdata = encode_brr(wave, looped=opts.loop)
        with open(opts.outfilename, 'wb') as outfp:
            outfp.write(brrdata)

if __name__=='__main__':
    if "idlelib" in sys.modules:
        main()
    else:
        main()
##    convolve_test()
