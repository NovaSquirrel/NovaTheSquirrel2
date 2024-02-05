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
PlayerFrameSource          = TempVal
; For ppu_copy_oam_partial
OamPartialCopy512Sub        = DecodePointer ; has 3 bytes and then 3 bytes for ScriptPointer
OamPartialCopyDivide16      = DecodePointer + 2
OamPartialCopyDivide16Rsb32 = DecodePointer + 4

VblankHandler:
  seta16
  ; Prepare for vblank - try and do actual computation here to save time inside vblank
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
    seta8
  :

  ; Player frame, if it's needed
  ldx #$ffff
  stx PlayerFrameSource
  tdc ; Clear top byte of accumulator
  lda PlayerFrame
  cmp PlayerFrameLast
  sta PlayerFrameLast
  beq PlayerFramesMatch
    seta16
    xba              ; *256
    asl              ; *512
    ;ora #$8000      <-- For LoROM
    sta PlayerFrameSource
    seta8
  PlayerFramesMatch:

  ; Pack the second OAM table together into the format the PPU expects
  jsl ppu_pack_oamhi_partial
  .a8 ; (does seta8)

  ; And then prepare the DMA values we'll use in ppu_copy_oam_partial
  ; which we can call once we're in vblank
  jsl prepare_ppu_copy_oam_partial
  seta8
  jsl WaitVblank
  ; AXY size preserved, so still .a8 .i16
  jsl ppu_copy_oam_partial
  setaxy16

  ; Set up faster access to DMA registers
  lda #DMAMODE
  tcd
  ; Most DMAs here are DMAMODE_PPUDATA so set it up
  lda #DMAMODE_PPUDATA
  sta <DMAMODE+$00
  sta <DMAMODE+$10

  ; Player frame
  lda a:PlayerFrameSource
  cmp #$ffff
  beq NoPlayerUpload
    sta <DMAADDR+$00
    ora #256
    sta <DMAADDR+$10

    lda #32*8 ; 8 tiles for each DMA
    sta <DMALEN+$00
    sta <DMALEN+$10

    lda #SpriteCHRBase+$000
    sta PPUADDR
    seta8
    .import PlayerGraphics
    lda #^PlayerGraphics
    sta <DMAADDRBANK+$00
    sta <DMAADDRBANK+$10

    lda #%00000001
    sta COPYSTART

    ; Bottom row -------------------
    ldx #SpriteCHRBase+$100
    stx PPUADDR
    lda #%00000010
    sta COPYSTART
    seta16
  NoPlayerUpload:

  ; Do row/column updates if required
  lda ColumnUpdateAddress
  beq :+
    stz ColumnUpdateAddress
    sta PPUADDR
    lda #.loword(ColumnUpdateBuffer)
    sta <DMAADDR
    lda #32*2
    sta <DMALEN
    seta8
    lda #^ColumnUpdateBuffer
    sta <DMAADDRBANK
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
    lda #.loword(RowUpdateBuffer)
    sta <DMAADDR
    ldy #32*2
    sty <DMALEN
    seta8
    lda #^RowUpdateBuffer
    sta <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16

    ; --- Second screen
    txa
    ora #2048>>1
    sta PPUADDR
    lda #.loword(RowUpdateBuffer+32*2)
    sta <DMAADDR
    sty <DMALEN

    seta8
    lda #%00000001
    sta COPYSTART
    seta16
  :

  ; Do row/column updates for second layer
  lda ColumnUpdateAddress2
  beq :+
    stz ColumnUpdateAddress2
    sta PPUADDR
    lda #.loword(ColumnUpdateBuffer2)
    sta <DMAADDR
    lda #32*2
    sta <DMALEN
    seta8
    lda #^ColumnUpdateBuffer2
    sta <DMAADDRBANK
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
    lda #.loword(RowUpdateBuffer2)
    sta <DMAADDR
    ldy #32*2
    sty <DMALEN
    seta8
    lda #^RowUpdateBuffer2
    sta <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16

    ; --- Second screen
    txa
    ora #2048>>1
    sta PPUADDR
    lda #.loword(RowUpdateBuffer2+32*2)
    sta <DMAADDR
    sty <DMALEN

    seta8
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
  sty <DMALEN
  stz GenericUpdateLength,x ; Mark the update slot as free
  lda GenericUpdateSource,x
  sta <DMAADDR
  lda GenericUpdateDestination,x ; >=8000 indicates it's a palette upload
  bmi WasPalette                 ; because only 32K words of VRAM are installed
  ; ---------------
  sta PPUADDR
  seta8
  lda GenericUpdateFlags,x   ; First byte is the bank
  sta <DMAADDRBANK
  lda #1
  sta COPYSTART
  lda GenericUpdateFlags+1,x ; Second byte is flags.
  ; Flag format:
  ; s.......
  ; +------- Do a second DMA with the same length, coming from GenericUpdateSource2
  bpl @NoSecondRow
    seta16
    sty <DMALEN ; Length stored from earlier
    lda GenericUpdateSource2,x
    sta <DMAADDR
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
  stz <DMAMODE   ; Linear, increasing DMA
  lda #<CGDATA
  sta <DMAPPUREG
  lda GenericUpdateFlags,x
  sta <DMAADDRBANK
  lda #1
  sta COPYSTART
  seta16
  ; Restore it to a PPUDATA copy 
  lda #DMAMODE_PPUDATA
  sta <DMAMODE
SkipGeneric:
  dex
  dex
  bpl GenericUpdateLoop

  ; ----------------
  ; Do block updates (or any other tilemap updates that are needed)
  lda ScatterUpdateLength
  beq ScatterBufferEmpty
    sta <DMALEN

    lda #(<PPUADDR << 8) | DMA_0123 | DMA_FORWARD ; Alternate between writing to PPUADDR and PPUDATA
    sta <DMAMODE
    lda #.loword(ScatterUpdateBuffer)
    sta <DMAADDR

    seta8
    lda #^ScatterUpdateBuffer
    sta <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16
  ScatterBufferEmpty:

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
    stz PaletteRequestIndex ; Also clears PaletteRequestValue
    seta8
    lda #^PaletteList
    sta DMAADDRBANK ; Source bank
    lda PaletteRequestUploadIndex
    sta CGADDR
    ; Initiate the transfer
    lda #%00000001
    sta COPYSTART
  :

  ;----------------------------------------------------------------------------
  ;- Ability tileset upload
  ;----------------------------------------------------------------------------

  ; Hold on, is there enough time to upload new ability graphics, if that's needed?
  ; It's 1KB plus four tiles. We can check to make sure it wouldn't cause vblank to be overrun
  ; by checking the current Y position.
  seta8
  bit PPUSTATUS2 ; Resets the flip flop for GETXY
  bit GETXY
  lda YCOORD
  cmp #261-(8+1) ; The following code takes about 8 scanlines, add 1 for security
  bcc :+
@TimeUp:
    ; There's not enough time to copy the ability graphics, so delay that until next frame
    jmp EndOfVblank ; Don't even bother to do the sprite tileset
  :
  ; Read YCOORD a second time - if the high bit of the Y position is set, there is definitely not enough time
  lda YCOORD
  lsr
  bcs @TimeUp
  bit VBLSTATUS ; Need to be in vblank
  bpl @TimeUp
  ; -----------------------------------
  ; Is there actually an ability to copy in?
  lda NeedAbilityChange
  beq NoNeedAbilityChange
    ldx #DMAMODE_PPUDATA
    stx DMAMODE

    .import AbilityIcons
    lda #^AbilityIcons
    sta DMAADDRBANK+$00

    ldx AbilityIconGraphicSource
    stx DMAADDR+$00
    ldy #32*2 ; 2 tiles for each DMA
    sty DMALEN+$00

    ; Top row ----------------------
    ldx #SpriteCHRBase+($100>>1)
    stx PPUADDR
    lda #%00000001
    sta COPYSTART

    ; Bottom row -------------------
    sty DMALEN+$00
    ldx #SpriteCHRBase+($300>>1)
    stx PPUADDR
    sta COPYSTART

    ; Ability graphics -------------
    ldx AbilityGraphicsSource
    stx DMAADDR

    ldx #1024 ; Two rows of tiles
    stx DMALEN
    ldx #SpriteCHRBase+($400>>1)
    stx PPUADDR
    lda #%00000001
    sta COPYSTART

    stz AbilityMovementLock
    stz NeedAbilityChange
    stz NeedAbilityChangeSilent
  NoNeedAbilityChange:

  ;----------------------------------------------------------------------------
  ;- Lowest priority is loading in new sprite tilesets
  ;----------------------------------------------------------------------------
  .a8 ; Still seta8
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
EndOfVblank:

  ; Will seta8 afterward
