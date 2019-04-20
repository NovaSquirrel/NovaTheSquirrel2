.include "snes.inc"
.include "global.inc"
.smart
.global LevelBuf
.import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight

.code

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
  and #31
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
    lda ColumnUpdateAddress
    ora #2048>>1
    sta ColumnUpdateAddress
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

  ldx #0
: lda [LevelBlockPtr],y ; Get the next level tile
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

  ; Stop after 32 tiles vertically
  cpx #32*2
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

  ldx #0
: lda [LevelBlockPtr],y ; Get the next level tile
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

  ; Stop after 32 tiles vertically
  cpx #32*2
  bne :-

  plb
  rtl
.endproc


; Render the left tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowTop
  phb
  phk
  plb

  ldx #0
: lda [LevelBlockPtr],y ; Get the next level tile
  iny
  phy
  asl ; Multiply by 2 because the table is 16-bit
  tay
  ; Write the two tiles in
  lda BlockTopLeft,y
  sta ColumnUpdateBuffer,x
  inx
  inx
  lda BlockTopRight,y
  sta ColumnUpdateBuffer,x
  inx
  inx
  ply

  ; Next column
  lda LevelBlockPtr
  add #LEVEL_HEIGHT*LEVEL_TILE_SIZE
  sta LevelBlockPtr

  ; Stop after 64 tiles horizontally
  cpx #64*2
  bne :-

  plb
  rtl
.endproc

; Render the right tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowBottom
  phb
  phk
  plb

  ldx #0
: lda [LevelBlockPtr],y ; Get the next level tile
  phy
  asl ; Multiply by 2 because the table is 16-bit
  tay
  ; Write the two tiles in
  lda BlockBottomLeft,y
  sta ColumnUpdateBuffer,x
  inx
  inx
  lda BlockBottomRight,y
  sta ColumnUpdateBuffer,x
  inx
  inx
  ply

  ; Next column
  lda LevelBlockPtr
  add #LEVEL_HEIGHT*LEVEL_TILE_SIZE
  sta LevelBlockPtr

  ; Stop after 64 tiles horizontally
  cpx #64*2
  bne :-

  plb
  rtl
.endproc

