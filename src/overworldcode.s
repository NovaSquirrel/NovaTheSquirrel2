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
.include "pathenum.s"
.include "graphicsenum.s"
.include "paletteenum.s"
.smart

PATH_ALLOW_DOWN  = %0001
PATH_ALLOW_UP    = %0010
PATH_ALLOW_RIGHT = %0100
PATH_ALLOW_LEFT  = %1000


MapMetatileBuffer    = Scratchpad + (256*0) ; 224 bytes
MapPathBuffer        = Scratchpad + (256*1) ; 224 bytes
MapDecorationSprites = Scratchpad + (256*2) ; 512 bytes
MapPrioritySprites   = Scratchpad + (256*4) ; ? bytes
MapDecorationLength  = TouchTemp     ; number of bytes
MapPriorityLength    = TouchTemp + 2 ; number of bytes
MapPlayerMoving      = TouchTemp + 4 ; player is currently moving

.import Overworld_Pointers
.import OWBlockTopLeft, OWBlockTopRight, OWBlockBottomLeft, OWBlockBottomRight
.import OWDecorationGraphic, OWDecorationPalette, OWDecorationPic
.import Overworld_LevelMarkers, Overworld_LevelPointers
.export OpenOverworld

.segment "Overworld"

.a16
.i16
.export ExitToOverworld
.proc ExitToOverworld
  ldx #$1ff
  txs ; Reset the stack pointer so no cleanup is needed
  jsl WaitVblank
  seta8
  lda #FORCEBLANK
  sta PPUBRIGHT
.endproc

; Input: A = overworld number
.a16
.i16
.proc OpenOverworld
  phk
  plb

  setaxy16
  lda OverworldMap
  and #255
  asl
  tax
  lda Overworld_Pointers,x
  ; Can actually treat it as a 16-bit pointer, overworld data is limited to this bank
  sta DecodePointer

  lda #$ffff
  sta SpriteTileSlots+2*0
  sta SpriteTileSlots+2*1
  sta SpriteTileSlots+2*2
  sta SpriteTileSlots+2*3
  sta SpritePaletteSlots+2*0
  sta SpritePaletteSlots+2*1
  sta SpritePaletteSlots+2*2
  sta SpritePaletteSlots+2*3
  stz MapPlayerMoving

  ldx #$c000 >> 1
  ldy #0
  jsl ppu_clear_nt

  ; Start reading the overworld
  ldy #0
  seta8


  ; -------------------------

  ldx #0
UploadGraphicLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitGraphicLoop
  jsl DoGraphicUpload
  bra UploadGraphicLoop
ExitGraphicLoop:

  lda #GraphicsUpload::OWNova
  jsl DoGraphicUpload
  lda #GraphicsUpload::OWLevel
  jsl DoGraphicUpload
  lda #GraphicsUpload::OWPaths
  jsl DoGraphicUpload
  lda #GraphicsUpload::SolidTiles
  jsl DoGraphicUpload

  ; -------------------------

  ldx #0
UploadPaletteLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitPaletteLoop
  phy
  txy
  jsl DoPaletteUpload
  ply
  inx
  bra UploadPaletteLoop
ExitPaletteLoop:

  phy
  ldy #0+7
  lda #Palette::FGCommon
  jsl DoPaletteUpload
  ldy #8+6
  lda #Palette::SPNova
  jsl DoPaletteUpload
  ldy #8+7
  lda #Palette::OWLevel
  jsl DoPaletteUpload
  ply

  ; -------------------------

  ldx #0
UploadSpriteGraphicLoop:
  lda (DecodePointer),y
  sta SpriteTileSlots,x
  iny
  cmp #255
  beq ExitSpriteGraphicLoop

  pha
  txa
  asl
  sta GraphicUploadOffset+1
  stz GraphicUploadOffset+0
  pla
  jsl DoGraphicUploadWithOffset
  inx
  bra UploadSpriteGraphicLoop
ExitSpriteGraphicLoop:

  ; -------------------------

  ldx #8
UploadSpritePaletteLoop:
  lda (DecodePointer),y
  sta SpritePaletteSlots-8,x
  iny
  cmp #255
  beq ExitSpritePaletteLoop
  phy
  txy
  jsl DoPaletteUpload
  ply
  inx
  bra UploadSpritePaletteLoop
ExitSpritePaletteLoop:

  ; -------------------------

  ldx #0
  stz 0 ; Initialize the repeat counter
DecompressMapLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitMapLoop

  ; If the high bit is set then set the repeat counter
  cmp #128
  bcc :+
    and #127
    inc a
    sta 0
    bra DecompressMapLoop
  :

  ; Repeat for counter + 1 times
  inc 0
: sta f:MapMetatileBuffer,x
  inx
  dec 0
  bne :-
  bra DecompressMapLoop
ExitMapLoop:

  ; -------------------------

  ldx #0
ReadPrioritySpriteLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitPrioritySpriteLoop
  jsr GetOverworldSpriteTile
  lda 0
  sta f:MapPrioritySprites+2,x
  ; Also returns 1, use it later

  ; Get X
  lda (DecodePointer),y
  iny
  sta f:MapPrioritySprites+0,x

  ; Get Y
  lda (DecodePointer),y
  iny
  sta f:MapPrioritySprites+1,x

  ; Get attributes
  lda (DecodePointer),y
  iny
  ora 1
  sta f:MapPrioritySprites+3,x
  inx
  inx
  inx
  inx
  bra ReadPrioritySpriteLoop
ExitPrioritySpriteLoop:
  stx MapPriorityLength

  ; -------------------------

  ldx #0
ReadDecorationSpriteLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitDecorationSpriteLoop
  jsr GetOverworldSpriteTile
  lda 0
  sta f:MapDecorationSprites+2,x
  ; Also returns 1, use it later

  ; Get X
  lda (DecodePointer),y
  iny
  sta f:MapDecorationSprites+0,x

  ; Get Y
  lda (DecodePointer),y
  iny
  sta f:MapDecorationSprites+1,x

  ; Get attributes
  lda (DecodePointer),y
  iny
  ora 1
  sta f:MapDecorationSprites+3,x
  inx
  inx
  inx
  inx
  bra ReadDecorationSpriteLoop
ExitDecorationSpriteLoop:

  ; Add the level markers too!
  ; tiles start at 32
  phy
  lda #16 ; 16 level slots
  sta 0
  tdc ; Clear A
  lda OverworldMap ; Choose which list of 16 level slots
  asl
  asl
  asl
  asl
  asl
  tay
AddLevelMarkerLoop:
  lda Overworld_LevelMarkers,y
  cmp #255
  beq UnusedLevelMarker
  pha
  and #15
  asl
  asl
  asl
  asl
  sta f:MapDecorationSprites+0,x ; X
  pla
  and #$f0
  sub #$10 ; Move up 16 pixels I guess
  sta f:MapDecorationSprites+1,x ; Y

  lda Overworld_LevelMarkers+1,y
  and #$f0
  lsr
  lsr
  lsr
  ora #32
  sta f:MapDecorationSprites+2,x ; Tile
  lda #>(OAM_COLOR_7|OAM_PRIORITY_2)
  sta f:MapDecorationSprites+3,x ; Attributes

  ; Next sprite
  inx
  inx
  inx
  inx
UnusedLevelMarker:
  iny
  iny
  dec 0
  bne AddLevelMarkerLoop
  ply



  stx MapDecorationLength

  ; -------------------------

  ldx #0
  stz 0 ; Initialize the repeat counter
DecompressPathLoop:
  lda (DecodePointer),y
  iny
  cmp #255
  beq ExitPathLoop

  ; If the high bit is set then set the repeat counter
  cmp #128
  bcc :+
    and #127
    inc a
    sta 0
    bra DecompressPathLoop
  :

  ; Repeat for counter + 1 times
  inc 0
: sta f:MapPathBuffer,x
  inx
  dec 0
  bne :-
  bra DecompressPathLoop
ExitPathLoop:

  ; ---------------

  ; Render the overworld
  lda #INC_DATAHI
  sta PPUCTRL
  seta16
  ldx #0
  lda #$d000>>1
  sta PPUADDR
RenderLoop:
  ; Top
  lda #16
  sta 0
: lda f:MapMetatileBuffer,x
  and #255
  asl
  tay
  lda OWBlockTopLeft,y
  sta PPUDATA
  lda OWBlockTopRight,y
  sta PPUDATA

  inx
  dec 0
  bne :-

  txa
  sub #16
  tax

  ; Bottom
  lda #16
  sta 0
: lda f:MapMetatileBuffer,x
  and #255
  asl
  tay
  lda OWBlockBottomLeft,y
  sta PPUDATA
  lda OWBlockBottomRight,y
  sta PPUDATA

  inx
  dec 0
  bne :-

  cpx #224
  bne RenderLoop

  ; -----------------------------------------------------------------
  ; Render the path layer (oh boy)
  ldx #0
  lda #$c000>>1
  sta PPUADDR
PathRenderLoop:
  ; Top
  lda #16
  sta 0
: lda f:MapPathBuffer,x
  and #255
  asl
  tay
  lda OWPathTopLeft,y
  sta PPUDATA
  lda OWPathTopRight,y
  sta PPUDATA

  inx
  dec 0
  bne :-

  txa
  sub #16
  tax

  ; Bottom
  lda #16
  sta 0
: lda f:MapPathBuffer,x
  and #255
  asl
  tay
  lda OWPathBottomLeft,y
  sta PPUDATA
  lda OWPathBottomRight,y
  sta PPUDATA

  inx
  dec 0
  bne :-

  cpx #224
  bne PathRenderLoop







  ; -----------------------------------
  ; Set up PPU registers
  ; (Is this the appropriate place for this?)
  seta8
  lda #1
  sta BGMODE       ; mode 1

  stz BGCHRADDR+0  ; bg planes 0-1 CHR at $0000
  lda #$e>>1
  sta BGCHRADDR+1  ; bg plane 2 CHR at $e000

  lda #$8000 >> 14
  sta OBSEL      ; sprite CHR at $8000, sprites are 8x8 and 16x16

  lda #1 | ($c000 >> 9)
  sta NTADDR+0   ; plane 0 nametable at $c000, 2 screens wide
  lda #1 | ($d000 >> 9)
  sta NTADDR+1   ; plane 1 nametable also at $d000, 2 screens wide
  lda #0 | ($e000 >> 9)
  sta NTADDR+2   ; plane 2 nametable at $e000, 1 screen

  ; set up plane 0's scroll
  stz BGSCROLLX+0
  stz BGSCROLLX+0
  stz BGSCROLLX+2
  stz BGSCROLLX+2
  lda #$FF
  sta BGSCROLLY+0  ; The PPU displays lines 1-224, so set scroll to
  sta BGSCROLLY+0  ; $FF so that the first displayed line is line 0
  sta BGSCROLLY+2
  sta BGSCROLLY+2

  stz PPURES
  lda #%00010011  ; enable sprites, plane 0 and 1
  sta BLENDMAIN
  lda #VBLANK_NMI|AUTOREAD  ; but disable htime/vtime IRQ
  sta PPUNMI






  ; -----------------------------------
OverworldLoop:
  setaxy16
  jsl WaitKeysReady ; Also clears OamPtr


  seta8
  lda MapPlayerMoving
  beq NotMoving
    tdc ; Clear A
    lda OverworldDirection
    tay

    lda OverworldPlayerX
    add MovementOffsetX,y
    sta OverworldPlayerX

    lda OverworldPlayerY
    add MovementOffsetY,y
    sta OverworldPlayerY

    ; Time to stop moving?
    lda OverworldPlayerX
    ora OverworldPlayerY
    and #15
    jne CantMove
      jsr GetLevelMarkerUnderPlayer
      bcs StopMoving
      jsr GetPathUnderPlayer
      sta 0
      tdc ; Clear all of A
      lda OverworldDirection
      tax
      lda f:AllowBitForDirection,x
      and 0
      bne :+
StopMoving:
        stz MapPlayerMoving
      :
      jmp CantMove
  NotMoving:


  ; Start walking
  lda keynew+1
  and #>KEY_LEFT
  beq NotLeft
    jsr GetPathUnderPlayer
    and #PATH_ALLOW_LEFT
    beq NotLeft
    dec OverworldPlayerX
    dec OverworldPlayerX
    lda #3
    sta OverworldDirection
    inc MapPlayerMoving
NotLeft:
  lda keynew+1
  and #>KEY_RIGHT
  beq NotRight
    jsr GetPathUnderPlayer
    and #PATH_ALLOW_RIGHT
    beq NotRight
    inc OverworldPlayerX
    inc OverworldPlayerX
    stz OverworldDirection
    inc MapPlayerMoving
NotRight:

  lda keynew+1
  and #>KEY_DOWN
  beq NotDown
    jsr GetPathUnderPlayer
    and #PATH_ALLOW_DOWN
    beq NotDown
    inc OverworldPlayerY
    inc OverworldPlayerY
    lda #1
    sta OverworldDirection
    inc MapPlayerMoving
NotDown:

  lda keynew+1
  and #>KEY_UP
  beq NotUp
    jsr GetPathUnderPlayer
    and #PATH_ALLOW_UP
    beq NotUp
    dec OverworldPlayerY
    dec OverworldPlayerY
    lda #2
    sta OverworldDirection
    inc MapPlayerMoving
NotUp:

  lda keynew+1
  and #>KEY_START
  bne :+
  lda keynew
  and #KEY_A
  beq NotStartLevel
:   jsr GetLevelMarkerUnderPlayer
    bcc NotStartLevel
      pha
      jsl WaitVblank
      lda #FORCEBLANK
      sta PPUBRIGHT
      tdc   ; Clear top byte of accumulator
      pla

      and #$f0 ; Just get the color
      cmp #$20 ; Maffi level?
      beq StartMaffiLevel

      lda 0 ; Level number
      .import StartLevel
      jml StartLevel
    StartMaffiLevel:
      lda 0 ; Level number
      .import StartMode7Level
      jml StartMode7Level
  NotStartLevel:

CantMove:
  seta16


  ; Draw all the sprites
  ldy OamPtr
  ldx #0
OverworldPriorityRenderSpriteLoop:
  lda f:MapPrioritySprites+0,x
  sta OAM+0,y
  lda f:MapPrioritySprites+2,x
  jsr RenderSpriteShared
  cpx MapPriorityLength
  bne OverworldPriorityRenderSpriteLoop
  ; -----------------------------------
  seta8
  lda OverworldPlayerX
  sta OAM+0+(4*0),y
  sta OAM+0+(4*1),y
  lda OverworldPlayerY
  sta OAM+1+(4*1),y
  sub #16
  sta OAM+1+(4*0),y
  lda #>(OAM_PRIORITY_2|OAM_COLOR_6)
  sta OAM+3+(4*0),y
  sta OAM+3+(4*1),y
  lda OverworldDirection
  cmp #3
  bne :+
    lda #>(OAM_PRIORITY_2|OAM_COLOR_6|OAM_XFLIP)
    sta OAM+3+(4*0),y
    sta OAM+3+(4*1),y
    lda #0
  :
  asl
  asl
  sta OAM+2+(4*0),y
  ora #2
  sta OAM+2+(4*1),y

  ; Player uses two sprites
  seta16
  lda #$0200
  sta OAMHI+0,y
  sta OAMHI+4,y
  tya
  add #4*2
  tay
  ; -----------------------------------
  ldx #0
OverworldRenderSpriteLoop:
  lda f:MapDecorationSprites+0,x
  sta OAM+0,y
  lda f:MapDecorationSprites+2,x
  jsr RenderSpriteShared
  cpx MapDecorationLength
  bne OverworldRenderSpriteLoop
  sty OamPtr

  ldx OamPtr
  jsl ppu_clear_oam
  jsl ppu_pack_oamhi

  jsl WaitVblank
  jsl ppu_copy_oam
  seta8
  lda #15
  sta PPUBRIGHT
  jmp OverworldLoop

  rtl

.a16
RenderSpriteShared:
  sta OAM+2,y
  lda #$0200  ; Use 16x16 sprites
  sta OAMHI,y
  inx
  inx
  inx
  inx
NextOAM:
  iny
  iny
  iny
  iny
  rts

MovementOffsetX: .lobytes 2, 0, 0, -2
MovementOffsetY: .lobytes 0, 2, -2, 0

AllowBitForDirection:
  .byt PATH_ALLOW_RIGHT
  .byt PATH_ALLOW_DOWN
  .byt PATH_ALLOW_UP
  .byt PATH_ALLOW_LEFT
.endproc

; Index the player is currently standing over
.a8
.i16
.proc GetIndexUnderPlayer
  tdc ; Clear the entire accumulator
  lda OverworldPlayerY
  and #$f0
  sta 0
  lda OverworldPlayerX
  lsr
  lsr
  lsr
  lsr
  ora 0
  tax
  rts
.endproc

; Carry set = There is a level marker under the player
; If there is a level, level header pointer is in LevelHeaderPointer,
; the level number is in 0, and the color/directions are in A
.a8
.i16
.proc GetLevelMarkerUnderPlayer
  jsr GetIndexUnderPlayer
  add #$10 ; Shouldn't need this; fix overworld.py maybe
  sta 0 ; Compare against this

  ldx #0
  tdc ; Clear top byte of accumulator

  lda OverworldMap ; Choose which list of 16 level slots
  asl
  asl
  asl
  asl
  asl ; Double it because it's a set of position,info pairs
  tay
AddLevelMarkerLoop:
  lda Overworld_LevelMarkers,y
  cmp 0
  beq Yes
  iny
  iny
  inx
  cpx #16 ; 16 level slots
  bne AddLevelMarkerLoop
Nope:
  clc ; Not over a level marker
  rts

Yes:
  lda Overworld_LevelMarkers+1,y
  pha ; Level color (top nybble) and directions (bottom nybble)

  ; X = the marker index within the world
  ; First get the level ID
  lda OverworldMap
  asl
  asl
  asl
  asl
  sta 0
  txa
  tsb 0

  ; Multiply OverworldMap by 3 bytes per pointer
  lda 0
  asl
  adc 0 ; (Carry is probably clear)
  tay

  ; Copy over the level header pointer
  lda Overworld_LevelPointers+0,y
  sta LevelHeaderPointer+0
  lda Overworld_LevelPointers+1,y
  sta LevelHeaderPointer+1
  lda Overworld_LevelPointers+2,y
  sta LevelHeaderPointer+2

  pla ; A = level color and directions
  sec ; Is over a level marker
  rts
.endproc


; Get the path ID under the player
.a8
.i16
.proc GetPathUnderPlayer
  jsr GetIndexUnderPlayer
  lda f:MapPathBuffer,x
  rts
.endproc



; Input: A = overworld sprite ID
; Output: 0 and 1
.a8
.i16
.proc GetOverworldSpriteTile
  phx
  phy

  setxy8
  tay

  ; Find the graphic
  lda OWDecorationGraphic,y
  ldx #3
: cmp SpriteTileSlots,x  
  beq :+
  dex
  bpl :-
: ; No handler for not finding it

  txa
  ; Multiply by 32
  asl
  asl
  asl
  asl
  asl
  ora OWDecorationPic,y
  sta 0

  ; Find the palette
  lda OWDecorationPalette,y
  ldx #3
: cmp SpritePaletteSlots,x  
  beq :+
  dex
  bpl :-
: ; No handler for not finding it

  txa
  asl
  ora #(>OAM_PRIORITY_2)|1 ; second set of 256 sprite tiles
  sta 1

  setxy16

  ply
  plx
  rts
.endproc


PathBase = (1024-32) | (7 << 10) ; Start at 7C00 and palette 7
XF = $4000 ; X flip
YF = $8000 ; Y flip
R   = 0
D   = 1
RD  = 2
Dot = 3

.proc OWPathTopLeft
; ....
  .word 0
; ...D
  .word PathBase|Dot
; ..U.
  .word PathBase|R
; ..UD
  .word PathBase|R
; .R..
  .word PathBase|Dot
; .R.D
  .word PathBase|Dot
; .RU.
  .word PathBase|R
; .RUD
  .word PathBase|R
; L...
  .word PathBase|D
; L..D
  .word PathBase|D
; L.U.
  .word PathBase|RD
; L.UD
  .word PathBase|RD
; LR..
  .word PathBase|D
; LR.D
  .word PathBase|D
; LRU.
  .word PathBase|RD
; LRUD
  .word PathBase|RD
; -----------------
;  PathWideCurveUL_A
  .word 0
;  PathWideCurveUL_B
  .word PathBase|8
;  PathWideCurveUL_C
  .word PathBase|4
;  PathWideCurveUR_A
  .word PathBase|D
;  PathWideCurveUR_B
  .word 0
;  PathWideCurveUR_D
  .word PathBase|5|XF
;  PathWideCurveDL_A
  .word PathBase|R
;  PathWideCurveDL_C
  .word 0
;  PathWideCurveDL_D
  .word PathBase|7|YF
;  PathWideCurveDR_B
  .word PathBase|R
;  PathWideCurveDR_C
  .word PathBase|D
;  PathWideCurveDR_D
  .word PathBase|6|XF|YF
.endproc

.proc OWPathTopRight
; ....
  .word 0
; ...D
  .word PathBase|Dot|XF
; ..U.
  .word PathBase|R|XF
; ..UD
  .word PathBase|R|XF
; .R..
  .word PathBase|D
; .R.D
  .word PathBase|D
; .RU.
  .word PathBase|RD|XF
; .RUD
  .word PathBase|RD|XF
; L...
  .word PathBase|Dot|XF
; L..D
  .word PathBase|Dot|XF
; L.U.
  .word PathBase|R|XF
; L.UD
  .word PathBase|R|XF
; LR..
  .word PathBase|D
; LR.D
  .word PathBase|D
; LRU.
  .word PathBase|RD|XF
; LRUD
  .word PathBase|RD|XF
; -----------------
;  PathWideCurveUL_A
  .word 0
;  PathWideCurveUL_B
  .word PathBase|D
;  PathWideCurveUL_C
  .word PathBase|5
;  PathWideCurveUR_A
  .word PathBase|8|XF
;  PathWideCurveUR_B
  .word 0
;  PathWideCurveUR_D
  .word PathBase|4|XF
;  PathWideCurveDL_A
  .word PathBase|R|XF
;  PathWideCurveDL_C
  .word PathBase|6|YF
;  PathWideCurveDL_D
  .word PathBase|D
;  PathWideCurveDR_B
  .word PathBase|R|XF
;  PathWideCurveDR_C
  .word PathBase|7|XF|YF
;  PathWideCurveDR_D
  .word 0
.endproc

.proc OWPathBottomLeft
; ....
  .word 0
; ...D
  .word PathBase|R
; ..U.
  .word PathBase|Dot|YF
; ..UD
  .word PathBase|R
; .R..
  .word PathBase|Dot|YF
; .R.D
  .word PathBase|R
; .RU.
  .word PathBase|D|YF
; .RUD
  .word PathBase|R
; L...
  .word PathBase|D|YF
; L..D
  .word PathBase|RD|YF
; L.U.
  .word PathBase|D|YF
; L.UD
  .word PathBase|RD|YF
; LR..
  .word PathBase|D|YF
; LR.D
  .word PathBase|RD|YF
; LRU.
  .word PathBase|D|YF
; LRUD
  .word PathBase|RD|YF
; -----------------
;  PathWideCurveUL_A
  .word 0
;  PathWideCurveUL_B
  .word PathBase|7
;  PathWideCurveUL_C
  .word PathBase|R
;  PathWideCurveUR_A
  .word PathBase|D|YF
;  PathWideCurveUR_B
  .word PathBase|6|XF
;  PathWideCurveUR_D
  .word PathBase|R
;  PathWideCurveDL_A
  .word PathBase|4|YF
;  PathWideCurveDL_C
  .word 0
;  PathWideCurveDL_D
  .word PathBase|8|YF
;  PathWideCurveDR_B
  .word PathBase|5|XF|YF
;  PathWideCurveDR_C
  .word PathBase|D|YF
;  PathWideCurveDR_D
  .word 0
.endproc

.proc OWPathBottomRight
; ....
  .word 0
; ...D
  .word PathBase|R|XF
; ..U.
  .word PathBase|Dot|XF|YF
; ..UD
  .word PathBase|R|XF
; .R..
  .word PathBase|D
; .R.D
  .word PathBase|RD|XF|YF
; .RU.
  .word PathBase|Dot|XF|YF
; .RUD
  .word PathBase|RD|XF|YF
; L...
  .word PathBase|Dot|XF|YF
; L..D
  .word PathBase|R|XF
; L.U.
  .word PathBase|Dot|XF|YF
; L.UD
  .word PathBase|R|XF
; LR..
  .word PathBase|D|YF
; LR.D
  .word PathBase|RD|XF|YF
; LRU.
  .word PathBase|D|YF
; LRUD
  .word PathBase|RD|XF|YF
; -----------------
;  PathWideCurveUL_A
  .word PathBase|6
;  PathWideCurveUL_B
  .word PathBase|D|YF
;  PathWideCurveUL_C
  .word PathBase|R|XF
;  PathWideCurveUR_A
  .word PathBase|7|XF
;  PathWideCurveUR_B
  .word 0
;  PathWideCurveUR_D
  .word PathBase|R|XF
;  PathWideCurveDL_A
  .word PathBase|5|YF
;  PathWideCurveDL_C
  .word 0
;  PathWideCurveDL_D
  .word PathBase|D|YF
;  PathWideCurveDR_B
  .word PathBase|4|XF|YF
;  PathWideCurveDR_C
  .word PathBase|8|XF|YF
;  PathWideCurveDR_D
  .word 0
.endproc

