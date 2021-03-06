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
.include "playerframe.inc"
.include "blockenum.s"
.include "actorenum.s"
.smart
.import ActorClearX, PlayerNegIfLeft, SpeedAngle2Offset256
.import BlockRunInteractionBelow

.segment "C_Player"

.export AbilityIcons, AbilityGraphics, AbilityTilesetForId, AbilityRoutineForId
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

  ; Tail swish can interact with blocks
  ; Maybe add an interaction later specifically for tail collision?
  lda TailAttackTimer
  cmp #6*2
  bne :+
    seta16
    lda PlayerPY
    sub #10*16
    tay
    lda #13*16
    jsl PlayerNegIfLeft
    add PlayerPX
    jsl GetLevelPtrXY
    jsl GetBlockFlag
    jsl BlockRunInteractionBelow
    seta8
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
; Will need to make sure there this can't push you into a wall or ceiling!
.a16
.proc AbilityPositionProjectile16x16Below
  phx
  lda PlayerPY
  sub #PlayerHeight+$80 ; Top of the head
  tay
  lda PlayerPX
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionBelow
  plx

  lda BlockFlag
  bpl NotSolid
SolidFromFG2:
    lda PlayerPY
    add #$0100
    sta ActorPY,x
    bra WasSolid
NotSolid:

  ; If the second layer exists and has interaction, try it too
  bit TwoLayerInteraction-1
  bpl NotTwoLayer
    phx
    lda PlayerPY
    sub #PlayerHeight+$80 ; Top of the head
    add FG2OffsetY
    tay
    lda PlayerPX
    add FG2OffsetX
    jsl GetLevelPtrXY
    lda #$4000
    tsb LevelBlockPtr
    lda [LevelBlockPtr]
    tax
    lda f:BlockFlags,x
    sta BlockFlag
    jsl BlockRunInteractionBelow
    plx
    lda BlockFlag
    bmi SolidFromFG2
NotTwoLayer:

  lda PlayerPY
  sta ActorPY,x
  sub #$100
  sta PlayerPY
WasSolid:

  lda PlayerPX
  sta ActorPX,x
  rts
.endproc

.a8
.proc RunAbilityNone
  jsr StepTailSwish
  bne :+
    lda TailAttackDirection
    and #>KEY_UP
    bne CopyInstead
    seta16
    jsl FindFreeProjectileX
    bcc :+
    lda #Actor::PlayerProjectile*2
    sta ActorType,x

    stz ActorProjectileType,x

    jsr AbilityPositionProjectile8x8
    jsr Shared
  :
  rts

CopyInstead:
  seta16
  jsl FindFreeProjectileX
  bcc _rts
  lda #Actor::PlayerProjectile16x16*2
  sta ActorType,x

  lda #PlayerProjectileType::Copy
  sta ActorProjectileType,x

  jsr AbilityPositionProjectile16x16
  jsr Shared

_rts:
  rts

.a16
Shared:
  stz ActorTimer,x
  lda #4*16
  jsl PlayerNegIfLeft
  sta ActorVX,x
  rts
.endproc

.a8
.proc RunAbilityBurger
  lda PlayerNeedsGroundAtAttack
  bne NoBelow
  lda TailAttackDirection
  and #>KEY_DOWN
  beq NoBelow
    jsr StepTailSwishBelow
    beq BurgerBelow
    rts
BurgerBelow:
    inc PlayerNeedsGround
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

  ; Set this for the actor riding stuff to work correctly
  lda #3*16
  jsl PlayerNegIfLeft
  sta ActorVX,x

  ; But also set this for ActorWalk
  seta8
  lda PlayerDir
  sta ActorDirection,x
  seta16
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
  :
  rts
.endproc

.a8
.proc RunAbilityBomb
  lda TailAttackDirection
  and #>KEY_DOWN
  jne BombBelow

  ; Hold frame 1 of the throw animation
  lda #PlayerFrame::THROW1
  sta TailAttackFrame

  ; If throwing, use the throw animation
  lda TailAttackVariable
  jne ThrowNow
  seta16
  lda keydown
  and #AttackKeys
  seta8
  bne :+
    inc TailAttackVariable
    bra NoIncreaseAngle
  :

  ; Increase the angle
  lda TailAttackVariable+1
  cmp #30
  beq :+
    ina
    sta TailAttackVariable+1
  :
NoIncreaseAngle:

  .import MathSinTable, MathCosTable
  seta16
  jsr GetAimAngle
  lda f:MathCosTable,x
  jsr Reduce
  sta 0
  lda f:MathSinTable,x
  jsr Reduce
  sta 2
  seta8

  ; Draw the angle
  tdc ; Clear A
  lda PlayerDir
  tay
  ldx OamPtr

  lda PlayerDrawX
  add 0
  sub #4
  sta OAM_XPOS+(4*0),x
  lda PlayerDrawY
  sub #16
  add 2
  sta OAM_YPOS+(4*0),x

  seta16
  lda #$6c|OAM_PRIORITY_2
  sta OAM_TILE+(4*0),x
  stz OAMHI+(4*0),x
  txa
  add #4
  sta OamPtr
  seta8
  rts

.a16
Reduce:
  asr_n 10
  rts

.a16
GetAimAngle:
  lda TailAttackVariable+1
  asl
  and #255
  sta 0

  lda PlayerDir
  lsr
  bcs @Left
@Right:
  tdc ; Clear accumulator
  sub 0
  bra @Shared
@Left:
  lda #128
  add 0
@Shared:
  asl
  and #$1fe
  tax
  rts

.a8
; Do the throw animation and make the bomb
ThrowNow:
  jsr StepThrowAnim
  bne NoThrow
    seta16
    jsl FindFreeProjectileX
    bcc NoThrow
    lda #Actor::PlayerProjectile16x16*2
    sta ActorType,x

    lda #PlayerProjectileType::Bomb
    sta ActorProjectileType,x

    jsr AbilityPositionProjectile16x16

    lda #140
    sta ActorTimer,x

    ; Set the angle correctly
    phx
    jsr GetAimAngle
    txy
    plx
    lda #3
    jsl SpeedAngle2Offset256
    lda 1
    asr_n 2
    sta ActorVX,x
    lda 4
    asr_n 2
    sub #$20
    sta ActorVY,x

    seta8
    lda PlayerDir
    sta ActorDirection,x
    stz ActorVarA,x
  NoThrow:
  rts

BombBelow:
  jsr StepTailSwish
  bne NoBombBelow
    seta16
    jsl FindFreeProjectileX
    bcc NoBombBelow
    stz ActorVX,x
    stz ActorVY,x
    lda #Actor::PlayerProjectile16x16*2
    sta ActorType,x
    lda #PlayerProjectileType::Bomb
    sta ActorProjectileType,x
    lda #200
    sta ActorTimer,x
    sta ActorVarA,x ; Needs to be nonzero
    seta8
    lda PlayerDir
    sta ActorDirection,x
    seta16
    jsr AbilityPositionProjectile16x16
  NoBombBelow:
  rts
.endproc

.a8
.proc RunAbilityIce
  lda PlayerNeedsGroundAtAttack
  bne NoBelow
  lda TailAttackDirection
  and #>KEY_DOWN
  beq NoBelow
    jsr StepTailSwishBelow
    beq IceBelow
    rts
IceBelow:
    inc PlayerNeedsGround
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

  lda TailAttackDirection
  and #>KEY_UP
  beq :+
    lda #.loword(-$30)
    sta ActorVY,x
  :

  seta8
  lda PlayerDir
  sta ActorDirection,x
  seta16
  rts
.endproc

.a8
.proc RunAbilityFire
  jsr StepTailSwish
  bne No
    seta16
    jsl FindFreeProjectileX
    bcc No
    lda #Actor::PlayerProjectile*2
    sta ActorType,x

    lda #PlayerProjectileType::FireBall
    sta ActorProjectileType,x

    jsr AbilityPositionProjectile8x8

    lda #75
    sta ActorTimer,x

    ; Horizontal speed
    lda #$20
    sta ActorVarA,x
    lda TailAttackDirection
    and #>KEY_DOWN
    beq :+
       stz ActorVarA,x
    :

    ; Vertical speed
    stz ActorVY,x
    lda TailAttackDirection
    and #>KEY_UP
    beq :+
       lda #.loword(-$50)
       sta ActorVY,x
    :

    seta8
    lda PlayerDir
    sta ActorDirection,x
    seta16
No:
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
  lda TailAttackTimer
  cmp #1
  bne NoCreateHook
    seta16
    jsl FindFreeProjectileX
    bcc NoCreateHook
    lda #Actor::PlayerProjectile16x16*2
    sta ActorType,x

    lda #PlayerProjectileType::FishingHook
    sta ActorProjectileType,x

    lda PlayerPY
    sub #3<<4
    sta ActorPY,x
    lda PlayerPX
    sta ActorPX,x

    lda #.loword(-$20)
    sta ActorVY,x
    stz ActorVarC,x

    seta8
    lda TailAttackDirection
    and #>(KEY_DOWN)
    beq :+
      lda #<(-$10)
      sta ActorVY,x
      
    :
    lda TailAttackDirection
    and #>(KEY_UP)
    beq :+
      lda #<(-$38)
      sta ActorVY,x

      lda PlayerDownRecently ; Go straight up if down+up+attack is used
      sta ActorVarC,x
      beq :+
		lda #<(-$58)
		sta ActorVY,x
    :

    lda PlayerDir
    sta ActorDirection,x
NoCreateHook:

  lda #1
  sta AbilityMovementLock
  lda #PlayerFrame::FISHING
  sta TailAttackFrame


  ; -----

  ; Display fishing rod
  tdc ; Clear A
  lda PlayerDir
  tay
  ldx OamPtr

  lda PlayerDrawX
  add RodOffsetX,y
  sta OAM_XPOS+(4*0),x
  sta OAM_XPOS+(4*1),x
  sta OAM_XPOS+(4*2),x
  add RodOffsetX2,y
  sta OAM_XPOS+(4*3),x

  lda PlayerDrawY
  sub #25
  sta OAM_YPOS+(4*0),x
  sta OAM_YPOS+(4*3),x
  add #8
  sta OAM_YPOS+(4*1),x
  add #8
  sta OAM_YPOS+(4*2),x

  lda #$28
  sta OAM_TILE+(4*0),x
  lda #$38
  sta OAM_TILE+(4*1),x
  lda #$39
  sta OAM_TILE+(4*2),x
  lda #$29
  sta OAM_TILE+(4*3),x
  lda RodAttrib,y
  sta OAM_ATTR+(4*0),x
  sta OAM_ATTR+(4*1),x
  sta OAM_ATTR+(4*2),x
  sta OAM_ATTR+(4*3),x
  seta16
  stz OAMHI+1+(4*0),x
  stz OAMHI+1+(4*1),x
  stz OAMHI+1+(4*2),x
  stz OAMHI+1+(4*3),x
  txa
  add #4*4
  sta OamPtr
  seta8

  ; -----

  ; Allow some measure of detecting how long the fishing rod has been out, for the
  ; early cancel code.
  lda TailAttackTimer
  cmp #20
  beq :+
    inc TailAttackTimer
  :
  rts
RodOffsetX: .lobytes 0, -8
RodOffsetX2: .lobytes 8, -8
RodAttrib: .byt >(OAM_PRIORITY_2), >(OAM_XFLIP|OAM_PRIORITY_2)
.endproc

.a8
.proc RunAbilityYoyo
  jsr StepTailSwish
  rts
.endproc

.a8
.proc RunAbilityWheel
  lda #1
  sta PlayerRolling

  lda retraces
  lsr
  lsr
  and #3
  add #PlayerFrame::ROLL1
  sta TailAttackFrame

  lda retraces
  and #16
  beq :+
    inc PlayerFrameXFlip
    inc PlayerFrameYFlip
  :
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
  lda TailAttackTimer
  cmp #1
  bne NoCreateRocket
    seta16
    jsl FindFreeProjectileX
    bcc NoCreateRocket
    lda #Actor::PlayerProjectile16x16*2
    sta ActorType,x

    lda #PlayerProjectileType::RemoteMissile
    sta ActorProjectileType,x

    lda PlayerPY
    sub #7<<4
    sta ActorPY,x
    lda PlayerPX
    sta ActorPX,x

    stz ActorVarA,x
    stz ActorVarB,x ; Angle

    lda #60
    sta ActorTimer,x
    seta8

    lda PlayerDir     ; If facing left, make missile face left too
    beq :+
      lda #128
      sta ActorVarB,x ; Angle
    :

    lda TailAttackDirection
    and #>(KEY_UP)
    beq :+
      lda #192
      sta ActorVarB,x ; Angle
    :

NoCreateRocket:

  ; Allow some measure of detecting how long the missile has been out, for the
  ; early detonation code.
  lda TailAttackTimer
  cmp #20
  beq :+
    inc TailAttackTimer
  :
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
  and #AttackKeys
  bne :+
    stz TailAttackTimer
    stz AbilityMovementLock
    rts
  :

  ; Force a bubble out immediately if there's none
  seta16
  .import CountProjectileAmount
  lda #Actor::PlayerProjectile*2
  jsl CountProjectileAmount
  beq ForceBubble
  seta8

  ; Use the amount of time the ability has been out instead of the frame counter
  lda TailAttackTimer
  ina
  ora #$f0
  sta TailAttackTimer
  cmp #$f8
  bne NoBubble
ForceBubble:
    seta16
    jsl FindFreeProjectileX
    bcc NoBubble
	jsl ActorClearX
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
  seta8
  lda #255
  sta ActorDynamicSlot,x
  seta16
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
  beq Found
  tya
  add #ActorSize
  tay
  cpy #ProjectileEnd
  bne Loop
  clc
  rtl
Found:
  seta8
  lda #255
  sta ActorDynamicSlot,y
  seta16
  sec
  rtl
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
