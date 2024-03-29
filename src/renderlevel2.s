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

.include "snes.inc"
.include "global.inc"
.smart
.global LevelBuf
.import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight

.segment "C_Player"

.a16
.i16
.export FG2TilemapUpdate
.proc FG2TilemapUpdate
  lda ScrollX
  add FG2OffsetX
  sta 0
  lda OldScrollX
  add OldFG2OffsetX
  sta 2

  ; Is a column update required?
  lda 0
  eor 2
  and #$80
  beq NoUpdateColumn
    ; Detect rightward movement even if wrapping to zero
    lda 0
    cmp #$0100
    bcs :+
    lda 2
    cmp #$ff00
    bcc :+
    lda 0
    jsr ToTiles
    bra UpdateRight
  :

    lda 0
    cmp 2
    jsr ToTiles
    bcs UpdateRight
  UpdateLeft:
    sub #2             ; Two tiles to the left
    jsr UpdateColumn2
    bra NoUpdateColumn
  UpdateRight:
    add #34            ; Two tiles past the end of the screen on the right
    jsr UpdateColumn2
  NoUpdateColumn:

  lda ScrollY
  add FG2OffsetY
  sta 0
  lda OldScrollY
  add OldFG2OffsetY
  sta 2

  ; Is a row update required?
  lda 0
  eor 2
  and #$80
  beq NoUpdateRow
    ; Detect downward movement even if wrapping to zero
    lda 0
    cmp #$0100
    bcs :+
    lda 2
    cmp #$ff00
    bcc :+
    lda 0
    jsr ToTiles
    bra UpdateDown
  :

    lda 0
    cmp 2
    jsr ToTiles
    bcs UpdateDown
  UpdateUp:
    jsr UpdateRow2
    bra NoUpdateRow
  UpdateDown:
    add #29            ; Just past the screen height
    jsr UpdateRow2
  NoUpdateRow:
  rtl

; Convert a 12.4 scroll position to a number of tiles
ToTiles:
  php
  lsr ; \ shift out the subpixels
  lsr ;  \
  lsr ;  /
  lsr ; /

  lsr ; \
  lsr ;  | shift out 8 pixels
  lsr ; /
  plp
  rts
.endproc

.a16
.i16
.proc UpdateRow2
Temp = 4
YPos = 6
  sta Temp

  ; Calculate the address of the row
  ; (Always starts at the leftmost column
  ; and extends all the way to the right.)
  and #31
  asl ; Multiply by 32, the number of words per row in a screen
  asl
  asl
  asl
  asl
  ora SecondFGTilemapPointer
  sta RowUpdateAddress2

  ; Get level pointer address
  ; (Always starts at the leftmost column of the screen)
  lda ScrollX
  add FG2OffsetX
  xba
  dec a
  jsl GetLevelColumnPtr

  ; Get index for the buffer
  lda ScrollX
  add FG2OffsetX
  xba
  dec a
  asl
  asl
  and #(64*2)-1
  tay

  ; Calculate an index to read level data with
  lda Temp
  and #.loword(~1)
  ora LevelBlockPtr
  tax

  ; Generate the top or the bottom as needed
  lda Temp
  lsr
  bcs :+
  jsl RenderLevelRowTop2
  rts
: jsl RenderLevelRowBottom2
  rts
.endproc

.proc UpdateColumn2
Temp = 4
YPos = 6
  sta Temp

  ; Calculate address of the column
  and #31
  ora SecondFGTilemapPointer
  sta ColumnUpdateAddress2

  ; Use the second screen if required
  lda Temp
  and #32
  beq :+
    lda #2048>>1
    tsb ColumnUpdateAddress2
  :

  ; Get level pointer address
  lda Temp ; Get metatile count
  lsr
  jsl GetLevelColumnPtr

  ; Calculate an index to read level data with
  lda ScrollY
  add FG2OffsetY
  xba
  asl
  and LevelColumnMask
  ora LevelBlockPtr
  tax

  ; Generate the left or right as needed
  lda Temp
  lsr
  bcc :+
  jsl RenderLevelColumnRight2
  rts
: jsl RenderLevelColumnLeft2
  rts 
.endproc

; -------------------------------------

.a16
.i16
.export RenderLevelScreens2
.proc RenderLevelScreens2
; 0 is used by RenderLevelColumnLeft2 and RenderLevelColumnRight2
BlockNum = 2
BlocksLeft = 4
Pointer = 6
  ; Start rendering
  lda ScrollX+1 ; Get the column number in blocks
  add FG2OffsetX+1
  and #$ff
  sub #4   ; Render out past the left side a bit
  sta BlockNum
  jsl GetLevelColumnPtr
  ; Don't OR in #$4000 because we'll index from LevelBufAlt instead of LevelBuf here

  lda #26  ; Go 26 blocks forward
  sta BlocksLeft

  ; Calculate the starting pointer to read level data
  lda ScrollY
  add FG2OffsetY
  xba
  and LevelColumnMask
  asl
  ora LevelBlockPtr
  sta Pointer

Loop:
  ; Calculate the column address
  lda BlockNum
  and #15
  asl
  ora SecondFGTilemapPointer
  sta ColumnUpdateAddress2

  ; Use the other nametable if necessary
  lda BlockNum
  and #16
  beq :+
    lda #2048>>1
    tsb ColumnUpdateAddress2
  :

  ; Upload two columns
  ldx Pointer
  jsl RenderLevelColumnLeft2
  jsl RenderLevelColumnUpload2
  inc ColumnUpdateAddress2
  ldx Pointer
  jsl RenderLevelColumnRight2
  jsl RenderLevelColumnUpload2

  ; Move onto the next block
  lda Pointer
  add LevelColumnSize
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1
  sta Pointer
  inc BlockNum

  dec BlocksLeft
  bne Loop


  stz ColumnUpdateAddress2
  rtl
.endproc

.proc RenderLevelColumnUpload2
  php
  seta16

  ; Set DMA parameters  
  lda ColumnUpdateAddress2
  sta PPUADDR
  lda #DMAMODE_PPUDATA
  sta DMAMODE
  lda #.loword(ColumnUpdateBuffer2)
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  lda #^ColumnUpdateBuffer2
  sta DMAADDRBANK

  lda #INC_DATAHI|VRAM_DOWN
  sta PPUCTRL

  lda #%00000001
  sta COPYSTART

  lda #INC_DATAHI
  sta PPUCTRL
  plp
  rtl
.endproc

.proc RenderLevelRowUpload2
  php

  ; .------------------
  ; | First screen
  ; '------------------
  seta16

  ; Set DMA parameters  
  lda RowUpdateAddress2
  sta PPUADDR
  lda #DMAMODE_PPUDATA
  sta DMAMODE
  lda #.loword(RowUpdateBuffer2)
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  lda #^ColumnUpdateBuffer2
  sta DMAADDRBANK

  lda #%00000001
  sta COPYSTART

  ; .------------------
  ; | Second screen
  ; '------------------
  seta16

  ; Reset the counters. Don't need to do DMAMODE again I assume?
  lda RowUpdateAddress2
  ora #2048>>1
  sta PPUADDR
  lda #.loword(RowUpdateBuffer2+32*2)
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  ;stz DMAADDRBANK

  lda #%00000001
  sta COPYSTART

  plp
  rtl
.endproc

.segment "BlockGraphicData"
; Render the left tile of a column of blocks
; (starting from index X within LevelBufAlt)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelColumnLeft2
  ColumnBits = 0
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  ; Get the bits that should stay constant for the current column
  lda LevelColumnMask
  eor #$ffff
  sta ColumnBits
  txa
  and ColumnBits
  sta ColumnBits

  ; Calculate starting index for scrolling buffer
  txa
  asl
  and #(32*2)-1
  tay
  sty TempVal
  ; Loop
:
  txa ; Stay in this column
  and LevelColumnMask
  ora ColumnBits
  tax

  lda a:LevelBufAlt,x ; Get the next level tile
  inx
  inx
  phx
  tax
  ; Write the two tiles in
  lda f:BlockTopLeft,x
  sta ColumnUpdateBuffer2,y
  iny
  iny
  lda f:BlockBottomLeft,x
  sta ColumnUpdateBuffer2,y
  iny
  iny
  plx

  ; Wrap around in the buffer
  tya
  and #(32*2)-1
  tay

  ; Stop after 32 tiles vertically
  cpy TempVal
  bne :-

  plb
  rtl
.endproc

; Render the right tile of a column of blocks
; (starting from index X within LevelBufAlt)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelColumnRight2
  ColumnBits = 0
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  ; Get the bits that should stay constant for the current column
  lda LevelColumnMask
  eor #$ffff
  sta ColumnBits
  txa
  and ColumnBits
  sta ColumnBits

  ; Calculate starting index for scrolling buffer
  txa
  asl
  and #(32*2)-1
  tay
  sty TempVal
  ; Loop
:
  txa ; Stay in this column
  and LevelColumnMask
  ora ColumnBits
  tax

  lda a:LevelBufAlt,x ; Get the next level tile
  inx
  inx
  phx
  tax
  ; Write the two tiles in
  lda f:BlockTopRight,x
  sta ColumnUpdateBuffer2,y
  iny
  iny
  lda f:BlockBottomRight,x
  sta ColumnUpdateBuffer2,y
  iny
  iny
  plx

  ; Wrap around in the buffer
  tya
  and #(32*2)-1
  tay

  ; Stop after 32 tiles vertically
  cpy TempVal
  bne :-

  plb
  rtl
.endproc


; Render the left tile of a column of blocks
; (starting from index X within LevelBufAlt)
; Initialize Y with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowTop2
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  lda #20
  sta TempVal

: lda a:LevelBufAlt,x ; Get the next level tile
  phx
  tax
  ; Write the two tiles in
  lda f:BlockTopLeft,x
  sta RowUpdateBuffer2,y
  iny
  iny
  lda f:BlockTopRight,x
  sta RowUpdateBuffer2,y
  iny
  iny
  pla

  ; Next column
  add LevelColumnSize
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1 ; Mask for entire level, dimensions actually irrelevant
  tax

  ; Wrap around in the buffer
  tya
  and #(64*2)-1
  tay

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rtl
.endproc

; Render the right tile of a column of blocks
; (starting from index X within LevelBufAlt)
; Initialize Y with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowBottom2
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  lda #20
  sta TempVal

: lda a:LevelBufAlt,x ; Get the next level tile
  phx
  tax
  ; Write the two tiles in
  lda f:BlockBottomLeft,x
  sta RowUpdateBuffer2,y
  iny
  iny
  lda f:BlockBottomRight,x
  sta RowUpdateBuffer2,y
  iny
  iny
  pla

  ; Next column
  add LevelColumnSize
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1 ; Mask for entire level, dimensions actually irrelevant
  tax

  ; Wrap around in the buffer
  tya
  and #(64*2)-1
  tay

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rtl
.endproc
