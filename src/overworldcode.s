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
.smart

.import Overworld_Pointers
.import OWBlockTopLeft, OWBlockTopRight, OWBlockBottomLeft, OWBlockBottomRight
.export OpenOverworld

.segment "Overworld"

; Input: A = overworld number
.a16
.i16
.proc OpenOverworld
  phk
  plb

  setaxy16
  and #255
  asl
  tax
  lda Overworld_Pointers,x
  ; Can actually treat it as a 16-bit pointer, overworld data is limited to this bank
  sta DecodePointer

  ; Start reading the overworld
  ldy #0
  seta8


  ; ---------------

  ldx #0
UploadGraphicLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitGraphicLoop
  jsl DoGraphicUpload
  bra UploadGraphicLoop
ExitGraphicLoop:

  ; ---------------

  ldx #0
UploadPaletteLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitPaletteLoop
  phy
  txy
  jsl DoPaletteUpload
  ply
  bra UploadPaletteLoop
ExitPaletteLoop:

  ; ---------------

  ldx #0
  stz 0 ; Initialize the repeat counter
DecompressMapLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitMapLoop

  ; If the high bit is set then set the repeat counter
  cmp #128
  bcc :+
    and #127
    inc a
    sta 0
    bra DecompressMapLoop
  :

  ; Repeat for counter + 1 times
  inc 0
: sta f:Scratchpad,x
  inx
  dec 0
  bne :-

  bra DecompressMapLoop

ExitMapLoop:

  ; ---------------

  lda #INC_DATAHI
  sta PPUCTRL

  ; Render the overworld
  seta16
  ldx #0
  lda #$c000>>1
  sta PPUADDR
RenderLoop:
  ; Top
  lda #16
  sta 0
: lda f:Scratchpad,x
  and #255
  asl
  tay
  lda OWBlockTopLeft,y
  sta PPUDATA
  lda OWBlockTopRight,y
  sta PPUDATA

  inx
  dec 0
  bne :-

  txa
  sub #16
  tax

  ; Bottom
  lda #16
  sta 0
: lda f:Scratchpad,x
  and #255
  asl
  tay
  lda OWBlockBottomLeft,y
  sta PPUDATA
  lda OWBlockBottomRight,y
  sta PPUDATA

  inx
  dec 0
  bne :-

  cpx #224
  bne RenderLoop








  ; -----------------------------------
  ; Set up PPU registers
  ; (Is this the appropriate place for this?)
  seta8
  lda #1
  sta BGMODE       ; mode 1

  stz BGCHRADDR+0  ; bg planes 0-1 CHR at $0000
  lda #$e>>1
  sta BGCHRADDR+1  ; bg plane 2 CHR at $e000

  lda #$8000 >> 14
  sta OBSEL      ; sprite CHR at $8000, sprites are 8x8 and 16x16

  lda #1 | ($c000 >> 9)
  sta NTADDR+0   ; plane 0 nametable at $c000, 2 screens wide
  lda #2 | ($d000 >> 9)
  sta NTADDR+1   ; plane 1 nametable also at $d000, 2 screens tall
  lda #0 | ($e000 >> 9)
  sta NTADDR+2   ; plane 2 nametable at $e000, 1 screen

  ; set up plane 0's scroll
  stz BGSCROLLX+0
  stz BGSCROLLX+0
  lda #$FF
  sta BGSCROLLY+0  ; The PPU displays lines 1-224, so set scroll to
  sta BGSCROLLY+0  ; $FF so that the first displayed line is line 0

  stz PPURES
  lda #%00010011  ; enable sprites, plane 0 and 1
  sta BLENDMAIN
  lda #VBLANK_NMI|AUTOREAD  ; but disable htime/vtime IRQ
  sta PPUNMI

  ; -----------------------------------
OverworldLoop:
  setaxy16
  jsl WaitKeysReady



  jsl WaitVblank
  seta8
  lda #15
  sta PPUBRIGHT
  jmp OverworldLoop

  rtl
.endproc


