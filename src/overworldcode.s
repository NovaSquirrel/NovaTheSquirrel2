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


MapMetatileBuffer    = Scratchpad             ; 224 bytes
MapDecorationSprites = Scratchpad + 256       ; 512 bytes
MapPrioritySprites   = Scratchpad + 256 + 512 ; ? bytes
MapDecorationLength  = TouchTemp     ; number of bytes
MapPriorityLength    = TouchTemp + 2 ; number of bytes

.import Overworld_Pointers
.import OWBlockTopLeft, OWBlockTopRight, OWBlockBottomLeft, OWBlockBottomRight
.import OWDecorationGraphic, OWDecorationPalette, OWDecorationPic
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

  lda #$ffff
  sta SpriteTileSlots+2*0
  sta SpriteTileSlots+2*1
  sta SpriteTileSlots+2*2
  sta SpriteTileSlots+2*3
  sta SpritePaletteSlots+2*0
  sta SpritePaletteSlots+2*1
  sta SpritePaletteSlots+2*2
  sta SpritePaletteSlots+2*3

  ; Start reading the overworld
  ldy #0
  seta8


  ; -------------------------

  ldx #0
UploadGraphicLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitGraphicLoop
  jsl DoGraphicUpload
  bra UploadGraphicLoop
ExitGraphicLoop:

  ; -------------------------

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
  inx
  bra UploadPaletteLoop
ExitPaletteLoop:

  ; -------------------------

  ldx #0
UploadSpriteGraphicLoop:
  lda (DecodePointer),y
  sta SpriteTileSlots,x
  iny
  cmp #255
  beq ExitSpriteGraphicLoop

  pha
  txa
  asl
  sta GraphicUploadOffset+1
  stz GraphicUploadOffset+0
  pla
  jsl DoGraphicUploadWithOffset
  inx
  bra UploadSpriteGraphicLoop
ExitSpriteGraphicLoop:

  ; -------------------------

  ldx #8
UploadSpritePaletteLoop:
  lda (DecodePointer),y
  sta SpritePaletteSlots-8,x
  iny
  cmp #255
  beq ExitSpritePaletteLoop
  phy
  txy
  jsl DoPaletteUpload
  ply
  inx
  bra UploadSpritePaletteLoop
ExitSpritePaletteLoop:

  ; -------------------------

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
: sta f:MapMetatileBuffer,x
  inx
  dec 0
  bne :-

  bra DecompressMapLoop

ExitMapLoop:

  ; -------------------------

  ldx #0
ReadPrioritySpriteLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitPrioritySpriteLoop
  jsr GetOverworldSpriteTile
  lda 0
  sta f:MapPrioritySprites+2,x
  ; Also returns 1, use it later

  ; Get X
  lda (DecodePointer),y
  iny
  sta f:MapPrioritySprites+0,x

  ; Get Y
  lda (DecodePointer),y
  iny
  sta f:MapPrioritySprites+1,x

  ; Get attributes
  lda (DecodePointer),y
  iny
  ora 1
  sta f:MapPrioritySprites+3,x
  inx
  inx
  inx
  inx
  bra ReadPrioritySpriteLoop
ExitPrioritySpriteLoop:
  stx MapPriorityLength

  ; -------------------------

  ldx #0
ReadDecorationSpriteLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitDecorationSpriteLoop
  jsr GetOverworldSpriteTile
  lda 0
  sta f:MapDecorationSprites+2,x
  ; Also returns 1, use it later

  ; Get X
  lda (DecodePointer),y
  iny
  sta f:MapDecorationSprites+0,x

  ; Get Y
  lda (DecodePointer),y
  iny
  sta f:MapDecorationSprites+1,x

  ; Get attributes
  lda (DecodePointer),y
  iny
  ora 1
  sta f:MapDecorationSprites+3,x
  inx
  inx
  inx
  inx
  bra ReadDecorationSpriteLoop
ExitDecorationSpriteLoop:
  stx MapDecorationLength

  ; ---------------

  ; Render the overworld
  lda #INC_DATAHI
  sta PPUCTRL
  seta16
  ldx #0
  lda #$c000>>1
  sta PPUADDR
RenderLoop:
  ; Top
  lda #16
  sta 0
: lda f:MapMetatileBuffer,x
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
: lda f:MapMetatileBuffer,x
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
  stz BGSCROLLX+2
  stz BGSCROLLX+2
  lda #$FF
  sta BGSCROLLY+0  ; The PPU displays lines 1-224, so set scroll to
  sta BGSCROLLY+0  ; $FF so that the first displayed line is line 0
  sta BGSCROLLY+2
  sta BGSCROLLY+2

  stz PPURES
  lda #%00010011  ; enable sprites, plane 0 and 1
  sta BLENDMAIN
  lda #VBLANK_NMI|AUTOREAD  ; but disable htime/vtime IRQ
  sta PPUNMI






  ; -----------------------------------
OverworldLoop:
  setaxy16
  jsl WaitKeysReady ; Also clears OamPtr

  ldy OamPtr
  ldx #0
OverworldPriorityRenderSpriteLoop:
  lda f:MapPrioritySprites+0,x
  sta OAM+0,y
  lda f:MapPrioritySprites+2,x
  jsr RenderSpriteShared
  cpy MapPriorityLength
  bne OverworldPriorityRenderSpriteLoop
  sty OamPtr
  ; -----------------------------------
  ldy OamPtr
  ldx #0
OverworldRenderSpriteLoop:
  lda f:MapDecorationSprites+0,x
  sta OAM+0,y
  lda f:MapDecorationSprites+2,x
  jsr RenderSpriteShared
  cpy MapDecorationLength
  bne OverworldRenderSpriteLoop
  sty OamPtr

  ldx OamPtr
  jsl ppu_clear_oam
  jsl ppu_pack_oamhi

  jsl WaitVblank
  jsl ppu_copy_oam
  seta8
  lda #15
  sta PPUBRIGHT
  jmp OverworldLoop

  rtl


.a16
RenderSpriteShared:
  sta OAM+2,y
  lda #$0200  ; Use 16x16 sprites
  sta OAMHI,y
  inx
  inx
  inx
  inx
  iny
  iny
  iny
  iny
  rts
.endproc

; Input: A = overworld sprite ID
; Output: 0 and 1
.a8
.i16
.proc GetOverworldSpriteTile
  phx
  phy

  setxy8
  tay

  ; Find the graphic
  lda OWDecorationGraphic,y
  ldx #3
: cmp SpriteTileSlots,x  
  beq :+
  dex
  bpl :-
: ; No handler for not finding it

  txa
  ; Multiply by 32
  asl
  asl
  asl
  asl
  asl
  ora OWDecorationPic,y
  sta 0

  ; Find the palette
  lda OWDecorationPalette,y
  ldx #3
: cmp SpritePaletteSlots,x  
  beq :+
  dex
  bpl :-
: ; No handler for not finding it

  txa
  asl
  ora #(>OAM_PRIORITY_2)|1 ; second set of 256 sprite tiles
  sta 1

  setxy16

  ply
  plx
  rts
.endproc

