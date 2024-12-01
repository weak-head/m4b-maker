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
#   --chapters-from-dirs      Treats each top-level subdirectory as a chapter. Audio files in these directories, 
#                              including nested subdirectories, are combined into that chapter.
#   --bitrate <value>         Sets the audio encoding bitrate, e.g., "128k" or "96k" (default: AAC VBR Very High).
#   --help                    Displays usage instructions and exits.
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


# Color codes for pretty print
readonly NC='\033[0m'      # No Color
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[0;37m'

readonly FINAL_M4A_FILENAME="final.m4a"
readonly CHAPTER_FILENAME="final.chapters.txt"
readonly FILE_ORDER_FILENAME="file_order.txt"

FFMPEG=$(command -v ffmpeg)
FFPROBE=$(command -v ffprobe)
MP4CHAPS=$(command -v mp4chaps)
MP4ART=$(command -v mp4art)
readonly FFMPEG FFPROBE MP4CHAPS MP4ART

INFO_TOTAL_CHAPTERS=0
INFO_TOTAL_DURATION=""

function print_usage {
  local VERSION="v0.3.1"

  echo -e "${CYAN}$(basename "$0")${NC} ${WHITE}${VERSION}${NC}"
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  ${BLUE}$(basename "$0") [options] <audiobook_directory>${NC}"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BLUE}--chapters-from-dirs${NC}    Treats each top-level subdirectory as a chapter."
  echo -e "                          Files within each chapter directory (including nested ones)"
  echo -e "                          are discovered recursively and processed alphabetically."
  echo -e "  ${BLUE}--bitrate <value>${NC}       Desired audio bitrate for the output, e.g., \"128k\" or \"96k\"."
  echo -e "                          Defaults to AAC VBR Very High quality."
  echo -e "  ${BLUE}--help${NC}                  Display this help message and exit."
  echo -e ""
  echo -e "${CYAN}Arguments:${NC}"
  echo -e "  ${BLUE}<audiobook_directory>${NC}   Path to the directory containing audiobook files or subdirectories."
  echo -e ""
  echo -e "${CYAN}Examples:${NC}"
  echo -e "  ${BLUE}$(basename "$0")${NC} ${MAGENTA}/path/to/audiobook${NC}"
  echo -e "      Combines all audio files in the \"audiobook\" directory into a single M4B audiobook."
  echo -e "      Chapters are based on filenames or metadata, with files processed alphabetically."
  echo -e ""
  echo -e "  ${BLUE}$(basename "$0")${NC} ${MAGENTA}--chapters-from-dirs --bitrate 96k /path/to/audiobook${NC}"
  echo -e "      Each top-level subdirectory in \"audiobook\" is treated as a chapter."
  echo -e "      Files within each chapter are processed recursively and alphabetically,"
  echo -e "      with audio encoded at 96 kbps bitrate."
  echo -e ""
  echo -e "${CYAN}Description:${NC}"
  echo -e "  This script automates the creation of an M4B audiobook. It processes audio files"
  echo -e "  recursively in the provided directory, maintaining playback order by sorting"
  echo -e "  files alphabetically. Depending on the mode:"
  echo -e "    - File-based chapters: Each audio file becomes a chapter."
  echo -e "    - Directory-based chapters: Each top-level subdirectory becomes a chapter, and"
  echo -e "      all audio files within it are combined, including files in nested subdirectories."
  echo -e ""
  echo -e "${CYAN}Workflow:${NC}"
  echo -e "  1. Scans the provided audiobook directory to identify audio files or subdirectories."
  echo -e "  2. Processes files in **alphabetical order** for consistent playback sequence."
  echo -e "  3. Organizes files into chapters based on filenames, metadata, or directory structure."
  echo -e "  4. Converts audio files to AAC format with the specified bitrate or default quality."
  echo -e "  5. Combines all files into a single M4B file with chapter markers."
  echo -e ""
  echo -e "${CYAN}Dependencies:${NC}"
  echo -e "  The following tools must be installed and available in your PATH:"
  echo -e "    ${YELLOW}ffmpeg${NC}       - Required for audio format conversion."
  echo -e "    ${YELLOW}ffprobe${NC}      - Used for analyzing audio file properties."
  echo -e "    ${YELLOW}mp4chaps${NC}     - Needed for chapter metadata manipulation."
  echo -e "    ${YELLOW}mp4art${NC}       - Adds cover image to audio book."
  echo -e ""
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
  local in_file=$1 out_file=$2 bitrate=$3
  local quality_args

  if [[ "${bitrate}" == "vbr-very-high" ]]; then
    quality_args="-q:a 1"
    echo -e "${BLUE}Converting '${in_file}' to M4A (AAC VBR Very High)...${NC}"
  else
    quality_args="-b:a ${bitrate}"
    echo -e "${BLUE}Converting '${in_file}' to M4A at bitrate ${bitrate}...${NC}"
  fi

  # shellcheck disable=SC2086
  if ${FFMPEG} -i "${in_file}" -c:a aac ${quality_args} -vn "${out_file}" -y > /dev/null 2>&1; then
    echo -e "${GREEN}✔ Successfully converted to M4A.${NC}"
  else
    echo -e "${RED}Error during conversion!${NC}"
    exit 1
  fi
}

function add_cover_image {
  local m4b_file=$1 source_folder=$2
  local cover_image

  # Looks in the source folder for the first jpg or png file within the audiobook directory
  cover_image=$(find "${source_folder}" -type f \( -iname "*.jpg" -o -iname "*.png" \) | head -n 1)
  
  if [[ -z "${cover_image}" ]]; then
    echo -e "\n${YELLOW}⚠ Warning: No cover image found. Skipping cover addition.${NC}"
    return
  fi

  echo -e "\n${BLUE}Adding cover image to audiobook...${NC}"

  if ${MP4ART} --add "${cover_image}" "${m4b_file}" > /dev/null 2>&1; then
    echo -e "${GREEN}✔ Successfully added cover image.${NC}"
  else
    echo -e "${RED}Error during cover image addition!${NC}"
    exit 1
  fi
}

function combine {
  local file_order=$1 m4a_file=$2

  echo -e "\n${BLUE}Combining all files into a single M4A file...${NC}"

  if ${FFMPEG} -f concat -safe 0 -i "${file_order}" -c copy "${m4a_file}" -y > /dev/null 2>&1; then
    echo -e "${GREEN}✔ Successfully combined all files.${NC}"
  else
    echo -e "${RED}Error during file concatenation!${NC}"
    exit 1
  fi
}

function add_chapters {
  local temp_dir=$1 m4a_file=$2

  echo -e "\n${BLUE}Adding chapters to the M4A file...${NC}"

  if (cd "${temp_dir}" && ${MP4CHAPS} -i "${m4a_file}" > /dev/null 2>&1); then
    echo -e "${GREEN}✔ Chapters successfully added.${NC}"
  else
    echo -e "${RED}Error adding chapters!${NC}"
    exit 1
  fi
}

function process_file_as_chapter {
  local temp_dir=$1 input_dir=$2 bitrate=$3 file_order=$4 file_chapter=$5
  local i=1 current_time=0

  # Discover all audio files and process them in alphabetical order
  mapfile -d $'\n' -t audio_files < <(find "${input_dir}" -type f \
    \( -name '*.mp3' -o -name '*.wav' -o -name '*.flac' \
    -o -name '*.aac' -o -name '*.ogg' -o -name '*.m4a' \
    -o -name '*.wma' \) | sort)

  INFO_TOTAL_CHAPTERS="${#audio_files[@]}"
  echo -e "${BLUE}Total Chapters:${NC} ${INFO_TOTAL_CHAPTERS}"
  echo -e "-----------------------------------------\n"
  echo -e "${GREEN}Processing Chapters...${NC}"
  echo -e "-----------------------------------------"

  for file in "${audio_files[@]}"; do
    [[ ! -f "${file}" ]] && continue  # Skip if file does not exist

    chapter_name=$( get_chapter_name "${file}" )
    echo -e "${GREEN}Chapter ${i}:${NC} '${chapter_name}'"

    output_m4a="${temp_dir}/$(basename "${file}" ."${file##*.}").m4a"
    echo "file '${output_m4a}'" >> "${file_order}"

    convert "${file}" "${output_m4a}" "${bitrate}"

    # Format the timestamp with hours potentially exceeding 24
    timestamp=$(printf "%02d:%02d:%06.3f\n" \
      "$(echo "${current_time} / 3600" | bc)" \
      "$(echo "${current_time} % 3600 / 60" | bc)" \
      "$(echo "${current_time} % 60" | bc)")
    echo "CHAPTER${i}=${timestamp}" >> "${file_chapter}"
    echo "CHAPTER${i}NAME=${chapter_name}" >> "${file_chapter}"

    duration=$( ${FFPROBE} -v quiet -show_entries format=duration "${output_m4a}" -of csv="p=0" )
    current_time=$(echo "${current_time} + ${duration}" | bc)
    i=$((i + 1))

    echo -e "${YELLOW}Added chapter: '${chapter_name}' at ${timestamp}.${NC}\n"
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
  echo -e "${BLUE}Total Chapters:${NC} ${INFO_TOTAL_CHAPTERS}"
  echo -e "-----------------------------------------\n"
  echo -e "${GREEN}Processing Chapters...${NC}"
  echo -e "-----------------------------------------"

  for chapter_dir in "${chapters[@]}"; do
    chapter_name=$(basename "${chapter_dir}")
    echo -e "${GREEN}Chapter ${i}:${NC} '${chapter_name}'"

    temp_chapter_dir="${temp_dir}/${chapter_name}"
    mkdir -p "${temp_chapter_dir}"

    # Discover all audio files and process them in alphabetical order
    mapfile -d $'\n' -t audio_files < <(find "${chapter_dir}" -type f \
      \( -name '*.mp3' -o -name '*.wav' -o -name '*.flac' \
      -o -name '*.aac' -o -name '*.ogg' -o -name '*.m4a' \
      -o -name '*.wma' \) | sort)

    chapter_duration=0
    for file in "${audio_files[@]}"; do
      [[ ! -f "${file}" ]] && continue  # Skip if file does not exist

      relative_path=$(realpath --relative-to="${input_dir}" "${file}")
      temp_file_path="${temp_chapter_dir}/${relative_path}"
      temp_file_path="${temp_file_path%.*}.m4a"

      echo "file '${temp_file_path}'" >> "${file_order}"

      mkdir -p "$(dirname "${temp_file_path}")"
      convert "${file}" "${temp_file_path}" "${bitrate}"

      duration=$( ${FFPROBE} -v quiet -show_entries format=duration "${temp_file_path}" -of csv="p=0" )
      chapter_duration=$(echo "${chapter_duration} + ${duration}" | bc)
    done

    # Format the timestamp with hours potentially exceeding 24
    timestamp=$(printf "%02d:%02d:%06.3f\n" \
      "$(echo "${current_time} / 3600" | bc)" \
      "$(echo "${current_time} % 3600 / 60" | bc)" \
      "$(echo "${current_time} % 60" | bc)")
    echo "CHAPTER${i}=${timestamp}" >> "${file_chapter}"
    echo "CHAPTER${i}NAME=${chapter_name}" >> "${file_chapter}"
     
    current_time=$(echo "${current_time} + ${chapter_duration}" | bc)
    i=$((i + 1))

    echo -e "${YELLOW}Added chapter: '${chapter_name}' at ${timestamp}.${NC}\n"
    echo -e "-----------------------------------------"
  done

  INFO_TOTAL_DURATION=$(printf "%02d hours %02d minutes\n" \
      "$(echo "${current_time} / 3600" | bc)" \
      "$(echo "${current_time} % 3600 / 60" | bc)")
}

CHAPTERS_FROM_DIRS=false  # Default is chapter from file
BITRATE="vbr-very-high"   # Default is AAC VBR Very High

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --chapters-from-dirs) CHAPTERS_FROM_DIRS=true; shift ;;
    --bitrate) BITRATE="$2"; shift 2 ;;
    --help) print_usage; exit 0 ;;
    *) break ;;
  esac
done

# Required positional argument: audiobook directory
if [[ "$#" -lt 1 ]]; then
  echo -e "\n${RED}Error: Input directory is required.${NC}"
  print_usage
  exit 1
fi

if [[ "$#" -gt 1 ]]; then
  echo -e "\n${RED}Error: Unrecognized extra arguments.${NC}"
  print_usage
  exit 1
fi

if [[ -z "${FFMPEG}" || -z "${FFPROBE}" || -z "${MP4CHAPS}" || -z "${MP4ART}" ]]; then
  echo -e "${RED}Missing required binaries: ffmpeg, ffprobe, mp4chaps, mp4art.${NC}"
  exit 1
fi

INPUT_DIR="$(realpath "$1")"
OUTPUT_FILE="$(dirname "${INPUT_DIR}")/$(basename "${INPUT_DIR}").m4b"
readonly INPUT_DIR OUTPUT_FILE

if [[ ! -d "${INPUT_DIR}" ]]; then
  echo -e "\n${RED}Error: Input directory does not exist.${NC}"
  exit 1
fi

TEMP_DIR=$(mktemp -d)
FINAL_M4A_FILE="${TEMP_DIR}/${FINAL_M4A_FILENAME}"
FILE_CHAPTER="${TEMP_DIR}/${CHAPTER_FILENAME}"
FILE_ORDER="${TEMP_DIR}/${FILE_ORDER_FILENAME}"
readonly TEMP_DIR FINAL_M4A_FILE FILE_CHAPTER FILE_ORDER

trap 'rm -rf "${TEMP_DIR}"' EXIT

touch "${FILE_CHAPTER}"
touch "${FILE_ORDER}"

echo -e "\n${BLUE}Starting audiobook creation...${NC}"
echo -e "-----------------------------------------"
echo -e "${BLUE}Source Directory:${NC} ${INPUT_DIR}"
echo -e "${BLUE}Output File:${NC} ${OUTPUT_FILE}"
echo -e "${BLUE}Bitrate:${NC} ${BITRATE}"

if ${CHAPTERS_FROM_DIRS}; then
  echo -e "${BLUE}Mode:${NC} Directory-based chapters."
  process_dirs_as_chapter "${TEMP_DIR}" "${INPUT_DIR}" "${BITRATE}" "${FILE_ORDER}" "${FILE_CHAPTER}"
else
  echo -e "${BLUE}Mode:${NC} File-based chapters."
  process_file_as_chapter "${TEMP_DIR}" "${INPUT_DIR}" "${BITRATE}" "${FILE_ORDER}" "${FILE_CHAPTER}"
fi

# Combine all M4A files into a single file
combine "${FILE_ORDER}" "${FINAL_M4A_FILE}"

# Add chapters to the final file
add_chapters "${TEMP_DIR}" "${FINAL_M4A_FILE}"

# Add cover image (if available)
add_cover_image "${FINAL_M4A_FILE}" "${INPUT_DIR}"

echo -e "\n${BLUE}Renaming final M4A file to M4B...${NC}"
echo -e "-----------------------------------------\n"
mv "${FINAL_M4A_FILE}" "${OUTPUT_FILE}"

echo -e "${GREEN}✔ Audiobook creation complete!${NC}"
echo -e "-----------------------------------------"
echo -e "${BLUE}Total Chapters:${NC} ${INFO_TOTAL_CHAPTERS}"
echo -e "${BLUE}Total Duration:${NC} ${INFO_TOTAL_DURATION}"
echo -e "${BLUE}Audiobook Saved To:${NC} ${OUTPUT_FILE}"
echo -e "-----------------------------------------\n"
