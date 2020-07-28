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
.smart
.a16
.i16

.export BGEffectInit
.proc BGEffectInit
  lda LevelBackgroundId
  and #255
  asl
  tax
  .import BackgroundSetup
  lda f:BackgroundSetup,x
  beq No
  sta 0
  jmp (0)
No:
  rtl
.endproc

.export BGEffectRun
.proc BGEffectRun
  lda LevelBackgroundId
  and #255
  asl
  tax
  .import BackgroundRoutine
  lda f:BackgroundRoutine,x
  beq No
  sta 0
  jmp (0)
No:
  rtl
.endproc


.export SetupSkyGradient
.proc SetupSkyGradient
  seta8
  lda #^HDMARedTable
  sta DMAADDRBANK+$20 ;R
  sta DMAADDRBANK+$30 ;G
  sta DMAADDRBANK+$40 ;B
  sta DMAADDRBANK+$50 ;Scroll
  stz HDMAINDBANK+$50

  ldx #(<COLDATA << 8) | DMA_LINEAR
  stx DMAMODE+$20
  stx DMAMODE+$30
  stx DMAMODE+$40
  ldx #(<BG2HOFS << 8) | DMA_00 | DMA_INDIRECT
  stx DMAMODE+$50

  ldx #.loword(HDMARedTable)
  stx DMAADDR+$20
  ldx #.loword(HDMAGreenTable)
  stx DMAADDR+$30
  ldx #.loword(HDMABlueTable)
  stx DMAADDR+$40
  ldx #.loword(HDMAScrollTable)
  stx DMAADDR+$50

  lda #%111100
  tsb HDMASTART_Mirror
  lda #%00100000 ; On backgrounds
  sta CGADSUB
  stz CGADDR
  stz CGDATA
  stz CGDATA
  setaxy16
  rtl

HDMARedTable:
   .byt $0F, $20
   .byt $0E, $21
   .byt $0F, $22
   .byt $0E, $23
   .byt $0E, $24
   .byt $0E, $25
   .byt $0F, $26
   .byt $0F, $27
   .byt $0E, $28
   .byt $0E, $29
   .byt $0E, $2A
   .byt $0F, $2B
   .byt $0F, $2C
   .byt $0E, $2D
   .byt $0E, $2E
   .byt $08, $2F
   .byt $00

HDMAGreenTable:
   .byt $0F, $4C
   .byt $0F, $4D
   .byt $0E, $4E
   .byt $0E, $4F
   .byt $0E, $50
   .byt $0F, $51
   .byt $0F, $52
   .byt $0E, $53
   .byt $0E, $54
   .byt $0E, $55
   .byt $0F, $56
   .byt $0F, $57
   .byt $0E, $58
   .byt $0E, $59
   .byt $0E, $5A
   .byt $08, $5B
   .byt $00

HDMABlueTable:
   .byt $0C, $9B
   .byt $46, $9C
   .byt $46, $9D
   .byt $46, $9E
   .byt $02, $9F
   .byt $00

HDMAScrollTable:
   .byt 127
   .addr BGEffectRAM+2
   .byt 44
   .addr BGEffectRAM+0
   .byt 1
   .addr BGScrollXPixels
   .byt 0
.endproc

.export UpdateSkyGradient
.proc UpdateSkyGradient
  lda BGScrollXPixels  
  lsr
  sta BGEffectRAM+0
  lsr
  sta BGEffectRAM+2
  rtl
.endproc
