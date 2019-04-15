.include "snes.inc"
.include "global.inc"
.smart

.segment "CODE5"
.proc load_bg_tiles
  phb  ; Save old program bank and push new bank
  phk
  plb

  ; Copy background palette to the S-PPU.
  ; We perform the copy using DMA (direct memory access), which has
  ; four steps:
  ; 1. Set the destination address in the desired area of memory,
  ;    be it CGRAM (palette), OAM (sprites), or VRAM (tile data and
  ;    background maps).
  ; 2. Tell the DMA controller which area of memory to copy to.
  ; 3. Tell the DMA controller the starting address to copy from.
  ; 4. Tell the DMA controller how big the data is in bytes.
  ; ppu_copy uses the current data bank as the source bank
  ; for the copy, so set the source bank.
  seta8
  stz CGADDR  ; Seek to the start of CGRAM
  setaxy16
  lda #DMAMODE_CGDATA
  ldx #palette & $FFFF
  ldy #palette_size
  jsl ppu_copy

  ; This demo uses background mode 0, in which each of four 2bpp
  ; layers gets its own palette, at word offsets $00-$1F, $20-$3F,
  ; $40-$5F, and $60-$7F in CGRAM.  (The other modes with 2bpp
  ; backgrounds use only $00-$1F.)  We just finished copying the
  ; main palette to $00; also copy it to $20 for the second layer
  ; in demo modes that use it.  The palettes could be different,
  ; but in this demo they're the same.
  seta8
  lda #$20
  sta CGADDR
  setaxy16
  lda #DMAMODE_CGDATA
  ldx #layer1_palette & $FFFF
  ldy #layer1_palette_size
  jsl ppu_copy

  ; Copy background tiles to PPU.
  ; PPU memory is also word addressed because the low and high bytes
  ; are actually on separate SRAM chips.
  ; In background mode 0, all background tiles are 2 bits per pixel,
  ; which take 16 bytes or 8 words per tile.
  setaxy16
  stz PPUADDR  ; we will start video memory at $0000
  lda #DMAMODE_PPUDATA
  ldy #chr_bin_size
  ldx #chr_bin & $FFFF
  jsl ppu_copy

  plb
  rtl
.endproc

.proc draw_bg
  ; This demo's background tile set includes glyphs at ASCII code
  ; points $20 (space) through $5F (underscore).  Clear the map
  ; to all spaces.
  setaxy16
  ldx #$6000
  ldy #' ' | (1 << 10)
  jsl ppu_clear_nt

  ; The screen spans rows 0-27, of which rows 23-27 are the ground.
  ; Draw the top of the ground using a grass tile
  setaxy16
  lda #$6000|NTXY(0, 23)
  sta PPUADDR
  lda #$000B
  ldx #32
floorloop1:
  sta PPUDATA
  dex
  bne floorloop1
  
  ; Draw areas buried under the floor as solid color
  lda #$0001
  ldx #4*32
floorloop2:
  sta PPUDATA
  dex
  bne floorloop2

  ; Draw blocks on the sides, in vertical columns
  seta8
  lda #VRAM_DOWN|INC_DATAHI
  sta PPUCTRL
  setaxy16
  
  ; At position (2, 19) (VRAM $6262) and (28, 19) (VRAM $627C),
  ; draw two columns of two blocks each, each block being 4 tiles:
  ; 0C 0D
  ; 0E 0F
  ldx #2

colloop:
  txa
  ora #$6000 | NTXY(0, 19)
  sta PPUADDR

  ; Draw $0C $0E $0C $0E or $0D $0F $0D $0F depending on column
  and #$0001
  ora #$040C  ; palette 1
  ldy #4
tileloop:
  sta PPUDATA
  eor #$02
  dey
  bne tileloop

  ; Columns 2, 3, 28, and 29 only  
  inx
  cpx #4  ; Skip columns 4 through 27
  bne not4
  ldx #28
not4:
  cpx #30
  bcc colloop

  ; The Super NES has no attribute table. Yay.

  seta8
  lda #INC_DATAHI  ; Set the data direction back to how
  sta PPUCTRL      ; the rest of the program expects it
  rtl
.endproc

.segment "RODATA5"
chr_bin:
  .incbin "obj/snes/bggfx.chrgb"
chr_bin_size = * - chr_bin

; The background palette
palette:
  .word RGB(15,23,31),RGB(12,12, 0),RGB(14,23, 0),RGB(16,31, 0)
  .word RGB( 0, 0,15),RGB(15,15, 0),RGB(23,23, 8),RGB(31,31,16)
palette_size = * - palette

layer1_palette = palette
layer1_palette_size = palette_size
