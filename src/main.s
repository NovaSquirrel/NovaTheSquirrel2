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
.export main, nmi_handler
.import RunAllActors, DrawPlayer, DrawPlayerStatus
.import StartLevel, ResumeLevelFromCheckpoint

.segment "CODE"
;;
; Minimalist NMI handler that only acknowledges NMI and signals
; to the main thread that NMI has occurred.
.proc nmi_handler
  ; Because the INC and BIT instructions can't use 24-bit (f:)
  ; addresses, set the data bank to one that can access low RAM
  ; ($0000-$1FFF) and the PPU ($2100-$213F) with a 16-bit address.
  ; Only banks $00-$3F and $80-$BF can do this, not $40-$7D or
  ; $C0-$FF.  ($7E can access low RAM but not the PPU.)  But in a
  ; LoROM program no larger than 16 Mbit, the CODE segment is in a
  ; bank that can, so copy the data bank to the program bank.
  phb
  phk
  plb

  seta16
  inc a:retraces   ; Increase NMI count to notify main thread
  seta8
  bit a:NMISTATUS  ; Acknowledge NMI

  jml [NMIHandler]
.endproc

.export NoNMIHandler
.proc NoNMIHandler
; Restore the previous data bank
  plb
  rti
.endproc


.segment "CODE"
; init.s sends us here
.proc main
  ; In the same way that the CPU of the Commodore 64 computer can
  ; interact with a floppy disk only through the CPU in the 1541 disk
  ; drive, the main CPU of the Super NES can interact with the audio
  ; hardware only through the sound CPU.  When the system turns on,
  ; the sound CPU is running the IPL (initial program load), which is
  ; designed to receive data from the main CPU through communication
  ; ports at $2140-$2143.  Load a program and start it running.
;  jsl spc_boot_apu

  seta8
  setxy16
  phk
  plb

  ; Clear the first 512 bytes manually here
  ldx #512-1
: stz 0, x
  dex
  bpl :-

  ; Clear the rest of the first 64KB
  ldx #512
  ldy #$10000 - 512
  jsl MemClear
  ldx #0
  txy
  jsl MemClear7F

  ; Reset the NMI handler
  lda #<NoNMIHandler
  sta NMIHandler+0
  lda #>NoNMIHandler
  sta NMIHandler+1
  lda #^NoNMIHandler
  sta NMIHandler+2

  ; Clear three screens
  ldx #$c000 >> 1
  ldy #$15
  jsl ppu_clear_nt
  ldx #$d000 >> 1
  ldy #$14
  jsl ppu_clear_nt
  ldx #$e000 >> 1
  ldy #0
  jsl ppu_clear_nt
  setaxy16

  ; Initialize random generator
  lda #12345
  sta random1
  dec
  sta random2

  .import OpenOverworld
  seta8
  lda #2*16
  sta OverworldPlayerX
  lda #10*16
  sta OverworldPlayerY
  stz OverworldMap
  stz OverworldDirection
  jml OpenOverworld
.endproc

.export GameMainLoop
.proc GameMainLoop
  phk
  plb
forever:
  ; Draw the player to a display list in main memory
  setaxy16
  inc framecount

  ; Update keys
  lda keydown
  sta keylast
  lda JOY1CUR
  sta keydown
  lda keylast
  eor #$ffff
  and keydown
  sta keynew

  lda keynew
  and #KEY_START
  beq :+
    .import OpenInventory
    jsl OpenInventory
    phk
    plb
  :

  ; Temporary debug feature
  lda keynew
  and #KEY_SELECT
  beq :++
    seta8
    lda PlayerAbility
    ina
    and #15
    sta PlayerAbility

    lda keydown+1
    and #>KEY_DOWN
    beq :+
      stz PlayerAbility
    :
    lda #1
    sta NeedAbilityChange
    seta16
  :

  ; Upon switching abilities, remove all player projectiles
  seta8
  lda NeedAbilityChange
  beq NoAbilityChange
  ; But don't do it if it should be silent! That probably means an unpause or something
  lda NeedAbilityChangeSilent
  bne NoAbilityChange
    seta16
    lda #ProjectileStart
  : tax
    stz ActorType,x
    add #ActorSize
    cmp #ProjectileEnd
    bcc :-
NoAbilityChange:

  seta16
  lda NeedLevelRerender
  lsr
  bcc :+
    jsl RenderLevelScreens
    seta8
    stz NeedLevelRerender
    seta16
  :

  ; Handle delayed block changes
  ldx #(MaxDelayedBlockEdits-1)*2
DelayedBlockLoop:
  ; Count down the timer, if there is a timer
  lda DelayedBlockEditTime,x
  beq @NoBlock
    dec DelayedBlockEditTime,x
    bne @NoBlock
    ; Hit zero? Make the change
    lda DelayedBlockEditAddr,x
    sta LevelBlockPtr
    lda DelayedBlockEditType,x
    jsl ChangeBlock
  @NoBlock:
  dex
  dex
  bpl DelayedBlockLoop

  ; Run stuff for this frame
  stz OamPtr
  jsl RunPlayer
  jsl AdjustCamera

  lda FG2OffsetX
  sta OldFG2OffsetX
  lda FG2OffsetY
  sta OldFG2OffsetY

  lda keydown
  and #KEY_L
  beq :+
    lda FG2OffsetX
    sub #$10
    sta FG2OffsetX
  :
  lda keydown
  and #KEY_R
  beq :+
    lda FG2OffsetX
    add #$10
    sta FG2OffsetX
  :

  bit TwoLayerLevel-1
  bpl @NotTwoLayer
    ; Carry the player along if they're riding on layer 2
    lda PlayerRidingFG2
    and #255
    beq :+
      lda OldFG2OffsetX
      sub FG2OffsetX
      add PlayerPX
      sta PlayerPX

      lda OldFG2OffsetY
      sub FG2OffsetY
      add PlayerPY
      sta PlayerPY
    :
    .import FG2TilemapUpdate
    jsl FG2TilemapUpdate
  @NotTwoLayer:

  ; Make a 5 sprite hole to fill later
  lda OamPtr
  sta PlayerOAMIndex
  add #4*5
  sta OamPtr

  jsl DrawPlayerStatus
  jsl RunAllActors
  jsl DrawPlayer
  .a16
  .i16

  ; Going past the bottom of the screen results in dying
  lda PlayerPY
  cmp #(512+32)*16
  bcs Die
  ; So does running out of health
  lda PlayerHealth
  and #255
  bne NotDie
Die:
  jsl WaitVblank
  seta8
  lda #FORCEBLANK
  sta PPUBRIGHT
  seta16
  jml ResumeLevelFromCheckpoint
  NotDie:



  ; Pack the second OAM table together into the format the PPU expects
  jsl ppu_pack_oamhi_partial
  ; And once that's out of the way, wait until vertical blank where
  ; I can actually copy all of the prepared OAM to the PPU
  jsl WaitVblank
  jsl ppu_copy_oam_partial
  ; And also do background updates:
  setaxy16

  ; Do row/column updates if required
  lda ColumnUpdateAddress
  beq :+
    jsl RenderLevelColumnUpload
    stz ColumnUpdateAddress
  :
  lda RowUpdateAddress
  beq :+
    jsl RenderLevelRowUpload
    stz RowUpdateAddress
  :
  ; Do row/column updates for second layer
  lda ColumnUpdateAddress2
  beq :+
    jsl RenderLevelColumnUpload2
    stz ColumnUpdateAddress2
  :
  lda RowUpdateAddress2
  beq :+
    jsl RenderLevelRowUpload2
    stz RowUpdateAddress2
  :
  ; -----------------------------------
  ; Do block updates
  ldx #(BLOCK_UPDATE_COUNT-1)*2
BlockUpdateLoop:
  lda BlockUpdateAddress,x
  beq SkipBlock
  sta PPUADDR
  lda BlockUpdateDataTL,x
  sta PPUDATA
  lda BlockUpdateDataTR,x
  sta PPUDATA

  lda BlockUpdateAddress,x ; Move down a row
  add #(32*2)>>1
  sta PPUADDR
  lda BlockUpdateDataBL,x
  sta PPUDATA
  lda BlockUpdateDataBR,x
  sta PPUDATA

  stz BlockUpdateAddress,x ; Cancel out the block now that it's been written
SkipBlock:
  dex
  dex
  bpl BlockUpdateLoop

  ; Do generic DMA updates
  ldx #(GENERIC_UPDATE_COUNT-1)*2
GenericUpdateLoop:
  lda GenericUpdateLength,x
  beq SkipGeneric
  sta DMALEN
  stz GenericUpdateLength,x ; Mark the update slot as free
  lda GenericUpdateSource,x
  sta DMAADDR
  lda GenericUpdateDestination,x
  bmi WasPalette
  ; ---------------
  sta PPUADDR
  lda #DMAMODE_PPUDATA
  sta DMAMODE
  seta8
  lda GenericUpdateFlags,x
  sta DMAADDRBANK
  lda #1
  sta COPYSTART
  seta16
  bra SkipGeneric
  ; ---------------
WasPalette:
  seta8
  sta CGADDR
  stz DMAMODE   ; Linear, increasing DMA
  lda #<CGDATA
  sta DMAPPUREG
  lda GenericUpdateFlags,x
  sta DMAADDRBANK
  lda #1
  sta COPYSTART
  seta16
SkipGeneric:
  dex
  dex
  bpl GenericUpdateLoop


  ; Handle palette requests
  ; (Maybe this should be combined into the generic updates later?)
  lda PaletteRequestIndex
  and #255
  beq :+
    tay
    lda PaletteRequestValue ; Do 16-bit read anyway because DoPaletteUpload will mask off the high byte
    jsl DoPaletteUpload
    stz PaletteRequestIndex ; Also clears the value since it's the next byte
  :


  ; -----------------------------------
  jsl PlayerFrameUpload

  seta8
  lda #$0F
  sta PPUBRIGHT  ; turn on rendering

  ; wait for control reading to finish
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait

  ; Update scroll registers
  seta16
  lda ScrollX
  lsr
  lsr
  lsr
  lsr
  sta 0
  sta FGScrollXPixels

  lda ScrollY
  lsr
  lsr
  lsr
  lsr
  dec a ; SNES displays lines 1-224 so shift it up to 0-223
  sta 2
  sta FGScrollYPixels
  seta8

  lda 0
  sta BGSCROLLX
  lda 1
  sta BGSCROLLX
  lda 2
  sta BGSCROLLY
  lda 3
  sta BGSCROLLY

  ; If in a two-layer level, don't scroll second layer as if it's a background
  lda TwoLayerLevel
  bne SetScrollForTwoLayerLevel

  ; Regular background layer
  seta16
  lsr 0
  lsr 2
  lda 0
  sta BGScrollXPixels

  lda 2
  add #128
  sta 2
  sta BGScrollYPixels
  seta8
  lda 0
  sta BGSCROLLX+2
  lda 1
  sta BGSCROLLX+2
  lda 2
  sta BGSCROLLY+2
  lda 3
  sta BGSCROLLY+2

; Jump back here if the second layer's scrolling was already set
ReturnFromTwoLayer:
  seta16
  .import BGEffectRun
  jsl BGEffectRun

  jmp forever

; ---------------------------------------------------------
SetScrollForTwoLayerLevel:
  seta16
  seta16
  lda ScrollX
  add FG2OffsetX
  lsr
  lsr
  lsr
  lsr
  sta 0
  sta BGScrollXPixels

  lda ScrollY
  add FG2OffsetY
  lsr
  lsr
  lsr
  lsr
  dec a ; SNES displays lines 1-224 so shift it up to 0-223
  sta 2
  sta BGScrollYPixels
  seta8

  lda 0
  sta BGSCROLLX+2
  lda 1
  sta BGSCROLLX+2
  lda 2
  sta BGSCROLLY+2
  lda 3
  sta BGSCROLLY+2
  jmp ReturnFromTwoLayer
.endproc
