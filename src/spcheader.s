;
; This file contains the metadata for an SPC700 save state file, as
; used by Super NES music players for PC.  It is not used at all in
; the .sfc file.
;
.import spc_entry
HAS_TITLE = 1

.segment "SPCHEADER"
spcheaderstart:
  .byte "SNES-SPC700 Sound File Data v0.30", 26, 26
  .if HAS_TITLE
    .byte 26
  .else
    .byte 27
  .endif
  .byte 30  ; format version
  .assert *-spcheaderstart = $25, error, "magic wrong size"

  .addr spc_entry
  .byte 0, 0, 0, 0, $EF  ; A, X, Y, P, S
  .assert *-spcheaderstart = $2C, error, "registers wrong size"

  .if HAS_TITLE
  .res (spcheaderstart + $2E - *)
tracktitle: .byte "Selnow"
  .res (spcheaderstart + $4E - *)
albumtitle: .byte "Pino's LoROM template"
  .res (spcheaderstart + $6E - *)
rippername: .byte "Pino P"
  .res (spcheaderstart + $7E - *)
tracksubtitle: .byte 0
  .res (spcheaderstart + $9E - *)
builddate: .byte 0
  .res (spcheaderstart + $A9 - *)
tracktime_s: .byte "100"
  .res (spcheaderstart + $AC - *)
fadetime_ms: .byte "0"
  .res (spcheaderstart + $B1 - *)
artistname: .byte "Pino P"
  .res (spcheaderstart + $D1 - *)
muted_ch: .byte %00000000
emulator: .byte 0  ; 0=other, 1=zsnes, 2=snes9x
  .endif

.segment "SPCFOOTER"
  .res 128, $00  ; dsp regs

