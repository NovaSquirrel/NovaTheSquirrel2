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
.smart

.segment "ActorData"
CommonTileBase = $40

.import DispActor16x16, DispActor8x8, DispParticle8x8, DispActor8x8WithOffset
.import DispParticle16x16
.import DispActor16x16Flipped, DispActor16x16FlippedAbsolute
.import DispActorMeta, DispActorMetaRight
.import ActorWalk, ActorWalkOnPlatform, ActorFall, ActorAutoBump, ActorApplyXVelocity
.import ActorTurnAround
.import ActorHover, ActorRoverMovement, CountActorAmount, ActorCopyPosXY, ActorClearY
.import PlayerActorCollision, TwoActorCollision
.import PlayerActorCollisionHurt, ActorLookAtPlayer
.import FindFreeProjectileY, ActorApplyVelocity, ActorGravity
.import PlayerNegIfLeft, ActorNegIfLeft
.import GetAngle512
.import ActorTryVertInteraction

; -------------------------------------

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

  ; Remove the subpixels
  lda 0
  jsr Reduce
  pha
  sta 0

  lda 2
  jsr Reduce
  pha
  sta 2

  seta8
  lda 0
  sta SpriteXYOffset+0
  lda 2
  add #4
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
  add #4
  sta SpriteXYOffset+1
  seta16

  lda #CommonTileBase+$2b+OAM_PRIORITY_2
  jml DispActor8x8WithOffset

; DispActor8x8WithOffset takes pixels, which is a problem.
; Shift the subpixels off.
Reduce:
  asr_n 4
  rts
.endproc

.a16
.i16
.proc RunProjectileBurger
  lda #$30
  jsl ActorWalk
  bcs Explode

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
Explode:
    lda #5*4
    jmp ChangeToExplosion
  :
  rtl
.endproc

.a16
.i16
.proc DrawProjectileBurger
  lda #32|OAM_PRIORITY_2
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
  rtl
.endproc

.a16
.i16
.proc DrawProjectileBomb
  rtl
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
  rtl
.endproc

.a16
.i16
.proc DrawProjectileIce
  lda #34|OAM_PRIORITY_2
  jml DispActor16x16
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
  ora #$3a|OAM_PRIORITY_2
  jml DispActor8x8
.endproc

.a16
.i16
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
  lda #OAM_PRIORITY_2|$28
  jml DispActor16x16
Nope:
  rtl
.endproc

.a16
.i16
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
  lda #1
  jsr SpeedAngle2Offset256
  ; Results in
  ; 0,1,2 X
  ; 3,4,5 Y
  jsr HalfLongVelocity
  jsr ActorApplyLongVelocity

  ; Calculate a value to compare against; only collide with one-way tiles if going down
  lda #$8000
  sta ActorVarC,x
  lda 4
  beq :+
  bmi :+
    lsr ActorVarC,x
  :

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


  ; Explode if necessary
  lda ActorPY,x
  sub #$80
  tay
  lda ActorPX,x
  jsl ActorTryVertInteraction
  cmp ActorVarC,x
  bcc :+
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
  lsr ; %01110000
  lsr ; %00111000
  lsr ; %00011100
  lsr ; %00001110
  and  #%00001110
  tay
  lda Frames,y
  jml DispActor16x16Flipped

Frames:
Up    = $2a
Diag  = $2c
Right = $2e
  PR = OAM_PRIORITY_2
  .word PR|Right, PR|Diag|OAM_YFLIP, PR|Up|OAM_YFLIP, PR|Diag|OAM_XFLIP|OAM_YFLIP
  .word PR|Right|OAM_XFLIP, PR|Diag|OAM_XFLIP, PR|Up, PR|Diag
.endproc

.a16
.i16
.proc RunProjectileBubble
  lda ActorTimer,x
  beq NotLaunched
    cmp #60
    bne :+
      stz ActorType,x
    :
    inc ActorTimer,x
	jsl ActorApplyVelocity
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

  ; Need to press attack, but not up or down
  lda keynew
  and #KEY_X|KEY_A|KEY_L|KEY_R
  beq :+
  lda keydown
  and #KEY_DOWN|KEY_UP
  bne :+
    inc ActorTimer,x
    lda #$50
    jsl PlayerNegIfLeft
    sta ActorVX,x
  :
  rtl

Divide:
  cmp #$8000
  ror
  cmp #$8000
  ror
  cmp #$8000
  ror
  rts
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
  jsl RandomByte
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

  jsr ActorExpire
  rtl
.endproc

.a16
.i16
.proc DrawProjectileExplosion
  lda #(6*16)|OAM_PRIORITY_2
  jml DispActor16x16
.endproc

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
    jsl ActorTryVertInteraction
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

  lda #$6|OAM_PRIORITY_2
  jml DispActor16x16
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
  .byt 4        ; 4 across
  .word .loword(-16), 0  ; X and Y
  .byt $00, $10, $10, $01
  .byt 255
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
  jsl CollideRide
  php

  seta8
  lda ActorState,x
  cmp #ActorStateValue::Init
  bne :+ ; change it to paused
    seta16
    lda ActorPX,x
    sta ActorVarA,x
    lda ActorPY,x
    sta ActorVarB,x
  :
  seta16

  lda framecount
  asl
  and #255
  asl
  tay
  lda #11
  jsr SpeedAngle2Offset256

  OldX = 6
  OldY = 8
  lda ActorPX,x
  sta OldX
  lda ActorPY,x
  sta OldY

  lda ActorVarA,x
  add 1
  sta ActorPX,x

  lda ActorVarB,x
  add 4
  sta ActorPY,x

  ; ---------------

  plp
  bcc NoRide
    seta8
    lda #2
    sta PlayerRidingSomething
    seta16
    stz PlayerVY
    lda ActorPY,x
    sub #$70
    sta PlayerPY

    lda ActorPX,x
    sub OldX
    add PlayerPX
    sta PlayerPX

;    lda ActorPY,x
;    sub OldY
;    add PlayerPY
;    sta PlayerPY
  NoRide:

  rtl
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
.i16
.export RunBurgerCannonV
.proc RunBurgerCannonV
  jsl ActorHover
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
  lda 0
  jsr DrawProjectileCopy::Reduce
  pha
  sta 0

  lda 2
  jsr DrawProjectileCopy::Reduce
  pha
  sta 2

  seta8
  lda 0
  add #4
  sta SpriteXYOffset+0
  lda 2
  add #4
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
  add #4
  sta SpriteXYOffset+0
  lda 2
  neg
  add #4
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
  jsl RunProjectileFireStill
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
    wdm 0
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
      jsr SpeedAngle2Offset256
      ply
      lda 1
      sta ActorVX,y
      lda 4
      sub #$40
      sta ActorVY,y

      lda #Actor::GeorgeBottle*2
      sta ActorType,y

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
  jsl RunProjectileWaterBottle
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
.export RunMirrorRabbit
.proc RunMirrorRabbit
  jsl ActorLookAtPlayer
  rtl
.endproc

.a16
.i16
.export DrawMirrorRabbit
.proc DrawMirrorRabbit
  lda #OAM_PRIORITY_2
  tsb SpriteTileBase
  lda #.loword(Rabbit2)
  jml DispActorMeta

Rabbit2:
  .byt 1|128    ; 16x16
  .word .loword(0), .loword(-16)     ; X and Y
  .byt $00
  .byt 1|128    ; 16x16
  .word .loword(0), .loword(0)     ; X and Y
  .byt $02
  .byt 255

Rabbit:
  .byt 2        ; 2 across
  .word .loword(-4), .loword(-24)  ; X and Y
  .byt $00, $01
  .byt 2        ; 2 across
  .word .loword(-4), .loword(-16)  ; X and Y
  .byt $0a, $1a
  .byt 1|128    ; 16x16
  .word .loword(0), .loword(0)     ; X and Y
  .byt $0b
  .byt 255
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






; -------------------------------------
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
  bcc :+
    stz ParticleType,x
  :

  dec ParticleTimer,x
  bne :+
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
  lda #0
  sta ActorType,y
  rtl

Bump:
  lda #.loword(-$30)
  sta ActorVY,x
BumpStunOnly:
  jsl ActorTurnAround
  seta8
  lda #ActorStateValue::Stunned
  sta ActorState,x
  seta16
  lda #90
  sta ActorTimer,x
  rtl


; Instantly kill anything
Kill:
  jml ActorBecomePoof

DamageALittle:
  lda #0
  sta ActorType,y
  lda #$04
  bra AddDamage  

DamageAndRemoveHalf:
  lda #0
  sta ActorType,y
  lda #$08
  bra AddDamage

DamageAndRemove:
  lda #0
  sta ActorType,y
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
  seta8
  lda #ActorStateValue::Stunned
  sta ActorState,x
  seta16
  lda #60
  sta ActorTimer,x
  rtl

HitProjectileResponse:
  .word .loword(StunAndRemove-1) ; Stun
  .word .loword(Copy-1) ; Copy
  .word .loword(Bump-1) ; Burger
  .word .loword(DamageAndRemove-1) ; Glider
  .word .loword(Bump-1) ; Bomb
  .word .loword(Bump-1) ; Ice
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
  lda #0
  sta ActorType,y

  ; Find the enemy's type
  ldy #0
: lda CopyEnemy,y
  beq @NoCopy
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
@NoCopy:
Nothing:
  rtl

CopyEnemy:
  .word Actor::FireWalk*2
  .word Actor::FireJump*2
  .word Actor::FireFlames*2
  .word Actor::FireFox*2
  .word Actor::Grillbert*2
  .word Actor::George*2
  .word Actor::Burger*2
  .word Actor::MirrorRabbit*2
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
.endproc



; Check for collision with a rideable 16x16 thing
.a16
.i16
.proc CollideRide
  ; Check for collision with player
  lda PlayerVY
  bpl :+
  clc
  rtl
: jml PlayerActorCollision
.endproc

.a16
.i16
.proc RideOnProjectile
  bcc Exit
    lda ActorPY,x
    cmp PlayerPY
    bcc :+
      seta8
      lda #2
      sta PlayerRidingSomething
      seta16
      lda ActorPY,x
      sub #$100
      sta PlayerPY

      stz PlayerVY
      sec
      rtl
: clc
Exit:
  rtl
.endproc

.a16
.i16
.proc ChangeToExplosion
  sta ActorTimer,x
  lda ActorPX,x
  sta ActorVX,x
  lda ActorPY,x
  sta ActorVY,x
  stz ActorVarA,x

  lda #Actor::PlayerProjectile16x16*2
  sta ActorType,x
  lda #PlayerProjectileType::Explosion
  sta ActorProjectileType,x
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
    lda #0
    sta ActorVarA,y
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
; output: 0,1,2 (X position), 2,3,4 (Y position)
.import MathSinTable, MathCosTable
.proc SpeedAngle2Offset256
  php
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
  plp
  rts
.endproc

.proc ActorExpire
  dec ActorTimer,x
  bne :+
    stz ActorType,x
  :
  rts
.endproc


.a16
.proc ActorBecomePoof
  phx
  lda ActorType,x
  stz ActorType,x
  tax
  .import ActorHeight
  lda f:ActorHeight,x
  sta 0
  plx

  jsl FindFreeParticleY
  bcc Exit
    lda #Particle::Poof
    sta ParticleType,y
    lda ActorPX,x
    sta ParticlePX,y
    lda ActorPY,x
    sub 0
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
  jsl ActorGetShot
  rts
.endproc

