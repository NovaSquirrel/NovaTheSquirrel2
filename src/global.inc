; Include handy macros
.include "ns_snes.s"

; main.s
.global main, nmi_handler, irq_handler
.globalzp oam_used

; ppuclear.s
.global ppu_copy_oam, ppu_pack_oamhi, ppu_clear_oam
.global ppu_copy, ppu_clear_nt, ppu_vsync
.global OAM, OAMHI

; bg.s
.global load_bg_tiles, draw_bg

; player.s
.global load_player_tiles, move_player, draw_player_sprite
.globalzp player_xlo, player_xhi, player_dxlo, player_yhi
.globalzp player_frame_sub, player_frame, player_facing

; blarggapu.s
.global spc_boot_apu



; --------------------------------------


