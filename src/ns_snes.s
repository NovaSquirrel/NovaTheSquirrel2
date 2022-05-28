; Only macros; hardware registers are handled in snes.inc
.feature leading_dot_in_identifiers
.macpack generic
.macpack longbranch

; Provide the regular 6502 with INA and DEA
.ifp02
.macro ina
  add #1
.endmacro

.macro dea
  sub #1
.endmacro
.endif

; Loop macro
; Times - Number of times to loop ( may be a memory location )
; Free  - Free memory location to use
.macro .dj_loop Times, Free
  .scope
    DJ_Counter = Free
    lda Times
    sta Free
DJ_Label:
.endmacro
.macro .end_djl
  NextIndex:
    dec DJ_Counter
    jne DJ_Label
  .endscope
.endmacro

; Swap using X
.macro swapx mema, memb
  ldx mema
  lda memb
  stx memb
  sta mema
.endmacro

; Swap using Y
.macro swapy mema, memb
  ldy mema
  lda memb
  sty memb
  sta mema
.endmacro

; Swap using just A + stack
.macro swapa mema, memb
  lda mema
  pha
  lda memb
  sta mema
  pla
  sta memb
.endmacro

; Swap array,x and array,y
.macro swaparray list
  lda list,x
  pha
  lda list,y
  sta list,x
  pla
  sta list,y
.endmacro

; Imitation of z80's djnz opcode.
; Can be on A, X, Y, or a memory location
; Label - Label to jump to
; Reg   - Counter register to use: A,X,Y or memory location
.macro djnz Label, Reg
  .if (.match({Reg}, a))
    dea
  .elseif (.match({Reg}, x))
    dex
  .elseif (.match({Reg}, y))
    dey
  .else
    dec var
  .endif
  bne Label
.endmacro

; Put a nybble in the ROM, big endian I guess?
.macro .nyb InpA, InpB
  .byt ( InpA<<4 ) | InpB
.endmacro

; For making "RTS trick" tables
.macro .raddr This
  .addr .loword(This-1)
.endmacro

; Negate
.macro neg
  .if .asize = 8
    eor #$ff
  .else
    eor #$ffff
  .endif
  ina
.endmacro

; Absolute value
.macro abs
.local @Skip
  bpl @Skip
  neg
@Skip:
.endmacro

; Sign extend, A = 0 if positive, all 1s if negative
.macro sex
.local @Skip
  .if .asize = 8
    ora #$7F
  .else
    ora #$7FFF
  .endif
  bmi @Skip
  lda #0
@Skip:
.endmacro

; 16-bit negate, 8-bit mode
.macro neg16 lo, hi
  sec             ;Ensure carry is set
  lda #0          ;Load constant zero
  sbc lo          ;... subtract the least significant byte
  sta lo          ;... and store the result
  lda #0          ;Load constant zero again
  sbc hi          ;... subtract the most significant byte
  sta hi          ;... and store the result
.endmacro

; 16-bit negate indexed, 8-bit mode
.macro neg16x lo, hi
  sec             ;Ensure carry is set
  lda #0          ;Load constant zero
  sbc lo,x        ;... subtract the least significant byte
  sta lo,x        ;... and store the result
  lda #0          ;Load constant zero again
  sbc hi,x        ;... subtract the most significant byte
  sta hi,x        ;... and store the result
.endmacro

; 16-bit increment, 8-bit mode
.macro inc16 variable
.local @Skip
  inc variable+0
  bne @Skip
  inc variable+1
@Skip:
.endmacro

; 16-bit decrement, 8-bit mode
.macro dec16 variable
.local @Skip
  lda variable+0
  bne @Skip
  dec variable+1
@Skip:
  dec variable+0
.endmacro

.macro pushaxy
  pha
  phx
  phy
.endmacro

.macro pullaxy
  ply
  plx
  pla
.endmacro

; For avoiding a "lda \ adc #0 \ sta"
.macro addcarry to
.local @Skip
  bcc @Skip
  inc to
@Skip:
.endmacro

; Above, but indexed
.macro addcarryx to
.local @Skip
  bcc @Skip
  inc to,x
@Skip:
.endmacro

; For avoiding a "lda \ sbc #0 \ sta"
.macro subcarry to
.local @Skip
  bcs @Skip
  dec to
@Skip:
.endmacro

; Above, but indexed
.macro subcarryx to
.local @Skip
  bcs @Skip
  dec to,x
@Skip:
.endmacro

; Decreases a variable if it's not already zero
.macro countdown counter
.local @Skip
  lda counter
  beq @Skip
    dec counter
@Skip:
.endmacro

; --- Conditional return ---
.macro rtseq
.local @Skip
  bne @Skip
  rts
@Skip:
.endmacro

.macro rtsne
.local @Skip
  beq @Skip
  rts
@Skip:
.endmacro

.macro rtscc
.local @Skip
  bcs @Skip
  rts
@Skip:
.endmacro

.macro rtscs
.local @Skip
  bcc @Skip
  rts
@Skip:
.endmacro

.macro rtspl
.local @Skip
  bmi @Skip
  rts
@Skip:
.endmacro

.macro rtsmi
.local @Skip
  bpl @Skip
  rts
@Skip:
.endmacro

; Splits a byte into nybbles and stores them
.macro unpack lo, hi
  pha
  and #15
  sta lo
  pla
  lsr
  lsr
  lsr
  lsr
  sta hi
.endmacro

; Splits a byte into nybbles and stores them, indexed
.macro unpackx lo, hi
  pha
  and #15
  sta lo,x
  pla
  lsr
  lsr
  lsr
  lsr
  sta hi,x
.endmacro

; Splits a byte into nybbles and stores them, indexed
.macro unpacky lo, hi
  pha
  and #15
  sta lo,y
  pla
  lsr
  lsr
  lsr
  lsr
  sta hi,y
.endmacro

; BIT absolute; skips the next two bytes.
; Be careful they don't form an address that's sensitive to reads
.macro skip2
  .byt $2c
.endmacro

; Arithmetic shift right, 8-bit
.macro asr
  .if .asize = 8
    cmp #$80
    ror
  .else
    cmp #$8000
    ror
  .endif
.endmacro

; Toggles carry
.macro notcarry
  rol
  eor #1
  ror
.endmacro

; Transfer K to B
.macro tkb
  phk
  plb
.endmacro

; Shortcut to typing out .loword() every time
; with how much it's needed in 65816 stuff
.define lw(value) $ffff & (value)

; Efficient arithmetic shift right
.macro asr_n times
  .if .asize = 8
    .if times = 1     ; 3 bytes
      cmp #$80
      ror
    .elseif times = 2 ; 6 bytes
      cmp #$80
      ror
      cmp #$80
      ror
    .else             ; 5+n bytes
      .local positive
      .repeat times
        lsr
      .endrep
      bit #$80 >> times
      beq positive
        ora #<($FF00 >> times)
      positive:
    .endif
  .else
    .if times = 1     ; 4 bytes
      cmp #$8000
      ror
    .elseif times = 2 ; 8 bytes
      cmp #$8000
      ror
      cmp #$8000
      ror
    .else             ; 7+n bytes
      .local positive
      .repeat times
        lsr
      .endrep
      bit #$8000 >> times
      beq positive
        ora #.loword($FFFF0000 >> times)
      positive:
    .endif
  .endif
.endmacro

; Reverse Subtract with Accumulator
; A = memory - A
.macro rsb param, index
  .if .asize = 8
    eor #$ff
  .else
    eor #$ffff
  .endif
  sec
  .if .paramcount = 2
    adc param, index
  .else
    adc param
  .endif
.endmacro

.macro assert_same_banks symbol1, symbol2
  .assert ^symbol1 = ^symbol2, error, .sprintf("%s must be in the same bank as %s", .string(symbol1), .string(symbol2))
.endmacro

.macro bit8 var
  .if .asize = 8
    bit var
  .else
    bit var-1
  .endif
.endmacro

.macro lda8 var
  .if .asize = 8
    lda var
  .else
    lda var
    and #255
  .endif
.endmacro
