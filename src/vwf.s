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

;
; API:
;
; ----- InitVWF
; Initializes the VWF engine and sets defaults for everything
;
; ----- DrawVWF
; Interprets the string pointed to via DecodePointer and renders into the text bitmap
;
; ----- PushVWF
; Pushes the current DecodePointer on the VWF engine's stack
;
; ----- CopyVWF
; Copies the text bitmap into VRAM
;

.include "snes.inc"
.include "global.inc"
.include "vwf.inc"
.include "graphicsenum.s"
.include "paletteenum.s"
.smart

; First plane
RenderBuffer1 = RenderBuffer
; Second plane
RenderBuffer2 = RenderBuffer + 2048

FontColorRoutine = TempVal       ; Address to JMP to
FontDataPointer  = TouchTemp + 0
FontWidthPointer = TouchTemp + 2
FontDrawX        = TouchTemp + 4 ; 8-bit
FontDrawY        = TouchTemp + 5 ; 16-bit
TextPointer      = DecodePointer
DoubleWideBuffer1 = 8  ; First half
DoubleWideBuffer2 = 10 ; Second half
.segment "VWF"

.export InitVWF
.proc InitVWF
  seta8
  stz FontDrawX
  stz VWFStackIndex

  setaxy16
  ldx #.loword(Scratchpad)
  ldy #4096
  jsl MemClear

  lda #.loword(chrData-(' '*8))
  sta FontDataPointer
  lda #.loword(chrWidths-' ')
  sta FontWidthPointer
  lda #.loword(DoFontColor1)
  sta FontColorRoutine

  stz FontDrawY
  rtl
.endproc

.export DrawVWF
.a16
.i16
.proc DrawVWF
  phb
  phk
  plb

  ; Initialize the render index
PreCharacterLoop:
  seta16
  lda FontDrawX
  and #255
  lsr
  lsr
  lsr
  add FontDrawY
  tax

CharacterLoop:
  seta8
  ; Draw
  lda [DecodePointer]
  cmp #$20
  jcc SpecialCommand
HaveCharacter:
  jsr GlyphShift

  ; Push the render buffer bank first
  lda #^RenderBuffer
  pha

  seta16
  phk
  plb
  jmp (FontColorRoutine)
AfterFontColor:

  ; Step forward by the width amount
  phk
  plb
  seta8
  lda #0
  xba
  lda [DecodePointer] ; Reread the character
  tay
  lda (FontWidthPointer),y
  add FontDrawX
  sta FontDrawX
  seta16

  ; Convert to tile index
  and #255
  lsr
  lsr
  lsr
  add FontDrawY
  tax

  inc DecodePointer
  jmp CharacterLoop

; -------------------------------------

SpecialCommand:
  ; $00-$1f execute a special command
  phk
  plb
  seta16
  inc DecodePointer ; Step past the command
  and #255
  asl
  tay
  lda SpecialCommandTable,y
  pha
  seta8
  rts

SpecialCommandTable:
  .addr EndScript-1
  .addr EndPage-1
  .addr EndLine-1
  .addr CallASM-1
  .addr EscapeCode-1
  .addr ExtendedChar-1
  .addr Color1-1
  .addr Color2-1
  .addr Color3-1
  .addr SetX-1
  .addr SetXY-1
  .addr WideText-1
  .addr BigText-1

; -------------------------------------

; Move the cursor horizontally and vertically to a given position
.a8
SetXY:
  lda [DecodePointer]
  sta FontDrawX
  ; Get Y too
  seta16
  inc DecodePointer
  lda [DecodePointer]
  and #255
  asl ; Multiply by 32
  asl
  asl
  asl
  asl
  sta FontDrawY

  inc DecodePointer
  jmp PreCharacterLoop

; Move the cursor horizontally to a given position
.a8
SetX:
  lda [DecodePointer]
  sta FontDrawX
  lda #1
  jmp TookParameters

.a8
Color1:
  seta16
  lda #.loword(DoFontColor1)
  sta FontColorRoutine
  jmp PreCharacterLoop

.a8
Color2:
  seta16
  lda #.loword(DoFontColor2)
  sta FontColorRoutine
  jmp PreCharacterLoop

.a8
Color3:
  seta16
  lda #.loword(DoFontColor3)
  sta FontColorRoutine
  jmp PreCharacterLoop

.a8
ExtendedChar: ; Interpret the next byte as a character code
  lda [DecodePointer]
  jmp HaveCharacter

.a8
EscapeCode:
  jmp PreCharacterLoop

.a8
.i16
CallASM:
  ; Read the pointer for the routine to call
  lda [DecodePointer]
  sta 0
  ldy #1
  lda [DecodePointer],y
  sta 1
  iny
  lda [DecodePointer],y
  sta 2

  jsl @Call
  lda #3
  jmp TookParameters
@Call:
  jml [0]

.a8
EndLine:
  stz FontDrawX
  seta16
  lda FontDrawY
  add #32*8
  sta FontDrawY
  jmp PreCharacterLoop

.a8
EndPage:
  jmp PreCharacterLoop

.a8
EndScript:
  ; Exit if the stack is empty
  lda VWFStackIndex
  beq ReallyExit

  dec VWFStackIndex

  ; Pop the text decode pointer off the stack
  lda #0 ; Clear high byte
  xba
  lda VWFStackIndex
  tay
  lda VWFStackL,y
  sta DecodePointer+0
  lda VWFStackH,y
  sta DecodePointer+1
  lda VWFStackB,y
  sta DecodePointer+2
  ; Keep going!
  jmp PreCharacterLoop

TookParameters: ; Step DecodePointer forward by a given number
  seta16
  and #255
  add DecodePointer
  sta DecodePointer
  jmp PreCharacterLoop

ReallyExit:
  setaxy16

  plb
  rtl
.endproc

.proc DoFontColor1
  plb
  .repeat 8, I
    lda I*2
    asl
    xba
    ora a:RenderBuffer1+(32*I),x
    sta a:RenderBuffer1+(32*I),x
  .endrep
  jmp DrawVWF::AfterFontColor
.endproc

.proc DoFontColor2
  plb
  .repeat 8, I
    lda I*2
    asl
    xba
    ora a:RenderBuffer2+(32*I),x
    sta a:RenderBuffer2+(32*I),x
  .endrep
  jmp DrawVWF::AfterFontColor
.endproc

.proc DoFontColor3
  plb
  .repeat 8, I
    lda I*2
    asl
    xba
    pha
    ora a:RenderBuffer1+(32*I),x
    sta a:RenderBuffer1+(32*I),x
    pla
    ora a:RenderBuffer2+(32*I),x
    sta a:RenderBuffer2+(32*I),x
  .endrep
  jmp DrawVWF::AfterFontColor
.endproc

; Draws text that's twice as wide
.proc WideText
  seta16
  lda FontDrawX
  and #255
  lsr
  lsr
  lsr
  add FontDrawY
  tax

CharacterLoop:
  seta8
  lda [DecodePointer]
  cmp #$20
  jcc DrawVWF::SpecialCommand ; Bail out of wide mode

  jsr Common1

  seta16
  .repeat 8, I
    lda I
    jsr DoubleWide
    lda DoubleWideBuffer1
    ora a:RenderBuffer1+(32*I),x
    sta a:RenderBuffer1+(32*I),x
    lda DoubleWideBuffer2
    ora a:RenderBuffer1+(32*I+2),x
    sta a:RenderBuffer1+(32*I+2),x
  .endrep

  jsr Common2
  jmp CharacterLoop

Common1:
  ; Compute the address of the character's glyph
  seta16
  and #255
  asl
  asl
  asl
  tay
  phk ; All the glyphs are in this bank
  plb
  seta8

  ; Get the tile data
  phx
  ldx #0
: lda (FontDataPointer),y
  sta 0,x
  iny
  inx
  cpx #8
  bne :-
  plx

  ; Set the render buffer bank now
  lda #^RenderBuffer
  pha
  plb
  rts

Common2:
  ; Step forward by double the width amount
  phk
  plb
  seta8
  lda #0
  xba
  lda [DecodePointer] ; Reread the character
  tay
  ; Add double the width
  lda (FontWidthPointer),y
  asl
  add FontDrawX
  sta FontDrawX
  seta16

  ; Convert to tile index
  and #255
  lsr
  lsr
  lsr
  add FontDrawY
  tax

  inc DecodePointer
  rts

; Doubles the pixel values of a glyph
DoubleWide:
  phx ; Index size is temporarily 8-bit, so preserve X
  setaxy8
  ; .... oooo
  ldy #4
  phy
: lsr
  php
  ror DoubleWideBuffer1+1
  plp
  ror DoubleWideBuffer1+1
  dey
  bne :-

  ; oooo ....
  ply
: lsr
  php
  ror DoubleWideBuffer1+0
  plp
  ror DoubleWideBuffer1+0
  dey
  bne :-

  stz DoubleWideBuffer2+0
  stz DoubleWideBuffer2+1

  lda FontDrawX
  and #7
  beq @Skip
  tay
: lsr DoubleWideBuffer1+0
  ror DoubleWideBuffer1+1
  ror DoubleWideBuffer2+0
  ror DoubleWideBuffer2+1
  dey
  bne :-
@Skip:

  setaxy16
  plx
  rts
.endproc

; Draws text that's twice as wide and tall
.proc BigText
  seta16
  lda FontDrawX
  and #255
  lsr
  lsr
  lsr
  add FontDrawY
  tax

CharacterLoop:
  seta8
  lda [DecodePointer]
  cmp #$20
  jcc DrawVWF::SpecialCommand ; Bail out of wide mode

  jsr WideText::Common1

  seta16
  .repeat 8, I
    lda I
    jsr WideText::DoubleWide
    lda DoubleWideBuffer1
    ora a:RenderBuffer1+(64*I+0),x
    sta a:RenderBuffer1+(64*I+0),x
    lda DoubleWideBuffer1
    ora a:RenderBuffer1+(64*I+32),x
    sta a:RenderBuffer1+(64*I+32),x
    lda DoubleWideBuffer2
    ora a:RenderBuffer1+(64*I+2+0),x
    sta a:RenderBuffer1+(64*I+2+0),x
    lda DoubleWideBuffer2
    ora a:RenderBuffer1+(64*I+2+32),x
    sta a:RenderBuffer1+(64*I+2+32),x
  .endrep

  jsr WideText::Common2
  jmp CharacterLoop
.endproc

; Push the current DecodePointer value
.export PushVWF
.i16
.proc PushVWF
  seta8
  ; Push the text decode pointer on the stack
  lda #0 ; Clear high byte
  xba
  lda VWFStackIndex
  tay
  lda DecodePointer+0
  sta VWFStackL,y
  lda DecodePointer+1
  sta VWFStackH,y
  lda DecodePointer+2
  sta VWFStackB,y

  inc VWFStackIndex
  rtl
.endproc

; Copy the bitmap buffer to VRAM
.export CopyVWF
.i16
.proc CopyVWF
  seta8
  lda #INC_DATALO|VRAM_BITMAP2 ; +1 on PPUDATA low byte write
  sta PPUCTRL

  ldx #.loword(RenderBuffer1)
  stx DMAADDR+$00
  ldx #.loword(RenderBuffer2)
  stx DMAADDR+$10
  ldx #DMAMODE_PPULODATA
  stx DMAMODE+$00
  ldx #DMAMODE_PPUHIDATA
  stx DMAMODE+$10
  ldx #2048
  stx DMALEN+$00
  stx DMALEN+$10
  lda #^RenderBuffer1
  sta DMAADDRBANK+$00
  sta DMAADDRBANK+$10

  ; -----------------------------------

  ldx #$f000>>1
  stx PPUADDR
  lda #$01
  sta COPYSTART

  ; -----------------------------------

  lda #INC_DATAHI|VRAM_BITMAP2  ; +1 on PPUDATA high byte write
  sta PPUCTRL

  stx PPUADDR
  lda #$02
  sta COPYSTART

  ; -----------------------------------

  lda #INC_DATAHI  ; +1 on PPUDATA high byte write
  sta PPUCTRL
  seta16
  rtl
.endproc

; Input: A (Glyph to draw)
; Output: 0-15 (The shifted glyph's rows)
.proc GlyphShift
  phk
  plb

  phy
  phx
  php
  setaxy16
  ; Calculate the start of the glyph's data
  and #255
  asl
  asl
  asl
  tay
  lda #0 ; Clear high byte for the TAX
  seta8
  lda FontDrawX
  and #7
  tax    ; High byte (zero) is transferred too
  lda ShiftTable,x
  sta CPUMCAND ; Keep this constant for the whole glyph

  ; Start shifting!
  lda (FontDataPointer),y
  .repeat 8, I
    sta CPUMUL              ; Kick off the multiplier
    iny                     ; 2 cycles
    lda (FontDataPointer),y ; 6 cycles
    ldx CPUPROD             ; 3 cycles before the read
    stx I*2                 ; =11 cycles waiting
  .endrep
  plp
  plx
  ply
  rts

ShiftTable:
  .byt 128, 64, 32, 16, 8, 4, 2, 1
.endproc

chrData:
  .byt   0,  0,  0,  0,  0,  0,  0,  0,  0,128,128,128,128,  0,128,  0
  .byt   0,160,160,  0,  0,  0,  0,  0,  0, 80,248, 80,248, 80,  0,  0
  .byt   0, 32,112,160, 96, 80,224, 64,  0,208,208, 32, 96, 64,176,176
  .byt   0, 64,160, 64,168,144,104,  0,  0,128,128,  0,  0,  0,  0,  0
  .byt   0, 32, 64,128,128,128, 64, 32,  0,128, 64, 32, 32, 32, 64,128
  .byt   0, 32,168,112,168, 32,  0,  0,  0, 32, 32,248, 32, 32,  0,  0
  .byt   0,  0,  0,  0,  0,  0,128,128,  0,  0,  0,240,  0,  0,  0,  0
  .byt   0,  0,  0,  0,  0,  0,128,  0,  0, 16, 16, 32, 96, 64,128,128
  .byt   0, 96,144,144,144,144, 96,  0,  0, 32, 96, 32, 32, 32, 32,  0
  .byt   0, 96,144, 16, 96,128,240,  0,  0, 96, 16, 96, 16,144, 96,  0
  .byt   0, 48, 80,144,240, 16, 16,  0,  0,112,128,224, 16,144, 96,  0
  .byt   0, 96,128,224,144,144, 96,  0,  0,240, 16, 32, 32, 64, 64,  0
  .byt   0, 96,144, 96,144,144, 96,  0,  0, 96,144,144,112, 16, 96,  0
  .byt   0,  0,128,  0,  0,  0,128,  0,  0,  0,128,  0,  0,  0,128,128
  .byt   0,  0, 16, 96,128, 96, 16,  0,  0,  0,240,  0,  0,240,  0,  0
  .byt   0,  0,128, 96, 16, 96,128,  0,  0, 96,144, 16, 32,  0, 32,  0
  .byt   0, 56, 68,154,170,170,158, 64,  0, 32, 80, 80,248,136,136,  0
  .byt   0,240,136,240,136,136,240,  0,  0,112,136,128,128,136,112,  0
  .byt   0,240,136,136,136,136,240,  0,  0,248,128,240,128,128,248,  0
  .byt   0,248,128,240,128,128,128,  0,  0,112,136,128,152,136,120,  0
  .byt   0,136,136,248,136,136,136,  0,  0,128,128,128,128,128,128,  0
  .byt   0, 64, 64, 64, 64, 64, 64,128,  0,136,144,160,224,144,136,  0
  .byt   0,128,128,128,128,128,248,  0,  0,132,204,204,180,180,132,  0
  .byt   0,136,200,168,168,152,136,  0,  0,112,136,136,136,136,112,  0
  .byt   0,240,136,136,240,128,128,  0,  0,112,136,136,136,136,112,  8
  .byt   0,240,136,136,240,144,136,  0,  0,112,136, 96, 16,136,112,  0
  .byt   0,248, 32, 32, 32, 32, 32,  0,  0,136,136,136,136,136,112,  0
  .byt   0,136,136,136, 80, 80, 32,  0,  0,132,180,180,180, 72, 72,  0
  .byt   0,136, 80, 32, 32, 80,136,  0,  0,136, 80, 32, 32, 32, 32,  0
  .byt   0,248,  8, 16, 96,128,248,  0,  0,224,128,128,128,128,128,224
  .byt   0,128,128, 64, 96, 32, 16, 16,  0,224, 32, 32, 32, 32, 32,224
  .byt   0, 32, 80,136,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,248
  .byt   0,128, 64,  0,  0,  0,  0,  0,  0,  0, 96, 16,112,144,112,  0
  .byt   0,128,224,144,144,144,224,  0,  0,  0, 96,144,128,144, 96,  0
  .byt   0, 16,112,144,144,144,112,  0,  0,  0, 96,144,240,128,112,  0
  .byt   0, 48, 64,224, 64, 64, 64,  0,  0,  0,112,144,144,112, 16, 96
  .byt   0,128,224,144,144,144,144,  0,  0,128,  0,128,128,128,128,  0
  .byt   0, 64,  0, 64, 64, 64, 64,128,  0,128,144,160,192,160,144,  0
  .byt   0,128,128,128,128,128, 64,  0,  0,  0,208,168,168,168,168,  0
  .byt   0,  0,224,144,144,144,144,  0,  0,  0, 96,144,144,144, 96,  0
  .byt   0,  0,224,144,144,224,128,128,  0,  0,112,144,144,112, 16, 16
  .byt   0,  0,224,128,128,128,128,  0,  0,  0,112,128, 96, 16,224,  0
  .byt   0, 64,224, 64, 64, 64, 32,  0,  0,  0,144,144,144,144,112,  0
  .byt   0,  0,144,144,144, 96, 96,  0,  0,  0,136,168,168, 80, 80,  0
  .byt   0,  0,144,144, 96,144,144,  0,  0,  0,144,144, 96, 32, 64,128
  .byt   0,  0,240, 16, 96,128,240,  0,  0, 48, 64, 64,128, 64, 64, 48
  .byt   0,128,128,128,128,128,128,128,  0,192, 32, 32, 16, 32, 32,192
  .byt   0, 80,160,  0,  0,  0,  0,  0,  0,  0, 32, 80,136,136,248,  0
  .byt   0, 56, 68,146,162,138, 68, 56,  0, 56, 68,154,162,154, 68, 56
  .byt   0,108,146,130,130, 68, 40, 16,  0,240,144,144,144,144,240,  0
  .byt   0, 32,112,168, 32, 32, 32,  0,  0, 32, 32, 32,168,112, 32,  0
  .byt   0,  0, 32, 64,248, 64, 32,  0,  0,  0, 32, 16,248, 16, 32,  0
chrWidths:
  .byt   3,  2,  4,  6,  5,  5,  6,  2,  4,  4,  6,  5,  2,  5,  2,  5
  .byt   5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  2,  2,  5,  5,  5,  5
  .byt   8,  6,  6,  6,  6,  6,  6,  6,  6,  2,  3,  6,  6,  7,  6,  6
  .byt   6,  6,  6,  6,  6,  6,  6,  7,  6,  6,  6,  4,  5,  4,  6,  5
  .byt   3,  5,  5,  5,  5,  5,  4,  5,  5,  2,  3,  5,  3,  6,  5,  5
  .byt   5,  5,  4,  5,  4,  5,  5,  6,  5,  5,  5,  5,  2,  5,  5,  6
  .byt   8,  8,  8,  5,  6,  6,  6,  6
