; Synchronize with the list on mode7actors.s
.enum Mode7ActorType
  None       = 0*2
  ArrowUp    = 1*2
  ArrowLeft  = 2*2
  ArrowDown  = 3*2
  ArrowRight = 4*2
  PinkBall   = 5*2
  PushBlock  = 6*2
  SlidingBlock = 7*2
  Burger       = 8*2
.endenum

.global Mode7ScrollX, Mode7ScrollY, Mode7PlayerX, Mode7PlayerY, Mode7RealAngle, Mode7Direction, Mode7MoveDirection, Mode7Turning, Mode7TurnWanted
.global Mode7SidestepWanted, Mode7ChipsLeft, Mode7HappyTimer, Mode7Oops, Mode7IceDirection, Mode7ForceMove

Mode7LevelMap                = LevelBuf + (64*64*0) ;\
Mode7LevelMapBelow           = LevelBuf + (64*64*1) ; \ 16KB, 4KB each
Mode7LevelMapCheckpoint      = LevelBuf + (64*64*2) ; /
Mode7LevelMapBelowCheckpoint = LevelBuf + (64*64*3) ;/
Mode7DynamicTileBuffer       = LevelBufAlt          ; 8 tiles long, 64*4*8 = 2048
Mode7DynamicTileUsed         = ColumnUpdateAddress  ; Reuse this, 8 bytes long and extends into RowUpdateAddress2

Mode7Keys                    = ActorAdvertisePointer ; 4 bytes
Mode7Tools                   = Mode7Keys+4           ; 2 bytes? Could be 1
Mode7BumpDirection           = ActorAdvertiseCountNext

TOOL_FIREBOOTS    = 1
TOOL_FLIPPERS     = 2
TOOL_SUCTIONBOOTS = 4
TOOL_ICESKATES    = 8

; Reusing this may be a little risky but it should be big enough
Mode7CheckpointX     = CheckpointState + 0
Mode7CheckpointY     = CheckpointState + 2
Mode7CheckpointDir   = CheckpointState + 4
Mode7CheckpointChips = CheckpointState + 6
Mode7CheckpointKeys  = CheckpointState + 8 ; Four bytes
Mode7CheckpointTools = CheckpointState + 10

.import M7BlockTopLeft, M7BlockTopRight, M7BlockBottomLeft, M7BlockBottomRight, M7BlockFlags
M7_BLOCK_SOLID          = 1
M7_BLOCK_SOLID_AIR      = 2
M7_BLOCK_SOLID_BLOCK    = 4
M7_BLOCK_SOLID_CREATURE = 8
M7_BLOCK_SHOW_BARRIER   = 16

DIRECTION_UP    = 0
DIRECTION_LEFT  = 1
DIRECTION_DOWN  = 2
DIRECTION_RIGHT = 3

BlockUpdateAddress = BlockUpdateAddressTop
