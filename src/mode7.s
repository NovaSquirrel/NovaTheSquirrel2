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

Mode7LevelMap = LevelBuf
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
  stz Mode7RealAngle
  stz Mode7Direction
  stz Mode7Turning
  stz Mode7TurnWanted

  lda #10*16
  sta Mode7PlayerX
  sta Mode7PlayerY

  ; Upload palettes
  seta8
  ; Try just transparency outside the map for now  
  lda #M7_NOWRAP
  sta M7SEL
  lda #^Mode7LevelMap
  sta LevelBlockPtr+2


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

  ; Common sprites
  lda #Palette::FGCommon
  ldy #8
  jsl DoPaletteUpload
  lda #GraphicsUpload::SPCommon
  jsl DoGraphicUpload

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
  ; Top row
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

  ; Bottom row
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
  lda #^Mode7IRQ
  sta IRQHandler+2
  ; -----------------------

  lda #$8000 >> 14
  sta OBSEL       ; sprite CHR at $8000, sprites are 8x8 and 16x16

  lda #VBLANK_NMI|AUTOREAD
  sta PPUNMI

  setaxy16
  lda #.loword(Mode7IRQ)
  sta IRQHandler+0

Loop:
  setaxy16
  jsl WaitVblank
  jsl ppu_copy_oam


  ; -----------------------------------
  seta8
  stz PPUCTRL
  seta16
  ; Do block updates
  ldx #(BLOCK_UPDATE_COUNT-1)*2
BlockUpdateLoop:
  lda BlockUpdateAddress,x
  beq SkipBlock
  sta PPUADDR
  seta8
  lda BlockUpdateDataTL,x
  sta PPUDATA
  ina
  sta PPUDATA

  seta16
  lda BlockUpdateAddress,x ; Move down a row
  add #128
  sta PPUADDR
  seta8
  lda BlockUpdateDataTL,x
  add #2
  sta PPUDATA
  ina
  sta PPUDATA
  seta16

  stz BlockUpdateAddress,x ; Cancel out the block now that it's been written
SkipBlock:
  dex
  dex
  bpl BlockUpdateLoop
  seta8
  lda #INC_DATAHI
  sta PPUCTRL

  seta16
  ; -----------------------------------
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

  lda #220
  sta HTIME
  lda #48
  sta VTIME
  seta8
  lda #^m7a_m7b_0
  sta DMAADDRBANK+$20
  lda #^m7c_m7d_0
  sta DMAADDRBANK+$30
  lda #4|8
  sta HDMASTART

  lda #$0F
  sta PPUBRIGHT ; Turn on rendering
  lda #1
  sta BGMODE

  lda #VBLANK_NMI|AUTOREAD|HVTIME_IRQ ; enable HV IRQ
  sta PPUNMI
  cli

  ; Initialize the scroll registers
  seta8
  lda Mode7ScrollX+0
  sta BGSCROLLX
  lda Mode7ScrollX+1
  sta BGSCROLLX
  lda Mode7ScrollY+0
  sta BGSCROLLY
  lda Mode7ScrollY+1
  sta BGSCROLLY

  lda #%00010000  ; enable sprites, plane 1
  sta BLENDMAIN

  ; Calculate the centers
  seta16
  lda Mode7ScrollX
  add #128
  seta8
  sta M7X
  xba
  sta M7X
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
  stz OamPtr

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
  beq NoRotation
    lda Mode7RealAngle
    add Mode7Turning
    and #31
    sta Mode7RealAngle
    and #7
    bne NoRotation
      stz Mode7Turning
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

  ; Make it so that 0,0 places the player on the top left corner of the map
  lda Mode7PlayerX
  sub #7*16+8
  sta Mode7ScrollX
  lda Mode7PlayerY
  sub #11*16+8
  sta Mode7ScrollY

  ldy OamPtr
  lda #$68|OAM_PRIORITY_2
  sta OAM_TILE,y
  seta8
  lda #128-4
  sta OAM_XPOS,y
  lda #192-4
  sta OAM_YPOS,y
  lda #0
  sta OAMHI+1,y
  seta16
  tya
  add #4
  sta OamPtr


  ; Change green to red
  lda Mode7PlayerX
  ora Mode7PlayerY
  and #15
  bne :+
  lda Mode7PlayerX
  ldy Mode7PlayerY
  jsr Mode7BlockAddress
  cmp #5
  bne :+
    lda #6
    jsr Mode7ChangeBlock
  :



  setaxy16
  ldx OamPtr
  jsl ppu_clear_oam
  jsl ppu_pack_oamhi

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


.proc Mode7IRQ
  pha
  php
  seta8
  bit TIMESTATUS ; Acknowledge interrupt
  lda #7
  sta BGMODE
  lda #%00010001  ; enable sprites, plane 0
  sta BLENDMAIN
  plp
  pla
  rti
.endproc

; A = block to set
; X = block address
.a16
.i16
.proc Mode7ChangeBlock
Temp = BlockTemp
  phx
  phy
  php
  seta8
  sta [LevelBlockPtr] ; Make the change in the level buffer itself
  setaxy16
  ; Find a free index in the block update queue
  ldy #(BLOCK_UPDATE_COUNT-1)*2
FindIndex:
  ldx BlockUpdateAddress,y ; Test for zero (exact value not used)
  beq Found
  dey                      ; Next index
  dey
  bpl FindIndex            ; Give up if all slots full
  jmp Exit
Found:
  ; From this point on in the routine, Y = free update queue index

  ; Store the tile number
  asl
  asl
  sta BlockUpdateDataTL,y

  ; Now calculate the PPU address
  ; LevelBlockPtr is 0000yyyyyyxxxxxx
  ; Needs to become  00yyyyyy0xxxxxx0
  lda LevelBlockPtr
  and #%111111000000 ; Get Y
  asl
  asl
  sta BlockUpdateAddress,y

  ; Add in X
  lda LevelBlockPtr
  and #%111111
  asl
  ora BlockUpdateAddress,y
  wdm 0
  sta BlockUpdateAddress,y

  ; Restore registers
Exit:

  plp
  ply
  plx
  rts
.endproc


; A = X coordinate
; Y = Y coordinate
; Output: LevelBlockPtr
.a16
.i16
.proc Mode7BlockAddress
  and #%1111110000
      ; ......xx xxxx....
  lsr ; .......x xxxxx...
  lsr ; ........ xxxxxx..
  lsr ; ........ .xxxxxx.
  lsr ; ........ ..xxxxxx
  sta LevelBlockPtr
  tya ; ......yy yyyy....
  and #%1111110000
  asl ; .....yyy yyy.....
  asl ; ....yyyy yy......
  tsb LevelBlockPtr
      ; ....yyyy yyxxxxxx
  lda [LevelBlockPtr]
  and #255
  rts
.endproc

