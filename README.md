# M4B Audiobook Creator

## Overview

This script automates the creation of an M4B audiobook from various audio formats, such as MP3, WAV, and FLAC, with flexible options for organizing chapters.

By default, chapters are created from individual files in the specified directory. However, using the --chapters-from-dirs flag, each subdirectory becomes a single chapter, combining all audio files within it. Chapter titles are generated from metadata, directory names, or filenames, preserving the original order for a consistent audiobook structure.

## Installation

Before installing the script, ensure the following dependencies are available:
- [FFmpeg](https://ffmpeg.org)
- [FFprobe](https://ffmpeg.org/ffprobe.html)
- [mp4chaps](https://github.com/dgraham/mp4v2)

Then, run:

```bash
make install
```

This will copy the script to `/usr/local/sbin/create-m4b`. To uninstall, run:

```bash
make uninstall
```

To change the install location, edit the `PREFIX` variable in the Makefile before installation.

## Usage

Once installed, run the script by calling `create-m4b`:

```bash
create-m4b [--chapters-from-dirs] [--bitrate 128k] /path/to/audiobook_directory
```

**Parameters**
- `--chapters-from-dirs` (Optional): Treats each subdirectory as a single chapter, combining all audio files within each subdirectory.
- `--bitrate` (Optional): Sets the output audio bitrate, e.g., 128k. If not specified, the original source bitrate is used.
- `audiobook_directory` (Required): Path to the directory containing audiobook files or subdirectories.

## Example

```bash
create-m4b --chapters-from-dirs --bitrate 96k /home/user/Downloads/book
```

This example creates an M4B audiobook with chapters based on subdirectories, using a 96 kbps bitrate.