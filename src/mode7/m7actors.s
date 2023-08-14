; Super Princess Engine
; Copyright (C) 2020-2023 NovaSquirrel
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
.include "../snes.inc"
.include "../global.inc"
.include "m7blockenum.s"
.include "m7global.s"
.smart
.import M7BlockTopLeft, M7BlockTopRight, M7BlockBottomLeft, M7BlockBottomRight, M7BlockFlags
.import Mode7LevelPtrXY, Mode7Tiles

.segment "C_Mode7Game"
ActorM7DynamicSlot = ActorIndexInLevel ; Reuse this
ActorM7LastDrawX = ActorState    ; and ActorOnGround
ActorM7LastDrawY = ActorOnScreen ; and ActorDamage

NUM_M7_ACTORS = 8

; Last tile number where there there is a version of the sprite in SoftwareSprites with that tile number underneath it
LastTileNumberWithPrerenderedSprite = 2
NumberOfSoftSprites = 7

; Finds a dynamic sprite slot and allocates it
; A = Index into Mode7DynamicTileBuffer to use
; Carry = success
.a16
.i16
.proc Mode7AllocateDynamicSlot
  phx
  seta8
  ; Look for a slot
  ldx #7
: lda Mode7DynamicTileUsed,x
  beq Found
  dex
  bpl :-
  seta16
  plx
  clc
  rts
Found:
  inc Mode7DynamicTileUsed,x
  seta16
  txa
  plx
  sec
  rts
.endproc

; Find a free block update slot
; Y = The slot it found
; Carry = Success
.proc Mode7FindFreeTilemapUpdateSlot
  php
  seta8
  ; Find a free index in the block update queue
  ldy #(BLOCK_UPDATE_COUNT-1)*2 ; Currently BLOCK_UPDATE_COUNT = 8
FindIndex:
  lda BlockUpdateDataTL+1,y ; Test for zero
  beq Found
  dey                      ; Next index
  dey
  bpl FindIndex
  bra Fail                 ; Give up if all slots full
Found:
  plp
  sec
  rts
Fail:
  plp
  clc
  rts
.endproc

.a16
.i16
; A = Actor to create
; X = X coordinate, pixels
; Y = Y coordinate, pixels
; Output: X is the slot used
; Output: Carry, if creation was successful
.export Mode7CreateActor
.proc Mode7CreateActor
TypeToMake = 0
XPos = 2
YPos = 4
  sta TypeToMake
  stx XPos
  sty YPos

  jsl FindFreeActorX
  bcc Fail
  jsr Mode7AllocateDynamicSlot
  bcc Fail
Success:
  sta ActorM7DynamicSlot,x
  lda TypeToMake
  sta ActorType,x
  lda XPos
  and #$fff0
  sta ActorPX,x
  sta ActorM7LastDrawX,x
  lda YPos
  and #$fff0
  sta ActorPY,x
  sta ActorM7LastDrawY,x

  ; Update the tilemap under the sprite
  lda ActorPX,x
  ldy ActorPY,x
  jsr Mode7LevelPtrXY

  jsr Mode7FindFreeTilemapUpdateSlot
  bcc NoTilemapUpdate
    jsr Mode7TilemapAddressForPosition
    phy
    jsr DoRenderAligned
    ply
    seta8
    jsr Mode7GetDynamicTileNumber
    sta BlockUpdateDataTL,y 
    ina
    sta BlockUpdateDataBL,y
    ina
    sta BlockUpdateDataTR,y
    ina
    sta BlockUpdateDataBR,y

    lda #1 ; Square
    sta BlockUpdateDataTL+1,y
    seta16
  NoTilemapUpdate:
  ; Report success even if the tilemap update didn't work
  sec
  rts
Fail:
  ; Carry is clear
  rts
.endproc

; Removes an actor and becomes a block instead
; A = block type to become
.a16
.i16
.proc Mode7ActorBecomeBlock
  pha ; Save the block type to become

  ; Get block address
  lda ActorPX,x
  ldy ActorPY,x
  jsr Mode7LevelPtrXY
  lda LevelBlockPtr
  pha

  jsr Mode7RemoveActor ; Un-draws the actor, which changes LevelBlockPtr

  pla
  sta LevelBlockPtr
  pla ; Block to become
  .import Mode7PutBlockAbove
  jmp Mode7PutBlockAbove
.endproc

.a16
.i16
.proc Mode7RemoveActor
  stz ActorType,x

  ; Erase the last place the sprite was drawn at
  lda ActorM7LastDrawY,x
  sta ActorPY,x
  tay
  lda ActorM7LastDrawX,x
  sta ActorPX,x
  jsr Mode7LevelPtrXY

  jsr Mode7FindFreeTilemapUpdateSlot
  jcc NoTilemapUpdate
    jsr Mode7TilemapAddressForPosition
    ; Determine the alignment to level tiles
    lda ActorPX,x
    and #$0008
    bne Horizontal
    lda ActorPY,x
    and #$0008
    beq Aligned
  Vertical:
    tdc
    seta8
    phx
    lda [LevelBlockPtr]
    tax
    lda M7BlockBottomLeft,x
    sta BlockUpdateDataTL,y
    lda M7BlockBottomRight,x
    sta BlockUpdateDataTR,y
    lda LevelBlockPtr
    add #64
    sta LevelBlockPtr
    addcarry LevelBlockPtr+1
    lda [LevelBlockPtr]
    tax
    lda M7BlockTopLeft,x
    sta BlockUpdateDataBL,y
    lda M7BlockTopRight,x
    sta BlockUpdateDataBR,y
    bra Finish
  Horizontal:
    tdc
    seta8
    phx
    lda [LevelBlockPtr]
    tax
    lda M7BlockTopRight,x
    sta BlockUpdateDataTL,y
    lda M7BlockBottomRight,x
    sta BlockUpdateDataBL,y
    inc LevelBlockPtr
    lda [LevelBlockPtr]
    tax
    lda M7BlockTopLeft,x
    sta BlockUpdateDataTR,y
    lda M7BlockBottomLeft,x
    sta BlockUpdateDataBR,y
    bra Finish
  Aligned:
    tdc
    seta8
    phx
    lda [LevelBlockPtr]
    tax
    lda M7BlockTopLeft,x
    sta BlockUpdateDataTL,y
    lda M7BlockTopRight,x
    sta BlockUpdateDataTR,y
    lda M7BlockBottomLeft,x
    sta BlockUpdateDataBL,y
    lda M7BlockBottomRight,x
    sta BlockUpdateDataBR,y
  Finish:
    .a8
    lda #1 ; Square
    sta BlockUpdateDataTL+1,y
    plx
    seta16
  NoTilemapUpdate:

  lda ActorM7DynamicSlot,x
  fallthrough Mode7FreeDynamicSlot
.endproc

; Frees the slot index in A
.a16
.i16
.proc Mode7FreeDynamicSlot
  phx
  and #255
  tax
  seta8
  stz Mode7DynamicTileUsed,x
  seta16
  plx
  rts
.endproc

.a16
.i16
.export Mode7RunActors
.proc Mode7RunActors
  ldx #ActorStart
Loop:
  lda ActorType,x
  beq :+
    jsr Call
  :
  txa
  add #ActorSize
  tax
  cpx #ActorStart+ActorSize*NUM_M7_ACTORS
  bne Loop
  rts
Call:
  tay
  ; Call the routine now
  lda Mode7ActorTable,y
  pha
  rts
.endproc

Mode7ActorTable:
  .raddr 0
  .raddr M7FlyingArrowUp
  .raddr M7FlyingArrowLeft
  .raddr M7FlyingArrowDown
  .raddr M7FlyingArrowRight
  .raddr M7PinkBall
  .raddr M7PushBlock
  .raddr M7SlidingBlock
  .raddr M7Burger

Mode7ActorGraphic:
  .word 0
  .word .loword(SoftwareSprites+(64*4*0)) ; Flying up 
  .word .loword(SoftwareSprites+(64*4*1)) ; Flying left
  .word .loword(SoftwareSprites+(64*4*2)) ; Flying down
  .word .loword(SoftwareSprites+(64*4*3)) ; Flying right
  .word .loword(SoftwareSprites+(64*4*4)) ; Pink ball
  .word .loword(SoftwareSprites+(64*4*5)) ; Push block
  .word .loword(SoftwareSprites+(64*4*5)) ; Sliding block
  .word .loword(SoftwareSprites+(64*4*6)) ; Burger

; Get the index into the dynamic tile buffer
.a16
.proc Mode7GetDynamicBuffer
  ; Multiply by 256
  lda ActorM7DynamicSlot,x
  xba
  rts
.endproc

.a8
.i16
.proc Mode7GetDynamicTileNumber
  lda ActorM7DynamicSlot,x
  ; Add number*4
  asl
  asl
  ; assert((PS & 1) == 0) Carry will be clear
  adc #$e0
  rts
.endproc

.proc M7FlyingArrowUp
  dec ActorPY,x
  dec ActorPY,x
  bra M7FlyingArrowCommon
.endproc
.proc M7FlyingArrowLeft
  dec ActorPX,x
  dec ActorPX,x
  bra M7FlyingArrowCommon
.endproc
.proc M7FlyingArrowDown
  inc ActorPY,x
  inc ActorPY,x
  bra M7FlyingArrowCommon
.endproc
.proc M7FlyingArrowRight
  inc ActorPX,x
  inc ActorPX,x
.endproc
.a16
.proc M7FlyingArrowCommon
  ; Be removed by running out of time
  dec ActorTimer,x
  bne :+
    jmp Mode7RemoveActor    
  :

  lda ActorPX,x
  ora ActorPY,x
  and #15
  bne NotAligned

  lda ActorPX,x
  ldy ActorPY,x
  jsr Mode7LevelPtrXY
  cmp #Mode7Block::Bomb
  beq RemoveCrate
;  cmp #Mode7Block::Dirt
;  beq RemoveCrate
  cmp #Mode7Block::MetalCrate
  beq RemoveCrate
  cmp #Mode7Block::WoodArrowUp
  bcc NotCrate
  cmp #Mode7Block::MetalArrowForkRight+1
  bcs NotCrate
    ; Doesn't support fork arrows yet but that's fine
    sub #Mode7Block::WoodArrowUp
    and #3
    asl
    add #1*2 ; Mode7ActorType::ArrowUp
    sta ActorType,x

    .import CheckerForPtr
    jsr CheckerForPtr
    seta8
    sta [LevelBlockPtr]
    seta16
    ; Refresh the actor timer
    lda #90
    sta ActorTimer,x
  NotCrate:
NotAligned:
  jmp Mode7UpdateActorPicture

RemoveCrate:
  phx
  .import Mode7EraseBlock
  jsr Mode7EraseBlock
  plx
  jmp Mode7RemoveActor    
.endproc

.a16
.proc M7PushBlock
  lda ActorDirection,x
  and #3
  asl
  tay

  lda ActorPX,x
  add OffsetX,y
  sta ActorPX,x

  lda ActorPY,x
  add OffsetY,y
  sta ActorPY,x

  ; Has it arrived on a grid square?
  lda ActorPX,x
  ora ActorPY,x
  and #15
  bne NotOnGrid
    ; Calculates it again in BecomeBlock, probably fine though
    lda ActorPX,x
    ldy ActorPY,x
    jsr Mode7LevelPtrXY
    cmp #Mode7Block::Water
    bne :+
      lda #Mode7Block::Empty
      jmp Mode7ActorBecomeBlock
    :
    lda #Mode7Block::PushableBlock
    jmp Mode7ActorBecomeBlock
  NotOnGrid:

  jmp Mode7UpdateActorPicture
OffsetX:
  .word 0, .loword(-4), 0, .loword(4)
OffsetY:
  .word .loword(-4), 0, .loword(4), 0
.endproc

.a16
.proc M7SlidingBlock
  ; Has it arrived on a grid square?
  lda ActorPX,x
  ora ActorPY,x
  and #15
  bne NotOnGrid
    ; Calculates it again in BecomeBlock, probably fine though
    lda ActorPX,x
    ldy ActorPY,x
    jsr Mode7LevelPtrXY

    lda ActorDirection,x
    and #3
    asl
    tay

    lda LevelBlockPtr
    .import ForwardPtrTile
    add ForwardPtrTile,y
    sta LevelBlockPtr

    lda [LevelBlockPtr]
    and #255
    tay
    lda M7BlockFlags,y
    bit #M7_BLOCK_SOLID_BLOCK
    beq :+
      lda #Mode7Block::PushableBlock
      jmp Mode7ActorBecomeBlock
    :
  NotOnGrid:

  lda ActorDirection,x
  and #3
  asl
  tay

  lda ActorPX,x
  add M7PushBlock::OffsetX,y
  sta ActorPX,x

  lda ActorPY,x
  add M7PushBlock::OffsetY,y
  sta ActorPY,x

  jmp Mode7UpdateActorPicture
.endproc

.a16
.proc M7PinkBall
  rts
.endproc

.a16
.proc M7Burger
  rts
.endproc

.a16
.proc Mode7TilemapAddressForPosition
  lda ActorPX,x
  and #$3f8 ; %000000xx xxxxx000
  lsr       ; %0000000x xxxxxx00
  lsr       ; %00000000 xxxxxxx0
  lsr       ; %00000000 0xxxxxxx
  sta 0
  lda ActorPY,x
  and #$3f8 ; %000000yy yyyyy000
  asl       ; %00000yyy yyyy0000
  asl       ; %0000yyyy yyy00000
  asl       ; %000yyyyy yy000000
  asl       ; %00yyyyyy y0000000
  ora 0     ; %00yyyyyy yxxxxxxx
  sta BlockUpdateAddress,y
  rts
.endproc

.a16
.i16
.proc Mode7UpdateActorPicture
TALL = 2
WIDE = 3

  jsr Mode7FindFreeTilemapUpdateSlot
  bcs :+ ; Return early if failed to find a slot
    rts
  :
  ; Y = tilemap update slot
  jsr Mode7TilemapAddressForPosition

  lda ActorPX,x
  ora ActorPY,x
  and #$0007
  bne :+
    jsr AlignedToGrid
    lda ActorPX,x
    sta ActorM7LastDrawX,x
    lda ActorPY,x
    sta ActorM7LastDrawY,x
  :
  rts

.a16
AlignedToGrid:
  phy
  lda ActorPX,x
  ldy ActorPY,x
  jsr Mode7LevelPtrXY

  lda LevelBlockPtr ; Preserve LevelBlockPtr because RenderAligned can overwrite it
  pha
  jsr RenderAligned
  pla
  sta LevelBlockPtr
  ply 

  lda ActorPX,x
  cmp ActorM7LastDrawX,x
  jeq @MovedVertically
  bcs @MovedRight
@MovedLeft:
  ; ##F
  ; ##F
  seta8
  tdc ; For TAX/TAY
  jsr Mode7GetDynamicTileNumber
  sta BlockUpdateDataTL,y 
  ina
  sta BlockUpdateDataBL,y
  ina
  sta BlockUpdateDataTR,y
  ina
  sta BlockUpdateDataBR,y

  phx
  inc LevelBlockPtr
  lda ActorPX,x
  and #8
  beq @MoveLeftFixRight
@MoveLeftFixLeft:
  lda [LevelBlockPtr]
  tax
  lda M7BlockTopRight,x
  sta BlockUpdateDataBL+1,y
  lda M7BlockBottomRight,x
  sta BlockUpdateDataBR+1,y
  bra @MoveLeftFixedLeft
@MoveLeftFixRight:
  lda [LevelBlockPtr]
  tax
  lda M7BlockTopLeft,x
  sta BlockUpdateDataBL+1,y
  lda M7BlockBottomLeft,x
  sta BlockUpdateDataBR+1,y
@MoveLeftFixedLeft:
  plx

  lda #WIDE
  sta BlockUpdateDataTL+1,y
  seta16
  rts
@MovedRight:
  ; F##
  ; F##
  seta8
  tdc ; For TAX/TAY
  lda BlockUpdateAddress,y
  dea
  sta BlockUpdateAddress,y

  jsr Mode7GetDynamicTileNumber
  sta BlockUpdateDataTR,y
  ina
  sta BlockUpdateDataBR,y
  ina
  sta BlockUpdateDataBL+1,y
  ina
  sta BlockUpdateDataBR+1,y

  phx
  lda ActorPX,x
  and #8
  bne @MoveRightFixRight
@MoveRightFixLeft:
  dec LevelBlockPtr
  lda [LevelBlockPtr]
  tax
  lda M7BlockTopRight,x
  sta BlockUpdateDataTL,y
  lda M7BlockBottomRight,x
  sta BlockUpdateDataBL,y
  bra @MoveRightFixedLeft
@MoveRightFixRight:
  lda [LevelBlockPtr]
  tax
  lda M7BlockTopLeft,x
  sta BlockUpdateDataTL,y
  lda M7BlockBottomLeft,x
  sta BlockUpdateDataBL,y
@MoveRightFixedLeft:
  plx

  lda #WIDE
  sta BlockUpdateDataTL+1,y
  seta16
  rts

@MovedVertically:
  lda ActorPY,x
  cmp ActorM7LastDrawY,x
  bcs @MovedDown
@MovedUp:
  ; ##
  ; ##
  ; FF
  seta8
  tdc ; For TAX/TAY
  jsr Mode7GetDynamicTileNumber
  sta BlockUpdateDataTL,y
  ina
  sta BlockUpdateDataBL,y
  ina
  sta BlockUpdateDataTR,y
  ina
  sta BlockUpdateDataBR,y

  phx
  lda LevelBlockPtr
  add #64
  sta LevelBlockPtr
  addcarry LevelBlockPtr+1
  lda ActorPY,x
  and #8
  beq @MoveUpFixBottom
@MoveUpFixTop:
  lda [LevelBlockPtr]
  tax
  lda M7BlockBottomLeft,x
  sta BlockUpdateDataBL+1,y
  lda M7BlockBottomRight,x
  sta BlockUpdateDataBR+1,y
  bra @MoveUpFixedTop
@MoveUpFixBottom:
  lda [LevelBlockPtr]
  tax
  lda M7BlockTopLeft,x
  sta BlockUpdateDataBL+1,y
  lda M7BlockTopRight,x
  sta BlockUpdateDataBR+1,y
@MoveUpFixedTop:
  plx

  lda #TALL
  sta BlockUpdateDataTL+1,y
  seta16
  rts
@MovedDown:
  ; FF
  ; ##
  ; ##
  .a16
  lda BlockUpdateAddress,y
  sub #128
  sta BlockUpdateAddress,y
  seta8
  tdc ; For TAX/TAY

  jsr Mode7GetDynamicTileNumber
  sta BlockUpdateDataBL,y
  ina
  sta BlockUpdateDataBL+1,y
  ina
  sta BlockUpdateDataBR,y
  ina
  sta BlockUpdateDataBR+1,y

  phx
  lda ActorPY,x
  and #8
  bne @MoveDownFixBottom
@MoveDownFixTop:
  lda LevelBlockPtr
  sub #64
  sta LevelBlockPtr
  subcarry LevelBlockPtr+1

  lda [LevelBlockPtr]
  tax
  lda M7BlockBottomLeft,x
  sta BlockUpdateDataTL,y
  lda M7BlockBottomRight,x
  sta BlockUpdateDataTR,y
  bra @MoveDownFixedTop
@MoveDownFixBottom:
  lda [LevelBlockPtr]
  tax
  lda M7BlockTopLeft,x
  sta BlockUpdateDataTL,y
  lda M7BlockTopRight,x
  sta BlockUpdateDataTR,y
@MoveDownFixedTop:
  plx

  lda #TALL
  sta BlockUpdateDataTL+1,y
  seta16
  rts

; -------------------------------------
; Render the actor on top of the tile it's on top of
.a16

.macro RenderOrCopyPrerenderedTile TileNumber
  .local Loop
  .local SkipLoop

  .a8
  lda TileNumber
  cmp #LastTileNumberWithPrerenderedSprite+1
  bcs :+
    setaxy16
    phb
    phx
    phy

    stx 0 ; X = Destination index
    and #255
	asl ; Carry is guaranteed clear after this
	tax
    tya
    adc SpritePointer
    ; Use this lookup table to figure out what offset is needed to put the desired tile underneath the sprite tile
	adc f:OffsetForPrerenderedSprites,x
    tax ; X = Source pointer: Source index + base for desired sprite + offset to the part of the sprite sheet with desired tile underneath

    lda 0 ; Destination index
    add #.loword(Mode7DynamicTileBuffer)
    tay ; Y = Destination pointer: Destination index + base

    lda #64-1
    mvn SoftwareSprites, Mode7DynamicTileBuffer
    pla
    add #64
    tay
    pla
    add #64
    tax
    plb
    seta8
    bra SkipLoop
  :

  lda #64
  sta Bytes
Loop:
  lda (SpritePointer),y
  beq :+
    sta f:Mode7DynamicTileBuffer,x
  :
  iny
  inx
  dec Bytes
  bne Loop
SkipLoop:
.endmacro

RenderAligned:
UnderTileUL = 4
UnderTileUR = 6
UnderTileBL = 8
UnderTileBR = 10
SpritePointer = 12
  jsr LoadUpTileNumbersUnderActor

  ; Do this before X gets reused for other stuff: 
  lda ActorType,x ; Multiply by 256 for four 64-byte tiles (but it's already pre-multiplied by 2, so fix that)
  tay
  lda Mode7ActorGraphic,y
  sta SpritePointer

  jsr CopyOverFourTileGfx
  phx
  phy
  tax
  .scope
    Bytes = 2

    ph2banks SoftwareSprites, RenderAligned
    plb

    ldy #0 ; Index for SpritePointer
    seta8

    RenderOrCopyPrerenderedTile UnderTileUL
    RenderOrCopyPrerenderedTile UnderTileBL
    RenderOrCopyPrerenderedTile UnderTileUR
    RenderOrCopyPrerenderedTile UnderTileBR

    plb
  .endscope

  seta16
  ply
  plx
  rts

; Offset to add in order to put different background tiles underneath the sprite tiles
OffsetForPrerenderedSprites:
  .addr 0, NumberOfSoftSprites*256*1, NumberOfSoftSprites*256*2

.a16
LoadUpTileNumbersUnderActor:
  lda ActorPX,x
  and #$0008
  jne LoadUpTileNumbersRight ; Software sprites are aligned to at least one axis right now
@Left:
  lda ActorPY,x
  and #$0008
  bne LoadUpTileNumbersDown

LoadUpTileNumbersAligned:
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockTopLeft,y
  and #255
  sta UnderTileUL
  lda M7BlockTopRight,y
  and #255
  sta UnderTileUR
  lda M7BlockBottomLeft,y
  and #255
  sta UnderTileBL
  lda M7BlockBottomRight,y
  and #255
  sta UnderTileBR
  rts

LoadUpTileNumbersDown:
  lda [LevelBlockPtr]
  and #255
  tay

  lda M7BlockBottomLeft,y
  and #255
  sta UnderTileUL
  lda M7BlockBottomRight,y
  and #255
  sta UnderTileUR

  ; Down one row
  lda LevelBlockPtr
  add #64
  sta LevelBlockPtr
  lda [LevelBlockPtr]
  and #255
  tay

  lda M7BlockTopLeft,y
  and #255
  sta UnderTileBL
  lda M7BlockTopRight,y
  and #255
  sta UnderTileBR
  rts

LoadUpTileNumbersRight:
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockTopRight,y
  and #255
  sta UnderTileUL
  lda M7BlockBottomRight,y
  and #255
  sta UnderTileBL

  ; Across one column
  inc LevelBlockPtr
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockTopLeft,y
  and #255
  sta UnderTileUR
  lda M7BlockBottomLeft,y
  and #255
  sta UnderTileBR
  rts

.if 0
LoadUpTileNumbersBoth:
  ; The worst case, needs to change the block pointer four times
  ; This isn't ready for use yet though since I'd need to clean up diagonally in addition to the four directions
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockTopLeft,y
  and #255
  sta UnderTileUL

  inc LevelBlockPtr
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockTopRight,y
  and #255
  sta UnderTileUR

  lda LevelBlockPtr
  add #64-1
  sta LevelBlockPtr
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockBottomLeft,y
  and #255
  sta UnderTileBL

  inc LevelBlockPtr
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockBottomRight,y
  and #255
  sta UnderTileBR
  rts
.endif

; Copies the tiles at UnderTileUL, UnderTileUR, UnderTileBL and UnderTileBR in order
.macro CopyOverOneTileGfx TileNumber
  lda TileNumber
  cmp #LastTileNumberWithPrerenderedSprite+1
  bcs :+
    ; Skip if the sprite tile will be MVN'd in instead
    tya
    adc #64 ; BCS not being taken means carry is clear
    tay
    bra :++
  :
  xba
  lsr
  lsr
  add #.loword(Mode7Tiles)
  tax
  lda #64-1
  mvn Mode7Tiles, Mode7DynamicTileBuffer
  :
.endmacro

.a16
CopyOverFourTileGfx:
  jsr Mode7GetDynamicBuffer
  pha
  phx
  phb ; MVN overwrites the data bank
  add #.loword(Mode7DynamicTileBuffer)
  tay

  CopyOverOneTileGfx UnderTileUL
  CopyOverOneTileGfx UnderTileBL
  CopyOverOneTileGfx UnderTileUR
  CopyOverOneTileGfx UnderTileBR

  plb
  plx
  pla ; A = Mode7GetDynamicBuffer's result still
  rts
.endproc
DoRenderAligned = Mode7UpdateActorPicture::RenderAligned

.pushseg
.segment "Mode7SoftwareSprites"
SoftwareSprites:
  .incbin "tilesetsX/M7SoftSprites.chr"
.popseg
