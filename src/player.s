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
.smart

.import BlockRunInteractionAbove, BlockRunInteractionBelow
.import BlockRunInteractionSide,  BlockRunInteractionInsideHead
.import BlockRunInteractionInsideBody

.segment "ZEROPAGE"

.segment "Player"
.importzp SlopeBCC, SlopeBCS
.import SlopeHeightTable, SlopeFlagTable

NOVA_WALK_SPEED = 2
NOVA_RUN_SPEED = 4
;AccelSpeeds: .byt 2,        4
;DecelSpeeds: .byt 4,        8

.a16
.i16
.proc RunPlayer
Temp = 2
SideXPos = 8
BottomCmp = 8

SlopeY = 6
MaxSpeedLeft = 10
MaxSpeedRight = 12
  phk
  plb

  seta8
  countdown JumpGracePeriod
  countdown PlayerWantsToJump
  countdown PlayerWantsToAttack
  countdown PlayerJumpCancelLock
  countdown PlayerOnLadder
  countdown PlayerInWater
  countdown PlayerInvincible
  countdown PlayerWalkLock
  stz PlayerOnSlope


  ; Tap run
  lda UseTapRun
  beq NoTapRun
    countdown TapReleaseTimer

    ; Set off a timer when you release left/right
    lda keydown+1
    eor #$ff
    and keylast+1
    and #>(KEY_LEFT|KEY_RIGHT)
    beq :+
      sta TapReleaseButton
      lda #14
      sta TapReleaseTimer
    :

    ; Allow the tap run to start
    lda keynew+1
    and #>(KEY_LEFT|KEY_RIGHT)
    beq :+
      ; Same button?
      and TapReleaseButton
      beq :+
      lda TapReleaseTimer
      beq :+
        lda #1
        sta PlayerWasRunning
        sta IsTapRun
    :

    ; Release a tap run
    lda IsTapRun
    beq :+
      lda keydown+1
      and #>(KEY_LEFT|KEY_RIGHT)
      bne :+
        lda PlayerOnGround
        beq :+
          stz PlayerWasRunning 
          stz IsTapRun
    :
  NoTapRun:

  ; Hackish workaround for abilities that end when you press the attack button
  ; so that they don't immediately trigger again
  lda TailAttackCooldown
  beq :+
    dec TailAttackCooldown
    bra CantAttack
  :

  lda keynew
  and #AttackKeys
  beq :+
    lda #3
    sta PlayerWantsToAttack
  :

  ; Start off an attack
  lda PlayerWantsToAttack
  beq :+
    lda PlayerRolling
    bne :+
    lda TailAttackTimer
    bne :+
      stz PlayerWantsToAttack
      inc TailAttackTimer
      stz TailAttackVariable+0
      stz TailAttackVariable+1
      lda keydown+1
      sta TailAttackDirection
      lda PlayerNeedsGround
      sta PlayerNeedsGroundAtAttack
  :
CantAttack:

  ; Continue an attack that was started
  lda TailAttackTimer
  beq :+
    tdc ; Clear A
    lda PlayerAbility
    asl
    tax
    php
    .import AbilityRoutineForId
    .assert ^RunPlayer = ^AbilityRoutineForId, error, "AbilityRoutineForId not in player bank"
    jsr (.loword(AbilityRoutineForId),x)
    plp
  :


  lda ForceControllerTime
  beq :+
     seta16
     lda ForceControllerBits
     tsb keydown
     seta8

     dec ForceControllerTime
     bne @NoCancelForce
       stz ForceControllerBits+0
       stz ForceControllerBits+1
     @NoCancelForce:
  :

  lda keydown+1
  and #>KEY_DOWN
  beq NotDown
    lda PlayerDownTimer
    cmp #60
    bcs YesDown
    inc PlayerDownTimer
    bne YesDown
  NotDown:
    stz PlayerDownTimer
  YesDown:

  lda keynew+1
  and #(KEY_B>>8)
  beq :+
    lda #3
    sta PlayerWantsToJump
  :

  ; Horizontal movement

  ; Calculate max speed from whether they're running or not
  ; (Updated only when on the ground)

  lda PlayerWasRunning ; nonzero = B button, only updated when on ground
  seta16
  beq :+
    lda #.loword(-(NOVA_RUN_SPEED*16)-1)
    sta MaxSpeedLeft
    lda #NOVA_RUN_SPEED*16
    sta MaxSpeedRight
    bra NotWalkSpeed
: lda #.loword(-(NOVA_WALK_SPEED*16)-1)
  sta MaxSpeedLeft
  lda #NOVA_WALK_SPEED*16
  sta MaxSpeedRight
NotWalkSpeed:

  ; Don't walk if the ability prevents it
  lda AbilityMovementLock
  ora PlayerWalkLock
  lsr
  bcs NotWalk

  ; Handle left and right
  lda keydown
  and #KEY_LEFT
  beq NotLeft
  lda ForceControllerBits
  and #KEY_RIGHT
  bne NotLeft
    seta8
    lda TailAttackTimer
    bne :+
      lda #1
      sta PlayerDir
    :
    seta16
    lda PlayerVX
    bpl :+
    cmp MaxSpeedLeft ; can be either run speed or walk speed
    bcc NotLeft
    cmp #.lobyte(-NOVA_RUN_SPEED*16-1)
    bcc NotLeft
:   sub #2 ; Acceleration speed
    sta PlayerVX
NotLeft:

  lda keydown
  and #KEY_RIGHT
  beq NotRight
  lda ForceControllerBits
  and #KEY_LEFT
  bne NotRight
    seta8
    lda TailAttackTimer
    bne :+
      stz PlayerDir
    :
    seta16
    lda PlayerVX
    bmi :+
    cmp MaxSpeedRight ; can be either run speed or walk speed
    bcs NotRight
    cmp #NOVA_RUN_SPEED*16
    bcs NotRight
:   add #2 ; Acceleration speed
    sta PlayerVX
NotRight:
NotWalk:

  ; Decelerate
  lda #4
  sta Temp

  ; Still decelerate if movement lock is on and you hold the button
  lda AbilityMovementLock
  lsr
  bcs DecelerateAnyway

  ; Adjust the deceleration speed if you're trying to turn around
  lda keydown
  and #KEY_LEFT
  beq :+
    lda PlayerVX
    bmi IsMoving
    lsr Temp
  :
  lda keydown
  and #KEY_RIGHT
  beq :+
    lda PlayerVX
    beq Stopped
    bpl IsMoving
    lsr Temp
  :
DecelerateAnyway:
  lda PlayerVX
  beq Stopped
    ; If negative, make positive
    php ; Save if it was negative
    bpl :+
      eor #$ffff
      ina
    :

    sub Temp ; Deceleration speed
    bpl :+
      tdc ; Clear accumulator
    :

    ; If negative, make negative again
    plp
    bpl :+
      eor #$ffff
      ina
    :

    sta PlayerVX
Stopped:
IsMoving:

   ; Another deceleration check; apply if you're moving faster than the max speed
   lda PlayerVX
   php
   bpl :+
     eor #$ffff
     ina
   :
   cmp MaxSpeedRight
   beq NoFixWalkSpeed ; If at or less than the max speed, don't fix
   bcc NoFixWalkSpeed
   sub #4
NoFixWalkSpeed:
   plp
   bpl :+
     eor #$ffff
     ina
   :
   sta PlayerVX


  ; Apply speed
  lda PlayerPX
  add PlayerVX
  sta PlayerPX


  ; Going downhill requires special help
  seta8
  lda PlayerOnGround ; Need to have been on ground last frame
  beq NoSlopeDown
  lda PlayerWantsToJump
  bne NoSlopeDown
  seta16
  lda PlayerVX     ; No compensation if not moving
  beq NoSlopeDown
    jsr GetSlopeYPos
    bcs :+
      ; Try again one block below
      inc LevelBlockPtr
      inc LevelBlockPtr
      lda [LevelBlockPtr]
      jsr GetSlopeYPosBelow
      bcc NoSlopeDown
    :

    lda SlopeY
    sta PlayerPY
    stz PlayerVY
  NoSlopeDown:
  seta16

  ; Check for moving into a wall on the right
  lda PlayerVX
  bmi SkipRight
  lda PlayerPX
  add #3*16
  sta SideXPos

  ; Right middle
  lda PlayerPY
  sub #12*16
  tay
  lda SideXPos
  jsr TryRightInteraction
  ; Right head
  lda PlayerPY
  sub #16*23 ;#16*16+14*16 ; Top of the head
  tay
  lda SideXPos
  jsr TryRightInteraction
SkipRight:

  ; -------------------------

  lda PlayerVX
  beq :+
  bpl SkipLeft
:
  ; Check for moving into a wall on the left
  lda PlayerPX
  sub #4*16
  sta SideXPos

  ; Left middle
  lda PlayerPY
  sub #12*16
  tay
  lda SideXPos
  jsr TryLeftInteraction
  ; Left head
  lda PlayerPY
  sub #16*23 ;#16*16+14*16 ; Top of the head
  tay
  lda SideXPos
  jsr TryLeftInteraction
SkipLeft:

  ; -------------------  

  lda PlayerOnLadder
  and #255
  bne HandleLadder
  lda PlayerInWater
  and #255
  bne PlayerHandleWater

  ; Vertical movement
  lda PlayerVY
  bmi GravityAddOK
  cmp #$60
  bcs SkipGravity
GravityAddOK:
  add #4
  sta PlayerVY
SkipGravity:
  add PlayerPY ; Apply the vertical speed
  sta PlayerPY
SkipApplyGravity:
  jmp PlayerIsntOnLadder

PlayerHandleWater:
  seta8
  stz PlayerNeedsGround
  seta16
  jsr OfferJump
  lda PlayerVY
  bmi @GravityAddOK
  cmp #$60
  bcs @SkipGravity
@GravityAddOK:
  add #2
  sta PlayerVY
@SkipGravity:
  cmp #$8000
  ror
  add PlayerPY ; Apply the vertical speed/2
  sta PlayerPY
@SkipApplyGravity:
  jmp PlayerIsntOnLadder

HandleLadder:
  stz PlayerVY
  jsr OfferJump
  lda keydown
  and #KEY_UP
  beq :+
    lda PlayerPY
    sub #$20
    sta PlayerPY
  :
  lda keydown
  and #KEY_DOWN
  beq :+
    lda PlayerPY
    add #$20
    sta PlayerPY
  :
PlayerIsntOnLadder:



  ; Allow canceling a jump
  lda PlayerVY
  bpl :+
    seta8
    lda PlayerJumpCancel
    bne :+
    lda keydown+1
    and #(KEY_B>>8)
    bne :+
      lda PlayerJumpCancelLock
      bne :+
        inc PlayerJumpCancel

        ; Reduce the jump to a small upward boost
        ; (unless the upward movement is already less than that)
        seta16
        lda PlayerVY
        cmp #.loword(-$20)
        bcs :+
        lda #.loword(-$20)
        sta PlayerVY
  :

  ; Cancel the jump cancel
  seta8
  lda PlayerOnGround
  sta PlayerOnGroundLast
  stz PlayerOnGround
  lda PlayerJumpCancel
  beq :+
    lda PlayerVY+1
    sta PlayerJumpCancel
  :
  seta16

  ; Collide with the ground
  ; (Determine if solid all must be set, or solid top)
  lda #$8000
  sta BottomCmp
  lda PlayerVY
  bmi :+
    seta8
    stz PlayerJumping
    seta16
    lda PlayerPY
    and #$80
    bne :+
      lda #$4000
      sta BottomCmp
  :

  ; Slope interaction
  jsr GetSlopeYPos
  bcc NoSlopeInteraction
    lda SlopeY
    cmp PlayerPY
    bcs NoSlopeInteraction
    
    sta PlayerPY
    stz PlayerVY

    ; Some unnecessary shifting, since this was previously shifted left
    ; and we're just undoing it, but the alternative is probably storing
    ; to PlayerSlopeType in every IsSlope call and I'd rather not.
    txa
    lsr
    lsr
    lsr
    lsr
    and #.loword(~1)
    sta PlayerSlopeType

    seta8
    inc PlayerOnSlope
    inc PlayerOnGround
    stz PlayerNeedsGround

    ; Start rolling
    lda PlayerDownTimer
    cmp #6
    bcc :+
      lda PlayerWantsToJump
      beq :+
        lda PlayerRidingSomething
        bne :+
          stz PlayerWantsToJump
          lda #1
          sta PlayerRolling
    :
    seta16

    ; Perform rolling
    lda PlayerRolling
    and #255
    beq :+
       seta8
       lda #2
       sta ForceControllerTime
       seta16
       ; Force left or right based on the slope direction
       lda #KEY_RIGHT|KEY_Y
       sta ForceControllerBits

       ldx PlayerSlopeType
       lda f:SlopeFlagTable,x
       bpl :+
         lda #KEY_LEFT|KEY_Y
         sta ForceControllerBits
    :
 
    ; Don't do the normal ground check
    bra SkipGroundCheck
  NoSlopeInteraction:

  lda PlayerVY
  bmi :+
  ; Left foot
  ldy PlayerPY
  lda PlayerPX
  sub #4*16
  jsr TryAboveInteraction
  ; Right foot
  ldy PlayerPY
  lda PlayerPX
  add #3*16
  jsr TryAboveInteraction
:
SkipGroundCheck:

  ; Above
  lda PlayerPY
  sub #PlayerHeight ; Top of the head
  sta PlayerPYTop   ; Used in collision detection with enemies
  tay
  lda PlayerPX
  jsr TryBelowInteraction

  ; Inside
  lda PlayerPY
  sub #8*16
  tay
  lda PlayerPX
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionInsideBody


  bit TwoLayerInteraction-1
  bpl :+
    jsr PlayerSecondLayerInteraction
  :


  ; -------------------
  lda PlayerWasRunning
  and #255
  beq :+
    lda retraces
    and #7
    bne :+
    jsl FindFreeParticleY
    bcc :+
    lda #Particle::LandingParticle
    sta ParticleType,y
    lda PlayerPX
    sta ParticlePX,y
    lda PlayerPY
    sta ParticlePY,y
  :
  
  ; Particle effect if on the ground but wasn't last frame
  seta8
  lda PlayerOnGround
  beq :+
  lda PlayerOnGroundLast
  bne :+
    seta16
    jsl FindFreeParticleY
    bcc :+
    lda #Particle::LandingParticle
    sta ParticleType,y
    lda PlayerPX
    sta ParticlePX,y
    lda PlayerPY
    sta ParticlePY,y
  :
  ; Don't change back, will be changed back by the seta8



  ; Offer a jump if not on ground and the grace period is still active
  seta8
  lda PlayerOnGround
  bne :+
  lda JumpGracePeriod
  beq :+
    seta16
    jsr OfferJumpFromGracePeriod
  :
  seta16

  ; If on the ground, offer a jump
  seta8
  stz PlayerRidingSomething
  lda PlayerOnGround
  seta16
  beq @NotOnGround
    jsr OfferJump

    seta8
    ; Update roll status
    lda PlayerOnSlope
    bne @NoCancelRoll
      stz PlayerRolling
    @NoCancelRoll:

    ; Update run status
    lda IsTapRun
    bne :+
      ;lda keydown
      ;and #KEY_R|KEY_L
      ;sta PlayerWasRunning
      ;lda keydown+1
      ;and #KEY_Y>>8
      ;tsb PlayerWasRunning
      lda keydown+1
      and #>KEY_Y
      sta PlayerWasRunning
    :
    seta16
  @NotOnGround:
  rtl

TryBelowInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionBelow

  lda BlockFlag
  bpl @NotSolid
    lda PlayerVY
    bpl :+
      stz PlayerVY
    :

    lda PlayerPY
    and #$ff00
    ora #14*16
    sta PlayerPY
  @NotSolid:
  rts

TryAboveInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionAbove
  ; Solid?
  lda BlockFlag
  cmp BottomCmp
  bcc :+
    lda #$00ff
    trb PlayerPY
HasGroundAfterAll:
    stz PlayerVY

    seta8
    inc PlayerOnGround
    stz PlayerOnLadder
    lda PlayerRidingSomething
    bne DoesntCount
      stz PlayerNeedsGround
    DoesntCount:
    seta16
    rts
  :

  ; Riding on something forces it to act like you are standing on solid ground
  lda PlayerRidingSomething
  and #255
  bne HasGroundAfterAll
  rts

TryLeftInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionSide
  ; Solid?
  lda BlockFlag
  bpl @NotSolid
    ; Left
    lda PlayerPX
    sub PlayerVX ; Undo the horizontal movement
    and #$ff00   ; Snap to the block
    add #4*16    ; Add to the offset to press against the block
    sta PlayerPX
    stz PlayerVX ; Stop moving horizontally
  @NotSolid:
  rts

TryRightInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionSide
  ; Solid?
  lda BlockFlag
  bpl @NotSolid
    ; Right
    lda PlayerPX
    sub PlayerVX  ; Undo the horizontal movement
    and #$ff00    ; Snap to the block
    add #12*16+12 ; Add the offset to press against the block
    sta PlayerPX
    stz PlayerVX  ; Stop moving horizontally
  @NotSolid:
  rts


.a16
; Get the Y position of the slope under the player's hotspot (SlopeY)
; and also return if they're on a slope at all (carry)
GetSlopeYPos:
  ldy PlayerPY
  lda PlayerPX
  jsl GetLevelPtrXY
  jsr IsSlope
  bcc NotSlope
    lda PlayerPY
    and #$ff00
    ora f:SlopeHeightTable,x
    sta SlopeY

    lda f:SlopeHeightTable,x
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr IsSlope
      bcc :+
        lda PlayerPY
        sbc #$0100 ; assert((PS & 1) == 1) Carry already set
        ora f:SlopeHeightTable,x
        sta SlopeY
    :
  sec
NotSlope:
  rts

.a16
; Similar but for checking one block below
GetSlopeYPosBelow:
  jsr IsSlope
  bcc NotSlope
    lda PlayerPY
    add #$0100
    and #$ff00
    ora f:SlopeHeightTable,x
    sta SlopeY

    lda f:SlopeHeightTable,x
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr IsSlope
      bcc :+
        lda PlayerPY
        ora f:SlopeHeightTable,x
        sta SlopeY
    :
  sec
  rts

.a16
; Determine if it's a slope (carry),
; but also determine the index into the height table (X)
IsSlope:
  cmp #SlopeBCC
  bcc :+
  cmp #SlopeBCS
  bcs :+
  sub #SlopeBCC
  ; Now we have the block ID times 2

  ; Multiply by 16 to get the index into the slope height table
  asl
  asl
  asl
  asl
  sta 0

  ; Select the column
  lda PlayerPX
  and #$f0 ; Get the pixels within a block
  lsr
  lsr
  lsr
  ora 0
  tax

  sec ; Success
  rts
: clc ; Failure
  rts

; Let the player jump if they press the button
.a16
OfferJump:
  seta8
  lda #7 ;JUMP_GRACE_PERIOD_LENGTH
  sta JumpGracePeriod
  seta16
OfferJumpFromGracePeriod:
  ; Newly pressed jump, either now or a few frames before
  lda PlayerWantsToJump
  and #255
  beq :+
  ; Still pressing the jump button
  lda keydown
  and #KEY_B
  beq :+
    seta8
    stz PlayerOnLadder
    stz JumpGracePeriod
    inc PlayerJumping
    seta16
    lda #.loword(-$50)
    sta PlayerVY
  :
  rts
.endproc

; Interact with the second foreground layer!
.proc PlayerSecondLayerInteraction
SideXPos = 8
BottomCmp = 8
  seta8
  stz PlayerRidingFG2
  seta16

  ; -----------------------------------
  ; Right
  ; -----------------------------------
  lda PlayerPX
  add FG2OffsetX
  add #3*16
  sta SideXPos

  ; Right middle
  lda PlayerPY
  add FG2OffsetY
  sub #12*16
  tay
  lda SideXPos
  jsr TryRightInteraction
  ; Right head
  lda PlayerPY
  add FG2OffsetY
  sub #16*23 ;#16*16+14*16 ; Top of the head
  tay
  lda SideXPos
  jsr TryRightInteraction

  ; -----------------------------------
  ; Left
  ; -----------------------------------
  lda PlayerPX
  add FG2OffsetX
  sub #4*16
  sta SideXPos
  
  ; Left middle
  lda PlayerPY
  add FG2OffsetY
  sub #12*16
  tay
  lda SideXPos
  jsr TryLeftInteraction
  ; Left head
  lda PlayerPY
  add FG2OffsetY
  sub #16*23 ;#16*16+14*16 ; Top of the head
  tay
  lda SideXPos
  jsr TryLeftInteraction

  ; -----------------------------------
  ; Floor
  ; -----------------------------------
  lda #$8000
  sta BottomCmp
  lda PlayerVY
  bmi :+
    seta8
    stz PlayerJumping
    seta16
    lda #$4000
    sta BottomCmp
  :

  lda PlayerVY
  bmi :+
  ; Left foot
  lda PlayerPY
  add FG2OffsetY
  tay
  lda PlayerPX
  add FG2OffsetX
  sub #4*16
  jsr TryAboveInteraction
  ; Right foot
  lda PlayerPY
  add FG2OffsetY
  tay
  lda PlayerPX
  add FG2OffsetX
  add #3*16
  jsr TryAboveInteraction
:

  ; -----------------------------------
  ; Ceiling
  ; -----------------------------------
  lda PlayerPY
  sub #PlayerHeight ; Top of the head
  add FG2OffsetY
  tay
  lda PlayerPX
  add FG2OffsetX
  jsr TryBelowInteraction
  rts


TryLeftInteraction:
  jsl GetLevelPtrXY
  jsr GetFG2BlockFlag
  jsl BlockRunInteractionSide
  ; Solid?
  lda BlockFlag
  bpl @NotSolid
    lda FG2OffsetX
    and #$00ff
    sta 0

    ; Left
    lda PlayerPX
    add 0
    sub PlayerVX ; Undo the horizontal movement
    and #$ff00   ; Snap to the block
    add #4*16    ; Add to the offset to press against the block
    sub 0
    sta PlayerPX
    stz PlayerVX ; Stop moving horizontally
    rts
  @NotSolid:
  rts

TryRightInteraction:
  jsl GetLevelPtrXY
  jsr GetFG2BlockFlag
  jsl BlockRunInteractionSide
  ; Solid?
  lda BlockFlag
  bpl @NotSolid
    lda FG2OffsetX
    and #$00ff
    sta 0

    ; Right
    lda PlayerPX
    add 0
    sub PlayerVX  ; Undo the horizontal movement
    and #$ff00    ; Snap to the block
    add #12*16+12 ; Add the offset to press against the block
    sub 0
    sta PlayerPX
    stz PlayerVX  ; Stop moving horizontally
    rts
  @NotSolid:
  rts

TryAboveInteraction:
  jsl GetLevelPtrXY
  jsr GetFG2BlockFlag
  jsl BlockRunInteractionAbove
  ; Solid?
  lda BlockFlag
  cmp BottomCmp
  bcc :+
    lda FG2OffsetY
    and #$00ff
    sta 0

    lda PlayerPY
    add 0
    and #$ff00
    sub 0
    sta PlayerPY
    
    sta PlayerPY
    stz PlayerVY

    seta8
    inc PlayerRidingFG2
    inc PlayerOnGround
    stz PlayerOnLadder
;    lda PlayerRidingSomething
;    bne DoesntCount
    stz PlayerNeedsGround
;    DoesntCount:
    seta16
    rts
  :
  rts

TryBelowInteraction:
  jsl GetLevelPtrXY
  jsr GetFG2BlockFlag
  jsl BlockRunInteractionBelow

  lda BlockFlag
  bpl @NotSolid
    lda FG2OffsetY
    and #$00ff
    sta 0

    lda PlayerVY
    bpl :+
      stz PlayerVY
    :

    lda PlayerPY
    add 0
    and #$ff00
    ora #14*16
    sub 0
    sta PlayerPY
  @NotSolid:
  rts

.endproc

.a16
.i16
.proc GetFG2BlockFlag
  lda #$4000
  tsb LevelBlockPtr
  lda [LevelBlockPtr]
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  rts
.endproc

; Damages the player
.export HurtPlayer
.proc HurtPlayer
  php
  seta8
  lda PlayerHealth
  beq :+
  lda PlayerInvincible
  bne :+
    dec PlayerHealth
    lda #160
    sta PlayerInvincible
  :
  plp
  rtl
.endproc

; Takes a speed in the accumulator, and negates it if player facing left
.a16
.export PlayerNegIfLeft
.proc PlayerNegIfLeft
  pha
  lda PlayerDir ; Ignore high byte
  lsr
  bcs Left
Right:
  pla ; No change
  rtl
Left:
  pla ; Negate
  neg
  rtl
.endproc
