# psvstrip-docker

Simple Docker container for the strip_psv.sh script, used for stripping licenses off of PSVgameSD dumps.

For more information see:
 - https://forum.no-intro.org/viewtopic.php?f=2&t=3443
 - https://dumping.guide/carts/sony/vita

## Usage

Strip your raw dump like this:

`docker pull jonasrosland/psvstrip-docker`

`docker run -v /yourdumpsdirectory:/data jonasrosland/psvstrip-docker strip_psv.sh -s /data/DUMPNAME.psv`

or if you're running it within the directory of the dump:

`docker run -v $PWD:/data jonasrosland/psvstrip-docker strip_psv.sh -s /data/DUMPNAME.psv`

Your stripped PSV file and license file will be saved in the same directory as the raw dump.

## Why am I doing this?

I noticed that I was getting incorrect results within my own Ubuntu 20.04 environment, verified on another Linux system and with the Windows version of PSVStrip.exe. The script _does work_, and to mitigate any future issues I built this Docker container to make sure there's a consistent environment that anyone can use, without issues.
