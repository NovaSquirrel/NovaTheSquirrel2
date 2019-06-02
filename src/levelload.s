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
.import GetLevelPtrXY_Horizontal

.segment "CODE"

; Accumulator = level number
.a16
.i16
.proc StartLevel
  setaxy16
  sta StartedLevelNumber

  phk
  plb

  jsl DecompressLevel

  lda #Palette::SPNova
  ldy #8
  jsl DoPaletteUpload

  lda #GraphicsUpload::MapBGForest
  jsl DoGraphicUpload
  lda #GraphicsUpload::SPCommon
  jsl DoGraphicUpload

  ; Copy in a placeholder level
  ldx #0
: lda PlaceholderLevel,x
  sta f:LevelBuf,x
  inx
  inx
  cpx #PlaceholderLevelEnd-PlaceholderLevel
  bne :-

  ; -----------------------------------

  jsl RenderLevelScreens

  jml GameMainLoop
.endproc

; Accumulator = level number
.a16
.i16
.proc DecompressLevel
  sta LevelNumber

  ; Clear out some buffers before the level loads stuff into them

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

  ; Clear level buffer
  lda #0
  ldx #256*32*2-2
: sta f:LevelBuf,x
  sta f:LevelBufAlt,x
  dex
  dex
  bpl :-

  ; Clear ColumnBytes
  ; lda #0 <--- not needed, still zero
  ldx #256-2
: sta f:ColumnBytes,x
  dex
  dex
  bpl :-

  ; Set defaults for horizontal levels
  lda #.loword(GetLevelPtrXY_Horizontal)
  sta GetLevelPtrXY_Ptr
  lda #32*2 ; 32 blocks tall
  sta LevelColumnSize

  seta8
  ; Clear a bunch of stuff in one go that's in contiguous space in memory
  ldx #LevelZeroWhenLoad_End-LevelZeroWhenLoad_Start-1
: stz LevelZeroWhenLoad_Start,x
  dex
  bpl :-

  ; -----------------------------------

  ; Parse the level header
  ; (Replace with a lookup later)
  lda #<SampleLevelHeader
  sta DecodePointer+0
  lda #>SampleLevelHeader
  sta DecodePointer+1
  lda #^SampleLevelHeader
  sta DecodePointer+2

  ; Music and starting player direction
  lda [DecodePointer]
  and #128
  sta PlayerDir

  ldy #1
  ; Starting X position
  lda [DecodePointer],y
  sta PlayerPX+1
  stz PlayerPX+0

  iny ; Y = 2
  ; Starting Y position
  lda [DecodePointer],y
  and #31
  sta PlayerPY+1
  stz PlayerPY+0

  ; Vertical scrolling and layer 2 flags
  iny ; Y = 3
  ; (Don't do anything with yet)

  ; Background color
  iny ; Y = 4
  stz CGADDR
  lda [DecodePointer],y
  sta LevelBackgroundColor+0
  sta CGDATA
  iny ; Y = 5
  lda [DecodePointer],y
  sta LevelBackgroundColor+1
  sta CGDATA

  iny ; Y = 6
  ; Background, two bytes
  ; (Don't do anything with yet)
  iny ; Y = 7
  ; Unused background byte

  ; Sprite data pointer
  iny ; Y = 8
  lda [DecodePointer],y
  sta LevelSpritePointer+0
  iny ; Y = 9
  lda [DecodePointer],y
  sta LevelSpritePointer+1
  lda DecodePointer+2
  sta LevelSpritePointer+2

  ; Scroll barriers
  ; Convert from bit array to byte array for easier access
  lda #1
  sta ScreenFlags+0    ; first screen has left boundary
  sta ScreenFlagsDummy ; last screen has right boundary
  iny ; Y = 10
  ldx #0
  lda [DecodePointer],y
: asl
  rol ScreenFlags+1,x
  inx
  cpx #8 ; move onto the next byte after we're done with the first
  bne :+
    iny ; Y = 11
    lda [DecodePointer],y
  :
  cpx #15
  beq :+
  bne :--
:

  iny ; Y = 12
  ; Sprite graphic slots
  ldx #0
: lda [DecodePointer],y
  iny
  sta SpriteTileSlots+0,x
  stz SpriteTileSlots+1,x
  cmp #255
  beq :+
    jsl DoGraphicUpload
  : 
  inx
  inx
  cpx #8*2
  bne :--

  ; Background palettes
  ldx #0
: lda [DecodePointer],y
  iny
  phy
  txy
  jsl DoPaletteUpload
  ply
  inx
  cpx #8
  bne :-

  ; Graphical assets
: lda [DecodePointer],y
  iny
  cmp #255
  beq :+
  jsl DoGraphicUpload
  bra :-
:

  ; Level data pointer
  lda [DecodePointer],y
  pha
  iny
  lda [DecodePointer],y
  sta DecodePointer+1
  pla
  sta DecodePointer+0

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
  setaxy16

  rtl
.endproc



SampleLevelHeader:
  .byt 0   ; No music, and facing right
  .byt 5   ; start at X position 5
  .byt 13  ; start at Y position 13 
  .byt $40 ; vertical scrolling allowed
  .word RGB(15,23,31) ; background color
  .word 1  ; background
  .addr SampleLevelSprite
  .word 0  ; No scroll barriers
  ; Eight sprite graphic slots
  .byt GraphicsUpload::SPWalker
  .byt GraphicsUpload::SPCannon
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  ; Eight background palette slots
  .byt Palette::FGCommon
  .byt Palette::FGGrassy
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt Palette::BGForest 
  ; Level graphic assets
  .byt GraphicsUpload::FGCommon
  .byt GraphicsUpload::FGGrassy
  .byt GraphicsUpload::FGTropicalWood
  .byt GraphicsUpload::BGForest
  .byt 255
  ; Pointer to the level foreground data
  .addr SampleLevelData

SampleLevelData:
  .byt $f0

SampleLevelSprite:
  .byt $ff


PlaceholderLevel:
.repeat 3
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 6, 6, 6, 6, 6
.endrep

.repeat 5
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::Ledge*2, Block::LedgeMiddle*2
.endrep

  ; Steep
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeL_U*2, Block::SteepSlopeL_D*2, Block::LedgeMiddle*2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeL_U*2, Block::SteepSlopeL_D*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeL_U*2, Block::SteepSlopeL_D*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

.repeat 5
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::LedgeSlopeAdjacent*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
.endrep

  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeR_U*2, Block::SteepSlopeR_D*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeR_U*2, Block::SteepSlopeR_D*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::SteepSlopeR_U*2, Block::SteepSlopeR_D*2, Block::LedgeMiddle*2

.repeat 5
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::Ledge*2, Block::LedgeMiddle*2
.endrep

  ; Medium
.if 1
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UL*2, Block::MedSlopeL_DL*2, Block::LedgeMiddle*2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UR*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UL*2, Block::MedSlopeL_DL*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UR*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UL*2, Block::MedSlopeL_DL*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeL_UR*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
.endif

.repeat 4
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::LedgeSlopeAdjacent*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
.endrep

  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UL*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UR*2, Block::MedSlopeR_DR*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UL*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UR*2, Block::MedSlopeR_DR*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2

  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UL*2, Block::LedgeMiddle*2, Block::LedgeMiddle*2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Block::MedSlopeR_UR*2, Block::MedSlopeR_DR*2, Block::LedgeMiddle*2


.repeat 8
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 2, 2
.endrep
.repeat 10
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2
.endrep
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2
.repeat 10
  .word 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2
.endrep
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 6, 6, 6, 6, 6
PlaceholderLevelEnd:
