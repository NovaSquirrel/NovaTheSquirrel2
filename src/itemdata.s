; This is automatically generated. Edit "items.txt" instead
.include "snes.inc"
.include "global.inc"
.export ItemFlags, ItemRun, ItemName
.import ItemPizzaSlice, ItemBerry, ItemWatermelon, ItemStrawberry

.segment "ItemData"

.proc ItemFlags
  .byt 0
  .byt 0 ; PizzaSlice
  .byt 0 ; Berry
  .byt 0 ; Watermelon
  .byt 0 ; Strawberry
  .byt 0 ; Balloon
  .byt 0 ; AutoBalloon
  .byt 0 ; LampOil
  .byt 0 ; Rope
  .byt 0 ; Bombs
  .byt 128 ; HeartsKey
  .byt 128 ; ClubsKey
  .byt 128 ; DiamondsKey
  .byt 128 ; SpadesKey
  .byt 128 ; Spring
  .byt 128 ; Block
  .byt 0 ; WholePizza
.endproc

.proc ItemRun
  .addr 0
  .addr .loword(ItemPizzaSlice)
  .addr .loword(ItemBerry)
  .addr .loword(ItemWatermelon)
  .addr .loword(ItemStrawberry)
  .addr .loword(0)
  .addr .loword(0)
  .addr .loword(0)
  .addr .loword(0)
  .addr .loword(0)
  .addr .loword(0)
  .addr .loword(0)
  .addr .loword(0)
  .addr .loword(0)
  .addr .loword(0)
  .addr .loword(0)
  .addr .loword(0)
.endproc

.proc ItemName
  .addr 0
  .addr .loword(ItemName_PizzaSlice)
  .addr .loword(ItemName_Berry)
  .addr .loword(ItemName_Watermelon)
  .addr .loword(ItemName_Strawberry)
  .addr .loword(ItemName_Balloon)
  .addr .loword(ItemName_AutoBalloon)
  .addr .loword(ItemName_LampOil)
  .addr .loword(ItemName_Rope)
  .addr .loword(ItemName_Bombs)
  .addr .loword(ItemName_HeartsKey)
  .addr .loword(ItemName_ClubsKey)
  .addr .loword(ItemName_DiamondsKey)
  .addr .loword(ItemName_SpadesKey)
  .addr .loword(ItemName_Spring)
  .addr .loword(ItemName_Block)
  .addr .loword(ItemName_WholePizza)
.endproc

ItemName_PizzaSlice:
  .byt "Pizza slice", 0
ItemName_Berry:
  .byt "Berry", 0
ItemName_Watermelon:
  .byt "Watermelon", 0
ItemName_Strawberry:
  .byt "Strawberry", 0
ItemName_Balloon:
  .byt "Balloon", 0
ItemName_AutoBalloon:
  .byt "Auto Balloon", 0
ItemName_LampOil:
  .byt "Lamp Oil", 0
ItemName_Rope:
  .byt "Rope", 0
ItemName_Bombs:
  .byt "Bombs", 0
ItemName_HeartsKey:
  .byt "Hearts Key", 0
ItemName_ClubsKey:
  .byt "Clubs Key", 0
ItemName_DiamondsKey:
  .byt "Diamonds Key", 0
ItemName_SpadesKey:
  .byt "Spades Key", 0
ItemName_Spring:
  .byt "Spring", 0
ItemName_Block:
  .byt "Block", 0
ItemName_WholePizza:
  .byt "Pizza", 0

