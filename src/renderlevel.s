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
.include "actorenum.s"
.smart
.global LevelBuf
.import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight
.import ActorSafeRemoveX

.segment "C_Player"

.a16
.i16
.proc RenderLevelScreens
  ; Set the correct scroll value
  lda PlayerPX
  sub #(8*256)
  bcs :+
    lda #0
: cmp ScrollXLimit
  bcc :+
    lda ScrollXLimit
  :
  sta ScrollX

  lda PlayerPY
  sta PlayerCameraTargetY
  sub #(8*256)
  bcs :+
    lda #0
: cmp ScrollYLimit
  bcc :+
    lda ScrollYLimit
  :
  sta ScrollY

  ; If vertical scrolling is not enabled, lock to the bottom of the level
  lda VerticalScrollEnabled
  lsr
  bcs :+
    lda ScrollYLimit
    sta ScrollY
  :

  ; -------------------

  ; Try to spawn all actors that would be found on this screen, if this flag is set
  lda RerenderInitEntities
  and #255
  jeq NoInitEntities

  ; Teleports will not erase certain actor types
  ; in order to avoid letting teleports break things.
  cmp #RERENDER_INIT_ENTITIES_TELEPORT
  bne DontPreserveEntities
    ldx #ActorStart
  @Loop:
    lda ActorType,x
    cmp #Actor::FlyingArrow*2
    beq @Preserve
    cmp #Actor::Boulder*2
    beq @Preserve
    cmp #Actor::ActivePushBlock*2
    beq @Preserve
    jsl ActorSafeRemoveX
  @Preserve:
    txa
    add #ActorSize
    tax
    cmp #ProjectileEnd
    bne @Loop
    ; Done here, skip over the other clear code
    bra DidPreserveEntities
  DontPreserveEntities:

  ; If not preserving anything, clear out the dynamic sprite allocations
  stz DynamicSpriteSlotUsed+0
  stz DynamicSpriteSlotUsed+2
  stz DynamicSpriteSlotUsed+4
  stz DynamicSpriteSlotUsed+6

  ; Init actors
  ldx #ActorStart
  ldy #ProjectileEnd-ActorStart
  jsl MemClear

  ; Allow all actors to spawn in
  ldx #.loword(LevelActorDefeatedAt)
  ldy #512
  jsl MemClear

DidPreserveEntities:

  seta8
  stz RerenderInitEntities
  seta16

  ; Init particles by clearing them out
  ldx #ParticleStart
  ldy #ParticleEnd-ParticleStart
  jsl MemClear

  seta8
  Low = 4
  High = 5
  ; Try to spawn actors.
  ; First find the minimum and maximum columns to check.
  lda VerticalLevelFlag
  bpl @Horizontal
@Vertical:
  lda ScrollY+1
  .byt $2c ; Skip over "lda ScrollX+1"
  .assert ScrollX < 256, error, "ScrollX must be in zeropage"
@Horizontal:
  lda ScrollX+1
  pha
  sub #4
  bcs :+
    tdc ; Clear accumulator
  :
  sta Low
  ; - get high column
  pla
  add #25
  bcc :+
    lda #255
  :
  sta High
  ; Now look through the list
  ldy #0
EnemyLoop:
  lda [LevelActorPointer],y
  cmp #255
  beq Exit
  cmp Low
  bcc Nope
  cmp High
  bcs Nope
  .import TryMakeActor
  jsl TryMakeActor
Nope:
  iny
  iny
  iny
  iny
  bne EnemyLoop
Exit:

NoInitEntities:
  seta16

  ; If the foreground should be shown with sprites, go set that up instead
  bit8 RenderLevelWithSprites
  bpl :+
    assert_same_banks RenderLevelScreens, InitRenderLevelWithSprites
    .import InitRenderLevelWithSprites
    jmp InitRenderLevelWithSprites
  :

  ; .------------------------------------------------------
  ; | Render the foreground to the first layer
  ; '------------------------------------------------------

BlockNum = 0
BlocksLeft = 2
Pointer = 4
  ; Start rendering
  lda ScrollX+1 ; Get the column number in blocks
  and #$ff
  sub #4   ; Render out past the left side a bit
  sta BlockNum
  jsl GetLevelColumnPtr
  lda #26  ; Go 26 blocks forward
  sta BlocksLeft

  lda ScrollY
  xba
  and LevelColumnMask
  asl
  ora LevelBlockPtr
  sta Pointer

Loop:
  ; Calculate the column address
  lda BlockNum
  and #15
  asl
  ora #ForegroundBG
  sta ColumnUpdateAddress

  ; Use the other nametable if necessary
  lda BlockNum
  and #16
  beq :+
    lda #2048>>1
    tsb ColumnUpdateAddress
  :

  ; Upload two columns
  ldx Pointer
  jsl RenderLevelColumnLeft
  jsl RenderLevelColumnUpload
  inc ColumnUpdateAddress
  ldx Pointer
  jsl RenderLevelColumnRight
  jsl RenderLevelColumnUpload

  ; Move onto the next block
  lda Pointer
  add LevelColumnSize
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1
  sta Pointer
  inc BlockNum

  dec BlocksLeft
  bne Loop


  stz ColumnUpdateAddress

  ; Go and do layer 2 if needed!
  bit TwoLayerLevel-1
  .import RenderLevelScreens2
  jmi RenderLevelScreens2
  rtl
.endproc

.proc RenderLevelColumnUpload
  php
  seta16

  ; Set DMA parameters  
  lda ColumnUpdateAddress
  sta PPUADDR
  lda #DMAMODE_PPUDATA
  sta DMAMODE
  lda #.loword(ColumnUpdateBuffer)
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  lda #^ColumnUpdateBuffer
  sta DMAADDRBANK

  lda #INC_DATAHI|VRAM_DOWN
  sta PPUCTRL

  lda #%00000001
  sta COPYSTART

  lda #INC_DATAHI
  sta PPUCTRL
  plp
  rtl
.endproc

.proc RenderLevelRowUpload
  php

  ; .------------------
  ; | First screen
  ; '------------------
  seta16

  ; Set DMA parameters  
  lda RowUpdateAddress
  sta PPUADDR
  lda #DMAMODE_PPUDATA
  sta DMAMODE
  lda #.loword(RowUpdateBuffer)
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  lda #^RowUpdateBuffer
  sta DMAADDRBANK

  lda #%00000001
  sta COPYSTART

  ; .------------------
  ; | Second screen
  ; '------------------
  seta16

  ; Reset the counters. Don't need to do DMAMODE again I assume?
  lda RowUpdateAddress
  ora #2048>>1
  sta PPUADDR
  lda #.loword(RowUpdateBuffer+32*2)
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8

  lda #%00000001
  sta COPYSTART

  plp
  rtl
.endproc

.segment "BlockGraphicData"
; Render the left tile of a column of blocks
; (starting from index X within LevelBuf)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelColumnLeft
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  ; Calculate starting index for scrolling buffer
  txa
  asl
  and #(32*2)-1
  tay
  sty TempVal
  ; Loop
: lda a:LevelBuf,x ; Get the next level tile
  inx
  inx
  phx
  tax
  ; Write the two tiles in
  lda f:BlockTopLeft,x
  sta ColumnUpdateBuffer,y
  iny
  iny
  lda f:BlockBottomLeft,x
  sta ColumnUpdateBuffer,y
  iny
  iny
  plx

  ; Wrap around in the buffer
  tya
  and #(32*2)-1
  tay

  ; Stop after 32 tiles vertically
  cpy TempVal
  bne :-

  plb
  rtl
.endproc

; Render the right tile of a column of blocks
; (starting from index X within LevelBuf)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelColumnRight
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  ; Calculate starting index for scrolling buffer
  txa
  asl
  and #(32*2)-1
  tay
  sty TempVal
  ; Loop
: lda a:LevelBuf,x ; Get the next level tile
  inx
  inx
  phx
  tax
  ; Write the two tiles in
  lda f:BlockTopRight,x
  sta ColumnUpdateBuffer,y
  iny
  iny
  lda f:BlockBottomRight,x
  sta ColumnUpdateBuffer,y
  iny
  iny
  plx

  ; Wrap around in the buffer
  tya
  and #(32*2)-1
  tay

  ; Stop after 32 tiles vertically
  cpy TempVal
  bne :-

  plb
  rtl
.endproc


; Render the left tile of a column of blocks
; (starting from index X within LevelBuf)
; Initialize Y with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowTop
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  lda #20
  sta TempVal

: lda a:LevelBuf,x ; Get the next level tile
  phx
  tax
  ; Write the two tiles in
  lda f:BlockTopLeft,x
  sta RowUpdateBuffer,y
  iny
  iny
  lda f:BlockTopRight,x
  sta RowUpdateBuffer,y
  iny
  iny
  pla

  ; Next column
  add LevelColumnSize
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1 ; Mask for entire level, dimensions actually irrelevant
  tax

  ; Wrap around in the buffer
  tya
  and #(64*2)-1
  tay

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rtl
.endproc

; Render the right tile of a column of blocks
; (starting from index X within LevelBuf)
; Initialize Y with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowBottom
  phb
  ph2banks LevelBuf, LevelBuf
  plb
  plb

  lda #20
  sta TempVal

: lda a:LevelBuf,x ; Get the next level tile
  phx
  tax
  ; Write the two tiles in
  lda f:BlockBottomLeft,x
  sta RowUpdateBuffer,y
  iny
  iny
  lda f:BlockBottomRight,x
  sta RowUpdateBuffer,y
  iny
  iny
  pla

  ; Next column
  add LevelColumnSize
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1 ; Mask for entire level, dimensions actually irrelevant
  tax

  ; Wrap around in the buffer
  tya
  and #(64*2)-1
  tay

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rtl
.endproc
