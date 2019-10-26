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
.include "graphicsenum.s"
.include "paletteenum.s"
.include "m7leveldata.inc"
.smart
.importzp hm_node
.import huffmunch_load_snes, huffmunch_read_snes

Mode7LevelMap = LevelBuf

M7A_M7B_Buffer1 = HDMA_Buffer1
M7C_M7D_Buffer1 = HDMA_Buffer1+1024
M7A_M7B_Buffer2 = HDMA_Buffer2
M7C_M7D_Buffer2 = HDMA_Buffer2+1024

.import m7a_m7b_0
.import m7c_m7d_0
.import m7a_m7b_list
.import m7c_m7d_list

.segment "BSS"
Mode7ScrollX:    .res 2
Mode7ScrollY:    .res 2
Mode7PlayerX:    .res 2
Mode7PlayerY:    .res 2
Mode7RealAngle:  .res 2 ; 0-31
Mode7Direction:  .res 2 ; 0-3
Mode7Turning:    .res 2
Mode7TurnWanted: .res 2
Mode7Sidestep:       .res 2
Mode7SidestepWanted: .res 2
Mode7SidestepDir:    .res 2

.segment "Mode7Game"

.export Mode7Test
.proc Mode7Test
  phk
  plb

  setaxy16
  ; Clear variables
  stz Mode7ScrollX
  stz Mode7ScrollY
  stz Mode7RealAngle
  stz Mode7Direction
  stz Mode7Turning
  stz Mode7TurnWanted
  stz Mode7PlayerX
  stz Mode7PlayerY
  stz Mode7Sidestep
  stz Mode7SidestepWanted

  seta8
  ; Transparency outside the mode 7 plane
  lda #M7_NOWRAP
  sta M7SEL
  lda #^Mode7LevelMap
  sta LevelBlockPtr+2


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
  ldy #8
  jsl DoPaletteUpload
  lda #GraphicsUpload::SPCommon
  jsl DoGraphicUpload
  lda #GraphicsUpload::MaffiM7TempWalk
  jsl DoGraphicUpload
  lda #Palette::SPMaffi
  ldy #8
  jsl DoPaletteUpload

  ; -----------------------------------

  ; Upload graphics
  stz PPUADDR
  lda #DMAMODE_PPUHIDATA
  ldx #$ffff & Mode7Tiles
  ldy #Mode7TilesEnd-Mode7Tiles
  jsl ppu_copy

  ; -----------------------------------

  ; Clear level map with a checkerboard pattern
  ldx #0
  lda #$0102
CheckerLoop:
  ldy #32
  xba
: sta f:Mode7LevelMap,x
  inx
  inx
  dey
  bne :-
  cpx #4096
  bne CheckerLoop

  ; Decompress a level of some sort
  seta8
  .import M7Level_sample2
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

  seta16
  ldx #0
  jsl huffmunch_load_snes

  ; Read out the level
  tay ; Y = compressed file size
  ldx #0
  seta8
DecompressReadLoop:
  phx
  phy
  jsl huffmunch_read_snes
  ply
  plx
  cmp #1 ; Keep the checkerboard if it's 1
  beq :+
    sta f:Mode7LevelMap,x
  :
  inx
  dey
  bne DecompressReadLoop
  seta16


  ; .----------------------------------
  ; | Render Mode7LevelMap
  ; '----------------------------------
  seta8
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

  lda #%00010000  ; enable sprites, plane 1
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

  lda Mode7Sidestep
  beq NoSidestep
    lda Mode7SidestepDir
    asl
    tax

    lda Mode7PlayerX
    add ForwardX,x
    sta Mode7PlayerX

    lda Mode7PlayerY
    add ForwardY,x
    sta Mode7PlayerY

    ; Stop a vertical sidestep when Y is lined up
    lda Mode7SidestepDir
    lsr
    bcs :+
      lda Mode7PlayerY
      and #15
      beq @Stop
    :

    ; Stop a horizontal sidestep when X is lined up
    lda Mode7SidestepDir
    lsr
    bcc :+
      lda Mode7PlayerX
      and #15
      beq @Stop
    :

    bra :+
    @Stop:
      stz Mode7Sidestep
    :
    jmp WasRotation
  NoSidestep:

  ; ---------------

  lda Mode7Turning
  jne AlreadyTurning
    lda keydown
    and #KEY_LEFT|KEY_RIGHT
    tsb Mode7TurnWanted
    lda keydown
    and #KEY_L|KEY_R
    tsb Mode7SidestepWanted

    ; Can't turn except directly on a tile
    lda Mode7PlayerX
    ora Mode7PlayerY
    and #15
    jne AlreadyTurning

    lda Mode7SidestepWanted
    and #KEY_L
    beq NoSidestepL
      stz Mode7SidestepWanted
      lda Mode7Direction
      inc
      and #3
      sta Mode7SidestepDir
      asl
      tax
      jsr CheckWallAhead
      bcs NoSidestepL
        inc Mode7Sidestep
        jmp WasRotation
    NoSidestepL:

    lda Mode7SidestepWanted
    and #KEY_R
    beq NoSidestepR
      stz Mode7SidestepWanted
      lda Mode7Direction
      dec
      and #3
      sta Mode7SidestepDir
      asl
      tax
      jsr CheckWallAhead
      bcs NoSidestepR
        inc Mode7Sidestep
        jmp WasRotation
    NoSidestepR:

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
      stz Mode7Sidestep
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
      stz Mode7Sidestep
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
  ; If not rotating, move forward
  lda Mode7Direction
  asl
  tax

  ; Only move forward when you press up
  lda Mode7PlayerX
  ora Mode7PlayerY
  and #15
  bne :+
    lda keydown
    and #KEY_UP
    beq WasRotation
  :

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
  lda Mode7PlayerX
  sub #7*16+8
  sta Mode7ScrollX
  lda Mode7PlayerY
  sub #11*16+8
  sta Mode7ScrollY


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


  ; Draw a crappy temporary walk animation
  ldy OamPtr
  lda framecount
  lsr
  and #%1100
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

  lda #$02
  sta OAMHI+1+(4*0),y
  sta OAMHI+1+(4*1),y
  sta OAMHI+1+(4*2),y
  sta OAMHI+1+(4*3),y
  seta16
  tya
  add #4*4
  sta OamPtr



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
  ph2banks m7a_m7b_0, m7a_m7b_0
  plb
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

  phk
  plb

  jmp Loop

  rtl
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
.incbin "../tools/M7Tileset.chrm7"
Mode7TilesEnd:

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
  .byt Floor ;Unused2
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
  .byt Floor ;FlyingBlock
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
  .raddr .loword(DoNothing) ;Hurt
  .raddr .loword(DoNothing) ;Spring
  .raddr .loword(DoNothing) ;ForceDown
  .raddr .loword(DoNothing) ;ForceUp
  .raddr .loword(DoNothing) ;ForceLeft
  .raddr .loword(DoNothing) ;ForceRight
  .raddr .loword(DoNothing) ;Unused1
  .raddr .loword(DoNothing) ;Unused2
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

DoNothing:
  rts

DoCollect:
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
