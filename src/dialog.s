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

  seta8
  lda #%00010111  ; enable sprites, plane 0, 1 and 2
  sta BLENDMAIN

  seta16
  ; Write graphics
  lda #GraphicsUpload::DialogBG
  jsl DoGraphicUpload
  lda #Palette::FGCommon
  ldy #8
  jsl DoPaletteUpload
  lda #Palette::SPNova
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

  plp
  rtl

.a8
OpPortrait:
  jsr GetParameter
  sta DialogPortrait

  seta16
  .import RenderNameFont
  jsl RenderNameFont
  seta8

  bra StartText

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
  bra StartText

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
  jsr InventoryDialogSharedBackground
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

.include "portraitenum.s"
DemoScript:
  .byt DialogCommand::Portrait, Portrait::Maffi
    .byt TextCommand::Color2, "Hello world", TextCommand::Color1, "! You're looking at an", TextCommand::EndLine, TextCommand::Color3, "example text box", TextCommand::Color1, "! It's actually in the", TextCommand::EndLine, "game this time instead of being a", TextCommand::EndLine, "mockup! This ", TextCommand::Color2, "box", TextCommand::Color1, " can fit a lot of", TextCommand::EndLine, TextCommand::Color3, "text", TextCommand::Color1, ". Maybe that's not a great idea.", TextCommand::EndPage
    .byt "Hello world!", TextCommand::EndLine, "This is another line!", TextCommand::EndLine, TextCommand::BigText, "Hopefully this", TextCommand::EndLine, TextCommand::EndLine, TextCommand::BigText, "works!", TextCommand::ExtendedChar, ExtraChar::Think, TextCommand::EndText
  .byt DialogCommand::End
