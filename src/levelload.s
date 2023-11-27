; Super Princess Engine
; Copyright (C) 2019-2020 NovaSquirrel
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
.include "leveldata.inc"
.smart
.import GameMainLoop, AutotileLevel, UploadLevelGraphics
.import GetLevelPtrXY_Horizontal, GetLevelPtrXY_Vertical
.import GetBlockX_Horizontal, GetBlockY_Horizontal, GetBlockXCoord_Horizontal, GetBlockYCoord_Horizontal
.import GetBlockX_Vertical, GetBlockY_Vertical, GetBlockXCoord_Vertical, GetBlockYCoord_Vertical
.import BlockByteReferenceTable

.segment "C_LevelDecompress"

; Accumulator = level number
.a16
.i16
.export StartLevel, StartLevelFromDoor
.proc StartLevel
  setaxy16
  ; Taken from the overworld and used for level-specific flags
  sta StartedLevelNumber
::StartLevelFromDoor:
  ldx #$1ff
  txs ; Reset the stack pointer so no cleanup is needed
  jsr StartLevelCommon
  jsl UploadLevelGraphics
  jsl MakeCheckpoint
  jml GameMainLoop
.endproc

; Called both when starting a level normally and when making a checkpoint through other means
.export MakeCheckpoint
.proc MakeCheckpoint
  php

  seta8
  ; Y instead of X so an actor can call it easily
  ldy #GameStateSize-1
: lda GameStateStart,y
  sta CheckpointState,y
  dey
  bpl :-

  lda PlayerPX+1
  sta CheckpointX
  lda PlayerPY+1
  sta CheckpointY

  plp
  rtl
.endproc

; Stuff that's done whether a level is started from scratch or resumed
.proc StartLevelCommon
  jsl DecompressLevel
  jsl AutotileLevel
  inc RerenderInitEntities
  rts
.endproc

.a16
.i16
.export ResumeLevelFromCheckpoint
.proc ResumeLevelFromCheckpoint
  jsr StartLevelCommon

  ; Restore saved state
  seta8
  ldy #GameStateSize-1
: lda CheckpointState,y
  sta GameStateStart,y
  dey
  bpl :-

  lda CheckpointX
  sta PlayerPX+1
  lda CheckpointY
  sta PlayerPY+1

  ; Wait until here to do this, because it renders the screen and we're overriding the player start position
  jsl UploadLevelGraphics

  ; Don't need to restore register size because GameMainLoop does setaxy16
  jml GameMainLoop
.endproc

; .----------------------------------------------------------------------------
; | Header parsing
; '----------------------------------------------------------------------------
; Loads the level whose header is pointed to by LevelHeaderPointer
.a16
.i16
.export DecompressLevel
.proc DecompressLevel
  ; Clear out some buffers before the level loads stuff into them

  ; Don't clear any entities, that'll be done when rendering

  ; Clear level buffer
  ldx #.loword(LevelBuf)
  ldy #(256*32*2)*2
  jsl MemClear7F


  ; Clear sprite palette slots
  lda #$ffff
  sta SpritePaletteSlots+2*0
  sta SpritePaletteSlots+2*1
  sta SpritePaletteSlots+2*2
  sta SpritePaletteSlots+2*3

  ldx #.loword(ColumnWords)
  ldy #512
  jsl MemClear7F

  ; Set defaults for horizontal levels
  lda #.loword(GetLevelPtrXY_Horizontal)
  sta GetLevelPtrXY_Ptr
  lda #.loword(GetBlockX_Horizontal)
  sta GetBlockX_Ptr
  lda #.loword(GetBlockY_Horizontal)
  sta GetBlockY_Ptr
  lda #.loword(GetBlockXCoord_Horizontal)
  sta GetBlockXCoord_Ptr
  lda #.loword(GetBlockYCoord_Horizontal)
  sta GetBlockYCoord_Ptr
  lda #32*2 ; 32 blocks tall
  sta LevelColumnSize
  dea
  sta LevelColumnMask

  lda #(15*16)*256 ; 15 screens of 16 tiles, each containing 256 subpixels
  sta ScrollXLimit
  lda #(16+2)*256  ; 1 screen of 16 tiles, each containing 256 subpixels. Add 2 tiles because (224 - 256) = 32 pixels.
  sta ScrollYLimit

  seta8
  ; ------------ Initialize variables ------------
  ; Clear a bunch of stuff in one go that's in contiguous space in memory
  ldx #LevelZeroWhenLoad_Start
  ldy #LevelZeroWhenLoad_End-LevelZeroWhenLoad_Start
  jsl MemClear

  ; Initialize settings that don't start at zero

  ; Health
  lda #4
  sta PlayerHealth

  ; Clear FirstActorOnScreen list too
  ldy #15
  lda #255
  sta PlayerFrameLast ; Force a load
: sta FirstActorOnScreen,y
  dey
  bpl :-

  ; Set the high byte of the level pointer
  ; so later accesses work correctly.
  lda #^LevelBuf
  sta LevelBlockPtr+2

  ; Initialize variables related to optimizations
  seta16
  stz framecount
  lda #ActorEnd
  sta ActorIterationLimit
  lda #ParticleEnd
  sta ParticleIterationLimit
  seta8

  ; -----------------------------------

  ; Parse the level header
  lda LevelHeaderPointer+0
  sta DecodePointer+0
  lda LevelHeaderPointer+1
  sta DecodePointer+1
  lda LevelHeaderPointer+2
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
  sta PlayerPY+1
  stz PlayerPY+0

  ; Vertical scrolling and layer 2 flags
  iny ; Y = 3
  lda [DecodePointer],y
  bpl :+
    ; (Is a vertical level)
    ; Swap starting X and Y positions
    lda PlayerPY+1
    pha
    lda PlayerPX+1
    sta PlayerPY+1
    pla
    sta PlayerPX+1

    seta16
    lda #.loword(GetLevelPtrXY_Vertical)
    sta GetLevelPtrXY_Ptr
    lda #.loword(GetBlockX_Vertical)
    sta GetBlockX_Ptr
    lda #.loword(GetBlockY_Vertical)
    sta GetBlockY_Ptr
    lda #.loword(GetBlockXCoord_Vertical)
    sta GetBlockXCoord_Ptr
    lda #.loword(GetBlockYCoord_Vertical)
    sta GetBlockYCoord_Ptr
    lda #256*2 ; 256 blocks tall
    sta LevelColumnSize
    dea
    sta LevelColumnMask

    lda #(15*16+2)*256 ; 15 screens of 16 tiles, each containing 256 subpixels. Add 2 tiles because (224 - 256) = 32 pixels.
    sta ScrollYLimit
    lda #16*256        ; 1 screen of 16 tiles, each containing 256 subpixels. 
    sta ScrollXLimit
    seta8

    ; In vertical levels, columns are 256 blocks tall, multiplied by 2 bytes
    stz LevelColumnSize+0
    lda #2
    sta LevelColumnSize+1

    dec VerticalLevelFlag ; Set it to 255
  :
  lda [DecodePointer],y
  and #$40
  beq :+
    dec VerticalScrollEnabled ; Set it to 255
  :
  lda [DecodePointer],y
  and #$20
  beq :+
    dec TwoLayerLevel
    stz FG2OffsetX
    stz FG2OffsetX+1
    stz FG2OffsetY
    stz FG2OffsetY+1
  :
  lda [DecodePointer],y
  and #$10
  beq :+
    dec TwoLayerInteraction
  :
  lda #>(BackgroundBG)
  sta SecondFGTilemapPointer+1
  stz SecondFGTilemapPointer+0
  lda [DecodePointer],y
  and #$08
  beq :+
    dec ForegroundLayerThree
    lda #>(ExtraBGWide)
    sta SecondFGTilemapPointer+1

    phx
    phy
    phb
    seta16
    lda #Block::BG3Empty
    sta f:LevelBufAlt
    ldx #.loword(LevelBufAlt)
    ldy #.loword(LevelBufAlt+2)
    lda #256*32*2-2
    mvn #^LevelBufAlt, #^LevelBufAlt 
    seta8
    plb
    ply
    plx
  :
  ; Flags $04, $02, $01 are free to use

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
  ; Background, one byte
  lda [DecodePointer],y
  sta LevelBackgroundId

  iny ; Y = 7
  ; Color math settings, one byte
  tdc ; Clear accumulator
  lda [DecodePointer],y
  sta LevelColorMathId
  tax
  .import ColorMathTableBGMODE
  lda f:ColorMathTableBGMODE,x
  sta LevelBGMode ; <--- Store default here, where it can be overridden later

  ; Actor data pointer
  iny ; Y = 8
  lda [DecodePointer],y
  sta LevelActorPointer+0
  iny ; Y = 9
  lda [DecodePointer],y
  sta LevelActorPointer+1
  lda DecodePointer+2
  sta LevelActorPointer+2
  iny ; Y = 10

.if 0
  ; Scroll barriers
  ; Convert from bit array to byte array for easier access
  lda #1
  sta ScreenFlags+0    ; first screen has left boundary
  sta ScreenFlagsDummy ; last screen has right boundary
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
.endif

  ; Sprite graphic slots
  ldx #0
: lda [DecodePointer],y
  iny
  sta SpriteTileSlots+0,x
  stz SpriteTileSlots+1,x
  inx
  inx
  cpx #8*2
  bne :-

  ; Background palettes
  ldx #0
: lda [DecodePointer],y
  sta BackgroundPaletteSlots,x
  inx
  iny
  cpx #8
  bne :-

  ; Graphical assets
  ldx #0
: lda [DecodePointer],y
  sta GraphicalAssets,x
  inx
  iny
  cmp #255
  bne :-

  ; Level data pointer
  lda [DecodePointer],y
  pha
  iny
  lda [DecodePointer],y
  sta DecodePointer+1
  pla
  sta DecodePointer+0

  ; -----------------------------------
  jsr IndexActorList

  ; Now use the new DecodePointer to decompress the level data
  phk
  plb
  stz DecodeColumn
  stz SecondLayer
  jsr LevelDecodeLoop

  ; Put the registers back in their expected sizes
  setaxy16
  rtl
.endproc

.a8
.i16
.proc IndexActorList
  setaxy8
  ldy #0
@Loop:
  lda [LevelActorPointer],y
  cmp #255 ; 255 marks the end of the list
  beq @Exit
  ; Get screen number
  lsr
  lsr
  lsr
  lsr
  tax
  ; Write actor number to the list, if the
  ; screen doesn't already have an actor set for it
  lda FirstActorOnScreen,x
  cmp #255
  bne :+
  seta16
  tya
  ; Divide by 4 to fit a bigger range into 255 bytes
  lsr
  lsr
  seta8
  sta FirstActorOnScreen,x
:
  ; Actors entries are four bytes long
  iny
  iny
  iny
  iny
  bra @Loop
@Exit:
  setxy16
  rts
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
SecondLayer  = 8
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
  .addr SpecialWrite1Byte
  .addr SpecialWrite2Byte
  .addr SpecialWriteNByte
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


; Helper routine
ColumnWriteIndex:
  seta16
  lda DecodeColumn
  and #255
  asl
  tax
  seta8
  rts
ColumnWriteOne:
  jsr NextLevelByte
  sta f:ColumnWords,x
  inx
  rts
SpecialWriteNByte:
  jsr ColumnWriteIndex
  jsr NextLevelByte
  sta 0
: jsr ColumnWriteOne
  dec 0
  bne :-
  rts
SpecialWrite2Byte:
  jsr ColumnWriteIndex
  jsr ColumnWriteOne
  jsr ColumnWriteOne
  rts
SpecialWrite1Byte:
  jsr ColumnWriteIndex
  jsr ColumnWriteOne
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
  ; Call additional table
  tdc
  jsr NextLevelByte
  asl
  tax
  jmp (.loword(SpecialConfigTable),x)

SpecialConfigTable:
  .addr UseAlternateBuffer
  .addr ActorListInRAM

.a8
UseAlternateBuffer:
  stz DecodeColumn
  dec SecondLayer ; Roll around to -1
  rts

.a8
ActorListInRAM:
  jsr NextLevelByte
  seta16
  ; Top byte still zero from the earlier TDC
  asl ; * 4
  asl
  ina ; the 255 on the end
  sta DMALEN
  lda #.loword(LevelActorBuffer)
  sta WMADDL
  lda #(<WMDATA << 8) | DMA_LINEAR | DMA_FORWARD
  sta DMAMODE

  lda LevelActorPointer
  sta DMAADDR
  seta8
  lda LevelActorPointer+2
  sta DMAADDRBANK
  stz WMADDH ; First bank

  lda #1
  sta COPYSTART

  lda #<LevelActorBuffer
  sta LevelActorPointer+0
  lda #>LevelActorBuffer
  sta LevelActorPointer+1
  lda #^LevelActorBuffer
  sta LevelActorPointer+2
  rts
.endproc

; .----------------------------------------------------------------------------
; | Level command templates
; '----------------------------------------------------------------------------

; Make sure to keep synchronized with the LO enum in leveldata.inc
; Maxes out at 120 commands? Last 8 correspond to special commands.
.proc LevelCommands
  ; Commands that place one or multiple blocks with the block specified with two bytes
  .word $ffff&CustomBlockSingle,    0
  .word $ffff&CustomBlockRectangle, 0

  ; Commands that place one or multiple blocks with the block specified with a byte
  .word $ffff&BlockByteReferenceSingle,    0
  .word $ffff&BlockByteReferenceSingle,    256
  .word $ffff&BlockByteReferenceRectangle, 0
  .word $ffff&BlockByteReferenceRectangle, 256

  ; Commands that place multiple blocks with the block specified with a nybble
  .word $ffff&BlockWideList,        32*0
  .word $ffff&BlockTallList,        32*0
  .word $ffff&BlockRectList,        32*0
  .word $ffff&BlockWideList,        32*1
  .word $ffff&BlockTallList,        32*1
  .word $ffff&BlockRectList,        32*1
  .word $ffff&BlockWideList,        32*2
  .word $ffff&BlockTallList,        32*2
  .word $ffff&BlockRectList,        32*2
  .word $ffff&BlockWideList,        32*3
  .word $ffff&BlockTallList,        32*3
  .word $ffff&BlockRectList,        32*3

  ; Commands that place a rectangle of a fixed type
  .word $ffff&BlockRectangle,       Block::Empty
  .word $ffff&BlockRectangle,       Block::Bricks
  .word $ffff&BlockRectangle,       Block::SolidBlock
  .word $ffff&BlockRectangle,       Block::Ice
  .word $ffff&BlockRectangle,       Block::LedgeMiddle
  .word $ffff&BlockRectangle,       Block::Stone
  .word $ffff&BlockRectangle,       Block::Sand

  ; Commands that place one block of a fixed type
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
  .word $ffff&BlockSingle,          Block::DoorTop
  .word $ffff&BlockSingle,          Block::SmallTreeTopLeft
  .word $ffff&BlockSingle,          Block::SmallTreeBushTopLeft

  ; Special slope commands
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
  .word Block::SolidBlock
  .word Block::LedgeSolidBottom
  .word Block::LedgeSolidLeft
  .word Block::LedgeSolidRight
  .word Block::FloatingPlatform
  .word Block::FloatingPlatformFallthrough
; Set 2
  .word Block::RopeLadder
  .word Block::Bridge
  .word Block::WoodPlatform
  .word Block::Pier
  .word Block::Fence
  .word Block::Stone
  .word Block::Sand
  .word Block::LeafCube
  .word Block::TreeLog
  .word Block::Grass
  .word Block::Vines
  .word Block::SmallTreeTrunk
  .word Block::RedFlower
  .word Block::BlueFlower
  .word Block::BlueFlowerSpiral
  .word Block::RedFlowerSpiral
; Set 3
  .word Block::BlueFlowerCircle
  .word Block::BranchPlatformMiddle
  .word Block::CeilingBarrier
  .word Block::LogPlatform
  .word Block::LogPlatformSupportLeft
  .word Block::LogPlatformSupportRight
  .word Block::WoodArrowRight
  .word Block::WoodArrowDown
  .word Block::WoodArrowLeft
  .word Block::WoodArrowUp
  .word Block::MetalArrowRight
  .word Block::MetalArrowDown
  .word Block::MetalArrowLeft
  .word Block::MetalArrowUp
  .word Block::WoodCrate
  .word Block::MetalCrate
; Set 4
  .word Block::MetalForkUp
  .word Block::MetalForkDown
  .word Block::ArrowRevealSolid
  .word Block::Water
  .word Block::WoodPlanks
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
.proc BlockByteReferenceSingle ; XY TT
  jsr XYLevelByte
  tdc ; Clear entire accumulator
  jsr NextLevelByte
  seta16
  ora LevelCommands+2,x
  asl
  tax
  lda f:BlockByteReferenceTable,x
  sta [LevelBlockPtr],y
  seta8
  rts
.endproc

.proc BlockByteReferenceRectangle ; XY TT WH
  jsr XYLevelByte
  tdc ; Clear entire accumulator
  jsr NextLevelByte
  seta16
  ora LevelCommands+2,x
  asl
  tax
  lda f:BlockByteReferenceTable,x
  sta DecodeValue
  seta8
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
  lda #Block::GradualSlopeL_U1
  sta [LevelBlockPtr],y
  iny
  iny
  lda #Block::GradualSlopeL_D1
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn

  ply
  lda #Block::GradualSlopeL_U2
  sta [LevelBlockPtr],y
  iny
  iny
  lda #Block::GradualSlopeL_D2
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn

  ply
  lda #Block::GradualSlopeL_U3
  sta [LevelBlockPtr],y
  inc DecodeHeight
  jsr SlopeDirtColumn

  ply
  lda #Block::GradualSlopeL_U4
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
  lda #Block::MedSlopeL_UL
  sta [LevelBlockPtr],y
  iny
  iny
  lda #Block::MedSlopeL_DL
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn
  ply
  lda #Block::MedSlopeL_UR
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
  lda #Block::SteepSlopeL_U
  sta [LevelBlockPtr],y
  iny
  iny
  lda #Block::SteepSlopeL_D
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
  lda #Block::GradualSlopeR_U1
  sta [LevelBlockPtr],y
  iny
  iny
  lda #Block::LedgeMiddle
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn

  ply
  lda #Block::GradualSlopeR_U2
  sta [LevelBlockPtr],y
  iny
  iny
  lda #Block::LedgeMiddle
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn

  ply
  lda #Block::GradualSlopeR_U3
  sta [LevelBlockPtr],y
  iny
  iny
  lda #Block::GradualSlopeR_D3
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn

  ply
  lda #Block::GradualSlopeR_U4
  sta [LevelBlockPtr],y
  iny
  iny
  lda #Block::GradualSlopeR_D4
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
  lda #Block::MedSlopeR_UL
  sta [LevelBlockPtr],y
  iny
  iny
  lda #Block::LedgeMiddle
  sta [LevelBlockPtr],y
  jsr SlopeDirtColumn
  ply
  lda #Block::MedSlopeR_UR
  sta [LevelBlockPtr],y
  iny
  iny
  lda #Block::MedSlopeR_DR
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
  lda #Block::SteepSlopeR_U
  sta [LevelBlockPtr],y
  iny
  iny
  phy
  lda #Block::SteepSlopeR_D
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
  and #255
  ; jsl GetLevelColumnPtr
  xba ; * 256
  asl ; * 512
  sta LevelBlockPtr

  ; Y is the current row times two
  lda DecodeColumn
  and #255
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

  ; 16-bit read, we really want the sign bit on SecondLayer here
  bit SecondLayer-1
  bpl :+
    lda #$4000			; OR it with 16KB
    tsb LevelBlockPtr
  :

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
.if 0
  ; Smaller version that doesn't actually fill the column,
  ; for some tests with overlapping slopes
  iny
  iny
  lda [LevelBlockPtr],y
  bne :+
    lda #Block::LedgeMiddle
    sta [LevelBlockPtr],y
  :
  lda LevelBlockPtr
  add LevelColumnSize
  sta LevelBlockPtr
  rts
.endif

  phx
  iny
  iny

  ; Use X as a counter
  lda DecodeHeight
  and #255
  ina
  tax

  ; Fill in dirt
  lda #Block::LedgeMiddle
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
