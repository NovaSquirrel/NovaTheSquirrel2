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
  phx
  ply
  php
  setaxy16
  ; Find a free index first
  ldy #(BLOCK_UPDATE_COUNT-1)*2
FindIndex:
  ldx BlockUpdateAddressT,y ; Test for zero
  beq Found
  dey
  dey
  bpl FindIndex
  bra Exit

Found:
  ; Store the block number
  asl
  tax

  ; Copy the four words in
  lda f:BlockTopLeft,x
  sta BlockUpdateDataTL,y
  lda f:BlockTopLeft,x
  sta BlockUpdateDataTR,y
  lda f:BlockBottomLeft,x
  sta BlockUpdateDataBL,y
  lda f:BlockBottomRight,x
  sta BlockUpdateDataBL,y

;ForegroundBG>>1
;2048>>1

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
