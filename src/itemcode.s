; Super Princess Engine
; Copyright (C) 2020 NovaSquirrel
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

.segment "C_Items"


.export InventoryHasItem, InventoryGiveItem, InventoryTakeItem

; Input: A (item number)
; Output: Carry (set if item was found), Y (item index)
.i16
.proc InventoryHasItem
  php
  seta8
  ldy #InventoryEnd-YourInventory-2
: cmp YourInventory,y
  beq Found
  dey
  dey
  bpl :-
NotFound:
  plp
  clc
  rtl
Found:
  plp
  sec
  rtl
.endproc

.a16
.i16
.proc InventoryGiveItem
  php
  seta8
  jsl InventoryHasItem
  bcs AlreadyHas

  ; Uh oh, we have to find a slot to put it in now
  sta 0 ; Save the item number
  tdc   ; Clear all of the accumulator
  lda 0 ; Reload the bottom byte of the accumulator
  tax
  .import ItemFlags
  lda f:ItemFlags,x
  bmi LevelItem

; Regular items go in the first inventory
RegularItem:
  ldy #0
: lda YourInventory,y
  beq FoundSlot
  iny
  iny
  cpy #InventoryLen*2
  bne :-
  bra TooMuch

; Level items go in the second inventory
LevelItem:
  ldy #InventoryLen*2
: lda YourInventory,y
  beq FoundSlot
  iny
  iny
  cpy #InventoryLen*2+InventoryLen*2
  bne :-
  bra TooMuch

.a8
FoundSlot:
  lda 0
  sta YourInventory+0,y ; Item type
  lda #1
  sta YourInventory+1,y ; Item count
  plp
  sec
  rtl

.a8
AlreadyHas:
  lda YourInventory+1,y
  cmp #99
  bcs TooMuch
  ina
  sta YourInventory+1,y 

  ; Success
  plp
  sec
  rtl

.a8
TooMuch:
  plp
  clc
  rtl
.endproc

.a16
.i16
.proc InventoryTakeItem
  jsl InventoryHasItem
  bcs :+
    ; If carry clear, fail and return a failure to the caller
    rtl
  :
  php
  seta8
  ; Decrease item count
  lda YourInventory+1,y
  dea
  sta YourInventory+1,y
  bne NotZero
    ; Store the new item count (zero) to the item type too
    sta YourInventory+0,y
  NotZero:

  plp
  sec ; Success
  rtl
.endproc


; A = item type
; Y = item index in inventory, probably? Indexed from YourInventory
.a16
.i16
.export RunItemRoutine
.proc RunItemRoutine
  php ; Save register size
  phb
  ; Use this bank instead
  phk
  plb

  seta16
  and #255
  asl
  tax
  .import ItemRun
  lda f:ItemRun,x
  beq NoRoutine
  jsr Call

  plb
  plp ; Restore register size
  rtl

; Jump using RTS
Call:
  pha
  seta8
  rts

NoRoutine:
  plb
  plp
  rtl
.endproc

.a8
.i16
.export ItemPizzaSlice
.proc ItemPizzaSlice
  rts
.endproc

.a8
.i16
.export ItemBerry
.proc ItemBerry
  rts
.endproc

.a8
.i16
.export ItemWatermelon
.proc ItemWatermelon
  rts
.endproc

.a8
.i16
.export ItemStrawberry
.proc ItemStrawberry
  rts
.endproc

.a8
.i16
.proc ChangeAbilityFromItem
  sta PlayerAbility
  lda #1
  sta NeedAbilityChange
  stz TailAttackTimer
  stz OldTailAttackTimer
  seta16
  lda #ProjectileStart
: tax
  stz ActorType,x
  add #ActorSize
  cmp #ProjectileEnd
  bcc :-
  seta8
  rts
.endproc

.a8
.i16
.export ItemAbilityBurger
.proc ItemAbilityBurger
  lda #Ability::Burger
  bra ChangeAbilityFromItem
.endproc

.a8
.i16
.export ItemAbilityGlider
.proc ItemAbilityGlider
  lda #Ability::Glider
  bra ChangeAbilityFromItem
.endproc

.a8
.i16
.export ItemAbilityFishing
.proc ItemAbilityFishing
  lda #Ability::Fishing
  bra ChangeAbilityFromItem
  rts
.endproc

.a8
.i16
.export ItemAbilityRocket
.proc ItemAbilityRocket
  lda #Ability::Rocket
  bra ChangeAbilityFromItem
.endproc

.a8
.i16
.export ItemAbilityBubble
.proc ItemAbilityBubble
  lda #Ability::Bubble
  bra ChangeAbilityFromItem
.endproc

.a8
.i16
.export ItemAbilityIce
.proc ItemAbilityIce
  lda #Ability::Ice
  bra ChangeAbilityFromItem
.endproc

.a8
.i16
.export ItemAbilityFire
.proc ItemAbilityFire
  lda #Ability::Fire
  bra ChangeAbilityFromItem
.endproc

.a8
.i16
.export ItemAbilityWater
.proc ItemAbilityWater
  lda #Ability::Water
  bra ChangeAbilityFromItem
.endproc

.a8
.i16
.export ItemAbilityBombs
.proc ItemAbilityBombs
  lda #Ability::Bomb
  bra ChangeAbilityFromItem
.endproc

.a8
.i16
.export ItemAbilitySword
.proc ItemAbilitySword
  lda #Ability::Sword
  bra ChangeAbilityFromItem
.endproc
