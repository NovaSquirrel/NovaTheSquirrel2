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

.segment "Player"

.a16
.i16
.proc AdjustCamera
ScrollOldX = 0
ScrollOldY = 2
TargetX = 4
TargetY = 6

  ; Save the old scroll positions
  lda ScrollX
  sta ScrollOldX
  lda ScrollY
  sta ScrollOldY

  ; Find the target scroll positions
  lda PlayerPX
  sub #8*256
  bcs :+
    lda #0
: sta TargetX

  lda PlayerPY
  sub #8*256  ; Pull back to center vertically
  bcs :+
    lda #0
: cmp #256*16 ; Limit to two screens of vertical scrolling
  bcc :+
  lda #256*16
: sta TargetY

  ; Move only a fraction of that
  ; TODO: probably limit speed like in NtS 1?
  lda TargetX
  sub ScrollX
  cmp #$8000
  ror
  cmp #$8000
  ror
  sta TargetX

  lda TargetY
  sub ScrollY
  cmp #$8000
  ror
  cmp #$8000
  ror
  sta TargetY

  ; Apply the scroll distance
  lda TargetX
  add ScrollX
  sta ScrollX

  lda TargetY
  add ScrollY
  sta ScrollY

  ; Is a column update required?
  lda ScrollX
  eor ScrollOldX
  and #$80
  beq NoUpdateColumn
    lda ScrollX
    cmp ScrollOldX
    jsr ToTiles
    bcs UpdateRight
  UpdateLeft:
    sub #2
    jsr UpdateColumn
    bra NoUpdateColumn
  UpdateRight:
    add #34
    jsr UpdateColumn
  NoUpdateColumn:

  ; Is a row update required?
  lda ScrollY
  eor ScrollOldY
  and #$80
  beq NoUpdateRow
    lda ScrollY
    cmp ScrollOldY
    jsr ToTiles
    bcs UpdateDown
  UpdateUp:
    dec a
    jsr UpdateRow
    bra NoUpdateRow
  UpdateDown:
    add #29
    jsr UpdateRow
  NoUpdateRow:

  rtl

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

.proc UpdateRow
Temp = 4
YPos = 6
  sta Temp

  ; Calculate the address of the row
  ; (Always starts at the leftmost column
  ; and extends all the way to the right.)
  and #31
  asl ; * 32 for rows
  asl
  asl
  asl
  asl
  ora #ForegroundBG>>1
  sta RowUpdateAddress

  ; Temporarily blank out the line
  ldx #0
  lda #1
: sta RowUpdateBuffer,x
  inx
  inx
  cpx #64*2
  bne :-

  ; Get level pointer address
  ; (Always starts at the leftmost column of the screen)
  lda ScrollX
  xba
  dec a
  jsl GetLevelColumnPtr

  ; Get index for the buffer
  lda ScrollX
  xba
  dec a
  asl
  asl
  and #(64*2)-1
  tax

  ; Use the Y scroll position in blocks
  lda Temp
  and #<~1
  tay

  ; Generate the top or the bottom as needed
  lda Temp
  lsr
  bcs :+
  jsl RenderLevelRowTop
  rts
: jsl RenderLevelRowBottom
  rts
.endproc

.proc UpdateColumn
Temp = 4
YPos = 6
  sta Temp

  ; Calculate address of the column
  and #31
  ora #ForegroundBG>>1
  sta ColumnUpdateAddress

  ; Use the second screen if required
  lda Temp
  and #32
  beq :+
    lda #2048>>1
    tsb ColumnUpdateAddress
  :

  ; Get level pointer address
  lda Temp ; Get metatile count
  lsr
  jsl GetLevelColumnPtr

  ; Use the Y scroll position in blocks
  lda ScrollY
  xba
  and #LEVEL_HEIGHT-1
  asl
  tay

  ; Generate the top or bottom as needed
  lda Temp
  lsr
  bcs :+
  jsl RenderLevelColumnLeft
  rts
: jsl RenderLevelColumnRight
  rts
.endproc
