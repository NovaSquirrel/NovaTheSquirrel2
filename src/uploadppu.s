; Super Princess Engine
; Copyright (C) 2019-2020 NovaSquirrel
; Parts of this file based on lorom-template
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
.i16

.segment "CODE"
;;
; Clears 2048 bytes ($1000 words) of video memory to a constant
; value.  This can be one nametable, 128 2bpp tiles, 64 4bpp tiles,
; or 32 8bpp tiles.  Must be called during vertical or forced blank.
; @param X starting address of nametable in VRAM (16-bit)
; @param Y value to write (16-bit)
.proc ppu_clear_nt
  seta16
  sty $0000
  ldy #1024        ; number of bytes to clear
  
  ; Clear low bytes
  seta8
  stz PPUCTRL      ; +1 on PPUDATA low byte write
  lda #$00         ; point at low byte of Y
  jsl doonedma
  
  lda #INC_DATAHI  ; +1 on PPUDATA high byte write
  sta PPUCTRL
  lda #$01         ; point at high byte of Y
doonedma:
  stx PPUADDR
  sta DMAADDR
  ora #<PPUDATA
  sta DMAPPUREG
  lda #DMA_CONST|DMA_LINEAR
  sta DMAMODE
  sty DMALEN
  stz DMAADDRHI
  stz DMAADDRBANK
  lda #$01
  sta COPYSTART
  rtl
.endproc

;;
; Moves remaining entries in the CPU's local copy of OAM to
; (-128, 225) to get them offscreen.
; @param X index of first sprite in OAM (0-508)
.proc ppu_clear_oam
  setaxy16
lowoamloop:
  lda #(225 << 8) | <-128
  sta OAM,x
  lda #$0100  ; bit 8: offscreen
  sta OAMHI,x
  inx
  inx
  inx
  inx
  cpx #512  ; 128 sprites times 4 bytes per sprite
  bcc lowoamloop
  rtl
.endproc

;;
; Converts high OAM (sizes and X sign bits) to the packed format
; expected by the S-PPU, and clears the next 3 sprites' high OAM
; bits for use with ppu_copy_oam_partial. Skips unused sprites.
.proc ppu_pack_oamhi_partial
  ldx OamPtr
  ldy #3
  seta8
  stz 1 ; Because of the 16-bit "dec 0" later

: cpx #512 ; Don't go past the end of OAM
  bcs Exit
  lda #1   ; High X bit set
  sta OAMHI+1,x
  lda #$f0 ; Y position if offscreen
  sta OAM+1,x
  inx
  inx
  inx
  inx
  dey
  bne :-
Exit:
  stx OamPtr

  ; -----------------------------------
  ; Counter for how many times to do this
  seta16
  txa
  lsr
  lsr
  lsr
  lsr
  sta 0

  setxy16
  ldx #0
  txy
packloop:
  ; Pack four sprites' size+xhi bits from OAMHI
  sep #$20
  lda OAMHI+13,y
  asl a
  asl a
  ora OAMHI+9,y
  asl a
  asl a
  ora OAMHI+5,y
  asl a
  asl a
  ora OAMHI+1,y
  sta OAMHI,x
  rep #$21  ; seta16 + clc for following addition

  ; Move to the next set of 4 OAM entries
  inx
  tya
  adc #16
  tay

  ; Done yet?
  dec 0
  bne packloop

  ; -----------------------------------
  ; Skip over the unused sprites and just
  ; put in high X bits set to 1 instead of
  ; trying to pack them
  seta8
  lda #%01010101
: cpx #32
  beq done
  sta OAMHI,x
  inx
  bra :-
done:
  rtl
.endproc

;;
; Converts high OAM (sizes and X sign bits) to the packed format
; expected by the S-PPU.
.proc ppu_pack_oamhi
  setxy16
  ldx #0
  txy
packloop:
  ; pack four sprites' size+xhi bits from OAMHI
  sep #$20
  lda OAMHI+13,y
  asl a
  asl a
  ora OAMHI+9,y
  asl a
  asl a
  ora OAMHI+5,y
  asl a
  asl a
  ora OAMHI+1,y
  sta OAMHI,x
  rep #$21  ; seta16 + clc for following addition

  ; move to the next set of 4 OAM entries
  inx
  tya
  adc #16
  tay
  
  ; done yet?
  cpx #32  ; 128 sprites divided by 4 sprites per byte
  bcc packloop
  rtl
.endproc

; Calculates some of the math ahead of time to use in ppu_copy_oam_partial
.proc prepare_ppu_copy_oam_partial
OamPartialCopy512Sub        = DecodePointer ; has 3 bytes and then 3 bytes for ScriptPointer
OamPartialCopyDivide16      = DecodePointer + 2
OamPartialCopyDivide16Rsb32 = DecodePointer + 4
  seta16
  lda #512
  sub OamPtr
  sta OamPartialCopy512Sub
  lda OamPtr
  lsr
  lsr
  lsr
  lsr
  sta OamPartialCopyDivide16
  rsb #32
  sta OamPartialCopyDivide16Rsb32
  rtl
.endproc

;;
; Copies packed OAM data to the S-PPU using DMA channel 0
; and hides unused sprites using DMA channel 1
.proc ppu_copy_oam_partial
OamPartialCopy512Sub        = DecodePointer ; has 3 bytes and then 3 bytes for ScriptPointer
OamPartialCopyDivide16      = DecodePointer + 2
OamPartialCopyDivide16Rsb32 = DecodePointer + 4
  .a8
  .i16
  ldx OamPtr                     ; If OAM is actually completely full (somehow),
  cpx #512                       ; then don't use this routine because it'll break
  bcs ppu_copy_oam               ; (because a DMA length of "zero" is actually 64KB)

  ldx #DMAMODE_OAMDATA           ; Actually copy in OAM
  stx DMAMODE+$00
  ldx #DMAMODE_OAMDATA|DMA_CONST ; Copy in a fixed source byte
  stx DMAMODE+$10

  ldx OamPtr                     ; Copy in the used part of the OAM buffer
  stx DMALEN+$00
  ldx OamPartialCopy512Sub
  stx DMALEN+$10

  ldx #OAM
  stx DMAADDR+$00
  ldx #.loword(oam_source)
  stx DMAADDR+$10

  lda #^oam_source
  sta DMAADDRBANK+$00
  sta DMAADDRBANK+$10

  lda #3
  sta COPYSTART
  ; ---------------------------

  ldx OamPartialCopyDivide16
  stx DMALEN+$00
  ldx OamPartialCopyDivide16Rsb32
  stx DMALEN+$10
  ldx #OAMHI
  stx DMAADDR+$00
  ldx #.loword(hi_source)
  stx DMAADDR+$10
  lda #3
  sta COPYSTART
  rtl
oam_source:
  .byt $f0
hi_source:
  .byt %01010101 ; upper bit on all X positions set
.endproc

;;
; Copies packed OAM data to the S-PPU using DMA channel 0.
.proc ppu_copy_oam
  setaxy16
  lda #DMAMODE_OAMDATA
  ldx #OAM
  ldy #544
  ; falls through to ppu_copy
.endproc

;;
; Copies data to the S-PPU using DMA channel 0.
; @param X source address
; @param DBR source bank
; @param Y number of bytes to copy
; @param A 15-8: destination PPU register; 7-0: DMA mode
;        useful constants:
; DMAMODE_PPUDATA, DMAMODE_CGDATA, DMAMODE_OAMDATA
.proc ppu_copy
  php
  setaxy16
  sta DMAMODE
  stx DMAADDR
  sty DMALEN
  seta8
  phb
  pla
  sta DMAADDRBANK
  lda #%00000001
  sta COPYSTART
  plp
  rtl
.endproc

;;
; Uploads a specific graphic asset to VRAM
; Preserves X and Y
; @param A graphic number (0-255)
.import GraphicsDirectory
.proc DoGraphicUpload
  phx
  php
  setaxy16
  stz GraphicUploadOffset

KeepOffset:
  ; Calculate the address
  and #255
  ; Multiply by 7 by subtracting the original value from value*8
  sta 0
  asl
  asl
  asl
  sub 0
  tax

  ; Now access the stuff from GraphicsDirectory:
  ; ppp dd ss - pointer, destination, size

  ; Destination address
  lda f:GraphicsDirectory+3,x
  add GraphicUploadOffset
  sta PPUADDR

  ; Size can indicate that it's compressed
  lda f:GraphicsDirectory+5,x
  bmi Compressed
  sta DMALEN

  ; Upload to VRAM
  lda #DMAMODE_PPUDATA
  sta DMAMODE

  ; Source address
  lda f:GraphicsDirectory+0,x
  sta DMAADDR

  ; Source bank
  seta8
  lda f:GraphicsDirectory+2,x
  sta DMAADDRBANK

  ; Initiate the transfer
  lda #%00000001
  sta COPYSTART

  plp
  plx
  rtl

::DoGraphicUploadWithOffset: ; Alternate entrance for using destination address offsets
  phx
  php
  setaxy16
  bra KeepOffset

.a16
.i16
Compressed:
  phy ; This is trashed by the decompress routine

  lda f:GraphicsDirectory+0,x ; Source address
  pha
  lda f:GraphicsDirectory+2,x ; Source bank, don't care about high byte
  plx
  .import LZ4_DecompressToVRAM
  jsl LZ4_DecompressToVRAM

  ply
  plp
  plx
  rtl
.endproc

;;
; Uploads a specific palette asset to CGRAM
; locals: 0, 1
; @param A palette number (0-255)
; @param Y palette to upload to (0-15)
.import PaletteList
.proc DoPaletteUpload
  php
  setaxy16

  ; Calculate the address of the palette data
  and #255
  ; Multiply by 30
  sta 0
  asl
  asl
  asl
  asl
  sub 0
  asl
  add #PaletteList & $ffff
  ; Source address
  sta DMAADDR

  ; Upload to CGRAM
  lda #DMAMODE_CGDATA
  sta DMAMODE

  ; Size
  lda #15*2
  sta DMALEN

  ; Source bank
  seta8
  lda #^PaletteList
  sta DMAADDRBANK

  ; Destination address
  tya
  ; Multiply by 16 and add 1
  asl
  asl
  asl
  sec
  rol
  sta CGADDR

  ; Initiate the transfer
  lda #%00000001
  sta COPYSTART

  plp
  rtl
.endproc

; Uploads sprite palettes after they've been overwritten
; by something like the dialog screen
.export ReuploadSpritePalettes
.proc ReuploadSpritePalettes
  seta8
  ; 24 bytes? a bit better than an unrolled loop
  ldy #12
  ldx #0
: lda SpritePaletteSlots,x
  jsl DoPaletteUpload
  inx
  inx
  iny
  cpy #16
  bne :-
.endproc
; Falls through into UploadLevelGraphics

; Upload level graphics and palettes,
; and also set PPU settings correctly for levels
.export UploadLevelGraphics
.proc UploadLevelGraphics
  seta8
  stz HDMASTART_Mirror
  stz HDMASTART

  ; Fix the background color
  stz CGADDR
  lda LevelBackgroundColor+0
  sta CGDATA
  lda LevelBackgroundColor+1
  sta CGDATA

  ; Upload level sprite graphics
  ldx #0
SpriteLoop:
  lda SpriteTileSlots,x
  cmp #255
  beq :+
    pha
    ; Sprite graphic slots are 1KB, and X is already
    ; the slot number multiplied by 2. So we need to
    ; multiply by 256 to find the word offset, which
    ; requires no shifting.
    txa
    sta GraphicUploadOffset+1
    stz GraphicUploadOffset+0
    pla
    jsl DoGraphicUploadWithOffset
  :
  inx
  inx
  cpx #8*2
  bne SpriteLoop

  ; Upload background palettes
  ldy #0
: lda BackgroundPaletteSlots,y
  jsl DoPaletteUpload
  iny
  cpy #8
  bne :-

  ; Upload graphical assets
  ldx #0
: lda GraphicalAssets,x
  inx
  cmp #255
  beq :+
  jsl DoGraphicUpload
  bra :-
:

  lda #1
  sta NeedAbilityChange
  sta NeedAbilityChangeSilent

  setaxy16
  lda #Palette::FGCommon
  ldy #8
  jsl DoPaletteUpload
  lda #Palette::SPNova
  ldy #9
  jsl DoPaletteUpload
  lda #GraphicsUpload::SPCommon
  jsl DoGraphicUpload

  seta8

  ; .------------------------------------.
  ; | Set up PPU registers for level use |
  ; '------------------------------------'
  lda LevelBGMode
  sta BGMODE
  lda #VBLANK_NMI|AUTOREAD  ; Disable htime/vtime IRQ
  sta PPUNMI

  lda #(BG1CHRBase>>12)|((BG2CHRBase>>12)<<4)
  sta BGCHRADDR+0  ; bg plane 0 CHR at $0000, plane 1 CHR at $2000
  lda #(BG3CHRBase>>12)|((BG3CHRBase>>12)<<4)
  sta BGCHRADDR+1  ; bg plane 2 CHR at $3000, plane 3 CHR at same

  lda #SpriteCHRBase >> 13
  sta OBSEL      ; sprite CHR at $6000, sprites are 8x8 and 16x16

  ; First layer always goes at $5800 and is two screens wide
  lda #1 | ((ForegroundBG >> 10)<<2)
  sta NTADDR+0   ; plane 0 nametable at $5800, 2 screens wide

  ; Third layer nametable defaults to $4c00 (1 screen), but if there's a foreground on it then it's $4800, 2 screens wide
  lda #0 | ((ExtraBG >> 10)<<2)
  sta NTADDR+2
  lda ForegroundLayerThree
  beq :+
    lda #1 | ((ExtraBGWide >> 10)<<2)
    sta NTADDR+2
    bra :++ ; This also means the second foreground layer is *not* on the second background layer
  :
  ; Force two screens wide on two-layer levels
  lda TwoLayerLevel
  beq :+
    lda #1 | ((BackgroundBG >> 10)<<2)
    sta NTADDR+1   ; plane 0 nametable at $5000, 2 screens wide
    stz BGCHRADDR ; First two planes both at $0000
  :

  ; Load in the background map and tiles
  .import BackgroundFlags, BackgroundMap2, BackgroundTiles2, BackgroundMap3, BackgroundTiles3
  lda LevelBackgroundId
  seta16
  and #255
  cmp #255
  beq NoBackground
    asl
    tax

    lda f:BackgroundMap2,x
    bmi @NoBG2
      jsl DoGraphicUpload
      lda f:BackgroundTiles2,x
      jsl DoGraphicUpload
      lda f:BackgroundFlags,x
      seta8
      and #3
      ora #(BackgroundBG >> 10)<<2
      sta NTADDR+1
      seta16
    @NoBG2:

    lda f:BackgroundMap3,x
    bmi @NoBG3
      jsl DoGraphicUpload
      lda f:BackgroundTiles3,x
      jsl DoGraphicUpload
      lda f:BackgroundFlags,x
      lsr
      lsr
      seta8
      and #3
      beq :+ ; Change the amount of space reserved based on the map size
        ora #(ExtraBGWide >> 10)<<2
        bra :++
      :
        ora #(ExtraBG >> 10)<<2
      :
      sta NTADDR+2
      seta16
    @NoBG3:
  NoBackground:
  seta8

  ; Copy over the level's chosen color math settings
  .import ColorMathTableBLENDMAIN, ColorMathTableBLENDSUB, ColorMathTableCGADSUB, ColorMathTableOptions
  tdc ; A = zero
  lda LevelColorMathId
  tax
  lda f:ColorMathTableBLENDMAIN,x
  sta BLENDMAIN
  lda f:ColorMathTableBLENDSUB,x
  sta BLENDSUB
  lda f:ColorMathTableCGADSUB,x
  sta CGADSUB_Mirror

  ; Color math options byte:
  ; ....H.SC
  ;     | |+- Black BG color, set COLDATA to background color
  ;     | +-- Add sub screen
  ;     +---- Pseudo hi-res
  lda f:ColorMathTableOptions,x
  tay
  and #SUB_HIRES
  sta PPURES
  tya
  and #ADD_SUB_SCREEN
  sta CGWSEL_Mirror
  tya
  lsr
  bcc :+
    jsr LevelBGColorToCOLDATA
  :

  ; ---------------------------------------------------------------------------
  ; Make sure to synchronize these with wherever the toggle blocks are located!
  lda ToggleSwitch1
  beq :+
    ldx #$2c00
    ldy #.loword(File_FGToggleBlocksSwapped+256*0)
    jsr ToggleSwitchDMA
  :
  lda ToggleSwitch2
  beq :+
    ldx #$2c80
    ldy #.loword(File_FGToggleBlocksSwapped+256*1)
    jsr ToggleSwitchDMA
  :
  lda ToggleSwitch3
  beq :+
    ldx #$2d00
    ldy #.loword(File_FGToggleBlocksSwapped+256*2)
    jsr ToggleSwitchDMA
  :

  lda CGADSUB_Mirror
  sta CGADSUB
  lda CGWSEL_Mirror
  sta CGWSEL

  setaxy16
  .import BGEffectInit
  jsl BGEffectInit
  setaxy16
  jsl RenderLevelScreens

  ; Finish up with the hook, if present
  lda UploadLevelGraphicsHook
  beq :+
    jml [UploadLevelGraphicsHook]
  :
  rtl

.a8
ToggleSwitchDMA:
  .import File_FGToggleBlocksSwapped
  lda #^File_FGToggleBlocksSwapped
  sta DMAADDRBANK

  stx PPUADDR
  sty DMAADDR

  ldx #256
  stx DMALEN
  ldx #DMAMODE_PPUDATA
  stx DMAMODE

  lda #1
  sta COPYSTART
  rts
.endproc

.a8
.proc LevelBGColorToCOLDATA
  ; Set the actual background to black
  stz CGADDR
  stz CGDATA
  stz CGDATA

  ; Red
  lda LevelBackgroundColor
  and #31
  ora #FIXED_COLOR_RED
  sta COLDATA

  ; Green
  seta16
  lda LevelBackgroundColor
  asl
  asl
  asl
  xba
  seta8
  and #31
  ora #FIXED_COLOR_GREEN
  sta COLDATA

  ; Blue
  lda LevelBackgroundColor+1
  lsr
  lsr
  ora #FIXED_COLOR_BLUE
  sta COLDATA
  rts
.endproc

.a16
.i16
.export DoPortraitUpload
.proc DoPortraitUpload
  pha
  phy
  jsl DecompressPortrait
  ply
  jsl DecompressedPortraitUpload
  pla
  rtl
.endproc

.a16
.i16
.export DecompressPortrait
.proc DecompressPortrait
Pointer     = 0
PortraitNum = 6
TileBase    = 7
SixteenTilesCounter = 9
MvnBuffer = 12
  .import InfoForPortrait
  php
  phb
  seta16
  and #255
  sta PortraitNum
  asl
  tax ; X = portrait 
  lda f:InfoForPortrait,x
  add #3 ; Skip to tile stuff
  sta Pointer
  seta8
  lda #^InfoForPortrait
  sta Pointer+2
  sta MvnBuffer+2 ; MVN source

  lda #$54 ; MVN
  sta MvnBuffer+0
  lda #^DecompressBuffer
  sta MvnBuffer+1 ; MVN destination
  lda #$60 ; RTS
  sta MvnBuffer+3

  tdc
  lda PortraitNum
  sub [Pointer] ; First portrait number for character
  inc Pointer
  seta16
  asl
  asl
  asl
  asl
  pha

  lda [Pointer]
  sta TileBase
  pla
  add Pointer
  ina ; Skip the tile base (16-bit value)
  ina
  sta Pointer

  lda #16
  sta SixteenTilesCounter
  ldy #.loword(DecompressBuffer) ; Destination is in Y
SixteenTileLoop:
  lda [Pointer] ; Get one of the sixteen tile numbers that make up the portrait
  inc Pointer
  and #255
  asl
  asl
  asl
  asl
  asl
  add TileBase
  tax ; Source is in X

  lda #32-1
  jsr MvnBuffer

  dec SixteenTilesCounter
  bne SixteenTileLoop

  plb
  plp
  rtl
.endproc

.a16
.i16
; Uploads portrait to address Y
.export DecompressedPortraitUpload
.proc DecompressedPortraitUpload
  php
  seta16
  lda #.loword(DecompressBuffer)
  sta DMAADDR+$00
  lda #.loword(DecompressBuffer)+256
  sta DMAADDR+$10

  ; Set DMA parameters  
  lda #DMAMODE_PPUDATA
  sta DMAMODE+$00
  sta DMAMODE+$10

  lda #32*8 ; 8 tiles for each DMA
  sta DMALEN+$00
  sta DMALEN+$10

  sty PPUADDR
  seta8
  lda #^DecompressBuffer
  sta DMAADDRBANK+$00
  sta DMAADDRBANK+$10

  lda #%00000001
  sta COPYSTART

  ; Bottom row -------------------
  seta16
  tya
  add #$200 >> 1
  sta PPUADDR
  seta8
  lda #%00000010
  sta COPYSTART

  plp
  rtl
.endproc

; Write increasing values to VRAM
.export WritePPUIncreasing
.proc WritePPUIncreasing
: sta PPUDATA
  ina
  dex
  bne :-
  rtl
.endproc

; Write the same value to VRAM repeatedly
.export WritePPURepeated
.proc WritePPURepeated
: sta PPUDATA
  dex
  bne :-
  rtl
.endproc

; Skip forward some amount of VRAM words
.export SkipPPUWords
.proc SkipPPUWords
: bit PPUDATARD
  dex
  bne :-
  rtl
.endproc

.if 0
.a16
.i16
.export WriteScriptedImage
.proc WriteScriptedImage
  lda [DecodePointer]
  rtl
.endproc
.endif

.a16
.i16
; Queues a DMA to happen during the next vblank
; A = Source address (CPU)
; 0 = Source bank
; 1 = Flags
;   Most significant bit means do a second DMA, using the same length but using GenericUpdateSource2 and GenericUpdateDestination2 
;   (You have to write these yourself - use carry to check if this routine succeeded first)
; X = Destination address (PPU)
;   Most significant bit set means it's a palette update
; Y = Number of bytes to copy
; Returns success in carry
.proc QueueGenericUpdate
BankAndFlags = 0
Source = 2
Destination = 4
Length = 6
  sta Source
  stx Destination
  sty Length
Already:
  ; Keep track of how many bytes have been queued up so far
  lda GenericUpdateByteTotal
  add Length
  bit BankAndFlags
  bpl :+
    adc Length ; Just assume carry is clear
  :
  sta GenericUpdateByteTotal
  cmp #3000
  bcc :+
    ; This probably shouldn't happen - assert(0) 
    clc
    rtl
  :

  ; Otherwise, go find a free slot
  ldx #(GENERIC_UPDATE_COUNT-1)*2
FindFree:
  lda GenericUpdateLength,x
  beq Found
  dex
  dex
  bpl FindFree
Fail:
  clc
  rtl

Found:
  lda BankAndFlags
  sta GenericUpdateFlags,x
  lda Source
  sta GenericUpdateSource,x
  lda Destination
  sta GenericUpdateDestination,x
  lda Length
  sta GenericUpdateLength,x
  sec
  rtl
.endproc

.if 0
.a16
.i16
; Queues a DMA to happen during the next vblank
; A = Source address (CPU)
; DBR = Source bank
; X = Destination address (PPU)
; Y = Number of bytes to copy
; Returns success in carry
.export QueueGenericUpdateSameBank
.proc QueueGenericUpdateSameBank
  sta 2
  stx 4
  sty 6
  seta8 ; Get the current bank
  phb
  pla
  sta 0
  stz 1
  seta16
  bra QueueGenericUpdateWithBank::Already
.endproc
.endif

; Returns A = sprite slot, if found
; Returns success in carry
.export AllocateDynamicSpriteSlot
.proc AllocateDynamicSpriteSlot
  phx
  seta8
  ldx #DYNAMIC_SPRITE_SLOTS-1
: lda DynamicSpriteSlotUsed,x
  beq Found
  dex
  bpl :-

NotFound:
  seta16
  plx
  clc ; Failure
  rtl

Found:
  inc DynamicSpriteSlotUsed,x ; Mark it as used
  seta16
  txa
  asl ; Store it as slot*2
  plx
  sec ; Success
  rtl
.endproc

; A = sprite slot
.export FreeDynamicSpriteSlot
.proc FreeDynamicSpriteSlot
  phx
  lsr ; It's stored as slot*2, so fix that
  tax
  seta8
  stz DynamicSpriteSlotUsed,x
  seta16
  plx
  rtl
.endproc

; A = tile number to use, for a specific dynamic sprite index
.export GetDynamicSpriteTileNumber
.proc GetDynamicSpriteTileNumber
  phx
  tax
  lda f:TileNumbers,x
  plx
  rtl
TileNumbers:
  .word 128+(32*0)
  .word 128+(32*0)+8
  .word 128+(32*1)
  .word 128+(32*1)+8
  .word 128+(32*2)
  .word 128+(32*2)+8
  .word 128+(32*3)
  .word 128+(32*3)+8
.endproc

.export GetDynamicSpriteVRAMAddress
.proc GetDynamicSpriteVRAMAddress
; Actual code not used yet, because QueueDynamicSpriteUpdate can do it instead
;  phx
;  tax
;  lda f:Addresses,x
;  plx
;  rtl
Addresses:
  .word SpriteCHRBase+($1000>>1)
  .word SpriteCHRBase+($1100>>1)
  .word SpriteCHRBase+($1400>>1)
  .word SpriteCHRBase+($1500>>1)
  .word SpriteCHRBase+($1800>>1)
  .word SpriteCHRBase+($1900>>1)
  .word SpriteCHRBase+($1C00>>1)
  .word SpriteCHRBase+($1D00>>1)
.endproc

; Queues a DMA to happen during the next vblank
; A = Source address (CPU)
; 0 = Source bank
; 1 = Flags - should have the most significant bit set to signal doing two DMAs
; X = Dynamic sprite number
; Y = Number of bytes to copy
; Returns success in carry
.a16
.export QueueDynamicSpriteUpdate
.proc QueueDynamicSpriteUpdate
BankAndFlags = QueueGenericUpdate::BankAndFlags
Source = QueueGenericUpdate::Source
Slot = 8
  pha
  ; Is this frame already uploaded?
  cmp DynamicSpriteAddress,x
  bne :+
    lda 0
    cmp DynamicSpriteBank,x
    beq AlreadyPresent
  :
  stx Slot

  lda f:GetDynamicSpriteVRAMAddress::Addresses,x
  tax
  pla
  jsl QueueGenericUpdate ; A=source, 0=source bank, X=destination, Y=bytes
  bcc Fail
  ; X = the generic update slot, still
  ; Y is preserved, so it's still the length
  tya
  add QueueGenericUpdate::Source
  sta GenericUpdateSource2,x
  lda QueueGenericUpdate::Destination
  ora #$0200 >> 1
  sta GenericUpdateDestination2,x

  ldx Slot
  lda BankAndFlags
  sta DynamicSpriteBank,x
  lda Source
  sta DynamicSpriteAddress,x

  sec
Fail:
  rtl

AlreadyPresent:
  pla ; Clean up
  sec ; Say it's already loaded
  rtl
.endproc
