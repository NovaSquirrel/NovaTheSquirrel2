#!/usr/bin/make -f
#
# Makefile for LoROM template
# Copyright 2014-2015 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# These are used in the title of the SFC program and the zip file.
title = nova-the-squirrel-2
version = 0.01

# Space-separated list of asm files without .s extension
# (use a backslash to continue on the next line)
objlist = \
  snesheader init main player memory common renderlevel \
  uploadppu blarggapu spcimage musicseq graphics blockdata \
  scrolling
objlistspc = \
  spcheader spcimage musicseq
brrlist = \
  karplusbassloop hat kickgen decentsnare

AS65 := ca65
LD65 := ld65
CFLAGS65 = 
objdir := obj/snes
srcdir := src
imgdir4 := tilesets4
imgdir2 := tilesets2

# If it's not bsnes, it's just BS.  But I acknowledge that being
# stuck on an old Atom laptop is BS.  Atom N450 can't run bsnes at
# full speed, but the Atom-based Pentium N3710 can.
ifndef SNESEMU
#SNESEMU := xterm -e zsnes -d
SNESEMU := bsnes
endif

# game-music-emu by blargg et al.
# Using paplay-based wrapper from
# https://forums.nesdev.com/viewtopic.php?f=6&t=16218
SPCPLAY := gmeplay

ifdef COMSPEC
PY := py.exe
else
PY :=
endif

# Calculate the current directory as Wine applications would see it.
# yep, that's 8 backslashes.  Apparently, there are 3 layers of escaping:
# one for the shell that executes sed, one for sed, and one for the shell
# that executes wine
# TODO: convert to use winepath -w
wincwd := $(shell pwd | sed -e "s'/'\\\\\\\\'g")

# .PHONY means these targets aren't actual filenames
.PHONY: all run nocash-run spcrun dist clean

# When you type make without a target name, make will try
# to build the first target.  So unless you're trying to run
# NO$SNS in Wine, you should move run above nocash-run.
run: $(title).sfc
	$(SNESEMU) $<

# Special target for just the SPC700 image
spcrun: $(title).spc
	$(SPCPLAY) $<

all: $(title).sfc $(title).spc

clean:
	-rm $(objdir)/*.o $(objdir)/*.chr $(objdir)/*.ov53 $(objdir)/*.sav $(objdir)/*.pb53 $(objdir)/*.s

dist: zip
zip: $(title)-$(version).zip
$(title)-$(version).zip: zip.in all README.md $(objdir)/index.txt
	$(PY) tools/zipup.py $< $(title)-$(version) -o $@
	-advzip -z3 $@

# Build zip.in from the list of files in the Git tree
zip.in:
	git ls-files | grep -e "^[^.]" > $@
	echo zip.in >> $@
	echo $(title).sfc >> $@
	echo $(title).spc >> $@

$(objdir)/index.txt: makefile
	echo "Files produced by build tools go here. (This file's existence forces the unzip tool to create this folder.)" > $@

# Rules for ROM

objlisto = $(foreach o,$(objlist),$(objdir)/$(o).o)
objlistospc = $(foreach o,$(objlistspc),$(objdir)/$(o).o)
brrlisto = $(foreach o,$(brrlist),$(objdir)/$(o).brr)
chr4all := $(patsubst %.png,%.chrsfc,$(wildcard tilesets4/*.png))
chr2all := $(patsubst %.png,%.chrgb,$(wildcard tilesets2/*.png))

map.txt $(title).sfc: lorom1024k.cfg $(objlisto)
	$(LD65) -o $(title).sfc -m map.txt -C $^
	$(PY) tools/fixchecksum.py $(title).sfc

spcmap.txt $(title).spc: spc.cfg $(objlistospc)
	$(LD65) -o $(title).spc -m spcmap.txt -C $^

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/snes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/mktables.s: tools/mktables.py
	$< > $@

# Files that depend on extra included files
$(objdir)/bg.o:
$(objdir)/player.o:
$(objdir)/spcimage.o: $(brrlisto)

# Block data relies on the enum
$(objdir)/blockdata.o: $(srcdir)/blockenum.s

# Automatically insert graphics into the ROM
$(srcdir)/graphics.s: $(chr2all) $(chr4all) tools/gfxlist.txt
	$(PY) tools/insertthegfx.py

# Automatically create the list of blocks from a description
$(srcdir)/blockdata.s: tools/blocks.txt
$(srcdir)/blockenum.s: tools/blocks.txt
	$(PY) tools/makeblocks.py

#$(objdir)/graphics.o: $(chr2all) $(chr4all)


$(objdir)/musicseq.o $(objdir)/spcimage.o: src/pentlyseq.inc


# Rules for CHR data

# .chrgb (CHR data for Game Boy) denotes the 2-bit tile format
# used by Game Boy and Game Boy Color, as well as Super NES
# mode 0 (all planes), mode 1 (third plane), and modes 4 and 5
# (second plane).
# Try generating it in the folder it's for
$(imgdir2)/%.chrgb: $(imgdir2)/%.png
	$(PY) tools/pilbmp2nes.py --planes=0,1 $< $@
$(imgdir4)/%.chrsfc: $(imgdir4)/%.png
	$(PY) tools/pilbmp2nes.py "--planes=0,1;2,3" $< $@


# Rules for audio
$(objdir)/%.brr: audio/%.wav
	$(PY) tools/wav2brr.py $< $@
$(objdir)/%.brr: $(objdir)/%.wav
	$(PY) tools/wav2brr.py $< $@
$(objdir)/%loop.brr: audio/%.wav
	$(PY) tools/wav2brr.py --loop $< $@
$(objdir)/%loop.brr: $(objdir)/%.wav
	$(PY) tools/wav2brr.py --loop $< $@
$(objdir)/karplusbass.wav: tools/karplus.py
	$(PY) $< -o $@ -n 1024 -p 64 -r 4186 -e square:1:4 -a 30000 -g 1.0 -f .5
$(objdir)/hat.wav: tools/makehat.py
	$(PY) $< $@
