; Macros for defining DispActorMeta frames
.macro Row8x8 xpos, ypos, tile1, tile2, tile3, tile4, tile5, tile6, tile7, tile8
  .ifnblank tile8
    .byt 8
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3, tile4, tile5, tile6, tile7, tile8
  .elseif (.not .blank(tile7))
    .byt 7
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3, tile4, tile5, tile6, tile7
  .elseif (.not .blank(tile6))
    .byt 6
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3, tile4, tile5, tile6
  .elseif (.not .blank(tile5))
    .byt 5
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3, tile4, tile5
  .elseif (.not .blank(tile4))
    .byt 4
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3, tile4
  .elseif (.not .blank(tile3))
    .byt 3
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3
  .elseif (.not .blank(tile2))
    .byt 2
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2
  .elseif (.not .blank(tile1))
    .byt 1
    .word .loword(xpos), .loword(ypos)
    .byt tile1
  .endif
.endmacro
.macro Row16x16 xpos, ypos, tile1, tile2, tile3, tile4, tile5, tile6, tile7, tile8
  .ifnblank tile8
    .byt 8|128
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3, tile4, tile5, tile6, tile7, tile8
  .elseif (.not .blank(tile7))
    .byt 7|128
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3, tile4, tile5, tile6, tile7
  .elseif (.not .blank(tile6))
    .byt 6|128
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3, tile4, tile5, tile6
  .elseif (.not .blank(tile5))
    .byt 5|128
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3, tile4, tile5
  .elseif (.not .blank(tile4))
    .byt 4|128
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3, tile4
  .elseif (.not .blank(tile3))
    .byt 3|128
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2, tile3
  .elseif (.not .blank(tile2))
    .byt 2|128
    .word .loword(xpos), .loword(ypos)
    .byt tile1, tile2
  .elseif (.not .blank(tile1))
    .byt 1|128
    .word .loword(xpos), .loword(ypos)
    .byt tile1
  .endif
.endmacro
.macro EndMetasprite
  .byt 255
.endmacro
FRAME_XFLIP = OAM_XFLIP >> 8
FRAME_YFLIP = OAM_YFLIP >> 8
