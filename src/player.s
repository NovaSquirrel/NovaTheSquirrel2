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
.importzp SlopeBCC, SlopeBCS
.import SlopeHeightTable

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
SlopeY = 6
MaxSpeedLeft = 10
MaxSpeedRight = 12
  phk
  plb

  ; Horizontal movement

  ; Calculate max speed from whether they're running or not
  ; (Updated only when on the ground)
  seta8
  countdown JumpGracePeriod
  countdown PlayerWantsToJump
  countdown PlayerJumpCancelLock

  lda keynew+1
  and #(KEY_B>>8)
  beq :+
    lda #3
    sta PlayerWantsToJump
  :

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


  ; Going downhill requires special help
  seta8
  lda PlayerOnGround ; Need to have been on ground last frame
  beq NoSlopeDown
  lda PlayerWantsToJump
  bne NoSlopeDown
  seta16
  lda PlayerVX     ; No compensation if not moving
  beq NoSlopeDown
    jsr GetSlopeYPos
    bcs :+
      ; Try again one block below
      inc LevelBlockPtr
      inc LevelBlockPtr
      lda [LevelBlockPtr]
      jsr GetSlopeYPosBelow
      bcc NoSlopeDown
    :

    lda SlopeY
    sta PlayerPY
    stz PlayerVY
  NoSlopeDown:
  seta16

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
  stz PlayerOnGround
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

  ; Slope interaction
  jsr GetSlopeYPos
  bcc :+
    lda SlopeY
    cmp PlayerPY
    bcs :+
    
    sta PlayerPY
    stz PlayerVY

    seta8
    inc PlayerOnGround
    seta16
    ; Don't do the normal ground check
    bra SkipGroundCheck
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
SkipGroundCheck:

  ; Above
  lda PlayerPY
  sub #16*16+14*16 ; Top of the head
  tay
  lda PlayerPX
  jsr TryBelowInteraction

  ; Inside
  lda PlayerPY
  sub #8*16
  tay
  lda PlayerPX
  jsl GetLevelPtrXY
  jsl GetBlockFlag
  jsl BlockRunInteractionInsideBody




  ; -------------------

  ; Offer a jump if not on ground and the grace period is still active
  seta8
  lda PlayerOnGround
  bne :+
  lda JumpGracePeriod
  beq :+
    seta16
    jsr OfferJumpFromGracePeriod
  :
  seta16

  ; If on the ground, offer a jump
  seta8
  lda PlayerOnGround
  seta16
  beq :+
    jsr OfferJump

    ; Update run status
    seta8
    lda keydown
    and #KEY_R|KEY_L
    sta PlayerWasRunning
    lda keydown+1
    and #KEY_Y>>8
    tsb PlayerWasRunning
    seta16
  :

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

    seta8
    inc PlayerOnGround
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
; Get the Y position of the slope under the player's hotspot (SlopeY)
; and also return if they're on a slope at all (carry)
GetSlopeYPos:
  ldy PlayerPY
  lda PlayerPX
  jsl GetLevelPtrXY
  jsr IsSlope
  bcc NotSlope
    lda PlayerPY
    and #$ff00
    ora f:SlopeHeightTable,x
    sta SlopeY

    lda f:SlopeHeightTable,x
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr IsSlope
      bcc :+
        lda PlayerPY
        sbc #$0100 ; Carry already set
        ora f:SlopeHeightTable,x
        sta SlopeY
    :
  sec
NotSlope:
  rts

.a16
; Similar but for checking one block below
GetSlopeYPosBelow:
  jsr IsSlope
  bcc NotSlope
    lda PlayerPY
    add #$0100
    and #$ff00
    ora f:SlopeHeightTable,x
    sta SlopeY

    lda f:SlopeHeightTable,x
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr IsSlope
      bcc :+
        lda PlayerPY
        ora f:SlopeHeightTable,x
        sta SlopeY
    :
  sec
  rts

.a16
; Determine if it's a slope (carry),
; but also determine the index into the height table (Y)
IsSlope:
  cmp #SlopeBCC
  bcc :+
  cmp #SlopeBCS
  bcs :+
  sub #SlopeBCC
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
  tax

  sec ; Success
  rts
: clc ; Failure
  rts

; Let the player jump if they press the button
.a16
OfferJump:
  seta8
  lda #7 ;JUMP_GRACE_PERIOD_LENGTH
  sta JumpGracePeriod
  seta16
OfferJumpFromGracePeriod:
  ; Newly pressed jump, either now or a few frames before
  lda PlayerWantsToJump
  and #255
  beq :+
  ; Still pressing the jump button
  lda keydown
  and #KEY_B
  beq :+
    seta8
    stz JumpGracePeriod
    inc PlayerJumping
    seta16
    lda #.loword(-$50)
    sta PlayerVY
  :
  rts
.endproc

.enum PlayerFrame
  IDLE
  WALK1
  WALK2
  WALK3
  WALK4
  WALK5
  WALK6
  WALK7
  WALK8
  RUN1
  RUN2
  RUN3
  RUN4
  RUN5
  RUN6
  RUN7
  RUN8
  JUMP
  FALL
.endenum

.a16
.i16
.proc DrawPlayer
  ldx OamPtr

  jsr XToPixels

  ; Keep the player within bounds horizontally
  lda 0
  cmp #$10
  bcs :+
    stz PlayerVX
    seta8
    lda #$00
    sta PlayerPX+0
    inc PlayerPX+1
    seta16
    jsr XToPixels
  :
  lda 0
  cmp #$f0
  bcc :+
    stz PlayerVX
    seta8
    dec PlayerPX+1
    lda #$ff
    sta PlayerPX+0
    seta16
    jsr XToPixels
  :

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
    lda PlayerWasRunning
    beq @NotRunning
      lda framecount
      lsr
      and #7
      add #8
      inc a
      sta PlayerFrame 
      bra :+
    @NotRunning:

    lda framecount
    lsr
    lsr
    and #7
    inc a
    sta PlayerFrame 
  :

  lda PlayerOnGround
  bne OnGround
    lda #PlayerFrame::FALL
    sta PlayerFrame

    lda PlayerJumping
    beq OnGround
      dec PlayerFrame
  OnGround:
  setaxy16
  rtl

XToPixels:
  ; X coordinate to pixels
  lda PlayerPX
  sub ScrollX
  lsr
  lsr
  lsr
  lsr
  sta 0
  rts
.endproc

