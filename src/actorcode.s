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
.include "actorframedefine.s"
.smart

.segment "C_ActorData"
CommonTileBase = $40

.import DispActor16x16, DispActor8x8, DispParticle8x8, DispActor8x8WithOffset
.import DispParticle16x16
.import DispActor16x16FourTiles, DispActor16x16Flipped, DispActor16x16FlippedAbsolute
.import DispActorMeta, DispActorMetaRight, DispActorMetaPriority2
.import ActorWalk, ActorWalkOnPlatform, ActorFall, ActorAutoBump, ActorApplyXVelocity
.import ActorTurnAround, ActorSafeRemoveX
.import ActorHover, ActorRoverMovement, CountActorAmount, ActorCopyPosXY, ActorClearY
.import PlayerActorCollision, TwoActorCollision, PlayerActorCollisionMultiRect
.import PlayerActorCollisionHurt, ActorLookAtPlayer
.import FindFreeProjectileY, ActorApplyVelocity, ActorGravity
.import ActorNegIfLeft, AllocateDynamicSpriteSlot
.import GetAngle512
.import ActorTryUpInteraction, ActorTryDownInteraction, ActorBumpAgainstCeiling
.import InitActorX, UpdateActorSizeX, InitActorY, UpdateActorSizeY

.a16
.i16
.export DrawBurger
.proc DrawBurger
  lda #0|OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunBurger
.proc RunBurger
  dec ActorVarB,x
  bne :+
    stz ActorType,x
  :

  lda ActorState,x
  and #255
  beq :+
    rtl
  :
  jsl ActorApplyVelocity
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawPinkBall
.proc DrawPinkBall
  lda #2|OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunPinkBall
.proc RunPinkBall
  rtl
.endproc


.a16
.i16
.export DrawLedgeWalker
.proc DrawLedgeWalker
  lda framecount
  lsr
  lsr
  and #2
  add #(3*2)|OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunLedgeWalker
.proc RunLedgeWalker
  lda #$10
  jsl ActorWalkOnPlatform
  jsl ActorFall
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export RunBounceGuy
.proc RunBounceGuy
  lda #$10
  jsl ActorWalk
  jsl ActorAutoBump

  jsl ActorFall
  jsr ActorBounceRandomHeights

  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.proc ActorBounceRandomHeights
  bcc :+
    ; Bounce when reaching the ground, if not stunned
    seta8
    lda ActorState,x
    bne :+
      jsl RandomByte
      ora #$80
      sta ActorVY+0,x
      lda #255
      sta ActorVY+1,x
  :
  seta16
  rts
.endproc

.a16
.i16
.export DrawBounceGuy
.proc DrawBounceGuy
  lda #$c|OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunSpinner
.proc RunSpinner
  rtl
.endproc

.a16
.i16
.export DrawSpinner
.proc DrawSpinner
  rtl
.endproc


.a16
.i16
.export RunSmashGuy
.proc RunSmashGuy
  lda ActorVarA,x ; if behavior set to 1, home in on player
  beq :+
  lda ActorState,x
  and #255
  bne :+
    lda #$10
    jsl ActorWalk
    jsl ActorAutoBump

    jsl RandomByte
    and #7
    bne :+
    jsl ActorLookAtPlayer
  :

  seta8
  lda ActorState,x
  cmp #ActorStateValue::Active
  bne :+
    seta16
    jsl ActorFall
    seta8
    bcc :+
      lda #ActorStateValue::Paused
      sta ActorState,x
      seta16
      lda #.loword(-4*16)
      sta 0
      lda #.loword(-8*16)
      sta 2
      jsl ActorMakePoofAtOffset
      seta8
  :

  lda ActorState,x
  cmp #ActorStateValue::Paused
  bne :+
    seta16
    lda ActorPY,x
    sub #$10
    sta ActorPY,x

    ; Check for collision with the ceiling
    lda ActorPY,x
    sub #$100
    tay
    lda ActorPX,x
    jsl ActorTryUpInteraction
    seta8
    bpl :+
    ; Snap against the ceiling
    stz ActorPY,x
    inc ActorPY+1,x
    stz ActorState,x
  :

  .a8
  lda ActorState,x
  bne :+
  lda ActorPX+1,x ; Player within 4 blocks horizontally
  sub PlayerPX+1
  abs
  ldy ActorVarA,x           ; smaller distance if on homing mode
  cmp DistanceToTrigger,y
  bcs :+
    lda #ActorStateValue::Active
    sta ActorState,x
    lda ActorVY+1,x ; fix vertical velocity if it's negative
    bpl :+
      stz ActorVY+0,x
      stz ActorVY+1,x
  :
  seta16

  jml PlayerActorCollisionHurt

DistanceToTrigger:
  .byt 4, 2
.endproc

.a16
.i16
.export DrawSmashGuy
.proc DrawSmashGuy
  lda #$e|OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export DrawCannonH
.proc DrawCannonH
  lda #11|OAM_PRIORITY_2
  jsr DrawCannonIndicator

  lda #$4|OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export DrawCannonV
.proc DrawCannonV
  lda #11|OAM_PRIORITY_2
  jsr DrawCannonIndicator

  lda ActorVarA,x
  bne UpsideDown

  lda #$6|OAM_PRIORITY_2
  jml DispActor16x16

UpsideDown:
  lda #$6|OAM_PRIORITY_2|OAM_YFLIP
  jml DispActor16x16FlippedAbsolute
.endproc

.a16
.i16
.export DrawCheckpoint
.proc DrawCheckpoint
  lda #$42|OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunCheckpoint
.proc RunCheckpoint
  jsl ActorHover
  jsl PlayerActorCollision
  bcc :+
    stz ActorType,x
    .import MakeCheckpoint
    jml MakeCheckpoint
  :
  rtl
.endproc

.a16
.i16
.export DrawMovingPlatform
.proc DrawMovingPlatform
  lda #$40|OAM_PRIORITY_2
  sta SpriteTileBase
  lda #.loword(Platform)
  sta DecodePointer
  jml DispActorMetaRight

Platform:
  Row8x8   -16,0,  $00, $10, $10, $01
  EndMetasprite
.endproc

.a16
.i16
.export RunMovingPlatformH
.proc RunMovingPlatformH
  rtl
.endproc

.a16
.i16
.export RunMovingPlatformLine
.proc RunMovingPlatformLine
  rtl
.endproc

.a16
.i16
.export RunMovingPlatformPush
.proc RunMovingPlatformPush
  lda PlayerPY
  cmp ActorPY,x
  bcs NoRide
  jsl CollideRide
  bcc NoRide
    lda ActorVarA,x
    asl
    tay

    lda ActorPX,x
    add DXList,y
    sta ActorPX,x

    lda PlayerPX
    add DXList,y
    sta PlayerPX

    lda ActorPY,x
    add DYList,y
    sta ActorPY,x

    lda ActorPY,x
    sub #$70
    sta PlayerPY

    stz PlayerVY

    seta8
    lda #2
    sta PlayerRidingSomething
    stz PlayerNeedsGround
    seta16
  NoRide:
  rtl

DXList:
  .word .loword($10), .loword($00), .loword(-$10), .loword($00)
  .word .loword($20), .loword($00), .loword(-$20), .loword($00)

DYList:
  .word .loword($00), .loword($10), .loword($00), .loword(-$10)
  .word .loword($00), .loword($20), .loword($00), .loword(-$20)
.endproc

.a16
.i16
.export DrawBunny
.proc DrawBunny
  lda ActorOnGround,x
  and #255
  bne :+
    lda #(2*7)|OAM_PRIORITY_2
    jml DispActor16x16
  :
  lda retraces
  lsr
  lsr
  and #2
  add #2*5
  ora #OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunBunny
.proc RunBunny
  lda framecount
  and #15
  bne :+
    jsl ActorLookAtPlayer
  :

  lda #10
  jsl ActorWalk
  jsl ActorAutoBump

  jsl ActorFall

  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawSlowSneaker
.proc DrawSlowSneaker
  lda retraces
  lsr
  lsr
  and #2
  add #2*3
  ora #OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunSlowSneaker
.proc RunSlowSneaker
  lda #20
  jsl ActorWalk
  jsl ActorAutoBump

  jsl ActorFall

  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawSneaker
.proc DrawSneaker
  ; "Sleeping" frame
  lda ActorVarC,x
  cmp #$20
  bcs :+
    lda #OAM_PRIORITY_2
    jml DispActor16x16
  :
  lda retraces
  lsr
  and #2
  add #2
  ora #OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunSneaker
.proc RunSneaker
  ; Gradually get faster
  lda ActorState,x
  and #255
  bne :+
  lda ActorVarC,x
  cmp #$20
  bcc :+
  sub #$20
  jsl ActorWalk
  jsl ActorAutoBump
:

  ; Count up a timer before starting to move
  seta8
  lda ActorState,x
  bne :+
    lda ActorOnScreen,x
    beq SlowBackDown
      lda ActorVarC,x
      cmp #$20+$30
      beq :+
        inc ActorVarC,x
  :
SlowedDown:
  seta16
  jsl ActorFall
  jml PlayerActorCollisionHurt

.a8
; If not on the screen, start slowing back down
SlowBackDown:
  lda ActorVarC,x
  cmp #$30
  bcc SlowedDown
  dec ActorVarC,x
  bra SlowedDown
.endproc

.a16
.i16
.export RunAnyCannonH
.proc RunAnyCannonH
  rtl
.endproc

.a16
.i16
.export RunAnyCannonV
.proc RunAnyCannonV
  rtl
.endproc

.a16
.i16
.export RunBurgerCannonH
.proc RunBurgerCannonH
  jsr ActorCannonCommon1
  bcc NoShoot
    jsl FindFreeActorY
    bcc NoShoot
      jsl ActorClearY
      jsl ActorCopyPosXY

      lda #Actor::Burger*2
      sta ActorType,y
      jsl InitActorY
      lda #0
      sta ActorTimer,y
      sta ActorVY,y
      lda #25*4
      sta ActorVarB,y ; Expiration timer
      lda #$38
      jsl ActorNegIfLeft
      sta ActorVX,y

      seta8
      lda ActorDirection,x
      sta ActorDirection,y
      seta16

      lda #16*16
      jsl ActorNegIfLeft
      add #.loword(-4*16)
      sta 0
      lda #.loword(-8*16)
      sta 2
      jsl ActorMakePoofAtOffset
NoShoot:
  rtl
.endproc

.a16
.proc ActorNegIfVarA
  pha
  lda ActorVarA,x
  bne Left
Right:
  pla ; No change
  rts
Left:
  pla ; Negate
  neg
  rts
.endproc


.a16
.i16
.export RunBurgerCannonV
.proc RunBurgerCannonV
  jsr ActorCannonCommon1
  bcc NoShoot
    jsl FindFreeActorY
    bcc NoShoot
      jsl ActorClearY
      jsl ActorCopyPosXY

      lda #Actor::Burger*2
      sta ActorType,y
      jsl InitActorY
      lda #0
      sta ActorTimer,y
      sta ActorVY,y
      lda #25*4
      sta ActorVarB,y ; Expiration timer
      lda #.loword(-$38)
      jsr ActorNegIfVarA
      sta ActorVY,y

      lda #.loword(-4*16)
      sta 0
      lda #.loword(-16*16)
      jsr ActorNegIfVarA
      add #.loword(-8*16)
      sta 2
      jsl ActorMakePoofAtOffset
NoShoot:
  rtl
.endproc


; Hover the cannon and control logic relating to when to shoot
.proc ActorCannonCommon1
  jsl ActorHover
NoHover:
  ; Initialize the timer if object is initializing
  lda ActorState,x
  and #255
  cmp #ActorStateValue::Init
  beq InitTimer

  ; decrease the timer otherwise
  dec ActorTimer,x
  bne NotFire
  jsr InitTimer

  sec ; Carry set: fire
  rts

InitTimer:
  jsl RandomByte
  and #63
  add #60
  sta ActorTimer,x
NotFire:
  clc ; Clear carry, don't fire
  rts
.endproc
ActorCannonCommon1NoHover = ActorCannonCommon1::NoHover

; Display an indicator when the cannon is about to fire
.proc DrawCannonIndicator
  sta TempVal

  lda ActorTimer,x
  cmp #32
  bcc :+
    rts
  :

  lda framecount
  and #31
  tay

  lda #1
  jsr ThwaiteSpeedAngle2Offset

  ; Remove the subpixels
  .import DrawProjectileCopyReduce
  .assert ^DrawProjectileCopyReduce = ^DrawCannonIndicator, error, "Player projectiles and other actors should share a bank"
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
  sub #4
  sta SpriteXYOffset+1
  seta16

  lda TempVal
  phy
  jsl DispActor8x8WithOffset
  ply

  pla
  sta 2
  pla
  sta 0

  ; Negate the offset
  seta8
  lda 0
  neg
  sta SpriteXYOffset+0
  lda 2
  neg
  sub #4
  sta SpriteXYOffset+1
  seta16

  lda TempVal
  jsl DispActor8x8WithOffset
  rts
.endproc


.a16
.i16
.export RunFireWalk
.proc RunFireWalk
  jsl ActorFall
  lda #$10
  ldy ActorVarA,x
  bne :+
    jsl ActorWalk
    jsl ActorAutoBump
    bra NormalWalk
  : 
  jsl ActorWalkOnPlatform
NormalWalk:

  ; Make flames sometimes
  lda ActorOnScreen,x ; Require them to be onscreen, to hopefully cut down on actor slot use
  and #255
  beq :+
  lda ActorState,x
  and #255
  bne :+
    lda framecount
    and #15
    bne :+
      jsl FindFreeActorY
      bcc :+
        jsl ActorClearY
        jsl ActorCopyPosXY

        ; Throw fires in the air
        lda #.loword(-$20)
        sta ActorVY,y

        ; Random X velocity
        jsl RandomByte
        and #15
        add #7
        jsl VelocityLeftOrRight
        sta ActorVX,y

        lda #Actor::FireFlames*2
        sta ActorType,y
        jsl InitActorY
        lda #32
        sta ActorTimer,y
  :

  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawFireWalk
.proc DrawFireWalk
  lda retraces
  lsr
  lsr
  and #2
  add #OAM_PRIORITY_2|8
  jml DispActor16x16
.endproc

.a16
.i16
.export RunFireJump
.proc RunFireJump
  jsl ActorFall
  bcc :+
    lda ActorState,x
    and #255
    bne :+
      lda #.loword(-$40)
      sta ActorVY,x

      lda #Actor::FireFlames*2  ; limit the number of flames
      jsl CountActorAmount
      cpy #6
      bcs :+
        jsl FindFreeActorY
        bcc :+
          jsl ActorClearY
          jsl ActorCopyPosXY

          lda #Actor::FireFlames*2
          sta ActorType,y
          jsl InitActorY
          lda #40
          sta ActorTimer,y
  :
  lda #$10
  jsl ActorWalk
  jsl ActorAutoBump
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawFireJump
.proc DrawFireJump
  lda framecount
  lsr
  lsr
  and #%1110
  tay
  lda Frames,y
  jml DispActor16x16Flipped

Frames:
  PR = OAM_PRIORITY_2
  .word PR|0|OAM_XFLIP, PR|2|OAM_XFLIP, PR|4|OAM_XFLIP, PR|6|OAM_XFLIP
  .word PR|0|OAM_YFLIP, PR|2|OAM_YFLIP, PR|4|OAM_YFLIP, PR|6|OAM_YFLIP
.endproc

.a16
.i16
.export RunFireBall
.proc RunFireBall
  rtl
.endproc

.a16
.i16
.export DrawFireBall
.proc DrawFireBall
  lda framecount
  and #1
  ora #12|$10|OAM_PRIORITY_2
  jml DispActor8x8
.endproc


.a16
.i16
.export RunFireBullet
.proc RunFireBullet
  jsr ActorExpire
  jsl ActorApplyXVelocity  
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawFireBullet
.proc DrawFireBullet
  lda #12+OAM_PRIORITY_2
  jml DispActor8x8
.endproc

.a16
.i16
.export RunFireFlames
.proc RunFireFlames
  .import RunProjectileFireStill
  jsl RunProjectileFireStill ; Reuse the projectile's behavior
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawFireFlames
.proc DrawFireFlames
  lda ActorTimer,x
  cmp #8
  bcs Always
  lsr
  bcc Nope
Always:
  lda #OAM_PRIORITY_2|14
  jml DispActor16x16
Nope:
  rtl
.endproc

.a16
.i16
.export RunFireFox
.proc RunFireFox
  jsl PlayerActorCollisionHurt

  jsl ActorFall
  bcs :+
    lda #$10
    jsl ActorWalk
    jml ActorAutoBump
  :

  jsl RandomByte
  and #15
  bne :+
    jsl ActorLookAtPlayer
  :

  ; Don't jump or shoot when stunned
  lda ActorState,x
  and #255
  beq Normal
  cmp #ActorStateValue::Active
  bne :+
  lda ActorTimer,x
  cmp #4
  beq DoShoot
:
  rtl
Normal:

  ; Sometimes jump
  jsl RandomByte
  and #15
  bne :+
    lda ActorVarA,x ; Don't jump if alternate behavior is set
    bne :+
    lda PlayerPY
    cmp ActorPY,x
    bcs LowJump
    ; Don't do high jumps if close to the player
    lda ActorPY,x
    sub PlayerPY
    cmp #$0300
    bcc LowJump
    lda #.loword(-$50)
    bra DoAJump
LowJump:
    lda #.loword(-$30)
DoAJump:
    sta ActorVY,x
  :

  lda PlayerPY
  sub ActorPY,x
  abs
  cmp #$0200
  bcs TooFar

  lda PlayerPX
  sub ActorPX,x
  abs
  cmp #$0600
  bcs TooFar

  lda framecount
  and #31
  bne :+
    lda #ActorStateValue::Active
    sta ActorState,x
    lda #20
    sta ActorTimer,x
  :
TooFar:
  rtl

DoShoot:
  jsl FindFreeActorY
  bcc :+
    jsl ActorClearY
    lda ActorPX,x
    sta ActorPX,y
    lda ActorPY,x
    sub #$58
    sta ActorPY,y

    ; Shoot fire bullets
    lda #0
    sta ActorVY,y

    lda #$30
    jsl ActorNegIfLeft
    sta ActorVX,y

    lda #Actor::FireBullet*2
    sta ActorType,y
    jsl InitActorY
    lda #40
    sta ActorTimer,y
    seta8
    lda ActorDirection,x
    sta ActorDirection,y
    seta16
  :
  rtl
.endproc

.a16
.i16
.export DrawFireFox
.proc DrawFireFox
  lda ActorState,x
  and #255
  cmp #ActorStateValue::Active
  beq Shooting

  lda ActorOnGround,x
  and #255
  beq InAir

Standing:
  lda #OAM_PRIORITY_2|0
  jml DispActor16x16
InAir:
  lda #OAM_PRIORITY_2|4
  jml DispActor16x16
Shooting:
  lda #OAM_PRIORITY_2|2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunGrillbert
.proc RunGrillbert
  jsl ActorHover
  jsl ActorRoverMovement
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawGrillbert
.proc DrawGrillbert
  lda retraces
  lsr
  lsr
  and #2
  add #OAM_PRIORITY_2|6
  jml DispActor16x16
.endproc

.a16
.i16
.export RunGeorge
.proc RunGeorge
  lda #$10
  jsl ActorWalkOnPlatform
  jsl ActorFall

  ; Count down the cooldown timer
  lda ActorVarA,x
  beq :+
    dec ActorVarA,x
  :

  seta8
  ; Set the cooldown timer
  lda ActorState,x
  cmp #ActorStateValue::Active
  bne :+
    lda ActorTimer,x
    cmp #1
    bne :+
      lda #90
      sta ActorVarA,x
  :

  lda ActorPX+1,x
  sub PlayerPX+1
  abs
  cmp #6
  jcs NotNear
  ; ---
  lda ActorPY+1,x
  sub PlayerPY+1
  abs
  cmp #7
  bcc :+
GoToNotNear:
    jmp NotNear
  :
  lda ActorState,x
  bne GoToNotNear
  lda ActorVarA,x ; Don't throw if it's already been done too recently
  bne GoToNotNear
    lda #ActorStateValue::Active
    sta ActorState,x
    seta16
    lda #60
    sta ActorTimer,x

    jsl FindFreeActorY
    jcc NotThrow
      jsl ActorClearY
      lda #$00c0
      jsl ActorNegIfLeft
      add ActorPX,x
      sta ActorPX,y

      lda ActorPY,x
      sub #$0080
      sta ActorPY,y

      ; Calculate angle
      phy
      lda PlayerPX
      sub ActorPX,y
      sta 0
      lda PlayerPY
      sub ActorPY,y
      sta 2
      jsl GetAngle512
      and #$fffe
      tay
      lda #1
      jsl SpeedAngle2Offset256
      ply
      lda 1
      sta ActorVX,y
      lda 4
      sub #$40
      sta ActorVY,y

      lda #Actor::GeorgeBottle*2
      sta ActorType,y
      jsl InitActorY

      lda #60
      sta ActorTimer,y
      seta8
      lda #ActorStateValue::Paused
      sta ActorState,y

      ; Put a warning
      seta16
      jsl FindFreeParticleY
      bcc NotThrow
        lda #Particle::WarningParticle
        sta ParticleType,y
        lda PlayerPX
        sub #$40
        sta ParticlePX,y
        lda PlayerPY
        sub #$0280
        sta ParticlePY,y
        lda #60
        sta ParticleTimer,y
    NotThrow:
  NotNear:
  seta16


  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawGeorge
.proc DrawGeorge
  lda ActorVarA,x
  bne Frame2

  lda #.loword(-4*16)
  sta SpriteXYOffset
  lda #OAM_PRIORITY_2 | 0
  jsr DispActor16x16HorizShift

  lda #.loword(4*16)
  sta SpriteXYOffset
  lda #OAM_PRIORITY_2 | 1
  jsr DispActor16x16HorizShift
  rtl

Frame2:
  lda #.loword(-4*16)
  sta SpriteXYOffset
  lda #OAM_PRIORITY_2 | 3
  jsr DispActor16x16HorizShift

  lda #.loword(4*16)
  sta SpriteXYOffset
  lda #OAM_PRIORITY_2 | 4
  jsr DispActor16x16HorizShift
  rtl
.endproc

.a16
.i16
.export RunGeorgeBottle
.proc RunGeorgeBottle
  lda ActorState,x
  and #255
  cmp #ActorStateValue::Paused
  bne NotPaused
  dec ActorTimer,x
  bne :+
    lda #30
    sta ActorTimer,x
    seta8
    stz ActorState,x
    seta16
: rtl

NotPaused:
  .import RunProjectileWaterBottle
  jsl RunProjectileWaterBottle ; Reuse the projectile's behavior
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawGeorgeBottle
.proc DrawGeorgeBottle
  lda framecount
  lsr
  and #%110
  tay

  lda OffsetsA,y
  sta SpriteXYOffset
  lda TilesA,y
  phy
  jsl DispActor8x8WithOffset
  ply

  lda OffsetsB,y
  sta SpriteXYOffset
  lda TilesB,y
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
  .word $0e|OAM_PRIORITY_2
  .word $1f|OAM_PRIORITY_2
  .word $0e|OAM_PRIORITY_2|OAM_XFLIP|OAM_YFLIP
  .word $1f|OAM_PRIORITY_2|OAM_XFLIP|OAM_YFLIP
OffsetsB:
  .lobytes 4, 8+4
  .lobytes 4-4, 8
  .lobytes 4, 8-4
  .lobytes 4+4, 8
TilesB:
  .word $1e|OAM_PRIORITY_2
  .word $0f|OAM_PRIORITY_2
  .word $1e|OAM_PRIORITY_2|OAM_XFLIP|OAM_YFLIP
  .word $0f|OAM_PRIORITY_2|OAM_XFLIP|OAM_YFLIP
.endproc

.a16
.i16
.export RunBomberTree
.proc RunBomberTree
  .import LakituMovement
  jsl LakituMovement

  lda framecount
  and #255
  bne NoShoot
    jsl FindFreeActorY
    bcc NoShoot
      jsl ActorClearY ; Includes clearing VarA and velocity and such
      jsl ActorCopyPosXY
      lda #Actor::BomberTreeSeed*2
      sta ActorType,y
      jsl InitActorY
  NoShoot:
  rtl
.endproc

.a16
.i16
.export DrawBomberTree
.proc DrawBomberTree
  lda #.loword(Tree)
  jml DispActorMetaPriority2
Tree:
  Row16x16  0,-16,  $00
  Row16x16  0,  0,  $02
  EndMetasprite
.endproc

.a16
.i16
.export RunBomberTreeSeed
.proc RunBomberTreeSeed
  jsl ActorFall
  bcc NotLanded
    inc ActorVarA,x
    lda ActorVarA,x
    cmp #32
    bne NotLanded
      stz ActorVarA,x ; Used for "emerged" flag
      lda #Actor::BomberTreeTurnip*2
      sta ActorType,x
      jsl UpdateActorSizeX
      lda #.loword(-$30)
      sta ActorVY,x

      lda ActorPY,x
      add #$0100
      sta ActorPY,x
      add #$0010
      sta ActorVarB,x
NotLanded:
  rtl
.endproc

.a16
.i16
.export DrawBomberTreeSeed
.proc DrawBomberTreeSeed
  lda ActorVarA,x
  bne DrawSprout
  lda #$4+OAM_PRIORITY_2
  jml DispActor8x8

DrawSprout:
  lda #.loword(Sprout)
  jml DispActorMetaPriority2
Sprout:
  Row8x8   -4,0,  $14,$15
  EndMetasprite
.endproc

.a16
.i16
.export RunBomberTreeTurnip
.proc RunBomberTreeTurnip
  jsl ActorFall

  ; Stop appearing behind the background
  lda ActorVY,x
  bmi GoingUp
    lda #1
    sta ActorVarA,x
GoingUp:


  lda framecount
  and #31
  bne :+
    jsl ActorLookAtPlayer
  :

  lda #10
  jsl ActorWalk
  jsl ActorAutoBump

  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawBomberTreeTurnip
.proc DrawBomberTreeTurnip
  lda ActorVarA,x
  bne NotInGround
    lda SpriteTileBase
    pha
    stz SpriteTileBase
    lda ActorPY,x
    pha
    lda ActorVarB,x
    sta ActorPY,x

    lda #CommonTileBase+$04+OAM_PRIORITY_1
    jsl DispActor16x16

    ; Fix stuff back to normal
    pla
    sta ActorPY,x
    pla
    sta SpriteTileBase
NotInGround:

  lda framecount
  and #16
  beq :+
  lda #.loword(Turnip)
  jml DispActorMetaPriority2
: lda #.loword(Turnip2)
  jml DispActorMetaPriority2

Turnip:
  Row8x8   -4,-16,  $14, $15
  Row16x16  0,  0,  $06
  EndMetasprite
Turnip2:
  Row8x8   -4,-16,  $14, $15
  Row16x16  0,  0,  $08
  EndMetasprite
.endproc

.a16
.i16
.export RunBomberTreeTurnipCool
.proc RunBomberTreeTurnipCool
  rtl
.endproc

.a16
.i16
.export DrawBomberTreeTurnipCool
.proc DrawBomberTreeTurnipCool
  rtl
.endproc

.a16
.i16
.export RunMirrorRabbit
.proc RunMirrorRabbit
  jsl ActorLookAtPlayer
  rtl
.endproc

.a16
.i16
.export DrawMirrorRabbit
.proc DrawMirrorRabbit
  lda #.loword(Rabbit2)
  jml DispActorMetaPriority2

Rabbit2:
  Row16x16  0,-16,  $00
  Row16x16  0,  0,  $02
  EndMetasprite
Rabbit:
  Row8x8   -4,-24,  $00, $01
  Row8x8   -4,-16,  $0a, $1a
  Row16x16  0,  0,  $0b
  EndMetasprite
.endproc

.a16
.i16
.export RunMirrorRabbitInHat
.proc RunMirrorRabbitInHat
  rtl
.endproc

.a16
.i16
.export DrawMirrorRabbitInHat
.proc DrawMirrorRabbitInHat
  rtl
.endproc


.a16
.i16
.export RunBurgerRider
.proc RunBurgerRider
  .import LakituMovement
  jsl LakituMovement

  lda framecount
  and #255
  bne NoShoot
    jsl FindFreeActorY
    bcc NoShoot
      jsl ActorClearY ; Includes clearing VarA and velocity and such
      jsl ActorCopyPosXY
      lda #Actor::ExplodingFries*2
      sta ActorType,y
  NoShoot:
  rtl
.endproc
.a16
.i16
.export DrawBurgerRider
.proc DrawBurgerRider
  lda #.loword(Normal)
  jml DispActorMetaPriority2

Normal:
  Row8x8   -4,-32,    $16, $17
  Row16x16  0,-16,    $04
  Row16x16 -8,  0,    $00,$02
  EndMetasprite
.endproc

.a16
.i16
.export RunExplodingFries
.proc RunExplodingFries
  stz ActorState,x ; Can't stun fries
  jsl ActorFall
  bcc InAir
  inc ActorVarA,x

  ; Remove the fries a little bit after they explode
  lda ActorVarA,x
  cmp #100
  bcc :+
  stz ActorType,x
: ; Explode fries after a bit
  cmp #50
  bne NotExplode
    jsr LaunchFry
    jsr LaunchFry
    jsr LaunchFry
    jsr LaunchFry
  NotExplode:
InAir:
  rtl

LaunchFry:
  jsl FindFreeActorY
  bcc :+
    jsl ActorClearY ; Includes clearing VarA and velocity and such
    lda #Actor::FrenchFry*2
    sta ActorType,y

    lda ActorPX,x
    sta ActorPX,y
    lda ActorPY,x
    sta ActorPY,y

    lda #.loword(-$60)
    sta ActorVY,y

    jsl RandomByte
    sta ActorVarA,y
    and #$001f
    jsl VelocityLeftOrRight
    sta ActorVX,y
  :
  rts
.endproc
.a16
.i16
.export DrawExplodingFries
.proc DrawExplodingFries
  lda ActorVarA,x
  cmp #50
  bcs Exploded
  lda #10|OAM_PRIORITY_2
  jml DispActor16x16

Exploded:
  lda #.loword(ExplodedFrame)
  jml DispActorMetaPriority2
ExplodedFrame:
  Row8x8 -4,0,  $1a,$1b
  EndMetasprite
.endproc

.a16
.i16
.export RunFrenchFry
.proc RunFrenchFry
  jsl ActorApplyXVelocity
  jsl ActorGravity
  jml PlayerActorCollisionHurt
.endproc
.a16
.i16
.export DrawFrenchFry
.proc DrawFrenchFry
  lda ActorVarA,x
  and #%1110
  tay
  lda Table,y
  jml DispActorMetaPriority2

Table:
  .addr .loword(FryPic1)
  .addr .loword(FryPic1)
  .addr .loword(FryPic2)
  .addr .loword(FryPic3)
  .addr .loword(FryPic3)
  .addr .loword(FryPic4)
  .addr .loword(FryPic5)
  .addr .loword(FryPic6)

FryPic1:
  Row8x8 -4,-8,  $0c
  Row8x8 -4, 0,  $1c
  EndMetasprite
FryPic2:
  Row8x8 -4,-8,  $1c|FRAME_YFLIP
  Row8x8 -4, 0,  $0c|FRAME_YFLIP
  EndMetasprite
FryPic3:
  Row8x8 -4,-8,  $0d
  Row8x8 -4, 0,  $1d
  EndMetasprite
FryPic4:
  Row8x8 -4,-8,  $1d|FRAME_YFLIP
  Row8x8 -4, 0,  $0d|FRAME_YFLIP
  EndMetasprite
FryPic5:
  Row8x8 -4,-8,  $0e
  Row8x8 -4, 0,  $1e
  EndMetasprite
FryPic6:
  Row8x8 -4,-8,  $1e|FRAME_YFLIP
  Row8x8 -4, 0,  $0e|FRAME_YFLIP
  EndMetasprite
.endproc

.a16
.i16
.export RunBubbleWizard
.proc RunBubbleWizard
  rtl
.endproc
.a16
.i16
.export DrawBubbleWizard
.proc DrawBubbleWizard
  rtl
.endproc

.a16
.i16
.export RunBubbleBuddy
.proc RunBubbleBuddy
  seta8
  stz ActorOnGround,x
  seta16

  ; Apply and add small amount of gravity
  lda ActorVY,x
  add #1
  sta ActorVY,x
  add ActorPY,x
  sta ActorPY,x

  lda ActorPY,x ; Only interact with ground on the top half of it
  and #$80
  bne InAir
  .import ActorFallOnlyGroundCheck
  jsl ActorFallOnlyGroundCheck
  bcc InAir
    jsl ActorLookAtPlayer
    stz ActorVY,x

    seta8
    inc ActorOnGround,x
    stz ActorPY,x ; Clear the low byte
    seta16

    ; Jump sometimes
    lda ActorState
    ora framecount
    and #15
    bne WasOnGround
    jsl RandomByte
    and #3
    bne WasOnGround
    lda ActorOnScreen,x
    and #255
    beq :+

    ; Do the jump
    lda #.loword(-$2a)
    sta ActorVY,x
    bra WasOnGround
InAir:
  lda #20
  jsl ActorWalk

WasOnGround:
  lda #10
  jsl ActorWalk
WasInAir:
  jml PlayerActorCollisionHurt
.endproc
.a16
.i16
.export DrawBubbleBuddy
.proc DrawBubbleBuddy
  lda ActorOnGround,x
  and #255
  beq :+
  lda #0|OAM_PRIORITY_2
  jml DispActor16x16
: lda #2|OAM_PRIORITY_2
  jml DispActor16x16
.endproc


.a16
.i16
.export RunBubbleBullet
.proc RunBubbleBullet
  jsr ActorExpire

  lda ActorTimer,x
  cmp #40
  beq Aim
  bcc Fly

  ; Smoothly slide to the right position

  lda ActorVarB,x
  sub ActorPX,x
  jsr Divide
  add ActorPX,x
  sta ActorPX,x

  ; -------

  lda ActorVarC,x
  sub ActorPY,x
  jsr Divide
  add ActorPY,x
  sta ActorPY,x

Done:
  jml PlayerActorCollisionHurt

Divide:
  asr_n 3
  rts

Aim:
  jsl ActorLookAtPlayer
  lda #$18
  jsl ActorNegIfLeft
  sta ActorVX,x
  seta8
  stz ActorDirection,x
  seta16
Fly:
  jsl ActorApplyXVelocity  
  bra Done
.endproc
.a16
.i16
.export DrawBubbleBullet
.proc DrawBubbleBullet
  lda ActorVarA,x
  and #%110
  tay
  lda Images,y
  jml DispActor8x8
Images:
  .word 14|$00|OAM_PRIORITY_2
  .word 14|$00|OAM_PRIORITY_2
  .word 15|$10|OAM_PRIORITY_2
  .word 15|$10|OAM_PRIORITY_2
.endproc


.a16
.i16
.export RunBubbleCat
.proc RunBubbleCat
  jsl ActorFall

  seta8
  ; Don't move or shoot when stunned
  lda ActorState,x
  beq Normal
  cmp #ActorStateValue::Active
  bne :+
  lda ActorTimer,x
  cmp #4
  beq DoShoot
:
  seta16
  rtl
Normal:

  .a8
  tdc
  lda PlayerPX+1
  sub ActorPX+1,x
  abs
  seta16
  ina
  asl
  jsl ActorWalkOnPlatform

  seta8
  ; Sometimes move into a shooting state
  lda PlayerPY+1
  sub ActorPY+1,x
  abs
  cmp #$03
  bcs TooFar

  lda PlayerPX+1
  sub ActorPX+1,x
  abs
  cmp #$06
  bcs TooFar

  lda framecount
  and #63
  bne :+
    lda #ActorStateValue::Active
    sta ActorState,x
    lda #20
    sta ActorTimer,x
  :
TooFar:
DontMove:
  seta16
  jml PlayerActorCollisionHurt

; Shoot one bubble
DoShoot:
  seta16
  jsl FindFreeActorY
  bcc :+
    jsl ActorClearY
    lda ActorPX,x
    sta ActorPX,y
    lda ActorPY,x
    sub #$58
    sta ActorPY,y

    ; Shoot bubble bullets
    lda #0
    sta ActorVY,y

    lda #$30
    jsl ActorNegIfLeft
    sta ActorVX,y

    lda #Actor::BubbleBullet*2
    sta ActorType,y
    lda #80
    sta ActorTimer,y

    ; Randomly position the bubble
    jsl RandomByte
    lsr
    jsl VelocityLeftOrRight
    add ActorPX,x
    sta ActorVarB,y
    jsl RandomByte
    lsr
    neg
    sub #$0100
    add ActorPY,x
    sta ActorVarC,y

    ; Random appearance of bubble
    jsl RandomByte
    sta ActorVarA,y
  :
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawBubbleCat
.proc DrawBubbleCat
  lda ActorState,x
  and #255
  cmp #ActorStateValue::Active
  beq Active

  lda framecount
  lsr
  lsr
  and #2
  add #(2*2)|OAM_PRIORITY_2

  jml DispActor16x16
Active:
  lda #(4*2)|OAM_PRIORITY_2
  jml DispActor16x16
.endproc


.a16
.i16
.export RunBubbleMoai
.proc RunBubbleMoai
  rtl
.endproc
.a16
.i16
.export DrawBubbleMoai
.proc DrawBubbleMoai
  lda #.loword(Normal)
  jml DispActorMetaPriority2

Normal:
  Row8x8   -4,-16,  $00,$01
  Row16x16  0,  0,  $02
  EndMetasprite
MouthOpen:
  Row8x8 -4,-16,   0,1
  Row8x8 -4, -8,   $02,$04
  Row8x8 -4,  0,   $12,$14
  EndMetasprite
.endproc

.a16
.i16
.export RunSkateboardMoai
.proc RunSkateboardMoai
  rtl
.endproc
.a16
.i16
.export DrawSkateboardMoai
.proc DrawSkateboardMoai
  rtl
.endproc





; A = tile to draw
.a16
.i16
.proc DispActor16x16HorizShift
  tay

  ; Flip the offset if needed
  lda ActorDirection,x
  lsr
  bcc :+
    lda SpriteXYOffset
    eor #$ffff
    ina
    sta SpriteXYOffset
  :

  lda ActorPX,x
  pha
  add SpriteXYOffset
  sta ActorPX,x
  tya
  jsl DispActor16x16  

  pla
  sta ActorPX,x
  rts
.endproc



.a16
.i16
.export RunActivePushBlock
.proc RunActivePushBlock
  lda ActorVarC,x
  cmp #2
  beq Falling
  asl
  tay
  lda MoveTable,y
  add ActorPX,x
  sta ActorPX,x

  lda ActorVY,x
  add ActorPY,x
  sta ActorPY,x

  ; Finish the move if needed
  dec ActorTimer,x
  beq :+
    rtl
  :

  ; Erase block at starting position's pointer
  lda ActorVarA,x ; Starting pointer
  sta LevelBlockPtr
  lda #Block::Empty
  jsl ChangeBlock

  ; Check if it should start falling, or if it moved onto solid ground
  lda ActorVarB,x
  ina
  ina
  sta LevelBlockPtr
  lda [LevelBlockPtr]
  beq StartFalling

DidLand:
  ; Just moved onto ground, so cancel
  lda ActorVarB,x ; Destination pointer
  sta LevelBlockPtr
  lda #Block::PushBlock
  jsl ChangeBlock
  stz ActorType,x
  rtl

StartFalling:
  lda #2
  sta ActorVarC,x  
  rtl

MoveTable:
  .word 2*16, .loword(-2*16)

Falling:
  ; Bottom of the screen?
  lda LevelColumnSize
  lsr
  sta 0
  lda ActorPY,x
  xba
  cmp 0
  beq DidLand

  ; Landed on something?
  lda ActorVarB,x
  ina
  ina
  sta LevelBlockPtr
  lda [LevelBlockPtr]
  bne DidLand

  ; Update the boundaries
  lda #Block::InvisibleWall
  sta [LevelBlockPtr]
  dec LevelBlockPtr
  dec LevelBlockPtr
  lda #Block::Empty
  sta [LevelBlockPtr]

  ; Probably safe to increment the top byte since it shouldn't overflow
  inc ActorPY+1,x ;assert([ActorPY+1+x]!=255)
  inc ActorVarB,x
  inc ActorVarB,x
  rtl
.endproc

.a16
.i16
.export DrawActivePushBlock
.proc DrawActivePushBlock
  lda #$40|OAM_PRIORITY_2
  sta SpriteTileBase
  lda #6
  jml DispActor16x16
.endproc


.a16
.i16
.export RunBoulder
.proc RunBoulder
  ; Instead of relying on the AutoRemove flag, only allow removing while not falling
  lda ActorVarA,x
  bne :+
  lda ActorPX,x
  sub PlayerPX
  abs
  cmp #$2000 ; How about two screens of distance does it?
  bcc :+
    stz ActorType,x ; Zero the type
    rtl
  :

  lda ActorState,x
  and #255
  cmp #ActorStateValue::Init
  bne :+
    ; Place an invisible wall at the current position
    ldy ActorPY,x
    lda ActorPX,x
    jsl GetLevelPtrXY
    lda #Block::InvisibleWall
    sta [LevelBlockPtr]
  :

  ; Keep falling
  lda ActorVarA,x
  bne KeepFalling

  ; Check below
  lda ActorPY,x
  add #$0080
  tay
  lda ActorPX,x
  jsl GetLevelPtrXY
  lda [LevelBlockPtr]
  cmp #Block::Empty
  beq StartFalling

Exit:
  ; Directly modify the list of actors in the level
  ; to update for the new position.
  ; Needs the "ActorListInRAM" level option.
  seta8
  ldy ActorIndexInLevel,x
  iny
  lda ActorPY+1,x
  sta [LevelActorPointer],y ; Could directly use LevelActorBuffer
  seta16
  rtl

StartFalling:
  lda #4
  sta ActorVarA,x
  lda #Block::InvisibleWall
  sta [LevelBlockPtr]

KeepFalling:
  ; Fall down, decrease timer
  lda ActorPY,x
  add #$0040
  sta ActorPY,x

  ; Decrease fall timer
  dec ActorVarA,x
  bne Exit

; Finish falling
Finish:
  lda ActorPY,x
  sub #$0100
  tay
  lda ActorPX,x
  jsl GetLevelPtrXY

  lda #Block::Empty
  sta [LevelBlockPtr]
  bra Exit
.endproc

.a16
.i16
.export DrawBoulder
.proc DrawBoulder
  lda #6|OAM_PRIORITY_2
  jml DispActor16x16
.endproc


.i16
.a16
.export DrawFlyingArrow
.proc DrawFlyingArrow
  lda ActorVarA,x
  tay
  lda Table,y
  jml DispActor16x16FlippedAbsolute
Table:
  .word 0|OAM_PRIORITY_2
  .word 2|OAM_PRIORITY_2
  .word 0|OAM_PRIORITY_2|OAM_XFLIP
  .word 2|OAM_PRIORITY_2|OAM_YFLIP
.endproc

.i16
.a16
.export RunFlyingArrow
.proc RunFlyingArrow
  .import CreateBrickBreakParticles
  .import CreateGrayBrickBreakParticles
  dec ActorTimer,x
  bne :+
    stz ActorType,x
  :

  ; Move forward
  ldy ActorVarA,x
  lda ActorPX,x
  add VXTable,y
  sta ActorPX,x

  lda ActorPY,x
  add VYTable,y
  sta ActorPY,x

  ; Interact with other crates
  lda ActorPY,x
  sub #$80
  tay
  lda ActorPX,x
  jsl GetLevelPtrXY
  lda [LevelBlockPtr]
  cmp #Block::WoodArrowRight
  bcc NotCrate
  cmp #Block::ArrowRevealSolid+1
  bcs NotCrate
  ; How should it be handled?
  cmp #Block::MetalArrowUp+1
  bcc TurnArrow
  cmp #Block::WoodCrate
  beq DestroyCrate
  cmp #Block::MetalCrate
  beq DestroyCrate
  cmp #Block::MetalForkUp
  jeq ForkUp
  cmp #Block::MetalForkDown
  jeq ForkDown
  cmp #Block::ArrowRevealSolid
  beq ArrowRevealSolid
NotCrate:
  rtl

VXTable:
  .word $28, 0, .loword(-$28), 0
VYTable:
  .word 0, $28, 0, .loword(-$28)

ArrowRevealSolid:
  jsl FindFreeParticleY
  bcc :+
    lda #Particle::Poof
    sta ParticleType,y
    jsl GetBlockXCoord
    add #$0080
    sta ParticlePX,y
    jsl GetBlockYCoord
    add #$0040
    sta ParticlePY,y
  :
  lda #Block::SolidBlock
  jml ChangeBlock

; Destroy the block and rotate
TurnArrow:
  sub #Block::WoodArrowRight
  and #3*2
  sta ActorVarA,x

  lda #120
  sta ActorTimer,x

  jsl GetBlockXCoord
  ora #$80
  sta ActorPX,x
  ; ---
  jsl GetBlockYCoord
  add #$0100
  sta ActorPY,x

  ; Fall into DestroyCrate
  bra JustDestroyCrate
DestroyCrate:
  stz ActorType,x

JustDestroyCrate:
  ; Look up whether to have brown or gray particles
  lda [LevelBlockPtr]
  sub #Block::WoodArrowRight
  lsr
  tay
  lda Metal,y
  lsr
  bcs @DoMetal
@DoWood:
  jsl CreateBrickBreakParticles
  bra @DidWood
@DoMetal:
  jsl CreateGrayBrickBreakParticles
@DidWood:

  lda #Block::Empty
  jml ChangeBlock

Metal: .byt 0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1

ForkUp:
  lda #3*2
  sta 0
  bra MakeForkedArrow
ForkDown:
  lda #1*2
  sta 0
MakeForkedArrow:
  jsl FindFreeActorY
  bcc :+
    ; Set up the new arrow
    lda #Actor::FlyingArrow*2
    sta ActorType,y

    jsl GetBlockXCoord
    ora #$80
    sta ActorPX,y
    ; ---
    jsl GetBlockYCoord
    add #$0100
    sta ActorPY,y

    lda 0
    sta ActorVarA,y

    lda #120
    sta ActorTimer,x
    sta ActorTimer,y
  :
  bra JustDestroyCrate
.endproc

.a16
.i16
.export RunEnemyGlider
.proc RunEnemyGlider
Direction = 0
  lda ActorState,x
  and #255
  bne NoMove

  ; Increase the counter
  inc ActorVarB,x

; -----------------------------
  lda ActorVarB,x
  lsr
  bcs NoMove
  ; Get the "frame" out of the four glider frames
  and #3
  asl ; 16-bit table
  tay

  lda GliderPushX,y ; get X push value from table
  jsl ActorNegIfLeft
  add ActorPX,x
  sta ActorPX,x
  
  lda GliderPushY,y ; get Y push value from table
  ldy ActorVarA,x   ; read value not used, but test for zero
  beq :+
    neg
  :
  add ActorPY,x
  sta ActorPY,x
NoMove:
; -----------------------------
  ; Wrap diagonally off the top and bottom of the bottom screen

  seta8
  lda ActorPY+1,x
  cmp #15
  bne :+
  lda #15+16
  jsr VerticalWrap
:

  lda ActorPY+1,x
  cmp #16+16
  bne :+
  lda #0+16
  jsr VerticalWrap
:
  seta16
  jml PlayerActorCollisionHurt

.a8
VerticalWrap:
  pha
  lda ActorDirection,x
  lsr
  bcs @Left
  lda ActorPX+1,x
  sub #$10
  sta ActorPX+1,x
  pla
  sta ActorPY+1,x
  rts
@Left:
  lda ActorPX+1,x
  add #$10
  sta ActorPX+1,x
  pla
  sta ActorPY+1,x
  rts

GliderPushX:
  .word $00, $00, $00, $50
GliderPushY:
  .word $00, $50, $00, $00
.endproc

.a16
.i16
.export DrawEnemyGlider
.proc DrawEnemyGlider
  jsr FlipIfUp
 
  lda ActorVarB,x
  and #%110
  ora 0
  jml DispActor16x16Flipped

; So LWSS can use it too
FlipIfUp:
  lda ActorVarA,x
  beq Down
Up:
  lda #OAM_PRIORITY_2|OAM_YFLIP
  bra WasUp
Down:
   lda #OAM_PRIORITY_2
WasUp:
  sta 0
  rts
.endproc

.a16
.i16
.export RunEnemyLWSS
.proc RunEnemyLWSS
  lda ActorState,x
  and #255
  bne NoMove

  ; Increase the counter
  inc ActorVarB,x

  lda ActorVarB,x
  and #3
  cmp #2
  bne Skip

  ; Go up or down as needed at the right time
  lda ActorVarA,x
  bne Up
Down:
  lda ActorPY,x
  add #$30
  sta ActorPY,x
  bra Skip
Up:
  lda ActorPY,x
  sub #$30
  sta ActorPY,x
Skip:

  ; Flip sometimes
  lda ActorVarB,x
  and #3
  cmp #0
  bne :+
    jsl ActorTurnAround
  :
NoMove:

  ; Wrap vertically
  ; (fix later?)
  lda ActorPY,x
  sub #$100
  and #$0ff0
  ora #$1000
  add #$100
  sta ActorPY,x
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawEnemyLWSS
.proc DrawEnemyLWSS
  jsr DrawEnemyGlider::FlipIfUp

  lda ActorVarB,x
  and #2
  ora #12
  ora 0
  jml DispActor16x16
.endproc

.a16
.i16
.export RunKnuckleSandwich
.proc RunKnuckleSandwich
  rtl
.endproc

.a16
.i16
.export DrawKnuckleSandwich
.proc DrawKnuckleSandwich
  rtl
.endproc

.a16
.i16
.export RunKnuckleSandwichSign
.proc RunKnuckleSandwichSign
  rtl
.endproc

.a16
.i16
.export DrawKnuckleSandwichSign
.proc DrawKnuckleSandwichSign
  lda ActorVarA,x
  asl
  adc #OAM_PRIORITY_2|12
  jml DispActor16x16
.endproc

.a16
.i16
.export RunPumpkinBoat
.proc RunPumpkinBoat
  rtl
.endproc

.a16
.i16
.export DrawPumpkinBoat
.proc DrawPumpkinBoat
  lda framecount
  and #%100
  beq :+
    lda #.loword(Frame1)
    jml DispActorMetaPriority2
: lda #.loword(Frame2)
  jml DispActorMetaPriority2

Frame1:
  Row16x16  -12,  0,  $02, $04
  Row16x16  -12,  0,  $00
  EndMetasprite
Frame2:
  Row8x8    0, 0
  Row16x16  -12,  0,  $00
  EndMetasprite
.endproc

.a16
.i16
.export RunRideableBoat
.proc RunRideableBoat
  rtl
.endproc

.a16
.i16
.export DrawRideableBoat
.proc DrawRideableBoat
  lda framecount
  and #%100
  beq :+
    lda #.loword(Frame1)
    jml DispActorMetaPriority2
: lda #.loword(Frame2)
  jml DispActorMetaPriority2

Frame1:
  Row8x8    0,  0,  $12, $13, $14, $15
  Row8x8    0, -8,  $17
  EndMetasprite

Frame2:
  Row8x8    0,  0,  $16, $13, $14, $15
  Row8x8    0, -8,  $17
  EndMetasprite

.endproc

.a16
.i16
.export RunPumpkinMan
.proc RunPumpkinMan
  rtl
.endproc

.a16
.i16
.export DrawPumpkinMan
.proc DrawPumpkinMan
  rtl
.endproc

.a16
.i16
.export RunPumpkinSpiceLatte
.proc RunPumpkinSpiceLatte
  rtl
.endproc

.a16
.i16
.export DrawPumpkinSpiceLatte
.proc DrawPumpkinSpiceLatte
  jmp DrawGeorgeBottle
.endproc

.a16
.i16
.export RunPumpkin
.proc RunPumpkin
  rtl
.endproc

.a16
.i16
.export DrawPumpkin
.proc DrawPumpkin
  lda #OAM_PRIORITY_2|11
  jml DispActor16x16
.endproc

.a16
.i16
.export RunSwordSlime
.proc RunSwordSlime
  lda #$10
  jsl ActorWalkOnPlatform
  jsl ActorFall
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawSwordSlime
.proc DrawSwordSlime
  lda framecount
  lsr
  lsr
  lsr
  and #%110
  tay
  lda Frames,y
  jml DispActorMetaPriority2

Frame1:
  Row16x16  -4,  0,  $00
  Row16x16   4,  0,  $01
  EndMetasprite
Frame2:
  Row16x16  -4,  0,  $03
  Row16x16   4,  0,  $04
  EndMetasprite
Frame3:
  Row16x16  -4,  0,  $06
  Row16x16   4,  0,  $07
  EndMetasprite
Frames:
  .addr .loword(Frame1)
  .addr .loword(Frame2)
  .addr .loword(Frame3)
  .addr .loword(Frame2)
.endproc

.a16
.i16
.export RunSwordSlimeSword
.proc RunSwordSlimeSword
  inc ActorVarA,x
  lda ActorVarA,x
  cmp #20
  bne :+
    stz ActorType,x
  :
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawSwordSlimeSword
.proc DrawSwordSlimeSword
  lda ActorVarA,x
  lsr
  lsr
  bne :+
    ; Frame 1
    lda #.loword(VerticalFrame)
    jml DispActorMetaPriority2
  :
  dea
  bne :+
    ; Frame 2
    lda #10|OAM_PRIORITY_2
    jml DispActor16x16
  :
  dea
  bne :+
    ; Frame 3
    lda #12|OAM_PRIORITY_2
    jml DispActor16x16
  :
  ; Frame 4
  lda #.loword(HorizontalFrame)
  jml DispActorMetaPriority2

VerticalFrame:
  Row8x8   -4, -8,  $09
  Row8x8   -4,  0,  $19
  EndMetasprite

HorizontalFrame:
  Row8x8   -4,  0,  $1e, $1f
  EndMetasprite

HorizontalGreenFrame:
  Row8x8   -4,  0,  $0e, $0f
  EndMetasprite
.endproc

.a16
.i16
.export RunStrifeCloud
.proc RunStrifeCloud
  ; If too far, move in
  lda ActorPX,x
  sub PlayerPX
  abs
  cmp #2*256
  bcs Move

  lda ActorState,x
  and #255
  bne NoShoot
  jsl ActorLookAtPlayer

  lda ActorIndexInLevel,x
  eor framecount
  and #31
  bne NoShoot
    jsl FindFreeActorY
    bcc NoShoot
      jsl ActorClearY
      jsl ActorCopyPosXY ; Put the sword onscreen
      jsl AllocateDynamicSpriteSlot
      bcc NoShoot
          seta8
          sta ActorDynamicSlot,y
		  lda ActorDirection,x
		  sta ActorDirection,y

          lda #ActorStateValue::Paused
          sta ActorState,x
          seta16

          ; Copy over the origin point
          lda ActorPY,x
          sta ActorVY,y
          lda ActorPX,x
          sta ActorVX,y

          lda #Actor::StrifeCloudSword*2
          sta ActorType,y

          jsl InitActorY

          lda #15
          sta ActorTimer,x
NoShoot:
  rtl

Move:
  lda #$10
  jsl ActorWalk
  jsl ActorAutoBump
  jsl ActorHover
  rtl
.endproc

.a16
.i16
.export DrawStrifeCloud
.proc DrawStrifeCloud
  lda framecount
  lsr
  and #%110
  ora #OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunBurgerRiderJumper
.proc RunBurgerRiderJumper
  jsl ActorFall
  bcc InAir
    jsl ActorLookAtPlayer
    inc ActorVarB,x
    lda ActorVarB,x
    cmp #20
    bcc :+
      stz ActorVarB,x
      lda #.loword(-$60)
      sta ActorVY,x
    :
    jml PlayerActorCollisionHurt
InAir:
  lda #20
  jsl ActorWalk
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawBurgerRiderJumper
.proc DrawBurgerRiderJumper
  lda ActorOnGround,x
  and #255
  bne :+
    lda #.loword(InAir)
    jml DispActorMetaPriority2
  :
  lda #.loword(Standing)
  jml DispActorMetaPriority2

InAir:
  Row8x8   -4,-32+4,    $16, $17
  Row16x16  0,-16+4,    $04
  Row16x16  0,  0+4,    $08
  EndMetasprite

Standing:
  Row8x8   -4,-32+4,    $16, $17
  Row16x16  0,-16+4,    $04
  Row8x8   -4, -8+4,    $06, $07
  Row8x8   -4,  0+4,    $0f, $1f
  EndMetasprite
.endproc

.a16
.i16
.export RunDave
.proc RunDave
  lda #$10
  jsl ActorWalkOnPlatform
  jml ActorFall
.endproc

.a16
.i16
.export DrawDave
.proc DrawDave
  lda framecount
  lsr
  lsr
  and #%10
  tay
  lda WalkFrames,y
  jml DispActorMetaPriority2
Standing:
  Row16x16   0, -16,   $00
  Row16x16   0,   0,   $02
  EndMetasprite
Walk1:
  Row16x16   0,-16,    $00
  Row8x8    -4, -8,    $02, $03
  Row8x8    -4, 0,     $12, $15
  EndMetasprite
Walk2:
  Row16x16   0,-16,    $00
  Row8x8     -4, -8,    $02, $03
  Row8x8     -4, 0,     $14, $13
  EndMetasprite
Jump:
  Row16x16   0,-16,    $00
  Row8x8     -4, -8,    $02, $03
  Row8x8     -4, 0,     $0a, $0b
  EndMetasprite
Mad:
  Row16x16   0, -16,   $06
  Row16x16   0,   0,   $02
  EndMetasprite
WalkFrames:
  .word .loword(Walk1)
  .word .loword(Walk2)
.endproc


; A = pointer to the data for the current frame
; Y = bank for the data, should have the most significant bit set so that two DMAs are queued (for two rows in VRAM)
.a16
.i16
.proc DrawUpdate32x32DynamicFrame
  sty 0    ; Y = Source address bank | $8000
  phx
  pha
  lda ActorDynamicSlot,x
  and #7
  tax      ; X = Sprite number
  ldy #256 ; Y = Number of bytes
  pla      ; A = Source address
  .import QueueDynamicSpriteUpdate
  jsl QueueDynamicSpriteUpdate
  plx

DisplayOnly:
  lda ActorDynamicSlot,x
  and #7
  .import GetDynamicSpriteTileNumber
  jsl GetDynamicSpriteTileNumber
  ora #OAM_PRIORITY_2
  sta SpriteTileBase

  lda #.loword(Frame)
  .import DispActorMetaPriority2
  jml DispActorMetaPriority2

Frame: ; Should have the program bank = data bank here!
  Row16x16 -8, -16,  $00, $02
  Row16x16 -8,   0,  $04, $06
;  Row16x16 -8, -8,  $00, $02
;  Row16x16 -8,  8,  $04, $06
  EndMetasprite
.endproc
Draw32x32DynamicFrame = DrawUpdate32x32DynamicFrame::DisplayOnly


  .byt 0 ; Because the collision is one frame behind
StrifeCloudSwordFrames:
  .byt 0, 0, 0
  .byt 2, 2, 2
  .byt 4, 4, 4
  .byt 6, 6, 6
  .byt 8, 8, 8
  .byt 8, 8, 8, 8

.a16
.i16
.export RunStrifeCloudSword
.proc RunStrifeCloudSword
  inc ActorVarA,x
  lda ActorVarA,x
  cmp #5*3+4
  bne :+
    lda #2
    sta $7faaaa
    jml ActorSafeRemoveX
  :
  asl
  tay

  lda TableX,y
  jsl ActorNegIfLeft  
  add ActorVX,x
  sta ActorPX,x

  lda TableY,y
  add ActorVY,x
  sta ActorPY,x

  ; Pick a hitbox to use
  ldy ActorVarA,x
  lda StrifeCloudSwordFrames-2,y
  and #255
  tay
  lda CollisionFrames,y
  jsl PlayerActorCollisionMultiRect
  bcc :+
    .import HurtPlayer
    jml HurtPlayer
  :
  rtl

CollisionFrames:
  .word .loword(Frame1), .loword(Frame2), .loword(Frame3), .loword(Frame4), .loword(Frame5)  
; left, width, top, height
Frame1:
  CollisionMultiRect -12,  6, -31, 24
  CollisionMultiRectEnd
Frame2:
  CollisionMultiRect -10, 11, -28, 21
  CollisionMultiRectEnd
Frame3:
  CollisionMultiRect -7,  18, -17, 13
  CollisionMultiRectEnd
Frame4:
  CollisionMultiRect -6,  20, -13, 10
  CollisionMultiRectEnd
Frame5:
  CollisionMultiRect -7,  22, -7,  6
  CollisionMultiRectEnd

TableX:
  .word .loword(160), .loword(190), .loword(221), .loword(250), .loword(278), .loword(305), .loword(330), .loword(352), .loword(373), .loword(390), .loword(405), .loword(417), .loword(425), .loword(430), .loword(432)
  .word .loword(432), .loword(432), .loword(432), .loword(432)

TableY:
y_offset = 8*16
  .word .loword(-448+y_offset), .loword(-446+y_offset), .loword(-441+y_offset), .loword(-433+y_offset), .loword(-421+y_offset), .loword(-406+y_offset), .loword(-389+y_offset), .loword(-368+y_offset), .loword(-346+y_offset), .loword(-321+y_offset), .loword(-294+y_offset), .loword(-266+y_offset), .loword(-237+y_offset), .loword(-206+y_offset), .loword(-176+y_offset)
  .word .loword(-176+y_offset), .loword(-176+y_offset), .loword(-176+y_offset), .loword(-176+y_offset)
.endproc

.a16
.i16
.export RunDaveSord
.proc RunDaveSord
  rtl
.endproc

.a16
.i16
.export DrawStrifeCloudSword
.proc DrawStrifeCloudSword
  ldy ActorVarA,x
  lda StrifeCloudSwordFrames,y
  and #255
  tay
  lda Frames,y
  ldy #^DSSwordSwing | $8000
  jml DrawUpdate32x32DynamicFrame
Frames:
  .word .loword(DSSwordSwing+(512*0))
  .word .loword(DSSwordSwing+(512*1))
  .word .loword(DSSwordSwing+(512*2))
  .word .loword(DSSwordSwing+(512*3))
  .word .loword(DSSwordSwing+(512*4))
.endproc

.a16
.i16
.export DrawDaveSord
.proc DrawDaveSord
  lda ActorVarA,x
  and #.loword(~1)
  tay
  lda Frames,y
  ldy #^DSSordSwing | $8000
  jml DrawUpdate32x32DynamicFrame
Frames:
  .word .loword(DSSordSwing+(512*0))
  .word .loword(DSSordSwing+(512*1))
  .word .loword(DSSordSwing+(512*2))
  .word .loword(DSSordSwing+(512*3))
  .word .loword(DSSordSwing+(512*4))
.endproc

; -------------------------------------
; Maybe move particles to a separate file, though we don't have many yet
.pushseg
.segment "C_ParticleCode"
.a16
.i16
.export DrawPoofParticle
.proc DrawPoofParticle
  lda ParticleTimer,x
  lsr
  and #%110
  ora #CommonTileBase+$20+OAM_PRIORITY_2
  jsl DispParticle16x16
  rts
.endproc

.a16
.i16
.export RunPoofParticle
.proc RunPoofParticle
  inc ParticleTimer,x
  lda ParticleTimer,x
  cmp #4*3
  bne :+
    stz ParticleType,x
  :
  rts
.endproc


.a16
.i16
.export DrawLandingParticle
.proc DrawLandingParticle
  lda ParticleTimer,x
  lsr
  lsr
  lsr
  add #CommonTileBase+$38+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export RunLandingParticle
.proc RunLandingParticle
  inc ParticleTimer,x
  lda ParticleTimer,x
  cmp #8*2
  bne :+
    stz ParticleType,x
  :
  rts
.endproc

.a16
.i16
.export DrawPrizeParticle
.proc DrawPrizeParticle
  lda #CommonTileBase+$28+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export RunPrizeParticle
.proc RunPrizeParticle
  lda ParticlePX,x
  add ParticleVX,x
  sta ParticlePX,x

  lda ParticleVY,x
  add #4
  sta ParticleVY,x
  add ParticlePY,x
  sta ParticlePY,x

  dec ParticleTimer,x
  bne :+
    stz ParticleType,x
  :
  rts
.endproc


.a16
.i16
.export DrawWarningParticle
.proc DrawWarningParticle
  lda framecount
  and #%1000
  beq Flipped
  lda #CommonTileBase+$0a+OAM_PRIORITY_2
  jsl DispParticle16x16
  rts
Flipped:
  lda #CommonTileBase+$0a+OAM_PRIORITY_2+OAM_XFLIP
  jsl DispParticle16x16
  rts
.endproc

.a16
.i16
.export RunParticleDisappear
.proc RunParticleDisappear
  dec ParticleTimer,x
  bne :+
    stz ParticleType,x
  :
  rts
.endproc



.a16
.i16
.export DrawSmokeParticle
.proc DrawSmokeParticle
  jsl RandomByte
  and #$11
  sta 0
  jsl RandomByte
  xba
  and #OAM_XFLIP|OAM_YFLIP
  ora 0
  ora #CommonTileBase+$26+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc



.a16
.i16
.export DrawBricksParticle
.proc DrawBricksParticle
  lda #CommonTileBase+$3c+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export DrawGrayBricksParticle
.proc DrawGrayBricksParticle
  lda #CommonTileBase+$3b+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export RunBricksParticle
.proc RunBricksParticle
  lda ParticlePX,x
  add ParticleVX,x
  sta ParticlePX,x

  lda ParticleVY,x
  add #4
  sta ParticleVY,x
  add ParticlePY,x
  sta ParticlePY,x
  cmp #256*32
  bcs Erase

  dec ParticleTimer,x
  bne :+
Erase:
    stz ParticleType,x
  :

.if 0
  lda ParticlePX,x
  ldy ParticlePY,x
  phx
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  plx  
  cmp #$4000
  bcc :+
    lda ParticleVY,x
    lsr
    eor #$ffff
    inc a
    sta ParticleVY,x
  :
.endif

  rts
.endproc
.popseg


; Check for collision with a rideable 16x16 thing
.a16
.i16
.export CollideRide
.proc CollideRide
  ; Check for collision with player
  lda PlayerVY
  bpl :+
  clc
  rtl
: jml PlayerActorCollision
.endproc

; Allocate a dynamic sprite slot if there isn't already one
.a16
.i16
.export AllocateDynamicSlotIfNeeded
.proc AllocateDynamicSlotIfNeeded
  bit ActorDynamicSlot-1,x
  bpl AlreadyDynamic
    jsl AllocateDynamicSpriteSlot
    bcs :+
      stz ActorType,x ; Get rid of the type if it can't allocate
      rtl
    :
    seta8
    sta ActorDynamicSlot,x
    seta16
AlreadyDynamic:
  sec
  rtl
.endproc

.export AllocateDynamicSpriteSlotForY
.proc AllocateDynamicSpriteSlotForY
  jsl AllocateDynamicSpriteSlot
  bcs :+
    tdc ; Clear accumulator
    sta ActorType,y ; Get rid of the type if it can't allocate
    clc
    rtl
  :
  seta8
  sta ActorDynamicSlot,y
  seta16
  sec
  rtl
.endproc

; A = explosion size
.a16
.i16
.export ChangeToExplosion
.proc ChangeToExplosion
  sta ActorTimer,x
  jsl AllocateDynamicSlotIfNeeded

  ; Save the position into the velocity
  lda ActorPX,x
  sta ActorVX,x
  lda ActorPY,x
  sta ActorVY,x
  stz ActorVarA,x ; Increasing radius
  lda #1
  sta ActorVarB,x ; First explosion actor

  lda #Actor::PlayerProjectile16x16*2
  sta ActorType,x
  lda #PlayerProjectileType::Explosion
  sta ActorProjectileType,x

  ; Make a second poof
  jsl FindFreeProjectileY
  bcc :+
    lda ActorType,x
    sta ActorType,y
    lda ActorTimer,x
    sta ActorTimer,y
    lda ActorProjectileType,x
    sta ActorProjectileType,y
    lda ActorPX,x
    sta ActorPX,y
    sta ActorVX,y
    lda ActorPY,x
    sta ActorPY,y
    sta ActorVY,y
    seta8
    lda ActorDynamicSlot,x
    sta ActorDynamicSlot,y
    seta16
    tdc ; Clear accumulator
    sta ActorVarA,y
    sta ActorVarB,y ; Second explosion actor
  :
  rtl
.endproc

; Less precise sin/cos table used by e.g. missile smoke generation.
; These are indexed by angle through the whole circle
; and scaled by 64.
; (90*7/8)s*64=
ThwaiteSineTable:
  .byt   0, 12, 24, 36, 45, 53, 59, 63
ThwaiteCosineTable:
  .byt  64, 63, 59, 53, 45, 36, 24, 12
  .byt   0,<-12,<-24,<-36,<-45,<-53,<-59,<-63
  .byt <-64,<-63,<-59,<-53,<-45,<-36,<-24,<-12
  .byt   0, 12, 24, 36, 45, 53, 59, 63


; Calculates a horizontal and vertical speed from a speed and an angle
; input: A (speed) Y (angle, 0-31)
; output: 0,1 (X position), 2,3 (Y position)
.export ThwaiteSpeedAngle2Offset
.proc ThwaiteSpeedAngle2Offset
  php
  seta8
  sta M7MCAND ; 16-bit factor
  stz M7MCAND
  lda ThwaiteCosineTable,y
  sta M7MUL ; 8-bit factor

  lda M7PRODLO
  sta 0
  lda M7PRODHI
  sta 1

  ; --------

  lda ThwaiteSineTable,y
  sta M7MUL ; 8-bit factor

  lda M7PRODLO
  sta 2
  lda M7PRODHI
  sta 3
  plp
  rts
.endproc

; Calculates a horizontal and vertical speed from a speed and an angle
; input: A (speed) Y (angle, 0-255 times 2)
; output: 0,1,2 (X position), 3,4,5 (Y position)
.import MathSinTable, MathCosTable
.export SpeedAngle2Offset256
.proc SpeedAngle2Offset256
  php

  phb
  phk
  plb
  seta8
  sta M7MUL ; 8-bit factor

  lda MathCosTable+0,y
  sta M7MCAND ; 16-bit factor
  lda MathCosTable+1,y
  sta M7MCAND

  lda M7PRODLO
  sta 0
  lda M7PRODHI
  sta 1
  lda M7PRODBANK
  sta 2

  ; --------

  lda MathSinTable+0,y
  sta M7MCAND ; 16-bit factor
  lda MathSinTable+1,y
  sta M7MCAND

  lda M7PRODLO
  sta 3
  lda M7PRODHI
  sta 4
  lda M7PRODBANK
  sta 5
  plb
  plp
  rtl
.endproc

.export ActorExpire
.proc ActorExpire
  dec ActorTimer,x
  bne :+
    jsl ActorSafeRemoveX
  :
  rts
.endproc


.a16
.export ActorBecomePoof
.proc ActorBecomePoof
  jsl ActorSafeRemoveX
  jsl FindFreeParticleY
  bcc Exit
    lda #Particle::Poof
    sta ParticleType,y
    lda ActorPX,x
    sta ParticlePX,y
    lda ActorPY,x
    sub ActorHeight,x
    add #4*16
    sta ParticlePY,y
Exit:
  rtl
.endproc

.a16
.proc ActorMakePoofAtOffset
  jsl FindFreeParticleY
  bcc Exit
    lda #Particle::Poof
    sta ParticleType,y
    lda ActorPX,x
    add 0
    sta ParticlePX,y
    lda ActorPY,x
    add 2
    sta ParticlePY,y
Exit:
  rtl
.endproc

.segment "C_ActorCommon" ; Must be in the same bank as RunAllActors
.export ActorRunOverrideList
.proc ActorRunOverrideList
  .addr .loword(Nothing)
  .addr .loword(Hooked)
  .addr .loword(Flying)
Nothing:
  tyx
  rts

Hooked:
  tyx

  ; Find the hook!
  ldy #ProjectileStart
@Loop:
  lda ActorType,y
  cmp #Actor::PlayerProjectile16x16*2
  bne :+
  lda ActorProjectileType,y
  cmp #PlayerProjectileType::FishingHook
  beq FoundHook
: tya
  add #ActorSize
  tay
  cpy #ProjectileEnd
  bne @Loop

; Failed to find the hook
  lda TailAttackDirection
  and #>KEY_UP
  bne :+
GetStunned:
    seta8
    lda #ActorStateValue::Stunned
    sta ActorState,x
    seta16
    stz ActorVX,x
    lda #180
    sta ActorTimer,x
    rts
  :

  stz ActorVX,x
  lda TailAttackDirection
  and #>KEY_LEFT
  beq :+
    lda #.loword(-$30)
    sta ActorVX,x
  :
  lda TailAttackDirection
  and #>KEY_RIGHT
  beq :+
    lda #.loword($30)
    sta ActorVX,x
  :


  lda #ActorOverrideValue::Flying
  sta ActorTimer,x

  lda #.loword(-$70)
  sta ActorVY,x
  rts
FoundHook:
  lda ActorPX,y
  sta ActorPX,x
  lda ActorPY,y
  add #12*16
  sta ActorPY,x
  rts

Flying:
  tyx

  jsl ActorApplyXVelocity
  jsl ActorFall
  bcs GetStunned
  .import ActorGetShot
  jsl ActorGetShot
  rts
.endproc

.pushseg
.segment "SordSwing"
DSSordSwing:
.incbin "../tilesetsX/DSSordSwing.chr"

.segment "SwordSwing"
DSSwordSwing:
.incbin "../tilesetsX/DSSwordSwing.chr"
.popseg
