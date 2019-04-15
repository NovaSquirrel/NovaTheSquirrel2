.include "snes.inc"
.include "global.inc"
.smart

.segment "ZEROPAGE"

; Game variables
player_xlo:       .res 1  ; horizontal position is xhi + xlo/256 px
player_xhi:       .res 1
player_dxlo:      .res 1  ; speed in pixels per 256 s
player_yhi:       .res 1
player_frame_sub: .res 1
player_frame:     .res 1
player_facing:    .res 1

.segment "CODE4"

