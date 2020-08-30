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
.include "graphicsenum.s"
.include "paletteenum.s"
.include "portraitenum.s"
.include "m7blockenum.s"
.smart
.importzp hm_node
.import M7BlockTopLeft, M7BlockTopRight, M7BlockBottomLeft, M7BlockBottomRight, M7BlockFlags

.export Mode7LevelMap, Mode7LevelMapBelow, Mode7DynamicTileBuffer, Mode7DynamicTileUsed
Mode7LevelMap                = LevelBuf + (64*64*0) ;\
Mode7LevelMapCheckpoint      = LevelBuf + (64*64*1) ; \ 16KB, 4KB each
Mode7LevelMapBelow           = LevelBuf + (64*64*2) ; /
Mode7LevelMapBelowCheckpoint = LevelBuf + (64*64*3) ;/
Mode7DynamicTileBuffer       = LevelBufAlt          ; 7 tiles long, 64*4*7 = 1792
Mode7DynamicTileUsed         = ColumnUpdateAddress  ; Reuse this, 7 bytes long? padded to 8 though
Mode7Keys                    = Mode7DynamicTileUsed+8 ; 4 bytes
Mode7Tools                   = Mode7Keys+4          ; 2 bytes? Could be 1

TOOL_FIREBOOTS    = 1
TOOL_FLIPPERS     = 2
TOOL_SUCTIONBOOTS = 4
TOOL_ICESKATES    = 8

CommonTilesetLength = (12*16+4)*64

; Reusing this may be a little risky but it should be big enough
Mode7CheckpointX     = CheckpointState + 0
Mode7CheckpointY     = CheckpointState + 2
Mode7CheckpointDir   = CheckpointState + 4
Mode7CheckpointChips = CheckpointState + 6
Mode7CheckpointKeys  = CheckpointState + 8 ; Four bytes
Mode7CheckpointTools = CheckpointState + 10

M7A_M7B_Buffer1Data  = HDMA_Buffer1
M7C_M7D_Buffer1Data  = HDMA_Buffer1+1024
M7A_M7B_Buffer2Data  = HDMA_Buffer2
M7C_M7D_Buffer2Data  = HDMA_Buffer2+1024

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

M7_BLOCK_SOLID_L      = 1
M7_BLOCK_SOLID_R      = 2
M7_BLOCK_SOLID_U      = 4
M7_BLOCK_SOLID_D      = 8

DIRECTION_UP    = 0
DIRECTION_LEFT  = 1
DIRECTION_DOWN  = 2
DIRECTION_RIGHT = 3

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
  stz Mode7CheckpointChips

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
  ; Binoculars
  ina
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

  stz Mode7DynamicTileUsed+0 ; 8 bytes long
  stz Mode7DynamicTileUsed+2
  stz Mode7DynamicTileUsed+4
  stz Mode7DynamicTileUsed+6

  stz Mode7DoLookAround
  stz Mode7LookAroundOffsetX
  stz Mode7LookAroundOffsetY

  ldx #ActorStart
  ldy #ActorEnd-ActorStart
  jsl MemClear
  ldx #BlockUpdateAddress
  ldy #BlockUpdateDataEnd-BlockUpdateAddress
  jsl MemClear

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

  jsr MakeCheckpoint
.endproc

.proc Mode7MainLoop
Loop:
  setaxy16
  inc framecount

  jsl WaitVblank
  jsl ppu_copy_oam

  ; Upload the dynamic tile area
  seta8
  ldy #DMAMODE_PPUHIDATA
  sty DMAMODE
  lda #INC_DATAHI
  sta PPUCTRL
  lda #^Mode7DynamicTileBuffer
  sta DMAADDRBANK
  ldy #.loword(Mode7DynamicTileBuffer)
  sty DMAADDR
  ldy #28*64
  sty DMALEN
  ldy #(14*16+4)*64
  sty PPUADDR
  lda #1
  sta COPYSTART
  seta16

  ; -----------------------------------
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
  jpl BlockUpdateLoop
  seta8
  lda #INC_DATAHI
  sta PPUCTRL

  seta16
  ; -----------------------------------
  ; Update the HUD
  lda #($c000 >> 1) + NTXY(6, 2)
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
  lda #($c000 >> 1) + NTXY(6, 3)
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
  lda #.loword(M7A_M7B_Table1)
  sta DMAADDR+$20
  lda #.loword(M7C_M7D_Table1)
  sta DMAADDR+$30
  lda framecount
  lsr
  bcc :+
    lda #.loword(M7A_M7B_Table2)
    sta DMAADDR+$20
    lda #.loword(M7C_M7D_Table2)
    sta DMAADDR+$30
  :

  lda #.loword(GradientTable)
  sta DMAADDR+$40
  lda #(<M7A << 8) | DMA_0011 | DMA_FORWARD | DMA_INDIRECT ; m7a and m7b
  sta DMAMODE+$20
  lda #(<M7C << 8) | DMA_0011 | DMA_FORWARD | DMA_INDIRECT ; m7c and m7d
  sta DMAMODE+$30
  lda #(<COLDATA <<8) ; one byte to COLDATA
  sta DMAMODE+$40

  lda #220
  sta HTIME
  lda #48
  sta VTIME
  seta8
  lda #^M7A_M7B_Table1
  sta DMAADDRBANK+$20
  sta DMAADDRBANK+$30
  lda #^HDMA_Buffer1
  sta HDMAINDBANK+$20
  sta HDMAINDBANK+$30

  lda #^GradientTable
  sta DMAADDRBANK+$40

  lda #4|8|16
  sta HDMASTART

  lda #$0F
  sta PPUBRIGHT ; Turn on rendering
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
  pha ; Hold onto this for a long while

  ; ---------------

  lda Mode7Turning
  bne :+
  lda keynew
  and #KEY_X
  beq :+
    lda Mode7DoLookAround
    ina
    sta Mode7DoLookAround
  :

  ; If you're currently looking around, allow using the d-pad to move the camera offset
  lda Mode7DoLookAround
  jeq DontLookAround
    ; If snapping back, move back to the player
    lda Mode7DoLookAround
    cmp #1
    beq AllowLookAround
      ina
      sta Mode7DoLookAround
      cmp #20
      bcc :+
        stz Mode7DoLookAround
        stz Mode7LookAroundOffsetX
        stz Mode7LookAroundOffsetY
      :

      lda Mode7LookAroundOffsetX
      pha
      asr_n 2
      rsb Mode7LookAroundOffsetX
      sta Mode7LookAroundOffsetX
      pla
      cmp Mode7LookAroundOffsetX
      bne :+
        stz Mode7LookAroundOffsetX
      :

      lda Mode7LookAroundOffsetY
      pha
      asr_n 2
      rsb Mode7LookAroundOffsetY
      sta Mode7LookAroundOffsetY
      pla
      cmp Mode7LookAroundOffsetY
      bne :+
        stz Mode7LookAroundOffsetY
      :

      bra DontLookAround
  AllowLookAround:
    ; If not snapping back to the player, move around in response to the keys
    lda keydown
    and #KEY_LEFT
    beq :+
      lda Mode7Direction
      ina
      jsr AddLookAroundDirection
    :
    lda keydown
    and #KEY_DOWN
    beq :+
      lda Mode7Direction
      ina
      ina
      jsr AddLookAroundDirection
    :
    lda keydown
    and #KEY_UP
    beq :+
      lda Mode7Direction
      jsr AddLookAroundDirection
    :
    lda keydown
    and #KEY_RIGHT
    beq :+
      lda Mode7Direction
      dea
      jsr AddLookAroundDirection
    :
  DontLookAround:

  lda Mode7DoLookAround
  ora Mode7Oops
  jne DontMoveForward
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

    lda Mode7ForceMove
    bpl :+
    @DoForceMoveAnyway:
      lda Mode7ForceMove
      and #3
      sta Mode7MoveDirection
      stz Mode7ForceMove
      bra @StartMoving
    :

    jmp WasRotation
@NotAligned:
@StartMoving:

  ; If moving and not rotating, move forward
  lda Mode7MoveDirection
  asl
  tax

  ; Don't check for walls except when moving onto a new block
  lda Mode7PlayerX
  ora Mode7PlayerY
  and #15
  bne @NotWall

  lda Mode7PlayerX
  ldy Mode7PlayerY
  jsr Mode7BlockAddress
  tay
  lda M7BlockFlags,y
  and #15
  cmp #15
  beq @DontCheckSolidInside
    and ForwardWallBitInside,x
    bne DontMoveForward
  @DontCheckSolidInside:

  ; Is there a wall one block ahead?
  lda Mode7PlayerY
  add ForwardYTile,x
  cmp #64*16 ; Don't allow if this would make the player go out of bounds
  bcs DontMoveForward
  tay
  lda Mode7PlayerX
  add ForwardXTile,x
  cmp #64*16 ; Don't allow if this would make the player go out of bounds
  bcs DontMoveForward
  jsr Mode7BlockAddress
  tay
  lda M7BlockFlags,y
  and ForwardWallBitOutside,x
  beq @NotWall
@IsWall:
    lda [LevelBlockPtr]
    and #255
    jsr CallBlockBump
    bra DontMoveForward
  @NotWall:

  ; Countering a force move by sidestepping?
  ; Check at this point because a blocked move against a wall shouldn't cancel it
  lda Mode7ForceMove
  bpl @NoForceMove
    bit #$4000 ; If it's ice, you can't 
    bne @DoForceMoveAnyway
    eor Mode7MoveDirection
    lsr
    bcc @DoForceMoveAnyway
    stz Mode7ForceMove
  @NoForceMove:

  ; Save the direction for ice purposes
  lda Mode7MoveDirection
  sta Mode7IceDirection

  ; Move forward after all
  lda Mode7PlayerX
  add ForwardX,x
  sta Mode7PlayerX

  lda Mode7PlayerY
  add ForwardY,x
  sta Mode7PlayerY
DontMoveForward:
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

  lda Mode7DoLookAround
  beq DoDrawPlayer
    ldy OamPtr
    lda #PORTRAIT_LOOK
    sta OAM_TILE+(4*0),y
    ora #$02
    sta OAM_TILE+(4*1),y
    lda #PORTRAIT_LOOK
    ora #$04
    sta OAM_TILE+(4*2),y
    ora #$02
    sta OAM_TILE+(4*3),y

    seta8
    lda #10
    sta OAM_XPOS+(4*0),y
    sta OAM_XPOS+(4*2),y
    sta OAM_YPOS+(4*0),y
    sta OAM_YPOS+(4*1),y
    lda #10+16
    sta OAM_XPOS+(4*1),y
    sta OAM_XPOS+(4*3),y
    sta OAM_YPOS+(4*2),y
    sta OAM_YPOS+(4*3),y

    ; Portrait
    lda #$02
    sta OAMHI+1+(4*0),y
    sta OAMHI+1+(4*1),y
    sta OAMHI+1+(4*2),y
    sta OAMHI+1+(4*3),y
    seta16
    tya
    add #4*4
    sta OamPtr

    jmp DontDrawPlayer
  DoDrawPlayer:

  ; Draw a crappy temporary walk animation
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
DontDrawPlayer:


  ; Don't respond to special floors when you weren't moving last frame
  pla ; Mode7PlayerX|Mode7PlayerY
  and #15
  beq DontRunSpecialFloor

  ; Respond to special floors when you're in the middle of a block
  lda Mode7PlayerX
  ora Mode7PlayerY
  and #15
  bne DontRunSpecialFloor
    lda Mode7LastPositionPtr
    beq :+
      sta LevelBlockPtr
      lda [LevelBlockPtr]
      and #255
      jsr CallBlockExit
    :

    lda Mode7PlayerX
    ldy Mode7PlayerY
    jsr Mode7BlockAddress
    pha
    lda LevelBlockPtr
    sta Mode7LastPositionPtr
    pla
    jsr CallBlockEnter
  DontRunSpecialFloor:

  setaxy16

  jsr Mode7DrawInventory

  ldx OamPtr
  jsl ppu_clear_oam
  jsl ppu_pack_oamhi

  jsr BuildHDMATable

  ; Test for the moving sprite system
.if 0
  lda keynew
  and #KEY_B
  beq :+
    lda #1*2
    ldx Mode7PlayerX
    ldy Mode7PlayerY
    .import Mode7CreateActor
    jsr Mode7CreateActor
  :
.endif

  .import Mode7RunActors
  jsr Mode7RunActors

  jmp Loop

  rtl
.endproc

.proc Mode7DoBlockUpdateWide
  ; 3x2, BL+1 and BR+1 go to the right
  .a16
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

.proc Mode7DoBlockUpdateTall
  ; 2x3, BL+1 and BR+1 go below
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
  ldx #0
  lda framecount
  lsr
  bcs :+
    ldx #0+2048
  :
BuildHDMALoop:
  lda 2*176*8,y ; M7A
  sta f:M7A_M7B_Buffer1Data+0,x
  sta f:M7C_M7D_Buffer1Data+2,x
  lda 0,y ; M7B
  sta f:M7A_M7B_Buffer1Data+2,x
  eor #$ffff
  ina
  sta f:M7C_M7D_Buffer1Data+0,x

  inx ; Next HDMA table entry
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

; Not used?
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
  lda M7BlockFlags,y
  and #15
  cmp #1
  rts
Block:
  sec
  rts
.endproc

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


.proc Mode7NMI
  seta8
  pha
  lda #1
  sta BGMODE
  lda #%00010010  ; enable sprites, plane 1
  sta BLENDMAIN
  pla
  plb
  rti
.endproc


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
  tax                 ; assert((a>>8) == 0)
  setaxy16
  ; Find a free index in the block update queue
  ldy #(BLOCK_UPDATE_COUNT-1)*2
FindIndex:
  lda BlockUpdateDataTL+1,y ; Test for empty slot
  and #255
  beq Found
  dey                      ; Next index
  dey
  bpl FindIndex            ; Give up if all slots full
  bra Exit
Found:
  ; From this point on in the routine, Y = free update queue index

  seta8
  ; Mode 7 has 8-bit tile numbers, unlike the main game which has 16-bit tile numbers
  ; so the second byte is mostly unused and can be repurposed. Here TL+1 is used to specify the shape/size of update.
  lda M7BlockTopLeft,x
  sta BlockUpdateDataTL,y
  lda M7BlockTopRight,x
  sta BlockUpdateDataTR,y
  lda M7BlockBottomLeft,x
  sta BlockUpdateDataBL,y
  lda M7BlockBottomRight,x
  sta BlockUpdateDataBR,y
  ; Enable, and mark it as a 16x16 update
  lda #1
  sta BlockUpdateDataTL+1,y
  seta16

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

; A = X coordinate (in pixels)
; Y = Y coordinate (in pixels)
; Output: LevelBlockPtr
.a16
.i16
.export Mode7BlockAddress
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


.a16
.import M7BlockInteractionSet, M7BlockInteractionEnter, M7BlockInteractionExit, M7BlockInteractionBump
GetInteractionSet:
  tay
  lda M7BlockInteractionSet,y
  and #255
  asl
  tay
  rts
CallBlockEnter:
  jsr GetInteractionSet
  lda M7BlockInteractionEnter,y
  pha
  rts
CallBlockExit:
  jsr GetInteractionSet
  lda M7BlockInteractionExit,y
  pha
  rts
CallBlockBump:
  jsr GetInteractionSet
  lda M7BlockInteractionBump,y
  pha
  rts

.a16
.export M7BlockNothing
M7BlockNothing:
.export M7BlockCloneButton
M7BlockCloneButton:
.export M7BlockMessage
M7BlockMessage:
.export M7BlockPushableBlock
M7BlockPushableBlock:
.export M7BlockSpring
M7BlockSpring:
.export M7BlockTeleport
M7BlockTeleport:
.export M7BlockToggleButton1
M7BlockToggleButton1:
.export M7BlockToggleButton2
M7BlockToggleButton2:
.export M7BlockWoodArrow
M7BlockWoodArrow:
  rts

.export M7BlockExit
.proc M7BlockExit
  lda Mode7ChipsLeft
  beq :+
    rts
  :
  .import ExitToOverworld
  jsl WaitVblank
  jml ExitToOverworld
.endproc


; Change a block to what its checkerboard block would be, based on the address
EraseBlock:
  lda LevelBlockPtr
  sta 0
  lsr
  lsr
  lsr
  lsr
  lsr
  lsr
  eor 0
  lsr
  tdc ; A = zero
  adc #Mode7Block::Checker1
  jmp Mode7ChangeBlock

.export M7BlockDirt
.proc M7BlockDirt
  bra EraseBlock
.endproc

.export M7BlockWater
.proc M7BlockWater
  lda Mode7Tools
  and #TOOL_FLIPPERS
  beq :+
    rts
  :
  jmp M7BlockHurt
.endproc

.export M7BlockFire
.proc M7BlockFire
  lda Mode7Tools
  and #TOOL_FIREBOOTS
  beq :+
    rts
  :
  jmp M7BlockHurt
.endproc

.export M7BlockThief
.proc M7BlockThief
  stz Mode7Tools
  rts
.endproc

.export M7BlockFireBoots
.proc M7BlockFireBoots
  lda #TOOL_FIREBOOTS
  tsb Mode7Tools
  bra EraseBlock
.endproc

.export M7BlockFlippers
.proc M7BlockFlippers
  lda #TOOL_FLIPPERS
  tsb Mode7Tools
  bra EraseBlock
.endproc

.export M7BlockSuctionBoots
.proc M7BlockSuctionBoots
  lda #TOOL_SUCTIONBOOTS
  tsb Mode7Tools
  bra EraseBlock
.endproc

.export M7BlockIceSkates
.proc M7BlockIceSkates
  lda #TOOL_ICESKATES
  tsb Mode7Tools
  bra EraseBlock
.endproc

.export M7BlockKey
.proc M7BlockKey
  tdc
  seta8
  lda [LevelBlockPtr]
  sub #Mode7Block::Key1
  tax
  inc Mode7Keys,x  
  seta16
  bra EraseBlock
.endproc

.export M7BlockLock
.proc M7BlockLock
  tdc
  seta8
  lda [LevelBlockPtr]
  sub #Mode7Block::Lock1
  tax
  lda Mode7Keys,x
  bne Unlock
  seta16
  rts
Unlock:
  dec Mode7Keys,x
  seta16
  bra EraseBlock
.endproc

.export M7BlockHurt
.proc M7BlockHurt
  lda #30
  sta Mode7Oops
  rts
.endproc

.export M7BlockIce
.proc M7BlockIce
  jsr CancelIfHaveSkates
  lda Mode7IceDirection
  ora #$8000 | $4000
  sta Mode7ForceMove
  rts
.endproc


IceGoUp:
  lda #$8000 | $4000 | DIRECTION_UP
  sta Mode7ForceMove
  rts
IceGoLeft:
  lda #$8000 | $4000 | DIRECTION_LEFT
  sta Mode7ForceMove
  rts
IceGoDown:
  lda #$8000 | $4000 | DIRECTION_DOWN
  sta Mode7ForceMove
  rts
IceGoRight:
  lda #$8000 | $4000 | DIRECTION_RIGHT
  sta Mode7ForceMove
  rts

.proc CancelIfHaveSkates
  lda Mode7Tools
  and #TOOL_ICESKATES
  beq :+
    pla ; Pop the return address off
    rts
  :
  rts
.endproc
.export M7BlockIceCornerUL
.proc M7BlockIceCornerUL
  jsr CancelIfHaveSkates
  lda Mode7IceDirection
  cmp #DIRECTION_LEFT
  beq IceGoDown
  bra IceGoRight
.endproc
.export M7BlockIceCornerUR
.proc M7BlockIceCornerUR
  jsr CancelIfHaveSkates
  lda Mode7IceDirection
  cmp #DIRECTION_RIGHT
  beq IceGoDown
  bra IceGoLeft
.endproc
.export M7BlockIceCornerDL
.proc M7BlockIceCornerDL
  jsr CancelIfHaveSkates
  lda Mode7IceDirection
  cmp #DIRECTION_LEFT
  beq IceGoUp
  bra IceGoRight
.endproc
.export M7BlockIceCornerDR
.proc M7BlockIceCornerDR
  jsr CancelIfHaveSkates
  lda Mode7IceDirection
  cmp #DIRECTION_RIGHT
  beq IceGoUp
  bra IceGoLeft
.endproc

.proc CancelIfHaveSuctionBoots
  lda Mode7Tools
  and #TOOL_SUCTIONBOOTS
  beq :+
    pla ; Pop the return address off
    rts
  :
  rts
.endproc
.export M7BlockForceLeft
.proc M7BlockForceLeft
  jsr CancelIfHaveSuctionBoots
  lda #$8000 | DIRECTION_LEFT
  sta Mode7ForceMove
  rts
.endproc
.export M7BlockForceDown
.proc M7BlockForceDown
  jsr CancelIfHaveSuctionBoots
  lda #$8000 | DIRECTION_DOWN
  sta Mode7ForceMove
  rts
.endproc
.export M7BlockForceUp
.proc M7BlockForceUp
  jsr CancelIfHaveSuctionBoots
  lda #$8000 | DIRECTION_UP
  sta Mode7ForceMove
  rts
.endproc
.export M7BlockForceRight
.proc M7BlockForceRight
  jsr CancelIfHaveSuctionBoots
  lda #$8000 | DIRECTION_RIGHT
  sta Mode7ForceMove
  rts
.endproc


.export M7BlockTurtle
.proc M7BlockTurtle
  lda #Mode7Block::Water
  jmp Mode7ChangeBlock
.endproc
.export M7BlockBecomeWall
.proc M7BlockBecomeWall
  lda #Mode7Block::Void
  jmp Mode7ChangeBlock
.endproc

.export M7BlockRotateBorderLR
.proc M7BlockRotateBorderLR
  lda #Mode7Block::RotateBorderUD
  jmp Mode7ChangeBlock
.endproc
.export M7BlockRotateBorderUD
.proc M7BlockRotateBorderUD
  lda #Mode7Block::RotateBorderLR
  jmp Mode7ChangeBlock
.endproc

.export M7BlockRotateCornerUL
.proc M7BlockRotateCornerUL
  lda #Mode7Block::RotateCornerUR
  jmp Mode7ChangeBlock
.endproc
.export M7BlockRotateCornerUR
.proc M7BlockRotateCornerUR
  lda #Mode7Block::RotateCornerDR
  jmp Mode7ChangeBlock
.endproc
.export M7BlockRotateCornerDR
.proc M7BlockRotateCornerDR
  lda #Mode7Block::RotateCornerDL
  jmp Mode7ChangeBlock
.endproc
.export M7BlockRotateCornerDL
.proc M7BlockRotateCornerDL
  lda #Mode7Block::RotateCornerUL
  jmp Mode7ChangeBlock
.endproc

.export M7BlockCollect
.proc M7BlockCollect
  lda #15
  sta Mode7HappyTimer

  sed
  lda Mode7ChipsLeft
  sub #1
  sta Mode7ChipsLeft
  cld
  lda #Mode7Block::Hurt
  jmp Mode7ChangeBlock
.endproc
.export M7BlockCountFour
.proc M7BlockCountFour
  lda #Mode7Block::CountThree
  jmp Mode7ChangeBlock
.endproc
.export M7BlockCountThree
.proc M7BlockCountThree
  lda #Mode7Block::CountTwo
  jmp Mode7ChangeBlock
.endproc
.export M7BlockCountTwo
.proc M7BlockCountTwo
  lda #Mode7Block::Collect
  jmp Mode7ChangeBlock
.endproc
.export M7BlockCheckpoint
.proc M7BlockCheckpoint
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
  lda Mode7Keys+0
  sta Mode7CheckpointKeys+0
  lda Mode7Keys+2
  sta Mode7CheckpointKeys+2
  lda Mode7Tools
  sta Mode7CheckpointTools

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
  lda Mode7CheckpointKeys+0
  sta Mode7Keys+0
  lda Mode7CheckpointKeys+2
  sta Mode7Keys+2
  lda Mode7CheckpointTools
  sta Mode7Tools

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

M7A_M7B_Table1:
  ; was 49 originally, but it looks like it has an incorrect scanline when I use 49 with indirect hdma?
  .byt 48
  .addr .loword(0)
  .byt 128 | 127
  .addr .loword(M7A_M7B_Buffer1Data)
  .byt 128 | 49
  .addr .loword(M7A_M7B_Buffer1Data+127*4)
  .byt 0
M7C_M7D_Table1:
  .byt 48
  .addr .loword(0)
  .byt 128 | 127
  .addr .loword(M7C_M7D_Buffer1Data)
  .byt 128 | 49
  .addr .loword(M7C_M7D_Buffer1Data+127*4)
  .byt 0
M7A_M7B_Table2:
  .byt 48
  .addr .loword(0)
  .byt 128 | 127
  .addr .loword(M7A_M7B_Buffer2Data)
  .byt 128 | 49
  .addr .loword(M7A_M7B_Buffer2Data+127*4)
  .byt 0
M7C_M7D_Table2:
  .byt 48
  .addr .loword(0)
  .byt 128 | 127
  .addr .loword(M7C_M7D_Buffer2Data)
  .byt 128 | 49
  .addr .loword(M7C_M7D_Buffer2Data+127*4)
  .byt 0


.segment "Mode7Tiles"
.export Mode7Tiles
Mode7Tiles:
.incbin "../tools/M7Tileset.chrm7", 0, CommonTilesetLength
