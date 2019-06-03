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
.include "leveldata.inc"
.smart
.import GameMainLoop
.import GetLevelPtrXY_Horizontal, GetLevelPtrXY_Vertical

.segment "CODE"

; Accumulator = level number
.a16
.i16
.proc StartLevel
  setaxy16
  sta StartedLevelNumber

  ; Will access the level data with 24-bit pointers.
  ; Set data bank to this bank for lookup tables.
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

  jsl RenderLevelScreens

  jml GameMainLoop
.endproc

; .----------------------------------------------------------------------------
; | Header parsing
; '----------------------------------------------------------------------------
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
  lda [DecodePointer],y
  bpl :+
    ; (Is a vertical level)
    ; Swap starting X and Y positions
    lda PlayerPX+1
    pha
    lda PlayerPY+1
    sta PlayerPX+1
    pla
    sta PlayerPX+1

    lda #<GetLevelPtrXY_Vertical
    sta GetLevelPtrXY_Ptr+0
    lda #>GetLevelPtrXY_Vertical
    sta GetLevelPtrXY_Ptr+1

    ; In vertical levels, columns are 256 blocks tall, multiplied by 2 bytes
    stz LevelColumnSize+0
    lda #2
    sta LevelColumnSize+1

    dec VerticalLevelFlag ; Set it to 255
  :
  ; (TODO: use the other flags)


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

  ; -----------------------------------

  ; Now use the new DecodePointer to decompress the level data
  rtl
.endproc

; .----------------------------------------------------------------------------
; | Level command templates
; '----------------------------------------------------------------------------
.enum
  SPECIAL_ROUTINE      = 0   ; ??
  BLOCK_SINGLE         = 2   ; TT XY
  BLOCK_RECTANGLE      = 4   ; TT XY WH
  BLOCK_WIDE_FROM_LIST = 6   ; TT XY Wm
  BLOCK_TALL_FROM_LIST = 8   ; TT XY Hm
  BLOCK_RECT_FROM_LIST = 10  ; TT XY Hm WW
.endenum


; Make sure to keep synchronized with the LO enum in leveldata.inc
; Maxes out at 120 commands? Last 8 correspond to special commands.
.proc LevelCommands
  .word $ffff&CustomBlockSingle,    0
  .word $ffff&CustomBlockRectangle, 0

  .word $ffff&BlockWideList,        32*0
  .word $ffff&BlockTallList,        32*0
  .word $ffff&BlockRectList,        32*0
  .word $ffff&BlockWideList,        32*1
  .word $ffff&BlockTallList,        32*1
  .word $ffff&BlockRectList,        32*1
  .word $ffff&BlockWideList,        32*2
  .word $ffff&BlockTallList,        32*2
  .word $ffff&BlockRectList,        32*2

  .word $ffff&BlockRectangle,       Block::Empty
  .word $ffff&BlockRectangle,       Block::Bricks
  .word $ffff&BlockRectangle,       Block::SolidBlock
  .word $ffff&BlockRectangle,       Block::Ice
  .word $ffff&BlockRectangle,       Block::LedgeMiddle
  .word $ffff&BlockSingle,          Block::Bricks
  .word $ffff&BlockSingle,          Block::Prize
  .word $ffff&BlockSingle,          Block::SolidBlock
  .word $ffff&BlockSingle,          Block::PickupBlock
  .word $ffff&BlockSingle,          Block::PushBlock
  .word $ffff&BlockSingle,          Block::Heart
  .word $ffff&BlockSingle,          Block::SmallHeart
  .word $ffff&BlockSingle,          Block::Sign
  .word $ffff&BlockSingle,          Block::Money
  .word $ffff&BlockSingle,          Block::Spring
  .word $ffff&BlockSingle,          Block::Rock
  .word $ffff&BlockSingle,          Block::LedgeLeft
  .word $ffff&BlockSingle,          Block::LedgeRight
  .word $ffff&BlockSingle,          Block::LedgeSolidLeft
  .word $ffff&BlockSingle,          Block::LedgeSolidRight
.assert (* - LevelCommands) < 120*4, error, "Too many level commands defined"
.endproc

; Used with BlockWideList, BlockTallList and BlockRectList
.proc NybbleTypesList
; Set 1
  .word Block::Empty
  .word Block::Ladder
  .word Block::SpikesUp
  .word Block::SpikesDown
  .word Block::Ledge
  .word Block::Money
  .word Block::PickupBlock
  .word Block::PushBlock
  .word Block::LedgeMiddle
  .word Block::Prize
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
; Set 2
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
; Set 3
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
  .word Block::Empty
.endproc

; .----------------------------------------------------------------------------
; | Actual handlers for the command templates
; '----------------------------------------------------------------------------
.a8
.proc BlockSingle
  rts
.endproc

.a8
.proc BlockRectangle
  rts
.endproc

.a8
.proc CustomBlockSingle
  rts
.endproc

.a8
.proc CustomBlockRectangle
  rts
.endproc

.a8
.proc BlockWideList
  rts
.endproc

.a8
.proc BlockTallList
  rts
.endproc

.a8
.proc BlockRectList
  rts
.endproc

; .----------------------------------------------------------------------------
; | Sample level while there isn't a level directory yet
; '----------------------------------------------------------------------------
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
  LObjN LO::R_SolidBlock,   0, 30,    15, 1
  LObj  LO::S_Spring,       4, 29
  LObj  LO::S_PickupBlock,  1, 29
  LObj  LO::S_PushBlock,    1, 29
  LObjN LO::R_Ice,          1, 25,    4, 4
  LFinished

SampleLevelSprite:
  .byt $ff
