# psvstrip-docker

Simple Docker container for the strip_psv.sh script, used for stripping licenses off of PSVgameSD dumps.

For more information see:
 - https://forum.no-intro.org/viewtopic.php?f=2&t=3443
 - https://dumping.guide/carts/sony/vita

## Usage

Strip your raw dump like this:

`docker pull jonasrosland/psvstrip-docker`

`docker run -v /yourdumpsdirectory:/data jonasrosland/psvstrip-docker strip_psv.sh -s /data/DUMPNAME.psv`

Your stripped PSV file and license file will be saved in the same directory as the raw dump.
