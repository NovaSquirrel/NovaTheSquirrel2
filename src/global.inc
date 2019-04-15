; Include handy macros
.include "ns_snes.s"

; main.s
.global main, nmi_handler, irq_handler
.globalzp oam_used

; uploadppu.s
.global ppu_copy_oam, ppu_pack_oamhi, ppu_clear_oam
.global ppu_copy, ppu_clear_nt, ppu_vsync
.global DoGraphicUpload

.global OAM, OAMHI

; blarggapu.s
.global spc_boot_apu

; --------------------------------------
