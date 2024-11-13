# M4B Audiobook Creator

## Overview

This script automates the process of creating an M4B audiobook from a variety of audio formats, including MP3, WAV, and FLAC. It offers flexibility in how chapters are organized, supporting both file-based and directory-based chaptering. The script can process a directory containing multiple audio files or subdirectories, giving you control over how the chapters are structured. By default, chapters are created based on individual files, but with the `--directories-as-chapters` flag, each subdirectory is treated as a single chapter, combining all audio files within that directory. You can also specify the audio quality (bitrate) for the output file, with a default of 128 kbps. Chapter titles are extracted from metadata, directory names, or filenames, while the original order of files is preserved to ensure the audiobook's intended structure is maintained.

## Installation

To install the script, use the provided `Makefile`. The following dependencies are required:

- `ffmpeg`
- `ffprobe`
- `mp4chaps`

To install the script, run:

```bash
make install
```

This will copy the script to `/usr/local/sbin/create-m4b`. If you'd like to uninstall it later, simply run:

```bash
make uninstall
```

By default, the script will be installed to `/usr/local/sbin`. If you'd prefer to install it to a different location, you can modify the `PREFIX` variable in the Makefile before running the installation command.

## Usage

Once installed, you can run the script from anywhere by calling `create-m4b`:

`create-m4b [--directories-as-chapters] /path/to/audiobook_directory [audio_quality]`

### Parameters
- `--directories-as-chapters` (Optional): Treats each directory as a separate chapter, combining files within each directory into a single chapter.
- `audiobook_directory` (Required): Path to the directory containing audiobook files or subdirectories.
- `audio_quality` (Optional): Desired audio quality (bitrate) for the output file, e.g., `128k` or `96k`. Defaults to 128 kbps if not specified.

## Examples

### Basic Usage with Default Quality

Create an M4B audiobook from all audio files in the `my_book` directory, using file-based chaptering and the default audio quality of 128 kbps:

```bash
create-m4b /home/user/audiobooks/my_book
```

#### Specify Audio Quality

Process the `my_book` directory with an audio quality of 96 kbps:

```bash
create-m4b /home/user/audiobooks/my_book 96k
```

### Directory-Based Chaptering

Treat each subdirectory within `my_series` as a separate chapter, combining all audio files in each directory into a single chapter in the final M4B file, with the default 128 kbps audio quality:

```bash
create-m4b --directories-as-chapters /home/user/audiobooks/my_series
```
