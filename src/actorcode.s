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

; -------------------------------------

.a16
.i16
.export DrawBurger
.proc DrawBurger
  rtl
.endproc

.a16
.i16
.export RunBurger
.proc RunBurger
  rtl
.endproc

.a16
.i16
.export DrawCannonH
.proc DrawCannonH
  rtl
.endproc

.a16
.i16
.export DrawCannonV
.proc DrawCannonV
  rtl
.endproc

.a16
.i16
.export DrawCheckpoint
.proc DrawCheckpoint
  rtl
.endproc

.a16
.i16
.export RunCheckpoint
.proc RunCheckpoint
  rtl
.endproc

.a16
.i16
.export DrawMovingPlatform
.proc DrawMovingPlatform
  rtl
.endproc

.a16
.i16
.export RunMovingPlatformH
.proc RunMovingPlatformH
  rtl
.endproc

.a16
.i16
.export RunMovingPlatformLine
.proc RunMovingPlatformLine
  rtl
.endproc

.a16
.i16
.export RunMovingPlatformPush
.proc RunMovingPlatformPush
  rtl
.endproc

.a16
.i16
.export DrawOwl
.proc DrawOwl
  rtl
.endproc

.a16
.i16
.export RunOwl
.proc RunOwl
  rtl
.endproc

.a16
.i16
.export DrawPlodder
.proc DrawPlodder
  rtl
.endproc

.a16
.i16
.export RunPlodder
.proc RunPlodder
  rtl
.endproc

.a16
.i16
.export DrawSneaker
.proc DrawSneaker
  rtl
.endproc

.a16
.i16
.export RunSneaker
.proc RunSneaker
  rtl
.endproc

.a16
.i16
.export RunAnyCannonH
.proc RunAnyCannonH
  rtl
.endproc

.a16
.i16
.export RunAnyCannonV
.proc RunAnyCannonV
  rtl
.endproc

.a16
.i16
.export RunBurgerCannonH
.proc RunBurgerCannonH
  rtl
.endproc

.a16
.i16
.export RunBurgerCannonV
.proc RunBurgerCannonV
  rtl
.endproc

; -------------------------------------
.a16
.i16
.export DrawPoof
.proc DrawPoof
  rtl
.endproc

.a16
.i16
.export RunPoof
.proc RunPoof
  rtl
.endproc
