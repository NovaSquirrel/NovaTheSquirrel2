; Super Princess Engine
; Copyright (C) 2020 NovaSquirrel
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
.include "m7blockenum.s"
.smart
.import M7BlockTopLeft, M7BlockTopRight, M7BlockBottomLeft, M7BlockBottomRight, M7BlockFlags
.import Mode7LevelMap, Mode7LevelMapBelow, Mode7DynamicTileBuffer, Mode7DynamicTileUsed
.import Mode7BlockAddress, Mode7Tiles

.segment "Mode7Game"
ActorM7DynamicSlot = ActorIndexInLevel ; Reuse this
ActorM7LastDrawX = ActorState    ; and ActorOnGround
ActorM7LastDrawY = ActorOnScreen ; and ActorDamage

NUM_M7_ACTORS = 8

; Finds a dynamic sprite slot and allocates it
; A = Index into Mode7DynamicTileBuffer to use
; Carry = success
.a16
.i16
.proc Mode7AllocateDynamicSlot
  phx
  seta8
  ; Look for a slot
  ldx #6
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
  sta 0
  stx 2
  sty 4

  jsl FindFreeActorX
  bcc Fail
  jsr Mode7AllocateDynamicSlot
  bcc Fail
Success:
  sta ActorM7DynamicSlot,x
  lda 0
  sta ActorType,x
  lda 2
  and #$fff0
  sta ActorPX,x
  sta ActorM7LastDrawX,x
  lda 4
  and #$fff0
  sta ActorPY,x
  sta ActorM7LastDrawY,x

  ; Update the tilemap under the sprite
  lda ActorPX,x
  ldy ActorPY,x
  jsr Mode7BlockAddress

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
  pha

  ; Get block address
  lda ActorPX,x
  ldy ActorPY,x
  jsr Mode7BlockAddress
  lda LevelBlockPtr
  pha

  jsr Mode7RemoveActor

  pla
  sta LevelBlockPtr
  pla
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
  jsr Mode7BlockAddress

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
.endproc
; Inline tail call to Mode7FreeDynamicSlot

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
  .raddr M7FlyingArrow
  .raddr M7FlyingArrow
  .raddr M7FlyingArrow
  .raddr M7FlyingArrow
  .raddr M7PinkBall
  .raddr M7PushBlock
  .raddr M7Burger

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
  adc #$e4
  rts
.endproc

.a16
.proc M7FlyingArrow
  inc ActorPX,x

;  lda ActorPX,x
;  cmp #7*16
;  bne DontDie
;    jmp Mode7RemoveActor
;  DontDie:

  jsr Mode7UpdateActorPicture
  rts
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
  bne :+
    lda #Mode7Block::PushableBlock
    jmp Mode7ActorBecomeBlock
  :

  jmp Mode7UpdateActorPicture
OffsetX:
  .word 0, .loword(-4), 0, .loword(4)
OffsetY:
  .word .loword(-4), 0, .loword(4), 0
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
  jsr Mode7BlockAddress

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
RenderAligned:
UnderTileUL = 4
UnderTileUR = 6
UnderTileBL = 8
UnderTileBR = 10
SpritePointer = 12
  jsr LoadUpTileNumbersUnderActor

  ; Do this before X gets reused for other stuff: 
  lda ActorType,x ; Multiply by 256 for four 64-byte tiles (but it's already pre-multiplied by 2, so fix that)
  xba
  lsr
  ; assert((PS & 1) == 0) Carry will be clear
  adc #.loword(SoftwareSprites-64*4) ; So the first non-empty type uses the first sprite
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
    stz Bytes
  @Loop:
    lda (SpritePointer),y
    beq :+
      sta f:Mode7DynamicTileBuffer,x
    :
    iny
    inx
    inc Bytes
    bne @Loop
    plb
  .endscope

  seta16
  ply
  plx
  rts

  .macro PointerForM7TileNumber
    and #255
    xba
    lsr
    lsr
    add #.loword(Mode7Tiles)
  .endmacro

.a16
LoadUpTileNumbersUnderActor:
  lda ActorPX,x
  and #$0008
  jne LoadUpTileNumbersRight ; Software sprites are aligned to at least one axis right now
@Left:
  lda ActorPY,x
  and #$0008
  beq LoadUpTileNumbersAligned
  bra LoadUpTileNumbersDown
;@Right:
;  lda ActorPY,x
;  and #$0008
;  jeq LoadUpTileNumbersRight
;  jmp LoadUpTileNumbersBoth

LoadUpTileNumbersAligned:
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockTopLeft,y
  PointerForM7TileNumber
  sta UnderTileUL
  lda M7BlockTopRight,y
  PointerForM7TileNumber
  sta UnderTileUR
  lda M7BlockBottomLeft,y
  PointerForM7TileNumber
  sta UnderTileBL
  lda M7BlockBottomRight,y
  PointerForM7TileNumber
  sta UnderTileBR
  rts

LoadUpTileNumbersDown:
  lda [LevelBlockPtr]
  and #255
  tay

  lda M7BlockBottomLeft,y
  PointerForM7TileNumber
  sta UnderTileUL
  lda M7BlockBottomRight,y
  PointerForM7TileNumber
  sta UnderTileUR

  lda LevelBlockPtr
  add #64
  sta LevelBlockPtr
  lda [LevelBlockPtr]
  and #255
  tay

  lda M7BlockTopLeft,y
  PointerForM7TileNumber
  sta UnderTileBL
  lda M7BlockTopRight,y
  PointerForM7TileNumber
  sta UnderTileBR
  rts

LoadUpTileNumbersRight:
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockTopRight,y
  PointerForM7TileNumber
  sta UnderTileUL
  lda M7BlockBottomRight,y
  PointerForM7TileNumber
  sta UnderTileBL

  inc LevelBlockPtr
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockTopLeft,y
  PointerForM7TileNumber
  sta UnderTileUR
  lda M7BlockBottomLeft,y
  PointerForM7TileNumber
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
  PointerForM7TileNumber
  sta UnderTileUL

  inc LevelBlockPtr
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockTopRight,y
  PointerForM7TileNumber
  sta UnderTileUR

  lda LevelBlockPtr
  add #64-1
  sta LevelBlockPtr
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockBottomLeft,y
  PointerForM7TileNumber
  sta UnderTileBL

  inc LevelBlockPtr
  lda [LevelBlockPtr]
  and #255
  tay
  ;---
  lda M7BlockBottomRight,y
  PointerForM7TileNumber
  sta UnderTileBR
  rts
.endif

; Copies the tiles at UnderTileUL, UnderTileUR, UnderTileBL and UnderTileBR in order
.a16
CopyOverFourTileGfx:
  jsr Mode7GetDynamicBuffer
  pha
  phx
  phb ; MVN overwrites the data bank
  add #.loword(Mode7DynamicTileBuffer)
  tay
  ldx UnderTileUL
  lda #64-1
  .byt $54, ^Mode7DynamicTileBuffer, ^Mode7Tiles ;<--- this is MVN
  ldx UnderTileBL
  lda #64-1
  .byt $54, ^Mode7DynamicTileBuffer, ^Mode7Tiles
  ldx UnderTileUR
  lda #64-1
  .byt $54, ^Mode7DynamicTileBuffer, ^Mode7Tiles
  ldx UnderTileBR
  lda #64-1
  .byt $54, ^Mode7DynamicTileBuffer, ^Mode7Tiles
  plb
  plx
  pla ; A = Mode7GetDynamicBuffer's result still
  rts
.endproc
DoRenderAligned = Mode7UpdateActorPicture::RenderAligned

.pushseg
.segment "Mode7SoftwareSprites"
SoftwareSprites:
  .incbin "tools/M7SoftSprites.chrm7"
.popseg
