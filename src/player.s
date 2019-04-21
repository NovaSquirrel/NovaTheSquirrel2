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

.segment "ZEROPAGE"

.segment "Player"

.a16
.i16
.proc RunPlayer
  php
  phk
  plb

  jsr HandlePlayer
  jsr DrawPlayer

  plp
  rtl
.endproc

.a16
.i16
.proc HandlePlayer
cur_keys = JOY1CUR
  lda cur_keys
  and #KEY_RIGHT
  beq :+
    lda PlayerPX
    add #16*4
    sta PlayerPX
  :

  lda cur_keys
  and #KEY_LEFT
  beq :+
    lda PlayerPX
    sub #16*4
    sta PlayerPX
    bcs :+
      stz PlayerPX
  :

  lda cur_keys
  and #KEY_UP
  beq :+
    lda PlayerPY
    sub #16*4
    sta PlayerPY
    bcs :+
      stz PlayerPY
  :

  lda cur_keys
  and #KEY_DOWN
  beq :+
    lda PlayerPY
    add #16*4
    sta PlayerPY
  :


  setaxy16
  rts
.endproc

.a16
.i16
.proc DrawPlayer
OAM_XPOS = OAM+0
OAM_YPOS = OAM+1
OAM_ATTR = OAM+2
OAM_TILE = OAM+3
  ldx OamPtr

  stx OamPtr
  rts
.endproc
