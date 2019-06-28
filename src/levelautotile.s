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
.include "blockenum.s"
.include "leveldata.inc"
.smart
.export AutotileLevel
.import BlockAutotile

.segment "LevelDecompress"

ChangeAtIndex     = 5 ; and 6
LeftPointer       = 7 ; and 8 9
MidPointer        = 10 ; and 11 12
RightPointer      = 13 ; and 14 15

.a16
.i16
.proc AutotileLevel
  phk
  plb

  seta8
  lda #^LevelBuf
  sta LeftPointer+2
  sta MidPointer+2
  sta RightPointer+2
  seta16

  ; For the first column, do stuff a bit different
  ; and use LeftPointer and MidPointer
  ldy #0
  stz LeftPointer
  stz MidPointer
  lda LevelColumnSize
  sta RightPointer
  ; A is still LevelColumnSize
  jsr Process

  ; For the middle part, process it normally
  ldy #0 ; Reset Y to zero
  lda RightPointer ; Reuse it from here because it's in zeropage
  sta MidPointer
  asl RightPointer
  lda #LEVEL_WIDTH * LEVEL_HEIGHT * LEVEL_TILE_SIZE
  sub LevelColumnSize ; Subtract two columns to account for the middle pointer being offset
  sub LevelColumnSize
  jsr Process

  ; For the last column, right pointer = middle pointer
  ; To avoid going off the end of the level
  lda MidPointer
  sta RightPointer
  lda #LEVEL_WIDTH * LEVEL_HEIGHT * LEVEL_TILE_SIZE
  sub LevelColumnSize ; Subtract one column to account for the middle pointer being offset
  jsr Process

  rtl

; Call something with the RTS trick
Call:
  pha
  rts

; Call the autotile routine registered with each metatile, if there is one
; Loop until the end index is reached
Process:
  sta ChangeAtIndex
Loop:
  lda [MidPointer],y
  tax
  lda BlockAutotile,x
  beq :+
    jsr Call
: ; Move down one row
  iny
  iny
  cpy ChangeAtIndex
  bcc Loop
  rts
.endproc

; -----------------------------------------------------------------------------

.export AutotileLadder
.proc AutotileLadder
  dey
  dey
  lda [MidPointer],y
  iny
  iny
  cmp #Block::Ladder * 2
  beq No
  cmp #Block::LadderTop * 2
  beq No
  lda #Block::LadderTop * 2
  sta [MidPointer],y
No:
  rts
.endproc

.proc IsLedgeTile
  cmp #Block::GradualSlopeR_U4*2+1
  bcs No
  cmp #Block::Ledge*2
  bcc No
Yes:
  sec
No:
  rts
.endproc

.export AutotileLedge
.proc AutotileLedge
  stz 0

  lda [LeftPointer],y
  jsr IsLedgeTile
  rol 0
  lda [RightPointer],y
  jsr IsLedgeTile
  rol 0
  asl 0 ; Multiply by 2 for the 16-bit table below

  ; Use the table
  ldx 0
  lda Table,x
  sta [MidPointer],y
  lda ExpandWith,x
  bra AutotileExpandOther

Table:
  .word Block::Ledge*2
  .word Block::LedgeLeft*2
  .word Block::LedgeRight*2
  .word Block::Ledge*2
ExpandWith:
  .word Block::LedgeMiddle*2
  .word Block::LedgeLeftSide*2
  .word Block::LedgeRightSide*2
  .word Block::LedgeMiddle*2
.endproc

.export AutotileExpandDirt
.proc AutotileExpandDirt
  ; 0 = Block to store
  lda #Block::LedgeMiddle*2
ExpandOther:
  sta 0

  ; 2 = Mask to determine if at the first row of a column
  lda LevelColumnSize
  dea
  sta 2

Loop:
  iny
  iny

  ; Check if first row
  tya
  and 2
  beq No

  lda [MidPointer],y
  beq Yes
  cmp 0
  bne No
Yes:
  lda 0
  sta [MidPointer],y
  bra Loop
No:
  dey
  dey
  rts
.endproc
AutotileExpandOther = AutotileExpandDirt::ExpandOther

.export AutotileLedgeSolidLeft
.proc AutotileLedgeSolidLeft
Loop:
  iny
  iny
  lda [MidPointer],y
  cmp #Block::LedgeSolidLeft*2
  bne Nope
  lda #Block::LedgeSolidLeftSide*2
  sta [MidPointer],y
  bra Loop

Nope:
  dey
  dey
  lda [LeftPointer],y
  cmp #Block::Ledge*2
  bne :+
    lda #Block::LedgeSolidLeftSideCorner*2
    sta [MidPointer],y
    jmp AutotileExpandDirt
  :
  rts
.endproc

.export AutotileLedgeSolidRight
.proc AutotileLedgeSolidRight
Loop:
  iny
  iny
  lda [MidPointer],y
  cmp #Block::LedgeSolidRight*2
  bne Nope
  lda #Block::LedgeSolidRightSide*2
  sta [MidPointer],y
  bra Loop

Nope:
  dey
  dey
  lda [LeftPointer],y
  cmp #Block::Ledge*2
  bne :+
    lda #Block::LedgeSolidRightSideCorner*2
    sta [MidPointer],y
    jmp AutotileExpandDirt
  :
  rts
.endproc

