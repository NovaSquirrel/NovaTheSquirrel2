Nova the Squirrel 2
===================

This is a sequel to [[Nova the Squirrel 1](https://github.com/NovaSquirrel/NovaTheSquirrel) which came out on the NES. The sequel targets the SNES instead, and intends on making use of the SNES's features and graphics.

![Screenshot](https://novasquirrel.com/rsc/nova2_2.png)

The game also intends to be more polished and refined than the first one. Here's some of the plans:

* Lots more animation than the first game had
* More copy abilities (currently planning to have 16 of them)
* Very prominent story emphasis, and lots of characters to meet and talk to
* Enemies now have health and attacks do varying amounts of damage
* Levels are now 256x32 or 32x256 (or potentially other sizes?) instead of exclusively 256x15
* Levels can have a second foreground layer that can move independently from the first
* Mode 7 perspective levels starring a mouse named Maffi, inspired by Jumping Flash!

Some parts based on [LoROM template](https://github.com/pinobatch/lorom-template).

Mode 7 perspective code based on [Dizworld](https://github.com/bbbradsmith/SNES_stuff/tree/main/dizworld#readme), by rainwarrior.

The corresponding level editor is [Princess Edit 2](https://github.com/NovaSquirrel/PrincessEdit2).

Forum threads with news:
* https://forums.nesdev.org/viewtopic.php?t=19067
* https://www.videogamesage.com/forums/topic/822-nova-the-squirrel-2-wip/

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

Characters and assets (such as art, levels, story) are not licensed to be used outside of this game. You may not use them without permission. See [snes-platformer-example](https://github.com/NovaSquirrel/snes-platformer-example) for the basic platformer game engine on its own, with free example assets.
