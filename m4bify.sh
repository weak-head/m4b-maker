#!/usr/bin/env bash
# This script automates the creation of an M4B audiobook from various audio formats (such as MP3, WAV, and FLAC).
# It supports file-based or directory-based chaptering, preserving structure by organizing chapters sequentially.
#
# Key Features:
# - Accepts an audiobook directory containing multiple audio files or subdirectories for custom chaptering.
# - Supports an optional bitrate selection for audio quality, defaulting to VBR Very High if not specified.
# - Preserves chapter information based on metadata, directory names, or filenames, organizing them in sequence.
# - Automatically names the output file based on the input directory name.
#
# Usage Instructions:
#   $> m4bify [--chapters-from-dirs] [--bitrate <value>] /path/to/audiobook_directory
#
# Parameters:
#   --chapters-from-dirs      - (Optional) Treats each directory as a separate chapter when specified.
#                               Files within each directory are combined into a single chapter.
#   --bitrate <value>         - (Optional) Desired audio bitrate for the output file, e.g., "128k" or "96k".
#                               Defaults to 'AAC VBR Very High' if not provided.
#   audiobook_directory       - Path to the directory containing audiobook files or subdirectories.
#
# Example Commands:
#   $> m4bify /home/user/audiobooks/my_book
#      Creates a single M4B audiobook file from all audio files in the "my_book" directory, using
#      the default audio quality and file-based chaptering.
#
#   $> m4bify --chapters-from-dirs --bitrate 96k /home/user/audiobooks/my_series
#      Treats each directory in "my_series" as a separate chapter, combining files within each
#      directory into one chapter in the final M4B file, using 96 kbps audio quality.


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

INFO_TOTAL_CHAPTERS=0
INFO_TOTAL_DURATION=""

function print_usage {
  echo -e "\n${BLUE}Usage:${NC} $0 [--chapters-from-dirs] [--bitrate <value>] /path/to/audiobook_directory"
  echo -e "\n${BLUE}Parameters:${NC}"
  echo -e "  --chapters-from-dirs      - (Optional) Treats each directory as a separate chapter when specified."
  echo -e "                               Files within each directory are combined into a single chapter."
  echo -e "  --bitrate <value>         - (Optional) Desired audio bitrate for the output file, e.g., \"128k\" or \"96k\"."
  echo -e "                               Defaults to the 'AAC VBR Very High' if not provided."
  echo -e "  audiobook_directory       - Path to the directory containing audiobook files or subdirectories."
  echo -e "\n${BLUE}Examples:${NC}"
  echo -e "  $0 /home/user/audiobooks/my_book"
  echo -e "      Creates a single M4B audiobook file from all audio files in the \"my_book\" directory,"
  echo -e "      using default audio quality and file-based chaptering."
  echo -e "\n  $0 --chapters-from-dirs --bitrate 96k /home/user/audiobooks/my_series"
  echo -e "      Treats each directory in \"my_series\" as a separate chapter, combining files within each"
  echo -e "      directory into one chapter in the final M4B file, using 96 kbps audio quality."
  echo -e "\n${BLUE}For more information, refer to the script comments.${NC}"
}

function get_chapter_name {
  local file=$1

  # Try to get chapter name from MP3 'title' tag.
  local chapter_name=$(${FFMPEG} -i "${file}" 2>&1 | grep -m 1 "title" | sed 's/.*title\s*:\s*//')

  # Fallback to base file name, with stripped invalid characters.
  if [ -z "${chapter_name}" ]; then
    chapter_name=$(basename "${file}" | sed 's/\.[^.]*$//' | sed 's/[<>:"/\\|?*]//g')
  fi

  echo "${chapter_name}"
}

function convert {
  local in_file=$1 out_file=$2 bitrate=$3

  if [[ "${bitrate}" == "vbr-very-high" ]]; then
    echo -e "${BLUE}Converting '${in_file}' to M4A (AAC VBR Very High)...${NC}"
    ${FFMPEG} -i "${in_file}" -c:a aac -q:a 1 -vn "${out_file}" -y > /dev/null 2>&1
  else
    echo -e "${BLUE}Converting '${in_file}' to M4A at bitrate ${bitrate}...${NC}"
    ${FFMPEG} -i "${in_file}" -c:a aac -b:a "${bitrate}" -vn "${out_file}" -y > /dev/null 2>&1
  fi

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✔ Successfully converted to M4A.${NC}"
  else
    echo -e "${RED}Error during conversion!${NC}"
    exit 1
  fi
}

function combine {
  local file_order=$1 m4a_file=$2

  echo -e "\n${BLUE}Combining all files into a single M4A file...${NC}"
  ${FFMPEG} -f concat -safe 0 -i "${file_order}" -c copy "${m4a_file}" -y > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✔ Successfully combined all files.${NC}"
  else
    echo -e "${RED}Error during file concatenation!${NC}"
    exit 1
  fi
}

function add_chapters {
  local temp_dir=$1 m4a_file=$2

  echo -e "\n${BLUE}Adding chapters to the M4A file...${NC}"
  (cd "${temp_dir}" && ${MP4CHAPS} -i "${m4a_file}" > /dev/null 2>&1)

  if [ $? -eq 0 ]; then
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

    output_m4a="${temp_dir}/$(basename "${file}" .${file##*.}).m4a"
    echo "file '${output_m4a}'" >> "${file_order}"

    convert "${file}" "${output_m4a}" "${bitrate}"

    timestamp=$(date -ud "@${current_time}" +'%H:%M:%S.%3N')
    echo "CHAPTER${i}=${timestamp}" >> "${file_chapter}"
    echo "CHAPTER${i}NAME=${chapter_name}" >> "${file_chapter}"

    duration=$( ${FFPROBE} -v quiet -show_entries format=duration "${output_m4a}" -of csv="p=0" )
    current_time=$(echo "${current_time} + ${duration}" | bc)
    i=$((i + 1))

    echo -e "${YELLOW}Added chapter: '${chapter_name}' at ${timestamp}.${NC}\n"
    echo -e "-----------------------------------------"
  done

  INFO_TOTAL_DURATION=$(date -ud "@${current_time}" +'%H hours, %M minutes')
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

    timestamp=$(date -ud "@${current_time}" +'%H:%M:%S.%3N')
    echo "CHAPTER${i}=${timestamp}" >> "${file_chapter}"
    echo "CHAPTER${i}NAME=${chapter_name}" >> "${file_chapter}"
     
    current_time=$(echo "${current_time} + ${chapter_duration}" | bc)
    i=$((i + 1))

    echo -e "${YELLOW}Added chapter: '${chapter_name}' at ${timestamp}.${NC}\n"
    echo -e "-----------------------------------------"
  done

  INFO_TOTAL_DURATION=$(date -ud "@${current_time}" +'%H hours, %M minutes')
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

if [[ -z "${FFMPEG}" || -z "${FFPROBE}" || -z "${MP4CHAPS}" ]]; then
  echo -e "${RED}Missing required binaries: ffmpeg, ffprobe, mp4chaps.${NC}"
  exit 1
fi

readonly INPUT_DIR="$(realpath "$1")"
readonly OUTPUT_FILE="$(dirname "${INPUT_DIR}")/$(basename "${INPUT_DIR}").m4b"

if [[ ! -d "${INPUT_DIR}" ]]; then
  echo -e "\n${RED}Error: Input directory does not exist.${NC}"
  exit 1
fi

readonly TEMP_DIR=$(mktemp -d)
readonly FINAL_M4A_FILE="${TEMP_DIR}/${FINAL_M4A_FILENAME}"
readonly FILE_CHAPTER="${TEMP_DIR}/${CHAPTER_FILENAME}"
readonly FILE_ORDER="${TEMP_DIR}/${FILE_ORDER_FILENAME}"

trap 'rm -rf "${TEMP_DIR}"' EXIT

> "${FILE_CHAPTER}"
> "${FILE_ORDER}"

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

echo -e "\n${BLUE}Renaming final M4A file to M4B...${NC}"
echo -e "-----------------------------------------\n"
mv "${FINAL_M4A_FILE}" "${OUTPUT_FILE}"

echo -e "${GREEN}✔ Audiobook creation complete!${NC}"
echo -e "-----------------------------------------"
echo -e "${BLUE}Total Chapters:${NC} ${INFO_TOTAL_CHAPTERS}"
echo -e "${BLUE}Total Duration:${NC} ${INFO_TOTAL_DURATION}"
echo -e "${BLUE}Audobook Saved To:${NC} ${OUTPUT_FILE}"
echo -e "-----------------------------------------\n"
