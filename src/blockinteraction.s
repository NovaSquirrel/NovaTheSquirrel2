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

.segment "C_BlockInteraction"

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

.a16
.proc BlockPickupBlock
  lda PlayerHoldingSomething
  lsr
  bcc :+
    rts
  :

  inc OfferAPress
  lda #KEY_A
  bit keynew
  bne :+
    rts
  :
  trb keynew

  ; See if maybe there's another block directly underneath to switch to
  lda LevelBlockPtr
  sta BlockTemp
  lda PlayerPX
  ldy PlayerPY
  jsl GetLevelPtrXY
  cmp #Block::PickupBlock
  beq :+
    ; Can't retarget, put it back
    lda BlockTemp
    sta LevelBlockPtr
  :

  ; Try picking it up - need to find an object
  jsl FindFreeActorY
  bcs :+
  rts
:
  ; Make the carried block
  lda #Actor::ActivePickupBlock*2
  sta ActorType,y
  lda PlayerPX
  sta ActorPX,y
  lda PlayerPY
  sta ActorPY,y
  lda #ActorStateValue::Carried
  sta ActorState,y
  tdc ; Clear accumulator
  sta ActorVX,y
  sta ActorVY,y
  seta8
  sta ActorDirection,y
  seta16
  inc PlayerHoldingSomething ; 8-bit variable but that's ok

  ; And get rid of the old block
  lda #Block::Empty
  jsl ChangeBlock
  jmp PoofAtBlock
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
;  ora #$80 <-- was $80 for BlockPushForwardCleanup - why?
  ora #$40 ; <-- Cancels out offset in object.s ParticleDrawPosition - maybe just not have the offset?
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
  jsr PoofAtBlock

  jsr Create
;  jmp Create

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

.export CreateBrickBreakParticles
.proc CreateBrickBreakParticles
  jsr BlockBricks::Create
  jsr BlockBricks::Create
  rtl
.endproc

.export CreateGrayBrickBreakParticles
.proc CreateGrayBrickBreakParticles
  jsr Create
  jsr Create
  rtl
Create:
  ; Create one facing right
  jsl FindFreeParticleY
  bcc :+
    jsl RandomByte
    and #15
    sta ParticleVX,y

    jsr BlockBricks::Common
    lda #Particle::GrayBricksParticle
    sta ParticleType,y
  :

  ; Create one facing left
  jsl FindFreeParticleY
  bcc :+
    jsl RandomByte
    and #15
    eor #$ffff
    inc a
    sta ParticleVX,y

    jsr BlockBricks::Common
    lda #Particle::GrayBricksParticle
    sta ParticleType,y
  :
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
  .import HurtPlayer
  jsl HurtPlayer
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
  ; but only if the spring isn't scheduled to disappear before it'd pop back up
  ldx #(MaxDelayedBlockEdits-1)*2
DelayedBlockLoop:
  ; Count down the timer, if there is a timer
  lda DelayedBlockEditTime,x
  beq :+
    ; Is it this block?
    lda DelayedBlockEditAddr,x
    cmp LevelBlockPtr
    bne :+
    lda DelayedBlockEditTime,x
    cmp #6
    bcc DontSpringUp
: dex
  dex
  bpl DelayedBlockLoop

  ; No problems? Go ahead and schedule it
  lda #5
  sta BlockTemp
  lda #Block::Spring
  jsl DelayChangeBlock
DontSpringUp:

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
.export BlockWater
.proc BlockWater
  seta8
  lda PlayerInWater
  bne :+
    lda PlayerVY+1
    bmi :+
      stz PlayerVY
      stz PlayerVY+1
  :
  lda #2
  sta PlayerInWater
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
  jsl GetBlockX
  bra TeleportAtColumn
DoorExit:
  .import ExitToOverworld
  jsr DoorFade
  jsl WaitVblank
  jml ExitToOverworld
.endproc

.a16
.i16
.proc TeleportAtColumn
  asl
  tax
  seta8
  lda f:ColumnWords+0,x
  cmp #$20
  beq LevelDoor
    sta PlayerPY+1
    lda f:ColumnWords+1,x
    sta PlayerPX+1
    lda #$80        ; Horizontally centered
    sta PlayerPX
    stz PlayerPY
    stz LevelFadeIn ; Start fading in after the transition

    jsr DoorFade

    lda #RERENDER_INIT_ENTITIES_TELEPORT
    sta RerenderInitEntities

    stz LevelIrisIn ; Start the iris effect again
    seta16

    jsl RenderLevelScreens
    rts
LevelDoor:
  lda f:ColumnWords+1,x
  pha
  jsr DoorFade
  pla

  ; Find the level header pointer
  setaxy16
  and #255 ; Multiply by 3
  sta 0
  asl
  adc 0 ; assert((PS & 1) == 0) Carry will be clear
  tax
  seta8
  .import DoorLevelTeleportList
  ; Use DoorLevelTeleportList to find the header
  lda DoorLevelTeleportList+0,x
  sta LevelHeaderPointer+0
  lda DoorLevelTeleportList+1,x
  sta LevelHeaderPointer+1
  lda DoorLevelTeleportList+2,x
  sta LevelHeaderPointer+2
  setaxy16

  .import StartLevelFromDoor
  jml StartLevelFromDoor
.endproc

.proc DoorFade
  seta8
  .import IrisInitTable, IrisUpdate, IrisInitHDMA, IrisDisable
  jsl IrisInitTable
  ; Fade the screen out and then disable rendering once it's black
  lda #$0e
  sta 15
FadeOut:
  inc framecount
  lda PlayerDrawX
  sta 0
  lda PlayerDrawY
  sub #16
  sta 1
  lda 15
  jsl IrisUpdate    
  jsl WaitVblank
  jsl IrisInitHDMA
  seta8
  lda HDMASTART_Mirror
  sta HDMASTART

  lda 15
  sta PPUBRIGHT
  dec
  sta 15
  bne FadeOut

  jsl IrisDisable
  lda #FORCEBLANK
  sta PPUBRIGHT
  rts
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

.a16
.i16
.export BlockWoodCrate
.proc BlockWoodCrate
  dec LevelBlockPtr
  dec LevelBlockPtr
  lda [LevelBlockPtr]
  inc LevelBlockPtr
  inc LevelBlockPtr
  cmp #Block::WoodCrate

  lda #16
  sta BlockTemp
  lda #Block::Empty
  jsl DelayChangeBlock
  lda #Block::Spring
  jsl ChangeBlock
  jsr BlockBricks::Create
  jsr BlockBricks::Create

  ; Snap player to the block
;  jsl GetBlockYCoord
;  cmp PlayerPY        <-- original checks if player is actually above the block, seems to work without it
;  bcc NoSnap              (probably since it originally responded from all edges instead of only the top)
    jsl GetBlockXCoord
    add #$0088
    sta PlayerPX
    stz PlayerVX
    seta8
    lda #3
    sta PlayerWalkLock
    seta16
  NoSnap:
  rts
.endproc

.a16
.i16
.export BlockWoodArrow
.proc BlockWoodArrow
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

  lda #Actor::FlyingArrow*2
  sta ActorType,y

  lda [LevelBlockPtr]
  sub #Block::WoodArrowRight
  sta ActorVarA,y ; Already an even number so it can be plugged into a 16-bit table later

  lda #120
  sta ActorTimer,y

  ; Remove the block
  lda #Block::Empty
  jsl ChangeBlock
  jsr BlockBricks::Create
  jsr BlockBricks::Create
  rts
.endproc

.a16
.i16
.export BlockAnimateGrass
.proc BlockAnimateGrass
  lda #Block::GrassSteppedOn
  cmp [LevelBlockPtr]
  beq AlreadyDown
  ; Now write the new block
  jsl ChangeBlock
  lda #10
  sta BlockTemp
  lda #Block::Grass
  jsl DelayChangeBlock
  rts

AlreadyDown:
  ; Find the delayed edit slot, increase the time
  jsr FindDelayedEditForBlock
  bcc :+
    lda #10
    sta DelayedBlockEditTime,x
  :
  rts
.endproc

.proc FindDelayedEditForBlock
  ldx #(MaxDelayedBlockEdits-1)*2
DelayedBlockLoop:
  ; Count down the timer, if there is a timer
  lda DelayedBlockEditTime,x
  beq :+
    ; Is it this block?
    lda DelayedBlockEditAddr,x
    cmp LevelBlockPtr
    beq Yes
: dex
  dex
  bpl DelayedBlockLoop
  clc
  rts
Yes:
  sec
  rts
.endproc

.a16
.i16
.export BlockToggleSwitch
.proc BlockToggleSwitch
Color = BlockTemp
Value = BlockTemp+2
  .import File_FGToggleBlocks, File_FGToggleBlocksSwapped
  lda [LevelBlockPtr]
  sub #Block::Toggle1Switch
  lsr
  sta Color
  tay
  seta8
  lda ToggleSwitch1,y
  eor #1
  sta ToggleSwitch1,y
  sta Value
  seta16

  ; Make the graphical change
  phx
  tya
  xba ; * 256
  lsr
  add #$4A00>>1
  tax ; X = VRAM destination
  ldy #256 ; Copy 256 bytes

  ; Calculate source address
  lda #^File_FGToggleBlocks
  sta 0
  lda Color
  xba
  add #.loword(File_FGToggleBlocks)
  lsr Value
  bcc :+
    lda #^File_FGToggleBlocksSwapped
    sta 0
    lda Color
    xba
    add #.loword(File_FGToggleBlocksSwapped)
  :
  jsl QueueGenericUpdate
  plx

  ; -------------------------
  ; Animate the switch itself
  lda #60
  sta BlockTemp
  lda [LevelBlockPtr]
  jsl DelayChangeBlock
  lda [LevelBlockPtr]
  add #3*2
  jsl ChangeBlock
  rts
.endproc

.a16
.i16
.export BlockToggleNonsolid
.proc BlockToggleNonsolid
  ; Determine which flag should be checked
  lda [LevelBlockPtr]
  sub #Block::Toggle1BlockNonsolid
  lsr
  tay

  ; Become solid if the flag is set
  lda ToggleSwitch1,y
  lsr
  bcc :+
     lda #$c000
     sta BlockFlag
  :
  rts
.endproc

.a16
.i16
.export BlockToggleSolid
.proc BlockToggleSolid
  ; Determine which flag should be checked
  lda [LevelBlockPtr]
  sub #Block::Toggle1BlockSolid
  lsr
  tay

  ; Become nonsolid if the flag is set
  lda ToggleSwitch1,y
  lsr
  bcc :+
     stz BlockFlag
  :
  rts
.endproc

.a16
.i16
.export BlockIceMelt
.proc BlockIceMelt
  lda ActorType,x
  cmp #Actor::PlayerProjectile16x16*2
  beq :+
  cmp #Actor::PlayerProjectile*2
  bne Exit
:

  lda ActorProjectileType,x
  cmp #PlayerProjectileType::FireBall
  beq Melt
  cmp #PlayerProjectileType::FireStill
  bne Exit
Melt:
  ; Change to nothing
  tdc
  jsl ChangeBlock
  jsr PoofAtBlock
Exit:
  rts
.endproc
