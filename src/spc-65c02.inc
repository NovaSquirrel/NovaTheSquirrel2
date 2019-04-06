; Super Nintendo SPC-700 program assembly using ca65 with 65C02 syntax

;.ifndef SPC65_INC ; ca65 still barfs on file second time through with this, ugh
SPC65_INC = 1

.ifndef DEFAULT_ABS
	DEFAULT_ABS = 1
.endif

CASPC_65XX = 1

.include "spc-ca65.inc"

.macro _op_65arith op, val, index
	.if .xmatch (.left (1, {val}), #) && .blank ({index})
		op a, val
	.elseif .xmatch (.left (1, {val}), <)
		.if .xmatch ({index}, x)
			op a, val+x
		.elseif .blank ({index})
			op a, val
		.else
			.assert 0, error, "unsupported addressing mode"
		.endif
	.elseif .xmatch (.left (1, {val}), {(})
		.if .xmatch (.right (1, {val}), {)}) && .xmatch ({index}, y)
			op a, [.mid (1, .tcount ({val})-2, {val})]+y
		.elseif .xmatch ({index}, {x)})
			op a, [.right (.tcount ({val})-1, {val})+x]
		.else
			.assert 0, error, "unsupported addressing mode"
		.endif
	.elseif .xmatch ({index}, x)
		op a, !val+x
	.elseif .xmatch ({index}, y)
		op a, !val+y
	.elseif .blank ({index})
		op a, !val
	.else
		.assert 0, error, "unsupported addressing mode"
	.endif
.endmacro

.macro _op_65arith_spc op, val, index
	; assembler kept barfing on !.blank && !.xmatch && !.xmatch
	.if !(.blank({index}) || .xmatch ({index}, y) || .xmatch ({index}, x) || .xmatch ({index}, {x)}))
		op val, index ; SPC fallback
	.else
		_op_65arith {op}, val, index
	.endif
.endmacro

.macro lda val, index
	_op_65arith mov, val, index
.endmacro

.macro cmp val, index
	_op_65arith_spc {cmp_}, val, index
.endmacro

.macro sbc val, index
	_op_65arith_spc {sbc_}, val, index
.endmacro

.macro adc val, index
	_op_65arith_spc {adc_}, val, index
.endmacro

.macro eor val, index
	_op_65arith_spc {eor_}, val, index
.endmacro

.macro and val, index
	_op_65arith_spc {and_}, val, index
.endmacro

.macro ora val, index
	_op_65arith {or}, val, index
.endmacro

.macro _op_cpxy reg, val
	.if .xmatch (.left (1, {val}), #)
		cmp_ reg, val
	.elseif .xmatch (.left (1, {val}), <)
		cmp_ reg, val
	.else
		cmp_ reg, !val
	.endif
.endmacro

.define cpx _op_cpxy x,
.define cpy _op_cpxy y,

.macro _op_ldxy otherreg, reg, val, index
	.if .xmatch (.left (1, {val}), #) && .blank ({index})
		mov reg, val
	.elseif .xmatch (.left (1, {val}), <)
		.if .xmatch ({index}, otherreg)
			mov reg, val+otherreg
		.else
			mov reg, val index
		.endif
	.elseif .xmatch ({index}, otherreg)
		mov reg, !val+otherreg
	.else
		mov reg, !val index
	.endif
.endmacro

.define ldy _op_ldxy x, y,
.define ldx _op_ldxy y, x,

.macro _op_65rmw op, val, index
	.if .xmatch (.right (1, {val}), x) || .xmatch (.right (1, {val}), y) || .xmatch (.left (1, {val}), [) || .xmatch (.left (1, {val}), !)
		op val index ; SPC fallback (index here just to generate error if it's not blank)
	.elseif .blank ({index}) && (.blank ({val}) || .xmatch ({val}, a))
		op a
	.elseif .xmatch (.left (1, {val}), <)
		.if .xmatch ({index}, x)
			op val+x
		.elseif .blank ({index})
			op val
		.else
			.assert 0, error, "unsupported addressing mode"
		.endif
	.elseif .xmatch ({index}, x)
		op !val+x
	.elseif .blank ({index})
		op !val
	.else
		.assert 0, error, "unsupported addressing mode"
	.endif
.endmacro

.macro lsr val, index
	_op_65rmw {lsr_}, val, index
.endmacro

.macro asl val, index
	_op_65rmw {asl_}, val, index
.endmacro

.macro ror val, index
	_op_65rmw {ror_}, val, index
.endmacro

.macro rol val, index
	_op_65rmw {rol_}, val, index
.endmacro

.macro inc val, index
	_op_65rmw {inc_}, val, index
.endmacro

.macro dec val, index
	_op_65rmw {dec_}, val, index
.endmacro

.macro sta val, index
	.if .xmatch (.left (1, {val}), <)
		.if .xmatch ({index}, x)
			mov val+x, a
		.elseif .blank ({index})
			mov val, a
		.else
			.assert 0, error, "unsupported addressing mode"
		.endif
	.elseif .xmatch (.left (1, {val}), {(})
		.if .xmatch (.right (1, {val}), {)}) && .xmatch ({index}, y)
			mov [.mid (1, .tcount ({val})-2, {val})]+y, a
		.elseif .xmatch ({index}, {x)})
			mov [.right (.tcount ({val})-1, {val})+x], a
		.else
			.assert 0, error, "unsupported addressing mode"
		.endif
	.elseif .xmatch ({index}, x)
		mov !val+x, a
	.elseif .xmatch ({index}, y)
		mov !val+y, a
	.elseif .blank ({index})
		mov !val, a
	.else
		.assert 0, error, "unsupported addressing mode"
	.endif
.endmacro

.macro _op_stxy otherreg, reg, val, index
	.if .xmatch (.left (1, {val}), <)
		.if .xmatch ({index}, otherreg)
			mov val+x, reg
		.elseif .blank ({index})
			mov val, reg
		.else
			.assert 0, error, "unsupported addressing mode"
		.endif
	.elseif .blank ({index})
		mov !val, reg
	.else
		.assert 0, error, "unsupported addressing mode"
	.endif
.endmacro

.define stx _op_stxy y, x,
.define sty _op_stxy x, y,

.macro jmp val
	.if .xmatch (.left (1, {val}), [) || .xmatch (.left (1, {val}), !)
		jmp_ val ; SPC fallback
	.elseif !.xmatch (.left (1, {val}), {(})
		jmp_ !val
	.else
		.assert 0, error, "JMP ($xxxx) not supported"
	.endif
.endmacro

.macro jsr val
	call !val
.endmacro

.define pha push a
.define phx push x
.define phy push y
.define php push psw

.define pla pop a
.define plx pop x
.define ply pop y
.define plp pop psw

.define rts ret
.define rti reti

.define sec setc
.define sev setv
.define sei di

.define clc clrc
.define clv clrv
.define cli ei

.define ina inc_ a
.define inx inc_ x
.define iny inc_ y

.define dea dec_ a
.define dex dec_ x
.define dey dec_ y

.define tax mov x, a
.define tay mov y, a
.define tya mov a, y
.define txa mov a, x
.define txs mov sp, x
.define tsx mov x, sp

;.endif
