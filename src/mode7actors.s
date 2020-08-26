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

; Reuse these
ActorOldXPos = FG2OffsetX
ActorOldYPos = FG2OffsetY

.segment "Mode7Game"
ActorM7DynamicSlot = ActorIndexInLevel ; Reuse this
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
  ldx #4
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
  lda 4
  and #$fff0
  sta ActorPY,x
  sec
  rts
Fail:
  rts
.endproc

.a16
.i16
.proc Mode7RemoveActor
  stz ActorType,x
  lda ActorM7DynamicSlot,x
.endproc
; Inline tail call to Mode7FreeDynamicSlot

; Frees the slot index in A
.a16
.i16
.proc Mode7FreeDynamicSlot
  and #255
  tax
  seta8
  stz Mode7DynamicTileUsed,x
  seta16
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
  ; Save the original position of the actor
  lda ActorPX,x
  sta ActorOldXPos
  lda ActorPY,x
  sta ActorOldYPos
  ; Call the routine now
  lda Mode7ActorTable,y
  pha
  rts
.endproc

Mode7ActorTable:
  .raddr 0
  .raddr M7FlyingArrow

; Get the index into the dynamic tile buffer
.a16
.proc Mode7GetDynamicBuffer
  ; Multiply by 256+128
  lda ActorM7DynamicSlot,x
  xba
  lsr
  sta 0
  lda ActorM7DynamicSlot,x
  xba
  add 0
  rts
.endproc

.a8
.i16
.proc Mode7GetDynamicTileNumber
  ; Multiply by 6
  lda ActorM7DynamicSlot,x
  ; Add number*4 + number*2
  asl
  sta 0
  asl
  add 0
  add #$e2
  rts
.endproc

.a16
.proc M7FlyingArrow
.if 0
  phx
  jsr Mode7GetDynamicBuffer
  tax
  lda #255
  sta f:Mode7DynamicTileBuffer,x
  sta f:Mode7DynamicTileBuffer+2,x
  sta f:Mode7DynamicTileBuffer+4,x
  sta f:Mode7DynamicTileBuffer+6,x
  sta f:Mode7DynamicTileBuffer+8,x
  sta f:Mode7DynamicTileBuffer+10,x
  sta f:Mode7DynamicTileBuffer+12,x
  sta f:Mode7DynamicTileBuffer+14,x
  sta f:Mode7DynamicTileBuffer+16,x
  plx
.endif

  inc ActorPX,x
  
  jsr Mode7UpdateActorPicture

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

  lda ActorPX,x
  ora ActorPY,x
  and #$0007
  jeq AlignedToGrid
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
  cmp ActorOldXPos
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
  cmp ActorOldYPos
  bcs @MovedDown
@MovedUp:
  ; FF
  ; ##
  ; ##
  seta8
  jsr Mode7GetDynamicTileNumber
  sta BlockUpdateDataBL,y
  ina
  sta BlockUpdateDataBL+1,y
  ina
  sta BlockUpdateDataBR,y
  ina
  sta BlockUpdateDataBR+1,y

  lda #10
  sta BlockUpdateDataTL,y
  sta BlockUpdateDataTR,y

  lda #TALL
  sta BlockUpdateDataTL+1,y
  seta16
  rts
@MovedDown:
  ; ##
  ; ##
  ; FF
  seta8
  jsr Mode7GetDynamicTileNumber
  sta BlockUpdateDataTL,y
  ina
  sta BlockUpdateDataBL,y
  ina
  sta BlockUpdateDataTR,y
  ina
  sta BlockUpdateDataBR,y

  lda #10
  sta BlockUpdateDataBL+1,y
  sta BlockUpdateDataBR+1,y

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
  jsr LoadUpTileNumbersUnderActor
  jsr CopyOverFourTileGfx

  phx
  phy
  tax
  .scope
    SpritePointer = 0
    Columns = 2
    Rows = 3

    lda #.loword(DemoSoftwareSprite)
    sta SpritePointer
    ldy #0 ; Index for the above
    seta8
    lda #16
    sta Columns
  @ColumnLoop:
    lda #16
    sta Rows
  @RowLoop:
    lda (SpritePointer),y
    beq :+
      sta f:Mode7DynamicTileBuffer,x
    :
    iny
    ; Next row
    seta16
    txa
    add #8
    tax
    seta8
    dec Rows
    bne @RowLoop

    ; Go back up to the top of the column
    seta16
    txa
    sub #128-1
    tax
    lda Columns
    and #255
    cmp #9
    bne :+
      txa
      add #128-8
      tax
    :
    seta8
    dec Columns
    bne @ColumnLoop
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
@Right:

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


DemoSoftwareSprite:
; 1 white
; 2 black
  .byt 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0
  .byt 0, 0, 0, 0, 2, 2, 1, 1, 1, 1, 2, 2, 0, 0, 0, 0
  .byt 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0, 0, 0
  .byt 0, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0, 0
  .byt 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0
  .byt 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0
  .byt 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2
  .byt 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2

  .byt 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2
  .byt 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2
  .byt 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0
  .byt 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0
  .byt 0, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0, 0
  .byt 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0, 0, 0
  .byt 0, 0, 0, 0, 2, 2, 1, 1, 1, 1, 2, 2, 0, 0, 0, 0
  .byt 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0
