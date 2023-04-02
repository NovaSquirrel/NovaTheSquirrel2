; Super Princess Engine
; Copyright (C) 2019-2023 NovaSquirrel
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

; LevelBlockPtr = block address
; Replaces a tile with the tile "underneath" or a regular floor if there was nothing
.a16
.i16
.proc Mode7UncoverBlock
  php

  phy
  ldy #64*64
  seta8
  lda [LevelBlockPtr],y
  sta [LevelBlockPtr]
  bne NotEmpty ; If the uncovered tile isn't empty, make it floor
    seta16
    jsr CheckerForPtr
    seta8
    sta [LevelBlockPtr]
  NotEmpty:
  tdc ; Clear A
  sta [LevelBlockPtr],y ; Erase block underneath
  ply

  plp
  rts
.endproc

; A = block to set
; LevelBlockPtr = block address
.export Mode7PutBlockAbove
.proc Mode7PutBlockAbove
  pha
  php
  seta8
  phy
  ldy #64*64
  lda [LevelBlockPtr]
  sta [LevelBlockPtr],y
  ply

  plp
  pla
  ; Inline tail call into Mode7ChangeBlock
.endproc

; A = block to set
; LevelBlockPtr = block address
.a16
.i16
.proc Mode7ChangeBlock
Temp = BlockTemp
  phx
  phy
  php
  seta8
  sta [LevelBlockPtr] ; Make the change in the level buffer itself
  tax                 ; assert((a>>8) == 0)
  setaxy16
  ; Find a free index in the block update queue
  ldy #(BLOCK_UPDATE_COUNT-1)*2
FindIndex:
  lda BlockUpdateDataTL+1,y ; Test for empty slot
  and #255
  beq Found
  dey                      ; Next index
  dey
  bpl FindIndex            ; Give up if all slots full
  bra Exit
Found:
  ; From this point on in the routine, Y = free update queue index

  seta8
  ; Mode 7 has 8-bit tile numbers, unlike the main game which has 16-bit tile numbers
  ; so the second byte is mostly unused and can be repurposed. Here TL+1 is used to specify the shape/size of update.
  lda M7BlockTopLeft,x
  sta BlockUpdateDataTL,y
  lda M7BlockTopRight,x
  sta BlockUpdateDataTR,y
  lda M7BlockBottomLeft,x
  sta BlockUpdateDataBL,y
  lda M7BlockBottomRight,x
  sta BlockUpdateDataBR,y
  ; Enable, and mark it as a 16x16 update
  lda #1
  sta BlockUpdateDataTL+1,y
  seta16

  ; Now calculate the PPU address
  ; LevelBlockPtr is 0000yyyyyyxxxxxx
  ; Needs to become  00yyyyyy0xxxxxx0
  lda LevelBlockPtr
  and #%111111000000 ; Get Y
  asl
  asl
  sta BlockUpdateAddress,y

  ; Add in X
  lda LevelBlockPtr
  and #%111111
  asl
  ora BlockUpdateAddress,y
  sta BlockUpdateAddress,y

  ; Restore registers
Exit:

  plp
  ply
  plx
  rts
.endproc

; A = X coordinate (in pixels)
; Y = Y coordinate (in pixels)
; Output: LevelBlockPtr
.a16
.i16
.export Mode7BlockAddress
.proc Mode7BlockAddress
  and #%1111110000
      ; ......xx xxxx....
  lsr ; .......x xxxxx...
  lsr ; ........ xxxxxx..
  lsr ; ........ .xxxxxx.
  lsr ; ........ ..xxxxxx
  sta LevelBlockPtr
  tya ; ......yy yyyy....
  and #%1111110000
  asl ; .....yyy yyy.....
  asl ; ....yyyy yy......
  tsb LevelBlockPtr
      ; ....yyyy yyxxxxxx
  lda [LevelBlockPtr]
  and #255
  rts
.endproc


.a16
.import M7BlockInteractionSet, M7BlockInteractionEnter, M7BlockInteractionExit, M7BlockInteractionBump
GetInteractionSet:
  tay
  lda M7BlockInteractionSet,y
  and #255
  asl
  tay
  rts
CallBlockEnter:
  jsr GetInteractionSet
  lda M7BlockInteractionEnter,y
  pha
  rts
CallBlockExit:
  jsr GetInteractionSet
  lda M7BlockInteractionExit,y
  pha
  rts
CallBlockBump:
  jsr GetInteractionSet
  lda M7BlockInteractionBump,y
  pha
  rts

.a16
.export M7BlockNothing
M7BlockNothing:
.export M7BlockCloneButton
M7BlockCloneButton:
.export M7BlockMessage
M7BlockMessage:
.export M7BlockSpring
M7BlockSpring:
.export M7BlockTeleport
M7BlockTeleport:
.export M7BlockToggleButton1
M7BlockToggleButton1:
.export M7BlockToggleButton2
M7BlockToggleButton2:
  rts

; Creates actor A at the block corresponding to LevelBlockPtr
.a16
.i16
.proc Mode7CreateActorFromBlock
  pha

  ; Maybe change the order of things, so it'll fail early if there's no actor slots
  jsr Mode7UncoverBlock

  lda LevelBlockPtr ; X
  and #63
  asl
  asl
  asl
  asl
  tax

  lda LevelBlockPtr ; Y
  and #63*64
  lsr
  lsr
  tay

  pla
;  .import Mode7CreateActor
;  jmp Mode7CreateActor
  ; Carry = success
  ; X = actor slot
.endproc

.export M7BlockPushableBlock
.proc M7BlockPushableBlock
.if 0
  lda LevelBlockPtr
  sta 0

  lda Mode7MoveDirection
  and #3
  asl
  tay
  lda ForwardPtrTile,y
  add LevelBlockPtr
  sta LevelBlockPtr
  lda [LevelBlockPtr]
  and #255
  cmp #Mode7Block::Dirt ; Special-case dirt specifically until the 16 below works
  beq Fail
  tax
  lda M7BlockFlags,x
  bit #16 ; Check if the block is specifically solid to blocks
  bne Fail
  and ForwardWallBitOutside,y
  beq :+
Fail:
    rts
  :
  lda 0
  sta LevelBlockPtr

  ; Create the block
  lda #Mode7ActorType::PushBlock
  jsr Mode7CreateActorFromBlock
  bcc :+
    seta8
    lda Mode7MoveDirection
    sta ActorDirection,x
    seta16
  :
.endif
  rts
.endproc


.export M7BlockExit
.proc M7BlockExit
  lda Mode7ChipsLeft
  beq :+
    rts
  :
  .import ExitToOverworld
  jsl WaitVblank
  jml ExitToOverworld
.endproc


; Change a block to what its checkerboard block would be, based on the address
.a16
; Probably could work at .a8 too
.export CheckerForPtr
CheckerForPtr:
  lda LevelBlockPtr
  sta 0
  lsr
  lsr
  lsr
  lsr
  lsr
  lsr
  eor 0
  lsr
  tdc ; A = zero
  adc #Mode7Block::Checker1
  rts
.export Mode7EraseBlock
Mode7EraseBlock:
  jsr CheckerForPtr
  jmp Mode7ChangeBlock

.export M7BlockDirt
.proc M7BlockDirt
  bra Mode7EraseBlock
.endproc

.export M7BlockWater
.proc M7BlockWater
  lda Mode7Tools
  and #TOOL_FLIPPERS
  beq :+
    rts
  :
  jmp M7BlockHurt
.endproc

.export M7BlockFire
.proc M7BlockFire
  lda Mode7Tools
  and #TOOL_FIREBOOTS
  beq :+
    rts
  :
  jmp M7BlockHurt
.endproc

.export M7BlockThief
.proc M7BlockThief
  stz Mode7Tools
  rts
.endproc

.export M7BlockFireBoots
.proc M7BlockFireBoots
  lda #TOOL_FIREBOOTS
  tsb Mode7Tools
  bra Mode7EraseBlock
.endproc

.export M7BlockFlippers
.proc M7BlockFlippers
  lda #TOOL_FLIPPERS
  tsb Mode7Tools
  bra Mode7EraseBlock
.endproc

.export M7BlockSuctionBoots
.proc M7BlockSuctionBoots
  lda #TOOL_SUCTIONBOOTS
  tsb Mode7Tools
  bra Mode7EraseBlock
.endproc

.export M7BlockIceSkates
.proc M7BlockIceSkates
  lda #TOOL_ICESKATES
  tsb Mode7Tools
  bra Mode7EraseBlock
.endproc

.export M7BlockKey
.proc M7BlockKey
  tdc
  seta8
  lda [LevelBlockPtr]
  sub #Mode7Block::Key1
  tax
  inc Mode7Keys,x  
  seta16
  bra Mode7EraseBlock
.endproc

.export M7BlockLock
.proc M7BlockLock
  tdc
  seta8
  lda [LevelBlockPtr]
  sub #Mode7Block::Lock1
  tax
  lda Mode7Keys,x
  bne Unlock
  seta16
  rts
Unlock:
  dec Mode7Keys,x
  seta16
  bra Mode7EraseBlock
.endproc

.export M7BlockWoodArrow
.proc M7BlockWoodArrow
  lda [LevelBlockPtr]
  and #255
  sub #Mode7Block::WoodArrowUp
  asl
  add #Mode7ActorType::ArrowUp
  jsr Mode7CreateActorFromBlock
  bcc :+
    lda #90
    sta ActorTimer,x
  :
  rts
.endproc



.export M7BlockHurt
.proc M7BlockHurt
  lda #30
  sta Mode7Oops
  rts
.endproc

.export M7BlockIce
.proc M7BlockIce
  jsr CancelIfHaveSkates
  lda Mode7IceDirection
  ora #$8000 | $4000
  sta Mode7ForceMove
  rts
.endproc


IceGoUp:
  lda #$8000 | $4000 | DIRECTION_UP
  sta Mode7ForceMove
  rts
IceGoLeft:
  lda #$8000 | $4000 | DIRECTION_LEFT
  sta Mode7ForceMove
  rts
IceGoDown:
  lda #$8000 | $4000 | DIRECTION_DOWN
  sta Mode7ForceMove
  rts
IceGoRight:
  lda #$8000 | $4000 | DIRECTION_RIGHT
  sta Mode7ForceMove
  rts

.proc CancelIfHaveSkates
  lda Mode7Tools
  and #TOOL_ICESKATES
  beq :+
    pla ; Pop the return address off
    rts
  :
  rts
.endproc
.export M7BlockIceCornerUL
.proc M7BlockIceCornerUL
  jsr CancelIfHaveSkates
  lda Mode7IceDirection
  cmp #DIRECTION_LEFT
  beq IceGoDown
  bra IceGoRight
.endproc
.export M7BlockIceCornerUR
.proc M7BlockIceCornerUR
  jsr CancelIfHaveSkates
  lda Mode7IceDirection
  cmp #DIRECTION_RIGHT
  beq IceGoDown
  bra IceGoLeft
.endproc
.export M7BlockIceCornerDL
.proc M7BlockIceCornerDL
  jsr CancelIfHaveSkates
  lda Mode7IceDirection
  cmp #DIRECTION_LEFT
  beq IceGoUp
  bra IceGoRight
.endproc
.export M7BlockIceCornerDR
.proc M7BlockIceCornerDR
  jsr CancelIfHaveSkates
  lda Mode7IceDirection
  cmp #DIRECTION_RIGHT
  beq IceGoUp
  bra IceGoLeft
.endproc

.proc CancelIfHaveSuctionBoots
  lda Mode7Tools
  and #TOOL_SUCTIONBOOTS
  beq :+
    pla ; Pop the return address off
    rts
  :
  rts
.endproc
.export M7BlockForceLeft
.proc M7BlockForceLeft
  jsr CancelIfHaveSuctionBoots
  lda #$8000 | DIRECTION_LEFT
  sta Mode7ForceMove
  rts
.endproc
.export M7BlockForceDown
.proc M7BlockForceDown
  jsr CancelIfHaveSuctionBoots
  lda #$8000 | DIRECTION_DOWN
  sta Mode7ForceMove
  rts
.endproc
.export M7BlockForceUp
.proc M7BlockForceUp
  jsr CancelIfHaveSuctionBoots
  lda #$8000 | DIRECTION_UP
  sta Mode7ForceMove
  rts
.endproc
.export M7BlockForceRight
.proc M7BlockForceRight
  jsr CancelIfHaveSuctionBoots
  lda #$8000 | DIRECTION_RIGHT
  sta Mode7ForceMove
  rts
.endproc


.export M7BlockTurtle
.proc M7BlockTurtle
  lda #Mode7Block::Water
  jmp Mode7ChangeBlock
.endproc
.export M7BlockBecomeWall
.proc M7BlockBecomeWall
  lda #Mode7Block::Void
  jmp Mode7ChangeBlock
.endproc

.export M7BlockRotateBorderLR
.proc M7BlockRotateBorderLR
  lda #Mode7Block::RotateBorderUD
  jmp Mode7ChangeBlock
.endproc
.export M7BlockRotateBorderUD
.proc M7BlockRotateBorderUD
  lda #Mode7Block::RotateBorderLR
  jmp Mode7ChangeBlock
.endproc

.export M7BlockRotateCornerUL
.proc M7BlockRotateCornerUL
  lda #Mode7Block::RotateCornerUR
  jmp Mode7ChangeBlock
.endproc
.export M7BlockRotateCornerUR
.proc M7BlockRotateCornerUR
  lda #Mode7Block::RotateCornerDR
  jmp Mode7ChangeBlock
.endproc
.export M7BlockRotateCornerDR
.proc M7BlockRotateCornerDR
  lda #Mode7Block::RotateCornerDL
  jmp Mode7ChangeBlock
.endproc
.export M7BlockRotateCornerDL
.proc M7BlockRotateCornerDL
  lda #Mode7Block::RotateCornerUL
  jmp Mode7ChangeBlock
.endproc

.export M7BlockCollect
.proc M7BlockCollect
  lda #15
  sta Mode7HappyTimer

  sed
  lda Mode7ChipsLeft
  sub #1
  sta Mode7ChipsLeft
  cld
  lda #Mode7Block::Hurt
  jmp Mode7ChangeBlock
.endproc
.export M7BlockCountFour
.proc M7BlockCountFour
  lda #Mode7Block::CountThree
  jmp Mode7ChangeBlock
.endproc
.export M7BlockCountThree
.proc M7BlockCountThree
  lda #Mode7Block::CountTwo
  jmp Mode7ChangeBlock
.endproc
.export M7BlockCountTwo
.proc M7BlockCountTwo
  lda #Mode7Block::Collect
  jmp Mode7ChangeBlock
.endproc
.export M7BlockCheckpoint
.proc M7BlockCheckpoint
  lda #Mode7Block::Empty
  jsr Mode7ChangeBlock
  .import Mode7MakeCheckpoint
  jmp Mode7MakeCheckpoint
.endproc