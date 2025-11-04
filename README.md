<div align="center">
  
  # M4B Audiobook Maker <!-- omit from toc -->

  A set of bash scripts to convert audio files into M4B audiobooks with chapter markers, customizable bitrate, book metadata and embedded cover art.

  <p align="center">
    <a href="https://github.com/weak-head/m4b-maker/actions/workflows/lint.yaml">
      <img alt="lint" 
           src="https://img.shields.io/github/actions/workflow/status/weak-head/m4b-maker/lint.yaml?label=lint"/>
    </a>
    <a href="https://github.com/weak-head/m4b-maker/releases">
      <img alt="GitHub Release"
           src="https://img.shields.io/github/v/release/weak-head/m4b-maker?color=blue" />
    </a>
    <a href="https://www.gnu.org/software/bash/">
      <img alt="#!/bin/bash" 
           src="https://img.shields.io/badge/-%23!%2Fbin%2Fbash-1f425f.svg?logo=image%2Fpng%3Bbase64%2CiVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyZpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw%2FeHBhY2tldCBiZWdpbj0i77u%2FIiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8%2BIDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuNi1jMTExIDc5LjE1ODMyNSwgMjAxNS8wOS8xMC0wMToxMDoyMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENDIDIwMTUgKFdpbmRvd3MpIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOkE3MDg2QTAyQUZCMzExRTVBMkQxRDMzMkJDMUQ4RDk3IiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOkE3MDg2QTAzQUZCMzExRTVBMkQxRDMzMkJDMUQ4RDk3Ij4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6QTcwODZBMDBBRkIzMTFFNUEyRDFEMzMyQkMxRDhEOTciIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6QTcwODZBMDFBRkIzMTFFNUEyRDFEMzMyQkMxRDhEOTciLz4gPC9yZGY6RGVzY3JpcHRpb24%2BIDwvcmRmOlJERj4gPC94OnhtcG1ldGE%2BIDw%2FeHBhY2tldCBlbmQ9InIiPz6lm45hAAADkklEQVR42qyVa0yTVxzGn7d9Wy03MS2ii8s%2BeokYNQSVhCzOjXZOFNF4jx%2BMRmPUMEUEqVG36jo2thizLSQSMd4N8ZoQ8RKjJtooaCpK6ZoCtRXKpRempbTv5ey83bhkAUphz8fznvP8znn%2B%2F3NeEEJgNBoRRSmz0ub%2FfuxEacBg%2FDmYtiCjgo5NG2mBXq%2BH5I1ogMRk9Zbd%2BQU2e1ML6VPLOyf5tvBQ8yT1lG10imxsABm7SLs898GTpyYynEzP60hO3trHDKvMigUwdeaceacqzp7nOI4n0SSIIjl36ao4Z356OV07fSQAk6xJ3XGg%2BLCr1d1OYlVHp4eUHPnerU79ZA%2F1kuv1JQMAg%2BE4O2P23EumF3VkvHprsZKMzKwbRUXFEyTvSIEmTVbrysp%2BWr8wfQHGK6WChVa3bKUmdWou%2BjpArdGkzZ41c1zG%2Fu5uGH4swzd561F%2BuhIT4%2BLnSuPsv9%2BJKIpjNr9dXYOyk7%2FBZrcjIT4eCnoKgedJP4BEqhG77E3NKP31FO7cfQA5K0dSYuLgz2TwCWJSOBzG6crzKK%2BohNfni%2Bx6OMUMMNe%2Fgf7ocbw0v0acKg6J8Ql0q%2BT%2FAXR5PNi5dz9c71upuQqCKFAD%2BYhrZLEAmpodaHO3Qy6TI3NhBpbrshGtOWKOSMYwYGQM8nJzoFJNxP2HjyIQho4PewK6hBktoDcUwtIln4PjOWzflQ%2Be5yl0yCCYgYikTclGlxadio%2BBQCSiW1UXoVGrKYwH4RgMrjU1HAB4vR6LzWYfFUCKxfS8Ftk5qxHoCUQAUkRJaSEokkV6Y%2F%2BJUOC4hn6A39NVXVBYeNP8piH6HeA4fPbpdBQV5KOx0QaL1YppX3Jgk0TwH2Vg6S3u%2BdB91%2B%2FpuNYPYFl5uP5V7ZqvsrX7jxqMXR6ff3gCQSTzFI0a1TX3wIs8ul%2Bq4HuWAAiM39vhOuR1O1fQ2gT%2F26Z8Z5vrl2OHi9OXZn995nLV9aFfS6UC9JeJPfuK0NBohWpCHMSAAsFe74WWP%2BvT25wtP9Bpob6uGqqyDnOtaeumjRu%2ByFu36VntK%2FPA5umTJeUtPWZSU9BCgud661odVp3DZtkc7AnYR33RRC708PrVi1larW7XwZIjLnd7R6SgSqWSNjU1B3F72pz5TZbXmX5vV81Yb7Lg7XT%2FUXriu8XLVqw6c6XqWnBKiiYU%2BMt3wWF7u7i91XlSEITwSAZ%2FCzAAHsJVbwXYFFEAAAAASUVORK5CYII%3D" /></a>
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

M4B Audiobook Maker is a set of bash scripts that simplify converting audio files into the M4B audiobook format. It includes `m4bify` for single conversions and `m4bulk` for batch processing.

**Single Audiobook Conversion (`m4bify`)**

Combines audio files into a single M4B audiobook with chapter markers, ensuring correct playback order by processing files alphabetically. Chapters are automatically created based on metadata, filenames, or top-level subdirectories. You can customize the audio quality, and if an image file or embedded art is available, it will be added as the book cover. Additionally, directory names that follow supported patterns are parsed to extract metadata such as the author, title, and year.

**Batch Audiobook Conversion (`m4bulk`)**

Scan a root directory for audiobook folders and convert them to M4B files in parallel. Pass custom options, such as bitrate and chapter settings, to apply them to all audiobooks. `m4bulk` leverages multiple worker threads for simultaneous processing, speeding up batch conversions.

## Getting Started

Ensure the following dependencies are installed: [ffmpeg](https://ffmpeg.org) and [mp4v2](https://mp4v2.org/).

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

This installs the scripts to `/usr/local/sbin/`.

## m4bify

`m4bify` creates M4B audiobook by processing files in the specified directory, sorting them alphabetically to ensure the correct playback order. Chapters can be organized either as file-based, where each audio file becomes its own chapter named using metadata or filenames, or directory-based, where each top-level subdirectory is treated as a chapter, combining all its audio files, including those in nested folders, into one.

Other features include:

- Configurable audio bitrate, with high-quality AAC VBR as the default.
- Metadata extraction from directory names that follow supported patterns.
- Automatic cover art inclusion from image files or embedded artwork.
- Embedding book descriptions from external text or Markdown files.
- Comprehensive logs with chapter metadata.

**Syntax**

```bash
m4bify [--help] [-d | --chapters-from-dirs] [-b <bitrate> | --bitrate <bitrate>] <directory>
```

**Options**

- `-d`, `--chapters-from-dirs`: Treats each top-level subdirectory as a chapter.
- `-b <value>`, `--bitrate <value>`: Sets the audio encoding bitrate. Supported values:
  - `<num>k` - Fixed bitrate (e.g. "32k", "128k")
  - `vbr` - VBR Very High
  - `alac` - [Apple Lossless Audio Codec](https://en.wikipedia.org/wiki/Apple_Lossless_Audio_Codec)
- `--help`: Displays usage instructions and exits.

**Arguments**

- `<directory>` (required): Path to the directory containing audiobook files.

**Directory Patterns**

| Pattern | Example |
|---|---|
| `<author_name> - <book_title> (<year>)` | J.K. Rowling - Harry Potter and the Philosopher's Stone (1997) |
| `<author_name> - <book_title>` | Agatha Christie - Murder on the Orient Express |
| `<book_title> (<year>)` | To Kill a Mockingbird (1960) |

Both hyphen (`-`) and underscore (`_`) are supported as separators. Additionally, square brackets (`[]`) can be used as an alternative to parentheses (`()`) for enclosing year information.

## m4bulk

`m4bulk` automates batch conversion of audiobook folders to M4B format using `m4bify`. It scans a root directory for audiobook folders and processes them in parallel.

Key features:

- Distributes tasks across multiple workers.
- Automatically detects audiobook directories in the root folder.
- Allows customization of `m4bify` options, such as bitrate and chapter generation.
- Generates and saves logs for each audiobook conversion in the source folder.

**Syntax**

```bash
m4bulk [--help] [--workers <N>] [m4bify-options] <audiobooks_directory>
```

**Options**

- `--workers <N>`: Number of worker threads (default: 50% of CPU cores).
- `--help`: Displays usage instructions and exits.

**Arguments**

- `[m4bify-options]` (optional): Optional arguments passed directly to `m4bify` (e.g. `-b <rate>`).
- `<audiobooks_directory>` (required): Directory containing subdirectories of audiobooks to convert.

## Usage Examples

**Metadata Extracted from Directory Name**

Combine all audio files in `/home/user/audiobooks/Author Name - Book Title (1993)/` into a single M4B audiobook. Chapters are automatically generated based on file metadata or filenames. Author, title and year are extracted from the directory name:

```bash
m4bify "/home/user/audiobooks/Author Name - Book Title (1993)"
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
m4bulk --workers 4 -d -b 128k /home/user/audiobooks
```

## Contributing <!-- omit from toc -->

Contributions, bug reports, and feature requests are welcome! Feel free to open an issue or submit a pull request.

## License <!-- omit from toc -->

This project is licensed under the MIT License. See the LICENSE file for details.

## Acknowledgments <!-- omit from toc -->

Thanks to the creators of [ffmpeg](https://ffmpeg.org) and [mp4v2](https://mp4v2.org/) for their excellent tools that make this project possible.
