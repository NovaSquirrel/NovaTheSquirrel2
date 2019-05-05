; Only macros; hardware registers are handled in snes.inc
.feature leading_dot_in_identifiers
.macpack generic
.macpack longbranch

; Meant to be an easy replacement for .repeat and .endrepeat
; when you're trying to save space. Uses a zeropage memory location
; instead of a register as a loop counter so as not to disturb any
; registers.
; Times - Number of times to loop ( may be a memory location )
; Free  - Free zeropage memory location to use
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

; These use increments (useless)
.macro .ij_loop Times, Free
  .scope
    DJ_Times = Times
    DJ_Counter = Free
    lda #0
    sta Free
DJ_Label:
.endmacro
.macro .end_ijl
  NextIndex:
    inc DJ_Counter
    lda DJ_Counter
    cmp Times
    jne DJ_Label
  .endscope
.endmacro

; swap using X
.macro swapx mema, memb
  ldx mema
  lda memb
  stx memb
  sta mema
.endmacro

; swap using Y
.macro swapy mema, memb
  ldy mema
  lda memb
  sty memb
  sta mema
.endmacro

; swap using just A + stack
.macro swapa mema, memb
  lda mema
  pha
  lda memb
  sta mema
  pla
  sta memb
.endmacro

; swap array,x and array,y
.macro swaparray list
  lda list,x
  pha
  lda list,y
  sta list,x
  pla
  sta list,y
.endmacro

; Imitation of z80's djnz opcode.
; Can be on A, X, Y, or a zeropage memory location
; Label - Label to jump to
; Reg   - Counter register to use: A,X,Y or memory location
.macro djnz Label, Reg
  .if (.match({Reg}, a))
    sub #1
  .elseif (.match({Reg}, x))
    dex
  .elseif (.match({Reg}, y))
    dey
  .else
    dec var
  .endif
  bne Label
.endmacro

.macro .nyb InpA, InpB		; Makes a .byt storing two 4 bit values
	.byt ( InpA<<4 ) | InpB
.endmacro

.macro .raddr This          ; like .addr but for making "RTS trick" tables with
 .addr This-1
.endmacro

.macro neg
  eor #255
  inc a
.endmacro

.macro abs ; absolute value
.local @Skip
  bpl @Skip
  neg
@Skip:
.endmacro

.macro negw
  eor #$ffff
  inc a
.endmacro

.macro absw ; absolute value
.local @Skip
  bpl @Skip
  negw
@Skip:
.endmacro

.macro sex ; sign extend
.local @Skip
  ora #$7F
  bmi @Skip
  lda #0
@Skip:
.endmacro

.macro sexw
.local @Skip
  ora #$7FFF
  bmi @Skip
  lda #0
@Skip:
.endmacro

.macro neg16 lo, hi
  sec             ;Ensure carry is set
  lda #0          ;Load constant zero
  sbc lo          ;... subtract the least significant byte
  sta lo          ;... and store the result
  lda #0          ;Load constant zero again
  sbc hi          ;... subtract the most significant byte
  sta hi          ;... and store the result
.endmacro

.macro neg16x lo, hi
  sec             ;Ensure carry is set
  lda #0          ;Load constant zero
  sbc lo,x        ;... subtract the least significant byte
  sta lo,x        ;... and store the result
  lda #0          ;Load constant zero again
  sbc hi,x        ;... subtract the most significant byte
  sta hi,x        ;... and store the result
.endmacro

.macro inc16 variable
.local @Skip
  inc variable+0
  bne @Skip
  inc variable+1
@Skip:
.endmacro

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

.macro addcarry to
.local @Skip
  bcc @Skip
  inc to
@Skip:
.endmacro

.macro subcarry to
.local @Skip
  bcs @Skip
  dec to
@Skip:
.endmacro

.macro addcarryx to
.local @Skip
  bcc @Skip
  inc to,x
@Skip:
.endmacro

.macro subcarryx to
.local @Skip
  bcs @Skip
  dec to,x
@Skip:
.endmacro

.macro countdown counter
.local @Skip
  lda counter
  beq @Skip
    dec counter
@Skip:
.endmacro

; --- conditional return ---
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

.macro skip2
  .byt $2c ; BIT absolute
.endmacro

.macro asr ; Arithmetic shift left
  cmp #$80
  ror
.endmacro

.macro notcarry ; toggles carry
  rol
  eor #1
  ror
.endmacro

.proc tkb ; transfer K to B
  phk
  plb
.endproc
