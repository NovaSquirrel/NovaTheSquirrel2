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
.global ppu_copy, ppu_clear_nt, ppu_vsync
.global DoGraphicUpload

; blarggapu.s
.global spc_boot_apu

; Common
.global GetLevelColumnPtr
.global RenderLevelScreens
.global RenderLevelColumnUpload
.global RenderLevelColumnLeft
.global RenderLevelColumnRight
.global RenderLevelRowUpload
.global RenderLevelRowTop
.global RenderLevelRowBottom
.global PlayerFrameUpload

.global RunPlayer, AdjustCamera
