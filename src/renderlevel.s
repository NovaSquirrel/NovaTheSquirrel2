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
: sta ScrollX

  lda PlayerPY
  sub #(8*256)
  bcs :+
    lda #0
: cmp #((32-14)*256)
  bcc :+
    lda #((32-14)*256)
  :
  sta ScrollY

  ; If vertical scrolling is not enabled, lock to the bottom of the level
  lda VerticalScrollEnabled
  lsr
  bcs :+
    lda #((32-14)*256)
    sta ScrollY
  :

  ; -------------------

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
DidPreserveEntities:

  seta8
  stz RerenderInitEntities
  seta16

  ; Init particles
  ldx #ParticleStart
  ldy #ParticleEnd-ParticleStart
  jsl MemClear

  seta8
  Low = 4
  High = 5
  ; Try to spawn actors.
  ; First find the minimum and maximum columns to check.
  lda ScrollX+1
  sub #4
  bcs :+
    lda #0
  :
  sta Low
  ; - get high column
  lda ScrollX+1
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



  ; -------------------

BlockNum = 0
BlocksLeft = 2
YPos = 4
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
  and #LEVEL_HEIGHT-1
  asl
  sta YPos

Loop:
  ; Calculate the column address
  lda BlockNum
  and #15
  asl
  ora #ForegroundBG>>1
  sta ColumnUpdateAddress

  ; Use the other nametable if necessary
  lda BlockNum
  and #16
  beq :+
    lda #2048>>1
    tsb ColumnUpdateAddress
  :

  ; Upload two columns
  ldy YPos
  jsl RenderLevelColumnLeft
  jsl RenderLevelColumnUpload
  inc ColumnUpdateAddress
  ldy YPos
  jsl RenderLevelColumnRight
  jsl RenderLevelColumnUpload

  ; Move onto the next block
  lda LevelBlockPtr
  add #LEVEL_HEIGHT*LEVEL_TILE_SIZE
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1
  sta LevelBlockPtr
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
  lda #ColumnUpdateBuffer
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  stz DMAADDRBANK

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
  lda #RowUpdateBuffer
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  stz DMAADDRBANK

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
  lda #RowUpdateBuffer+32*2
  sta DMAADDR
  lda #32*2
  sta DMALEN

  seta8
  stz DMAADDRBANK

  lda #%00000001
  sta COPYSTART

  plp
  rtl
.endproc

.segment "BlockGraphicData"
; Render the left tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelColumnLeft
  phb
  phk
  plb

  tya
  asl
  and #(32*2)-1
  tax
  stx TempVal
: lda [LevelBlockPtr],y ; Get the next level tile
  iny
  iny
  phy
  tay
  ; Write the two tiles in
  lda BlockTopLeft,y
  sta f:ColumnUpdateBuffer,x
  inx
  inx
  lda BlockBottomLeft,y
  sta f:ColumnUpdateBuffer,x
  inx
  inx
  ply

  ; Wrap around in the buffer
  txa
  and #(32*2)-1
  tax

  ; Stop after 32 tiles vertically
  cpx TempVal
  bne :-

  plb
  rtl
.endproc

; Render the right tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelColumnRight
  phb
  phk
  plb

  tya
  asl
  and #(32*2)-1
  tax
  stx TempVal
: lda [LevelBlockPtr],y ; Get the next level tile
  iny
  iny
  phy
  tay
  ; Write the two tiles in
  lda BlockTopRight,y
  sta f:ColumnUpdateBuffer,x
  inx
  inx
  lda BlockBottomRight,y
  sta f:ColumnUpdateBuffer,x
  inx
  inx
  ply

  ; Wrap around in the buffer
  txa
  and #(32*2)-1
  tax

  ; Stop after 32 tiles vertically
  cpx TempVal
  bne :-

  plb
  rtl
.endproc


; Render the left tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; Initialize X with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowTop
  phb
  phk
  plb

  lda #20
  sta TempVal

: lda [LevelBlockPtr],y ; Get the next level tile
  phy
  tay
  ; Write the two tiles in
  lda BlockTopLeft,y
  sta f:RowUpdateBuffer,x
  inx
  inx
  lda BlockTopRight,y
  sta f:RowUpdateBuffer,x
  inx
  inx
  ply

  ; Next column
  lda LevelBlockPtr
  add LevelColumnSize
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1 ; Mask for entire level, dimensions actually irrelevant
  sta LevelBlockPtr

  ; Wrap around in the buffer
  txa
  and #(64*2)-1
  tax

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rtl
.endproc

; Render the right tile of a column of blocks
; (at LevelBlockPtr starting from index Y)
; Initialize X with buffer position before calling.
; 16-bit accumulator and index
.a16
.i16
.proc RenderLevelRowBottom
  phb
  phk
  plb

  lda #20
  sta TempVal

: lda [LevelBlockPtr],y ; Get the next level tile
  phy
  tay
  ; Write the two tiles in
  lda BlockBottomLeft,y
  sta f:RowUpdateBuffer,x
  inx
  inx
  lda BlockBottomRight,y
  sta f:RowUpdateBuffer,x
  inx
  inx
  ply

  ; Next column
  lda LevelBlockPtr
  add LevelColumnSize
  and #(LEVEL_WIDTH*LEVEL_HEIGHT*LEVEL_TILE_SIZE)-1 ; Mask for entire level, dimensions actually irrelevant
  sta LevelBlockPtr

  ; Wrap around in the buffer
  txa
  and #(64*2)-1
  tax

  ; Stop after 64 tiles horizontally
  dec TempVal
  bne :-

  plb
  rtl
.endproc
