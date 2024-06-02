; Super Princess Engine
; Copyright (C) 2024 NovaSquirrel
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

.import SongDirectory
.importzp SONG_COUNT

.code

; input: A (song ID; 0=common, >0=song)
; output: Carry (song is valid), A (bank), X (address), Y (size)
.a8
.i16
.export LoadAudioData : far
.proc LoadAudioData
  cmp #0
  beq LoadCommon
  cmp #<SONG_COUNT
  bcs Invalid

  seta16

  ; Multiply by 5
  and #$00ff
  sta 0
  asl
  asl
  adc 0
  tax
  
  lda f:SongDirectory+3-5,x ; Size
  tay
  lda f:SongDirectory+0-5,x ; Address
  pha
  seta8
  lda f:SongDirectory+2-5,x ; Bank
  plx
  sec
  rtl

Invalid:
  clc
  rtl

LoadCommon:
  lda #^CommonAudioData_Bin
  ldx #.loword(CommonAudioData_Bin)
  ldy #CommonAudioData_SIZE
  sec
  rtl
.endproc

; input: A (sound effect)
.export PlaySoundEffect
.proc PlaySoundEffect
  php
  phk
  plb
  ; Assume .i16 and data bank == program bank
  seta8
  jsr Tad_QueueSoundEffect
  plp
  rtl
.endproc

.export UpdateAudio
.proc UpdateAudio
  php
  ; Communicate with the audio driver
  seta8
  setxy16
  phk ; Make sure that DB can access RAM and registers
  plb
  jsl Tad_Process
  plp
  rtl
.endproc

; -----------------------------------------------

.segment "AudioDriver"

.export Tad_Loader_Bin, Tad_Loader_SIZE
.export Tad_AudioDriver_Bin, Tad_AudioDriver_SIZE
.export Tad_BlankSong_Bin, Tad_BlankSong_SIZE

CommonAudioData_Bin: .incbin "../audio/audio_common.bin"
CommonAudioData_SIZE = .sizeof(CommonAudioData_Bin) 

Tad_Loader_Bin: .incbin "../audio/driver/loader.bin"
Tad_Loader_SIZE = .sizeof(Tad_Loader_Bin)

Tad_AudioDriver_Bin: .incbin "../audio/driver/audio-driver.bin"
Tad_AudioDriver_SIZE = .sizeof(Tad_AudioDriver_Bin)

Tad_BlankSong_Bin: .incbin "../audio/driver/blank-song.bin"
Tad_BlankSong_SIZE = .sizeof(Tad_BlankSong_Bin)
