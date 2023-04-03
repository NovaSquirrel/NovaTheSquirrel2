; Super Princess Engine
; Copyright (C) 2019-2023 NovaSquirrel
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
.include "../snes.inc"
.include "../global.inc"
.include "../graphicsenum.s"
.include "../paletteenum.s"
.include "../portraitenum.s"
.include "m7blockenum.s"
.include "m7global.s"
.smart
.importzp hm_node

.importzp angle, scale, scale2, posx, posy, cosa, sina, math_a, math_b, math_p, math_r, det_r, texelx, texely, screenx, screeny
.importzp mode7_m7t
.importzp pv_l0, pv_l1, pv_s0, pv_s1, pv_sh, pv_interp, pv_negate
.import mode7_bg2hofs, mode7_bg2vofs, mode7_hdma_en, mode7_hofs, mode7_vofs, pv_buffer, mode7_m7x, mode7_m7y

.import pv_texel_to_screen, pv_rebuild, pv_set_origin, pv_setup_for_ground, pv_set_ground_origin

.export Mode7LevelMap, Mode7LevelMapBelow

; Where to draw Maffi
MODE_Y_SX = 128
MODE_Y_SY = 168

.segment "ZEROPAGE"
.exportzp mode7_height
mode7_height: .res 1

.segment "BSS"
; Expose these for reuse by other systems
Mode7PlayerHeight: .res 2
Mode7PlayerVSpeed: .res 2
Mode7PlayerJumpCancel: .res 2

Mode7ScrollX:    .res 2
Mode7ScrollY:    .res 2
Mode7PlayerX:    .res 2
Mode7PlayerY:    .res 2
Mode7RealAngle:  .res 2 ; 0-31
Mode7Direction:  .res 2 ; 0-3
Mode7MoveDirection: .res 2 ; 0-3
Mode7Turning:    .res 2
Mode7TurnWanted: .res 2
Mode7SidestepWanted: .res 2
Mode7ChipsLeft:      .res 2
Mode7Portrait = TouchTemp
Mode7HappyTimer:  .res 2
Mode7Oops:        .res 2
Mode7ShadowHUD = Scratchpad
Mode7LastPositionPtr: .res 2
Mode7ForceMove: .res 2
Mode7IceDirection: .res 2 ; Last direction used

Mode7DoLookAround: .res 2
Mode7LookAroundOffsetX = FG2OffsetX ; Reuse
Mode7LookAroundOffsetY = FG2OffsetY
; Maybe I can reuse more of the above?? Have some sort of overlay system

PORTRAIT_NORMAL = $80 | OAM_PRIORITY_3
PORTRAIT_OOPS   = $88 | OAM_PRIORITY_3
PORTRAIT_HAPPY  = $A0 | OAM_PRIORITY_3
PORTRAIT_BLINK  = $A8 | OAM_PRIORITY_3
PORTRAIT_LOOK   = $C0 | OAM_PRIORITY_3

.segment "C_Mode7Game"

.export StartMode7Level
.proc StartMode7Level
  phk
  plb

  setaxy16
  sta StartedLevelNumber

  ; Clear variables
  stz Mode7ScrollX
  stz Mode7ScrollY
  stz Mode7RealAngle
  stz Mode7Direction
  stz Mode7PlayerX
  stz Mode7PlayerY
  stz Mode7ChipsLeft
  stz Mode7CheckpointChips
  stz Mode7Tools
  stz Mode7Keys
  stz Mode7Keys+2

  stz Mode7PlayerHeight
  stz Mode7PlayerVSpeed
  stz Mode7PlayerJumpCancel

  ldx #.loword(Mode7LevelMapBelow)
  ldy #64*64
  jsl MemClear7F

  seta8
  ; Transparency outside the mode 7 plane
  lda #M7_BORDER00 ;M7_NOWRAP
  sta M7SEL
  ; Prepare LevelBlockPtr's bank byte
  lda #^Mode7LevelMap
  sta LevelBlockPtr+2

  ; The HUD goes on layer 2 and goes at $c000
  lda #0 | (($6000 >> 10)<<2) ; Right after the sprite graphics
  sta NTADDR+1
  ; Base for the tiles themselves are $c000 too
  lda #($6000>>12) | (($6000>>12)<<4)
  sta BGCHRADDR+0



  ; Upload palettes
  stz CGADDR
  ; Write black
;  stz CGDATA
;  stz CGDATA
  ; Old sky palette before I went with the gradient instead
  lda #<RGB(15,23,31)
  sta CGDATA
  lda #>RGB(15,23,31)
  sta CGDATA
  seta16
  ; ---
  lda #DMAMODE_CGDATA
  ldx #$ffff & Mode7Palette
  ldy #90*2
  jsl ppu_copy

  ; Common sprites
  lda #Palette::Mode7HUDSprites
  pha
  ldy #9
  jsl DoPaletteUpload
  pla
  ; And upload the common palette to the last background palette
  ldy #7
  jsl DoPaletteUpload
  lda #GraphicsUpload::Mode7HUDSprites
  jsl DoGraphicUpload
  lda #GraphicsUpload::MaffiM7TempWalk
  jsl DoGraphicUpload
  lda #GraphicsUpload::Mode7HUD
  jsl DoGraphicUpload
  lda #Palette::SPMaffi
  ldy #8
  jsl DoPaletteUpload


  .import DoPortraitUpload
  lda #Portrait::Maffi
  ldy #$4800
  jsl DoPortraitUpload
  ina
  ldy #$4880
  jsl DoPortraitUpload
  ina
  ldy #$4a00
  jsl DoPortraitUpload
  ina
  ldy #$4a80
  jsl DoPortraitUpload
  ; Binoculars
  ina
  ina
  ldy #$4c00
  jsl DoPortraitUpload

  ; Put FGCommon in the last background palette for the HUD
  lda #Palette::FGCommon
  ldy #7
  jsl DoPaletteUpload

  ; -----------------------------------

  ; Upload graphics
  .import LZ4_DecompressToMode7Tiles, SFX_LZ4_decompress
  ldy #DMAMODE_PPUHIDATA
  sty DMAMODE
  seta8
  lda #^Mode7Tiles
  sta DMAADDRBANK
  ldy #.loword(Mode7Tiles)
  sty DMAADDR
  ldy #CommonTilesetLength
  sty DMALEN

  stz PPUADDR+0
  stz PPUADDR+1
  lda #1
  sta COPYSTART
  seta16

  ; -----------------------------------

  ; Put a checkerboard map in the alternate level map
  ldx #0
  lda #$0102
CheckerLoop:
  ldy #32
  xba
: sta f:LevelBufAlt,x
  inx
  inx
  dey
  bne :-
  cpx #4096
  bne CheckerLoop

  ; Read the level pointer that was passed in from the overworld map
  seta8
  hm_node = 0
  lda LevelHeaderPointer+0
  sta hm_node+0
  lda LevelHeaderPointer+1
  sta hm_node+1
  lda LevelHeaderPointer+2
  sta hm_node+2

  ; Starting X pos
  lda [hm_node]
  .repeat 4
    asl
    rol posx+3
  .endrep
  add #$08
  sta posx+2
  inc16 hm_node

  ; Starting Y pos
  lda [hm_node]
  .repeat 4
    asl
    rol posy+3
  .endrep
  add #$08
  sta posy+2
  inc16 hm_node

  ; Direction
  lda [hm_node]
  sta Mode7Direction
  .repeat 4
    asl
  .endrep
  sta Mode7RealAngle
  inc16 hm_node

  ; Decompress the level map
  seta16
  ldx hm_node
  ldy #.loword(Mode7LevelMap)
  lda LevelHeaderPointer+2
  and #255
  ora #(^Mode7LevelMap <<8)
  jsl SFX_LZ4_decompress
  .a16

  ; Add in the checkerboard
  seta8
  ldx #4095
CheckerboardAdd:
  lda f:Mode7LevelMap,x
  cmp #1
  bne :+
    lda f:LevelBufAlt,x
    sta f:Mode7LevelMap,x
  :
  dex
  bne CheckerboardAdd
  seta16

RestoredFromCheckpoint:
  stz Mode7Turning
  stz Mode7TurnWanted
  stz Mode7SidestepWanted
  stz Mode7HappyTimer
  stz Mode7Oops

  stz Mode7LastPositionPtr
  stz Mode7ForceMove
  stz Mode7IceDirection ; Probably don't need to init this one but whatever

  stz Mode7DoLookAround
  stz Mode7LookAroundOffsetX
  stz Mode7LookAroundOffsetY

  ldx #ActorStart
  ldy #ActorEnd-ActorStart
  jsl MemClear
  ldx #BlockUpdateAddress
  ldy #BlockUpdateDataEnd-BlockUpdateAddress
  jsl MemClear

  ldx #0
  jsl ppu_clear_oam

  ; Clear the HUD's nametable
  ldx #$6000
  ldy #64
  jsl ppu_clear_nt
  .a8
  tdc ; Clear all of accumulator

  ; .----------------------------------
  ; | Render Mode7LevelMap
  ; '----------------------------------

  ; Increment the address on low writes, as the tilemap is in low VRAM bytes
  stz PPUADDR+0
  stz PPUADDR+1
  stz PPUCTRL

  ldx #0
  lda #64 ; Row counter
  sta 0
RenderMapLoop:
  ; Top row
  ldy #64
RenderTopLoop:
  lda f:Mode7LevelMap,x
  ; Could chips while this is going on
  cmp #Mode7Block::Collect
  bne DontIncreaseChipCounter
    pha
    lda Mode7CheckpointChips ; Don't add if coming in from a checkpoint and it's already been calculated
    bne :+
      sed
      lda Mode7ChipsLeft
      adc #0 ; assert((PS & 1) == 1) Carry will be set
      sta Mode7ChipsLeft
      cld
    :
    pla
DontIncreaseChipCounter:

  phx
  tax
  lda M7BlockTopLeft,x
  sta PPUDATA
  lda M7BlockTopRight,x
  sta PPUDATA
  plx
  inx
  dey
  bne RenderTopLoop

  seta16
  txa
  sub #64
  tax
  tdc
  seta8

  ; Bottom row
  ldy #64
: lda f:Mode7LevelMap,x
  phx
  tax
  lda M7BlockBottomLeft,x
  sta PPUDATA
  lda M7BlockBottomRight,x
  sta PPUDATA
  plx
  inx
  dey
  bne :-

  dec 0
  bne RenderMapLoop

  ; Restore it to incrementing address on high writes
  lda #INC_DATAHI
  sta PPUCTRL

  ; -----------------------------------

  seta8
  lda #^Mode7IRQ
  sta IRQHandler+2
  sta NMIHandler+2
  ; -----------------------

  lda #$8000 >> 14
  sta OBSEL       ; sprite CHR at $8000, sprites are 8x8 and 16x16

  lda #VBLANK_NMI|AUTOREAD
  sta PPUNMI

  setaxy16
  lda #.loword(Mode7IRQ)
  sta IRQHandler+0
  lda #.loword(Mode7NMI)
  sta NMIHandler+0

  jsr Mode7MakeCheckpoint
.endproc
; Falls through into Mode7MainLoop

.proc Mode7MainLoop
	seta8
	stz mode7_height
Loop:
	setaxy16
	inc framecount

	jsl prepare_ppu_copy_oam_partial
	seta8
	jsl WaitVblank
	; AXY size preserved, so still .a8 .i16
	jsl ppu_copy_oam_partial
	.a8

	; ---------------------------------------------
	; - Mode 7 vblank tasks
	; ---------------------------------------------
	; Parallax
	.if 0
		seta16
		lda posx+2
		lsr
		;  lsr
		and #%111   ; ........ .....xxx
		xba         ; .....xxx ........
		lsr         ; ......xx x.......
		sta 0

		lda posy+2
		neg
		lsr
		;  lsr
		and #%111   ; ........ .....yyy
		asl         ; ........ ....yyy.
		asl         ; ........ ...yyy..
		asl         ; ........ ..yyy...
		ora 0       ; ......xx x.yyy...
		add #.loword(Mode7Parallax)
		sta DMAADDR
		seta8

		ldy #0
		sty PPUADDR
		ldy #DMAMODE_PPUHIDATA
		sty DMAMODE
		lda #^Mode7Parallax
		sta DMAADDRBANK
		ldy #64
		sty DMALEN

		lda #1
		sta COPYSTART
	.endif

	setaxy16
	.import mode7_hdma, mode7_hdma_en
	phb
	ldx #.loword(mode7_hdma)
	ldy #$4300
	lda #(16*8)-1
	mvn #^mode7_hdma,#^004300
	plb

	seta8

	lda mode7_hdma_en
	sta HDMASTART

	; Write to registers
	lda mode7_m7x+0
	sta M7X
	lda mode7_m7x+1
	sta M7X
	;---
	lda mode7_m7y+0
	sta M7Y
	lda mode7_m7y+1
	sta M7Y
	;---
	lda mode7_hofs+0
	sta BG1HOFS
	lda mode7_hofs+1
	sta BG1HOFS
	lda mode7_vofs+0
	sta BG1VOFS
	lda mode7_vofs+1
	sta BG1VOFS
	;---
	lda #$0F
	sta PPUBRIGHT

	stz CGWSEL      ; Color math is always enabled
	lda #$23        ; Enable additive blend on BG1 + BG2 + backdrop
	sta CGADSUB

	; ---------------------------------------------
	; - Calculate stuff for the next frame!
	; ---------------------------------------------
	jsl WaitKeysReady ; Also clears OamPtr

	seta16
	setxy8
	; Allow jumping
	lda Mode7PlayerHeight
	cmp #$400
	bcs :+
	lda keynew
	and #KEY_B
	beq :+
		lda #.loword($200) ; other values tried: $240, $400
		sta Mode7PlayerVSpeed
		stz Mode7PlayerJumpCancel
	:

	; Apply gravity
	lda Mode7PlayerVSpeed
	sub #$8 ; other values tried: $10
	sta Mode7PlayerVSpeed
	add Mode7PlayerHeight
	sta Mode7PlayerHeight
	bpl :+
		stz Mode7PlayerVSpeed
		stz Mode7PlayerHeight
		lda #0
	:
	seta8
	xba
	sta mode7_height
	seta16

	; Allow canceling jumps
	lda keydown
	and #KEY_B
	bne :+
	lda Mode7PlayerVSpeed
	bmi :+
	lda Mode7PlayerJumpCancel
	bne :+
		inc Mode7PlayerJumpCancel
		lsr Mode7PlayerVSpeed
		lsr Mode7PlayerVSpeed
	:

	; rotate with left/right
	ldx z:angle
	lda keydown
	bit #KEY_LEFT
	beq :+
		inx
		bit #KEY_Y
		beq :+
			inx
	:
	lda keydown
	bit #KEY_RIGHT
	beq :+
		dex
		bit #KEY_Y
		beq :+
			dex
	:
	stx z:angle

	; Generate perspective, unless you're on the ground
	; in which case use precalculated perspective
	; --------------------
	lda z:mode7_height
	and #$00FF
	beq OnGround
		; set horizon
		lsr
		add #48 ; Was originally 32
		tax
		sta z:pv_l0 ; First scanline. l0 = 48+(mode7_height/2)  [48-112]
		ldx #224
		stx z:pv_l1 ; Last scanline + 1

		; set view scale
		lda z:mode7_height
		and #$00FF
		asl
	;	asl ; Added by Nova for camera effect
		add #384
		sta z:pv_s0 ; 384 + (height*2)    [384-640]

		lda z:mode7_height
		and #$00FF
		lsr
	;	lsr ; Added by Nova for camera effect
		adc #64
		sta z:pv_s1 ; 64 + (height/2)     [64-128]

		stz z:pv_sh ; dependent-vertical scale

		ldx #2
		stx z:pv_interp ; 2x interpolation
		jsr pv_rebuild
		bra :+
	OnGround:
		jsr pv_setup_for_ground
	:


	; up/down moves player (depends on generated rotation matrix)
	lda keydown
	and #KEY_DOWN ; down
	beq :+
		; X += B * 2
		lda z:mode7_m7t + 2 ; B
		asl
		pha
		add z:posx+1
		sta z:posx+1
		pla
		jsr sign
		adc z:posx+3
		and #$0003 ; wrap to 0-1023
		sta z:posx+3

		; Y += D * 2
		lda z:mode7_m7t + 6 ; D
		asl
		pha
		add z:posy+1
		sta z:posy+1
		pla
		jsr sign
		adc z:posy+3
		and #$0003
		sta z:posy+3
	:

	lda keydown
	and #KEY_UP ; up
	beq :+
		; X -= B * 2
		lda #0
		sub z:mode7_m7t + 2 ; B
		asl
		pha
		add z:posx+1
		sta z:posx+1
		pla
		jsr sign
		adc z:posx+3
		and #$0003
		sta z:posx+3

		; Y -= D * 2
		lda #0
		sub z:mode7_m7t + 6 ; D
		asl
		pha
		add z:posy+1
		sta z:posy+1
		pla
		jsr sign
		adc z:posy+3
		and #$0003
		sta z:posy+3
	:

	setxy8
	; Set origin
	ldy #MODE_Y_SY ; place focus at center of scanline SY
	lda z:mode7_height
	and #$00FF
	beq :+
	jsr pv_set_origin
	bra :++
:	jsr pv_set_ground_origin
	:


	jsr Mode7DrawPlayer
	.a16
	.i16

	.if 0
	  ; TEST
	  lda #150
	  sta texelx
	  sta texely
	  jsr pv_texel_to_screen
	  lda screeny
	  cmp #$5FFF
	  beq :+
		ldy OamPtr

		lda #$40|OAM_PRIORITY_2
		sta OAM_TILE,y
		seta8
		lda screenx
		sta OAM_XPOS,y
		lda screeny
		sta OAM_YPOS,y

		lda #$00
		sta OAMHI+1,y
		seta16

		iny
		iny
		iny
		iny
		sty OamPtr
	  :
	.endif

	.if 0
	  lda #160
	  sta texelx
	  sta texely
	  jsr pv_texel_to_screen
	  lda screeny
	  cmp #$5FFF
	  beq :+
		ldy OamPtr

		lda #$40|OAM_PRIORITY_2
		sta OAM_TILE,y
		seta8
		lda screenx
		sta OAM_XPOS,y
		lda screeny
		sta OAM_YPOS,y

		lda #$00
		sta OAMHI+1,y
		seta16

		iny
		iny
		iny
		iny
		sty OamPtr
	  :
	.endif

	.if 0
	  lda #170
	  sta texelx
	  sta texely
	  jsr pv_texel_to_screen
	  lda screeny
	  cmp #$5FFF
	  beq :+
		ldy OamPtr

		lda #$40|OAM_PRIORITY_2
		sta OAM_TILE,y
		seta8
		lda screenx
		sta OAM_XPOS,y
		lda screeny
		sta OAM_YPOS,y

		lda #$00
		sta OAMHI+1,y
		seta16

		iny
		iny
		iny
		iny
		sty OamPtr
	  :
	.endif

	jsl ppu_pack_oamhi_partial
	.a8 ; (does seta8)

	lda #$0F
	sta PPUBRIGHT

	jmp Loop
.endproc


.proc Mode7DrawPlayer
  setxy16
  seta16
  lda #PORTRAIT_NORMAL
  sta Mode7Portrait

  ; Blink sometimes!
  lda framecount
  lsr
  lsr
  lsr
  and #63
  beq @Blink
  cmp #2
  bne :+
@Blink:
    lda #PORTRAIT_BLINK
    sta Mode7Portrait
  :

  ; Draw the player
  ldy OamPtr
  lda keydown
  and #KEY_UP|KEY_DOWN|KEY_L|KEY_R
  bne :+
    lda #4
    bra :++
  :
  lda framecount
  lsr
: and #%1100
  ora #OAM_PRIORITY_2
  sta 0
  sta OAM_TILE+(4*0),y
  ora #$02
  sta OAM_TILE+(4*1),y
  lda 0
  ora #$20
  sta OAM_TILE+(4*2),y
  ora #$02
  sta OAM_TILE+(4*3),y

  ; Portrait
  lda Mode7Portrait
  sta OAM_TILE+(4*4),y
  ora #$02
  sta OAM_TILE+(4*5),y
  lda Mode7Portrait
  ora #$04
  sta OAM_TILE+(4*6),y
  ora #$02
  sta OAM_TILE+(4*7),y

  ; Shadow
  lda mode7_height
  lsr
  lsr
  lsr
  lsr
  and #%1110
  ora #$40|OAM_PRIORITY_2
  sta 0
  sta OAM_TILE+(4*8),y
  ina
  sta OAM_TILE+(4*9),y
  lda framecount
  lsr
  bcc :+
    lda 0
    ora #OAM_XFLIP
    sta OAM_TILE+(4*9),y
    ina
    sta OAM_TILE+(4*8),y    
  :

  seta8
  ; Player is made up of four sprites
  lda #MODE_Y_SX-16
  sta OAM_XPOS+(4*0),y
  sta OAM_XPOS+(4*2),y

  lda #MODE_Y_SY - 16 + 1
  sub mode7_height
  sta OAM_YPOS+(4*2),y
  sta OAM_YPOS+(4*3),y
  sub #16
  sta OAM_YPOS+(4*0),y
  sta OAM_YPOS+(4*1),y

  lda #MODE_Y_SX
  sta OAM_XPOS+(4*1),y
  sta OAM_XPOS+(4*3),y

  ; Portrait position
  lda #10
  sta OAM_XPOS+(4*4),y
  sta OAM_XPOS+(4*6),y
  sta OAM_YPOS+(4*4),y
  sta OAM_YPOS+(4*5),y
  lda #10+16
  sta OAM_XPOS+(4*5),y
  sta OAM_XPOS+(4*7),y
  sta OAM_YPOS+(4*6),y
  sta OAM_YPOS+(4*7),y

  ; Player's shadow
  lda #MODE_Y_SX-8
  sta OAM_XPOS+(4*8),y
  lda #MODE_Y_SX
  sta OAM_XPOS+(4*9),y
  lda #MODE_Y_SY-4
  sta OAM_YPOS+(4*8),y
  sta OAM_YPOS+(4*9),y

  lda #$02
  sta OAMHI+1+(4*0),y
  sta OAMHI+1+(4*1),y
  sta OAMHI+1+(4*2),y
  sta OAMHI+1+(4*3),y
  ; Portrait
  sta OAMHI+1+(4*4),y
  sta OAMHI+1+(4*5),y
  sta OAMHI+1+(4*6),y
  sta OAMHI+1+(4*7),y
  ; Shadow
  lda #$00
  sta OAMHI+1+(4*8),y
  sta OAMHI+1+(4*9),y
  seta16
  tya
  add #10*4
  sta OamPtr
  rts
.endproc

.a16
.i16
.proc Mode7DrawInventory
CurrentXY = 2
Tools = 4
KeyCount = 6
Attr = OAM_PRIORITY_2 | OAM_COLOR_1
  lda #(11*8) | ((2*8)<<8) ; Y is second byte
  sta CurrentXY
  lda Mode7Tools
  sta Tools

  ldx OamPtr

  ; Draw footwear
  lsr Tools ; Fire boots
  bcc :+
    lda #Attr|$40
    jsr AddOneSprite
  :
  lsr Tools ; Flippers
  bcc :+
    lda #Attr|$42
    jsr AddOneSprite
  :
  lsr Tools ; Suction boots
  bcc :+
    lda #Attr|$44
    jsr AddOneSprite
  :
  lsr Tools ; Iceskates
  bcc :+
    lda #Attr|$46
    jsr AddOneSprite
  :

  ; Draw keys
  ldy #0
KeyLoop:
  lda Mode7Keys,y
  and #255
  beq NoKeys
  tya
  asl
  adc #Attr|$48
  jsr AddOneSprite
NoKeys:
  iny
  cpy #4
  bne KeyLoop

  stx OamPtr
  rts

AddOneSprite:
  sta OAM_TILE,x ; Gets attribute too
  lda CurrentXY
  sta OAM_XPOS,x ; Gets Y too
  lda #$0200     ; 16x16
  sta OAMHI,x
  inx
  inx
  inx
  inx

  lda CurrentXY
  add #16
  sta CurrentXY
  rts
.endproc

; Up, Right, Down, Left?
ForwardX:
  .word 0, .loword(-2), 0, .loword(2)
ForwardY:
  .word .loword(-2), 0, .loword(2), 0
ForwardXTile:
  .word 0, .loword(-16), 0, .loword(16)
ForwardYTile:
  .word .loword(-16), 0, .loword(16), 0
ForwardWallBitOutside:
  .word M7_BLOCK_SOLID_U, M7_BLOCK_SOLID_R, M7_BLOCK_SOLID_D, M7_BLOCK_SOLID_L
ForwardWallBitInside:
  .word M7_BLOCK_SOLID_D, M7_BLOCK_SOLID_L, M7_BLOCK_SOLID_U, M7_BLOCK_SOLID_R

ForwardPtrTile:
  .word .loword(-64), .loword(-1), .loword(64), .loword(1)

; For the lookaround code above in the main loop
.a16
.proc AddLookAroundDirection
  and #3
  asl
  tax
  lda ForwardX,x
  add Mode7LookAroundOffsetX
  sta Mode7LookAroundOffsetX
  lda ForwardY,x
  add Mode7LookAroundOffsetY
  sta Mode7LookAroundOffsetY
  rts
.endproc

.include "m7palettedata.s"


.proc Mode7IRQ
  pha
  php
  seta8
  ; f: is used because if MVN gets interrupted then the data bank will be $7F
  lda f:TIMESTATUS ; Acknowledge interrupt
  lda #7
  sta f:BGMODE
  lda #%00010001  ; enable sprites, plane 0
  sta f:BLENDMAIN
  plp
  pla
  rti
.endproc

.a16
.i16
.export Mode7MakeCheckpoint
.proc Mode7MakeCheckpoint
  lda Mode7PlayerX
  sta Mode7CheckpointX
  lda Mode7PlayerY
  sta Mode7CheckpointY
  lda Mode7Direction
  sta Mode7CheckpointDir
  lda Mode7ChipsLeft
  sta Mode7CheckpointChips
  lda Mode7Keys+0
  sta Mode7CheckpointKeys+0
  lda Mode7Keys+2
  sta Mode7CheckpointKeys+2
  lda Mode7Tools
  sta Mode7CheckpointTools

  phb
  ldx #.loword(Mode7LevelMap)
  ldy #.loword(Mode7LevelMapCheckpoint)
  lda #(64*64*2)-1
  mvn Mode7LevelMap, Mode7LevelMapCheckpoint
  plb
  rts
.endproc

.proc Mode7Die
  seta8
  jsl WaitVblank
  lda #FORCEBLANK
  sta PPUBRIGHT
  stz BLENDMAIN
  seta16
  lda StartedLevelNumber
.endproc
  ; Fall into next routine
.proc RestoreCheckpoint
  setaxy16
  lda Mode7CheckpointX
  sta Mode7PlayerX
  lda Mode7CheckpointY
  sta Mode7PlayerY
  lda Mode7CheckpointDir
  sta Mode7Direction
  .repeat 4
    asl
  .endrep
  sta Mode7RealAngle
  lda Mode7CheckpointChips
  sta Mode7ChipsLeft
  lda Mode7CheckpointKeys+0
  sta Mode7Keys+0
  lda Mode7CheckpointKeys+2
  sta Mode7Keys+2
  lda Mode7CheckpointTools
  sta Mode7Tools

  phb
  ldx #.loword(Mode7LevelMapCheckpoint)
  ldy #.loword(Mode7LevelMap)
  lda #(64*64*2)-1
  mvn Mode7LevelMapCheckpoint, Mode7LevelMap
  plb

  jmp StartMode7Level::RestoredFromCheckpoint
.endproc

.proc CalculateScroll
  lda Mode7PlayerX
  add Mode7LookAroundOffsetX
  sub #7*16+8
  sta Mode7ScrollX
  lda Mode7PlayerY
  add Mode7LookAroundOffsetY
  sub #11*16+8
  sta Mode7ScrollY
  rts
.endproc

GradientTable:     ; 
   .byt $02, $9F   ; 
   .byt $07, $9E   ; 
   .byt $08, $9D   ; 
   .byt $07, $9C   ; 
   .byt $07, $9B   ; 
   .byt $07, $9A   ; 
   .byt $08, $99   ; 
   .byt $07, $98   ; 
   .byt $07, $97   ; 
   .byt $07, $96   ; 
   .byt $08, $95   ; 
   .byt $07, $94   ; 
   .byt $07, $93   ; 
   .byt $07, $92   ; 
   .byt $07, $91   ; 
   .byt $07, $90   ; 
   .byt $08, $8F   ; 
   .byt $07, $8E   ; 
   .byt $07, $8D   ; 
   .byt $07, $8C   ; 
   .byt $08, $8B   ; 
   .byt $07, $8A   ; 
   .byt $07, $89   ; 
   .byt $07, $88   ; 
   .byt $08, $87   ; 
   .byt $07, $86   ; 
   .byt $07, $85   ; 
   .byt $07, $84   ; 
   .byt $08, $83   ; 
   .byt $07, $82   ; 
   .byt $07, $81   ; 
   .byt $05, $80   ; 
   .byt $00        ; 

.segment "Mode7Tiles"
.export Mode7Tiles
Mode7Tiles:
.incbin "../../tilesetsX/M7Tileset.chr", 0, CommonTilesetLength

Mode7Parallax:
.incbin "../../tilesetsX/M7Parallax.chr"



.segment "C_Mode7Game"

.proc Mode7NMI
  seta8
  pha
  lda #1
  sta f:BGMODE
;  lda #%00010010  ; enable sprites, plane 1
  lda #%00000011  ; enable sprites, plane 1
  sta f:BLENDMAIN
  pla

  plb
  rti
.endproc

.a16
.proc sign ; A = value, returns either 0 or $FFFF, preserves flags
	;.i any
	php
	cmp #$8000
	bcs :+
		lda #0
		plp
		rts
:	lda #$FFFF
	plp
	rts
.endproc
