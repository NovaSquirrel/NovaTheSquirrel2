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

; VRAM map:
; 0000-3FFF: Mode 7
; 4000-5FFF: Sprites
; 6000-7BFF: Clouds tiles
; 7C00-7FFF: Clouds map, 32x32

HALF_CAMERA_RATE = 1
FORCEFIELD_FLOOR_TILE = 1
;CONSISTENT_CAMERA_HEIGHT = 1
;COARSE_CAMERA_TURN = 1
;FORCEFIELD_PILLAR = 1
SMOOTHER_TURNING = 1
.include "../snes.inc"
.include "../global.inc"
.include "../graphicsenum.s"
.include "../paletteenum.s"
.include "../portraitenum.s"
.include "m7playerframe.inc"
.include "m7blockenum.s"
.include "m7global.s"
.smart
.importzp hm_node

.importzp angle, scale, scale2, M7PosX, M7PosY, cosa, sina, math_a, math_b, math_p, math_r, det_r, texelx, texely, screenx, screeny
.importzp mode7_m7t
.importzp pv_l0, pv_l1, pv_s0, pv_s1, pv_sh, pv_interp, pv_negate
.import pv_buffer, mode7_m7x, mode7_m7y

.import pv_texel_to_screen, pv_rebuild, pv_set_origin, pv_setup_for_ground, pv_set_ground_origin

.import Mode7CallBlockStepOn, Mode7CallBlockStepOff, Mode7CallBlockBump, Mode7CallBlockJumpOn, Mode7CallBlockJumpOff, Mode7CallBlockTouching
.import Mode7PlayerGraphics
.import Mode7ChangeBlockAppearance

; Where to draw Maffi
MODE7_PLAYER_SX = 128
MODE7_PLAYER_SY = 168

.segment "ZEROPAGE"
.exportzp mode7_height
mode7_height: .res 1

.segment "BSS"
.export Mode7PlayerHeight, Mode7PlayerVSpeed, Mode7PlayerJumpCancel, Mode7PlayerJumping
; Expose these for reuse by other systems
Mode7PlayerHeight: .res 2
Mode7PlayerVSpeed: .res 2
Mode7PlayerJumpCancel: .res 2
Mode7PlayerJumping: .res 2

Mode7ChipsLeft:      .res 2
Mode7Portrait = TouchTemp
Mode7HappyTimer:  .res 2
Mode7Oops:        .res 2
Mode7ShadowHUD = Scratchpad

Mode7HaveBlock:  .res 2

Mode7ShowForcefield: .res 2
Mode7ForcefieldPointer: .res 2
Mode7ForcefieldTimer: .res 2
Mode7Acceleration: .res 2
Mode7SideAcceleration: .res 2
Mode7TurnAcceleration: .res 2

;Mode7LastPositionPtr: .res 2
;Mode7ForceMove: .res 2

;Mode7DoLookAround: .res 2
;Mode7LookAroundOffsetX = FG2OffsetX ; Reuse
;Mode7LookAroundOffsetY = FG2OffsetY
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
  stz Mode7ChipsLeft
  stz Mode7CheckpointChips
  stz Mode7Tools
  stz Mode7Keys
  stz Mode7Keys+2
  stz GenericUpdateLength
  stz ToggleSwitch1 ; and ToggleSwitch2
  stz Mode7HaveBlock
  stz Mode7Acceleration
  stz Mode7SideAcceleration

  stz Mode7PlayerHeight
  stz Mode7PlayerVSpeed
  stz Mode7PlayerJumpCancel
  stz Mode7PlayerJumping

  stz Mode7ShowForcefield
  stz Mode7ForcefieldTimer

  ldx #.loword(Mode7LevelMapBelow)
  ldy #64*64
  jsl MemClear7F

  seta8
  lda #4
  sta PlayerHealth

  ; Transparency outside the mode 7 plane
  lda #M7_BORDER00 ;M7_NOWRAP
  sta M7SEL
  ; Prepare LevelBlockPtr's bank byte
  lda #^Mode7LevelMap
  sta LevelBlockPtr+2

  ; The HUD goes on layer 2 and goes at the end of video RAM
  lda #0 | (($7c00 >> 10)<<2)
  sta NTADDR+1
  ; Base for the tiles themselves are $6000
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
  ldy #93*2
  jsl ppu_copy

  lda #GraphicsUpload::Mode7HUDSprites
  jsl DoGraphicUpload
  lda #GraphicsUpload::Mode7Sprites
  jsl DoGraphicUpload
  lda #GraphicsUpload::BGMode7Clouds
  jsl DoGraphicUpload
  lda #GraphicsUpload::MapBGMode7Clouds
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
  pha
  ldy #7
  jsl DoPaletteUpload
  pla
  ; Also the second sprite palette
  ldy #9
  jsl DoPaletteUpload
  ; HUD sprites too
  lda #Palette::Mode7HUDSprites
  ldy #10
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
  ldy #Mode7TilesEnd-Mode7Tiles
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
    rol M7PosX+2
  .endrep
  add #$08
  sta M7PosX+1
  inc16 hm_node

  ; Starting Y pos
  lda [hm_node]
  .repeat 4
    asl
    rol M7PosY+2
  .endrep
  add #$08
  sta M7PosY+1
  inc16 hm_node

  ; Direction
  lda [hm_node]
  .repeat 6
    asl
  .endrep
  sta angle
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
  stz Mode7HappyTimer
  stz Mode7Oops

;  stz Mode7LastPositionPtr
;  stz Mode7ForceMove

;  stz Mode7DoLookAround
;  stz Mode7LookAroundOffsetX
;  stz Mode7LookAroundOffsetY

  stz Mode7DynamicTileUsed+0
  stz Mode7DynamicTileUsed+2
  stz Mode7DynamicTileUsed+4
  stz Mode7DynamicTileUsed+6

  ldx #ActorStart
  ldy #ActorEnd-ActorStart
  jsl MemClear
  ldx #BlockUpdateAddress
  ldy #BlockUpdateDataEnd-BlockUpdateAddress
  jsl MemClear

  ldx #0
  jsl ppu_clear_oam

  ; Clear the HUD's nametable
;  ldx #$6000
;  ldy #64
;  jsl ppu_clear_nt
  seta8
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

  lda #$4000 >> 13
  sta OBSEL       ; sprite CHR at $4000, sprites are 8x8 and 16x16

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
	stz LevelFadeIn
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

	seta8
	stz PPUCTRL
	seta16
	; Do block updates.
	; The second bytes of the tile numbers aren't normally used, because Mode 7 has 8-bit tile numbers,
	; so they're repurposed here.
	ldx #(BLOCK_UPDATE_COUNT-1)*2
BlockUpdateLoop:
	lda BlockUpdateDataTL+1,x ; Repurposed to be an update size/shape
	and #255
	jeq SkipBlock
	dea
	beq @Square
	dea
	beq @Tall
@Wide:
	jsr Mode7DoBlockUpdateWide
	bra SkipBlock
@Tall:
	jsr Mode7DoBlockUpdateTall
	bra SkipBlock
@Square: ; 2x2
	.a16
	lda BlockUpdateAddress,x
	sta PPUADDR
	seta8
	lda BlockUpdateDataTL,x
	sta PPUDATA
	lda BlockUpdateDataTR,x
	sta PPUDATA
	seta16
	lda BlockUpdateAddress,x ; Move down a row
	add #128
	sta PPUADDR
	seta8
	lda BlockUpdateDataBL,x
	sta PPUDATA
	lda BlockUpdateDataBR,x
	sta PPUDATA
	stz BlockUpdateDataTL+1,x ; Cancel out the block now that it's been written
SkipBlock:
	seta16
	dex
	dex
	bpl BlockUpdateLoop
	seta8
	lda #INC_DATAHI
	sta PPUCTRL

	.i16
	ldx GenericUpdateLength
	beq :+
		stx DMALEN
		ldx #DMAMODE_PPUHIDATA
		stx DMAMODE
		ldx GenericUpdateSource
		stx DMAADDR
		lda GenericUpdateFlags
		sta DMAADDRBANK
		ldx GenericUpdateDestination
		stx PPUADDR

		lda #1
		sta COPYSTART

		; Disable this update
		stz GenericUpdateLength
		stz GenericUpdateLength+1
	:

	; Upload the dynamic tile area
	; TODO: make this conditional, intead of always doing it?
	ldy #DMAMODE_PPUHIDATA
	sty DMAMODE
	lda #^Mode7DynamicTileBuffer
	sta DMAADDRBANK
	ldy #.loword(Mode7DynamicTileBuffer)
	sty DMAADDR
	ldy #32*64
	sty DMALEN
	ldy #(14*16)*64
	sty PPUADDR
	lda #1
	sta COPYSTART

	; Upload the fan frame
	; TODO: Use a more generic system for this?
	lda framecount
	and #3
	bne :+
	ldy #DMAMODE_PPUHIDATA
	sty DMAMODE
	lda #^Mode7FanAnimation
	sta DMAADDRBANK
	ldy #256
	sty DMALEN
	seta16
	lda framecount
	lsr
	lsr
	and #3
	xba
	add #.loword(Mode7FanAnimation)
	sta DMAADDR
	seta8
	ldy #$0500
	sty PPUADDR
	lda #1
	sta COPYSTART
	:

	; Upload the player frame
	ldy #DMAMODE_PPUDATA
	sty DMAMODE
	sty DMAMODE+$10
	lda #^Mode7PlayerGraphics
	sta DMAADDRBANK
	sta DMAADDRBANK+$10
	ldy #256
	sty DMALEN
	sty DMALEN+$10
	seta16
	lda PlayerFrame
	and #255
	xba
	asl
	adc #.loword(Mode7PlayerGraphics)
	sta DMAADDR
	add #256
	sta DMAADDR+$10
	seta8
	; First row
	ldy #$4000
	sty PPUADDR
	lda #1
	sta COPYSTART
	; Second row
	ldy #$4100
	sty PPUADDR
	lda #2
	sta COPYSTART


	; Parallax
	.if 0
		seta16
		lda M7PosX+1
		lsr
		;  lsr
		and #%111   ; ........ .....xxx
		xba         ; .....xxx ........
		lsr         ; ......xx x.......
		sta 0

		lda M7PosY+1
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
	.import mode7_hdma
	phb
	ldx #.loword(mode7_hdma)
	ldy #$4300
	lda #(16*8)-1
	mvn #^mode7_hdma,#^$004300
	plb

	seta8

	lda HDMASTART_Mirror
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
	lda FGScrollXPixels+0
	sta BG1HOFS
	lda FGScrollXPixels+1
	sta BG1HOFS
	lda FGScrollYPixels+0
	sta BG1VOFS
	lda FGScrollYPixels+1
	sta BG1VOFS

	lda Layer2_ScrollXPixels+0
	sta BG2HOFS
	lda Layer2_ScrollXPixels+1
	sta BG2HOFS
	lda Layer2_ScrollYPixels+0
	sta BG2VOFS
	lda Layer2_ScrollYPixels+1
	sta BG2VOFS
	;---
	lda LevelFadeIn
	sta PPUBRIGHT
	cmp #$0f
	beq :+
		ina
	:
	sta LevelFadeIn

	stz CGWSEL      ; Color math is always enabled
	lda #$23        ; Enable additive blend on BG1 + BG2 + backdrop
	sta CGADSUB

	; ---------------------------------------------
	; - Calculate stuff for the next frame!
	; ---------------------------------------------
	jsl WaitKeysReady ; Also clears OamPtr

	setaxy16
	; Allow jumping
	lda Mode7PlayerHeight
	cmp #$400
	bcs :+
	lda keynew
	and #KEY_B
	beq :+
		lda #.loword($200) ; other values tried: $240, $400
		sta Mode7PlayerVSpeed
		sta Mode7PlayerJumping ; Nonzero
		stz Mode7PlayerJumpCancel

		jsr Mode7LevelPtrXYAtPlayer
		jsr Mode7CallBlockJumpOff
	:

;	lda keynew
;	and #KEY_X
;	beq :+
;		lda #Mode7ActorType::ArrowUp
;		ldx M7PosX+1
;		ldy M7PosY+1
;		.import Mode7CreateActor
;		jsr Mode7CreateActor
;	:

	; Apply gravity
	lda Mode7PlayerVSpeed
	sub #$8 ; other values tried: $10
	sta Mode7PlayerVSpeed
	add Mode7PlayerHeight
	sta Mode7PlayerHeight
	cmp #.loword(-$1000)
	bcc DidntLand
		stz Mode7PlayerVSpeed
		stz Mode7PlayerHeight

		lda Mode7PlayerJumping
		stz Mode7PlayerJumping
		beq :+
			jsr Mode7LevelPtrXYAtPlayer
			jsr Mode7CallBlockJumpOn
		:
		lda #0 ; For mode7_height
	DidntLand:
	setaxy8
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

	.ifdef SMOOTHER_TURNING
		lda keydown
		and #KEY_L|KEY_R
		bne @NoDecelerate
		@YesDecelerate:
			lda Mode7TurnAcceleration
			beq @NoDecelerate
			; If negative, make positive
			php ; Save if it was negative
			bpl :+
			  eor #$ffff
			  ina
			:

			dea ; Decrease speed
			bpl :+
				tdc ; Clear accumulator
			:

			plp
			; If it was previously negative, make it negative again
			bpl :+
				eor #$ffff
				ina
			:
			sta Mode7TurnAcceleration
		@NoDecelerate:

		lda keydown
		and #KEY_R
		beq @NoRightAccelerate
			lda Mode7TurnAcceleration
			bmi :+
			cmp #TURN_TABLE_LENGTH
			bcs :++
			:
				inc Mode7TurnAcceleration
			:
		@NoRightAccelerate:

		lda keydown
		and #KEY_L
		beq @NoLeftAccelerate
			lda Mode7TurnAcceleration
			bpl :+
			cmp #.loword(-TURN_TABLE_LENGTH+1)
			bcc :++
			:
				dec Mode7TurnAcceleration
			:
		@NoLeftAccelerate:

		; ---

		lda Mode7TurnAcceleration
		abs
		asl
		tay
		lda TurnAccelerationTable,y
		bit Mode7TurnAcceleration
		bmi :+
			eor #$ffff
			ina
		:
		add z:angle
		and #255
		sta z:angle

		.if 0
		lda Mode7TurnAcceleration
		beq @NoTurnAcceleration
		bit #1
		beq @NoTurnAcceleration
			bpl @TurnRight
			@TurnLeft:
				inx
				lda keydown
				and #KEY_X
				beq :+
					inx
				:
				bra @NoTurnAcceleration
			@TurnRight:
				dex
				lda keydown
				and #KEY_X
				beq :+
					dex
				:
		@NoTurnAcceleration:
		.endif

	.else
		; rotate with left/right
		ldx z:angle

		.ifdef COARSE_CAMERA_TURN
		lda framecount
		lsr
		bcc @NoTurn
		.endif

		lda keydown
		bit #KEY_L
		beq :+
			inx
			.ifdef COARSE_CAMERA_TURN
			inx
			inx
			inx
			.endif
			bit #KEY_Y
			beq :+
				inx
		:
		lda keydown
		bit #KEY_R
		beq :+
			dex
			.ifdef COARSE_CAMERA_TURN
			dex
			dex
			dex
			.endif
			bit #KEY_Y
			beq :+
				dex
		:

		.ifdef COARSE_CAMERA_TURN
		@NoTurn:
		.endif
		stx z:angle
	.endif

	; Generate perspective, unless you're on the ground
	; in which case use precalculated perspective
	; --------------------
	.ifndef CONSISTENT_CAMERA_HEIGHT
	lda z:mode7_height
	and #$00FF
	.ifdef HALF_CAMERA_RATE
		lsr
	.endif
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
		.ifdef HALF_CAMERA_RATE
			lsr
		.endif
		asl
	;	asl ; Added by Nova for camera effect
		add #384
		sta z:pv_s0 ; 384 + (height*2)    [384-640]

		lda z:mode7_height
		and #$00FF
		.ifdef HALF_CAMERA_RATE
			lsr
		.endif
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
	.endif
		jsr pv_setup_for_ground
	.ifndef CONSISTENT_CAMERA_HEIGHT
	:
	.endif

	setaxy16

	.ifdef FORCEFIELD_FLOOR_TILE
	; Remove barrier from the tilemap
	lda Mode7ShowForcefield
	beq :+
		stz Mode7ShowForcefield
        lda Mode7ForcefieldPointer
        sta LevelBlockPtr
        lda [LevelBlockPtr]
		and #255
		jsr Mode7ChangeBlockAppearance
	:
	.endif

	jsr Mode7LevelPtrXYAtPlayer
	; React to fans
	FanMaxHeight = $7000
	FanCancelSpeed = .loword($100)
	cmp #Mode7Block::Fan
	bne NotOverFan
		lda Mode7PlayerHeight
		cmp #FanMaxHeight
		bcs NotOverFan

		lda Mode7PlayerVSpeed
		add #16
		sta Mode7PlayerVSpeed		
	NotOverFan:
	; Save the block the player is standing on
	lda Mode7PlayerHeight ; Not touching the tile if you're in the air
	bne :+
		lda [LevelBlockPtr]
		and #255
		jsr Mode7CallBlockTouching
	:
	pei (LevelBlockPtr)

	; If player is too high up, soften their vertical lift
	lda Mode7PlayerHeight
	cmp #FanMaxHeight
	bcc :+
		lda Mode7PlayerVSpeed ; If negative, already good
		bmi :+
		cmp #FanCancelSpeed   ; If slow enough, already good 
		bcc :+

		lda #FanCancelSpeed   ; Soften the fly with a smaller lift
		sta Mode7PlayerVSpeed
	:

	.if 0
	; up/down moves player (depends on generated rotation matrix)
	lda keydown
	and #KEY_DOWN ; down
	beq :+
		lda #1
		sta Mode7BumpDirection

		.import smul16
		lda Mode7Acceleration
		sta math_a
		lda z:mode7_m7t + 2
		sta math_b
		setxy8
		jsr smul16
		lda math_p+1
		setxy16
		sta 0

		; X += B * 2
		lda 0 ;z:mode7_m7t + 2 ; B
		;asl
		pha
		add z:M7PosX+0
		sta 0
		pla
		jsr sign
		adc z:M7PosX+2
		and #$0003 ; wrap to 0-1023
		sta 2
		jsr Mode7TryNewX

		.import smul16
		lda Mode7Acceleration
		sta math_a
		lda z:mode7_m7t + 6
		sta math_b
		setxy8
		jsr smul16
		lda math_p+1
		setxy16
		sta 0

		; Y += D * 2
		lda 0 ;z:mode7_m7t + 6 ; D
		;asl
		pha
		add z:M7PosY+0
		sta 0
		pla
		jsr sign
		adc z:M7PosY+2
		and #$0003
		sta 2
		jsr Mode7TryNewY
	:
	.endif

    ; ---------------------------------------------------------------

	lda keydown
	and #KEY_UP|KEY_DOWN
	bne @NoDecelerate
		lda Mode7Acceleration
		beq @NoDecelerate
		; If negative, make positive
		php ; Save if it was negative
		bpl :+
		  eor #$ffff
		  ina
		:

		sub #32
		bpl :+
			tdc ; Clear accumulator
		:

		plp
		; If it was previously negative, make it negative again
		bpl :+
			eor #$ffff
			ina
		:
		sta Mode7Acceleration
	@NoDecelerate:

	lda keydown
	and #KEY_UP ; up
	beq @NoUpAccelerate
		lda Mode7Acceleration
		bmi :+
		cmp #512
		bcs :++
		:
			add #32
			sta Mode7Acceleration
		:
	@NoUpAccelerate:

	lda keydown
	and #KEY_DOWN ; down
	beq @NoDownAccelerate
		lda Mode7Acceleration
		bpl :+
		cmp #.loword(-512)
		bcc :++
		:
			sub #32
			sta Mode7Acceleration
		:
	@NoDownAccelerate:

	lda Mode7Acceleration
	beq :+
		jsr Mode7MoveForward
	:

    ; ---------------------------------------------------------------

	lda keydown
	and #KEY_LEFT|KEY_RIGHT
	bne @NoSideDecelerate
    @YesSideDecelerate:
		lda Mode7SideAcceleration
		beq @NoSideDecelerate
		; If negative, make positive
		php ; Save if it was negative
		bpl :+
		  eor #$ffff
		  ina
		:

		sub #32
		bpl :+
			tdc ; Clear accumulator
		:

		plp
		; If it was previously negative, make it negative again
		bpl :+
			eor #$ffff
			ina
		:
		sta Mode7SideAcceleration
	@NoSideDecelerate:

	lda keydown
	and #KEY_LEFT
	beq @NoLeftAccelerate
		lda Mode7SideAcceleration
		bmi :+
		cmp #512
		bcs :++
		:
			add #32
			sta Mode7SideAcceleration
		:
	@NoLeftAccelerate:

	lda keydown
	and #KEY_RIGHT
	beq @NoRightAccelerate
		lda Mode7SideAcceleration
		bpl :+
		cmp #.loword(-512)
		bcc :++
		:
			sub #32
			sta Mode7SideAcceleration
		:
	@NoRightAccelerate:

	lda Mode7SideAcceleration
	beq :+
		jsr Mode7MoveSideways
	:

    ; ---------------------------------------------------------------

	; Calculate LevelBlockPtr again
	jsr Mode7LevelPtrXYAtPlayer
	lda LevelBlockPtr
	sta ScrollY ; Temporary space
	; Old LevelBlockPtr
	pla
	sta ScrollX ; Temporary space
	cmp LevelBlockPtr
	beq SameTile
		lda Mode7PlayerHeight
		bne SameTile
		lda [LevelBlockPtr]
		and #255
		jsr Mode7CallBlockStepOn

		lda ScrollX
		sta LevelBlockPtr
		lda [LevelBlockPtr]
		and #255
		jsr Mode7CallBlockStepOff
	SameTile:

	lda Mode7PlayerHeight
	bne :+
	lda keynew
	and #KEY_A
	bne :++
	:	jmp @NotPickupPush
	:
		lda Mode7HaveBlock
		beq @DontHaveBlock
	@DoHaveBlock:
		lda angle
		add #18
		and #63 ; Only one quarter
		cmp #18*2
		bcs @NotPickupPush

		jsr Mode7GetFourDirectionsAngle
		asl
		tay
		lda LevelBlockPtr
		add ForwardPtrTile,y
		sta LevelBlockPtr

		lda [LevelBlockPtr]
		and #255
		tay
		lda M7BlockFlags,y
		bit #M7_BLOCK_SOLID_BLOCK
		bne @NotPickupPush

		stz Mode7HaveBlock

		lda LevelBlockPtr ; X
		and #63
		asl
		asl
		asl
		asl
		tax

		lda LevelBlockPtr ; Y
		and #63*64
		lsr
		lsr
		tay

		.import Mode7CreateActor
		lda #Mode7ActorType::SlidingBlock
		jsr Mode7CreateActor
		bcc :+
			jsr Mode7GetFourDirectionsAngle
			seta8
			sta ActorDirection,x
			seta16
		:
		bra @NotPickupPush
	@DontHaveBlock:
		lda [LevelBlockPtr]
		and #255
		cmp #Mode7Block::PushableBlock
		beq @FoundPushBlock
		jsr Mode7GetFourDirectionsAngle
		asl
		tay
		lda ForwardPtrTile,y
		add ScrollY ; LevelBlockPtr
		sta LevelBlockPtr
		lda [LevelBlockPtr]
		and #255
		cmp #Mode7Block::PushableBlock
		bne @NotPickupPush
		@FoundPushBlock:
			.import Mode7UncoverAndShow
			jsr Mode7UncoverAndShow
			inc Mode7HaveBlock
	@NotPickupPush:

	setxy8
	; Set origin
	ldy #MODE7_PLAYER_SY ; place focus at center of scanline SY
	.ifndef CONSISTENT_CAMERA_HEIGHT
	lda z:mode7_height
	and #$00FF
	.ifdef HALF_CAMERA_RATE
		lsr
	.endif
	beq :+
	jsr pv_set_origin
	bra :++
:	.endif
	jsr pv_set_ground_origin
	.ifndef CONSISTENT_CAMERA_HEIGHT
	:
	.endif

	jsr Mode7DrawPlayer
	.a16
	.i16

	.if 0
	  ; TEST
      lda framecount
      and #63
	  add #150
	  sta texelx
      lda #150
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

	.import Mode7RunActors
	jsr Mode7RunActors

	jsl ppu_pack_oamhi_partial
	.a8 ; (does seta8)

	;lda #$0F
	;sta PPUBRIGHT

	jmp Loop

TURN_TABLE_LENGTH = 16 ; Doesn't include the initial zero
TurnAccelerationTable:
  .word 0, 1, 0, 1, 0, 1, 1, 1, 1, 2, 1, 2, 1, 2, 2, 2, 2
.endproc


.a16
.i16
.proc Mode7TryNewX
	; 0,2 = New position
	; M7PosX+0, M7PosX+2 = Current position

	SolidMask = 4
	lda #M7_BLOCK_SOLID
	sta SolidMask
	lda mode7_height
	and #255
	beq :+
		lda #M7_BLOCK_SOLID_AIR
		sta SolidMask
	:

	lda 1
	ldy M7PosY+1
	jsr Mode7LevelPtrXY
	jsr ApplyToggleBlockIDSwap
	tax
	lda M7BlockFlags,x
	and SolidMask
	beq :++
		jsr Mode7SetForcefield
		and #M7_BLOCK_SOLID_AIR
		bne :+
			txa
			jmp Mode7CallBlockBump
		:
		rts
	:

	; Apply the new position
	lda 0
	sta M7PosX+0
	lda 2
	sta M7PosX+2
	rts
.endproc

.a16
.i16
.proc Mode7TryNewY
	; 0,2 = New position
	; M7PosY+0, M7PosY+2 = Current position

	SolidMask = 4
	lda #M7_BLOCK_SOLID
	sta SolidMask
	lda mode7_height
	and #255
	beq :+
		lda #M7_BLOCK_SOLID_AIR
		sta SolidMask
	:

	lda M7PosX+1
	ldy 1
	jsr Mode7LevelPtrXY
	jsr ApplyToggleBlockIDSwap
	tax
	lda M7BlockFlags,x
	and SolidMask
	beq :++
		jsr Mode7SetForcefield
		and #M7_BLOCK_SOLID_AIR
		bne :+
			txa
			jmp Mode7CallBlockBump
		:
		rts
	:

	; Apply the new position
	lda 0
	sta M7PosY+0
	lda 2
	sta M7PosY+2
	rts
.endproc

.a16
.proc Mode7SetForcefield
	pha
	lda M7BlockFlags,x
	and #M7_BLOCK_SOLID_AIR
	beq :+
		inc Mode7ShowForcefield
		lda LevelBlockPtr
		sta Mode7ForcefieldPointer
	:
	pla
	rts
.endproc

.a16
.proc ApplyToggleBlockIDSwap
	cmp #Mode7Block::ToggleFloor1
	beq ToggleFloor1
	cmp #Mode7Block::ToggleWall1
	beq ToggleWall1
	cmp #Mode7Block::ToggleFloor2
	beq ToggleFloor2
	cmp #Mode7Block::ToggleWall2
	beq ToggleWall2
	rts

ToggleFloor1:
	bit8 ToggleSwitch1
	bmi BeBarrier
	rts
ToggleWall1:
	bit8 ToggleSwitch1
	bmi BeFloor
	rts
ToggleFloor2:
	bit8 ToggleSwitch2
	bmi BeBarrier
	rts
ToggleWall2:
	bit8 ToggleSwitch2
	bmi BeFloor
	rts

BeFloor:
	lda #Mode7Block::Checker1
	rts
BeBarrier:
	lda #Mode7Block::Barrier
	rts
.endproc


Mode7LevelPtrXYAtPlayer:
	lda M7PosX+1
	ldy M7PosY+1
.a16
.i16
; A = X position, in pixels
; Y = Y position, in pixels
; Output: LevelBlockPtr
.export Mode7LevelPtrXY
.proc Mode7LevelPtrXY
	    ; ......xx xxxx....
	lsr ; .......x xxxxx...
	lsr ; ........ xxxxxx..
	lsr ; ........ .xxxxxx.
	lsr ; ........ ..xxxxxx
	and            #%111111
	sta LevelBlockPtr

	tya ; ......yy yyyy....
	asl ; .....yyy yyy.....
	asl ; ....yyyy yy......
	and  #%0000111111000000
	tsb LevelBlockPtr
	    ; 0000yyyy yyxxxxxx
	lda [LevelBlockPtr]
	and #255
	rts
.endproc

.a16
.proc Mode7DoBlockUpdateWide
  ; 3x2, BL+1 and BR+1 go to the right
  lda BlockUpdateAddress,x
  sta PPUADDR
  seta8
  lda BlockUpdateDataTL,x
  sta PPUDATA
  lda BlockUpdateDataTR,x
  sta PPUDATA
  lda BlockUpdateDataBL+1,x
  sta PPUDATA
  seta16
  lda BlockUpdateAddress,x ; Move down a row
  add #128
  sta PPUADDR
  seta8
  lda BlockUpdateDataBL,x
  sta PPUDATA
  lda BlockUpdateDataBR,x
  sta PPUDATA
  lda BlockUpdateDataBR+1,x
  sta PPUDATA
  stz BlockUpdateDataTL+1,x ; Cancel out the block now that it's been written
  rts
.endproc

.a16
.proc Mode7DoBlockUpdateTall
  ; 2x3, BL+1 and BR+1 go below
  lda BlockUpdateAddress,x
  sta PPUADDR
  seta8
  lda BlockUpdateDataTL,x
  sta PPUDATA
  lda BlockUpdateDataTR,x
  sta PPUDATA
  seta16
  lda BlockUpdateAddress,x ; Move down a row
  add #128
  sta PPUADDR
  seta8
  lda BlockUpdateDataBL,x
  sta PPUDATA
  lda BlockUpdateDataBR,x
  sta PPUDATA
  seta16
  lda BlockUpdateAddress,x ; Move down two rows
  add #256
  sta PPUADDR
  seta8
  lda BlockUpdateDataBL+1,x
  sta PPUDATA
  lda BlockUpdateDataBR+1,x
  sta PPUDATA
  stz BlockUpdateDataTL+1,x ; Cancel out the block now that it's been written
  rts
.endproc

.a16
.export Mode7MoveForward
.proc Mode7MoveForward
	stz Mode7BumpDirection
	lda Mode7Acceleration
	bpl :+
		lda #1
		sta Mode7BumpDirection
	:

	.import smul16
	lda Mode7Acceleration
	sta math_a
	lda z:mode7_m7t + 2 ; B
	sta math_b
    setxy8
	jsr smul16
	lda math_p+1
	setxy16
	sta 0

	; X -= B * 2
	lda #0
	sub 0
	pha
	add z:M7PosX+0
	sta 0
	pla
	jsr sign
	adc z:M7PosX+2
	and #$0003
	sta 2
	jsr Mode7TryNewX

	lda Mode7Acceleration
	sta math_b
	lda z:mode7_m7t + 6 ; D
	sta math_a
	setxy8
	jsr smul16
	lda math_p+1
	setxy16
	sta 0

	; Y -= D * 2
	lda #0
	sub 0
	pha
	add z:M7PosY+0
	sta 0
	pla
	jsr sign
	adc z:M7PosY+2
	and #$0003
	sta 2
	jmp Mode7TryNewY
.endproc

.a16
.export Mode7MoveSideways
.proc Mode7MoveSideways
	stz Mode7BumpDirection

	.import smul16
	lda Mode7SideAcceleration
	sta math_a
	lda z:mode7_m7t + 6 ; D
	sta math_b
    setxy8
	jsr smul16
	lda math_p+1
	setxy16
	sta 0

	; X -= B * 2
	lda #0
	sub 0
	pha
	add z:M7PosX+0
	sta 0
	pla
	jsr sign
	adc z:M7PosX+2
	and #$0003
	sta 2
	jsr Mode7TryNewX

	lda Mode7SideAcceleration
	sta math_b
	lda z:mode7_m7t + 2 ; B
    eor #$ffff
    ina
	sta math_a
	setxy8
	jsr smul16
	lda math_p+1
	setxy16
	sta 0

	; Y -= D * 2
	lda #0
	sub 0
	pha
	add z:M7PosY+0
	sta 0
	pla
	jsr sign
	adc z:M7PosY+2
	and #$0003
	sta 2
	jmp Mode7TryNewY
.endproc

.proc Mode7DrawPlayer
HUDTileNumberStart = 32
  PlayerSpriteStart    = 0 ; 1 2 3
  PortraitSpriteStart  = 4 ; 5 6 7
  ShadowSpriteStart    = 8 ; 9
  CollectibleIconStart = 10
  CollectibleLeftStart = 11 ; 12 13 14
  ItemSpriteStart      = 15
  SpriteCount          = 16

  setaxy16
  jsr Mode7LevelPtrXYAtPlayer ; Prepare pointer for later

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

  setxy8
  ; Find the frame to use
  lda framecount
  lsr
  lsr
  sta CPUNUM
  ldx #20
  stx CPUDEN

  lda Mode7PlayerHeight
  beq @NotInAir
    ldx #Mode7PlayerFrame::JUMP1
    stx PlayerFrame

    lda Mode7PlayerVSpeed
    bpl @GoingUp
      ldx #Mode7PlayerFrame::FALL1
      stx PlayerFrame
    @GoingUp:

    seta8
	.ifndef CONSISTENT_CAMERA_HEIGHT
    lda mode7_height
    lsr
    lsr
    lsr
    lsr
	.ifndef HALF_CAMERA_RATE
		lsr
	.endif
    and #$fe
	cmp #3*2
	bcc :+
      lda #3*2
	:
    add PlayerFrame
    sta PlayerFrame
	.endif
    seta16

    lda framecount
    and #8
    beq :+
      inc PlayerFrame
    :
    bra @NotIdle
  @NotInAir:

  lda keydown
  and #KEY_UP|KEY_DOWN
  beq :+
    lda framecount ; Each cel is 8 frames
    lsr
    lsr
    lsr
    and #7
    add #Mode7PlayerFrame::WALK1
    tax
    stx PlayerFrame
    bra @NotIdle
  :

  ; For idle animation, use the remainder
  ldx CPUREM
  lda PlayerIdleFrames,x
  tax
  stx PlayerFrame

  @NotIdle:

  setxy16

  ; Draw the player
  ldy OamPtr

  lda #OAM_PRIORITY_2
  sta OAM_TILE+(4*(PlayerSpriteStart+0)),y
  ina
  ina
  sta OAM_TILE+(4*(PlayerSpriteStart+1)),y
  ina
  ina
  sta OAM_TILE+(4*(PlayerSpriteStart+2)),y
  ina
  ina
  sta OAM_TILE+(4*(PlayerSpriteStart+3)),y

  ; Portrait
  lda Mode7Portrait
  sta OAM_TILE+(4*(PortraitSpriteStart+0)),y
  ora #$02
  sta OAM_TILE+(4*(PortraitSpriteStart+1)),y
  lda Mode7Portrait
  ora #$04
  sta OAM_TILE+(4*(PortraitSpriteStart+2)),y
  ora #$02
  sta OAM_TILE+(4*(PortraitSpriteStart+3)),y

  ; Shadow
  lda mode7_height
  lsr
  lsr
  lsr
  lsr
  lsr    ; <-- Extra shift to remove the least significant bit of the tile number and use it to alternate rows instead
  bit #1
  php
  and #%110
  ora #(HUDTileNumberStart + $20) | OAM_PRIORITY_2
  plp
  beq :+
    ora #16
  :
  sta 0
  sta OAM_TILE+(4*(ShadowSpriteStart+0)),y
  ina
  sta OAM_TILE+(4*(ShadowSpriteStart+1)),y

  ; If over the void, use a different shadow
  lda [LevelBlockPtr]
  and #255
  bne :+
    lda #(HUDTileNumberStart + $34) | OAM_PRIORITY_2
    sta 0
    sta OAM_TILE+(4*(ShadowSpriteStart+0)),y
    ina
    sta OAM_TILE+(4*(ShadowSpriteStart+1)),y
  :

  lda framecount
  lsr
  bcc :+
    lda 0
    ora #OAM_XFLIP
    sta OAM_TILE+(4*(ShadowSpriteStart+1)),y
    ina
    sta OAM_TILE+(4*(ShadowSpriteStart+0)),y
  :

  ; Items left to get
  lda #HUDTileNumberStart + 11 + OAM_COLOR_1 + OAM_PRIORITY_3
  sta OAM_TILE+(4*CollectibleIconStart),y

  lda Mode7ChipsLeft
  beq @GoldZeros
  lsr
  lsr
  lsr
  lsr
  add #HUDTileNumberStart + 1 + OAM_COLOR_1 + OAM_PRIORITY_3
  sta OAM_TILE+(4*(CollectibleLeftStart+0)),y
  ora #16
  sta OAM_TILE+(4*(CollectibleLeftStart+1)),y

  lda Mode7ChipsLeft
  and #15
  add #HUDTileNumberStart + 1 + OAM_COLOR_1 + OAM_PRIORITY_3
  sta OAM_TILE+(4*(CollectibleLeftStart+2)),y
  ora #16
  sta OAM_TILE+(4*(CollectibleLeftStart+3)),y
  bra @NotZero
@GoldZeros:
  lda #HUDTileNumberStart + OAM_COLOR_1 + OAM_PRIORITY_3
  sta OAM_TILE+(4*(CollectibleLeftStart+0)),y
  sta OAM_TILE+(4*(CollectibleLeftStart+2)),y
  ora #16
  sta OAM_TILE+(4*(CollectibleLeftStart+1)),y
  sta OAM_TILE+(4*(CollectibleLeftStart+3)),y
@NotZero:


  seta8
  ; Player is made up of four sprites
  lda #MODE7_PLAYER_SX-16
  sta OAM_XPOS+(4*(PlayerSpriteStart+0)),y
  sta OAM_XPOS+(4*(PlayerSpriteStart+2)),y

  lda #MODE7_PLAYER_SY - 16 + 1 + 1 ; additional + 1 for the empty row on the bottom
  sub mode7_height
  sta OAM_YPOS+(4*(PlayerSpriteStart+2)),y
  sta OAM_YPOS+(4*(PlayerSpriteStart+3)),y
  sub #16
  sta OAM_YPOS+(4*(PlayerSpriteStart+0)),y
  sta OAM_YPOS+(4*(PlayerSpriteStart+1)),y

  lda #MODE7_PLAYER_SX
  sta OAM_XPOS+(4*(PlayerSpriteStart+1)),y
  sta OAM_XPOS+(4*(PlayerSpriteStart+3)),y

  ; Portrait position
  lda #10
  sta OAM_XPOS+(4*(PortraitSpriteStart+0)),y
  sta OAM_XPOS+(4*(PortraitSpriteStart+2)),y
  sta OAM_YPOS+(4*(PortraitSpriteStart+0)),y
  sta OAM_YPOS+(4*(PortraitSpriteStart+1)),y
  lda #10+16
  sta OAM_XPOS+(4*(PortraitSpriteStart+1)),y
  sta OAM_XPOS+(4*(PortraitSpriteStart+3)),y
  sta OAM_YPOS+(4*(PortraitSpriteStart+2)),y
  sta OAM_YPOS+(4*(PortraitSpriteStart+3)),y

  ; How many items are left to collect
  lda #10 + 16 - 8
  sta OAM_YPOS+(4*(CollectibleIconStart+0)),y
  sta OAM_YPOS+(4*(CollectibleLeftStart+0)),y
  sta OAM_YPOS+(4*(CollectibleLeftStart+2)),y
  lda #10 + 16
  sta OAM_YPOS+(4*(CollectibleLeftStart+1)),y
  sta OAM_YPOS+(4*(CollectibleLeftStart+3)),y
  lda #10 + 32 + 4
  sta OAM_XPOS+(4*(CollectibleIconStart+0)),y
  lda #10 + 32 + 4 + 16
  sta OAM_XPOS+(4*(CollectibleLeftStart+0)),y
  sta OAM_XPOS+(4*(CollectibleLeftStart+1)),y
  lda #10 + 32 + 4 + 16 + 8
  sta OAM_XPOS+(4*(CollectibleLeftStart+2)),y
  sta OAM_XPOS+(4*(CollectibleLeftStart+3)),y

  ; Player's shadow
  lda #MODE7_PLAYER_SX-8
  sta OAM_XPOS+(4*(ShadowSpriteStart+0)),y
  lda #MODE7_PLAYER_SX
  sta OAM_XPOS+(4*(ShadowSpriteStart+1)),y
  lda #MODE7_PLAYER_SY-4
  sta OAM_YPOS+(4*(ShadowSpriteStart+0)),y
  sta OAM_YPOS+(4*(ShadowSpriteStart+1)),y

  lda #$02
  sta OAMHI+1+(4*(PlayerSpriteStart+0)),y
  sta OAMHI+1+(4*(PlayerSpriteStart+1)),y
  sta OAMHI+1+(4*(PlayerSpriteStart+2)),y
  sta OAMHI+1+(4*(PlayerSpriteStart+3)),y
  ; Portrait
  sta OAMHI+1+(4*(PortraitSpriteStart+0)),y
  sta OAMHI+1+(4*(PortraitSpriteStart+1)),y
  sta OAMHI+1+(4*(PortraitSpriteStart+2)),y
  sta OAMHI+1+(4*(PortraitSpriteStart+3)),y
  sta OAMHI+1+(4*(CollectibleIconStart)),y
  sta OAMHI+1+(4*(ItemSpriteStart)),y
  ; Shadow
  lda #$00
  sta OAMHI+1+(4*(ShadowSpriteStart+0)),y
  sta OAMHI+1+(4*(ShadowSpriteStart+1)),y
  ; Collectibles left
  sta OAMHI+1+(4*(CollectibleLeftStart+0)),y
  sta OAMHI+1+(4*(CollectibleLeftStart+1)),y
  sta OAMHI+1+(4*(CollectibleLeftStart+2)),y
  sta OAMHI+1+(4*(CollectibleLeftStart+3)),y
  seta16
  tya
  add #SpriteCount*4
  sta OamPtr

  ; Draw health
  tay
  HealthX = 0
  HealthCount = 2
  lda #10 + 32 + 4
  sta HealthX

  lda PlayerHealth
  and #255
  lsr
  php
  sta HealthCount
HealthLoop:
  lda HealthCount
  beq HealthLoopEnd
  lda #HUDTileNumberStart + OAM_COLOR_1 + OAM_PRIORITY_3 + $2e
  jsr MakeHealthIcon
  dec HealthCount
  bne HealthLoop
HealthLoopEnd:
  plp 
  bcc :+
    lda #HUDTileNumberStart + OAM_COLOR_1 + OAM_PRIORITY_3 + $2f
    jsr MakeHealthIcon
  :

  sty OamPtr

  ; -------------------------
  ; Make the forcefield
  lda Mode7ShowForcefield
  beq :+
    inc Mode7ForcefieldTimer
    bra :++
  : stz Mode7ForcefieldTimer
  :
  lda Mode7ForcefieldPointer

  lda Mode7ShowForcefield
  cmp #1
  beq YesForcefield
JumpToNoForcefield:
  jmp NoForcefield
YesForcefield:
  lda Mode7ForcefieldTimer
  cmp #3
  bcc JumpToNoForcefield

.ifdef FORCEFIELD_FLOOR_TILE
  lda Mode7ForcefieldPointer
  sta LevelBlockPtr
  lda #Mode7Block::PushedBarrier
  jsr Mode7ChangeBlockAppearance
.endif
  lda keydown
  and #KEY_DOWN
  bne JumpToNoForcefield

.ifdef FORCEFIELD_PILLAR
  ; LevelBlockPtr is 0000yyyyyyxxxxxx
  lda Mode7ForcefieldPointer ; X
  and #63   ; 0000000000xxxxxx
  asl
  asl
  asl
  asl
  add #8
  sta texelx

  lda Mode7ForcefieldPointer ; Y
  and #63*64 ; 0000yyyyyy000000
  lsr
  lsr
  add #8
  sta texely

  jsr pv_texel_to_screen
  lda screeny
  cmp #$5FFF
  beq :+
    lda framecount
	lsr
	lsr
    and #3
    rsb screeny
    sta screeny
  ForcefieldLoop:
    ldy OamPtr
    lda #HUDTileNumberStart + OAM_COLOR_1 + OAM_PRIORITY_3 + 12 + $20
    sta OAM_TILE+(4*0),y
    sta OAM_TILE+(4*1),y
    seta8
    lda screenx
    sub #16
;    sub #8
    sta OAM_XPOS+(4*0),y
    add #16
    sta OAM_XPOS+(4*1),y
    lda screeny
    sub #12
    sta OAM_YPOS+(4*0),y
    sta OAM_YPOS+(4*1),y

    lda #$02
    sta OAMHI+1+(4*0),y
    sta OAMHI+1+(4*1),y
    seta16

	tya
	add #4*2
	sta OamPtr
    lda screeny
    bmi :+
    sub #16
    sta screeny
    bra ForcefieldLoop
  :
.endif
NoForcefield:

  rts

PlayerIdleFrames:
  .byt Mode7PlayerFrame::IDLE1, Mode7PlayerFrame::IDLE1
  .byt Mode7PlayerFrame::IDLE2, Mode7PlayerFrame::IDLE3, Mode7PlayerFrame::IDLE4, Mode7PlayerFrame::IDLE5, Mode7PlayerFrame::IDLE6, Mode7PlayerFrame::IDLE7, Mode7PlayerFrame::IDLE8, Mode7PlayerFrame::IDLE9
  .byt Mode7PlayerFrame::IDLE10, Mode7PlayerFrame::IDLE10
  .byt Mode7PlayerFrame::IDLE11, Mode7PlayerFrame::IDLE12, Mode7PlayerFrame::IDLE13, Mode7PlayerFrame::IDLE14, Mode7PlayerFrame::IDLE15, Mode7PlayerFrame::IDLE16, Mode7PlayerFrame::IDLE17, Mode7PlayerFrame::IDLE18

MakeHealthIcon:
  sta OAM_TILE,y
  seta8
  lda HealthX
  sta OAM_XPOS,y
  add #8
  sta HealthX
  lda #10 + 16 + 8
  sta OAM_YPOS,y
  seta16
  lda #0
  sta OAMHI+0,y

  ; Next sprite
  iny
  iny
  iny
  iny
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

.a16
.export Mode7GetFourDirectionsAngle
.proc Mode7GetFourDirectionsAngle
	lda angle
	add #32 ; -32 to 32 should be direction 0
	asl
	asl
	xba
	and #3
	rts
.endproc

; Right, Down, Left, Up
.export ForwardPtrTile
ForwardPtrTile:
  .word .loword(-64), .loword(-1), .loword(64), .loword(1)
;  .word .loword(1), .loword(64), .loword(-1), .loword(-64)
ForwardPixelTileX:
  .word 0, .loword(-16), 0, 16
ForwardPixelTileY:
  .word .loword(-16), 0, 16, 0

; For the lookaround code above in the main loop
.a16
.if 0
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
.endif

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
;  lda Mode7PlayerX
  sta Mode7CheckpointX
;  lda Mode7PlayerY
  sta Mode7CheckpointY
  lda angle
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
;  sta Mode7PlayerX
  lda Mode7CheckpointY
;  sta Mode7PlayerY
  lda Mode7CheckpointDir
  sta angle
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

.segment "Mode7Tiles"
.export Mode7Tiles
Mode7Tiles:
.incbin "../../tilesetsX/M7Tileset.chr"
Mode7TilesEnd:

.export Mode7ToggleSwapped, Mode7ToggleNotSwapped
Mode7ToggleNotSwapped = Mode7Tiles + 4*64*16
Mode7ToggleSwapped:
.incbin "../../tilesetsX/M7ToggleSwapped.chr"

Mode7Parallax:
.incbin "../../tilesetsX/M7Parallax.chr"

Mode7FanAnimation:
.incbin "../../tilesetsX/M7FanAnimation.chr"


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
