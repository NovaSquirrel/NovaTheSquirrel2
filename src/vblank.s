; Super Princess Engine
; Copyright (C) 2019-2020 NovaSquirrel
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

; This file has Nova the Squirrel 2's vblank handling code,
; and is included by main.s

VblankHandler:
  ; Pack the second OAM table together into the format the PPU expects
  jsl ppu_pack_oamhi_partial
  ; And once that's out of the way, wait until vertical blank where
  ; I can actually copy all of the prepared OAM to the PPU
  jsl WaitVblank
  jsl ppu_copy_oam_partial
  ; And also do background updates:
  setaxy16

  lda #DMAMODE
  tcd

  ; Do row/column updates if required
  lda ColumnUpdateAddress
  beq :+
    stz ColumnUpdateAddress
    sta PPUADDR
    lda #DMAMODE_PPUDATA
    sta <DMAMODE
    lda #ColumnUpdateBuffer
    sta <DMAADDR
    lda #32*2
    sta <DMALEN
    seta8
    stz <DMAADDRBANK
    lda #INC_DATAHI|VRAM_DOWN
    sta PPUCTRL
    lda #%00000001
    sta COPYSTART
    lda #INC_DATAHI
    sta PPUCTRL
    seta16
  :

  ldx RowUpdateAddress
  beq :+
    stz RowUpdateAddress
    ; --- First screen
    ; Set DMA parameters  
    stx PPUADDR
    lda #DMAMODE_PPUDATA
    sta <DMAMODE
    lda #RowUpdateBuffer
    sta <DMAADDR
    ldy #32*2
    sty <DMALEN
    seta8
    stz <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16

    ; --- Second screen
    txa
    ora #2048>>1
    sta PPUADDR
    lda #RowUpdateBuffer+32*2
    sta <DMAADDR
    sty <DMALEN

    seta8
    stz <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16
  :

  ; Do row/column updates for second layer
  lda ColumnUpdateAddress2
  beq :+
    stz ColumnUpdateAddress2
    sta PPUADDR
    lda #DMAMODE_PPUDATA
    sta <DMAMODE
    lda #ColumnUpdateBuffer2
    sta <DMAADDR
    lda #32*2
    sta <DMALEN
    seta8
    stz <DMAADDRBANK
    lda #INC_DATAHI|VRAM_DOWN
    sta PPUCTRL
    lda #%00000001
    sta COPYSTART
    lda #INC_DATAHI
    sta PPUCTRL
    seta16
  :

  lda RowUpdateAddress2
  beq :+
    stz RowUpdateAddress2
    ; --- First screen
    ; Set DMA parameters  
    stx PPUADDR
    lda #DMAMODE_PPUDATA
    sta <DMAMODE
    lda #RowUpdateBuffer2
    sta <DMAADDR
    ldy #32*2
    sty <DMALEN
    seta8
    stz <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16

    ; --- Second screen
    txa
    ora #2048>>1
    sta PPUADDR
    lda #RowUpdateBuffer2+32*2
    sta <DMAADDR
    sty <DMALEN

    seta8
    stz <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16
  :

  .a16
  ; Do generic DMA updates
  ldx #(GENERIC_UPDATE_COUNT-1)*2
GenericUpdateLoop:
  ldy GenericUpdateLength,x
  beq SkipGeneric
  ; Y used for safe-keeping in case it's needed, since it will get zero'd
  sty DMALEN
  stz GenericUpdateLength,x ; Mark the update slot as free
  lda GenericUpdateSource,x
  sta DMAADDR
  lda GenericUpdateDestination,x ; >=8000 indicates it's a palette upload
  bmi WasPalette                 ; because only 32K words of VRAM are installed
  ; ---------------
  sta PPUADDR
  lda #DMAMODE_PPUDATA
  sta DMAMODE
  seta8
  lda GenericUpdateFlags,x
  sta DMAADDRBANK
  lda #1
  sta COPYSTART
  lda GenericUpdateFlags+1,x ; Check metadata
  bpl @NoSecondRow
    seta16
    sty DMALEN ; Length stored from earlier
    lda GenericUpdateSource2,x
    sta DMAADDR
    ; Can probably leave the bank the same;
    ; I don't think I'll ever have data straddle two banks, due to LoROM
    ; and I don't think DMA can modify the source bank anyway
    lda GenericUpdateDestination2,x
    sta PPUADDR
    seta8
    lda #1
    sta COPYSTART
  @NoSecondRow:
  seta16
  bra SkipGeneric
  ; ---------------

WasPalette:
  seta8
  sta CGADDR
  stz DMAMODE   ; Linear, increasing DMA
  lda #<CGDATA
  sta DMAPPUREG
  lda GenericUpdateFlags,x
  sta DMAADDRBANK
  lda #1
  sta COPYSTART
  seta16
SkipGeneric:
  dex
  dex
  bpl GenericUpdateLoop

  lda #$2100
  tcd

  ; -----------------------------------
  ; Do block updates
  ldx #(BLOCK_UPDATE_COUNT-1)*2
BlockUpdateLoop:
  lda BlockUpdateAddress,x
  beq SkipBlock
  sta <PPUADDR
  lda BlockUpdateDataTL,x
  sta <PPUDATA
  lda BlockUpdateDataTR,x
  sta <PPUDATA

  lda BlockUpdateAddress,x ; Move down a row
  add #(32*2)>>1
  sta <PPUADDR
  lda BlockUpdateDataBL,x
  sta <PPUDATA
  lda BlockUpdateDataBR,x
  sta <PPUDATA

  stz BlockUpdateAddress,x ; Cancel out the block now that it's been written
SkipBlock:
  dex
  dex
  bpl BlockUpdateLoop

  lda #0
  tcd

  ; -----------------------
  ; Handle palette requests
  ; (Maybe this should be combined into the generic updates later?)
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
