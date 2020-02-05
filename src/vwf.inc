; These occupy $00-$1f so there can only be 32 of these
.enum TextCommand
  EndText       ; End page, stop processing the text entirely
  EndPage       ; End page, wait for input, and start a new page of text
  EndLine       ; End current line
  EndDialog     ; End entire dialog script
  Portrait      ; Change to a new portrait and continue with a new page
  CallASM       ; Followed by 3-byte 
  EscapeCode    ; For if I need more than 32 text commands
  ExtendedChar  ; Followed by a one-byte character
  Color1        ; Switch to color 1
  Color2        ; Switch to color 2
  Color3        ; Switch to color 3
  SetX          ; Followed by X
  SetXY         ; Followed by X and then Y
  WideText      ; Switch to extra-wide text
  BigText       ; Switch to extra-wide and extra-tall text
.endenum

; There can be 256 of these
.enum DialogCommand
  End           ; Stop the dialog and return to the game
  Portrait      ; Followed by a portrait number and VWF text
  CallAsm       ; Followed by a 3-byte pointer
  Narrate       ; Followed by VWF text
.endenum

; Code the VWF engine returns to the dialog engine when it stops
.enum VWFReturnCode
  EndText   = 0 ; Stop running the text at all
  EndDialog = 2 ; End the dialog entirely
  EndPage   = 4 ; End the page and continue with a new one
  Portrait  = 6 ; End the page and continue with a new one with a new portrait
.endenum

.enum ExtraChar
  ButtonA      = $80
  ButtonB      = $81
  ButtonX      = $82
  ButtonY      = $83
  ArrowUp      = $84
  ArrowDown    = $85
  ArrowLeft    = $86
  ArrowRight   = $87
  Heart        = $88
  HeartFull    = $89
  Copyright    = $8a
  Registered   = $8b
  Trademark    = $8c
  Star         = $8d
  Check        = $8e
  ButtonL      = $90
  ButtonR      = $91
  Smile        = $92
  Frown        = $93
  Mad          = $94
  Meh          = $95
  ThumbsUp     = $96
  ThumbsDown   = $97
  Think        = $98
.endenum
