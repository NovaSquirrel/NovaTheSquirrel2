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
.import ObjectRun, ObjectDraw, ObjectFlags, ObjectWidth, ObjectHeight, ObjectBank, ObjectGraphic, ObjectPalette
.smart

.segment "ActorData"

; Two comparisons to make to determine if something is a slope
SlopeBCC = Block::MedSlopeL_DL*2
SlopeBCS = Block::GradualSlopeR_U4*2+1
.export SlopeBCC, SlopeBCS
SlopeY = 2

.export RunAllObjects
.proc RunAllObjects
  setaxy16

  ; Prepare for the loop
  lda PaletteInUse+0
  sta PaletteInUseLast+0
  lda PaletteInUse+2
  sta PaletteInUseLast+2

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

  ; Call the common routines
  lda ObjectType,x
  beq SkipEntity
  phx
  tax
  lda f:ObjectFlags,x
  plx

  lsr ; AutoRemove
  bcc NotAutoRemove
    ; Remove entity if too far away from the player
    pha
    lda ObjectPX,x
    sub PlayerPX
    absw
    cmp #$2000 ; How about two screens of distance does it?
    bcc :+
      pla
      stz ObjectType,x ; Zero the type
      bra SkipEntity   ; Skip doing anything else with this entity since it no longer exists
    :
    pla
  NotAutoRemove:

  lsr ; GetShot
  bcc NotGetShot

  NotGetShot:

  lsr ; AutoReset
  bcc NotAutoReset
    pha
    lda ObjectTimer,x
    beq :+
    dec ObjectTimer,x
    bne :+
      ; Zero the state, keep the variable that ends up in the high byte
      lda ObjectState,x
      and #$ff00
      sta ObjectState,x
    :
    pla
  NotAutoReset:

  lsr ; WaitUntilNear
  bcc NotWaitUntilNear

  NotWaitUntilNear:

SkipEntity:

  ; Next entity
  txa
  add #ObjectSize
  tax
  cpx #ObjectEnd
  bne Loop
  rtl

; Call the object run code
.a16
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
.a16
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

  ; Get the desired tileset
  lda f:ObjectGraphic,x

  ; Detect the correct tile base
  ; using an unrolled loop
  cmp SpriteTileSlots+2*0
  bne :+
    lda #$100
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*1
  bne :+
    lda #$120
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*2
  bne :+
    lda #$140
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*3
  bne :+
    lda #$160
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*4
  bne :+
    lda #$180
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*5
  bne :+
    lda #$1A0
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*6
  bne :+
    lda #$1C0
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*7
  bne :+
    lda #$1E0
  :
FoundTileset:
  sta SpriteTileBase

  ; Detect the correct palette
  ; using an unrolled loop again
  lda f:ObjectPalette,x
  cmp SpritePaletteSlots+2*0
  bne :+
    inc PaletteInUse+0
    lda #%1000<<8
    bra FoundPalette
  :
  cmp SpritePaletteSlots+2*1
  bne :+
    inc PaletteInUse+1
    lda #%1010<<8
    bra FoundPalette
  :
  cmp SpritePaletteSlots+2*2
  bne :+
    inc PaletteInUse+2
    lda #%1100<<8
    bra FoundPalette
  :
  cmp SpritePaletteSlots+2*3
  bne :+
    inc PaletteInUse+3
    lda #%1110<<8
    bra FoundPalette
  :

  ; -----------------------------------
  ; Palette not found, so request it!
  lda PaletteRequestIndex
  bne PaletteNotFound ; Unless a palette is already being requested, then wait for next frame

  ; Prefer unassigned palette slots first
  ldy #4*2-2
  lda #$ffff
: cmp SpritePaletteSlots,y
  beq FoundPaletteRequestIndex
  dey
  dey
  bpl :-

  ; No unassigned ones? Just look for one that wasn't used last frame
  seta8
  ldy #4-1
: lda PaletteInUseLast,y
  beq FoundPaletteRequestIndex2 ; No objects using this palette
  dey
  bpl :-
  ; No suitable slots found, so give up for this frame
  seta16
  bra PaletteNotFound

FoundPaletteRequestIndex2:
  ; Convert the index since PaletteInUseLast is 8-bit while SpritePaletteSlots is 16-bit
  seta16
  tya
  asl
  tay
FoundPaletteRequestIndex:
  ; Write the desired palette into the list of active palettes
  lda f:ObjectPalette,x
  sta SpritePaletteSlots,y

  seta8
  ; And also that's the palette we need to request
  sta PaletteRequestValue

  ; Calculate index to upload it to
  tya
  lsr
  ora #8+4 ; Last four sprite palettes
  sta PaletteRequestIndex
  seta16

  ; Use the new palette index,
  ; since it will be there by the time we do OAM DMA
  tya              ; ........ .....pp.
  xba              ; .....pp. ........
  ora #OAM_COLOR_4 ; ....1pp. ........
  bra FoundPalette ; yxPPpppt tttttttt

PaletteNotFound:
  ; Probably exit without drawing it, instead of drawing with the wrong colors
  lda #0
FoundPalette:
  tsb SpriteTileBase

  ; Jump to the per-object routine and return with an RTL
  plx ; X now equals the object index base again
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

; Causes the enemy to move back and forth horizontally,
; seeking the player
.export LakituMovement
.a16
.proc LakituMovement
  jsl ObjectApplyXVelocity

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

  ; Change direction to face the player
  jsl ObjectLookAtPlayer

  ; Only speed up if not around player
  lda ObjectPX,x
  sub PlayerPX
  absw
  cmp #$300
  bcc TooClose
  lda #4
  jsl ObjectNegIfLeft
  add ObjectVX,x

  ; Limit speed to 3 pixels/frame
  php ; Take absolute value and negate it back if it was negative
  ; Flags are still from the previous add
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
TooClose:

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
  pla ; No change
  rtl
Left:
  pla ; Negate
  negw
  rtl
.endproc

.proc ObjectApplyVelocity
  lda ObjectPX,x
  add ObjectVX,x
  sta ObjectPX,x
YOnly:
  lda ObjectPY,x
  add ObjectVY,x
  sta ObjectPY,x
  rtl
.endproc
ObjectApplyYVelocity = ObjectApplyVelocity::YOnly

.proc ObjectApplyXVelocity
  lda ObjectPX,x
  add ObjectVX,x
  sta ObjectPX,x
  rtl
.endproc


; Walks forward, and turns around if walking farther
; would cause the object to fall off the edge of a platform
; input: A (walk speed), X (object slot)
.export ObjectWalkOnPlatform
.proc ObjectWalkOnPlatform
  jsl ObjectWalk
  jsl ObjectAutoBump
.endproc
; fallthrough
.a16
.export ObjectStayOnPlatform
.proc ObjectStayOnPlatform
  ; Check forward a bit
  ldy ObjectPY,x
  lda #8*16
  jsl ObjectNegIfLeft
  add ObjectPX,x
  jsl ObjectTryVertInteraction

  cmp #$4000 ; Test for solid on top
  bcs :+
    jsl ObjectTurnAround
  :
  rtl
.endproc

; Look up the block at a coordinate and 
.export ObjectTryVertInteraction
.import BlockRunInteractionEntityTopBottom
.proc ObjectTryVertInteraction
  jsl GetLevelPtrXY
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionEntityTopBottom
  lda BlockFlag
  rtl
.endproc

.export ObjectTrySideInteraction
.import BlockRunInteractionEntitySide
.proc ObjectTrySideInteraction
  jsl GetLevelPtrXY
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionEntitySide
  lda BlockFlag
  rtl
.endproc

.a16
.export ObjectWalk
.proc ObjectWalk
WalkDistance = 0
  jsl ObjectNegIfLeft
  sta WalkDistance

  ; Don't walk if the state is nonzero
  lda ObjectState,x
  and #255
  beq :+
    clc
    rtl
  :

  ; Look up if the wall is solid
  lda ObjectPY,x
  sub #1<<8
  tay
  lda ObjectPX,x
  add WalkDistance
  jsl ObjectTrySideInteraction
  bpl NotSolid
  Solid:
     sec
     rtl
  NotSolid:

  ; Apply the walk
  lda ObjectPX,x
  add WalkDistance
  sta ObjectPX,x
  ; Fall into ObjectDownhillFix
.endproc
.a16
.proc ObjectDownhillFix

  ; Going downhill requires special help
  seta8
  lda ObjectOnGround,x ; Need to have been on ground last frame
  beq NoSlopeDown
  lda ObjectVY+1,x
  bmi NoSlopeDown
  seta16
    jsr ObjectGetSlopeYPos
    bcs :+
      ; Try again one block below
      inc LevelBlockPtr
      inc LevelBlockPtr
      lda [LevelBlockPtr]
      jsr ObjectGetSlopeYPosBelow
      bcc NoSlopeDown
    :

    lda SlopeY
    sta ObjectPY,x
    stz ObjectVY,x
  NoSlopeDown:
  seta16

  ; Reset carry to indicate not bumping into something
  ; because ObjectWalk falls into this
  clc
  rtl
.endproc

.a16
.export ObjectGravity
.proc ObjectGravity
  lda ObjectVY,x
  bmi OK
  cmp #$60
  bcs Skip
OK:
  add #4
  sta ObjectVY,x
Skip:
  jmp ObjectApplyYVelocity
.endproc

; Calls ObjectGravity and then fixes things if they land on a solid block
; input: X (object pointer)
; output: carry (standing on platform)
.a16
.export ObjectFall
.proc ObjectFall
  jsl ObjectGravity

  ; Remove if too far off the bottom
  lda ObjectPY,x
  bmi :+
    cmp #32*256
    bcc :+
    cmp #$ffff - 2*256
    bcs :+
      stz ObjectType,x
      rtl
  :

  jmp ObjectCheckStandingOnSolid
.endproc


; Checks if an object is on top of a solid block
; input: X (object slot)
; output: Zero flag (not zero if on top of a solid block)
; locals: 0, 1
.a16
.export ObjectCheckStandingOnSolid
.proc ObjectCheckStandingOnSolid
  seta8
  stz ObjectOnGround,x
  seta16

  ; If going upwards, don't check (for now)
  stz 0
  lda ObjectVY,x
  bpl :+
    lda #0
    rtl
  :

  ; Check for slope interaction
  jsr ObjectGetSlopeYPos
  bcc :+
    lda SlopeY
;    cmp ObjectPY,x
;    bcs :+
    sta ObjectPY,x
    stz ObjectVY,x

    seta8
    inc ObjectOnGround,x
    seta16
    ; Don't do the normal ground check
    sec
    rtl
  :

  ; Maybe add checks for the sides
  ldy ObjectPY,x
  lda ObjectPX,x
  jsl ObjectTryVertInteraction
  cmp #$4000
  rol 0

  lda 0
  seta8
  sta ObjectOnGround,x
  ; React to touching the ground
  beq :+
    stz ObjectPY,x ; Clear the low byte
    seta16
    stz ObjectVY,x
    sec
    rtl
  :
  seta16
  clc
  rtl
.endproc

; Get the Y position of the slope under the player's hotspot (SlopeY)
; and also return if they're on a slope at all (carry)
.a16
.proc ObjectGetSlopeYPos
  ldy ObjectPY,x
  lda ObjectPX,x
  jsl GetLevelPtrXY
  jsr ObjectIsSlope
  bcc NotSlope
    phk
    plb
    lda ObjectPY,x
    and #$ff00
    ora SlopeHeightTable,y
    sta SlopeY

    lda SlopeHeightTable,y
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr ObjectIsSlope
      bcc :+
        lda ObjectPY,x
        sbc #$0100 ; Carry already set
        ora SlopeHeightTable,y
        sta SlopeY
    :
  sec
NotSlope:
  rts
.endproc

.a16
; Similar but for checking one block below
.proc ObjectGetSlopeYPosBelow
  jsr ObjectIsSlope
  bcc NotSlope
    lda ObjectPY,x
    add #$0100
    and #$ff00
    ora SlopeHeightTable,y
    sta SlopeY

    lda SlopeHeightTable,y
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr ObjectIsSlope
      bcc :+
        lda ObjectPY,x
        ora SlopeHeightTable,y
        sta SlopeY
    :
  sec
NotSlope:
  rts
.endproc

.a16
.proc ObjectIsSlope
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
  lda ObjectPX,x
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

; Automatically turn around when bumping
; into something during ObjectWalk
.a16
.export ObjectAutoBump
.proc ObjectAutoBump
  bcc NoBump
  jmp ObjectTurnAround
NoBump:
  rtl
.endproc

; Automatically removes an object if they're too far away from the camera
.a16
.export ObjectAutoRemove
.proc ObjectAutoRemove
  lda ObjectPX
  sub ScrollX
  cmp #.loword(-8*256)
  bcs Good
  cmp #32*256
  bcc Good
  stz ObjectType,x
Good:
  rtl
.endproc

; Automatically removes an object if they're too far away from the camera
; (Bigger range)
.a16
.export ObjectAutoRemoveFar
.proc ObjectAutoRemoveFar
  lda ObjectPX
  sub ScrollX
  cmp #.loword(-24*256)
  bcs Good
  cmp #40*256
  bcc Good
  stz ObjectType,x
Good:
  rtl
.endproc

; TODO
.a16
.proc ObjectBecomePoof
  stz ObjectType,x
  rtl
.endproc


; Calculate the position of the object on-screen
; and whether it's visible in the first place
.a16
.proc ObjectDrawPosition
  lda ObjectPX,x
  sub ScrollX
  cmp #.loword(-1*256)
  bcs :+
  cmp #16*256
  bcs Invalid
: lsr
  lsr
  lsr
  lsr
  sub #8
  sta 0

  lda ObjectPY,x
  sub ScrollY
  ; TODO: properly allow sprites to be partially offscreen on the top
;  cmp #.loword(-1*256)
;  bcs :+
  cmp #15*256
  bcs Invalid
  lsr
  lsr
  lsr
  lsr
  sub #16
  sta 2

  sec
  rts
Invalid:
  clc
  rts
.endproc

; A = tile to draw
.a16
.export DispObject16x16
.proc DispObject16x16
  sta 4

  ; If facing left, set the X flip bit
  lda ObjectDirection,x ; Ignore high byte
  lsr
  bcc :+
    lda #OAM_XFLIP
    tsb 4
  :

  ldy OamPtr

  jsr ObjectDrawPosition
  bcs :+
    rtl
  :  

  lda 4
  ora SpriteTileBase
  sta OAM_TILE,y ; 16-bit, combined with attribute

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00001000
  lda #1 ; 16x16 sprites
  rol
  sta OAMHI+1,y
  seta16

  tya
  add #4
  sta OamPtr
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
