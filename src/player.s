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
.include "blockenum.s"
.smart

.import BlockRunInteractionAbove, BlockRunInteractionBelow
.import BlockRunInteractionSide,  BlockRunInteractionInsideHead
.import BlockRunInteractionInsideBody

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

NOVA_WALK_SPEED = 2
NOVA_RUN_SPEED = 4
;AccelSpeeds: .byt 2,        4
;DecelSpeeds: .byt 4,        8

.a16
.i16
.proc RunPlayer
Temp = 2
SideXPos = 8
BottomCmp = 8
MaxSpeedLeft = 10
MaxSpeedRight = 12
  phk
  plb

  ; Horizontal movement

  ; Calculate max speed from whether they're running or not
  ; (Updated only when on the ground)
  seta8
  stz PlayerOnGround
  countdown JumpGracePeriod

  lda PlayerWasRunning ; nonzero = B button, only updated when on ground
  seta16
  beq :+
    lda #.loword(-(NOVA_RUN_SPEED*16)-1)
    sta MaxSpeedLeft
    lda #NOVA_RUN_SPEED*16
    sta MaxSpeedRight
    bra NotWalkSpeed
: lda #.loword(-(NOVA_WALK_SPEED*16)-1)
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
    bpl :+
    cmp MaxSpeedLeft ; can be either run speed or walk speed
    bcc NotLeft
    cmp #.lobyte(-NOVA_RUN_SPEED*16-1)
    bcc NotLeft
:   sub #2 ; Acceleration speed
    sta PlayerVX
NotLeft:

  lda keydown
  and #KEY_RIGHT
  beq NotRight
    seta8
    stz PlayerDir
    seta16
    lda PlayerVX
    bmi :+
    cmp MaxSpeedRight ; can be either run speed or walk speed
    bcs NotRight
    cmp #NOVA_RUN_SPEED*16
    bcs NotRight
:   add #2 ; Acceleration speed
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

   ; Another deceleration check; apply if you're moving faster than the max speed
   lda PlayerVX
   php
   bpl :+
     eor #$ffff
     ina
   :
   cmp MaxSpeedRight
   beq NoFixWalkSpeed ; If at or less than the max speed, don't fix
   bcc NoFixWalkSpeed
   sub #4
NoFixWalkSpeed:
   plp
   bpl :+
     eor #$ffff
     ina
   :
   sta PlayerVX


  ; Apply speed
  lda PlayerPX
  add PlayerVX
  sta PlayerPX

  ; Boundary on the left
  lda PlayerPX
  cmp #16*16
  bcs :+
    lda #16*16
    sta PlayerPX
  :

  ; Check for moving into a wall
  lda PlayerPX
  add #3*16
  bit PlayerVX
  bpl :+
    sub #3*16+4*16 ; Subtract off the right and subtract again
  :
  sta SideXPos

  ; Left middle
  lda PlayerPY
  sub #12*16
  tay
  lda SideXPos
  jsr TrySideInteraction
  ; Right head
  lda PlayerPY
  sub #16*23 ;#16*16+14*16 ; Top of the head
  tay
  lda SideXPos
  jsr TrySideInteraction



  ; -------------------

  ; Slope interaction
  ; Move up a pixel
SlopeUnderFeet:
  lda PlayerPY
  sub #$10
  tay
  lda PlayerPX
  jsl GetLevelPtrXY
  jsr IsSlope
  bcc :+
    lda SlopeHeightTable,y
    beq SlopeAbove

    lda PlayerPY
    and #$ff00
    ora SlopeHeightTable,y
    sub #$10
    sta PlayerPY
    stz PlayerVY
  :
  bra SlopeEnd

SlopeAbove:
  dec LevelBlockPtr
  dec LevelBlockPtr
  lda [LevelBlockPtr]
  jsr IsSlope
  bcc :+
    lda PlayerPY
    sub #$0100
    and #$ff00
    ora SlopeHeightTable,y
    sub #$10
    sta PlayerPY

    stz PlayerVY
  :

SlopeEnd:

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


  ; Allow canceling a jump
  lda PlayerVY
  bpl :+
    seta8
    lda PlayerJumpCancel
    bne :+
    lda keydown+1
    and #(KEY_B>>8)
    bne :+
      lda PlayerJumpCancelLock
      bne :+
        inc PlayerJumpCancel

        ; Reduce the jump to a small upward boost
        ; (unless the upward movement is already less than that)
        seta16
        lda PlayerVY
        cmp #.loword(-$20)
        bcs :+
        lda #.loword(-$20)
        sta PlayerVY
  :

  ; Cancel the jump cancel
  seta8
  lda PlayerJumpCancel
  beq :+
    lda PlayerVY+1
    sta PlayerJumpCancel
  :
  seta16

  ; Collide with the ground
  ; (Determine if solid all must be set, or solid top)
  lda #$8000
  sta BottomCmp
  lda PlayerVY
  bmi :+
    seta8
    stz PlayerJumping
    seta16
    lda #$4000
    sta BottomCmp
  :

  lda PlayerVY
  bmi :+
  ; Left foot
  ldy PlayerPY
  lda PlayerPX
  sub #4*16
  jsr TryAboveInteraction
  ; Right foot
  ldy PlayerPY
  lda PlayerPX
  add #3*16
  jsr TryAboveInteraction
:

  seta8
  lda PlayerOnGround
  bne :+
  lda JumpGracePeriod
  beq :+
    seta16
    jsr OfferJumpFromGracePeriod
  :
  seta16


  ; Left above
  lda PlayerPY
  sub #16*16+14*16 ; Top of the head
  tay
;  phy
  lda PlayerPX
;  sub #4*16
  jsr TryBelowInteraction
  ; Right above
;  ply
;  lda PlayerPX
;  add #3*16
;  jsr TryBelowInteraction

  ; -------------------

  rtl

TryBelowInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionBelow

  lda BlockFlag
  bpl @NotSolid
    stz PlayerVY

    lda PlayerPY
    and #$ff00
    ora #14*16
    sta PlayerPY
  @NotSolid:
  rts


TryAboveInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionAbove
  ; Solid?
  lda BlockFlag
  cmp BottomCmp
  bcc :+
    stz PlayerVY
    lda #$00ff
    trb PlayerPY

    jsr OfferJump

    seta8
    inc PlayerOnGround

    ; Update run status
    lda keydown
    and #KEY_R|KEY_L
    sta PlayerWasRunning
    lda keydown+1
    and #KEY_Y>>8
    tsb PlayerWasRunning
    seta16
  :
  rts

TrySideInteraction:
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionSide
  ; Solid?
  lda BlockFlag
  bpl @NotSolid
    lda SideXPos
    cmp PlayerPX
    bcs :+
      lda PlayerPX
      sub PlayerVX ; Undo the horizontal movement
      and #$ff00   ; Snap to the block
      add #4*16    ; Add to the offset to press against the block
      sta PlayerPX
      stz PlayerVX ; Stop moving horizontally
      rts
    :

    lda PlayerPX
    sub PlayerVX  ; Undo the horizontal movement
    and #$ff00    ; Snap to the block
    add #12*16+12 ; Add the offset to press against the block
    sta PlayerPX
    stz PlayerVX  ; Stop moving horizontally
  @NotSolid:
  rts

.a16
IsSlope:
  cmp #Block::MedSlopeL_DL*2
  bcc :+
  cmp #Block::GradualSlopeR_U4*2+1
  bcs :+
  sub #Block::MedSlopeL_DL*2
  ; Now we have the block ID times 2

  ; Multiply by 16 to get the index into the slope table
  asl
  asl
  asl
  asl
  sta 0

  ; Select the column
  lda PlayerPX
  and #$f0 ; Get the pixels within a block
  lsr
  lsr
  lsr
  ora 0
  tay

  sec ; Success
  rts
: clc ; Failure
  rts
.endproc

.a16
OfferJump:
  seta8
  lda #7 ;JUMP_GRACE_PERIOD_LENGTH
  sta JumpGracePeriod
  seta16
OfferJumpFromGracePeriod:
  lda keynew
  and #KEY_B
  beq :+
    seta8
    ;stz PlayerOnLadder
    stz JumpGracePeriod
    inc PlayerJumping
    seta16
    lda #.loword(-$50)
    sta PlayerVY
  :
  rts


.a16
.i16
.proc DrawPlayer
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

  ; -----------------------------------

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
  setaxy16
  rtl
.endproc

.export SlopeHeightTable
.proc SlopeHeightTable
; MedSlopeL_DL
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; MedSlopeR_DR
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; GradualSlopeL_D1
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; GradualSlopeL_D2
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; GradualSlopeR_D3
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; GradualSlopeR_D4
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; SteepSlopeL_D
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; SteepSlopeR_D
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

;MedSlopeL_UL
.word $f0, $f0, $e0, $e0, $d0, $d0, $c0, $c0
.word $b0, $b0, $a0, $a0, $90, $90, $80, $80

;MedSlopeL_UR
.word $70, $70, $60, $60, $50, $50, $40, $40
.word $30, $30, $20, $20, $10, $10, $00, $00

;MedSlopeR_UL
.word $00, $00, $10, $10, $20, $20, $30, $30
.word $40, $40, $50, $50, $60, $60, $70, $70

;MedSlopeR_UR
.word $80, $80, $90, $90, $a0, $a0, $b0, $b0
.word $c0, $c0, $d0, $d0, $e0, $e0, $f0, $f0

;SteepSlopeL_U
.word $f0, $e0, $d0, $c0, $b0, $a0, $90, $80
.word $70, $60, $50, $40, $30, $20, $10, $00

;SteepSlopeR_U
.word $00, $10, $20, $30, $40, $50, $60, $70
.word $80, $90, $a0, $b0, $c0, $d0, $e0, $f0

;GradualSlopeL_U1
.word $f0, $f0, $f0, $f0, $e0, $e0, $e0, $e0
.word $d0, $d0, $d0, $d0, $c0, $c0, $c0, $c0

;GradualSlopeL_U2
.word $b0, $b0, $b0, $b0, $a0, $a0, $a0, $a0
.word $90, $90, $90, $90, $80, $80, $80, $80

;GradualSlopeL_U3
.word $70, $70, $70, $70, $60, $60, $60, $60
.word $50, $50, $50, $50, $40, $40, $40, $40

;GradualSlopeL_U4
.word $30, $30, $30, $30, $20, $20, $20, $20
.word $10, $10, $10, $10, $00, $00, $00, $00

;GradualSlopeR_U1
.word $00, $00, $00, $00, $10, $10, $10, $10
.word $20, $20, $20, $20, $30, $30, $30, $30

;GradualSlopeR_U2
.word $40, $40, $40, $40, $50, $50, $50, $50
.word $60, $60, $60, $60, $70, $70, $70, $70

;GradualSlopeR_U3
.word $80, $80, $80, $80, $90, $90, $90, $90
.word $a0, $a0, $a0, $a0, $b0, $b0, $b0, $b0

;GradualSlopeR_U4
.word $c0, $c0, $c0, $c0, $d0, $d0, $d0, $d0
.word $e0, $e0, $e0, $e0, $f0, $f0, $f0, $f0
.endproc
