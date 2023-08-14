; Adapted from https://github.com/bbbradsmith/SNES_stuff/tree/main/dizworld
; which is licensed under CC BY 4.0
;
; Original:
; rainwarrior 2022
; http://rainwarrior.ca
;
; Adapted by NovaSquirrel

.include "../snes.inc"
.include "../global.inc"
.smart

.globalzp angle, scale, scale2, M7PosX, M7PosY, cosa, sina, math_a, math_b, math_p, math_r, det_r, texelx, texely, screenx, screeny
.globalzp mode7_m7t
.globalzp pv_l0, pv_l1, pv_s0, pv_s1, pv_sh, pv_interp
.global pv_buffer, mode7_m7x, mode7_m7y

.import perspective_m7a_m7b_list, perspective_m7c_m7d_list, perspective_ab_banks

.segment "ZEROPAGE" ; < $100
temp = 0 ; temp+0 to temp+13 used
temp2 = 14

;Original definitions:
;pv_zr:        .res 2 ; interpolated 1/Z
;pv_zr_inc:    .res 2 ; zr increment per line
;pv_sh_:       .res 2 ; =pv_sh, or if pv_sh=0 then computed value
;pv_scale:     .res 4 ; 8-bit scale of a/b/c/d
;pv_negate:    .res 1 ; negation of a/b/c/d
;pv_interps:   .res 2 ; interpolate * 4 for stride increment
pv_zr      = temp2
pv_zr_inc  = pv_zr + 2
pv_sh_     = pv_zr_inc + 2
.assert ((pv_sh_ + 2) < 24), error, "too many temporaries in Mode 7"
pv_negate  = TouchTemp
pv_interps = TouchTemp+1 ;and +2
pv_scale   = TouchTemp+3 ;and +4, +5, +6

; TODO: Put these behind a union?
angle:        .res 2 ; for spinning modes
;scale:        .res 2 ; for uniform scale
;scale2:       .res 4 ; for separate axis scale
M7PosX:       .res 4 ; position for some modes with subpixel precision
M7PosY:       .res 4 ; ff ii ii ..

cosa:         .res 2 ; sincos result
sina:         .res 2
math_a:       .res 4 ; multiply/divide/math input terms 16 or 32-bit
math_b:       .res 4
math_p:       .res 8 ; product/quotient
math_r:       .res 8 ; remainder

;det_r:        .res 4 ; storage for 1 / AD-BC (16.16f)
texelx:       .res 2 ; input/result for coordinate transforms
texely:       .res 2
screenx:      .res 2
screeny:      .res 2

mode7_m7t:    .res 8 ; <-- Initial mode 7 matrix settings. Can ignore because HDMA will overwrite it.

; perspective
; inputs
pv_l0:        .res 1 ; first scanline
pv_l1:        .res 1 ; last scanline + 1
pv_s0:        .res 2 ; horizontal texel distance at l0
pv_s1:        .res 2 ; horizontal texel distance at l1
pv_sh:        .res 2 ; vertical texel distance from l0 to l1, sh=0 to copy s0 scale for efficiency: (s0*(l1-l0)/256)
pv_interp:    .res 1 ; interpolate every X lines, 0,1=1x (no interpolation, 2=2x, 4=4x, other values invalid


.segment "BSS"
;pv_wrap:        .res 1 ; 0 if no wrapping, 1 if wrapping (does not affect PPU wrapping)
mode7_m7x:      .res 2
mode7_m7y:      .res 2
pv_buffer:      .res 1 ; 0/1 selects double buffer

;--------------------------------------
; HDMA double-buffer for perspective
pv_hdma_ab0 = HDMA_Buffer1      ; Mode 7 matrix AB
pv_hdma_cd0 = HDMA_Buffer1+1024 ; Mode 7 matrix CD

pv_hdma_ab1 = HDMA_Buffer2
pv_hdma_cd1 = HDMA_Buffer2+1024

PV_HDMA_STRIDE = pv_hdma_ab1 - pv_hdma_ab0
.export PV_HDMA_STRIDE

.a8
.i8
.segment "C_Mode7Game"

;
; =============================================================================
; Math
;

; summary of available subroutines:
;   inputs:  math_a, math_b, A register
;   outputs: math_p, math_r, A register
;   values are unsigned (u16), signed (s16), either (16) or fixed point (8.8)
;   .a16 .i8 DB=0 assumed
;
; umul16:         u16 a *    u16 b =  u32 p                clobbers A/X/Y                 ~620 clocks
; smul16_u8:      s16 a *     u8 b =  s24 p (A=msw)        clobbers A/X/Y                 ~570 clocks
; smul16:         s16 a *    s16 b =   32 p                clobbers A/X/Y                 ~770 clocks
; mul16t:          16 a *     16 b =   16 A/p (truncated)  clobbers A/X/Y                 ~500 clocks
; smul16f:       s8.8 a *   s8.8 b = s8.8 A = s16.16 p     clobbers A/X/Y                 ~920 clocks
; smul32f_16f:  s24.8 a *   s8.8 b = s8.8 A =  s8.24 p     clobbers A/X/Y,a,b,r           ~2570 clocks (1.8 scanlines)
; smul32ft:     s24.8 a * s16.16 b = s8.8 A = s16.24 r     clobbers A/X/Y,a,b,p,temp0-13  ~3600 clocks (2.6 scanlines)
;
; udiv32:         u32 a /    u32 b =  u32 p    % u32 r     clobbers A/X (DB any)          ~12400 clocks (9 scanlines)
; sdiv32          s32 a /    s32 b =  s32 p    % u32 r     clobbers A/X/Y (DB any)        ~14000 clocks (10 scanlines)
; recip16f:           1 /   s8.8 A = s8.8 A = s16.16 p     clobbers A/X,a,b (DB any)      ~12450 clocks (9 scanlines)
;
; sign:         A = value, returns either 0 or $FFFF       preserves flags (.i8/.i16 allowed, DB any)
; sincos:       A = angle 0-255, result in cosa/sina       clobbers A/X (i8/.i16 allowed, DB any)

; unsigned 16-bit multiply, 32-bit result
; Written by 93143: https://forums.nesdev.org/viewtopic.php?p=280089#p280089
.a16
.i8
.proc umul16 ; math_a x math_b = math_p, clobbers A/X/Y
	; DB = 0
	ldx z:math_a+0
	stx a:CPUMCAND
	ldy z:math_b+0
	sty a:CPUMUL       ; a0 x b0 (A)
	ldx z:math_b+1
	stz z:math_p+2
	lda a:CPUPROD
	stx a:CPUMUL       ; a0 x b1 (B)
	sta z:math_p+0    ; 00AA
	ldx z:math_a+1
	lda a:CPUPROD
	stx a:CPUMCAND
	sty a:CPUMUL       ; a1 x b0 (C)
	add z:math_p+1    ; 00AA + 0BB0 (can't set carry because high byte was 0)
	ldy z:math_b+1
	adc a:CPUPROD
	sty a:CPUMUL       ; a1 x b1 (D)
	sta z:math_p+1    ; 00AA + 0BB0 + 0CC0
	lda z:math_p+2
	bcc :+
	adc #$00FF        ; if carry, increment top byte
:
	adc a:CPUPROD
	sta z:math_p+2    ; 00AA + 0BB0 + 0CC0 + DD00
	rts
.endproc

; signed 16-bit x 8-bit multiply, 24-bit result, returns high 16
.a16
.i8
.export smul16_u8, sdiv32, umul16, smul32f_16f, smul16, smul16f
.proc smul16_u8 ; math_a x math_b = math_p, clobbers A/X/Y
	; DB = 0
	ldx z:math_b
	stx a:CPUMCAND
	ldy z:math_a+0
	sty a:CPUMUL       ; b x a0 (A)
	ldx z:math_a+1
	stz z:math_p+2
	lda a:CPUPROD
	stx a:CPUMUL       ; b x a1 (B)
	sta z:math_p+0    ; 0AA
	lda z:math_p+1
	add a:CPUPROD       ; 0AA + BB0
	sta z:math_p+1
	cpx #$80
	bcc :+ ; if sign bit, must mutiply b by sign extend
		ldx #$FF
		stx a:4203
		clc
		lda z:math_p+2
		adc a:CPUPROD   ; 0AA + BB0 + C00
		sta z:math_p+2
		lda z:math_p+1
	:
	rts
.endproc

; signed 16-bit multiply, 32-bit result, clobbers A/X/Y
.a16
.i8
.proc smul16
	; DB = 0
	jsr umul16
	; A = math_p+2
	; X = math_a+1
	; Y = math_b+1
	cpx #$80
	bcc :+
		;sec
		sbc z:math_b ; sign extend math_a: (-1 << 16) x math_b
	:
	cpy #$80
	bcc :+
		;sec
		sbc z:math_a ; sign extend math_b: (-1 << 16) x math_a
	:
	sta z:math_p+2
	rts
.endproc

; 16-bit multiply, truncated 16-bit result (sign-agnostic), clobbers A/X/Y
.proc mul16t
	; DB = 0
	.a16
	.i8
	ldx z:math_a+0
	stx a:CPUMCAND
	ldy z:math_b+0
	sty a:CPUMUL       ; a0 x b0 (A)
	ldx z:math_b+1
	nop
	lda a:CPUPROD
	stx a:CPUMUL       ; a0 x b1 (B)
	sta z:math_p+0    ; AA
	ldx z:math_a+1
	lda a:CPUPROD
	stx a:CPUMCAND
	sty a:CPUMUL       ; a1 x b0 (C)
	add z:math_p+1    ; AA + B0
	add a:CPUPROD       ; AA + B0 + C0
	tax
	stx z:math_p+1
	lda z:math_p+0
	rts
.endproc

.a16
.i8
.proc smul16f ; smul16 but returning the middle 16-bit value as A (i.e. 8.8 fixed point multiply)
	; DB = 0
	jsr smul16
	lda z:math_p+1
	rts
.endproc

.a16
.i8
.proc smul32f_16f ; a = 24.8 fixed, b = 8.8 fixed, result in A = 8.8, clobbers: math_a/math_b/math_r
	; DB = 0
	lda z:math_a+0
	sta z:math_p+4
	lda z:math_a+2
	sta z:math_p+6 ; p+4 = a
	lda z:math_b+0
	sta z:math_r+4 ; r+4 = b
	cmp #$8000
	bcs :+
		lda #0
		bra :++
	:
		lda #$FFFF
	:
	sta z:math_r+6 ; sign extended
	; 32-bit multiply from 3 x 16-bit multiply
	jsr umul16     ; a0 x b0 (A)
	lda z:math_p+0
	sta z:math_r+0
	lda z:math_p+2
	sta z:math_r+2 ; r+0 = 00AA
	lda z:math_r+6
	sta z:math_b+0
	jsr mul16t     ; a0 x b1 (B)
	add z:math_r+2
	sta z:math_r+2 ; r+0 = AAAA + BB00
	lda z:math_p+6
	sta z:math_a+0
	lda z:math_r+4
	sta z:math_b+0
	jsr mul16t     ; a1 x b0 (C)
	add z:math_r+2 ; r+0 = AAAA + BB00 + CC00
	sta z:math_p+2
	lda z:math_r+0
	sta z:math_p+0
	lda z:math_p+2 ; result in upper bits
	rts
.endproc

.a16
.i8
.proc smul32ft ; a = 24.8 fixed, b = 16.16 fixed, 16.24 result in math_r, returns 8.8 in A, clobbers math_a/b/p, temp0-13
	; DB = 0
	; sign extend and copy to temp
	lda z:math_a+0
	sta z:temp+0
	lda z:math_a+2
	sta z:temp+2
	stz z:temp+4
	cmp #$8000
	bcc :+
		lda #$FFFF
		sta z:temp+4
	:
	lda z:math_b+0
	sta z:temp+8
	lda z:math_b+2
	sta z:temp+10
	stz z:temp+12
	cmp #$8000
	bcc :+
		lda #$FFFF
		sta z:temp+12
	:
	; 40-bit multiply (temporary result in r)
	jsr umul16 ; a0 x b0 (A)
	lda z:math_p+0
	sta z:math_r+0
	lda z:math_p+2
	sta z:math_r+2
	stz z:math_r+4 ; 0AAAA
	lda z:temp+10
	sta z:math_b
	jsr umul16 ; a0 x b1 (B)
	lda z:math_p+0
	add z:math_r+2
	sta z:math_r+2
	lda z:math_p+2
	adc z:math_r+4
	sta z:math_r+4 ; 0AAAA + BBB00
	lda z:temp+2
	sta z:math_a
	lda z:temp+8
	sta z:math_b
	jsr umul16 ; a1 x b0 (C)
	lda z:math_p+0
	add z:math_r+2
	sta z:math_r+2
	lda z:math_p+2
	adc z:math_r+4 ; 0AAAA + BBB00 + CCC00
	; 3 8x8 multiplies for the top byte
	; A is now temporary r+4
	ldx z:temp+0
	stx a:CPUMCAND
	ldx z:temp+12
	stx a:CPUMUL ; a0 x b2 (D)
	ldx z:temp+2
	add a:CPUPROD      ; 0AAAA + BBB00 + CCC00 + D0000
	stx a:CPUMCAND
	ldx z:temp+10
	stx a:CPUMUL ; a1 x b1 (E)
	ldx z:temp+4
	add a:CPUPROD     ; 0AAAA + BBB00 + CCC00 + D0000 + E0000
	stx a:CPUMCAND
	ldx z:temp+8
	stx a:CPUMUL ; a2 x b0 (F)
	nop
	nop
	add a:CPUPROD     ; 0AAAA + BBB00 + CCC00 + D0000 + E0000 + F0000
	sta z:math_r+4
	lda z:math_r+3 ; return top 16 bits
	rts
.endproc

; 32-bit / 32-bit division, 32 + 32 result
; math_a / math_b = math_p
; math_a % math_b = math_r
; clobbers A/X
.proc udiv32
	; DB = any
	.a16
	.i8
	lda z:math_a+0
	asl
	sta z:math_p+0
	lda z:math_a+2
	rol
	sta z:math_p+2
	stz z:math_r+2 ; A is used temporarily as low word of r
	lda #0
	ldx #32
@loop:
	rol
	rol z:math_r+2
	cmp z:math_b+0
	pha
	lda z:math_r+2
	sbc z:math_b+2
	bcc :+
		sta z:math_r+2
		pla
		sbc z:math_b+0
		sec
		bra :++
	:
		pla
	:
	rol z:math_p+0
	rol z:math_p+2
	dex
	bne @loop
	sta z:math_r+0
	rts
	; Optimization notes:
	;   This routine is very simple and very slow.
	;   We try to do it only a few times per frame, but it's still pretty hefty.
	;   There is likely a way to decompose the operation to use the 16/8 hardware divider,
	;   but I have not yet discovered one.
.endproc

.proc sdiv32 ; 32-bit/32-bit signed division, 32+32 result, math_a / math_b = math_p & math_r, clobbers A/X/Y
	ldy #0 ; y=1 marks an inverted result
	lda z:math_a+2
	bpl :+
		iny
		lda z:math_a+0
		eor #$FFFF
		add #1
		sta z:math_a+0
		lda z:math_a+2
		eor #$FFFF
		adc #0
		sta z:math_a+2
	:
	lda z:math_b+2
	bpl :+
		iny
		lda z:math_b+0
		eor #$FFFF
		add #1
		sta z:math_b+0
		lda z:math_b+2
		eor #$FFFF
		adc #0
		sta z:math_b+2
	:
	jsr udiv32
	cpy #1
	bne :+
		lda z:math_p+0
		eor #$FFFF
		add #1
		sta z:math_p+0
		lda z:math_p+2
		eor #$FFFF
		adc #0
		sta z:math_b+2
	:
	rts
.endproc

; fixed point reciprocal, clobbers A/X/Y/math_a/math_b/math_p/math_r
.if 0
.proc recip16f ; A = fixed point number, result in A
; Used only by calc_det_r
	; DB = any
	sta z:math_b+0
	stz z:math_b+2
	cmp #$8000
	bcs :+
		ldy #0
		bra :++
	:
		lda #$FFFF
		eor z:math_b+0
		inc
		sta z:math_b+0
		ldy #1 ; Y indicates negate at end
	:
	; numerator: 1.0 << 16
	stz z:math_a+0
	lda #(1*256)
	sta z:math_a+2
	jsr udiv32 ; A<<16
	cpy #1
	bne :+
		lda #0
		sub z:math_p+0
		sta z:math_p+0
		lda #0
		sbc z:math_p+2
		sta z:math_p+2
	:
	lda z:math_p+1
	rts
	; Optimization notes:
	;   See udiv32 notes above.
	;   If not using the p+0 byte, this could be done a little faster with a udiv24,
	;   but this demo needs p+0 for all uses.
.endproc
.endif

.a16
.export sincos
.proc sincos ; A = angle 0-255, result in cosa/sina, clobbers A/X
	;.i any
	php
	setxy16
	asl
	tax
	lda f:sincos_table, X
	sta z:cosa
	txa
	add #(192*2) ; sin(x) = cos(x + 3/4 turn)
	and #(256*2)-1
	tax
	lda f:sincos_table, X
	sta z:sina
	plp
	rts
.endproc

sincos_table:
.word $0100,$0100,$0100,$00FF,$00FF,$00FE,$00FD,$00FC,$00FB,$00FA,$00F8,$00F7,$00F5,$00F3,$00F1,$00EF
.word $00ED,$00EA,$00E7,$00E5,$00E2,$00DF,$00DC,$00D8,$00D5,$00D1,$00CE,$00CA,$00C6,$00C2,$00BE,$00B9
.word $00B5,$00B1,$00AC,$00A7,$00A2,$009D,$0098,$0093,$008E,$0089,$0084,$007E,$0079,$0073,$006D,$0068
.word $0062,$005C,$0056,$0050,$004A,$0044,$003E,$0038,$0032,$002C,$0026,$001F,$0019,$0013,$000D,$0006
.word $0000,$FFFA,$FFF3,$FFED,$FFE7,$FFE1,$FFDA,$FFD4,$FFCE,$FFC8,$FFC2,$FFBC,$FFB6,$FFB0,$FFAA,$FFA4
.word $FF9E,$FF98,$FF93,$FF8D,$FF87,$FF82,$FF7C,$FF77,$FF72,$FF6D,$FF68,$FF63,$FF5E,$FF59,$FF54,$FF4F
.word $FF4B,$FF47,$FF42,$FF3E,$FF3A,$FF36,$FF32,$FF2F,$FF2B,$FF28,$FF24,$FF21,$FF1E,$FF1B,$FF19,$FF16
.word $FF13,$FF11,$FF0F,$FF0D,$FF0B,$FF09,$FF08,$FF06,$FF05,$FF04,$FF03,$FF02,$FF01,$FF01,$FF00,$FF00
.word $FF00,$FF00,$FF00,$FF01,$FF01,$FF02,$FF03,$FF04,$FF05,$FF06,$FF08,$FF09,$FF0B,$FF0D,$FF0F,$FF11
.word $FF13,$FF16,$FF19,$FF1B,$FF1E,$FF21,$FF24,$FF28,$FF2B,$FF2F,$FF32,$FF36,$FF3A,$FF3E,$FF42,$FF47
.word $FF4B,$FF4F,$FF54,$FF59,$FF5E,$FF63,$FF68,$FF6D,$FF72,$FF77,$FF7C,$FF82,$FF87,$FF8D,$FF93,$FF98
.word $FF9E,$FFA4,$FFAA,$FFB0,$FFB6,$FFBC,$FFC2,$FFC8,$FFCE,$FFD4,$FFDA,$FFE1,$FFE7,$FFED,$FFF3,$FFFA
.word $0000,$0006,$000D,$0013,$0019,$001F,$0026,$002C,$0032,$0038,$003E,$0044,$004A,$0050,$0056,$005C
.word $0062,$0068,$006D,$0073,$0079,$007E,$0084,$0089,$008E,$0093,$0098,$009D,$00A2,$00A7,$00AC,$00B1
.word $00B5,$00B9,$00BE,$00C2,$00C6,$00CA,$00CE,$00D1,$00D5,$00D8,$00DC,$00DF,$00E2,$00E5,$00E7,$00EA
.word $00ED,$00EF,$00F1,$00F3,$00F5,$00F7,$00F8,$00FA,$00FB,$00FC,$00FD,$00FE,$00FF,$00FF,$0100,$0100
; python generator:
;import math
;vt = [round(256*math.cos(i*math.pi/128)) for i in range(256)]
;for y in range(16):
;    s = ".word "
;    for x in range(16):
;        s += "$%04X" % (vt[x+(y*16)] & 0xFFFF)
;        if x < 15: s += ","
;    print(s)

;
; =============================================================================
; Mode 7 calculations
;

;
; A,B,C,D = M7A,B,C,D "matrix"
; Sx,Sy = screen coordinate (0-255,0-223) "screen"
; Ox,Oy = M7HOFS,M7VOFS "offset"
; Px,Py = M7X,M7Y "pivot"
; Tx,Ty = texel coordinate
; Mx,My = horizontal texel scale, vertical texel scale
;
; Screen to texel (official formula):
;
;   [A B]   [Sx+Ox-Px]   [ Px ]   [ Tx ]
;   [   ] x [        ] + [    ] = [    ]
;   [C D]   [Sy+Oy-Py]   [ Py ]   [ Ty ]
; 
;   Tx = A (Sx + Ox - Px) + B (Sy + Oy - Py) + Px
;   Ty = C (Sx + Ox - Px) + D (Sy + Oy - Py) + Py
;
; Texel to screen:
;
;   Sx = Px - Ox + (D(Tx-Px)-B(Ty-Py)) / (AD-BC)
;   Sy = Py - Oy + (A(Ty-Py)-C(Tx-Px)) / (AD-BC)
;
; Calculating offset when you know where on-screen a texel should appear,
; which is the same as texel-to-screen but with Ox,Oy and Sx,Sy swapped:
;
;   Ox = Px - Sx + (D(Tx-Px)-B(Ty-Py)) / (AD-BC)
;   Oy = Py - Sy + (A(Ty-Py)-C(Tx-Px)) / (AD-BC)
;
; Because we are only using rotation + scale for ABCD, the determinant (AD-BC) is more simply:
;
;   AD - BC = Mx cos * My cos + Mx sin * My sin
;           = (Mx * My)(cos^2 + sin^2)
;           = Mx * My
;

;
; In general in these examples calculating texel_to_screen (and the reciprocal determinant det_r) are time-intensive operations.
; The provided texel_to_screen is very generic, and with precision good enough for most purposes.
; In most practical cases these can be simplified or avoided. For example:
;  - Scale of 1 means det_r=1 and can be skipped entirely.
;  - Fixed or limited scaling could have a constant det_r, or looked up from a small table.
;  - If Px,Py is always mid-screen, Tx-Px,Ty-Py will be low for on-screen sprites.
;    With appropriate culling of distant objects, texel_to_scale can be done at lower precision.
;  - ABCD could be replaced by versions pre-scaled with 1/(AD-BC), avoiding its separate application.
;  - Object positions might be stored in an alternative way (camera-relative, polar coordinates, etc.) that does not need as much transformation.
;

; 1 for higher precision determinant reciprocal (more accurate under scaling)
;   adds about 10 more hardware multiplies to texel_to_screen (11 vs 9 scanlines?)
DETR40 = 1

.if 0
; recalculate det_r = 1 / (AD-BC) = 1 / (Mx * My)
; used by texel_to_screen
.proc calc_det_r
	lda z:scale2+0 ; Mx 8.8f
	sta z:math_a
	lda z:scale2+2 ; My 8.8f
	sta z:math_b
	jsr smul16f ; Mx * My 8.8f
	jsr recip16f
	lda z:math_p+0 ; 1 / (Mx * My) 16.16f
	sta z:det_r+0
	lda z:math_p+2
	sta z:det_r+2
	rts
.endproc

.proc texel_to_screen ; input: texelx,texely output screenx,screeny (requires det_r)
	lda z:texelx
	sub f:mode7_m7x
	pha ; Tx-Px 16u
	sta z:math_a
	lda z:mode7_m7t+4 ; C
	sta z:math_b
	jsr smul16
	lda z:math_p+0
	sta z:temp+0 ; C(Tx-Px) 24.8f
	lda z:math_p+2
	sta z:temp+2
	lda z:texely
	sub f:mode7_m7y
	pha ; Ty-Py 16u
	sta z:math_a
	lda z:mode7_m7t+0 ; A
	sta z:math_b
	jsr smul16
	lda z:math_p+0
	sub z:temp+0 ; A(Ty-Py)-C(Tx-Px) 24.8f
	sta z:math_a+0
	lda z:math_p+2
	sbc z:temp+2
	sta z:math_a+2
	.if ::DETR40
		lda z:det_r+0 ; 16.16f
		sta z:math_b+0
		lda z:det_r+2
		sta z:math_b+2
		jsr smul32ft ; (A(Ty-Py)-C(Tx-Px)) / (AD-BC) 16u
	.else
		lda z:det_r+1 ; 8.8f
		sta z:math_b
		jsr smul32f_16f ; 16u
	.endif
	add f:mode7_m7y ; Py + (A(Ty-Py)-C(Tx-Px)) / (AD-BC)
	sub f:FGScrollYPixels ; Py - Oy + (A(Ty-Py)-C(Tx-Px)) / (AD-BC)
	sta z:screeny
	pla ; Ty-Py 16u
	sta z:math_a
	lda z:mode7_m7t+2 ; B
	sta z:math_b
	jsr smul16
	lda z:math_p+0
	sta z:temp+0 ; B(Ty-Py) 24.8f
	lda z:math_p+2
	sta z:temp+2
	pla ; Tx-Px 16u
	sta z:math_a
	lda z:mode7_m7t+6 ;D
	sta z:math_b
	jsr smul16
	lda z:math_p+0
	sub z:temp+0 ; D(Tx-Px)-B(Ty-Py) 24.8f
	sta z:math_a+0
	lda z:math_p+2
	sbc z:temp+2
	sta z:math_a+2
	.if ::DETR40
		lda z:det_r+0 ; 16.16f
		sta z:math_b+0
		lda z:det_r+2
		sta z:math_b+2
		jsr smul32ft ; (D(Tx-Px)-B(Ty-Py)) / (AD-BC) 16u
	.else
		lda z:det_r+1 ; 8.8f
		sta z:math_b
		jsr smul32f_16f ; 16u
	.endif
	add f:mode7_m7x ; Px + (D(Tx-Px)-B(Ty-Py)) / (AD-BC)
	sub f:FGScrollXPixels ; Px - Ox + (D(Tx-Px)-B(Ty-Py)) / (AD-BC)
	sta z:screenx
	rts
.endproc
.endif

;
; =============================================================================
; Perspective View
;
; Overview:
;   Parameters
;     angle (u8) - determines the direction of view, specified in 256ths of a circle
;     pv_l0 (u8) - the vertical line of output picture where the view begins (horizon), 0 for top of screen
;     pv_l1 (u8) - the vertical line where the view stops (usually 224)
;     pv_s0 (u16) - the horizontal width of the view in texels on the texure map at L0 (256 = 1:1 scale, max < 1024)
;     pv_s1 (u16) - the horizontal width at L1, S1 should be <= S0
;     pv_sh (u16) - the vertical height of the view in texels on the texture map, use 0 for "automatic" (fast), L1-L0 = 1:1 scale
;     pv_interp (u8) - values of 2 or 4 give 2x or 4x vertical interpolation (faster calculation, less accurate), other values disable interpolation
;     pv_wrap (u8) - 1 if pv_texel_to_world coordinates need to wrap
;
; L0 to L1 defines the area of the screen to be covered by the perspective effect.
; S0, S1, and SH are the top, bottom, and height of a trapezoid view frustum, this is an area on the 1024x1024 mode 7 texture map that will be visible in this perspective
;
; Calculation overview:
;   Creating a correct perspective involves a "Z" factor which is proportional to your distance from a point on the plane.
;   The scale of Z is arbitrary as long as the Z for the bottom is the right ratio to the Z at the top.
;   For our perspective, Z at the top is proportional to S0, and Z at the bottom is proportional to S1.
;   Across the vertical space of the picture, Z does not interpolate linearly. However, its reciprocal 1/Z does.
;   We can linearly interpolate this reciprocal 1/Z and then invert it to recover a perspective correct Z for each line.
;     Useful reference: https://en.wikipedia.org/wiki/Texture_mapping#Perspective_correctness
;
;   This calculation is used to generate a set of scalings of the Mode 7 ABCD matrix for each line of the picture, to be updated by HDMA.
;   Setup:
;     ZR0 = 1/S0
;     ZR1 = 1/S1
;     SA = (256 * SH) / (S0 * (L1 - L0)), or SA = 1 if automatic (SH=0)
;   Per-line:
;     zr = lerp(ZR0,ZR1,(line-L0)/(L1-L0))
;     z = 1 / zr
;     a = z *  cos(angle)
;     b = z *  sin(angle) * SA
;     c = z * -sin(angle)
;     d = z *  cos(angle) * SA
;
;   Note that the above is an idealized version of the computation. It might be usable as-is on a CPU with floating point operations,
;   but the actual SNES computation will involved fixed point numbers with carefully chosen scales. More details in the code below.
;
; Configuration and performance:
;   There are 3 versions of the perspective generator which take increasing CPU time:
;     1. angle=0:  No rotation of the view.
;     2. pv_sh=0:  Vertical view scale is locked to horizontal view scale.
;     3. pv_sh!=0: Full calculation, vertical view scale is independent of horizontal.
;   Interpolation can be applied on every 2nd, or 3 of 4 lines:
;     1. pv_interp=0/1: no interpolation:      ~1.2 scanlines per line, ~0.9 if sh=0, ~0.7 if angle=0
;     2. pv_interp=2:   interpolate odd lines, ~0.9 scanlines per line, ~0.7 if sh=0, ~0.6 if angle=0
;     3. pv_interp=4:   interpolate 3/4 lines, ~0.7 scanlines per line, ~0.6 if sh=0, ~0.6 if angle=0
;
; Interpolation can be used to reduce CPU time. 2x tends to look fine,
; though 4x starts to amplify precision errors a little bit unpleasantly
; (i.e. rippling across specific scanlines), especially near the bottom.
;
; With sh=0, it will behave as if sh = (s0 * (l1-l0)) / 256
; This means if s0 has N texels per pixel horizontally, sh will have N texels per pixel vertically.
; The resulting view usually has a fairly natural looking scal. A square appears square, locally speaking.
; Many games without DSP (e.g. F-Zero, Final Fantasy VI) accepted this compromise,
; trading independent vertical scale away for faster computation.

.export pv_tm1, pv_fade_table0, pv_fade_table1

; indirect TM tables to swap BG1 and BG2 (both with OBJ)
pv_tm1: .byte $11
pv_tm2: .byte $12

; indirect COLDATA tables for fade
pv_fade_table0: ; black for top of screen
.byte $E0
pv_fade_table1:
.byte $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E1, $E2, $E3, $E4, $E5, $E6, $E7 ; 16 lines at bottom of sky
.byte $FC, $FA, $F7, $F4, $F1, $EE, $EC, $EA, $E8, $E6, $E5, $E4, $E3, $E2, $E1, $E0 ; 16 lines at top of ground

pv_ztable: ; 12 bit (1<<15)/z lookup
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; 0000
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; 0020
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; 0040
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; 0060
.byte $FF,$FE,$FC,$FA,$F8,$F6,$F5,$F3,$F1,$EF,$ED,$EC,$EA,$E8,$E7,$E5,$E4,$E2,$E0,$DF,$DD,$DC,$DA,$D9,$D8,$D6,$D5,$D3,$D2,$D1,$CF,$CE ; 0080
.byte $CD,$CC,$CA,$C9,$C8,$C7,$C5,$C4,$C3,$C2,$C1,$C0,$BF,$BD,$BC,$BB,$BA,$B9,$B8,$B7,$B6,$B5,$B4,$B3,$B2,$B1,$B0,$AF,$AE,$AD,$AC,$AC ; 00A0
.byte $AB,$AA,$A9,$A8,$A7,$A6,$A5,$A5,$A4,$A3,$A2,$A1,$A1,$A0,$9F,$9E,$9E,$9D,$9C,$9B,$9B,$9A,$99,$98,$98,$97,$96,$96,$95,$94,$94,$93 ; 00C0
.byte $92,$92,$91,$90,$90,$8F,$8E,$8E,$8D,$8D,$8C,$8B,$8B,$8A,$8A,$89,$89,$88,$87,$87,$86,$86,$85,$85,$84,$84,$83,$83,$82,$82,$81,$81 ; 00E0
.byte $80,$80,$7F,$7F,$7E,$7E,$7D,$7D,$7C,$7C,$7B,$7B,$7A,$7A,$79,$79,$78,$78,$78,$77,$77,$76,$76,$75,$75,$75,$74,$74,$73,$73,$73,$72 ; 0100
.byte $72,$71,$71,$71,$70,$70,$6F,$6F,$6F,$6E,$6E,$6E,$6D,$6D,$6D,$6C,$6C,$6B,$6B,$6B,$6A,$6A,$6A,$69,$69,$69,$68,$68,$68,$67,$67,$67 ; 0120
.byte $66,$66,$66,$65,$65,$65,$65,$64,$64,$64,$63,$63,$63,$62,$62,$62,$62,$61,$61,$61,$60,$60,$60,$60,$5F,$5F,$5F,$5E,$5E,$5E,$5E,$5D ; 0140
.byte $5D,$5D,$5D,$5C,$5C,$5C,$5C,$5B,$5B,$5B,$5B,$5A,$5A,$5A,$5A,$59,$59,$59,$59,$58,$58,$58,$58,$57,$57,$57,$57,$56,$56,$56,$56,$56 ; 0160
.byte $55,$55,$55,$55,$54,$54,$54,$54,$54,$53,$53,$53,$53,$53,$52,$52,$52,$52,$52,$51,$51,$51,$51,$51,$50,$50,$50,$50,$50,$4F,$4F,$4F ; 0180
.byte $4F,$4F,$4E,$4E,$4E,$4E,$4E,$4D,$4D,$4D,$4D,$4D,$4D,$4C,$4C,$4C,$4C,$4C,$4C,$4B,$4B,$4B,$4B,$4B,$4A,$4A,$4A,$4A,$4A,$4A,$49,$49 ; 01A0
.byte $49,$49,$49,$49,$48,$48,$48,$48,$48,$48,$48,$47,$47,$47,$47,$47,$47,$46,$46,$46,$46,$46,$46,$46,$45,$45,$45,$45,$45,$45,$45,$44 ; 01C0
.byte $44,$44,$44,$44,$44,$44,$43,$43,$43,$43,$43,$43,$43,$42,$42,$42,$42,$42,$42,$42,$42,$41,$41,$41,$41,$41,$41,$41,$41,$40,$40,$40 ; 01E0
.byte $40,$40,$40,$40,$40,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3D,$3D,$3D,$3D,$3D,$3D,$3D,$3D,$3D,$3C,$3C ; 0200
.byte $3C,$3C,$3C,$3C,$3C,$3C,$3C,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$3A,$39,$39,$39,$39,$39,$39 ; 0220
.byte $39,$39,$39,$39,$38,$38,$38,$38,$38,$38,$38,$38,$38,$38,$38,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$37,$36,$36,$36,$36,$36,$36 ; 0240
.byte $36,$36,$36,$36,$36,$35,$35,$35,$35,$35,$35,$35,$35,$35,$35,$35,$35,$34,$34,$34,$34,$34,$34,$34,$34,$34,$34,$34,$34,$33,$33,$33 ; 0260
.byte $33,$33,$33,$33,$33,$33,$33,$33,$33,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$31,$31,$31,$31,$31,$31,$31,$31,$31,$31 ; 0280
.byte $31,$31,$31,$31,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$30,$2F,$2F,$2F,$2F,$2F,$2F,$2F,$2F,$2F,$2F,$2F,$2F,$2F,$2F ; 02A0
.byte $2F,$2E,$2E,$2E,$2E,$2E,$2E,$2E,$2E,$2E,$2E,$2E,$2E,$2E,$2E,$2E,$2E,$2D,$2D,$2D,$2D,$2D,$2D,$2D,$2D,$2D,$2D,$2D,$2D,$2D,$2D,$2D ; 02C0
.byte $2D,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2B,$2B,$2B,$2B,$2B,$2B,$2B,$2B,$2B,$2B,$2B,$2B,$2B,$2B ; 02E0
.byte $2B,$2B,$2B,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$29,$29,$29,$29,$29,$29,$29,$29,$29,$29 ; 0300
.byte $29,$29,$29,$29,$29,$29,$29,$29,$29,$29,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$28,$27,$27 ; 0320
.byte $27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$27,$26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$26 ; 0340
.byte $26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25 ; 0360
.byte $25,$25,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$23,$23,$23,$23 ; 0380
.byte $23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$23,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22 ; 03A0
.byte $22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$22,$21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$21 ; 03C0
.byte $21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$21,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20 ; 03E0
.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F ; 0400
.byte $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E ; 0420
.byte $1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D ; 0440
.byte $1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1C,$1C ; 0460
.byte $1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C ; 0480
.byte $1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B ; 04A0
.byte $1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A ; 04C0
.byte $1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$1A ; 04E0
.byte $1A,$1A,$1A,$1A,$1A,$1A,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19 ; 0500
.byte $19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$19,$18,$18,$18,$18,$18,$18 ; 0520
.byte $18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18 ; 0540
.byte $18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17 ; 0560
.byte $17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17 ; 0580
.byte $17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$17,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16 ; 05A0
.byte $16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16 ; 05C0
.byte $16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$16,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15 ; 05E0
.byte $15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15 ; 0600
.byte $15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$15,$14 ; 0620
.byte $14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14 ; 0640
.byte $14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14 ; 0660
.byte $14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$14,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13 ; 0680
.byte $13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13 ; 06A0
.byte $13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13 ; 06C0
.byte $13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$13,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12 ; 06E0
.byte $12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12 ; 0700
.byte $12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12 ; 0720
.byte $12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$12,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11 ; 0740
.byte $11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11 ; 0760
.byte $11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11 ; 0780
.byte $11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$11 ; 07A0
.byte $11,$11,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10 ; 07C0
.byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10 ; 07E0
.byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10 ; 0800
.byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10 ; 0820
.byte $10,$10,$10,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F ; 0840
.byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F ; 0860
.byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F ; 0880
.byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F ; 08A0
.byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E ; 08C0
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E ; 08E0
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E ; 0900
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E ; 0920
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E ; 0940
.byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0D,$0D,$0D,$0D ; 0960
.byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D ; 0980
.byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D ; 09A0
.byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D ; 09C0
.byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D ; 09E0
.byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D ; 0A00
.byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0C,$0C ; 0A20
.byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C ; 0A40
.byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C ; 0A60
.byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C ; 0A80
.byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C ; 0AA0
.byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C ; 0AC0
.byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C ; 0AE0
.byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C ; 0B00
.byte $0C,$0C,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B ; 0B20
.byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B ; 0B40
.byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B ; 0B60
.byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B ; 0B80
.byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B ; 0BA0
.byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B ; 0BC0
.byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B ; 0BE0
.byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B ; 0C00
.byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A ; 0C20
.byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A ; 0C40
.byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A ; 0C60
.byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A ; 0C80
.byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A ; 0CA0
.byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A ; 0CC0
.byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A ; 0CE0
.byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A ; 0D00
.byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A ; 0D20
.byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A ; 0D40
.byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$09,$09,$09,$09,$09,$09 ; 0D60
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0D80
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0DA0
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0DC0
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0DE0
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0E00
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0E20
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0E40
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0E60
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0E80
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0EA0
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0EC0
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09 ; 0EE0
.byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08 ; 0F00
.byte $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08 ; 0F20
.byte $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08 ; 0F40
.byte $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08 ; 0F60
.byte $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08 ; 0F80
.byte $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08 ; 0FA0
.byte $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08 ; 0FC0
.byte $08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08 ; 0FE0
; This table is 12-bit (4kb) but could be made smaller at a precision tradeoff.
; An 8-bit implementation was tried using the hardware div: (1<<11) / (zr>>8))
; This looked too imprecise and there was excessive "rippling", especially in the distance.
; I think as low as 10-bits (1kb) is still fairly good, and beyond 12-bit didn't seem to offer any useful additional precision.
; If using a smaller table, compensate by adding lsr(s) to the zr shift in @abcd_pv_line.
;
; python generator:
;def ztable(bits,width=32):
;    s = "pv_ztable: ; %d bit (1<<%d)/z lookup" % (bits,3+bits)
;    for i in range(0,1<<(bits)):
;        v = 0xFF
;        if i > 0:
;            v = min(0xFF,round((1 << (3+bits)) / i))
;        if (i % width) == 0:
;            s += "\n.byte "
;        s += "$%02X" % v
;        if (i % width) != width-1:
;            s += ","
;        else:
;            s += " ; %04X" % (i+1-width)
;    print(s)

.a8
.i16
.export pv_buffer_x
.proc pv_buffer_x ; sets X to 0 or PV_HDMA_STRIDE to select the needed buffer
	lda f:pv_buffer
	beq :+
		ldx #PV_HDMA_STRIDE
		rts
	:
	ldx #0
	rts
.endproc

; rebuild the perspective HDMA tables (only needed if pv input variables or angle change, moving the origin only does not require a rebuild)
.export pv_rebuild
.proc pv_rebuild
	php
	phb
	seta8
	setxy16
	.a8
	.i16
	lda #$7F
	pha
	plb
	; 1. flip the double buffer
	; =========================
	lda f:pv_buffer
	eor #1
	sta f:pv_buffer
	; 2. calculate BG mode table + TM table (pv_hdma_bgm, pv_hdma_tm)
	; ========================================
	jsr pv_buffer_x
	stx z:temp
	ldy z:temp ; X = Y = pv_buffer_x
	lda z:pv_l0
	beq @bgm_end
	dec ; need to set on scanline before L0
	beq @bgm_end
	sta z:temp
	@bgm_mode: ; use nmi_bgmode until L0
		cmp #128
		bcc :+
			lda #128
		:
		sta a:pv_hdma_bgm0+0, X
		sta a:pv_hdma_tm0+0, Y
		eor #$FF
		sec
		adc z:temp
		sta z:temp
		lda #1 ;BG mode
		sta a:pv_hdma_bgm0+1, X
		lda #<pv_tm2
		sta a:pv_hdma_tm0+1, Y
		lda #>pv_tm2
		sta a:pv_hdma_tm0+2, Y
		inx
		inx
		iny
		iny
		iny
		lda z:temp
		bne @bgm_mode
	@bgm_end:
	; set mode 7 at L0
	lda #1
	sta a:pv_hdma_bgm0+0, X
	lda #7
	sta a:pv_hdma_bgm0+1, X
	stz a:pv_hdma_bgm0+2, X ; end of table
	; set BG2 at L0
	lda #1
	sta a:pv_hdma_tm0+0, Y
	lda #<pv_tm1
	sta a:pv_hdma_tm0+1, Y
	lda #>pv_tm1
	sta a:pv_hdma_tm0+2, Y
	lda #0
	sta a:pv_hdma_tm0+3, Y ; end of table
	; 3. calculate TM table and color fade (indirect tables: pv_hdma_tm, pv_hdma_col)
	; =====================================================
	jsr pv_buffer_x
	lda z:pv_l0
	sub #(16+1)
	sta z:temp+0
	stz z:temp+1
	@col_fade: ; black until L0-16
		cmp #128
		bcc :+
			lda #128
		:
		sta a:pv_hdma_col0+0, X
		eor #$FF
		sec
		adc z:temp+0
		sta z:temp+0
		lda #<pv_fade_table0
		sta a:pv_hdma_col0+1, X
		lda #>pv_fade_table0
		sta a:pv_hdma_col0+2, X
		inx
		inx
		inx
		lda z:temp+0
		bne @col_fade
	; 32 lines from fade table
	lda #$80 | 32
	sta a:pv_hdma_col0+0, X
	lda #<pv_fade_table1
	sta a:pv_hdma_col0+1, X
	lda #>pv_fade_table1
	sta a:pv_hdma_col0+2, X
	stz a:pv_hdma_col0+3, X ; end of table
	; 4. calculate ABCD
	; =================
	; Overview of calculation:
	;   Interpolating from S0 to S1 texel scales, with perspective correction,
	;   meaning that for Z proportional to S0/S1, 1/Z interpolates linearly down the screen.
	;   So: 1/Z is interpolated, and used to recover the corrected Z.
	;   Finally, it's multiplied by the rotation matrix, and the vertical values receive a relative scaling.
	;   Various shifts are applied to make the fixed point precision practical.
	;   Acceptable ranges are set by the fixed point precision. These could be adjusted to trade precision for more/less range:
	;   - S0/S1 should be <1024: 2.6 precision goes from 0 to 4x-1 scale
	;   - SH scale (SA) should be less than <2x S0 scale: 1.7 precision goes from 0 to 2x-1 relative scale.
	;     If SH=0 then SA will be forced to 1, allowing more efficient computation but SH will automatically have the same texel scale as S0.
	;   - L0<L1, L1<254 (L1 should probably always be 224)
	;
	; Setup:
	;   ZR0 = (1<<21)/S0              ; 11.21 / 8.8 (S0) = 19.13, truncated to 3.13
	;   ZR1 = (1<<21)/S1
	;   SA = (256 * SH) / (S0 * (L1 - L0)) ; pre-combined with rotation cos/sin at 1.7
	; Per-line:
	;   zr = >lerp(ZR0,ZR1)>>4        ; 3.9 (truncated from 3.13)
	;   z = <((1<<15)/zr)             ; 1.15 / 3.9 = 10.6, clamped to 2.6
	;   a = z *  cos(angle)      >> 5 ; 2.6 * 1.7 (cos>>1)    = 3.13 >> 5 = 8.8
	;   b = z *  sin(angle) * SA >> 5 ; 2.6 * 1.7 (SA*sin>>1) = 3.13 >> 5 = 8.8
	;   c = z * -sin(angle)      >> 5
	;   d = z *  cos(angle) * SA >> 5
	;
	; Setup
	; -----
	seta16
	setxy8
	.a16
	.i8
	phb
	ldy #0
	phy
	plb ; data bank 0 for hardware multiply/divide access
	; calculate ZR0 = (1<<21)/S0
	lda #(1<<21)>>16
	stz z:math_a+0
	sta a:math_a+2
	lda z:pv_s0
	sta a:math_b+0
	stz a:math_b+2
	jsr udiv32
	; result should fit in 16-bits, clamp to 0001-FFFF
	lda a:math_p+2
	beq :+
		lda #$FFFF
		sta a:math_p+0
	:
	lda a:math_p+0
	bne :+
		inc
	:
	sta z:pv_zr
	; calculate ZR1 = (1<<21)/S1
	lda z:pv_s1
	sta a:math_b+0
	jsr udiv32
	lda a:math_p+2
	beq :+
		lda #$FFFF
		sta a:math_p+0
	:
	lda a:math_p+0
	bne :+
		inc
	:
	; calculate (ZR1 - ZR0) / (L1 - L0) for interpolation increment
	ldy #0
	sub z:pv_zr
	bcs :+
		eor #$FFFF
		inc
		iny
	: ; Y = negate
	sta f:$004204 ; WRDIVH:WRDIVL = abs(ZR1 - ZR0)
	seta8
	.a8
	lda z:pv_interp
	cmp #2
	beq :+
	cmp #4
	beq :+
		lda #1 ; otherwise default to 1
	:
	asl
	asl
	sta z:pv_interps+0 ; interps = interp * 4 (stride for increment)
	stz z:pv_interps+1 ; high byte zero for use with 16-bit registers
	lda z:pv_l1
	sub z:pv_l0
	sta f:$004206 ; WRDIVB = (L1 - L0), result in 12 cycles + far load
	sta z:temp+0 ; temp+0 = L1-L0 = scanline count
	ldx z:pv_interp
	cpx #4
	bne :+
		lsr
		lsr
		bra :++
	:
	cpx #2
	bne :+
		lsr
	:
	inc
	sta z:temp+1 ; temp+1 = (L1-L0 / INTERPOLATE)+1 = un-interpolated scanline count + 1
	seta16
	.a16
	; result is ready
	lda f:$004214 ; RDDIVH:RDDIVL = abs(ZR1 - ZR0) / (L1 - L0)
	ldx z:pv_interp
	cpx #4
	bne :+
		asl
		asl
		bra :++
	:
	cpx #2
	bne :+
		asl
	:
	cpy #0
	beq :+ ; negate if needed
		eor #$FFFF
		inc
	:
	sta z:pv_zr_inc ; per-line increment * interpolation factor
	; calculate SA
	lda z:pv_s0
	sta z:math_a
	lda #0
	ldx z:temp+0 ; L1-L0 = scanline count
	txa
	sta z:math_b
	jsr umul16
	lda z:math_p+0
	sta z:math_b+0
	lda z:math_p+2
	sta z:math_b+2 ; b = S0 * (L1-L0)
	stz z:math_a+0
	lda z:pv_sh
	beq :+
		sta z:pv_sh_
		sta z:math_a+2 ; a = (SH * 256) << 8
		jsr udiv32
		lda z:math_p+0
		bra :++
	:
		lda #1<<8 ; SH = 0 means: SA = 1
		lda z:math_b+1
		sta z:pv_sh_ ; computed SH = (S0 * (L1-L0)) / 256
	:
	sta z:math_a ; SA = (SH * 256) / (S0 * (L1-L0))
	; fetch sincos for rotation matrix
	lda #0
	ldx z:angle
	txa
	jsr sincos
	; store m7t matrix (replaced by HDMA but used for other purposes like pv_texel_to_screen, and player movement)
	lda z:cosa
	sta z:mode7_m7t+0 ; A = cos
	sta z:mode7_m7t+6 ; D = cos
	lda z:sina
	sta z:mode7_m7t+2 ; B = sin
	eor #$FFFF
	inc
	sta z:mode7_m7t+4 ; C = -sin
	; check for negations, take abs of cosa/sina
	; want: cos sin -sin cos, keep track of flips to recover from abs by negating afterwards
	ldx #0
	lda z:cosa
	bpl :+
		eor #$FFFF
		inc
		sta z:cosa
		ldx #%1001
	:
	stx z:pv_negate
	lda z:sina
	bmi :+
		lda #%0100
		bra :++
	:
		eor #$FFFF
		inc
		sta z:sina
		lda #%0010
	:
	eor z:pv_negate
	tax
	stx z:pv_negate
	; generate scale (convert 8.8 cosa/sina to 1.7, prescale vertical by SA)
	lda z:cosa
	sta z:math_b
	lsr
	tax
	stx z:pv_scale+0 ; scale A = cos / 2
	lda z:pv_sh
	beq :++
		jsr umul16
		lda z:math_p+1
		lsr
		cmp #$0100
		bcc :+ ; clamp at $FF
			lda #$00FF
		:
		tax
	:
	stx z:pv_scale+3 ; scale D = SA * cos / 2
	lda z:sina
	sta z:math_b
	lsr
	tax
	stx z:pv_scale+2 ; scale C = sin / 2
	lda z:pv_sh
	beq :++
		jsr umul16
		lda z:math_p+1
		lsr
		cmp #$0100
		bcc :+ ; clamp at $FF
			lda #$00FF
		:
		tax
	:
	stx z:pv_scale+1 ; scale B = SA * sin / 2
	plb ; return to RAM data bank
	; generate HDMA indirection buffers
	; ---------------------------------
	seta8
	setxy16
	.a8
	.i16
	jsr pv_buffer_x
	stx z:temp+4 ; pv_buffer_x
	stx z:temp+6 ; pv_buffer_x
	seta16
	.a16
	lda z:pv_l0
	and #$00FF
	beq @abcdi_head_end
	dec ;set on scanline before L0
	beq @abcdi_head_end
	sta z:temp+2 ; L0 
	@abcdi_head:
		cmp #128
		bcc :+
			lda #128
		:
		sta a:pv_hdma_abi0+0, X
		sta a:pv_hdma_cdi0+0, X
		eor #$FF
		sec
		adc z:temp+2
		and #$00FF
		sta z:temp+2
		; these could be skipped, as the values won't display anyway
		lda #.loword(pv_hdma_ab0)
		add z:temp+4
		sta a:pv_hdma_abi0+1, X
		lda #.loword(pv_hdma_cd0)
		add z:temp+4
		sta a:pv_hdma_cdi0+1, X
		; next group
		inx
		inx
		inx
		lda z:temp+2
		bne @abcdi_head
	@abcdi_head_end:
	lda z:temp+0 ; L1-L0 (scanline count)
	and #$00FF
	sta z:temp+2
	@abcdi_body:
		cmp #127 ; repeat mode maxes at 127
		bcc :+
			lda #127
		:
		eor #$80 ; repeat mode
		sta a:pv_hdma_abi0+0, X
		sta a:pv_hdma_cdi0+0, X
		eor #$7F
		sec
		adc z:temp+2
		and #$00FF
		sta z:temp+2
		lda #.loword(pv_hdma_ab0)
		add z:temp+4
		sta a:pv_hdma_abi0+1, X
		lda #.loword(pv_hdma_cd0)
		add z:temp+4
		sta a:pv_hdma_cdi0+1, X
		inx
		inx
		inx
		lda z:temp+2
		beq @abcdi_body_end
		lda z:temp+4 ; if split 127 + rest, add the offset
		add #(127*4)
		sta z:temp+4
		lda z:temp+2
		bra @abcdi_body
	@abcdi_body_end:
	stz a:pv_hdma_abi0+0, X ; end of table
	stz a:pv_hdma_cdi0+0, X
	; Generate scanlines with perspective correction
	; ---------------------------------------------------
	.a16
	.i16
	phb
	setxy8
	.i8
	ldx #0
	phx
	plb ; DB = 0 for absolute writes to hardware
	; reuse math result ZP as long pointers
	ldx #^pv_hdma_ab0
	stx z:math_a+2
	stx z:math_b+2
	stx z:math_p+2
	stx z:math_r+2
	lda #.loword(pv_hdma_ab0+0)
	sta z:math_a+0
	lda #.loword(pv_hdma_ab0+2)
	sta z:math_b+0
	lda #.loword(pv_hdma_cd0+0)
	sta z:math_p+0
	lda #.loword(pv_hdma_cd0+2)
	sta z:math_r+0
	setxy16
	.i16
	; temp+1 =  un-interpolated scanline count
	; temp+6/7 = pv_buffer_x
	ldy z:temp+6
	lda z:temp+1
	and #$00FF
	sta z:temp+2 ; temp+2/3 = countdown
	lda z:pv_negate
	and #$000F
	sta z:temp+4 ; temp+4/5 = negate
	; choose 1 of 3 variations:
	ldx z:pv_scale+1
	bne :+
		lda z:pv_negate
		and #%1001
		bne :+
		; if b=0 (assume c=0) angle is either 0, 180
		; if a/d are not negated, angle=0
		jsr pv_abcd_lines_angle0_ ; only calculates a/d, fills 
		bra :+++
	:
	seta8
	.a8
	txa
	cmp z:pv_scale+2
	bne :+
		lda z:pv_scale+0
		cmp z:pv_scale+3
		bne :+
		; if b==c and a==d then SA=1
		seta16
		.a16
		jsr pv_abcd_lines_sa1_
		bra :++
	:
		seta16
		.a16
		jsr pv_abcd_lines_full_
	:
	plb ; DB = $7E
	; Generate linear interpolation, apply negation
	; ----------------------------------------------------------------
	; ~750 clocks per line
	.a16
	.i16
	lda z:pv_interps
	cmp #(2*4)
	bcc @interpolate_end
		ldx z:temp+6 ; pv_buffer_x
		lda z:temp+1 ; un-interpolated scanline count
		and #$0FF
		beq @interpolate_end
		dec
		beq @interpolate_end
		sta z:temp+2 ; temp+2/3 = countdown
		lda z:pv_interps
		cmp #(4*4)
		beq :+
			jsr pv_interpolate_2x_
			bra :++
		:
			jsr pv_interpolate_4x_
		:
	@interpolate_end:
	seta8
	setxy16
	.a8
	.i16
	; 5. set HDMA tables for next frame
	; =================================
	lda #%111111
	sta z:HDMASTART_Mirror    ; enable HDMA (0,1,2,3,4)
	stz a:mode7_hdma+(0*16)+0 ; bgm: 1 byte transfer
	lda #DMA_INDIRECT
	sta a:mode7_hdma+(1*16)+0 ; tm: 1 byte transfer
	lda #DMA_INDIRECT | DMA_0011
	sta a:mode7_hdma+(2*16)+0 ; AB: 4 byte transfer, indirect
	sta a:mode7_hdma+(3*16)+0 ; CD: 4 byte transfer, indirect
	sta a:mode7_hdma+(5*16)+0
	lda #DMA_INDIRECT
	sta a:mode7_hdma+(4*16)+0 ; col: 1 byte transfer, indirect

	lda #<BGMODE
	sta a:mode7_hdma+(0*16)+1 ; bgm: $2105 BGMODE
	lda #<BLENDMAIN
	sta a:mode7_hdma+(1*16)+1 ; tm: $212C TM
	lda #<M7A
	sta a:mode7_hdma+(2*16)+1
	lda #<M7C
	sta a:mode7_hdma+(3*16)+1
	lda #<COLDATA
	sta a:mode7_hdma+(4*16)+1
	lda #<CGADDR
	sta a:mode7_hdma+(5*16)+1


	lda #$7F
	sta a:mode7_hdma+(0*16)+4 ; bank
	sta a:mode7_hdma+(1*16)+4
	sta a:mode7_hdma+(2*16)+4
	sta a:mode7_hdma+(3*16)+4
	sta a:mode7_hdma+(4*16)+4
	sta a:mode7_hdma+(5*16)+4

	lda #^pv_tm1
	sta a:mode7_hdma+(1*16)+7 ; indirect bank
	lda #$7F
	sta a:mode7_hdma+(2*16)+7 ; M7A M7B
	sta a:mode7_hdma+(3*16)+7 ; M7C M7D
	lda #^pv_fade_table0
	sta a:mode7_hdma+(4*16)+7 ; fog effect
	sta a:mode7_hdma+(5*16)+7 ; BG color
	jsr pv_buffer_x
	stx z:temp
	seta16
	.a16
	lda #.loword(pv_hdma_bgm0)
	add z:temp
	sta a:mode7_hdma+(0*16)+2
	lda #.loword(pv_hdma_tm0)
	add z:temp
	sta a:mode7_hdma+(1*16)+2
	lda #.loword(pv_hdma_abi0)
	add z:temp
	sta a:mode7_hdma+(2*16)+2
	lda #.loword(pv_hdma_cdi0)
	add z:temp
	sta a:mode7_hdma+(3*16)+2
	lda #.loword(pv_hdma_col0)
	add z:temp
	sta a:mode7_hdma+(4*16)+2
	lda #.loword(pv_hdma_bgcolor0)
	add z:temp
	sta a:mode7_hdma+(5*16)+2

	lda z:pv_l0
	dea
	jsr UpdateMode7BGColorHDMA

	; restore register sizes, data bank, and return
	plb
	plp
	rts
.endproc

pv_abcd_lines_full_: ; full perspective with independent horizontal/vertical scale: ~1670 clocks per line
	; temp+2/3 = un-interpolated scanline count
	; temp+4/5 = pv_negate
	; Y = pv_buffer_x
	.a16
	.i16
	; perspective divide: lerp(zr) ; z = (1<15)/(zr>>4)
	; using a table wider than 8 bits instead of the hardware 16/8 divide allows a more precise result
	lda z:pv_zr
	lsr
	lsr
	lsr
	lsr
	tax ; X = 12-bit zr for ztable lookup
	lda f:pv_ztable, X
	sta a:CPUMCAND ; WRMPYA = z (spurious write to $4303)
	nop ; needed because writing $4303 again too fast will cause an erroneous result
	; scale a
	ldx z:pv_scale+0
	stx a:CPUMUL ; WRMPYB = scale a (spurious write to $4304)
		; while waiting for the result: lerp(zr)
		lda z:pv_zr
		add z:pv_zr_inc
		sta z:pv_zr ; zr += linear interpolation increment for next line
	lda a:CPUPROD ; RDMPYH:RDMPYL = z * a
	lsr
	lsr
	lsr
	lsr
	lsr
	; scale b
	ldx z:pv_scale+1
	stx a:CPUMUL
		; negate and store a while waiting
		lsr z:temp+4
		bcc :+
			eor #$FFFF
			inc
		:
		sta [math_a], Y ; pv_hdma_ab0+0
	lda a:CPUPROD
	lsr
	lsr
	lsr
	lsr
	lsr
	; scale c
	ldx z:pv_scale+2
	stx a:CPUMUL
		; store b
		lsr z:temp+4
		bcc :+
			eor #$FFFF
			inc
		:
		sta [math_b], Y ; pv_hdma_ab0+2
	lda a:CPUPROD
	lsr
	lsr
	lsr
	lsr
	lsr
	; scale d
	ldx z:pv_scale+3
	stx a:CPUMUL
		; store c
		lsr z:temp+4
		bcc :+
			eor #$FFFF
			inc
		:
		sta [math_p], Y ; pv_hdma_cd0+0
	lda a:CPUPROD
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr z:temp+4
	bcc :+
		eor #$FFFF
		inc
	:
	sta [math_r], Y ; pv_hdma_cd0+2
	; reload negate and do next
	lda z:pv_negate
	and #$000F
	sta z:temp+4
	tya
	add z:pv_interps
	tay
	dec z:temp+2
	beq :+
	jmp pv_abcd_lines_full_
:
	rts
	; Optimization notes:
	; 1. The negation test (lsr temp+4, bcc) could be eliminated by creating 4 permuations of this routine.
	;    I did not want to complicate this example with 4 copies of the same code, but it would save a few cycles.
	; 2. If the arrays were placed in LoRAM area (<$2000) and this code was placed in a LoROM area of memory
	;    (e.g. banks $80-BF if HiROM), we could use absolute addressing for both the hardware multiplier
	;    and our output array at the same time. Instead I used far addressing for the array and DB=0
	;    so that the arrays can go anywhere in RAM, and the code can run from both LoROM and HiROM.
	; 3. Instead of Z*A at 8x8=16 multiply, could perhaps use 8x16=16 with two hardware multiplies.
	;    This would eliminate the 5 LSRs (i.e. scale would be 1.10 instead of 1.7, with its top 5 bits = 0),
	;    offsetting the added time for a second hardware multiply. (FF6 does something like this.)
	;    Not sure if extra bits of accuracy for A would help in any significant way, though.
	;    I think the 8-bit Z result is the real bottleneck for precision.
	;    Alternatively you could use a 16-bit Z result table (3.10 with its top 5 bits = 0)?
	;    If both were 16-bit precision could definitely improve, at the expense of performance.

pv_abcd_lines_sa1_: ; SA=1 means d=a and c=-b: ~1210 clocks per line
	; temp+2/3 = un-interpolated scanline count
	; temp+4/5 = pv_negate
	; Y = pv_buffer_x
	.a16
	.i16
	lda z:pv_zr
	lsr
	lsr
	lsr
	lsr
	tax
	lda f:pv_ztable, X
	sta a:CPUMCAND
	nop ; delay for next CPUMUL
	; scale a/d
	ldx z:pv_scale+0
	stx a:CPUMUL
		lda z:pv_zr
		add z:pv_zr_inc
		sta z:pv_zr
	lda a:CPUPROD
	lsr
	lsr
	lsr
	lsr
	lsr
	; scale b/c
	ldx z:pv_scale+1
	stx a:CPUMUL
		; negate and store a while waiting
		lsr z:temp+4
		bcc :+
			eor #$FFFF
			inc
		:
		sta [math_a], Y ; pv_hdma_ab0+0
		sta [math_r], Y ; pv_hdma_cd0+2 d=a
	lda a:CPUPROD
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr z:temp+4
	bcc :+
		sta [math_p], Y ; pv_hdma_cd0+0
		eor #$FFFF
		inc
		sta [math_b], Y ; pv_hdma_ab0+2 b=-c
		bra :++
	:
		sta [math_b], Y ; pv_hdma_ab0+2
		eor #$FFFF
		inc
		sta [math_p], Y ; pv_hdma_cd0+0 c=-b
	:
	; next
	lda z:pv_negate
	and #$000F
	sta z:temp+4
	tya
	add z:pv_interps
	tay
	dec z:temp+2
	bne pv_abcd_lines_sa1_
	rts

pv_abcd_lines_angle0_: ; angle 0 means a/d are positive and b=c=0: ~970 clocks per line
	; temp+2/3 = un-interpolated scanline count
	; Y = pv_buffer_x
	.a16
	.i16
	lda z:pv_zr
	lsr
	lsr
	lsr
	lsr
	tax
	lda f:pv_ztable, X
	sta a:CPUMCAND
	nop ; delay for next CPUMUL
	; scale a
	ldx z:pv_scale+0
	stx a:CPUMUL
		lda z:pv_zr
		add z:pv_zr_inc
		sta z:pv_zr
	lda a:CPUPROD
	; scale d
	ldx z:pv_scale+3
	stx a:CPUMUL
		; scale and store a while waiting
		lsr
		lsr
		lsr
		lsr
		lsr
		sta [math_a], Y ; pv_hdma_ab0+0
	lda a:CPUPROD
	lsr
	lsr
	lsr
	lsr
	lsr
	sta [math_r], Y ; pv_hdma_cd0+2
	; b/c = 0
	lda #0
	sta [math_b], Y
	sta [math_p], Y
	; next
	tya
	add z:pv_interps
	tay
	dec z:temp+2
	bne pv_abcd_lines_angle0_
	rts

pv_interpolate_4x_: ; interpolate from every 4th line to every 2nd line
	.a16
	.i16
	; x = pv_buffer_x
	; temp+2/3 = lines to interpolate
	lda temp+2
	pha
	phx
	:
		lda a:pv_hdma_ab0+0,    X
		add a:pv_hdma_ab0+0+16, X
		ror
		sta a:pv_hdma_ab0+0+ 8, X
		lda a:pv_hdma_ab0+2,    X
		add a:pv_hdma_ab0+2+16, X
		ror
		sta a:pv_hdma_ab0+2+ 8, X
		lda a:pv_hdma_cd0+0,    X
		add a:pv_hdma_cd0+0+16, X
		ror
		sta a:pv_hdma_cd0+0+ 8, X
		lda a:pv_hdma_cd0+2,    X
		add a:pv_hdma_cd0+2+16, X
		ror
		sta a:pv_hdma_cd0+2+ 8, X
		txa
		add #16
		tax
		dec z:temp+2
		bne :-
	plx
	pla
	asl
	sta temp+2 ; reload counter for twice as many lines at 2x interpolation
	;jmp pv_interpolate_2x_
    fallthrough pv_interpolate_2x_

pv_interpolate_2x_: ; interpolate from every 2nd line to every line
	.a16
	.i16
	; x = pv_buffer_x
	; temp+2/3 = lines to interpolate
	:
		lda a:pv_hdma_ab0+0,   X
		add a:pv_hdma_ab0+0+8, X
		ror
		sta a:pv_hdma_ab0+0+4, X
		lda a:pv_hdma_ab0+2,   X
		add a:pv_hdma_ab0+2+8, X
		ror
		sta a:pv_hdma_ab0+2+4, X
		lda a:pv_hdma_cd0+0,   X
		add a:pv_hdma_cd0+0+8, X
		ror
		sta a:pv_hdma_cd0+0+4, X
		lda a:pv_hdma_cd0+2,   X
		add a:pv_hdma_cd0+2+8, X
		ror
		sta a:pv_hdma_cd0+2+4, X
		txa
		add #8
		tax
		dec z:temp+2
		bne :-
	rts

.a16
.i8
.export pv_set_origin
.proc pv_set_origin ; Y = scanline to place posx/posy on the centre of
	; Call this only after pv_rebuild has brought the perspective tables up to date.
	; If you don't rotate or change the perspective, this can be reused many times to change the origin without having to use pv_rebuild again.
	sty z:temp+0 ; temp+0 = target scanline
	tya
	sub z:pv_l0
	and #$00FF
	asl
	asl
	sta z:temp+2 ; temp+2/3 = index to line

	seta8
	setxy16

	lda z:pv_l1
	sub z:temp+0
	sta z:math_b ; math_b = scanlines above bottom

	jsr pv_buffer_x ; X = index to pv buffers

	seta16

	txa
	add z:temp+2
	tax ; X = index of target scanline in pv buffers
	lda f:pv_hdma_ab0+2, X
	sta z:math_a ; math_a = b coefficient
	lda f:pv_hdma_cd0+2, X
	pha ; store for a moment
	setxy8
	.i8
	jsr smul16_u8
	add z:M7PosX+1
	sta f:mode7_m7x ; ox = posx + (scanlines * b)
	sub #128
	sta f:FGScrollXPixels ; ox - 128
	pla
	sta z:math_a ; math_a = d coefficient
	jsr smul16_u8
	add z:M7PosY+1
	sta f:mode7_m7y ; oy = posy + (scanlines * d)
	lda z:pv_l1
	and #$00FF
	eor #$FFFF
	sec
	adc f:mode7_m7y
	sta f:FGScrollYPixels ; oy - L1
	; scroll sky to meet L0 and pan with angle
	lda z:angle
	asl
	asl
	eor #$FFFF
	and #$03FF
	sta f:Layer2_ScrollXPixels

	lda z:pv_l0
	eor #$FFFF
	sec
	adc #240
	sta f:Layer2_ScrollYPixels
	rts
.endproc

.a16
.i8
.proc pv_texel_to_screen_generic ; input: texelx,texely output screenx,screeny (pv_rebuild must be up to date)
	php
	setxy8
	; 1. translate to origin-relative position
	lda z:texelx
	sub f:mode7_m7x
	sta z:screenx
	lda z:texely
	sub f:mode7_m7y
	sta z:screeny

	; 2. try wrapping if the distance is larger than half the map
	; Skip
.if 0
	ldx f:pv_wrap
	beq @wrap_end
		lda z:screenx
		bmi @wrap_xm
			cmp #512
			bcc @wrap_x_end
			sub #1024
			sta z:screenx ; try X-1024
			bra @wrap_x_end
		@wrap_xm:
			cmp #.loword(-513)
			bcs @wrap_x_end
			add #1024
			sta z:screenx ; try X+1024
			;bra @wrap_y
		@wrap_x_end:
		lda z:screeny
		bmi @wrap_ym
			cmp #512
			bcc @wrap_end
			sub #1024
			sta z:screeny ; try Y-1024
			bra @wrap_end
		@wrap_ym:
			cmp #.loword(-513)
			bcs @wrap_end
			add #1024
			sta z:screeny ; try Y+1024
			;bra @wrap_end
		;
	@wrap_end:
.endif

	; 3. project into the rotated frustum
	ldx z:pv_scale+1
	bne @rotate
	lda z:pv_negate
	and #%1001
	beq @rotate_end ; if b=0, assume c=0, and if a/d are not negated, angle=0
	@rotate:
		lda z:screenx
		sta z:math_a
		lda z:mode7_m7t+0
		sta z:math_b
		jsr smul16f ; X*A

		pha ; X*A
		lda z:mode7_m7t+2
		sta z:math_b
		jsr smul16f ; X*B

		pha ; X*B, X*A
		lda z:screeny
		sta z:math_a
		lda z:mode7_m7t+6
		sta z:math_b
		jsr smul16 ; Y*D

		pla
		add z:math_p+1
		sta z:screeny ; sy = X*B + Y*D
		lda z:mode7_m7t+4
		sta z:math_b
		jsr smul16 ; Y*C

		pla
		add z:math_p+1
		sta z:screenx ; sx = X*A + Y*C
	@rotate_end:

	; translate Y to move 0 to the top of the screen, rather than the origin at the bottom
	lda z:screeny
	add z:pv_sh_
	sta z:screeny

	; 4. transform Y to scanline
	;
	; Interpolating Y from 0 to SH with perspective correction gives the relationship between Y in frustum-texel-space and scanlines:
	;   t = (scanline - L0) / (L1-L0)
	;   Y = lerp(0/S0,SH/S1,t) / lerp(1/S0,1/S1,t)
	; Inverting this calculation to find scanline from Y:
	;   (scanline - L0) = (Y * S1 * (L1-L0)) / ((S0 * SH) - Y * (S0 - S1))
	;
	; X must be rescaled by a factor of S0-to-S1 / 256, interpolating linearly with Y:
	;   screenx = X / lerp(S0/256,S1/256,Y/SH)
	; This becomes a division by the same factor as with Y:
	;   screenx = (X * SH * 256) / ((S0 * SH) - Y * (S0 - S1))
	;
	lda z:screeny
	bmi @offscreen
	cmp z:pv_sh_
	bcc :+
	@offscreen: ; just return a very large screeny to indicate offscreen
		lda #$5FFF
		sta z:screeny
		plp
		rts
	:
	sta z:math_a
	lda z:pv_s1
	sta z:math_b
	jsr smul16
	lda z:math_p+0
	sta z:math_a+0
	lda z:math_p+2
	sta z:math_a+2 ; Y * S1
	lda z:pv_l1
	sub z:pv_l0
	and #$00FF
	sta z:math_b
	jsr smul32f_16f

	lda z:math_p+0
	sta z:temp+0
	lda z:math_p+2
	sta z:temp+2 ; Y * S1 * (L1-L0)
	lda z:pv_s0
	sta z:math_a
	lda z:pv_sh_
	sta z:math_b
	jsr umul16

	lda z:math_p+0
	sta z:temp+4
	lda z:math_p+2
	sta z:temp+6 ; S0 * SH
	lda z:screeny
	sta z:math_a
	lda z:pv_s0
	sub z:pv_s1
	sta z:math_b
	jsr smul16 ; Y * (S0 - S1)

	lda z:temp+4
	sub z:math_p+0
	sta z:temp+4
	sta z:math_b+0
	lda z:temp+6
	sbc z:math_p+2
	sta z:math_b+2 ; (S0 * SH) - Y * (S0 - S1)
	sta z:temp+6
	lda z:temp+0
	sta z:math_a+0
	lda z:temp+2
	sta z:math_a+2
	jsr sdiv32 ; (Y * S1 * (L1-L0)) / ((S0 * SH) - Y * (S0 - S1))

	lda z:pv_l0
	and #$00FF
	add z:math_p+0
	sta z:screeny ; screeny is now correct


	; screenx
	lda z:pv_sh_
	sta z:math_a
	lda z:screenx
	sta z:math_b
	jsr smul16 ; X * SH

	stz z:math_a
	lda z:math_p+0
	sta z:math_a+1
	ldx z:math_p+2
	stx z:math_a+3 ; X * SH * 256
	lda z:temp+4
	sta z:math_b+0
	lda z:temp+6
	sta z:math_b+2 ; (S0 * SH) - Y * (S0 - S1)
	jsr sdiv32 ; (X * SH * 256) / ((S0 * SH) - Y * (S0 - S1))
	lda z:math_p+0
	add #128
	sta z:screenx
	; NOTE: could probably only do 1 division (1 / the shared denominator) and then 2 multiplies.
	plp
	rts
	; Optimization note:
	;   Should probably do 1 division (1 / the shared denominator) and then 2 multiplies, since udiv32/sdiv32 is so slow,
	;   and overlapped hardware multiplies can probably do it faster? This function could probably be made a lot leaner,
	;   but ultimately if we need to do many of these per frame a more efficient alternative route may be needed.
	;   For example: if we only need to rotate, but don't change other parameters, we could create a lookup table with SH entries,
	;   mapping every Y to a screeny, and providing a scaling factor for every X. (e.g. F-Zero doesn't change perspective during a race.)
.endproc

; .------------------------------------------------------------------
; | Different versions of the perspective routines to use on the ground
; '------------------------------------------------------------------

.export pv_setup_for_ground
.proc pv_setup_for_ground
	temp = 0
	ab_lut_pointer = 2 ;and 3, 4
	php
	phb

	; Work on data structures in bank 7F
	ph2banks mode7_hdma, mode7_hdma
	plb
	plb

	setaxy16

	; Calculate which table to use based on which angle is used
	lda angle
	asl
	tax
	lda f:perspective_m7a_m7b_list,x
	sta ab_lut_pointer

	; Find what bank the table is in
	lda angle
	asl
	asl
	xba
	and #%11
    tax
	lda f:perspective_ab_banks,x
	seta8
	sta ab_lut_pointer+2

	lda f:pv_buffer
	eor #1
	sta f:pv_buffer
	jsr pv_buffer_x

	; Make the HDMA tables that will point to the data
	lda #47
	sta a:pv_hdma_abi0+0,x
	sta a:pv_hdma_cdi0+0,x
	; Skip +1 and +2 because they won't be visible

	; After the first 48 there's 176 scanline left, to fill with the actual perspective data

	; Copy data for 127 scanlines, in repeat mode
	lda #$80+127
	sta a:pv_hdma_abi0+3,x
	sta a:pv_hdma_cdi0+3,x
	; Go for 49 more scanlines. 127+49=176
	lda #$80+49
	sta a:pv_hdma_abi0+6,x
	sta a:pv_hdma_cdi0+6,x
	; Then put the end marker
	stz a:pv_hdma_abi0+9,x
	stz a:pv_hdma_cdi0+9,x

	seta16
	lda ab_lut_pointer
	sta a:pv_hdma_abi0+4,x
	add #127*4
	sta a:pv_hdma_abi0+7,x

	txa
	add #.loword(pv_hdma_cd0)
	sta a:pv_hdma_cdi0+4,x
	add #127*4
	sta a:pv_hdma_cdi0+7,x


	; Derive CD from AB
	; X not needed after this process so it's ok to modify
	ldy #0
DeriveCDFromAB:
	.repeat 8, I
	lda [ab_lut_pointer],y  ; Get A, which is cos(angle)
	iny
	iny
	sta pv_hdma_cd0+2+I*4,x ; D is also cos(angle), so D = A
	lda [ab_lut_pointer],y  ; Get B, which is sin(angle)
	iny
	iny
	eor #$ffff
	ina
	sta pv_hdma_cd0+I*4,x   ; C is -sin(angle), so it can be -B
	.endrep

	txa
	add #4*8
	tax
	cpy #176*4
	bcs :+
		jmp DeriveCDFromAB
	:

	seta8

	; Set up HDMA configuration for next frame
	lda #%111111
	sta z:HDMASTART_Mirror    ; enable HDMA (0,1,2,3,4)
	stz a:mode7_hdma+(0*16)+0 ; bgm: 1 byte transfer
	stz a:mode7_hdma+(1*16)+0 ; tm: 1 byte transfer
	lda #DMA_INDIRECT | DMA_0011
	sta a:mode7_hdma+(2*16)+0 ; AB: 4 byte transfer, indirect
	sta a:mode7_hdma+(3*16)+0 ; CD: 4 byte transfer, indirect
	sta a:mode7_hdma+(5*16)+0
	lda #DMA_INDIRECT
	sta a:mode7_hdma+(4*16)+0 ; col: 1 byte transfer, indirect

	lda #<BGMODE
	sta a:mode7_hdma+(0*16)+1 ; bgm: $2105 BGMODE
	lda #<BLENDMAIN
	sta a:mode7_hdma+(1*16)+1 ; tm: $212C TM
	lda #<M7A
	sta a:mode7_hdma+(2*16)+1
	lda #<M7C
	sta a:mode7_hdma+(3*16)+1
	lda #<COLDATA
	sta a:mode7_hdma+(4*16)+1
	lda #<CGADDR
	sta a:mode7_hdma+(5*16)+1

	; Table banks
	lda #^GroundPerspectiveTM
	sta a:mode7_hdma+(0*16)+4 ; BGMODE
	sta a:mode7_hdma+(1*16)+4 ; BLENDMAIN/TM
	sta a:mode7_hdma+(4*16)+4 ; COLDATA

	; AB and CD use tables in RAM
	lda #^pv_hdma_abi0
	sta a:mode7_hdma+(2*16)+4 ; AB
	sta a:mode7_hdma+(3*16)+4 ; CD
	sta a:mode7_hdma+(5*16)+4 ; BGColor

	; Indirect banks
	lda ab_lut_pointer+2 ; From LUT
	sta a:mode7_hdma+(2*16)+7 ; M7A M7B
	lda #^pv_hdma_cd0    ; Derived from LUT
	sta a:mode7_hdma+(3*16)+7 ; M7C M7D
	lda #^pv_fade_table0
	sta a:mode7_hdma+(4*16)+7 ; fog effect
	sta a:mode7_hdma+(5*16)+7 ; BG color

	lda f:pv_buffer
	beq :+
		seta16
		lda #PV_HDMA_STRIDE
		bra :++
	:
	seta16
	lda #0
:	sta temp

	lda #.loword(GroundPerspectiveBGM)
	sta a:mode7_hdma+(0*16)+2

	lda #.loword(GroundPerspectiveTM)
	sta a:mode7_hdma+(1*16)+2

	lda #.loword(pv_hdma_abi0)
	add temp
	sta a:mode7_hdma+(2*16)+2

	lda #.loword(pv_hdma_cdi0)
	add temp
	sta a:mode7_hdma+(3*16)+2

	lda #.loword(GroundPerspectiveCOL)
	sta a:mode7_hdma+(4*16)+2

	lda #.loword(pv_hdma_bgcolor0)
	add temp
	sta a:mode7_hdma+(5*16)+2

	lda #47
	jsr UpdateMode7BGColorHDMA

    ; The rest of the routine don't do anything for the effect, but do set up variables to be how other code expects them
	setxy8
	lda #0
	ldx z:angle
	txa
	jsr sincos
	; store m7t matrix (replaced by HDMA but used for other purposes like pv_texel_to_screen, and player movement)
	lda z:cosa
	sta z:mode7_m7t+0 ; A = cos
	sta z:mode7_m7t+6 ; D = cos
	lda z:sina
	sta z:mode7_m7t+2 ; B = sin
	eor #$FFFF
	inc
	sta z:mode7_m7t+4 ; C = -sin

	plb
	plp
	rts
.endproc

.a16
.i16
.proc UpdateMode7BGColorHDMA
	pha
	jsr pv_buffer_x

	pla
	sta a:pv_hdma_bgcolor0+0,x
	lda #.loword(SkyColor)
	sta a:pv_hdma_bgcolor0+1,x ; and +2

;	lda #1
;	sta a:pv_hdma_bgcolor0+3,x
;	lda #.loword(GroundColor)
;	sta a:pv_hdma_bgcolor0+4,x ; and +5
;	stz a:pv_hdma_bgcolor0+6,x

	lda #128 + 127
	sta a:pv_hdma_bgcolor0+3,x
	lda #.loword(GroundColor2)
	sta a:pv_hdma_bgcolor0+4,x ; and +5

	lda #128 + 49
	sta a:pv_hdma_bgcolor0+6,x
	lda #.loword(GroundColor2 + 127*4)
	sta a:pv_hdma_bgcolor0+7,x ; and +8

	stz a:pv_hdma_bgcolor0+9,x

	rts

SkyColorValue = RGB(15,23,31)
;GroundColorValue = RGB(43/8,78/8,149/8)

SkyColor:
	.byt 0, 0, <SkyColorValue, >SkyColorValue
;GroundColor:
;	.byt 0, 0, <GroundColorValue, >GroundColorValue

GroundColor2:
; Generated with this Python code:
;def lerp(a, b, t):
;	return (1 - t) * a + t * b
;
;for i in range(176):
;	r = lerp(39,  27, i/176)
;	g = lerp(137, 36, i/176)
;	b = lerp(205, 71, i/176)
;	print(".word 0, RGB(%d,%d,%d)" % (int(r/8),int(g/8),int(b/8)))
.word 0, RGB(4,17,25)
.word 0, RGB(4,17,25)
.word 0, RGB(4,16,25)
.word 0, RGB(4,16,25)
.word 0, RGB(4,16,25)
.word 0, RGB(4,16,25)
.word 0, RGB(4,16,25)
.word 0, RGB(4,16,24)
.word 0, RGB(4,16,24)
.word 0, RGB(4,16,24)
.word 0, RGB(4,16,24)
.word 0, RGB(4,16,24)
.word 0, RGB(4,16,24)
.word 0, RGB(4,16,24)
.word 0, RGB(4,16,24)
.word 0, RGB(4,16,24)
.word 0, RGB(4,15,24)
.word 0, RGB(4,15,24)
.word 0, RGB(4,15,23)
.word 0, RGB(4,15,23)
.word 0, RGB(4,15,23)
.word 0, RGB(4,15,23)
.word 0, RGB(4,15,23)
.word 0, RGB(4,15,23)
.word 0, RGB(4,15,23)
.word 0, RGB(4,15,23)
.word 0, RGB(4,15,23)
.word 0, RGB(4,15,23)
.word 0, RGB(4,15,22)
.word 0, RGB(4,15,22)
.word 0, RGB(4,14,22)
.word 0, RGB(4,14,22)
.word 0, RGB(4,14,22)
.word 0, RGB(4,14,22)
.word 0, RGB(4,14,22)
.word 0, RGB(4,14,22)
.word 0, RGB(4,14,22)
.word 0, RGB(4,14,22)
.word 0, RGB(4,14,22)
.word 0, RGB(4,14,21)
.word 0, RGB(4,14,21)
.word 0, RGB(4,14,21)
.word 0, RGB(4,14,21)
.word 0, RGB(4,14,21)
.word 0, RGB(4,13,21)
.word 0, RGB(4,13,21)
.word 0, RGB(4,13,21)
.word 0, RGB(4,13,21)
.word 0, RGB(4,13,21)
.word 0, RGB(4,13,20)
.word 0, RGB(4,13,20)
.word 0, RGB(4,13,20)
.word 0, RGB(4,13,20)
.word 0, RGB(4,13,20)
.word 0, RGB(4,13,20)
.word 0, RGB(4,13,20)
.word 0, RGB(4,13,20)
.word 0, RGB(4,13,20)
.word 0, RGB(4,12,20)
.word 0, RGB(4,12,20)
.word 0, RGB(4,12,19)
.word 0, RGB(4,12,19)
.word 0, RGB(4,12,19)
.word 0, RGB(4,12,19)
.word 0, RGB(4,12,19)
.word 0, RGB(4,12,19)
.word 0, RGB(4,12,19)
.word 0, RGB(4,12,19)
.word 0, RGB(4,12,19)
.word 0, RGB(4,12,19)
.word 0, RGB(4,12,18)
.word 0, RGB(4,12,18)
.word 0, RGB(4,11,18)
.word 0, RGB(4,11,18)
.word 0, RGB(4,11,18)
.word 0, RGB(4,11,18)
.word 0, RGB(4,11,18)
.word 0, RGB(4,11,18)
.word 0, RGB(4,11,18)
.word 0, RGB(4,11,18)
.word 0, RGB(4,11,18)
.word 0, RGB(4,11,17)
.word 0, RGB(4,11,17)
.word 0, RGB(4,11,17)
.word 0, RGB(4,11,17)
.word 0, RGB(4,11,17)
.word 0, RGB(4,10,17)
.word 0, RGB(4,10,17)
.word 0, RGB(4,10,17)
.word 0, RGB(4,10,17)
.word 0, RGB(4,10,17)
.word 0, RGB(4,10,16)
.word 0, RGB(4,10,16)
.word 0, RGB(4,10,16)
.word 0, RGB(4,10,16)
.word 0, RGB(4,10,16)
.word 0, RGB(4,10,16)
.word 0, RGB(4,10,16)
.word 0, RGB(4,10,16)
.word 0, RGB(4,10,16)
.word 0, RGB(4,9,16)
.word 0, RGB(4,9,16)
.word 0, RGB(4,9,15)
.word 0, RGB(3,9,15)
.word 0, RGB(3,9,15)
.word 0, RGB(3,9,15)
.word 0, RGB(3,9,15)
.word 0, RGB(3,9,15)
.word 0, RGB(3,9,15)
.word 0, RGB(3,9,15)
.word 0, RGB(3,9,15)
.word 0, RGB(3,9,15)
.word 0, RGB(3,9,14)
.word 0, RGB(3,9,14)
.word 0, RGB(3,8,14)
.word 0, RGB(3,8,14)
.word 0, RGB(3,8,14)
.word 0, RGB(3,8,14)
.word 0, RGB(3,8,14)
.word 0, RGB(3,8,14)
.word 0, RGB(3,8,14)
.word 0, RGB(3,8,14)
.word 0, RGB(3,8,14)
.word 0, RGB(3,8,13)
.word 0, RGB(3,8,13)
.word 0, RGB(3,8,13)
.word 0, RGB(3,8,13)
.word 0, RGB(3,8,13)
.word 0, RGB(3,7,13)
.word 0, RGB(3,7,13)
.word 0, RGB(3,7,13)
.word 0, RGB(3,7,13)
.word 0, RGB(3,7,13)
.word 0, RGB(3,7,12)
.word 0, RGB(3,7,12)
.word 0, RGB(3,7,12)
.word 0, RGB(3,7,12)
.word 0, RGB(3,7,12)
.word 0, RGB(3,7,12)
.word 0, RGB(3,7,12)
.word 0, RGB(3,7,12)
.word 0, RGB(3,7,12)
.word 0, RGB(3,6,12)
.word 0, RGB(3,6,12)
.word 0, RGB(3,6,11)
.word 0, RGB(3,6,11)
.word 0, RGB(3,6,11)
.word 0, RGB(3,6,11)
.word 0, RGB(3,6,11)
.word 0, RGB(3,6,11)
.word 0, RGB(3,6,11)
.word 0, RGB(3,6,11)
.word 0, RGB(3,6,11)
.word 0, RGB(3,6,11)
.word 0, RGB(3,6,10)
.word 0, RGB(3,6,10)
.word 0, RGB(3,5,10)
.word 0, RGB(3,5,10)
.word 0, RGB(3,5,10)
.word 0, RGB(3,5,10)
.word 0, RGB(3,5,10)
.word 0, RGB(3,5,10)
.word 0, RGB(3,5,10)
.word 0, RGB(3,5,10)
.word 0, RGB(3,5,10)
.word 0, RGB(3,5,9)
.word 0, RGB(3,5,9)
.word 0, RGB(3,5,9)
.word 0, RGB(3,5,9)
.word 0, RGB(3,5,9)
.word 0, RGB(3,4,9)
.word 0, RGB(3,4,9)
.word 0, RGB(3,4,9)
.word 0, RGB(3,4,9)
.word 0, RGB(3,4,9)
.word 0, RGB(3,4,8)
.endproc

; HDMA tables to use on the ground
.proc GroundPerspectiveTM
	.byt 47, $12
	.byt 1,  $11
	.byt 0
.endproc

.proc GroundPerspectiveBGM
	.byt 47, 1
	.byt 1,  7
	.byt 0
.endproc

.proc GroundPerspectiveCOL
	.byt 48-16-1
	.addr pv_fade_table0
	.byt $80 | 32
	.addr pv_fade_table1
	.byt 0
.endproc


.a16
.i8
.export pv_set_ground_origin
.proc pv_set_ground_origin ; Y = scanline to place posx/posy on the center of
target_scanline = 0
index_to_line   = 2 ; and 3
ab_lut_pointer  = 4 ; and 5, 6
abcd_banks      = 10 ; and 11
	sty target_scanline ; temp+0 = target scanline
	tya
	sub #48 ; l0
	and #$00FF
	asl ;*2
	asl ;*4
	sta index_to_line

	setxy16
	; Calculate which table to use based on which angle is used
	lda angle
	asl
	tax
	lda f:perspective_m7a_m7b_list,x
	add index_to_line
	sta ab_lut_pointer

	; Find what bank the table is in
	lda angle
	asl
	asl
	xba
	and #%11
    tax
	lda f:perspective_ab_banks,x
	seta8
	; Set the bank for the pointer
	sta ab_lut_pointer+2

	lda #224 ;l1
	sub target_scanline
	sta z:math_b ; math_b = scanlines above bottom
	seta16
	lda [ab_lut_pointer] ; Get A, which is the same as D
	pha ; store for a moment
	inc ab_lut_pointer
	inc ab_lut_pointer
	lda [ab_lut_pointer] ; Get B
	sta z:math_a ; math_a = b coefficient
	setxy8
	.i8
	jsr smul16_u8
	add z:M7PosX+1
	sta f:mode7_m7x ; ox = posx + (scanlines * b)
	sub #128
	sta f:FGScrollXPixels ; ox - 128
	pla
	sta z:math_a ; math_a = d coefficient
	jsr smul16_u8
	add z:M7PosY+1
	sta f:mode7_m7y ; oy = posy + (scanlines * d)

	lda #224 ;l1
	eor #$FFFF
	sec
	adc f:mode7_m7y
	sta f:FGScrollYPixels ; oy - L1

	; scroll sky to meet L0 and pan with angle
	lda z:angle
	asl
	asl
	eor #$FFFF
	and #$03FF
	sta f:Layer2_ScrollXPixels

	lda #48 ;l0
	eor #$FFFF
	sec
	adc #240
	sta f:Layer2_ScrollYPixels
	rts
.endproc

.a16
.i8
.export pv_texel_to_screen
.proc pv_texel_to_screen
  .importzp mode7_height
  lda mode7_height
  and #255
  beq :+
  jmp pv_texel_to_screen_generic
:
.endproc
; Fall through

.a16
.i8
.export pv_texel_to_screen_ground
.proc pv_texel_to_screen_ground ; input: texelx,texely output screenx,screeny (pv_rebuild must be up to date)
pv_sh_constant = (384 * (224-48)) / 256 ;(S0 * (L1-L0)) / 256 = 264
s0_constant = 384
s1_constant = 64
l0_constant = 48
l1_constant = 224

temp = 0
	php
	setxy8

	; 1. translate to origin-relative position
	lda z:texelx
	sub f:mode7_m7x
	sta z:screenx
	lda z:texely
	sub f:mode7_m7y
	sta z:screeny
	; 2. try wrapping if the distance is larger than half the map
	; Skip

	; 3. project into the rotated frustum
;	ldx z:pv_scale+1
;	bne @rotate
;	lda z:pv_negate
;	and #%1001
;	beq @rotate_end ; if b=0, assume c=0, and if a/d are not negated, angle=0
	@rotate:
		lda z:screenx
		sta z:math_a
		lda z:mode7_m7t+0
		sta z:math_b
		jsr smul16f ; X*A

		pha ; X*A
		lda z:mode7_m7t+2
		sta z:math_b
		jsr smul16f ; X*B

		pha ; X*B, X*A
		lda z:screeny
		sta z:math_a
		lda z:mode7_m7t+6
		sta z:math_b
		jsr smul16 ; Y*D

		pla
		add z:math_p+1
		sta z:screeny ; sy = X*B + Y*D
		lda z:mode7_m7t+4
		sta z:math_b
		jsr smul16 ; Y*C

		pla
		add z:math_p+1
		sta z:screenx ; sx = X*A + Y*C
	@rotate_end:

	; translate Y to move 0 to the top of the screen, rather than the origin at the bottom
	lda z:screeny
	add #pv_sh_constant
	sta z:screeny

	; 4. transform Y to scanline
	;
	; Interpolating Y from 0 to SH with perspective correction gives the relationship between Y in frustum-texel-space and scanlines:
	;   t = (scanline - L0) / (L1-L0)
	;   Y = lerp(0/S0,SH/S1,t) / lerp(1/S0,1/S1,t)
	; Inverting this calculation to find scanline from Y:
	;   (scanline - L0) = (Y * S1 * (L1-L0)) / ((S0 * SH) - Y * (S0 - S1))
	;
	; X must be rescaled by a factor of S0-to-S1 / 256, interpolating linearly with Y:
	;   screenx = X / lerp(S0/256,S1/256,Y/SH)
	; This becomes a division by the same factor as with Y:
	;   screenx = (X * SH * 256) / ((S0 * SH) - Y * (S0 - S1))
	;
	lda z:screeny
	bmi @offscreen
	cmp #pv_sh_constant
	bcc :+
	@offscreen: ; just return a very large screeny to indicate offscreen
		lda #$5FFF
		sta z:screeny
		plp
		rts
	:
	sta z:math_a
	lda #s1_constant
	sta z:math_b
	jsr smul16
	lda z:math_p+0
	sta z:math_a+0
	lda z:math_p+2
	sta z:math_a+2 ; Y * S1
    lda #l1_constant - l0_constant
	sta z:math_b
	jsr smul32f_16f

	lda z:math_p+0
	sta z:temp+0
	lda z:math_p+2
	sta z:temp+2 ; Y * S1 * (L1-L0)
	lda #s0_constant
	sta z:math_a
	lda #pv_sh_constant
	sta z:math_b
	jsr umul16

	lda z:math_p+0
	sta z:temp+4
	lda z:math_p+2
	sta z:temp+6 ; S0 * SH
	lda z:screeny
	sta z:math_a
    lda #s0_constant - s1_constant
	sta z:math_b
	jsr smul16 ; Y * (S0 - S1)

	lda z:temp+4
	sub z:math_p+0
	sta z:temp+4
	sta z:math_b+0
	lda z:temp+6
	sbc z:math_p+2
	sta z:math_b+2 ; (S0 * SH) - Y * (S0 - S1)
	sta z:temp+6
	lda z:temp+0
	sta z:math_a+0
	lda z:temp+2
	sta z:math_a+2
	jsr sdiv32 ; (Y * S1 * (L1-L0)) / ((S0 * SH) - Y * (S0 - S1))

	lda #l0_constant
	add z:math_p+0
	sta z:screeny ; screeny is now correct
	; screenx
	lda #pv_sh_constant
	sta z:math_a
	lda z:screenx
	sta z:math_b
	jsr smul16 ; X * SH

	stz z:math_a
	lda z:math_p+0
	sta z:math_a+1
	ldx z:math_p+2
	stx z:math_a+3 ; X * SH * 256
	lda z:temp+4
	sta z:math_b+0
	lda z:temp+6
	sta z:math_b+2 ; (S0 * SH) - Y * (S0 - S1)
	jsr sdiv32 ; (X * SH * 256) / ((S0 * SH) - Y * (S0 - S1))

	lda z:math_p+0
	add #128
	sta z:screenx
	; NOTE: could probably only do 1 division (1 / the shared denominator) and then 2 multiplies.
	plp
	rts
	; Optimization note:
	;   Should probably do 1 division (1 / the shared denominator) and then 2 multiplies, since udiv32/sdiv32 is so slow,
	;   and overlapped hardware multiplies can probably do it faster? This function could probably be made a lot leaner,
	;   but ultimately if we need to do many of these per frame a more efficient alternative route may be needed.
	;   For example: if we only need to rotate, but don't change other parameters, we could create a lookup table with SH entries,
	;   mapping every Y to a screeny, and providing a scaling factor for every X. (e.g. F-Zero doesn't change perspective during a race.)
.endproc

