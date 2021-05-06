# mpv-segment-linking

Implements support for matroska [segment linking](https://www.ietf.org/archive/id/draft-ietf-cellar-matroska-06.html#name-hard-linking) in mpv player.
This is **not** the same as [ordered chapters](https://www.ietf.org/archive/id/draft-ietf-cellar-matroska-06.html#name-medium-linking), which mpv already supports natively.
While both features are relatively obscure, ordered chapters are used for more often due to being able to support everything segments do, plus more.
Nevertheless, segment linked files do still exist, so this script can be used to implement limitted support for the feature until such a time as mpv implements it natively.

This script requires that `mkvinfo`, part of the [mkvtoolnix](https://mkvtoolnix.download/) toolset, be available in the system path.

## Behaviour

When opening a file containing a segment link the script will search the directory for files with matching segment UIDs.
Previous UIDs will be prepended before the opened file in the timeline, and next UIDs will be appended after.
The script will follow the next and previous segments and continue extending them until it cannot find any more linked segments, a.k.a, it will create a chain of linked segments stretching out from both directions of the opened file.
Playback will always start from the beginning of the timeline regardless of which file is opened.

This should follow the official [specification](https://www.ietf.org/archive/id/draft-ietf-cellar-matroska-06.html#name-hard-linking). Any incorrect behaviour should be reported.

## Options

This script respects the `access-references` and `ordered-chapters` options.
If either of these options are disabled then so will this script.
This is to maintain parity with normal ordered chapters, considering the similarities of the features.

The script also respects the `ordered-chapters-files` option, which tells the player to search for matching files inside the given playlist, instead of the file's directory.

## Limitations

There are a small number of limitations compared to the native implementation of ordered chapters, mostly involving the use of the `ordered-chapters-files` option.

* cannot detect if a network file should contain segments

* `ordered-chapters-files` only supports playlists consisting of a single filename on each line, more complex playlist formats like `pls` do not work

* `ordered-chapters-files` cannot point to a network playlist (http, ftp, etc)

* `ordered-chapters-files` cannot get the UIDs of playlist items that are accessed over a network protocol (http, ftp, etc)

## Unclear Behaviour

It is not clear how this script would react with files that also contain ordered chapters or editions. I do not have any files to test this with.

Currently new chapters are added between each linked file. My test files already have chapters at those locations, which makes for a messy chapter index.
I haven't yet checked if linked segments always have inbuilt chapters, or if it's just my files, and if it is worth cleaning these chapters up I don't yet know how.

