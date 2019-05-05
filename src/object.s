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
.import ObjectRun, ObjectDraw, ObjectFlags, ObjectWidth, ObjectHeight, ObjectBank
.smart

.segment "ActorData"

.export RunAllObjects
.proc RunAllObjects
  setaxy16

  ; Load X with the actual pointer
  ldx #ObjectStart
Loop:
  lda ObjectType,x
  beq SkipEntity   ; Skip if empty

  ; Call the run and draw routines
  pha
  jsl CallRun
  pla
  jsl CallDraw

  ; TODO: call the opt-in routines

SkipEntity:

  ; Next entity
  txa
  add #ObjectSize
  tax
  cpx #ObjectEnd
  bne Loop
  rtl

; Call the object run code
CallRun:
  phx
  tax
  seta8
  lda f:ObjectBank+0,x
  pha
  plb ; Use code bank as data bank
  sta 2
  seta16
  lda f:ObjectRun,x
  sta 0
  plx

  ; Jump to it and return with an RTL
  jml [0]

; Call the object draw code
CallDraw:
  phx
  tax
  seta8
  lda f:ObjectBank+1,x
  pha
  plb ; Use code bank as data bank
  sta 2
  seta16
  lda f:ObjectDraw,x
  sta 0
  plx

  ; Jump to it and return with an RTL
  jml [0]
.endproc



.a16
.i16
.proc FindFreeObjectX
  ldx #ObjectStart
Loop:
  lda ObjectType,x
  beq Found
  txa
  add #ObjectSize
  tax
  cpx #ObjectEnd
  bne Loop
  clc
  rtl
Found:
  lda #$ffff
  sta ObjectIndexInLevel,x
  sec
  rtl
.endproc

.a16
.i16
.proc FindFreeObjectY
  ldy #ObjectStart
Loop:
  lda ObjectType,y
  beq Found
  tya
  add #ObjectSize
  tay
  cpy #ObjectEnd
  bne Loop
  clc
  rtl
Found:
  lda #$ffff
  sta ObjectIndexInLevel,y
  sec
  rtl
.endproc


; Just flip the LSB of ObjectDirection
.export ObjectTurnAround
.a16
.proc ObjectTurnAround
  ; No harm in using it as a 16-bit value here, it's just written back
  lda ObjectDirection,x ; a 0 marks an empty slot
  eor #1
  sta ObjectDirection,x
  rtl
.endproc

.export ObjectLookAtPlayer
.a16
.proc ObjectLookAtPlayer
  lda ObjectPX,x
  cmp PlayerPX

  ; No harm in using it as a 16-bit value here, it's just written back
  lda ObjectDirection,x
  and #$fffe
  adc #0
  sta ObjectDirection,x

  rtl
.endproc

; Causes the object to hover in place
; takes over ObjectVarC and uses it for hover position
.export ObjectHover
.a16
.proc ObjectHover
  phb
  phk ; To access the table at the end
  plb
  ldy ObjectVarC,x

  seta8
  lda Wavy,y
  sex
  sta 0

  lda ObjectPY+0,x
  add Wavy,y
  sta ObjectPY+0,x
  lda ObjectPY+1,x
  adc 0
  sta ObjectPY+1,x

  inc ObjectVarC,x
  lda ObjectVarC,x
  and #63
  sta ObjectVarC,x
  seta16

  plb
  rtl
Wavy:
  .byt 0, 0, 1, 2, 3, 3, 4
  .byt 5, 5, 6, 6, 7, 7, 7
  .byt 7, 7, 7, 7, 7, 7, 7
  .byt 6, 6, 5, 5, 4, 3, 3
  .byt 2, 1, 0, 0

  .byt <-0, <-0, <-1, <-2, <-3, <-3, <-4
  .byt <-5, <-5, <-6, <-6, <-7, <-7, <-7
  .byt <-7, <-7, <-7, <-7, <-7, <-7, <-7
  .byt <-6, <-6, <-5, <-5, <-4, <-3, <-3
  .byt <-2, <-1, <-0, <-0
.endproc

; Limits horizontal speed to 3 pixels/frame
; Currently private for LakituMovement
.a16
.proc ObjectSpeedLimit
  ; Limit speed
  lda ObjectVX,x
  php
  bpl :+
    eor #$ffff
    inc a
  :

  cmp #$0030
  bcs :+
    lda #$0030
  :

  plp
  bpl :+
    eor #$ffff
    inc a
  :
  sta ObjectVX,x
  rts
.endproc

; Causes the enemy to move back and forth horizontally,
; seeking the player
.export LakituMovement
.a16
.proc LakituMovement
  jsl ObjectApplyVelocity

;  lda ObjectPXL,x
;  add #$80
;  lda ObjectPXH,x
;  adc #0
;  ldy ObjectPYH,x
;  jsr GetLevelColumnPtr
;  cmp #Metatiles::ENEMY_BARRIER
;  bne :+
;    neg16x ObjectVXL, ObjectVXH
;    rts
;  :

  ; Stop if stunned
  lda ObjectState,x ; Ignore high byte
  and #255
  beq :+
    stz ObjectVX,x
  :

  stz ObjectVY,x ; the "bounce" effect gives vertical velocity, so don't let it

  ; Change direction to face the player
  jsl ObjectLookAtPlayer

  ; Only speed up if not around player
  lda ObjectPX,x
  sub PlayerPX
  absw
  cmp #$300
  bcc :+
  lda #4
  jsl ObjectNegIfLeft
  add ObjectVX,x
  sta ObjectVX,x
  jsr ObjectSpeedLimit
:

  rtl
.endproc

; Takes a speed in the accumulator, and negates it if object facing left
.a16
.export ObjectNegIfLeft
.proc ObjectNegIfLeft
  pha
  lda ObjectDirection,x ; Ignore high byte
  lsr
  bcs Left
Right:
  pla
  rtl
Left:
  pla
  negw
  rtl
.endproc

.proc ObjectApplyVelocity
  lda ObjectPX,x
  add ObjectVX,x
  sta ObjectPX,x

  lda ObjectPY,x
  add ObjectVY,x
  sta ObjectPY,x
  rtl
.endproc
