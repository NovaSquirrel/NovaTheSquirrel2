;
; Definition of the internal header and vectors at $00FFC0-$00FFFF
; in the Super NES address space.
;

.include "snes.inc"
;.include "global.inc"
.smart
.import resetstub, main, nmi_handler, IRQHandler

; LoROM is mapped to $808000-$FFFFFF in 32K blocks,
; skipping a15 and a23. Most is mirrored down to $008000.
MAPPER_LOROM = $20    ; a15 skipped
; HiROM is mapped to $C00000-$FFFFFF linearly.
; It is mirrored down to $400000, and the second half of
; each 64K bank is mirrored to $008000 and $808000.
MAPPER_HIROM = $21    ; C00000-FFFFFF skipping a22, a23
; ExHiROM is mapped to $C00000-$FFFFFF followed by
; $400000-$7FFFFF.  There are two inaccessible 32K holes
; near the end, and two 32K blocks that are accessible only
; through their mirrors to $3E8000 and $3F8000.
MAPPER_EXHIROM = $25  ; skipping a22, inverting a23

; If ROMSPEED_120NS is turned on, the game will be pressed
; on more expensive "fast ROM" that allows the CPU to run
; at its full 3.6 MHz when accessing ROM at $808000 and up.
ROMSPEED_200NS = $00
ROMSPEED_120NS = $10

; ROM and backup RAM sizes are expressed as
; ceil(log2(size in bytes)) - 10
MEMSIZE_NONE  = $00
MEMSIZE_2KB   = $01
MEMSIZE_4KB   = $02
MEMSIZE_8KB   = $03
MEMSIZE_16KB  = $04
MEMSIZE_32KB  = $05
MEMSIZE_64KB  = $06
MEMSIZE_128KB = $07  ; values from here up are for SRAM
MEMSIZE_256KB = $08  ; values from here down are for ROM
MEMSIZE_512KB = $09  ; Super Mario World
MEMSIZE_1MB   = $0A  ; Mario Paint
MEMSIZE_2MB   = $0B  ; Mega Man X, Super Mario All-Stars, original SF2
MEMSIZE_4MB   = $0C  ; Turbo/Super SF2, all Donkey Kong Country
MEMSIZE_8MB   = $0D  ; ExHiROM only: Tales of Phantasia, SF Alpha 2

REGION_JAPAN = $00
REGION_AMERICA = $01
REGION_PAL = $02

.segment "SNESHEADER"
romname:
  ; The ROM name must be no longer than 21 characters.
  .byte "NOVA THE SQUIRREL 2"
  .assert * - romname <= 21, error, "ROM name too long"
  .if * - romname < 21
    .res romname + 21 - *, $20  ; space padding
  .endif
  .byte MAPPER_HIROM|ROMSPEED_120NS
  .byte $00   ; 00: no extra RAM; 02: RAM with battery
  .byte MEMSIZE_1MB  ; ROM size (08-0C typical)
  .byte MEMSIZE_NONE   ; backup RAM size (01,03,05 typical; Dezaemon has 07)
  .byte REGION_AMERICA
  .byte $00   ; publisher id, or $33 for see 16 bytes before header
  .byte $00   ; ROM revision number
  .word $0000 ; sum of all bytes will be poked here after linking
  .word $0000 ; $FFFF minus above sum will also be poked here
  .res 4  ; unused vectors
  ; clcxce mode vectors
  ; reset unused because reset switches to 6502 mode
  .addr cop_handler, brk_handler, abort_handler
  .addr nmistub, $FFFF, irqstub
  .res 4  ; more unused vectors
  ; 6502 mode vectors
  ; brk unused because 6502 mode uses irq handler and pushes the
  ; X flag clear for /IRQ or set for BRK
  .addr ecop_handler, $FFFF, eabort_handler
  .addr enmi_handler, resetstub, eirq_handler
  
.segment "CODE"

; Jumping out of bank $00 is especially important if you're using
; ROMSPEED_120NS.
nmistub:
  jml nmi_handler

irqstub:
  jml [IRQHandler]

; Unused exception handlers
cop_handler:
brk_handler:
abort_handler:
ecop_handler:
eabort_handler:
enmi_handler:
eirq_handler:
  rti

