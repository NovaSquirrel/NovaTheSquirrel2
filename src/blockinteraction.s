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
.include "actorenum.s"
.smart

.segment "BlockInteraction"

.export BlockAutoItem, BlockInventoryItem, BlockHeart, BlockSmallHeart
.export BlockMoney, BlockPickupBlock, BlockPushBlock, BlockPrize, BlockBricks
.export BlockSign, BlockSpikes, BlockSpring, BlockLadder

; Export the interaction runners
.export BlockRunInteractionAbove, BlockRunInteractionBelow
.export BlockRunInteractionSide, BlockRunInteractionInsideHead
.export BlockRunInteractionInsideBody, BlockRunInteractionEntityInside
.export BlockRunInteractionEntityTopBottom, BlockRunInteractionEntitySide

; .-------------------------------------
; | Runners for interactions
; '-------------------------------------

.a16
.i16
.import BlockInteractionAbove
.proc BlockRunInteractionAbove
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionAbove),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionBelow
.proc BlockRunInteractionBelow
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionBelow),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionSide
.proc BlockRunInteractionSide
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionSide),x)
  plb
Skip:
  rtl
.endproc


.a16
.i16
.import BlockInteractionInsideHead
.proc BlockRunInteractionInsideHead
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionInsideHead),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionInsideBody
.proc BlockRunInteractionInsideBody
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionInsideBody),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionEntityInside
.proc BlockRunInteractionEntityInside
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionEntityInside),x)
  plb
Skip:
  rtl
.endproc

; Pass in a block flag word and it will run the interaction
.a16
.i16
.import BlockInteractionEntityTopBottom
.proc BlockRunInteractionEntityTopBottom
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tay
  lda BlockInteractionEntityTopBottom,y
  jsr Call
  plb
Skip:
  rtl

Call: ; Could use the RTS trick here instead
  sta TempVal
  jmp (TempVal)
.endproc

; Pass in a block flag word and it will run the interaction
.a16
.i16
.import BlockInteractionEntitySide
.proc BlockRunInteractionEntitySide
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tay
  lda BlockInteractionEntitySide,y
  jsr BlockRunInteractionEntityTopBottom::Call
  plb
Skip:
  rtl
.endproc




; -------------------------------------

.proc BlockAutoItem
  rts
.endproc

.proc BlockInventoryItem
  rts
.endproc

.proc BlockHeart
  rts
.endproc

.proc BlockSmallHeart
  rts
.endproc

.proc BlockMoney
  lda #Block::Empty
  jsl ChangeBlock
  rts
.endproc

.proc BlockPickupBlock
  rts
.endproc

.proc BlockPushBlock
  rts
.endproc

.a16
.proc BlockPrize
  lda #Block::PrizeAnimation1
  jsl ChangeBlock

  lda #5
  sta BlockTemp
  lda #Block::PrizeAnimation2
  jsl DelayChangeBlock

  lda #10
  sta BlockTemp
  lda #Block::UsedPrize
  jsl DelayChangeBlock

  jsl FindFreeParticleY
  bcc :+
    lda #Particle::PrizeParticle
    sta ParticleType,y
    jmp ParticleAtBlock
  :
  rts
.endproc

.proc BlockBricks
  lda #Block::Empty
  jsl ChangeBlock
  rts
.endproc

.proc BlockSign
  rts
.endproc

.proc BlockSpikes
  rts
.endproc

.proc BlockSpring
  lda #.loword(-$70)
  sta PlayerVY

  seta8
  lda #30
  sta PlayerJumpCancelLock
  sta PlayerJumping
  seta16

  ; Animate the spring changing
  lda #5
  sta BlockTemp
  lda #Block::Spring
  jsl DelayChangeBlock
  lda #Block::SpringPressed
  jsl ChangeBlock
  rts
.endproc

.proc BlockLadder
  rts
.endproc

.a16
.proc ParticleAtBlock
  jsl GetBlockX
  xba
  ora #$80
  sta ParticlePX,y

  jsl GetBlockY
  xba
  ora #$80
  sta ParticlePY,y
  rts
.endproc
