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

.import BlockRunInteractionAbove, BlockRunInteractionBelow
.import BlockRunInteractionSide,  BlockRunInteractionInsideHead
.import BlockRunInteractionInsideBody
.import ActorClear

.segment "ZEROPAGE"

.segment "Player"
.importzp SlopeBCC, SlopeBCS
.import SlopeHeightTable, SlopeFlagTable

.a16
.i16
.import PlayerGraphics
.proc PlayerFrameUpload
  php
  seta16

  ; Set DMA parameters  
  lda #DMAMODE_PPUDATA
  sta DMAMODE+$00
  sta DMAMODE+$10

  lda PlayerFrame
  and #255         ; Zero extend
  xba              ; *256
  asl              ; *512
  ora #$8000
  sta DMAADDR+$00
  ora #256
  sta DMAADDR+$10

  lda #32*8 ; 8 tiles for each DMA
  sta DMALEN+$00
  sta DMALEN+$10

  lda #($8000)>>1
  sta PPUADDR
  seta8
  lda #^PlayerGraphics
  sta DMAADDRBANK+$00
  sta DMAADDRBANK+$10

  lda #%00000001
  sta COPYSTART

  ; Bottom row -------------------
  seta16
  lda #($8200)>>1
  sta PPUADDR
  seta8
  lda #%00000010
  sta COPYSTART

  ; -----------------------------------
  ; Is there an ability icon to copy in?
  lda NeedAbilityChange
  beq NoNeedAbilityChange
    lda #^AbilityIcons
    sta DMAADDRBANK+$00
    sta DMAADDRBANK+$10

    seta16
    lda PlayerAbility
    and #255
    xba ; Multiply by 256
    lsr ; Divide by 2 to get 128
    add #.loword(AbilityIcons)
    sta DMAADDR+$00
    add #64
    sta DMAADDR+$10

    lda #32*2 ; 2 tiles for each DMA
    sta DMALEN+$00
    sta DMALEN+$10

    ; Top row ----------------------
    lda #($8100)>>1
    sta PPUADDR
    seta8
    lda #%00000001
    sta COPYSTART

    ; Bottom row -------------------
    seta16
    lda #($8300)>>1
    sta PPUADDR
    seta8
    lda #%00000010
    sta COPYSTART


    ; Ability graphics -------------
    phk
    plb
    seta16
    lda PlayerAbility
    and #255
    tay
    lda AbilityTilesetForId,y
    and #255
    xba
    asl
    asl
    adc #.loword(AbilityGraphics) ; Carry always clear here
    sta DMAADDR

    lda #1024 ; Two rows of tiles
    sta DMALEN
    lda #($8400)>>1
    sta PPUADDR
    seta8
    lda #%00000001
    sta COPYSTART



    stz NeedAbilityChange
    stz NeedAbilityChangeSilent
  NoNeedAbilityChange:

  plp
  rtl
.endproc

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
  countdown PlayerInvincible
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


  lda keynew
  and #KEY_X|KEY_A|KEY_L|KEY_R
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
      lda keydown+1
      sta TailAttackDirection
  :

  ; Continue an attack that was started
  lda TailAttackTimer
  beq :+
    tdc ; Clear A
    lda PlayerAbility
    asl
    tax
    php
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
      lda #0
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

  ; Check for moving into a wall
  lda PlayerPX
  add #3*16
  bit PlayerVX
  bpl :+
    sub #3*16+4*16 ; Subtract off the right and subtract again
  :
  sta SideXPos

  ; Left middle
  lda PlayerPY
  sub #12*16
  tay
  lda SideXPos
  jsr TrySideInteraction
  ; Right head
  lda PlayerPY
  sub #16*23 ;#16*16+14*16 ; Top of the head
  tay
  lda SideXPos
  jsr TrySideInteraction

  ; -------------------  

  lda PlayerOnLadder
  and #255
  bne HandleLadder

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

    ; Start rolling
    lda PlayerDownTimer
    cmp #4
    bcc :+
      lda PlayerRidingSomething
      bne :+
        lda #1
        sta PlayerRolling
    :
    seta16

    ; Perform rolling
    lda PlayerRolling
    and #255
    beq :+
       lda #2
       sta ForceControllerTime
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
  sta PlayerPYTop
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
    stz PlayerVY

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
    seta16
    rts
  :

  ; Riding on something forces it to act like you are standing on solid ground
  lda PlayerRidingSomething
  and #255
  bne HasGroundAfterAll
  rts

TrySideInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionSide
  ; Solid?
  lda BlockFlag
  bpl @NotSolid
    lda SideXPos
    cmp PlayerPX
    bcs :+
      ; Left
      lda PlayerPX
      sub PlayerVX ; Undo the horizontal movement
      and #$ff00   ; Snap to the block
      add #4*16    ; Add to the offset to press against the block
      sta PlayerPX
      stz PlayerVX ; Stop moving horizontally
      rts
    :

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
        sbc #$0100 ; Carry already set
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

.enum PlayerFrame
  IDLE
  WALK1
  WALK2
  WALK3
  WALK4
  WALK5
  WALK6
  WALK7
  WALK8
  RUN1
  RUN2
  RUN3
  RUN4
  RUN5
  RUN6
  RUN7
  RUN8
  JUMP
  FALL
  CLIMB1
  CLIMB2
  ROLL1
  ROLL2
  ROLL3
  ROLL4
  ATTACK1
  ATTACK2
  ATTACK3
  ATTACK4
  ATTACK5
  ATTACK6
  ATTACK7
  ATTACK8
  ATTACK9
  REMOTE1
  REMOTE2
  FISHING
  THROW1
  THROW2
  THROW3
  ATTACKBELOW1
  ATTACKBELOW2
  ATTACKBELOW3
  ATTACKBELOW4
  ATTACKBELOW5
  ATTACKBELOW6
.endenum

.a16
.i16
.export DrawPlayer
.proc DrawPlayer
  ldx PlayerOAMIndex

  jsr XToPixels

  ; Keep the player within bounds horizontally
  ; and fix it if they're out of bounds.
  lda 0
  cmp #$10
  bcs :+
    stz PlayerVX
    seta8
    lda #$00
    sta PlayerPX+0
    inc PlayerPX+1
    seta16
    jsr XToPixels
  :
  lda 0
  cmp #$f0
  bcc :+
    stz PlayerVX
    seta8
    dec PlayerPX+1
    lda #$ff
    sta PlayerPX+0
    seta16
    jsr XToPixels
  :

  ; Y coordinate to pixels
  lda PlayerPY
  sub ScrollY
  cmp #(224*16)+(32*16)
  bcc :+
    lda #255
    bra HaveY
  :
  lsr
  lsr
  lsr
  lsr
HaveY:
  sta 2


  lda #$0200  ; Use 16x16 sprites
  sta OAMHI+(4*0),x
  sta OAMHI+(4*1),x
  sta OAMHI+(4*2),x
  sta OAMHI+(4*3),x
  sta OAMHI+(4*4),x

  seta8
  lda 0
  sta PlayerDrawX
  sta OAM_XPOS+(4*1),x
  sta OAM_XPOS+(4*3),x
  sub #16
  sta OAM_XPOS+(4*0),x
  sta OAM_XPOS+(4*2),x

  lda PlayerRolling
  beq :+
    lda 2
    add #8
    sta 2
  :

  lda 2
  sta PlayerDrawY
  sub #16
  sta OAM_YPOS+(4*2),x
  sta OAM_YPOS+(4*3),x
  sub #16
  sta OAM_YPOS+(4*0),x
  sta OAM_YPOS+(4*1),x

  ; Ability icon
  lda #15
  sta OAM_XPOS+(4*4),x
  lda #8
  sta OAM_YPOS+(4*4),x

  ; Tile numbers
  lda #0
  sta OAM_TILE+(4*0),x
  lda #2
  sta OAM_TILE+(4*1),x
  lda #4
  sta OAM_TILE+(4*2),x
  lda #6
  sta OAM_TILE+(4*3),x
  lda #8 ; Ability icon
  sta OAM_TILE+(4*4),x

  ; Horizontal flip
  lda PlayerDir
  eor PlayerFrameXFlip
  beq :+
    ; Rewrite tile numbers
    lda #2
    sta OAM_TILE+(4*0),x
    lda #0
    sta OAM_TILE+(4*1),x
    lda #6
    sta OAM_TILE+(4*2),x
    lda #4
    sta OAM_TILE+(4*3),x

    lda #OAM_XFLIP>>8
  :
  ora #>(OAM_PRIORITY_2|OAM_COLOR_1) ; priority
  sta OAM_ATTR+(4*0),x
  sta OAM_ATTR+(4*1),x
  sta OAM_ATTR+(4*2),x
  sta OAM_ATTR+(4*3),x

  ; Ability icon has top priority
  lda #>(OAM_PRIORITY_3|OAM_COLOR_0)
  sta OAM_ATTR+(4*4),x

  ; Do a vertical flip (possibly on top of a horizontal flip) if requested
  lda PlayerFrameYFlip
  beq :+
    ; Swap vertically
    lda OAM_TILE+(4*0),x
    pha
    lda OAM_TILE+(4*2),x
    sta OAM_TILE+(4*0),x
    pla
    sta OAM_TILE+(4*2),x

    lda OAM_TILE+(4*1),x
    pha
    lda OAM_TILE+(4*3),x
    sta OAM_TILE+(4*1),x
    pla
    sta OAM_TILE+(4*3),x

    ; Fix attributes
    lda OAM_ATTR+(4*0),x
    ora #OAM_YFLIP>>8
    sta OAM_ATTR+(4*0),x
    sta OAM_ATTR+(4*1),x
    sta OAM_ATTR+(4*2),x
    sta OAM_ATTR+(4*3),x
  :


  ; Invincibility effect
  lda PlayerInvincible
  lsr
  bcc :+
    lda #225 ; Move offscreen every other frame
    sta OAM_YPOS+(4*0),x
    sta OAM_YPOS+(4*1),x
    sta OAM_YPOS+(4*2),x
    sta OAM_YPOS+(4*3),x
  :

  ; Automatically cycle through the walk animation
  seta8
  stz PlayerFrame
  stz PlayerFrameXFlip
  stz PlayerFrameYFlip

  lda keydown+1
  and #(KEY_LEFT|KEY_RIGHT)>>8
  beq :+
    lda PlayerWasRunning
    beq @NotRunning
      lda framecount
      lsr
      and #7
      add #8
      inc a
      sta PlayerFrame 
      bra :+
    @NotRunning:

    lda framecount
    lsr
    lsr
    and #7
    inc a
    sta PlayerFrame 
  :

  lda PlayerOnGround
  bne OnGround
    lda #PlayerFrame::FALL
    sta PlayerFrame

    lda PlayerJumping
    beq OnGround
      dec PlayerFrame
  OnGround:


  lda TailAttackTimer
  beq NoTailAttack
    lda TailAttackFrame
    sta PlayerFrame
    bra Exit
  NoTailAttack:

  lda PlayerOnLadder
  beq OffLadder
    lda retraces
    lsr
    lsr
    lsr
    and #1
    add #PlayerFrame::CLIMB1
    sta PlayerFrame

    ; Turn around
    lda retraces
    and #16
    bne OffLadder
      inc PlayerFrameXFlip
  OffLadder:


  lda PlayerRolling
  beq NoRoll
    lda retraces
    lsr
    lsr
    and #3
    add #PlayerFrame::ROLL1
    sta PlayerFrame

    lda retraces
    inc a
    and #16
    beq NoRoll
      inc PlayerFrameXFlip
      inc PlayerFrameYFlip
  NoRoll:


Exit:
  setaxy16
  rtl

XToPixels:
  ; X coordinate to pixels
  lda PlayerPX
  sub ScrollX
  lsr
  lsr
  lsr
  lsr
  sta 0
  rts
.endproc

.export DrawPlayerStatus
.proc DrawPlayerStatus
  ldx OamPtr
  ; -----------------------------------
  ; But we still need to draw the health meter
  HealthCount = 0
  HealthX = 1
  seta8
  lda #15
  sta HealthX

  lda PlayerHealth
  lsr
  php
  sta HealthCount
HealthLoop:
  lda HealthCount
  beq HealthLoopEnd
  lda #$6e
  jsr MakeHealthIcon
  dec HealthCount
  bne HealthLoop
HealthLoopEnd:
  plp 
  bcc :+
    lda #$6f
    jsr MakeHealthIcon
  :

  ; -----------------------------------
  stx OamPtr
  setaxy16
  rtl

.a8
MakeHealthIcon:
  sta OAM_TILE,x
  lda HealthX
  sta OAM_XPOS,x
  add #8
  sta HealthX
  lda #>(OAM_PRIORITY_2|OAM_COLOR_0)
  sta OAM_ATTR,x
  lda #16+8
  sta OAM_YPOS,x
  stz OAMHI+0,x
  stz OAMHI+1,x

  ; Next sprite
  inx
  inx
  inx
  inx
  rts
.endproc


AttackAnimationSequence:
  .byt PlayerFrame::ATTACK1
  .byt PlayerFrame::ATTACK2
  .byt PlayerFrame::ATTACK3
  .byt PlayerFrame::ATTACK4
  .byt PlayerFrame::ATTACK5
  .byt PlayerFrame::ATTACK6, PlayerFrame::ATTACK6
  .byt PlayerFrame::ATTACK7, PlayerFrame::ATTACK7
  .byt PlayerFrame::ATTACK8, PlayerFrame::ATTACK8
  .byt PlayerFrame::ATTACK9, PlayerFrame::ATTACK9
AttackAnimationSequenceEnd:

AttackBelowAnimationSequence:
  .byt PlayerFrame::ATTACKBELOW1
  .byt PlayerFrame::ATTACKBELOW2
  .byt PlayerFrame::ATTACKBELOW3
  .byt PlayerFrame::ATTACKBELOW4
  .byt PlayerFrame::ATTACKBELOW5
  .byt PlayerFrame::ATTACKBELOW6, PlayerFrame::ATTACKBELOW6
  .byt PlayerFrame::ATTACK7, PlayerFrame::ATTACK7
  .byt PlayerFrame::ATTACK8, PlayerFrame::ATTACK8
  .byt PlayerFrame::ATTACK9, PlayerFrame::ATTACK9
AttackBelowAnimationSequenceEnd:

AbilityIcons:
  .incbin "../tilesets4/AbilityIcons.chrsfc"
AbilityGraphics:
  .incbin "../tilesets4/AbilityMiscellaneous.chrsfc"
  .incbin "../tilesets4/AbilityHammerBubbles.chrsfc"
  .incbin "../tilesets4/AbilityMirror.chrsfc"
  .incbin "../tilesets4/AbilityRemote.chrsfc"
  .incbin "../tilesets4/AbilityWaterFishing.chrsfc"
SetNone   = 0 ; Don't need anything
SetMisc   = 0
SetHammer = 1
SetMirror = 2
SetRemote = 3
SetWater  = 4
AbilityTilesetForId:
  .byt SetNone   ; None
  .byt SetMisc   ; Burger
  .byt SetMisc   ; Glider
  .byt SetMisc   ; Bomb
  .byt SetMisc   ; Ice
  .byt SetMisc   ; Fire
  .byt SetWater  ; Water
  .byt SetHammer ; Hammer
  .byt SetWater  ; Fishing
  .byt SetMisc   ; Yoyo
  .byt SetNone   ; Wheel
  .byt SetMirror ; Mirror
  .byt SetNone   ; Wing
  .byt SetRemote ; Remote
  .byt SetRemote ; Rocket
  .byt SetHammer ; Bubble
AbilityRoutineForId:
  .addr .loword(RunAbilityNone)
  .addr .loword(RunAbilityBurger)
  .addr .loword(RunAbilityGlider)
  .addr .loword(RunAbilityBomb)
  .addr .loword(RunAbilityIce)
  .addr .loword(RunAbilityFire)
  .addr .loword(RunAbilityWater)
  .addr .loword(RunAbilityHammer)
  .addr .loword(RunAbilityFishing)
  .addr .loword(RunAbilityYoyo)
  .addr .loword(RunAbilityWheel)
  .addr .loword(RunAbilityMirror)
  .addr .loword(RunAbilityWing)
  .addr .loword(RunAbilityRemote)
  .addr .loword(RunAbilityRocket)
  .addr .loword(RunAbilityBubble)

; -----------------------------------------------------------------------------

.a8
.proc StepTailSwish
  lda TailAttackTimer
  pha
  pha
  dea
  lsr
  tax
  lda AttackAnimationSequence,x
  sta TailAttackFrame

  inc TailAttackTimer
  pla
  cmp #(AttackAnimationSequenceEnd-AttackAnimationSequence-1)*2
  bne :+
    stz TailAttackTimer
  :

  pla
  cmp #4*2
  rts
.endproc

.a8
.proc StepTailSwishBelow
  lda TailAttackTimer
  pha
  pha
  dea
  lsr
  tax
  lda AttackBelowAnimationSequence,x
  sta TailAttackFrame

  inc TailAttackTimer
  pla
  cmp #(AttackAnimationSequenceEnd-AttackAnimationSequence-1)*2
  bne :+
    stz TailAttackTimer
  :

  pla
  cmp #3*2
  rts
.endproc

.a8
.proc StepThrowAnim
  lda TailAttackTimer
  pha
  pha
  dea
  lsr
  lsr
  add #PlayerFrame::THROW1
  sta TailAttackFrame

  inc TailAttackTimer
  pla
  cmp #6*2
  bne :+
    stz TailAttackTimer
  :

  pla
  cmp #4*2
  rts
.endproc

; Shared code between abilities to put a projectile in the correct spot
; for a simple 8x8 one
.a16
.proc AbilityPositionProjectile8x8
  lda PlayerPY
  sub #7<<4
  sta ActorPY,x

Horizontal:
  lda #13<<4
  jsl PlayerNegIfLeft
  add PlayerPX
  sta ActorPX,x
  rts
.endproc

; Same, for 16x16
.a16
.proc AbilityPositionProjectile16x16
  lda PlayerPY
  sub #4<<4
  sta ActorPY,x
  bra AbilityPositionProjectile8x8::Horizontal
.endproc

; Same but for 16x16 projectiles that are ridden on
.a16
.proc AbilityPositionProjectile16x16Below
  lda PlayerPY
  sta ActorPY,x
  sub #$100
  sta PlayerPY

  lda PlayerPX
  sta ActorPX,x
  rts
.endproc

.a8
.proc RunAbilityNone
  jsr StepTailSwish
  bne :+
    seta16
    jsl FindFreeProjectileX
    bcc :+
    lda #Actor::PlayerProjectile*2
    sta ActorType,x

    stz ActorProjectileType,x

    jsr AbilityPositionProjectile8x8

    stz ActorTimer,x

    lda #4*16
    jsl PlayerNegIfLeft
    sta ActorVX,x
  :
  rts
.endproc

.a8
.proc RunAbilityBurger
  lda TailAttackDirection
  and #>KEY_DOWN
  beq NoBelow
    jsr StepTailSwishBelow
    beq BurgerBelow
    rts
BurgerBelow:
    seta16
    jsl FindFreeProjectileX
    bcc :+
    jsr DoBurgerShared
    stz PlayerVY

    ; Position the burger underneath the player
    jsr AbilityPositionProjectile16x16Below
  : rts
NoBelow:

  ; -----------------------------------

  jsr StepTailSwish
  bne :+
BurgerSide:
    seta16
    jsl FindFreeProjectileX
    bcc :+
    jsr DoBurgerShared
    jsr AbilityPositionProjectile16x16
  :
  rts

.a16
DoBurgerShared:
  lda #Actor::PlayerProjectile16x16*2
  sta ActorType,x

  lda #PlayerProjectileType::Burger
  sta ActorProjectileType,x

  lda #40
  sta ActorTimer,x

  lda #3*16
  jsl PlayerNegIfLeft
  sta ActorVX,x
  rts
.endproc

.a8
.proc RunAbilityGlider
  jsr StepTailSwish
  bne :+
    seta16
    jsl FindFreeProjectileX
    bcc :+
    lda #Actor::PlayerProjectile*2
    sta ActorType,x

    lda #PlayerProjectileType::Glider
    sta ActorProjectileType,x

    jsr AbilityPositionProjectile8x8

    lda #140
    sta ActorTimer,x

    seta8
    lda PlayerDir
    sta ActorDirection,x
    lda TailAttackDirection
    sta ActorVarA,x
    seta16
  :
  rts
.endproc

.a8
.proc RunAbilityBomb
  jsr StepTailSwish
  rts
.endproc

.a8
.proc RunAbilityIce
  lda TailAttackDirection
  and #>KEY_DOWN
  beq NoBelow
    jsr StepTailSwishBelow
    beq IceBelow
    rts
IceBelow:
    seta16
    jsl FindFreeProjectileX
    bcc :+
    jsr DoIceShared
    stz PlayerVY
    jsr AbilityPositionProjectile16x16Below
  : rts
NoBelow:

  ; -----------------------------------

  jsr StepTailSwish
  bne :+
IceSide:
    seta16
    jsl FindFreeProjectileX
    bcc :+
    jsr DoIceShared
    jsr AbilityPositionProjectile16x16
  :
  rts

.a16
DoIceShared:
  lda #Actor::PlayerProjectile16x16*2
  sta ActorType,x

  lda #PlayerProjectileType::Ice
  sta ActorProjectileType,x

  lda #80
  sta ActorTimer,x
  lda #$30
  sta ActorVarA,x

  stz ActorVX,x
  stz ActorVY,x

  seta8
  lda PlayerDir
  sta ActorDirection,x
  seta16
  rts
.endproc

.a8
.proc RunAbilityFire
  jsr StepTailSwish
  rts
.endproc

.a8
.proc RunAbilityWater
  jsr StepThrowAnim
  bne NoThrow
    seta16
    jsl FindFreeProjectileX
    bcc :+
    lda #Actor::PlayerProjectile16x16*2
    sta ActorType,x

    lda #PlayerProjectileType::WaterBottle
    sta ActorProjectileType,x

    lda PlayerPY
    sub #7<<4
    sta ActorPY,x
    lda PlayerPX
    sta ActorPX,x

    lda #60
    sta ActorTimer,x

    ; Pick from four varieties
    jsl RandomByte
    and #3
    sta ActorVarA,x

    ; Default arc
    lda #$1c
    sta ActorVX,x
    lda #.loword(-$58)
    sta ActorVY,x

    lda TailAttackDirection
    and #>(KEY_UP)
    beq :+
      lda #$26
      sta ActorVX,x
      lda #.loword(-$67)
      sta ActorVY,x
    :

    lda TailAttackDirection
    and #>(KEY_DOWN)
    beq :+
      lda #$18
      sta ActorVX,x
      lda #.loword(-$40)
      sta ActorVY,x
    :

    lda PlayerDir
    lsr
    bcc :+
      lda ActorVX,x
      eor #$ffff
      ina
      sta ActorVX,x
    :
  NoThrow:
  rts
.endproc

.a8
.proc RunAbilityHammer
  jsr StepTailSwish
  rts
.endproc

.a8
.proc RunAbilityFishing
  lda #1
  sta AbilityMovementLock
  lda #PlayerFrame::FISHING
  sta TailAttackFrame
  rts
.endproc

.a8
.proc RunAbilityYoyo
  jsr StepTailSwish
  rts
.endproc

.a8
.proc RunAbilityWheel
  jsr StepTailSwish
  rts
.endproc

.a8
.proc RunAbilityMirror
  jsr StepTailSwish
  rts
.endproc

.a8
.proc RunAbilityWing
  jsr StepTailSwish
  rts
.endproc

.a8
.proc RunAbilityRemote
  lda #1
  sta AbilityMovementLock
  lda retraces
  lsr
  lsr
  lsr
  lsr
  lsr
  and #1
  add #PlayerFrame::REMOTE1
  sta TailAttackFrame
  rts
.endproc

.a8
.proc RunAbilityRocket
  bra RunAbilityRemote
.endproc


.a8
.proc RunAbilityBubble
  ; Need Up+Attack or Down+Attack to charge
  lda TailAttackDirection
  and #>(KEY_DOWN|KEY_UP)
  bne ChargeUp
  jsr StepTailSwish
  rts
ChargeUp:

  lda #1
  sta AbilityMovementLock
  lda #PlayerFrame::FISHING
  sta TailAttackFrame

  ; Display bubble wand
  tdc ; Clear A
  lda PlayerDir
  tay
  ldx OamPtr
  lda PlayerDrawX
  add WandOffsetX,y
  sta OAM_XPOS,x
  lda PlayerDrawY
  sub #26
  sta OAM_YPOS,x
  lda #$2a
  sta OAM_TILE,x
  lda WandAttrib,y
  sta OAM_ATTR,x
  stz OAMHI+0,x
  lda #$02
  sta OAMHI+1,x
  inx
  inx
  inx
  inx
  stx OamPtr

  lda keydown
  and #KEY_X|KEY_A|KEY_L|KEY_R
  bne :+
    stz TailAttackTimer
    stz AbilityMovementLock
    rts
  :

  ; Use the amount of time the ability has been out instead of the frame counter
  lda TailAttackTimer
  ina
  ora #$f0
  sta TailAttackTimer
  cmp #$f8
  bne NoBubble
    seta16
    jsl FindFreeProjectileX
    bcc NoBubble
	jsl ActorClear
    lda #Actor::PlayerProjectile*2
    sta ActorType,x

    lda #PlayerProjectileType::Bubble
    sta ActorProjectileType,x

    jsr AbilityPositionProjectile8x8
    lda PlayerPY
    sub #16*16
    sta ActorPY,x

    stz ActorTimer,x

    jsl RandomByte
    and #16+1
    sta ActorVarA,x

    .import RandomPlayerBubblePosition
    jsl RandomPlayerBubblePosition
  NoBubble:

  rts
WandOffsetX: .lobytes 1, -16-1
WandAttrib: .byt >(OAM_PRIORITY_2), >(OAM_XFLIP|OAM_PRIORITY_2)
.endproc

; -----------------------------------------------------------------------------




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
  negw
  rtl
.endproc

.a16
.i16
.export FindFreeProjectileX
.proc FindFreeProjectileX
  ldx #ProjectileStart
Loop:
  lda ActorType,x
  beq Found
  txa
  add #ActorSize
  tax
  cpx #ProjectileEnd
  bne Loop
  clc
  rtl
Found:
  sec
  rtl
.endproc

.a16
.i16
.export FindFreeProjectileY
.proc FindFreeProjectileY
  ldy #ProjectileStart
Loop:
  lda ActorType,y
  beq FindFreeProjectileX::Found
  tya
  add #ActorSize
  tay
  cpy #ProjectileEnd
  bne Loop
  clc
  rtl
.endproc
