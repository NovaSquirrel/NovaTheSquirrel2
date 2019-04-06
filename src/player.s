.include "snes.inc"
.include "global.inc"
.smart

.segment "ZEROPAGE"

; Game variables
player_xlo:       .res 1  ; horizontal position is xhi + xlo/256 px
player_xhi:       .res 1
player_dxlo:      .res 1  ; speed in pixels per 256 s
player_yhi:       .res 1
player_frame_sub: .res 1
player_frame:     .res 1
player_facing:    .res 1

.segment "CODE4"

;;
; Loads palette and tiles related to the player sprite.
.proc load_player_tiles
  phb
  phk
  plb

  ; Because the S-PPU supports only square sprites, you sometimes
  ; have to leave blank space around oddly sized sprites.
  ; So zero out the tiles of the sprite that aren't used.
  setxy16
  ldx #$4000
  ldy #$0000
  jsl ppu_clear_nt
  
  ; After leaving the blank space, copy in the sprite data.
  ; Sprites in all background modes use 4-bit-per-pixel tiles,
  ; which take 32 bytes or 16 words per tile.
  setaxy16
  lda #$4000
  sta PPUADDR
  lda #DMAMODE_PPUDATA
  ldy #objtiles_bin_size
  ldx #objtiles_bin & $FFFF
  jsl ppu_copy

  ; There are 8 sprite palettes, each 15 colors in size, at $81-$8F,
  ; $91-$9F, ..., $F1-$FF.  Each color takes two bytes.
  ; CGRAM is word addressed, which means addresses are in 16-bit
  ; units, so you write the number of the color.
  seta8
  lda #$81
  sta CGADDR  ; CGADDR is word addressed.  $81 is actually
  setaxy16
  lda #DMAMODE_CGDATA
  ldx #objpalette & $FFFF
  ldy #objpalette_size
  jsl ppu_copy

  plb  ; Restore the data bank
  rtl
.endproc

; except for STZs and BRAs, the following subroutine is
; direct copypasta from the NES template code
cur_keys = JOY1CUR+1

; constants used by move_player
; PAL frames are about 20% longer than NTSC frames.  So if you make
; dual NTSC and PAL versions, or you auto-adapt to the TV system,
; you'll want PAL velocity values to be 1.2 times the corresponding
; NTSC values, and PAL accelerations should be 1.44 times NTSC.
WALK_SPD = 105  ; speed limit in 1/256 px/frame
WALK_ACCEL = 4  ; movement acceleration in 1/256 px/frame^2
WALK_BRAKE = 8  ; stopping acceleration in 1/256 px/frame^2

LEFT_WALL = 32
RIGHT_WALL = 224

;;
; Moves the player based on controller 1.
.proc move_player

  ; Acceleration to right: Do it only if the player is holding right
  ; on the Control Pad and has a nonnegative velocity.
  setaxy8
  lda cur_keys
  and #>KEY_RIGHT
  beq notRight
  lda player_dxlo
  bmi notRight
  
    ; Right is pressed.  Add to velocity, but don't allow velocity
    ; to be greater than the maximum.
    clc
    adc #WALK_ACCEL
    cmp #WALK_SPD
    bcc :+
      lda #WALK_SPD
    :
    sta player_dxlo
    lda player_facing  ; Set the facing direction to not flipped 
    and #<~$40         ; turn off bit 6, leave all others on
    sta player_facing
    jmp doneRight
  notRight:

    ; Right is not pressed.  Brake if headed right.
    lda player_dxlo
    bmi doneRight
    cmp #WALK_BRAKE
    bcs notRightStop
    lda #WALK_BRAKE+1  ; add 1 to compensate for the carry being clear
  notRightStop:
    sbc #WALK_BRAKE
    sta player_dxlo
  doneRight:

  ; Acceleration to left: Do it only if the player is holding left
  ; on the Control Pad and has a nonpositive velocity.
  lda cur_keys
  and #>KEY_LEFT
  beq notLeft
  lda player_dxlo
  beq isLeft
    bpl notLeft
  isLeft:

  ; Left is pressed.  Add to velocity.
    lda player_dxlo
    sec
    sbc #WALK_ACCEL
    cmp #256-WALK_SPD
    bcs :+
      lda #256-WALK_SPD
    :
    sta player_dxlo
    lda player_facing  ; Set the facing direction to flipped
    ora #$40
    sta player_facing
    jmp doneLeft
  notLeft:

    ; Left is not pressed.  Brake if headed left.
    lda player_dxlo
    bpl doneLeft
    cmp #256-WALK_BRAKE
    bcc notLeftStop
    lda #256-WALK_BRAKE
  notLeftStop:
    adc #8-1
    sta player_dxlo
  doneLeft:

  ; In a real game, you'd respond to A, B, Up, Down, etc. here.

  ; Move the player by adding the velocity to the 16-bit X position.
  lda player_dxlo
  bpl player_dxlo_pos
    ; if velocity is negative, subtract 1 from high byte to sign extend
    dec player_xhi
  player_dxlo_pos:
  clc
  adc player_xlo
  sta player_xlo
  lda #0          ; add high byte
  adc player_xhi
  sta player_xhi

  ; Test for collision with side walls
  ; (in actual games, this would involve collision with a tile map)
  cmp #LEFT_WALL-4
  bcs notHitLeft
    lda #LEFT_WALL-4
    sta player_xhi
    stz player_dxlo
    bra doneWallCollision
  notHitLeft:

  cmp #RIGHT_WALL-12
  bcc notHitRight
    lda #RIGHT_WALL-13
    sta player_xhi
    stz player_dxlo
  notHitRight:

  ; Additional checks for collision, if needed, would go here.
doneWallCollision:

  ; Animate the player
  ; If stopped, freeze the animation on frame 0 (stand)
  lda player_dxlo
  bne notStop1
    lda #$C0
    sta player_frame_sub
    stz player_frame
    rtl
  notStop1:

  ; Take absolute value of velocity (negate it if it's negative)
  bpl player_animate_noneg
    eor #$FF
    clc
    adc #1
  player_animate_noneg:

  lsr a  ; Multiply abs(velocity) by 5/16
  lsr a
  sta 0
  lsr a
  lsr a
  adc 0

  ; And 16-bit add it to player_frame
  adc player_frame_sub
  sta player_frame_sub
  lda player_frame
  adc #0

  ; Wrap from $800 (after last frame of walk cycle)
  ; to $100 (first frame of walk cycle)
  cmp #8
  bcc have_player_frame
    lda #1
  have_player_frame:

  sta player_frame
  rtl
.endproc

;;
; Draws the player's sprite to the display list using 16x16 pixel
; sprites.  Hardware 16x16 makes it a sh'load easier to draw a
; character than it was on the NES where even modestly sized
; characters required laying out a grid of sprites.
.proc draw_player_sprite
OAM_XPOS = OAM+0
OAM_YPOS = OAM+1
OAM_ATTR = OAM+2
OAM_TILE = OAM+3

  ldx oam_used
  
  ; OAM+0,x: x coordinate, top half
  ; OAM+1,x: y coordinate, top half
  ; OAM+2,x: flipping, priority, and palette, top half
  ; OAM+3,x: tile number, top half
  ; OAM+4-7,x: same for bottom half
  ; OAMHI+1,x: x coordinate high bit and size bit, top half
  ; OAMHI+5,x: same for bottom half
  
  ; Frame 7's center of gravity is offset a little to fit in the
  ; 16-pixel-wide box.  This means its X coordinate needs to be
  ; offset by about a pixel.
  seta8
  lda player_xhi
  and #$00FF
  sta OAM_XPOS+(4*0),x
  sta OAM_XPOS+(4*1),x

  sec
  sbc #8
  sta OAM_XPOS+(4*2),x
  sta OAM_XPOS+(4*3),x
  bit player_facing
  bvc :+
    clc
    adc #24
    sta OAM_XPOS+(4*2),x
    sta OAM_XPOS+(4*3),x
  :


  seta16
  lda #$0200  ; large, and not off left side
  sta OAMHI+0,x
  sta OAMHI+4,x
  lda #$0000
  sta OAMHI+8,x
  sta OAMHI+12,x
  seta8


  ; Write the attributes and the tile number at the same time
  ; in one 16-bit chunk
  lda player_facing
  ora #$30  ; priority
  xba
  lda #0
  asl a
  seta16
  sta OAM_ATTR+(4*0),x
  ora #3
  sta OAM_ATTR+(4*1),x
  dea
  sta OAM_ATTR+(4*2),x
  ora #$10
  sta OAM_ATTR+(4*3),x


  sep #$21  ; seta8 + sec (for following subtract)
  lda player_yhi
  sec
  sbc #32
  sta OAM_YPOS+(4*0),x
  clc
  adc #16
  sta OAM_YPOS+(4*1),x
  sta OAM_YPOS+(4*2),x
  clc
  adc #8
  sta OAM_YPOS+(4*3),x

  ; The character uses two display list entries (8 bytes).
  ; Mark them used.
  txa
  clc
  adc #4*4
  sta oam_used
  rtl
.endproc

.segment "RODATA4"

; sprite tiles
objtiles_bin:
  .incbin "obj/snes/swinging2.chrsfc"
objtiles_bin_size = * - objtiles_bin

; The sprite palette
objpalette:
;  .word               RGB(16, 8, 0),RGB( 6, 6, 6),RGB(12,12,12)
;  .word RGB(18,18,18),RGB(23,23,23),RGB(16, 0, 0),RGB(24, 0, 0)
;  .word RGB(20,16,14),RGB(31,22,20),RGB(21, 0, 0),RGB(31, 0, 0)
;  .word RGB( 0, 0,15),RGB( 0, 0, 3),RGB(21, 0, 0),RGB(31, 0, 0)
  ; Maffi palette
  .word               RGB(0, 0, 0), RGB(31,31,31),RGB( 3, 3, 3)
  .word RGB(8, 5,15),RGB(6, 6, 6),RGB(12, 7, 22),RGB(15, 8, 31)
  .word RGB(13, 13, 13),RGB(17, 17, 17),RGB(17, 18, 31),RGB(24, 24, 24)
  .word RGB(27, 27, 28),RGB(0, 0, 0),RGB(0, 0, 0),RGB(0, 0, 0)

objpalette_size = * - objpalette

