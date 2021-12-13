; Probably use LevelColumnSize instead of these
LEVEL_WIDTH = 256
LEVEL_HEIGHT = 32
LEVEL_TILE_SIZE = 2

ForegroundBG = $B000
BackgroundBG = $A000
ExtraBG = $9800
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
  AutoRemove    = 1
  AutoReset     = 2
  GetShot       = 4
  WaitUntilNear = 8
  WaitForCameraVertically = 16
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
  Init    = 128|4
  Override= 128|5 ; Call different routine instead of the proper Run routine
.endenum

.enum ActorOverrideValue
  None   = 0
  Hooked = 2 ; Caught by a hook
  Flying = 4 ; Fly until it hits something
.endenum

.global FindFreeActorX, FindFreeActorY, FindFreeParticleY

.global RandomByte, VelocityLeftOrRight

AttackKeys = KEY_X|KEY_A|KEY_L|KEY_R
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
  .word .loword((left+width/2)*16), .loword((width/2)*16)
  ; Now the bottom and the top
  .word .loword((top+height-1)*16), .loword((top)*16)
.endmacro

.macro CollisionMultiRectEnd
  .word $8000
.endmacro
