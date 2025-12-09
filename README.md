Nova the Squirrel 2
===================

This is a sequel to [Nova the Squirrel 1](https://github.com/NovaSquirrel/NovaTheSquirrel) which came out on the NES. The sequel targets the SNES instead, and intends on making use of the SNES's features and graphics.

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

* Python 3 (and [Pillow](https://pillow.readthedocs.io/en/stable/))
* GNU Make
* GNU Coreutils
* [ca65](https://cc65.github.io/)
* [lz4](https://github.com/lz4/lz4/releases) compressor (Windows build included)

With that in place, just enter `make`

On Windows I suggest using [msys2](https://www.msys2.org/) to provide Make and Coreutils. You may be able to use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) instead if you prefer.

[nrom-template](https://github.com/pinobatch/nrom-template#setting-up-the-build-environment) has a guide for building on Windows and Linux that will also work for this game, though you will still need to get `lz4`.

License
=======

All game and tool code is available under GPL version 3.

This project uses [Terrific Audio Driver](https://github.com/undisbeliever/terrific-audio-driver) which is under the zlib license.

This project also uses LZ4 code from [libSFX](https://github.com/Optiroc/libSFX) which is under the MIT license.

The following are to be considered "all rights reserved". They are provided in this repository to allow other people to build the game, but may not be used in other projects without permission.
* Character designs
* PNG files (and files generated from them) except for the `palettes` directory and fonts
* TMX files (and files generated from them)
* Levels (`levels` and `m7levels` directories)
* Story (`dialog.txt`)

See [snes-platformer-example](https://github.com/NovaSquirrel/snes-platformer-example) for an example that replaces all assets with free ones, uses a permissive license for the code, and removes complexity specific to this game.
