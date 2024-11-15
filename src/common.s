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

.code

; Wait for a Vblank using WAI instead of a busy loop
.proc WaitVblank
  php
  seta8
loop1:
  bit VBLSTATUS  ; Wait for leaving previous vblank
  bmi loop1
loop2:
  wai
  bit VBLSTATUS  ; Wait for start of this vblank
  bpl loop2
  plp
  rtl
.endproc

; Random number generator
; From http://wiki.nesdev.com/w/index.php/Random_number_generator/Linear_feedback_shift_register_(advanced)#Overlapped_24_and_32_bit_LFSR
; output: A (random number)
.proc RandomByte
  phx ; Needed because setaxy8 will clear the high byte of X
  phy
  php
  setaxy8
  tdc ; Clear A, including the high byte

  seed = random1
  ; rotate the middle bytes left
  ldy seed+2 ; will move to seed+3 at the end
  lda seed+1
  sta seed+2
  ; compute seed+1 ($C5>>1 = %1100010)
  lda seed+3 ; original high byte
  lsr
  sta seed+1 ; reverse: 100011
  lsr
  lsr
  lsr
  lsr
  eor seed+1
  lsr
  eor seed+1
  eor seed+0 ; combine with original low byte
  sta seed+1
  ; compute seed+0 ($C5 = %11000101)
  lda seed+3 ; original high byte
  asl
  eor seed+3
  asl
  asl
  asl
  asl
  eor seed+3
  asl
  asl
  eor seed+3
  sty seed+3 ; finish rotating byte 2 into 3
  sta seed+0

  plp
  ply
  plx
  rtl
.endproc

; Randomly negates the input you give it
.a16
.proc VelocityLeftOrRight
  pha
  jsl RandomByte
  lsr
  bcc Right
Left:
  pla
  eor #$ffff
  ina
  rtl
Right:
  pla
  rtl
.endproc

.a16
.proc FadeIn
  php

  seta8
  lda #$1
: pha
  jsl WaitVblank
  pla
  sta PPUBRIGHT
  ina
  ina
  cmp #$0f+2
  bne :-

  plp
  rtl
.endproc

.a16
.proc FadeOut
  php

  seta8
  lda #$11
: pha
  jsl WaitVblank
  pla
  dea
  dea
  sta PPUBRIGHT
  bpl :-
  lda #FORCEBLANK
  sta PPUBRIGHT

  plp
  rtl
.endproc

.proc WaitKeysReady
  php
  seta8
  ; Wait for the controller to be ready
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait
  seta16

  ; -----------------------------------

  lda keydown
  sta keylast
  lda JOY1CUR
  sta keydown
  lda keylast
  eor #$ffff
  and keydown
  sta keynew
  stz OamPtr
  plp
  rtl
.endproc

; Quickly clears a section of WRAM
; Inputs: X (address), Y (size)
.i16
.proc MemClear
  php
  seta8
  stz WMADDH ; high bit of WRAM address
UseHighHalf:
  stx WMADDL ; WRAM address, bottom 16 bits
  sty DMALEN

  ldx #DMAMODE_RAMFILL
ZeroSource:
  stx DMAMODE

  ldx #.loword(ZeroSource+1)
  stx DMAADDR
  lda #^MemClear
  sta DMAADDRBANK

  lda #$01
  sta COPYSTART
  plp
  rtl
.endproc

; Quickly clears a section of the second 64KB of RAM
; Inputs: X (address), Y (size)
.i16
.a16
.proc MemClear7F
  php
  seta8
  lda #1
  sta WMADDH
  bra MemClear::UseHighHalf
.endproc

.export KeyRepeat
.proc KeyRepeat
  php
  seta8
  lda keydown+1
  beq NoAutorepeat
  cmp keylast+1
  bne NoAutorepeat
  inc AutoRepeatTimer
  lda AutoRepeatTimer
  cmp #12
  bcc SkipNoAutorepeat

  lda retraces
  and #3
  bne :+
    lda keydown+1
    and #>(KEY_LEFT|KEY_RIGHT|KEY_UP|KEY_DOWN)
    sta keynew+1
  :

  ; Keep it from going up to 255 and resetting
  dec AutoRepeatTimer
  bne SkipNoAutorepeat
NoAutorepeat:
  stz AutoRepeatTimer
SkipNoAutorepeat:
  plp
  rtl
.endproc
