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

.segment "CODE2"

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

.import spc_entry
.import __SPCIMAGE_RUN__, __SPCIMAGE_LOAD__, __SPCIMAGE_SIZE__

.proc spc_boot_apu
  jsr spc_wait_boot

  ; Upload sample to SPC at $200
  ldy #__SPCIMAGE_RUN__
  jsr spc_begin_upload
:
  tyx
  lda f:__SPCIMAGE_LOAD__,x
  jsr spc_upload_byte
  cpy #__SPCIMAGE_SIZE__
  bne :-
  ldy #spc_entry
  jsr spc_execute
  rtl
.endproc

