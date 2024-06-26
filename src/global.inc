; Probably use LevelColumnSize instead of these
LEVEL_WIDTH = 256
LEVEL_HEIGHT = 32
MAX_LEVEL_HEIGHT = 256
LEVEL_TILE_SIZE = 2

ForegroundBG = $5800
BackgroundBG = $5000
ExtraBG      = $4c00 ; Used for layer 3
ExtraBGWide  = $4800 ; Used for map when ForegroundLayerThree is on (or for a bigger layer 3 background)
SpriteCHRBase = $6000
BG1CHRBase = $0000
BG2CHRBase = $2000
BG3CHRBase = $3000

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
.global prepare_ppu_copy_oam_partial, ppu_copy_oam_partial, ppu_pack_oamhi_partial
.global ppu_copy, ppu_clear_nt, ppu_vsync, WaitVblank
.global DoGraphicUpload, DoPaletteUpload
.global DoGraphicUploadWithOffset
.global QueueGenericUpdate, QueueGenericUpdateSameBank
.global WritePPUIncreasing, WritePPURepeated, SkipPPUWords

; audio_misc.s
.global PlaySoundEffect, UpdateAudio

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
.global Unsigned16x16Multiply, Unsigned16x16Multiply_16

.global RunPlayer, DrawPlayer, DrawPlayerStatus, AdjustCamera
.global BlockFlags
BLOCK_FLAGS_CLASS = %111111

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
