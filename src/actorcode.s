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

.include "snes.inc"
.include "global.inc"
.smart

.segment "ActorData"
CommonTileBase = $40

.import DispActor16x16, DispParticle8x8
.import ActorWalk, ActorFall, ActorAutoBump

; -------------------------------------

.a16
.i16
.export DrawBurger
.proc DrawBurger
;  lda PlayerOnGround
;  and #255
  lda #0
  jml DispActor16x16
.endproc

.a16
.i16
.export RunBurger
.proc RunBurger
;  lda PlayerPX
;  sta ActorPX,x
;  lda PlayerPY
;  sub #$400
;  sta ActorPY,x
  lda #3
  jml ActorWalk
.endproc

.a16
.i16
.export DrawCannonH
.proc DrawCannonH
  rtl
.endproc

.a16
.i16
.export DrawCannonV
.proc DrawCannonV
  rtl
.endproc

.a16
.i16
.export DrawCheckpoint
.proc DrawCheckpoint
  rtl
.endproc

.a16
.i16
.export RunCheckpoint
.proc RunCheckpoint
  rtl
.endproc

.a16
.i16
.export DrawMovingPlatform
.proc DrawMovingPlatform
  rtl
.endproc

.a16
.i16
.export RunMovingPlatformH
.proc RunMovingPlatformH
  rtl
.endproc

.a16
.i16
.export RunMovingPlatformLine
.proc RunMovingPlatformLine
  rtl
.endproc

.a16
.i16
.export RunMovingPlatformPush
.proc RunMovingPlatformPush
  rtl
.endproc

.a16
.i16
.export DrawOwl
.proc DrawOwl
  rtl
.endproc

.a16
.i16
.export RunOwl
.proc RunOwl
  rtl
.endproc

.a16
.i16
.export DrawPlodder
.proc DrawPlodder
  lda retraces
  lsr
  and #2
  ora #OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunPlodder
.proc RunPlodder
  jml ActorFall
.endproc

.a16
.i16
.export DrawSneaker
.proc DrawSneaker
  lda retraces
  lsr
  and #2
  ora #OAM_PRIORITY_2
  jml DispActor16x16
.endproc

.a16
.i16
.export RunSneaker
.proc RunSneaker
  lda #$40
  jsl ActorWalk
  jsl ActorAutoBump

  jml ActorFall
.endproc

.a16
.i16
.export RunAnyCannonH
.proc RunAnyCannonH
  rtl
.endproc

.a16
.i16
.export RunAnyCannonV
.proc RunAnyCannonV
  rtl
.endproc

.a16
.i16
.export RunBurgerCannonH
.proc RunBurgerCannonH
  rtl
.endproc

.a16
.i16
.export RunBurgerCannonV
.proc RunBurgerCannonV
  rtl
.endproc

; -------------------------------------
.a16
.i16
.export DrawPoof
.proc DrawPoof
  rts
.endproc

.a16
.i16
.export RunPoof
.proc RunPoof
  rts
.endproc

.a16
.i16
.export DrawLandingParticle
.proc DrawLandingParticle
  lda ParticleTimer,x
  lsr
  lsr
  lsr
  add #CommonTileBase+$38+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export RunLandingParticle
.proc RunLandingParticle
  inc ParticleTimer,x
  lda ParticleTimer,x
  cmp #8*2
  bne :+
    stz ParticleType,x
  :
  rts
.endproc

.a16
.i16
.export DrawPrizeParticle
.proc DrawPrizeParticle
  rts
.endproc

.a16
.i16
.export RunPrizeParticle
.proc RunPrizeParticle
  rts
.endproc


.a16
.i16
.export DrawBricksParticle
.proc DrawBricksParticle
  lda #CommonTileBase+$3c+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export RunBricksParticle
.proc RunBricksParticle
  lda ParticlePX,x
  add ParticleVX,x
  sta ParticlePX,x

  lda ParticleVY,x
  add #4
  sta ParticleVY,x
  add ParticlePY,x
  sta ParticlePY,x
  cmp #256*32
  bcc :+
    stz ParticleType,x
  :

  dec ParticleTimer,x
  bne :+
    stz ParticleType,x
  :
  rts
.endproc
