#!/usr/bin/make -f
#
# Based on the makefile for LoROM template
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
  snesheader init main player memory common renderlevel renderlevel2 renderlevelsprites \
  uploadppu graphics blockdata tad-audio_config audio_incbins audio_misc \
  scrolling playergraphics blockinteraction palettedata \
  levelload levelautotile leveldata levelarray actordata actorcode actorshared \
  mode7/mode7 mode7/m7blocks mode7/m7actors mode7/m7math mode7/m7leveldata mode7/m7blockdata mode7/perspective_data mode7/m7playergraphics \
  overworldblockdata overworlddata overworldcode sincos_data inventory vwf \
  math portraitdata dialog namefont namefontwidth vwf_fontdata \
  lz4 dialog_npc_data dialog_text_data itemcode itemdata color_math_settings \
  backgrounddata bgeffectcode playerdraw playerability iris \
  playerprojectile hubworld

CC := gcc
AS65 := ca65
LD65 := ld65
CFLAGS65 = -g
TAD_COMPILER := audio/tad-compiler

objdir := obj/snes
audiodir := audio
srcdir := src
imgdirX := tilesetsX
imgdir4 := tilesets4
imgdir2 := tilesets2
bgdir := backgrounds

ifndef SNESEMU
SNESEMU := ./mesen
endif

lz4_flags    := -f -9

ifdef COMSPEC
PY := py.exe -3 
lz4_compress := tools/lz4
else
PY := python3
lz4_compress := lz4
endif

# Calculate the current directory as Wine applications would see it.
# yep, that's 8 backslashes.  Apparently, there are 3 layers of escaping:
# one for the shell that executes sed, one for sed, and one for the shell
# that executes wine
# TODO: convert to use winepath -w
#wincwd := $(shell pwd | sed -e "s'/'\\\\\\\\'g")

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
	-rm $(objdir)/*.o $(objdir)/mode7/*.o $(objdir)/*.chr $(objdir)/*.ov53 $(objdir)/*.sav $(objdir)/*.s

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
chrXall := $(patsubst %.png,%.chr,$(wildcard tilesetsX/*.png))
chr4all := $(patsubst %.png,%.chrsfc,$(wildcard tilesets4/*.png))
chr2all := $(patsubst %.png,%.chrgb,$(wildcard tilesets2/*.png))
chr4_lz4          := $(patsubst %.png,%.chrsfc.lz4,$(wildcard tilesets4/lz4/*.png))
chr2_lz4          := $(patsubst %.png,%.chrgb.lz4,$(wildcard tilesets2/lz4/*.png))
palettes := $(wildcard palettes/*.png)
variable_palettes := $(wildcard palettes/variable/*.png)
portraits := $(wildcard portraits/*.png)
levels := $(wildcard levels/*.json)
overworlds := $(wildcard overworlds/*.tmx)
m7levels_lz4 := $(patsubst %.tmx,%.lz4,$(wildcard m7levels/*.tmx))
m7levels_bin := $(patsubst %.tmx,%.bin,$(wildcard m7levels/*.tmx))
all_npc_gfx := $(wildcard npc/*.png)

# Background conversion
# (nametable conversion is implied)
backgrounds := $(wildcard backgrounds/*.png)
chr4allbackground := $(patsubst %.png,%.chrsfc,$(wildcard backgrounds/*.png))

auto_linker.cfg: linker_template.cfg $(objlisto)
	$(PY) tools/uncle_fill.py hirom:16 auto_linker.cfg $^
map.txt $(title).sfc: auto_linker.cfg
	$(LD65) -o $(title).sfc -m map.txt --dbgfile $(title).dbg -C auto_linker.cfg $(objlisto)
	$(PY) tools/fixchecksum.py $(title).sfc

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/snes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/mktables.s: tools/mktables.py
	$< > $@

# Files that depend on enums
$(srcdir)/graphics.s: $(srcdir)/graphicsenum.s
$(srcdir)/backgrounddata.s: $(srcdir)/backgroundenum.s $(srcdir)/graphicsenum.s
$(srcdir)/portraitdata.s: $(srcdir)/portraitenum.s
$(objdir)/renderlevel.o: $(srcdir)/actorenum.s

$(objdir)/main.o: $(srcdir)/vblank.s $(srcdir)/audio_enum.inc
$(objdir)/blockdata.o: $(srcdir)/blockenum.s
$(objdir)/levelautotile.o: $(srcdir)/blockenum.s
$(objdir)/mode7/m7blockdata.o: $(srcdir)/mode7/m7blockenum.s
$(objdir)/mode7/m7actors.o: $(srcdir)/mode7/m7blockenum.s tilesetsX/M7SoftSprites.chr
$(objdir)/overworldblockdata.o: $(srcdir)/overworldblockenum.s
$(objdir)/player.o: $(srcdir)/blockenum.s $(srcdir)/actorenum.s $(srcdir)/blockenum.s $(srcdir)/audio_enum.inc
$(objdir)/actorshared.o: $(srcdir)/blockenum.s
$(objdir)/levelload.o: $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s $(srcdir)/blockenum.s
$(objdir)/leveldata.o: $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s $(srcdir)/actorenum.s $(srcdir)/blockenum.s $(srcdir)/backgroundenum.s $(srcdir)/color_math_settings_enum.s
$(objdir)/overworldcode.o: $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s $(srcdir)/pathenum.s
$(objdir)/overworlddata.o: $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s $(srcdir)/actorenum.s $(srcdir)/pathenum.s
$(objdir)/actordata.o: $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s
$(objdir)/uploadppu.o: $(palettes) $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s
$(objdir)/inventory.o: $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s $(srcdir)/vwf.inc
$(objdir)/mode7/mode7.o: $(srcdir)/paletteenum.s $(srcdir)/mode7/m7palettedata.s $(srcdir)/graphicsenum.s $(srcdir)/portraitenum.s $(srcdir)/mode7/m7blockenum.s tilesetsX/M7Tileset.chr $(m7levels_lz4)
$(objdir)/blockinteraction.o: $(srcdir)/actorenum.s $(srcdir)/blockenum.s $(srcdir)/itemenum.s $(srcdir)/audio_enum.inc
$(srcdir)/actordata.s: $(srcdir)/actorenum.s
$(objdir)/actorcode.o: $(srcdir)/actorenum.s $(srcdir)/blockenum.s
$(objdir)/playerprojectile.o: $(srcdir)/actorenum.s $(srcdir)/blockenum.s $(srcdir)/audio_enum.inc
$(objdir)/playerability.o: $(srcdir)/actorenum.s
$(srcdir)/itemdata.s: $(srcdir)/itemenum.s $(srcdir)/vwf.inc
$(objdir)/itemcode.o: $(srcdir)/itemenum.s
$(objdir)/dialog.o: $(srcdir)/vwf.inc $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s
$(objdir)/vwf.o: $(srcdir)/vwf.inc
$(objdir)/namefont.o: tilesets2/DialogNameFont.chrgb $(srcdir)/namefontwidth.s
$(objdir)/dialog_text_data.o: $(srcdir)/paletteenum.s $(srcdir)/graphicsenum.s $(srcdir)/dialog_npc_enum.s $(srcdir)/vwf.inc $(srcdir)/blockenum.s $(srcdir)/portraitenum.s
$(srcdir)/namefontwidth.s: tilesets2/DialogNameFont.chrgb
	$(PY) tools/namefontwidthtable.py
$(srcdir)/vwf_fontdata.s: tools/fonts/BaseSeven.png tools/makefontvwf.py
	$(PY) tools/makefontvwf.py

# Automatically insert graphics into the ROM
$(srcdir)/graphicsenum.s: $(chr2all) $(chr4all) $(chrXall) $(chr4allbackground) $(chr4_lz4) $(chr2_lz4) tools/gfxlist.txt tools/insertthegfx.py
	$(PY) tools/insertthegfx.py

# Automatically create the list of blocks from a description
$(srcdir)/blockdata.s: tools/blocks.txt tools/makeblocks.py
$(srcdir)/blockenum.s: tools/blocks.txt tools/makeblocks.py
	$(PY) tools/makeblocks.py

# For Mode 7 levels too
$(srcdir)/mode7/m7blockdata.s: tools/m7blocks.txt tools/m7makeblocks.py
	$(PY) tools/m7makeblocks.py
$(srcdir)/mode7/m7blockenum.s: tools/m7blocks.txt tools/m7makeblocks.py
	$(PY) tools/m7makeblocks.py

# Automatically create the list of overworld blocks from a description
$(srcdir)/overworldblockdata.s: tools/overworldblocks.txt
$(srcdir)/overworldblockenum.s: tools/overworldblocks.txt
	$(PY) tools/makeoverworldblocks.py



$(objdir)/portraitdata.o: $(portraits) $(srcdir)/portraitenum.s
$(srcdir)/portraitenum.s: $(portraits) tools/encodeportraits.py
	$(PY) tools/encodeportraits.py
$(objdir)/dialog.o: $(srcdir)/dialog_npc_enum.s
$(srcdir)/dialog_npc_data.s: $(srcdir)/dialog_npc_enum.s
$(srcdir)/dialog_npc_enum.s: $(portraits) $(all_npc_gfx) tools/makenpc.py
	$(PY) tools/makenpc.py
$(srcdir)/palettedata.s: $(palettes) $(variable_palettes)
$(srcdir)/paletteenum.s: $(palettes) $(variable_palettes) tools/encodepalettes.py
	$(PY) tools/encodepalettes.py

$(srcdir)/actorenum.s: tools/actors.txt tools/makeactor.py
	$(PY) tools/makeactor.py
$(srcdir)/itemenum.s: tools/items.txt tools/makeitems.py
	$(PY) tools/makeitems.py
$(srcdir)/backgroundenum.s: tools/backgrounds.txt tools/makebackgrounds.py
	$(PY) tools/makebackgrounds.py
$(srcdir)/color_math_settings_enum.s: tools/color_math_settings.txt tools/makecolormathsettings.py
	$(PY) tools/makecolormathsettings.py

$(srcdir)/leveldata.s: $(levels) tools/levelconvert.py
	$(PY) tools/levelconvert.py
$(srcdir)/overworlddata.s: $(overworlds) tools/overworld.py
	$(PY) tools/overworld.py
$(srcdir)/mode7/perspective_data.s: tools/perspective.py
	$(PY) tools/perspective.py
$(srcdir)/sincos_data.s: tools/makesincos.py
	$(PY) tools/makesincos.py
$(srcdir)/dialog_text_data.s: tools/makedialog.py story/dialog.txt
	$(PY) tools/makedialog.py
m7levels/%.lz4: m7levels/%.bin
	$(lz4_compress) $(lz4_flags) $< $@
	@touch $@
m7levels/%.bin: m7levels/%.tmx tools/m7levelconvert.py $(srcdir)/mode7/m7blockenum.s
	$(PY) tools/m7levelconvert.py $< $@
$(srcdir)/mode7/m7leveldata.s: $(m7levels_lz4) $(m7levels_bin) tools/m7levelinsert.py
	$(PY) tools/m7levelinsert.py
$(objdir)/mode7/m7leveldata.o: $(m7levels_lz4) $(m7levels_bin) $(srcdir)/mode7/m7leveldata.s
$(objdir)/backgrounddata.o: $(srcdir)/backgroundenum.s
$(objdir)/hubworld.o: hubworld/fg.bin hubworld/bg.bin hubworld/metatiles.bin hubworld/palettes.bin hubworld/hubworld.chrsfc hubworld/solidmap.bin $(srcdir)/paletteenum.s
hubworld/fg.bin hubworld/bg.bin hubworld/metatiles.bin hubworld/solidmap.bin hubworld/palettes.bin hubworld/hubworld.chrsfc: hubworld/fg.png hubworld/bg.png hubworld/palettes.png hubworld/attribute.png tools/hubworld.py
	$(PY) tools/hubworld.py

$(objdir)/musicseq.o $(objdir)/spcimage.o: src/pentlyseq.inc


# Rules for CHR data

# .chrgb (CHR data for Game Boy) denotes the 2-bit tile format
# used by Game Boy and Game Boy Color, as well as Super NES
# mode 0 (all planes), mode 1 (third plane), and modes 4 and 5
# (second plane).
# Try generating it in the folder it's for
$(imgdir2)/%.chrgb: $(imgdir2)/%.png
	$(PY) tools/pilbmp2nes.py --planes=0,1 $< $@
$(imgdir2)/lz4/%.chrgb: $(imgdir2)/lz4/%.png
	$(PY) tools/pilbmp2nes.py --planes=0,1 $< $@
$(imgdir4)/%.chrsfc: $(imgdir4)/%.png
	$(PY) tools/pilbmp2nes.py "--planes=0,1;2,3" $< $@

$(imgdirX)/%.chr: $(imgdirX)/%.txt $(imgdirX)/%.png
	$(PY) tools/pilbmp2nes.py "--flag-file" $^ $@

$(imgdir4)/lz4/%.chrsfc: $(imgdir4)/lz4/%.png
	$(PY) tools/pilbmp2nes.py "--planes=0,1;2,3" $< $@


$(bgdir)/%.chrsfc: $(bgdir)/%.png tools/makebackgroundmap.py
	$(PY) tools/makebackgroundmap.py $<
$(srcdir)/mode7/m7palettedata.s: tilesetsX/M7Tileset.png tools/mode7palette.py
	$(PY) tools/mode7palette.py

tilesets4/lz4/%.chrsfc.lz4: tilesets4/lz4/%.chrsfc
	$(lz4_compress) $(lz4_flags) $< $@
	@touch $@
tilesets2/lz4/%.chrgb.lz4: tilesets2/lz4/%.chrgb
	$(lz4_compress) $(lz4_flags) $< $@
	@touch $@

# ----------------
# Rules for audio
$(srcdir)/audio_enum.inc: $(audiodir)/example-project.terrificaudio
	$(TAD_COMPILER) ca65-enums --output $@ $(audiodir)/example-project.terrificaudio
$(audiodir)/audio_common.bin: $(audiodir)/example-project.terrificaudio $(audiodir)/sound-effects.txt $(wildcard $(audiodir)/songs/*.mml)
	$(TAD_COMPILER) common --output $@ $(audiodir)/example-project.terrificaudio
$(patsubst %.mml,%.bin,$(wildcard $(audiodir)/songs/*.mml)): $(audiodir)/songs/*.mml
	$(TAD_COMPILER) song --output $@ $(audiodir)/example-project.terrificaudio $(patsubst %.bin,%.mml, $@)

$(objdir)/audio_incbins.o: $(audiodir)/audio_common.bin $(patsubst %.mml,%.bin,$(wildcard $(audiodir)/songs/*.mml))
$(srcdir)/audio_incbins.s: $(audiodir)/example-project.terrificaudio $(patsubst %.mml,%.bin,$(wildcard $(audiodir)/songs/*.mml))
	$(PY) tools/create_tad_incbins.py $< $@

$(objdir)/audio_misc.o: $(audiodir)/audio_common.bin
