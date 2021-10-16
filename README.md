# mpv-segment-linking

Implements support for matroska [hard segment linking](https://www.ietf.org/archive/id/draft-ietf-cellar-matroska-06.html#name-hard-linking) in mpv player.
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

### mpv-options
This script respects the `access-references` and `ordered-chapters` options.
If either of these options are disabled then so will this script.
This is to maintain parity with normal ordered chapters, considering the similarities of the features.

The `chapter-merge-threshold` option is used to merge chapters that are too close together, as with ordered chapters.

The script also has limitted support for the `ordered-chapters-files` option, which tells the player to search for matching files inside the given playlist, instead of the file's directory. This may be changed to a separate option in the future.

### script-opts
All script options, and their defaults, are listen in the [segment_linking.conf](segment_linking.conf) file. Most of these options are related to
the custom segment-linking [metafiles](#metafiles)

## Metafiles
This script supports custom segment metafiles, which can allow this script to work across network file systems and on systems without `mkvinfo`.
By default, if the current file cannot be read due to being a network file or because `mkvinfo` is not available, then the script will attempt to read
a meta-file from the same directory as the currently playing file. The name of the file is specified by the `default_metafile` script-opt.
A metafile can be forcibly used by manually setting the `metafile` script-opt; in this case, the script will not even attempt to scan any files directly.

In order to load network metadata files this script requires that the [mpv-read-file](https://github.com/CogentRedTester/mpv-read-file) API be installed.
Simply follow the install instructions and make sure to include the `wget` commandline utility in the system path.

### Build Scripts
The `Build-SegmentMetaFile.ps1` and `build-segment-metafile.sh` build scripts can be used to generate metafiles in the correct format.
Simply pass a list of files as arguments to the scripts and they will automatically scan them using `mkvinfo` and save a properly formatted
metafile into the current folder.

    ./build-segment-metafile.sh *.mkv

The default output file is `.segment-linking`, which matches the default metafile that this script attempts to load.
However, the output file can be changed using the `-o` flag. For example:

    ./build-segment-metafile.sh *.mkv -o segments.meta

## Limitations

There are several limitations compared to the native implementation of ordered chapters, mostly involving the use of the `ordered-chapters-files` option.
Most of these limitations can be solved by using the metafiles.

* cannot detect if a network file should contain segments

* `ordered-chapters-files` only supports playlists consisting of a single filename on each line, more complex playlist formats like `pls` do not work

* `ordered-chapters-files` cannot point to a network playlist (http, ftp, etc)

* `ordered-chapters-files` cannot get the UIDs of playlist items that are accessed over a network protocol (http, ftp, etc)

## Unclear Behaviour

It is not clear how this script would react with files that also contain ordered chapters or editions. I do not have any files to test this with.

All chapters added between segments by the edl specification are removed by the script whether or not they are within the merge threshold of existing chapters.
This behaviour matches the VLC implementation of the feature, which is what I'll be replicating.
