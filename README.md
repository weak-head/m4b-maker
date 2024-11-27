<div align="center">
  
  # M4B Audiobook Maker <!-- omit from toc -->

  A set of bash scripts to convert audio files into M4B audiobooks with chapter markers and customizable bitrate. 

  <p align="center">
    <a href="https://www.gnu.org/software/bash/">
      <img alt="#!/bin/bash" 
           src="https://img.shields.io/badge/-%23!%2Fbin%2Fbash-1f425f.svg?logo=image%2Fpng%3Bbase64%2CiVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyZpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw%2FeHBhY2tldCBiZWdpbj0i77u%2FIiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8%2BIDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuNi1jMTExIDc5LjE1ODMyNSwgMjAxNS8wOS8xMC0wMToxMDoyMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENDIDIwMTUgKFdpbmRvd3MpIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOkE3MDg2QTAyQUZCMzExRTVBMkQxRDMzMkJDMUQ4RDk3IiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOkE3MDg2QTAzQUZCMzExRTVBMkQxRDMzMkJDMUQ4RDk3Ij4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6QTcwODZBMDBBRkIzMTFFNUEyRDFEMzMyQkMxRDhEOTciIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6QTcwODZBMDFBRkIzMTFFNUEyRDFEMzMyQkMxRDhEOTciLz4gPC9yZGY6RGVzY3JpcHRpb24%2BIDwvcmRmOlJERj4gPC94OnhtcG1ldGE%2BIDw%2FeHBhY2tldCBlbmQ9InIiPz6lm45hAAADkklEQVR42qyVa0yTVxzGn7d9Wy03MS2ii8s%2BeokYNQSVhCzOjXZOFNF4jx%2BMRmPUMEUEqVG36jo2thizLSQSMd4N8ZoQ8RKjJtooaCpK6ZoCtRXKpRempbTv5ey83bhkAUphz8fznvP8znn%2B%2F3NeEEJgNBoRRSmz0ub%2FfuxEacBg%2FDmYtiCjgo5NG2mBXq%2BH5I1ogMRk9Zbd%2BQU2e1ML6VPLOyf5tvBQ8yT1lG10imxsABm7SLs898GTpyYynEzP60hO3trHDKvMigUwdeaceacqzp7nOI4n0SSIIjl36ao4Z356OV07fSQAk6xJ3XGg%2BLCr1d1OYlVHp4eUHPnerU79ZA%2F1kuv1JQMAg%2BE4O2P23EumF3VkvHprsZKMzKwbRUXFEyTvSIEmTVbrysp%2BWr8wfQHGK6WChVa3bKUmdWou%2BjpArdGkzZ41c1zG%2Fu5uGH4swzd561F%2BuhIT4%2BLnSuPsv9%2BJKIpjNr9dXYOyk7%2FBZrcjIT4eCnoKgedJP4BEqhG77E3NKP31FO7cfQA5K0dSYuLgz2TwCWJSOBzG6crzKK%2BohNfni%2Bx6OMUMMNe%2Fgf7ocbw0v0acKg6J8Ql0q%2BT%2FAXR5PNi5dz9c71upuQqCKFAD%2BYhrZLEAmpodaHO3Qy6TI3NhBpbrshGtOWKOSMYwYGQM8nJzoFJNxP2HjyIQho4PewK6hBktoDcUwtIln4PjOWzflQ%2Be5yl0yCCYgYikTclGlxadio%2BBQCSiW1UXoVGrKYwH4RgMrjU1HAB4vR6LzWYfFUCKxfS8Ftk5qxHoCUQAUkRJaSEokkV6Y%2F%2BJUOC4hn6A39NVXVBYeNP8piH6HeA4fPbpdBQV5KOx0QaL1YppX3Jgk0TwH2Vg6S3u%2BdB91%2B%2FpuNYPYFl5uP5V7ZqvsrX7jxqMXR6ff3gCQSTzFI0a1TX3wIs8ul%2Bq4HuWAAiM39vhOuR1O1fQ2gT%2F26Z8Z5vrl2OHi9OXZn995nLV9aFfS6UC9JeJPfuK0NBohWpCHMSAAsFe74WWP%2BvT25wtP9Bpob6uGqqyDnOtaeumjRu%2ByFu36VntK%2FPA5umTJeUtPWZSU9BCgud661odVp3DZtkc7AnYR33RRC708PrVi1larW7XwZIjLnd7R6SgSqWSNjU1B3F72pz5TZbXmX5vV81Yb7Lg7XT%2FUXriu8XLVqw6c6XqWnBKiiYU%2BMt3wWF7u7i91XlSEITwSAZ%2FCzAAHsJVbwXYFFEAAAAASUVORK5CYII%3D" />
    </a>
    &nbsp;
    <a href="https://github.com/weak-head/m4b-maker/releases">
      <img alt="GitHub Release"
           src="https://img.shields.io/github/v/release/weak-head/m4b-maker?color=blue" />
    </a>
    &nbsp;
    <a href="https://opensource.org/license/mit">
      <img alt="MIT License" 
           src="https://img.shields.io/badge/license-MIT-blue" />
    </a>
  </p>
</div>


## Table of Contents <!-- omit from toc -->
- [Overview](#overview)
- [Getting Started](#getting-started)
- [m4bify](#m4bify)
- [m4bulk](#m4bulk)
- [Usage Examples](#usage-examples)

## Overview

M4B Audiobook Maker is a set of bash scripts that simplify converting audio files into the M4B audiobook format. It includes `m4bify` for single conversions and `m4bulk` for batch processing, with parallel execution to speed up multi-core systems.

**Key Features**

- *Single Audiobook Conversion (`m4bify`)*\
  Combine audio files (MP3, WAV, FLAC, etc.) from a directory into a single M4B file with chapter markers. Files are processed alphabetically to ensure the correct playback order. Chapters are auto-generated from metadata or file names, or you can use the `--chapters-from-dirs` flag to create chapters from top-level subdirectories and specify a custom bitrate with the `--bitrate` flag.

- *Batch Audiobook Conversion (`m4bulk`)*\
  Scan a root directory for audiobook folders and convert them to M4B files in parallel. You can pass custom options like bitrate and chapter settings to `m4bify` for each task. `m4bulk` uses multiple worker threads to process audiobooks simultaneously, making batch conversions much faster.

- *Detailed Logging*\
  Both scripts create detailed logs with chapter info, durations, and any errors. After a batch run, `m4bulk` gives a summary with success/failure counts and total processing time, while `m4bify` creates a detailed log of a single audiobook conversion.

## Getting Started

Ensure the following dependencies are installed: [ffmpeg](https://ffmpeg.org), [ffprobe](https://ffmpeg.org/ffprobe.html) and [mp4chaps](https://mp4v2.org/).

```bash
# For RPM-based systems (Fedora, RHEL, CentOS)
sudo dnf install ffmpeg libmp4v2

# For Debian-based systems (Ubuntu, Debian)
sudo apt install ffmpeg
```

To install the scripts, run:

```bash
make install
```

This installs scripts to `/usr/local/sbin/`. To change the location, adjust the `PREFIX` in the Makefile. To uninstall, use:

```bash
make uninstall
```

## m4bify

`m4bify` makes it easy to turn audio files (MP3, WAV, FLAC, etc.) into M4B audiobooks. It processes files in the specified directory, sorting them alphabetically to ensure the right playback order.

You can organize chapters in two ways:

- *File-based Chapters (Default)*: Each audio file becomes its own chapter, named using metadata or filenames.
- *Directory-based Chapters*: Each top-level subdirectory becomes a chapter, combining all its audio files (including those in nested folders) into one.

Other features include:

- Customizable audio bitrate, with high-quality AAC VBR as the default.
- Automatic naming of the output file based on the directory name.
- Detailed logs with chapter metadata and durations for easy reference.

**Syntax**

```bash
m4bify [--help] [--chapters-from-dirs] [--bitrate 128k] <audiobook_directory>
```

**Options**

- `--chapters-from-dirs` (optional): Treats each top-level subdirectory as a chapter.
- `--bitrate <value>` (optional): Sets the audio encoding bitrate, e.g., "128k" or "96k" (default: AAC VBR Very High).
- `--help`: Displays usage instructions and exits.

**Arguments**

- `<audiobook_directory>` (required): Path to the directory containing audiobook files.

## m4bulk

`m4bulk` automates batch conversion of audiobook folders to M4B format using `m4bify`. It scans a root directory for audiobook folders and processes them efficiently with parallel execution.

Key features:

- *Parallel Processing*: Splits tasks across multiple threads to take advantage of multi-core systems.
- *Custom Settings*: Lets you customize `m4bify` options, like bitrate and chapter generation.
- *Automated Folder Detection*: Automatically finds audiobook directories in the root folder.
- *Detailed Logs*: Creates logs for each conversion and saves them in the source folder for easy reference.

**Syntax**

```bash
m4bulk [--help] [--workers <N>] [m4bify-options] <audiobooks_directory>
```

**Options**

- `--workers <N>` (optional): Number of worker threads (default: 50% of CPU cores). Must be between 1 and the total number of CPU cores.
- `--help`: Displays usage instructions and exits.

**Arguments**

- `[m4bify-options]` (optional): Optional arguments passed directly to `m4bify` (e.g., `--bitrate <rate>`, `--chapters-from-dirs`).
- `<audiobooks_directory>` (required): The root directory containing subdirectories of audiobooks to convert.

## Usage Examples

**Single Audiobook Conversion**

Combine all audio files in `/home/user/audiobooks/book/` into a single M4B audiobook. Chapters are automatically generated based on file metadata or filenames:

```bash
m4bify /home/user/audiobooks/book
```

**Subdirectory Chapters with Custom Bitrate**

Combine all top-level subdirectories in `/home/user/audiobooks/book/` into a single audiobook, with each subdirectory treated as a separate chapter. Files are processed recursively in alphabetical order, with audio encoded at 96 kbps:

```bash
m4bify --chapters-from-dirs --bitrate 96k /home/user/audiobooks/book
```

**Bulk Conversion with Default Settings**

Convert all subdirectories in `/home/user/audiobooks/` to M4B format using default settings. The process utilizes 50% of available CPU cores:

```bash
m4bulk /home/user/audiobooks
```

**Bulk Conversion with Custom Threads and Bitrate**

Convert audiobook directories in `/home/user/audiobooks/` with 4 worker threads. Each subdirectory is treated as a chapter, and audio is encoded at 128 kbps:

```bash
m4bulk --workers 4 --chapters-from-dirs --bitrate 128k /home/user/audiobooks
```

## Contributing <!-- omit from toc -->

Contributions, bug reports, and feature requests are welcome! Feel free to open an issue or submit a pull request.

## License <!-- omit from toc -->

This project is licensed under the MIT License. See the LICENSE file for details.

## Acknowledgments <!-- omit from toc -->

Thanks to the creators of [ffmpeg](https://ffmpeg.org) and [mp4chaps](https://mp4v2.org/) for their excellent tools that make this project possible.