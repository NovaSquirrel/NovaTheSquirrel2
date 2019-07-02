; Probably use LevelColumnSize instead of these
LEVEL_WIDTH = 256
LEVEL_HEIGHT = 32
LEVEL_TILE_SIZE = 2

ForegroundBG = $C000
BackgroundBG = $D000
ExtraBG = $E000

; ------------------------------------

; Include handy macros
.include "ns_snes.s"
.include "memory.inc"

; main.s
.global main, nmi_handler, irq_handler

; uploadppu.s
.global ppu_copy_oam, ppu_pack_oamhi, ppu_clear_oam
.global ppu_copy, ppu_clear_nt, ppu_vsync, WaitVblank
.global DoGraphicUpload, DoPaletteUpload

; blarggapu.s
.global spc_boot_apu

; Common
.global GetLevelColumnPtr, GetLevelPtrXY, GetBlockFlag
.global RenderLevelScreens
.global RenderLevelColumnUpload
.global RenderLevelColumnLeft
.global RenderLevelColumnRight
.global RenderLevelRowUpload
.global RenderLevelRowTop
.global RenderLevelRowBottom
.global PlayerFrameUpload

.global RunPlayer, DrawPlayer, AdjustCamera
.global BlockFlags

.global ChangeBlock, DelayChangeBlock
.global GetBlockX, GetBlockY

.global StartLevel, DecompressLevel

; Flags
.enum ActorFlag
  AutoRemove    = 1
  GetShot       = 2
  AutoReset     = 4
  WaitUntilNear = 8
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
.endenum

.global FindFreeActorX, FindFreeActorY, FindFreeParticleY
