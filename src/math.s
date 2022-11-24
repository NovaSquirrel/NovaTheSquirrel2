.include "snes.inc"
.include "global.inc"
.smart
.import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight
.code

; Wrapper for GetAtan2 that saves X and the data bank, and automatically loads the angle
.export GetAngle512
.a16
.i16
.proc GetAngle512
  phb
  phx
  setxy8
  jsr GetAtan2
  setaxy16
  plx
  plb

  lda 0 ; Get the angle
  rtl
.endproc


; Adapted from https://github.com/VitorVilela7/SMW-CodeLib/blob/master/asm/math/atan2.asm by NovaSquirrel
; Original by Akaginite
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GetAtan2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; This routine will get angle between two points.
;
; Input:
; $00-$01 X-Distance
; $02-$03 Y-Distance
;
; Output:
; $00-$01 Angle (0x0000-0x01FF)
; $02-$06 will be destructed.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.a16
.i8
.proc GetAtan2
  phk
  plb

  ldy #0
  lda 0
  bpl :+    ; DX = abs(DX)
    ldy #4
    eor #$ffff
    ina
    sta 0
  :

  lda 2
  bpl :+    ; DY = abs(DY)
    iny
    iny
    eor #$ffff
    ina
    sta 2
  :

  cmp 0    ; If X is smaller than Y, swap them
  bcc :+
    pha
    lda 0
    sta 2
    pla
    sta 0
    iny
  :

  sty 6
  lda 2
  sta 4
  stz 2
  ora 0
  and #$ff00
  beq Next
    xba
  : lsr 0
    lsr 4
    ror 2
    lsr a
    bne :-
Next:
  ldy 0
  beq DivZero
  lda 3
  sta CPUNUM
  sty CPUDEN

  seta8
  ; Wait 16 cycles
  stz 1
  lda #$40
  cpy 3
  beq :+
  bra Delay
Delay:

  ldy CPUQUOT
  lda AtanTable,y
: lsr 6
  bcc :+
  eor #$7f
  ina
: lsr 6
  bcc :+
  eor #$ff
  ina
  beq :+
  inc 1
: lsr 6
  bcc :+
  eor #$ff
  ina
  bne :+
  inc 1
: sta 0
  lda #$fe
  trb 1
  rts
		
DivZero:
  seta8
  ldy #0
  lda 6
  lsr a
  bcs :+
    lda #$80
    lsr a
: and #1
  sta 1
  sta 0
  rts
.endproc

AtanTable:
  .byt $00,$00,$01,$01,$01,$02,$02,$02,$03,$03,$03,$03,$04,$04,$04,$05
  .byt $05,$05,$06,$06,$06,$07,$07,$07,$08,$08,$08,$09,$09,$09,$0A,$0A
  .byt $0A,$0A,$0B,$0B,$0B,$0C,$0C,$0C,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0F
  .byt $0F,$0F,$10,$10,$10,$11,$11,$11,$12,$12,$12,$12,$13,$13,$13,$14
  .byt $14,$14,$15,$15,$15,$15,$16,$16,$16,$17,$17,$17,$18,$18,$18,$18
  .byt $19,$19,$19,$1A,$1A,$1A,$1A,$1B,$1B,$1B,$1C,$1C,$1C,$1C,$1D,$1D
  .byt $1D,$1E,$1E,$1E,$1E,$1F,$1F,$1F,$1F,$20,$20,$20,$21,$21,$21,$21
  .byt $22,$22,$22,$22,$23,$23,$23,$23,$24,$24,$24,$24,$25,$25,$25,$26
  .byt $26,$26,$26,$27,$27,$27,$27,$28,$28,$28,$28,$29,$29,$29,$29,$2A
  .byt $2A,$2A,$2A,$2A,$2B,$2B,$2B,$2B,$2C,$2C,$2C,$2C,$2D,$2D,$2D,$2D
  .byt $2E,$2E,$2E,$2E,$2E,$2F,$2F,$2F,$2F,$30,$30,$30,$30,$30,$31,$31
  .byt $31,$31,$32,$32,$32,$32,$32,$33,$33,$33,$33,$33,$34,$34,$34,$34
  .byt $34,$35,$35,$35,$35,$35,$36,$36,$36,$36,$36,$37,$37,$37,$37,$37
  .byt $38,$38,$38,$38,$38,$39,$39,$39,$39,$39,$39,$3A,$3A,$3A,$3A,$3A
  .byt $3B,$3B,$3B,$3B,$3B,$3B,$3C,$3C,$3C,$3C,$3C,$3D,$3D,$3D,$3D,$3D
  .byt $3D,$3E,$3E,$3E,$3E,$3E,$3E,$3F,$3F,$3F,$3F,$3F,$3F,$40,$40,$40

.a16
.i16
.proc Unsigned16x16Multiply
; Adapted from https://wiki.superfamicom.org/16-bit-multiplication-and-division
MultiplyA  = 0
MultiplyB  = 2
ResultLow  = 4
ResultHigh = 6
  setxy8
  ldx MultiplyA
  stx CPUMCAND
  ldy MultiplyB
  sty CPUMUL        ; set up 1st multiply
  ldx MultiplyB+1
  clc
  lda CPUPROD       ; load CPUPROD for 1st multiply
  stx CPUMUL        ; start 2nd multiply
  sta ResultLow
  stz ResultHigh    ; high word of product needs to be cleared
  lda CPUPROD       ; read CPUPROD from 2nd multiply
  ldx MultiplyA+1
  stx CPUMCAND      ; set up 3rd multiply
  sty CPUMUL        ; y still contains MultiplyB
  ldy MultiplyB+1
  adc ResultLow+1
  adc CPUPROD       ; add 3rd product
  sta ResultLow+1
  sty CPUMUL        ; set up 4th multiply
  lda ResultHigh    ; carry bit to last byte of product
  bcc :+
    adc #$00ff
  :
  adc CPUPROD       ; add 4th product
  sta ResultHigh    ; final store
  setxy16
  rtl
.endproc

.a16
.i16
.proc Unsigned16x16Multiply_16
; Adapted from https://wiki.superfamicom.org/16-bit-multiplication-and-division
MultiplyA  = 0
MultiplyB  = 2
ResultLow  = 4
  setxy8
  ldx MultiplyA
  stx CPUMCAND
  ldy MultiplyB
  sty CPUMUL        ; set up 1st multiply
  ldx MultiplyB+1
  clc
  lda CPUPROD       ; load CPUPROD for 1st multiply
  stx CPUMUL        ; start 2nd multiply
  sta a:ResultLow
  lda CPUPROD       ; read CPUPROD from 2nd multiply
  ldx MultiplyA+1
  stx CPUMCAND      ; set up 3rd multiply
  sty CPUMUL        ; y still contains MultiplyB
  adc a:ResultLow+1
  adc CPUPROD       ; add 3rd product
  sta ResultLow+1
  setxy16
  rtl
.endproc
