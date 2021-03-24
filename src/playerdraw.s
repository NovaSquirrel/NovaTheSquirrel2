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
.include "playerframe.inc"
.smart

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

  lda #(SpriteCHRBase+$000)>>1
  sta PPUADDR
  seta8
  lda #^PlayerGraphics
  sta DMAADDRBANK+$00
  sta DMAADDRBANK+$10

  lda #%00000001
  sta COPYSTART

  ; Bottom row -------------------
  seta16
  lda #(SpriteCHRBase+$200)>>1
  sta PPUADDR
  seta8
  lda #%00000010
  sta COPYSTART

  ; Hold on, is there enough time to upload new ability graphics, if that's needed?
  ; It's 1KB plus four tiles. We can check to make sure it wouldn't cause vblank to be overrun
  ; by checking the current Y position.
  bit PPUSTATUS2 ; Resets the flip flop for GETXY
  bit GETXY
  lda YCOORD
  cmp #261-(8+1) ; The following code takes about 8 scanlines, add 1 for security
  bcc :+
@TimeUp:
    ; There's not enough time to copy the ability graphics, so delay that until next frame
    plp
    rtl
  :
  ; Read YCOORD a second time - if the high bit of the Y position is set, there is definitely not enough time
  lda YCOORD
  lsr
  bcs @TimeUp
  bit VBLSTATUS ; Need to be in vblank
  bpl @TimeUp

  ; -----------------------------------
  ; Is there an ability icon to copy in?
  lda NeedAbilityChange
  beq NoNeedAbilityChange
    .import AbilityIcons
    lda #^AbilityIcons
    sta DMAADDRBANK+$00
    sta DMAADDRBANK+$10

    seta16
    lda PlayerAbility
    and #255
    xba ; Multiply by 256
    lsr ; Divide by 2 to get 128
    add #.loword(AbilityIcons)
    sta DMAADDR+$00
    add #64
    sta DMAADDR+$10

    lda #32*2 ; 2 tiles for each DMA
    sta DMALEN+$00
    sta DMALEN+$10

    ; Top row ----------------------
    lda #(SpriteCHRBase+$100)>>1
    sta PPUADDR
    seta8
    lda #%00000001
    sta COPYSTART

    ; Bottom row -------------------
    seta16
    lda #(SpriteCHRBase+$300)>>1
    sta PPUADDR
    seta8
    lda #%00000010
    sta COPYSTART

    ; Ability graphics -------------
    phk
    plb
    seta16
    lda PlayerAbility
    and #255
    tay
    .import AbilityTilesetForId
    lda AbilityTilesetForId,y
    and #255
    xba
    asl
    asl
    .import AbilityGraphics
    adc #.loword(AbilityGraphics) ; assert((PS & 1) == 0) Carry always clear here
    sta DMAADDR

    lda #1024 ; Two rows of tiles
    sta DMALEN
    lda #(SpriteCHRBase+$400)>>1
    sta PPUADDR
    seta8
    lda #%00000001
    sta COPYSTART

    stz NeedAbilityChange
    stz NeedAbilityChangeSilent
    stz TailAttackTimer
    stz AbilityMovementLock
  NoNeedAbilityChange:

  plp
  rtl
.endproc

.a16
.i16
.export DrawPlayer
.proc DrawPlayer
  ldx PlayerOAMIndex

  jsr XToPixels

  ; Keep the player within bounds horizontally
  ; and fix it if they're out of bounds.
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
  lsr
  lsr
  lsr
  lsr
  sub FGScrollYPixels
  cmp #224+32 ; Put the player offscreen if needed
  bcc :+
    lda #255
  :
HaveY:
  sta 2


  lda #$0200  ; Use 16x16 sprites
  sta OAMHI+(4*0),x
  sta OAMHI+(4*1),x
  sta OAMHI+(4*2),x
  sta OAMHI+(4*3),x
  sta OAMHI+(4*4),x

  seta8
  lda 0
  sta PlayerDrawX
  sta OAM_XPOS+(4*1),x
  sta OAM_XPOS+(4*3),x
  sub #16
  sta OAM_XPOS+(4*0),x
  sta OAM_XPOS+(4*2),x

  lda PlayerRolling
  beq :+
    lda 2
    add #8
    sta 2
  :

  lda 2
  sta PlayerDrawY
  sub #17
  sta OAM_YPOS+(4*2),x
  sta OAM_YPOS+(4*3),x
  sub #16
  sta OAM_YPOS+(4*0),x
  sta OAM_YPOS+(4*1),x

  ; Ability icon
  lda #15
  sta OAM_XPOS+(4*4),x
  lda #8
  sta OAM_YPOS+(4*4),x

  ; Tile numbers
  lda #0
  sta OAM_TILE+(4*0),x
  lda #2
  sta OAM_TILE+(4*1),x
  lda #4
  sta OAM_TILE+(4*2),x
  lda #6
  sta OAM_TILE+(4*3),x
  lda #8 ; Ability icon
  sta OAM_TILE+(4*4),x

  ; Horizontal flip
  lda PlayerDir
  eor PlayerFrameXFlip
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

    lda #OAM_XFLIP>>8
  :
  ora #>(OAM_PRIORITY_2|OAM_COLOR_1) ; priority
  sta OAM_ATTR+(4*0),x
  sta OAM_ATTR+(4*1),x
  sta OAM_ATTR+(4*2),x
  sta OAM_ATTR+(4*3),x

  ; Ability icon has top priority
  lda #>(OAM_PRIORITY_3|OAM_COLOR_0)
  sta OAM_ATTR+(4*4),x

  ; Do a vertical flip (possibly on top of a horizontal flip) if requested
  lda PlayerFrameYFlip
  beq :+
    ; Swap vertically
    lda OAM_TILE+(4*0),x
    pha
    lda OAM_TILE+(4*2),x
    sta OAM_TILE+(4*0),x
    pla
    sta OAM_TILE+(4*2),x

    lda OAM_TILE+(4*1),x
    pha
    lda OAM_TILE+(4*3),x
    sta OAM_TILE+(4*1),x
    pla
    sta OAM_TILE+(4*3),x

    ; Fix attributes
    lda OAM_ATTR+(4*0),x
    ora #OAM_YFLIP>>8
    sta OAM_ATTR+(4*0),x
    sta OAM_ATTR+(4*1),x
    sta OAM_ATTR+(4*2),x
    sta OAM_ATTR+(4*3),x
  :


  ; Invincibility effect
  lda PlayerInvincible
  lsr
  bcc :+
    lda #225 ; Move offscreen every other frame
    sta OAM_YPOS+(4*0),x
    sta OAM_YPOS+(4*1),x
    sta OAM_YPOS+(4*2),x
    sta OAM_YPOS+(4*3),x
  :

  ; Automatically cycle through the walk animation
  seta8
  stz PlayerFrame
  stz PlayerFrameXFlip
  stz PlayerFrameYFlip

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


  lda TailAttackTimer
  beq NoTailAttack
    lda TailAttackFrame
    sta PlayerFrame
    bra Exit
  NoTailAttack:

  lda PlayerOnLadder
  beq OffLadder
    lda retraces
    lsr
    lsr
    lsr
    and #1
    add #PlayerFrame::CLIMB1
    sta PlayerFrame

    ; Turn around
    lda retraces
    and #16
    bne OffLadder
      inc PlayerFrameXFlip
  OffLadder:


  lda PlayerRolling
  beq NoRoll
    lda retraces
    lsr
    lsr
    and #3
    add #PlayerFrame::ROLL1
    sta PlayerFrame

    lda retraces
    inc a
    and #16
    beq NoRoll
      inc PlayerFrameXFlip
      inc PlayerFrameYFlip
  NoRoll:


Exit:
  setaxy16
  rtl

XToPixels:
  ; X coordinate to pixels
  lda PlayerPX
  lsr
  lsr
  lsr
  lsr
  sub FGScrollXPixels
  sta 0
  rts
.endproc

.export DrawPlayerStatus
.proc DrawPlayerStatus
  ldx OamPtr
  ; -----------------------------------
  ; But we still need to draw the health meter
  HealthCount = 0
  HealthX = 1
  seta8
  lda #15
  sta HealthX

  lda PlayerHealth
  lsr
  php
  sta HealthCount
HealthLoop:
  lda HealthCount
  beq HealthLoopEnd
  lda #$6e
  jsr MakeHealthIcon
  dec HealthCount
  bne HealthLoop
HealthLoopEnd:
  plp 
  bcc :+
    lda #$6f
    jsr MakeHealthIcon
  :

  ; -----------------------------------
  stx OamPtr
  setaxy16
  rtl

.a8
MakeHealthIcon:
  sta OAM_TILE,x
  lda HealthX
  sta OAM_XPOS,x
  add #8
  sta HealthX
  lda #>(OAM_PRIORITY_3|OAM_COLOR_0)
  sta OAM_ATTR,x
  lda #16+8
  sta OAM_YPOS,x
  stz OAMHI+0,x
  stz OAMHI+1,x

  ; Next sprite
  inx
  inx
  inx
  inx
  rts
.endproc
