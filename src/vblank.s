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

; Synchronize with playerdraw.s
AbilityGraphicsSource      = TouchTemp
AbilityIconGraphicSource   = TouchTemp + 2
PaletteRequestUploadIndex  = TouchTemp + 4
PaletteRequestSource       = TouchTemp + 5

VblankHandler:
  seta16
  ; Prepare for vblank
  lda NeedAbilityChange
  and #255
  beq :+
    .import AbilityTilesetForId, AbilityIcons, AbilityGraphics, PaletteList
    lda PlayerAbility
    and #255
    tax
    lda f:AbilityTilesetForId,x
    and #255
    xba
    asl
    asl
    adc #.loword(AbilityGraphics) ; assert((PS & 1) == 0) Carry always clear here
    sta AbilityGraphicsSource
    ;---
    lda PlayerAbility
    and #255
    xba ; Multiply by 256
    lsr ; Divide by 2 to get 128
    add #.loword(AbilityIcons)
    sta AbilityIconGraphicSource
  :
  seta8
  lda PaletteRequestIndex
  beq :+
    asl
    asl
    asl
    sec
    rol
    sta PaletteRequestUploadIndex

    seta16
    lda PaletteRequestValue
    and #255
    sta 0
    asl
    asl
    asl
    asl
    sub 0
    asl
    add #PaletteList & $ffff
    sta PaletteRequestSource
  :

  ; Pack the second OAM table together into the format the PPU expects
  jsl ppu_pack_oamhi_partial ; does seta8
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
    tax
    sta PPUADDR
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
  lda GenericUpdateFlags,x   ; First byte is the bank
  sta DMAADDRBANK
  lda #1
  sta COPYSTART
  lda GenericUpdateFlags+1,x ; Second byte is flags.
  ; Flag format:
  ; s.......
  ; +------- Do a second DMA with the same length, coming from GenericUpdateSource2
  bpl @NoSecondRow
    seta16
    sty DMALEN ; Length stored from earlier
    lda GenericUpdateSource2,x
    sta DMAADDR
    ; Leave the bank the same - the data will not straddle two banks
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
     lda PaletteRequestSource
     sta DMAADDR
     lda #DMAMODE_CGDATA
     sta DMAMODE ; Upload to CGRAM
     lda #15*2
     sta DMALEN ; Size
     seta8
     lda #^PaletteList
     sta DMAADDRBANK ; Source bank
     lda PaletteRequestUploadIndex
     sta CGADDR
     ; Initiate the transfer
     lda #%00000001
     sta COPYSTART
     stz PaletteRequestIndex
  :

  ; -----------------------------------
  jsl PlayerFrameUpload

  ; Lowest priority is loading in new sprite tilesets
  seta8
  lda SpriteTilesRequestSource+2 ; Won't have sources with a zero bank
  beq @DontUploadSpriteTiles
  bit PPUSTATUS2 ; Resets the flip flop for GETXY
  bit GETXY
  lda YCOORD
  cmp #261-(7+1) ; Seems to take about 7 scanlines - add one for safety
  bcs @DontUploadSpriteTiles
  ; Read YCOORD a second time - if the high bit of the Y position is set, there is definitely not enough time
  lda YCOORD
  lsr
  bcs @DontUploadSpriteTiles
  bit VBLSTATUS ; Need to be in vblank
  bpl @DontUploadSpriteTiles
    lda SpriteTilesRequestSource
    sta DMAADDR
    seta16
    lda SpriteTilesRequestSource+1
    sta DMAADDRHI ; Gets the bank too
    lda SpriteTilesRequestDestination
    sta PPUADDR

    lda #DMAMODE_PPUDATA
    sta DMAMODE
    lda #1024
    sta DMALEN
    seta8
    lda #1
    sta COPYSTART

    stz SpriteTilesRequestSource+2 ; Bank
  @DontUploadSpriteTiles:
  seta16
