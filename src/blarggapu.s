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

.import spc_entry, fast_spc_entry, GSS_MusicUploadAddress, SongDirectory
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

.enum GSS_Commands
	NO_OP
	INITIALIZE
	LOAD
	STEREO
	GLOBAL_VOLUME
	CHANNEL_VOLUME
	MUSIC_START
	MUSIC_STOP
	MUSIC_PAUSE
	SFX_PLAY
	STOP_ALL_SOUNDS
.endenum

.a8
.export GSS_SendCommand
.proc GSS_SendCommand
	sta 0
NoWrite:
    lda APU3
    pha
:   lda APU0
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
:   lda APU0
	bne :-

	lda #1   ; Fast load
	sta APU1
	lda #GSS_Commands::LOAD
	sta APU0

	; Wait for SPC to be ready
:	lda APU0
	cmp #69
	bne :-

	; Disable interrupts
	stz PPUNMI
	php
	sei

    ldy #0
    jsr TransferLoop

	; Reenable interrupts
	plp
	lda #VBLANK_NMI|AUTOREAD
	sta PPUNMI

	lda #$80
	sta APU0
:   lda APU0
    bne :-
	rtl
.endproc

.proc TransferLoop
	Pointer = 2
	Length = 0
Upload:
	lda [Pointer],y
	sta APU1
	iny
	lda [Pointer],y
	sta APU2
	iny
	lda #1
	sta APU0
:	lda APU0
	bpl :-

	lda [Pointer],y
	sta APU1
	iny
	lda [Pointer],y
	sta APU2
	iny
	cpy Length
	bcs Exit
	:	lda APU0
		bmi :-
		bra Upload
	Exit:
	rts
.endproc
