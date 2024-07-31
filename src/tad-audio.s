;; Terrific Audio Driver ca65 API

; This file MUST be recompiled if the memory map changes.
;
; SPDX-FileCopyrightText: © 2024 Marcus Rowe <undisbeliever@gmail.com>
; SPDX-License-Identifier: Zlib
;
; Copyright © 2024 Marcus Rowe <undisbeliever@gmail.com>
;
; This software is provided 'as-is', without any express or implied warranty.  In
; no event will the authors be held liable for any damages arising from the use of
; this software.
;
; Permission is granted to anyone to use this software for any purpose, including
; commercial applications, and to alter it and redistribute it freely, subject to
; the following restrictions:
;
;      1. The origin of this software must not be misrepresented; you must not
;         claim that you wrote the original software. If you use this software in
;         a product, an acknowledgment in the product documentation would be
;         appreciated but is not required.
;
;      2. Altered source versions must be plainly marked as such, and must not be
;         misrepresented as being the original software.
;
;      3. This notice may not be removed or altered from any source distribution.


.setcpu "65816"
.smart

; Ensure autoimport is disabled
.autoimport -


.export Tad_Init : far, Tad_Process : far, Tad_FinishLoadingData : far
.export Tad_QueueCommand, Tad_QueueCommandOverride
.export Tad_QueuePannedSoundEffect, Tad_QueueSoundEffect
.export Tad_LoadSong, Tad_LoadSongIfChanged, Tad_GetSong, Tad_ReloadCommonAudioData
.export Tad_SetMono, Tad_SetStereo, Tad_GetStereoFlag
.export Tad_SongsStartImmediately, Tad_SongsStartPaused, Tad_SetTransferSize
.export Tad_IsLoaderActive, Tad_IsSongLoaded, Tad_IsSfxPlaying, Tad_IsSongPlaying

.exportzp Tad_sfxQueue_sfx, Tad_sfxQueue_pan


;; =======
;; DEFINES
;; =======

;; Memory Map
;; ----------
;;
;; `tad-audio.s` requires either a `LOROM` or `HIROM` symbol to determine the memory map used by the ROM.

.if .defined(LOROM) && .defined(HIROM)
    .error "Cannot use HIROM and LOROM at the same time"
.endif
.if ! (.defined(LOROM) || .defined(HIROM))
    .error "Unknown memory map: Missing LOROM or HIROM define"
.endif

;; Segments
;; --------
;;
;; The following optional defines are used to determine the segment to place the code in.
;;
;;  * `TAD_PROCESS_SEGMENT` defines the segment to store the subroutines that processes the queues
;;     and loads data into Audio-RAM (`Tad_Init`, `Tad_Process`, `Tad_FinishLoadingData`).
;;      * The exported subroutines in this segment are called using `JSL` long addressing.
;;      * If `TAD_PROCESS_SEGMENT` is undefined, `TAD_CODE_SEGMENT` is used.
;;
;;  * `TAD_CODE_SEGMENT` defines the segment to store the remaining subroutines.
;;      * The subroutines in this segment are called using `JSR` absolute addressing.
;;      * If `TAD_CODE_SEGMENT` is undefined, "CODE" will be used.
;;
;;
;; NOTE: Because ca65 only allows numbers in `-D name=value` command line arguments, the only
;; way to set these defines is to create a new source file that defines `TAD_CODE_SEGMENT`
;; and/or `TAD_PROCESS_SEGMENT` and then includes `tad-audio.s`.
;;
;; For example:
;;
;;      .define TAD_CODE_SEGMENT "CODE1"
;;      .define TAD_PROCESS_SEGMENT "CODE3"
;;
;;      .include "../terrific-audio-driver/audio-driver/ca65-api/tad-audio.s"
;;

.if .not .match({TAD_CODE_SEGMENT}, {""})
    .define TAD_CODE_SEGMENT "CODE"
.endif

.if .not .match({TAD_PROCESS_SEGMENT}, {""})
    .define TAD_PROCESS_SEGMENT TAD_CODE_SEGMENT
.endif




;; ===========
;; Binary Data
;; ===========
;;
;; These 3 files MUST be embedded (using `.incbin`) into the ROM if the developer uses a custom
;; `LoadAudioData` callback.
;;

;; Terrific Audio Driver spc700 Loader (loader.bin)
.import Tad_Loader_Bin
.importzp Tad_Loader_SIZE

;; Terrific Audio Driver spc700 driver (audio-driver.bin)
.import Tad_AudioDriver_Bin, Tad_AudioDriver_SIZE

;; A blank song to play when `Tad_LoadSong` input is 0 or invalid (blank-song.bin)
.import Tad_BlankSong_Bin
.importzp Tad_BlankSong_SIZE


.assert Tad_Loader_SIZE > 64 && Tad_Loader_SIZE < 128, lderror, "Invalid Tad_Loader_Bin size"
.assert .bankbyte(Tad_Loader_Bin) + .bankbyte(Tad_Loader_Bin + Tad_Loader_SIZE), lderror, "Tad_Loader_Bin does not fit inside a single bank"

.assert Tad_AudioDriver_SIZE > $600 && Tad_AudioDriver_SIZE < $a00, lderror, "Invalid Tad_AudioDriver_Bin size"
; `Tad_AudioDriver_Bin` can cross bank boundaries

.assert Tad_BlankSong_SIZE > 32 && Tad_BlankSong_SIZE < 64, lderror, "Invalid Tad_BlankSong_Bin size"
; `Tad_BlankSong_Bin` can cross bank boundaries



;; =========
;; CALLBACKS
;; =========


;; LoadAudioData callback
;;
;; IN: A = 0 - Common audio data (MUST return carry set)
;; IN: A >= 1 - Song data (might be invalid)
;; OUT: Carry set if input (`A`) was valid
;; OUT: A:X = far address
;; OUT: Y = size
;;
;; Called with JSL long addressing (returns with RTL).
.a8
.i16
;; DB access registers
.import LoadAudioData: Far


;; =========
;; CONSTANTS
;; =========


;; Address to store the loader (in Audio-RAM).
;; Address (in Audio-RAM) to execute after loading the Loader.
;; MUST match LOADER_ADDR in `audio-driver/src/common_memmap.wiz`.
LOADER_ARAM_ADDR = $0200


;; Minimum transfer size accepted by `Tad_SetTransferSize`
;;
;; MUST BE > 0
MIN_TRANSFER_PER_FRAME = 32

;; Maximum transfer size accepted by `Tad_SetTransferSize`
;;
;; The loader can transfer ~849 bytes per 60Hz frame SlowROM or FastROM
MAX_TRANSFER_PER_FRAME = 800

;; Default number of bytes to transfer to Audio-RAM per `Tad_Process` call.
;;
;; MUST BE > 0
DEFAULT_TRANSFER_PER_FRAME = 256



;; ========
;; IO Ports
;; ========

;; IO communication protocol version.
;;
;; Used by `tad-compiler ca65-export` to verify the IO protocol in `tad-audio.s` matches the audio-driver.
;;
;; This constant MUST be increased if `LOADER_ADDR` or the IO Communication protocol changes.
.export TAD_IO_VERSION : abs = 16


; MUST match `audio-driver/src/io-commands.wiz`
.enum Command
    PAUSE = 0
    PAUSE_MUSIC_PLAY_SFX = 2
    UNPAUSE = 4
    PLAY_SOUND_EFFECT_COMMAND = 6
    STOP_SOUND_EFFECTS = 8
    SET_MAIN_VOLUME = 10
    SET_MUSIC_CHANNELS = 12
    SET_SONG_TEMPO = 14
.endenum

MAX_PAN = 128
CENTER_PAN = MAX_PAN / 2


;; MUST match `audio-driver/src/io-commands.wiz`
.scope IO_ToDriver
    ;; The command to execute.
    ;;
    ;;      iii0ccci
    ;;          ccc = command
    ;;            0 = reserved for future expansion
    ;;            i = command id, MUST be different on every command.
    ;;                Used to detect when a new command has been sent to the driver.
    ;;
    ;; NOTES:
    ;;  * The command will only be execute if the `command` byte has changed.
    ;;  * This value MUST be written last.
    ;;  * The command and parameter bytes MUST NOT change unless the previous command
    ;;    has been acknowledged.
    COMMAND_PORT = $2140 ; APUIO0

    N_COMMANDS = 8
    COMMAND_MASK   = %00001110
    COMMAND_I_MASK = %11100001

    ;; The first command parameter port
    PARAMETER0_PORT = $2141 ; APUIO1

    ;; The second command parameter port
    PARAMETER1_PORT = $2142 ; APUIO2


    ;; Writing `SWITCH_TO_LOADER` to this port should stop execution and start the loader.
    ;;
    ;; If the audio-driver is running; if the `SWITCH_TO_LOADER_BIT` is set,
    ;; the audio driver will stop and execute the loader.
    ;;
    ;; If the loader is in the middle of a transfer and both the `SWITCH_TO_LOADER_BIT`
    ;; and MSB (bit 7) bits are set, the loader will restart.
    SWITCH_TO_LOADER_PORT = $2143 ; APUIO3

    SWITCH_TO_LOADER_BIT = 5
    SWITCH_TO_LOADER = $80 | (1 << SWITCH_TO_LOADER_BIT)
.endscope


;; MUST match `audio-driver/src/io-commands.wiz`
.scope IO_ToScpu
    ;; Audio driver command acknowledgment.
    ;;
    ;; Acknowledgment of the `ToDriver.command` byte.  Not used in the loader.
    ;;
    ;; After the command has been processed, the `IO.ToDriver.command` value will be written to this port.
    COMMAND_ACK_PORT = $2140 ; APUIO0


    ;; The mode the S-SMP is currently executing.
    ;;
    ;; Used by both the loader and the audio-driver.
    ;;
    ;; NOTE: The IPL sets this value after at has cleared the zero-page.
    ;;       Do not read this value immediately after reset.
    ;;       Make sure enough time has passed for the IPL to set IO Port 1
    ;;       to $bb before reading this port.
    MODE_PORT = $2141 ; APUIO1

    ;; The S-SMP is at the start of the IPL, waiting for the ready signal.
    MODE_IPL = $bb

    ;; The S-SMP is running the loader.
    MODE_LOADER = $4c ; 'L', Loader.LOADER_READY_L

    ;; The S-SMP is running the audio-driver.
    MODE_AUDIO_DRIVER = $61 ; 'a'
.endscope


;; MUST match `audio-driver/src/io-commands.wiz`
.scope LoaderDataType
    ;; The `audio-driver.bin` file.
    ;; MUST be loaded first.
    CODE        = 0

    ;; Common audio data.
    ;; Contains samples, pitch table and sound effects.
    ;; MUST be loaded after `LoaderDataType.CODE` and before song data.
    COMMON_DATA = 1

    ;; Any value over `MIN_SONG_VALUE` will load song data
    ;; Song data MUST be loaded after `LoaderDataType.COMMON_DATA`.
    MIN_SONG_VALUE = 2

    ;; If this bit is set, the song will be played in stereo.
    ;; If this bit is clear, the song will be played in mono.
    ;;
    ;; MUST NOT be set when loading code or common-audio-data.
    STEREO_FLAG_BIT = 7
    STEREO_FLAG = 1 << STEREO_FLAG_BIT

    ;; If this bit is set, the song will play after the echo buffer has been cleared.
    ;; If this bit is clear, the audio driver will start in a paused state.
    ;;
    ;; MUST NOT be set when loading code or common-audio-data.
    PLAY_SONG_BIT = 6
    PLAY_SONG_FLAG = 1 << PLAY_SONG_BIT
.endscope


;; MUST match `audio-driver/src/io-commands.wiz`
.scope IO_Loader_Init
    LOADER_DATA_TYPE_PORT = $2141 ; APUIO1
    READY_PORT_L          = $2142 ; APUIO2
    READY_PORT_H          = $2143 ; APUIO3

    READY_PORT_HL         = $2142 ; APUIO2 & APUIO3

    LOADER_READY_L = %01001100  ; 'L'
    LOADER_READY_H = %01000100  ; 'D'
    LOADER_READY_HL = LOADER_READY_L | (LOADER_READY_H << 8)
.endscope


;; MUST match `audio-driver/src/io-commands.wiz`
.scope IO_Loader
    DATA_PORT_L   = $2141 ; APUIO1
    DATA_PORT_H   = $2142 ; APUIO2
    SPINLOCK_PORT = $2143 ; APUIO3

    ;; The spinlock value when the audio driver starts playing a song
    SPINLOCK_INIT_VALUE = 0

    ;; Only the lower 4 bits of the spinlock should be set while sending data to the loader
    SPINLOCK_MASK = $0f

    ;; Signal to the loader that the transfer has completed.
    SPINLOCK_COMPLETE = $80

    ;; If this value is written to the spinlock, the loader will restart;
    SPINLOCK_SWITCH_TO_LOADER = IO_ToDriver::SWITCH_TO_LOADER
.endscope


;; =========
;; Variables
;; =========


.enum State
    NULL                                = $00
    ;; Waiting for loader to send the ready signal.
    WAITING_FOR_LOADER                  = $7c
    ;; Loading common audio data.
    LOADING_COMMON_AUDIO_DATA           = $7d
    ;; Loading a song and the LoaderDataType::PLAY_SONG_FLAG was clear.
    LOADING_SONG_DATA_PAUSED            = $7e
    ;; Loading a song and the LoaderDataType::PLAY_SONG_FLAG was set.
    LOADING_SONG_DATA_PLAY              = $7f
    ;; Song is loaded into Audio-RAM and the audio driver is paused.
    ;; No play-sound-effect commands will be sent when the driver is paused.
    PAUSED                              = $80
    ;; Song is loaded into Audio-RAM and the audio driver is playing sfx (song paused).
    PLAYING_SFX                         = $81
    ;; Song is loaded into Audio-RAM and the audio driver is playing the song.
    PLAYING                             = $82
.endenum
__FIRST_LOADING_STATE      = State::LOADING_COMMON_AUDIO_DATA
__FIRST_LOADING_SONG_STATE = State::LOADING_SONG_DATA_PAUSED


.scope Flags
    ;; The mono/stereo flag
    ;;  * If set, the next song will be played in stereo.
    ;;  * If clear, the next song will be played in mono.
    ;; Default: Mono
    STEREO                   = LoaderDataType::STEREO_FLAG

    ;; Determines if the song is played immediately after loading into Audio-RAM
    ;;  * If set, the audio driver will play the song after the next song is loaded into Audio-RAM
    ;;  * If clear, the audio driver will be paused after the next song is loaded into Audio-RAM
    ;; Default: Set
    PLAY_SONG_IMMEDIATELY    = LoaderDataType::PLAY_SONG_FLAG

    ;; If set the *common audio data* will be loaded into Audio-RAM the next time a song is requested.
    ;;
    ;; This flag is cleared after the *common audio data* is loaded into Audio-RAM
    RELOAD_COMMON_AUDIO_DATA = 1 << 0


    ;; A mask for the flags that are sent to the loader
    _LOADER_MASK = STEREO | PLAY_SONG_IMMEDIATELY
.endscope


.bss
    ;; The current audio driver state
    ;; (`State` enum)
    Tad_state: .res 1

    ;; `Flags` bitfield
    ;; (see `Flags` namespace)
    Tad_flags: .res 1

    ;; Number of bytes to transfer per `Tad_Process` call
    ;;
    ;; MUST be > 0
    Tad_bytesToTransferPerFrame: .res 2

    ;; The previous `IO_ToScpu::COMMAND_PORT` sent to the S-SMP audio driver.
    Tad_previousCommand: .res 1


;; ---------------------------------------------------
;; Queue 1 - remaining data to transfer into Audio-RAM
;; ---------------------------------------------------
.bss
    ;; A far pointer to the remaining data to transfer
    Tad_dataToTransfer_addr: .res 2
    Tad_dataToTransfer_bank: .res 1

    ;; The remaining number of bytes to transfer
    Tad_dataToTransfer_size: .res 2

    ;; The previous value written to the loader spinLock
    Tad_dataToTransfer_prevSpinLock: .res 1


;; ----------------------------------------------
;; Queue 2 - The next song to load into Audio-RAM
;; ----------------------------------------------
.bss
    ;; The next song to load into Audio-RAM
    ;; Used by the `WAITING_FOR_LOADER` state
    ;; If this value is 0 or an invalid song, a blank silent song will be loaded instead.
    Tad_nextSong: .res 1


;; ------------------------------------------------------
;; Queue 3 - The next command to send to the audio driver
;; ------------------------------------------------------
.bss
    ;; The next `Command` to send to the audio driver.
    ;; MUST NOT be PLAY_SOUND_EFFECT_COMMAND.
    ;; If this value is negative, the queue is empty.
    Tad_nextCommand_id: .res 1

    ;; The parameter of the next next command (if any)
    Tad_nextCommand_parameter: .res 1


;; ---------------------------------------
;; Queue 4 - The next sound effect to play
;; ---------------------------------------
.zeropage
    ;; see tad-audio.inc
    Tad_sfxQueue_sfx: .res 1
    Tad_sfxQueue_pan: .res 1


;; Memory Map Asserts
;; ==================
.bss
    .assert (* > $100) && (* < $2000), lderror, ".bss is not in lowram"



;; ==================
;; Loader subroutines
;; ==================

.segment TAD_PROCESS_SEGMENT


;; Transfer and execute Loader using the IPL
;;
;; REQUIRES: S-SMP reset and no data has been written to it yet
;;
;; This macro MUST only be called once.  There is no way to reset the S-SMP and restart the IPL.
;;
;; A8
;; I16
;; DB access registers
.macro __Tad_Loader_TransferLoaderViaIpl
    .assert .asize = 8, error
    .assert .isize = 16, error

APUIO0 = $2140
APUIO1 = $2141
APUIO2 = $2142
APUIO3 = $2143

    ; Clear start command port (just in case APUIO0 has $cc in it)
    ; SOURCE: `blarggapu.s` from lorom-template, originally written by blargg (Shay Green)
    stz     APUIO0

    ; Wait for ready signal
    ldy     #$bbaa
    :
        cpy     APUIO0
        bne     :-

    ldx     #LOADER_ARAM_ADDR
    lda     #$cc
    stx     APUIO2              ; destination ARAM address
    sta     APUIO1              ; non-zero = write data to address
    sta     APUIO0              ; New data command (non-zero and APUIO0 + more than 2, or $cc on the first transfer)

    ; Wait for a response from the IPL
    :
        cmp     APUIO0
        bne     :-


    ; Transfer the data
    .assert Tad_Loader_SIZE < $ff, error, "Cannot fit Tad_Loader_SIZE in an 8 bit index"

    sep     #$30
.i8
    ldx     #0
    @IplLoop:
        ; Send the next byte to the IPL
        lda     f:Tad_Loader_Bin,x
        sta     APUIO1

        ; Tell the IPL the next byte is ready
        stx     APUIO0

        ; Wait for a response form the IPL
        :
            cpx     APUIO0
            bne     :-

        inx
        cpx     #Tad_Loader_SIZE
        bcc     @IplLoop

    rep     #$10
.i16

    ; Send an execute program command to the IPL
    ldx     #LOADER_ARAM_ADDR
    stx     APUIO2                  ; A-RAM address
    stz     APUIO1                  ; zero = execute program at A-RAM address
    lda     #Tad_Loader_SIZE + 2
    sta     APUIO0                  ; New data command (must be +2 the previous APUIO0 write)
.endmacro



;; Sends a LoaderDataType byte to the loader if the loader is ready
;;
;; Assumes loader just started OR a `SWITCH_TO_LOADER` message was sent to the audio driver/loader.
;;
;; IN: A = LoaderDataType value
;; OUT: carry = loader is ready and LoaderDataType sent
;;
.a8
.i16
;; DB access registers
.proc _Tad_Loader_CheckReadyAndSendLoaderDataType
    ; Test if the loader is ready
    ldx     #IO_Loader_Init::LOADER_READY_HL
    cpx     IO_Loader_Init::READY_PORT_HL
    bne     ReturnFalse
        ; Send the ready signal and the LoaderDataType
        sta     IO_Loader_Init::LOADER_DATA_TYPE_PORT

        lda     #IO_Loader_Init::LOADER_READY_L
        sta     IO_Loader_Init::READY_PORT_L

        lda     #IO_Loader_Init::LOADER_READY_H
        sta     IO_Loader_Init::READY_PORT_H

        ; The S-CPU must wait for the loader to write 0 to the spinlock before transferring data.
        stz     Tad_dataToTransfer_prevSpinLock

        ; return true
        sec
        rts

ReturnFalse:
    clc
    rts
.endproc



;; Set the data transfer queue
;;
;; IN: A:X = far address
;; IN: Y = size
.a8
.i16
;; DB access registers
.proc _Tad_Loader_SetDataToTransfer
    stx     Tad_dataToTransfer_addr
    sta     Tad_dataToTransfer_bank
    sty     Tad_dataToTransfer_size

    rts
.endproc



;; Transfer data to the audio loader.
;;
;; ASSUMES: `check_ready_and_send_loader_data_type` and `set_data_to_transfer` were previously called.
;;
;; NOTE: This function may read one byte past the end of the transfer queue.
;;
;; OUT: carry set if all data in the transfer queue was sent to Audio-RAM.
;;
.a8
.i16
;; DB access lowram
.proc _Tad_Loader_TransferData
    ; Early exit if the loader is not ready
    ;
    ; This test doubles as a lock for the previous transfer.
    ;
    ; This also prevents a freeze in `process()` if the loader has crashed/glitched.
    ; (`finish_loading_data()` will freeze if the loader has crashed/glitched.
    lda     Tad_dataToTransfer_prevSpinLock
    cmp     f:IO_Loader::SPINLOCK_PORT
    bne     @ReturnFalse

    phd
    phb

    rep     #$30
.a16

    ; Calculate number of words to read
    lda     Tad_dataToTransfer_size
    cmp     Tad_bytesToTransferPerFrame
    bcc     :+
        lda     Tad_bytesToTransferPerFrame
    :
    inc     ; required
    lsr

    ; Prevent corrupting all of Audio-RAM if number of words == 0
    bne     :+
        inc
    :
    ; Store word to read in X
    tax

    ; Reverse subtract Tad_dataToTransfer_size (with clamping)
    asl                             ; convert number of words to number of bytes
    eor     #$ffff
    sec
    adc     Tad_dataToTransfer_size
    bcs     :+
        lda     #0
    :
    sta     Tad_dataToTransfer_size


    lda     #$2100
    tcd
; D = $2100

    sep     #$20
.a8

    lda     Tad_dataToTransfer_bank
    ldy     Tad_dataToTransfer_addr

    pha
    plb
; DB = Tad_dataToTransfer_bank

    @Loop:
        ; x = number of words remaining
        ; y = data address (using y to force addr,y addressing mode)

        lda     a:0,y
        sta     z:.lobyte(IO_Loader::DATA_PORT_L)

        ; The bank overflow test must be done here as `Tad_dataToTransfer_addr` might point to an odd memory address.
        iny
        beq     @BankOverflow_1
    @BankOverflow_1_Resume:

        lda     a:0,y
        sta     z:.lobyte(IO_Loader::DATA_PORT_H)

        ; Increment this spinloack value
        ;
        ; The upper 4 bits of the spinlock must be clear'
        ; Cannot be 0.  Zero is used to spinlock the loader init before this loop starts
        ;               (see Loader Step 3 in `terrific-audio-driver/audio-driver/src/io-commands.wiz`)

        .assert ($ffff & 7) + 1 < IO_Loader::SPINLOCK_MASK, error
        tya             ; y = address of data, it should always increment by 2
        and     #7
        inc
        sta     z:.lobyte(IO_Loader::SPINLOCK_PORT)

        iny
        beq     @BankOverflow_2
    @BankOverflow_2_Resume:

        dex
        beq     @EndLoop

        ; Spinloop until the S-SMP has acknowledged the data
        :
            cmp     z:.lobyte(IO_Loader::SPINLOCK_PORT)
            bne     :-

        bra     @Loop
@EndLoop:

    plb
    pld
; DB restored
; D = 0

    sty     Tad_dataToTransfer_addr
    sta     Tad_dataToTransfer_prevSpinLock


    ldy     Tad_dataToTransfer_size
    bne     @ReturnFalse
        ; End of data transfer

        ; Wait for Loader to acknowledge the last write
        :
            cmp     f:IO_Loader::SPINLOCK_PORT
            bne     :-

        ; No more data to transfer
        lda     #IO_Loader::SPINLOCK_COMPLETE
        sta     f:IO_Loader::SPINLOCK_PORT

        sec
        rts

@ReturnFalse:
    clc
    rts


@BankOverflow_1:
    jsr     __Tad_Loader_GotoNextBank
    bra     @BankOverflow_1_Resume

@BankOverflow_2:
    ; Must save/restore A, it holds the spinlock
    pha
        jsr     __Tad_Loader_GotoNextBank
    pla
    bra     @BankOverflow_2_Resume
.endproc


;; Advance to the next bank
;;
;; MUST only be called to _Tad_Loader_TransferData
;;
;; ASSUMES: Y = 0 (Y addr overflowed to 0)
;;
;; IN: Y = 0
;; IN: DB = Tad_dataToTransfer_bank
;;
;; OUT: Y = new address
;; OUT: DB = new bank
;;
;; KEEP: X
.a8
.i16
;; DB = Tad_dataToTransfer_bank
.proc __Tad_Loader_GotoNextBank
    phb
    pla

    inc
    sta     f:Tad_dataToTransfer_bank

    pha
    plb
; DB = new Tad_dataToTransfer_bank value

    ; MUST NOT CHANGE X

    ; Y = 0
    .if .defined(LOROM)
        and     #$fe
        cmp     #$7e
        beq     :+
            ; Bank is not Work-RAM
            ldy     #$8000
        :
    .elseif .defined(HIROM)
        and     #$7f
        cmp     #$40
        bcs     :+
            ; Bank is a register bank
            ; set Y to the first ROM address
            ldy     #$8000
        :
    .else
        .error "Unknown memory map"
    .endif

    ; Y = 0 or $8000
    rts
.endproc


;; OUT: carry set if state is LOADING_*
;; A8
.macro __Tad_IsLoaderActive
    .assert .asize = 8, error

    .assert State::NULL < __FIRST_LOADING_STATE, error
    .assert State::WAITING_FOR_LOADER < __FIRST_LOADING_STATE, error
    .assert (State::PAUSED & $7f) < __FIRST_LOADING_STATE, error
    .assert (State::PLAYING & $7f) < __FIRST_LOADING_STATE, error

    lda     Tad_state
    and     #$7f
    cmp     #__FIRST_LOADING_STATE
.endmacro


;; ==========
;; Public API
;; ==========

;; -------------------------------
;; TAD_PROCESS_SEGMENT subroutines
;; -------------------------------

.segment TAD_PROCESS_SEGMENT


; JSL/RTL subroutine
.a8
.i16
; DB unknown
.proc Tad_Init : far
    phb

    lda     #$80
    pha
    plb
; DB = $80

    __Tad_Loader_TransferLoaderViaIpl

    lda     #Flags::RELOAD_COMMON_AUDIO_DATA | Flags::PLAY_SONG_IMMEDIATELY
    sta     Tad_flags

    ldx     #DEFAULT_TRANSFER_PER_FRAME
    stx     Tad_bytesToTransferPerFrame

    lda     #.bankbyte(Tad_AudioDriver_Bin)
    ldx     #.loword(Tad_AudioDriver_Bin)
    ldy     #Tad_AudioDriver_SIZE
    jsr     _Tad_Loader_SetDataToTransfer

    lda     #$ff
    sta     Tad_nextCommand_id
    sta     Tad_sfxQueue_sfx

    stz     Tad_nextSong

    @DataTypeLoop:
        lda     #LoaderDataType::CODE
        jsr     _Tad_Loader_CheckReadyAndSendLoaderDataType
        bcc     @DataTypeLoop

    @TransferLoop:
        jsr     _Tad_Loader_TransferData
        bcc     @TransferLoop

    lda     #State::WAITING_FOR_LOADER
    sta     Tad_state

    plb
; DB restored
    rtl
.endproc


;; Sends a command to the audio driver.
;;
;; REQUIRES: state == PAUSED or state == PLAYING.
;; REQUIRES: The previous command has been processed by the audio-driver.
;; REQUIRES: `Tad_nextCommand_id` is not a play-sound-effect command.
;; REQUIRES: `Tad_nextCommand_id` is a valid comma.
;;
;; IN: Y = Tad_nextCommand_id
.a8
.i8
;; DB access lowram
.macro __Tad_Process_SendCommand
    .assert .asize = 8, error
    .assert .isize = 8, error

    lda     Tad_nextCommand_parameter
    sta     f:IO_ToDriver::PARAMETER0_PORT

    lda     Tad_previousCommand
    and     #IO_ToDriver::COMMAND_I_MASK    ; Clear the non i bits of the command
    eor     #IO_ToDriver::COMMAND_I_MASK    ; Flip the i bits
    ora     Tad_nextCommand_id              ; Set the c bits
    sta     f:IO_ToDriver::COMMAND_PORT
    sta     Tad_previousCommand

    cpy     #Command::UNPAUSE + 1
    bcs     @NotPauseOrPlay
        ; Change state if the command is a pause or play command
        .assert Command::PAUSE = 0, error
        .assert Command::PAUSE_MUSIC_PLAY_SFX = 2, error
        .assert Command::UNPAUSE = 4, error
        .assert (Command::PAUSE >> 1) & 3 | $80 = State::PAUSED, error
        .assert (Command::PAUSE_MUSIC_PLAY_SFX >> 1) & 3 | $80 = State::PLAYING_SFX, error
        .assert (Command::UNPAUSE >> 1) & 3 | $80 = State::PLAYING, error
        lsr
        and     #3
        ora     #$80
        sta     Tad_state
@NotPauseOrPlay:

    ; Reset command queue
    lda     #$ff
    sta     Tad_nextCommand_id
.endmacro



;; Send a play-sound-effect command to the audio driver.
;;
;; REQUIRES: state == PLAYING
;; REQUIRES: The previous command has been processed by the audio-driver.
;;
;; IN: A = Tad_sfxQueue_sfx
;;
;; A8
;; I8
;; DB access lowram
.macro __Tad_Process_SendSfxCommand
    .assert .asize = 8, error
    .assert .isize = 8, error

    ; parameter 0 = sfx_id
    sta     f:IO_ToDriver::PARAMETER0_PORT

    ; parameter 1 = pan
    lda     Tad_sfxQueue_pan
    cmp     #MAX_PAN + 1
    bcc     :+
        lda     #CENTER_PAN
    :
    sta     f:IO_ToDriver::PARAMETER1_PORT

    ; Send play-sound-effect command
    lda     Tad_previousCommand
    and     #IO_ToDriver::COMMAND_I_MASK            ; Clear the non i bits of the command
    eor     #IO_ToDriver::COMMAND_I_MASK            ; Flip the i bits
    ora     #Command::PLAY_SOUND_EFFECT_COMMAND     ; Set the c bits

    sta     f:IO_ToDriver::COMMAND_PORT
    sta     Tad_previousCommand

    ; Reset the SFX queue
    ldy     #$ff
    sty     Tad_sfxQueue_sfx
    sty     Tad_sfxQueue_pan
.endmacro



; JSL/RTL subroutine
.a8
.i16
; DB access lowram
.proc Tad_Process : far
    .assert State::PAUSED = $80, error
    .assert State::PLAYING > $80, error
    lda     Tad_state
    bpl     @NotLoaded
        ; Playing or paused state
        sep     #$10
    .i8
        tax

        lda     Tad_previousCommand
        cmp     f:IO_ToScpu::COMMAND_ACK_PORT
        bne     @Return_I8
            ; Previous command has been processed

            ; Check command queue
            ldy     Tad_nextCommand_id
            bpl     @SendCommand

            ; X = Tad_state
            .assert State::PAUSED < $81, error
            .assert State::PLAYING >= $81, error
            .assert State::PLAYING_SFX >= $81, error
            dex
            bpl     @Return_I8
                ; Playing state
                lda     Tad_sfxQueue_sfx
                cmp     #$ff
                beq     @Return_I8
                    __Tad_Process_SendSfxCommand

        @Return_I8:
            rep     #$10
        .i16
            rtl

        .a8
        .i8
        @SendCommand:
            __Tad_Process_SendCommand
            rep     #$10
        .i16
            rtl

    @NotLoaded:
        ; Song is not loaded into Audio-RAM

        ; Test if state is WAITING_FOR_LOADER or LOADING_*
        .assert __FIRST_LOADING_STATE = State::WAITING_FOR_LOADER + 1, error
        cmp     #State::WAITING_FOR_LOADER
        beq     __Tad_Process_WaitingForLoader
        bcs     __Tad_Process_Loading

    ; State is null
    rtl
.endproc



;; Process the WAITING_FOR_LOADER state
;;
;; return using RTL
.a8
.i16
;; DB access lowram
.proc __Tad_Process_WaitingForLoader ; RTL
    phb

    ; Setting DB to access registers as it:
    ;  * Simplifies `_Tad_Loader_CheckReadyAndSendLoaderDataType`
    ;  * Ensures `LoadAudioData` is called with a fixed data bank
    ;    (NOTE: `LoadAudioData` is tagged `DB access registers`)
    lda     #$80
    pha
    plb
; DB = $80

    lda     Tad_flags
    bit     #Flags::RELOAD_COMMON_AUDIO_DATA
    beq     @SongData
        ; Common audio data
        lda     #LoaderDataType::COMMON_DATA
        jsr     _Tad_Loader_CheckReadyAndSendLoaderDataType
        bcc     @Return

        ; Clear the RELOAD_COMMON_AUDIO_DATA flag
        ;
        ; It is safe to do this before the data is loaded into audio-RAM.
        ; `Tad_LoadSong` will not restart the loader if state == LOADING_COMMON_AUDIO_DATA.
        lda     #Flags::RELOAD_COMMON_AUDIO_DATA
        trb     Tad_flags

        lda     #State::LOADING_COMMON_AUDIO_DATA
        pha

        lda     #0
        bra     @LoadData

    @SongData:
        ; Songs

        ; a = Tad_flags
        and     #Flags::_LOADER_MASK
        ora     #LoaderDataType::MIN_SONG_VALUE
        jsr     _Tad_Loader_CheckReadyAndSendLoaderDataType
        bcc     @Return

        ; Determine next state
        .assert Flags::PLAY_SONG_IMMEDIATELY = $40, error
        .assert State::LOADING_SONG_DATA_PAUSED + 1 = State::LOADING_SONG_DATA_PLAY, error
        lda     Tad_flags
        asl
        asl
        lda     #0
        ; carry = PLAY_SONG_IMMEDIATELY flag
        adc     #State::LOADING_SONG_DATA_PAUSED
        pha

        ; Load next song
        lda     Tad_nextSong
        beq     @UseBlankSong

@LoadData:
    jsl     LoadAudioData
    bcs     :+
        ; LoadAudioData returned false
    @UseBlankSong:
        lda     #.bankbyte(Tad_BlankSong_Bin)
        ldx     #.loword(Tad_BlankSong_Bin)
        ldy     #Tad_BlankSong_SIZE
    :

    ; STACK holds next state
    ; A:X = data address
    ; Y = data size
    jsr     _Tad_Loader_SetDataToTransfer

    pla
    sta     Tad_state

@Return:
    plb
; DB restored
    rtl
.endproc



;; Process the LOADING_* states
;;
;; return using RTL
.a8
.i16
;; DB access lowram
.proc __Tad_Process_Loading ; RTL
    jsr     _Tad_Loader_TransferData
    bcc     @Return
        ; Data loaded successfully
        lda     Tad_state
        cmp     #State::LOADING_COMMON_AUDIO_DATA
        bne     @Song
            ; Common audio data was just transferred
            ; Loader is still active
            lda     #State::WAITING_FOR_LOADER
            bra     @EndIf

        @Song:
            ; song data was loaded into Audio-RAM
            ; Loader has finished, audio driver is now active

            stz     Tad_previousCommand

            ; Reset command and SFX queues
            lda     #$ff
            sta     Tad_nextCommand_id
            sta     Tad_sfxQueue_sfx
            sta     Tad_sfxQueue_pan

            ; Use `Tad_state` to determine if the song is playing or paused.
            ; Cannot use `Tad_flags` as it may have changed after the `LoaderDataType` was sent to
            ; the loader (while the song was loaded).
            .assert ((State::LOADING_SONG_DATA_PAUSED & 1) << 1) | $80 = State::PAUSED, error
            .assert ((State::LOADING_SONG_DATA_PLAY & 1) << 1) | $80 = State::PLAYING, error
            lda     Tad_state
            and     #1
            asl
            ora     #$80

        ; A = new state
    @EndIf:
        sta     Tad_state

@Return:
    rtl
.endproc



; JSL/RTL subroutine
.a8
.i16
; DB access lowram
.proc Tad_FinishLoadingData : far
    @Loop:
        __Tad_IsLoaderActive
        bcc     @EndLoop
            jsl     __Tad_Process_Loading
        bra     @Loop
    @EndLoop:

    rtl
.endproc


;; ----------------------------
;; TAD_CODE_SEGMENT subroutines
;; ----------------------------

.segment TAD_CODE_SEGMENT


; IN: A = command
; IN: X = parameter
; OUT: Carry set if command added to queue
.a8
; I unknown
; DB access lowram
.proc Tad_QueueCommand
    bit     Tad_nextCommand_id
    bpl     ReturnFalse
        ; command queue is empty
    WriteCommand:
        and     #IO_ToDriver::COMMAND_MASK
        sta     Tad_nextCommand_id

        txa
        sta     Tad_nextCommand_parameter

        ; return true
        sec
        rts

ReturnFalse:
    clc
    rts
.endproc


; IN: A = command
; IN: X = parameter
.a8
; I unknown
; DB access lowram
Tad_QueueCommandOverride := Tad_QueueCommand::WriteCommand



; IN: A = sfx id
; IN: X = pan
.a8
; I unknown
; DB access lowram
; KEEP: X, Y
.proc Tad_QueuePannedSoundEffect
    cmp     Tad_sfxQueue_sfx
    bcs     @EndIf
        sta     Tad_sfxQueue_sfx

        txa
        sta     Tad_sfxQueue_pan

@EndIf:
    rts
.endproc



; IN: A = sfx_id
.a8
; I unknown
; DB access lowram
; KEEP: X, Y
.proc Tad_QueueSoundEffect
    cmp     Tad_sfxQueue_sfx
    bcs     @EndIf
        sta     Tad_sfxQueue_sfx

        lda     #CENTER_PAN
        sta     Tad_sfxQueue_pan
@EndIf:
    rts
.endproc



; IN: A = song_id
.a8
; I unknown
; DB access lowram
.proc Tad_LoadSong
    .assert __FIRST_LOADING_SONG_STATE > State::NULL, error
    .assert __FIRST_LOADING_SONG_STATE > State::WAITING_FOR_LOADER, error
    .assert __FIRST_LOADING_SONG_STATE > State::LOADING_COMMON_AUDIO_DATA, error

    sta     Tad_nextSong

    lda     Tad_state
    cmp     #__FIRST_LOADING_SONG_STATE
    bcc     :+
        ; State is not NULL, WAITING_FOR_LOADER or LOADING_COMMON_AUDIO_DATA

        ; Send a *switch-to-loader* command to the audio-driver or loader
        lda     #IO_ToDriver::SWITCH_TO_LOADER
        sta     f:IO_ToDriver::SWITCH_TO_LOADER_PORT

        lda     #State::WAITING_FOR_LOADER
        sta     Tad_state
    :
    rts
.endproc


; IN: A = song_id
; OUT: carry set if `Tad_LoadSong` was called
.a8
; I unknown
; DB access lowram
.proc Tad_LoadSongIfChanged
    cmp     Tad_nextSong
    beq     :+
        jsr     Tad_LoadSong
        sec
        rts
    :
    clc
    rts
.endproc


;; OUT: A = The song_id used in the last `Tad_LoadSong` call.
.a8
; I unknown
; DB access lowram
.proc Tad_GetSong
    ; `Tad_nextSong` is only written to in `Tad_Init` and `Tad_LoadSong`.
    lda     Tad_nextSong
    rts
.endproc


.a8
; I unknown
; DB access lowram
.proc Tad_ReloadCommonAudioData
    lda     #Flags::RELOAD_COMMON_AUDIO_DATA
    tsb     Tad_flags
    rts
.endproc


.a8
; I unknown
; DB access lowram
.proc Tad_SetMono
    lda     #Flags::STEREO
    trb     Tad_flags
    rts
.endproc


.a8
; I unknown
; DB access lowram
.proc Tad_SetStereo
    lda     #Flags::STEREO
    tsb     Tad_flags
    rts
.endproc


; OUT: carry set if stero
.a8
; I unknown
; DB access lowram
.proc Tad_GetStereoFlag
    .assert Flags::STEREO = $80, error
    lda     Tad_flags
    cmp     #Flags::STEREO
    rts
.endproc


.a8
; I unknown
; DB access lowram
.proc Tad_SongsStartImmediately
    lda     #Flags::PLAY_SONG_IMMEDIATELY
    tsb     Tad_flags
    rts
.endproc


.a8
; I unknown
; DB access lowram
.proc Tad_SongsStartPaused
    lda     #Flags::PLAY_SONG_IMMEDIATELY
    trb     Tad_flags
    rts
.endproc


; IN: X = new `Tad_bytesToTransferPerFrame` value
; A unknown
.i16
; DB access lowram
.proc Tad_SetTransferSize
    cpx     #MAX_TRANSFER_PER_FRAME
    bcc     :+
        ldx     #MAX_TRANSFER_PER_FRAME
    :
    cpx     #MIN_TRANSFER_PER_FRAME
    bcs     :+
        ldx     #MIN_TRANSFER_PER_FRAME
    :
    stx     Tad_bytesToTransferPerFrame

    rts
.endproc



; OUT: carry set if state is LOADING_*
.a8
; I unknown
; DB access lowram
.proc Tad_IsLoaderActive
    __Tad_IsLoaderActive
    rts
.endproc



; OUT: carry set if state is PAUSED, PLAYING_SFX or PLAYING
.a8
; I unknown
; DB access lowram
.proc Tad_IsSongLoaded
    .assert State::PLAYING_SFX > State::PAUSED, error
    .assert State::PLAYING > State::PAUSED, error
    ; Assumes PLAYING is the last state

    lda     Tad_state
    cmp     #State::PAUSED
    rts
.endproc



; OUT: carry set if state is PLAYING_SFX or PLAYING
.a8
; I unknown
; DB access lowram
.proc Tad_IsSfxPlaying
    .assert State::PLAYING > State::PLAYING_SFX, error
    ; Assumes PLAYING is the last state

    lda     Tad_state
    cmp     #State::PLAYING_SFX
    rts
.endproc



; OUT: carry set if state is PLAYING
.a8
; I unknown
; DB access lowram
.proc Tad_IsSongPlaying
    ; Assumes PLAYING is the last state

    lda     Tad_state
    cmp     #State::PLAYING
    rts
.endproc


