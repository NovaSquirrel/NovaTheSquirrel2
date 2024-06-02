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
.import BlockRunInteractionBelow, CountProjectileAmount
.import InitActorX, CalculateNextPlayerFrame
.import AllocateDynamicSpriteSlot, FreeDynamicSpriteSlot, QueueDynamicSpriteUpdate, GetDynamicSpriteTileNumber

.export AbilityIcons, AbilityGraphics, AbilityTilesetForId, AbilityRunRoutineForId, AbilityDrawRoutineForId

.segment "AbilityGraphics"
AbilityIcons:
  .incbin "../tilesets4/AbilityIcons.chrsfc"
AbilityGraphics:
  .incbin "../tilesets4/AbilityMiscellaneous.chrsfc"
  .incbin "../tilesets4/AbilityHammerBubbles.chrsfc"
  .incbin "../tilesets4/AbilityMirror.chrsfc"
  .incbin "../tilesets4/AbilityRemote.chrsfc"
  .incbin "../tilesets4/AbilityWater.chrsfc"
  .incbin "../tilesets4/AbilityFishing.chrsfc"
  .incbin "../tilesets4/AbilityBurger.chrsfc"
  .incbin "../tilesets4/AbilityFire.chrsfc"
  .incbin "../tilesets4/AbilityIce.chrsfc"
  .incbin "../tilesets4/AbilityRocket.chrsfc"
  .incbin "../tilesets4/AbilitySword.chrsfc"
SetNone   = 0 ; Don't need anything
.enum
SetMisc
SetHammer
SetMirror
SetRemote
SetWater
SetFishing
SetBurger
SetFire
SetIce
SetRocket
SetSword
.endenum

.segment "C_Player"
AbilityTilesetForId:
  .byt SetNone   ; None
  .byt SetBurger ; Burger
  .byt SetMisc   ; Glider
  .byt SetMisc   ; Bomb
  .byt SetIce    ; Ice
  .byt SetFire   ; Fire
  .byt SetWater  ; Water
  .byt SetHammer ; Hammer
  .byt SetFishing; Fishing
  .byt SetMisc   ; Yoyo
  .byt SetSword  ; Sword
  .byt SetMirror ; Mirror
  .byt SetNone   ; Wing
  .byt SetRemote ; Remote
  .byt SetRocket ; Rocket
  .byt SetHammer ; Bubble
  .byt SetNone   ; Bounce
AbilityRunRoutineForId:
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
  .addr .loword(RunAbilitySword)
  .addr .loword(RunAbilityMirror)
  .addr .loword(RunAbilityWing)
  .addr .loword(RunAbilityRemote)
  .addr .loword(RunAbilityRocket)
  .addr .loword(RunAbilityBubble)
AbilityDrawRoutineForId:
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilityBomb)
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilityFishing)
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilitySword)
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilityNone)
  .addr .loword(DrawAbilityBubble)
; -----------------------------------------------------------------------------
.a8
.proc DrawAbilityNone
  rts
.endproc

.a8
.export StepTailSwish
.proc StepTailSwish
  lda TailAttackTimer
  pha
  pha
  dea
  lsr
  tax ; <--- Make sure higher byte of A is clear
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

.a8
.proc AllowChangingDirectionDuringAbility
  lda keydown+1
  and #>KEY_LEFT
  beq NotLeft
  lda ForceControllerBits+1
  and #>KEY_RIGHT
  bne NotLeft
    lda #1
    sta PlayerDir
NotLeft:

  lda keydown+1
  and #>KEY_RIGHT
  beq NotRight
  lda ForceControllerBits+1
  and #>KEY_LEFT
  bne NotRight
    stz PlayerDir
NotRight:
  rts
.endproc

.a8
.proc UpdateAttackFrameWithHoldFrame
  inc PlayerHoldingSomething
  jsl CalculateNextPlayerFrame
  seta8
  dec PlayerHoldingSomething
  lda PlayerFrame
  sta TailAttackFrame
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
    jsl InitActorX

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
  jsl InitActorX

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
  jsl InitActorX

  lda #PlayerProjectileType::Burger
  sta ActorProjectileType,x

  lda #40
  sta ActorTimer,x
  stz ActorVarA,x

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
    jsl InitActorX

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
    jsl InitActorX

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
    jsl InitActorX
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
.proc DrawAbilityBomb
  lda TailAttackDirection
  and #>KEY_DOWN
  beq :+
    rts
  :
  .import MathSinTable, MathCosTable
  seta16
  jsr RunAbilityBomb::GetAimAngle
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
  ldx HighPriorityOAMIndex

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
  sta HighPriorityOAMIndex
  seta8
  rts

.a16
Reduce:
  asr_n 10
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
  bne DontMakeProjectile
IceSide:
    lda PlayerDownRecently
    beq @NotDownRecently
      seta16
      jsl FindFreeProjectileX
      bcc DontMakeProjectile
      jsr DoIceShared
      stz ActorVarA,x
      asl ActorTimer,x
      jsr AbilityPositionProjectile16x16
      rts
    @NotDownRecently:

    seta16
    jsl FindFreeProjectileX
    bcc DontMakeProjectile
    jsr DoIceShared
    jsr AbilityPositionProjectile16x16
  DontMakeProjectile:
  rts

.a16
DoIceShared:
  lda #Actor::PlayerProjectile16x16*2
  sta ActorType,x
  jsl InitActorX

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
    jsl InitActorX

    lda #PlayerProjectileType::FireBall
    sta ActorProjectileType,x

    jsr AbilityPositionProjectile8x8

    lda #75
    sta ActorTimer,x

    ; Horizontal speed
    lda #$20
    sta ActorVarA,x
    lda PlayerDownRecently
    and #255
    bne DownUp
    lda TailAttackDirection
    and #>KEY_DOWN
    beq :+
DownUp:
       stz ActorVarA,x
    :
    ; But zero the velocity so that the FireStill projectile doesn't move due to uninitialized memory
    stz ActorVX,x

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
    jsl InitActorX

    seta8
    stz ActorDirection,x
    seta16

    lda #PlayerProjectileType::WaterBottle
    sta ActorProjectileType,x

    lda PlayerPY
    sub #20<<4
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
    jsl InitActorX

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
  jsr UpdateAttackFrameWithHoldFrame


  ; -----

  ; Allow some measure of detecting how long the fishing rod has been out, for the
  ; early cancel code.
  lda TailAttackTimer
  cmp #20
  beq :+
    inc TailAttackTimer
  :
  rts
.endproc

.a8
.proc DrawAbilityFishing
  .import DispActor8x8
  ; Display fishing rod
  tdc ; Clear A
  lda PlayerDir
  tay
  ldx HighPriorityOAMIndex

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
  sta HighPriorityOAMIndex

  ; sizes get restored after this
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
.proc RunAbilitySword
; TODO: Make sure the dynamic sprite slot can get freed if the sword ability is interrupted!
; TailAttackVariable+0: 0=Normal, 2=Charging, 3=Throwing animation
; TailAttackVariable+1: Charging time
ChargeTime = 20

  lda TailAttackTimer
  cmp #2 ; When the charging happens it's set to 2 because 1 allocates stuff
  beq :+
SkipCharge:
  jmp NotCharge
: lda TailAttackVariable
  beq SkipCharge
    jsr AllowChangingDirectionDuringAbility

    lda keydown
    and #AttackKeys
    jne NotChargeRelease
      stz TailAttackTimer
      stz TailAttackVariable

      lda TailAttackDynamicSlot
      jsl FreeDynamicSpriteSlot
      seta8
      lda TailAttackVariable+1
      cmp #ChargeTime
      bcc @NoThrow
      ; Animate
      lda #9 ; Skip ahead
      sta TailAttackTimer
      lda #3 ; Do not draw the sword while doing the attack animation
      sta TailAttackVariable
      seta16
      jsl FindFreeProjectileX
      bcc @NoThrow
        lda #Actor::PlayerProjectile16x16*2
        sta ActorType,x
        jsl InitActorX
        lda #PlayerProjectileType::ThrownSword
        sta ActorProjectileType,x
        stz ActorTimer,x ; Animation timer here
        stz ActorVarA,x  ; Whether the sword hit a button yet
        stz ActorVarB,x  ; Vertical deceleration
        stz ActorVY,x    ; Vertical speed
        lda #$38
        sta ActorVarC,x  ; Horizontal speed
        seta8
        lda PlayerDir
        sta ActorDirection,x
        seta16
        lda PlayerPY
        sub #11*16
        sta ActorPY,x
        lda #12*16
        jsl PlayerNegIfLeft
        add PlayerPX
        sta ActorPX,x

        ; Diagonal throws
        lda keydown
        and #KEY_UP
        beq :+
           lda #.loword(1)
           sta ActorVarB,x
           lda #.loword(-$38)
           sta ActorVY,x
        :
        lda keydown
        and #KEY_DOWN
        beq :+
           lda #.loword(-1)
           sta ActorVarB,x
           lda #.loword($38)
           sta ActorVY,x
        :
      @NoThrow:
      seta8
    NotChargeRelease:

    ; Build up toward the charge
    lda TailAttackVariable+1
    cmp #ChargeTime
    bcs :+
      inc TailAttackVariable+1
    :

    ; Hold the sword
    lda #PlayerFrame::SWORD1
    sta TailAttackFrame

    ; If you're moving left or right then use a walk animation (and it will draw the sword differently)
    lda keydown+1
    and #>(KEY_LEFT|KEY_RIGHT)
    beq :+
      inc PlayerHoldingSomething
      jsl CalculateNextPlayerFrame
      seta8
      dec PlayerHoldingSomething
      lda PlayerFrame
      sta TailAttackFrame
    :
    rts
  NotCharge:

  ; Throw animation if = 3, so skip a lot of stuff
  lda TailAttackVariable
  cmp #3
  bne :++
    inc TailAttackTimer

    lda TailAttackTimer
    tax ; <--- Make sure higher byte of A is clear
    lda AttackSwordSequence-1,x
    sta TailAttackFrame

    lda TailAttackTimer
    cmp #(AttackSwordSequenceEnd-AttackSwordSequence-1)
    bne :+
      stz TailAttackTimer
    :
    rts
  :

  ; Show the right frame in the animation
  lda TailAttackTimer
  pha
  tax ; <--- Make sure higher byte of A is clear
  lda AttackSwordSequence-1,x
  sta TailAttackFrame

  inc TailAttackTimer
  ; End the animation when it's done
  pla

  ; Allocate and queue frame A when the timer has just started
  .a8
  cmp #1
  bne NotInit
    jsl AllocateDynamicSpriteSlot
    bcs :+
      ; Bail out of the attack
      stz TailAttackTimer
      rts
    :
    sta TailAttackDynamicSlot

    seta16
    lda #.loword(DSSwordAbility)
    jmp QueueUpdate
  NotInit:

  ; Frame B
  .a8
  cmp #11
  jne NotB
    seta16
    lda PlayerPY
    sub #17*16
    tay
    lda #16*16
    jsl PlayerNegIfLeft
    add PlayerPX
    jsl GetLevelPtrXY
    jsl GetBlockFlag
    jsl BlockRunInteractionBelow

    ; Try making the small projectile
    jsl FindFreeProjectileX
    bcc :+
      lda #Actor::PlayerProjectile*2
      sta ActorType,x
      jsl InitActorX
      lda #PlayerProjectileType::SwordSwipe
      sta ActorProjectileType,x

      seta8
      lda PlayerDir
      sta ActorDirection,x
      seta16
      lda PlayerPY
      sub #11*16
      sta ActorPY,x
      lda #16*16
      jsl PlayerNegIfLeft
      add PlayerPX
      sta ActorPX,x
      lda #16
      sta ActorTimer,x
    :

    ; Make a bigger hitbox directly in front of the swipe
    jsl FindFreeProjectileX
    bcc :+
      lda #Actor::PlayerProjectile*2
      sta ActorType,x
      jsl InitActorX
      lda #22*16
      sta ActorWidth,x
      lda #PlayerHeight
      sta ActorHeight,x
      lda #PlayerProjectileType::SwordSwipeNearby
      sta ActorProjectileType,x

      lda PlayerPY
      sta ActorPY,x
      lda #10*16
      jsl PlayerNegIfLeft
      add PlayerPX
      sta ActorPX,x
      lda #3
      sta ActorTimer,x
    :

    lda #.loword(DSSwordAbility+512*1)
    jmp QueueUpdate
  NotB:

  .a8
  cmp #13
  bne NotC
    seta16
    lda PlayerPY
    sub #8*16
    tay
    lda #9*16
    jsl PlayerNegIfLeft
    add PlayerPX
    jsl GetLevelPtrXY
    jsl GetBlockFlag
    jsl BlockRunInteractionBelow

    lda #.loword(DSSwordAbility+512*2)
    jmp QueueUpdate
  NotC:

  .a8
  cmp #15
  bne NotD
    seta16
    lda #.loword(DSSwordAbility+512*3)
    jmp QueueUpdate
  NotD:

  .a8
  cmp #(AttackSwordSequenceEnd-AttackSwordSequence-1)
  bne NotEnd
    lda keydown ; Keep going?
    and #AttackKeys
    beq :+
      lda #2
      sta TailAttackTimer
      sta TailAttackVariable
      seta16
      lda #.loword(DSSwordAbility)
      jmp QueueUpdate
    :
    .a8

    stz TailAttackTimer
    lda TailAttackDynamicSlot
    jsl FreeDynamicSpriteSlot
    rts
  NotEnd:
  rts

.a16
.i16
QueueUpdate:
  pha
  lda TailAttackDynamicSlot
  and #ACTOR_DYNAMIC_SLOT_MASK
  tax
  ldy #256
  lda #^DSSwordAbility | $8000
  sta 0
  pla
  jsl QueueDynamicSpriteUpdate
  rts
; SWORD1 - frame A
; SWORD2 - frame A
; SWORD3 - frame A
; SWORD4 - frame B
; SWORD5 - frame C
; SWORD6 - frame D
; IDLE   - frame D

; 1 SWORD1, 2 SWORD1 3 SWORD1 4 SWORD1 5 SWORD1
; 6 SWORD2  7 SWORD2
; 8 SWORD3  9 SWORD3 10 SWORD3
; 11 SWORD4 12 SWORD4
; 13 SWORD5 14 SWORD5
; 15 SWORD6 16 SWORD6 17 SWORD6
; 18 IDLE   19 IDLE 20 IDLE 21 IDLE 22 IDLE

AttackSwordSequence:
  .byt PlayerFrame::SWORD1, PlayerFrame::SWORD1, PlayerFrame::SWORD1, PlayerFrame::SWORD1, PlayerFrame::SWORD1
  .byt PlayerFrame::SWORD2, PlayerFrame::SWORD2
  .byt PlayerFrame::SWORD3, PlayerFrame::SWORD3, PlayerFrame::SWORD3
  .byt PlayerFrame::SWORD4, PlayerFrame::SWORD4
  .byt PlayerFrame::SWORD5, PlayerFrame::SWORD5
  .byt PlayerFrame::SWORD6, PlayerFrame::SWORD6, PlayerFrame::SWORD6
  .byt PlayerFrame::IDLE, PlayerFrame::IDLE, PlayerFrame::IDLE, PlayerFrame::IDLE, PlayerFrame::IDLE
AttackSwordSequenceEnd:
.endproc

.pushseg
.segment "PlayerSwordSwing"
DSSwordAbility:
.incbin "../tilesetsX/DSSwordAbility.chr"
.popseg

.a8
.proc DrawAbilitySword
  seta16
  lda TailAttackDynamicSlot
  and #ACTOR_DYNAMIC_SLOT_MASK
  jsl GetDynamicSpriteTileNumber
  sta SpriteTileBase
  seta8

  lda TailAttackVariable
  cmp #3 ; Throwing
  bne :+
    rts
  :
  cmp #2 ; Charging
  bne NotCharging
  lda PlayerFrame
  cmp #PlayerFrame::SWORD1
  beq NotCharging
    ldy #.loword(Frame1Holding)
    lda TailAttackVariable+1
    cmp #RunAbilitySword::ChargeTime
    bcc :+
      ldy #.loword(Frame1HoldingCharged)
    :

    lda PlayerDir
    pha
    eor #1
    sta PlayerDir
    jsr DrawAbilityFrame
    pla
    sta PlayerDir
    rts
  NotCharging:

  lda TailAttackVariable+1
  cmp #RunAbilitySword::ChargeTime
  bcc :+
    ldy #.loword(Frame1Charged)
    jmp DrawAbilityFrame
  :

  tdc ; Clear top byte of A
  lda OldTailAttackTimer
  dea
  tax
  lda RunAbilitySword::AttackSwordSequence,x
  cmp #PlayerFrame::IDLE
  bne :+
    lda #PlayerFrame::SWORD6+1
  :
  sub #PlayerFrame::SWORD1
  asl
  tax
  ldy Frames,x
  jsr DrawAbilityFrame
  rts

Frames:
  .addr Frame1, Frame2, Frame3, Frame4, Frame5, Frame6, Frame7

BH = 4   ; "Bottom half"
BR = $10 ; "Bottom row"
S16 = $02
S8  = $00
Frame1:
  ; Size, Tile, Y, +X, -X
  .lobytes S16, $00,    -35, -15,    0-(-15)-16
  .byt $80
Frame2:
  .lobytes S8,  BH+3,   -39,  -5,    0-(-5)-8
  .lobytes S8,  BH+3+BR,-39+8,-5,    0-(-5)-8
  .byt $80
Frame3:
  .lobytes S16, BH,    -30, -6,      0-(-6)-16
  .lobytes S16, BH+1,  -30, -6+8,    0-(-6+8)-16
  .byt $80
Frame4:
  .lobytes S16, 0,     -29,    2,    0-(2)-16
  .lobytes S16, BH,    -29+16, 2,    0-(2)-16
  .lobytes S8,  2,     -20,    2+16, 0-(2+16)-8
  .byt $80
Frame5:
  .lobytes S16, BH,    -16,   -4,    0-(-4)-16
  .lobytes S16, BH+1,  -16,   -4+8,  0-(-4+8)-16
  .lobytes S8,  BR+2,  -16-8, -4+16, 0-(-4+16)-8
  .byt $80
Frame6:
  .lobytes S16, 0,     -9-8,  -7,    0-(-7)-16
  .lobytes S16, 1,     -9-8,  -7+8,  0-(-7+8)-16
  .byt $80
Frame7:
  .lobytes S16, BH,    -11,   -16,   0-(-16)-16
  .byt $80

Frame1Charged:
  .lobytes S16, $02,    -35, -15,    0-(-15)-16
  .byt $80
Frame1Holding:
  .lobytes S16, $00,    -27, -9,    0-(-9)-16
  .byt $80
Frame1HoldingCharged:
  .lobytes S16, $02,    -27, -9,    0-(-9)-16
  .byt $80
.endproc

; Displays a an ability metasprite above the player
; Y = pointer to frame data to draw
; Format:
; Size, Tile, Y, X, -X
; 255
.a8
.proc DrawAbilityFrame
Pointer = 0
  sty Pointer
  ldx HighPriorityOAMIndex

  ldy #0
Loop:
  lda (Pointer),y ; Size
  bmi Exit
  sta OAMHI+1,x

  iny
  lda (Pointer),y ; Tile
  ora SpriteTileBase
  sta OAM_TILE,x

  iny
  lda (Pointer),y ; Y pos
  add PlayerDrawY
  sta OAM_YPOS,x

  iny
  lda PlayerDir
  bne Left
Right:
  lda PlayerDrawX
  add (Pointer),y
  sta OAM_XPOS,x
  lda #>(OAM_PRIORITY_2)
  sta OAM_ATTR,x
  iny ; Skip over -X
Next:
  iny
  inx
  inx
  inx
  inx
  bra Loop

Left:
  iny ; Skip over +X
  lda PlayerDrawX
  add (Pointer),y
  sta OAM_XPOS,x
  lda #>(OAM_XFLIP|OAM_PRIORITY_2)
  sta OAM_ATTR,x
  bra Next

Exit:
  stx HighPriorityOAMIndex
  rts
.endproc

.if 0
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
.endif

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
    jsl InitActorX

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
.i16
.proc RunAbilityBubble
; TailAttackVariable+0: Nonzero = Have already checked if there were bubbles when the ability started
; TailAttackVariable+1: Were there bubbles when the ability started?
; This is used to decide between tailswishing when sending out stored bubbles or to do the style where it fires it off after releasing the button
  jsr AllowChangingDirectionDuringAbility

  ; At the start of the ability, check if there are bubbles
  lda TailAttackVariable
  bne InitializedWithCount
    inc TailAttackVariable
    jsr HaveFloatingBubbles
    sta TailAttackVariable+1
  InitializedWithCount:

  ; Need Up+Attack or Down+Attack to charge
  lda TailAttackVariable+1
  beq ChargeUp
  lda TailAttackDirection
  and #>(KEY_DOWN|KEY_UP)
  bne ChargeUp
  jsr StepTailSwish
  rts
ChargeUp:

  lda TailAttackDirection
  and #>(KEY_DOWN|KEY_UP)
  beq :+
    lda #1
    sta AbilityMovementLock
  :
  jsr UpdateAttackFrameWithHoldFrame

  lda keydown ; Cancel the charging
  and #AttackKeys
  bne :+
    stz TailAttackTimer
    stz AbilityMovementLock
    rts
  :

  ; Force a bubble out immediately if there's none
  jsr HaveFloatingBubbles
  beq ForceBubble

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
    jsl InitActorX

    lda #PlayerProjectileType::BubbleHeld
    sta ActorProjectileType,x
    ; But if using down+attack, override
    lda TailAttackDirection
    and #>(KEY_DOWN|KEY_UP)
    beq :+
      lda #PlayerProjectileType::Bubble
      sta ActorProjectileType,x
    :

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

; Bubbles are floating if their timer is zero
; Returns answer in Z flag and accumulator (1 if true, 0 if false)
HaveFloatingBubbles:
  seta16
  ldy #ProjectileStart
@Loop:
  lda ActorType,y
  cmp #Actor::PlayerProjectile*2
  bne :+
  lda ActorTimer,y ; Flying bubbles don't count here
  bne :+
    seta8
    lda #1 ; High byte is zero because a BNE skips this
    rts
  :
  .a16 ; Branch not taken? still in 16-bit land
  tya
  add #ActorSize
  tay
  cpy #ProjectileEnd
  bne @Loop
  tdc ; Clear accumulator
  seta8
  rts
.endproc

.a8
.i16
.proc DrawAbilityBubble
  lda TailAttackVariable+1
  beq ChargeUp
  lda TailAttackDirection
  and #>(KEY_DOWN|KEY_UP)
  bne ChargeUp
  rts
ChargeUp:

  ; Display bubble wand
  tdc ; Clear A
  lda PlayerDir
  tay
  ldx HighPriorityOAMIndex
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
  stx HighPriorityOAMIndex
  rts
WandOffsetX: .lobytes 1, -16-1
WandAttrib: .byt >(OAM_PRIORITY_2), >(OAM_XFLIP|OAM_PRIORITY_2)
.endproc

.a16
.i16
.export FindFreeProjectileX
.proc FindFreeProjectileX
  phy
  lda #ProjectileStart
  clc
Loop:
  tax
  ldy ActorType,x ; Don't care what gets loaded into Y, but it will set flags
  beq Found
  adc #ActorSize
  cmp #ProjectileEnd ; Carry should always be clear at this point
  bcc Loop
NotFound:
  ply
  clc
  rtl
Found:
  ply
  seta8
  lda #255
  sta ActorDynamicSlot,x
  seta16
  sec
  rtl
.endproc

; Used by ChangeToExplosion
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
