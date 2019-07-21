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
.import ActorRun, ActorDraw, ActorFlags, ActorWidth, ActorHeight, ActorBank, ActorGraphic, ActorPalette
.import ParticleRun, ParticleDraw, ActorGetShot
.smart

.segment "ActorData"

; Two comparisons to make to determine if something is a slope
SlopeBCC = Block::MedSlopeL_DL
SlopeBCS = Block::GradualSlopeR_U4_Dirt+1
.export SlopeBCC, SlopeBCS
SlopeY = 2

.export RunAllActors
.proc RunAllActors
  setaxy16

  ; Prepare for the loop
  lda PaletteInUse+0
  sta PaletteInUseLast+0
  lda PaletteInUse+2
  sta PaletteInUseLast+2

  ; Load X with the actual pointer
  ldx #ActorStart
Loop:
  lda ActorType,x
  beq SkipEntity   ; Skip if empty

  ; Call the run and draw routines
  pha
  jsl CallRun
  pla
  jsl CallDraw

  ; Call the common routines
  lda ActorType,x
  beq SkipEntity
  phx
  tax
  lda f:ActorFlags,x
  plx

  lsr ; AutoRemove
  bcc NotAutoRemove
    ; Remove entity if too far away from the player
    pha
    lda ActorPX,x
    sub PlayerPX
    absw
    cmp #$2000 ; How about two screens of distance does it?
    bcc :+
      pla
      stz ActorType,x ; Zero the type
      bra SkipEntity   ; Skip doing anything else with this entity since it no longer exists
    :
    pla
  NotAutoRemove:

  lsr ; GetShot
  bcc NotGetShot
    pha
    jsl ActorGetShot
    pla
  NotGetShot:

  lsr ; AutoReset
  bcc NotAutoReset
    pha
    lda ActorTimer,x
    beq :+
    dec ActorTimer,x
    bne :+
      ; Zero the state, keep the variable that ends up in the high byte
      lda ActorState,x
      and #$ff00
      sta ActorState,x
    :
    pla
  NotAutoReset:

  lsr ; WaitUntilNear
  bcc NotWaitUntilNear

  NotWaitUntilNear:

  ; Reset the "init" state
  seta8
  lda ActorState,x
  cmp #ActorStateValue::Init
  bne :+
    stz ActorState,x
  :
  seta16
SkipEntity:

  ; Next entity
  txa
  add #ActorSize
  tax
  cpx #ActorEnd
  bne Loop

  jmp RunAllParticles

; Call the Actor run code
.a16
CallRun:
  phx
  tax
  seta8
  lda f:ActorBank+0,x
  pha
  plb ; Use code bank as data bank
  sta 2
  seta16
  lda f:ActorRun,x
  sta 0
  plx

  ; Jump to it and return with an RTL
  jml [0]

; Call the Actor draw code
.a16
CallDraw:
  phx
  tax
  seta8
  lda f:ActorBank+1,x
  pha
  plb ; Use code bank as data bank
  sta 2
  seta16
  lda f:ActorDraw,x
  sta 0

  ; Get the desired tileset
  lda f:ActorGraphic,x

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
  lda f:ActorPalette,x
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
  beq FoundPaletteRequestIndex2 ; No Actors using this palette
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
  lda f:ActorPalette,x
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

  ; Jump to the per-Actor routine and return with an RTL
  plx ; X now equals the Actor index base again
  jml [0]
.endproc

.a16
.i16
.proc RunAllParticles
  phk
  plb

  ldx #ParticleStart
Loop:
  lda ParticleType,x
  beq SkipEntity   ; Skip if empty

  ; Call the run and draw routines
  asl
  pha
  jsr CallRun
  pla
  jsr CallDraw

SkipEntity:
  ; Next particle
  txa
  add #ParticleSize
  tax
  cpx #ParticleEnd
  bne Loop
  rtl

CallRun:
  tay
  lda ParticleRun,y
  pha
  rts
CallDraw:
  tay
  lda ParticleDraw,y
  pha
  rts
.endproc


.a16
.i16
.proc FindFreeActorX
  ldx #ActorStart
Loop:
  lda ActorType,x
  beq Found
  txa
  add #ActorSize
  tax
  cpx #ActorEnd
  bne Loop
  clc
  rtl
Found:
  lda #$ffff
  sta ActorIndexInLevel,x
  sec
  rtl
.endproc

.a16
.i16
.proc FindFreeActorY
  ldy #ActorStart
Loop:
  lda ActorType,y
  beq Found
  tya
  add #ActorSize
  tay
  cpy #ActorEnd
  bne Loop
  clc
  rtl
Found:
  lda #$ffff
  sta ActorIndexInLevel,y
  sec
  rtl
.endproc


.a16
.i16
.proc FindFreeParticleY
  ldy #ParticleStart
Loop:
  lda ParticleType,y
  beq Found
  tya
  add #ParticleSize
  tay
  cpy #ParticleEnd
  bne Loop
  clc
  rtl
Found:
  lda #0
  sta ParticleTimer,y
  sta ParticleVX,y
  sta ParticleVY,y
  sec
  rtl
.endproc

; Just flip the LSB of ActorDirection
.export ActorTurnAround
.a16
.proc ActorTurnAround
  ; No harm in using it as a 16-bit value here, it's just written back
  lda ActorDirection,x ; a 0 marks an empty slot
  eor #1
  sta ActorDirection,x
  rtl
.endproc

.export ActorLookAtPlayer
.a16
.proc ActorLookAtPlayer
  lda ActorPX,x
  cmp PlayerPX

  ; No harm in using it as a 16-bit value here, it's just written back
  lda ActorDirection,x
  and #$fffe
  adc #0
  sta ActorDirection,x

  rtl
.endproc

; Causes the Actor to hover in place
; takes over ActorVarC and uses it for hover position
.export ActorHover
.a16
.proc ActorHover
  phb
  phk ; To access the table at the end
  plb
  ldy ActorVarC,x

  seta8
  lda Wavy,y
  sex
  sta 0

  lda ActorPY+0,x
  add Wavy,y
  sta ActorPY+0,x
  lda ActorPY+1,x
  adc 0
  sta ActorPY+1,x

  inc ActorVarC,x
  lda ActorVarC,x
  and #63
  sta ActorVarC,x
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
  jsl ActorApplyXVelocity

;  lda ActorPXL,x
;  add #$80
;  lda ActorPXH,x
;  adc #0
;  ldy ActorPYH,x
;  jsr GetLevelColumnPtr
;  cmp #Metatiles::ENEMY_BARRIER
;  bne :+
;    neg16x ActorVXL, ActorVXH
;    rts
;  :

  ; Stop if stunned
  lda ActorState,x ; Ignore high byte
  and #255
  beq :+
    stz ActorVX,x
  :

  ; Change direction to face the player
  jsl ActorLookAtPlayer

  ; Only speed up if not around player
  lda ActorPX,x
  sub PlayerPX
  absw
  cmp #$300
  bcc TooClose
  lda #4
  jsl ActorNegIfLeft
  add ActorVX,x

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

  sta ActorVX,x
TooClose:

  rtl
.endproc

; Takes a speed in the accumulator, and negates it if Actor facing left
.a16
.export ActorNegIfLeft
.proc ActorNegIfLeft
  pha
  lda ActorDirection,x ; Ignore high byte
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

.export ActorApplyVelocity
.proc ActorApplyVelocity
  lda ActorPX,x
  add ActorVX,x
  sta ActorPX,x
YOnly:
  lda ActorPY,x
  add ActorVY,x
  sta ActorPY,x
  rtl
.endproc
ActorApplyYVelocity = ActorApplyVelocity::YOnly

.export ActorApplyXVelocity
.export ActorApplyYVelocity
.proc ActorApplyXVelocity
  lda ActorPX,x
  add ActorVX,x
  sta ActorPX,x
  rtl
.endproc


; Walks forward, and turns around if walking farther
; would cause the Actor to fall off the edge of a platform
; input: A (walk speed), X (Actor slot)
.export ActorWalkOnPlatform
.proc ActorWalkOnPlatform
  jsl ActorWalk
  jsl ActorAutoBump
.endproc
; fallthrough
.a16
.export ActorStayOnPlatform
.proc ActorStayOnPlatform
  ; Check forward a bit
  ldy ActorPY,x
  lda #8*16
  jsl ActorNegIfLeft
  add ActorPX,x
  jsl ActorTryVertInteraction

  cmp #$4000 ; Test for solid on top
  bcs :+
    jsl ActorTurnAround
  :
  rtl
.endproc

; Look up the block at a coordinate and run the interaction routine it has, if applicable
.export ActorTryVertInteraction
.import BlockRunInteractionActorTopBottom
.proc ActorTryVertInteraction
  jsl GetLevelPtrXY
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionActorTopBottom
  lda BlockFlag
  rtl
.endproc

.export ActorTrySideInteraction
.import BlockRunInteractionActorSide
.proc ActorTrySideInteraction
  jsl GetLevelPtrXY
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionActorSide
  lda BlockFlag
  rtl
.endproc

.a16
.export ActorWalk
.proc ActorWalk
WalkDistance = 0
  jsl ActorNegIfLeft
  sta WalkDistance

  ; Don't walk if the state is nonzero
  lda ActorState,x
  and #255
  beq :+
    clc
    rtl
  :

  ; Look up if the wall is solid
  lda ActorPY,x
  sub #1<<8
  tay
  lda ActorPX,x
  add WalkDistance
  jsl ActorTrySideInteraction
  bpl NotSolid
  Solid:
     sec
     rtl
  NotSolid:

  ; Apply the walk
  lda ActorPX,x
  add WalkDistance
  sta ActorPX,x
  ; Fall into ActorDownhillFix
.endproc
.a16
.proc ActorDownhillFix

  ; Going downhill requires special help
  seta8
  lda ActorOnGround,x ; Need to have been on ground last frame
  beq NoSlopeDown
  lda ActorVY+1,x
  bmi NoSlopeDown
  seta16
    jsr ActorGetSlopeYPos
    bcs :+
      ; Try again one block below
      inc LevelBlockPtr
      inc LevelBlockPtr
      lda [LevelBlockPtr]
      jsr ActorGetSlopeYPosBelow
      bcc NoSlopeDown
    :

    lda SlopeY
    sta ActorPY,x
    stz ActorVY,x
  NoSlopeDown:
  seta16

  ; Reset carry to indicate not bumping into something
  ; because ActorWalk falls into this
  clc
  rtl
.endproc

.a16
.export ActorGravity
.proc ActorGravity
  lda ActorVY,x
  bmi OK
  cmp #$60
  bcs Skip
OK:
  add #4
  sta ActorVY,x
Skip:
  jmp ActorApplyYVelocity
.endproc

; Calls ActorGravity and then fixes things if they land on a solid block
; input: X (Actor pointer)
; output: carry (standing on platform)
.a16
.export ActorFall
.proc ActorFall
  jsl ActorGravity

  ; Remove if too far off the bottom
  lda ActorPY,x
  bmi :+
    cmp #32*256
    bcc :+
    cmp #$ffff - 2*256
    bcs :+
      stz ActorType,x
      rtl
  :

  jmp ActorCheckStandingOnSolid
.endproc


; Checks if an Actor is on top of a solid block
; input: X (Actor slot)
; output: Zero flag (not zero if on top of a solid block)
; locals: 0, 1
.a16
.export ActorCheckStandingOnSolid
.proc ActorCheckStandingOnSolid
  seta8
  stz ActorOnGround,x
  seta16

  ; If going upwards, don't check (for now)
  stz 0
  lda ActorVY,x
  bpl :+
    lda #0
    rtl
  :

  ; Check for slope interaction
  jsr ActorGetSlopeYPos
  bcc :+
    lda SlopeY
;    cmp ActorPY,x
;    bcs :+
    sta ActorPY,x
    stz ActorVY,x

    seta8
    inc ActorOnGround,x
    seta16
    ; Don't do the normal ground check
    sec
    rtl
  :

  ; Maybe add checks for the sides
  ldy ActorPY,x
  lda ActorPX,x
  jsl ActorTryVertInteraction
  cmp #$4000
  rol 0

  lda 0
  seta8
  sta ActorOnGround,x
  ; React to touching the ground
  beq :+
    stz ActorPY,x ; Clear the low byte
    seta16
    stz ActorVY,x
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
.proc ActorGetSlopeYPos
  ldy ActorPY,x
  lda ActorPX,x
  jsl GetLevelPtrXY
  jsr ActorIsSlope
  bcc NotSlope
    phk
    plb
    lda ActorPY,x
    and #$ff00
    ora SlopeHeightTable,y
    sta SlopeY

    lda SlopeHeightTable,y
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr ActorIsSlope
      bcc :+
        lda ActorPY,x
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
.proc ActorGetSlopeYPosBelow
  jsr ActorIsSlope
  bcc NotSlope
    lda ActorPY,x
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
      jsr ActorIsSlope
      bcc :+
        lda ActorPY,x
        ora SlopeHeightTable,y
        sta SlopeY
    :
  sec
NotSlope:
  rts
.endproc

.a16
.proc ActorIsSlope
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
  lda ActorPX,x
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
; into something during ActorWalk
.a16
.export ActorAutoBump
.proc ActorAutoBump
  bcc NoBump
  jmp ActorTurnAround
NoBump:
  rtl
.endproc

; Automatically removes an Actor if they're too far away from the camera
.a16
.export ActorAutoRemove
.proc ActorAutoRemove
  lda ActorPX
  sub ScrollX
  cmp #.loword(-8*256)
  bcs Good
  cmp #32*256
  bcc Good
  stz ActorType,x
Good:
  rtl
.endproc

; Automatically removes an Actor if they're too far away from the camera
; (Bigger range)
.a16
.export ActorAutoRemoveFar
.proc ActorAutoRemoveFar
  lda ActorPX
  sub ScrollX
  cmp #.loword(-24*256)
  bcs Good
  cmp #40*256
  bcc Good
  stz ActorType,x
Good:
  rtl
.endproc

; TODO
.a16
.proc ActorBecomePoof
  stz ActorType,x
  rtl
.endproc


; Calculate the position of the Actor on-screen
; and whether it's visible in the first place
.a16
.proc ActorDrawPosition
  lda ActorPX,x
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

  lda ActorPY,x
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
.export DispActor16x16
.proc DispActor16x16
  sta 4

  ; If facing left, set the X flip bit
  lda ActorDirection,x ; Ignore high byte
  lsr
  bcc :+
    lda #OAM_XFLIP
    tsb 4
  :

  ; If stunned, flip upside down
  lda ActorState,x
  and #$00ff
  cmp #ActorStateValue::Stunned
  bne :+
    lda #OAM_YFLIP
    tsb 4
  :


  ldy OamPtr

  jsr ActorDrawPosition
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

; A = tile to draw
.a16
.export DispActor8x8
.proc DispActor8x8
  sta 4

  ; If facing left, set the X flip bit
  lda ActorDirection,x ; Ignore high byte
  lsr
  bcc :+
    lda #OAM_XFLIP
    tsb 4
  :

  ldy OamPtr

  jsr ActorDrawPosition
  bcs :+
    rtl
  :  

  lda 4
  ora SpriteTileBase
  sta OAM_TILE,y ; 16-bit, combined with attribute

  seta8
  lda 0
  add #4
  sta OAM_XPOS,y
  lda 2
  add #8
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00001000
  lda #0 ; 8x8 sprites
  rol
  sta OAMHI+1,y
  seta16

  tya
  add #4
  sta OamPtr
  rtl
.endproc


.a16
.proc ParticleDrawPosition
  lda ParticlePX,x
  sub ScrollX
  cmp #.loword(-1*256)
  bcs :+
  cmp #16*256
  bcs Invalid
: lsr
  lsr
  lsr
  lsr
  sub #4
  sta 0

  lda ParticlePY,x
  sub ScrollY
  cmp #15*256
  bcs Invalid
  lsr
  lsr
  lsr
  lsr
  sub #4
  sta 2

  sec
  rts
Invalid:
  clc
  rts
.endproc

; A = tile to draw
.a16
.export DispParticle8x8
.proc DispParticle8x8
  ldy OamPtr
  sta OAM_TILE,y ; 16-bit, combined with attribute

  jsr ParticleDrawPosition
  bcs :+
    rtl
  :  

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00001000
  lda #0 ; 8x8 sprites
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

.repeat 2
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
.endrep
.endproc

.pushseg
.segment "Player"
.export SlopeFlagTable
.proc SlopeFlagTable
Left  = $8000
Right = $0000
Gradual = 1
Medium  = 2
Steep   = 4

.word Left  ; MedSlopeL_DL
.word Right ; MedSlopeR_DR
.word Left  ; GradualSlopeL_D1
.word Left  ; GradualSlopeL_D2
.word Right ; GradualSlopeR_D3
.word Right ; GradualSlopeR_D4
.word Left  ; SteepSlopeL_D
.word Right ; SteepSlopeR_D
.repeat 2
.word Left  | Medium  ; MedSlopeL_UL
.word Left  | Medium  ; MedSlopeL_UR
.word Right | Medium  ; MedSlopeR_UL
.word Right | Medium  ; MedSlopeR_UR
.word Left  | Steep   ; SteepSlopeL_U
.word Right | Steep   ; SteepSlopeR_U
.word Left  | Gradual ; GradualSlopeL_U1
.word Left  | Gradual ; GradualSlopeL_U2
.word Left  | Gradual ; GradualSlopeL_U3
.word Left  | Gradual ; GradualSlopeL_U4
.word Right | Gradual ; GradualSlopeR_U1
.word Right | Gradual ; GradualSlopeR_U2
.word Right | Gradual ; GradualSlopeR_U3
.word Right | Gradual ; GradualSlopeR_U4
.endrep
.endproc
.popseg


; Tests if two actors overlap
; Inputs: Actor pointers X and Y
.export TwoActorCollision
.a16
.i16
.proc TwoActorCollision
AWidth   = TouchTemp+0
AHeight1 = TouchTemp+2
AHeight2 = TouchTemp+4
AYPos    = TouchTemp+6
  ; Test X positions

  ; Add the two widths together
  phx
  lda ActorType,x
  tax
  lda f:ActorHeight,x
  sta AHeight1

  ; The two actors' widths are added together, so just do this math now
  lda f:ActorWidth,x
  ldx ActorType,y
  add f:ActorWidth,x
  sta AWidth

  lda f:ActorHeight,x
  sta AHeight2
  plx

  ; Assert that (abs(a.x - b.x) * 2 < (a.width + b.width))
  lda ActorPX,x
  sub ActorPX,y
  bpl :+       ; Take the absolute value
    eor #$ffff
    ina
  :
  asl
  cmp AWidth
  bcs No

  ; -----------------------------------

  ; Test Y positions
  ; Y positions of actors are the bottom, so get the top of the actors
  lda ActorPY,x
  sub AHeight1
  pha

  lda ActorPY,y
  sub AHeight2
  sta AYPos

  dec AHeight2 ; For satisfying the SIZE2-1
  lda AHeight2
  add AHeight1 ; And now it's modified so it'll have the -1 for SIZE1+SIZE2-1
  sta AHeight1

  pla
  clc
  sbc AYPos    ; Note will subtract n-1
  sbc AHeight2 ; #SIZE2-1
  adc AHeight1 ; #SIZE1+SIZE2-1; Carry set if overlap
  bcc No

Yes:
  sec
  rtl
No:
  clc
  rtl
.endproc


.export PlayerActorCollision
.a16
.i16
.proc PlayerActorCollision
AWidth   = TouchTemp+0
AHeight1 = TouchTemp+2
AYPos    = TouchTemp+4
  ; Test X positions

  ; Add the two widths together
  phx
  lda ActorType,x
  tax
  lda f:ActorHeight,x
  sta AHeight1

  ; Player and actor width are added together
  lda f:ActorWidth,x
  add #8<<4 ; Player width
  sta AWidth
  plx

  ; Assert that (abs(a.x - b.x) * 2 < (a.width + b.width))
  lda PlayerPX
  sub ActorPX,x
  bpl :+       ; Take the absolute value
    eor #$ffff
    ina
  :
  asl
  cmp AWidth
  bcs No

  ; -----------------------------------

  ; Test Y positions
  ; Y positions of actors are the bottom, so get the top of the actor
  lda ActorPY,x
  sub AHeight1
  pha

  ; And we also need the two heights added together
  lda AHeight1
  add #PlayerHeight-1
  sta AHeight1

  pla
  clc
  sbc PlayerPYTop     ; Note will subtract n-1
  sbc #PlayerHeight-1 ; #SIZE2-1
  adc AHeight1        ; #SIZE1+SIZE2-1; Carry set if overlap
  bcc No

Yes:
  sec
  rtl
No:
  clc
  rtl
.endproc


.export PlayerActorCollisionHurt
.a16
.i16
.proc PlayerActorCollisionHurt
  ; Don't hurt the player if the actor is stunned
  lda ActorState,x
  and #$00ff
  cmp #ActorStateValue::Stunned
  beq Exit

  jsl PlayerActorCollision
  bcc :+
    .import HurtPlayer
    jml HurtPlayer
  :
Exit:
  rtl
.endproc
