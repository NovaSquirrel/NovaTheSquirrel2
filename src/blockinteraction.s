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
.include "actorenum.s"
.include "itemenum.s"
.smart

.segment "BlockInteraction"

.export BlockAutoItem, BlockInventoryItem, BlockHeart, BlockSmallHeart
.export BlockMoney, BlockPickupBlock, BlockPushBlock, BlockPrize, BlockBricks
.export BlockSign, BlockSpikes, BlockSpring, BlockLadder, BlockLadderTop
.export BlockFallthrough, BlockDoor, BlockCeilingBarrier, BlockKey

; Export the interaction runners
.export BlockRunInteractionAbove, BlockRunInteractionBelow
.export BlockRunInteractionSide, BlockRunInteractionInsideHead
.export BlockRunInteractionInsideBody, BlockRunInteractionActorInside
.export BlockRunInteractionActorTopBottom, BlockRunInteractionActorSide

.import InventoryGiveItem, InventoryTakeItem, InventoryHasItem

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
.import BlockInteractionActorInside
.proc BlockRunInteractionActorInside
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionActorInside),x)
  plb
Skip:
  rtl
.endproc

; Pass in a block flag word and it will run the interaction
.a16
.i16
.import BlockInteractionActorTopBottom
.proc BlockRunInteractionActorTopBottom
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tay
  lda BlockInteractionActorTopBottom,y
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
.import BlockInteractionActorSide
.proc BlockRunInteractionActorSide
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tay
  lda BlockInteractionActorSide,y
  jsr BlockRunInteractionActorTopBottom::Call
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
  seta8
  lda PlayerHealth
  cmp #4
  bcs Full
    lda #4
    sta PlayerHealth
    seta16
    lda #Block::Empty
    jsl ChangeBlock
  Full:
  seta16
  rts
.endproc

.proc BlockSmallHeart
  seta8
  lda PlayerHealth
  cmp #4
  bcs Full
    inc PlayerHealth
    seta16
    lda #Block::Empty
    jsl ChangeBlock
  Full:
  seta16
  rts
.endproc

.export GetOneCoin
.proc GetOneCoin
  ; Don't add coins if you have the maximum amount already
  seta8
  lda MoneyAmount+2
  cmp #$09
  bcc OK
  lda #$99
  cmp MoneyAmount+1
  bne OK
  cmp MoneyAmount+0
  beq Skip
OK:
  sed
  lda MoneyAmount
  add #1
  sta MoneyAmount
  lda MoneyAmount+1
  adc #0
  sta MoneyAmount+1
  lda MoneyAmount+2
  adc #0
  sta MoneyAmount+2
  cld
Skip:
  seta16
  rtl
.endproc

.proc BlockMoney
  jsl GetOneCoin

  lda #Block::Empty
  jsl ChangeBlock

  jsl FindFreeParticleY
  bcc :+
    lda #Particle::LandingParticle
    sta ParticleType,y
    jmp ParticleAtBlock
  :
  rts
.endproc

.proc BlockPickupBlock
  rts
.endproc


.a16
.proc BlockPushForwardShared
OldPointer = 2
WasPushed = 4
  stz WasPushed
  lda LevelBlockPtr
  sta OldPointer

  jsl GetBlockXCoord
  ora #$80
  cmp PlayerPX

  ; Carry clear if push right, set if push left
  lda LevelBlockPtr
  bcc PushLeft
PushRight:
  add LevelColumnSize
  bra WasPushRight
PushLeft:
  sub LevelColumnSize
WasPushRight:
  sta LevelBlockPtr
  lda [LevelBlockPtr]
  rts
.endproc

.proc PoofAtBlock
  ; Need a free slot first
  jsl FindFreeParticleY
  bcs :+
    rts
  :
  lda #Particle::Poof
  sta ParticleType,y

  ; Position it where the block is
  jsl GetBlockXCoord
  ora #$80
  sta ParticlePX,y

  ; For a 16x16 particle
  jsl GetBlockYCoord
  ora #$40
  sta ParticlePY,y
  rts
.endproc

.a16
.proc BlockPushForwardCleanup
  lda BlockPushForwardShared::OldPointer
  sta LevelBlockPtr
  lda BlockPushForwardShared::WasPushed
  beq NotPushed
    lda #Block::Empty
    jsl ChangeBlock
    bra PoofAtBlock
NotPushed:
  rts
.endproc

.a16
.export BlockCloneUpPushBlock
.proc BlockCloneUpPushBlock
  jsr BlockPushForwardShared
  bne NotForward
    inc BlockPushForwardShared::WasPushed
    lda #Block::CloneUpPushBlock
    jsl ChangeBlock
NotForward:

  dec LevelBlockPtr
  dec LevelBlockPtr
  lda [LevelBlockPtr]
  bne NotUp
    inc BlockPushForwardShared::WasPushed
    lda #Block::CloneUpPushBlock
    jsl ChangeBlock
NotUp:
  bra BlockPushForwardCleanup
.endproc

.a16
.export BlockPushNoGravity
.proc BlockPushNoGravity
  jsr BlockPushForwardShared
  bne NotForward
    inc BlockPushForwardShared::WasPushed
    lda #Block::NoGravityPushBlock
    jsl ChangeBlock
NotForward:
  bra BlockPushForwardCleanup
.endproc

.a16
.export BlockCloneDownPushBlock
.proc BlockCloneDownPushBlock
  jsr BlockPushForwardShared
  bne NotForward
    inc BlockPushForwardShared::WasPushed
    lda #Block::CloneDownPushBlock
    jsl ChangeBlock
NotForward:

  inc LevelBlockPtr
  inc LevelBlockPtr
  lda [LevelBlockPtr]
  bne NotDown
    inc BlockPushForwardShared::WasPushed
    lda #Block::CloneDownPushBlock
    jsl ChangeBlock
NotDown:

  bra BlockPushForwardCleanup
.endproc




.a16
.proc BlockPushBlock
TempPtr = BlockTemp + 2
  ; Fail to push if no actor slots free
  jsl FindFreeActorY
  bcs :+
  rts
:

  ; Get the X and Y positions from the block itself
  jsl GetBlockXCoord
  ora #$80
  sta ActorPX,y
  ; ---
  jsl GetBlockYCoord
  add #$0100
  sta ActorPY,y

  ; Determine if pushing from the left (go right) or pushing from the right (go left)
  lda PlayerPX
  cmp ActorPX,y
  lda #0
  adc #0 ; 0 if push right, 1 if push left
  sta ActorVarC,y

  ; Copy over the old block pointer, so it can change the InvisibleWall to nothing once it's done moving
  lda LevelBlockPtr
  sta ActorVarA,y
  sta TempPtr

  ; Don't try to push if there's a block above
  dea
  dea
  sta LevelBlockPtr
  lda [LevelBlockPtr]
  cmp #Block::PushBlock
  beq Nevermind
  cmp #Block::InvisibleWall
  beq Nevermind
  inc LevelBlockPtr
  inc LevelBlockPtr

  lda #8
  sta ActorTimer,y
  lda #0
  sta ActorDirection,y ; Also zeros state, since it's 16-bit
  sta ActorVY,y

  ; Calculate the pointer we're pushing into
  lda ActorVarC,y
  beq PushRight
PushLeft:
  lda LevelBlockPtr
  sub LevelColumnSize
  bra WasPushLeft
PushRight:
  lda LevelBlockPtr
  add LevelColumnSize
WasPushLeft:
  sta ActorVarB,y

  ; Also check for an invisible wall in front and above
  dea
  dea
  sta LevelBlockPtr
  lda [LevelBlockPtr]
  cmp #Block::InvisibleWall
  beq Nevermind
  inc LevelBlockPtr
  inc LevelBlockPtr

  ; Try to climb otherwise
  lda [LevelBlockPtr]
  beq DontClimb
  lda #.loword(-2*16) ; Go upward
  sta ActorVY,y
  dec LevelBlockPtr
  dec LevelBlockPtr
  lda LevelBlockPtr
  sta ActorVarB,y ; Update the destination block
  lda [LevelBlockPtr]
  bne Nevermind
DontClimb:
  ; Destination should be a barrier too
  lda #Block::InvisibleWall
  jsl ChangeBlock

  ; Set the type, which actually activates everything
  lda #Actor::ActivePushBlock*2
  sta ActorType,y

  ; Change LevelBlockPtr back
  lda TempPtr
  sta LevelBlockPtr

  ; Change the old block to a barrier
  lda #Block::InvisibleWall
  jsl ChangeBlock
  rts

Nevermind:
  ; Change LevelBlockPtr back anyway
  lda TempPtr
  sta LevelBlockPtr
  rts
.endproc

.a16
.proc BlockPrize
  jsl GetOneCoin

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
    lda #30
    sta ParticleTimer,y
    lda #.loword(-$30)
    sta ParticleVY,y

    jsl RandomByte
    and #7
    jsl VelocityLeftOrRight
    sta ParticleVX,y

    jmp ParticleAtBlock
  :
  rts
.endproc

.proc BlockBricks
  lda #Block::Empty
  jsl ChangeBlock

  jsr Create
  jmp Create

Create:
  ; Create one facing right
  jsl FindFreeParticleY
  bcc :+
    jsl RandomByte
    and #15
    sta ParticleVX,y

    jsr Common
  :

  ; Create one facing left
  jsl FindFreeParticleY
  bcc :+
    jsl RandomByte
    and #15
    eor #$ffff
    inc a
    sta ParticleVX,y
    bra Common
  :
  rts

Common:
  jsl RandomByte
  and #15
  add #.loword(-$30)
  sta ParticleVY,y

  lda #30
  sta ParticleTimer,y

  lda #Particle::BricksParticle
  sta ParticleType,y
  jsr ParticleAtBlock
  rts
.endproc

.proc BlockSign
  lda keynew
  and #KEY_UP
  beq :+
    pha
    jsl GetBlockX
    asl
    tax
    seta8
    lda f:ColumnWords+0,x
    sta ScriptPointer+0
    lda f:ColumnWords+1,x
    sta ScriptPointer+1
    lda f:ColumnWords+2,x
    sta ScriptPointer+2
    seta16
    .import StartDialog
    jsl StartDialog
    .import ReuploadSpritePalettes
    jsl ReuploadSpritePalettes
    plx
  :
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
  stz PlayerNeedsGround
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

.a16
.proc BlockLadder
  seta8
  lda PlayerOnLadder
  beq :+
    inc PlayerOnLadder
  :
  lda PlayerRidingSomething
  bne Exit
  seta16

  lda keydown
  and #KEY_UP|KEY_DOWN
  beq :+
GetOnLadder:
    ; Snap onto the ladder
    lda PlayerPX
    and #$ff00
    ora #$0080
    sta PlayerPX
    stz PlayerVX

    seta8
    lda #2
    sta PlayerOnLadder
Exit:
    seta16
  :
  rts
.endproc

.a16
.proc BlockLadderTop
  ; Make sure you're standing on it
  jsl GetBlockXCoord
  xba
  seta8
  cmp PlayerPX+1
  seta16
  beq :+
    rts
  :

  seta8
  lda PlayerDownTimer
  cmp #4
  bcc :+
    lda #2
    sta ForceControllerTime
    seta16
    lda #KEY_DOWN
    sta ForceControllerBits
    stz BlockFlag
    jmp BlockLadder::GetOnLadder
  :
  seta16
  rts
.endproc

.a16
.proc BlockFallthrough
  seta8
  lda PlayerDownTimer
  cmp #16
  bcc :+
    lda #2
    sta ForceControllerTime
    seta16
    lda #KEY_DOWN
    sta ForceControllerBits
    stz BlockFlag
  :
  seta16
  rts
.endproc

.a16
.proc ParticleAtBlock
  jsl GetBlockXCoord
  ora #$80
  sta ParticlePX,y

  jsl GetBlockYCoord
  ora #$80
  sta ParticlePY,y
  rts
.endproc

.a16
.i16
.proc BlockDoor
  lda keynew
  and #KEY_UP
  bne Up
  rts
Up:
  dec LevelBlockPtr
  dec LevelBlockPtr
  lda [LevelBlockPtr]
  cmp #Block::DoorExit
  beq DoorExit
DoorNormal:
  rts
DoorExit:
  .import ExitToOverworld
  jml ExitToOverworld
.endproc

.a16
.i16
.proc BlockCeilingBarrier
  lda #$40
  sta PlayerVY
  rts
.endproc

.a16
.i16
.proc BlockKey
  lda [LevelBlockPtr]
  sub #Block::HeartsKey
  lsr
  add #InventoryItem::HeartsKey
  jsl InventoryGiveItem
  bcs :+
    rts
  :

  lda #Block::Empty
  jsl ChangeBlock

  jsl FindFreeParticleY
  bcc :+
    lda #Particle::LandingParticle
    sta ParticleType,y
    jmp ParticleAtBlock
  :
  rts
.endproc

.a16
.i16
.export BlockLockTop
.proc BlockLockTop
  lda [LevelBlockPtr]
  sub #Block::HeartsLockTop
  lsr
  add #InventoryItem::HeartsKey
  jsl InventoryTakeItem
  bcc :+
    lda #Block::Empty
    jsl ChangeBlock
    inc LevelBlockPtr
    inc LevelBlockPtr
    lda #Block::Empty
    jsl ChangeBlock
    dec LevelBlockPtr ; Maybe not required?
    dec LevelBlockPtr
  :
  rts
.endproc

.a16
.i16
.export BlockLock
.proc BlockLock
  lda [LevelBlockPtr]
  sub #Block::HeartsLock
  lsr
  add #InventoryItem::HeartsKey
  jsl InventoryTakeItem
  bcc :+
    lda #Block::Empty
    jsl ChangeBlock

    jsr BlockBricks::Create
    jsr BlockBricks::Create
  :
  rts
.endproc
