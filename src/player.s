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
.import PlayerGraphics
.proc PlayerFrameUpload
  php
  seta16

  ; Set DMA parameters  
  lda #DMAMODE_PPUDATA
  sta DMAMODE+$00
  sta DMAMODE+$10

  lda PlayerFrame
  and #255         ; Zero extend
  xba              ; *256
  asl              ; *512
  ora #$8000
  sta DMAADDR+$00
  ora #256
  sta DMAADDR+$10

  lda #32*8 ; 8 tiles for each DMA
  sta DMALEN+$00
  sta DMALEN+$10

  lda #($8000)>>1
  sta PPUADDR
  seta8
  lda #^PlayerGraphics
  sta DMAADDRBANK+$00
  sta DMAADDRBANK+$10

  lda #%00000001
  sta COPYSTART

  ; Bottom row -------------------
  seta16
  lda #($8200)>>1
  sta PPUADDR
  seta8
  lda #%00000010
  sta COPYSTART

  plp
  rtl
.endproc

.a16
.i16
.proc RunPlayer
  php
  phk
  plb

  jsr HandlePlayer
  jsr DrawPlayer

  ; Automatically cycle through the walk animation

  seta8
  stz PlayerFrame

  lda keydown+1
  and #(KEY_LEFT|KEY_RIGHT)>>8
  beq :+
    lda retraces
    lsr
    lsr
    and #7
    inc a
    sta PlayerFrame 
  :

  plp
  rtl
.endproc

NOVA_WALK_SPEED = 2
NOVA_RUN_SPEED = 4
;AccelSpeeds: .byt 2,        4
;DecelSpeeds: .byt 4,        8

.a16
.i16
.proc HandlePlayer
Temp = 2
MaxSpeedLeft = 10
MaxSpeedRight = 12

  ; Horizontal movement

  ; Calculate max speed from whether they're running or not
  ; (Updated only when on the ground)
  seta8
  lda PlayerWasRunning ; nonzero = B button, only updated when on ground
  seta16
  beq :+
    lda #.loword(-(NOVA_RUN_SPEED*16))
    sta MaxSpeedLeft
    lda #NOVA_RUN_SPEED*16
    sta MaxSpeedRight
    bne NotWalkSpeed
: lda #.loword(-(NOVA_WALK_SPEED*16))
  sta MaxSpeedLeft
  lda #NOVA_WALK_SPEED*16
  sta MaxSpeedRight
NotWalkSpeed:


  ; Handle left and right
  lda keydown
  and #KEY_LEFT
  beq NotLeft
    seta8
    lda #1
    sta PlayerDir
    seta16
    lda PlayerVX
    cmp MaxSpeedLeft ; can be either run speed or walk speed
    beq NotLeft
    cmp #.lobyte(-NOVA_RUN_SPEED*16)
    beq NotLeft
    sub #2 ; Acceleration speed
    sta PlayerVX
NotLeft:

  lda keydown
  and #KEY_RIGHT
  beq NotRight
    seta8
    stz PlayerDir
    seta16
    lda PlayerVX
    cmp MaxSpeedRight ; can be either run speed or walk speed
    beq NotRight
    cmp #NOVA_RUN_SPEED*16
    beq NotRight

    add #2 ; Acceleration speed
    sta PlayerVX
NotRight:
NotWalk:

  ; Decelerate
  lda #4
  sta Temp
  ; Adjust the deceleration speed if you're trying to turn around
  lda keydown
  and #KEY_LEFT
  beq :+
    lda PlayerVX
    bmi IsMoving
    lsr Temp
  :
  lda keydown
  and #KEY_RIGHT
  beq :+
    lda PlayerVX
    beq Stopped
    bpl IsMoving
    lsr Temp
  :
  lda PlayerVX
  beq Stopped
    ; If negative, make positive
    php ; Save if it was negative
    bpl :+
      eor #$ffff
      ina
    :

    sub Temp ; Deceleration speed
    bpl :+
      lda #0
    :

    ; If negative, make negative again
    plp
    bpl :+
      eor #$ffff
      ina
    :

    sta PlayerVX
Stopped:
IsMoving:

  ; Apply speed
  lda PlayerPX
  add PlayerVX
  sta PlayerPX

  ; -------------------

  ; Vertical movement
  lda PlayerVY
  bmi GravityAddOK
  cmp #$60
  bcs SkipGravity
GravityAddOK:
  add #4
  sta PlayerVY
SkipGravity:
  add PlayerPY ; Apply the vertical speed
  sta PlayerPY
SkipApplyGravity:



  ldy PlayerPY
  lda PlayerPX
  jsl GetLevelPtrXY
  asl
  tax
  lda f:BlockFlags,x

  bpl :+
    stz PlayerVY
    lda PlayerPY
    and #$ff00
    sta PlayerPY
  :


  rts
.endproc

.a16
.i16
.proc DrawPlayer
OAM_XPOS = OAM+0
OAM_YPOS = OAM+1
OAM_TILE = OAM+2
OAM_ATTR = OAM+3
  ldx OamPtr

  ; X coordinate to pixels
  lda PlayerPX
  sub ScrollX
  lsr
  lsr
  lsr
  lsr
  sta 0

  ; Y coordinate to pixels
  lda PlayerPY
  sub ScrollY
  lsr
  lsr
  lsr
  lsr
  sta 2

  lda #$0200  ; Use 16x16 sprites
  sta OAMHI+(4*0),x
  sta OAMHI+(4*1),x
  sta OAMHI+(4*2),x
  sta OAMHI+(4*3),x

  seta8
  lda 0
  sta OAM_XPOS+(4*1),x
  sta OAM_XPOS+(4*3),x
  sub #16
  sta OAM_XPOS+(4*0),x
  sta OAM_XPOS+(4*2),x

  lda 2
  sub #16
  sta OAM_YPOS+(4*2),x
  sta OAM_YPOS+(4*3),x
  sub #16
  sta OAM_YPOS+(4*0),x
  sta OAM_YPOS+(4*1),x


  ; Tile numbers
  lda #0
  sta OAM_TILE+(4*0),x
  lda #2
  sta OAM_TILE+(4*1),x
  lda #4
  sta OAM_TILE+(4*2),x
  lda #6
  sta OAM_TILE+(4*3),x

  ; Background flip
  lda PlayerDir
  beq :+
    ; Rewrite tile numbers
    lda #2
    sta OAM_TILE+(4*0),x
    lda #0
    sta OAM_TILE+(4*1),x
    lda #6
    sta OAM_TILE+(4*2),x
    lda #4
    sta OAM_TILE+(4*3),x

    lda #%01000000
  :
  ora #%00100000 ; priority
  sta OAM_ATTR+(4*0),x
  sta OAM_ATTR+(4*1),x
  sta OAM_ATTR+(4*2),x
  sta OAM_ATTR+(4*3),x
 
  seta16
  ; Four sprites
  txa
  clc
  adc #4*4
  sta OamPtr
  rts
.endproc
