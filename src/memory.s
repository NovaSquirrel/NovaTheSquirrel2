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

; Format for 16-bit X and Y positions and speeds:
; HHHHHHHH LLLLSSSS
; |||||||| ||||++++ - subpixels
; ++++++++ ++++------ actual pixels

.include "memory.inc"

.segment "ZEROPAGE"
  retraces: .res 2
  framecount: .res 2  ; Only increases every iteration of the main loop

  keydown:  .res 2
  keylast:  .res 2
  keynew:   .res 2

  ScrollX:  .res 2
  ScrollY:  .res 2

  random1:  .res 2
  random2:  .res 2

  LevelBlockPtr: .res 3 ; Pointer to one block or a column of blocks. 00xxxxxxxxyyyyy0
  BlockFlag:     .res 2 ; Contains block class, solid flags, and interaction set
  BlockRealX:    .res 2 ; Real X coordinate used to calculate LevelBlockPtr (Unused)
  BlockRealY:    .res 2 ; Real Y coordinate used to calculate LevelBlockPtr (Unused)
  BlockTemp:     .res 4 ; Temporary bytes for block interaction routines specifically

  PlayerPX:        .res 2 ; \ player X and Y positions
  PlayerPY:        .res 2 ; /
  PlayerVX:        .res 2 ; \
  PlayerVY:        .res 2 ; /
  PlayerFrame:     .res 1 ; Player animation frame
  PlayerFrameXFlip: .res 1
  PlayerFrameYFlip: .res 1

  ForceControllerBits: .res 2
  ForceControllerTime: .res 1

  PlayerAbility:    .res 1     ; ability the player currently has

  PlayerWasRunning: .res 1     ; was the player running when they jumped?
  PlayerDir:        .res 1     ; currently facing left?
  PlayerJumping:    .res 1     ; true if jumping (not falling)
  PlayerOnGround:   .res 1     ; true if on ground
  PlayerOnGroundLast: .res 1   ; true if on ground last frame
  PlayerWalkLock:   .res 1     ; timer for the player being unable to move left/right
  PlayerDownTimer:  .res 1     ; timer for how long the player has been holding down
                               ; (used for fallthrough platforms)
  PlayerSelectTimer:  .res 1   ; timer for how long the player has been holding select
  PlayerHealth:     .res 1     ; current health, measured in half hearts

  LevelNumber:           .res 2 ; Current level number (actual map number from the game)
  StartedLevelNumber:    .res 2 ; Level number that was picked from the level select (level select number)
  NeedLevelReload:       .res 1 ; If set, decode LevelNumber again

  SpriteTileBase:   .res 2 ; Detected tile base for the current entity (includes palette index)

  OamPtr:           .res 2 ;
  TempVal:          .res 4
  TempX:            .res 1 ; for saving the X register
  TempY:            .res 1 ; for saving the Y register

  LevelColumnSize:  .res 2 ; for moving left and right in a level buffer
  DecodePointer:    .res 3 ; multipurpose 24-bit pointer
  LevelActorPointer: .res 3 ; actor pointer for this level

.segment "BSS" ; First 8KB of RAM
  ActorSize = 10*2+3
  ActorStart: .res ActorLen*ActorSize
  ActorEnd:

  ActorType         = 0 ; Actor type ID
  ActorPX           = 2 ; Positions
  ActorPY           = 4 ;
  ActorVX           = 6 ; Speeds
  ActorVY           = 8 ;
  ActorVarA         = 10 ; 
  ActorVarB         = 12 ; 
  ActorVarC         = 14 ; 
  ActorIndexInLevel = 16 ; Actor's index in level list, prevents Actor from being respawned until it's despawned
  ActorTimer        = 18 ; when timer reaches 0, reset state
  ActorDirection    = 20 ; 0 (Right) or 1 (Left). Other bits may be used later. Good place for parameters from level?
  ActorState        = 21 ; Nonzero usually means stunned
  ActorOnGround     = 22 ; Nonzero means on ground

  ; For less important, light entities
  ParticleSize = 7*2
  ParticleStart: .res ParticleLen*ParticleSize
  ParticleEnd:

  ParticleType       = 0
  ParticlePX         = 2
  ParticlePY         = 4
  ParticleVX         = 6
  ParticleVY         = 8
  ParticleTimer      = 10
  ParticleVariable   = 12

  ; For automatically detecting which tile slot or palette has the right data
  SpriteTileSlots:     .res 2*8
  SpritePaletteSlots:  .res 2*4

  IRQHandler: .res 3

  OAM:   .res 512
  OAMHI: .res 512
  ; OAMHI contains bit 8 of X (the horizontal position) and the size
  ; bit for each sprite.  It's a bit wasteful of memory, as the
  ; 512-byte OAMHI needs to be packed by software into 32 bytes before
  ; being sent to the PPU, but it makes sprite drawing code much
  ; simpler.

  ; Video updates from scrolling
  ColumnUpdateAddress: .res 2     ; Address to upload to, or zero for none
  ColumnUpdateBuffer:  .res 32*2  ; 32 tiles vertically
  RowUpdateAddress:    .res 2     ; Address to upload to, or zero for none
  RowUpdateBuffer:     .res 64*2  ; 64 tiles horizontally

  BlockUpdateAddress:  .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataTL:   .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataTR:   .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataBL:   .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataBR:   .res BLOCK_UPDATE_COUNT*2

  DelayedBlockEditType: .res MaxDelayedBlockEdits*2 ; Block type to put in
  DelayedBlockEditAddr: .res MaxDelayedBlockEdits*2 ; Address to put the block at
; DelayedBlockEditTime: ; Declared elsewhere. Time left until the change

  GetLevelPtrXY_Ptr: .res 2 ; Pointer for how to handle getting a pointer from an X and Y position

  PlayerAccelSpeed: .res 2
  PlayerDecelSpeed: .res 2
  JumpGracePeriod: .res 1
  PlayerJumpCancelLock: .res 1 ; timer for the player being unable to cancel a jump
  PlayerJumpCancel: .res 1
  PlayerWantsToJump: .res 1    ; true if player pressed the jump button

  LevelBackgroundColor:   .res 2


; All of these are cleared in one go at the start of level decompression
LevelZeroWhenLoad_Start:
  ScreenFlags:            .res 16
  ScreenFlagsDummy:       .res 1
  VerticalLevelFlag:      .res 1

  ; How many Actors use each of the four palette slots, for detecting when one is free
  PaletteInUse:        .res 4
  PaletteInUseLast:    .res 4
  ; Dynamically uploading sprite palettes
  PaletteRequestIndex: .res 1
  PaletteRequestValue: .res 1
  PlayerOnLadder:      .res 1

  PlayerOnSlope:       .res 1 ; Nonzero if the player is on a slope
  PlayerSlopeType:     .res 2 ; Type of slope the player is on, if they are on one
  PlayerRolling:       .res 1 ; Nonzero if the player is rolling down a slope

  DelayedBlockEditTime: .res MaxDelayedBlockEdits*2 ; Time left until the edit
LevelZeroWhenLoad_End:
  NeedAbilityChange:       .res 1
  NeedAbilityChangeSilent: .res 1

  ; For speeding up actor spawning
  ; (keeps track of which actor index is the first one on a particular screen)
  ; Multiply by 4 to use it.
  FirstActorOnScreen:     .res 16

.segment "BSS7E"


.segment "BSS7F"
  LevelBuf:    .res 256*32*2 ; 16KB, primary buffer
  LevelBufAlt: .res 256*32*2 ; 16KB, for layer 2 levels or other purposes
  ColumnBytes: .res 256

  ParallaxTilemap: .res 8192 ; four screens to DMA into layer 2
  HDMA_Buffer1: .res 2048    ; for building HDMA tables in
  HDMA_Buffer2: .res 2048    ; for double buffering the previous
