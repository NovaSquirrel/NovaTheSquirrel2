.globalzp retraces
.globalzp framecount
.globalzp keydown
.globalzp keylast
.globalzp keynew
.globalzp ScrollX, ScrollY
.global   OldScrollX, OldScrollY
.globalzp FG2OffsetX, FG2OffsetY
.global   OldFG2OffsetX, OldFG2OffsetY
.globalzp LevelBlockPtr
.globalzp BlockFlag
.globalzp BlockRealX
.globalzp BlockRealY
.globalzp BlockTemp

.globalzp SpriteTileBase

.globalzp PlayerPX
.globalzp PlayerPXLeft
.globalzp PlayerPXRight
.globalzp PlayerPY
.globalzp PlayerPYTop
.globalzp PlayerVX
.globalzp PlayerVY
.globalzp PlayerFrame
.global PlayerFrameLast
.globalzp PlayerFrameXFlip
.globalzp PlayerFrameYFlip
.globalzp PlayerDir
.globalzp PlayerWasRunning
.global PlayerOnLadder, PlayerInWater
.global PlayerOnSlope
.global PlayerSlopeType
.global PlayerRolling
.global PlayerCameraTargetY, CameraDisableNudgeAbove, CameraShake
.globalzp PlayerOnGround
.globalzp PlayerOnGroundLast
.globalzp PlayerHealth
.global PlayerHoldingSomething
.global PlayerInvincible
.global PlayerNeedsGround
.global PlayerNeedsGroundAtAttack
.globalzp PlayerWalkLock
.globalzp PlayerDownTimer
.global PlayerDownRecently
.globalzp PlayerJumping
.globalzp OamPtr
.globalzp TempVal
.globalzp TouchTemp
.globalzp DecodePointer
.globalzp ScriptPointer
.globalzp ForceControllerBits
.globalzp ForceControllerTime

.globalzp PlayerAbility
.enum Ability
  None
  Burger
  Glider
  Bomb
  Ice
  Fire
  Water
  Hammer
  Fishing
  Yoyo
  Sword
  Mirror
  Wing
  Remote
  Rocket
  Bubble
  Bounce
.endenum

.global NeedAbilityChange
.global NeedAbilityChangeSilent
.global OfferAPress

.global PlayerJumpCancel
.global PlayerJumpCancelLock
.global PlayerWantsToJump
.global PlayerWantsToAttack
.global PlayerAccelSpeed
.global PlayerDecelSpeed
.global JumpGracePeriod
.global PlayerRidingSomething, PlayerRidingSomethingLast, PlayerRidingFG2
; 1 = Riding something normally, 2 = Don't update the PlayerCameraTargetY 
RIDING_NO_PLATFORM_SNAP = 2

.global PlayerDrawX
.global PlayerDrawY
.global PlayerOAMIndex
.global HighPriorityOAMIndex

.global ColumnUpdateAddress, ColumnUpdateAddress2
.global ColumnUpdateBuffer, ColumnUpdateBuffer2
.global RowUpdateAddress, RowUpdateAddress2
.global RowUpdateBuffer, RowUpdateBuffer2

BLOCK_UPDATE_COUNT = 8
.global BlockUpdateAddressTop
.global BlockUpdateAddressBottom
.global BlockUpdateDataTL
.global BlockUpdateDataTR
.global BlockUpdateDataBL
.global BlockUpdateDataBR
.global BlockUpdateDataEnd

MaxDelayedBlockEdits = 15
.global DelayedBlockEditType
.global DelayedBlockEditTime
.global DelayedBlockEditAddr

GENERIC_UPDATE_COUNT = 5
.global GenericUpdateDestination, GenericUpdateDestination2
.global GenericUpdateLength
.global GenericUpdateSource, GenericUpdateSource2
.global GenericUpdateFlags

; Not indexed like the above
.global GenericUpdateByteTotal

DYNAMIC_SPRITE_SLOTS = 8
.global DynamicSpriteSlotUsed
.global DynamicSpriteAddress ;\ For checking if the frame is already uploaded
.global DynamicSpriteBank    ;/
ACTOR_DYNAMIC_SLOT_MASK = 7*2 ; For getting it from ActorDynamicSlot with 16-bit accumulator

.globalzp LevelColumnSize, LevelColumnMask
.global GetLevelPtrXY_Ptr
.global GetBlockX_Ptr
.global GetBlockY_Ptr
.global GetBlockXCoord_Ptr
.global GetBlockYCoord_Ptr
.global ScrollXLimit, ScrollYLimit
.global LevelBuf
.global LevelBufAlt
.global ColumnWords
.global ParallaxTilemap
.global LevelActorList
.global FirstActorOnScreen



.global OAM
.global OAMHI
OAM_XPOS = OAM+0
OAM_YPOS = OAM+1
OAM_TILE = OAM+2
OAM_ATTR = OAM+3

ActorLen = 32
ProjectileLen = 8
.global ActorStart
.globalzp ActorSize
.global ActorEnd
.globalzp ActorType
.globalzp ActorPX
.globalzp ActorPY
.globalzp ActorVX
.globalzp ActorVY
.globalzp ActorVarA
.globalzp ActorVarB
.globalzp ActorVarC
.globalzp ActorDirection
.globalzp ActorIndexInLevel
.globalzp ActorTimer
.globalzp ActorState
.globalzp ActorOnGround
.globalzp ActorOnScreen
.globalzp ActorDamage
.globalzp ActorProjectileType
.globalzp ActorDynamicSlot
.globalzp ActorWidth
.globalzp ActorHeight
.global ProjectileStart
.global ProjectileEnd

.enum PlayerProjectileType
  Stun
  Copy
  Burger
  Glider
  Bomb
  Ice
  FireBall
  FireStill
  WaterBottle
  Hammer
  FishingHook
  Yoyo
  Mirror
  RemoteHand
  RemoteCar
  RemoteMissile
  Bubble
  Explosion
  CopyAnimation
  BubbleHeld
  CopyFailAnimation
  SwordSwipe
  SwordSwipeNearby
  ThrownSword
.endenum

ParticleLen = 20
.global ParticleStart
.globalzp ParticleSize
.global ParticleEnd
.globalzp ParticleType
.globalzp ParticlePX
.globalzp ParticlePY
.globalzp ParticleVX
.globalzp ParticleVY
.globalzp ParticleTimer
.globalzp ParticleVariable

.globalzp ActorIterationLimit
.globalzp ParticleIterationLimit

; Actors that other actors might be interested in
ActorAdvertiseLen = 5
.global ActorAdvertisePointer     ; Prevous frame, series of pointers
.global ActorAdvertiseType        ; Type of each actor in the list, to speed up finding the actor you want
.globalzp ActorAdvertiseCount       ; How many pointers there are (counts up by 2)
.global ActorAdvertisePointerNext ; For the next frame
.global ActorAdvertiseCountNext
.global ActorAdvertiseTypeNext

.global SpriteTileSlots
.global SpritePaletteSlots
.global BackgroundPaletteSlots
.global GraphicalAssets
.global PaletteInUse, PaletteInUseLast        ; For dynamically allocating palette slots
.global SpriteTilesInUse, SpriteTilesInUseLast ; And sprite tileset slots
.global SpriteTilesUseTime ; Framecount when the slot is used
.global PaletteRequestIndex, PaletteRequestValue
.global SpriteTilesRequestDestination, SpriteTilesRequestSource

.global GraphicUploadOffset
SpriteXYOffset = GraphicUploadOffset ; in the order X, Y

.globalzp StartedLevelNumber
.global NeedLevelReload
.global NeedLevelRerender

RERENDER_INIT_ENTITIES_TELEPORT = $80
.global RerenderInitEntities


; ScreenFlags stores flags for each screen in the level - which mostly means scrolling boundaries
.global ScreenFlags
SF_V_BARRIER_LEFT   = %10000000
SF_V_BARRIER_MIDDLE = %01000000
SF_H_BARRIER_LEFT   = %00100000 ; Top left
SF_H_BARRIER_RIGHT  = %00010000 ; Top right
SF_SPECIAL_MASK     = %00001111
.enum SF_SPECIAL
  NONE
  DEADLY_PIT ; Passing through the vertical barrier is harmful
.endenum

.global LevelZeroWhenLoad_Start
.global LevelZeroWhenLoad_End

.global LevelBackgroundColor
.global LevelBackgroundId
.global LevelColorMathId
.global FGScrollXPixels, FGScrollYPixels, BGScrollXPixels, BGScrollYPixels, BGEffectRAM, BGEffectRAM_Mirror
.global Layer1_ScrollXPixels, Layer1_ScrollYPixels, Layer2_ScrollXPixels, Layer2_ScrollYPixels
.global Layer3_ScrollXPixels, Layer3_ScrollYPixels, Layer4_ScrollXPixels, Layer4_ScrollYPixels

.globalzp LevelActorPointer
.global VerticalLevelFlag
.global VerticalScrollEnabled
.global LevelBGMode, GlassForegroundEffect, TwoLayerLevel, TwoLayerInteraction, ForegroundLayerThree, RenderLevelWithSprites, SecondFGTilemapPointer
.global LevelFadeIn, LevelIrisIn, GameplayHook, ScrollOverrideHook
.global ToggleSwitch1, ToggleSwitch2, ToggleSwitch3
.global UploadLevelGraphicsHook

.globalzp random1
.globalzp random2
.globalzp HDMASTART_Mirror, CGWSEL_Mirror, CGADSUB_Mirror


.global NMIHandler ; For keeping effects stable
.global IRQHandler ; For changing what IRQ does for different effects

.global HDMA_Buffer1
.global pv_hdma_bgm0, pv_hdma_tm0, pv_hdma_abi0, pv_hdma_cdi0, pv_hdma_col0, pv_hdma_bgcolor0
.global HDMA_Buffer2
.global pv_hdma_bgm1, pv_hdma_tm1, pv_hdma_abi1, pv_hdma_cdi1, pv_hdma_col1, pv_hdma_bgcolor1
.global mode7_hdma

.global Scratchpad
.global RenderBuffer, NameFontRenderTop, NameFontRenderBottom
.global LevelActorBuffer, LevelActorDefeatedAt

.global UseTapRun, TapReleaseTimer, TapReleaseButton, IsTapRun
.global TailAttackTimer, OldTailAttackTimer, TailAttackDirection, TailAttackFrame, TailAttackCooldown, TailAttackVariable, TailAttackDynamicSlot
.global AbilityMovementLock
.global CopyingAnimationTimer
.global InteractionByProjectile

; Save stuff
.global MoneyAmount
.global LevelCleared
.global LevelAvailable
.global CollectibleBits
.global EventFlag

.global GameStateStart
.global GameStateEnd
GameStateSize = GameStateEnd-GameStateStart
InventoryLen = 25

.global YourInventory, LevelInventory, InventoryEnd

.global CheckpointState, CheckpointX, CheckpointY, LevelHeaderPointer

.global CursorX
.global CursorY
.global AutoRepeatTimer

VWFStackLen   = 4
.global VWFStackL
.global VWFStackH
.global VWFStackB
.global VWFStackIndex
DialogStackLen = 4
.global DialogStackL
.global DialogStackH
.global DialogStackB
.global DialogStackIndex
DialogCharacterLen = 5
.global DialogCharacterId
.global DialogCharacterX
.global DialogCharacterY
.global DialogCharacterFlip



.global OverworldPlayerX
.global OverworldPlayerY
.global OverworldMap
.global OverworldDirection

.global SmallRenderBuffer
.global DecompressBuffer
.global IrisEffectBuffer1, IrisEffectBuffer2
.global LevelSpriteFGBuffer
