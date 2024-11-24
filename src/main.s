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
.include "audio_enum.inc"
.include "tad-audio.inc"
.smart
.export main, nmi_handler
.import RunAllActors, DrawPlayer, DrawPlayerStatus
.import StartLevel, ResumeLevelFromCheckpoint, BGEffectRun

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

.if 1
  ; Load in the audio engine
  seta8
  setxy16
  phk
  plb

  jsl Tad_Init

;  lda #Song::gimo_297
;  jsr Tad_LoadSong
.endif

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
  .a8

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


;  .import OpenHubworld
;  jml OpenHubworld

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
  jsl UpdateAudio

  ; Draw the player to a display list in main memory
  setaxy16
  inc framecount

  ; If the frame counter is too high, adjust the frame counter and any timestamps the game has saved,
  ; in order to avoid potentially weird stuff when comparing pre-wrap and post-wrap timestamps.
  framecount_limit = $f000
  framecount_limit_subtract = $8000
  lda framecount
  cmp #framecount_limit
  bcc @DontFixFramecount
    ; Set the timer back
    ;sec <-- Carry is set because BCC not taken
    sbc #framecount_limit_subtract
    sta framecount

    ; Fix the saved SpriteTilesUseTime timestamps, which are used when trying to figure out which
    ; actor graphic slot to replace, based on which slot has gone the longest without being used.
    ldx #2*8-2
  @FixSpriteTilesUseTime:
    lda SpriteTilesUseTime,x
    ina ; Leave $ffff timestamps alone, which should just stay at $ffff
    beq :+
      sub #framecount_limit_subtract
      sta SpriteTilesUseTime,x
      bcs :+ ; If it would go negative, set it to zero
      stz SpriteTilesUseTime,x
    :
    dex
    dex
    bpl @FixSpriteTilesUseTime

    stz framecount
  @DontFixFramecount:

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
    seta8
    lda #255
    sta PlayerFrameLast ; Force an update
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
  stz GenericUpdateByteTotal
  stz HighPriorityOAMIndex
  lda #4*(4)
  sta PlayerOAMIndex
  lda #4*(4+5)
  sta OamPtr
  seta8
  ; Start out with the first four sprites offscreen
  lda #$f0
  sta OAM_YPOS+(4*0)
  sta OAM_YPOS+(4*1)
  sta OAM_YPOS+(4*2)
  sta OAM_YPOS+(4*3)
  seta16

  jsl RunPlayer
  jsl AdjustCamera

  ; Make a copy of the old layer 2 position so it can be compared against new values
  lda FG2OffsetX
  sta OldFG2OffsetX
  lda FG2OffsetY
  sta OldFG2OffsetY

  .a16
  ; Hook is primarily meant for controlling foreground layer 2 movement, but can be whatever
  lda GameplayHook
  beq :+
    jsl CallGameplayHook
  :

  ; Calculate the integer versions of the scroll positions now,
  ; so that the player and actors can use them for their own positioning.
  ; A background can pick its own routine here from a list of options for different scroll speeds.
  lda LevelBackgroundId
  and #255
  asl
  tax
  .import BackgroundFlags
  lda f:BackgroundFlags,x
  lsr
  lsr
  lsr
  and #%11110
  tax
  jsr (.loword(ParallaxScrollRoutines),x)

  ; If the level has two foreground layers, calculate the scroll positions for that
  ; second foreground layer, and also move actors and the player if they're standing on the second layer.
  bit8 TwoLayerLevel
  jpl @NotTwoLayer
    lda FG2OffsetX
    lsr
    lsr
    lsr
    lsr
    add FGScrollXPixels
    tax

    lda FG2OffsetY
    lsr
    lsr
    lsr
    lsr
    adc #0              ; Should be carry clear after this because of the LSRs
    adc FGScrollYPixels
    ; Don't decrement A because FGScrollYPixels did it already
    tay

    ; Figure out which SNES layer corresponds to the second foreground layer
    bit8 ForegroundLayerThree
    bpl :+
      ; Extra FG on layer 3
      stx Layer3_ScrollXPixels
      sty Layer3_ScrollYPixels
      bra :++
    :
      ; Extra FG on layer 2
      stx Layer2_ScrollXPixels
      sty Layer2_ScrollYPixels
      lda BGScrollXPixels
      sta Layer3_ScrollXPixels
      lda BGScrollYPixels
      sta Layer3_ScrollYPixels
    :

	; -------------------------------------------
    ; Handle the gameplay aspects of two foreground layer levels too:

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

    ; Carry the actors along if they're riding on foreground layer 2
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
  @NotTwoLayer:
 
  ; Allow changing the scroll positions after they have been calculated
  lda ScrollOverrideHook
  beq :+
    jsl CallScrollOverrideHook
  :
  ; Call this after the scroll hook, in case the background update code wants to use the scroll values
  jsl BGEffectRun

  jsl DrawPlayerStatus

  jsl RunAllActors
  jsl DrawPlayer

  bit8 RenderLevelWithSprites
  bpl :+
    .import UpdateSpriteFGLayer
    jsl UpdateSpriteFGLayer
  :

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
  ldx LevelShapeIndex
  lda PlayerPY
  cmp f:MaximumAllowedPlayerY,x
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

;    seta8
;    lda #$0d
;    sta PPUBRIGHT
;    seta16

  ; Include code for handling the vblank
  ; and updating PPU memory.
  .include "vblank.s"

  seta8
  ; Turn on rendering
  lda LevelFadeIn
  sta PPUBRIGHT
  cmp #$0f
  beq :+
    inc LevelFadeIn
  :

  ; Wait for control reading to finish
  ; (will almost certainly skip the loop immediately)
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait

  ; Update scroll registers
  pea $2100
  pld
  lda Layer1_ScrollXPixels
  sta <BGSCROLLX+0
  lda Layer1_ScrollXPixels+1
  sta <BGSCROLLX+0
  lda Layer1_ScrollYPixels
  sta <BGSCROLLY+0
  lda Layer1_ScrollYPixels+1
  sta <BGSCROLLY+0

  lda Layer2_ScrollXPixels
  sta <BGSCROLLX+2
  lda Layer2_ScrollXPixels+1
  sta <BGSCROLLX+2
  lda Layer2_ScrollYPixels
  sta <BGSCROLLY+2
  lda Layer2_ScrollYPixels+1
  sta <BGSCROLLY+2

  lda Layer3_ScrollXPixels
  sta <BGSCROLLX+4
  lda Layer3_ScrollXPixels+1
  sta <BGSCROLLX+4
  lda Layer3_ScrollYPixels
  sta <BGSCROLLY+4
  lda Layer3_ScrollYPixels+1
  sta <BGSCROLLY+4

  lda Layer4_ScrollXPixels
  sta <BGSCROLLX+6
  lda Layer4_ScrollXPixels+1
  sta <BGSCROLLX+6
  lda Layer4_ScrollYPixels
  sta <BGSCROLLY+6
  lda Layer4_ScrollYPixels+1
  sta <BGSCROLLY+6
  pea $0000
  pld
  ; Copy these over now so that BGEffectRun can run whenever without causing tearing
  ldx BGEffectRAM_Mirror+0
  stx BGEffectRAM+0
  ldx BGEffectRAM_Mirror+2
  stx BGEffectRAM+2
  ldx BGEffectRAM_Mirror+4
  stx BGEffectRAM+4
  ldx BGEffectRAM_Mirror+6
  stx BGEffectRAM+6

  ; Add iris effect
  seta8
  lda LevelIrisIn
  cmp #IRIS_EFFECT_END
  bcs :+
  jsl IrisInitHDMA
:

  lda HDMASTART_Mirror
  sta HDMASTART

  ; Clean up after vblank, now that everything that's time-sensitive is done
  seta16
  stz ScatterUpdateLength

  ; Go on with game logic again
  jmp forever
.endproc

CameraShakeTable:
;  .word 0, .loword(-1), .loword(-1), .loword(2), .loword(-1), .loword(-2), .loword(-1), .loword(1), .loword(-2)
;  .word 0, .loword(-1), .loword(1), .loword(-2), .loword(2), .loword(-3), .loword(3), .loword(-4), .loword(4)
  .word 0, .loword(-1), .loword(1), .loword(-1), .loword(1), .loword(-2), .loword(2), .loword(-2), .loword(2)

MaximumAllowedPlayerY:
  .word (512+64)*16 ; Horizontal
  .word $1000-16*16 ; Vertical
  .word (1024+64)*16 ; Horizontal tall
  .word (512+64)*16 ; Unused

.a16
.proc CallGameplayHook
  jml [GameplayHook]
.endproc

.proc CallScrollOverrideHook
  jml [ScrollOverrideHook]
.endproc

.proc ParallaxScrollRoutines
  ; Room for 16 options
  .addr DefaultParallaxScroll ; 1, 1/2, 1/4

DefaultParallaxScroll:
  lda ScrollX
  lsr
  lsr
  lsr
  lsr
  sta FGScrollXPixels
  sta Layer1_ScrollXPixels
  lsr
  sta BGScrollXPixels
  sta Layer2_ScrollXPixels
  lsr
  sta Layer3_ScrollXPixels
  ; ---
  ; Get position in camera shake table first
  .if 0
  lda CameraShake
  and #255
  beq :+
    dec CameraShake ; 16-bit decrement, but it should be fine since it shouldn't decrement if low byte is zero
  :
  asl
  tax
  .endif

  lda ScrollY
  lsr
  lsr
  lsr
  lsr
  adc #0
  dec a ; SNES displays lines 1-224 so shift it up to 0-223
  ;add f:CameraShakeTable,x
  sta FGScrollYPixels
  sta Layer1_ScrollYPixels
  lsr
  add #128
  sta BGScrollYPixels
  sta Layer2_ScrollYPixels
  lsr
  add #128
  sta Layer3_ScrollYPixels
  rts
.endproc
