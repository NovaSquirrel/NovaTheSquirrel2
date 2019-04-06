.setcpu "none"
.include "spc-65c02.inc"
.include "pentlyseq.inc"

.macro stya addr
.local addr1
addr1 = addr
  .assert addr <= $00FE, error, "stya works only in zero page"
  movw <addr, ya
.endmacro

TIMEREN     = $F1  ; 0-2: enable timer; 7: enable ROM in $FFC0-$FFFF
DSPADDR     = $F2
DSPDATA     = $F3
TIMERPERIOD = $FA  ; Divisors for timers (0, 1: 8 kHz base; 2: 64 kHz base)
TIMERVAL    = $FD  ; Number of times timer incremented (bits 3-0; cleared on read)

DSP_CLVOL    = $00
DSP_CRVOL    = $01
DSP_CFREQLO  = $02  ; Playback frequency in 7.8125 Hz units
DSP_CFREQHI  = $03  ; (ignored 
DSP_CSAMPNUM = $04  
DSP_CATTACK  = $05  ; 7: set; 6-4: decay rate; 3-0: attack rate
DSP_CSUSTAIN = $06  ; 7-5: sustain level; 4-0: sustain decay rate
DSP_CGAIN    = $07  ; Used only when attack is disabled

DSP_LVOL     = $0C
DSP_RVOL     = $1C
DSP_LECHOVOL = $2C
DSP_RECHOVOL = $3C
DSP_KEYON    = $4C
DSP_KEYOFF   = $5C
DSP_FLAGS    = $6C  ; 5: disable echo; 4-0: set LFSR rate
DSP_FMCH     = $2D  ; Modulate these channels' frequency by the amplitude before it
DSP_NOISECH  = $3D  ; Replace these channels with LFSR noise
DSP_ECHOCH   = $4D  ; Echo comes from these channels
DSP_SAMPDIR  = $5D  ; High byte of base address of sample table

.export sample_dir, spc_entry

.segment "SPCZEROPAGE"
; Writing to KON or KOFF twice within a 64-cycle (2 sample) window
; is unreliable.  So writes are collected into bitmask regs.
kon_ready: .res 1
koff_ready: .res 1

; We want to KOFF the notes, wait a bit for them to be faded out,
; and KON the new notes a little later.
ready_notes: .res 8
noteInstrument: .res 8


patternptrlo: .res 8
patternptrhi: .res 8
noteRowsLeft: .res 8
musicPattern: .res 8
patternTranspose: .res 8
noteLegato: .res 8

; Effects remaining to implement
channelVolume: .res 8
graceTime: .res 8
defaultGraceTime: .res 8

music_tempoLo: .res 1
music_tempoHi: .res 1
tempo_counter: .res 2
conductorPos: .res 2
conductorSegnoLo: .res 1
conductorSegnoHi: .res 1
conductorWaitRows: .res 1

NUM_CHANNELS = 8
TIMER_HZ = 125
MAX_CHANNEL_VOLUME = 4

.segment "SPCIMAGE"
.align 256
sample_dir:
  ; each directory entry is 4 bytes:
  ; a start address then a loop address
  .addr pulse_8_brr, pulse_8_brr
  .addr pulse_4_brr, pulse_4_brr
  .addr pulse_2_brr, pulse_2_brr
  .addr triangle_brr, triangle_brr
  .addr karplusbassloop_brr, karplusbass_loop
  .addr hat_brr, hat_brr
  .addr kick_brr, kick_brr
  .addr snare_brr, snare_brr

  nop  ; resync debugger's disassembly
.align 256
spc_entry:
  jsr pently_init
  lda #0
  jsr pently_start_music

nexttick:
  :
    lda TIMERVAL
    beq :-
  jsr pently_update
  jmp nexttick

; CONDUCTOR TRACK ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.proc pently_init
  ldy #$7F
  lda #DSP_LVOL  ; master volume left
  stya DSPADDR
  lda #DSP_RVOL  ; master volume right
  stya DSPADDR

  ; Disable the APU features we're not using
  ldy #%00100000  ; mute off, echo write off, LFSR noise stop
  lda #DSP_FLAGS
  stya DSPADDR
  ldy #$00
  sty music_tempoLo
  sty music_tempoHi
  lda #DSP_KEYON  ; Clear key on
  stya DSPADDR
  lda #DSP_FMCH   ; Clear frequency modulation
  stya DSPADDR

  dey
  lda #DSP_KEYOFF  ; Key off everything
  stya DSPADDR
  sty tempo_counter
  sty tempo_counter+1
  iny

  lda #DSP_NOISECH  ; LFSR noise on no channels
  stya DSPADDR
  lda #DSP_ECHOCH  ; Echo on no channels
  stya DSPADDR
  lda #DSP_LECHOVOL  ; Left echo volume = 0
  stya DSPADDR
  lda #DSP_RECHOVOL  ; Right echo volume = 0
  stya DSPADDR
  
  ; The DSP acts on KON and KOFF only once every two samples (1/16000
  ; seconds or 64 cycles).  A key on or key off request must remain
  ; set for at least 64 cycles, but key off must be cleared before
  ; key on can be set again.  If key on is set while key off is set,
  ; it'll immediately cut the note and possibly cause a pop.
  ldx #NUM_CHANNELS - 1
  lda #$FF
  :
    sta <ready_notes,x
    dex
    bpl :-

  lda #DSP_KEYOFF
  stya DSPADDR
  
  lda #DSP_SAMPDIR  ; set sample directory start address
  ldy #>sample_dir
  stya DSPADDR

  lda #8000/TIMER_HZ  ; S-Pently will use 125 Hz
  sta TIMERPERIOD
  lda #%10000001
  sta TIMEREN
  lda TIMERVAL
  rts
.endproc

.proc pently_start_music
  pha
  ; Start the song
  lda #<300
  ldy #>300
  stya music_tempoLo
  lda #0
  sta conductorWaitRows

  pla
  asl a
  tax
  lda pently_songs,x
  sta conductorPos
  sta conductorSegnoLo
  lda pently_songs+1,x
  sta conductorPos+1
  sta conductorSegnoHi
  ; falls through
.endproc

.proc pently_stop_all_tracks
  ldx #NUM_CHANNELS - 1
  initpatternloop:
    lda #<silentPattern
    sta <patternptrlo,x
    lda #>silentPattern
    sta <patternptrhi,x
    lda #$FF
    sta <musicPattern,x
    lda #0
    sta <noteRowsLeft,x
    sta <noteLegato,x
    txa
    and #$01
    sta <defaultGraceTime,x
    sta <graceTime,x
    lda #MAX_CHANNEL_VOLUME
    sta <channelVolume,x
    dex
    bpl initpatternloop
  rts
.endproc

.proc pently_update
  jsr keyon_ready_notes
  
  ; TODO: figure out something for sound effects

  ; TODO: figure out something for grace time

  ; Bresenham accumulator for next row
  clc
  lda music_tempoLo
  adc tempo_counter
  sta tempo_counter
  lda music_tempoHi
  adc tempo_counter+1
  sta tempo_counter+1
  bcc between_rows

  ; New row time!
  lda tempo_counter
  sec
  sbc #<(60 * TIMER_HZ)
  sta tempo_counter
  lda tempo_counter+1
  sec
  sbc #>(60 * TIMER_HZ)
  sta tempo_counter+1

  jsr play_conductor
  ldx #NUM_CHANNELS - 1
  :
    lda defaultGraceTime,x
    sta graceTime,x
    bne nr_notGraceTime
      jsr processTrackPattern
    nr_notGraceTime:
    dex
    bpl :-
  jmp keyoff_ready_notes

between_rows:
  ldx #NUM_CHANNELS - 1
  :
.if 1
    lda graceTime,x
    beq br_notGraceTime
    sec
    sbc #1
    sta graceTime,x
    bne br_notGraceTime
      jsr processTrackPattern
.endif
    br_notGraceTime:
    dex
    bpl :-
  jmp keyoff_ready_notes
.endproc

.proc play_conductor
  lda <conductorWaitRows
  beq doConductor
    dec <conductorWaitRows
    rts
  doConductor:

  ldy #0
  lda (<conductorPos),y
  inc <conductorPos
  bne :+
    inc <conductorPos+1
  :
  cmp #CON_SETTEMPO
  bcc @notTempoChange
    ; Removed: BPM math
    and #%00000111
    sta music_tempoHi
  
    lda (<conductorPos),y
    inc <conductorPos
    bne :+
      inc <conductorPos+1
    :
    sta music_tempoLo
    jmp doConductor
  @notTempoChange:
  cmp #CON_WAITROWS
  bcc conductorPlayPattern
  bne @notWaitRows
    jmp conductorDoWaitRows
  @notWaitRows:

  ; Removed: attack track
  ; Removed for now: note on
  ; TODO: Restore note on

  @notAttackSet:

  cmp #CON_FINE
  bne @notFine
    lda #0
    sta <music_tempoHi
    sta <music_tempoLo
    ; Removed: dal segno callback
    jmp pently_stop_all_tracks
  @notFine:

  cmp #CON_SEGNO
  bne @notSegno
    lda <conductorPos
    sta <conductorSegnoLo
    lda <conductorPos+1
    sta <conductorSegnoHi
    jmp doConductor
  @notSegno:

  cmp #CON_DALSEGNO
  bne @notDalSegno
    lda <conductorSegnoLo
    sta <conductorPos
    lda <conductorSegnoHi
    sta <conductorPos+1
    ; Removed: dal segno callback
    jmp doConductor
  @notDalSegno:
  rts

conductorPlayPattern:
  ; Fortunately we can store channels' fields adjacently because
  ; they're 16 bytes apart in the DSP, and the SPC700 has a nibble
  ; swap instruction.
  and #$07
  tax

  ; Removed handling for attack track, as S-DSP doesn't really
  ; support restarting a note already in progress.  One can switch
  ; to the other note's sample, but that doesn't take effect until
  ; the current sample's loop point, unlike pitch that takes effect
  ; immediately, and ADSR that I haven't really researched yet.
  lda #0
  sta <noteLegato,x  ; start all patterns with legato off
  lda (<conductorPos),y
  sta <musicPattern,x
  iny
  lda (<conductorPos),y
  sta <patternTranspose,x
  iny
  lda (<conductorPos),y
  sta <noteInstrument,x
  tya
  sec
skipAplusCconductor:
  adc <conductorPos
  sta <conductorPos
  bcc :+
    inc <conductorPos+1
  :
  jsr startPattern
  jmp doConductor

  ; this should be last so it can fall into skipConductor
conductorDoWaitRows:
  lda (<conductorPos),y
  inc <conductorPos
  bne :+
    inc <conductorPos+1
  :
  sta <conductorWaitRows
  rts
.endproc

; PLAYING PATTERNS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

durations: .byte 1, 2, 3, 4, 6, 8, 12, 16

.proc startPattern
  lda <defaultGraceTime,x
  sta <graceTime,x
  lda #0
  sta <noteRowsLeft,x
  lda <musicPattern,x
  cmp #$FF
  bcc @notSilentPattern
    lda #<silentPattern
    sta <patternptrlo,x
    lda #>silentPattern
    sta <patternptrhi,x
    rts
  @notSilentPattern:
  asl a
  tay
  bcc @isLoPattern
    lda pently_patterns+256,y
    sta <patternptrhi,x
    lda pently_patterns+257,y
    sta <patternptrhi,x
    rts
  @isLoPattern:
  lda pently_patterns,y
  sta <patternptrlo,x
  lda pently_patterns+1,y
  sta <patternptrhi,x
  rts
.endproc

.proc processTrackPattern
patternptr = $00

  lda noteRowsLeft,x
  beq notWaitingRows
    sec
    sbc #1
    sta noteRowsLeft,x
    rts
  notWaitingRows:

  lda patternptrlo,x
  sta patternptr
  lda patternptrhi,x
  sta patternptr+1

anotherPatternByte:
  ldy #0
  lda (patternptr),y
  cmp #$FF
  bcc notStartPatternOver
    jsr startPattern
    lda #0
    sta graceTime,x
    bra notWaitingRows
  notStartPatternOver:
  inc patternptr
  bne :+
    inc patternptr+1
  :

  cmp #INSTRUMENT
  bcs isEffectCmd

  ; Set the note's duration
  pha
  and #$07
  tay
  lda durations,y
  sta noteRowsLeft,x
  pla
  lsr a
  lsr a
  lsr a
  cmp #25
  bcc isTransposedNote
  beq skipNote
    ; $7F: Note off
    lda #$7F
    sta <ready_notes,x
    bra skipNote
  isTransposedNote:
  
  ldy <patternTranspose,x
  bpl noteOnNotDrum

    ; Drum mode: play a middle C with instrument X
    sta <noteInstrument,x
    lda #2*12+0
    bra have_notenum
  noteOnNotDrum:
  clc
  adc <patternTranspose,x
have_notenum:
  sta <ready_notes,x  ; Using previous instrument

skipNote:
  lda <noteRowsLeft,x
  sec
  sbc #1
  sta <noteRowsLeft,x
patDone:
  lda <patternptr
  sta <patternptrlo,x
  lda <patternptr+1
  sta <patternptrhi,x
  rts

isEffectCmd:
  sbc #INSTRUMENT
  cmp #NUM_EFFECTS
  bcs anotherPatternByte
  asl a
  tay
  lda patcmdhandlers+1,y
  pha
  lda patcmdhandlers,y
  pha
  rts

; An authentic 6502 adds 2 to PC in JSR and 1 in RTS.
; The SPC700 instead adds 3 in JSR and 0 in RTS.
; This means we push without -1.
; Each effect is called with carry clear and the effect number
; times 2 in Y.
patcmdhandlers:
  .addr set_fx_instrument
  .addr set_fx_arpeggio
  .addr set_fx_legato
  .addr set_fx_legato
  .addr set_fx_transpose
  .addr set_fx_grace
  .addr set_fx_vibrato
  .addr set_fx_ch_volume

  .addr set_fx_portamento
  .addr set_fx_portamento  ; Reserved for future use
  .addr set_fx_fastarp
  .addr set_fx_slowarp
NUM_EFFECTS = (* - patcmdhandlers) / 2

; These effects don't exist yet in S-Pently
  set_fx_arpeggio = nextPatternByte
  set_fx_vibrato = anotherPatternByte
  set_fx_portamento = anotherPatternByte
  set_fx_fastarp = anotherPatternByte
  set_fx_slowarp = anotherPatternByte

set_fx_instrument:
  ldy #0
  lda (patternptr),y
  sta noteInstrument,x

nextPatternByte:
  inc patternptr
  bne :+
    inc patternptr+1
  :
  jmp anotherPatternByte

set_fx_legato:
  tya
  and #$02
  sta noteLegato,x
  jmp anotherPatternByte

set_fx_grace:
  ldy #0
  lda (patternptr),y
  asl a
  sta graceTime,x
  jmp nextPatternByte

set_fx_transpose:
  lda patternTranspose,x
  ldy #0
  adc (patternptr),y
  sta patternTranspose,x
  jmp nextPatternByte

set_fx_ch_volume:
  ldy #0
  lda (patternptr),y
  sta <channelVolume,x
  jmp nextPatternByte
.endproc

silentPattern: .byte $D7, $FF

; S-Pently alignment audit 2018-03-20: Down to pentlymusic.s line 724

; PLAYING NOTES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;
; Sets the frequency of channel X to A times the frequency for note Y.
; Frequency 0 represents 2093 Hz, which when used with a 32-sample
; wave represents a C two octaves below middle C.
; If A * 2^(Y/12) >= 64, the playback frequency is unspecified.
; @param X voice ID (0-7)
; @param A pitch scale (BRR blocks per period)
; @param Y semitone number
; @return A, Y, $00 trashed; X preserved
.proc ch_set_pitch
pitchhi = $00
  sta pitchhi
  txa
  xcn a
  ora #DSP_CFREQLO
  sta DSPADDR
  tya
octave_loop:
  cmp #12
  bcc octave_done
  sbc #12
  asl pitchhi
  jmp octave_loop
octave_done:
  tay
  lda notefreqs_lowbyte,y
  ldy pitchhi
  mul ya
  sta DSPDATA
  inc DSPADDR
  ;clc  ; octave_loop always ends with carry clear
  tya
  adc pitchhi
  sta DSPDATA
  rts
.endproc

;;
; Sets volume, sample ID, and envelope of channel X to instrument A.
; @param X channel number (0-7)
; @param A instrument number
; @return $02: pointer to instrument; $04: channel volume;
; A: instrument's pitch scale; Y trashed; X preserved
.proc ch_set_inst
instptr = $02
chvolalt = $04
  ldy #8
  mul ya
  clc
  adc #<music_inst_table
  sta instptr
  tya
  adc #>music_inst_table
  sta instptr+1
  txa
  xcn a
  sta DSPADDR
  
  ; Set left channel volume
  ldy #0
  lda (instptr),y
  pha
  xcn a
  and #$0F  ; 0 to 15
  ldy <channelVolume,x  ; 0 to 4
  mul ya
  asl a
  sta DSPDATA

  ; Set right channel volume
  inc DSPADDR
  pla
  and #$0F
  ldy <channelVolume,x
  mul ya
  asl a
  sta DSPDATA

  ; Set sample ID and envelope
  lda DSPADDR
  eor #DSP_CSAMPNUM^DSP_CRVOL
  sta DSPADDR
  ldy #2
  lda (instptr),y
  sta DSPDATA
  inc DSPADDR
  iny
  lda (instptr),y
  sta DSPDATA
  inc DSPADDR
  iny
  lda (instptr),y
  sta DSPDATA

  ; Return the frequency scale
  ldy #1
  lda (instptr),y
  rts
.endproc

;;
; Calculate which notes are ready to be keyed off.
; Sending a key off command takes 2 samples (64 cycles), which
; starts a fade-out process that takes up to 256 samples (8 ms).
; So find which voices are ready for key off and on, and do so.
.proc keyoff_ready_notes
unready_chs = $07
  ldx #NUM_CHANNELS - 1
  loop:
    ; Bit 7 of ready_notes is 1 for no keyoff or 0 for keyoff.
    lda ready_notes,x
    asl a
    rol unready_chs
    dex
    bpl loop
  lda #DSP_KEYOFF
  sta DSPADDR
  lda unready_chs
  eor #$FF
  sta DSPDATA
  rts
.endproc

.proc keyon_ready_notes
unready_chs = $07
  ldx #NUM_CHANNELS - 1
  loop:
    ; Bit 7 of ready_notes is 1 for no keyon or 0 for keyon.
    ; $78-$7F are invalid notes used to key off without keying on.
    lda ready_notes,x
    cmp #$78
    bcs not_ready
      lda noteInstrument,x
      jsr ch_set_inst
      pha
      lda ready_notes,x
      tay
      pla
      jsr ch_set_pitch

      clc
    not_ready:
    rol unready_chs

    ; Acknowledge key on
    lda #$FF
    sta ready_notes,x
    dex
    bpl loop
  lda #DSP_KEYOFF
  ldy #0
  stya DSPADDR
  lda #DSP_KEYON
  sta DSPADDR
  lda unready_chs
  eor #$FF
  sta DSPDATA
  rts
.endproc

; Sample data ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

pulse_2_brr:
  .byte $B0,$9B,$BB,$BB,$BB,$BB,$BB,$BB,$B9
  .byte $B3,$75,$55,$55,$55,$55,$55,$55,$57
pulse_4_brr:
  .byte $B0,$9B,$BB,$BB,$B9,$75,$55,$55,$55
  .byte $B3,$55,$55,$55,$55,$55,$55,$55,$57
pulse_8_brr:
  .byte $B0,$9B,$B9,$75,$55,$55,$55,$55,$55
  .byte $B3,$55,$55,$55,$55,$55,$55,$55,$57
triangle_brr:
  ; The triangle wave is intentionally distorted slightly because the
  ; SPC700's Gaussian interpolator has a glitch with three
  ; consecutive 8<<12 samples.
  .byte $C0,$00,$11,$22,$33,$44,$55,$66,$76
  .byte $C0,$77,$66,$55,$44,$33,$22,$11,$00
  .byte $C0,$FF,$EE,$DD,$CC,$BB,$AA,$99,$89
  .byte $C3,$88,$99,$AA,$BB,$CC,$DD,$EE,$FF
karplusbassloop_brr:
    .incbin "obj/snes/karplusbassloop.brr"
karplusbass_loop = * - 36  ; period 64 samples (36 bytes)
hat_brr:
    .incbin "obj/snes/hat.brr"
kick_brr:
    .incbin "obj/snes/kickgen.brr"
snare_brr:
    .incbin "obj/snes/decentsnare.brr"

; $ python3
; [round(261.625 * 8 / 7.8125 * 2**(i / 12)) - 256 for i in range(12)]
notefreqs_lowbyte:
  .byte 12, 28, 45, 63, 82, 102, 123, 145, 169, 195, 221, 250
one_shl_x:
  .repeat 8, I
    .byte 1 << I
  .endrepeat

