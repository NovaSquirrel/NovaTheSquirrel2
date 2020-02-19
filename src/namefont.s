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
MenuBGScroll = SpriteTileBase
.include "vwf.inc"
.smart

.segment "Dialog"

FontDrawX        = TouchTemp ; 8-bit
PrintedCharacter = TouchTemp + 1

.a16
.i16
.export RenderNameFont
.proc RenderNameFont
  phb

  ; Clear out the name font first
  ldx #.loword(NameFontRenderTop)
  ldy #768
  jsl MemClear

  seta8
  stz FontDrawX

  lda #<TestText
  sta DecodePointer+0
  lda #>TestText
  sta DecodePointer+1
  lda #^TestText
  sta DecodePointer+2

  ; -----------------------------------
CharacterLoop:
  ; .----------------------------------
  ; | Get a character
  ; '----------------------------------
  seta8
  lda [DecodePointer]
  jeq EndOfString
  cmp #1
  bne :+
    ; 1 = Space
    lda FontDrawX
    adc #4-1 ; Carry always set
    sta FontDrawX
    jmp NextCharacter
  :
  sub #2
HaveCharacterAlready:
  sta PrintedCharacter

  ; .----------------------------------
  ; | Shift the glyph
  ; '----------------------------------
  phk
  plb
  setaxy16
  ; Calculate the start of the glyph's data
  and #255
  asl
  asl
  asl
  asl
  asl
  adc #.loword(DialogNameFont)
  tay
  seta8
  tdc          ; Clear high byte for the TAX
  lda FontDrawX
  and #7
  tax          ; High byte (zero) is transferred too
  lda ShiftTable,x
  sta CPUMCAND ; Keep this constant for the whole glyph

  ; Start shifting!
  lda 0,y
  .repeat 24, I
    sta CPUMUL                ; Kick off the multiplier
    lda I+1,y                 ; 5 cycles
    ldx CPUPROD               ; 3 cycles before the read
    stx SmallRenderBuffer+I*2 ; =8 cycles waiting
  .endrep

  ; .----------------------------------
  ; | OR the shifted glyph in
  ; '----------------------------------
  seta16
  lda FontDrawX
  and #<(~%111) ; %........ .ttttppp
  asl           ; %........ tttt0000
  asl           ; %.......t ttt00000
  tax
  seta8
  lda #^NameFontRenderTop
  pha
  plb

  ; SmallRenderBuffer:
  ; (row 0, byte 0) plane 0 L, plane 0 H, plane 1 L, plane 1 H
  ; (row 1, byte 4) plane 0 L, plane 0 H, plane 1 L, plane 1 H
  ; (row 2, byte 8) plane 0 L, plane 0 H, plane 1 L, plane 1 H
  ; Need to rearrange to SNES 4bpp format here
  .repeat 8, I
    seta16
    lda f:SmallRenderBuffer+I*4+0
    asl
    seta8
    ora a:NameFontRenderTop+I*2+32,x
    sta a:NameFontRenderTop+I*2+32,x
    xba
    ora a:NameFontRenderTop+I*2,x
    sta a:NameFontRenderTop+I*2,x

    seta16
    lda f:SmallRenderBuffer+I*4+2
    asl
    seta8
    ora a:NameFontRenderTop+I*2+32+1,x
    sta a:NameFontRenderTop+I*2+32+1,x
    xba
    ora a:NameFontRenderTop+I*2+1,x
    sta a:NameFontRenderTop+I*2+1,x
  .endrep

  ; Bottom four rows go into NameFontRenderBottom instead
  .repeat 4, I
    seta16
    lda f:SmallRenderBuffer+(I+8)*4+0
    asl
    seta8
    ora a:NameFontRenderBottom+I*2+32,x
    sta a:NameFontRenderBottom+I*2+32,x
    xba
    ora a:NameFontRenderBottom+I*2,x
    sta a:NameFontRenderBottom+I*2,x

    seta16
    lda f:SmallRenderBuffer+(I+8)*4+2
    asl
    seta8
    ora a:NameFontRenderBottom+I*2+32+1,x
    sta a:NameFontRenderBottom+I*2+32+1,x
    xba
    ora a:NameFontRenderBottom+I*2+1,x
    sta a:NameFontRenderBottom+I*2+1,x
  .endrep

  ; .----------------------------------
  ; | Step FontDrawX forward
  ; '----------------------------------
  tdc
  ; Special-case Mm and Ww because they're wider than 8 pixels
  lda PrintedCharacter
  cmp #'M'-'A'
  beq UpperM
  cmp #'m'-'a'+26
  beq LowerM
  cmp #'W'-'A'
  beq UpperW
  cmp #'w'-'a'+26
  beq LowerW
  tax
  .import DialogNameFontWidths
  lda f:DialogNameFontWidths,x
  add FontDrawX
  sta FontDrawX

NextCharacter:
  seta16
  inc DecodePointer
  jmp CharacterLoop
EndOfString:
  plb
  rtl

; Handlers for the four special-case characters
.a8
UpperM:
  jsr StepAhead8
  lda #26*2+0
  jmp HaveCharacterAlready
UpperW:
  jsr StepAhead8
  lda #26*2+1
  jmp HaveCharacterAlready
LowerM:
  jsr StepAhead8
  lda #26*2+2
  jmp HaveCharacterAlready
LowerW:
  jsr StepAhead8
  lda #26*2+3
  jmp HaveCharacterAlready

StepAhead8:
  lda FontDrawX
  add #8
  sta FontDrawX
  rts

ShiftTable:
  .byt 128, 64, 32, 16, 8, 4, 2, 1
.endproc

.macro NameFontText String
  .repeat .strlen(String), I
    .scope
      Char = .strat(String, I)
      .if Char = ' '
        .byt 1
      .endif
      .if Char >= 'A' && Char <= 'Z'
        .byt 2 + Char-'A'
      .endif
      .if Char >= 'a' && Char <= 'z'
        .byt 2 + Char-'a'+26
      .endif
    .endscope
  .endrep
  .byt 0
.endmacro

TestText:
  NameFontText "Maffi"

; Copies NameFontRenderTop and NameFontRenderBottom
; A = address to upload to
; Y = number of tiles to upload, multiplied by 32
.a16
.i16
.export UploadNameFont
.proc UploadNameFont
  php
  pha
  sta PPUADDR

  ; Set DMA parameters  
  lda #DMAMODE_PPUDATA
  sta DMAMODE+$00
  sta DMAMODE+$10

  lda #.loword(NameFontRenderTop)
  sta DMAADDR+$00
  lda #.loword(NameFontRenderBottom)
  sta DMAADDR+$10

  sty DMALEN+$00
  sty DMALEN+$10

  seta8
  lda #^NameFontRenderTop
  sta DMAADDRBANK+$00
  sta DMAADDRBANK+$10

  lda #%00000001
  sta COPYSTART

  ; Bottom row -------------------
  seta16
  pla
  add #(16*32)>>1 ; Go down a row
  sta PPUADDR
  seta8
  lda #%00000010
  sta COPYSTART
  plp
  rtl
.endproc

DialogNameFont:
  .incbin "../tilesets2/DialogNameFont.chrgb"
