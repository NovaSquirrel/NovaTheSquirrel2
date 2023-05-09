; Super Princess Engine
; Copyright (C) 2019-2023 NovaSquirrel
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
.import BlockSpriteTile

HORIZ_SPRITE_COLS = 17
HORIZ_SPRITE_ROWS = 14

VERT_SPRITE_COLS = 16
VERT_SPRITE_ROWS = 15

RenderLevelSpriteBuffer = LevelSpriteFGBuffer

.segment "C_Player"

.a16
.i16
.export InitRenderLevelWithSprites
.proc InitRenderLevelWithSprites
  bit8 VerticalLevelFlag
  bmi InitRenderLevelWithSpritesVertical

; Leave 0 free for FillInColumnForSpriteRender
ColumnsLeft = 2
  ph2banks LevelBuf, InitRenderLevelWithSprites
  plb
  lda #HORIZ_SPRITE_COLS
  sta ColumnsLeft

  jsr IndexOfBottomOfLevelAtScrollX
  tax
  ldy #0
: jsr FillInColumnForSpriteRender
  txa
  add #(32-HORIZ_SPRITE_ROWS)*2
  tax
  dec ColumnsLeft
  bne :-
  plb

  rtl

; -------------------------------------
InitRenderLevelWithSpritesVertical:
; Leave 0 free for FillInRowForSpriteRender
RowsLeft = 2
  ph2banks LevelBuf, InitRenderLevelWithSprites
  plb
  lda #VERT_SPRITE_ROWS
  sta RowsLeft

  lda ScrollY
  bit #%00001000 ; Round the Y position
  beq :+
    add #%00010000
  :
  xba
  and #255
  asl
  tax
  ldy #0
: jsr FillInRowForSpriteRender
  txa
  sub #256*2*VERT_SPRITE_COLS-2
  tax
  dec RowsLeft
  bne :-
  plb

  rtl
.endproc

; .----------------------------------------------------------------------------
; | Horizontal levels
; '----------------------------------------------------------------------------

.a16
.i16
.proc IndexOfBottomOfLevelAtScrollX
  lda ScrollX
  xba
  and #255
  asl ; * 2
  asl ; * 4
  asl ; * 8
  asl ; * 16
  asl ; * 32
  asl ; * 64
  ora #(32-HORIZ_SPRITE_ROWS)*2
  rts
.endproc

.a16
.i16
; Copy one column from LevelBuf,x to RenderLevelSpriteBuffer,y
.proc FillInColumnForSpriteRender
ColumnBlocksLeft = 0
  lda #HORIZ_SPRITE_ROWS
  sta ColumnBlocksLeft

  ph2banks LevelBuf, FillInColumnForSpriteRender
  plb

FillLoop:
  lda a:LevelBuf,x
  phx
  tax
  lda f:BlockSpriteTile,x
  plx
  sta a:RenderLevelSpriteBuffer,y
  inx
  inx
  iny
  iny
  dec ColumnBlocksLeft
  bne FillLoop

  plb
  rts
.endproc

.a16
.i16
.export UpdateSpriteFGLayer
.proc UpdateSpriteFGLayer
; Horizontal levels have the buffer arranged in columns major format
XOffset = 0
  ; For vertical levels, use the other routine
  bit8 VerticalLevelFlag
  jmi UpdateSpriteFGLayerVertical

  lda ScrollX
  eor OldScrollX
  and #$0100
  beq NoBufferChangeNeeded
    lda ScrollX
    cmp OldScrollX
    bcs UpdateRight
  UpdateLeft: ; Moved left, so move everything right and update the left side
    lda #((HORIZ_SPRITE_COLS-1)*HORIZ_SPRITE_ROWS*2)-1
    ldx #.loword(RenderLevelSpriteBuffer+(HORIZ_SPRITE_ROWS*(HORIZ_SPRITE_COLS-1)*2-1)) ; Source
    ldy #.loword(RenderLevelSpriteBuffer+(HORIZ_SPRITE_ROWS*(HORIZ_SPRITE_COLS)*2-1)) ; Destination
    mvp #^RenderLevelSpriteBuffer,#^RenderLevelSpriteBuffer

    jsr IndexOfBottomOfLevelAtScrollX
    tax
    ldy #0
    jsr FillInColumnForSpriteRender

    bra NoBufferChangeNeeded
  UpdateRight: ; Moved right, so move everything left and update the right side
    lda #((HORIZ_SPRITE_COLS-1)*HORIZ_SPRITE_ROWS*2)-1
    ldx #.loword(RenderLevelSpriteBuffer+(HORIZ_SPRITE_ROWS*2)) ; Source
    ldy #.loword(RenderLevelSpriteBuffer) ; Destination
    mvn #^RenderLevelSpriteBuffer,#^RenderLevelSpriteBuffer

    jsr IndexOfBottomOfLevelAtScrollX
    add #32*16*2 ; 32 per column, 16 columns, 2 bytes each
    tax
    ldy #HORIZ_SPRITE_ROWS*(HORIZ_SPRITE_COLS-1)*2
    jsr FillInColumnForSpriteRender
  NoBufferChangeNeeded:
  phk ; Fix B and also point it here for the Positions,x accesses
  plb

; .--------------------------------------------------------
; | Render to sprites!
; '--------------------------------------------------------
  lda ScrollX
  and #%11110000
  asl
  asl
  asl
  asl
  sta XOffset

  ldx #0
  ldy OamPtr

; ---------------------------------------------------------
; Left section
  .repeat 14, I
  lda f:RenderLevelSpriteBuffer+(2*I),x
  beq :++
    sta OAM_TILE,y
    lda Positions+(2*I),x ;Low byte Y, High byte X
                          ;Could just be a constant instead
    sub XOffset           ;Change the high byte and leave the Y alone
    xba                   ;Low byte X, High byte Y
    sta OAM_XPOS,y
    lda #$0300  ; Use 16x16 sprites
    sta OAMHI,y

    lda XOffset
    bne :+
      lda #$0200
      sta OAMHI,y
    :

    iny
    iny
    iny
    iny
  :
  .endrep

  ldx #14*2

; ---------------------------------------------------------
; Middle section
Loop:
  .repeat 14, I
  lda f:RenderLevelSpriteBuffer+(2*I),x
  beq :+
    sta OAM_TILE,y
    lda Positions+(2*I),x ;Low byte Y, High byte X
    sub XOffset           ;Change the high byte and leave the Y alone
    xba                   ;Low byte X, High byte Y
    sta OAM_XPOS,y
    lda #$0200  ; Use 16x16 sprites
    sta OAMHI,y
    iny
    iny
    iny
    iny
  :
  .endrep
  txa
  add #14*2
  tax
  cpx #(HORIZ_SPRITE_COLS-1) * HORIZ_SPRITE_ROWS * 2
  jne Loop

; ---------------------------------------------------------
; Right section
  lda XOffset
  bne :+
    sty OamPtr
    rtl
  :
  .repeat 14, I
  lda f:RenderLevelSpriteBuffer+(2*I),x
  beq :+
    sta OAM_TILE,y
    lda Positions+(2*I),x ;Low byte Y, High byte X
                          ;Could just be a constant instead
    sub XOffset           ;Change the high byte and leave the Y alone
    xba                   ;Low byte X, High byte Y
    sta OAM_XPOS,y
    lda #$0200  ; Use 16x16 sprites
    sta OAMHI,y
    iny
    iny
    iny
    iny
  :
  .endrep
  sty OamPtr
  rtl

Positions:
  .repeat ::HORIZ_SPRITE_COLS * ::HORIZ_SPRITE_ROWS, I
    .byte (I .mod HORIZ_SPRITE_ROWS)*16 ; Y
    .byte <((I / HORIZ_SPRITE_ROWS)*16) ; X
  .endrep
.endproc

; .----------------------------------------------------------------------------
; | Vertical levels
; '----------------------------------------------------------------------------

.a16
.i16
; Copy one row from LevelBuf,x to RenderLevelSpriteBuffer,y
; Very similar to FillInColumnForSpriteRender except it moves horizontally through the level
.proc FillInRowForSpriteRender
ColumnBlocksLeft = 0
  lda #VERT_SPRITE_COLS
  sta ColumnBlocksLeft

  ph2banks LevelBuf, FillInRowForSpriteRender
  plb

FillLoop:
  lda a:LevelBuf,x
  phx
  tax
  lda f:BlockSpriteTile,x
  plx
  sta a:RenderLevelSpriteBuffer,y

  txa
  add LevelColumnSize
  tax
  iny
  iny
  dec ColumnBlocksLeft
  bne FillLoop

  plb
  rts
.endproc

.a16
.i16
.export UpdateSpriteFGLayerVertical
.proc UpdateSpriteFGLayerVertical
; Vertical levels have the buffer arranged in row major format
YOffset = 0
RoundScrollY    = 4
RoundOldScrollY = 6
  lda ScrollY
  jsr Round
  sta RoundScrollY

  lda OldScrollY
  jsr Round
  sta RoundOldScrollY

  lda RoundScrollY
  eor RoundOldScrollY
  and #$0100
  beq NoBufferChangeNeeded
    lda RoundScrollY
    cmp RoundOldScrollY
    bcs UpdateDown
  UpdateUp: ; Moved left, so move everything right and update the left side
    lda #((VERT_SPRITE_ROWS-1)*VERT_SPRITE_COLS*2)-1
    ldx #.loword(RenderLevelSpriteBuffer+(VERT_SPRITE_COLS*(VERT_SPRITE_ROWS-1)*2-1)) ; Source
    ldy #.loword(RenderLevelSpriteBuffer+(VERT_SPRITE_COLS*(VERT_SPRITE_ROWS)*2-1)) ; Destination
    mvp #^RenderLevelSpriteBuffer,#^RenderLevelSpriteBuffer

    lda RoundScrollY
    xba
    and #255
    asl
    tax
    ldy #0
    jsr FillInRowForSpriteRender

    bra NoBufferChangeNeeded
  UpdateDown: ; Moved right, so move everything left and update the right side
    lda #((VERT_SPRITE_ROWS-1)*HORIZ_SPRITE_COLS*2)-1
    ldx #.loword(RenderLevelSpriteBuffer+(VERT_SPRITE_COLS*2)) ; Source
    ldy #.loword(RenderLevelSpriteBuffer) ; Destination
    mvn #^RenderLevelSpriteBuffer,#^RenderLevelSpriteBuffer

    lda RoundScrollY
    xba
    and #255
    asl
    adc #14*2 ; Go down 14 blocks
    tax
    ldy #VERT_SPRITE_COLS*(VERT_SPRITE_ROWS-1)*2
    jsr FillInRowForSpriteRender
  NoBufferChangeNeeded:
  phk ; Fix B and also point it here for the Positions,x accesses
  plb

; .--------------------------------------------------------
; | Render to sprites!
; '--------------------------------------------------------
  lda RoundScrollY
  and #%11110000
  asl
  asl
  asl
  asl
  sta YOffset

  ldx #0
  ldy OamPtr

; ---------------------------------------------------------
; Main section
Loop:
  .repeat 16, I
  lda f:RenderLevelSpriteBuffer+(2*I),x
  beq :+
    sta OAM_TILE,y
    lda Positions+(2*I),x ;High byte Y, Low byte X
    sub YOffset           ;Change the high byte and leave the X alone
    sta OAM_XPOS,y
    lda #$0200  ; Use 16x16 sprites
    sta OAMHI,y
    iny
    iny
    iny
    iny
  :
  .endrep
  txa
  add #16*2
  tax
  cpx #(VERT_SPRITE_ROWS-1) * VERT_SPRITE_COLS * 2
  jne Loop

; ---------------------------------------------------------
; Bottom section
  lda YOffset
  bne :+
    sty OamPtr
    rtl
  :
  .repeat 16, I
  lda f:RenderLevelSpriteBuffer+(2*I),x
  beq :+
    sta OAM_TILE,y
    lda Positions+(2*I),x ;High byte Y, Low byte X
                          ;Could just be a constant instead
    sub YOffset           ;Change the high byte and leave the X alone
    sta OAM_XPOS,y
    lda #$0200  ; Use 16x16 sprites
    sta OAMHI,y
    iny
    iny
    iny
    iny
  :
  .endrep

  sty OamPtr
  rtl

Positions:
  .repeat ::VERT_SPRITE_COLS * ::VERT_SPRITE_ROWS, I
    .byte <((I .mod VERT_SPRITE_COLS)*16) ; X
    .byte (I / VERT_SPRITE_COLS)*16 ; Y
  .endrep

.a16
Round:
  bit #%00001000
  beq :+
    add #%00010000
  :
  rts
.endproc

