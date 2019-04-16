.include "snes.inc"
.include "global.inc"
.smart
.export main, nmi_handler
.include "graphicsenum.s"

USE_PSEUDOHIRES = 0
USE_INTERLACE = 0
USE_AUDIO = 1

.segment "ZEROPAGE"
nmis: .res 1
oam_used: .res 2

.segment "BSS"

OAM:   .res 512
OAMHI: .res 512
; OAMHI contains bit 8 of X (the horizontal position) and the size
; bit for each sprite.  It's a bit wasteful of memory, as the
; 512-byte OAMHI needs to be packed by software into 32 bytes before
; being sent to the PPU, but it makes sprite drawing code much
; simpler.  The OBC1 coprocessor used in the game Metal Combat:
; Falcon's Revenge performs the same packing function in hardware,
; possibly as a copy protection method.

.segment "CODE"
;;
; Minimalist NMI handler that only acknowledges NMI and signals
; to the main thread that NMI has occurred.
.proc nmi_handler
  ; Because the INC and BIT instructions can't use 24-bit (f:)
  ; addresses, set the data bank to one that can access low RAM
  ; ($0000-$1FFF) and the PPU ($2100-$213F) with a 16-bit address.
  ; Only banks $00-$3F and $80-$BF can do this, not $40-$7D or
  ; $C0-$FF.  ($7E can access low RAM but not the PPU.)  But in a
  ; LoROM program no larger than 16 Mbit, the CODE segment is in a
  ; bank that can, so copy the data bank to the program bank.
  phb
  phk
  plb

  seta8
  inc a:nmis       ; Increase NMI count to notify main thread
  bit a:NMISTATUS  ; Acknowledge NMI

  ; And restore the previous data bank value.
  plb
  rti
.endproc

;;
; This program doesn't use IRQs either.
.proc irq_handler
  rti
.endproc

.segment "CODE"
; init.s sends us here
.proc main
  ; In the same way that the CPU of the Commodore 64 computer can
  ; interact with a floppy disk only through the CPU in the 1541 disk
  ; drive, the main CPU of the Super NES can interact with the audio
  ; hardware only through the sound CPU.  When the system turns on,
  ; the sound CPU is running the IPL (initial program load), which is
  ; designed to receive data from the main CPU through communication
  ; ports at $2140-$2143.  Load a program and start it running.
  .if ::USE_AUDIO
;    jsl spc_boot_apu
  .endif

  ; Upload graphics
  seta8
  setxy16
  lda #GraphicsUpload::FGCommon
  jsl DoGraphicUpload
  lda #GraphicsUpload::FGTropicalWood
  jsl DoGraphicUpload
  
  ldx #$c000 >> 1
  ldy #$15
  jsl ppu_clear_nt
  ldx #$d000 >> 1
  ldy #$14
  jsl ppu_clear_nt
  ldx #$e000 >> 1
  ldy #0
  jsl ppu_clear_nt


  ; In LoROM no larger than 16 Mbit, all program banks can reach
  ; the system area (low RAM, PPU ports, and DMA ports).
  ; This isn't true of larger LoROM or of HiROM (without tricks).
  phk
  plb

  ; Upload palette
  seta8
  stz CGADDR
  setaxy16
  lda #DMAMODE_CGDATA
  ldx #palette & $FFFF
  ldy #palette_size
  jsl ppu_copy

  ; Program the PPU for the display mode
  seta8
  lda #1
  sta BGMODE     ; mode 0 (four 2-bit BGs) with 8x8 tiles

  stz BGCHRADDR+0  ; bg planes 0-1 CHR at $0000
  lda #$e>>1
  sta BGCHRADDR+1  ; bg plane 2 CHR at $e000

  ; OBSEL needs the start of the sprite pattern table in $2000-word
  ; units.  In other words, bits 14 and 13 of the address go in bits
  ; 0, 1 and 2 of OBSEL.
  lda #$8000 >> 13
  sta OBSEL      ; sprite CHR at $8000, sprites are 8x8 and 16x16

  lda #1 | ($c000 >> 9)
  sta NTADDR+0   ; plane 0 nametable at $c000, 2 screens wide
  lda #1 | ($d000 >> 9)
  sta NTADDR+1   ; plane 1 nametable also at $d000, 2 screens wide
  lda #0 | ($e000 >> 9)
  sta NTADDR+2   ; plane 2 nametable at $e000, 1 screen

  ; set up plane 0's scroll
  stz BGSCROLLX+0
  stz BGSCROLLX+0
  lda #$FF
  sta BGSCROLLY+0  ; The PPU displays lines 1-224, so set scroll to
  sta BGSCROLLY+0  ; $FF so that the first displayed line is line 0

  stz PPURES
  lda #%00010001  ; enable sprites and plane 0
  sta BLENDMAIN
  lda #VBLANK_NMI|AUTOREAD  ; but disable htime/vtime IRQ
  sta PPUNMI

  ; Set up game variables, as if it were the start of a new level.
;  stz player_facing
;  stz player_dxlo
;  lda #184
;  sta player_yhi



;  stz player_frame_sub
;  lda #48 << 8
;  sta player_xlo

forever:

;  jsl move_player

  ; Draw the player to a display list in main memory
  setaxy16
  stz oam_used
;  jsl draw_player_sprite

  ; Mark remaining sprites as offscreen, then convert sprite size
  ; data from the convenient-to-manipulate format described by
  ; psycopathicteen to the packed format that the PPU actually uses.
  ldx oam_used
  jsl ppu_clear_oam
  jsl ppu_pack_oamhi

  ; Backgrounds and OAM can be modified only during vertical blanking.
  ; Wait for vertical blanking and copy prepared data to OAM.
  jsl ppu_vsync
  jsl ppu_copy_oam
  seta8
  lda #$0F
  sta PPUBRIGHT  ; turn on rendering

  ; wait for control reading to finish
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait
  stz BGSCROLLX
  stz BGSCROLLX

  jmp forever
.endproc




palette:
  .word RGB(15,23,31)
  .word RGB8(34, 32, 52)
  .word RGB8(89, 86, 82)
  .word RGB8(132, 126, 135)
  .word RGB8(155, 173, 183)
  .word RGB8(203, 219, 252)
  .word RGB8(255, 255, 255)
  .word RGB8(102, 57, 49)
  .word RGB8(143, 86, 59)
  .word RGB8(217, 160, 102)
  .word RGB8(238, 195, 154)
  .word RGB8(91, 110, 225)
  .word RGB8(99, 155, 255)
  .word RGB8(172, 50, 50)
  .word RGB8(217, 87, 99)
  .word RGB8(255, 0, 255)
palette_size = * - palette
