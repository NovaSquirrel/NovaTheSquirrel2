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

.include "snes.inc"
.include "global.inc"
.include "paletteenum.s"
.smart

.export OpenHubworld

.segment "C_HubWorld"

HUBWORLD_MAP_COLUMN_SIZE = 64*2
HUBWORLD_MAP_TOTAL_SIZE  = HUBWORLD_MAP_COLUMN_SIZE * 64

.a16
.i16
.proc OpenHubworld
  ; -----------------------------------
  ; Set up PPU registers
  seta8
  setxy16
  lda #1|BG3_PRIORITY
  sta BGMODE       ; mode 1

  stz BGCHRADDR+0  ; bg planes 0-1 CHR at $0000
  lda #$4>>1
  sta BGCHRADDR+1  ; bg plane 2 CHR at $4000

  lda #SpriteCHRBase >> 14
  sta OBSEL      ; sprite CHR at $c000, sprites are 8x8 and 16x16

  lda #1 | (ForegroundBG >> 9)
  sta NTADDR+0   ; plane 0 nametable at $b000, 2 screens wide
  lda #1 | (BackgroundBG >> 9)
  sta NTADDR+1   ; plane 1 nametable at $a000, 2 screens wide
  lda #0 | (ExtraBG >> 9)
  sta NTADDR+2   ; plane 2 nametable at $9800, 1 screen

  ; set up plane 0's scroll
;  stz BGSCROLLX+0
;  stz BGSCROLLX+0
;  stz BGSCROLLX+2
;  stz BGSCROLLX+2
;  lda #$FF
;  sta BGSCROLLY+0  ; The PPU displays lines 1-224, so set scroll to
;  sta BGSCROLLY+0  ; $FF so that the first displayed line is line 0
;  sta BGSCROLLY+2
;  sta BGSCROLLY+2

  stz PPURES
  lda #%00010011  ; enable sprites, plane 0 and 1
  sta BLENDMAIN
  stz BLENDSUB
  lda #VBLANK_NMI|AUTOREAD  ; but disable htime/vtime IRQ
  sta PPUNMI

  stz CGWSEL
  stz CGWSEL_Mirror
  stz CGADSUB
  stz CGADSUB_Mirror

  ; Clear game related variables
  lda #1
  sta PlayerOnGround
  stz PlayerJumping

  ; -----------------------------------
  ; Load in palettes and graphics
  lda #^HubWorldPalettes
  sta DMAADDRBANK

  stz CGADDR
  ldx #.loword(HubWorldPalettes)
  stx DMAADDR
  ldx #.loword(HubWorldPalettesEnd-HubWorldPalettes)
  stx DMALEN

  ldx #DMAMODE_CGDATA
  stx DMAMODE

  ; -----------------------------------
  lda #^HubWorldGraphics
  sta DMAADDRBANK+$10

  ldx #0
  stx PPUADDR
  ldx #.loword(HubWorldGraphics)
  stx DMAADDR+$10
  ldx #.loword(HubWorldGraphicsEnd-HubWorldGraphics)
  stx DMALEN+$10

  ldx #DMAMODE_PPUDATA
  stx DMAMODE+$10

  lda #%11
  sta COPYSTART

  seta16

  lda #Palette::FGCommon
  ldy #8
  jsl DoPaletteUpload
  lda #Palette::SPNova
  ldy #9
  jsl DoPaletteUpload

  lda #128*16
  sta PlayerPX
  sta PlayerPY

  jsr RenderHubworldScreens

  stz ColumnUpdateAddress
  stz ColumnUpdateAddress2
  stz RowUpdateAddress
  stz RowUpdateAddress2

.endproc
; Fall through
.proc HubworldLoop
  phk
  plb
  .a16
  inc framecount

  ; -----------------------------------------------------------------
  ; Handle controls

  lda keydown
  sta keylast
  lda JOY1CUR
  sta keydown
  lda keylast
  eor #$ffff
  and keydown
  sta keynew

  Speed = 2
  lda #$0020
  sta Speed

  lda keydown
  and #KEY_Y
  beq :+
    asl Speed
  :

  lda keydown
  and #KEY_LEFT
  beq :+
    lda PlayerPX
    sub Speed
    sta PlayerPX
    seta8
    lda #1
    sta PlayerDir
    seta16
    jsr HubworldSolidUnderPlayer
    beq :+
      lda PlayerPX
      add Speed
      and #$ff80
      add #3*8
      sta PlayerPX
  :
  lda keydown
  and #KEY_RIGHT
  beq :+
    lda PlayerPX
    add Speed
    sta PlayerPX
    seta8
    stz PlayerDir
    seta16
    jsr HubworldSolidUnderPlayer
    beq :+
      lda PlayerPX
      sub Speed
      and #$ff80
      add #12*8+12
      sta PlayerPX
  :
  lda keydown
  and #KEY_UP
  beq :+
    lda PlayerPY
    sub Speed
    sta PlayerPY
    jsr HubworldSolidUnderPlayer
    beq :+
      lda PlayerPY
      add Speed
      and #$ff80
      add #3*8
      sta PlayerPY
  :
  lda keydown
  and #KEY_DOWN
  beq :+
    lda PlayerPY
    add Speed
    sta PlayerPY
    jsr HubworldSolidUnderPlayer
    beq :+
      lda PlayerPY
      sub Speed
      and #$ff80
      add #12*8+12
      sta PlayerPY
  :
  ; Dim the screen as a test for detecting solidity
  lda PlayerPX
  ldx PlayerPY
  jsr HubworldLookupSolidMap
  beq :+
    seta8
    lda #$05
    sta PPUBRIGHT
    seta16
  :

  jsr HubworldAdjustCamera

  ; Draw the player!
  stz OamPtr
  stz PlayerOAMIndex
  lda keydown
  and #KEY_UP | KEY_DOWN
  beq :+
    lda #KEY_LEFT | KEY_RIGHT ; Animate walking even if you press up/down instead of left/right
    tsb keydown
  :
  jsl DrawPlayer
  lda #4*4
  sta OamPtr

  ; Get ready to OAM DMA
  ldx OamPtr
  jsl ppu_clear_oam
  jsl ppu_pack_oamhi

  jsl WaitVblank
  jsl ppu_copy_oam
  seta16

  ; Set up faster access to DMA registers
  lda #DMAMODE
  tcd
  lda #DMAMODE_PPUDATA
  sta <DMAMODE
  sta <DMAMODE+$10 ; For player, if needed

  ; -------------------------
  ; Player frame
  PlayerFrameUpload:
    lda a:PlayerFrame
    xba              ; *256
    asl              ; *512
    ;ora #$8000      <-- For LoROM
    sta <DMAADDR+$00
    ora #256
    sta <DMAADDR+$10

    lda #32*8 ; 8 tiles for each DMA
    sta <DMALEN+$00
    sta <DMALEN+$10

    lda #(SpriteCHRBase+$000)>>1
    sta PPUADDR
    seta8
    .import PlayerGraphics
    lda #^PlayerGraphics
    sta <DMAADDRBANK+$00
    sta <DMAADDRBANK+$10

    lda #%00000001
    sta COPYSTART

    ; Bottom row -------------------
    ldx #(SpriteCHRBase+$200)>>1
    stx PPUADDR
    lda #%00000010
    sta COPYSTART
    seta16

  ; Do row/column updates if required
  lda ColumnUpdateAddress
  beq :+
    stz ColumnUpdateAddress
    sta PPUADDR
    lda #.loword(ColumnUpdateBuffer)
    sta <DMAADDR
    lda #32*2
    sta <DMALEN
    seta8
    lda #^ColumnUpdateBuffer
    sta <DMAADDRBANK
    lda #INC_DATAHI|VRAM_DOWN
    sta PPUCTRL
    lda #%00000001
    sta COPYSTART
    lda #INC_DATAHI
    sta PPUCTRL
    seta16
  :

  ldx RowUpdateAddress
  beq :+
    stz RowUpdateAddress
    ; --- First screen
    ; Set DMA parameters  
    stx PPUADDR
    lda #.loword(RowUpdateBuffer)
    sta <DMAADDR
    ldy #32*2
    sty <DMALEN
    seta8
    lda #^RowUpdateBuffer
    sta <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16

    ; --- Second screen
    txa
    ora #2048>>1
    sta PPUADDR
    lda #.loword(RowUpdateBuffer+32*2)
    sta <DMAADDR
    sty <DMALEN

    seta8
    lda #%00000001
    sta COPYSTART
    seta16
  :

  ; Do row/column updates for second layer
  lda ColumnUpdateAddress2
  beq :+
    stz ColumnUpdateAddress2
    sta PPUADDR
    lda #.loword(ColumnUpdateBuffer2)
    sta <DMAADDR
    lda #32*2
    sta <DMALEN
    seta8
    lda #^ColumnUpdateBuffer2
    sta <DMAADDRBANK
    lda #INC_DATAHI|VRAM_DOWN
    sta PPUCTRL
    lda #%00000001
    sta COPYSTART
    lda #INC_DATAHI
    sta PPUCTRL
    seta16
  :

  lda RowUpdateAddress2
  beq :+
    stz RowUpdateAddress2
    ; --- First screen
    ; Set DMA parameters  
    tax
    sta PPUADDR
    lda #.loword(RowUpdateBuffer2)
    sta <DMAADDR
    ldy #32*2
    sty <DMALEN
    seta8
    lda #^RowUpdateBuffer2
    sta <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16

    ; --- Second screen
    txa
    ora #2048>>1
    sta PPUADDR
    lda #.loword(RowUpdateBuffer2+32*2)
    sta <DMAADDR
    sty <DMALEN

    seta8
    lda #%00000001
    sta COPYSTART
    seta16
  :

  ; Change direct page back to normal
  lda #0
  tcd
  seta8

  ; -----------------------------------

  lda #$0f
  sta PPUBRIGHT

  ; Wait for control reading to finish
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait

  seta16
  lda ScrollX
  lsr
  lsr
  lsr
  lsr
  sta FGScrollXPixels
  seta8
  sta BGSCROLLX
  xba
  sta BGSCROLLX
  xba
  sta BGSCROLLX+2
  xba
  sta BGSCROLLX+2
  seta16

  lda ScrollY
  lsr
  lsr
  lsr
  lsr
  sta FGScrollYPixels
  seta8
  sta BGSCROLLY
  xba
  sta BGSCROLLY
  xba
  sta BGSCROLLY+2
  xba
  sta BGSCROLLY+2
  seta16

  jmp HubworldLoop
.endproc

; -------------------------------------

.a16
.i16
.proc RenderHubworldScreens
BlockNum = 0
BlocksLeft = 2
Pointer = 4
  ; Start rendering
  lda ScrollX+1 ; Get the column number in blocks
  and #$ff
  sub #4   ; Render out past the left side a bit
  sta BlockNum

  jsr HubworldMapColumnPtr

  lda #26  ; Go 26 blocks forward
  sta BlocksLeft

  lda ScrollY
  xba
  and #HUBWORLD_MAP_COLUMN_SIZE-1
  asl
  ora LevelBlockPtr
  sta Pointer

Loop:
  ; Calculate the column address
  lda BlockNum
  and #15
  asl
  pha
  ora #ForegroundBG>>1
  sta ColumnUpdateAddress
  pla
  ora #BackgroundBG>>1
  sta ColumnUpdateAddress2

  ; Use the other nametable if necessary
  lda BlockNum
  and #16
  beq :+
    lda #2048>>1
    tsb ColumnUpdateAddress
    tsb ColumnUpdateAddress2
  :

  ; Upload two columns
  ldx Pointer
  jsr RenderHubworldColumnLeft
  jsl RenderLevelColumnUpload
  jsl RenderLevelColumnUpload2
  inc ColumnUpdateAddress
  inc ColumnUpdateAddress2
  ldx Pointer
  jsr RenderHubworldColumnRight
  jsl RenderLevelColumnUpload
  jsl RenderLevelColumnUpload2

  ; Move onto the next block
  lda Pointer
  add #HUBWORLD_MAP_COLUMN_SIZE
  and #HUBWORLD_MAP_TOTAL_SIZE-1
  sta Pointer
  inc BlockNum

  dec BlocksLeft
  bne Loop
  rts
.endproc

; Render the right tile of a column of blocks
; (starting from index X within the hubworld map)
; 16-bit accumulator and index
.a16
.i16
.proc RenderHubworldColumnLeft
  phb
  ph2banks ColumnUpdateBuffer, ColumnUpdateBuffer
  plb
  plb

  ; Calculate starting index for scrolling buffer
  txa
  asl
  and #(32*2)-1
  tay
  sty TempVal
  ; Loop
: phx
  phx
  lda f:HubWorldFG,x ; Get the next level tile
  tax
  ; Write the two tiles in
  lda f:HubWorldMetatileUL,x
  sta ColumnUpdateBuffer+0,y
  lda f:HubWorldMetatileLL,x
  sta ColumnUpdateBuffer+2,y
  plx
  lda f:HubWorldBG,x
  tax
  ; Write the two tiles into the other buffer
  lda f:HubWorldMetatileUL,x
  sta ColumnUpdateBuffer2+0,y
  lda f:HubWorldMetatileLL,x
  sta ColumnUpdateBuffer2+2,y
  plx
  inx
  inx

  ; Wrap around in the buffer
  iny
  iny
  iny
  iny
  tya
  and #(32*2)-1
  tay

  ; Stop after 32 tiles vertically
  cpy TempVal
  bne :-

  plb
  rts
.endproc

; Render the right tile of a column of blocks
; (starting from index X within the hubworld map)
; 16-bit accumulator and index
.a16
.i16
.proc RenderHubworldColumnRight
  phb
  ph2banks ColumnUpdateBuffer, ColumnUpdateBuffer
  plb
  plb

  ; Calculate starting index for scrolling buffer
  txa
  asl
  and #(32*2)-1
  tay
  sty TempVal
  ; Loop
: phx
  phx
  lda f:HubWorldFG,x ; Get the next level tile
  tax
  ; Write the two tiles in
  lda f:HubWorldMetatileUR,x
  sta ColumnUpdateBuffer+0,y
  lda f:HubWorldMetatileLR,x
  sta ColumnUpdateBuffer+2,y
  plx
  lda f:HubWorldBG,x
  tax
  ; Write the two tiles into the other buffer
  lda f:HubWorldMetatileUR,x
  sta ColumnUpdateBuffer2+0,y
  lda f:HubWorldMetatileLR,x
  sta ColumnUpdateBuffer2+2,y
  plx
  inx
  inx

  ; Wrap around in the buffer
  iny
  iny
  iny
  iny
  tya
  and #(32*2)-1
  tay

  ; Stop after 32 tiles vertically
  cpy TempVal
  bne :-

  plb
  rts
.endproc

; Render the left tile of a column of blocks
; (starting from index X within the hubworld map)
; Initialize Y with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderHubworldRowTop
  phb
  ph2banks RowUpdateBuffer, RowUpdateBuffer
  plb
  plb

  lda #20
  sta TempVal

: phx
  phx
  lda f:HubWorldFG,x ; Get the next map tile
  tax
  ; Write the two tiles in
  lda f:HubWorldMetatileUL,x
  sta RowUpdateBuffer+0,y
  lda f:HubWorldMetatileUR,x
  sta RowUpdateBuffer+2,y
  plx
  lda f:HubWorldBG,x
  tax
  ; Write the two tiles into the other buffer
  lda f:HubWorldMetatileUL,x
  sta RowUpdateBuffer2+0,y
  lda f:HubWorldMetatileUR,x
  sta RowUpdateBuffer2+2,y

  ; Next column
  pla
  add #HUBWORLD_MAP_COLUMN_SIZE
  and #HUBWORLD_MAP_TOTAL_SIZE-1
  tax

  ; Wrap around in the buffer
  iny
  iny
  iny
  iny
  tya
  and #(64*2)-1
  tay

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rts
.endproc

; Render the right tile of a column of blocks
; (starting from index X within the hubworld map)
; Initialize Y with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderHubworldRowBottom
  phb
  ph2banks RowUpdateBuffer, RowUpdateBuffer
  plb
  plb

  lda #20
  sta TempVal

: phx
  phx
  lda f:HubWorldFG,x ; Get the next map tile
  tax
  ; Write the two tiles in
  lda f:HubWorldMetatileLL,x
  sta RowUpdateBuffer+0,y
  lda f:HubWorldMetatileLR,x
  sta RowUpdateBuffer+2,y
  plx
  lda f:HubWorldBG,x
  tax
  ; Write the two tiles into the other buffer
  lda f:HubWorldMetatileLL,x
  sta RowUpdateBuffer2+0,y
  lda f:HubWorldMetatileLR,x
  sta RowUpdateBuffer2+2,y

  ; Next column
  pla
  add #HUBWORLD_MAP_COLUMN_SIZE
  and #HUBWORLD_MAP_TOTAL_SIZE-1
  tax

  ; Wrap around in the buffer
  iny
  iny
  iny
  iny
  tya
  and #(64*2)-1
  tay

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rts
.endproc

; Adjust the camera to target the player's new position
; and detect if any scrolling updates need to happen
.a16
.i16
.proc HubworldAdjustCamera
ScrollOldX = OldScrollX
ScrollOldY = OldScrollY
TargetX = 4
TargetY = 6
XLimitConstant = (3*16)*256
YLimitConstant = (3*16)*256 

 ; Save the old scroll positions
  lda ScrollX
  sta ScrollOldX
  lda ScrollY
  sta ScrollOldY

  ; Find the target scroll positions
  lda PlayerPX
  sub #8*256
  bcs :+
    lda #0
: cmp #XLimitConstant
  bcc :+
  lda #XLimitConstant
: sub ScrollX
  asr_n 3
  jsr SpeedLimit
  add ScrollX
  sta ScrollX

  lda PlayerPY
  sub #8*256
  bcs :+
    lda #0
: cmp #YLimitConstant
  bcc :+
  lda #YLimitConstant
: sub ScrollY
  asr_n 3
  jsr SpeedLimit
  add ScrollY
  sta ScrollY

  ; -----------------------------------

  ; Is a column update required?
  lda ScrollX
  eor ScrollOldX
  and #$80
  beq NoUpdateColumn
    lda ScrollX
    cmp ScrollOldX
    jsr ToTiles
    bcs UpdateRight
  UpdateLeft:
    sub #2             ; Two tiles to the left
    jsr HubworldUpdateColumn
    bra NoUpdateColumn
  UpdateRight:
    add #34            ; Two tiles past the end of the screen on the right
    jsr HubworldUpdateColumn
  NoUpdateColumn:

  ; Is a row update required?
  lda ScrollY
  eor ScrollOldY
  and #$80
  beq NoUpdateRow
    lda ScrollY
    cmp ScrollOldY
    jsr ToTiles
    bcs UpdateDown
  UpdateUp:
    jsr HubworldUpdateRow
    bra NoUpdateRow
  UpdateDown:
    add #29            ; Just past the screen height
    jsr HubworldUpdateRow
  NoUpdateRow:

  ; All done
  rts

; Convert a 12.4 scroll position to a number of tiles
ToTiles:
  php
  lsr ; \ shift out the subpixels
  lsr ;  \
  lsr ;  /
  lsr ; /

  lsr ; \
  lsr ;  | shift out 8 pixels
  lsr ; /
  plp
  rts

SpeedLimit:
  ; Take absolute value
  php
  bpl :+
    eor #$ffff
    inc a
  :
  ; Speed limit for being too small too! Helps avoid awkwardly moving a single pixel at the end
  cmp #$0003
  bcs :+
    lda #$0000
  :
  ; Cap it at 8 pixels
  cmp #$0080
  bcc :+
    lda #$0080
  :
  ; Undo absolute value
  plp
  bpl :+
    eor #$ffff
    inc a
  :
  rts
.endproc

.a16
.proc HubworldSolidUnderPlayer
  lda PlayerPX
  ldx PlayerPY
  ; Fall through
  ;jmp PlayerPos
.endproc

.a16
; Checks if a specific X and Y position are over a solid tile
; A = X position
; X = Y position
.proc HubworldLookupSolidMap
Index = 0
  ; Start with:
  ;   A = ..xxxxxx x.......
  ;   X = ..yyyyyy y.......
  ; Goal: 00000yyy yyyyxxxx

  asl ; .xxxxxxx ........
  xba ; ........ .xxxxxxx
  and           #%1111111
  pha
  lsr ; ........ ..xxxxxx
  lsr ; ........ ...xxxxx
  lsr ; ........ ....xxxx
  sta Index
  txa ; ..yyyyyy y.......
  lsr ; ...yyyyy yy......
  lsr ; ....yyyy yyy.....
  lsr ; .....yyy yyyy....
  and  #%0000011111110000
  tsb Index ; <-- 00000yyy yyyyxxxx
  pla
  ; The solidity map packs the solidity for eight tiles into a byte to save space.
  ; Use the bottom three bits to pick which bit to check instead of involving them in the index calculation.
  and #%111
  tax
  seta8
  lda Table,x
  ldx Index
  and f:HubWorldSolidMap,x
  seta16
  rts
Table:
  .byt 1, 2, 4, 8, 16, 32, 64, 128
.endproc

.a16
.proc HubworldMapColumnPtr
  and #255
  asl ; * 2
  asl ; * 4
  asl ; * 8
  asl ; * 16
  asl ; * 32
  asl ; * 64
  asl ; * 128
  sta LevelBlockPtr
  rts
.endproc

.a16
.proc HubworldUpdateRow
Temp = 4
YPos = 6
  sta Temp

  ; Calculate the address of the row
  ; (Always starts at the leftmost column
  ; and extends all the way to the right.)
  and #31
  asl ; Multiply by 32, the number of words per row in a screen
  asl
  asl
  asl
  asl
  pha
  ora #ForegroundBG>>1
  sta RowUpdateAddress
  pla
  ora #BackgroundBG>>1
  sta RowUpdateAddress2

  ; Get level pointer address
  ; (Always starts at the leftmost column of the screen)
  lda ScrollX
  xba
  dec a
  jsr HubworldMapColumnPtr

  ; Get index for the buffer
  lda ScrollX
  xba
  dec a
  asl
  asl
  and #(64*2)-1
  tay

  ; Calculate an index to read level data with
  lda Temp
  and #.loword(~1)
  ora LevelBlockPtr
  tax

  ; Generate the top or the bottom as needed
  lda Temp
  lsr
  bcs :+
    jmp RenderHubworldRowTop
  :
  jmp RenderHubworldRowBottom
.endproc

.a16
.proc HubworldUpdateColumn
Temp = 4
YPos = 6
  sta Temp

  ; Calculate address of the column
  and #31
  pha
  ora #ForegroundBG>>1
  sta ColumnUpdateAddress
  pla
  ora #BackgroundBG>>1
  sta ColumnUpdateAddress2

  ; Use the second screen if required
  lda Temp
  and #32
  beq :+
    lda #2048>>1
    tsb ColumnUpdateAddress
    tsb ColumnUpdateAddress2
  :

  ; Get level pointer address
  lda Temp ; Get metatile count
  lsr
  jsr HubworldMapColumnPtr

  ; Calculate an index to read level data with
  lda ScrollY
  xba
  asl
  and #HUBWORLD_MAP_COLUMN_SIZE-1
  ora LevelBlockPtr
  tax

  ; Generate the left or right as needed
  lda Temp
  lsr
  bcc :+
    jmp RenderHubworldColumnRight
  :
  jmp RenderHubworldColumnLeft
.endproc

; -------------------------------------

.segment "HubWorld_Graphics"
HubWorldGraphics:
  .incbin "../hubworld/hubworld.chrsfc"
HubWorldGraphicsEnd:

.segment "HubWorld_Maps"
HubWorldFG: .incbin "../hubworld/fg.bin"
HubWorldBG: .incbin "../hubworld/bg.bin"

.segment "HubWorld_Data"
HubWorldSolidMap:
  .incbin "../hubworld/solidmap.bin"

HubWorldPalettes:
  .incbin "../hubworld/palettes.bin"
HubWorldPalettesEnd:

HubWorldMetatiles:
  .incbin "../hubworld/metatiles.bin"
HubWorldMetatilesEnd:
MetatileCount = (HubWorldMetatilesEnd-HubWorldMetatiles)/8

HubWorldMetatileUL = HubWorldMetatiles + (MetatileCount*0)*2
HubWorldMetatileUR = HubWorldMetatiles + (MetatileCount*1)*2
HubWorldMetatileLL = HubWorldMetatiles + (MetatileCount*2)*2
HubWorldMetatileLR = HubWorldMetatiles + (MetatileCount*3)*2
