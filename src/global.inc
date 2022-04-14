; Probably use LevelColumnSize instead of these
LEVEL_WIDTH = 256
LEVEL_HEIGHT = 32
MAX_LEVEL_HEIGHT = 256
LEVEL_TILE_SIZE = 2

ForegroundBG = $B000
BackgroundBG = $A000
ExtraBG      = $9800 ; Used for layer 3
ExtraBGWide  = $9000 ; Used for map when ForegroundLayerThree is on (or for a bigger layer 3 background)
SpriteCHRBase = $C000
BG1CHRBase = $0000
BG2CHRBase = $4000
BG3CHRBase = $4000

PlayerHeight = 16*16+14*16
PlayerCollideWidth = 8*16

; ------------------------------------

; Include handy macros
.include "ns_snes.s"
.include "memory.inc"

; main.s
.global main, nmi_handler, irq_handler

; uploadppu.s
.global ppu_copy_oam, ppu_pack_oamhi, ppu_clear_oam
.global ppu_copy_oam_partial, ppu_pack_oamhi_partial
.global ppu_copy, ppu_clear_nt, ppu_vsync, WaitVblank
.global DoGraphicUpload, DoPaletteUpload
.global DoGraphicUploadWithOffset
.global QueueGenericUpdate, QueueGenericUpdateSameBank
.global WritePPUIncreasing, WritePPURepeated, SkipPPUWords

; blarggapu.s
.global spc_boot_apu

; Common
.global GetLevelColumnPtr, GetLevelPtrXY, GetBlockFlag
.global RenderLevelScreens
.global RenderLevelColumnUpload, RenderLevelColumnLeft, RenderLevelColumnRight
.global RenderLevelRowUpload, RenderLevelRowTop, RenderLevelRowBottom
.global RenderLevelColumnUpload2, RenderLevelColumnLeft2, RenderLevelColumnRight2
.global RenderLevelRowUpload2, RenderLevelRowTop2, RenderLevelRowBottom2
.global PlayerFrameUpload
.global FadeIn, FadeOut, WaitKeysReady
.global MemClear, MemClear7F

.global RunPlayer, DrawPlayer, DrawPlayerStatus, AdjustCamera
.global BlockFlags

.global ChangeBlock, DelayChangeBlock
.global GetBlockX, GetBlockY, GetBlockXCoord, GetBlockYCoord

; Flags
.enum ActorFlag
  Priority      = %1100000000000000 ; Priority bits
  Essential     = %1000000000000000 
  Primary       = %0100000000000000
  Secondary     = %0000000000000000
.endenum

.enum ActorStateValue
  None    = 0
  Paused  = 128|1
  Stunned = 128|2
  Active  = 128|3
  Init    = 128|4 ; State is set to Init for one frame to allow actors to detect they were just created
  Override= 128|5 ; Call a different routine (selected by ActorTimer) instead of the usual Run routine
  Carried = 128|6 ; Actors is being carried by the player
.endenum

.enum ActorOverrideValue
  None   = 0
  Hooked = 2 ; Caught by a hook
  Flying = 4 ; Fly until it hits something
.endenum

.global FindFreeActorX, FindFreeActorY, FindFreeParticleY

.global RandomByte, VelocityLeftOrRight

AttackKeys = KEY_X|KEY_L|KEY_R
DirectionKeys = KEY_LEFT|KEY_DOWN|KEY_UP|KEY_RIGHT

.macro NameFontText String
  .repeat .strlen(String), I
    .scope
      Char = .strat(String, I)
      .if Char = ' ' || Char = '_'
        .byt 1
      .endif
      .if Char >= 'A' && Char <= 'Z'
        .byt 2 + Char-'A'
      .endif
      .if Char >= 'a' && Char <= 'z'
        .byt 2 + Char-'a'+26
      .endif
    .endscope
  .endrep
  .byt 0
.endmacro

; For PlayerActorCollisionMultiRect
.macro CollisionMultiRect left, width, top, height
  ; Format:
  ;   .word x_offset, width/2, y_offset_bottom, y_offset_top
  ;   (Repeat for however many rectangles)
  ;   .word $8000
  .word .loword(left*16+(width*8)), .loword(width*8)
  ; Now the bottom and the top
  .word .loword((top+height-1)*16), .loword((top)*16)
.endmacro

.macro CollisionMultiRectEnd
  .word $8000
.endmacro

.enum GSS_SubCommands
	INITIALIZE
	STEREO
	MUSIC_START
	MUSIC_STOP
	MUSIC_PAUSE
	STOP_ALL_SOUNDS
	FAST_LOAD
	LOAD
	ECHO_VOLUME_CHANNELS
	ECHO_ADDRESS_DELAY
	ECHO_FIR_FEEDBACK
	; unused slot
	; unused slot
	; unused slot
	; unused slot
	; unused slot
.endenum

.enum GSS_Commands
	NO_OP
	SUBCOMMAND

	GLOBAL_VOLUME
	; APU2 = Volume
	; APU3 = Change speed

	CHANNEL_VOLUME
	; APU2 = Volume
	; APU3 = Channel mask

	SFX_PLAY
	; APU1 = Volume 
	; APU2 = Effect number
	; APU3 = Pan

	STREAM_START
	STREAM_STOP
	STREAM_SEND

	INITIALIZE      = SUBCOMMAND + (GSS_SubCommands::INITIALIZE << 4)
	; No parameters

	STEREO          = SUBCOMMAND + (GSS_SubCommands::STEREO << 4)
	; APU2 = Stereo, if nonzero

	MUSIC_START     = SUBCOMMAND + (GSS_SubCommands::MUSIC_START << 4)
	; No parameters

	MUSIC_STOP      = SUBCOMMAND + (GSS_SubCommands::MUSIC_STOP << 4)
	; No parameters

	MUSIC_PAUSE     = SUBCOMMAND + (GSS_SubCommands::MUSIC_PAUSE << 4)
	; APU2 = Pause if nonzero

	STOP_ALL_SOUNDS = SUBCOMMAND + (GSS_SubCommands::STOP_ALL_SOUNDS << 4)
	; No parameters

	FAST_LOAD       = SUBCOMMAND + (GSS_SubCommands::FAST_LOAD << 4)
	; No parameters

	LOAD            = SUBCOMMAND + (GSS_SubCommands::LOAD << 4)
	; No parameters

	ECHO_VOLUME_CHANNELS = SUBCOMMAND + (GSS_SubCommands::ECHO_VOLUME_CHANNELS << 4)
	; APU2 = Volume
	; APU3 = Channel mask

	ECHO_ADDRESS_DELAY   = SUBCOMMAND + (GSS_SubCommands::ECHO_ADDRESS_DELAY << 4)
	; APU2 = High byte of the start of the echo buffer 
	; APU3 = Echo delay (and buffer size) in 2KB chunks. or 0 is 4 bytes

	ECHO_FIR_FEEDBACK    = SUBCOMMAND + (GSS_SubCommands::ECHO_FIR_FEEDBACK << 4)
	; APU2 = FIR set
	; APU3 = Feedback volume (the volume at which the echo-output is mixed back to the echo-input).
	;    Volume (-128..+127) (negative = phase inverted) (sample=sample*vol/128)
	;    Medium values (like 40h) produce "normal" echos (with decreasing volume on each repetition). Value 00h would produce a one-shot echo, value 7Fh would repeat the echo almost infinitely (assuming that FIRx leaves the overall volume unchanged).
.endenum
