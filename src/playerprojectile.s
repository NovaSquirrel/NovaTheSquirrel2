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
.include "actorenum.s"
.include "blockenum.s"
.smart

.import ActorBecomePoof, ActorTurnAround, TwoActorCollision, DispActor8x8, DispActor8x8WithOffset, DispActor16x16, ActorExpire
.import CollideRide, ThwaiteSpeedAngle2Offset, ActorTryUpInteraction, ActorTryDownInteraction, ActorTryDownInteractionIfClass, ActorWalk, ActorFall, ActorAutoBump
.import ChangeToExplosion, PlayerActorCollision, ActorGravity, ActorApplyVelocity, ActorApplyXVelocity, PlayerNegIfLeft
.import DispActor16x16Flipped, DispActor16x16FlippedAbsolute, SpeedAngle2Offset256, DispParticle8x8
.import ActorSafeRemoveY, BlockRunInteractionBelow, PoofAtBlockFar

.assert ^ChangeToExplosion = ^RunPlayerProjectile, error, "Player projectiles and other actors should share a bank"

.segment "C_ActorData"
CommonTileBase = $40

.a16
.i16
.export RunPlayerProjectile
.proc RunPlayerProjectile
  lda ActorProjectileType,x
  asl
  tay
  lda RunPlayerProjectileTable,y
  pha
  rts
.endproc

RunPlayerProjectileTable:
  .word .loword(RunProjectileStun-1)
  .word .loword(RunProjectileCopy-1)
  .word .loword(RunProjectileBurger-1)
  .word .loword(RunProjectileGlider-1)
  .word .loword(RunProjectileBomb-1)
  .word .loword(RunProjectileIce-1)
  .word .loword(RunProjectileFireBall-1)
  .word .loword(RunProjectileFireStill-1)
  .word .loword(RunProjectileWaterBottle-1)
  .word .loword(RunProjectileHammer-1)
  .word .loword(RunProjectileFishingHook-1)
  .word .loword(RunProjectileYoyo-1)
  .word .loword(RunProjectileMirror-1)
  .word .loword(RunProjectileRemoteHand-1)
  .word .loword(RunProjectileRemoteCar-1)
  .word .loword(RunProjectileRemoteMissile-1)
  .word .loword(RunProjectileBubble-1)
  .word .loword(RunProjectileExplosion-1)
  .word .loword(RunProjectileCopyAnimation-1)
  .word .loword(RunProjectileBubbleHeld-1)
  .word .loword(RunProjectileCopyFailAnimation-1)
  .word .loword(RunProjectileSwordSwipe-1)
  .word .loword(RunProjectileSwordSwipeNearby-1)
  .word .loword(RunProjectileThrownSword-1)
.a16
.i16
.export DrawPlayerProjectile
.proc DrawPlayerProjectile
  lda ActorProjectileType,x
  asl
  tay
  lda DrawPlayerProjectileTable,y
  pha
  rts
.endproc

DrawPlayerProjectileTable:
  .word .loword(DrawProjectileStun-1)
  .word .loword(DrawProjectileCopy-1)
  .word .loword(DrawProjectileBurger-1)
  .word .loword(DrawProjectileGlider-1)
  .word .loword(DrawProjectileBomb-1)
  .word .loword(DrawProjectileIce-1)
  .word .loword(DrawProjectileFireBall-1)
  .word .loword(DrawProjectileFireStill-1)
  .word .loword(DrawProjectileWaterBottle-1)
  .word .loword(DrawProjectileHammer-1)
  .word .loword(DrawProjectileFishingHook-1)
  .word .loword(DrawProjectileYoyo-1)
  .word .loword(DrawProjectileMirror-1)
  .word .loword(DrawProjectileRemoteHand-1)
  .word .loword(DrawProjectileRemoteCar-1)
  .word .loword(DrawProjectileRemoteMissile-1)
  .word .loword(DrawProjectileBubble-1)
  .word .loword(DrawProjectileExplosion-1)
  .word .loword(DrawProjectileCopyAnimation-1)
  .word .loword(DrawProjectileBubble-1)
  .word .loword(DrawProjectileCopyFailAnimation-1)
  .word .loword(DrawProjectileSwordSwipe-1)
  .word .loword(DrawProjectileSwordSwipeNearby-1)
  .word .loword(DrawProjectileThrownSword-1)


; Look up the block at a coordinate and run the interaction routine it has, if applicable
; But *only* if it's a specific class, passed in with 0
; Will try the second layer if the first is not solid or solid on top
; A = X coordinate, Y = Y coordinate
.a16
.i16
.export TryInsideInteractionIfClass
.proc TryInsideInteractionIfClass
  bit8 TwoLayerInteraction
  bmi TwoLayer
FirstLayer:
  jsl GetLevelPtrXY
Run:
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  and #BLOCK_FLAGS_CLASS << 8
  cmp 0
  beq :+
    plx
    clc
    rtl
  :

  lda BlockFlag
  plx
  phx ; Block interaction may overwrite X, so preserve it
  .import BlockRunInteractionInsideBody
  jsl BlockRunInteractionInsideBody
  plx
  sec
  rtl

TwoLayer:
  pha
  phy
  jsl FirstLayer
  bcs AlreadyDidFirstLayer

  ; Try second layer
  pla
  add FG2OffsetY
  tay
  pla
  add FG2OffsetX
  jsl GetLevelPtrXY
  lda #$4000
  tsb LevelBlockPtr
  lda [LevelBlockPtr]
  bra Run

AlreadyDidFirstLayer:
  ply
  pla
  ; Carry will be set
  rtl
.endproc

.a16
.i16
.proc RunProjectileStun
  jsl ActorApplyXVelocity

  inc ActorTimer,x
  lda ActorTimer,x
  cmp #20
  bne :+
    stz ActorType,x
  :
  rtl
.endproc

.a16
.i16
.proc DrawProjectileStun
  lda #CommonTileBase+$2c+OAM_PRIORITY_2
  jml DispActor8x8
.endproc

.a16
.i16
.proc RunProjectileCopy
  jsl ActorApplyXVelocity

  inc ActorTimer,x
  lda ActorTimer,x
  cmp #20
  bne :+
    stz ActorType,x
  :
  rtl
.endproc

.a16
.i16
.proc DrawProjectileCopy
  lda framecount
  and #31
  tay

  lda #1
  jsr ThwaiteSpeedAngle2Offset
CustomRadius:
  ; Remove the subpixels
  lda 0
  jsr DrawProjectileCopyReduce
  pha
  sta 0

  lda 2
  jsr DrawProjectileCopyReduce
  pha
  sta 2

  seta8
  lda 0
  sta SpriteXYOffset+0
  lda 2
  sta SpriteXYOffset+1
  seta16

  lda #CommonTileBase+$2a+OAM_PRIORITY_2
  phy
  jsl DispActor8x8WithOffset
  ply

  pla
  sta 2
  pla
  sta 0

  seta8
  lda 0
  eor #255
  ina
  sta SpriteXYOffset+0
  lda 2
  eor #255
  ina
  sta SpriteXYOffset+1
  seta16

  lda #CommonTileBase+$2b+OAM_PRIORITY_2
  jml DispActor8x8WithOffset

; DispActor8x8WithOffset takes pixels, which is a problem.
; Shift the subpixels off.
::DrawProjectileCopyReduce:
  asr_n 4
  rts
.endproc
.export DrawProjectileCopyReduce

.if 0
RunProjectileCopyAnimationFlyIn:
  lda PlayerPX
  sub ActorPX,x
  asr_n 3
  add ActorPX,x
  sta ActorPX,x

  lda PlayerPY
  sub #$100
  sub ActorPY,x
  asr_n 3
  add ActorPY,x
  sta ActorPY,x
  rtl
.endif

.a16
.i16
.proc RunProjectileCopyAnimation
;  lda ActorVarB,x
;  bne RunProjectileCopyAnimationFlyIn

  inc ActorTimer,x
  lda ActorTimer,x
  cmp #50
  bne :+
    stz ActorType,x
    rtl
    .if 0
    inc ActorVarB,x

    ; Move up for real
    lda ActorTimer,x
    asl
    asl
    rsb ActorPY,x
    sta ActorPY,x
    bra RunProjectileCopyAnimationFlyIn
    .endif
  :

  ; Increase radius
  lda ActorTimer,x
  and #%11
  bne :+
    lda ActorVarA,x
    cmp #3
    beq :+
      inc ActorVarA,x
  :

  ; Move to the thing being copied
  ldy ActorVarC,x
  beq DontMove
  lda ActorType,y
  bne DoMove
DontMove:
    ; There is a potential for this enemy slot to die and then immediately get replaced on the same frame,
    ; but that should be ok?
    stz ActorVarC,x
    rtl
  DoMove:

  ; Okay actually do move to it
  lda ActorPX,y
  sta ActorPX,x
  lda ActorHeight,y
  lsr
  rsb ActorPY,y
  sta ActorPY,x
  rtl
.endproc

.if 0
DrawProjectileCopyAnimationFlyIn:
  lda #8|OAM_PRIORITY_2
  jml DispActor16x16
.endif

.a16
.i16
.proc DrawProjectileCopyAnimation
;  lda ActorVarB,x
;  bne DrawProjectileCopyAnimationFlyIn

  ; Move up a bit according to the timer
  lda ActorTimer,x
  asl
  asl
  sta 0

  ; ---
  lda ActorTimer,x ; Flicker effect
  cmp #2
  beq No
  cmp #4
  beq No
  cmp #48
  beq No
  cmp #46
  beq No
  cmp #44
  beq No

  lda ActorPY,x
  pha
  sub 0
  sta ActorPY,x
  lda #8|OAM_PRIORITY_2
  jsl DispActor16x16FlippedAbsolute
  pla
  sta ActorPY,x
No:

  lda framecount ; Pick angle for ThwaiteSpeedAngle2Offset
  and #31
  tay
  lda ActorVarA,x ; The radius
  ina
  jsr ThwaiteSpeedAngle2Offset

  jmp DrawProjectileCopy::CustomRadius
.endproc

.a16
.i16
.proc RunProjectileCopyFailAnimation
  jsl ActorApplyXVelocity
  jsl ActorGravity
  inc ActorTimer,x
  lda ActorTimer,x
  cmp #32
  bcc :+
    stz ActorType,x
  :
  rtl
.endproc

DrawProjectileCopyFailAnimation = DrawProjectileCopy

.a16
.i16
.proc RunProjectileBurger
  ; If nonzero, it's about to explode
  lda ActorVarA,x
  beq NotStopped
    dec ActorTimer,x
    bne :+
      lda #5*4
      jmp ChangeToExplosion
    :
    rtl
  NotStopped:

  lda #$30
  jsl ActorWalk
  bcs GetReadyToExplode

  jsl CollideRide
  jsl RideOnProjectile
  ; Also move the player when the burger moves
  bcc :+
    lda PlayerPX
    add ActorVX,x
    sta PlayerPX
  :

  dec ActorTimer,x
  bne :+
    inc ActorVarA,x
GetReadyToExplode:
    inc ActorVarA,x
    lda #4
    sta ActorTimer,x
  :
  rtl
.endproc

.a16
.i16
.proc DrawProjectileBurger
  lda ActorVarA,x
  dea
  beq One
  dea
  beq Two
Zero:
  lda framecount
  lsr
  and #%110
  ora #32|OAM_PRIORITY_2
  jml DispActor16x16

Two: ; About to explode
  lda #32|8|OAM_PRIORITY_2
  jml DispActor16x16


One: ; Collided with something
  lda framecount
  lsr
  bcc :+
    lda #32|10|OAM_PRIORITY_2
    jml DispActor16x16
: lda #32|12|OAM_PRIORITY_2
  jml DispActor16x16

.endproc

.a16
.i16
.proc RunProjectileGlider
  lda framecount
  and #3
  asl
  tay

  lda GliderPushX,y
  pha

  lda ActorDirection,x ; Read 8-bit variable as 16-bit
  lsr
  bcc :+
    pla
    eor #$ffff
    ina
    pha
  :

  pla
  add ActorPX,x
  sta ActorPX,x

  ; ---------------

  lda GliderPushY,y
  pha

  lda ActorVarA,x ; Read 8-bit variable as 16-bit
  and #>(KEY_UP)
  beq :+
    pla
    eor #$ffff
    ina
    pha
  :

  pla
  add ActorPY,x
  sta ActorPY,x

  ; ---------------

  jsr ActorExpire
  rtl
GliderPushX:
  .word $00, $00, $00, $30
GliderPushY:
  .word $00, $30, $00, $00
.endproc

.a16
.i16
.proc DrawProjectileGlider
  stz 0
  lda ActorVarA,x
  and #>(KEY_UP)
  beq :+
    lda #OAM_YFLIP
    sta 0
  :

  lda framecount
  and #3
  add #$2a|OAM_PRIORITY_2
  ora 0
  jml DispActor8x8
.endproc

.a16
.i16
.proc RunProjectileBomb
  lda ActorVarA,x
  bne Stationary
  ; Make sure it does despawn
  dec ActorTimer,x
  bne :+
    stz ActorType,x
  :

  jsl ActorFall
  bcc :+
DoExplode:
    lda #5*4
    jmp ChangeToExplosion
  :
  ; ActorFall will leave $ffff in 0 if it bumped a ceiling, in which case we need to explode
  inc 0
  beq DoExplode

  ; Make smoke particle repeatedly
  lda framecount
  and #3
  bne :+
    jsl FindFreeParticleY
    bcc :+
      lda #Particle::SmokeParticle
      sta ParticleType,y
      lda ActorPX,x
      sta ParticlePX,y
      lda ActorPY,x
      sub #8*16
      sta ParticlePY,y
      lda #25
      sta ParticleTimer,y
  :

  jml ActorApplyXVelocity

Stationary:
  dec ActorTimer,x
  beq DoExplode
  jsl CollideRide
  jml RideOnProjectile
  ; Carry = riding, not currently used though
.endproc

.a16
.i16
.proc DrawProjectileBomb
  lda ActorVarA,x
  bne Bigger
  lda #38|OAM_PRIORITY_2
  jml DispActor16x16
Bigger:
  lda #36|OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.proc RunProjectileIce
  jsr ActorExpire

  jsl CollideRide
  php

  jsl ActorFall
  lda ActorVarA,x
  pha
  jsl ActorWalk
  jsl ActorAutoBump
  pla
  sta TempVal ; keep the VarA that was actually used for later

  lda ActorVarA,x
  beq :+
  dec ActorVarA,x
  lda #10
  sta ActorTimer,x
: sta ActorVX,x ; required to be nonzero for the projectile to collide with enemies

  plp
  jsl RideOnProjectile
  bcc @NotRiding
  ; Without this, if the block falls fast enough the player will fall off
  lda ActorVY,x
  sta PlayerVY

  ; Add the speed to the player so they move with the block
  lda TempVal
  beq @NotRiding
  sta 0

  ; Let the player keep the block going
  lda keydown
  and #KEY_DOWN
  beq :+
    inc ActorVarA,x
  :

  ; Negate the offset if facing left
  lda ActorDirection,x
  lsr
  bcc :+
  lda 0
    eor #$ffff
    ina
    sta 0
  :

  ; Finally add the offset to the player position
  lda PlayerPX
  add 0
  sta PlayerPX
@NotRiding:

  ; Reimplement a bug from Nova the Squirrel 1 with ice.
  ; Does the actor still exist?
  lda ActorType,x
  bne ActorExists
    ldy #ProjectileStart
  : lda ActorType,y
    cmp #Actor::PlayerProjectile16x16*2
    beq ActorExists
    tya
    add #ActorSize
    tay
    cmp #ProjectileEnd
    bne :-
    seta8
    stz PlayerNeedsGround
    seta16
ActorExists:

  ; Make ice particles
  lda framecount
  and #3
  bne NoMakeParticle
    jsl FindFreeParticleY
    bcc :+
      lda #Particle::IceBlockParticle
      sta ParticleType,y

      jsl RandomByte
      sta 0
      lda ActorPX,x
      sub #8*16
      add 0
      sta ParticlePX,y

      jsl RandomByte
      sta ParticleVariable,y
      
      jsl RandomByte
      sta 0
      lda ActorPY,x
      sub ActorHeight,x
      add 0

      sta ParticlePY,y
      lda #30
      sta ParticleTimer,y
    :
  NoMakeParticle:
  rtl
.endproc

.a16
.i16
.proc DrawProjectileIce
  lda ActorTimer,x
  cmp #6
  bcc :+
  lda #32|OAM_PRIORITY_2
  jml DispActor16x16
: cmp #4
  bcc :+
  lda #32|2|OAM_PRIORITY_2
  jml DispActor16x16
: cmp #2
  bcc :+
  lda #32|4|OAM_PRIORITY_2
  jml DispActor16x16
: lda #32|10|$10|OAM_PRIORITY_2
  jml DispActor8x8
.endproc

.a16
.i16
.proc RunProjectileFireBall
  dec ActorTimer,x
  bne :+
    inc ActorProjectileType,x ; to FireStill
    lda #$40
    sta ActorTimer,x
    rtl
  :

  lda ActorVarA,x
  jsl ActorWalk
  jsl ActorAutoBump

  jsl ActorFall
  bcc Exit
  lda #.loword(-$20)
  sta ActorVY,x
Exit:
  rtl
.endproc

.a16
.i16
.proc DrawProjectileFireBall
  lda framecount
  and #1
  ora #$38|OAM_PRIORITY_2
  jml DispActor8x8
.endproc

.a16
.i16
.export RunProjectileFireStill
.proc RunProjectileFireStill
  jsl ActorFall
  bcc :+
    stz ActorVX,x
  :
  jsl ActorApplyVelocity

  lda framecount
  and #7
  bne :+
    jsl ActorTurnAround
  :

  jsr ActorExpire
  rtl
.endproc

.a16
.i16
.proc DrawProjectileFireStill
  ; Burn and then start flickering once it's about gone
  lda ActorTimer,x
  cmp #8
  bcs Always
  lsr
  bcc Nope
Always:
  lda framecount
  and #%110
  ora #OAM_PRIORITY_2|$20
  jml DispActor16x16
Nope:
  rtl
.endproc

.a16
.i16
.export RunProjectileWaterBottle
.proc RunProjectileWaterBottle
  jsr ActorExpire
  jsl ActorGravity
  jml ActorApplyXVelocity
.endproc

.a16
.i16
.proc DrawProjectileWaterBottle
  lda framecount
  lsr
  and #%110
  tay

  lda OffsetsA,y
  sta SpriteXYOffset
  lda TilesA,y
  add ActorVarA,x
  phy
  jsl DispActor8x8WithOffset
  ply

  lda OffsetsB,y
  sta SpriteXYOffset
  lda TilesB,y
  add ActorVarA,x
  jml DispActor8x8WithOffset

; Base is:
; X + 4
; Y + 8

OffsetsA:
  .lobytes 4, 8-4
  .lobytes 4+4, 8
  .lobytes 4, 8+4
  .lobytes 4-4, 8
TilesA:
  .word $20|OAM_PRIORITY_2
  .word $34|OAM_PRIORITY_2
  .word $20|OAM_PRIORITY_2|OAM_XFLIP|OAM_YFLIP
  .word $34|OAM_PRIORITY_2|OAM_XFLIP|OAM_YFLIP
OffsetsB:
  .lobytes 4, 8+4
  .lobytes 4-4, 8
  .lobytes 4, 8-4
  .lobytes 4+4, 8
TilesB:
  .word $30|OAM_PRIORITY_2
  .word $24|OAM_PRIORITY_2
  .word $30|OAM_PRIORITY_2|OAM_XFLIP|OAM_YFLIP
  .word $24|OAM_PRIORITY_2|OAM_XFLIP|OAM_YFLIP
.endproc

.a16
.i16
.proc RunProjectileHammer
  rtl
.endproc

.a16
.i16
.proc DrawProjectileHammer
  rtl
.endproc

.a16
.i16
.proc RunProjectileFishingHook
  ; TailAttackVariable:
  ; bit 0 - Returning hook to the player
  ; bit 1 - Hook caught something!
  lda TailAttackVariable
  lsr
  bcc NotPlayerSeek
    jsl PlayerActorCollision
    php
    bcs PlayerTouchingAlready
      lda PlayerPX
      sub ActorPX,x
      jsr Divide
      add ActorPX,x
      sta ActorPX,x

      lda PlayerPY
      sub #4*16
      sub ActorPY,x
      jsr Divide
      add ActorPY,x
      sta ActorPY,x
    PlayerTouchingAlready:
    plp
    bcc NotPlayerTouch
      .if 0
      lda TailAttackVariable
      and #2
      beq NoCatch
      ; If something was caught, require a key press to end the ability
      lda keynew
      and #DirectionKeys
      bne :+
        rtl
      :
   NoCatch:
      .endif
      stz ActorType,x
      seta8
      lda #5
      sta TailAttackCooldown
      stz TailAttackTimer
      stz AbilityMovementLock
      seta16
    NotPlayerTouch:
    rtl
  NotPlayerSeek:

  jsl ActorFall
  bcs :+
    lda ActorVarC,x ; Don't move forward if variable C is set
    bne :+
    lda #$50
    jsl ActorWalk
    jsl ActorAutoBump
  :
  ; ActorFall can zero this out, so avoid that
  lda #Actor::PlayerProjectile16x16*2
  sta ActorType,x

  ; Can press attack button again if it's been a few frames
  ; (to detect that it wasn't the press that created the hook in the first place)
  ; and it bring the hook back
  lda keynew
  and #AttackKeys
  beq :+
    lda TailAttackTimer
    and #255
    cmp #5
    bcc :+
      seta8
      lda #1
      tsb TailAttackVariable
      lda keydown+1
      sta TailAttackDirection
      seta16
  :
  rtl

Divide:
  asr_n 3
  rts
.endproc

.a16
.i16
.proc DrawProjectileFishingHook
  lda #OAM_PRIORITY_2|$2c
  jml DispActor16x16
.endproc

.a16
.i16
.proc RunProjectileYoyo
  rtl
.endproc

.a16
.i16
.proc DrawProjectileYoyo
  rtl
.endproc

.a16
.i16
.proc RunProjectileMirror
  rtl
.endproc

.a16
.i16
.proc DrawProjectileMirror
  rtl
.endproc

.a16
.i16
.proc RunProjectileRemoteHand
  rtl
.endproc

.a16
.i16
.proc DrawProjectileRemoteHand
  rtl
.endproc

.a16
.i16
.proc RunProjectileRemoteCar
  rtl
.endproc

.a16
.i16
.proc DrawProjectileRemoteCar
  rtl
.endproc

.a16
.i16
.proc RunProjectileSwordSwipe
  lda #12
  jsl ActorWalk
Expire:
  jsr ActorExpire
Return:
  rtl
.endproc
RunProjectileSwordSwipeNearby = RunProjectileSwordSwipe::Expire
DrawProjectileSwordSwipeNearby = RunProjectileSwordSwipe::Return

.a16
.i16
.proc DrawProjectileSwordSwipe
  lda ActorTimer,x
  cmp #4
  bcc Frame2
  cmp #8
  bcc Frame1

  lda #$30|11|OAM_PRIORITY_2
  jml DispActor8x8
Frame1:
  lda #$30|10|OAM_PRIORITY_2
  jml DispActor8x8
Frame2:
  lda #$30|9|OAM_PRIORITY_2
  jml DispActor8x8
.endproc

.a16
.i16
.proc RunProjectileThrownSword
  inc ActorTimer,x

  lda ActorDirection,x
  lsr
  php
  lda ActorVarC,x
  plp
  bcc :+
    eor #$ffff
    ina
  :
  add ActorPX,x
  sta ActorPX,x

  dec ActorVarC,x ; Slow down

  lda ActorVarC,x
  cmp #.loword(-$38)
  bne :+
    stz ActorType,x
  :

  ; Move vertically, and then come back down
  lda ActorVY,x
  add ActorVarB,x
  sta ActorVY,x
  add ActorPY,x
  sta ActorPY,x

  ; Check for buttons

  lda ActorVarA,x ; Only hit one button per sword
  bne :+

  ; Try underneath
  lda #BlockClass::Button << 8
  sta 0
  lda ActorPY,x
  tay
  lda ActorPX,x
  jsl TryInsideInteractionIfClass
  bcs DidActivateButton
  ; Try above
  lda ActorPY,x
  sub #10*16
  tay
  lda ActorPX,x
  jsl TryInsideInteractionIfClass
  bcc :+
DidActivateButton:
    lda #1
    sta ActorVarA,x
  :

  rtl
.endproc

.a16
.i16
.proc DrawProjectileThrownSword
; DispActor8x8WithOffset uses 0,1,2,3,4,5 and Y
  lda #OAM_PRIORITY_2|$20
  sta SpriteTileBase

;  lda #.loword(-4*256)
;  sta SpriteXYOffset
;  lda #$4e
;  jsl DispActor8x8WithOffset

  lda ActorTimer,x
  and #%11110
  tay
  ; Is it a diagonal frame?
  and #%00110
  cmp #%00100
  bne :+
    tya
    lsr
    lsr
    and #%110
    tay
    lda Diagonals,y
    jml DispActor16x16Flipped
  :

  lda Offset1,y
  sta SpriteXYOffset
  lda Tile1,y
  phy
  jsl DispActor8x8WithOffset
  ply

  lda #.loword(-Raise*256)
  sta SpriteXYOffset
  lda Tile2,y
  phy
  jsl DispActor8x8WithOffset
  ply

  lda Offset3,y
  sta SpriteXYOffset
  lda Tile3,y
  jml DispActor8x8WithOffset

Flip = OAM_XFLIP|OAM_YFLIP

Diagonals:
	.word 12, 14, 12|Flip, 14|Flip

Tile1:
	.word      $00,      $11, $ff,      $03,      $14,      $06, $ff,      $17
	.word Flip|$00, Flip|$11, $ff, Flip|$03, Flip|$14, Flip|$06, $ff, Flip|$17
Tile2:
	.word      $10,      $02, $ff,      $13,      $05,      $16, $ff,      $08
	.word Flip|$10, Flip|$02, $ff, Flip|$13, Flip|$05, Flip|$16, $ff, Flip|$08
Tile3:
	.word      $01,      $12, $ff,      $04,      $15,      $07, $ff,      $18
	.word Flip|$01, Flip|$12, $ff, Flip|$04, Flip|$15, Flip|$07, $ff, Flip|$18

Raise = 4

Offset1:
	.lobytes 0,-8-Raise
	.lobytes 1,-8-Raise
    .word $ffff ; --------
	.lobytes -8,0-Raise
	.lobytes -8,0-Raise
	.lobytes -8,0-Raise
    .word $ffff ; --------
	.lobytes 0,-8-Raise
;---
	.lobytes 0,8-Raise
	.lobytes -1,8-Raise
    .word $ffff ; --------
	.lobytes 8,0-Raise
	.lobytes 8,0-Raise
	.lobytes 8,0-Raise
    .word $ffff ; --------
	.lobytes 0,8-Raise

Offset3:
	.lobytes  0,8-Raise
	.lobytes  0,8-Raise
    .word $ffff ; --------
	.lobytes  8,-4-Raise
	.lobytes  8,0-Raise
	.lobytes  8,1-Raise
    .word $ffff ; --------
	.lobytes  1,8-Raise
;---
	.lobytes  0,-8-Raise
	.lobytes  0,-8-Raise
    .word $ffff ; --------
	.lobytes  -8,4-Raise
	.lobytes  -8,0-Raise
	.lobytes  -8,-1-Raise
    .word $ffff ; --------
	.lobytes  -1,-8-Raise
.endproc

.proc HalfLongVelocity
  seta8
  lda 2
  asl
  ror 2
  ror 1
  ror 0

  lda 5
  asl
  ror 5
  ror 4
  ror 3
  rts
.endproc

.proc ActorApplyLongVelocity
  XPosExtra = ActorVarA+0 ; Extra position bits
  YPosExtra = ActorVarA+1 ; Extra position bits
  seta8
  lda XPosExtra,x
  add 0
  sta XPosExtra,x
  lda ActorPX+0,x
  adc 1
  sta ActorPX+0,x
  lda ActorPX+1,x
  adc 2
  sta ActorPX+1,x

  lda YPosExtra,x
  add 3
  sta YPosExtra,x
  lda ActorPY+0,x
  adc 4
  sta ActorPY+0,x
  lda ActorPY+1,x
  adc 5
  sta ActorPY+1,x
  seta16
  rts
.endproc

.a16
.i16
.proc RunProjectileRemoteMissile
  XPosExtra = ActorVarA+0 ; Extra position bits
  YPosExtra = ActorVarA+1 ; Extra position bits
  ThisAngle = ActorVarB   ; Angle
TargetAngle = 0
AbsDifference = 2

  ; Calculate target angle
  seta8
  tdc ; Clear accumulator, for the TAY
  lda keydown+1
  and #>(KEY_LEFT|KEY_RIGHT|KEY_UP|KEY_DOWN)
  beq NoTarget
    tay
    seta16 ; Switch to 16-bit to make the math easier
    lda TargetAngleTable,y
    and #255
    cmp #255
    beq NoTarget
    sta TargetAngle

    ; Implement the retargeting here
    lda ThisAngle,x
    sub TargetAngle
    abs
    sta AbsDifference

    ; If the difference is small enough, just snap
    cmp #4
    bcs :+
      lda TargetAngle
      sta ThisAngle,x
      bra NoTarget
    :

    cmp #128
    bcs :+
      lda ThisAngle,x
      cmp TargetAngle
      bcc :+
        lda ThisAngle,x
        sub #3
        sta ThisAngle,x
        bra NoTarget
    :

    lda AbsDifference
    cmp #128
    bne :+
      lda ThisAngle,x
      eor #128
      sta ThisAngle,x
      bra NoTarget
    :
    bcc :+
      lda ThisAngle,x
      cmp TargetAngle
      bcs :+
        lda ThisAngle,x
        sub #3
        sta ThisAngle,x
        bra NoTarget
    :

    lda ThisAngle,x
    add #3
    sta ThisAngle,x
NoTarget:
  seta16

  lda ThisAngle,x
  and #255
  sta ThisAngle,x
  asl
  tay
  lda PlayerWasRunning ; Go faster when holding the run button?
  and #255
  cmp #1 ; Must be nonzero
  lda #0
  rol
  add #1
  jsl SpeedAngle2Offset256
  ; Results in
  ; 0,1,2 X
  ; 3,4,5 Y
  jsr HalfLongVelocity
  jsr ActorApplyLongVelocity

  ; Can press attack button again if it's been a few frames
  ; (to detect that it wasn't the press that created the rocket in the first place)
  ; and it will explode without having to hit anything.
  lda keynew
  and #AttackKeys
  beq :+
    lda TailAttackTimer
    and #255
    cmp #5
    bcs ExplodeNow
  :


  lda framecount
  and #7
  bne :+
    jsl FindFreeParticleY
    bcc :+
      lda #Particle::SmokeParticle
      sta ParticleType,y
      lda ActorPX,x
      sta ParticlePX,y
      lda ActorPY,x
      sub #8*16
      sta ParticlePY,y
      lda #30
      sta ParticleTimer,y
  :


  ; Calculate a value to compare against; only collide with one-way tiles if going down
  lda 4 ; Vertical speed positive and not zero
  beq :+
  bmi :+
    lda ActorPY,x
    sub #$80
    tay
    lda ActorPX,x
    jsl ActorTryDownInteraction
    cmp #$4000
    bcs ExplodeNow   
  :

  ; Explode if necessary
  lda ActorPY,x
  sub #$80
  tay
  lda ActorPX,x
  jsl ActorTryUpInteraction
  bpl :+
ExplodeNow:
    seta8
    lda #5
    sta TailAttackCooldown
    stz AbilityMovementLock
    stz TailAttackTimer
    seta16
    lda #5*4
    jmp ChangeToExplosion
  :
  rtl
TargetAngleTable:
  .byt 255 ; udlr
  .byt 0   ; udlR East
  .byt 128 ; udLr West
  .byt 255 ; udLR
  .byt 64  ; uDlr South
  .byt 32  ; uDlR Southeast
  .byt 96  ; uDLr Southwest
  .byt 255 ; uDLR
  .byt 192 ; Udlr North
  .byt 224 ; UdlR Northeast
  .byt 160 ; UdLr Northwest
  .byt 255 ; UdLR
  .byt 255 ; UDlr
  .byt 255 ; UDlR
  .byt 255 ; UDLr
  .byt 255 ; UDLR
.endproc

.a16
.i16
.proc DrawProjectileRemoteMissile
  lda ActorVarB,x
  add #8
  lsr ; %01111000
  lsr ; %00111100
  lsr ; %00011110
  and  #%00011110
  tay
  lda Frames,y
  jml DispActor16x16FlippedAbsolute

Frames:
Up     = $20
DiagU  = $22
Diag   = $24
DiagR  = $26
Right  = $28
  PR = OAM_PRIORITY_2
  .word PR|Right, PR|DiagR|OAM_YFLIP, PR|Diag|OAM_YFLIP, PR|DiagU|OAM_YFLIP
  .word PR|Up|OAM_YFLIP, PR|DiagU|OAM_YFLIP|OAM_XFLIP, PR|Diag|OAM_XFLIP|OAM_YFLIP, PR|DiagR|OAM_XFLIP|OAM_YFLIP
  .word PR|Right|OAM_XFLIP, PR|DiagR|OAM_XFLIP, PR|Diag|OAM_XFLIP, PR|DiagU|OAM_XFLIP
  .word PR|Up, PR|DiagU, PR|Diag, PR|DiagR
;  .word PR|Right, PR|Diag|OAM_YFLIP, PR|Up|OAM_YFLIP, PR|Diag|OAM_XFLIP|OAM_YFLIP
;  .word PR|Right|OAM_XFLIP, PR|Diag|OAM_XFLIP, PR|Up, PR|Diag
.endproc

.a16
.i16
.proc RunProjectileBubbleShared
  lda ActorTimer,x
  beq NotLaunched
    cmp #60
    bne :+
      stz ActorType,x
    :
    inc ActorTimer,x
	jsl ActorApplyVelocity
    clc
    rtl
  NotLaunched:
  ; -------

  lda PlayerPX
  add ActorVarB,x

  sub ActorPX,x
  jsr Divide
  add ActorPX,x
  sta ActorPX,x

  ; -------

  lda PlayerPY
  sub #8*16
  add ActorVarC,x

  sub ActorPY,x
  jsr Divide
  add ActorPY,x
  sta ActorPY,x

  ; -------

  lda framecount
  and #15
  bne NoRearrange
    jsl RandomPlayerBubblePosition
  NoRearrange:
  sec
  rtl

Divide:
  asr_n 3
  rts
.endproc

.a16
.i16
.proc RunProjectileBubbleHeld
  jsl RunProjectileBubbleShared
  bcc Exit

  ; Launch when no longer holding the button
  lda keydown
  and #KEY_X|KEY_A|KEY_L|KEY_R
  bne :+
Go:
    inc ActorTimer,x
    lda #$50
    jsl PlayerNegIfLeft
    sta ActorVX,x
  :
Exit:
  rtl
.endproc

.a16
.i16
.proc RunProjectileBubble
  jsl RunProjectileBubbleShared
  bcc Exit

  ; Need to press attack, but not up or down
  lda keynew
  and #KEY_X|KEY_A|KEY_L|KEY_R
  beq :+
    lda keydown
    and #KEY_DOWN|KEY_UP
    beq RunProjectileBubbleHeld::Go
  :
Exit:
  rtl
.endproc

.a16
.export RandomPlayerBubblePosition
.proc RandomPlayerBubblePosition
  jsl RandomByte
  asl
  jsl VelocityLeftOrRight
  sta ActorVarB,x
  jsl RandomByte
  and #127
  jsl VelocityLeftOrRight
  sta ActorVarC,x
  rtl
.endproc


.a16
.i16
.proc DrawProjectileBubble
  lda #$28|OAM_PRIORITY_2
  add ActorVarA,x
  jml DispActor8x8
.endproc

.a16
.i16
.proc RunProjectileExplosion
;  jsl RandomByte
  lda ActorVarB,x
  asl
  asl
  asl
  asl
  sta 0
  lda framecount
  add ActorVarA,x
  eor 0
  and #31
  tay
  lda ActorVarA,x
  lsr
  lsr
  jsr ThwaiteSpeedAngle2Offset
  inc ActorVarA,x

  lda ActorVX,x
  add 0
  sta ActorPX,x

  lda ActorVY,x
  add 2
  sta ActorPY,x

  ; Explode certain types
  lda ActorPY,x
  sub #$0060
  tay
  lda ActorPX,x
  sub #$0060
  jsr InteractWithBlock

  lda ActorPY,x
  sub #$0060
  tay
  lda ActorPX,x
  add #$0060
  jsr InteractWithBlock

  lda ActorPY,x
  add #$0060
  tay
  lda ActorPX,x
  sub #$0060
  jsr InteractWithBlock

  lda ActorPY,x
  add #$0060
  tay
  lda ActorPX,x
  add #$0060
  jsr InteractWithBlock

ExpireThen:
  jsr ActorExpire
  rtl

InteractWithBlock:
  inc InteractionByProjectile
  phx
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionBelow
  plx
  dec InteractionByProjectile
  ; Insert additional types the Below interaction doesn't do
  lda [LevelBlockPtr]
  cmp #Block::Ice
  beq ExplodeBlock
  rts
ExplodeBlock:
  pla ; Pop the return address off
  tdc
  jsl ChangeBlock
  jsl PoofAtBlockFar
  bra ExpireThen
.endproc

.pushseg
.segment "DynamicExplosion"
DSExplosion:
.incbin "../tilesetsX/DSExplosion.chr"
.popseg

.include "actorframedefine.s"
.a16
.i16
.proc DrawProjectileExplosion
  ; Don't update the explosion if it's the second actor
  lda ActorVarB,x
  beq :+
    phx

    phx
    lda ActorVarA,x
;    and #<~1
    asl
    tax
    lda Frames,x
    plx
;    lsr
;    xba
;    asl
;    add #.loword(DSExplosion)
    pha
    lda ActorDynamicSlot,x
    and #ACTOR_DYNAMIC_SLOT_MASK
    tax
    ldy #256
    lda #^DSExplosion | $8000
    sta 0
    pla
    .import QueueDynamicSpriteUpdate
    jsl QueueDynamicSpriteUpdate
    plx
  :

  lda ActorDynamicSlot,x
  and #ACTOR_DYNAMIC_SLOT_MASK
  .import GetDynamicSpriteTileNumber
  jsl GetDynamicSpriteTileNumber
  ora #OAM_PRIORITY_2
  sta SpriteTileBase

  lda #.loword(Frame)
  .import DispActorMetaPriority2
  jml DispActorMetaPriority2

Frame:
  Row16x16 -8, -8,  $00, $02
  Row16x16 -8,  8,  $04, $06
  EndMetasprite

Frames:
  .word .loword(DSExplosion+(512*0))
  .word .loword(DSExplosion+(512*1))
  .word .loword(DSExplosion+(512*1))
  .word .loword(DSExplosion+(512*1))
  .word .loword(DSExplosion+(512*2))
  .word .loword(DSExplosion+(512*2))
  .word .loword(DSExplosion+(512*2))
  .word .loword(DSExplosion+(512*3))
  .word .loword(DSExplosion+(512*3))
  .word .loword(DSExplosion+(512*4))
  .word .loword(DSExplosion+(512*4))
  .word .loword(DSExplosion+(512*5))
  .word .loword(DSExplosion+(512*5))
  .word .loword(DSExplosion+(512*6))
  .word .loword(DSExplosion+(512*6))
  .word .loword(DSExplosion+(512*7))
  .word .loword(DSExplosion+(512*7))
  .word .loword(DSExplosion+(512*8))
  .word .loword(DSExplosion+(512*8))
  .word .loword(DSExplosion+(512*9))
.endproc

; Check for a collision with a player projectile
; and run the default handler for it
.export ActorGetShot
.proc ActorGetShot
  jsl ActorGetShotTest
  bcc :+
  jsl ActorGotShot
: rtl
.endproc

.a16
.proc ActorGetShotTest
ProjectileIndex = TempVal
ProjectileType  = 0
  ldy #ProjectileStart
Loop:
  lda ActorType,y
;  cmp #Actor::PlayerProjectile*2
  beq NotProjectile  

  jsl TwoActorCollision
  bcc :+
    lda ActorProjectileType,y
    sta ProjectileType
    sty ProjectileIndex
    sec
    rtl
  :

NotProjectile:
  tya
  add #ActorSize
  tay
  cpy #ProjectileEnd
  bne Loop

  clc
  rtl
.endproc

.proc ActorGotShot
ProjectileIndex = ActorGetShotTest::ProjectileIndex
ProjectileType  = ActorGetShotTest::ProjectileType
Temp1 = 2
Temp2 = 4
Temp3 = 6
  phk
  plb
  lda ProjectileType
  asl
  tay
  lda HitProjectileResponse,y
  pha
  ldy ProjectileIndex
  rts

StunAndRemove:
  ; Use ProjectileType to decide what to do.
  ; For now just stun.
  seta8
  lda #ActorStateValue::Stunned
  sta ActorState,x
  stz AbilityMovementLock
  seta16

  lda #180
  sta ActorTimer,x

  ldy ProjectileIndex
  jsl ActorSafeRemoveY

  ; Make a stun animation particle now
  jsl FindFreeParticleY
  bcc @Exit
    lda #Particle::EnemyStunnedParticle
    sta ParticleType,y
    lda ActorPX,x
    sta ParticlePX,y
    lda ActorPY,x
    sta ParticlePY,y
    stx ParticleVariable,y
    lda #180
    sta ParticleTimer,y
@Exit:
  rtl

BumpFreeze:
  ; Must be moving in order to bump
  lda ActorVX,y
  ora ActorVY,y
  bne :+
    rtl
  :

  ; Try to make a freeze particle!
  lda framecount
  lsr
  bcs :+
  jsl FindFreeParticleY
  bcc :+
    jsl RandomByte
    sta ParticleVariable,y

    lda #Particle::IceBlockFreezeParticle
    sta ParticleType,y

    lda ActorPX,x
    sub #4*16
    sta ParticlePX,y

    lda ActorPY,x
    sub #16*16
    sta ParticlePY,y

    lda #15
    sta ParticleTimer,y
  :

  bra BumpUpward

Bump:
  ; Must be moving in order to bump
  lda ActorVX,y
  ora ActorVY,y
  bne :+
    rtl
  :
BumpUpward:
  lda #.loword(-$30)
  sta ActorVY,x
BumpStunOnly:
  jsl ActorTurnAround
  lda #ActorStateValue::Stunned
  sta ActorState,x
  lda #90
  sta ActorTimer,x
  rtl

; Instantly kill anything
Kill:
  jml ActorBecomePoof

DamageALittleLess:
  jsr ProjectileBecomesLandingParticle
  lda #$02
  bra AddDamage

DamageALittle:
  jsr ProjectileBecomesLandingParticle
  lda #$04
  bra AddDamage

DamageAndRemoveHalf:
  lda #Particle::EnemyDamagedParticle
  jsr ProjectileBecomesDamageParticle
  lda #$08
  bra AddDamage

DamageAndRemove:
  lda #Particle::EnemyDamagedParticle
  jsr ProjectileBecomesDamageParticle
Damage:
  lda #$10

; A = damage
AddDamage:
  sta 0

  ; Add the damage now
  lda ActorDamage,x
  and #255
  add 0
  seta8
  sta ActorDamage,x
  seta16
  ; If >= $0100 then it's automatically defeated
  cmp #$0100
  bcs Defeated
  ; Otherwise we need to check how much health the enemy had;
  ; Save new damage value
  sta 0

  phx
  lda ActorType,x
  lsr
  tax
  .import ActorHealth
  lda f:ActorHealth,x
  and #255
  plx
  cmp 0
  beq Defeated
  bcs Damaged
Defeated:
  jml ActorBecomePoof
Damaged:
  lda #ActorStateValue::Stunned
  sta ActorState,x
  lda #60
  sta ActorTimer,x
  rtl

ProjectileBecomesLandingParticle:
  lda ActorPX,y
  sta Temp1
  lda ActorPY,y
  sta Temp2
  jsl ActorSafeRemoveY
  jsl FindFreeParticleY
  bcc @Exit
    lda #Particle::LandingParticle
    sta ParticleType,y
    lda Temp1
    sta ParticlePX,y
    lda Temp2
    sta ParticlePY,y
@Exit:
  rts

ProjectileBecomesDamageParticle:
  lda ActorPX,y
  sta Temp1
  lda ActorPY,y
  sta Temp2
  jsl ActorSafeRemoveY
  jsl FindFreeParticleY
  bcc @Exit
    lda #Particle::EnemyDamagedParticle
    sta ParticleType,y
    lda Temp1
    sta ParticlePX,y
    lda Temp2
    sta ParticlePY,y
    lda #20
    sta ParticleTimer,y
    lda #.loword(-$30)
    sta ParticleVY,y
    jsl RandomByte
    and #15
    add #7
    jsl VelocityLeftOrRight
    sta ParticleVX,y
@Exit:
  rts

HitProjectileResponse:
  .word .loword(StunAndRemove-1) ; Stun
  .word .loword(Copy-1) ; Copy
  .word .loword(Bump-1) ; Burger
  .word .loword(DamageAndRemove-1) ; Glider
  .word .loword(Bump-1) ; Bomb
  .word .loword(BumpFreeze-1) ; Ice
  .word .loword(DamageAndRemove-1) ; Fire ball
  .word .loword(Damage-1) ; Fire still
  .word .loword(DamageAndRemoveHalf-1) ; Water bottle
  .word .loword(Damage-1) ; Hammer
  .word .loword(Hook-1) ; Fishing hook
  .word .loword(Damage-1) ; Yoyo
  .word .loword(StunAndRemove-1) ; Mirror
  .word .loword(StunAndRemove-1) ; RC hand
  .word .loword(Bump-1) ; RC car
  .word .loword(Nothing-1) ; RC missile
  .word .loword(DamageALittle-1) ; Bubble
  .word .loword(Kill-1) ; Explosion
  .word .loword(Nothing-1) ; Copy animation
  .word .loword(DamageALittleLess-1) ; Bubble (Held)
  .word .loword(Nothing-1) ; Copy fail animation
  .word .loword(Damage-1) ; Sword swipe
  .word .loword(Damage-1) ; Sword swipe (nearby)
  .word .loword(ThrownSword-1) ; Thrown sword

; Hook an enemy and pull them to the player
Hook:
  seta8
  lda #2
  tsb TailAttackVariable

  lda #ActorStateValue::Override
  sta ActorState,x
  stz AbilityMovementLock
  seta16
  lda #ActorOverrideValue::Hooked
  sta ActorTimer,x
  rtl

; Look up the enemy's type and copy the corresponding ability
Copy:
;  lda #0 ; <--- Don't need ActorSafeRemoveY for Copy, because only one
;         ; kind of projectile uses it, and it does not allocate dynamic sprite slots
;  sta ActorType,y
  lda #PlayerProjectileType::CopyAnimation
  sta ActorProjectileType,y
  tdc ; Clear A
  sta ActorTimer,y
  sta ActorVarA,y
  sta ActorVarB,y
  stx ActorVarC,y
  seta8
  lda #50
  sta CopyingAnimationTimer
  seta16

  ; Find the enemy's type
  ldy #0
: lda CopyEnemy,y
  beq NoCopy
  cmp ActorType,x
  beq @YesCopy
  iny
  iny
  bra :-

  ; Get the ability ID
@YesCopy:
  tya
  lsr
  tay
  seta8
  lda CopyAbility,y
  sta PlayerAbility
  lda #1
  sta NeedAbilityChange
  seta16
Nothing:
  rtl

NoCopy:
  seta8
  stz CopyingAnimationTimer
  seta16
  ldy ProjectileIndex
  lda #PlayerProjectileType::CopyFailAnimation
  sta ActorProjectileType,y

  lda #.loword(-$30)
  sta ParticleVY,y

  lda ParticleVX,y
  php
  jsl RandomByte
  and #31
  sta ParticleVX,y

  plp
  bmi :+
    eor #$ffff
    ina
    sta ParticleVX,y
  :
  rtl

ThrownSword:
.if 0
  lda #$8000 ; Marker for "stop flying"
  cmp ActorVarC,x
  bne :+
    rtl ; Ignore
  :
  sta ActorVarC,x
.endif
  lda #Particle::EnemyDamagedParticle
  jsr ProjectileBecomesDamageParticle
  lda #$10
  jmp AddDamage

CopyEnemy:
  .word Actor::FireWalk*2
  .word Actor::FireJump*2
  .word Actor::FireFlames*2
  .word Actor::FireFox*2
  .word Actor::Grillbert*2
  .word Actor::George*2
  .word Actor::Burger*2
  .word Actor::MirrorRabbit*2
  .word Actor::BubbleCat*2
  .word Actor::BubbleBuddy*2
  .word Actor::BubbleMoai*2
  .word Actor::SkateboardMoai*2
  .word Actor::ExplodingFries*2
  .word Actor::BurgerRider*2
  .word Actor::EnemyGlider*2
  .word Actor::EnemyLWSS*2
  .word Actor::KnuckleSandwich*2
  .word Actor::PumpkinBoat*2
  .word Actor::PumpkinMan*2
  .word Actor::SwordSlime*2
  .word Actor::StrifeCloud*2
  .word Actor::Dave*2
  .word Actor::BurgerRiderJumper*2
  .word Actor::BubbleWizard*2
  .word 0

CopyAbility:
  .byt Ability::Fire
  .byt Ability::Fire
  .byt Ability::Fire
  .byt Ability::Fire
  .byt Ability::Fire
  .byt Ability::Water
  .byt Ability::Burger
  .byt Ability::Mirror
  .byt Ability::Bubble
  .byt Ability::Bubble
  .byt Ability::Bubble
  .byt Ability::Bubble
  .byt Ability::Burger
  .byt Ability::Burger
  .byt Ability::Glider
  .byt Ability::Glider
  .byt Ability::Burger
  .byt Ability::Water
  .byt Ability::Water
  .byt Ability::Sword
  .byt Ability::Sword
  .byt Ability::Sword
  .byt Ability::Burger
  .byt Ability::Bubble
.endproc

.a16
.i16
.proc RideOnProjectile
  bcc Exit
    lda ActorPY,x
    cmp PlayerPY
    bcc :+
      seta8
      lda #1
      sta PlayerRidingSomething
      seta16
      lda ActorPY,x
      sub #$100
      sta PlayerPY

      ; Originally zero'd PlayerVY here, but that made it so you couldn't jump off of burgers?
      sec
      rtl
: clc
Exit:
  rtl
.endproc
