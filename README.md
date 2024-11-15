# M4B Audiobook Creator

## Overview

This script automates the creation of an M4B audiobook from various audio formats, such as MP3, WAV, and FLAC, with flexible options for organizing chapters.

By default, chapters are created from individual files in the specified directory. However, using the `--chapters-from-dirs` flag, each subdirectory becomes a single chapter, combining all audio files within it. 

Chapter titles are generated from metadata, directory names, or filenames, preserving the original order for a consistent audiobook structure.

## Installation

Ensure the following dependencies are installed: [ffmpeg](https://ffmpeg.org), [ffprobe](https://ffmpeg.org/ffprobe.html) and [mp4chaps](https://mp4v2.org/).

```bash
# For RPM-based Systems
sudo dnf install ffmpeg libmp4v2

# For Debian-based Systems
sudo apt install ffmpeg
```

To install the script, run:

```bash
make install
```

This installs it to `/usr/local/sbin/create-m4b`. To change the location, adjust the `PREFIX` in the Makefile. To uninstall, use:

```bash
make uninstall
```

## Usage

Run the script with the following command:

```bash
create-m4b [--chapters-from-dirs] [--bitrate 128k] /path/to/audiobook_directory
```

**Options**
- `--chapters-from-dirs` (Optional): Treats each subdirectory as a chapter.
- `--bitrate` (Optional): Sets the output audio bitrate (e.g., `128k`). Defaults to 'AAC VBR Very High' if not specified.
- `audiobook_directory` (Required): Path to the directory containing audiobook files.

For help, run:

```bash
create-m4b --help
```

## Examples

Create a single M4B file from all audio files in the "my_book" directory with default audio quality and file-based chapters:

```bash
create-m4b /home/user/audiobooks/my_book
```

Treat each directory in "my_series" as a chapter, using 96 kbps audio quality:

```bash
create-m4b --chapters-from-dirs --bitrate 96k /home/user/audiobooks/my_series
```
