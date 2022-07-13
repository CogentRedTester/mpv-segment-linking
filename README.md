# mpv-segment-linking

Implements support for matroska [hard segment linking](https://www.ietf.org/archive/id/draft-ietf-cellar-matroska-06.html#name-hard-linking) in mpv player.
This is **not** the same as [ordered chapters](https://www.ietf.org/archive/id/draft-ietf-cellar-matroska-06.html#name-medium-linking), which mpv already supports natively.
While both features are relatively obscure, ordered chapters are used far more often due to being able to support everything segments do, plus more.
Nevertheless, segment linked files do still exist, so this script can be used to implement limitted support for the feature until such a time as mpv implements it natively.

This script requires that `mkvinfo`, part of the [mkvtoolnix](https://mkvtoolnix.download/) toolset, be available in the system path.

## Basic Setup

If you just want to play local hard-linked files like you would ordered chapters, then all you need to do is:

1.  Place segment-linking.lua into the mpv [scripts directory](https://mpv.io/manual/master/#files)
2.  Place `mkvinfo` into the system PATH (if in doubt on windows then place in the same directory as `mpv.exe`)

Everything else should be automated.
All the advanced information below can be ignored.

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

### Format

The first line of the metafiles must be `# mpv-segment-linking v0.1`.
Lines beginning with `#` are treated as comments, empty lines are ignored, and newlines
can be LF or CRLF. All other lines are treated as statements.

Statements can consist of:

```conf
<filename>
UID=<uid>
PREV=<uid>
NEXT=<uid>
```

Where `<filename>` is the absolute or relative path of the file
for which the following `<uids>` apply. Paths must be relative to the metafile.
The `UID` field is the segment UID for that matroska file, and the `PREV` and
`NEXT` fields are the next and previous segment UIDs for that file.
All three of these fields are optional and can be in any order, but the
entry is useless without the `UID` field. There cannot be any whitespace before
or after the `<filename>`, `<uid>`, or `UID|PREV|NEXT`.

The first statement in the file must be a `<filename>`. If multiple
`UID|PREV|NEXT` statements are made for the same file then the latest
takes preference.

If you have a file that begins with `UID|PREV|NEXT=` then you can add `./`
to the front to make it a `<filename>`.

Here is an example of a simple metafile:

```conf
# mpv-segment-linking v0.1

01. Cardcaptor Sakura [BD 1080p Hi10P 5.1 AAC][kuchikirukia].mkv
UID=0xbf 0x8c 0x8d 0x54 0x32 0x4e 0x88 0x21 0x96 0x2e 0x55 0x51 0x53 0x7c 0x34 0xc3
PREV=0x72 0x77 0xc3 0x31 0xcf 0x62 0xe9 0x55 0xa6 0xd1 0x5d 0x79 0x8c 0x44 0x94 0x60

NCOP1a (for linked mkvs).mkv
UID=0x72 0x77 0xc3 0x31 0xcf 0x62 0xe9 0x55 0xa6 0xd1 0x5d 0x79 0x8c 0x44 0x94 0x60
```

### Build Scripts
The `Build-SegmentMetaFile.ps1` and `build-segment-metafile.sh` build scripts can be used to generate metafiles in the correct format.
Simply pass a list of files as arguments to the scripts and they will automatically scan them using `mkvinfo` and save a properly formatted
metafile into the current folder.

    ./build-segment-metafile.sh *.mkv

The default output file is `.segment-linking`, which matches the default metafile that this script attempts to load.
However, the output file can be changed using the `-o` flag. For example:

    ./build-segment-metafile.sh *.mkv -o segments.meta

## Limitations

There are several limitations compared to the native implementation of ordered chapters.
Most of these limitations can be solved by using the metafiles.

* cannot detect if a network file should contain segments

* does not support the `ordered-chapters-files` option.

## Unclear Behaviour

It is not clear how this script would react with files that also contain ordered chapters or editions. I do not have any files to test this with.

All chapters added between segments by the edl specification are removed by the script whether or not they are within the merge threshold of existing chapters.
This behaviour matches the VLC implementation of the feature, which is what I'll be replicating.
