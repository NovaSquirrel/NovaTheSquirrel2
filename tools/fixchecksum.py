#!/usr/bin/env python3
"""

Super NES
See versionText for copyright

"""
import os, sys, argparse

modes = {
    'lorom': (0x20, 0x7FDC),
    'hirom': (0x21, 0xFFDC),
    'exhirom': (0x25, 0x40FFDC)
}
helptop = 'Calculates the header checksum for a Super NES executable.'
helpbottom = """
If the input file has a 512-byte header for obsolete floppy-based
copiers, it will be removed.  Modern emulators and flash solutions
do not need this header.
"""
versionText = """
0.01wip
Copyright 2016 Damian Yerrick
[free software license notice goes here]
"""

def parse_argv(argv):
    def mode_sort_key(x):
        return (0, 0, '') if x[1] is None else (1, modes[x[1]][0], x[0])

    modechoices = [('auto', None)]
    modechoices.extend((s, s) for s in modes)
    modechoices.extend(('%02x' % m, s) for s, (m, a) in modes.items())
    modechoices.extend(('%02x' % (m | 0x10), s) for s, (m, a) in modes.items())
    modechoices.sort(key=mode_sort_key)
    sorted_modes = [row[0] for row in modechoices]
    modechoices = dict(modechoices)

    parser = argparse.ArgumentParser(
        description=helptop,
        epilog=helpbottom.strip(),
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('--version', action='version',
                        version=versionText.strip())
    parser.add_argument('-v', '--verbose', action="store_true",
                        help='show work on stderr')
    parser.add_argument('infilename',
                        help='name of .sfc image')
    parser.add_argument('outfilename', nargs='?', default=None,
                        help='name of output image with correct header; overwrites original if blank')
    parser.add_argument('--mode', choices=sorted_modes, default="auto",
                        help='override mapping mode')
    parser.add_argument('--double', action="store_true",
                        help='double the executable up to a power of two when writing')
    out = parser.parse_args(argv[1:])
    out.mode = modechoices[out.mode]
    return out

def doubleup(seq, verbose=True):
    """Double up a mutable sequence to the next power of two.

As long as the length of the sequence is not a power of two, find the
least significant bit of the length and duplicate that many bytes at
the end of the sequence.  There will be one more call to seq.extend()
than there are zero bits between the most and least significant 1 bit
in the length.

For example, a sequence of length 22 (10110) will be doubled up to
24 (11000) by duplicating the last two elements and then to 32
(100000) by duplicating the last eight.

Return a list of previous sizes from the smallest to the largest,
whose length is the number of duplications.
"""
    sizes = []
    while True:
        # The amount to be added to the end is the least significant
        # bit of the length.
        sz = len(seq)
        sz_lsb = sz & -sz
        if sz_lsb == sz:
            return sizes
        sizes.append(sz)
        seq.extend(seq[-sz_lsb:])

def main(argv=None):
    argv = argv or sys.argv
    args = parse_argv(argv)
    inmode, csaddress = modes.get(args.mode, (None, None))
    outfilename = args.outfilename or args.infilename
    progname = os.path.basename(argv[0])
    errpfx = "%s: %s: " % (progname, args.infilename)
    if args.verbose:
        print("Reading %s and writing %s starting at %s"
              % (args.infilename, outfilename,
                 '%06x' % csaddress if csaddress else 'wherever'),
              file=sys.stderr)

    # Ensure size is within appropriate bounds
    with open(args.infilename, 'rb') as infp:
        data = bytearray(infp.read(8*1048576 + 512))
        exdata = infp.read(1)
    if exdata:
        print(errpfx+"file exceeds 64 Mbit", sys.stderr)
        sys.exit(1)
    if len(data) < 131072:
        msg = "file is smaller than 1 Mbit" if data else "file is empty"
        print(errpfx+msg, file=sys.stderr)
        sys.exit(1)
    if args.verbose:
        mbitsize = len(data) / 131072
        print("%sfile length is %.1f Mbit ($%X)"
              % (errpfx, mbitsize, len(data)), file=sys.stderr)

    # Chop off copier header if needed
    if len(data) % 32768 == 512:
        del data[:512]
        if args.verbose:
            print(errpfx+"removed copier header", file=sys.stderr)

    # Checksums are calculated based on doubling up the ROM size
    # to a power of two
    doubled = bytearray(data)
    oldsizes = doubleup(doubled)
    if oldsizes and args.verbose:
        toldsizes = ''.join("%d to " % sz for sz in oldsizes)
        print("%sdoubled up from %s%d ($%x) bytes"
              % (errpfx, toldsizes, len(doubled), len(doubled)),
              file=sys.stderr)

    # Autodetect mapping mode
    using_mode, using_modename = inmode, args.mode
    if inmode is None:
        for modename, (mode, csaddress) in modes.items():
            if csaddress + 4 > len(doubled):
                continue
            if doubled[csaddress - 7] & 0xEF == mode:
                using_mode, using_modename = mode, modename
                if args.verbose:
                    print("%sautodetected %s ($%02x) mapping mode"
                          % (errpfx, modename, doubled[csaddress - 7]),
                          file=sys.stderr)
                break
        if using_mode is None:
            print(errpfx+"could not detect mapping mode as lorom, hirom, or exhirom",
                  file=sys.stderr)
            sys.exit(1)
    mode_from_file = doubled[csaddress - 7]
    modediff = (using_mode ^ mode_from_file) & 0xEF
    if modediff:
        if args.verbose:
            print("%swarning: %s ($%02x) mapping mode doesn't match $%02x mode in file"
                  % (errpfx, modename, doubled[csaddress - 7]),
                  file=sys.stderr)

    # Actually calculate the checksum
    doubled[csaddress:csaddress + 4] = [0, 0, 255, 255]
    bytesum = sum(doubled)
    doubled[csaddress + 2] = bytesum & 0xFF
    doubled[csaddress + 3] = (bytesum >> 8) & 0xFF
    doubled[csaddress + 0] = doubled[csaddress + 2] ^ 0xFF
    doubled[csaddress + 1] = doubled[csaddress + 3] ^ 0xFF
    if args.verbose:
        print("%ssum of bytes is %s ($%08x)"
              % (errpfx, bytesum, bytesum), file=sys.stderr)
        tcsum = ' '.join('%02x' % b for b in doubled[csaddress:csaddress + 4])
        print("%schecksum bytes are %s"
              % (errpfx, tcsum), file=sys.stderr)

    if not args.double:
        del doubled[len(data):]
    with open(outfilename, 'wb') as outfp:
        outfp.write(doubled)

if __name__=='__main__':
##    try:
##        main('fixchecksum.py --help'.split())
##    except SystemExit:
##        print("then it'd exit.  Good.")
##    else:
##        assert False
##    try:
##        main('fixchecksum.py --version'.split())
##    except SystemExit:
##        print("then it'd exit.  Good.")
##    else:
##        assert False
##    main('fixchecksum.py -v ../lorom-template.sfc fixed.sfc --mode 20'.split())
    main()
