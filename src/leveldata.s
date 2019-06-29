; This is automatically generated. Edit level JSON files instead
.include "snes.inc"
.include "actorenum.s"
.include "graphicsenum.s"
.include "paletteenum.s"
.include "blockenum.s"
.include "leveldata.inc"

.segment "LevelBank1"

.export level_demo
level_demo:
  .byt 0|0
  .byt 7
  .byt 29
  .byt 0
  .word RGB(15,23,31)
  .word $ffff
  .addr .loword(level_demo_sp)
  .dbyt 0

  .byt GraphicsUpload::SPWalker
  .byt GraphicsUpload::SPCannon
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt 255

  .byt Palette::FGCommon
  .byt Palette::FGGrassy
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt Palette::BGForest

  .byt GraphicsUpload::FGCommon
  .byt GraphicsUpload::FGGrassy
  .byt GraphicsUpload::FGTropicalWood
  .byt GraphicsUpload::BGForest
  .byt 255
  .addr .loword(level_demo_fg)

level_demo_fg:
  LObjN LO::Rect1, 0, 30, 0, LN1::Ledge, 17
  LObjN LO::Wide1, 2, 26, 4, LN1::Prize
  LObjN LO::Tall1, 7, 24, 5, LN1::Ladder
  LObjN LO::Wide1, 1, 24, 5, LN1::Ledge
  LObjN LO::Rect1, 0, 21, 1, LN1::Money, 1
  LObjN LO::Wide1, 2, 21, 5, LN1::Ledge
  LObjN LO::Rect1, 0, 18, 1, LN1::Money, 1
  LObjN LO::R_Bricks, 2, 17, 2, 0
  LObjN LO::SlopeL_Gradual, 4, 29, 0, 0
  LObjN LO::SlopeL_Medium, 4, 28, 1, 1
  LObjN LO::SlopeL_Steep, 4, 26, 3, 3
  LObjN LO::SlopeL_Medium, 4, 22, 1, 1
  LObjN LO::SlopeL_Gradual, 4, 20, 0, 0
  LObjN LO::Wide1, 4, 20, 6, LN1::Ledge
  LObjN LO::Wide1, 1, 18, 4, LN1::Money
  LObjN LO::SlopeR_Gradual, 6, 20, 0, 0
  LObjN LO::SlopeR_Medium, 4, 21, 1, 1
  LObjN LO::SlopeR_Steep, 4, 23, 3, 3
  LObjN LO::SlopeR_Medium, 4, 27, 1, 1
  LObjN LO::SlopeR_Gradual, 4, 29, 0, 0
  LObjN LO::Wide1, 4, 30, 1, LN1::Ledge
  LObj  LO::S_Spring, 1, 29
  LRCustom Block::LedgeSolidLeft, 1, 26, 0, 4
  LObjN LO::Wide1, 1, 26, 5, LN1::Ledge
  LObj  LO::S_Spring, 5, 25
  LRCustom Block::LedgeSolidLeft, 1, 22, 0, 4
  LObjN LO::Wide1, 1, 22, 3, LN1::Ledge
  LRCustom Block::LedgeSolidRight, 4, 22, 0, 9
  LFinished

level_demo_sp:
  LSpr Object::Sneaker, 0, 3, 25
  LSpr Object::Sneaker, 0, 15, 20
  LSpr Object::Sneaker, 1, 17, 29
  LSpr Object::Sneaker, 0, 67, 25
  LSpr Object::Sneaker, 1, 74, 21
  .byt 255


.export level_ztest
level_ztest:
  .byt 0|0
  .byt 7
  .byt 29
  .byt 0
  .word RGB(15,23,31)
  .word $ffff
  .addr .loword(level_ztest_sp)
  .dbyt 0

  .byt GraphicsUpload::SPWalker
  .byt GraphicsUpload::SPCannon
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt 255

  .byt Palette::FGCommon
  .byt Palette::FGGrassy
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt 255
  .byt Palette::BGForest

  .byt GraphicsUpload::FGCommon
  .byt GraphicsUpload::FGGrassy
  .byt GraphicsUpload::FGTropicalWood
  .byt GraphicsUpload::BGForest
  .byt 255
  .addr .loword(level_ztest_fg)

level_ztest_fg:
  LObjN LO::Rect1, 0, 30, 1, LN1::SolidBlock, 35
  LObjN LO::R_Bricks, 7, 15, 6, 5
  LRCustom Block::SmallHeart, 1, 24, 0, 2
  LXMinus16
  LObjN LO::R_SolidBlock, 11, 18, 5, 4
  LRCustom Block::Heart, 3, 25, 4, 0
  LRCustom Block::Heart, 7, 26, 4, 0
  LRCustom Block::SmallHeart, 2, 25, 0, 2
  LObjN LO::R_Bricks, 1, 20, 3, 3
  LObjN LO::R_SolidBlock, 2, 22, 3, 3
  LObjN LO::Rect1, 8, 21, 4, LN1::Money, 4
  LXMinus16
  LObjN LO::R_SolidBlock, 14, 23, 3, 3
  LFinished

level_ztest_sp:
  LSpr Object::Sneaker, 1, 17, 29
  .byt 255


