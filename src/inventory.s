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
.include "graphicsenum.s"
.include "paletteenum.s"
.smart

.segment "Inventory"

.i16
.a16
.export OpenInventory
.proc OpenInventory
  phk
  plb
  jsl WaitVblank

  seta8
  lda #FORCEBLANK
  sta PPUBRIGHT

  ; Reset all scrolling
  ldx #2*3-1
: stz BGSCROLLX,x
  stz BGSCROLLX,x
  dex
  bpl :-

  lda #<(-4)
  sta BGSCROLLY
  lda #>(-4)
  sta BGSCROLLY

  seta16
  ; Write graphics
  lda #GraphicsUpload::InventoryBG
  jsl DoGraphicUpload
  lda #GraphicsUpload::InventorySprite
  jsl DoGraphicUpload

  ; Clear the screens
  ldx #$c000 >> 1
  ldy #0
  jsl ppu_clear_nt
  ldx #$d000 >> 1
  ldy #0
  jsl ppu_clear_nt
  ldx #$e000 >> 1
  ldy #0
  jsl ppu_clear_nt

  seta16
  ; Write palettes
  lda #Palette::InventoryBG
  ldy #0
  jsl DoPaletteUpload
  lda #Palette::InventorySprite
  ldy #8
  jsl DoPaletteUpload



  lda #$0a0c
  sta 0
  lda #(ForegroundBG + (5*64 + 3*2))>>1
  jsr MakeWindow

  lda #$0a0c
  sta 0
  lda #(ForegroundBG + (5*64 + 17*2))>>1
  jsr MakeWindow

  lda #$0702
  sta 0
  lda #(ForegroundBG + (0*64 + 3*2))>>1
  jsr MakeWindow

  lda #$0e02
  sta 0
  lda #(ForegroundBG + (0*64 + 13*2))>>1
  jsr MakeWindow

  lda #$1005
  sta 0
  lda #(ForegroundBG + (20*64 + 7*2))>>1
  jsr MakeWindow

  ; Money (Top row)
  lda #(ForegroundBG + (1*64 + 4*2))>>1
  sta PPUADDR
  lda #$5a
  sta PPUDATA
  ina
  sta PPUDATA
  lda MoneyAmount+2
  and #255
  ora #$50
  sta PPUDATA
  lda MoneyAmount+1
  jsr MoneyTop
  lda MoneyAmount+0
  jsr MoneyTop

  ; Money (Bottom row)
  lda #(ForegroundBG + (2*64 + 4*2))>>1
  sta PPUADDR
  lda #$6a
  sta PPUDATA
  ina
  sta PPUDATA
  lda MoneyAmount+2
  and #255
  ora #$60
  sta PPUDATA
  lda MoneyAmount+1
  jsr MoneyBottom
  lda MoneyAmount+0
  jsr MoneyBottom

  ; Action icons
  lda #(ForegroundBG + (1*64 + 14*2))>>1
  sta PPUADDR
  ldx #.loword(IconStringTop)
  jsr PutStringX

  lda #(ForegroundBG + (2*64 + 14*2))>>1
  sta PPUADDR
  ldx #.loword(IconStringBottom)
  jsr PutStringX
  
  ; Inventory titles
  lda #(ForegroundBG + (6*64 + 4*2))>>1
  sta PPUADDR
  lda #$3e
  sta PPUDATA
  lda #$30
  ldx #8
  jsr WritePPUIncreasing
  lda #$3e
  sta PPUDATA

  lda #(ForegroundBG + (7*64 + 4*2))>>1
  sta PPUADDR
  lda #$4e
  sta PPUDATA
  lda #$40
  ldx #8
  jsr WritePPUIncreasing
  lda #$4e
  sta PPUDATA


  lda #(ForegroundBG + (6*64 + 18*2))>>1
  sta PPUADDR
  lda #$3e
  sta PPUDATA
  sta PPUDATA
  lda #$38
  ldx #6
  jsr WritePPUIncreasing
  lda #$3e
  sta PPUDATA
  sta PPUDATA

  lda #(ForegroundBG + (7*64 + 18*2))>>1
  sta PPUADDR
  lda #$4e
  sta PPUDATA
  sta PPUDATA
  lda #$48
  ldx #6
  jsr WritePPUIncreasing
  lda #$4e
  sta PPUDATA
  sta PPUDATA

  ; Circles!
  lda #(ForegroundBG + (8*64 + 4*2))>>1
  sta PPUADDR

  ldy #5
: jsr CircleTop
  ldx #4
  jsr SkipXWords
  jsr CircleTop
  ldx #8
  jsr SkipXWords
 
  jsr CircleBottom
  ldx #4
  jsr SkipXWords
  jsr CircleBottom
  ldx #8
  jsr SkipXWords
  dey
  bne :-

  ; Maffi platform
  lda #(ForegroundBG + (22*64 + 26*2))>>1
  sta PPUADDR
  lda #$1f
  sta PPUDATA
  dea
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  lda #$2f
  sta PPUDATA


  ; -----------------------------------
  ; Main inventory loop
Loop:
  setaxy16
  jsl WaitKeysReady

  lda keynew
  and #KEY_START
  jne Exit


  seta8
  ; Draw Maffi
  lda #208
  sta 0
  lda #179
  sta 1
  lda #$1b
  sta 2
  lda #5
  jsr HorizontalSpriteStrip

  lda #208
  sta 0
  lda #179-8
  sta 1
  lda #$0b
  sta 2
  lda #5
  jsr HorizontalSpriteStrip

  lda retraces
  and #64
  beq ZZZAlternate

  lda #208+8
  sta 0
  lda #179-16
  sta 1
  lda #$17
  sta 2
  lda #4
  jsr HorizontalSpriteStrip

  lda #208+8
  sta 0
  lda #179-24
  sta 1
  lda #$07
  sta 2
  lda #3
  jsr HorizontalSpriteStrip

  bra NotZZZAlternate
ZZZAlternate:

  lda #208+8
  sta 0
  lda #179-16
  sta 1
  lda #$14
  sta 2
  lda #3
  jsr HorizontalSpriteStrip

  lda #240
  sta 0
  lda #$1a
  sta 2
  lda #1
  jsr HorizontalSpriteStrip

  lda #208+8
  sta 0
  lda #179-24
  sta 1
  lda #$04
  sta 2
  lda #3
  jsr HorizontalSpriteStrip

NotZZZAlternate:
  seta16



  ldx OamPtr
  jsl ppu_clear_oam
  jsl ppu_pack_oamhi

  setaxy16
  jsl WaitVblank
  jsl ppu_copy_oam

  ; Turn rendering on
  seta8
  lda #15
  sta PPUBRIGHT
  jmp Loop

Exit:
  jsl WaitVblank
  seta8
  lda #FORCEBLANK
  sta PPUBRIGHT
  .import UploadLevelGraphics
  jml UploadLevelGraphics
.endproc


.a16
.proc MoneyTop
  and #255
  pha
  lsr
  lsr
  lsr
  lsr
  ora #$50
  sta PPUDATA
  pla
  and #$0f
  ora #$50
  sta PPUDATA
  rts
.endproc

.a16
.proc MoneyBottom
  and #255
  pha
  lsr
  lsr
  lsr
  lsr
  ora #$60
  sta PPUDATA
  pla
  and #$0f
  ora #$60
  sta PPUDATA
  rts
.endproc

.a16
.proc MakeWindow
  Address = 2
  Height  = 0
  Width   = 1
  setxy8
  sta Address

  ; Top row
  sta PPUADDR
  lda #$1c
  sta PPUDATA
  jsr Horizontal
  lda #$1d
  sta PPUDATA
  
  ; Bottom row
  lda Height
  and #255
  xba
  lsr
  lsr
  lsr
  add #32
  add Address
  sta PPUADDR
  lda #$2c
  sta PPUDATA
  jsr Horizontal
  lda #$2d
  sta PPUDATA

  ; Vertical writes
  ldx #INC_DATAHI|VRAM_DOWN
  stx PPUCTRL

  lda Address
  add #32
  sta PPUADDR
  jsr Vertical

  lda Width
  and #255
  add Address
  add #32+1
  sta PPUADDR
  jsr Vertical

  ; Horizontal writes again
  ldx #INC_DATAHI
  stx PPUCTRL
  setxy16
  rts

Horizontal:
  ldx Width
  lda #$1e
: sta PPUDATA
  dex
  bne :-
  rts
Vertical:
  ldx Height
  lda #$2e
: sta PPUDATA
  dex
  bne :-
  rts
.endproc

IconStringTop:    .byt $10, $11, $3e, $12, $13, $3e, $14, $15, $3e, $16, $17, $3e, $18, $19, 0
IconStringBottom: .byt $20, $21, $3e, $22, $23, $3e, $24, $25, $3e, $26, $27, $3e, $28, $29, 0

.a16
.proc PutStringX
  lda a:0,x
  and #255
  beq Exit
  sta PPUDATA
  inx
  bra PutStringX
Exit:
  rts
.endproc

.proc WritePPUIncreasing
: sta PPUDATA
  ina
  dex
  bne :-
  rts
.endproc

.proc CircleTop
  ldx #5
: lda #$1a
  sta PPUDATA
  ina
  sta PPUDATA
  dex
  bne :-
  rts
.endproc

.proc CircleBottom
  ldx #5
: lda #$2a
  sta PPUDATA
  ina
  sta PPUDATA
  dex
  bne :-
  rts
.endproc

.proc SkipXWords
: bit PPUDATARD
  dex
  bne :-
  rts
.endproc

; 0 X position
; 1 Y position
; 2 Tile
; A = width
.a8
.proc HorizontalSpriteStrip
XPos  = 0
YPos  = 1
Tile  = 2
Width = 3
  ldx OamPtr

  sta Width
Loop:
  lda XPos
  sta OAM_XPOS,x
  add #8
  sta XPos

  lda YPos
  sta OAM_YPOS,x
  lda Tile
  inc Tile
  sta OAM_TILE,x
  lda #>OAM_PRIORITY_2
  sta OAM_ATTR,x
  stz OAMHI+0,x
  stz OAMHI+1,x

  inx
  inx
  inx
  inx
  dec Width
  bne Loop

  stx OamPtr
  rts
.endproc

