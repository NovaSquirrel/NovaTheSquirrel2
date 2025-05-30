.enum LO
  S_Custom
  R_Custom
  S_ByteRef1
  S_ByteRef2
  R_ByteRef1
  R_ByteRef2
  H_ByteRef1
  H_ByteRef2
  Wide1
  Tall1
  Rect1
  Wide2
  Tall2
  Rect2
  Wide3
  Tall3
  Rect3
  Wide4
  Tall4
  Rect4
  R_Empty
  R_Bricks
  R_SolidBlock
  R_Ice
  R_LedgeMiddle
  R_Stone
  R_Sand
  S_Bricks
  S_Prize
  S_SolidBlock
  S_PickupBlock
  S_PushBlock
  S_Heart
  S_SmallHeart
  S_Sign
  S_Money
  S_Spring
  S_Rock
  S_LedgeLeft
  S_LedgeRight
  S_LedgeSolidLeft
  S_LedgeSolidRight
  S_DoorTop
  S_SmallTreeTopLeft
  S_SmallTreeBushTopLeft
  SlopeL_Gradual
  SlopeL_Medium
  SlopeL_Steep
  SlopeR_Gradual
  SlopeR_Medium
  SlopeR_Steep
.endenum

.enum LN1
  Empty
  Ladder
  SpikesUp
  SpikesDown
  Ledge
  Money
  PickupBlock
  PushBlock
  LedgeMiddle
  Prize
  SolidBlock
  LedgeSolidBottom
  LedgeSolidLeft
  LedgeSolidRight
  FloatingPlatform
  FloatingPlatformFallthrough
.endenum

.enum LN2
  RopeLadder
  Bridge
  WoodPlatform
  Pier
  Fence
  Stone
  Sand
  LeafCube
  TreeLog
  Grass
  Vines
  SmallTreeTrunk
  RedFlower
  BlueFlower
  BlueFlowerSpiral
  RedFlowerSpiral
.endenum

.enum LN3
  BlueFlowerCircle
  BranchPlatformMiddle
  CeilingBarrier
  LogPlatform
  LogPlatformSupportLeft
  LogPlatformSupportRight
  WoodArrowRight
  WoodArrowDown
  WoodArrowLeft
  WoodArrowUp
  MetalArrowRight
  MetalArrowDown
  MetalArrowLeft
  MetalArrowUp
  WoodCrate
  MetalCrate
.endenum

.enum LN4
  MetalForkUp
  MetalForkDown
  ArrowRevealSolid
  Water
  WoodPlanks
.endenum

.macro LSpr Type, Direction, XPos, YPos, Extra
  .byt XPos
  .byt (Direction<<7)|YPos
  .byt <Type
  ; Last byte combines extra bits with four extra sprite type bits.
  ; May be completely overboard
  .ifnblank Extra
    .byt (Extra<<4)|(>Type)
  .else
    .byt >Type
  .endif
.endmacro

.macro LObj Type, XPos, YPos, Extra1, Extra2
  .assert XPos >= 0 && XPos <= 255, error, "Invalid X position"
  .assert YPos >= 0 && YPos <= 31, error, "Invalid Y position"
  .byt (Type<<1) | (YPos>>4)
  .byt (XPos<<4) | (YPos&15)
  .ifnblank Extra1
    .byt Extra1
    .ifnblank Extra2
      .byt Extra2
    .endif
  .endif
.endmacro

.macro LObjN Type, XPos, YPos, Width, Height, Extra
  .assert XPos >= 0 && XPos <= 255, error, "Invalid X position"
  .assert YPos >= 0 && YPos <= 31, error, "Invalid Y position"
  .assert Width >= 0 && Width <= 15, error, "Invalid width"
  .assert Height >= 0 && Height <= 15, error, "Invalid height"
  LObj Type, XPos, YPos, (Width<<4)|Height
  .ifnblank Extra
    .byt Extra
  .endif
.endmacro

.macro LSCustom Type, XPos, YPos
  .assert XPos >= 0 && XPos <= 255, error, "Invalid X position"
  .assert YPos >= 0 && YPos <= 31, error, "Invalid Y position"
  LObj LO::S_Custom, XPos, YPos
  .word Type
.endmacro

.macro LRCustom Type, XPos, YPos, Width, Height
  .assert XPos >= 0 && XPos <= 255, error, "Invalid X position"
  .assert YPos >= 0 && YPos <= 31, error, "Invalid Y position"
  .assert Width >= 0 && Width <= 15, error, "Invalid width"
  .assert Height >= 0 && Height <= 15, error, "Invalid height"
  LObj LO::R_Custom, XPos, YPos
  .word Type
  .byt (Width<<4)|Height
.endmacro

.macro LSByteRef Type, XPos, YPos ; Single
  .assert XPos >= 0 && XPos <= 255, error, "Invalid X position"
  .assert YPos >= 0 && YPos <= 31, error, "Invalid Y position"
  .assert Type < 512, error, "Invalid block type"
  LObj (LO::S_ByteRef1 + >Type), XPos, YPos
  .byte <Type
.endmacro

.macro LRByteRef Type, XPos, YPos, Width, Height ; Rectangle
  .assert XPos >= 0 && XPos <= 255, error, "Invalid X position"
  .assert YPos >= 0 && YPos <= 31, error, "Invalid Y position"
  .assert Width >= 0 && Width <= 15, error, "Invalid width"
  .assert Height >= 0 && Height <= 15, error, "Invalid height"
  .assert Type < 512, error, "Invalid block type"
  LObj (LO::R_ByteRef1 + >Type), XPos, YPos
  .byte <Type
  .byt (Width<<4)|Height
.endmacro

.macro LHByteRef Type, XPos, YPos, Width, Height ; Huge
  .assert XPos >= 0 && XPos <= 255, error, "Invalid X position"
  .assert YPos >= 0 && YPos <= 31, error, "Invalid Y position"
  .assert Width >= 0 && Width <= 255, error, "Invalid width"
  .assert Height >= 0 && Height <= 255, error, "Invalid height"
  .assert Type < 512, error, "Invalid block type"
  LObj (LO::H_ByteRef1 + >Type), XPos, YPos
  .byte <Type
  .byt Width, Height
.endmacro

.macro LFinished
  .byt $f0
.endmacro

.macro LSetX NewX
  .byt $f1, NewX
.endmacro

.macro LWriteCol Col1, Col2, Col3, Col4, Col5, Col6, Col7, Col8
  .ifnblank Col8
    .byt $f4
    .byt 8, Col1, Col2, Col3, Col4, Col5, Col6, Col7, Col8
  .else
  .ifnblank Col7
    .byt $f4
    .byt 7, Col1, Col2, Col3, Col4, Col5, Col6, Col7
  .else
  .ifnblank Col6
    .byt $f4
    .byt 6, Col1, Col2, Col3, Col4, Col5, Col6
  .else
  .ifnblank Col5
    .byt $f4
    .byt 5, Col1, Col2, Col3, Col4, Col5
  .else
  .ifnblank Col4
    .byt $f4
    .byt 4, Col1, Col2, Col3, Col4
  .else
  .ifnblank Col3
    .byt $f4
    .byt 3, Col1, Col2, Col3
  .else
  .ifnblank Col2
    .byt $f3
    .byt Col1, Col2
  .else
    .byt $f2
    .byt Col1
  .endif
  .endif
  .endif
  .endif
  .endif
  .endif
  .endif
.endmacro

.macro LXMinus16
  .byt $f5
.endmacro

.macro LXPlus16
  .byt $f6
.endmacro

LSpecialCmd = $f7

.macro LToggleYExtension
  .byt $f8
.endmacro

.enum LevelSpecialConfig
  AlternateBuffer
  ActorListInRAM
.endenum
