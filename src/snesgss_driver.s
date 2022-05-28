.setcpu "none"
.include "spc-65c02.inc"
.export spc_entry, GSS_MusicUploadAddress, SongDirectory

UPDATE_RATE_HZ	= 160   ;quantization of music events
BRR_STREAMING = 0       ;set to one to turn on streaming

CHANNEL_COUNT = 11
FIRST_SFX_CHANNEL = 8

;---Memory layout---
; $0000..$00ef direct page, all driver variables are there
; $00f0..$00ff DSP registers
; $0100..$01ff stack page
; $0200..$nnnn driver code
;        $xx00 sample directory
;        $nnnn adsr data list
;        $nnnn sound effects data
;        $nnnn music data
;        $nnnn BRR streamer buffer

;---Interface---
;65816 ---> SPC
; CPU0 = Command number
; CPU1 = Parameter
; CPU2 = Parameter
; CPU3 = Parameter
;65816 <--- SPC
; CPU0 = Zero if busy, command number if processing that command
; CPU1 = Unused
; CPU2 = Used for streaming and fast loading
; CPU3 = Command count

;I/O registers
TEST = $f0
CTRL = $f1
ADDR = $f2
DATA = $f3
CPU0 = $f4
CPU1 = $f5
CPU2 = $f6
CPU3 = $f7
TMP0 = $f8
TMP1 = $f9
T0TG = $fa
T1TG = $fb
T2TG = $fc
T0OT = $fd
T1OT = $fe
T2OT = $ff

;DSP channel registers, x0..x9, x is channel number
DSP_VOLL  = $00
DSP_VOLR  = $01
DSP_PL    = $02
DSP_PH    = $03
DSP_SRCN  = $04
DSP_ADSR1 = $05
DSP_ADSR2 = $06
DSP_GAIN  = $07
DSP_ENVX  = $08
DSP_OUTX  = $09

;DSP registers for global settings
DSP_MVOLL = $0c
DSP_MVOLR = $1c
DSP_EVOLL = $2c
DSP_EVOLR = $3c
DSP_KON   = $4c
DSP_KOF   = $5c
DSP_FLG   = $6c
DSP_ENDX  = $7c
DSP_EFB   = $0d
DSP_PMON  = $2d
DSP_NON   = $3d
DSP_EON   = $4d
DSP_DIR   = $5d
DSP_ESA   = $6d
DSP_EDL   = $7d
DSP_C0    = $0f
DSP_C1    = $1f
DSP_C2    = $2f
DSP_C3    = $3f
DSP_C4    = $4f
DSP_C5    = $5f
DSP_C6    = $6f
DSP_C7    = $7f

;vars
;max address for vars is $ef, because $f0..$ff is used for the I/O registers
;first two bytes of the direct page are used by IPL!

.segment "SPCZEROPAGE"
D_STEREO:      .res 1
D_BUFPTR:      .res 1
D_CHx0:        .res 1
D_CH0x:        .res 1
D_KON:         .res 1
D_KOF:         .res 1
D_PAN:         .res 1
D_VOL:         .res 1
D_PTR_L:       .res 1
D_PTR_H:       .res 1
D_PITCH_UPD:   .res 1
D_PITCH_L:     .res 1
D_PITCH_H:     .res 1
D_TEMP:        .res 1
D_MUSIC_CHNS:  .res 1
D_PAUSE:       .res 1
D_GLOBAL_TGT:  .res 1
D_GLOBAL_OUT:  .res 1
D_GLOBAL_STEP: .res 1
D_GLOBAL_DIV:  .res 1

.if BRR_STREAMING
S_ENABLE:      .res 1
S_BUFFER_OFF:  .res 1
S_BUFFER_PTR:  .res 2
S_BUFFER_RD:   .res 1
S_BUFFER_WR:   .res 1
.endif

D_CHNVOL:      .res CHANNEL_COUNT
D_CHNPAN:      .res CHANNEL_COUNT

M_PTR_L:       .res CHANNEL_COUNT
M_PTR_H:       .res CHANNEL_COUNT
M_WAIT_L:      .res CHANNEL_COUNT
M_WAIT_H:      .res CHANNEL_COUNT
M_PITCH_L:     .res CHANNEL_COUNT
M_PITCH_H:     .res CHANNEL_COUNT
M_VOL:         .res CHANNEL_COUNT
M_DETUNE:      .res CHANNEL_COUNT
M_SLIDE:       .res CHANNEL_COUNT
M_PORTAMENTO:  .res CHANNEL_COUNT
M_PORTA_TO_L:  .res CHANNEL_COUNT
M_PORTA_TO_H:  .res CHANNEL_COUNT
M_MODULATION:  .res CHANNEL_COUNT
M_MOD_OFF:     .res CHANNEL_COUNT
M_REF_LEN:     .res CHANNEL_COUNT
;M_REF_RET_L:   .res CHANNEL_COUNT
;M_REF_RET_H:   .res CHANNEL_COUNT
M_INSTRUMENT:  .res CHANNEL_COUNT

COMMAND_COUNT: .res 1 ; Used for acknowledgement

;DSP registers write buffer located in the stack page, as it is not used for the most part
;first four bytes are reserved for shortest echo buffer

M_REF_RET_L = $0104
M_REF_RET_H = M_REF_RET_L + CHANNEL_COUNT
D_BUFFER    = M_REF_RET_H + CHANNEL_COUNT

streamBufSize    = 28		;how many BRR blocks in a buffer, max is 28 (28*9=252)
streamSampleRate = 16000	;stream sample rate
streamData       = $ffc0-(streamBufSize*9*9) ;fixed location for streaming data

streamData1 = streamData
streamData2 = streamData1+(streamBufSize*9)
streamData3 = streamData2+(streamBufSize*9)
streamData4 = streamData3+(streamBufSize*9)
streamData5 = streamData4+(streamBufSize*9)
streamData6 = streamData5+(streamBufSize*9)
streamData7 = streamData6+(streamBufSize*9)
streamData8 = streamData7+(streamBufSize*9)
streamSync  = streamData8+(streamBufSize*9)
streamPitch = (4096*streamSampleRate/32000)

.segment "SPCIMAGE"
spc_entry:
	clrp
	ldx #$ef				;stack is located in $100..$1ff
	txs
	bra mainLoopInit		;$0204, editor should set two zeroes here
;	bra editorInit

;editorInit:
;	jsr initDSPAndVars
;	ldx #1
;	stx <D_STEREO			;enable stereo in the editor, mono by default
;	dex
;	jsr	startMusic

mainLoopInit:
  	mov <T0TG,#8000/UPDATE_RATE_HZ
	mov <CTRL,#$81 ;enable timer 0 and IPL
    lda #0
    sta <COMMAND_COUNT
    sta <CPU3
	jsr setReady

;main loop waits for next frame checking the timer
;during the wait it checks and performs commands, also updates BRR streamer position (if enabled)

mainLoop:
	lda <CPU0				;read command code, when it is zero (<SCMD_NONE), no new command
	cmp <CPU0				;apparently if you read at the same time the other side writes that can cause a problem, so reread
	bne mainLoop
	tay
	beq commandDone
	sta <CPU0				;set busy flag for CPU by echoing a command code

    ldy <COMMAND_COUNT      ;acknowledge the command
    iny
    sty <COMMAND_COUNT
    sty <CPU3

	tay
	and #$0f				;get command offset in the jump table into X
	asl
	tax
	tya
	xcn a						;get channel number into Y
	and #$0f
	tay
	;jmp (cmdList,x)
	jmp  [!cmdList+X]

commandDone:
;all commands jump back here
.if BRR_STREAMING
	jsr updateBRRStreamerPos
.endif
	lda <T0OT
	beq mainLoop
	jsr updateGlobalVolume
	jsr updateMusicPlayer
	bra mainLoop

cmdSubCommand:
	tya
	asl
	tax
	jmp [!subCmdList+X]

cmdInitialize:
	jsr setReady
	jsr initDSPAndVars
	bra commandDone

cmdStereo:
	lda <CPU2
	sta <D_STEREO
SetReadyAndDone:
	jsr setReady
	bra commandDone

cmdGlobalVolume:
	lda <CPU2	;volume
	ldx <CPU3	;change speed
	jsr setReady
	cmp #127
	bcc @noClip
	lda #127
@noClip:
	asl
	sta <D_GLOBAL_TGT
	stx <D_GLOBAL_STEP
	bra commandDone

cmdChannelVolume:
	lda <CPU2	;volume
	ldx <CPU3	;channel mask
	jsr setReady
	cmp #127
	bcc @noClip
	lda #127
@noClip:
	asl
	tay
	txa
	ldx #0
@check:
	ror
	bcc @noVol
	sty <D_CHNVOL,x
@noVol:
	inx
	cpx #CHANNEL_COUNT
	bne @check
	jsr updateAllChannelsVolume
	bra commandDone

cmdMusicPlay:
	jsr setReady
	jsr resetChannelMaskDspBase
	ldx #0				;music always uses channels starting from 0
	stx <D_PAUSE			;reset pause flag
	jsr	startMusic
	jmp commandDone

cmdStopAllSounds:
	jsr setReady
	jsr resetChannelMaskDspBase
	lda #CHANNEL_COUNT
	sta <D_MUSIC_CHNS
	bra stopChannels

cmdMusicStop:
	jsr setReady
	jsr resetChannelMaskDspBase
	lda <D_MUSIC_CHNS
	bne stopChannels
	jmp commandDone

stopChannels:
	lda #0
@loop:
	pha
	jsr setChannel
	ldx <D_CH0x
	lda #0
	sta <M_PTR_H,x
	jsr bufKeyOff
	pla
	inc
	dec <D_MUSIC_CHNS
	bne @loop
	jsr bufKeyOffApply
	jsr bufKeyOnApply
	jmp commandDone

cmdMusicPause:
	lda <CPU2			;pause state
	sta <D_PAUSE
	jsr setReady
	jsr updateAllChannelsVolume
	jmp commandDone

cmdSfxPlay:
	cpy D_MUSIC_CHNS	;don't play effects on music channels
	bcs @play
		jsr setReady
		jmp	commandDone
	@play:
	sty <D_TEMP			;remember requested channel
	ldx <CPU1			;volume
	stx <D_VOL
	lda <CPU2			;effect number
	ldx <CPU3			;pan
	stx <D_PAN
	jsr setReady
	cmp #SOUND_EFFECT_COUNT ;check if there is an effect with this number, just in case
	bcs @done
		asl
		tay
		lda GSS_SoundEffectDirectory+0,y
		sta <D_PTR_L
		lda GSS_SoundEffectDirectory+1,y
		sta <D_PTR_H

		ldx <D_TEMP
		jsr startSoundEffect
	@done:
	jmp commandDone


.proc cmdLoad
	jsr setReady
;.if BRR_STREAMING
;	jsr streamStop			;stop BRR streaming to prevent glitches after loading
;.endif
	ldx #0
	stx <D_KON
	dex
	stx <D_KOF
	jsr bufKeyOffApply
	ldx #$ef
	txs
	jmp $ffc9
.endproc

.proc cmdFastLoad
	; Adapted from https://github.com/Optiroc/libSFX/blob/master/include/CPU/SMP.s
	ldx <CPU3      ; Number of pages
	mov <CPU2,#$80 ; Tell the 65c816 to start sending the data

	; Re-initialize the addresses for the self-modifying code
	; (Will result in multiple loads with the same value)
	lda #>(GSS_MusicUploadAddress+$00)
	sta mA+2
	lda #>(GSS_MusicUploadAddress+$40)
	sta mB+2
	lda #>(GSS_MusicUploadAddress+$80)
	sta mC+2
	lda #>(GSS_MusicUploadAddress+$C0)
	sta mD+2

	; ---------------------------------
	; Transfer four-byte chunks
	; ---------------------------------
page:
	ldy #$3f
quad:
	lda <CPU0
mA:	sta GSS_MusicUploadAddress+$00,y
	lda <CPU1
mB:	sta GSS_MusicUploadAddress+$40,y
	lda <CPU2
mC: sta GSS_MusicUploadAddress+$80,y
	lda <CPU3
	sty <CPU2 ; Tell 65c816 we're ready for more
mD: sta GSS_MusicUploadAddress+$C0,y
	dey
	bpl quad

	inc mA+2  ;Increment MSBs of addresses
	inc mB+2
	inc mC+2
	inc mD+2
	dex
	bne page

	mov <CPU2,#$00 ; Reset CPU2 so it's ready for the next time this command is called

	; Get ready for more commands
	jsr setReady
	jmp commandDone
.endproc

.if BRR_STREAMING
cmdStreamStart:
	jsr setReady
	lda #0
	sta S_BUFFER_WR
	sta S_BUFFER_RD

	jsr streamSetBufPtr
	jsr streamClearBuffers

	lda #$ff
	sta S_ENABLE

	ldx #<BRRStreamInitData
	ldy #>BRRStreamInitData
	jsr sendDSPSequence

	lda #0			;sync channel volume to zero
	sta <M_VOL+6
	lda #127		;stream channel volume to max
	sta <M_VOL+7

	jsr updateAllChannelsVolume
	jmp commandDone

cmdStreamStop:
	jsr setReady
	jsr streamStop
	jmp commandDone

cmdStreamSend:
	lda S_ENABLE
	beq @nosend
		lda S_BUFFER_WR
		cmp S_BUFFER_RD
		bne @send
	@nosend:

	lda #0
	sta <CPU2

	jsr setReady

	jmp commandDone

@send:
	lda #1
	sta <CPU2
	jsr setReady
	ldx #1
@wait1:
	jsr updateBRRStreamerPos
	cpx <CPU0
	bne @wait1

	ldy S_BUFFER_OFF

	lda (<S_BUFFER_PTR),y	;keep the flags
	and #3
	ora <CPU1
	sta (<S_BUFFER_PTR),y
	iny
	lda <CPU2
	sta (<S_BUFFER_PTR),y
	iny
	lda <CPU3
	sta (<S_BUFFER_PTR),y
	iny

	inx
	stx <CPU0
@wait2:
	jsr updateBRRStreamerPos
	cpx <CPU0
	bne @wait2

	lda <CPU1
	sta (<S_BUFFER_PTR),y
	iny
	lda <CPU2
	sta (<S_BUFFER_PTR),y
	iny
	lda <CPU3
	sta (<S_BUFFER_PTR),y
	iny

	inx
	stx <CPU0

@wait3:

	jsr updateBRRStreamerPos
	cpx <CPU0
	bne @wait3

	lda <CPU1
	sta (<S_BUFFER_PTR),y
	iny
	lda <CPU2
	sta (<S_BUFFER_PTR),y
	iny
	lda <CPU3
	sta (<S_BUFFER_PTR),y
	iny

	jsr setReady
	lda #0
	sta <CPU2

	sty S_BUFFER_OFF
	cpy #streamBufSize*9
	bne @skip
		lda S_BUFFER_WR
		inc
		and #7
		sta S_BUFFER_WR
		jsr streamSetBufPtr
	@skip:
	jmp commandDone

streamStop:
	lda #0
	sta S_ENABLE
	lda #DSP_KOF	;stop channels 6 and 7
	sta <ADDR
	lda #$c0
	sta <DATA
	jsr updateAllChannelsVolume
	rts

;clear BRR streamer buffers, fill them with c0 00..00 with stop bit in the last block
streamClearBuffers:
	ldx #0
	lda #streamBufSize
	sta <D_TEMP
@clear0:
	lda #$c0
	sta streamData1,x
	sta streamData2,x
	sta streamData3,x
	sta streamData4,x
	sta streamData5,x
	sta streamData6,x
	sta streamData7,x
	sta streamData8,x
	sta streamSync,x
	inx
	lda #$00
	ldy #8
@clear1:
	sta streamData1,x
	sta streamData2,x
	sta streamData3,x
	sta streamData4,x
	sta streamData5,x
	sta streamData6,x
	sta streamData7,x
	sta streamData8,x
	sta streamSync,x
	inx
	dey
	bne @clear1
	dec <D_TEMP
	bne @clear0
	lda #$c3
	sta streamData8+streamBufSize*9-9
	sta streamSync+streamBufSize*9-9
	rts

streamSetBufPtr:
	asl
	tax
	lda streamBufferPtr+0,x
	sta S_BUFFER_PTR+0
	lda streamBufferPtr+1,x
	sta S_BUFFER_PTR+1
	lda #0
	sta S_BUFFER_OFF
	rts
.endif

; Echo commands taken from https://github.com/nesdoug/SNES_13
.proc cmdEchoVolChans
	ldx #DSP_EON
	stx <ADDR
	lda CPU3
	sta <DATA

	lda <CPU2
	ldx #DSP_EVOLL
	stx <ADDR
	sta <DATA
	ldx #DSP_EVOLL
	stx <ADDR
	sta <DATA

	ldx #DSP_FLG ; Turn echo data writing on/off
	stx <ADDR
	tax
	beq echo_off
	clr1 DATA.5
	jmp SetReadyAndDone
echo_off:
	set1 DATA.5
	jmp SetReadyAndDone
.endproc

.proc cmdEchoAddrDelay
	lda #DSP_ESA ; Echo address high byte
	sta <ADDR
	lda <CPU2
	sta <DATA
	sta <D_PTR_H
	lda #DSP_EDL ; Echo delay (and buffer size) in 2KB chunks. or 0 is 4 bytes
	sta <ADDR
	lda <CPU3
	jsr setReady
	and #$0f ; Sanitize
	sta <DATA
	asl a ;2
	asl a ;4
	asl a ;8
	tax ;high byte count
	bne forward
		inx
forward:
	lda #0
	sta <D_PTR_L
	tay ;low byte count
;clear the echo buffer
loop:
	sta (<D_PTR_L),y
	iny
	bne loop
	inc <D_PTR_H
	dex
	bne loop
;wait a little
;both x and y are 0
loop2:
	nop
	dex
	bne loop2
	dey
	bne loop2
	jmp commandDone
.endproc

.proc cmdFeedbackFir
	lda #DSP_EFB ; Feedback volume
	sta <ADDR
	lda <CPU3
	sta <DATA
	lda <CPU2 ; FIR setting
	asl a
	asl a
	asl a
	tay

	ldx #7
loop:
	lda fir_addr, x	
	sta <ADDR
	lda fir_table,y
	sta <DATA
	iny
	dex
	bpl loop
	jmp SetReadyAndDone

fir_addr:
	.byt $7f, $6f, $5f, $4f, $3f, $2f, $1f, $0f

fir_table:
	;simple echo
	.byt $7f, $00, $00, $00, $00, $00, $00, $00
	;multi echo
	.byt $48, $20, $12, $0c, $00, $00, $00, $00
	;low pass echo
	.byt $0c, $21, $2b, $2b, $13, $fe, $f3, $f9
	;high pass echo
	.byt $01, $02, $04, $08, $10, $20, $40, $80
.endproc

;start music, using the channels starting from the specified one
;in: X=the starting channel, musicDataPtr=music data location
startMusic:
	lda #<GSS_MusicUploadAddress
	sta <D_PTR_L
	lda #>GSS_MusicUploadAddress
	sta <D_PTR_H
	ldy #0					;how many channels in the song
	lda (<D_PTR_L),y
	sta <D_MUSIC_CHNS
	bne @start				;just in case
		jmp commandDone
	@start:
	sta <D_TEMP
	iny
@loop:
	phx
	txa
	jsr setChannel

	phy
	jsr startChannel

	lda #128
	sta <D_CHNPAN,x		;reset pan for music channels

	ply
	plx

	inx						;the song requires too many channels, skip those that don't fit
	cpx #CHANNEL_COUNT
	bcs @done

	iny
	iny

	dec <D_TEMP
	bne @loop
@done:
	rts

;start sound effects, almost the same as music
;in: X=the starting channel, D_PTR=effect data location,D_VOL,D_PAN
startSoundEffect:
	ldy #0
	lda (<D_PTR_L),y		;how many channels in the song
	sta <D_TEMP
	iny
@loop:
	; Mute the original channel if it's a sound effect interrupt channel
	cpx #FIRST_SFX_CHANNEL
	bcc @NotInterrupt
		phx
		; Is it necesary to key off the original note here?
		lda channelToInterruptForSfx,x
		tax
		lda #0
		sta channelMask,x
		dec a
		sta channelDspBase,x
		plx
@NotInterrupt:

	phx
	txa
	jsr setChannel
	phy
	jsr startChannel
	
	lda <D_VOL				;apply effect volume
;	cmp #127
;	bcc .noClip
;.noClip:

	asl
	sta <D_CHNVOL,x

	lda <D_PAN				;apply effect pan
	sta <D_CHNPAN,x

	ply
	plx

	inx
	cpx #CHANNEL_COUNT
	bcs @done

	iny
	iny

	dec <D_TEMP
	bne @loop

@done:
	rts

;initialize channel
;in: D_CH0x=channel, D_PTR_L,Y=offset to the channel data
startChannel:
	jsr bufKeyOff
	jsr bufKeyOffApply

	ldx <D_CH0x

	lda #0

	sta <M_PITCH_L,x		;reset current pitch
	sta <M_PITCH_H,x

	sta <M_PORTA_TO_L,x	;reset portamento pitch
	sta <M_PORTA_TO_H,x

	sta <M_DETUNE,x		;reset all effects
	sta <M_SLIDE,x
	sta <M_PORTAMENTO,x
	sta <M_MODULATION,x
	sta <M_MOD_OFF,x
	sta <M_REF_LEN,x		;reset reference

	sta <M_WAIT_H,x
	lda #4					;short delay between initial keyoff and starting a channel, to prevent clicks
	sta <M_WAIT_L,x

	lda #127				;set default channel volume
	sta <M_VOL,x
	
	lda (<D_PTR_L),y
	sta <M_PTR_L,x
	iny
	lda (<D_PTR_L),y
	sta <M_PTR_H,x
	rts

;run one frame of music player
updateMusicPlayer:
	jsr bufClear
	lda #0
@loop:
	pha
	ldx <D_PAUSE
	beq @noPause
		cmp D_MUSIC_CHNS		;the pause only skips channels with music
		bcc @skipChannel
	@noPause:

	jsr setChannel			;select current channel

	lda #0					;reset pitch update flag, set by any pitch change event in the updateChannel
	sta <D_PITCH_UPD

	jsr updateChannel		;perform channel update
	jsr updatePitch			;write pitch registers if the pitch was updated
@skipChannel:
	pla
	inc
	cmp #CHANNEL_COUNT
	bne @loop

	jsr bufKeyOffApply
	jsr bufApply
	jsr bufKeyOnApply
	rts

;read one byte of a music channel data, and advance the read pointer in temp variable
;readChannelByteZ sets Y offset to zero, readChannelByte skips it as Y often remains zero anyway
;it also handles reference calls and returns

readChannelByteZ:
	ldy #0
readChannelByte:
	lda (<D_PTR_L),y

	incw <D_PTR_L

	pha
	ldx <D_CH0x

	lda <M_REF_LEN,x		;check reference length
	beq @done

	dec <M_REF_LEN,x		;decrement reference length
	bne @done

	lda M_REF_RET_L,x		;restore original pointer
	sta <D_PTR_L
	lda M_REF_RET_H,x
	sta <D_PTR_H
@done:
	pla
	rts

;perform update of one music data channel, and parse channel data when needed

updateChannel:
	ldx <D_CH0x

	lda <M_PTR_H,x			;when the pointer MSB is zero, channel is inactive
	bne @processChannel
		rts
	@processChannel:

	sta <D_PTR_H
	lda <M_PTR_L,x
	sta <D_PTR_L

	lda <M_MODULATION,x	;when modulation is active, pitch gets updated constantly
	sta <D_PITCH_UPD
	beq @noModulation

	and #$0f				;advance the modulation pointer
	clc
	adc <M_MOD_OFF,x

	cmp #192
	bcc @noWrap

	sec
	sbc #192

@noWrap:

	sta <M_MOD_OFF,x

@noModulation:

	lda <M_PORTAMENTO,x
	bne @doPortamento		;portamento has priority over slides

	lda <M_SLIDE,x
	bne @doSlide
	jmp @noSlide

@doSlide:

	sta <D_PITCH_UPD

	bmi @slideDown
	bra @slideUp

@doPortamento:

	lda <M_PITCH_H,x		;compare current pitch and needed pitch
	cmp <M_PORTA_TO_H,x
	bne @portaCompareDone
		lda <M_PITCH_L,x
		cmp <M_PORTA_TO_L,x
	@portaCompareDone:
	beq @noSlide			;go noslide if no pitch change is needed
	bcs @portaDown
@portaUp:
	inc <D_PITCH_UPD

	lda <M_PITCH_L,x
	clc
	adc <M_PORTAMENTO,x
	sta <M_PITCH_L,x
	lda <M_PITCH_H,x
	adc #0
	sta <M_PITCH_H,x

	cmp <M_PORTA_TO_H,x	;check if the pitch goes higher than needed
	bne @portaUpLimit
	lda <M_PITCH_L,x
	cmp <M_PORTA_TO_L,x
@portaUpLimit:
	bcs @portaPitchLimit
	bra @noSlide
@portaDown:

	inc <D_PITCH_UPD

	lda <M_PITCH_L,x
	sec
	sbc <M_PORTAMENTO,x
	sta <M_PITCH_L,x
	lda <M_PITCH_H,x
	sbc #0
	sta <M_PITCH_H,x

	cmp <M_PORTA_TO_H,x	;check if the pitch goes lower than needed
	bne @portaDownLimit
	lda <M_PITCH_L,x
	cmp <M_PORTA_TO_L,x

@portaDownLimit:

	bcc @portaPitchLimit
	bra @noSlide

@portaPitchLimit:

	lda <M_PORTA_TO_L,x
	sta <M_PITCH_L,x
	lda <M_PORTA_TO_H,x
	sta <M_PITCH_H,x

	bra @noSlide
@slideUp:

	lda <M_PITCH_L,x
	clc
	adc <M_SLIDE,x
	sta <M_PITCH_L,x
	lda <M_PITCH_H,x
	adc #0
	sta <M_PITCH_H,x

	cmp #$40
	bcc @noSlide

	lda #$3f
	sta <M_PITCH_H,x
	lda #$30
	sta <M_PITCH_L,x

	bra @noSlide

@slideDown:

	lda <M_PITCH_L,x
	clc
	adc <M_SLIDE,x
	sta <M_PITCH_L,x
	lda <M_PITCH_H,x
	adc #255
	sta <M_PITCH_H,x

	bcs @noSlide

	lda #0
	sta <M_PITCH_H,x
	sta <M_PITCH_L,x

@noSlide:

	lda <M_WAIT_L,x
	bne @wait1
		lda <M_WAIT_H,x
		beq @readLoopStart
		dec <M_WAIT_H,x
	@wait1:

	dec <M_WAIT_L,x

	lda <M_WAIT_L,x
	ora <M_WAIT_H,x

	beq @readLoopStart
	rts
@readLoopStart:

	jsr updateChannelVolume
	
@readLoop:

	jsr readChannelByteZ		;read a new byte, set Y to zero, X to D_CH0x

	cmp #149
	bcc @setShortDelay
	cmp #245
	beq @keyOff
	bcc @newNote

	cmp #246
	beq @setLongDelay
	cmp #247
	beq @setEffectVolume
	cmp #248
	beq @setEffectPan
	cmp #249
	beq @setEffectDetune
	cmp #250
	beq @setEffectSlide
	cmp #251
	beq @setEffectPortamento
	cmp #252
	beq @setEffectModulation
	cmp #253
	beq @setReference
	cmp #254
	bne @jumpLoop
	jmp @setInstrument

@jumpLoop:	;255
	cpx #FIRST_SFX_CHANNEL
	bcc @NotInterrupt
		jmp RestoreAfterSoundEffect
@NotInterrupt:

	jsr readChannelByte
	pha
	jsr readChannelByte

	sta <D_PTR_H
	pla
	sta <D_PTR_L

	bra @readLoop

@keyOff:
	jsr bufKeyOff
	bra @readLoop

@setShortDelay:
	sta <M_WAIT_L,x
	bra @storePtr

@newNote:
	sec
	sbc #150

	jsr setPitch

	lda <M_PORTAMENTO,x	;only set key on when portamento is not active
	bne @readLoop
	jsr bufKeyOn
	bra @readLoop
@setLongDelay:
	jsr readChannelByte
	sta <M_WAIT_L,x

	jsr readChannelByte
	sta <M_WAIT_H,x

	bra @storePtr
@setEffectVolume:
	jsr readChannelByte		;read volume value
	sta <M_VOL,x
	jsr updateChannelVolume	;apply volume and pan
	bra @readLoop
@setEffectPan:
	jsr readChannelByte		;read pan value
	sta <D_CHNPAN,x
	jsr updateChannelVolume	;apply volume and pan
	jmp @readLoop
@setEffectDetune:
	jsr readChannelByte		;read detune value
	sta <M_DETUNE,x
	inc <D_PITCH_UPD		;set pitch update flag
	jmp @readLoop
@setEffectSlide:
	jsr readChannelByte		;read slide value (8-bit signed, -99..99)
	sta <M_SLIDE,x
	jmp @readLoop
@setEffectPortamento:
	jsr readChannelByte		;read portamento value (8-bit unsigned, 0..99)
	sta <M_PORTAMENTO,x
	jmp @readLoop
@setEffectModulation:
	jsr readChannelByte		;read modulation value
	sta <M_MODULATION,x
	jmp @readLoop
@setReference:
	jsr readChannelByte		;read reference LSB
	pha
	jsr readChannelByte		;read reference MSB
	pha
	jsr readChannelByte		;read reference length in bytes

	sta <M_REF_LEN,x

	lda <D_PTR_L			;remember previous pointer as the return address
	sta M_REF_RET_L,x
	lda <D_PTR_H
	sta M_REF_RET_H,x

	pla						;set reference pointer
	sta <D_PTR_H
	pla
	sta <D_PTR_L

	jmp @readLoop
@setInstrument:
	jsr readChannelByte
	jsr setInstrument
	jmp @readLoop

@storePtr:
	ldx <D_CH0x

	lda <D_PTR_L			;store changed pointer
	sta <M_PTR_L,x
	lda <D_PTR_H
	sta <M_PTR_H,x
	rts

;initialize DSP registers and driver variables
initDSPAndVars:
	ldx #0
	stx <CPU2					;init CPU2 since it's used for synchronization
	stx <D_KON					;no keys pressed
	stx <D_KOF					;no keys released
	stx <D_STEREO				;mono by default
	stx <D_MUSIC_CHNS			;how many channels current music uses
	stx <D_PAUSE				;pause mode is inactive
.if BRR_STREAMING
	stx S_ENABLE				;disable streaming
.endif
	stx <D_GLOBAL_DIV			;reset global volume change speed divider

	stx <D_GLOBAL_OUT			;current global volume
	ldx #255
	stx <D_GLOBAL_TGT			;target global volume
	stx <D_GLOBAL_STEP			;global volume change speed
	
	ldx #<DSPInitData
	ldy #>DSPInitData
	jsr sendDSPSequence

	ldx #0
@initChannels:
	lda #0
	sta <M_PTR_H,x

	lda #128
	sta <D_CHNPAN,x
	lda #255
	sta <D_CHNVOL,x
	
	sta <M_INSTRUMENT,x

	inx
	cpx #CHANNEL_COUNT
	bne @initChannels
.if BRR_STREAMING
	jsr streamClearBuffers
.endif
	rts

RestoreAfterSoundEffect:
	; Stop reading bytes for the sound effect's channel
	lda #0
	sta <M_PTR_H,x

	; Restore the original channel
	lda channelToInterruptForSfx,x
	sta <D_CH0x
	tax
	lda initialChannelDspBase,x
	sta <D_CHx0
	sta channelDspBase,x
	lda initialChannelMask,x
	sta channelMask,x

	; Recalculate everything
	jsr updateChannelVolume
	jsr updatePitchForce
	lda <M_INSTRUMENT,x
	jmp setInstrument

.if BRR_STREAMING
;updates play position for the BRR streamer
updateBRRStreamerPos:
	lda #DSP_ENDX				;check if channel 6 stopped playing
	sta ADDR
	lda DATA
	and #$40
	beq @skip
		sta DATA

		lda S_BUFFER_RD
		inc
		and #7
		sta S_BUFFER_RD
	@skip:
	rts
.endif

;set the ready flag for the 65816 side, so it can send a new command
setReady:
	pha
	lda #%10010001				;reset communication I/O, enable timer 0 and IPL
	sta <CTRL
	lda #0
	sta <CPU0
	sta <CPU1
	pla
	rts

;set current channel for all other setNNN routines
;in: A=channel 0..7
setChannel:
	sta <D_CH0x
	phx
	tax
	lda channelDspBase,x
	plx
	sta <D_CHx0
	rts

;set instrument (<Sample and ADSR) for specified channel
;in: D_CHx0=channel, A=instrument number 0..255
setInstrument:
	tay

	ldx <D_CH0x
	cmp <M_INSTRUMENT,x
	beq @skip
		sta <M_INSTRUMENT,x

		lda <D_CHx0
		ora #DSP_SRCN
		tax

		tya
		jsr bufRegWrite				;write instrument number, remains in A after jsr

		asl							;get offset for parameter tables
		tay

		lda <D_CHx0					;write adsr parameters
		ora #DSP_ADSR1
		tax
		lda GSS_SampleADSR,y		;first adsr byte
		jsr bufRegWrite

		lda <D_CHx0
		ora #DSP_ADSR2
		tax
		lda GSS_SampleADSR+1,y		;second adsr byte
		jsr bufRegWrite
	@skip:
	rts

;set pitch variables accoding to note
;in: D_CH0x=channel, A=note
setPitch:
	asl
	tay

	ldx <D_CH0x

	lda notePeriodTable+0,y
	sta <M_PORTA_TO_L,x

	lda notePeriodTable+1,y
	sta <M_PORTA_TO_H,x

	lda <M_PORTAMENTO,x
	beq @portaOff

	cmp #99						;P99 gets legato effect, changes pitch right away without sending keyon
	beq @portaOff
	rts
@portaOff:

	lda <M_PORTA_TO_L,x		;when portamento is inactive, copy the target pitch into current pitch immideately
	sta <M_PITCH_L,x
	lda <M_PORTA_TO_H,x
	sta <M_PITCH_H,x
	inc <D_PITCH_UPD
	rts

;apply current pitch of the channel, also applies the detune value
;in: D_CHx0=channel if the pitch change flag is set
updatePitch:
	lda <D_PITCH_UPD
	bne updatePitchForce
	rts
updatePitchForce:
	ldx <D_CH0x

	lda <M_PITCH_L,x
	clc
	adc <M_DETUNE,x
	sta <D_PITCH_L
	lda <M_PITCH_H,x
	adc #0
	sta <D_PITCH_H

	lda <M_MODULATION,x
	beq @noModulation

	and #$f0
	tay

	lda <M_MOD_OFF,x
	tax
	lda vibratoTable,x
	bmi @modSubtract
@modAdd:
	mul ya
	tya

	clc
	adc D_PITCH_L
	sta <D_PITCH_L
	lda <D_PITCH_H
	adc #0
	sta <D_PITCH_H
	bra @noModulation
@modSubtract:
	eor #255
	inc

	mul ya
	tya
	sta <D_TEMP

	lda <D_PITCH_L
	sec
	sbc D_TEMP
	sta <D_PITCH_L
	lda <D_PITCH_H
	sbc #0
	sta <D_PITCH_H
@noModulation:
	lda <D_CHx0
	ora #DSP_PH
	tax
	lda <D_PITCH_H
	jsr bufRegWrite

	lda <D_CHx0
	ora #DSP_PL
	tax
	lda <D_PITCH_L
	jsr bufRegWrite
	rts

;set volume and pan for current channel, according to M_VOL,D_CHNVOL,D_CHNPAN, and music pause state
;in: D_CHx0=channel

updateChannelVolume:

	ldx <D_CH0x

	cpx D_MUSIC_CHNS
	bcs @noMute

	lda <D_PAUSE
	beq @noMute

	lda #0
	bra @calcVol

@noMute:

	lda <D_CHNVOL,x		;get virtual channel volume

@calcVol:

	ldy <M_VOL,x			;get music channel volume
	mul ya
	sty <D_VOL				;resulting volume

	lda <D_STEREO
	bne @stereo

@mono:
	lda <D_VOL
	pha
	pha
	bra @setVol

@stereo:
	lda <D_CHNPAN,x		;calculate left volume
	eor #$ff
	tay
	lda <D_VOL
	mul ya
	phy

	ldy <D_CHNPAN,x		;calculate right volume
	lda <D_VOL
	mul ya
	phy

@setVol:

	lda <D_CHx0			;write volume registers
	ora #DSP_VOLR
	tax
	pla
	jsr bufRegWrite

	lda <D_CHx0
	ora #DSP_VOLL
	tax
	pla
	jsr bufRegWrite

	rts

;set volume and pan for all channels

updateAllChannelsVolume:
	lda #0
@updVol:
	pha
	jsr setChannel
	jsr updateChannelVolume
	pla
	inc
	cmp #CHANNEL_COUNT
	bne @updVol
	jsr bufApply
	rts

;update global volume, considering current fade speed
updateGlobalVolume:
	inc <D_GLOBAL_DIV
	lda <D_GLOBAL_DIV
	and #7
	beq @update
	lda <D_GLOBAL_STEP
	cmp #255
	beq @update
	rts
@update:
	lda <D_GLOBAL_OUT
	cmp D_GLOBAL_TGT
	beq @setVolume
	bcs @fadeOut
@fadeIn:
	adc D_GLOBAL_STEP
	bcc @fadeInLimit
	
	lda <D_GLOBAL_TGT
	bra @setVolume
@fadeInLimit:
	cmp D_GLOBAL_TGT
	bcc @setVolume
	lda <D_GLOBAL_TGT
	bra @setVolume
@fadeOut:
	sbc D_GLOBAL_STEP
	bcs @fadeOutLimit
	lda <D_GLOBAL_TGT
	bra @setVolume
@fadeOutLimit:	
	cmp D_GLOBAL_TGT
	bcs @setVolume
	lda <D_GLOBAL_TGT
@setVolume:
	sta <D_GLOBAL_OUT
	lsr

	ldx #DSP_MVOLL
	stx ADDR
	sta DATA

	ldx #DSP_MVOLR
	stx ADDR
	sta DATA
	rts
	
;clear register writes buffer, just set ptr to 0
bufClear:
	mov <D_BUFPTR,#0
	rts

;add register write in buffer
;in X=reg, A=value
bufRegWrite:
	cpx #255 ; Will be 255 when the channel has its output disabled for a sound effect
	bne :+
		rts
	:
	pha
	txa
	ldx <D_BUFPTR
	sta D_BUFFER,x
	inx

	pla
	sta D_BUFFER,x
	inx
	stx <D_BUFPTR
	rts

;set keyon for specified channel in the temp variable
;in: D_CH0x=channel
bufKeyOn:
	ldx <D_CH0x
	lda channelMask,x
	ora <D_KON
	sta <D_KON
	rts

;set keyoff for specified channel in the temp variable
;in: D_CH0x=channel
bufKeyOff:
	ldx <D_CH0x
	lda channelMask,x
	ora <D_KOF
	sta <D_KOF
	rts

;send writes from buffer and clear it
bufApply:
	lda <D_BUFPTR
	beq @done
	ldx #0
@loop:
	lda D_BUFFER,x
	sta ADDR
	inx
	lda D_BUFFER,x
	sta DATA
	inx
	cpx D_BUFPTR
	bne @loop
	mov <D_BUFPTR,#0
@done:
	rts

;send keyon from the temp variable
bufKeyOnApply:
	lda <D_KON
	eor #$ff
	and D_KOF
	ldx #DSP_KOF
	stx ADDR
	sta <D_KOF
	sta DATA

	lda #DSP_KON
	sta ADDR
	lda <D_KON
	mov <D_KON,#0
	sta DATA
	rts

;send keyoff from the temp variable
bufKeyOffApply:
	lda #DSP_KOF
	sta ADDR
	lda <D_KOF
	sta DATA
	rts

;send sequence of DSP register writes, used for init
sendDSPSequence:
	stx <D_PTR_L
	sty <D_PTR_H
	ldy #0
@loop:
	lda (<D_PTR_L),y
	beq @done

	sta ADDR
	iny
	lda (<D_PTR_L),y
	sta DATA
	iny

	bra @loop
@done:
	rts

cmdList:
	.word 0                 ;0 no command, means the APU is ready for a new command
	.word cmdSubCommand     ;1 run subcommand
	.word cmdGlobalVolume   ;2 set global volume
	.word cmdChannelVolume  ;3 set channel volume
	.word cmdSfxPlay        ;4 play sound effect
.if BRR_STREAMING
	.word cmdStreamStart	;5 start sound streaming
	.word cmdStreamStop		;6 stop sound streaming
	.word cmdStreamSend		;7 send a block of data if needed
.endif

subCmdList:
	.word cmdInitialize     ;0 initialize DSP
	.word cmdStereo         ;1 change stereo sound mode, mono by default
	.word cmdMusicPlay      ;2 start music
	.word cmdMusicStop      ;3 stop music
	.word cmdMusicPause     ;4 pause music
	.word cmdStopAllSounds  ;5 stop all sounds
	.word cmdFastLoad       ;6 load new music data (custom loader)
	.word cmdLoad           ;7 load new music data (jump to IPL)
	.word cmdEchoVolChans	;8 set echo bufer volume
	.word cmdEchoAddrDelay	;9 set echo buffer address and delay size
	.word cmdFeedbackFir	;10 set feedback volume and FIR filter

notePeriodTable:
	.word $0042,$0046,$004a,$004f,$0054,$0059,$005e,$0064,$006a,$0070,$0077,$007e
	.word $0085,$008d,$0095,$009e,$00a8,$00b2,$00bc,$00c8,$00d4,$00e0,$00ee,$00fc
	.word $010b,$011b,$012b,$013d,$0150,$0164,$0179,$0190,$01a8,$01c1,$01dc,$01f8
	.word $0216,$0236,$0257,$027b,$02a1,$02c9,$02f3,$0320,$0350,$0382,$03b8,$03f0
	.word $042c,$046c,$04af,$04f6,$0542,$0592,$05e7,$0641,$06a0,$0705,$0770,$07e1
	.word $0859,$08d8,$095f,$09ed,$0a85,$0b25,$0bce,$0c82,$0d41,$0e0a,$0ee0,$0fc3
	.word $10b3,$11b1,$12be,$13db,$150a,$164a,$179d,$1905,$1a82,$1c15,$1dc1,$1f86
	.word $2166,$2362,$257d,$27b7,$2a14,$2c95,$2f3b,$320a,$3504,$382b,$3b82,$3f0c

vibratoTable:
	.byte $00,$04,$08,$0c,$10,$14,$18,$1c,$20,$24,$28,$2c,$30,$34,$38,$3b
	.byte $3f,$43,$46,$49,$4d,$50,$53,$56,$59,$5c,$5f,$62,$64,$67,$69,$6b
	.byte $6d,$70,$71,$73,$75,$76,$78,$79,$7a,$7b,$7c,$7d,$7d,$7e,$7e,$7e
	.byte $7f,$7e,$7e,$7e,$7d,$7d,$7c,$7b,$7a,$79,$78,$76,$75,$73,$71,$70
	.byte $6d,$6b,$69,$67,$64,$62,$5f,$5c,$59,$56,$53,$50,$4d,$49,$46,$43
	.byte $3f,$3b,$38,$34,$30,$2c,$28,$24,$20,$1c,$18,$14,$10,$0c,$08,$04
	.byte $00,$fc,$f8,$f4,$f0,$ec,$e8,$e4,$e0,$dc,$d8,$d4,$d0,$cc,$c8,$c5
	.byte $c1,$bd,$ba,$b7,$b3,$b0,$ad,$aa,$a7,$a4,$a1,$9e,$9c,$99,$97,$95
	.byte $93,$90,$8f,$8d,$8b,$8a,$88,$87,$86,$85,$84,$83,$83,$82,$82,$82
	.byte $81,$82,$82,$82,$83,$83,$84,$85,$86,$87,$88,$8a,$8b,$8d,$8f,$90
	.byte $93,$95,$97,$99,$9c,$9e,$a1,$a4,$a7,$aa,$ad,$b0,$b3,$b7,$ba,$bd
	.byte $c1,$c5,$c8,$cc,$d0,$d4,$d8,$dc,$e0,$e4,$e8,$ec,$f0,$f4,$f8,$fc

channelMask:
	.byte $01,$02,$04,$08,$10,$20,$40,$80 ; Music
	.byte $80, $40, $20 ; Sound effects
channelDspBase:
	.byte $00,$10,$20,$30,$40,$50,$60,$70 ; Music
	.byte $70, $60, $50 ; Sound effects

channelToInterruptForSfx = * - FIRST_SFX_CHANNEL
.byt 7, 6, 5

.proc resetChannelMaskDspBase
	ldx #end-mask-1
:	lda mask,x
	sta channelMask,x
	dex
	bpl :-
	rts

mask:
	.byte $01,$02,$04,$08,$10,$20,$40,$80 ; Music
	.byte $80, $40, $20 ; Sound effects
dspBase:
	.byte $00,$10,$20,$30,$40,$50,$60,$70 ; Music
	.byte $70, $60, $50 ; Sound effects
end:
.endproc
initialChannelDspBase = resetChannelMaskDspBase::dspBase
initialChannelMask = resetChannelMaskDspBase::mask

.if BRR_STREAMING
streamBufferPtr:
	.word streamData1
	.word streamData2
	.word streamData3
	.word streamData4
	.word streamData5
	.word streamData6
	.word streamData7
	.word streamData8
.endif

DSPInitData:
	.byte DSP_FLG  ,%01100000				;mute, disable echo
	.byte DSP_MVOLL,0						;global volume to zero
	.byte DSP_MVOLR,0
	.byte DSP_PMON ,0						;no pitch modulation
	.byte DSP_NON  ,0						;no noise
	.byte DSP_ESA  ,1						;echo buffer in the stack page
	.byte DSP_EDL  ,0						;minimal echo buffer length
	.byte DSP_EFB  ,0						;no echo feedback
	.byte DSP_C0   ,127						;zero echo filter
	.byte DSP_C1   ,0
	.byte DSP_C2   ,0
	.byte DSP_C3   ,0
	.byte DSP_C4   ,0
	.byte DSP_C5   ,0
	.byte DSP_C6   ,0
	.byte DSP_C7   ,0
	.byte DSP_EON  ,0						;echo disabled
	.byte DSP_EVOLL,0						;echo volume to zero
	.byte DSP_EVOLR,0
	.byte DSP_KOF  ,255						;all keys off
	.byte DSP_DIR  ,>GSS_SampleDirectory	;sample dir location
	.byte DSP_FLG  ,%00100000				;no mute, disable echo
	.byte 0

.if BRR_STREAMING
BRRStreamInitData:
	.byte DSP_ADSR1+$70,$00					;disable ADSR on channel 7
	.byte DSP_GAIN +$70,$1f
	.byte DSP_PL   +$70,streamPitch&255	;set pitch on channels 6 and 7
	.byte DSP_PH   +$70,streamPitch/256
	.byte DSP_PL   +$60,streamPitch&255
	.byte DSP_PH   +$60,streamPitch/256
	.byte DSP_SRCN +$70,0					;stream always playing on channel 7
	.byte DSP_SRCN +$60,8					;sync stream always playing on channel 6
	.byte DSP_KON      ,$c0					;start channels 6 and 7
	.byte 0
.endif

;	.align 256		;sample dir list should be aligned to 256 bytes
;sampleDirAddr:		;four bytes per sample, first 9 entries reserved for the BRR streamer
;	.word streamData1,streamData1
;	.word streamData2,streamData2
;	.word streamData3,streamData3
;	.word streamData4,streamData4
;	.word streamData5,streamData5
;	.word streamData6,streamData6
;	.word streamData7,streamData7
;	.word streamData8,streamData8
;	.word streamSync,streamSync

;------------------------------------------------------------------------------------------------------
.include "../audio/gss_data.s"
