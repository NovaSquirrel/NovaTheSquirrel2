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
.import RunAllObjects

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

  seta16
  inc a:retraces   ; Increase NMI count to notify main thread
  seta8
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

  lda #0
  jml StartLevel
.endproc

.export GameMainLoop
.proc GameMainLoop
  phk
  plb
forever:
  ; Draw the player to a display list in main memory
  setaxy16
  inc framecount

  ; Update keys
  lda keydown
  sta keylast
  lda JOY1CUR
  sta keydown
  lda keylast
  eor #$ffff
  and keydown
  sta keynew

  ; Handle delayed block changes
  ldx #(MaxDelayedBlockEdits-1)*2
DelayedBlockLoop:
  ; Count down the timer, if there is a timer
  lda DelayedBlockEditTime,x
  beq @NoBlock
    dec DelayedBlockEditTime,x
    bne @NoBlock
    ; Hit zero? Make the change
    lda DelayedBlockEditAddr,x
    sta LevelBlockPtr
    lda DelayedBlockEditType,x
    jsl ChangeBlock
  @NoBlock:
  dex
  dex
  bpl DelayedBlockLoop

  ; Run stuff for this frame
  stz OamPtr
  jsl RunPlayer
  jsl AdjustCamera
  jsl DrawPlayer
  jsl RunAllObjects

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
  lda BlockUpdateAddress,x
  beq SkipBlock
  sta PPUADDR
  lda BlockUpdateDataTL,x
  sta PPUDATA
  lda BlockUpdateDataTR,x
  sta PPUDATA

  lda BlockUpdateAddress,x ; Move down a row
  add #(32*2)>>1
  sta PPUADDR
  lda BlockUpdateDataBL,x
  sta PPUDATA
  lda BlockUpdateDataBR,x
  sta PPUDATA

  stz BlockUpdateAddress,x ; Cancel out the block now that it's been written
SkipBlock:
  dex
  dex
  bpl BlockUpdateLoop


  ; Handle palette requests
  lda PaletteRequestIndex
  and #255
  beq :+
    tay
    lda PaletteRequestValue ; Do 16-bit read anyway because DoPaletteUpload will mask off the high byte
    jsl DoPaletteUpload
    stz PaletteRequestIndex ; Also clears the value since it's the next byte
  :


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

  ; Background layer
  seta16
  lsr 0
  lsr 2

  lda 2
  add #128
  sta 2
  seta8
  lda 0
  sta BGSCROLLX+2
  lda 1
  sta BGSCROLLX+2
  lda 2
  sta BGSCROLLY+2
  lda 3
  sta BGSCROLLY+2

  jmp forever
.endproc
