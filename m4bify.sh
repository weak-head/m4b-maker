#!/usr/bin/env bash
# This script automates the creation of an M4B audiobook from various audio formats (e.g., MP3, WAV, FLAC). 
# It organizes and combines audio files into a single audiobook file with chapter markers.
#
# Key Features:
# - Processes audio files recursively, discovering them in all subdirectories.
# - Files are processed in **alphabetical order** to maintain correct playback sequence.
# - Supports chapter generation based on filenames or directory structure:
#   - Default: Each file becomes a chapter, named based on metadata or filename.
#   - With `--chapters-from-dirs`: Each top-level subdirectory is treated as a chapter, while its contents 
#     (including nested subdirectories) are processed recursively as audio files.
# - Allows custom bitrate settings for audio encoding, defaulting to high-quality AAC VBR.
# - Automatically names the output file based on the input directory name.
# - Provides detailed logging of chapter and duration information.
#
# Usage Instructions:
#   $> m4bify [--chapters-from-dirs] [--bitrate <value>] <audiobook_directory>
#
# Options:
#   -d, --chapters-from-dirs   Treats each top-level subdirectory as a chapter. Audio files in these directories, 
#                              including nested subdirectories, are combined into that chapter.
#   -b, --bitrate <value>      Sets the audio encoding bitrate, e.g., "128k" or "96k" (default: AAC VBR Very High).
#   --help                     Displays usage instructions and exits.
#
# Arguments:
#   <audiobook_directory>     Path to the directory containing audio files or subdirectories.
#
# Example Commands:
#   $> m4bify <audiobook_directory>
#      Combines all audio files in `<audiobook_directory>` into a single M4B audiobook, 
#      with chapters named based on file metadata or filenames.
#
#   $> m4bify --chapters-from-dirs --bitrate 96k <audiobook_directory>
#      Combines all top-level subdirectories in `<audiobook_directory>` into separate chapters. 
#      Files within these directories are processed recursively and alphabetically, with 96 kbps audio quality.
#
# Dependencies:
# - ffmpeg       For audio conversion and merging.
# - ffprobe      For extracting audio properties like duration.
# - mp4chaps     For adding chapter metadata to the final M4B file.
# - mp4art       For adding in a cover image to the final M4A file before converting it to M4B.

readonly VERSION="v0.3.6"

# Color schema for pretty print
readonly NC='\033[0m'           # No Color
declare -A COLORS=(
    # -- print usage
    [TITLE]='\033[0;36m'        # Cyan
    [TEXT]='\033[0;37m'         # White
    [CMD]='\033[0;34m'          # Blue
    [ARGS]='\033[0;35m'         # Magenta
    [PATTERN]='\033[0;35m'      # Magenta
    # -- conversion log
    [SECTION]='\033[1;32m'      # Green (bold)
    [CHAPTER]='\033[1;35m'      # Magenta (bold)
    [ACTION]='\033[0;34m⏳ '    # Blue
    [NEWCHAP]='\033[0;36m📝 '   # Cyan
    [FILE]='\033[0;36m📄 '      # Cyan
    [META]='\033[0;36m📕️ '      # Cyan
    # -- message severity
    [INFO]='\033[0;36mℹ️ '      # Cyan
    [WARN]='\033[0;33m⚠️ '      # Yellow
    [ERROR]='\033[0;31m❌ '     # Red
    [SUCCESS]='\033[0;32m✅ '   # Green
)

readonly FINAL_M4A_FILENAME="final.m4a"
readonly CHAPTER_FILENAME="final.chapters.txt"
readonly FILE_ORDER_FILENAME="file_order.txt"

FFMPEG=$(command -v ffmpeg)
FFPROBE=$(command -v ffprobe)
MP4CHAPS=$(command -v mp4chaps)
MP4ART=$(command -v mp4art)
readonly FFMPEG FFPROBE MP4CHAPS MP4ART

# libfdk_acc VBR Quality Profiles
# Profile  | Bitrate (kbps) | Description
# ---------|----------------|--------------------------
#    1     | ~32            | Low quality
#    2     | ~40            | Medium quality
#    3     | ~56            | High quality
#    4     | ~72            | Very high quality
#    5     | ~112           | Highest quality
LIBFDK_VBR_PROFILE=5

# aac VBR Quality Profiles
# Profile  | Bitrate Range (kbps) | Description
# ---------|-----------------------|--------------------------
#    0     | 220–260              | Highest quality
#    1     | 190–250              | Very high quality (default)
#    2     | 170–210              | High quality (recommended)
#    3     | 150–195              | Medium quality
#    4     | 130–175              | Standard quality
#    5     | 110–145              | Lower quality
#    6     |  90–130              | Low quality
#    7     |  80–120              | Very low quality
#    8     |  70–105              | Poor quality
#    9     |  65–85               | Lowest quality
AAC_VBR_PROFILE=1

INFO_TOTAL_SIZE=0
INFO_TOTAL_CHAPTERS=0
INFO_TOTAL_DURATION=""
INFO_META_AUTHOR=""
INFO_META_TITLE=""
INFO_META_DATE=""

function print_usage {
  echo -e "${COLORS[TITLE]}$(basename "$0")${NC} ${COLORS[TEXT]}${VERSION}${NC}"
  echo -e ""
  echo -e "${COLORS[TITLE]}Usage:${NC}"
  echo -e "  ${COLORS[CMD]}$(basename "$0")${NC} ${COLORS[ARGS]}[options] <audiobook_directory>${NC}"
  echo -e ""
  echo -e "${COLORS[TITLE]}Options:${NC}"
  echo -e "  ${COLORS[ARGS]}-d, --chapters-from-dirs${NC}    Treats each top-level subdirectory as a chapter."
  echo -e "                              Files within each chapter directory (including nested ones)"
  echo -e "                              are discovered recursively and processed alphabetically."
  echo -e "  ${COLORS[ARGS]}-b, --bitrate <value>${NC}       Desired audio bitrate for the output, e.g., \"128k\" or \"96k\"."
  echo -e "                              Defaults to VBR Very High quality (~96-192 kbps)."
  echo -e "  ${COLORS[ARGS]}--help${NC}                      Display this help message and exit."
  echo -e ""
  echo -e "${COLORS[TITLE]}Arguments:${NC}"
  echo -e "  ${COLORS[ARGS]}<audiobook_directory>${NC}       Path to the directory containing audiobook files or subdirectories."
  echo -e ""
  echo -e "${COLORS[TITLE]}Examples:${NC}"
  echo -e "  ${COLORS[CMD]}$(basename "$0")${NC} ${COLORS[ARGS]}\"/home/user/Author Name - Book Title (1993)\"${NC}"
  echo -e "      Combines all audio files in the directory \"Author Name - Book Title (1993)\""
  echo -e "      into a single M4B audiobook. Chapters are created based on filenames or embedded"
  echo -e "      audio metadata, with files processed in alphabetical order. Such as the directory name"
  echo -e "      follows the pattern ${COLORS[PATTERN]}'<author_name> - <book_title> (year)'${NC}, the author name, book title,"
  echo -e "      and year will be automatically extracted and embedded into the resulting M4B audiobook."
  echo -e ""
  echo -e "  ${COLORS[CMD]}$(basename "$0")${NC} ${COLORS[ARGS]}-d -b 96k /path/to/audiobook${NC}"
  echo -e "      Each top-level subdirectory in \"audiobook\" is treated as a chapter."
  echo -e "      Files within each chapter are processed recursively and alphabetically,"
  echo -e "      with audio encoded at 96 kbps bitrate."
  echo -e ""
  echo -e "${COLORS[TITLE]}Description:${NC}"
  echo -e "  This script automates the creation of an M4B audiobook. It processes audio files"
  echo -e "  recursively in the provided directory, maintaining playback order by sorting"
  echo -e "  files alphabetically. Depending on the mode:"
  echo -e "    - File-based chapters: Each audio file becomes a chapter."
  echo -e "    - Directory-based chapters: Each top-level subdirectory becomes a chapter, and"
  echo -e "      all audio files within it are combined, including files in nested subdirectories."
  echo -e "  Additionally, the script can extract metadata from the directory name to embed in the M4B."
  echo -e "  If the directory name follows a supported naming pattern, the script will automatically"
  echo -e "  extract the author name, book title, and year from the name and embed these values into"
  echo -e "  the resulting M4B audiobook. The supported directory name patterns include:"
  echo -e "    - ${COLORS[PATTERN]}<author_name> - <book_title> (<year>)${NC}       'J.K. Rowling - Harry Potter (1997)'"
  echo -e "    - ${COLORS[PATTERN]}<author_name> - <book_title> [<year>]${NC}       'J.K. Rowling - Harry Potter [1997]'"
  echo -e "    - ${COLORS[PATTERN]}<book_title> (<year>)${NC}                       'Harry Potter (1997)'"
  echo -e "    - ${COLORS[PATTERN]}<book_title> [<year>]${NC}                       'Harry Potter [1997]'"
  echo -e "    - ${COLORS[PATTERN]}<author_name> - <book_title>${NC}                'J.K. Rowling - Harry Potter'"
  echo -e "  Both hyphen (-) and underscore (_) are supported as separators in these patterns."
  echo -e "  If there is an image file in the directory or embedded art within the audio files,"
  echo -e "  it will be used as the book cover for the M4B audiobook."
  echo -e ""
  echo -e "${COLORS[TITLE]}Workflow:${NC}"
  echo -e "  1. Scans the provided audiobook directory to identify audio files or subdirectories."
  echo -e "  2. Processes files in **alphabetical order** for consistent playback sequence."
  echo -e "  3. Organizes files into chapters based on filenames, metadata, or directory structure."
  echo -e "  4. Converts audio files to AAC format with the specified bitrate or default quality."
  echo -e "  5. Combines all files into a single M4B file with chapter markers."
  echo -e "  6. Extracts author name, book title, and year from the directory name if it follows a supported pattern."
  echo -e "  7. Uses any image file or embedded art as the book cover in the M4B audiobook."
  echo -e ""
  echo -e "${COLORS[TITLE]}Dependencies:${NC}"
  echo -e "  The following tools must be installed and available in your PATH:"
  echo -e "    ${COLORS[CMD]}ffmpeg${NC}       - Required for audio format conversion."
  echo -e "    ${COLORS[CMD]}ffprobe${NC}      - Used for analyzing audio file properties."
  echo -e "    ${COLORS[CMD]}mp4chaps${NC}     - Needed for chapter metadata manipulation."
  echo -e "    ${COLORS[CMD]}mp4art${NC}       - Adds cover image to audio book."
  echo -e ""
}

function get_relative_path {
  local parent_path=$1 nested_path=$2

  parent_real=$(realpath "${parent_path}")
  nested_real=$(realpath "${nested_path}")

  if [[ "${nested_real}" == "${parent_real}"* ]]; then
    rel_path="${nested_real#"$parent_real/"}"
    echo "${rel_path}"
  else
    echo "${nested_path}"
  fi
}

function get_chapter_name {
  local file=$1
  local chapter_name

  # Try to get chapter name from MP3 'title' tag.
  chapter_name=$(${FFMPEG} -i "${file}" 2>&1 | grep -m 1 "title" | sed 's/.*title\s*:\s*//')

  # Fallback to base file name, with stripped invalid characters.
  if [ -z "${chapter_name}" ]; then
    chapter_name=$(basename "${file}" | sed 's/\.[^.]*$//' | sed 's/[<>:"/\\|?*]//g')
  fi

  echo "${chapter_name}"
}

function convert {
  local in_file=$1 out_file=$2 bitrate=$3 path_info=$4
  local quality=""
  local codec="aac" # Native FFmpeg AAC audio codec

  # Use libfdk_aac codec, if available
  if ${FFMPEG} -version | grep -q "enable-libfdk-aac"; then
    codec="libfdk_aac"
  fi

  # Select quality options
  if [[ "${bitrate}" == "vbr" ]]; then
    if [[ "${codec}" == "libfdk_aac" ]]; then
      quality="-vbr ${LIBFDK_VBR_PROFILE}"
      echo -e "${COLORS[ACTION]}Encoding '${path_info}' [${codec} vbr ${LIBFDK_VBR_PROFILE}]...${NC}"
    else
      quality="-q:a ${AAC_VBR_PROFILE}"
      echo -e "${COLORS[ACTION]}Encoding '${path_info}' [${codec} vbr ${AAC_VBR_PROFILE}]...${NC}"
    fi
  else
    quality="-b:a ${bitrate}"
    echo -e "${COLORS[ACTION]}Encoding '${path_info}' [${codec} cbr ${bitrate}]...${NC}"
  fi

  # shellcheck disable=SC2086
  if ${FFMPEG} -i "${in_file}" -c:a "${codec}" ${quality} -vn "${out_file}" -y > /dev/null 2>&1; then
    echo -e "${COLORS[SUCCESS]}Successfully encoded.${NC}"
  else
    echo -e "${COLORS[ERROR]}Failed to encode!${NC}"
    exit 1
  fi
}

function add_cover_image {
  local m4b_file=$1 source_dir=$2 temp_dir=$3
  local cover_image image_ext

  echo -e "${COLORS[ACTION]}Checking for cover image...${NC}"

  # Use the first image file in the source folder as cover
  cover_image=$(find "${source_dir}" -type f \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
    -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.tiff" \
    -o -iname "*.heic" -o -iname "*.heif" \) | head -n 1)

  if [[ -n "${cover_image}" ]]; then
    rel_path=$( get_relative_path "${source_dir}" "${cover_image}" )
    echo -e "${COLORS[INFO]}Using artwork from image file '${rel_path}'${NC}"
  else
    echo -e "${COLORS[INFO]}No external cover image file found.${NC}"

    # If there is no image file, try to extract an embedded cover art from the audio files
    mapfile -d $'\n' -t audio_files < <(find "${source_dir}" -type f \
      \( -name '*.mp3' -o -name '*.wav' -o -name '*.flac' \
      -o -name '*.aac' -o -name '*.ogg' -o -name '*.m4a' \
      -o -name '*.wma' \) | sort)

    for file in "${audio_files[@]}"; do
      [[ ! -f "${file}" ]] && continue  # Skip if file does not exist

      # Check for the embedded cover art
      image_codec=$(ffprobe -v quiet \
        -select_streams v:0 -show_entries stream=codec_name \
        -of default=noprint_wrappers=1:nokey=1 "${file}")

      if [[ -n "${image_codec}" ]]; then
        rel_path=$( get_relative_path "${source_dir}" "${file}" )
        echo -e "${COLORS[INFO]}Using embedded artwork from '${rel_path}' [${image_codec}]${NC}"

        case "${image_codec}" in
          mjpeg|jpeg) image_ext="jpg" ;;
          png) image_ext="png" ;;
          bmp) image_ext="bmp" ;;
          gif) image_ext="gif" ;;
          tiff) image_ext="tiff" ;;
          webp) image_ext="webp" ;;
          heif|heic) image_ext="heic" ;;
          *) image_ext="img" ;;  # Unknown or unsupported image codecs
        esac

        cover_image="${temp_dir}/cover.${image_ext}"

        # Extract cover image from the audio file
        if ${FFMPEG} -i "${file}" -an -vcodec copy -frames:v 1 "${cover_image}" -y > /dev/null 2>&1; then
          break
        else
          echo -e "${COLORS[WARN]}Failed to extract the embedded cover.${NC}"
        fi
      fi
    done
  fi

  # Embed the cover image file into the m4b audiobook
  if [[ -f "${cover_image}" ]]; then
    echo -e "${COLORS[ACTION]}Embedding cover art...${NC}"
    if ${MP4ART} --add "${cover_image}" "${m4b_file}" > /dev/null 2>&1; then
      echo -e "${COLORS[SUCCESS]}Cover art added successfully.${NC}"
    else
      echo -e "${COLORS[ERROR]}Failed to add cover art!${NC}"
      exit 1
    fi
  else
    echo -e "${COLORS[INFO]}No supported embedded cover art.${NC}"
    echo -e "${COLORS[WARN]}Skipped cover art addition.${NC}"
  fi
}

function add_description {
  local m4b_file=$1 source_dir=$2 temp_dir=$3
  local description_file

  echo -e "${COLORS[ACTION]}Checking for book description file...${NC}"

  # Use the first matched file in the source folder as book description
  description_file=$(find "${source_dir}" -type f \
    \( -iname "*.txt" -o -iname "*.info" -o -iname "*.md" \) | head -n 1)

  # Embed the book description into the m4b audiobook
  if [[ -f "${description_file}" ]]; then
    rel_path=$( get_relative_path "${source_dir}" "${description_file}" )
    echo -e "${COLORS[INFO]}Found description in '${rel_path}'${NC}"

    # Read and clean up the description:
    # - Trim leading/trailing whitespace
    # - Preserve internal newlines
    description=$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "${description_file}")

    original_m4a="${temp_dir}/final.nodescr.m4a"
    mv "${m4b_file}" "${original_m4a}"

    echo -e "${COLORS[ACTION]}Embedding description into audiobook metadata...${NC}"
    if ${FFMPEG} -i "${original_m4a}" \
        -metadata description="${description}" \
        -codec copy "${m4b_file}" -y > /dev/null 2>&1; then
      echo -e "${COLORS[SUCCESS]}Book description embedded successfully.${NC}"
    else
      echo -e "${COLORS[ERROR]}Failed to embed book description.${NC}"
      exit 1
    fi
  else
    echo -e "${COLORS[INFO]}No book description found.${NC}"
    echo -e "${COLORS[WARN]}Skipped book description addition.${NC}"
  fi
}

function add_metadata {
  local m4b_file=$1 source_dir=$2 temp_dir=$3
  local dir_name author title date

  local regex_1='^(.+) [-_] (.+) \(([0-9]{4})\)$'  # "Author Name - Book Title (1939)"
  local regex_2='^(.+) [-_] (.+) \[([0-9]{4})\]$'  # "Author Name _ Book Title [1939]"
  local regex_3='^(.+) \(([0-9]{4})\)$'            # "Book Title (1939)"
  local regex_4='^(.+) \[([0-9]{4})\]$'            # "Book Title [1939]"
  local regex_5='^(.+) [-_] (.+)$'                 # "Author Name - Book Title"

  echo -e "${COLORS[ACTION]}Extracting audiobook metadata...${NC}"
  dir_name=$(basename "${source_dir%/}")

  # Try to extract audiobook metadata from directory name
  if [[ ${dir_name} =~ ${regex_1} || ${dir_name} =~ ${regex_2} ]]; then
    author="${BASH_REMATCH[1]}"; title="${BASH_REMATCH[2]}"; date="${BASH_REMATCH[3]}"
  elif [[ ${dir_name} =~ ${regex_3} || ${dir_name} =~ ${regex_4} ]]; then
    title="${BASH_REMATCH[1]}"; date="${BASH_REMATCH[2]}"; author=""
  elif [[ ${dir_name} =~ ${regex_5} ]]; then
    author="${BASH_REMATCH[1]}"; title="${BASH_REMATCH[2]}"; date=""
  else
    echo -e "${COLORS[INFO]}No matching pattern for directory name.${NC}"
  fi

  if [[ -n "${title}" ]]; then
    original_m4a="${temp_dir}/final.untagged.m4a"
    mv "${m4b_file}" "${original_m4a}"

    INFO_META_AUTHOR="${author}"
    INFO_META_TITLE="${title}"
    INFO_META_DATE="${date}"

    echo -e "${COLORS[META]}Author:${NC} ${author}"
    echo -e "${COLORS[META]}Title:${NC} ${title}"
    echo -e "${COLORS[META]}Date:${NC} ${date}"
    echo -e "${COLORS[ACTION]}Embedding metadata...${NC}"

    if ${FFMPEG} -i "${original_m4a}" \
        -metadata title="${title}" -metadata album="${title}" \
        -metadata artist="${author}" -metadata album_artist="${author}" \
        -metadata date="${date}" -metadata genre="Audiobook" \
        -codec copy "${m4b_file}" -y > /dev/null 2>&1; then
      echo -e "${COLORS[SUCCESS]}Metadata embedded successfully.${NC}"
    else
      echo -e "${COLORS[ERROR]}Failed to embed metadata.${NC}"
      exit 1
    fi
  else
    echo -e "${COLORS[WARN]}Skipped metadata extraction.${NC}"
  fi
}

function combine {
  local file_order=$1 m4a_file=$2

  echo -e "${COLORS[ACTION]}Combining audio files into a single audiobook...${NC}"

  if ${FFMPEG} -f concat -safe 0 -i "${file_order}" -c copy "${m4a_file}" -y > /dev/null 2>&1; then
    echo -e "${COLORS[SUCCESS]}Audio files merged successfully.${NC}"
    INFO_TOTAL_SIZE=$(echo "scale=0; $(stat -c%s "${m4a_file}") / 1024^2" | bc) # MB
  else
    echo -e "${COLORS[ERROR]}Failed to merge audio files!${NC}"
    exit 1
  fi
}

function add_chapters {
  local temp_dir=$1 m4a_file=$2

  echo -e "${COLORS[ACTION]}Adding chapter markers...${NC}"

  if (cd "${temp_dir}" && ${MP4CHAPS} -i "${m4a_file}" > /dev/null 2>&1); then
    echo -e "${COLORS[SUCCESS]}Chapter markers added successfully.${NC}"
  else
    echo -e "${COLORS[ERROR]}Failed to add chapter markers!${NC}"
    exit 1
  fi
}

function move_audiobook {
  local temp_file=$1 destination=$2

  echo -e "${COLORS[ACTION]}Moving audiobook to destination...${NC}"
 
  if mv "${temp_file}" "${destination}" > /dev/null 2>&1; then
    echo -e "${COLORS[SUCCESS]}Audiobook moved successfully.${NC}"
  else
    echo -e "${COLORS[ERROR]}Failed to move audiobook to the destinaton!${NC}"
    exit 1
  fi
}

function process_file_as_chapter {
  local temp_dir=$1 input_dir=$2 bitrate=$3 file_order=$4 file_chapter=$5
  local i=1 current_time=0

  # Discover all audio files and process them in alphabetical order
  mapfile -d $'\n' -t audio_files < <(find "${input_dir}" -type f \
    \( -iname '*.mp3' -o -iname '*.wav' -o -iname '*.flac' \
    -o -iname '*.aac' -o -iname '*.ogg' -o -iname '*.m4a' \
    -o -iname '*.wma' \) | sort)

  INFO_TOTAL_CHAPTERS="${#audio_files[@]}"
  echo -e "${COLORS[INFO]}Total Chapters:${NC} ${INFO_TOTAL_CHAPTERS}"
  echo -e "-----------------------------------------\n"
  echo -e "${COLORS[SECTION]}Processing Chapters...${NC}"
  echo -e "-----------------------------------------"

  for file in "${audio_files[@]}"; do
    [[ ! -f "${file}" ]] && continue  # Skip if file does not exist

    chapter_name=$( get_chapter_name "${file}" )
    echo -e "${COLORS[CHAPTER]}Chapter ${i}:${NC} ${chapter_name}"

    output_m4a=$(mktemp "${temp_dir}/audio_${i}_XXXXXXXXXXXXXXX.m4a")
    echo "file '${output_m4a}'" >> "${file_order}"

    rel_path=$( get_relative_path "${input_dir}" "${file}" )
    convert "${file}" "${output_m4a}" "${bitrate}" "${rel_path}"

    # Format the timestamp with hours potentially exceeding 24
    timestamp=$(LC_NUMERIC="C" printf "%02d:%02d:%06.3f\n" \
      "$(echo "${current_time} / 3600" | bc)" \
      "$(echo "${current_time} % 3600 / 60" | bc)" \
      "$(echo "${current_time} % 60" | bc)")
    echo "CHAPTER${i}=${timestamp}" >> "${file_chapter}"
    echo "CHAPTER${i}NAME=${chapter_name}" >> "${file_chapter}"

    duration=$( ${FFPROBE} -v quiet -show_entries format=duration "${output_m4a}" -of csv="p=0" )
    current_time=$(echo "${current_time} + ${duration}" | bc)
    i=$((i + 1))

    echo -e "${COLORS[NEWCHAP]}Added chapter '${chapter_name}' @ ${timestamp}${NC}"
    echo -e "-----------------------------------------"
  done

  INFO_TOTAL_DURATION=$(printf "%02d hours %02d minutes\n" \
      "$(echo "${current_time} / 3600" | bc)" \
      "$(echo "${current_time} % 3600 / 60" | bc)")
}

function process_dirs_as_chapter {
  local temp_dir=$1 input_dir=$2 bitrate=$3 file_order=$4 file_chapter=$5
  local i=1 current_time=0

  local chapters=("${input_dir}"/*/)

  INFO_TOTAL_CHAPTERS="${#chapters[@]}"
  echo -e "${COLORS[INFO]}Total Chapters:${NC} ${INFO_TOTAL_CHAPTERS}"
  echo -e "-----------------------------------------\n"
  echo -e "${COLORS[SECTION]}Processing Chapters...${NC}"
  echo -e "-----------------------------------------"

  for chapter_dir in "${chapters[@]}"; do
    chapter_name=$(basename "${chapter_dir}")
    echo -e "${COLORS[CHAPTER]}Chapter ${i}:${NC} ${chapter_name}"

    # Discover all audio files and process them in alphabetical order
    mapfile -d $'\n' -t audio_files < <(find "${chapter_dir}" -type f \
      \( -name '*.mp3' -o -name '*.wav' -o -name '*.flac' \
      -o -name '*.aac' -o -name '*.ogg' -o -name '*.m4a' \
      -o -name '*.wma' \) | sort)

    chapter_duration=0
    for file in "${audio_files[@]}"; do
      [[ ! -f "${file}" ]] && continue  # Skip if file does not exist

      output_m4a=$(mktemp "${temp_dir}/audio_${i}_XXXXXXXXXXXXXXX.m4a")
      echo "file '${output_m4a}'" >> "${file_order}"

      rel_path=$( get_relative_path "${input_dir}" "${file}" )
      convert "${file}" "${output_m4a}" "${bitrate}" "${rel_path}"

      duration=$( ${FFPROBE} -v quiet -show_entries format=duration "${output_m4a}" -of csv="p=0" )
      chapter_duration=$(echo "${chapter_duration} + ${duration}" | bc)
    done

    # Format the timestamp with hours potentially exceeding 24
    timestamp=$(LC_NUMERIC="C" printf "%02d:%02d:%06.3f\n" \
      "$(echo "${current_time} / 3600" | bc)" \
      "$(echo "${current_time} % 3600 / 60" | bc)" \
      "$(echo "${current_time} % 60" | bc)")
    echo "CHAPTER${i}=${timestamp}" >> "${file_chapter}"
    echo "CHAPTER${i}NAME=${chapter_name}" >> "${file_chapter}"
     
    current_time=$(echo "${current_time} + ${chapter_duration}" | bc)
    i=$((i + 1))

    echo -e "${COLORS[NEWCHAP]}Added chapter '${chapter_name}' @ ${timestamp}${NC}"
    echo -e "-----------------------------------------"
  done

  INFO_TOTAL_DURATION=$(printf "%02d hours %02d minutes\n" \
      "$(echo "${current_time} / 3600" | bc)" \
      "$(echo "${current_time} % 3600 / 60" | bc)")
}

CHAPTERS_FROM_DIRS=false  # Default is chapter from file
BITRATE="vbr"             # Default is VBR

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -d|--chapters-from-dirs) CHAPTERS_FROM_DIRS=true; shift ;;
    -b|--bitrate) BITRATE="$2"; shift 2 ;;
    --help) print_usage; exit 0 ;;
    *) break ;;
  esac
done

# Required positional argument: audiobook directory
if [[ "$#" -lt 1 ]]; then
  echo -e "\n${COLORS[ERROR]}Error: Input directory is required.\n${NC}"
  print_usage
  exit 1
fi

if [[ "$#" -gt 1 ]]; then
  echo -e "\n${COLORS[ERROR]}Error: Unrecognized extra arguments.\n${NC}"
  print_usage
  exit 1
fi

if [[ -z "${FFMPEG}" || -z "${FFPROBE}" || -z "${MP4CHAPS}" || -z "${MP4ART}" ]]; then
  echo -e "${COLORS[ERROR]}Missing required binaries: ffmpeg, ffprobe, mp4chaps, mp4art.${NC}"
  exit 1
fi

INPUT_DIR="$(realpath "$1")"
OUTPUT_FILE="$(dirname "${INPUT_DIR}")/$(basename "${INPUT_DIR}").m4b"
readonly INPUT_DIR OUTPUT_FILE

if [[ ! -d "${INPUT_DIR}" ]]; then
  echo -e "\n${COLORS[ERROR]}Error: Input directory does not exist.${NC}"
  exit 1
fi

FFMPEG_VERSION=$(ffmpeg -version | head -n 1 | awk '{print $3}')
FFPROBE_VERSION=$(ffprobe -version | head -n 1 | awk '{print $3}')
MP4CHAPS_VERSION=$(mp4chaps --version 2>&1 | grep -oP 'MP4v2 \K[^\s]+')
MP4ART_VERSION=$(mp4art --version 2>&1 | grep -oP 'MP4v2 \K[^\s]+')
readonly FFMPEG_VERSION FFPROBE_VERSION MP4CHAPS_VERSION MP4ART_VERSION

FFMPEG_OPTIONS=""
if ${FFMPEG} -version | grep -q "enable-libfdk-aac"; then
  FFMPEG_OPTIONS=" (libfdk_aac)"
fi
readonly FFMPEG_OPTIONS

TEMP_DIR=$(mktemp -d)
FINAL_M4A_FILE="${TEMP_DIR}/${FINAL_M4A_FILENAME}"
FILE_CHAPTER="${TEMP_DIR}/${CHAPTER_FILENAME}"
FILE_ORDER="${TEMP_DIR}/${FILE_ORDER_FILENAME}"
readonly TEMP_DIR FINAL_M4A_FILE FILE_CHAPTER FILE_ORDER

trap 'rm -rf "${TEMP_DIR}"' EXIT

touch "${FILE_CHAPTER}"
touch "${FILE_ORDER}"

echo -e "\n${COLORS[SECTION]}Detecting Environment...${NC}"
echo -e "-----------------------------------------"
echo -e "${COLORS[INFO]}m4bify:${NC} ${VERSION}"
echo -e "${COLORS[INFO]}ffmpeg:${NC} ${FFMPEG_VERSION}${FFMPEG_OPTIONS}"
echo -e "${COLORS[INFO]}ffprobe:${NC} ${FFPROBE_VERSION}"
echo -e "${COLORS[INFO]}mp4chaps:${NC} ${MP4CHAPS_VERSION}"
echo -e "${COLORS[INFO]}mp4art:${NC} ${MP4ART_VERSION}"
echo -e "-----------------------------------------"
echo -e "\n${COLORS[SECTION]}Creating Audiobook...${NC}"
echo -e "-----------------------------------------"
echo -e "${COLORS[INFO]}Source Directory:${NC} ${INPUT_DIR}"
echo -e "${COLORS[INFO]}Output File:${NC} ${OUTPUT_FILE}"
echo -e "${COLORS[INFO]}Bitrate:${NC} ${BITRATE}"

if ${CHAPTERS_FROM_DIRS}; then
  echo -e "${COLORS[INFO]}Mode:${NC} Directory-based chapters"
  process_dirs_as_chapter "${TEMP_DIR}" "${INPUT_DIR}" "${BITRATE}" "${FILE_ORDER}" "${FILE_CHAPTER}"
else
  echo -e "${COLORS[INFO]}Mode:${NC} File-based chapters"
  process_file_as_chapter "${TEMP_DIR}" "${INPUT_DIR}" "${BITRATE}" "${FILE_ORDER}" "${FILE_CHAPTER}"
fi

echo -e "\n${COLORS[SECTION]}Merging Audio Files...${NC}"
echo -e "-----------------------------------------"

# Combine all M4A files into a single file
combine "${FILE_ORDER}" "${FINAL_M4A_FILE}"

echo -e "-----------------------------------------"
echo -e "\n${COLORS[SECTION]}Processing Metadata...${NC}"
echo -e "-----------------------------------------"

# Add chapters to the final file
add_chapters "${TEMP_DIR}" "${FINAL_M4A_FILE}"
echo -e "---"

# Add cover image (if available)
add_cover_image "${FINAL_M4A_FILE}" "${INPUT_DIR}" "${TEMP_DIR}"
echo -e "---"

# Add book description (if available)
add_description "${FINAL_M4A_FILE}" "${INPUT_DIR}" "${TEMP_DIR}"
echo -e "---"

# Add audiobook ID3 tags
add_metadata "${FINAL_M4A_FILE}" "${INPUT_DIR}" "${TEMP_DIR}"

echo -e "-----------------------------------------"
echo -e "\n${COLORS[SECTION]}Finalizing...${NC}"
echo -e "-----------------------------------------"

# Move the created audiobook to the destination
move_audiobook "${FINAL_M4A_FILE}" "${OUTPUT_FILE}"

echo -e "${COLORS[SUCCESS]}Audiobook creation complete!${NC}"
echo -e "-----------------------------------------"
echo -e "\n${COLORS[SECTION]}M4B Audiobook Summary:${NC}"
echo -e "-----------------------------------------"
echo -e "${COLORS[FILE]}File:${NC} ${OUTPUT_FILE}"
echo -e "${COLORS[FILE]}Chapters:${NC} ${INFO_TOTAL_CHAPTERS}"
echo -e "${COLORS[FILE]}Length:${NC} ${INFO_TOTAL_DURATION}"
echo -e "${COLORS[FILE]}Size:${NC} ${INFO_TOTAL_SIZE} MB"
echo -e "${COLORS[META]}Author:${NC} ${INFO_META_AUTHOR}"
echo -e "${COLORS[META]}Title:${NC} ${INFO_META_TITLE}"
echo -e "${COLORS[META]}Date:${NC} ${INFO_META_DATE}"
echo -e "-----------------------------------------\n"
