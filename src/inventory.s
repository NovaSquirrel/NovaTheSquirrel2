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
.smart

.segment "Inventory"
.import InitVWF, DrawVWF, CopyVWF, KeyRepeat
CursorTopMenu = CursorX + 1
.import Mode7ScrollX, Mode7ScrollY ; Reuse these since it's not used during the inventory
MenuBGScroll = SpriteTileBase
.include "vwf.inc"


TopMenuStrings:
  .addr StringReset, StringToss, StringOptions, StringHelp, StringExitLevel

StringReset:
  .byt TextCommand::WideText, "Reset"
  .byt TextCommand::EndLine, "Reset to the most recent"
  .byt TextCommand::EndLine, "checkpoint and try again"
  .byt TextCommand::EndText

StringToss:
  .byt TextCommand::WideText, "Toss"
  .byt TextCommand::EndLine, "Remove items from your"
  .byt TextCommand::EndLine, "inventory"
  .byt TextCommand::EndText

StringOptions:
  .byt TextCommand::WideText, "Options"
  .byt TextCommand::EndLine, "Change the control scheme"
  .byt TextCommand::EndLine, "and other options"
  .byt TextCommand::EndText

StringHelp:
  .byt TextCommand::WideText, "Help"
  .byt TextCommand::EndLine, "Check out the enclosed"
  .byt TextCommand::EndLine, "instruction book"
  .byt TextCommand::EndText

StringExitLevel:
  .byt TextCommand::WideText, "Exit level"
  .byt TextCommand::EndLine, "Return to the overworld map"
  .byt TextCommand::EndText


.i16
.a16
.export OpenInventory
.proc OpenInventory
  phk
  plb

  stz CursorX
  lda #1
  sta CursorY

  jsr InventoryDialogSharedInit
  seta8

  lda #<(-4)
  sta BGSCROLLY+0
  lda #>(-4)
  sta BGSCROLLY+0

  ; Text layer is offset a little different
  lda #<(-1)
  sta BGSCROLLX+4
  lda #>(-1)
  sta BGSCROLLX+4
  lda #<(-4)
  sta BGSCROLLY+4
  lda #>(-4)
  sta BGSCROLLY+4

  lda #%00010111  ; enable sprites, plane 0, 1 and 2
  sta BLENDMAIN

  seta16
  ; Write graphics
  lda #GraphicsUpload::InventoryBG
  jsl DoGraphicUpload
  lda #GraphicsUpload::InventorySprite
  jsl DoGraphicUpload



  ; Temporary until I start actually preloading this with the first selected item
  jsl InitVWF
  jsl CopyVWF

  ; Prep the VWF area
  seta16
  .repeat 5, I
    lda #($e000>>1)|(8+(21+I)*32)
    sta PPUADDR
    lda #8*32+(I*32)+(4<<10|$2000) ; priority, palette 4
    ldx #16
    jsl WritePPUIncreasing
  .endrep

  ; Put in background for the VWF area
  lda #$c550>>1
  sta PPUADDR
  ldy #5
VWFBackLoop:
  ldx #16
  lda #$3e
: sta PPUDATA
  dex
  bne :-

  ldx #16
: lda PPUDATARD
  dex
  bne :-

  dey
  bne VWFBackLoop


  seta16
  lda #Palette::InventorySprite
  ldy #8
  jsl DoPaletteUpload

  ; ---------------

  lda #$0a0c
  sta 0
  lda #(ForegroundBG + (5*64 + 3*2))>>1
  jsr MakeWindow

  lda #$0a0c
  sta 0
  lda #(ForegroundBG + (5*64 + 17*2))>>1
  jsr MakeWindow

  lda #$0702
  sta 0
  lda #(ForegroundBG + (0*64 + 3*2))>>1
  jsr MakeWindow

  lda #$0e02
  sta 0
  lda #(ForegroundBG + (0*64 + 13*2))>>1
  jsr MakeWindow

  lda #$1005
  sta 0
  lda #(ForegroundBG + (20*64 + 7*2))>>1
  jsr MakeWindow

  ; Money (Top row)
  lda #(ForegroundBG + (1*64 + 4*2))>>1
  sta PPUADDR
  lda #$5a
  sta PPUDATA
  ina
  sta PPUDATA
  lda MoneyAmount+2
  and #255
  ora #$50
  sta PPUDATA
  lda MoneyAmount+1
  jsr MoneyTop
  lda MoneyAmount+0
  jsr MoneyTop

  ; Money (Bottom row)
  lda #(ForegroundBG + (2*64 + 4*2))>>1
  sta PPUADDR
  lda #$6a
  sta PPUDATA
  ina
  sta PPUDATA
  lda MoneyAmount+2
  and #255
  ora #$60
  sta PPUDATA
  lda MoneyAmount+1
  jsr MoneyBottom
  lda MoneyAmount+0
  jsr MoneyBottom

  ; Action icons
  lda #(ForegroundBG + (1*64 + 14*2))>>1
  sta PPUADDR
  ldx #.loword(IconStringTop)
  jsr PutStringX

  lda #(ForegroundBG + (2*64 + 14*2))>>1
  sta PPUADDR
  ldx #.loword(IconStringBottom)
  jsr PutStringX
  
  ; Inventory titles
  lda #(ForegroundBG + (6*64 + 4*2))>>1
  sta PPUADDR
  lda #$3e
  sta PPUDATA
  lda #$30
  ldx #8
  jsl WritePPUIncreasing
  lda #$3e
  sta PPUDATA

  lda #(ForegroundBG + (7*64 + 4*2))>>1
  sta PPUADDR
  lda #$4e
  sta PPUDATA
  lda #$40
  ldx #8
  jsl WritePPUIncreasing
  lda #$4e
  sta PPUDATA


  lda #(ForegroundBG + (6*64 + 18*2))>>1
  sta PPUADDR
  lda #$3e
  sta PPUDATA
  sta PPUDATA
  lda #$38
  ldx #6
  jsl WritePPUIncreasing
  lda #$3e
  sta PPUDATA
  sta PPUDATA

  lda #(ForegroundBG + (7*64 + 18*2))>>1
  sta PPUADDR
  lda #$4e
  sta PPUDATA
  sta PPUDATA
  lda #$48
  ldx #6
  jsl WritePPUIncreasing
  lda #$4e
  sta PPUDATA
  sta PPUDATA

  ; Circles!
  lda #(ForegroundBG + (8*64 + 4*2))>>1
  sta PPUADDR

  ldy #5
: jsr CircleTop
  ldx #4
  jsl SkipPPUWords
  jsr CircleTop
  ldx #8
  jsl SkipPPUWords
 
  jsr CircleBottom
  ldx #4
  jsl SkipPPUWords
  jsr CircleBottom
  ldx #8
  jsl SkipPPUWords
  dey
  bne :-

.if 0
  ; Maffi platform
  lda #(ForegroundBG + (22*64 + 26*2))>>1
  sta PPUADDR
  lda #$1f
  sta PPUDATA
  dea
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  lda #$2f
  sta PPUDATA
.endif

  ; -----------------------------------
  ; Main inventory loop
Loop:
  setaxy16
  jsl WaitKeysReady
  jsl KeyRepeat

  seta8
  ; Handle vertical cursor movement
  lda keynew+1
  and #>KEY_UP
  beq :+
    dec CursorY
    bpl :+
      lda #5
      sta CursorY
  :

  lda keynew+1
  and #>KEY_DOWN
  beq :+
    inc CursorY
    lda CursorY
    cmp #6
    bne :+
      stz CursorY
  :

  ; Handle horizontal cursor movement
  lda CursorY
  beq CursorTopRow
CursorNotTopRow:

  lda keynew+1
  and #>KEY_LEFT
  beq :+
    dec CursorX
    bpl :+
      lda #9
      sta CursorX
  :

  lda keynew+1
  and #>KEY_RIGHT
  beq :+
    inc CursorX
    lda CursorX
    cmp #10
    bne :+
      stz CursorX
  :

  bra CursorWasNotTopRow
CursorTopRow:

  lda keynew+1
  and #>KEY_LEFT
  beq :+
    dec CursorTopMenu
    bpl :+
      lda #4
      sta CursorTopMenu
  :

  lda keynew+1
  and #>KEY_RIGHT
  beq :+
    inc CursorTopMenu
    lda CursorTopMenu
    cmp #5
    bne :+
      stz CursorTopMenu
  :

  ; Exit from the level
  lda keynew
  and #KEY_A
  beq :+
    lda CursorTopMenu
    cmp #4
    bne :+
      .import ExitToOverworld
      jml ExitToOverworld
  :

CursorWasNotTopRow:

  ; Display the cursor
  lda CursorX
  cmp #5
  bcc :+
    ina
    ina
  :
  asl
  asl
  asl
  asl
  adc #<-3 ; Carry always zero here
  add #4*8
  sta 0

  lda CursorY
  asl
  asl
  asl
  asl
  add #(8-2)*8
  sta 1

  ; Top row displays differently
  lda CursorY
  bne :+
    lda CursorTopMenu
    asl
    adc CursorTopMenu
    asl
    asl
    asl
    add #14*8-3
    sta 0

    lda #1*8
    sta 1
  :

  lda 0
  sta OAM_XPOS+(4*0)
  sta OAM_XPOS+(4*2)
  add #6
  sta OAM_XPOS+(4*1)
  sta OAM_XPOS+(4*3)

  lda 1
  sta OAM_YPOS+(4*0)
  sta OAM_YPOS+(4*1)
  add #6
  sta OAM_YPOS+(4*2)
  sta OAM_YPOS+(4*3)

  stz OAM_TILE+(4*0)
  stz OAM_TILE+(4*1)
  stz OAM_TILE+(4*2)
  stz OAM_TILE+(4*3)
  lda #>(OAM_PRIORITY_2)
  sta OAM_ATTR+(4*0)
  lda #>(OAM_PRIORITY_2|OAM_XFLIP)
  sta OAM_ATTR+(4*1)
  lda #>(OAM_PRIORITY_2|OAM_YFLIP)
  sta OAM_ATTR+(4*2)
  lda #>(OAM_PRIORITY_2|OAM_XFLIP|OAM_YFLIP)
  sta OAM_ATTR+(4*3)

  stz OAMHI+0+(4*0)
  stz OAMHI+0+(4*1)
  stz OAMHI+0+(4*2)
  stz OAMHI+0+(4*3)
  lda #$02
  sta OAMHI+1+(4*0)
  sta OAMHI+1+(4*1)
  sta OAMHI+1+(4*2)
  sta OAMHI+1+(4*3)

  ldx #4*4
  stx OamPtr





  lda keynew+1
  and #>KEY_START
  jne Exit

MAFFI_LEFT = 13*8
  ; Draw Maffi
  lda #208-MAFFI_LEFT
  sta 0
  lda #179-16
  sta 1
  lda #$1b
  sta 2
  lda #5
  jsr HorizontalSpriteStrip

  lda #208-MAFFI_LEFT
  sta 0
  lda #179-8-16
  sta 1
  lda #$0b
  sta 2
  lda #5
  jsr HorizontalSpriteStrip

  lda retraces
  and #64
  beq ZZZAlternate

  lda #208+8-MAFFI_LEFT
  sta 0
  lda #179-16-16
  sta 1
  lda #$17
  sta 2
  lda #4
  jsr HorizontalSpriteStrip

  lda #208+8-MAFFI_LEFT
  sta 0
  lda #179-24-16
  sta 1
  lda #$07
  sta 2
  lda #3
  jsr HorizontalSpriteStrip

  bra NotZZZAlternate
ZZZAlternate:

  lda #208+8-MAFFI_LEFT
  sta 0
  lda #179-16-16
  sta 1
  lda #$14
  sta 2
  lda #3
  jsr HorizontalSpriteStrip

  lda #240-MAFFI_LEFT
  sta 0
  lda #$1a
  sta 2
  lda #1
  jsr HorizontalSpriteStrip

  lda #208+8-MAFFI_LEFT
  sta 0
  lda #179-24-16
  sta 1
  lda #$04
  sta 2
  lda #3
  jsr HorizontalSpriteStrip

NotZZZAlternate:

  ; Refresh the description if needed
  lda keynew+1
  and #>(KEY_LEFT|KEY_RIGHT|KEY_DOWN|KEY_UP)
  beq :+
    jsr RefreshItemDescription
  :

  seta16

  ldx OamPtr
  jsl ppu_clear_oam
  jsl ppu_pack_oamhi

  setaxy16
  jsl WaitVblank
  jsl CopyVWF
  jsl ppu_copy_oam

  jsr InventoryDialogSharedBackground
  jmp Loop

Exit:
  jsl WaitVblank
  seta8
  lda #FORCEBLANK
  sta PPUBRIGHT
  .import UploadLevelGraphics
  jml UploadLevelGraphics
.endproc

; Redraw the item description for whatever the player is currently pointing at
.proc RefreshItemDescription
  jsl InitVWF

  seta8

  lda CursorY
  bne ItemDescription
  tdc ; Clear A
  lda CursorTopMenu
  asl
  tax
  lda TopMenuStrings+0,x
  sta DecodePointer+0
  lda TopMenuStrings+1,x
  sta DecodePointer+1
  lda #^StringReset
  sta DecodePointer+2
  jsl DrawVWF
  rts

ItemDescription:
  rts
.endproc


.a16
.proc MoneyTop
  and #255
  pha
  lsr
  lsr
  lsr
  lsr
  ora #$50
  sta PPUDATA
  pla
  and #$0f
  ora #$50
  sta PPUDATA
  rts
.endproc

.a16
.proc MoneyBottom
  and #255
  pha
  lsr
  lsr
  lsr
  lsr
  ora #$60
  sta PPUDATA
  pla
  and #$0f
  ora #$60
  sta PPUDATA
  rts
.endproc

.a16
.proc MakeWindow
  Address = 2
  Height  = 0
  Width   = 1
  setxy8
  sta Address

  ; Top row
  sta PPUADDR
  lda #$1c
  sta PPUDATA
  jsr Horizontal
  lda #$1d
  sta PPUDATA
  
  ; Bottom row
  lda Height
  and #255
  xba
  lsr
  lsr
  lsr
  add #32
  add Address
  sta PPUADDR
  lda #$2c
  sta PPUDATA
  jsr Horizontal
  lda #$2d
  sta PPUDATA

  ; Vertical writes
  ldx #INC_DATAHI|VRAM_DOWN
  stx PPUCTRL

  lda Address
  add #32
  sta PPUADDR
  jsr Vertical

  lda Width
  and #255
  add Address
  add #32+1
  sta PPUADDR
  jsr Vertical

  ; Horizontal writes again
  ldx #INC_DATAHI
  stx PPUCTRL
  setxy16
  rts

Horizontal:
  ldx Width
  lda #$1e
: sta PPUDATA
  dex
  bne :-
  rts
Vertical:
  ldx Height
  lda #$2e
: sta PPUDATA
  dex
  bne :-
  rts
.endproc

IconStringTop:    .byt $10, $11, $3e, $12, $13, $3e, $14, $15, $3e, $16, $17, $3e, $18, $19, 0
IconStringBottom: .byt $20, $21, $3e, $22, $23, $3e, $24, $25, $3e, $26, $27, $3e, $28, $29, 0

.a16
.proc PutStringX
  lda a:0,x
  and #255
  beq Exit
  sta PPUDATA
  inx
  bra PutStringX
Exit:
  rts
.endproc

.proc CircleTop
  ldx #5
: lda #$1a
  sta PPUDATA
  ina
  sta PPUDATA
  dex
  bne :-
  rts
.endproc

.proc CircleBottom
  ldx #5
: lda #$2a
  sta PPUDATA
  ina
  sta PPUDATA
  dex
  bne :-
  rts
.endproc

; 0 X position
; 1 Y position
; 2 Tile
; A = width
.a8
.proc HorizontalSpriteStrip
XPos  = 0
YPos  = 1
Tile  = 2
Width = 3
  ldx OamPtr

  sta Width
Loop:
  lda XPos
  sta OAM_XPOS,x
  add #8
  sta XPos

  lda YPos
  sta OAM_YPOS,x
  lda Tile
  inc Tile
  sta OAM_TILE,x
  lda #>OAM_PRIORITY_2
  sta OAM_ATTR,x
  stz OAMHI+0,x
  stz OAMHI+1,x

  inx
  inx
  inx
  inx
  dec Width
  bne Loop

  stx OamPtr
  rts
.endproc


.export InventoryDialogSharedInit
.proc InventoryDialogSharedInit
  jsl WaitVblank
  ; Initialize the background scroll effect
  stz MenuBGScroll

  seta8
  lda #FORCEBLANK
  sta PPUBRIGHT
  lda #1|BG3_PRIORITY
  sta BGMODE
  ; 32x32 tilemaps on all backgrounds
  lda #0 | ($c000 >> 9) ; Foreground
  sta NTADDR+0
  lda #0 | ($d000 >> 9) ; Background
  sta NTADDR+1
  lda #0 | ($e000 >> 9) ; Text
  sta NTADDR+2

  ; Reset all scrolling
  ldx #2*3-1
: stz BGSCROLLX,x
  stz BGSCROLLX,x
  dex
  bpl :-

  seta16
  lda #GraphicsUpload::InventoryBG2
  jsl DoGraphicUpload

  ; Clear the screens
  ldx #$c000 >> 1 ; Foreground
  ldy #0
  jsl ppu_clear_nt
  ldx #$e000 >> 1 ; Text
  ldy #32*8+31
  jsl ppu_clear_nt
  ; Don't clear D000 because it will be completely overwritten soon
  setaxy16

  ; Write palettes for everything else
  lda #Palette::InventoryBG
  ldy #0
  jsl DoPaletteUpload
  lda #Palette::InventoryBG2
  ldy #2
  jsl DoPaletteUpload

  lda #$d000 >> 1
  sta PPUADDR
BGFill:
  ldy #8
@Loop2:
  lda #128 | (2<<10)
  sta 0
@Loop:
  ldx #8
  : lda 0
    sta PPUDATA
    ina
    sta PPUDATA
    ina
    sta PPUDATA
    ina
    sta PPUDATA
    dex
    bne :-
  lda 0
  add #4
  sta 0
  cmp #128 + (4*4) | (2<<10)
  bne @Loop
  dey
  bne @Loop2

  ; Set palette for text
  seta8
  lda #17
  sta CGADDR
  lda #<RGB(0,0,0)
  sta CGDATA
  lda #>RGB(0,0,0)
  sta CGDATA
  lda #<RGB(31,0,0)
  sta CGDATA
  lda #>RGB(31,0,0)
  sta CGDATA
  lda #<RGB(0,0,31)
  sta CGDATA
  lda #>RGB(0,0,31)
  sta CGDATA
  rts
.endproc

.export InventoryDialogSharedBackground
.proc InventoryDialogSharedBackground
  seta16
  ; Slowly move the background diagonally
  lda MenuBGScroll
  add #$04
  sta MenuBGScroll
  lsr
  lsr
  lsr
  lsr
  sta 0

  ; Turn rendering on
  seta8
  lda #15
  sta PPUBRIGHT

  lda 0
  sta BGSCROLLX+2
  lda 1
  sta BGSCROLLX+2
  lda 0
  sta BGSCROLLY+2
  lda 1
  sta BGSCROLLY+2
  rts
.endproc


