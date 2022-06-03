; High-level interface to SPC-700 bootloader
; Originally by "blargg" (Shay Green)
; http://wiki.superfamicom.org/snes/show/How+to+Write+to+DSP+Registers+Without+any+SPC-700+Code
;
; 1. Call spc_wait_boot
; 2. To upload data:
;       A. Call spc_begin_upload
;       B. Call spc_upload_byte any number of times
;       C. Go back to A to upload to different addr
; 3. To begin execution, call spc_execute
;
; Have your SPC code jump to $FFC0 to re-run bootloader.
; Be sure to call spc_wait_boot after that.

.include "snes.inc"
.include "global.inc"
.smart
.i16

.segment "CODE"

; Waits for SPC to finish booting. Call before first
; using SPC or after bootrom has been re-run.
; Preserved: X, Y
.proc spc_wait_boot
  ; Clear command port in case it already has $CC at reset
  seta8
  stz APU0
::spc_wait_boot_without_clear:
  ; Wait for the SPC to signal it's ready with APU0=$AA, APU1=$BB
  seta16
  lda #$BBAA
waitBBAA:
  cmp APU0
  bne waitBBAA
  seta8
  rts
.endproc

; Starts upload to SPC addr Y and sets Y to
; 0 for use as index with spc_upload_byte.
; Preserved: X
.proc spc_begin_upload
  seta8
  sty APU2

  ; Tell the SPC to set the start address.  The first value written
  ; to APU0 must be $CC, and each subsequent value must be nonzero
  ; and at least $02 above the index LSB previously written to $00.
  ; Adding $22 always works because APU0 starts at $AA.
  lda APU0
  clc
  adc #$22
  bne @skip  ; ensure nonzero, as zero means start execution
  inc a
@skip:
  sta APU1
  sta APU0

  ; Wait for acknowledgement
@wait:
  cmp APU0
  bne @wait

  ; Initialize index into block
  ldy #0
  rts
.endproc

; Uploads byte A to SPC and increments Y. The low byte of Y
; must not change between calls, as it 
; Preserved: X
.proc spc_upload_byte
  sta APU1

  ; Signal that it's ready
  tya
  sta APU0
  iny

  ; Wait for acknowledgement
@wait:
  cmp APU0
  bne @wait
  rts
.endproc

; Starts executing at SPC addr Y
; Preserved: X, Y
.proc spc_execute
  sty APU2
  stz APU1
  lda APU0
  clc
  adc #$22
  sta APU0

  ; Wait for acknowledgement
@wait:
  cmp APU0
  bne @wait

  ; Specific to this music engine:
  ; There will be a BB left over in APU1 from the IPL - wait for it to go away, which signals the SPC is ready
  seta16
: lda APU0
  bne :-
  seta8
  rts
.endproc

.export spc_write_dsp, spc_boot_apu

; Writes high byte of X to SPC-700 DSP register in low byte of X
.proc spc_write_dsp
  phx
  ; Just do a two-byte upload to $00F2-$00F3, so we
  ; set the DSP address, then write the byte into that.
  ldy #$00F2
  jsr spc_begin_upload
  pla
  jsr spc_upload_byte     ; low byte of X to $F2
  pla
  jsr spc_upload_byte     ; high byte of X to $F3
  rtl
.endproc

.import spc_entry, GSS_MusicUploadAddress, SongDirectory
.import __SPCIMAGE_RUN__, __SPCIMAGE_LOAD__, __SPCIMAGE_SIZE__

.proc spc_boot_apu
	setxy16
	jsr spc_wait_boot

	ldy #__SPCIMAGE_RUN__
	jsr spc_begin_upload
:	tyx
	lda f:__SPCIMAGE_LOAD__,x
	jsr spc_upload_byte
	cpy #__SPCIMAGE_SIZE__
	bne :-
	ldy #spc_entry
	jsr spc_execute
	rtl
.endproc

; ---------------------------------------------------------

.a8
.export GSS_SendCommand, GSS_SendCommandParamX
GSS_SendCommandParamX:
	stx 2
.proc GSS_SendCommand
	sta 0
NoWrite:
	lda APU3
	pha
:	lda APU0
	bne :-
	seta16
	lda 2
	sta APU2
	lda 0
	seta8
	xba
	sta APU1
	xba
	sta APU0

	; Wait for acknowledgement
	pla
:	cmp APU3
	beq :-
	rtl
.endproc

.export GSS_LoadSong
.if 0 ; Normal version
.proc GSS_LoadSong
Pointer = 2
Length  = 0
	setaxy16
	and #$00ff
	asl
	asl
	tax
	lda f:SongDirectory+0,x
	sta Pointer
	lda f:SongDirectory+2,x
	sta Length
	seta8
	lda #^SongDirectory
	sta Pointer+2

	; Wait for SPC to be ready
:	lda APU0
	bne :-

	.import GSS_MusicUploadAddress
	lda #GSS_Commands::LOAD
	sta APU0

	setxy16
	jsr spc_wait_boot_without_clear

	ldy #GSS_MusicUploadAddress
	jsr spc_begin_upload
:	lda [Pointer],y
	jsr spc_upload_byte
	cpy Length
	bne :-
	ldy #spc_entry
	jsr spc_execute
	rtl
.endproc
.endif

.if 1 ;FAST version
.proc GSS_LoadSong
	; Adapted from https://github.com/Optiroc/libSFX/blob/master/include/CPU/SMP.s
	Pointer   = LevelBlockPtr
	PageCount = TempVal
	StopAtX   = <M7PRODLO
	phb

; -------------------------------------------
; Fetch from the song directory first
; -------------------------------------------
	setaxy16
	and #$00ff
	asl
	asl
	tax
	lda f:SongDirectory+0,x ; Pointer
	sta Pointer
	lda f:SongDirectory+2,x ; Length
	xba
	bit #$ff00 ; If it's not an even multiple of 256, round up
	beq :+
		ina
	:
	sta f:PageCount
	seta8
	lda #^SongDirectory
	pha
	plb

	; Disable interrupts
	stz PPUNMI
	php
	sei

; -------------------------------------------
; Copy transfer routine to RAM and patch it
; -------------------------------------------
	seta16
	ldx #0
:	lda f:TransferRoutine,x
	sta 0,x
	inx
	inx
	cpx #TransferRoutineSize
	bcc :-
	lda Pointer
	sta z:TransferByte1+1
	clc
	adc #$40
	sta z:TransferByte2+1
	adc #$40
	sta z:TransferByte3+1
	adc #$40
	sta z:TransferByte4+1

	; ---

	lda #$2100 ; Allow direct page access to APU0-APU3
	tcd

	seta8
	setxy16

	; Wait for SPC700 to be free for a new command
:	lda <APU0+0
	bne :-

	; Put the compare value in the PPU multiplier result
	lda #$3f
	sta <M7MCAND
	lda f:PageCount
	sta <APU3
	sta <M7MCAND

	lda #1     ; Multiply by 1
	sta <M7MUL

	lda #GSS_Commands::FAST_LOAD
	sta <APU0

	; Wait for SPC700 to signal it's ready for fast transfer
:	bit <APU2+0 ; Silence "Suspicious address expression"
	bpl :-

; -------------------------------------------
; Do the actual transfer now that it's ready
; -------------------------------------------
	ldx #$003f ; Index (through the file)
Page:
	ldy #$003f ; Index (through the page)
Quad:
	jmp 0
ReturnFromTransfer:
	tya

	; Wait for SPC700 to signal it's ready
:	cmp <APU2+0 ; Silence "Suspicious address expression"
	bne :-
	dex
	dey
	bpl Quad

	; Move file index forward through the file
	seta16_clc
	txa
	adc #$0140
	tax
	seta8
	cpx StopAtX
	bne Page

	; Reenable interrupts
	plp
	lda #VBLANK_NMI|AUTOREAD
	sta PPUNMI

	; Set direct page back to zero; restore data bank
	pea 0
	pld
	plb
	rtl

; -------------------------------------------
; Routine that gets copied to RAM and patched
; -------------------------------------------
TransferRoutine:
.org 0
TransferByte1:
	lda $abcd,x
	sta <APU0
TransferByte2:
	lda $abcd,x
	sta <APU1
TransferByte3:
	lda $abcd,x
	sta <APU2
TransferByte4:
	lda $abcd,x
	sta <APU3
	jmp ReturnFromTransfer
.reloc
TransferRoutineSize = * - TransferRoutine
.endproc
.endif
