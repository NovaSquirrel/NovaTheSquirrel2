#!/usr/bin/env python3
from __future__ import with_statement, division, print_function
from contextlib import closing
import array, wave, sys, os, optparse, random
if str is not bytes:
    xrange = range

help_version = """karplus 0.01
Copyright 2015 Damian Yerrick
Copying and distribution of this file, with or without
modification, are permitted in any medium without royalty
provided the copyright notice and this notice are preserved.
This file is offered as-is, without any warranty.
"""

help_usage = "Usage: %prog [options] [OUTFILE]"
help_prolog = """
Generates a plucked-string sound using Karplus-Strong synthesis,
which applies echo at a period within audio frequency.
For an explanation of the theory, see
https://en.wikipedia.org/wiki/Karplus-Strong_string_synthesis
"""
help_epilog = """
Excitation formulas:

random is a uniform pseudorandom number generator.

square:n:d:b produces a square wave with n/d duty cycle, where 0 < n < d.
If b is 0, the square wave is positive; if it is nonzero, the excitation
is balanced.  square is a synonym for square:1:2:1.

saw:n:d:p produces a sawtooth raised to p power occupying the first
n/d of each period, where 1 <= p and 0 < n <= d.  saw is a synonym
for saw:1:1:1.
"""


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

def get_fir_group_delay(kernel):
    """Calculate the group delay of an FIR filter.

This is valid at low frequencies for all FIR kernels and at all
frequencies for symmetric (linear phase) kernels.

"""
    return sum(a * b for a, b in enumerate(kernel)) / sum(kernel)

def karplus_echo(wave, delay, decay, kernel, length, rawkernel=False):
    """Perform Karplus-Strong string synthesis on an excitation waveform.

wave -- a modifiable sequence of sample values, usually a list
    or a floating point array containing a short burst of noise or
    other wideband excitation, to which samples shall be appended
delay -- a number of samples
decay -- a factor used to scale the waveform before filtering it,
    usually 0.9 to 1
kernel -- a sequence that will be convolved with the delayed samples.
    If rawkernel is not set, make a copy of kernel scaled to have
    a sum of 1.
maxlen -- the number of samples

The effective period in samples is the delay value plus the group
delay of fircoeffs. For example, the kernel [1, 6, 1] has a group
delay of 1.  So kernel = [1, 6, 1] and delay = 49 actually produces
a period of  50 samples: 49 from delay and 1 from kernel.

"""
    if not rawkernel:
        decay = decay / sum(kernel)
    kernel = [c * decay for c in kernel]
    delayend = delay + len(kernel)
    while len(wave) < length:
        prev = wave[-delay:-delayend:-1]
        dot = sum(a * b for a, b in zip(kernel, prev))
        wave.append(dot)

def make_bass_sample():
    """Make a bass guitar sample using Karplus-Strong synthesis.

It consists of a single cycle of a 25% duty, 64-sample waveform,
echoed 16 times.

"""
    karpbuf = [30000]*16+[-10000]*48
    fircoeffs = [1, 6, 1]
    # Use 1.00 in an enveloped environment (xm, it, spc)
    # Use 0.99 in a non-enveloped environment (mod, s3m, nsf)
    decay = 1.00
    delay = len(karpbuf) - int(round(get_fir_group_delay(fircoeffs)))
    maxlen = 1024
    karplus_echo(karpbuf, delay, decay, fircoeffs, maxlen)
    outbuf = array.array('h',
                         (min(32000, max(-32000, int(round(c)))) for c in karpbuf))
    save_wave_as_mono16("karplus.wav", 4186, outbuf)

# And the other half is deciding what to make.

def random_excitation(length, amplitude, args=None):
    return [random.randrange(-amplitude, amplitude + 1)
            for i in xrange(length)]

def square_excitation(length, amplitude, args=None):
    num = int(args[0]) if len(args) >= 2 else 1
    den = int(args[1]) if len(args) >= 2 else 2
    highlen = int(round(num * length / den))
    if not 0 < highlen < length:
        raise ValueError("duty numerator %d must be strictly between 0 and denominator %d"
                         % (num, den))
    lowlen = length - highlen

    balanced = int(args[2]) if len(args) >= 3 else 1
    if not balanced:
        highlevel = amplitude
        lowlevel = 0
    elif highlen < lowlen:
        highlevel = amplitude
        lowlevel = -int(round(amplitude * highlen / lowlen))
    else:
        highlevel = int(round(amplitude * lowlen / highlen))
        lowlevel = -amplitude
    return [highlevel] * highlen + [lowlevel] * lowlen

def saw_excitation(length, amplitude, args=None):
    num = int(args[0]) if len(args) >= 2 else 1
    den = int(args[1]) if len(args) >= 2 else 2
    power = float(args[2]) if len(args) < 3 else 1
    highlen = int(round(num * length / den))
    if not 0 < highlen < length:
        raise ValueError("duty numerator %d must be no greater than denominator %d"
                         % (num, den))
    if not 0 < power:
        raise ValueError("exponent %f must be greater than 0" % power)

    scale = amplitude / ramp[0]
    ramp = [(i / (highlen - 1)) ** power * amplitude
            for i in xrange(highlen - 1, 0, -2)]
    ramp = ramp[::-1] + [-i for i in ramp]
    return ramp + [0] * (length - len(ramp))

excitation_types = {
    'random': random_excitation,
    'square': square_excitation,
    'saw': saw_excitation
}

class MultiGrafIndentedHelpFormatter(optparse.IndentedHelpFormatter):
    """An optparse.IndentedHelpFormatter supporting multi-paragraph text."""

    @staticmethod
    def paragraphize(text):
        """Split text into paragraphs at multiple blank lines.

Return an iterator of strings each containing one paragraph.

"""
        lines = []
        for line in text.split("\n"):
            line = line.rstrip()
            if line:
                lines.append(line)
            elif lines:
                yield '\n'.join(lines)
                lines = []
        if lines:
            yield '\n'.join(lines)

    def _format_text(self, text):
        """
        Format multiple paragraphs of free-form text for inclusion
        in the help output at the current indentation level.
        """
        fmt = super(MultiGrafIndentedHelpFormatter, self)._format_text
        return "\n\n".join(fmt(graf) for graf in self.paragraphize(text))

def parse_argv(argv):
    parser = optparse.OptionParser(version=help_version, usage=help_usage,
                                   description=help_prolog, epilog=help_epilog,
                                   formatter=MultiGrafIndentedHelpFormatter())
    parser.add_option("-o", dest="outfilename",
                      help="write output to OUTFILE",
                      metavar="OUTFILE")
    parser.add_option("-n", "--length", dest="length",
                      metavar="PERIOD", type="int", default=1024,
                      help="set the output length in samples (default: 1024)")
    parser.add_option("-p", "--period", dest="period",
                      metavar="PERIOD", type="int", default=32,
                      help="set the wave period in samples (default: 32)")
    parser.add_option("-r", "--rate", dest="rate",
                      metavar="RATE", type="int", default=8372,
                      help="with -d, set the wave sample rate in Hz (default: 8372)")
    parser.add_option("-e", "--excitation", dest="excitation",
                      help="set excitation to FORMULA (default: random)",
                      metavar="FORMULA", default="random")
    parser.add_option("-a", "--amplitude", dest="amplitude",
                      metavar="VALUE", type="int", default=32000,
                      help="set excitation amplitude to VALUE (up to 32767; default 32000)")
    parser.add_option("-g", "--gain", dest="gain",
                      metavar="AMOUNT", type="float", default=1.0,
                      help="feed AMOUNT of the signal back the delay line (default: 1.0; also try .9 or .98)")
    parser.add_option("-f", "--lpf-strength", dest="lpfstrength",
                      metavar="AMOUNT", type="float", default=1.0,
                      help="set strength of low-pass filter on feedback to AMOUNT (0.0 to 1.33; default: 0.5)")

    (options, pos) = parser.parse_args(argv[1:])
    if not options.outfilename:
        try:
            outfilename = pos[0]
        except IndexError:
            parser.error("output file not specified; try %s --help"
                         % os.path.basename(argv[0]))
    if not 4 <= options.period <= options.length:
        parser.error("period is too short")
    if not 10 <= options.rate <= 128000:
        parser.error("output sample rate must be 10 to 128000 Hz")
    excitation = options.excitation.split(':')
    try:
        exciter = excitation_types[excitation[0]]
    except KeyError:
        parser.error("unknown excitation type %s" % excitation[0])
    exciteargs = excitation[1:]
    if options.amplitude > 32767:
        parser.error("amplitude must be no greater than 32767")
    if not 0.0 <= options.gain <= 1.0:
        parser.error("gain must be 0.0 to 1.0")
    if not 0.0 <= 3 * options.lpfstrength <= 4.0:
        parser.error("filter strength must be 0.0 to 1.33")

    return options, exciter, exciteargs

def main(argv=None):
    argv = argv or sys.argv
    options, exciter, exciteargs = parse_argv(argv)
    karpbuf = exciter(options.period, options.amplitude, exciteargs)
    fircoeffs = [options.lpfstrength,
                 4.0 - options.lpfstrength * 2,
                 options.lpfstrength]
    delay = len(karpbuf) - 1
    karplus_echo(karpbuf, delay, options.gain, fircoeffs, options.length)
    outbuf = array.array('h',
                         (min(32767, max(-32767, int(round(c))))
                          for c in karpbuf))
    save_wave_as_mono16(options.outfilename, options.rate, outbuf)
    
if __name__=='__main__':
##    main([sys.argv[0], '-o', 'test.wav'])
##    main([sys.argv[0], '-o', 'karplusbass.wav', '-n', '1024',
##          '-p', '64', '-r', '4186', '-e', 'square:1:4',
##          '-a', '30000', '-g', '1.0', '-f', '.5'])
    main()
