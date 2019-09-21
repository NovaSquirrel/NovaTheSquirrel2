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
.include "actorenum.s"
.smart

.segment "ActorData"
CommonTileBase = $40

.import DispActor16x16, DispActor8x8, DispParticle8x8
.import ActorWalk, ActorWalkOnPlatform, ActorFall, ActorAutoBump, ActorApplyXVelocity
.import PlayerActorCollision, TwoActorCollision
.import PlayerActorCollisionHurt, ActorLookAtPlayer
.import FindFreeProjectileY

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
  rtl
.endproc

.a16
.i16
.proc DrawProjectileCopy
  rtl
.endproc

.a16
.i16
.proc RunProjectileBurger
  jsl ActorApplyXVelocity

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

  dec ActorTimer,x
  bne :+
    stz ActorType,x
  :
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
  dec ActorTimer,x
  bne :+
    stz ActorType,x
  :

  jsl ActorFall
  lda ActorVarA,x
  sta TempVal ; keep the VarA that was actually used for later
  jsl ActorWalk
  jsl ActorAutoBump

  lda ActorVarA,x
  beq :+
  dec ActorVarA,x
  lda #10
  sta ActorTimer,x
: sta ActorVX,x ; required to be nonzero for the projectile to collide with enemies

  jsl CollideRide
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
  rtl
.endproc

.a16
.i16
.proc DrawProjectileFireBall
  rtl
.endproc

.a16
.i16
.proc RunProjectileFireStill
  rtl
.endproc

.a16
.i16
.proc DrawProjectileFireStill
  rtl
.endproc

.a16
.i16
.proc RunProjectileWaterBottle
  rtl
.endproc

.a16
.i16
.proc DrawProjectileWaterBottle
  rtl
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
  rtl
.endproc

.a16
.i16
.proc DrawProjectileFishingHook
  rtl
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
.proc RunProjectileRemoteMissile
  rtl
.endproc

.a16
.i16
.proc DrawProjectileRemoteMissile
  rtl
.endproc

.a16
.i16
.proc RunProjectileBubble
  rtl
.endproc

.a16
.i16
.proc DrawProjectileBubble
  rtl
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

  dec ActorTimer,x
  bne :+
    stz ActorType,x
  :
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
  lda #0
  jml DispActor16x16
.endproc

.a16
.i16
.export RunBurger
.proc RunBurger
  lda #3
  jml ActorWalk
.endproc

.a16
.i16
.export DrawSpikedHat
.proc DrawSpikedHat
  lda #(3*2)|OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunSpikedHat
.proc RunSpikedHat
  lda #$20
  jsl ActorWalkOnPlatform
  jsl ActorFall
  jml PlayerActorCollisionHurt
.endproc



.a16
.i16
.export DrawCannonH
.proc DrawCannonH
  rtl
.endproc

.a16
.i16
.export DrawCannonV
.proc DrawCannonV
  rtl
.endproc

.a16
.i16
.export DrawCheckpoint
.proc DrawCheckpoint
  rtl
.endproc

.a16
.i16
.export RunCheckpoint
.proc RunCheckpoint
  rtl
.endproc

.a16
.i16
.export DrawMovingPlatform
.proc DrawMovingPlatform
  rtl
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
  asl
  jsl ActorWalk
  jsl ActorAutoBump
:

  ; Count up a timer before starting to move
  seta8
  lda ActorState,x
  bne :+
    lda ActorOnScreen,x
    beq :+
      lda ActorVarC,x
      cmp #$20+$30/2
      beq :+
        inc ActorVarC,x
  :
  seta16

  jsl ActorFall
  jml PlayerActorCollisionHurt
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
  rtl
.endproc

.a16
.i16
.export RunBurgerCannonV
.proc RunBurgerCannonV
  rtl
.endproc

; -------------------------------------
.a16
.i16
.export DrawPoof
.proc DrawPoof
  rts
.endproc

.a16
.i16
.export RunPoof
.proc RunPoof
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
    lda ActorType,y
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
  ; Use ProjectileType to decide what to do.
  ; For now just stun.
  seta8
  lda #ActorStateValue::Stunned
  sta ActorState,x
  seta16

  lda #180
  sta ActorTimer,x

  ldy ProjectileIndex
  lda #0
  sta ActorType,y
  rtl
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


