; Super Princess Engine
; Copyright (C) 2020 NovaSquirrel
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
MenuBGScroll = SpriteTileBase
.include "vwf.inc"
.smart

.segment "Dialog"
.import InventoryTilemapMenu, InventoryTilemapBG, InventoryTilemapText, InventoryPalette
DialogTileBase = $3e0|InventoryPalette

.import DoPortraitUpload ; Uploads portrait A to address Y; be in vblank
.import PaletteForPortrait, PortraitPaletteData
.import InitVWF, DrawVWF, CopyVWF
.import Mode7HappyTimer
DialogPortrait = Mode7HappyTimer

; Set ScriptPointer before calling
.i16
.a16
.export StartDialog
.proc StartDialog
  php

  .import InventoryDialogSharedInit, InventoryDialogSharedBackground
  .assert ^InventoryDialogSharedInit = ^StartDialog, error, "Dialog and inventory must be in the same bank"
  .assert ^InventoryDialogSharedBackground = ^StartDialog, error, "Dialog and inventory must be in the same bank"
  jsr InventoryDialogSharedInit

  seta16
  lda #(<WINDOWMAIN <<8) | DMA_LINEAR | DMA_FORWARD
  sta DMAMODE+$20
  lda #(<BG3HOFS    <<8) | DMA_00     | DMA_FORWARD
  sta DMAMODE+$30
  lda #.loword(DialogHDMA_WindowEnable)
  sta DMAADDR+$20
  lda #.loword(DialogHDMA_ScrollX)
  sta DMAADDR+$30

  seta8
  lda #%00010111  ; enable sprites, plane 0, 1 and 2
  sta BLENDMAIN
  stz DialogStackIndex

  ; Set up the windows
  lda #%00100000
  sta BG12WINDOW
  lda #32
  sta WINDOW1L
  lda #224
  sta WINDOW1R
  lda #%10
  sta WINDOWMAIN

  lda #^DialogHDMA_WindowEnable
  sta DMAADDRBANK+$20
  sta DMAADDRBANK+$30

  lda #%1100
  sta HDMASTART

  seta16
  ; Write graphics
  lda #GraphicsUpload::DialogBG
  jsl DoGraphicUpload
  lda #Palette::FGCommon
  ldy #8
  jsl DoPaletteUpload
  lda #Palette::FGCommon
  ldy #1
  jsl DoPaletteUpload
  lda #Palette::SPNova ; I think I'm just using this for the name font
  ldy #9
  jsl DoPaletteUpload

  ; Prep the VWF area
  .repeat 6, I
    lda #(InventoryTilemapText>>1)|(8+(3+I)*32)
    sta PPUADDR
    lda #48*16+(I*32)+(3<<10|$2000) ; priority, palette 3
    ldx #20
    jsl WritePPUIncreasing
  .endrep

  ; Create the text box
  lda #(InventoryTilemapMenu>>1)|(3+2*32)
  sta PPUADDR
  jsr TopBox
  ; Do the middle
  ldy #6
: ldx #6
  jsl SkipPPUWords
  lda #DialogTileBase|$05 ; Left vertical bar
  sta PPUDATA
  lda #$03|InventoryPalette ; Portrait area
  ldx #4
  jsl WritePPURepeated
  lda #DialogTileBase|$08 ; Separator between portrait and text
  sta PPUDATA
  lda #$01|InventoryPalette ; Text area
  ldx #19
  jsl WritePPURepeated
  lda #DialogTileBase|$05 ; Right vertical bar
  sta PPUDATA
  dey
  bne :-
  ldx #6
  jsl SkipPPUWords
  ; Do the bottom
  lda #DialogTileBase|$02
  sta PPUDATA
  ldx #24
  lda #DialogTileBase|$04
  jsl WritePPURepeated
  lda #DialogTileBase|$03
  sta PPUDATA

  ; Create the scene box
  lda #(InventoryTilemapMenu>>1)|(3+12*32)
  sta PPUADDR
  jsr TopBox
  ; Do the middle
  ldy #12
: ldx #6
  jsl SkipPPUWords
  lda #DialogTileBase|$05 ; Left vertical bar
  sta PPUDATA
  lda #$00 ; Placeholder area
  ldx #24
  jsl WritePPURepeated
  lda #DialogTileBase|$05 ; Right vertical bar
  sta PPUDATA
  dey
  bne :-
  jsr BottomBox



  ; Set up portrait sprites (and name sprites)
  ldx #0

  seta8
  lda #4*8
  sta OAM_XPOS+(4*0),x
  sta OAM_XPOS+(4*2),x
  sta OAM_YPOS+(4*0),x
  sta OAM_YPOS+(4*1),x
  lda #6*8
  sta OAM_XPOS+(4*1),x
  sta OAM_XPOS+(4*3),x
  sta OAM_YPOS+(4*2),x
  sta OAM_YPOS+(4*3),x

  lda #10
  sta OAM_YPOS+(4*4),x
  sta OAM_YPOS+(4*5),x
  sta OAM_YPOS+(4*6),x
  sta OAM_YPOS+(4*7),x
  sta OAM_YPOS+(4*8),x
  sta OAM_YPOS+(4*9),x

  lda #65+(16*0)
  sta OAM_XPOS+(4*4),x
  lda #65+(16*1)
  sta OAM_XPOS+(4*5),x
  lda #65+(16*2)
  sta OAM_XPOS+(4*6),x
  lda #65+(16*3)
  sta OAM_XPOS+(4*7),x
  lda #65+(16*4)
  sta OAM_XPOS+(4*8),x
  lda #65+(16*5)
  sta OAM_XPOS+(4*9),x

  ; Portrait
  lda #$80
  sta OAM_TILE+(4*0),x
  ina
  ina
  sta OAM_TILE+(4*1),x
  ina
  ina
  sta OAM_TILE+(4*2),x
  ina
  ina
  sta OAM_TILE+(4*3),x

  ; Name
  lda #$a0
  sta OAM_TILE+(4*4),x
  ina
  ina
  sta OAM_TILE+(4*5),x
  ina
  ina
  sta OAM_TILE+(4*6),x
  ina
  ina
  sta OAM_TILE+(4*7),x
  ina
  ina
  sta OAM_TILE+(4*8),x
  ina
  ina
  sta OAM_TILE+(4*9),x

  lda #>(OAM_PRIORITY_2|OAM_COLOR_7)
  sta OAM_ATTR+(4*0),x
  sta OAM_ATTR+(4*1),x
  sta OAM_ATTR+(4*2),x
  sta OAM_ATTR+(4*3),x
  lda #>(OAM_PRIORITY_2|OAM_COLOR_1)
  sta OAM_ATTR+(4*4),x
  sta OAM_ATTR+(4*5),x
  sta OAM_ATTR+(4*6),x
  sta OAM_ATTR+(4*7),x
  sta OAM_ATTR+(4*8),x
  sta OAM_ATTR+(4*9),x

  stz OAMHI+0+(4*0),x
  stz OAMHI+0+(4*1),x
  stz OAMHI+0+(4*2),x
  stz OAMHI+0+(4*3),x
  stz OAMHI+0+(4*4),x
  stz OAMHI+0+(4*5),x
  stz OAMHI+0+(4*6),x
  stz OAMHI+0+(4*7),x
  stz OAMHI+0+(4*8),x
  stz OAMHI+0+(4*9),x
  lda #$02
  sta OAMHI+1+(4*0),x
  sta OAMHI+1+(4*1),x
  sta OAMHI+1+(4*2),x
  sta OAMHI+1+(4*3),x
  sta OAMHI+1+(4*4),x
  sta OAMHI+1+(4*5),x
  sta OAMHI+1+(4*6),x
  sta OAMHI+1+(4*7),x
  sta OAMHI+1+(4*8),x
  sta OAMHI+1+(4*9),x
  seta16
  ldx #4*10
  jsl ppu_clear_oam
  jsl ppu_pack_oamhi

  seta8
  ; Set the pointer to a demo script anyway
  lda #<DemoScript
  sta ScriptPointer+0
  lda #>DemoScript
  sta ScriptPointer+1
  lda #^DemoScript
  sta ScriptPointer+2

  ; Adjust background's scroll to make the text line up correctly
  lda #<(-2)
  sta BGSCROLLX+4
  lda #>(-2)
  sta BGSCROLLX+4
  stz BGSCROLLY+4
  stz BGSCROLLY+4

  seta8
DialogLoop:
  tdc ; Clear accumulator
  lda [ScriptPointer]
  inc16 ScriptPointer ; Step the pointer forward
  asl
  tax
  jsr (.loword(HandleDialogOpcode),x)
  bra DialogLoop

HandleDialogOpcode:
  .addr OpEnd
  .addr OpPortrait
  .addr OpCallAsm
  .addr OpNarrate
  .addr OpCallDialog
  .addr OpReturn
  .addr OpBackground2bpp
  .addr OpUploadGraphics
  .addr OpUploadPalettes
  .addr OpClearMetatiles
  .addr OpSceneMetatiles
  .addr OpSceneTiles
  .addr OpSceneText

.a8
ReturnEndDialog:
OpEnd:
  pla ; \ Undo jsr (.loword(HandleDialogOpcode),x)
  pla ; /

  jsl WaitVblank
  seta8
  lda #FORCEBLANK
  sta PPUBRIGHT
  lda #%00010011 ; Enable only layer 1 and 2
  sta f:BLENDMAIN

  ; Disable window again
  stz BG12WINDOW
  stz WINDOWMAIN
  stz HDMASTART

  plp
  rtl

.a8
OpCallDialog:
  tdc
  lda DialogStackIndex
  tax

  ; Save old pointer
  lda ScriptPointer+0
  add #3 ; Skip over the pointer after this
  sta DialogStackL,x
  lda ScriptPointer+1
  adc #0
  sta DialogStackH,x
  lda ScriptPointer+2
  sta DialogStackB,x

  inc DialogStackIndex

  jsr GetParameter ; Low
  pha
  jsr GetParameter ; High
  pha
  jsr GetParameter ; Bank
  sta ScriptPointer+2
  pla
  sta ScriptPointer+1
  pla
  sta ScriptPointer+0
  rts

.a8
OpReturn:
  dec DialogStackIndex
  tdc
  lda DialogStackIndex
  tax

  ; Restore the pointer
  lda DialogStackL,x
  sta ScriptPointer+0
  lda DialogStackH,x
  sta ScriptPointer+1
  lda DialogStackB,x
  sta ScriptPointer+2
  rts

.a8
OpPortrait:
  jsr GetParameter
  sta DialogPortrait

  seta16
  .import RenderNameFont
  jsl RenderNameFont
  seta8

  jmp StartText

.a8
OpCallAsm:
  jsr GetParameter
  sta 0
  jsr GetParameter
  sta 1
  jsr GetParameter
  sta 2
  jsl :+
  rts
: jmp [0]

.a8
OpNarrate:
  jmp StartText

.a8
OpBackground2bpp:
  ; Parameter 1 = the compressed bitmap to draw
  jsr GetParameter
  jsl DoGraphicUpload

  ; Parameter 2 = the palette to draw it with
  jsr GetParameter
  seta16
  and #255
  asl
  tax
  .import VariablePaletteDirectory, VariablePaletteData
  lda f:VariablePaletteDirectory,x
  tax
  inx ; Skip the first byte, which is the size
  seta8
  ; First color is the background color
  stz CGADDR
  jsr OneColorFromVariablePalette
  lda #5
  sta CGADDR
  ; Now do the remaining three colors
  ldy #3
: jsr OneColorFromVariablePalette
  dey
  bne :-

  seta16
  ; Put increasing tiles on the background
  lda #(InventoryTilemapText>>1)|(4+13*32)
  sta PPUADDR
  lda #384+(1<<10) ; palette 1
  ldy #12
: ldx #24
  jsl WritePPUIncreasing
  ldx #8
  jsl SkipPPUWords
  dey
  bne :-
  seta8
  rts

OneColorFromVariablePalette:
  jsr :+
: lda f:VariablePaletteData,x
  sta CGDATA
  inx
  rts

.a8
OpUploadGraphics:
: jsr GetParameter
  cmp #255
  beq @Exit
  jsl DoGraphicUpload
  bra :-
@Exit:
  rts

.a8
OpUploadPalettes:
  ldy #2
: jsr GetParameter
  cmp #255
  beq @Exit
  jsl DoPaletteUpload
  iny
  bra :-
@Exit:
  rts

.a8
OpClearMetatiles:
  seta16
  lda #(InventoryTilemapMenu>>1)|(4+13*32)
  sta PPUADDR
  ldy #12
: lda #0
  ldx #24
  jsl WritePPURepeated
  ldx #8
  jsl SkipPPUWords
  dey
  bne :-
  seta8
  rts

.a8
OpSceneMetatiles:
  ; %tttt tttP - Block low,  P=reposition
  ; %FRtt tttt - Block high, F=final, R=repeat
  ; %DYYY XXXX - D=down, YX=position (if P set)
  ; %.HHH LLLL - L=amount to repeat (if R set)
  ;              if H is nonzero then it's a rectangle fill with L=width, H=height
.scope MetatileDraw
  BlockID     = 0 ; Block with flags embedded in it
  Direction   = 2 ; 2 or 64, add after applying the block
  Position    = 4 ; VRAM position
  Length      = 6 ; Number of times to repeat horizontally or vertically
  Height      = 8 ; If nonzero, it's a rectangle fill, and Length is a width
  seta16

Loop:
  ; Get one metatile, plus flags
  lda [ScriptPointer]
  inc ScriptPointer
  inc ScriptPointer
  sta BlockID

  tdc ; A = 0
  ina ; A = 1
  sta Length
  stz Height
  trb BlockID
  beq KeepPosition
    lda [ScriptPointer]
    and #%1110000
    asl
    asl
    sta Position
    lda [ScriptPointer]
    and #%0001111
    asl
    ora Position
    add #(InventoryTilemapMenu>>1)|(4+13*32)
    sta Position

    ; Select whether to write across or down
    lda #2
    sta Direction
    lda [ScriptPointer]
    and #128
    beq :+
      lda #64
      sta Direction
    :

    inc ScriptPointer
KeepPosition:

  lda #$4000
  trb BlockID
  beq NoRepeat
    lda [ScriptPointer]
    and #$0f
    sta Length
    lda [ScriptPointer]
    and #$f0
    lsr
    lsr
    lsr
    lsr
    sta Height

    inc ScriptPointer
NoRepeat:

  ; Save whether or not to finish after this block
  lda #$8000
  trb BlockID
  php

  ; If no height, just do a rectangle fill
  lda Height
  beq WriteMetatileLoop
WriteMetatileRect:
@NextRow:
  lda Position
  pha
  lda Length
  pha

@Row:
  jsr DrawOneMetatile
  inc Position
  inc Position
  dec Length
  bne @Row

  pla
  sta Length
  pla
  add #64      ; Next row of metatiles
  sta Position
  dec Height
  bne @NextRow
  bra Done

; Write a line of metatiles across or down
WriteMetatileLoop:
  jsr DrawOneMetatile
  lda Position
  add Direction ; 2 or 64, to go right or down
  sta Position
  dec Length
  bne WriteMetatileLoop

; Pull the "finished" bit from the stack
Done:
  plp
  jeq Loop
  seta8
.endscope
  rts

.a16
; Draw a single metatile on the screen at a position
DrawOneMetatile:
  .import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight
  lda MetatileDraw::Position
  sta PPUADDR
  ldx MetatileDraw::BlockID
  lda f:BlockTopLeft,x
  sta PPUDATA
  lda f:BlockTopRight,x
  sta PPUDATA
  lda MetatileDraw::Position
  add #32
  sta PPUADDR
  lda f:BlockBottomLeft,x
  sta PPUDATA
  lda f:BlockBottomRight,x
  sta PPUDATA
  rts

.a8
OpSceneTiles:
  rts

.a8
OpSceneText:
  seta16
  ; Calculate the position from the X,Y first
  lda [ScriptPointer]
  inc ScriptPointer
  and #255
  sta 0
  lda [ScriptPointer]
  and #255
  inc ScriptPointer
  asl
  asl
  asl
  asl
  asl
  ora 0
  add #(InventoryTilemapMenu>>1)|(4+13*32)
  sta 2 ; Backup
  sta PPUADDR
@Loop:
  lda [ScriptPointer]
  inc ScriptPointer
  and #255
  beq @Done
  cmp #10 ; Newline character
  beq @NextLine
  add #(896-32)|(1<<10)
  sta PPUDATA
  bra @Loop
@Done:
  seta8
  rts
.a16
@NextLine:
  lda 2
  add #32
  sta PPUADDR
  sta 2
  bra @Loop

.a8
; Get one byte of parameter
GetParameter:
  lda [ScriptPointer]
  inc16 ScriptPointer
  rts

.a8
StartText:
  ; Copy over the pointer
  lda ScriptPointer+0
  sta DecodePointer+0
  lda ScriptPointer+1
  sta DecodePointer+1
  lda ScriptPointer+2
  sta DecodePointer+2
  jsl InitVWF
  jsl DrawVWF
  phx
  jsl WaitVblank

  jsl CopyVWF
  jsl ppu_copy_oam
.a8 ; ppu_copy_oam leaves it 8-bit as a side effect
  ; Get the portrait ready
  lda DialogPortrait
  ldy #$9000 >> 1
  jsl DoPortraitUpload ; preserves A
  seta16
  ; Get palette number
  and #255
  tax
  lda f:PaletteForPortrait,x

  ; Get index into the list of portrait palettes
  and #255
  asl ; * 16 first for the number of colors
  asl
  asl
  asl
  asl ; * 2 for two bytes per color
  adc #.loword(PortraitPaletteData)
  sta DMAADDR
  lda #DMAMODE_CGDATA
  sta DMAMODE
  lda #15*2
  sta DMALEN
  ; Copy the palette in
  seta8
  lda #15*16+1
  sta CGADDR
  lda #^PortraitPaletteData
  sta DMAADDRBANK
  lda #%00000001
  sta COPYSTART

  seta16
  lda #$9400 >> 1
  ldy #12*32
  .import UploadNameFont
  jsl UploadNameFont

@WaitForKey:
  jsl WaitVblank
  jsl WaitKeysReady
  jsr InventoryDialogSharedBackground ; Also turns rendering on
  seta16
  lda keynew
  and #KEY_A
  beq @WaitForKey

  plx
  seta8
  ; Copy the pointer back
  lda DecodePointer+0
  sta ScriptPointer+0
  lda DecodePointer+1
  sta ScriptPointer+1
  lda DecodePointer+2
  sta ScriptPointer+2
  jmp (.loword(HandleReturnCode),x)
HandleReturnCode:
  .addr ReturnEndText
  .addr ReturnEndDialog
  .addr ReturnEndPage
  .addr ReturnPortrait

ReturnEndText:
  rts
ReturnEndPage:
  jmp StartText
ReturnPortrait:
  jmp OpPortrait
.endproc

.proc DialogIRQHandler
  pha
  php
  seta8
  lda f:TIMESTATUS ; Acknowledge interrupt
  lda #%00010111 ; Enable all layers
  sta f:BLENDMAIN
  plp
  pla
  rti
.endproc

.proc DialogNMIHandler
  seta8
  pha
  lda #%000100100 ; Only show layer 3
  sta f:BLENDMAIN

  lda #VBLANK_NMI|AUTOREAD|HVTIME_IRQ ; enable HV IRQ
  sta PPUNMI
  lda #220
  sta HTIME
  stz HTIME+1
  lda #48
  sta VTIME
  sta VTIME+1

  pla
  plb
  rti
.endproc

.a16
.i16
.proc TopBox
  lda #DialogTileBase|$00
  sta PPUDATA
  ldx #24
  lda #DialogTileBase|$04
  jsl WritePPURepeated
  lda #DialogTileBase|$01
  sta PPUDATA
  rts
.endproc

.a16
.i16
.proc BottomBox
  ldx #6
  jsl SkipPPUWords
  ; Do the bottom
  lda #DialogTileBase|$02
  sta PPUDATA
  ldx #24
  lda #DialogTileBase|$04
  jsl WritePPURepeated
  lda #DialogTileBase|$03
  sta PPUDATA
  rts
.endproc

DialogHDMA_ScrollX:
  .byt 100, <(-2), >(-2)
  .byt 100, 0, 0
  .byt 0
DialogHDMA_WindowEnable:
  .byt 100, 0
  .byt 100, %10
  .byt 1,   0
  .byt 0



.include "portraitenum.s"

MT_Reposition = $0001
MT_Repeat     = $4000
MT_Finish     = $8000

DemoScriptScene:
  .byt DialogCommand::Background2bpp, GraphicsUpload::DialogForest, VariablePalette::ForestBG
  .byt DialogCommand::SceneMetatiles
  .word MT_Reposition|MT_Repeat|MT_Finish|128
  .byt $50
  .byt 12
  .byt DialogCommand::Return

DemoScript:
  .byt DialogCommand::Call
  .faraddr DemoScriptScene

  .byt DialogCommand::Portrait, Portrait::Maffi
    .byt TextCommand::Color2, "Hello world", TextCommand::Color1, TextCommand::ExtendedChar, ExtraChar::Pawprint, TextCommand::EndText
  .byt DialogCommand::End


.if 0
  .byt DialogCommand::ClearMetatiles

  .byt DialogCommand::SceneMetatiles
  .word MT_Reposition|8
  .byt $00 ; 0,0
  .word MT_Reposition|4
  .byt $11 ; 1,1
  .word MT_Reposition|8
  .byt $33 ; 3,3
  .word MT_Reposition|MT_Repeat|8
  .byt $55 ; 5,5
  .byt 4   ; 4 blocks long
  .word MT_Finish|MT_Reposition|MT_Repeat|4
  .byt $05 ; 5,0
  .byt $33 ; rectangle fill: 3 by 3

  .byt DialogCommand::Background2bpp, GraphicsUpload::DialogForest, VariablePalette::ForestBG

  .byt DialogCommand::UploadGraphics, GraphicsUpload::CurlyFont, 255

  .byt DialogCommand::SceneText, 4,4, "Hello world!",10,"Multiple lines!",0

  .byt DialogCommand::Portrait, Portrait::Maffi
    .byt TextCommand::Color2, "Hello world", TextCommand::Color1, "! You're looking at an", TextCommand::EndLine, TextCommand::Color3, "example text box", TextCommand::Color1, "! It's actually in the", TextCommand::EndLine, "game this time instead of being a", TextCommand::EndLine, "mockup! This ", TextCommand::Color2, "box", TextCommand::Color1, " can fit a lot of", TextCommand::EndLine, TextCommand::Color3, "text", TextCommand::Color1, ". Maybe that's not a great idea.", TextCommand::EndPage
    .byt "Hello world!", TextCommand::EndLine, "This is another line!", TextCommand::EndLine, TextCommand::BigText, "Hopefully this", TextCommand::EndLine, TextCommand::EndLine, TextCommand::BigText, "works!", TextCommand::ExtendedChar, ExtraChar::Think, TextCommand::EndText
  .byt DialogCommand::End
.endif
