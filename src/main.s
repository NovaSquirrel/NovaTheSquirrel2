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

.include "snes.inc"
.include "global.inc"
.smart
.export main, nmi_handler
.include "graphicsenum.s"

.segment "ZEROPAGE"
.segment "BSS"

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
  inc a:retraces   ; Increase NMI count to notify main thread
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
;  jsl spc_boot_apu

  seta8
  setxy16
  phk
  plb

  ; Clear the first 8KB of RAM
  ldx #8192-1
: stz 0, x
  dex
  bpl :-

  ; Upload graphics
  lda #GraphicsUpload::FGCommon
  jsl DoGraphicUpload
  lda #GraphicsUpload::FGTropicalWood
  jsl DoGraphicUpload

  ; Clear three screens
  ldx #$c000 >> 1
  ldy #$15
  jsl ppu_clear_nt
  ldx #$d000 >> 1
  ldy #$14
  jsl ppu_clear_nt
  ldx #$e000 >> 1
  ldy #0
  jsl ppu_clear_nt
  setaxy16


  lda #4*256
  sta PlayerPX
  sta PlayerPY

  ; Clear level buffer
  lda #0
  tax
: sta f:LevelBuf,x
  inx
  inx
  cpx #256*32*2
  bne :-

  ; Copy in a placeholder level
  ldx #0
: lda PlaceholderLevel,x
  sta f:LevelBuf,x
  inx
  inx
  cpx #PlaceholderLevelEnd-PlaceholderLevel
  bne :-

  jsl RenderLevelScreens

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

  ; Player palette
  seta8
  lda #$81
  sta CGADDR
  setaxy16
  lda #DMAMODE_CGDATA
  ldx #PlayerPalette & $FFFF
  ldy #15*2
  jsl ppu_copy


  ; Set up PPU registers
  seta8
  lda #1
  sta BGMODE       ; mode 1

  stz BGCHRADDR+0  ; bg planes 0-1 CHR at $0000
  lda #$e>>1
  sta BGCHRADDR+1  ; bg plane 2 CHR at $e000

  lda #$8000 >> 14
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

forever:
  ; Draw the player to a display list in main memory
  setaxy16
  ; Update keys
  lda keydown
  sta keylast
  lda JOY1CUR
  sta keydown
  lda keylast
  eor #$ffff
  and keydown
  sta keynew

  ; Run stuff for this frame
  stz OamPtr
  jsl RunPlayer
  jsl AdjustCamera

  ; Mark remaining sprites as offscreen, then convert sprite size
  ; data from the convenient-to-manipulate format described by
  ; psycopathicteen to the packed format that the PPU actually uses.
  setaxy16
  ldx OamPtr
  jsl ppu_clear_oam
  jsl ppu_pack_oamhi

  ; -------------------

  ; Backgrounds and OAM can be modified only during vertical blanking.
  ; Wait for vertical blanking and copy prepared data to OAM.
  jsl WaitVblank
  jsl ppu_copy_oam

  ; Do row/column updates if required
  lda ColumnUpdateAddress
  beq :+
    jsl RenderLevelColumnUpload
    stz ColumnUpdateAddress
  :
  lda RowUpdateAddress
  beq :+
    jsl RenderLevelRowUpload
    stz RowUpdateAddress
  :
  ; -----------------------------------
  ; Do block updates
  ldx #(BLOCK_UPDATE_COUNT-1)*2
BlockUpdateLoop:
  lda BlockUpdateAddressT,x
  beq SkipBlock
  sta PPUADDR
  lda BlockUpdateDataTL,x
  sta PPUDATA
  lda BlockUpdateDataTR,x
  sta PPUDATA

  lda BlockUpdateAddressB,x
  sta PPUADDR
  lda BlockUpdateDataBL,x
  sta PPUDATA
  lda BlockUpdateDataBR,x
  sta PPUDATA

  stz BlockUpdateAddressT,x ; Cancel out the block now that it's been written
SkipBlock:
  dex
  dex
  bpl BlockUpdateLoop


  ; -----------------------------------
  jsl PlayerFrameUpload

  seta8
  lda #$0F
  sta PPUBRIGHT  ; turn on rendering

  ; wait for control reading to finish
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait

  ; Update scroll registers
  seta16
  lda ScrollX
  lsr
  lsr
  lsr
  lsr
  sta 0

  lda ScrollY
  dec a ; SNES displays lines 1-224 so shift it up to 0-223
  lsr
  lsr
  lsr
  lsr
  sta 2
  seta8

  lda 0
  sta BGSCROLLX
  lda 1
  sta BGSCROLLX
  lda 2
  sta BGSCROLLY
  lda 3
  sta BGSCROLLY

  jmp forever
.endproc

; Background palette
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

PlayerPalette:
  .word RGB8($ff, $ff, $ff)
  .word RGB8($00, $00, $00)
  .word RGB8($23, $55, $23)
  .word RGB8($3f, $99, $3f)
  .word RGB8($4a, $b5, $4a)
  .word RGB8($5a, $d6, $5a)
  .word RGB8($53, $76, $ff)
  .word RGB8($44, $61, $d2)
  .word RGB8($34, $4b, $a2)
  .word RGB8($00, $00, $fc)
  .word RGB8($f6, $79, $60)
  .word 0, 0, 0, 0

PlaceholderLevel:
.repeat 3
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 6, 6, 6, 6, 6
.endrep
.repeat 8
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 2, 2, 2, 2
.endrep
.repeat 10
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2
.endrep
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2
.repeat 10
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2
.endrep
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 6, 6, 6, 6, 6
PlaceholderLevelEnd:
