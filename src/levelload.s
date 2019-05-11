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
.include "blockenum.s"
.smart
.import GameMainLoop

.segment "CODE"

; Accumulator = level number
.a16
.i16
.proc StartLevel
  setaxy16
  sta StartedLevelNumber

  phk
  plb

  ; Init entities
  ldx #ObjectStart
: stz 0,x
  inx
  inx
  cpx #ObjectEnd
  bne :-

  ; Init particles
  ldx #ParticleStart
: stz 0,x
  inx
  inx
  cpx #ParticleEnd
  bne :-


  lda #8*2
  sta ObjectStart+ObjectType
  lda #4*256
  sta ObjectStart+ObjectPX
  lda #20*256
  sta ObjectStart+ObjectPY


  ; Init player
  lda #4*256
  sta PlayerPX
  sta PlayerPY

  ; Clear level buffer
  lda #0
  tax
: sta f:LevelBuf,x
  inx
  inx
  cpx #256*32*2
  bne :-

  ; Copy in a placeholder level
  ldx #0
: lda PlaceholderLevel,x
  sta f:LevelBuf,x
  inx
  inx
  cpx #PlaceholderLevelEnd-PlaceholderLevel
  bne :-


  ; Upload graphics
  lda #GraphicsUpload::FGCommon
  jsl DoGraphicUpload
  lda #GraphicsUpload::FGGrassy
  jsl DoGraphicUpload
  lda #GraphicsUpload::FGTropicalWood
  jsl DoGraphicUpload
  lda #GraphicsUpload::SPCommon
  jsl DoGraphicUpload
  lda #GraphicsUpload::SPWalker
  jsl DoGraphicUpload
  lda #GraphicsUpload::SPCannon
  jsl DoGraphicUpload

  ; Upload palettes
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
  lda #Palette::SPNova
  ldy #8
  jsl DoPaletteUpload
  lda #Palette::FGCommon
  ldy #9
  jsl DoPaletteUpload
  lda #Palette::SPWalker
  ldy #15
  jsl DoPaletteUpload
  lda #Palette::SPCannon
  ldy #14
  jsl DoPaletteUpload

  ; Write this information to the slot tables
  lda #$ffff
  sta SpriteTileSlots
  sta SpriteTileSlots+2
  sta SpriteTileSlots+4
  sta SpriteTileSlots+6
  sta SpriteTileSlots+8
  sta SpriteTileSlots+10
  sta SpriteTileSlots+12
  sta SpriteTileSlots+14

  sta SpritePaletteSlots+0
  sta SpritePaletteSlots+2
  lda #Palette::SPCannon
  sta SpritePaletteSlots+4
  lda #Palette::SPWalker
  sta SpritePaletteSlots+6

  lda #GraphicsUpload::SPWalker
  sta SpriteTileSlots+0
  lda #GraphicsUpload::SPCannon
  sta SpriteTileSlots+4

  ; -----------------------------------

  ; Set up PPU registers
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
  lda #1 | ($d000 >> 9)
  sta NTADDR+1   ; plane 1 nametable also at $d000, 2 screens wide
  lda #0 | ($e000 >> 9)
  sta NTADDR+2   ; plane 2 nametable at $e000, 1 screen

  ; set up plane 0's scroll
  stz BGSCROLLX+0
  stz BGSCROLLX+0
  lda #$FF
  sta BGSCROLLY+0  ; The PPU displays lines 1-224, so set scroll to
  sta BGSCROLLY+0  ; $FF so that the first displayed line is line 0

  stz PPURES
  lda #%00010001  ; enable sprites and plane 0
  sta BLENDMAIN
  lda #VBLANK_NMI|AUTOREAD  ; but disable htime/vtime IRQ
  sta PPUNMI
  setaxy16

  jsl RenderLevelScreens

  jml GameMainLoop
.endproc

; Accumulator = level number
.a16
.i16
.proc DecompressLevel
  sta LevelNumber
  rtl
.endproc


PlaceholderLevel:
.repeat 3
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 6, 6, 6, 6, 6
.endrep

.repeat 5
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::Ledge*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
.endrep

  ; Steep
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeL_U*2, Block::SteepSlopeL_D*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeL_U*2, Block::SteepSlopeL_D*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeL_U*2, Block::SteepSlopeL_D*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

.repeat 5
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::LedgeSlopeAdjacent*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
.endrep

  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeR_U*2, Block::SteepSlopeR_D*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeR_U*2, Block::SteepSlopeR_D*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeR_U*2, Block::SteepSlopeR_D*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

.repeat 5
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::Ledge*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
.endrep

  ; Medium
.if 1
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UL*2, Block::MedSlopeL_DL*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UR*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UL*2, Block::MedSlopeL_DL*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UR*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UL*2, Block::MedSlopeL_DL*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UR*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
.endif

.repeat 4
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::LedgeSlopeAdjacent*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
.endrep

  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UL*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UR*2, Block::MedSlopeR_DR*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UL*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UR*2, Block::MedSlopeR_DR*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UL*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UR*2, Block::MedSlopeR_DR*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2


.repeat 8
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 2, 2, 2, 2
.endrep
.repeat 10
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2
.endrep
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2
.repeat 10
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2
.endrep
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 6, 6, 6, 6, 6
PlaceholderLevelEnd:
