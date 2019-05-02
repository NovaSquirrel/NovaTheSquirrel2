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
  asl ; * 2
  asl ; * 4
  asl ; * 8
  asl ; * 16
  asl ; * 32
  asl ; * 64
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
  ; Save the coordinates for later access
  sta BlockRealX
  sty BlockRealY

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
  wai
loop2:
  bit VBLSTATUS  ; Wait for start of this vblank
  bpl loop2
  plp
  rtl
.endproc


; Changes a block in the level immediately and queues a PPU update.
; input: A (new block), LevelBlockPtr (block to change)
; locals: 0
.a16
.i16
.proc ChangeBlock
Temp = 0
  phx
  phy
  php
  setaxy16
  sta [LevelBlockPtr] ; Make the change in the level buffer itself

  ; Find a free index in the block update queue
  ldy #(BLOCK_UPDATE_COUNT-1)*2
FindIndex:
  ldx BlockUpdateAddress,y ; Test for zero (exact value not used)
  beq Found
  dey                      ; Next index
  dey
  bpl FindIndex            ; Give up if all slots full
  jmp Exit
Found:
  ; From this point on in the routine, Y = free update queue index

  ; Save block number in X specifically, for 24-bit Absolute Indexed
  tax
  ; Now the accumulator is free to do other things

  ; -----------------------------------

  ; First, make sure the block is actually onscreen (Horizontally)
  lda LevelBlockPtr ; Get level column
  asl
  asl
  xba
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
  lda LevelBlockPtr ; Get level row
  lsr
  and #31
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
  add #16+1
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
  ; LevelBlockPtr is 00xxxxxxxxyyyyy0
  ; Needs to become  0....pyyyyyxxxxx
  lda LevelBlockPtr
  and #%11110 ; Grab Y & 15
  asl
  asl
  asl
  asl
  asl
  ora #ForegroundBG>>1
  sta BlockUpdateAddress,y

  ; Add in X
  lda LevelBlockPtr
  asl
  asl
  xba
  and #15
  asl
  ora BlockUpdateAddress,y
  sta BlockUpdateAddress,y

  ; Choose second screen if needed
  lda LevelBlockPtr
  and #%0000010000000000
  beq :+
    lda BlockUpdateAddress,y
    ora #2048>>1
    sta BlockUpdateAddress,y
  :

  ; Restore registers
Exit:
  plp
  ply
  plx
  rtl
.endproc

; To write
.a16
.i16
.proc DelayChangeBlock
  rtl
.endproc


; Gets the column number of LevelBlockPtr
.a16
.proc GetBlockX
  lda LevelBlockPtr ; Get level column
  asl
  asl
  xba
  and #255
  rtl
.endproc

; Get the row number of LevelBlockPtr
.a16
.proc GetBlockY
  lda LevelBlockPtr ; Get level row
  lsr
  and #31
  rtl
.endproc
