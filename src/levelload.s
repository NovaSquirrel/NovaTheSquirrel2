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
.import GameMainLoop, AutotileLevel
.import GetLevelPtrXY_Horizontal, GetLevelPtrXY_Vertical

.segment "LevelDecompress"

; Accumulator = level number
.a16
.i16
.proc StartLevel
  setaxy16
  sta StartedLevelNumber

  jsl DecompressLevel
  jsl AutotileLevel

  lda #1*2
  sta ObjectStart+ObjectType
  lda #0*256
  sta ObjectStart+ObjectPX
  lda #20*256
  sta ObjectStart+ObjectPY
  lda #0
  sta ObjectStart+ObjectVX
  sta ObjectStart+ObjectVY

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

  ; Clear sprite palette slots
  lda #$ffff
  sta SpritePaletteSlots+2*0
  sta SpritePaletteSlots+2*1
  sta SpritePaletteSlots+2*2
  sta SpritePaletteSlots+2*3

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

  ; Set the high byte of the level pointer
  ; so later accesses work correctly.
  lda #^LevelBuf
  sta LevelBlockPtr+2

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

  ; -----------------------------------

  ; Now use the new DecodePointer to decompress the level data
  phk
  plb
  stz DecodeColumn
  jsr LevelDecodeLoop

  ; Put the registers back in their expected sizes
  setaxy16
  rtl
.endproc

.proc LevelDecodeLoop
: jsr LevelDecodeCommand
  bra :-
.endproc

DecodeType   = 2
DecodeWidth  = 3
DecodeHeight = 4
DecodeColumn = 5 ; Current column to write to
DecodeValue  = 6 ; and 7
.a8
.i16
.proc LevelDecodeCommand
  jsr NextLevelByte
  sta DecodeType
  cmp #$f0
  bcs SpecialCommand

  seta16
  and #<~1 ; Already effectively multiplied by 2
  asl      ; so multiply by 4 now
  tax
  seta8

  jmp (.loword(LevelCommands),x)

SpecialCommand:
  seta16
  and #$0f
  asl
  tax
  seta8
  jmp (.loword(SpecialCommandTable),x)

SpecialCommandTable:
  .addr SpecialFinished
  .addr SpecialSetX
  .addr SpecialWrite1Column
  .addr SpecialWrite2Column
  .addr SpecialWrite3Column
  .addr SpecialXMinus16
  .addr SpecialXPlus16
  .addr SpecialConfig

SpecialFinished:
  plx ; Pop two bytes
  rts
SpecialSetX:
  jsr NextLevelByte
  sta DecodeColumn
  rts
SpecialWrite3Column:
  rts
SpecialWrite2Column:
  rts
SpecialWrite1Column:
  rts
SpecialXMinus16:
  lda DecodeColumn
  sub #16
  sta DecodeColumn
  rts
SpecialXPlus16:
  lda DecodeColumn
  add #16
  sta DecodeColumn
  rts
SpecialConfig:
  jsr NextLevelByte
  ; Call additional table
  rts
.endproc

; .----------------------------------------------------------------------------
; | Level command templates
; '----------------------------------------------------------------------------

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

  .word $ffff&BlockRectangle,       2*Block::Empty
  .word $ffff&BlockRectangle,       2*Block::Bricks
  .word $ffff&BlockRectangle,       2*Block::SolidBlock
  .word $ffff&BlockRectangle,       2*Block::Ice
  .word $ffff&BlockRectangle,       2*Block::LedgeMiddle
  .word $ffff&BlockSingle,          2*Block::Bricks
  .word $ffff&BlockSingle,          2*Block::Prize
  .word $ffff&BlockSingle,          2*Block::SolidBlock
  .word $ffff&BlockSingle,          2*Block::PickupBlock
  .word $ffff&BlockSingle,          2*Block::PushBlock
  .word $ffff&BlockSingle,          2*Block::Heart
  .word $ffff&BlockSingle,          2*Block::SmallHeart
  .word $ffff&BlockSingle,          2*Block::Sign
  .word $ffff&BlockSingle,          2*Block::Money
  .word $ffff&BlockSingle,          2*Block::Spring
  .word $ffff&BlockSingle,          2*Block::Rock
  .word $ffff&BlockSingle,          2*Block::LedgeLeft
  .word $ffff&BlockSingle,          2*Block::LedgeRight
  .word $ffff&BlockSingle,          2*Block::LedgeSolidLeft
  .word $ffff&BlockSingle,          2*Block::LedgeSolidRight

  .word $ffff&SlopeLGradual,        0
  .word $ffff&SlopeLMedium,         0
  .word $ffff&SlopeLSteep,          0
  .word $ffff&SlopeRGradual,        0
  .word $ffff&SlopeRMedium,         0
  .word $ffff&SlopeRSteep,          0
.assert (* - LevelCommands) < 120*4, error, "Too many level commands defined"
.endproc

; Used with BlockWideList, BlockTallList and BlockRectList
.proc NybbleTypesList
; Set 1
  .word Block::Empty*2
  .word Block::Ladder*2
  .word Block::SpikesUp*2
  .word Block::SpikesDown*2
  .word Block::Ledge*2
  .word Block::Money*2
  .word Block::PickupBlock*2
  .word Block::PushBlock*2
  .word Block::LedgeMiddle*2
  .word Block::Prize*2
  .word Block::SolidBlock*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
; Set 2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
; Set 3
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
  .word Block::Empty*2
.endproc

; .----------------------------------------------------------------------------
; | Actual handlers for the command templates
; '----------------------------------------------------------------------------
.a8
.proc BlockSingle ; XY
  jsr XYLevelByte
  lda LevelCommands+2,x
  sta [LevelBlockPtr],y
  iny
  lda LevelCommands+3,x
  sta [LevelBlockPtr],y
  rts
.endproc

.a8
.proc BlockRectangle ; XY WH
  jsr XYLevelByte
  lda LevelCommands+2,x
  sta DecodeValue+0
  lda LevelCommands+3,x
  sta DecodeValue+1
  jmp HasRectangleParameter
.endproc

.a8
.proc CustomBlockSingle ; XY TT TT
  jsr XYLevelByte
  jsr NextLevelByte
  sta [LevelBlockPtr],y
  iny
  jsr NextLevelByte
  sta [LevelBlockPtr],y
  rts
.endproc

.a8
.proc CustomBlockRectangle ; XY TT TT WH
  jsr XYLevelByte
  jsr NextLevelByte
  sta DecodeValue+0
  jsr NextLevelByte
  sta DecodeValue+1
  jmp HasRectangleParameter
.endproc

.a8
.proc BlockWideList ; XY WT
  jsr XYLevelByte
  jsr NextLevelByte
  stz DecodeHeight
  pha
  lsr
  lsr
  lsr
  lsr
  sta DecodeWidth
  pla
  jsr UseNybbleTable
  jmp DecodeWriteRectangle
.endproc

.a8
.proc BlockTallList ; XY HT
  jsr XYLevelByte
  jsr NextLevelByte
  stz DecodeWidth
  pha
  lsr
  lsr
  lsr
  lsr
  sta DecodeHeight
  pla
  jsr UseNybbleTable
  jmp DecodeWriteRectangle
.endproc

.a8
.proc BlockRectList ; XY HT WW
  jsr XYLevelByte
  jsr NextLevelByte
  pha
  lsr
  lsr
  lsr
  lsr
  sta DecodeHeight
  pla
  jsr UseNybbleTable
  jsr NextLevelByte
  sta DecodeWidth
  jmp DecodeWriteRectangle
.endproc

.a8
.proc SlopeLGradual ; XY WH
  jsr GetXYWidthHeight_WidthInX
  .a16

Loop:
  phy
  phy
  phy
  phy
  lda #2*Block::GradualSlopeL_U1
  sta [LevelBlockPtr],y
  iny
  iny
  lda #2*Block::GradualSlopeL_D1
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn

  ply
  lda #2*Block::GradualSlopeL_U2
  sta [LevelBlockPtr],y
  iny
  iny
  lda #2*Block::GradualSlopeL_D2
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn

  ply
  lda #2*Block::GradualSlopeL_U3
  sta [LevelBlockPtr],y
  inc DecodeHeight
  jsr SlopeDirtColumn

  ply
  lda #2*Block::GradualSlopeL_U4
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn
  ply

  dey
  dey

  dex
  bpl Loop

  seta8
  rts
.endproc

.a8
.proc SlopeLMedium ; XY WH
  jsr GetXYWidthHeight_WidthInX
  .a16

Loop:
  phy
  phy
  lda #2*Block::MedSlopeL_UL
  sta [LevelBlockPtr],y
  iny
  iny
  lda #2*Block::MedSlopeL_DL
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn
  ply
  lda #2*Block::MedSlopeL_UR
  sta [LevelBlockPtr],y
  inc DecodeHeight
  jsr SlopeDirtColumn
  ply

  dey
  dey

  dex
  bpl Loop

  seta8
  rts
.endproc

.a8
.proc SlopeLSteep ; XY WH
  jsr GetXYWidthHeight_WidthInX
  .a16

Loop:
  phy
  lda #2*Block::SteepSlopeL_U
  sta [LevelBlockPtr],y
  iny
  iny
  lda #2*Block::SteepSlopeL_D
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn
  ply

  dey
  dey
  inc DecodeHeight

  dex
  bpl Loop

  seta8
  rts
.endproc

.a8
.proc SlopeRGradual ; XY WH
  jsr GetXYWidthHeight_WidthInX
  jsr DownhillSlope
  .a16

Loop:
  phy
  phy
  phy
  phy
  lda #2*Block::GradualSlopeR_U1
  sta [LevelBlockPtr],y
  iny
  iny
  lda #2*Block::LedgeMiddle
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn

  ply
  lda #2*Block::GradualSlopeR_U2
  sta [LevelBlockPtr],y
  iny
  iny
  lda #2*Block::LedgeMiddle
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn

  ply
  lda #2*Block::GradualSlopeR_U3
  sta [LevelBlockPtr],y
  iny
  iny
  lda #2*Block::GradualSlopeR_D3
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn

  ply
  lda #2*Block::GradualSlopeR_U4
  sta [LevelBlockPtr],y
  iny
  iny
  lda #2*Block::GradualSlopeR_D4
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn
  ply
  seta8
  dec DecodeHeight
  seta16
  iny
  iny

  dex
  bpl Loop

  seta8
  rts
.endproc

.a8
.proc SlopeRMedium ; XY WH
  jsr GetXYWidthHeight_WidthInX
  jsr DownhillSlope
  .a16

Loop:
  phy
  phy
  lda #2*Block::MedSlopeR_UL
  sta [LevelBlockPtr],y
  iny
  iny
  lda #2*Block::LedgeMiddle
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn
  ply
  lda #2*Block::MedSlopeR_UR
  sta [LevelBlockPtr],y
  iny
  iny
  lda #2*Block::MedSlopeR_DR
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn
  ply

  seta8
  dec DecodeHeight
  seta16
  iny
  iny

  dex
  bpl Loop

  seta8
  rts
.endproc

.a8
.proc SlopeRSteep ; XY WH
  jsr GetXYWidthHeight_WidthInX
  jsr DownhillSlope
  .a16
Loop:
  lda #2*Block::SteepSlopeR_U
  sta [LevelBlockPtr],y
  iny
  iny
  phy
  lda #2*Block::SteepSlopeR_D
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn
  ply

  seta8
  dec DecodeHeight
  seta16

  dex
  bpl Loop

  seta8
  rts
.endproc


; .----------------------------------------------------------------------------
; | Level comand helpers
; '----------------------------------------------------------------------------
; Get the position byte and calculate a level pointer using that
.a8
.i16
.proc XYLevelByte
  jsr NextLevelByte

  pha
  ; Add the X offset
  lsr
  lsr
  lsr
  lsr
  add DecodeColumn
  sta DecodeColumn

  ; Get the Y position
  pla ; XY byte
  and #15
  lsr DecodeType ; Destructively read the least significant bit
  bcc :+
    ora #16
  :
  sta 0 ; Y position (0-31)


  bit VerticalLevelFlag
  bpl Horizontal
; In vertical levels, X and Y values are swapped
Vertical:
  ; Use "Y" position as column instead
  seta16
  jsl GetLevelColumnPtr
  ; Y is the current row times two
  lda DecodeColumn
Common:
  asl
  tay
  seta8
  rts

; In horizontal levels, things are normal
Horizontal:
  lda DecodeColumn
  seta16
  jsl GetLevelColumnPtr
  ; Set Y to the height * 2
  lda 0
  and #255
  bra Common
.endproc

; -------------------------------------

; Get a byte and step the pointer
.a8
.proc NextLevelByte
  lda [DecodePointer]
  inc DecodePointer+0
  bne :+
  inc DecodePointer+1
: rts
.endproc

; -------------------------------------

; Get the width and height byte, separate it, and then fall into the rectangle writer
HasRectangleParameter:
  jsr GetWidthHeight
; Writes a rectangle to the level buffer
; locals: 0
.a8
.proc DecodeWriteRectangle
  inc DecodeWidth  ; Increase width and height by 1
  inc DecodeHeight ; So that 0 is 1 and 15 is 16
ColumnLoop:
  lda DecodeHeight ; Save height
  sta 0

  phy
RowLoop:
  lda DecodeValue+0
  sta [LevelBlockPtr],y
  iny
  lda DecodeValue+1
  sta [LevelBlockPtr],y
  iny
  dec 0
  bne RowLoop
  ply

  ; Next column
  seta16
  lda LevelBlockPtr
  add LevelColumnSize
  sta LevelBlockPtr
  seta8

  dec DecodeWidth
  bne ColumnLoop
  rts
.endproc

; -------------------------------------

; Select a block type from NybbleTypesList
.proc UseNybbleTable
  seta16
  and #15
  asl
  ora LevelCommands+2,x
  tax
  lda NybbleTypesList,x
  sta DecodeValue
  seta8
  rts
.endproc

; -------------------------------------

; Helper routine for slopes
.a16
.proc SlopeDirtColumn
  phx
  iny
  iny

  ; Use X as a counter
  lda DecodeHeight
  and #255
  ina
  tax

  ; Fill in dirt
  lda #2*Block::LedgeMiddle
: dex
  beq :+
  sta [LevelBlockPtr],y
  iny
  iny
  bra :-
:
  
  ; Next column
  lda LevelBlockPtr
  add LevelColumnSize
  sta LevelBlockPtr
  plx
  rts
.endproc

; -------------------------------------

; Get the width hand height byte and separate the nybbles
GetXYWidthHeight:
  jsr XYLevelByte
GetWidthHeight:
  jsr NextLevelByte
.a8
; Separates a WH byte into a separate DecodeWidth and DecodeHeight
.proc SeparateWidthHeight
  pha
  lsr
  lsr
  lsr
  lsr
  sta DecodeWidth
  pla
  and #15
  sta DecodeHeight
  rts
.endproc

; -------------------------------------

; Like the above but puts the width in X for loop use.
; Slope helper routine. Leaves the accumulator 16-bit.
.proc GetXYWidthHeight_WidthInX
  jsr GetXYWidthHeight
  seta16
  lda DecodeWidth
  and #255
  tax
  rts
.endproc

; -------------------------------------

; Initializes the starting height appropriately
.proc DownhillSlope
  seta8
  lda DecodeWidth
  add DecodeHeight
  sta DecodeHeight
  seta16
  rts
.endproc

; .----------------------------------------------------------------------------
; | Sample level while there isn't a level directory yet
; '----------------------------------------------------------------------------
SampleLevelHeader:
  .byt 0   ; No music, and facing right
  .byt 3   ; start at X position 3
  .byt 13  ; start at Y position 13
  .byt $40 ; vertical scrolling allowed
  .word RGB(15,23,31) ; background color
  .word 1  ; background
  .addr SampleLevelSprite
  .byt %00000000, %00000000  ; No scroll barriers
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
  LObjN LO::Rect1, 0, 30, 0, LN1::Ledge, 17
  LObjN LO::Wide1, 2, 26, 4, LN1::Prize
  LObjN LO::Tall1, 7, 24, 5, LN1::Ladder
  LObjN LO::Wide1, 1, 24, 5, LN1::Ledge
  LObjN LO::Rect1, 0, 21, 1, LN1::Money, 1
  LObjN LO::Wide1, 2, 21, 5, LN1::Ledge
  LObjN LO::Rect1, 0, 18, 1, LN1::Money, 1
  LObjN LO::R_Bricks, 2, 17, 2, 0
  LObjN LO::SlopeL_Gradual, 4, 29, 0, 0
  LObjN LO::SlopeL_Medium, 4, 28, 1, 1
  LObjN LO::SlopeL_Steep, 4, 26, 3, 3
  LObjN LO::SlopeL_Medium, 4, 22, 1, 1
  LObjN LO::SlopeL_Gradual, 4, 20, 0, 0
  LObjN LO::Wide1, 4, 20, 6, LN1::Ledge
  LObjN LO::Wide1, 1, 18, 4, LN1::Money
  LObjN LO::SlopeR_Gradual, 6, 20, 0, 0
  LObjN LO::SlopeR_Medium, 4, 21, 1, 1
  LObjN LO::SlopeR_Steep, 4, 23, 3, 3
  LObjN LO::SlopeR_Medium, 4, 27, 1, 1
  LObjN LO::SlopeR_Gradual, 4, 29, 0, 0
  LObjN LO::Wide1, 4, 30, 1, LN1::Ledge
  LObj  LO::S_Spring, 1, 29
  LRCustom Block::LedgeSolidLeft, 1, 26, 0, 4
  LObjN LO::Wide1, 1, 26, 5, LN1::Ledge
  LObj  LO::S_Spring, 5, 25
  LRCustom Block::LedgeSolidLeft, 1, 22, 0, 4
  LObjN LO::Wide1, 1, 22, 3, LN1::Ledge
  LRCustom Block::LedgeSolidRight, 4, 22, 0, 9
  LFinished

SampleLevelSprite:
  .byt $ff
