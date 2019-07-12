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

Mode7LevelMap = LevelBufAlt
.import m7a_m7b_0
.import m7c_m7d_0
.import m7a_m7b_list
.import m7c_m7d_list

.segment "BSS"
Mode7ScrollX:    .res 2
Mode7ScrollY:    .res 2
Mode7PlayerX:    .res 2
Mode7PlayerY:    .res 2
Mode7RealAngle:  .res 2 ; 0-31
Mode7Direction:  .res 2 ; 0-3
Mode7Turning:    .res 2
Mode7TurnWanted: .res 2

.segment "Mode7Game"

.export Mode7Test
.proc Mode7Test
  phk
  plb

  setaxy16
  ; Clear variables
  stz Mode7ScrollX
  stz Mode7ScrollY
  stz Mode7PlayerX
  stz Mode7PlayerY
  stz Mode7RealAngle
  stz Mode7Direction
  stz Mode7Turning
  stz Mode7TurnWanted

  ; Upload palettes
  seta8
  stz CGADDR
  lda #<RGB(15,23,31)
  sta CGDATA
  lda #>RGB(15,23,31)
  sta CGDATA
  seta16
  ; ---
  lda #DMAMODE_CGDATA
  ldx #$ffff & Mode7Palette
  ldy #64*2
  jsl ppu_copy

  ; Upload graphics
  stz PPUADDR
  lda #DMAMODE_PPUHIDATA
  ldx #$ffff & Mode7Tiles
  ldy #Mode7TilesEnd-Mode7Tiles
  jsl ppu_copy

  ; -----------------------------------

  ; Clear level map with a checkerboard pattern
  ldx #0
  lda #$0102
CheckerLoop:
  ldy #32
  xba
: sta f:Mode7LevelMap,x
  inx
  inx
  dey
  bne :-
  cpx #4096
  bne CheckerLoop

  ; Write some sample blocks
  seta8
  lda #5
  sta f:Mode7LevelMap+(64*5+5)
  sta f:Mode7LevelMap+(64*5+6)
  sta f:Mode7LevelMap+(64*5+7)
  sta f:Mode7LevelMap+(64*5+8)
  sta f:Mode7LevelMap+(64*6+5)
  sta f:Mode7LevelMap+(64*7+5)
  sta f:Mode7LevelMap+(64*8+5)

  ina
  sta f:Mode7LevelMap+(64*5+15)
  sta f:Mode7LevelMap+(64*5+16)
  sta f:Mode7LevelMap+(64*5+17)
  sta f:Mode7LevelMap+(64*5+18)
  sta f:Mode7LevelMap+(64*6+15)
  sta f:Mode7LevelMap+(64*7+15)
  sta f:Mode7LevelMap+(64*8+15)

  ina
  sta f:Mode7LevelMap+(64*5+10)
  sta f:Mode7LevelMap+(64*6+10)
  sta f:Mode7LevelMap+(64*7+10)
  sta f:Mode7LevelMap+(64*8+10)

  ; .----------------------------------
  ; | Render Mode7LevelMap
  ; '----------------------------------
  seta8
  ; Increment the address on low writes, as the tilemap is in low VRAM bytes
  stz PPUADDR+0
  stz PPUADDR+1
  stz PPUCTRL

  ldx #0
  lda #64 ; Row counter
  sta 0
RenderMapLoop:
  ldy #64
: lda f:Mode7LevelMap,x
  asl
  asl
  sta PPUDATA
  ina
  sta PPUDATA
  inx
  dey
  bne :-

  seta16
  txa
  sub #64
  tax
  seta8

  ldy #64
: lda f:Mode7LevelMap,x
  asl
  asl
  ora #2
  sta PPUDATA
  ina
  sta PPUDATA
  inx
  dey
  bne :-

  dec 0
  bne RenderMapLoop

  ; Restore it to incrementing address on high writes
  lda #INC_DATAHI
  sta PPUCTRL

  ; -----------------------------------

  seta8
  lda #7
  sta BGMODE       ; mode 7

  ; -----------------------

  lda #$8000 >> 14
  sta OBSEL       ; sprite CHR at $8000, sprites are 8x8 and 16x16

  lda #%00010001  ; enable sprites, plane 0
  sta BLENDMAIN
  lda #VBLANK_NMI|AUTOREAD  ; but disable htime/vtime IRQ
  sta PPUNMI

  setaxy16

Loop:
  setaxy16
  jsl WaitVblank

  ; Start preparing the HDMA
  lda Mode7RealAngle
  asl
  tax
  lda m7a_m7b_list,x
  sta DMAADDR+$20
  lda m7c_m7d_list,x
  sta DMAADDR+$30
  lda #$1b03 ; m7a and m7b
  sta DMAMODE+$20
  lda #$1d03 ; m7c and m7d
  sta DMAMODE+$30

  seta8
  lda #^m7a_m7b_0
  sta DMAADDRBANK+$20
  lda #^m7c_m7d_0
  sta DMAADDRBANK+$30
  lda #4|8
  sta HDMASTART

  lda #$0F
  sta PPUBRIGHT  ; turn on rendering

  ; Set the scroll registers
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
  add #192
  seta8
  sta M7Y
  xba
  sta M7Y

  seta8
  ; Wait for the controller to be ready
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait
  seta16

  ; -----------------------------------

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

  lda Mode7Turning
  bne AlreadyTurning
    lda keydown
    and #KEY_LEFT|KEY_RIGHT
    tsb Mode7TurnWanted

    lda Mode7PlayerX
    ora Mode7PlayerY
    and #15
    bne AlreadyTurning

    lda Mode7TurnWanted
    and #KEY_RIGHT
    beq :+
      dec Mode7Turning
      lda Mode7Direction
      dec
      and #3
      sta Mode7Direction
      stz Mode7TurnWanted
    :

    lda Mode7TurnWanted
    and #KEY_LEFT
    beq :+
      inc Mode7Turning
      lda Mode7Direction
      inc
      and #3
      sta Mode7Direction
      stz Mode7TurnWanted
    :
  AlreadyTurning:


  lda Mode7Turning
  beq NotTurning
    lda Mode7RealAngle
    add Mode7Turning
    and #31
    sta Mode7RealAngle
    and #7
    bne NotTurning
      stz Mode7Turning
  NotTurning:



  lda retraces
  and #3
  bne NoRotation
  lda keydown
  and #KEY_L
  beq :+
    dec Mode7RealAngle
    lda Mode7RealAngle
    and #31
    sta Mode7RealAngle
  :

  lda keydown
  and #KEY_R
  beq :+
    inc Mode7RealAngle
    lda Mode7RealAngle
    and #31
    sta Mode7RealAngle
  :
  bra WasRotation

NoRotation:
  ; If not rotating, move forward
  lda Mode7Direction
  asl
  tax
  lda Mode7PlayerX
  add ForwardX,x
  sta Mode7PlayerX

  lda Mode7PlayerY
  add ForwardY,x
  sta Mode7PlayerY
WasRotation:


  lda Mode7PlayerX
  sta Mode7ScrollX
  lda Mode7PlayerY
  sta Mode7ScrollY
  jmp Loop
  rtl

ForwardX:
  .word 0, .loword(-2), 0, .loword(2)
ForwardY:
  .word .loword(-2), 0, .loword(2), 0
.endproc

Mode7Tiles:
.incbin "../tools/M7Tileset.chrm7"

; Smiley
  .byt 0,   0, 11, 11, 11, 11,  0,  0
  .byt 0,  11, 12, 12, 12, 12, 11,  0
  .byt 11, 12,  1, 12, 12,  1, 12, 11
  .byt 11, 12, 12, 12, 12, 12, 12, 11
  .byt 11, 12,  1, 12, 12,  1, 12, 11
  .byt 11, 12, 12,  1,  1, 12, 12, 11
  .byt 0,  11, 12, 12, 12, 12, 11,  0
  .byt 0,   0, 11, 11, 11, 11,  0,  0
Mode7TilesEnd:

.include "m7palettedata.s"
