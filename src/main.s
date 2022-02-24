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

IRIS_EFFECT_END = 30

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

  ; In the same way that the CPU of the Commodore 64 computer can
  ; interact with a floppy disk only through the CPU in the 1541 disk
  ; drive, the main CPU of the Super NES can interact with the audio
  ; hardware only through the sound CPU.  When the system turns on,
  ; the sound CPU is running the IPL (initial program load), which is
  ; designed to receive data from the main CPU through communication
  ; ports at $2140-$2143.  Load a program and start it running.
  jsl spc_boot_apu
  seta8
  .import GSS_SendCommand, GSS_LoadSong
  lda #GSS_Commands::INITIALIZE
  jsl GSS_SendCommand
  lda #0
  jsl GSS_LoadSong
  lda #GSS_Commands::MUSIC_START
  jsl GSS_SendCommand


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

  ; Clear palette
  stz CGADDR
  ldx #256
: stz CGDATA
  stz CGDATA
  dex
  bne :-
  ; Clear VRAM too
  seta16
  stz PPUADDR
  ldx #$8000
: stz PPUDATA
  dex
  bne :-



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
  stz framecount
forever:
  ; Draw the player to a display list in main memory
  setaxy16
  inc framecount
  seta16

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
;  lda RunGameLogic
;  lsr
;  bcc :+
    jsl RunPlayer
;  :

  jsl AdjustCamera

  ; Calculate the scroll positions ahead of time so their integer values are ready
  lda ScrollX
  lsr
  lsr
  lsr
  lsr
  sta FGScrollXPixels
  lsr
  sta BGScrollXPixels
  ; ---
  lda ScrollY
  lsr
  lsr
  lsr
  lsr
  adc #0
  dec a ; SNES displays lines 1-224 so shift it up to 0-223
  sta FGScrollYPixels
  lsr
  add #128
  sta BGScrollYPixels

  lda FG2OffsetX
  sta OldFG2OffsetX
  lda FG2OffsetY
  sta OldFG2OffsetY

  .a16
  lda FG2MovementRoutine
  beq :+
    jsl CallFG2MovementRoutine
  :

  ; Update foreground layer 2
  bit TwoLayerLevel-1
  bpl @NotTwoLayer
    ; Carry the player along if they're riding on foreground layer 2
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

  ; If you're holding onto something, reserve a sprite slot above the player to draw it
  lda PlayerHoldingSomething
  lsr
  bcc :+
    lda PlayerOAMIndex
    sta ActorHeldOAMIndex
    add #4
    sta PlayerOAMIndex
    lda OamPtr
    add #4
    sta OamPtr
  :

  jsl DrawPlayerStatus

;  lda RunGameLogic
;  lsr
;  bcc SkipActors
  ; Move all of the actors that are standing on a second FG layer
  bit TwoLayerInteraction-1
  bpl @NotTwoLayerForActors
    ldx #ActorStart
  @TwoLayerActorLoop:
    lda ActorType,x
    beq :+
      lda ActorOnGround,x
      and #128
      beq :+
        lda OldFG2OffsetX
        sub FG2OffsetX
        add ActorPX,x
        sta ActorPX,x

        lda OldFG2OffsetY
        sub FG2OffsetY
        add ActorPY,x
        sta ActorPY,x
    :
    txa
    add #ActorSize
    tax
    cpx #ActorEnd
    bne @TwoLayerActorLoop
  @NotTwoLayerForActors:

    jsl RunAllActors
;  SkipActors:
  jsl DrawPlayer
  .a16
  .i16

  ; Update iris stuff
  seta8
  .import IrisInitTable, IrisUpdate, IrisInitHDMA, IrisDisable
  lda LevelIrisIn
  cmp #IRIS_EFFECT_END
  beq NoIris

  lda PlayerDrawX
  sta 0
  lda PlayerDrawY
  sub #16
  sta 1
  lda LevelIrisIn
  jsl IrisUpdate

  lda LevelIrisIn
  ina
  sta LevelIrisIn
  cmp #IRIS_EFFECT_END
  bne NoIris
  jsl IrisDisable
NoIris:
  setaxy16

  ; Going past the bottom of the screen results in dying
  lda PlayerPY
  cmp #(512+32)*16
  bcs Die
    ; So does running out of health
    lda PlayerHealth
    and #255
    bne NotDie
  Die:
    ; Wait and turn off the screen
    jsl WaitVblank
    seta8
    lda #FORCEBLANK
    sta PPUBRIGHT
    seta16
    jml ResumeLevelFromCheckpoint
  NotDie:

  ; Include code for handling the vblank
  ; and updating PPU memory.
  .include "vblank.s"

  seta8
  ; Turn on rendering
  lda LevelFadeIn
  sta PPUBRIGHT
  cmp #$0f
  beq :+
    ina
  :
  sta LevelFadeIn

  ; Wait for control reading to finish
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait

  ; Update scroll registers
  ; ---Primary foreground---
  seta8
  lda FGScrollXPixels+0
  sta BGSCROLLX
  lda FGScrollXPixels+1
  sta BGSCROLLX
  lda FGScrollYPixels+0
  sta BGSCROLLY
  lda FGScrollYPixels+1
  sta BGSCROLLY

  lda TwoLayerLevel
  eor ForegroundLayerThree
  bne :+
    lda BGScrollXPixels+0
    sta BGSCROLLX+2
    lda BGScrollXPixels+1
    sta BGSCROLLX+2
    lda BGScrollYPixels+0
    sta BGSCROLLY+2
    lda BGScrollYPixels+1
    sta BGSCROLLY+2
  :

  ; If in a two-layer level, scroll the second layer differently
  lda TwoLayerLevel
  bne SetScrollForTwoLayerLevel

; Jump back here if the second layer's scrolling was already set
ReturnFromTwoLayer:
  seta16
  .import BGEffectRun
  jsl BGEffectRun

  ; Add iris effect
  seta8
  lda LevelIrisIn
  cmp #IRIS_EFFECT_END
  bcs :+
  jsl IrisInitHDMA
:

  lda HDMASTART_Mirror
  sta HDMASTART
  jmp forever

; ---------------------------------------------------------
SetScrollForTwoLayerLevel:
  seta16
  lda FG2OffsetX
  lsr
  lsr
  lsr
  lsr
  add FGScrollXPixels
  sta 0
  sta FG2ScrollXPixels

  lda FG2OffsetY
  lsr
  lsr
  lsr
  lsr
  adc #0
  add FGScrollYPixels
  dec a ; SNES displays lines 1-224 so shift it up to 0-223
  sta 2
  sta FG2ScrollYPixels
  seta8

  lda ForegroundLayerThree
  bne :+
    ; Foreground on layer 2
    lda 0
    sta BGSCROLLX+2
    lda 1
    sta BGSCROLLX+2
    lda 2
    sta BGSCROLLY+2
    lda 3
    sta BGSCROLLY+2
    jmp ReturnFromTwoLayer
  :
  ; Foreground on layer 3
  lda 0
  sta BGSCROLLX+4
  lda 1
  sta BGSCROLLX+4
  lda 2
  sta BGSCROLLY+4
  lda 3
  sta BGSCROLLY+4

  jmp ReturnFromTwoLayer
.endproc

.a16
.proc CallFG2MovementRoutine
  jml [FG2MovementRoutine]
.endproc
