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
.include "blockenum.s"
.include "graphicsenum.s"
.include "paletteenum.s"
.include "portraitenum.s"
.include "m7leveldata.inc"
.smart
.importzp hm_node
.import huffmunch_load_snes, huffmunch_read_snes

Mode7LevelMap = LevelBuf
Mode7LevelMapCheckpoint = LevelBuf + (64*64) ; 4096

; Reusing this may be a little risky but it should be big enough
Mode7CheckpointX     = CheckpointState + 0
Mode7CheckpointY     = CheckpointState + 2
Mode7CheckpointDir   = CheckpointState + 4
Mode7CheckpointChips = CheckpointState = 6

M7A_M7B_Buffer1 = HDMA_Buffer1
M7C_M7D_Buffer1 = HDMA_Buffer1+1024
M7A_M7B_Buffer2 = HDMA_Buffer2
M7C_M7D_Buffer2 = HDMA_Buffer2+1024

.import m7a_m7b_0
.import m7a_m7b_list

.segment "BSS"
; Expose these for reuse by other systems
.export Mode7ScrollX, Mode7ScrollY, Mode7PlayerX, Mode7PlayerY, Mode7RealAngle, Mode7Direction, Mode7MoveDirection, Mode7Turning, Mode7TurnWanted
.export Mode7SidestepWanted, Mode7ChipsLeft, Mode7HappyTimer, Mode7Oops
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

PORTRAIT_NORMAL = $80 | OAM_PRIORITY_3
PORTRAIT_OOPS   = $88 | OAM_PRIORITY_3
PORTRAIT_HAPPY  = $A0 | OAM_PRIORITY_3
PORTRAIT_BLINK  = $A8 | OAM_PRIORITY_3
PORTRAIT_LEFT   = $C0 | OAM_PRIORITY_3


.segment "Mode7Game"

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

  seta8
  ; Transparency outside the mode 7 plane
  lda #M7_NOWRAP
  sta M7SEL
  ; Prepare LevelBlockPtr's bank byte
  lda #^Mode7LevelMap
  sta LevelBlockPtr+2

  ; The HUD goes on layer 2 and goes at $c000
  lda #0 | ($c000 >> 9) ; Right after the sprite graphics
  sta NTADDR+1
  ; Base for the tiles themselves are $c000 too
  lda #$cc >> 1
  sta BGCHRADDR+0



  ; Upload palettes
  stz CGADDR
  ; Write black
  stz CGDATA
  stz CGDATA
  ; Old sky palette before I went with the gradient instead
;  lda #<RGB(15,23,31)
;  sta CGDATA
;  lda #>RGB(15,23,31)
;  sta CGDATA
  seta16
  ; ---
  lda #DMAMODE_CGDATA
  ldx #$ffff & Mode7Palette
  ldy #64*2
  jsl ppu_copy

  ; Common sprites
  lda #Palette::FGCommon
  pha
  ldy #9
  jsl DoPaletteUpload
  pla
  ; And upload the common palette to the last background palette
  ldy #7
  jsl DoPaletteUpload
  lda #GraphicsUpload::SPCommon
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
  ldy #$9000 >> 1
  jsl DoPortraitUpload
  ina
  ldy #$9100 >> 1
  jsl DoPortraitUpload
  ina
  ldy #$9400 >> 1
  jsl DoPortraitUpload
  ina
  ldy #$9500 >> 1
  jsl DoPortraitUpload
  ina
  ldy #$9800 >> 1
  jsl DoPortraitUpload
 


  ; Put FGCommon in the last background palette for the HUD
  lda #Palette::FGCommon
  ldy #7
  jsl DoPaletteUpload

  ; -----------------------------------

  ; Upload graphics
  .import LZ4_DecompressToMode7Tiles, SFX_LZ4_decompress
  ldx #.loword(Mode7Tiles)
  lda #^Mode7Tiles
  stz PPUADDR
  jsl LZ4_DecompressToMode7Tiles

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

  ; Decompress a level of some sort
  seta8
  .import M7Level_sample2
  hm_node = 0
  lda #<M7Level_sample2
  sta hm_node+0
  lda #>M7Level_sample2
  sta hm_node+1
  lda #^M7Level_sample2
  sta hm_node+2

  ; Starting X pos
  lda [hm_node]
  .repeat 4
    asl
    rol Mode7PlayerX+1
  .endrep
  sta Mode7PlayerX
  inc16 hm_node

  ; Starting Y pos
  lda [hm_node]
  .repeat 4
    asl
    rol Mode7PlayerY+1
  .endrep
  sta Mode7PlayerY
  inc16 hm_node

  ; Direction
  lda [hm_node]
  sta Mode7Direction
  asl
  asl
  asl
  sta Mode7RealAngle
  inc16 hm_node

  ; Decompress the level map
  seta16
  ldx hm_node
  ldy #.loword(Mode7LevelMap)
  lda #(^Mode7LevelMap <<8) | ^M7Level_sample2
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

  ; Initialize the HDMA table and mode 7 scroll
  jsr BuildHDMATable
  jsr CalculateScroll

  ldx #0
  jsl ppu_clear_oam

  ; Clear the HUD's nametable
  ldx #$c000 >> 1
  ldy #64
  jsl ppu_clear_nt
  .a8

  ; Prepare the HDMA tables
  lda #49
  sta f:M7A_M7B_Buffer1
  sta f:M7C_M7D_Buffer1
  sta f:M7A_M7B_Buffer2
  sta f:M7C_M7D_Buffer2
  ; "1 scanline"
  lda #1
  ldx #5
: sta f:M7A_M7B_Buffer1,x
  sta f:M7C_M7D_Buffer1,x
  sta f:M7A_M7B_Buffer2,x
  sta f:M7C_M7D_Buffer2,x
  inx
  inx
  inx
  inx
  inx
  cpx #5*(224-48)
  bne :-
  ; Zero scanlines, terminate the list
  dea
  sta f:M7A_M7B_Buffer1,x
  sta f:M7C_M7D_Buffer1,x
  sta f:M7A_M7B_Buffer2,x
  sta f:M7C_M7D_Buffer2,x

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
: lda f:Mode7LevelMap,x
  cmp #Mode7Block::Collect
  bne DontIncreaseChipCounter
    pha
    sed
    lda Mode7ChipsLeft
    adc #0 ; assert((PS & 1) == 1) Carry will be set
    sta Mode7ChipsLeft
    cld
    pla
DontIncreaseChipCounter:
  asl
  asl
  sta PPUDATA
  ina
  sta PPUDATA
  inx
  dey
  bne :-

  seta16
  txa
  sub #64
  tax
  seta8

  ; Bottom row
  ldy #64
: lda f:Mode7LevelMap,x
  asl
  asl
  ora #2
  sta PPUDATA
  ina
  sta PPUDATA
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
  ; -----------------------

  lda #$8000 >> 14
  sta OBSEL       ; sprite CHR at $8000, sprites are 8x8 and 16x16

  lda #VBLANK_NMI|AUTOREAD
  sta PPUNMI

  setaxy16
  lda #.loword(Mode7IRQ)
  sta IRQHandler+0

  jsr MakeCheckpoint
Loop:
  setaxy16
  inc framecount

  jsl WaitVblank
  jsl ppu_copy_oam


  ; -----------------------------------
  seta8
  stz PPUCTRL
  seta16
  ; Do block updates
  ldx #(BLOCK_UPDATE_COUNT-1)*2
BlockUpdateLoop:
  lda BlockUpdateAddress,x
  beq SkipBlock
  sta PPUADDR
  seta8
  lda BlockUpdateDataTL,x
  sta PPUDATA
  ina
  sta PPUDATA

  seta16
  lda BlockUpdateAddress,x ; Move down a row
  add #128
  sta PPUADDR
  seta8
  lda BlockUpdateDataTL,x
  add #2
  sta PPUDATA
  ina
  sta PPUDATA
  seta16

  stz BlockUpdateAddress,x ; Cancel out the block now that it's been written
SkipBlock:
  dex
  dex
  bpl BlockUpdateLoop
  seta8
  lda #INC_DATAHI
  sta PPUCTRL

  seta16
  ; -----------------------------------
  ; Update the HUD
  lda #($c000 >> 1) + NTXY(14, 2)
  sta PPUADDR
  HUD_Base = 64 + (7 << 10)
  lda #12 | HUD_Base
  sta PPUDATA
  ina
  sta PPUDATA
  lda Mode7ChipsLeft
  bne :+
    lda #1|HUD_Base
    sta PPUDATA
    sta PPUDATA
    bra @TopWasZero
  :
  lsr
  lsr
  lsr
  lsr
  add #2 | HUD_Base
  sta PPUDATA
  lda Mode7ChipsLeft
  and #$0f
  add #2 | HUD_Base
  sta PPUDATA
@TopWasZero:
  ;--- (Bottom)
  lda #($c000 >> 1) + NTXY(14, 3)
  sta PPUADDR
  lda #$10+12 | HUD_Base
  sta PPUDATA
  ina
  sta PPUDATA
  lda Mode7ChipsLeft
  bne :+
    lda #$11|HUD_Base
    sta PPUDATA
    sta PPUDATA
    bra @BottomWasZero
  :
  lsr
  lsr
  lsr
  lsr
  add #$12 | HUD_Base
  sta PPUDATA
  lda Mode7ChipsLeft
  and #$0f
  add #$12 | HUD_Base
  sta PPUDATA
@BottomWasZero:

  ; -----------------------------------
  ; Start preparing the HDMA
  lda Mode7RealAngle
  asl
  tax

  ; Double buffering
  lda #.loword(M7A_M7B_Buffer1)
  sta DMAADDR+$20
  lda #.loword(M7C_M7D_Buffer1)
  sta DMAADDR+$30
  lda framecount
  lsr
  bcc :+
    lda #.loword(M7A_M7B_Buffer2)
    sta DMAADDR+$20
    lda #.loword(M7C_M7D_Buffer2)
    sta DMAADDR+$30
  :

  lda #.loword(GradientTable)
  sta DMAADDR+$40
  lda #$1b03 ; m7a and m7b
  sta DMAMODE+$20
  lda #$1d03 ; m7c and m7d
  sta DMAMODE+$30
  lda #$3200 ; one byte to COLDATA
  sta DMAMODE+$40

  lda #220
  sta HTIME
  lda #48
  sta VTIME
  seta8
  lda #^HDMA_Buffer1
  sta DMAADDRBANK+$20
  sta DMAADDRBANK+$30
  lda #^GradientTable
  sta DMAADDRBANK+$40

  lda #4|8|16
  sta HDMASTART

  lda #$0F
  sta PPUBRIGHT ; Turn on rendering
  lda #1
  sta BGMODE
  lda #%11100000 ; Reset COLDATA
  sta COLDATA


  lda #0          ; Color math is always enabled
  sta CGWSEL
  lda #%00100000  ; Color math when the background color is used
  sta CGADSUB


  lda #VBLANK_NMI|AUTOREAD|HVTIME_IRQ ; enable HV IRQ
  sta PPUNMI
  cli

  ; Initialize the scroll registers
  seta8
  lda Mode7ScrollX+0
  sta BGSCROLLX
  lda Mode7ScrollX+1
  sta BGSCROLLX
  lda Mode7ScrollY+0
  sta BGSCROLLY
  lda Mode7ScrollY+1
  sta BGSCROLLY

  lda #%00010010  ; enable sprites, plane 1
  sta BLENDMAIN

  ; Calculate the centers
  seta16
  lda Mode7ScrollX
  add #128
  seta8
  sta M7X
  xba
  sta M7X
  seta16
  lda Mode7ScrollY
  add #192
  seta8
  sta M7Y
  xba
  sta M7Y

  jsl WaitKeysReady
  seta16

  ; ---------------

  ; Save player X ORed with player Y so we can know if the player was moving last frame
  lda Mode7PlayerX
  ora Mode7PlayerY
  pha

  ; ---------------

  lda Mode7Oops
  jne WasRotation
  lda Mode7Turning
  jne AlreadyTurning
    lda keydown
    and #KEY_LEFT|KEY_RIGHT
    tsb Mode7TurnWanted

    ; Can't turn except directly on a tile
    lda Mode7PlayerX
    ora Mode7PlayerY
    and #15
    php

    beq :+
      ; But you set SidestepWanted while moving forward/backward and also pressing the sidestep key
      lda Mode7Direction
      eor Mode7MoveDirection
      lsr
      bcs :+

      lda keydown
      and #KEY_L|KEY_R
      tsb Mode7SidestepWanted
    :

    plp
    jne AlreadyTurning

.if 0
    lda keydown
    and #KEY_B
    beq NotStop
      lda keydown
      and #KEY_UP
      beq :+
        stz Mode7TurnWanted
      :
      jmp WasRotation
    NotStop:
.endif

    lda Mode7TurnWanted
    and #KEY_RIGHT
    beq :+
      dec Mode7Turning
      lda Mode7Direction
      dec
      and #3
      sta Mode7Direction
      stz Mode7TurnWanted
    :

    lda Mode7TurnWanted
    and #KEY_LEFT
    beq :+
      inc Mode7Turning
      lda Mode7Direction
      inc
      and #3
      sta Mode7Direction
      stz Mode7TurnWanted
    :
  AlreadyTurning:

  lda Mode7Turning
  beq NoRotation
    lda Mode7RealAngle
    add Mode7Turning
    and #31
    sta Mode7RealAngle
    and #7
    bne NoRotation
      stz Mode7Turning
NoRotation:

  ; If not rotating, allow moving forward
  lda Mode7PlayerX
  ora Mode7PlayerY
  and #15
  bne @NotAligned
    lda keydown
    ora Mode7SidestepWanted
    and #KEY_L
    beq :+
      stz Mode7SidestepWanted
      lda Mode7Direction
      ina
      and #3
      sta Mode7MoveDirection
      bra @StartMoving
    :

    lda keydown
    ora Mode7SidestepWanted
    and #KEY_R
    beq :+
      stz Mode7SidestepWanted
      lda Mode7Direction
      dec
      and #3
      sta Mode7MoveDirection
      bra @StartMoving
    :

    lda keydown
    and #KEY_UP
    beq :+
      lda Mode7Direction
      sta Mode7MoveDirection
      bra @StartMoving
    :

    lda keydown
    and #KEY_DOWN
    beq :+
      lda Mode7Direction
      eor #2
      sta Mode7MoveDirection
      bra @StartMoving
    :

    bra WasRotation
@NotAligned:
@StartMoving:

  ; If not rotating, move forward
  lda Mode7MoveDirection
  asl
  tax

  ; Don't check for walls except when moving onto a new block
  lda Mode7PlayerX
  ora Mode7PlayerY
  and #15
  bne NotWall
  ; Is there a wall one block ahead?
  lda Mode7PlayerY
  add ForwardYTile,x
  cmp #64*16 ; Don't allow if this would make the player go out of bounds
  bcs WasRotation
  tay
  lda Mode7PlayerX
  add ForwardXTile,x
  cmp #64*16 ; Don't allow if this would make the player go out of bounds
  bcs WasRotation
  jsr Mode7BlockAddress
  tay
  lda BlockInfo,y
  lsr
  bcc NotWall
IsWall:
    bra WasRotation
  NotWall:

  lda Mode7PlayerX
  add ForwardX,x
  sta Mode7PlayerX

  lda Mode7PlayerY
  add ForwardY,x
  sta Mode7PlayerY
WasRotation:

  ; Make it so that 0,0 places the player on the top left corner of the map
  jsr CalculateScroll

; Star I was using to show the player position initially
.if 0
  ldy OamPtr
  lda #$68|OAM_PRIORITY_2
  sta OAM_TILE,y
  seta8
  lda #128-4
  sta OAM_XPOS,y
  lda #192-4
  sta OAM_YPOS,y
  lda #0
  sta OAMHI+1,y
  seta16
  tya
  add #4
  sta OamPtr
.endif

  ; Decide which portrait to use
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
  

  lda Mode7HappyTimer
  beq :+
    lda #PORTRAIT_HAPPY
    sta Mode7Portrait
    dec Mode7HappyTimer
  :
  lda Mode7Oops
  beq :+
    lda #PORTRAIT_OOPS
    sta Mode7Portrait
    dec Mode7Oops
    jeq Mode7Die
  :


  ; Draw a crappy temporary walk animation
  ldy OamPtr
  lda keydown
  and #KEY_UP
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

  lda Mode7Portrait
  sta OAM_TILE+(4*4),y
  ora #$02
  sta OAM_TILE+(4*5),y
  lda Mode7Portrait
  ora #$04
  sta OAM_TILE+(4*6),y
  ora #$02
  sta OAM_TILE+(4*7),y

  seta8
  DrawCenterX = 128
  DrawCenterY = 192

  lda #DrawCenterX-16
  sta OAM_XPOS+(4*0),y
  sta OAM_XPOS+(4*2),y
  lda #DrawCenterY-12-16
  sta OAM_YPOS+(4*0),y
  sta OAM_YPOS+(4*1),y

  lda #DrawCenterX
  sta OAM_XPOS+(4*1),y
  sta OAM_XPOS+(4*3),y
  lda #DrawCenterY-12
  sta OAM_YPOS+(4*2),y
  sta OAM_YPOS+(4*3),y


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
  seta16
  tya
  add #8*4
  sta OamPtr



  ; Don't respond to special floors when you weren't moving last frame
  pla ; Mode7PlayerX|Mode7PlayerY
  and #15
  beq :+

  ; Respond to special floors when you're in the middle of a block
  lda Mode7PlayerX
  ora Mode7PlayerY
  and #15
  bne :+
    lda Mode7PlayerX
    ldy Mode7PlayerY
    jsr Mode7BlockAddress
    jsr CallBlockAction
  :

  setaxy16
  ldx OamPtr
  jsl ppu_clear_oam
  jsl ppu_pack_oamhi

  jsr BuildHDMATable

  jmp Loop

  rtl
.endproc

.a16
.i16
.proc BuildHDMATable
  ; Build the HDMA table for the matrix registers,
  ; allowing them to be compressed significantly.
  lda Mode7RealAngle
  asl
  tax
  ldy m7a_m7b_list,x ; Should be the same bank as this one

  ; Counter for how many rows are left
  lda #224-48
  sta 0

  ; Switch the data bank.
  ; Probably actually better than switching to 8-bit mode and back to do it.
  ph2banks m7a_m7b_0, StartMode7Level
  plb

  ; Write index
  ldx #1
  lda framecount
  lsr
  bcs :+
    ldx #1+2048
  :
BuildHDMALoop:
  lda 2*176*8,y ; M7A
  sta f:M7A_M7B_Buffer1+0,x
  sta f:M7C_M7D_Buffer1+2,x
  lda 0,y ; M7B
  sta f:M7A_M7B_Buffer1+2,x
  eor #$ffff
  ina
  sta f:M7C_M7D_Buffer1+0,x

  inx ; Next HDMA table entry
  inx
  inx
  inx
  inx
  iny ; Next perspective table entry
  iny
  dec 0
  bne BuildHDMALoop

  ; Set B back to this bank
  plb
  rts
.endproc

ForwardX:
  .word 0, .loword(-2), 0, .loword(2)
ForwardY:
  .word .loword(-2), 0, .loword(2), 0
ForwardXTile:
  .word 0, .loword(-16), 0, .loword(16)
ForwardYTile:
  .word .loword(-16), 0, .loword(16), 0

.proc CheckWallAhead
  lda Mode7PlayerY
  add ForwardYTile,x
  cmp #64*16 ; Don't allow if this would make the player go out of bounds
  bcs Block
  tay
  lda Mode7PlayerX
  add ForwardXTile,x
  cmp #64*16 ; Don't allow if this would make the player go out of bounds
  bcs Block
  jsr Mode7BlockAddress
  tay
  lda BlockInfo,y
  lsr
  rts
Block:
  sec
  rts
.endproc

Mode7Tiles:
.incbin "../tools/M7Tileset.chrm7.lz4"

.include "m7palettedata.s"


.proc Mode7IRQ
  pha
  php
  seta8
  bit TIMESTATUS ; Acknowledge interrupt
  lda #7
  sta BGMODE
  lda #%00010001  ; enable sprites, plane 0
  sta BLENDMAIN
  plp
  pla
  rti
.endproc

; A = block to set
; X = block address
.a16
.i16
.proc Mode7ChangeBlock
Temp = BlockTemp
  phx
  phy
  php
  seta8
  sta [LevelBlockPtr] ; Make the change in the level buffer itself
  setaxy16
  ; Find a free index in the block update queue
  ldy #(BLOCK_UPDATE_COUNT-1)*2
FindIndex:
  ldx BlockUpdateAddress,y ; Test for zero (exact value not used)
  beq Found
  dey                      ; Next index
  dey
  bpl FindIndex            ; Give up if all slots full
  jmp Exit
Found:
  ; From this point on in the routine, Y = free update queue index

  ; Store the tile number
  asl
  asl
  sta BlockUpdateDataTL,y

  ; Now calculate the PPU address
  ; LevelBlockPtr is 0000yyyyyyxxxxxx
  ; Needs to become  00yyyyyy0xxxxxx0
  lda LevelBlockPtr
  and #%111111000000 ; Get Y
  asl
  asl
  sta BlockUpdateAddress,y

  ; Add in X
  lda LevelBlockPtr
  and #%111111
  asl
  ora BlockUpdateAddress,y
  sta BlockUpdateAddress,y

  ; Restore registers
Exit:

  plp
  ply
  plx
  rts
.endproc


; A = X coordinate
; Y = Y coordinate
; Output: LevelBlockPtr
.a16
.i16
.proc Mode7BlockAddress
  and #%1111110000
      ; ......xx xxxx....
  lsr ; .......x xxxxx...
  lsr ; ........ xxxxxx..
  lsr ; ........ .xxxxxx.
  lsr ; ........ ..xxxxxx
  sta LevelBlockPtr
  tya ; ......yy yyyy....
  and #%1111110000
  asl ; .....yyy yyy.....
  asl ; ....yyyy yy......
  tsb LevelBlockPtr
      ; ....yyyy yyxxxxxx
  lda [LevelBlockPtr]
  and #255
  rts
.endproc

.proc BlockInfo
  Solid = 1
  Floor = 0
  .byt Solid ;Void
  .byt Floor ;Checker1
  .byt Floor ;Checker2
  .byt Floor ;ToggleFloor
  .byt Floor ;ToggleWall
  .byt Floor ;Collect
  .byt Floor ;Hurt
  .byt Floor ;Spring
  .byt Floor ;ForceDown
  .byt Floor ;ForceUp
  .byt Floor ;ForceLeft
  .byt Floor ;ForceRight
  .byt Floor ;Unused1
  .byt Floor ;Checkpoint
  .byt Floor ;ToggleButton
  .byt Floor ;Button
  .byt Solid ;BlueLock
  .byt Solid ;RedLock
  .byt Solid ;GreenLock
  .byt Solid ;YellowLock
  .byt Floor ;BlueKey
  .byt Floor ;RedKey
  .byt Floor ;GreenKey
  .byt Floor ;YellowKey
  .byt Floor ;CountFive
  .byt Floor ;CountFour
  .byt Floor ;CountThree
  .byt Floor ;CountTwo
  .byt Floor ;GetBlock
  .byt Solid ;AcceptBlock
  .byt Floor ;Bridge
  .byt Solid ;FlyingBlock
  .byt Floor ;Exit
  .byt Floor ;Ice
  .byt Floor ;Bomb
  .byt Floor ;RedButton
.endproc

CallBlockAction:
  asl
  tay
  lda BlockAction,y
  pha
  rts

.proc BlockAction
  .raddr .loword(DoNothing) ;Void
  .raddr .loword(DoNothing) ;Checker1
  .raddr .loword(DoNothing) ;Checker2
  .raddr .loword(DoNothing) ;ToggleFloor
  .raddr .loword(DoNothing) ;ToggleWall
  .raddr .loword(DoCollect) ;Collect
  .raddr .loword(DoHurt)    ;Hurt
  .raddr .loword(DoNothing) ;Spring
  .raddr .loword(DoNothing) ;ForceDown
  .raddr .loword(DoNothing) ;ForceUp
  .raddr .loword(DoNothing) ;ForceLeft
  .raddr .loword(DoNothing) ;ForceRight
  .raddr .loword(DoNothing) ;Unused
  .raddr .loword(DoCheckpoint) ;Checkpoint
  .raddr .loword(DoNothing) ;ToggleButton
  .raddr .loword(DoNothing) ;Button
  .raddr .loword(DoNothing) ;BlueLock
  .raddr .loword(DoNothing) ;RedLock
  .raddr .loword(DoNothing) ;GreenLock
  .raddr .loword(DoNothing) ;YellowLock
  .raddr .loword(DoNothing) ;BlueKey
  .raddr .loword(DoNothing) ;RedKey
  .raddr .loword(DoNothing) ;GreenKey
  .raddr .loword(DoNothing) ;YellowKey
  .raddr .loword(DoCountFive) ;CountFive
  .raddr .loword(DoCountFour) ;CountFour
  .raddr .loword(DoCountThree) ;CountThree
  .raddr .loword(DoCountTwo) ;CountTwo
  .raddr .loword(DoNothing) ;GetBlock
  .raddr .loword(DoNothing) ;AcceptBlock
  .raddr .loword(DoNothing) ;Bridge
  .raddr .loword(DoNothing) ;FlyingBlock
  .raddr .loword(DoNothing) ;Exit
  .raddr .loword(DoNothing) ;Ice
  .raddr .loword(DoNothing) ;Bomb
  .raddr .loword(DoNothing) ;RedButton
DoNothing:
  rts

DoHurt:
  lda #30
  sta Mode7Oops
  rts

DoCollect:
  lda #15
  sta Mode7HappyTimer

  sed
  lda Mode7ChipsLeft
  sub #1
  sta Mode7ChipsLeft
  cld
  lda #Mode7Block::Hurt
  jmp Mode7ChangeBlock
DoCountFive:
  lda #Mode7Block::CountFour
  jmp Mode7ChangeBlock
DoCountFour:
  lda #Mode7Block::CountThree
  jmp Mode7ChangeBlock
DoCountThree:
  lda #Mode7Block::CountTwo
  jmp Mode7ChangeBlock
DoCountTwo:
  lda #Mode7Block::Collect
  jmp Mode7ChangeBlock

DoCheckpoint:
  lda #Mode7Block::Empty
  jsr Mode7ChangeBlock
  jmp MakeCheckpoint
.endproc




.a16
.i16
.proc MakeCheckpoint
  lda Mode7PlayerX
  sta Mode7CheckpointX
  lda Mode7PlayerY
  sta Mode7CheckpointY
  lda Mode7Direction
  sta Mode7CheckpointDir
  lda Mode7ChipsLeft
  sta Mode7CheckpointChips

  ldx #4096-2
: lda f:Mode7LevelMap,x
  sta f:Mode7LevelMapCheckpoint,x
  dex
  dex
  bne :-
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
  asl
  asl
  asl
  sta Mode7RealAngle
  lda Mode7CheckpointChips
  sta Mode7ChipsLeft

  ldx #4096-2
: lda f:Mode7LevelMapCheckpoint,x
  sta f:Mode7LevelMap,x
  dex
  dex
  bne :-
  jmp StartMode7Level::RestoredFromCheckpoint
.endproc

.proc CalculateScroll
  lda Mode7PlayerX
  sub #7*16+8
  sta Mode7ScrollX
  lda Mode7PlayerY
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
