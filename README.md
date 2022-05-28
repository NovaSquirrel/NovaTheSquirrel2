Nova the Squirrel 2
===================

This is a sequel to [[Nova the Squirrel 1](https://github.com/NovaSquirrel/NovaTheSquirrel) which came out on the NES. The sequel targets the SNES instead, and intends on making use of the SNES's features and graphics.

![Screenshot](https://novasquirrel.com/rsc/nova2_2.png)

The game also intends to be more polished and refined than the first one. Here's some of the plans:

* More animation on lots of things
* More copy abilities (currently planning to have 16 of them)
* More story emphasis
* Enemies now have health and attacks do varying amounts of damage
* Levels are now 256x32 or 32x256 (or potentially other sizes?) instead of exclusively 256x15
* Levels can have a second foreground layer that can move independently from the first
* Mode 7 perspective levels starring a mouse named Maffi

Some parts based on [LoROM template](https://github.com/pinobatch/lorom-template)

The corresponding level editor is [Princess Edit 2](https://github.com/NovaSquirrel/PrincessEdit2).

Building
========

You'll need the following:

* Python 3 (and Pillow)
* GNU Make
* [ca65](https://cc65.github.io/)
* [lz4](https://github.com/lz4/lz4/releases) compressor (Windows build included)

With that in place, just enter `make`.

License
=======

All game and tool code is available under GPL version 3.

This project uses a modified version of SNESGSS which [appears to be licensed under Apache License 2.0](https://code.google.com/archive/p/snesgss/). These modifications and the new exporter are licensed under the same.

This project also uses LZ4 and SPC700 loading code from [libSFX](https://github.com/Optiroc/libSFX) which is under the MIT license.

Assets (such as art, levels, story) are not licensed to be used outside of this game. You may not use them without permission. After the game is complete I may make a version with free-to-use assets if there's interest.
