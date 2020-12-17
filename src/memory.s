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

  ScrollX:  .res 2   ; Primary foreground
  ScrollY:  .res 2
  FG2OffsetX: .res 2 ; Secondary foreground
  FG2OffsetY: .res 2

  random1:  .res 2
  random2:  .res 2

  HDMASTART_Mirror: .res 1 ; Maintained everywhere HDMA is used
  CGWSEL_Mirror: .res 1    ; Currently only maintained during gameplay
  CGADSUB_Mirror: .res 1   ; Currently only maintained during gameplay

  LevelBlockPtr: .res 3 ; Pointer to one block or a column of blocks. 00xxxxxxxxyyyyy0
  BlockFlag:     .res 2 ; Contains block class, solid flags, and interaction set
  BlockRealX:    .res 2 ; Real X coordinate used to calculate LevelBlockPtr (Unused)
  BlockRealY:    .res 2 ; Real Y coordinate used to calculate LevelBlockPtr (Unused)
  BlockTemp:     .res 4 ; Temporary bytes for block interaction routines specifically

  PlayerPX:        .res 2 ; \ player X and Y positions
  PlayerPY:        .res 2 ; /
  PlayerPYTop:     .res 2 ; Y position for the top of the player
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
  PlayerOnGroundLast: .res 1   ; true if on ground last frame - used to display the landing particle
  PlayerWalkLock:   .res 1     ; timer for the player being unable to move left/right
  PlayerDownTimer:  .res 1     ; timer for how long the player has been holding down
                               ; (used for fallthrough platforms)
  PlayerSelectTimer:  .res 1   ; timer for how long the player has been holding select
  PlayerHealth:     .res 1     ; current health, measured in half hearts

  StartedLevelNumber:    .res 2 ; Level number that was picked from the level select (level select number)

  SpriteTileBase:   .res 2 ; Detected tile base for the current entity (includes palette index)

  OamPtr:           .res 2 ;
  TempVal:          .res 4
  TempX:            .res 1 ; for saving the X register
  TempY:            .res 1 ; for saving the Y register
  TouchTemp:        .res 8

  LevelColumnSize:  .res 2 ; for moving left and right in a level buffer
  DecodePointer:    .res 3 ; multipurpose 24-bit pointer
  ScriptPointer:    .res 3 ; multipurpose 24-bit pointer
  LevelActorPointer: .res 3 ; actor pointer for this level

.segment "BSS" ; First 8KB of RAM
  ActorSize = 10*2+6
  ActorStart: .res ActorLen*ActorSize
  ActorEnd:
  ; Must be contiguous
  ProjectileStart: .res ProjectileLen*ActorSize
  ProjectileEnd:

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
  ActorOnScreen     = 23 ; Nonzero means on screen
  ActorDamage       = 24 ; Amount of damage the actor has
  ActorDynamicSlot  = 25 ; Dynamic sprite slot (0-7) or 255 if none
  ActorProjectileType = ActorIndexInLevel ; Safe to reuse, since this is only checked on normal actor slots

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
  ; For reuploading palette information
  BackgroundPaletteSlots: .res 8
  GraphicalAssets:     .res 30

  GraphicUploadOffset: .res 2

  NeedLevelReload:       .res 1 ; If set, decode LevelNumber again
  NeedLevelRerender:     .res 1 ; If set, rerender the level again
  RerenderInitEntities:  .res 1 ; If set, init entity lists for next rerender;
                                ; if $80 (RERENDER_INIT_ENTITIES_TELEPORT), preserve certain entity types
  NMIHandler: .res 3
  IRQHandler: .res 3

  OAM:   .res 512
  OAMHI: .res 512
  ; OAMHI contains bit 8 of X (the horizontal position) and the size
  ; bit for each sprite.  It's a bit wasteful of memory, as the
  ; 512-byte OAMHI needs to be packed by software into 32 bytes before
  ; being sent to the PPU, but it makes sprite drawing code much
  ; simpler.

  GetLevelPtrXY_Ptr: .res 2 ; Pointer for how to handle getting a pointer from an X and Y position
  GetBlockX_Ptr: .res 2     ; Pointer for how to get the X position (in blocks) from a level pointer
  GetBlockY_Ptr: .res 2     ; Pointer for how to get the Y position (in blocks) from a level pointer
  GetBlockXCoord_Ptr: .res 2     ; Pointer for how to get the X position (coordinate) from a level pointer
  GetBlockYCoord_Ptr: .res 2     ; Pointer for how to get the Y position (coordinate) from a level pointer

  PlayerAccelSpeed: .res 2
  PlayerDecelSpeed: .res 2
  JumpGracePeriod: .res 1
  PlayerJumpCancelLock: .res 1 ; timer for the player being unable to cancel a jump
  PlayerJumpCancel: .res 1
  PlayerWantsToJump: .res 1    ; true if player pressed the jump button
  PlayerWantsToAttack: .res 1  ; true if player pressed the attack button
  PlayerRidingSomething: .res 1 ; if 1, player is treated to be standing on a solid and can jump
  PlayerRidingFG2: .res 1
  PlayerDownRecently: .res 1   ; Player pressed down recently (for down+up abilities)

  PlayerDrawX: .res 1
  PlayerDrawY: .res 1
  PlayerOAMIndex: .res 2

  ; Mirrors, for effects
  FGScrollXPixels: .res 2
  FGScrollYPixels: .res 2
  BGScrollXPixels: .res 2
  BGScrollYPixels: .res 2
  FG2ScrollXPixels: .res 2
  FG2ScrollYPixels: .res 2
  ; Storage, for effects
  BGEffectRAM:     .res 8

  LevelBackgroundColor:   .res 2 ; Palette entry
  LevelBackgroundId:      .res 1 ; Backgrounds specified in backgrounds.txt

  OldFG2OffsetX: .res 2 ; Secondary foreground
  OldFG2OffsetY: .res 2
  OldScrollX: .res 2
  OldScrollY: .res 2
  SecondFGTilemapPointer: .res 2 ; Usually BackgroundBG>>1 but can be ExtraBG>>1

; All of these are cleared in one go at the start of level decompression
LevelZeroWhenLoad_Start:
  ScreenFlags:            .res 16
  ScreenFlagsDummy:       .res 1
  VerticalLevelFlag:      .res 1 ; Level is vertical instead of horizontal
  VerticalScrollEnabled:  .res 1 ; Enable vertical scrolling
  GlassForegroundEffect:  .res 1
  TwoLayerLevel:          .res 1 ; Two foreground layer level
  TwoLayerInteraction:    .res 1 ; Interaction with the second layer is enabled
  ForegroundLayerThree:   .res 1 ; The second foreground layer is on layer 3, not layer 2
  LevelFadeIn:            .res 1 ; Timer for fading the level in
  LevelIrisIn:            .res 1 ; Timer for doing the "iris in" effect
  RunGameLogic:           .res 1 ; If nonzero, run all of the game logic
  FG2MovementRoutine:     .res 3 ; Pointer for a routine to call every frame
  ToggleSwitch1:          .res 1
  ToggleSwitch2:          .res 1
  ToggleSwitch3:          .res 1

  ; How many Actors use each of the four palette slots, for detecting when one is free
  PaletteInUse:        .res 4
  PaletteInUseLast:    .res 4
  ; The same, for the eight tileset slots
  SpriteTilesInUse:     .res 8
  SpriteTilesInUseLast: .res 8
  SpriteTilesUseTime:   .res 8*2 ; Timestamp - a copy of framecount

  ; Dynamically uploading sprite palettes
  PaletteRequestIndex: .res 1 ; 8-15, 0 if unused
  PaletteRequestValue: .res 1

  ; And sprite tiles
  SpriteTilesRequestDestination: .res 2 ; VRAM address
  SpriteTilesRequestSource:      .res 3 ; Source address, zero if unused
  ; Size is always 1KB

  PlayerOnLadder:      .res 1
  PlayerInWater:       .res 1

  PlayerOnSlope:       .res 1 ; Nonzero if the player is on a slope
  PlayerSlopeType:     .res 2 ; Type of slope the player is on, if they are on one
  PlayerRolling:       .res 1 ; Nonzero if the player is rolling down a slope

  ; Video updates from scrolling
  ColumnUpdateAddress: .res 2     ; Address to upload to, or zero for none
  ColumnUpdateBuffer:  .res 32*2  ; 32 tiles vertically
  RowUpdateAddress:    .res 2     ; Address to upload to, or zero for none
  RowUpdateBuffer:     .res 64*2  ; 64 tiles horizontally

  ; Second layer
  ColumnUpdateAddress2: .res 2     ; Address to upload to, or zero for none
  ColumnUpdateBuffer2:  .res 32*2  ; 32 tiles vertically
  RowUpdateAddress2:    .res 2     ; Address to upload to, or zero for none
  RowUpdateBuffer2:     .res 64*2  ; 64 tiles horizontally

  ; For ChangeBlock
  BlockUpdateAddress:  .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataTL:   .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataTR:   .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataBL:   .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataBR:   .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataEnd:

  ; VRAM/CGRAM updates, for tiles and palette updates
  GenericUpdateDestination: .res GENERIC_UPDATE_COUNT*2
  GenericUpdateLength:      .res GENERIC_UPDATE_COUNT*2
  GenericUpdateSource:      .res GENERIC_UPDATE_COUNT*2
  GenericUpdateDestination2: .res GENERIC_UPDATE_COUNT*2 ;\--- Used for two-row DMAs
  GenericUpdateSource2:      .res GENERIC_UPDATE_COUNT*2 ;/
  GenericUpdateFlags:       .res GENERIC_UPDATE_COUNT*2 ; First byte is bank
  ; Second byte of GenericUpdateFlags has some other metadata:
  ; For VRAM updates, if bit 7 is set, there is a second DMA to Destination2 from Source2

  DynamicSpriteSlotUsed: .res DYNAMIC_SPRITE_SLOTS
  ; Every slot is nonzero if used, zero if not

  ; Delayed ChangeBlock updates
  DelayedBlockEditType: .res MaxDelayedBlockEdits*2 ; Block type to put in
  DelayedBlockEditAddr: .res MaxDelayedBlockEdits*2 ; Address to put the block at
  DelayedBlockEditTime: .res MaxDelayedBlockEdits*2 ; Time left until the change

  PlayerInvincible: .res 1     ; timer for player invincibility
  PlayerNeedsGround: .res 1     ; resets to zero when touching the ground
  PlayerNeedsGroundAtAttack: .res 1 ; State at the start of the attack
  NeedAbilityChange:       .res 1
  NeedAbilityChangeSilent: .res 1

  TailAttackTimer:     .res 1 ; How far we are into the animation
  TailAttackDirection: .res 1 ; What directional keys were pressed
  TailAttackFrame:     .res 1 ; Current frame to use for the player during the attack
  TailAttackCooldown:  .res 1 ; Frames before the attack button can be used again
  AbilityMovementLock: .res 1
LevelZeroWhenLoad_End:
  TailAttackVariable:  .res 2 ; Zero'd when an attack starts

  ; For speeding up actor spawning
  ; (keeps track of which actor index is the first one on a particular screen)
  ; Multiply by 4 to use it.
  FirstActorOnScreen:     .res 16


  ; Tap-run state
  UseTapRun: .res 1
  TapReleaseTimer: .res 1 ; Starts a countdown once left/right are released
  TapReleaseButton: .res 1 ; Indicates if left or right was released
  IsTapRun: .res 1 ; Current run is from a tap

  VWFStackL:     .res VWFStackLen
  VWFStackH:     .res VWFStackLen
  VWFStackB:     .res VWFStackLen
  VWFStackIndex: .res 1
  DialogStackL:     .res DialogStackLen
  DialogStackH:     .res DialogStackLen
  DialogStackB:     .res DialogStackLen
  DialogStackIndex: .res 1

  ; Reusable for other things
  DialogCharacterId:   .res DialogCharacterLen
  DialogCharacterX:    .res DialogCharacterLen
  DialogCharacterY:    .res DialogCharacterLen
  DialogCharacterFlip: .res DialogCharacterLen

  CursorX:       .res 2
  CursorY:       .res 2
  AutoRepeatTimer: .res 1

  OverworldPlayerX:   .res 1
  OverworldPlayerY:   .res 1
  OverworldMap:       .res 1
  OverworldDirection: .res 1

  SmallRenderBuffer: .res 64

GameStateStart:
  YourInventory:    .res InventoryLen*2 ; Type, Amount pairs
  LevelInventory:   .res InventoryLen*2
  InventoryEnd:
GameStateEnd:
SaveDataStart:
  SavedGameState:   .res GameStateEnd-GameStateStart
  MoneyAmount:      .res 3   ; 5 BCD digits
  LevelCleared:     .res 8   ; 64 levels, bit = enabled
  LevelAvailable:   .res 8   ; 64 levels, bit = enabled
  CollectibleBits:  .res 8   ; 64 levels, bit = gotten
  EventFlag:        .res 32  ; 256 event flags
SaveDataEnd:

CheckpointState:    .res GameStateEnd-GameStateStart
CheckpointX:        .res 1
CheckpointY:        .res 1
LevelHeaderPointer: .res 3 ; For starting the same level from a checkpoint, or other purposes

.segment "BSS7E"
  RenderBuffer:
  Scratchpad:  .res 4096
  NameFontRenderTop:    .res 384 ; Enough for 12 tiles
  NameFontRenderBottom: .res 384 ; Enough for 12 tiles

  LevelActorBuffer: .res 1024 ; Room for 256 actors if the list must be in RAM, not used by default
  IrisEffectBuffer1: .res 224*3+5 ; HDMA table
  IrisEffectBuffer2: .res 224*3+5 ; HDMA table

.segment "BSS7F"
  LevelBuf:    .res 256*32*2 ; 16KB, primary buffer
  LevelBufAlt: .res 256*32*2 ; 16KB, for layer 2 levels or other purposes
  ColumnWords: .res 512      ; Two byte per column of the level

;  ParallaxTilemap: .res 8192 ; four screens to DMA into layer 2
  HDMA_Buffer1: .res 2048    ; for building HDMA tables in
  HDMA_Buffer2: .res 2048    ; for double buffering the previous

  DecompressBuffer: .res 8192 ; Not used by LZ4_DecompressToMode7Tiles, though that's also currently unused
