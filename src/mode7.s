; Super Princess Engine
; Copyright (C) 2019 NovaSquirrel
;
; This program is free software: you can redistribute it and/or
; modify it under the terms of the GNU General Public License as
; published by the Free Software Foundation; either version 3 of the
; License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
.include "snes.inc"
.include "global.inc"
.include "blockenum.s"
.include "graphicsenum.s"
.include "paletteenum.s"
.smart

.import m7a_m7b_0
.import m7c_m7d_0
.import m7a_m7b_list
.import m7c_m7d_list

.segment "ZEROPAGE"
Mode7ScrollX: .res 2
Mode7ScrollY: .res 2
Mode7Angle:   .res 2

.segment "Mode7Game"

.export Mode7Test
.proc Mode7Test
  phk
  plb

  setaxy16
  stz Mode7ScrollX
  stz Mode7ScrollY
  stz Mode7Angle

  stz CGADDR
  lda #RGB(15,23,31)
  sta CGDATA
  ; ---
  lda #Palette::FGCommon
  ldy #0
  jsl DoPaletteUpload
  lda #Palette::FGGrassy
  ldy #1
  jsl DoPaletteUpload

  ; Copy in the tiles
  stz PPUADDR
  lda #DMAMODE_PPUHIDATA
  ldx #$ffff & Mode7Tiles
  ldy #Mode7TilesEnd-Mode7Tiles
  jsl ppu_copy


  ; Make a tilemap I guess
  stz PPUADDR
  seta8
  stz PPUCTRL

  ldx #128*128
: jsl RandomByte
  and #3
  sta PPUDATA
  dex
  bne :-
  ; Restore it to incrementing address on high writes
  lda #INC_DATAHI
  sta PPUCTRL



  seta8
  lda #7
  sta BGMODE       ; mode 7

  ; -----------------------

  ; Identity matrix:
  ; $0100 $0000
  ; $0000 $0100
  lda #$01
  stz M7A
  sta M7A
  stz M7B
  stz M7B
  stz M7C
  stz M7C
  stz M7D
  sta M7D

  ; Rotation center
  lda #$80
  sta M7X
  stz M7X

  lda #$40
  sta M7Y
  lda #$01
  sta M7Y

  stz BGSCROLLX
  stz BGSCROLLX
  stz BGSCROLLY
  stz BGSCROLLY

  lda #$8000 >> 14
  sta OBSEL       ; sprite CHR at $8000, sprites are 8x8 and 16x16

  lda #%00010001  ; enable sprites, plane 0
  sta BLENDMAIN
  lda #VBLANK_NMI|AUTOREAD  ; but disable htime/vtime IRQ
  sta PPUNMI

  setaxy16


  jsl WaitVblank
  seta8
  lda #$0F
  sta PPUBRIGHT  ; turn on rendering
  seta16

Loop:
  setaxy16
  jsl WaitVblank

  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait

  lda keydown
  sta keylast
  lda JOY1CUR
  sta keydown
  lda keylast
  eor #$ffff
  and keydown
  sta keynew

  lda keydown
  and #KEY_UP
  beq :+
    dec Mode7ScrollY
  :

  lda keydown
  and #KEY_DOWN
  beq :+
    inc Mode7ScrollY
  :

  lda keydown
  and #KEY_LEFT
  beq :+
    dec Mode7ScrollX
  :

  lda keydown
  and #KEY_RIGHT
  beq :+
    inc Mode7ScrollX
  :


  lda retraces
  and #3
  bne NoRotation
  lda keydown
  and #KEY_L
  beq :+
    dec Mode7Angle
    lda Mode7Angle
    and #31
    sta Mode7Angle
  :

  lda keydown
  and #KEY_R
  beq :+
    inc Mode7Angle
    lda Mode7Angle
    and #31
    sta Mode7Angle
  :
NoRotation:


.if 0
  lda retraces
  and #3
  bne :+
    dec Mode7ScrollY
  :
.endif


  seta16
  lda Mode7ScrollX
  seta8
  sta BGSCROLLX
  xba
  sta BGSCROLLX
  seta16
  lda Mode7ScrollX
  add #128
  seta8
  sta M7X
  xba
  sta M7X


  seta16
  lda Mode7ScrollY
  seta8
  sta BGSCROLLY
  xba
  sta BGSCROLLY
  seta16
  lda Mode7ScrollY
  add #256
  seta8
  sta M7Y
  xba
  sta M7Y


  seta16
  lda #$1b03 ; m7a and m7b
  sta DMAMODE+$20
  lda #$1d03 ; m7c and m7d
  sta DMAMODE+$30

  lda Mode7Angle
  asl
  tax
  lda m7a_m7b_list,x
  sta DMAADDR+$20
  lda m7c_m7d_list,x
  sta DMAADDR+$30
  seta8
  lda #^m7a_m7b_0
  sta DMAADDRBANK+$20
  lda #^m7c_m7d_0
  sta DMAADDRBANK+$30
  lda #4|8
  sta HDMASTART


  jmp Loop


  rtl
.endproc

Mode7Tiles:
.repeat 64
  .byt 1
.endrep

.repeat 64
  .byt 11
.endrep

.repeat 64
  .byt 12
.endrep

  .byt 0,   0, 11, 11, 11, 11,  0,  0
  .byt 0,  11, 12, 12, 12, 12, 11,  0
  .byt 11, 12,  1, 12, 12,  1, 12, 11
  .byt 11, 12, 12, 12, 12, 12, 12, 11
  .byt 11, 12,  1, 12, 12,  1, 12, 11
  .byt 11, 12, 12,  1,  1, 12, 12, 11
  .byt 0,  11, 12, 12, 12, 12, 11,  0
  .byt 0,   0, 11, 11, 11, 11,  0,  0
Mode7TilesEnd:
