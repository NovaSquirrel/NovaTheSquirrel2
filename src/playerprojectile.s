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
.import CollideRide, ThwaiteSpeedAngle2Offset, ActorTryUpInteraction, ActorTryDownInteraction, ActorWalk, ActorFall, ActorAutoBump
.import ChangeToExplosion, PlayerActorCollision, ActorGravity, ActorApplyVelocity, ActorApplyXVelocity, PlayerNegIfLeft
.import DispActor16x16Flipped, DispActor16x16FlippedAbsolute, SpeedAngle2Offset256
.import ActorSafeRemoveY, BlockRunInteractionBelow

.assert ^ChangeToExplosion = ^RunPlayerProjectile, error, "Player projectiles and other actors should share a bank"

.segment "ActorData"
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
DrawProjectileCopyReduce = DrawProjectileCopy::Reduce
.export DrawProjectileCopyReduce

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
  lda #OAM_PRIORITY_2|$28
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
  lsr ; %01110000
  lsr ; %00111000
  lsr ; %00011100
  lsr ; %00001110
  and  #%00001110
  tay
  lda Frames,y
  jml DispActor16x16FlippedAbsolute

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
  asr_n 3
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
  phx
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionBelow
  plx
  ; Insert additional types the Below interaction doesn't do
  cmp #Block::Ice
  beq ExplodeBlock
  rts
ExplodeBlock:
  pla ; Pop the return address off
  tdc
  jsl ChangeBlock
  bra ExpireThen
.endproc

.pushseg
.segment "DynamicExplosion"
DSExplosion:
.incbin "../tilesets4/DSExplosion.chrsfc"
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
    and #7
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
  and #7
  .import GetDynamicSpriteTileNumber
  jsl GetDynamicSpriteTileNumber
  ora #OAM_PRIORITY_2
  sta SpriteTileBase

  lda #.loword(Frame)
  .import DispActorMetaPriority2
  jml DispActorMetaPriority2
;  lda #(6*16)|OAM_PRIORITY_2
;  jml DispActor16x16

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
  jml ActorSafeRemoveY

Bump:
  ; Must be moving in order to bump
  lda ActorVX,y
  ora ActorVY,y
  bne :+
    rtl
  :
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
  jsl ActorSafeRemoveY
  lda #$04
  bra AddDamage  

DamageAndRemoveHalf:
  jsl ActorSafeRemoveY
  lda #$08
  bra AddDamage

DamageAndRemove:
  jsl ActorSafeRemoveY
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
  lda #0 ; <--- only the copy projectile copies, so don't need ActorSafeRemoveY
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
  .word Actor::BubbleCat*2
  .word Actor::BubbleBuddy*2
  .word Actor::BubbleMoai*2
  .word Actor::SkateboardMoai*2
  .word Actor::ExplodingFries*2
  .word Actor::BurgerRider*2
  .word Actor::EnemyGlider*2
  .word Actor::EnemyLWSS*2
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

      ; Originally zero'd PlayerVY here, but that made it so you couldn't jump off of burgers?
      sec
      rtl
: clc
Exit:
  rtl
.endproc
