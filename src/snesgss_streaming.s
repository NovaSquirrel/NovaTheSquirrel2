; Adapted from sneslib.asm and sneslib.h in the original snesgss release

.include "snes.inc"
.smart
.i16
.import GSS_SendCommand

temp_pointer = 0
temp_pointer2 = 3

.segment "BSS"
spc_stream_block:          .res 2
spc_stream_block_ptr:      .res 2
spc_stream_block_ptr_prev: .res 2
spc_stream_block_size:     .res 2
spc_stream_block_repeat:   .res 2
spc_stream_enable:         .res 2
spc_stream_stop_flag:      .res 2
spc_stream_block_list:     .res 3
spc_stream_block_src:      .res 3

.segment "CODE"

; Start BRR streaming, it uses channels 6 and 7
; These channels should not be used with any functions while the streamer is active
; A = Pointer to the block list (need to set bank on the pointer separately)
.a16
.proc spc_stream_start 
	sta spc_stream_block_list

	stz spc_stream_block
	stz spc_stream_stop_flag

	lda #1
	sta spc_stream_enable

	jsr stream_set_block

	lda #GSS_Commands::STREAM_START
	jml GSS_SendCommand
.endproc

; Stop streaming
.a16
.proc spc_stream_stop
	stz spc_stream_enable
	lda #GSS_Commands::STREAM_STOP
	jml GSS_SendCommand
.endproc

; Not used
;.a16
;.proc spc_stream_advance_ptr
;	add spc_stream_block_ptr
;	sta spc_stream_block_ptr
;	cmp spc_stream_block_size
;	bcc :+
;		inc spc_stream_block
;		jsl spc_stream_set_block
;	:
;	rtl
;.endproc

.a16
.proc spc_stream_update
brr_stream_list = temp_pointer
brr_stream_src = temp_pointer2

; If the stream is enabled, go ahead and run the stream
	php
    setaxy16
_stream_update_loop:
	lda spc_stream_enable
	bne _stream_update_loop1
_stream_update_done:
	plp
	rtl

; -------------------------------------

_stream_update_loop1:
	lda spc_stream_stop_flag
	beq _stream_update_play

	; If the stream stop flag is set, turn off the enable flag and send the command to stop the stream
	stz spc_stream_enable

	; Wait until SPC is not busy, then send command and wait for acknowledgement
	seta8
:	lda APU0
	bne :-

	lda #GSS_Commands::STREAM_STOP
	sta APU0
:	lda APU0
	beq :-

	bra _stream_update_done

; -------------------------------------

_stream_update_play:
	seta8
	; Wait until SPC is not busy
:	lda APU0
	bne :-

	; Signal that you want to start sending stream data
	lda #GSS_Commands::STREAM_SEND
	sta APU0

:	lda APU0
	beq :-
:	lda APU0
	bne :-

	; SPC uses APU2 to signal that streaming is enabled, and to proceed
	lda APU2
	beq _stream_update_done

	seta16
	lda spc_stream_block_src+0
	sta brr_stream_src+0
	lda spc_stream_block_src+1
	sta brr_stream_src+1

	lda spc_stream_block_repeat
	beq _norepeat
		dec spc_stream_block_repeat
		ldy spc_stream_block_ptr_prev
		bra _stream_update_send
	_norepeat:

	; Get a byte
	ldy spc_stream_block_ptr
	lda [brr_stream_src],y
	and #255
	lsr a
	bcc _stream_update_repeat
	sta spc_stream_block_repeat

	; Step the pointer forward one byte and write it back
	iny
	sty spc_stream_block_ptr
	cpy spc_stream_block_size
	bcc _stream_update_nojump1
		inc spc_stream_block
		jsr stream_set_block
	_stream_update_nojump1:

	ldy spc_stream_block_ptr_prev
	bra _stream_update_send

_stream_update_repeat:
	lda spc_stream_block_ptr
	sta spc_stream_block_ptr_prev
	tay
	clc
	adc #9
	sta spc_stream_block_ptr
	cmp spc_stream_block_size
	bcc _stream_update_send

	inc spc_stream_block

	phy
	jsr stream_set_block
	ply

_stream_update_send:
	; Write one block in 3 chunks
	seta8
	lda [brr_stream_src],y
	iny
	sta APU1
	lda [brr_stream_src],y
	iny
	sta APU2
	lda [brr_stream_src],y
	iny
	sta APU3

	lda #1
	sta APU0
	inc a

:	cmp APU0
	bne :-

	lda [brr_stream_src],y
	iny
	sta APU1
	lda [brr_stream_src],y
	iny
	sta APU2
	lda [brr_stream_src],y
	iny
	sta APU3

	lda #2
	sta APU0
	inc a

:	cmp APU0
	bne :-

	lda [brr_stream_src],y
	iny
	sta APU1
	lda [brr_stream_src],y
	iny
	sta APU2
	lda [brr_stream_src],y
	iny
	sta APU3

	lda #3
	sta APU0

	jmp _stream_update_loop

;--------------------------------------
::stream_set_block:
	stz spc_stream_block_repeat

	; Multiply by 3 because spc_stream_block_list points to a series of 24-bit pointers
	lda spc_stream_block
	asl a
	adc spc_stream_block
	tay

	lda spc_stream_block_list+0
	sta brr_stream_list+0
	lda spc_stream_block_list+1
	sta brr_stream_list+1

	; Get the 24-bit pointer from the list
	lda [brr_stream_list],y
	sta spc_stream_block_src+0
	iny
	lda [brr_stream_list],y
	sta spc_stream_block_src+1

	; A zero pointer indicates a stop
	ora spc_stream_block_src+0
	bne noeof
		ina ; A = 1
		sta spc_stream_stop_flag
		rts
	noeof:

	lda spc_stream_block_src+0
	sta brr_stream_list+0
	lda spc_stream_block_src+1
	sta brr_stream_list+1
	
	; Get the size
	lda [brr_stream_list]
	sta spc_stream_block_size
	
	lda #2
	sta spc_stream_block_ptr
	sta spc_stream_block_ptr_prev
	rts
.endproc
