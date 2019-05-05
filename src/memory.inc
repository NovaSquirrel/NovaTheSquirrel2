.globalzp retraces
.globalzp keydown
.globalzp keylast
.globalzp keynew
.globalzp ScrollX
.globalzp ScrollY
.globalzp LevelBlockPtr
.globalzp BlockFlag
.globalzp BlockRealX
.globalzp BlockRealY

.globalzp SpriteTileBase

.globalzp PlayerPX
.globalzp PlayerPY
.globalzp PlayerVX
.globalzp PlayerVY
.globalzp PlayerFrame
.globalzp PlayerDir
.globalzp PlayerWasRunning
.globalzp PlayerOnGround
.globalzp PlayerHealth
.globalzp PlayerWalkLock
.globalzp PlayerDownTimer
.globalzp PlayerJumping
.globalzp OamPtr
.globalzp TempVal
.globalzp TempX
.globalzp TempY

.global PlayerJumpCancel
.global PlayerJumpCancelLock
.global PlayerAccelSpeed
.global PlayerDecelSpeed
.global JumpGracePeriod

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

.global LevelBuf
.global OAM
.global OAMHI

ObjectLen = 20
.global ObjectStart
.globalzp ObjectSize
.global ObjectEnd
.globalzp ObjectType
.globalzp ObjectPX
.globalzp ObjectPY
.globalzp ObjectVX
.globalzp ObjectVY
.globalzp ObjectF2
.globalzp ObjectF3
.globalzp ObjectF4
.globalzp ObjectIndexInLevel
.globalzp ObjectTimer

ParticleLen = 16
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

.globalzp LevelNumber
.globalzp StartedLevelNumber
.globalzp NeedLevelReload
