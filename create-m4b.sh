#!/usr/bin/env bash
# This script automates the creation of an M4B audiobook from various audio formats (such as MP3, WAV, and FLAC).
# It allows for either file-based or directory-based chaptering, preserving structure by organizing chapters sequentially.
#
# Key Features:
# - Accepts an audiobook directory containing multiple audio files or subdirectories for custom chaptering.
# - Supports optional audio quality selection, defaulting to 128 kbps if not specified.
# - Preserves chapter information based on metadata, directory names, or filenames, organizing them in sequence.
#
# Usage Instructions:
#   $> create-m4b [--directories-as-chapters] /path/to/audiobook_directory [audio_quality]
#
# Parameters:
#   --directories-as-chapters - (Optional) When specified, treats each directory as a separate chapter.
#                               Files within each directory are combined into a single chapter.
#   audiobook_directory       - Path to the directory containing audiobook files or subdirectories.
#   audio_quality             - (Optional) Desired audio quality (bitrate) for the output file, e.g., "128k" or "96k".
#                               Defaults to 128 kbps if not provided.
#
# Example Commands:
#   $> create-m4b /home/user/audiobooks/my_book 128k
#      This command creates a single M4B audiobook file from all audio files in the "my_book" directory
#      with 128 kbps audio quality, using file-based chaptering.
#
#   $> create-m4b --directories-as-chapters /home/user/audiobooks/my_series
#      This command treats each directory in "my_series" as a separate chapter, combining files within each
#      directory into one chapter in the final M4B file, using the default audio quality of 128 kbps.


# Color codes for pretty print
readonly NC='\033[0m'      # No Color
readonly BLACK='\033[0;30m'
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

readonly FFMPEG=$(command -v ffmpeg)
readonly FFPROBE=$(command -v ffprobe)
readonly MP4CHAPS=$(command -v mp4chaps)

function get_chapter_name {
  local file=$1

  local chapter_name=$(${FFMPEG} -i "${file}" 2>&1 | grep -m 1 "title" | sed 's/.*title\s*:\s*//')

  if [ -z "${chapter_name}" ]; then
    chapter_name=$(basename "${file}" | sed 's/\.[^.]*$//' | sed 's/[<>:"/\\|?*]//g')
  fi

  echo "${chapter_name}"
}

function convert {
  local in_file=$1
  local out_file=$2
  local quality=$3

  echo -e "${BLUE}Converting ${in_file} to M4A at ${quality}...${NC}"
  ${FFMPEG} -i "${in_file}" -c:a aac -b:a "${quality}" -vn "${out_file}" -y > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully converted to M4A.${NC}"
  else
    echo -e "${RED}Error during conversion!${NC}"
    exit 1
  fi
}

function combine {
  local file_order=$1
  local final_m4a_file=$2

  echo -e "\n${BLUE}Combining all chapters into a single M4A file...${NC}"

  ${FFMPEG} -f concat -safe 0 -i "${file_order}" -c copy "${final_m4a_file}" -y > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully combined into final M4A file.${NC}"
  else
    echo -e "${RED}Error during file concatenation!${NC}"
    exit 1
  fi
}

function add_chapters {
  local temp_dir=$1
  local final_m4a_file=$2

  echo -e "\n${BLUE}Adding chapters to the final M4A file...${NC}"

  (cd "${temp_dir}" && ${MP4CHAPS} -i "${final_m4a_file}" > /dev/null 2>&1)

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Chapters successfully added.${NC}"
  else
    echo -e "${RED}Error adding chapters!${NC}"
    exit 1
  fi
}

function process_file_as_chapter {
  local temp_dir=$1
  local input_dir=$2
  local quality=$3
  local file_order=$4
  local file_chapter=$5

  local i=1
  local current_time=0
  local audio_files=($(find "${input_dir}" -type f \
    \( -name '*.mp3' \
    -o -name '*.wav' \
    -o -name '*.flac' \
    -o -name '*.aac' \
    -o -name '*.ogg' \
    -o -name '*.m4a' \
    -o -name '*.wma' \) | sort))

  echo -e "${YELLOW}Processing files...${NC}\n"
  for file in "${audio_files[@]}"; do
    if [[ ! -f "${file}" ]]; then
      continue
    fi

    chapter_name=$( get_chapter_name "${file}" )
    echo -e "${GREEN}Processing chapter:${NC} ${chapter_name}"

    output_m4a="${temp_dir}/$(basename "${file}" .${file##*.}).m4a"
    echo "file '${output_m4a}'" >> "${file_order}"

    convert "${file}" "${output_m4a}" "${quality}"

    duration=$( ${FFPROBE} -v quiet -show_entries format=duration "${output_m4a}" -of csv="p=0" )
    timestamp=$(date -ud "@${current_time}" +'%H:%M:%S.%3N')

    echo "CHAPTER${i}=${timestamp}" >> "${file_chapter}"
    echo "CHAPTER${i}NAME=${chapter_name}" >> "${file_chapter}"

    current_time=$(echo "${current_time} + ${duration}" | bc)
    i=$((i + 1))

    echo -e "${YELLOW}Added chapter: '${chapter_name}' at ${timestamp}.${NC}"
    echo -e "-----------------------------------------"
  done
}

function process_dirs_as_chapter {
  echo "TBD"
}

# Check for --directories-as-chapters in arguments
USE_DIRECTORIES_AS_CHAPTERS=false
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --directories-as-chapters) USE_DIRECTORIES_AS_CHAPTERS=true; shift ;;
    *) break ;;
  esac
done

# Required positional argument: audiobook directory
if [[ "$#" -lt 1 ]]; then
  echo -e "\n${RED}Error: Input directory is required.${NC}"
  echo -e "Usage: $0 [--directories-as-chapters] /path/to/audiobook_directory <audio_quality>\n"
  exit 1
fi

if [[ "$#" -lt 1 ]]; then
  echo -e "\n${RED}Error: Input directory is required.${NC}"
  echo -e "Usage: $0 /path/to/audiobook_directory <audio_quality>\n"
  exit 1
fi

if [[ -z "${FFMPEG}" || -z "${FFPROBE}" || -z "${MP4CHAPS}" ]]; then
  echo -e "${RED}Missing required binaries: ffmpeg, ffprobe, mp4chaps.${NC}"
  exit 1
fi

readonly INPUT_DIR="$(realpath "$1")"
readonly AUDIO_QUALITY="${2:-128k}"

if [[ ! -d "${INPUT_DIR}" ]]; then
  echo -e "\n${RED}Error: Input directory does not exist.${NC}"
  exit 1
fi

readonly OUTPUT_FILE="$(dirname "${INPUT_DIR}")/$(basename "${INPUT_DIR}").m4b"

readonly TEMP_DIR=$(mktemp -d)
readonly FINAL_M4A_FILE="${TEMP_DIR}/${FINAL_M4A_FILENAME}"
readonly FILE_CHAPTER="${TEMP_DIR}/${CHAPTER_FILENAME}"
readonly FILE_ORDER="${TEMP_DIR}/${FILE_ORDER_FILENAME}"

trap 'rm -rf "${TEMP_DIR}"' EXIT

> "${FILE_CHAPTER}"
> "${FILE_ORDER}"

echo -e "\n${BLUE}Starting the audiobook creation process...${NC}"
echo -e "${BLUE}Input directory:${NC} ${INPUT_DIR}"
echo -e "${BLUE}Output file will be saved to:${NC} ${OUTPUT_FILE}"
echo -e "${BLUE}Use directories as chapters:${NC} ${USE_DIRECTORIES_AS_CHAPTERS}"
echo -e "${BLUE}Audio quality set to:${NC} ${AUDIO_QUALITY}\n"
echo -e "-----------------------------------------\n"

if ${USE_DIRECTORIES_AS_CHAPTERS}; then
  process_dirs_as_chapter "${TEMP_DIR}" "${INPUT_DIR}" "${AUDIO_QUALITY}" "${FILE_ORDER}" "${FILE_CHAPTER}"
else
  process_file_as_chapter "${TEMP_DIR}" "${INPUT_DIR}" "${AUDIO_QUALITY}" "${FILE_ORDER}" "${FILE_CHAPTER}"
fi

combine "${FILE_ORDER}" "${FINAL_M4A_FILE}" 
add_chapters "${TEMP_DIR}" "${FINAL_M4A_FILE}"

echo -e "\n${BLUE}Renaming final M4A file to M4B...${NC}"
mv "${FINAL_M4A_FILE}" "${OUTPUT_FILE}"

echo -e "\n${GREEN}Audiobook creation complete!${NC}"
echo -e "${BLUE}Final M4B file saved to:${NC} ${OUTPUT_FILE}"
echo -e "-----------------------------------------\n"