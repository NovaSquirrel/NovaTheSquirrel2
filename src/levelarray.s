; Super Princess Engine
; Copyright (C) 2019-2024 NovaSquirrel
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


; .----------------------------------------------------------------------------
; | Routines to modify the level array
; '----------------------------------------------------------------------------

; Changes a block in the level immediately and queues a PPU update.
; input: A (new block), LevelBlockPtr (block to change)
; locals: BlockTemp
.a16
.i16
.proc ChangeBlock
ADDRESS = 0
DATA    = 2
Temp    = BlockTemp
; Could reserve a second variable to avoid calling GetBlockX twice
  phx
  phy
  php
  setaxy16
  sta [LevelBlockPtr] ; Make the change in the level buffer itself

  ldy ScatterUpdateLength
  cpy #SCATTER_BUFFER_LENGTH - (4*4) + 1 ; There needs to be enough room for four tiles
  bcc :+
    ; Instead try to do it later
    ldy #1
    sty BlockTemp
    jsl DelayChangeBlock ; Takes A and LevelBlockPtr just like ChangeBlock
    jmp Exit
  :

  ; From this point on in the routine, Y = index to write into the scatter buffer

  ; Save block number in X specifically, for 24-bit Absolute Indexed
  tax
  ; Now the accumulator is free to do other things

  ; Use the second routine if it's on the second foreground layer
  bit8 TwoLayerLevel ; But only if it actually is a two layer level
  bpl :+
    bit LevelBlockPtr
    jvs ChangeBlockFG2
  :
  ; -----------------------------------

  ; First, make sure the block is actually onscreen (Horizontally)
  jsl GetBlockX
  seta8
  sta Temp ; Store column so it can be compared against

  lda ScrollX+1
  sub #1 ; TODO: check
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
  sta ScatterUpdateBuffer+(4*0)+DATA,y
  lda f:BlockTopRight,x
  sta ScatterUpdateBuffer+(4*1)+DATA,y
  lda f:BlockBottomLeft,x
  sta ScatterUpdateBuffer+(4*2)+DATA,y
  lda f:BlockBottomRight,x
  sta ScatterUpdateBuffer+(4*3)+DATA,y

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
  sta ScatterUpdateBuffer+(4*0)+ADDRESS,y

CalculateRestOfAddress:
  ; Add in X
  jsl GetBlockX
  pha
  and #15
  asl
  ora ScatterUpdateBuffer+(4*0)+ADDRESS,y
  sta ScatterUpdateBuffer+(4*0)+ADDRESS,y

  ; Choose second screen if needed
  pla
  and #16
  beq :+
    lda ScatterUpdateBuffer+(4*0)+ADDRESS,y
    ora #2048>>1
    sta ScatterUpdateBuffer+(4*0)+ADDRESS,y
  :

  ; Derive the other addresses from the first one
  lda ScatterUpdateBuffer+(4*0)+ADDRESS,y
  ina
  sta ScatterUpdateBuffer+(4*1)+ADDRESS,y
  add #31
  sta ScatterUpdateBuffer+(4*2)+ADDRESS,y
  ina
  sta ScatterUpdateBuffer+(4*3)+ADDRESS,y

  tya
  adc #16 ; Carry guaranteed to be clear
  sta ScatterUpdateLength

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
ADDRESS = ChangeBlock::ADDRESS
DATA    = ChangeBlock::DATA
Temp    = ChangeBlock::Temp
Exit    = ChangeBlock::Exit
  ; First, make sure the block is actually onscreen (Horizontally)
  lda LevelBlockPtr ; Get level column
  asl
  asl
  xba
  seta8
  sta Temp ; Store column so it can be compared against

  jmp InRange
  lda ScrollX+1
  add FG2OffsetX+1 ; <--
  sub #1
  bcc @FineLeft
  cmp Temp
  bcc @FineLeft
  jmp Exit
@FineLeft:

  lda ScrollX+1
  add FG2OffsetX+1 ; <--
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
  add FG2OffsetY+1 ; <--
  sub #1
  bcc @FineUp
  cmp Temp
  bcc @FineUp
  jmp Exit
@FineUp:

  lda ScrollY+1
  add FG2OffsetY+1 ; <--
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
  sta ScatterUpdateBuffer+(4*0)+DATA,y
  lda f:BlockTopRight,x
  sta ScatterUpdateBuffer+(4*1)+DATA,y
  lda f:BlockBottomLeft,x
  sta ScatterUpdateBuffer+(4*2)+DATA,y
  lda f:BlockBottomRight,x
  sta ScatterUpdateBuffer+(4*3)+DATA,y

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
  ora SecondFGTilemapPointer ; <--
  sta ScatterUpdateBuffer+(4*0)+ADDRESS,y
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


; .----------------------------------------------------------------------------
; | Coordinates to level pointer
; '----------------------------------------------------------------------------

; Sets LevelBlockPtr to the start of a given column in the level, then reads a specific row
; input: A (column), Y (row)
; output: LevelBlockPtr is set, also A = block at column,row
; Verify that LevelBlockPtr+2 is #^LevelBuf
; Overwrites X
.a16
.proc GetLevelColumnPtr
  ; Multiply by 32 (level height) and then once more for 16-bit values
  and #255

  ldx LevelShapeIndex
  jmp (.loword(:+), x)
: .addr Horizontal
  .addr Vertical
  .addr HorizontalTall

Horizontal: ; Each column is 64 bytes
  xba ; * 256
  lsr ; * 128
  lsr ; * 64
  sta LevelBlockPtr

  lda [LevelBlockPtr],y
  rtl

HorizontalTall: ; Each column is 128 bytes
  xba ; * 256
  lsr ; * 128
  sta LevelBlockPtr

  lda [LevelBlockPtr],y
  rtl

Vertical: ; Each column is 512 bytes
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

.export GetLevelPtrXY_HorizontalTall
.proc GetLevelPtrXY_HorizontalTall
  ; Save the coordinates for later access
;  sta BlockRealX
;  sty BlockRealY

  ; X position * 128
  lsr
  and #%0111111110000000
  sta LevelBlockPtr
  ; 0xxxxxxxx0000000

  ; Y position
  tya
  xba
  asl
  and #127
  tsb LevelBlockPtr
  ; 0xxxxxxxxyyyyyy0

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


; .----------------------------------------------------------------------------
; | Level pointer to coordinates
; '----------------------------------------------------------------------------

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
.export GetBlockX_HorizontalTall
.proc GetBlockX_HorizontalTall
  lda LevelBlockPtr ; Get level column
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
  lda LevelBlockPtr
  asl
  asl
  bcs SecondLayer
  and #$ff00
  rtl

SecondLayer:
  and #$ff00
  sub FG2OffsetX
  rtl
.endproc

.a16
.export GetBlockXCoord_HorizontalTall
.proc GetBlockXCoord_HorizontalTall
  lda LevelBlockPtr
  asl
  and #$ff00
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
.export GetBlockY_HorizontalTall
.proc GetBlockY_HorizontalTall
  lda LevelBlockPtr ; Get level row
  lsr
  and #63
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
.export GetBlockYCoord_HorizontalTall
.proc GetBlockYCoord_HorizontalTall
  lda LevelBlockPtr ; Get level row
  lsr
  and #63
  xba
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


; .----------------------------------------------------------------------------
; | Block miscellaneous
; '----------------------------------------------------------------------------

; Get BlockFlag for the block ID in the accumulator
; !!! Turn this into a macro probably
.a16
.i16
.proc GetBlockFlag
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  rtl
.endproc
