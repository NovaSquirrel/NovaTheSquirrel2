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
.globalzp PlayerPY
.globalzp PlayerPYTop
.globalzp PlayerVX
.globalzp PlayerVY
.globalzp PlayerFrame
.globalzp PlayerFrameXFlip
.globalzp PlayerFrameYFlip
.globalzp PlayerDir
.globalzp PlayerWasRunning
.global PlayerOnLadder, PlayerInWater
.global PlayerOnSlope
.global PlayerSlopeType
.global PlayerRolling
.globalzp PlayerOnGround
.globalzp PlayerOnGroundLast
.globalzp PlayerHealth
.global PlayerInvincible
.global PlayerNeedsGround
.global PlayerNeedsGroundAtAttack
.globalzp PlayerWalkLock
.globalzp PlayerDownTimer
.globalzp PlayerJumping
.globalzp OamPtr
.globalzp TempVal
.globalzp TempX
.globalzp TempY
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
  Wheel
  Mirror
  Wing
  Remote
  Rocket
  Bubble
.endenum

.global   NeedAbilityChange
.global   NeedAbilityChangeSilent

.global PlayerJumpCancel
.global PlayerJumpCancelLock
.global PlayerWantsToJump
.global PlayerWantsToAttack
.global PlayerAccelSpeed
.global PlayerDecelSpeed
.global JumpGracePeriod
.global PlayerRidingSomething, PlayerRidingFG2
.global PlayerDrawX
.global PlayerDrawY
.global PlayerOAMIndex

.global ColumnUpdateAddress, ColumnUpdateAddress2
.global ColumnUpdateBuffer, ColumnUpdateBuffer2
.global RowUpdateAddress, RowUpdateAddress2
.global RowUpdateBuffer, RowUpdateBuffer2

BLOCK_UPDATE_COUNT = 8
.global BlockUpdateAddress
.global BlockUpdateDataTL
.global BlockUpdateDataTR
.global BlockUpdateDataBL
.global BlockUpdateDataBR
.global BlockUpdateDataEnd

MaxDelayedBlockEdits = 15
.global DelayedBlockEditType
.global DelayedBlockEditTime
.global DelayedBlockEditAddr

GENERIC_UPDATE_COUNT = 4
.global GenericUpdateDestination
.global GenericUpdateLength
.global GenericUpdateSource
.global GenericUpdateFlags

.globalzp LevelColumnSize
.global GetLevelPtrXY_Ptr
.global GetBlockX_Ptr
.global GetBlockY_Ptr
.global GetBlockXCoord_Ptr
.global GetBlockYCoord_Ptr
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

ActorLen = 24
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
.endenum

ParticleLen = 32
.global ParticleStart
.globalzp ParticleSize
.global ParticleEnd
.globalzp ParticleType
.globalzp ParticlePX
.globalzp ParticlePY
.globalzp ParticleVX
.globalzp ParticleVY
.globalzp ParticleTimer

.global SpriteTileSlots
.global SpritePaletteSlots
.global BackgroundPaletteSlots
.global GraphicalAssets
.global PaletteInUse        ; For dynamically allocating palette slots
.global PaletteInUseLast
.global PaletteRequestIndex
.global PaletteRequestValue

.global GraphicUploadOffset
SpriteXYOffset = GraphicUploadOffset ; in the order X, Y

.globalzp LevelNumber
.globalzp StartedLevelNumber
.global NeedLevelReload
.global NeedLevelRerender

RERENDER_INIT_ENTITIES_TELEPORT = $80
.global RerenderInitEntities


; ScreenFlags stores flags for each screen in the level; so far there's just one flag:
SCREEN_BOUNDARY = 1 ; boundary on left side of screen

.global LevelZeroWhenLoad_Start
.global LevelZeroWhenLoad_End

.global ScreenFlags
.global ScreenFlagsDummy
.global LevelBackgroundColor
.global LevelBackgroundId
.global FGScrollXPixels, FGScrollYPixels, BGScrollXPixels, BGScrollYPixels, BGEffectRAM
.global FG2ScrollXPixels, FG2ScrollYPixels
.globalzp LevelActorPointer
.global VerticalLevelFlag
.global VerticalScrollEnabled
.global GlassForegroundEffect, TwoLayerLevel, TwoLayerInteraction, ForegroundLayerThree, SecondFGTilemapPointer
.global LevelFadeIn, LevelIrisIn, RunGameLogic, FG2MovementRoutine
.global ToggleSwitch1, ToggleSwitch2, ToggleSwitch3

.globalzp random1
.globalzp random2
.globalzp HDMASTART_Mirror, CGWSEL_Mirror, CGADSUB_Mirror


.global NMIHandler ; For keeping effects stable
.global IRQHandler ; For changing what IRQ does for different effects
.global HDMA_Buffer1
.global HDMA_Buffer2
.global Scratchpad
.global RenderBuffer, NameFontRenderTop, NameFontRenderBottom
.global LevelActorBuffer

.global UseTapRun, TapReleaseTimer, TapReleaseButton, IsTapRun
.global TailAttackTimer, TailAttackDirection, TailAttackFrame, TailAttackCooldown, TailAttackVariable
.global AbilityMovementLock


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
