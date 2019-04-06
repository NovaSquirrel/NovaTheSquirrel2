;
; S-CPU and S-PPU MMIO port definitions for Super NES
; and useful 65816 macros
;
; Copyright 2014-2015 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;

;
; This header summarizes some of the Super NES MMIO ports.
; For more details, see these web pages:
; http://wiki.superfamicom.org/
; http://problemkaputt.de/fullsnes.htm
;
; Names of MMIO ports in this header file may differ from purported
; official names for two reasons: to avoid the appearance of
; misappropriation, and because sometimes these make more sense.
;

.ifndef SNES_H
.define SNES_H
.p816

; S-PPU configuration ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PPUBRIGHT = $2100
; 76543210
; |   ++++- brightness (F: max)
; +-------- 1: disable rendering
FORCEBLANK = $80

PPURES = $2133
; 76543210
; ||  |||+- Screen interlace
; ||  ||+-- Shrink sprites vertically during interlace
; ||  |+--- 0: show lines 1-224; 1: show lines 1-239
; ||  +---- Show subscreen in left half of each pixel
; ||        (modes 012347; forced on in modes 56)
; |+------- In mode 7, use bit 7 as priority
; +-------- External genlock, intended for SFC Titler. Use 0 on SNES.
INTERLACE    = $01
INTERLACEOBJ = $02
BG_TALL      = $04
SUB_HIRES    = $08
M7_EXTBG     = $40

PPUSTATUS1 = $213E
; 76543210  PPU address generator status
; ||  ++++- PPU1 version (always 1)
; |+------- 1: sprite overflow (>32 on a line) since the last vblank end
; +-------- 1: sliver overflow (>34 on a line) since the last vblank end
; this parallels bit 5 of $2002 on NES

PPUSTATUS2 = $213F
; 76543210  PPU compositor status
; || |++++- PPU2 version (1-3, not counting minor versions of 3)
; || +----- 1: PAL
; |+------- 1: GETXY has happened since last PPUSTATUS2 read
; +-------- Toggles every vblank

; S-PPU sprites ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

OBSEL = $2101
; 76543210
; ||||| ++- Sprite main pattern table (0=$0000, 1=$2000, 2=$4000, 3=$6000)
; |||++---- Alt pattern table offset (0=$1000, 1=$2000, 2=$3000, 3=$4000)
; +++------ 0: 8/16; 1: 8/32; 2: 8/64; 3: 16/64; 4: 32/64; 5: 64/64
;           (all sprites are square and 2D-mapped)
OBSIZE_8_16  = $00
OBSIZE_8_32  = $20
OBSIZE_8_64  = $40
OBSIZE_16_32 = $60
OBSIZE_16_64 = $80
OBSIZE_32_64 = $A0

OAMADDR = $2102  ; 16-bit, 128 sprites followed by high-X/size table
OAMDATA = $2104
OAMDATARD = $2138
; Parallels NES $2003, except apparently word-addressed.
; OAM random access is working here, unlike on NES.
; If bit 15 is set, value at start of frame apparently also
; controls which sprites are in front

; S-PPU background configuration ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

BGMODE = $2105
; 76543210
; |||||+++- 0: 4 planes 2 bpp
; |||||     1: 2 planes 4 bpp, 1 plane 2 bpp
; |||||     2: 2 planes 4 bpp, OPT
; |||||     3: 1 plane 8 bpp, 1 plane 4 bpp
; |||||     4: 1 plane 8 bpp, 1 plane 2 bpp, OPT
; |||||     5: 1 plane 4 bpp, 1 plane 2 bpp, hires
; |||||     6: 1 plane 4 bpp, OPT, hires
; |||||     7: 1 plane rot/scale
; ||||+---- In mode 1, set plane 2 high-prio in front of all others
; |||+----- Plane 0 tile size (0: 8x8, 1: 16x16)
; ||+------ Plane 1 tile size (0: 8x8, 1: 16x16)
; |+------- Plane 2 tile size (0: 8x8, 1: 16x16)
; +-------- Plane 3 tile size (0: 8x8, 1: 16x16)
;           Modes 5 and 6 use 16x8 instead of 8x8
;           Mode 7 always uses 8x8

MOSAIC = $2106
; 76543210
; |||||||+- Apply mosaic to plane 0 (or mode 7 high-prio horizontal)
; ||||||+-- Apply mosaic to plane 1 (or mode 7 high-prio vertical)
; |||||+--- Apply mosaic to plane 2
; ||||+---- Apply mosaic to plane 3
; ++++----- Pixel size minus 1 (0=1x1, 15=16x16)

NTADDR = $2107  ; through $210A
; 76543210
;  ||||||+- Nametable width (0: 1 screen, 1: 2 screens)
;  |||||+-- Nametable height (0: 1 screen, 1: 2 screens)
;  +++++--- Nametable base address in $400 units
; Each nametable in modes 0-6 is 32 rows, each 32 spaces long.
.define NTXY(xc,yc) ((xc)|((yc)<<5))

BGCHRADDR = $210B
; FEDCBA98 76543210
;  ||| |||  ||| +++- Pattern table base address for plane 0
;  ||| |||  +++----- Same for plane 1
;  ||| +++---------- Same for plane 2
;  +++-------------- Same for plane 3

M7SEL = $211A
; 76543210
; ||    ||
; ||    |+- Flip screen horizontally
; ||    +-- Flip screen vertically
; ++------- 0: repeat entire mode 7 plane
;           2: transparent outside; 3: tile $00 repeating outside
M7_HFLIP    = $01
M7_VFLIP    = $02
M7_WRAP     = $00
M7_NOWRAP   = $80
M7_BORDER00 = $C0

; S-PPU scrolling ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

BGSCROLLX = $210D  ; double write low then high (000-3FF m0-6, 000-7FF m7)
BGSCROLLY = $210E  ; similar. reg 210F-2114 are same for other planes
; Hi-res scrolling in modes 5-6 moves by whole (sub+main) pixels in X
; but half scanlines in Y.
; The top visible line is the line below the value written here.
; For example, in 224-line mode, if 12 is written, lines 13 through
; 237 of the background are visible.  This differs from the NES.
;
; Mode 7 uses this value as the center of rotation.  This differs
; from the GBA, which fixes the center of rotation at the top left.

; 211B-2120 control mode 7 matrix; to be documented later

; S-PPU VRAM data port ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PPUCTRL = $2115
; 76543210
; |   ||++- VRAM address increment (1, 32, 128, 128)
; |   ++--- Rotate low bits of address left by 3 (off, 8, 9, or 10)
; +-------- 0: Increment after low data port access; 1: after high
; Corresponds to bit 2 of $2000 on NES
VRAM_DOWN   = $01
VRAM_M7DOWN = $02
INC_DATAHI  = $80

PPUADDR = $2116  ; Word address, not double-write anymore
PPUDATA = $2118
PPUDATAHI = $2119
PPUDATARD = $2139  ; Same dummy read as on NES is needed
PPUDATARDHI = $213A

; S-PPU palette ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CGADDR = $2121
CGDATA = $2122  ; 5-bit BGR, write twice, low byte first
CGDATARD = $213B  ; 5-bit BGR, read twice, low byte first
.define RGB(r,g,b) ((r)|((g)<<5)|((b)<<10))

; S-PPU window ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

BG12WINDOW = $2123
BG34WINDOW = $2124
OBJWINDOW = $2125
; 76543210
; ||||||++- 0: disable window 1 on BG1/BG3/OBJ; 2: enable; 3: enable outside
; ||||++--- 0: disable window 2 on BG1/BG3/OBJ; 2: enable; 3: enable outside
; ||++----- 0: disable window 1 on BG2/BG4; 2: enable; 3: enable outside
; ++------- 0: disable window 2 on BG2/BG4; 2: enable; 3: enable outside

WINDOW1L = $2126
WINDOW1R = $2127
WINDOW2L = $2128
WINDOW2R = $2129

BGWINDOP = $212A   ; Window op is how windows are combined when both
OBJWINDOP = $212B  ; windows 1 and 2 are enabled.
; 76543210
; ||||||++- Window op for plane 0 or sprites (0: or, 1: and, 2: xor, 3: xnor)
; ||||++--- Window op for plane 1 or color window
; ||++----- Window op for plane 2
; ++------- Window op for plane 3

; S-PPU blending (or "color math") ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; The main layer enable reg, corresponding to PPUMASK on the NES,
; is BLENDMAIN.
BLENDMAIN  = $212C  ; Layers enabled for main input of blending
BLENDSUB   = $212D  ; Layers enabled for sub input of blending
WINDOWMAIN = $212E  ; Windows enabled for main input of blending
WINDOWSUB  = $212F  ; Windows enabled for sub input of blending
; 76543210
;    ||||+- plane 0
;    |||+-- plane 1
;    ||+--- plane 2
;    |+---- plane 3
;    +----- sprites
; BLENDMAIN roughly parallels NES $2001 bits 4-3,
; except that turning off both bits doesn't disable rendering.
; (Use PPUBRIGHT for that.)

; PPU1 appears to generate a stream of (main, sub) pairs, which
; PPU2 combines to form output colors.

; Blending parameters not documented yet.  Wait for a future demo.

; When BGMODE is 0-6 (or during vblank in mode 7), a fast 16x8
; signed multiply is available, finishing by the next CPU cycle.
M7MCAND = $211B    ; write low then high
M7MUL = $211C      ; 8-bit factor
M7PRODLO = $2134
M7PRODHI = $2135
M7PRODBANK = $2136

GETXY = $2137  ; read while $4201 D7 is set: populate x and y coords
XCOORD = $213C  ; used with light guns, read twice
YCOORD = $213D  ; also read twice

; SPC700 communication ports ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

APU0 = $2140
APU1 = $2141
APU2 = $2142
APU3 = $2143

; S-CPU interrupt control ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PPUNMI = $4200
; 76543210
; | ||   +- Automatically read controllers in first 4 lines of vblank
; | ++----- 0: No IRQ; 1: IRQs at HTIME;
; |         2: one IRQ at (0, VTIME); 3: one IRQ at (HTIME, VTIME)
; +-------- 1: Enable NMI at start of vblank
VBLANK_NMI = $80
HTIME_IRQ  = $10
VTIME_IRQ  = $20
HVTIME_IRQ = $30
AUTOREAD   = $01

HTIME   = $4207
HTIMEHI = $4208
VTIME   = $4209
VTIMEHI = $420A

NMISTATUS = $4210
; 76543210
; |   ||||
; |   ++++- DMA controller version (1, 2) where v1 has an HDMA glitch
; +-------- 1: Vblank has started since last read (like $2002.d7 on NES)

TIMESTATUS = $4211  ; Acknowledge htime/vtime IRQ
VBLSTATUS = $4212
; 76543210
; ||     +- 0: Controller reading finished; 1: busy
; |+------- In hblank
; +-------- In vblank

ROMSPEED = $420D  ; 0: slow ROM everywhere; 1: fast ROM in banks 80-FF
                  ; (requires 120ns or faster PRG ROM)

; S-CPU controller I/O ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Manual controller reading behaves almost exactly as on Famicom.
; For games using up to 2 standard controllers, these aren't needed,
; as you can enable controller autoreading along with vblank NMIs.
; But for games using (multitap, mouse, etc.), you will need to
; read the extra bits separately after the autoreader finishes.
JOY0 = $4016
JOY1 = $4017

; In addition to the common strobe, each controller port has an
; additional output bit that can be used as, say, a chip select
; for SPI peripherals.
JOYOUT = $4201
; 76543210
; |+------- Controller 1 pin 6 output
; +-------- Controller 2 pin 6 output

; Results of the autoreader
JOY1CUR = $4218    ; Bit 0: used by standard controllers
JOY2CUR = $421A
JOY1B1CUR = $421C  ; Bit 1: used by multitap and a few oddball
JOY2B1CUR = $421E  ; input devices
; FEDCBA98 76543210
; BYSRUDLR AXLRTTTT
; |||||||| ||||++++- controller type (0: controller, 1: mouse)
; |||||||| ||++----- shoulder buttons
; ++-------++------- right face buttons
;   ||++++---------- Control Pad
;   ++-------------- center face buttons
KEY_B      = $8000
KEY_Y      = $4000
KEY_SELECT = $2000
KEY_START  = $1000
KEY_UP     = $0800
KEY_DOWN   = $0400
KEY_LEFT   = $0200
KEY_RIGHT  = $0100
KEY_A      = $0080
KEY_X      = $0040
KEY_L      = $0020
KEY_R      = $0010

; S-CPU multiply and divide ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Multiply unit.  Also good for shifting pixels when drawing
; text in a proportional font.
CPUMCAND = $4202  ; unchanged by multiplications
CPUMUL = $4203    ; write here to fill CPUPROD 8 cycles later
CPUPROD = $4216
CPUPRODHI = $4217

; Divide unit
CPUNUM = $4204
CPUNUMHI = $4205
CPUDEN = $4206    ; write divisor to fill CPUQUOT/CPUREM 16 cycles later
CPUQUOT = $4214
CPUQUOTHI = $4215
CPUREM = CPUPROD
CPUREMHI = CPUPRODHI

; S-CPU DMA ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

COPYSTART = $420B  ; writes of 1 << n start a DMA copy on channel n
HDMASTART = $420C  ; writes of 1 << n start HDMA on channel n
; Don't run a DMA copy while HDMA is enabled, or you might run into
; a defect in revision 1 of the S-CPU that causes crashing.

; There are 8 DMA channels.
; Registers for channels 1-7 start at $4310, $4320, ...
DMAMODE = $4300
; 76543210
; || ||+++- PPU address offset pattern
; || ||     0: 0     1: 01    2: 00    3: 0011  4: 0123  5: 0101
; || ++---- Memcpy only: 0: increment; 1: fixed; 2: decrement
; |+------- HDMA only: 1: Table contains pointers
; +-------- Direction (0: read CPU write PPU; 1: read PPU write CPU)
DMA_LINEAR   = $00
DMA_01       = $01
DMA_00       = $02  ; For HDMA to double write ports; copies can use linear
DMA_0011     = $03  ; For HDMA to scroll positions and mode 7 matrices
DMA_0123     = $04  ; For HDMA to window registers
DMA_0101     = $05  ; Not sure how this would be useful for HDMA
DMA_FORWARD  = $00
DMA_CONST    = $08
DMA_BACKWARD = $10
DMA_INDIRECT = $40
DMA_READPPU  = $80

DMAPPUREG = $4301
DMAADDR = $4302
DMAADDRHI = $4303
DMAADDRBANK = $4304
DMALEN = $4305  ; number of bytes, not number of transfers; 0 means 65536
DMALENHI = $4306

; A future demo that includes HDMA effects would include port definitions.
;HDMAINDBANK = $4307
;HDMATABLELO = $4308
;HDMATABLEHI = $4309
;HDMALINE = $430A

; composite values for use with 16-bit writes to DMAMODE
DMAMODE_PPULOFILL = (<PPUDATA << 8)       | DMA_LINEAR | DMA_CONST
DMAMODE_PPUHIFILL = (<(PPUDATA + 1) << 8) | DMA_LINEAR | DMA_CONST
DMAMODE_PPUFILL   = (<PPUDATA << 8)       | DMA_01     | DMA_CONST
DMAMODE_PPULODATA = (<PPUDATA << 8)       | DMA_LINEAR | DMA_FORWARD
DMAMODE_PPUHIDATA = (<(PPUDATA + 1) << 8) | DMA_LINEAR | DMA_FORWARD
DMAMODE_PPUDATA   = (<PPUDATA << 8)       | DMA_01     | DMA_FORWARD
DMAMODE_CGDATA    = (<CGDATA << 8)        | DMA_00     | DMA_FORWARD
DMAMODE_OAMDATA   = (<OAMDATA << 8)       | DMA_00     | DMA_FORWARD

; FULLSNES NAMES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; These aliases match the names presented in Fullsnes.

; S-PPU write
INIDISP = PPUBRIGHT
OAMADDL = OAMADDR+0
OAMADDH = OAMADDR+1
BG1SC   = NTADDR+0
BG2SC   = NTADDR+1
BG3SC   = NTADDR+2
BG4SC   = NTADDR+3
BG12NBA = BGCHRADDR+0  ; Welcome to...
BG34NBA = BGCHRADDR+1  ; BG34NBA JAM!!!
BG1HOFS = BGSCROLLX+0
BG1VOFS = BGSCROLLY+0
BG2HOFS = BGSCROLLX+2
BG2VOFS = BGSCROLLY+2
BG3HOFS = BGSCROLLX+4
BG3VOFS = BGSCROLLY+4
BG4HOFS = BGSCROLLX+6
BG4VOFS = BGSCROLLY+6
VMAIN   = PPUCTRL
VMADDL  = PPUADDR+0
VMADDH  = PPUADDR+1
VMDATAL = PPUDATA+0
VMDATAH = PPUDATA+1
M7A     = $211B
M7B     = $211C
M7C     = $211D
M7D     = $211E
M7X     = $211F
M7Y     = $2120
CGADD   = CGADDR
W12SEL  = BG12WINDOW
W34SEL  = BG34WINDOW
WOBJSEL = OBJWINDOW
WH0     = WINDOW1L
WH1     = WINDOW1R
WH2     = WINDOW2L
WH3     = WINDOW2R
WBGLOG  = BGWINDOP
WOBJLOG = OBJWINDOP
TM      = BLENDMAIN
TS      = BLENDSUB
TMW     = WINDOWMAIN
TSW     = WINDOWSUB
CGWSEL  = $2130
CGADSUB = $2131
COLDATA = $2132
SETINI  = PPURES

; S-PPU read
MPYL    = M7PRODLO
MPYM    = M7PRODHI
MPYH    = M7PRODBANK
SLHV    = GETXY
RDOAM   = OAMDATARD
RDVRAML = PPUDATARD
RDVRAMH = PPUDATARDHI
RDCGRAM = CGDATARD
OPHCT   = XCOORD
OPVCT   = YCOORD
STAT77  = PPUSTATUS1
STAT78  = PPUSTATUS2

; other B bus devices
APUIO0 = APU0  ; didn't want to use capital O with digit 0
APUIO1 = APU1
APUIO2 = APU2
APUIO3 = APU3
WMDATA = $2180
WMADDL = $2181
WMADDM = $2182
WMADDH = $2183

; S-CPU I/O write
NMITIMEN = $4200
WRIO     = $4201
WRMPYA   = CPUMCAND
WRMPYB   = CPUMUL
WRDIVL   = CPUNUM
WRDIVH   = CPUNUMHI
WRDIVB   = CPUDEN
HTIMEL   = HTIME
HTIMEH   = HTIMEHI
VTIMEL   = VTIME
VTIMEH   = VTIMEHI
MDMAEN   = COPYSTART  ; where I come from MDMA is a drug
HDMAEN   = HDMASTART
MEMSEL   = ROMSPEED

; S-CPU I/O read
RDNMI  = NMISTATUS
TIMEUP = TIMESTATUS
HVBJOY = VBLSTATUS
RDIO   = $4213
RDDIVL = CPUQUOT
RDDIVH = CPUQUOT+1
RDMPYL = CPUPROD
RDMPYH = CPUPROD+1
JOY1L  = JOY1CUR+0
JOY1H  = JOY1CUR+1
JOY2L  = JOY2CUR+0
JOY2H  = JOY2CUR+1
JOY3L  = JOY1B1CUR+0
JOY3H  = JOY1B1CUR+1
JOY4L  = JOY2B1CUR+0
JOY4H  = JOY2B1CUR+1

; MACRO PACK ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Macros to change the accumulator and index width.
; For best results, use .smart which lets the assembler follow
; SEP/REP and generate appropriately wide immediate values.

;;
; Sets the X and Y registers to use 8-bit values.
; The upper bits are treated as cleared.
.macro setxy8
  sep #$10
.endmacro

;;
; Sets the X and Y registers to use 16-bit values.
.macro setxy16
  rep #$10
.endmacro

;;
; Sets the accumulator (A) and memory-only data manipulation
; instructions (such as STZ and ROR) to use 8-bit data.
; The upper 8 bits of A can be swapped in and out with the
; XBA instruction.
.macro seta8
  sep #$20
.endmacro

;;
; Sets the accumulator and memory-only data manipulation
; instructions to use 16-bit data.
.macro seta16
  rep #$20
.endmacro

;;
; Equivalent to seta8 and setxy8.
.macro setaxy8
  sep #$30
.endmacro

;;
; Equivalent to seta16 and setxy16.
.macro setaxy16
  rep #$30
.endmacro

; Macros to push constant values on the stack to be pulled off
; by instructions such as PLB (pull data segment)

;;
; Pushes two constant bytes in the order second, first
; to be pulled in the order first, second.
.macro ph2b first, second
.local first_, second_, arg
first_ = first
second_ = second
arg = (first_ & $FF) | ((second_ & $FF) << 8)
  pea arg
.endmacro

;;
; Pushes the bank byte of two addresses such that
; PLB will pull them in the order first, second.
; One common pattern is
; ph2banks some_addr, *
; plb
; (stuff using some_addr)
; plb
.macro ph2banks first, second
.local first_, second_
first_ = first
second_ = second
  ph2b ^first_, ^second_
.endmacro

.endif
