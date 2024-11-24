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
.export AutotileLevel
.import BlockAutotile

.segment "C_LevelDecompress"

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

  lda LevelShapeIndex
  cmp #2*2 ; Level shape is Horizontal Tall
  beq ProcessEntire32K

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

  bit TwoLayerLevel-1
  bmi HasSecondLayer
  rtl

ProcessEntire32K:
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
  lda #LEVEL_WIDTH * LEVEL_HEIGHT * LEVEL_TILE_SIZE * 2
  sub LevelColumnSize ; Subtract two columns to account for the middle pointer being offset
  sub LevelColumnSize
  jsr Process

  ; For the last column, right pointer = middle pointer
  ; To avoid going off the end of the level
  lda MidPointer
  sta RightPointer
  lda #LEVEL_WIDTH * LEVEL_HEIGHT * LEVEL_TILE_SIZE * 2
  sub LevelColumnSize ; Subtract one column to account for the middle pointer being offset
  jsr Process
  rtl

HasSecondLayer:
  ; For the first column, do stuff a bit different
  ; and use LeftPointer and MidPointer
  ldy #0
  lda #LEVEL_WIDTH * LEVEL_HEIGHT * LEVEL_TILE_SIZE
  sta LeftPointer
  sta MidPointer
  ora LevelColumnSize
  sta RightPointer ; Stop at the right column
  lda LevelColumnSize
  jsr Process

  ; For the middle part, process it normally
  ldy #0 ; Reset Y to zero
  lda RightPointer ; Reuse it from here because it's in zeropage
  sta MidPointer
  lda RightPointer
  add LevelColumnSize
  sta RightPointer
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
; A = index to stop at
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
  cmp #Block::Ladder
  beq No
  cmp #Block::LadderTop
  beq No
  lda #Block::LadderTop
  sta [MidPointer],y
No:
  rts
.endproc

.export AutotileGuideRailPillar
.proc AutotileGuideRailPillar
  lda #Block::GuideRailPillarTop
  sta [MidPointer],y
Loop:
  iny
  iny
  lda [MidPointer],y
  cmp #Block::GuideRailPillar
  beq Loop
Stop:
  dey
  dey
  lda #Block::GuideRailPillarBottom
  sta [MidPointer],y
  rts
.endproc

.proc IsLedgeTile
  cmp #Block::LedgeMiddle
  beq No
  cmp #Block::GradualSlopeR_U4_Dirt+1
  bcs No
  cmp #Block::Ledge
  bcc No2 ; Carry is already clear so skip right to the rts
Yes:
  sec
  rts
No:
  clc
No2:
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

  ; Add dirt if needed
  cpx #0*2
  beq NoDirt
  cpx #3*2
  beq NoDirt
    jsr AdjustLedgeForDirt
  NoDirt:

  lda ExpandWith,x
  bra AutotileExpandOther

Table:
  .word Block::Ledge
  .word Block::LedgeLeft
  .word Block::LedgeRight
  .word Block::Ledge
ExpandWith:
  .word Block::LedgeMiddle
  .word Block::LedgeLeftSide
  .word Block::LedgeRightSide
  .word Block::LedgeMiddle
.endproc

.export AutotileExpandDirt
.proc AutotileExpandDirt
  ; 0 = Block to store
  lda #Block::LedgeMiddle
::AutotileExpandOther:
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

  ; If filling with dirt, check for tiles to autotile below
;  lda 0
;  cmp #Block::LedgeMiddle
;  bne NotFillDirt
    lda [MidPointer],y
    cmp #Block::MedSlopeL_UL
    bcc @NotSlope
    cmp #Block::GradualSlopeR_U4+1
    bcs @NotSlope
       adc #14*2
       sta [MidPointer],y
	@NotSlope:
  NotFillDirt:

  dey
  dey
  rts
.endproc

.export AutotileLedgeSolidLeft
.proc AutotileLedgeSolidLeft
  ; Check the block above
  dey
  dey
  ; Connect to LedgeSolidBottom if it's there (it will have turned into LedgeSolidBottomRight)
  lda [LeftPointer],y
  cmp #Block::LedgeSolidBottomRight
  beq ConnectToBottom
  lda [MidPointer],y
  ; There's dirt behind if there's these three types:
  cmp #Block::LedgeLeftSide
  beq WithDirt
  cmp #Block::LedgeRightSide
  beq WithDirt
  cmp #Block::LedgeMiddle
  bne NotLedgeAbove
WithDirt:
    iny
    iny
    lda #Block::LedgeSolidLeft_Dirt
    sta [MidPointer],y
    bra Loop
ConnectToBottom:
    lda #Block::LedgeSolidLeftSideCornerBottom
    sta [MidPointer],y
    ; Change the LedgeSolidBottomRight so it actually continues into this block
    lda #Block::LedgeSolidBottom
    sta [LeftPointer],y
    bra Loop
  NotLedgeAbove:
  iny
  iny

; Adjust every block in the column
Loop:
  iny
  iny
  lda [MidPointer],y
  cmp #Block::LedgeSolidLeft
  bne Nope
  lda #Block::LedgeSolidLeftSide
  sta [MidPointer],y
  bra Loop

; Hit the bottom
Nope:
  dey
  dey
  lda [LeftPointer],y
  jsr IsLedgeTile
  bcc :+
;  lda [LeftPointer],y
;  cmp #Block::LedgeLeft
;  beq Yup
;  cmp #Block::LedgeSolidLeft
;  beq Yup
;  cmp #Block::Ledge
;  bne :+
Yup:
    lda #Block::LedgeSolidLeftSideCorner
    sta [MidPointer],y
    jmp AutotileExpandDirt
  :
  rts
.endproc

.export AutotileLedgeSolidRight
.proc AutotileLedgeSolidRight
  ; Check the block above
  dey
  dey
  ; Connect to LedgeSolidBottom if it's there
  lda [RightPointer],y
  cmp #Block::LedgeSolidBottom
  beq ConnectToBottom
  lda [MidPointer],y
  ; There's dirt behind if there's these three types:
  cmp #Block::LedgeLeftSide
  beq WithDirt
  cmp #Block::LedgeRightSide
  beq WithDirt
  cmp #Block::LedgeMiddle
  bne NotLedgeAbove
WithDirt:
    iny
    iny
    lda #Block::LedgeSolidRight_Dirt
    sta [MidPointer],y
    bra Loop
ConnectToBottom:
    lda #Block::LedgeSolidRightSideCornerBottom
    sta [MidPointer],y
    bra Loop
  NotLedgeAbove:
  iny
  iny

; Adjust every block in the column
Loop:
  iny
  iny
  lda [MidPointer],y
  cmp #Block::LedgeSolidRight
  bne Nope
  lda #Block::LedgeSolidRightSide
  sta [MidPointer],y
  bra Loop

; Hit the bottom
Nope:
  dey
  dey
  lda [RightPointer],y
  jsr IsLedgeTile
  bcc :+
;  lda [RightPointer],y
;  cmp #Block::LedgeRight
;  beq Yup
;  cmp #Block::LedgeSolidRight
;  beq Yup
;  cmp #Block::Ledge
;  bne :+
Yup:
    lda #Block::LedgeSolidRightSideCorner
    sta [MidPointer],y
    jmp AutotileExpandDirt
  :
  rts
.endproc


.export AutotileLedgeSolidBottom
.proc AutotileLedgeSolidBottom
  stz 0

  lda [LeftPointer],y
  jsr IsBottom
  rol 0
  lda [RightPointer],y
  jsr IsBottom
  rol 0
  asl 0 ; Multiply by 2 for the 16-bit table below

  ; Use the table
  ldx 0
  lda Table,x
  sta [MidPointer],y
  rts

Table:
  .word Block::LedgeSolidBottom
  .word Block::LedgeSolidBottomLeft
  .word Block::LedgeSolidBottomRight
  .word Block::LedgeSolidBottom

IsBottom:
  cmp #Block::LedgeSolidBottom
  beq Yes
  cmp #Block::LedgeSolidBottomLeft
  beq Yes
  cmp #Block::LedgeSolidBottomRight
  beq Yes
  cmp #Block::LedgeSolidRightSideCornerBottom
  beq Yes
  clc
  rts
Yes:
  ; Carry set by being >= the compared value
  rts
.endproc

.export AutotilePier
.proc AutotilePier
  stz 0

  lda [LeftPointer],y
  jsr IsPier
  rol 0
  lda [RightPointer],y
  jsr IsPier
  rol 0
  asl 0 ; Multiply by 2 for the 16-bit table below

  dey
  dey
  lda [MidPointer],y
  bne :+
    lda #Block::PierTop
    add 0
    sta [MidPointer],y
  :
  iny
  iny

  lda #Block::PierPole
  jmp AutotileExpandOther

IsPier:
  cmp #Block::Pier
  bne No
  ; Carry set
  rts
No:
  clc
  rts
.endproc

.export AutotileRopeLadder
.proc AutotileRopeLadder
  dey
  dey
  lda [MidPointer],y
  iny
  iny
  cmp #Block::RopeLadder
  beq No
  cmp #Block::RopeLadderTop
  beq No
  lda #Block::RopeLadderTop
  sta [MidPointer],y
No:
  rts
.endproc

.export AutotileBridge
.proc AutotileBridge
  stz 0

  lda [LeftPointer],y
  jsr IsBridge
  rol 0
  lda [RightPointer],y
  jsr IsBridge
  rol 0
  asl 0 ; Multiply by 2 for the 16-bit table below

  ; Use the table
  ldx 0
  lda Table,x
  sta [MidPointer],y
  dey
  dey
  lda TopTable,x
  sta [MidPointer],y
  iny
  iny
  rts
Table:
  .word Block::Bridge, Block::BridgeLeft, Block::BridgeRight, Block::Bridge
TopTable:
  .word Block::BridgeTop, Block::BridgeLeftTop, Block::BridgeRightTop, Block::BridgeTop

IsBridge:
  cmp #Block::BridgeRight+1
  bcs No
  cmp #Block::Bridge
  bcc No
  ; Carry set
  rts
No:
  clc
  rts
.endproc

.export AutotileSand
.proc AutotileSand
  stz 0

  ; Up
  tyx
  dey
  dey
  lda [MidPointer],y
  jsr IsSand
  rol 0

  ; Down
  txy
  iny
  iny
  lda [MidPointer],y
  jsr IsSand
  rol 0

  ; Right
  txy
  lda [RightPointer],y
  jsr IsSand
  rol 0

  ; Left
  lda [LeftPointer],y
  jsr IsSand
  lda 0
  rol
  asl
  tax
  lda SandTable,x
  sta [MidPointer],y
  rts

SandTable:
  .word Block::Sand            ; ....
  .word Block::Sand            ; ...L
  .word Block::Sand            ; ..R.
  .word Block::Sand            ; ..RL
  .word Block::Sand            ; .D..
  .word Block::SandTopRight    ; .D.L
  .word Block::SandTopLeft     ; .DR.
  .word Block::SandTop         ; .DRL
  .word Block::Sand            ; U...
  .word Block::SandBottomRight ; U..L
  .word Block::SandBottomLeft  ; U.R.
  .word Block::SandBottom      ; U.RL
  .word Block::Sand            ; UD..
  .word Block::SandRight       ; UD.L
  .word Block::SandLeft        ; UDR.
  .word Block::Sand            ; UDRL

IsSand:
  cmp #Block::SandBottomRight+1
  bcs No
  cmp #Block::SandLeft
  bcs Yes
No:
  clc
Yes:
  rts
.endproc

.export AutotileStone
.proc AutotileStone
  .macro IsStone
    cmp #Block::StoneMossy+1
    bcs :+
    cmp #Block::StoneSingle
    bcs :++
  :
    clc
  :
  .endmacro
  stz 0

  ; Up
  tyx
  dey
  dey
  lda [MidPointer],y
  IsStone
  rol 0

  ; Down
  txy
  iny
  iny
  lda [MidPointer],y
  IsStone
  rol 0

  ; Right
  txy
  lda [RightPointer],y
  IsStone
  rol 0

  ; Left
  lda [LeftPointer],y
  IsStone

  lda 0
  rol
  asl
  adc #Block::StoneSingle
  sta [MidPointer],y
  rts
.endproc

.export AutotileCliffWall
.proc AutotileCliffWall
  .macro IsCliff
    cmp #Block::CliffWallNoAutotile+1
    bcs :+
    cmp #Block::CliffVineOverCliff
    bcs :++
  :
    clc
  :
  .endmacro
  stz 0

  ; Up
  tyx
  dey
  dey
  lda [MidPointer],y
  IsCliff
  rol 0

  ; Down
  txy
  iny
  iny
  lda [MidPointer],y
  IsCliff
  rol 0

  ; Right
  txy
  lda [RightPointer],y
  IsCliff
  rol 0

  ; Left
  lda [LeftPointer],y
  IsCliff
  lda 0
  rol
  asl
  adc #Block::CliffWallSingle
  sta [MidPointer],y

  rts
  ; Is there cliff below?
  lda 0
  and #%0010 ; Down; not %0100 because a rol 0 was skipped on Left
  bne :+
    rts
  :
  iny
  iny
  cpy ChangeAtIndex
  bcc :+
    txy ; X is still the backed up Y position
    rts
  :
  bra AutotileCliffWall
.endproc

.export AutotileSmallTreeBush
.proc AutotileSmallTreeBush
  lda #Block::SmallTreeBushTopRight
  sta [RightPointer],y
  iny
  iny
  lda #Block::SmallTreeBushBottomLeft
  sta [MidPointer],y
  lda #Block::SmallTreeBushBottomRight
  sta [RightPointer],y
  rts
.endproc

.export AutotileSmallTree
.proc AutotileSmallTree
  lda #Block::SmallTreeTopRight
  sta [RightPointer],y
  iny
  iny
  lda #Block::SmallTreeBottomLeft
  sta [MidPointer],y
  lda #Block::SmallTreeBottomRight
  sta [RightPointer],y
  iny
  iny
  lda #Block::SmallTreeTrunkTopLeft
  sta [MidPointer],y
  lda #Block::SmallTreeTrunkTopRight
  sta [RightPointer],y
  ; Expand down
: iny
  iny
  lda [MidPointer],y
  bne Exit
  lda #Block::SmallTreeTrunkLeft
  sta [MidPointer],y
  lda #Block::SmallTreeTrunkRight
  sta [RightPointer],y
  bra :-

Exit:
  dey
  dey
  rts
.endproc

.export AutotileVines
.proc AutotileVines
  lda #Block::Vines
  jmp AutotileExpandOther
.endproc

.export AutotileBranchPlatform
.proc AutotileBranchPlatform
  lda [LeftPointer],y
  cmp #Block::BranchPlatformLeft
  beq :+
  cmp #Block::BranchPlatformMiddle
  bne Left
:
  lda [RightPointer],y
  cmp #Block::BranchPlatformMiddle
  bne Right
  rts

Left:
  lda #Block::BranchPlatformLeft
  sta [MidPointer],y
  rts
Right:
  lda #Block::BranchPlatformRight
  sta [MidPointer],y
  rts
.endproc

.export AutotileDoor
.proc AutotileDoor
  iny
  iny
  lda #Block::DoorBottom
  sta [MidPointer],y
  rts
.endproc

.a16
.export AdjustLedgeForDirt
.proc AdjustLedgeForDirt
  dey
  dey
  lda [MidPointer],y
  iny
  iny
  ; These are the types of dirt to check against
  cmp #Block::LedgeLeftSide
  beq @Yes
  cmp #Block::LedgeRightSide
  beq @Yes
  cmp #Block::LedgeMiddle
  bne :+
@Yes:
    ; Add dirt to the ledge
    lda [MidPointer],y
    add #4*2
    sta [MidPointer],y
  :
  rts
.endproc

.a16
.export AutotileBottomLock
.proc AutotileBottomLock
  lda [MidPointer],y
  add #4*2
  iny
  iny
  sta [MidPointer],y
  rts
.endproc

.a16
.export AutotileDirtBigStar
.proc AutotileDirtBigStar
  lda #Block::GrassyDirtBigStar2
  sta [RightPointer],y
  iny
  iny
  lda #Block::GrassyDirtBigStar3
  sta [MidPointer],y
  lda #Block::GrassyDirtBigStar4
  sta [RightPointer],y
  dey
  dey
  rts
.endproc

.a16
.export AutotileWater
.proc AutotileWater
  stz 0

  ; Left
  lda [LeftPointer],y
  jsr IsWater
  rol 0

  ; Right
  lda [RightPointer],y
  jsr IsWater
  rol 0

  ; Down
  tyx
  iny
  iny
  lda [MidPointer],y
  jsr IsWater
  rol 0

  ; Up
  txy
  dey
  dey
  lda [MidPointer],y
  jsr IsWater
  rol 0

  txy
  lda 0
  asl
  add #Block::WaterSingle
  sta [MidPointer],y
  cmp #Block::Water
  beq :+
  rts
:
  ; Try for inner corners
  stz 0
  dey
  dey
  lda [LeftPointer],y
  jsr IsWater
  rol 0
  lda [RightPointer],y
  jsr IsWater
  lda 0
  rol
  txy
  eor #3
  asl 
  adc #Block::Water
  sta [MidPointer],y
  rts

IsWater:
  cmp #Block::WaterInnerCornerBoth+1
  bcs No
  cmp #Block::WaterSingle
  bcs Yes
No:
  clc
Yes:
  rts
.endproc

.export AutotileGlassPillar
.proc AutotileGlassPillar
  lda #Block::GlassPillarTop
  sta [MidPointer],y
Loop:
  iny
  iny
  lda [MidPointer],y
  cmp #Block::GlassPillarMiddle
  beq Loop
Stop:
  dey
  dey
  lda #Block::GlassPillarBottom
  sta [MidPointer],y
  rts
.endproc

.export AutotileSkipEmpty
.proc AutotileSkipEmpty
  lda [MidPointer],y
Loop:
  .repeat 4
    iny
    iny
    cpy ChangeAtIndex
    bcs Exit
    cmp [MidPointer],y
    bne Exit
  .endrep
  iny
  iny
  cpy ChangeAtIndex
  bcs Exit
  cmp [MidPointer],y
  beq Loop
Exit:
  ; Back this up since it'll INY INY after this routine
  dey
  dey
  rts
.endproc


.export AutotileWoodPlankPlatform
.proc AutotileWoodPlankPlatform
  pea Block::WoodPlankPlatformSingle        ; >=
  pea Block::WoodPlankPlatformPillarRight+1 ; <
  pea Block::WoodPlankPlatformSingle        ; Base
  jsr AutotileHorizontalGeneric
  lsr
  dea
  beq Left
  dea
  beq Right
  rts
Left:
  lda #Block::WoodPlankPlatformPillarLeft
  jmp AutotileExpandOther
Right:
  lda #Block::WoodPlankPlatformPillarRight
  jmp AutotileExpandOther
.endproc

.export AutotileWoodPlanks
.proc AutotileWoodPlanks
  pea Block::WoodPlanks         ; >=
  pea Block::WoodPlanksMiddle+1 ; <
  pea Block::WoodPlanks         ; Base
  jsr AutotileHorizontalGeneric
  rts
.endproc

.export AutotileFence
.proc AutotileFence
  pea Block::Fence         ; >=
  pea Block::FenceMiddle+1 ; <
  pea Block::Fence         ; Base
  jsr AutotileHorizontalGeneric
  rts
.endproc

.export AutotileFloatingPlatform
.proc AutotileFloatingPlatform
  pea Block::FloatingPlatform         ; >=
  pea Block::FloatingPlatformMiddle+1 ; <
  pea Block::FloatingPlatform         ; Base
  jsr AutotileHorizontalGeneric
  rts
.endproc

.export AutotileFloatingPlatformFallthrough
.proc AutotileFloatingPlatformFallthrough
  pea Block::FloatingPlatformFallthrough         ; >=
  pea Block::FloatingPlatformMiddleFallthrough+1 ; <
  pea Block::FloatingPlatformFallthrough         ; Base
  jsr AutotileHorizontalGeneric
  rts
.endproc

.export AutotileWoodPlatform
.proc AutotileWoodPlatform
  pea Block::WoodPlatform         ; >=
  pea Block::WoodPlatformMiddle+1 ; <
  pea Block::WoodPlatform         ; Base
  jsr AutotileHorizontalGeneric
  lda #Block::WoodPlatformPole
  jmp AutotileExpandOther
.endproc

.export AutotileGRCanopyPillar
.proc AutotileGRCanopyPillar
  ; When placing the pillar on its own, change the block above to accomodate for this
  dey
  dey
  lda [MidPointer],y
  cmp #Block::GRCanopy
  bne :+
    lda #Block::GRCanopyOnPillar
    sta [MidPointer],y
  :
  iny
  iny
DontFixAbove:
  lda #Block::GRCanopyPillar
  jsr AutotileExpandOther
  lda #Block::GRCanopyPillarBottom
  sta [MidPointer],y
  rts
.endproc

.export AutotileGRCanopy
.proc AutotileGRCanopy
  pea Block::GRCanopySingle     ; >=
  pea Block::GRCanopyOnPillar+1 ; <
  pea Block::GRCanopySingle     ; Base
  jsr AutotileHorizontalGeneric

  ; Expand
  cmp #3*2
  bne AutotileGRCanopyPillar::DontFixAbove
  rts
.endproc

.proc AutotileHorizontalGeneric
  ; 1,s Return address
  ; 3,s Must be >=
  ; 5,s Must be <
  ; 7,s Base block value
  stz 0

  lda [LeftPointer],y
  jsr IsInRange
  rol 0
  lda [RightPointer],y
  jsr IsInRange
  rol 0
  asl 0 ; Multiply by 2 because tile numbers are only even

  lda 7,s
  add 0
  sta [MidPointer],y

  ; Remove the parameters before returning
  pla
  sta 7-2,s ; Move the return address over
  pla
  pla
  lda 0 ; Reload the results from the side checking so it's ready to go for code to act on
  rts

IsInRange: ;+2 for the jsr into here
  cmp 5+2,s
  bcs No
  cmp 3+2,s
  bcs Yes
No:
  clc
Yes:
  rts
.endproc
