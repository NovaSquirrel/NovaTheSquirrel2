; Super Princess Engine
; Copyright (C) 2019 NovaSquirrel
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

; Format for 16-bit X and Y positions and speeds:
; HHHHHHHH LLLLSSSS
; |||||||| ||||++++ - subpixels
; ++++++++ ++++------ actual pixels


.segment "BSS"
  retraces: .res 1
  keydown:  .res 2
  keylast:  .res 2
  keynew:   .res 2

.segment "BSS7E"


.segment "BSS7F"
  LEVEL_WIDTH = 256
  LEVEL_HEIGHT = 32
  LEVEL_TILE_SIZE = 2
  LevelBuf: .res 256*32*2


