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
; Waits for the start of vertical blanking.
.proc ppu_vsync
  php
  seta8
loop1:
  bit VBLSTATUS  ; Wait for leaving previous vblank
  bmi loop1
loop2:
  bit VBLSTATUS  ; Wait for start of this vblank
  bpl loop2
  plp
  rtl
.endproc


;;
; Uploads a specific graphic asset to VRAM
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

  ; Upload to VRAM
  lda #DMAMODE_PPUDATA
  sta DMAMODE

  ; Now access the stuff from GraphicsDirectory:
  ; ppp dd ss - pointer, destination, size

  ; Source address
  lda f:GraphicsDirectory+0,x
  sta DMAADDR

  ; Destination address
  lda f:GraphicsDirectory+3,x
  add GraphicUploadOffset
  sta PPUADDR

  ; Size
  lda f:GraphicsDirectory+5,x
  sta DMALEN

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

WithOffset: ; Alternate entrance for using destination address offsets
  phx
  php
  setaxy16
  bra KeepOffset
.endproc
DoGraphicUploadWithOffset = DoGraphicUpload::WithOffset
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

; Upload level graphics and palettes,
; and also set PPU settings correctly for levels
.export UploadLevelGraphics
.proc UploadLevelGraphics
  seta8

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
  phy
  jsl DoPaletteUpload
  ply
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

  lda #GraphicsUpload::MapBGForest
  jsl DoGraphicUpload
  lda #GraphicsUpload::SPCommon
  jsl DoGraphicUpload

  ; Clear layer 3
  ldx #$e000 >> 1
  ldy #32*4
  jsl ppu_clear_nt
  ; Including the graphics?
  ldx #$e800 >> 1
  ldy #0
  jsl ppu_clear_nt

  ; .------------------------------------.
  ; | Set up PPU registers for level use |
  ; '------------------------------------'
  .a8 ; Side effect of ppu_clear_nt
  lda #1
  sta BGMODE       ; mode 1

  stz BGCHRADDR+0  ; bg planes 0-1 CHR at $0000
  lda #$e>>1
  sta BGCHRADDR+1  ; bg plane 2 CHR at $e000

  lda #$8000 >> 14
  sta OBSEL      ; sprite CHR at $8000, sprites are 8x8 and 16x16

  lda #1 | ($c000 >> 9)
  sta NTADDR+0   ; plane 0 nametable at $c000, 2 screens wide
  lda #2 | ($d000 >> 9)
  sta NTADDR+1   ; plane 1 nametable also at $d000, 2 screens tall
  lda #0 | ($e000 >> 9)
  sta NTADDR+2   ; plane 2 nametable at $e000, 1 screen

  stz PPURES
  lda #%00010011  ; enable sprites, plane 0 and 1
  sta BLENDMAIN
  lda #VBLANK_NMI|AUTOREAD  ; but disable htime/vtime IRQ
  sta PPUNMI

  seta16
  jml RenderLevelScreens
.endproc

.a16
.i16
; Uploads portrait A to address Y
.export DoPortraitUpload
.proc DoPortraitUpload
  pha
  php
  seta16

  and #255         ; Zero extend
  xba              ; *256
  asl              ; *512
  ora #$8000
  sta DMAADDR+$00
  ora #256
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
  .import PortraitData
  lda #^PortraitData
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
  pla
  rtl
.endproc
