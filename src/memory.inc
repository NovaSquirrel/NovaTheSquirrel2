.globalzp retraces
.globalzp framecount
.globalzp keydown
.globalzp keylast
.globalzp keynew
.globalzp ScrollX
.globalzp ScrollY
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
.global PlayerOnLadder
.global PlayerOnSlope
.global PlayerSlopeType
.global PlayerRolling
.globalzp PlayerOnGround
.globalzp PlayerOnGroundLast
.globalzp PlayerHealth
.globalzp PlayerInvincible
.globalzp PlayerWalkLock
.globalzp PlayerDownTimer
.globalzp PlayerJumping
.globalzp OamPtr
.globalzp TempVal
.globalzp TempX
.globalzp TempY
.globalzp TouchTemp
.globalzp DecodePointer
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
.global PlayerRidingSomething
.global PlayerDrawX
.global PlayerDrawY
.global PlayerOAMIndex

.global ColumnUpdateAddress
.global ColumnUpdateBuffer
.global RowUpdateAddress
.global RowUpdateBuffer

BLOCK_UPDATE_COUNT = 4
.global BlockUpdateAddress
.global BlockUpdateDataTL
.global BlockUpdateDataTR
.global BlockUpdateDataBL
.global BlockUpdateDataBR

MaxDelayedBlockEdits = 15
.global DelayedBlockEditType
.global DelayedBlockEditTime
.global DelayedBlockEditAddr


.globalzp LevelColumnSize
.global GetLevelPtrXY_Ptr
.global LevelBuf
.global LevelBufAlt
.global ColumnBytes
.global ParallaxTilemap
.global LevelActorList
.global FirstActorOnScreen



.global OAM
.global OAMHI
OAM_XPOS = OAM+0
OAM_YPOS = OAM+1
OAM_TILE = OAM+2
OAM_ATTR = OAM+3

ActorLen = 20
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
SpriteXYOffset = GraphicUploadOffset

.globalzp LevelNumber
.globalzp StartedLevelNumber
.global NeedLevelReload
.global NeedLevelRerender
.global RerenderInitEntities

; ScreenFlags stores flags for each screen in the level; so far there's just one flag:
SCREEN_BOUNDARY = 1 ; boundary on left side of screen

.global LevelZeroWhenLoad_Start
.global LevelZeroWhenLoad_End

.global ScreenFlags
.global ScreenFlagsDummy
.global LevelBackgroundColor
.globalzp LevelActorPointer
.global VerticalLevelFlag
.global VerticalScrollEnabled

.globalzp random1
.globalzp random2

.global IRQHandler ; For changing what IRQ does for different effects
.global HDMA_Buffer1
.global HDMA_Buffer2
.global Scratchpad
.global RenderBuffer

.global UseTapRun, TapReleaseTimer, TapReleaseButton, IsTapRun
.global TailAttackTimer, TailAttackDirection, TailAttackFrame
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

.global CheckpointState, CheckpointX, CheckpointY, LevelHeaderPointer

.global CursorX
.global CursorY
.global AutoRepeatTimer

VWFStackLen   = 4
.global VWFStackL
.global VWFStackH
.global VWFStackB
.global VWFStackIndex

.global OverworldPlayerX
.global OverworldPlayerY
.global OverworldMap
.global OverworldDirection
