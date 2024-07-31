;; Terrific Audio Driver ca65 API

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


; Required to import symbols with far addressing
.p816


;; ===
;; ABI
;; ===
;;
;; All subroutines MUST called with the following register state:
;;  * 65816 native mode
;;  * Decimal mode off
;;  * 8 bit Memory
;;  * 16 bit Index, unless the subroutine is tagged `I unknown`
;;  * `D` Direct Page = 0
;;  * `DB` Data Bank Register accesses low-RAM (`$7e or $00..=$3f or $80..=$bf`).
;;    * EXCEPTION: The `LoadAudioData` callback.
;;
;; These subroutines MUST NOT be called in an interrupt ISR.  They are not thread-safe.
;;
;; `Tad_Init` MUST be called first, before any other `Tad_*` subroutine.
;; `Tad_Init` has additional restrictions.  See `Tad_Init` documentation for more details.
;;
;; `tad-audio.s` MUST BE the only code that accesses the $2140 - $2143 APUIO registers.
;;



;; ==================
;; External Resources
;; ==================
;;
;; To increase compatibility with existing resource subsystems, `tad-audio.s` does not embed
;; the audio driver or audio data into the ROM.
;;
;; The audio driver is divided into 3 files
;; (see the *Binary Data* section of `tad-audio.s` for more details):
;;
;;  * `loader.bin` - the custom spc700 loader.  Imported as `Tad_Loader_Bin`, `Tad_Loader_SIZE`.
;;  * `audio-driver.bin` - the spc700 audio driver.  Imported as `Tad_AudioDriver_Bin`, `Tad_AudioDriver_SIZE`.
;;  * `blank-song.bin` - a blank (silent) song.  Imported as `Tad_BlankSong_Bin`, `Tad_BlankSong_SIZE`.
;;
;; Audio data is loaded using the external callback `LoadAudioData`.  `LoadAudioData` is
;; called when *Common Audio Data* or *Song Data* need to be loaded into Audio-RAM.
;; Please see the `CALLBACKS` section for more details, as `LoadAudioData` has complex timing
;; requirements.
;;
;; There is no bounds checking in `tad-audio.s`.
;;  * `LoadAudioData` is responsible for determining if the input to `Tad_LoadSong` is valid.
;;  * The audio driver (*Common Audio Data*) is responsible for determining if the *sfx id*
;;    is valid.
;;
;; The `tad-compiler ca65-export` command can output a single uncompressed binary file that
;; contains the audio-driver and audio-data and an assembly file that contains audio driver
;; exports and `LoadAudioData` callback.
;;
;; Alternatively, the developer can create their own `LoadAudioData` callback subroutine and
;; populate the ROM with the output of the `tad-compiler common` and `tad-compiler song`
;; commands.



;; =========
;; Constants
;; =========


;; Maximum pan value (100% to the right)
MAX_PAN = 128

;; Center pan value (default if pan is not specified)
CENTER_PAN = MAX_PAN / 2

;; Minimum tick clock value for the `TadCommand::SET_SONG_TEMPO` command.
MIN_TICK_CLOCK = 64



;; Terrific Audio Driver IO commands
;;
; MUST match `audio-driver/src/io-commands.wiz`
.enum TadCommand
    ;; Pause the song and sound effect channels.
    ;; * IO commands will still be executed when the audio-driver is paused.
    ;; * The audio driver starts paused unless the `LoaderDataType.PLAY_SONG_BIT` is set.
    PAUSE = 0

    ;; Pauses the music channels, sound effects will continue to play.
    ;; Unpauses the sound effects channels.
    PAUSE_MUSIC_PLAY_SFX = 2

    ;; Unpauses the music and sound effect channels.
    UNPAUSE = 4

    ; SHOULD NOT USE PLAY_SOUND_EFFECT in `queue_command`
    ; (command queue only holds 1 parameter byte and PLAY_SOUND_EFFECT has 2 parameters)

    ;; Stop all active sound effects
    STOP_SOUND_EFFECTS = 8

    ;; Set the main volume
    ;;  * parameter0: signed i8 volume
    ;;
    ;; NOTE: The main volume is reset whenever a new song is loaded.
    SET_MAIN_VOLUME = 10

    ;; Enables or disables music channels.
    ;;  * parameter0: A bitmask of the 8 music channels that can send key-on events
    ;;
    ;; NOTE: The music channels bitmask is reset whenever a new song is loaded.
    SET_MUSIC_CHANNELS = 12

    ;; Set the song tempo.
    ;;  * parameter0: The new S-DSP TIMER_0 register value
    ;;    (MUST be >= MIN_TICK_CLOCK 64, is bounds checked)
    ;;
    ;; NOTE: The song can still change the tempo.
    SET_SONG_TEMPO = 14
.endenum


;; ===========
;; Subroutines
;; ===========


;; Initialises the audio driver:
;;
;;  * Loads the loader into Audio-RAM
;;  * Loads the audio driver into Audio-RAM
;;  * Sets the song to 0 (silence)
;;  * Resets variables
;;  * Sets the flags
;;      * Sets the *Reload Common Audio Data* flag
;;      * Sets the *Play Song Immediately* flag
;;      * Clears the *Stereo* flag (mono output)
;;  * Queues a common audio data transfer
;;
;; This function will require multiple frames of execution time.
;;
;; REQUIRES: S-SMP reset
;;
;; TIMING:
;;  * Should be called more than 40 scanlines after reset
;;  * MUST be called ONCE
;;     * Calling `Tad_Init` more than once will hardlock.
;;  * MUST be called with INTERRUPTS DISABLED
;;  * MUST be called while the S-SMP is running the IPL.
;;  * MUST be called after the `LoadAudioData` callback is setup (if necessary)
;;  * `Tad_Init` MUST be called before any other TAD subroutine.
;;
;; Called with JSL long addressing (returns with RTL).
;; A8
;; I16
;; DB unknown
.import Tad_Init : far


;; Processes the next queue.
;;
;; This function will do one of the following, depending on the state:
;;  * Transfer data to the Audio-RAM
;;  * Wait for the loader and call the `LoadAudioData` callback when the loader is ready to receive new data
;;  * Send a command to the audio driver
;;  * Send a play-sound effect command to the audio driver
;;
;; NOTE: The command and sound-effect queues will be reset after a new song is loaded into Audio-RAM.
;;
;; TIMING:
;;  * MUST be called after `Tad_Init`.
;;  * Should be called once per frame.
;;  * MUST NOT be called in an interrupt ISR.
;;
;; Called with JSL long addressing (returns with RTL).
;; A8
;; I16
;; DB access lowram
.import Tad_Process : far


;; Finish loading the data into audio-RAM.
;;
;; `Tad_FinishLoadingData` will not transfer data if the state is `WAITING_FOR_LOADER`.
;; It will only transfer data if the loader is in the middle of transferring data
;; (when `Tad_IsLoaderActive` returns true).
;;
;; This function can be safely called by `LoadAudioData`.
;;
;; This function may require multiple frames of execution time.
;;
;; Called with JSL long addressing (returns with RTL).
;; A8
;; I16
;; DB access lowram
.import Tad_FinishLoadingData : far


;; Adds a command to the queue if the queue is empty.
;;
;; The command queue can only hold 1 command.
;; Returns true if the command was added to the queue.
;;
;; MUST NOT be used to send a play-sound-effect command.
;;
;; IN: A = `TadCommand` value
;; IN: X = Command parameter (if any). Only the lower 8 bits will be sent to the Audio Driver.
;;
;; OUT: Carry set if the command was added to the queue
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_QueueCommand


;; Adds a command to the queue, overriding any previously unsent commands.
;;
;; MUST NOT be used to send a play-sound-effect command.
;; The command queue can only hold 1 command.
;;
;; IN: A = `TadCommand` value
;; IN: X = Command parameter (if any). Only the lower 8 bits will be sent to the Audio Driver.
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_QueueCommandOverride


;; Queue the next sound effect to play, with panning.
;;
;; NOTE: Only 1 sound effect can be played at a time
;; NOTE: Lower sound effect IDs take priority over higher sound effect IDs.
;;
;; IN: A = sfx id (as determined by the sound effect export order in the project file)
;; IN: X = pan (only the lower 8 bits are used.  If `pan > MAX_PAN`, the sound effect will use center pan)
;;
;; A8
;; I unknown
;; DB access lowram
;; KEEP: Y, X
.import Tad_QueuePannedSoundEffect


;; Queue the next sound effect to play with center pan (MAX_PAN/2).
;;
;; NOTE: Only 1 sound effect can be played at a time.
;; NOTE: Lower sound effect IDs take priority over higher sound effect IDs.
;;
;; IN: A = sfx id (as determined by the sound effect export order in the project file)
;;
;; A8
;; I unknown
;; DB access lowram
;; KEEP: Y, X
.import Tad_QueueSoundEffect


;; Disables the audio driver, starts the loader and queues a song transfer.
;;
;; This function will not restart the loader if the loader is loading common audio data.
;;
;; CAUTION: The audio driver starts in the paused state if the `PlaySongImmediately` flag is false.
;;
;; CAUTION: `Tad_LoadSong` will switch the state to `WAITING_FOR_LOADER`.  `LoadAudioData` will
;; not be called until `Tad_Process` is called **and** the audio-driver has switched to the loader.
;; While the state remains `WAITING_FOR_LOADER`, no audio data will be transferred and calling
;; `Tad_FinishLoadingData` will not transfer any audio data.
;;
;; IN: A = 0 - play a blank (silent song)
;; IN: A >= 1 - Play song number `A`
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_LoadSong


;; Calls `Tad_LoadSong` if `A` != the song_id used in the last `Tad_LoadSong` call.
;;
;; See `Tad_LoadSong` for details about how songs are loaded into the audio driver.
;;
;; IN: A = 0 - play a blank (silent song)
;; IN: A >= 1 - Play song number `A`
;;
;; OUT: Carry set if the song_id changed and `Tad_LoadSong` was called.
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_LoadSongIfChanged


;; Returns the current song id in the A register.
;;
;; OUT: A = The song_id used in the last `Tad_LoadSong` call.
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_GetSong


;; If this subroutine is called, the *common audio data* will be reloaded into Audio-RAM.
;; This will not take effect until the next song is loaded into Audio-RAM.
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_ReloadCommonAudioData


;; Clears the stereo flag.
;; This will not take effect until the next song is loaded into Audio-RAM.
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_SetMono


;; Set the stereo flag.
;; This will not take effect until the next song is loaded into Audio-RAM.
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_SetStereo


;; Reads the mono/stereo flag
;;
;; OUT: Carry set if stereo
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_GetStereoFlag


;; Sets the `PlaySongImmediately` flag
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_SongsStartImmediately


;; Clears the `PlaySongImmediately` flag
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_SongsStartPaused


;; Sets the number of bytes to transfer to Audio-RAM per `Tad_Process` call.
;;
;; The value will be clamped from `MIN_TRANSFER_PER_FRAME` to `MAX_TRANSFER_PER_FRAME`.
;;
;; IN: X = number of bytes to transfer on every `Tad_Process` call.
;;
;; A unknown
;; I16
;; DB access lowram
.import Tad_SetTransferSize


;; OUT: Carry set if the loader is still using data returned by `LoadAudioData` (state == `LOADING_*`)
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_IsLoaderActive


;; OUT: Carry set if the song is loaded into audio-RAM (state is `PAUSED`, `PLAYING_SFX` or `PLAYING`)
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_IsSongLoaded


;; OUT: Carry set if the song is loaded into audio-RAM and sound effects are not paused
;;      (state is `PLAYING_SFX` or `PLAYING`)
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_IsSfxPlaying


;; OUT: Carry set if the song is playing (state is `PLAYING`)
;;
;; A8
;; I unknown
;; DB access lowram
.import Tad_IsSongPlaying


;; =========
;; Variables
;; =========

;; Sound Effect Queue
;; ==================
;;
;; This queue is read by `Tad_Process` and a `play_sound_effect` command is sent to the audio driver when:
;;  * A song is loaded into Audio-RAM
;;  * Sound effects are playing (not paused)
;;  * The previous command sent to the audio driver has been acknowledged
;;  * The command queue is empty
;;  * `Tad_sfxQueue_sfx != $ff`
;;
;; If `Tad_sfxQueue_pan > MAX_PAN`, then `CENTER_PAN` will be used instead.
;;
;; After the `play_sound_effect` command (or when a song is loaded), `Tad_sfxQueue_sfx` and
;; `Tad_sfxQueue_pan` will be reset to $ff.
;;
;; In `Tad_QueueSoundEffect` lower sound effect indexes take priority over higher sound effect
;; indexes (as defined by the project file sound effect export order).
;;
;;
;; The sound-effect queue variables are public to allow for custom queue sound-effect subroutines.
;; For example, a queue-sound-effect subroutine with a different ABI or copies of
;; `Tad_QueueSoundEffect` in multiple banks, etc.


;; The next sound effect id to send to the audio driver.
;;
;; If `Tad_sfxQueue_sfx == $ff` then the queue is considered empty.
;;
;; (zeropage u8)
.importzp Tad_sfxQueue_sfx


;; The pan value to play `Tad_sfxQueue_sfx` with.
;;
;; If this value is greater than `MAX_PAN`, then `CENTER_PAN` will be used instead.
;;
;; (zeropage u8)
.importzp Tad_sfxQueue_pan



;; =========
;; CALLBACKS
;; =========

;; LoadAudioData
;; =============
;;
;; This callback will be called by `Tad_Process` when the common audio data or song
;; data need to be loaded into Audio-RAM.
;;
;; This subroutine is responsible for determining if the input is a valid song.
;; If the input is *common audio data* this function MUST return data with carry set.
;;
;; This subroutine can be generated by `tad-compiler`. Alternatively, the developer
;; can create their own `LoadAudioData` subroutine if they wish to use their own
;; resources subsystem or want to use compressed song data.
;;
;; The data is allowed to cross bank boundaries. When the data crosses a bank
;; boundary, the data pointer is advanced to start of the next bank (as determined
;; by the bank byte and memory map).
;;
;;
;; This callback is called with JSL long addressing, it MUST RETURN using the RTL
;; instruction.
;;
;;
;; The `DB` Data Bank Register does NOT point to low-RAM.
;;
;; IN: A = 0  - load *common audio data*
;;              (This function MUST return carry set with a valid address/size if A=0)
;; IN: A >= 1 - load *song data*
;;
;; OUT: Carry set if input (`A`) was valid
;; OUT: A:X = far address (only read if carry set)
;; OUT:   Y = data size (only read if carry set)
;;
;; LIFETIME:
;;
;;  * The data MUST remain in memory while it is being transferred to Audio-RAM
;;    (which may take several frames).
;;  * The data can be freed on the next `LoadAudioData` call.
;;  * The data can be freed when the state changes to PAUSED, PLAYING_SFX or PLAYING.
;;  * The data can be freed if the `Tad_IsLoaderActive` function returns false.
;;  * The `Tad_FinishLoadingData` subroutine can be used to flush decompressed
;;    memory into Audio-RAM.  The data can be freed immediately after a
;;    `Tad_FinishLoadingData` call.
;;
;; This function MUST NOT call `Tad_Process` or `Tad_LoadSong`.
;; It is allowed to call `Tad_FinishLoadingData`.
;;
;;
;; Called with JSL long addressing (returns with RTL).
;; A8
;; I16
;; DB access registers


