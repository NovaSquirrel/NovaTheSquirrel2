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

.segment "C_Player"

.a16
.i16
.proc AdjustCamera
ScrollOldX = OldScrollX
ScrollOldY = OldScrollY
TargetX = 4
TargetY = 6

  ; If the player is below the target, player Y position is the new target
  lda PlayerPY
  cmp PlayerCameraTargetY
  bcc :+
    sta PlayerCameraTargetY
  :

  ; Allow disabling the feature ahead
  lda CameraDisableNudgeAbove
  lsr
  bcs :+
  ; Start adjusting the camera target up if the player is too high up on the screen
  ; (which will happen if they use a spring)
  lda PlayerDrawY
  and #255
  cmp #64
  bcs :+
    lda PlayerCameraTargetY
    sub #64
    sta PlayerCameraTargetY
  :

  ; Save the old scroll positions
  lda ScrollX
  sta ScrollOldX
  lda ScrollY
  sta ScrollOldY

  ; Try to push the camera back if the player is going faster?
;  lda PlayerVX
;  asl ; *2
;  asl ; *4
;  asl ; *8
;  add PlayerVX ; *9
;  asl ; *18
;  add PlayerPX

  ; Find the target scroll positions
  lda PlayerPX
  sub #8*256
  bcs :+
    lda #0
: cmp ScrollXLimit
  bcc :+
  lda ScrollXLimit
: sta TargetX

  ; For a horizontal level, going off of the top of the screen should not target upward
  bit VerticalLevelFlag-1
  bmi :+
  lda PlayerCameraTargetY
  bpl :+
    stz PlayerCameraTargetY
  :

  lda PlayerCameraTargetY
  sub #8*256  ; Pull back to center vertically
  bcs :+
    lda #0
: cmp ScrollYLimit
  bcc :+
  lda ScrollYLimit
: sta TargetY


  ; Move only a fraction of that
  lda TargetY
  sub ScrollY
  php
  bpl :+
    neg
  :

  ; Calculate how fast to scroll vertically
  pha
  lsr ; / 128
  lsr
  lsr
  lsr
  lsr
  lsr
  lsr
  and #255
  rsb #20
  beq @DontDivideByZero
  bpl :+
@DontDivideByZero:
    lda #1
  :
  tay
@DoDivision:
  pla
  sta CPUNUM
  seta8
  tya
  sta CPUDEN
  ; Wait 16 clock cycles
  seta16
  ; ---
  ; Do the X calculation while I'm waiting
  lda TargetX
  sub ScrollX
  cmp #$8000
  ror
  cmp #$8000
  ror
  cmp #$8000
  ror
  sta TargetX
  ; ---
  lda CPUQUOT
  plp
  bpl :+
    neg
  :
  sta TargetY


  .if 0
  cmp #$8000
  ror
  cmp #$8000
  ror
  cmp #$8000
  ror
  cmp #$8000
  ror
  adc #0
  sta TargetY
  .endif

  ; Apply the scroll distance
  lda TargetX
  jsr SpeedLimit
  add ScrollX
  sta ScrollX

  lda TargetY
  jsr SpeedLimit
  add ScrollY
  sta ScrollY

  ; If vertical scrolling is not enabled, lock to the bottom of the level
  lda VerticalScrollEnabled
  lsr
  bcs :+
    lda ScrollYLimit
    sta ScrollY
  :

  ; -----------------------------------

  bit VerticalLevelFlag-1
  bmi IsVerticalLevel

; .---------------------------------------
; |SCROLL BARRIERS (left)
; '---------------------------------------

  lda ScrollX
  eor ScrollOldX
  and #%00010000 << 8
  beq NoScreenChangeLeft
  lda ScrollX
  and #$ff
  cmp #$80
  bcc NoScreenChangeLeft
  ; See if we're scrolling past a barrier
  lda ScrollOldX
  xba
  lsr
  lsr
  lsr
  lsr
  and #15
  tay
  lda ScreenFlags,y
  lsr
  bcc NoScreenChangeLeft
  lda ScrollOldX
  and #$f000
  sta ScrollX
NoScreenChangeLeft:

; .---------------------------------------
; | SCROLL BARRIERS (right)
; '---------------------------------------  
  lda ScrollX
  bit #$0f00
  bne NoScreenChangeRight
  bit #$00f0
  beq NoScreenChangeRight
  ; Check the next screen and see if it's got a barrier
  xba
  lsr
  lsr
  lsr
  lsr
  and #15
  tay
  lda ScreenFlags+1,y
  lsr
  bcc NoScreenChangeRight
  seta8
  lda #$0f
  sta ScrollX+0
  seta16
NoScreenChangeRight:

  IsVerticalLevel:

  ; -----------------------------------


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
    sub #2             ; Two tiles to the left
    jsr UpdateColumn
    bra NoUpdateColumn
  UpdateRight:
    add #34            ; Two tiles past the end of the screen on the right
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
    jsr UpdateRow
    bra NoUpdateRow
  UpdateDown:
    add #29            ; Just past the screen height
    jsr UpdateRow
  NoUpdateRow:

  rtl

; Convert a 12.4 scroll position to a number of tiles
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

SpeedLimit:
  ; Take absolute value
  php
  bpl :+
    eor #$ffff
    inc a
  :
  ; Cap it at 8 pixels
  cmp #$0080
  bcc :+
    lda #$0080
  :
  ; Undo absolute value
  plp
  bpl :+
    eor #$ffff
    inc a
  :
  rts
.endproc

.a16
.proc UpdateRow
Temp = 4
YPos = 6
  sta Temp

  ; Calculate the address of the row
  ; (Always starts at the leftmost column
  ; and extends all the way to the right.)
  and #31
  asl ; Multiply by 32, the number of words per row in a screen
  asl
  asl
  asl
  asl
  ora #ForegroundBG>>1
  sta RowUpdateAddress

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
  tay

  ; Calculate an index to read level data with
  lda Temp
  and #.loword(~1)
  ora LevelBlockPtr
  tax

  ; Generate the top or the bottom as needed
  lda Temp
  lsr
  bcs :+
  jsl RenderLevelRowTop
  rts
:
  
  ; If it's the bottom row, also scan for actors to introduce into the level
  lda Temp
  pha ; Don't rely on this routine not overwriting this variable
  jsl RenderLevelRowBottom
  pla

  bit VerticalLevelFlag-1
  jmi ScanForActorsToMake
  rts
.endproc

.a16
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

  ; Calculate an index to read level data with
  lda ScrollY
  xba
  asl
  and LevelColumnMask
  ora LevelBlockPtr
  tax

  ; Generate the left or right as needed
  lda Temp
  lsr
  bcc :+
  jsl RenderLevelColumnRight
  rts
:

  ; If it's the left column, also scan for actors to introduce into the level
  lda Temp
  pha ; Don't rely on this routine not overwriting this variable
  jsl RenderLevelColumnLeft
  pla
  bit VerticalLevelFlag-1
  bmi Exit
::ScanForActorsToMake:
CheckColumn = Temp + 0
CheckScreen = Temp + 1
  lsr
  setaxy8
  sta CheckColumn
  and #$f0
  sta CheckScreen
  lsr
  lsr
  lsr
  lsr ; Screen number
  tay
  lda FirstActorOnScreen,y
  cmp #255 ; No actors on screen
  beq Exit

  setaxy16
  and #$00ff ; Clear high byte
  asl        ; Multiply by 4
  asl
  tay

  seta8
Loop:
  lda [LevelActorPointer],y
  cmp #255
  beq Exit ; Exit since the actor data is over
  pha
  and #$f0
  cmp CheckScreen
  bne Exit_PLA ; Exit since the actor data is on a different screen now
  pla
  cmp CheckColumn
  bne :+
    jsl TryMakeActor
  :
  ; Next actor
  iny
  iny
  iny
  iny
  bra Loop

Exit_PLA:
  pla
Exit:
  setaxy16
  rts 
.endproc

; Try to make an actor from the level actor list
; inputs: Y (actor index)
; preserves Y
.a8
.i16
.export TryMakeActor
.proc TryMakeActor
Index = 0
  sty Index
  phy
  php
  setaxy16
  
  ; Ensure the actor has not already been spawned
  ldx #ActorStart
CheckExistsLoop:
  lda ActorType,x ; Ignore ActorIndexInLevel if there is no Actor there
  beq :+
    lda ActorIndexInLevel,x ; Already exists
    cmp Index
    beq Exit
  :
  ; Next actor
  txa
  add #ActorSize
  tax
  cpx #ActorEnd
  bne CheckExistsLoop

  ; -----------------------------------
  ; Spawn in the actor
  jsl FindFreeActorX
  bcc Exit

  ; X now points at a free slot
  stz ActorVX,x
  stz ActorVY,x
  stz ActorVarB,x
  stz ActorVarC,x
  stz ActorTimer,x
  stz ActorOnScreen,x ; also ActorDamage
  tya
  sta ActorIndexInLevel,x

  ; Actor list organized as XXXXXXXX D..YYYYY tttttttt abcdTTTT
  seta8
  lda [LevelActorPointer],y ; X position
  sta ActorPX+1,x
  lda #$80                   ; Center it
  sta ActorPX+0,x
  iny
  lda [LevelActorPointer],y ; Y position, and two unused bits
  asl
  php
  lsr
  and #31
  sta ActorPY+1,x
  lda #$ff
  sta ActorPY+0,x

  ; Swap X and Y if it's a vertical level
  lda VerticalLevelFlag
  beq @Horizontal
  lda ActorPX+1,x
  pha
  lda ActorPY+1,x
  sta ActorPX+1,x
  pla
  sta ActorPY+1,x
@Horizontal:

  ; Copy the most significant bit of the Y position to the least significant bit of the direction
  plp
  .a8 ; plp restores it to 8-bit accumulator
  tdc ; Clear accumulator
  rol
  sta ActorDirection,x
  iny

  seta16
  lda [LevelActorPointer],y ; Actor type and flags
  and #$fff
  asl
  sta ActorType,x
  .import InitActorX
  jsl InitActorX

  ; Store the flags into Actor generic variable A
  lda [LevelActorPointer],y
  xba
  lsr
  lsr
  lsr
  lsr
  and #15
  sta ActorVarA,x

Exit:
  plp
  ply
  rtl
.endproc

