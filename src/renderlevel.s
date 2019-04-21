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
.global LevelBuf
.import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight

.segment "Player"

.a16
.i16
.proc RenderLevelScreens
  ; Set the high byte of the pointer
  seta8
  lda #^LevelBuf
  sta LevelBlockPtr+2

  setaxy16
  ; Set the correct scroll value
  lda PlayerPX
  sub #(8*256)
  bcs :+
    lda #0
: sta ScrollX

  ; -------------------

BlockNum = 0
BlocksLeft = 2
YPos = 4
  ; Start rendering
  xba      ; Get the column number in blocks (A still the value written to ScrollX)
  sub #4   ; Render out past the left side a bit
  sta BlockNum
  jsl GetLevelColumnPtr
  lda #26  ; Go 26 blocks forward
  sta BlocksLeft

  lda ScrollY
  xba
  and #LEVEL_HEIGHT-1
  asl
  sta YPos

Loop:
  ; Calculate the column address
  lda BlockNum
  and #15
  asl
  ora #ForegroundBG>>1
  sta ColumnUpdateAddress

  ; Use the other nametable if necessary
  lda BlockNum
  and #16
  beq :+
    lda #2048>>1
    tsb ColumnUpdateAddress
  :

  ; Upload two columns
  ldy YPos
  jsl RenderLevelColumnLeft
  jsl RenderLevelColumnUpload
  inc ColumnUpdateAddress
  ldy YPos
  jsl RenderLevelColumnRight
  jsl RenderLevelColumnUpload

  ; Move onto the next block
  lda LevelBlockPtr
  add #LEVEL_HEIGHT*LEVEL_TILE_SIZE
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1
  sta LevelBlockPtr
  inc BlockNum

  dec BlocksLeft
  bne Loop


  stz ColumnUpdateAddress
  rtl
.endproc

.proc RenderLevelColumnUpload
  php
  seta16

  ; Set DMA parameters  
  lda ColumnUpdateAddress
  sta PPUADDR
  lda #DMAMODE_PPUDATA
  sta DMAMODE
  lda #ColumnUpdateBuffer
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  stz DMAADDRBANK

  lda #INC_DATAHI|VRAM_DOWN
  sta PPUCTRL

  lda #%00000001
  sta COPYSTART

  lda #INC_DATAHI
  sta PPUCTRL
  plp
  rtl
.endproc

.proc RenderLevelRowUpload
  php

  ; .------------------
  ; | First screen
  ; '------------------
  seta16

  ; Set DMA parameters  
  lda RowUpdateAddress
  sta PPUADDR
  lda #DMAMODE_PPUDATA
  sta DMAMODE
  lda #RowUpdateBuffer
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  stz DMAADDRBANK

  lda #%00000001
  sta COPYSTART

  ; .------------------
  ; | Second screen
  ; '------------------
  seta16

  ; Reset the counters. Don't need to do DMAMODE again I assume?
  lda RowUpdateAddress
  ora #2048>>1
  sta PPUADDR
  lda #RowUpdateBuffer+32*2
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  stz DMAADDRBANK

  lda #%00000001
  sta COPYSTART

  plp
  rtl
.endproc

.segment "BlockGraphicData"
; Render the left tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelColumnLeft
  phb
  phk
  plb

  tya
  asl
  and #(32*2)-1
  tax
  stx TempVal
: lda [LevelBlockPtr],y ; Get the next level tile
  iny
  iny
  phy
  asl ; Multiply by 2 because the table is 16-bit
  tay
  ; Write the two tiles in
  lda BlockTopLeft,y
  sta ColumnUpdateBuffer,x
  inx
  inx
  lda BlockBottomLeft,y
  sta ColumnUpdateBuffer,x
  inx
  inx
  ply

  ; Wrap around in the buffer
  txa
  and #(32*2)-1
  tax

  ; Stop after 32 tiles vertically
  cpx TempVal
  bne :-

  plb
  rtl
.endproc

; Render the right tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelColumnRight
  phb
  phk
  plb

  tya
  asl
  and #(32*2)-1
  tax
  stx TempVal
: lda [LevelBlockPtr],y ; Get the next level tile
  iny
  iny
  phy
  asl ; Multiply by 2 because the table is 16-bit
  tay
  ; Write the two tiles in
  lda BlockTopRight,y
  sta ColumnUpdateBuffer,x
  inx
  inx
  lda BlockBottomRight,y
  sta ColumnUpdateBuffer,x
  inx
  inx
  ply

  ; Wrap around in the buffer
  txa
  and #(32*2)-1
  tax

  ; Stop after 32 tiles vertically
  cpx TempVal
  bne :-

  plb
  rtl
.endproc


; Render the left tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; Initialize X with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowTop
  phb
  phk
  plb

  lda #20
  sta TempVal

: lda [LevelBlockPtr],y ; Get the next level tile
  phy
  asl ; Multiply by 2 because the table is 16-bit
  tay
  ; Write the two tiles in
  lda BlockTopLeft,y
  sta RowUpdateBuffer,x
  inx
  inx
  lda BlockTopRight,y
  sta RowUpdateBuffer,x
  inx
  inx
  ply

  ; Next column
  tya
  add #LEVEL_HEIGHT*LEVEL_TILE_SIZE
  tay

  ; Wrap around in the buffer
  txa
  and #(64*2)-1
  tax

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rtl
.endproc

; Render the right tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; Initialize X with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowBottom
  phb
  phk
  plb

  lda #20
  sta TempVal

: lda [LevelBlockPtr],y ; Get the next level tile
  phy
  asl ; Multiply by 2 because the table is 16-bit
  tay
  ; Write the two tiles in
  lda BlockBottomLeft,y
  sta RowUpdateBuffer,x
  inx
  inx
  lda BlockBottomRight,y
  sta RowUpdateBuffer,x
  inx
  inx
  ply

  ; Next column
  tya
  add #LEVEL_HEIGHT*LEVEL_TILE_SIZE
  tay

  ; Wrap around in the buffer
  txa
  and #(64*2)-1
  tax

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rtl
.endproc
