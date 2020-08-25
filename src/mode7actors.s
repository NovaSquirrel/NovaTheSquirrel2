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
.include "m7blockenum.s"
.smart
.import Mode7LevelMap, Mode7LevelMapBelow, Mode7DynamicTileBuffer, Mode7DynamicTileUsed

.segment "Mode7Game"
ActorM7DynamicSlot = ActorIndexInLevel ; Reuse this
NUM_M7_ACTORS = 8

; Finds a dynamic sprite slot and allocates it
; A = Index into Mode7DynamicTileBuffer to use
; Carry = success
.a16
.i16
.proc Mode7AllocateDynamicSlot
  phx
  seta8
  ; Look for a slot
  ldx #7
: lda Mode7DynamicTileUsed,x
  beq Found
  dex
  bpl :-
  seta16
  plx
  clc
  rts
Found:
  inc Mode7DynamicTileUsed,x
  seta16
  ; A = X * 256 (four tiles)
  txa
  xba
  plx
  sec
  rts
.endproc


.a16
.i16
; A = Actor to create
; X = X coordinate, 12.4 format
; Y = Y coordinate, 12.4 format
.export Mode7CreateActor
.proc Mode7CreateActor
  sta 0
  stx 2
  sty 4

  jsl FindFreeActorX
  bcc Fail
  jsr Mode7AllocateDynamicSlot
  bcc Fail
Success:
  sta ActorM7DynamicSlot,x
  lda 0
  sta ActorType,x
  lda 2
  and #$fff0
  sta ActorPX,x
  lda 4
  and #$fff0
  sta ActorPY,x
  sec
  rts
Fail:
  rts
.endproc

.a16
.i16
.proc Mode7RemoveActor
  stz ActorType,x
  lda ActorM7DynamicSlot,x
.endproc
; Inline tail call to Mode7FreeDynamicSlot

; Frees the slot index in A
.a16
.i16
.proc Mode7FreeDynamicSlot
  xba
  and #255
  tax
  seta8
  stz Mode7DynamicTileUsed,x
  seta16
  rts
.endproc

.a16
.i16
.export Mode7RunActors
.proc Mode7RunActors
  ldx #ActorStart
Loop:
  lda ActorType,x
  beq :+
    jsr Call
  :
  txa
  add #ActorSize
  tax
  cpx #ActorStart+ActorSize*NUM_M7_ACTORS
  bne Loop
  rts
Call:
  tay
  lda Mode7ActorTable,y
  pha
  rts
.endproc

Mode7ActorTable:
  .raddr 0
  .raddr M7FlyingArrow

.proc M7FlyingArrow
  phx
  lda ActorM7DynamicSlot,x
  tax
  lda #255
  sta f:Mode7DynamicTileBuffer,x
  sta f:Mode7DynamicTileBuffer+2,x
  sta f:Mode7DynamicTileBuffer+4,x
  sta f:Mode7DynamicTileBuffer+6,x
  sta f:Mode7DynamicTileBuffer+8,x
  sta f:Mode7DynamicTileBuffer+10,x
  sta f:Mode7DynamicTileBuffer+12,x
  sta f:Mode7DynamicTileBuffer+14,x
  sta f:Mode7DynamicTileBuffer+16,x
  plx
  rts
.endproc
