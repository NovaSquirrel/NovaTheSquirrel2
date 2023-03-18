; Super Princess Engine
; Copyright (C) 2019-2020 NovaSquirrel
;
; This program is free software: you can redistribute it and/or
; modify it under the terms of the GNU General Public License as
; published by the Free Software Foundation; either version 3 of the
; License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
.include "snes.inc"
.include "global.inc"
.smart
.import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight

.code

; Sets LevelBlockPtr to the start of a given column in the level, then reads a specific row
; input: A (column), Y (row)
; output: LevelBlockPtr is set, also A = block at column,row
; Verify that LevelBlockPtr+2 is #^LevelBuf
.a16
.proc GetLevelColumnPtr
  ; Multiply by 32 (level height) and then once more for 16-bit values
  and #255
  bit VerticalLevelFlag-1 ; Check high bit
  bmi :+
  asl ; * 2
  asl ; * 4
  asl ; * 8
  asl ; * 16
  asl ; * 32
  asl ; * 64
  sta LevelBlockPtr

  lda [LevelBlockPtr],y
  rtl

: ; For vertical levels, a column is 512 bytes instead
  xba ; * 256
  asl ; * 512
  sta LevelBlockPtr

  lda [LevelBlockPtr],y
  rtl
.endproc

; Sets LevelBlockPtr to point to a specific coordinate in the level
; input: A (X position in 12.4 format), Y (Y position in 12.4 format)
; output: LevelBlockPtr is set, also A = block at column,row
; Verify that LevelBlockPtr+2 is #^LevelBuf
.a16
.i16
.proc GetLevelPtrXY
  ; Maybe alternatively branch on VerticalLevelFlag,
  ; but an indirect jump is 5 cycles and that's hard to beat
  jmp (GetLevelPtrXY_Ptr)
.endproc

.export GetLevelPtrXY_Horizontal
.proc GetLevelPtrXY_Horizontal
  ; Save the coordinates for later access
;  sta BlockRealX
;  sty BlockRealY

  ; X position * 64
  lsr
  lsr
  and #%0011111111000000
  sta LevelBlockPtr
  ; 00xxxxxxxx000000

  ; Y position
  tya
  xba
  asl
  and #63
  tsb LevelBlockPtr
  ; 00xxxxxxxxyyyyy0

  lda [LevelBlockPtr]
  rtl
.endproc

.export GetLevelPtrXY_Vertical
.proc GetLevelPtrXY_Vertical
  ; X position * 512
  asl
  and #%0011111000000000
  sta LevelBlockPtr
  ; 00xxxxx000000000

  ; Y position
  tya
  xba
  asl
  and #511
  tsb LevelBlockPtr
  ; 00xxxxxyyyyyyyy0

  lda [LevelBlockPtr]
  rtl
.endproc

; Get BlockFlag for the block ID in the accumulator
.a16
.i16
.proc GetBlockFlag
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  rtl
.endproc

; Wait for a Vblank using WAI instead of a busy loop
.proc WaitVblank
  php
  seta8
loop1:
  bit VBLSTATUS  ; Wait for leaving previous vblank
  bmi loop1
loop2:
  wai
  bit VBLSTATUS  ; Wait for start of this vblank
  bpl loop2
  plp
  rtl
.endproc


; Changes a block in the level immediately and queues a PPU update.
; input: A (new block), LevelBlockPtr (block to change)
; locals: BlockTemp
.a16
.i16
.proc ChangeBlock
Temp = BlockTemp
; Could reserve a second variable to avoid calling GetBlockX twice
  phx
  phy
  php
  setaxy16
  sta [LevelBlockPtr] ; Make the change in the level buffer itself

  ; Find a free index in the block update queue
  ldy #(BLOCK_UPDATE_COUNT-1)*2
FindIndex:
  ldx BlockUpdateAddressTop,y ; Test for zero (exact value not used)
  beq Found
  dey                      ; Next index
  dey
  bpl FindIndex            ; If you run out of slots, don't do the update now
  ; Instead try to do it later
  ldy #1
  sty BlockTemp
  jsl DelayChangeBlock ; Takes A and LevelBlockPtr just like ChangeBlock
  jmp Exit
Found:
  ; From this point on in the routine, Y = free update queue index

  ; Save block number in X specifically, for 24-bit Absolute Indexed
  tax
  ; Now the accumulator is free to do other things

  ; Use the second routine if it's on the second foreground layer
  bit LevelBlockPtr
  jvs ChangeBlockFG2
  ; -----------------------------------

  ; First, make sure the block is actually onscreen (Horizontally)
  jsl GetBlockX
  seta8
  sta Temp ; Store column so it can be compared against

  lda ScrollX+1
  sub #1
  bcc @FineLeft
  cmp Temp
  bcc @FineLeft
  jmp Exit
@FineLeft:

  lda ScrollX+1
  add #16+1
  bcs @FineRight
  cmp Temp
  bcs @FineRight
  jmp Exit
@FineRight:
  seta16

  ; -----------------------------------

  ; Second, make sure the block is actually onscreen (Vertically)
  jsl GetBlockY
  seta8
  sta Temp ; Store row so it can be compared against

  lda ScrollY+1
  sub #1
  bcc @FineUp
  cmp Temp
  bcc @FineUp
  jmp Exit
@FineUp:

  lda ScrollY+1
  add #14+1
  bcs @FineDown
  cmp Temp
  bcs @FineDown
  jmp Exit
@FineDown:
  seta16

  ; -----------------------------------

  ; Copy the block appearance into the update buffer
  lda f:BlockTopLeft,x
  sta BlockUpdateDataTL,y
  lda f:BlockTopRight,x
  sta BlockUpdateDataTR,y
  lda f:BlockBottomLeft,x
  sta BlockUpdateDataBL,y
  lda f:BlockBottomRight,x
  sta BlockUpdateDataBR,y

  ; Now calculate the PPU address
  ; LevelBlockPtr is 00xxxxxxxxyyyyy0 (for horizontal levels)
  ; Needs to become  0....pyyyyyxxxxx
  lda Temp ; still GetBlockY's result
  asl
  and #%11110 ; Grab Y & 15
  asl
  asl
  asl
  asl
  asl
  ora #ForegroundBG
  sta BlockUpdateAddressTop,y

CalculateRestOfAddress:
  ; Add in X
  jsl GetBlockX
  pha
  and #15
  asl
  ora BlockUpdateAddressTop,y
  sta BlockUpdateAddressTop,y

  ; Choose second screen if needed
  pla
  and #16
  beq :+
    lda BlockUpdateAddressTop,y
    ora #2048>>1
    sta BlockUpdateAddressTop,y
  :

  ; Precalculate the bottom row
  lda BlockUpdateAddressTop,y
  add #(32*2)>>1
  sta BlockUpdateAddressBottom,y

  ; Restore registers
Exit:
  plp
  ply
  plx
  rtl
.endproc

; Continuation of ChangeBlock for the second foreground layer
.a16
.i16
.proc ChangeBlockFG2
Temp = ChangeBlock::Temp
Exit = ChangeBlock::Exit
  ; First, make sure the block is actually onscreen (Horizontally)
  lda LevelBlockPtr ; Get level column
  asl
  asl
  xba
  seta8
  sta Temp ; Store column so it can be compared against

  jmp InRange
  lda ScrollX+1
  add FG2OffsetX+1
  sub #1
  bcc @FineLeft
  cmp Temp
  bcc @FineLeft
  jmp Exit
@FineLeft:

  lda ScrollX+1
  add FG2OffsetX+1
  add #16+1
  bcs @FineRight
  cmp Temp
  bcs @FineRight
  jmp Exit
@FineRight:
  seta16

  ; -----------------------------------

  ; Second, make sure the block is actually onscreen (Vertically)
  lda LevelBlockPtr ; Get level row
  lsr
  and #31
  seta8
  sta Temp ; Store row so it can be compared against

  lda ScrollY+1
  add FG2OffsetY+1
  sub #1
  bcc @FineUp
  cmp Temp
  bcc @FineUp
  jmp Exit
@FineUp:

  lda ScrollY+1
  add FG2OffsetY+1
  add #14+1
  bcs @FineDown
  cmp Temp
  bcs @FineDown
  jmp Exit
@FineDown:
InRange:
  seta16

  ; -----------------------------------

  ; Copy the block appearance into the update buffer
  lda f:BlockTopLeft,x
  sta BlockUpdateDataTL,y
  lda f:BlockTopRight,x
  sta BlockUpdateDataTR,y
  lda f:BlockBottomLeft,x
  sta BlockUpdateDataBL,y
  lda f:BlockBottomRight,x
  sta BlockUpdateDataBR,y

  ; Now calculate the PPU address
  ; LevelBlockPtr is 00xxxxxxxxyyyyy0 (for horizontal levels)
  ; Needs to become  0....pyyyyyxxxxx
  jsl GetBlockY
  asl
  and #%11110 ; Grab Y & 15
  asl
  asl
  asl
  asl
  asl
  ora SecondFGTilemapPointer
  sta BlockUpdateAddressTop,y
  jmp ChangeBlock::CalculateRestOfAddress
.endproc

; Changes a block, in the future!
; input: A (new block), LevelBlockPtr (block to change), BlockTemp (Time amount)
.a16
.i16
.proc DelayChangeBlock
  phx
  phy

  ; Find an unused slot
  ldx #(MaxDelayedBlockEdits-1)*2
DelayedBlockLoop:
  ldy DelayedBlockEditTime,x ; Load Y to set flags only
  beq Found                  ; Found an empty slot!
  dex
  dex
  bpl DelayedBlockLoop
  bra Exit ; Fail

Found:
  sta DelayedBlockEditType,x

  lda BlockTemp
  sta DelayedBlockEditTime,x

  lda LevelBlockPtr
  sta DelayedBlockEditAddr,x

Exit:
  ply
  plx
  rtl
.endproc


; Gets the column number of LevelBlockPtr
.a16
.proc GetBlockX
  jmp (GetBlockX_Ptr)
.endproc

.a16
.export GetBlockX_Horizontal
.proc GetBlockX_Horizontal
  lda LevelBlockPtr ; Get level column
  asl
  asl
  xba
  and #255
  rtl
.endproc

.a16
.export GetBlockX_Vertical
.proc GetBlockX_Vertical
  lda LevelBlockPtr ; Get level column
  lsr
  xba
  and #31
  rtl
.endproc

; Set accumulator to X coordinate of LevelBlockPtr
.a16
.proc GetBlockXCoord
  jmp (GetBlockXCoord_Ptr)
.endproc

.a16
.export GetBlockXCoord_Horizontal
.proc GetBlockXCoord_Horizontal
  lda LevelBlockPtr ; Get level column
  bit #$4000
  bne SecondLayer
  asl
  asl
  and #$ff00
  rtl

SecondLayer:
  and #$3fff
  asl
  asl
  and #$ff00
  sub FG2OffsetX
  rtl
.endproc

.a16
.export GetBlockXCoord_Vertical
.proc GetBlockXCoord_Vertical
  ; 00xxxxxyyyyyyyy0
  lda LevelBlockPtr ; Get level column
  bit #$4000
  bne SecondLayer
  lsr
  and #%11111 * 256
  rtl

SecondLayer:
  lsr
  and #%11111 * 256
  sub FG2OffsetX
  rtl
.endproc

; Get the row number of LevelBlockPtr
.a16
.proc GetBlockY
  jmp (GetBlockY_Ptr)
.endproc

.a16
.export GetBlockY_Horizontal
.proc GetBlockY_Horizontal
  lda LevelBlockPtr ; Get level row
  lsr
  and #31
  rtl
.endproc

.a16
.export GetBlockY_Vertical
.proc GetBlockY_Vertical
  lda LevelBlockPtr ; Get level row
  lsr
  and #255
  rtl
.endproc

; Set accumulator to Y coordinate of LevelBlockPtr
.a16
.proc GetBlockYCoord
  jmp (GetBlockYCoord_Ptr)
.endproc

.a16
.export GetBlockYCoord_Horizontal
.proc GetBlockYCoord_Horizontal
  lda LevelBlockPtr ; Get level row
  bit #$4000
  bne SecondLayer
  lsr
  and #31
  xba
  rtl

SecondLayer:
  lsr
  and #31
  xba
  sub FG2OffsetY
  rtl
.endproc

.a16
.export GetBlockYCoord_Vertical
.proc GetBlockYCoord_Vertical
  ; 00xxxxxyyyyyyyy0
  lda LevelBlockPtr ; Get level row
  bit #$4000
  bne SecondLayer
  lsr
  and #255
  xba
  rtl

SecondLayer:
  lsr
  and #255
  xba
  sub FG2OffsetY
  rtl
.endproc

; Random number generator
; From http://wiki.nesdev.com/w/index.php/Random_number_generator/Linear_feedback_shift_register_(advanced)#Overlapped_24_and_32_bit_LFSR
; output: A (random number)
.proc RandomByte
  phx ; Needed because setaxy8 will clear the high byte of X
  phy
  php
  setaxy8
  tdc ; Clear A, including the high byte

  seed = random1
  ; rotate the middle bytes left
  ldy seed+2 ; will move to seed+3 at the end
  lda seed+1
  sta seed+2
  ; compute seed+1 ($C5>>1 = %1100010)
  lda seed+3 ; original high byte
  lsr
  sta seed+1 ; reverse: 100011
  lsr
  lsr
  lsr
  lsr
  eor seed+1
  lsr
  eor seed+1
  eor seed+0 ; combine with original low byte
  sta seed+1
  ; compute seed+0 ($C5 = %11000101)
  lda seed+3 ; original high byte
  asl
  eor seed+3
  asl
  asl
  asl
  asl
  eor seed+3
  asl
  asl
  eor seed+3
  sty seed+3 ; finish rotating byte 2 into 3
  sta seed+0

  plp
  ply
  plx
  rtl
.endproc

; Randomly negates the input you give it
.a16
.proc VelocityLeftOrRight
  pha
  jsl RandomByte
  lsr
  bcc Right
Left:
  pla
  eor #$ffff
  ina
  rtl
Right:
  pla
  rtl
.endproc

.a16
.proc FadeIn
  php

  seta8
  lda #$1
: pha
  jsl WaitVblank
  pla
  sta PPUBRIGHT
  ina
  ina
  cmp #$0f+2
  bne :-

  plp
  rtl
.endproc

.a16
.proc FadeOut
  php

  seta8
  lda #$11
: pha
  jsl WaitVblank
  pla
  dea
  dea
  sta PPUBRIGHT
  bpl :-
  lda #FORCEBLANK
  sta PPUBRIGHT

  plp
  rtl
.endproc

.proc WaitKeysReady
  php
  seta8
  ; Wait for the controller to be ready
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait
  seta16

  ; -----------------------------------

  lda keydown
  sta keylast
  lda JOY1CUR
  sta keydown
  lda keylast
  eor #$ffff
  and keydown
  sta keynew
  stz OamPtr
  plp
  rtl
.endproc

; Quickly clears a section of WRAM
; Inputs: X (address), Y (size)
.i16
.proc MemClear
  php
  seta8
  stz WMADDH ; high bit of WRAM address
UseHighHalf:
  stx WMADDL ; WRAM address, bottom 16 bits
  sty DMALEN

  ldx #DMAMODE_RAMFILL
ZeroSource:
  stx DMAMODE

  ldx #.loword(ZeroSource+1)
  stx DMAADDR
  lda #^MemClear
  sta DMAADDRBANK

  lda #$01
  sta COPYSTART
  plp
  rtl
.endproc

; Quickly clears a section of the second 64KB of RAM
; Inputs: X (address), Y (size)
.i16
.a16
.proc MemClear7F
  php
  seta8
  lda #1
  sta WMADDH
  bra MemClear::UseHighHalf
.endproc

.export KeyRepeat
.proc KeyRepeat
  php
  seta8
  lda keydown+1
  beq NoAutorepeat
  cmp keylast+1
  bne NoAutorepeat
  inc AutoRepeatTimer
  lda AutoRepeatTimer
  cmp #12
  bcc SkipNoAutorepeat

  lda retraces
  and #3
  bne :+
    lda keydown+1
    and #>(KEY_LEFT|KEY_RIGHT|KEY_UP|KEY_DOWN)
    sta keynew+1
  :

  ; Keep it from going up to 255 and resetting
  dec AutoRepeatTimer
  bne SkipNoAutorepeat
NoAutorepeat:
  stz AutoRepeatTimer
SkipNoAutorepeat:
  plp
  rtl
.endproc
