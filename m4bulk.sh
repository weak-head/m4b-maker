#!/usr/bin/env bash
# This script automates the batch conversion of audiobook directories to M4B format using `m4bify`, 
# with support for parallel processing to maximize efficiency on multi-core systems. 
# It simplifies the conversion process, ensures task distribution across worker threads, 
# and provides detailed logging for troubleshooting and review.
#
# Key Features:
# - Automatically identifies audiobook directories within a specified root directory for batch processing.
# - Allows configuration of worker threads for parallel processing, optimizing resource usage.
# - Passes custom options directly to `m4bify`, enabling flexibility in bitrate, chapter generation, and more.
# - Creates detailed logs for each audiobook conversion, highlighting successes and errors.
# - Summarizes the results at the end of the process, including elapsed time, success counts, and failures.
#
# Usage Instructions:
#   $> m4bulk [--workers <N>] [m4bify-options] <audiobooks_directory>
#
# Parameters:
#   --workers <N>           - (Optional) Number of worker threads to use. Defaults to 50% of CPU cores.
#                             Must be an integer between 1 and the total number of available cores.
#   [m4bify-options]        - Additional arguments supported by `m4bify`, passed directly (e.g., bitrate, chapters).
#   <audiobooks_directory>  - The top-level directory containing audiobook subdirectories to process.
#
# Examples:
#   $> m4bulk /home/user/audiobooks/
#      Converts all subdirectories in "/home/user/audiobooks/" using default settings and 50% of CPU cores.
#
#   $> m4bulk --workers 4 --chapters-from-dirs --bitrate 128k /home/user/audiobooks/
#      Converts audiobook directories in "/home/user/audiobooks/" with 4 worker threads, 
#      each subdirectory treated as a chapter and audio set to 128 kbps bitrate.
#
# Workflow:
# 1. Scans the specified root directory for audiobook subdirectories to convert.
# 2. Initializes a task queue and assigns tasks across worker threads for efficient parallel processing.
# 3. Logs conversion results, capturing outputs and errors for each audiobook directory.
# 4. Summarizes the entire conversion process, including elapsed time and counts of successes and failures.
#
# Dependencies:
# - `m4bify`: The primary tool for audiobook conversion (must be installed and accessible in the system's PATH).
# - Required tools for `m4bify`:
#     - `ffmpeg`    - For audio encoding and format conversion.
#     - `ffprobe`   - To analyze audio file properties.
#     - `mp4chaps`  - To manage chapter metadata in M4B files.
#
# Notes:
# - Ensure all dependencies are installed and available before running this script.
# - Logs for each audiobook conversion will be saved in the same directory as the source audiobooks.
# - Customize worker threads and m4bify options to optimize for system resources and project requirements.

readonly VERSION="v0.3.4"

# Color schema for pretty print
readonly NC='\033[0m'           # No Color
declare -A COLORS=(
    # -- print usage
    [TITLE]='\033[0;36m'        # Cyan
    [TEXT]='\033[0;37m'         # White
    [CMD]='\033[0;34m'          # Blue
    [ARGS]='\033[0;35m'         # Magenta
    # -- conversion log
    [SECTION]='\033[1;32m'      # Green (bold)
    [DISCOVER]='\033[0;35m🔍 '     # Magenta
    [ACTION]='\033[0;34m⏳ '    # Blue
    [RESULT]='\033[0;36m📄 '    # Cyan
    # -- message severity
    [INFO]='\033[0;36mℹ️ '       # Cyan
    [WARN]='\033[0;33m⚡ '      # Yellow
    [ERROR]='\033[0;31m❌ '     # Red
    [SUCCESS]='\033[0;32m✅ '   # Green
)

# Strip ANSI escape codes
readonly REGEX_STRIP_ANSI_EC="s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"

M4BIFY=$(command -v m4bify)
readonly M4BIFY

function print_usage {
  echo -e "${COLORS[TITLE]}$(basename "$0")${NC} ${COLORS[TEXT]}${VERSION}${NC}"
  echo -e ""
  echo -e "${COLORS[TITLE]}Usage:${NC}"
  echo -e "  ${COLORS[CMD]}$(basename "$0")${NC} ${COLORS[ARGS]}[options] [m4bify-options] <audiobooks_directory>${NC}"
  echo -e ""
  echo -e "${COLORS[TITLE]}Options:${NC}"
  echo -e "  ${COLORS[ARGS]}--workers <N>${NC}           Number of worker threads (default: 50% of CPU cores)."
  echo -e "                          Must be an integer between 1 and the total available CPU cores."
  echo -e "  ${COLORS[ARGS]}--help${NC}                  Display this help message and exit."
  echo -e ""
  echo -e "${COLORS[TITLE]}Arguments:${NC}"
  echo -e "  ${COLORS[ARGS]}[m4bify-options]${NC}        Optional arguments passed directly to ${COLORS[CMD]}m4bify${NC}."
  echo -e "                          Examples include ${COLORS[ARGS]}--bitrate <rate>${NC} or ${COLORS[ARGS]}--chapters-from-dirs${NC}."
  echo -e "  ${COLORS[ARGS]}<audiobooks_directory>${NC}  The root directory containing subdirectories of audiobooks to convert."
  echo -e ""
  echo -e "${COLORS[TITLE]}Examples:${NC}"
  echo -e "  ${COLORS[CMD]}$(basename "$0")${NC} ${COLORS[ARGS]}/path/to/audiobooks${NC}"
  echo -e "      Converts all subdirectories in the \"audiobooks\" directory into M4B files."
  echo -e "      The script automatically determines the optimal number of worker threads (default is 50% of available CPU cores)."
  echo -e "      Files are processed with default settings, and no additional encoding options are applied."
  echo -e ""
  echo -e "  ${COLORS[CMD]}$(basename "$0")${NC} ${COLORS[ARGS]}--workers 4 --bitrate 128k --chapters-from-dirs /path/to/audiobooks${NC}"
  echo -e "      Processes all audiobook subdirectories in \"audiobooks\" using 4 worker threads."
  echo -e "      Files are encoded at a bitrate of 128 kbps. Additionally, the script treats each top-level subdirectory as a chapter,"
  echo -e "      and chapters are extracted based on the folder structure."
  echo -e ""
  echo -e "${COLORS[TITLE]}Description:${NC}"
  echo -e "  This script automates the batch conversion of audiobook directories into M4B format using ${COLORS[CMD]}m4bify${NC}."
  echo -e "  It supports parallel processing, custom configurations, and detailed logging for efficient and reliable execution."
  echo -e ""
  echo -e "${COLORS[TITLE]}Workflow:${NC}"
  echo -e "  1. Scans the specified root directory for audiobook subdirectories."
  echo -e "  2. Queues directories for processing and assigns tasks to worker threads in parallel."
  echo -e "  3. Logs conversion outputs for each audiobook directory to help identify successes or errors."
  echo -e "  4. Summarizes the overall process, including elapsed time, success counts, and any failures."
  echo -e ""
  echo -e "${COLORS[TITLE]}Logging:${NC}"
  echo -e "  Logs are saved alongside each audiobook directory, detailing success or failure."
  echo -e "  A summary log provides a quick overview of the batch processing results."
  echo -e ""
  echo -e "${COLORS[TITLE]}Dependencies:${NC}"
  echo -e "  This script depends on ${COLORS[CMD]}m4bify${NC}, which must be installed and accessible in your PATH."
  echo -e "  ${COLORS[CMD]}m4bify${NC} has the following indirect dependencies:"
  echo -e "    - ${COLORS[CMD]}ffmpeg${NC}: For audio encoding and format conversion."
  echo -e "    - ${COLORS[CMD]}ffprobe${NC}: To analyze audio file properties."
  echo -e "    - ${COLORS[CMD]}mp4chaps${NC}: For chapter metadata manipulation in M4B files."
  echo -e ""
  echo -e "${COLORS[TITLE]}Notes:${NC}"
  echo -e "  - Ensure all dependencies are installed and accessible in the system's PATH."
  echo -e "  - Logs are created in the same directory as the processed audiobooks."
  echo -e "  - Customize the number of workers and ${COLORS[CMD]}m4bify${NC} options to suit your hardware and project requirements."
  echo -e ""
}

function next_directory {
  local queue=$1 lock=$2
  local directory
  {
    flock -x 200 
    directory=$(head -n 1 "${queue}")

    # If a directory is retrieved, remove it from the queue    
    if [[ -n $directory ]]; then
      sed -i '1d' "${queue}"
    fi

    echo "${directory}"
  } 200>>"${lock}"
}

function worker {
  local queue=$2 lock=$3; success=$4; failure=$5; shift 5
  local args=("$@") 
  local directory log_file

  while true; do
    directory=$(next_directory "${queue}" "${lock}")
    log_file="${directory}.log"

    # No more items to process, this worker can exit
    if [[ -z $directory ]]; then
      break
    fi

    echo -e "${COLORS[ACTION]}Processing:${NC} ${directory}"

    # Create the M4B book using m4bify, capturing the output 
    # to the log file and stripping the color codes
    ${M4BIFY} "${args[@]}" "${directory}" 2>&1 \
      | stdbuf -oL sed -r "${REGEX_STRIP_ANSI_EC}" > "${log_file}"

    # Exit status of the first command (m4bify)
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
      echo -e "${COLORS[SUCCESS]}Completed:${NC} ${directory}"
      echo "${directory}" >> "${success}"
    else
      echo -e "${COLORS[ERROR]}Error:${NC} ${directory}"
      echo "${directory}" >> "${failure}"
    fi
  done
}

ARGS=() # Default is nothing
WORKERS=$(( $(nproc) / 2 )) # Default is 50% of CPU cores

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --workers) WORKERS="$2"; shift 2 ;;
    --help) print_usage; exit 0 ;;
    --) shift; ARGS=("$@"); break ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

# Required at least one argument: audiobook directory
if [[ ${#ARGS[@]} -eq 0 ]]; then
  echo -e "\n${COLORS[ERROR]}Error: Input directory is required.${NC}\n"
  print_usage
  exit 1
fi

if [[ -z "${M4BIFY}" ]]; then
  echo -e "${COLORS[ERROR]}Missing required binaries: m4bify.${NC}"
  exit 1
fi

DIRECTORY=$(realpath "${ARGS[-1]}")
unset 'ARGS[-1]'

if [[ ! -d "${DIRECTORY}" ]]; then
  echo -e "\n${COLORS[ERROR]}Error: Input directory does not exist.${NC}"
  exit 1
fi

if ! [[ "${WORKERS}" =~ ^[0-9]+$ ]] || ((WORKERS < 1)) || ((WORKERS > $(nproc))); then
  echo -e "\n${COLORS[ERROR]}Error: Invalid number of workers '${WORKERS}'. Must be an integer between 1 and $(nproc).${NC}"
  exit 1
fi

echo -e "\n${COLORS[SECTION]}Preparing conversion...${NC}"
echo -e "-----------------------------------------"
echo -e "${COLORS[INFO]}Workers:${NC} ${WORKERS}"
echo -e "${COLORS[INFO]}Arguments:${NC} ${ARGS[*]}"
echo -e "${COLORS[INFO]}Source Directory:${NC} ${DIRECTORY}"
echo -e "-----------------------------------------\n"

TEMP_QUEUE_FILE=$(mktemp)
TEMP_LOCK_FILE=$(mktemp)
TEMP_INFO_SUCCESS_FILE=$(mktemp)
TEMP_INFO_ERROR_FILE=$(mktemp)
readonly TEMP_QUEUE_FILE TEMP_LOCK_FILE TEMP_INFO_SUCCESS_FILE TEMP_INFO_ERROR_FILE

touch "${TEMP_INFO_SUCCESS_FILE}"
touch "${TEMP_INFO_ERROR_FILE}"

trap 'rm -f "${TEMP_QUEUE_FILE}" "${TEMP_LOCK_FILE}" "${TEMP_INFO_SUCCESS_FILE}" "${TEMP_INFO_ERROR_FILE}"' EXIT

# Discover books and initialize the queue with the list of directories
find "${DIRECTORY}" -mindepth 1 -maxdepth 1 -type d > "${TEMP_QUEUE_FILE}"

echo -e "${COLORS[SECTION]}Discovering audiobooks...${NC}"
echo -e "-----------------------------------------"

while IFS= read -r directory; do
  echo -e "${COLORS[DISCOVER]}Discovered:${NC} ${directory}"
done < "${TEMP_QUEUE_FILE}"

echo -e "\n${COLORS[INFO]}Total:${NC} $(awk 'END {print NR}' "${TEMP_QUEUE_FILE}")"
echo -e "-----------------------------------------\n"
echo -e "${COLORS[SECTION]}Converting audiobooks...${NC}"
echo -e "-----------------------------------------"

for ((i = 0; i < WORKERS; i++)); do
  worker "${i}" \
    "${TEMP_QUEUE_FILE}" "${TEMP_LOCK_FILE}" \
    "${TEMP_INFO_SUCCESS_FILE}" "${TEMP_INFO_ERROR_FILE}" \
    "${ARGS[@]}" &
done

wait

INFO_SUCCESS_COUNT=$(wc -l < "${TEMP_INFO_SUCCESS_FILE}")
INFO_ERROR_COUNT=$(wc -l < "${TEMP_INFO_ERROR_FILE}")

if (( SECONDS >= 3600 )); then
  INFO_TOTAL_ELAPSED=$(printf "%02d hours, %02d minutes, %02d seconds\n" \
    $((SECONDS / 3600)) \
    $((SECONDS % 3600 / 60)) \
    $((SECONDS % 60)))
else
  INFO_TOTAL_ELAPSED=$(printf "%02d minutes, %02d seconds\n" \
    $((SECONDS / 60)) \
    $((SECONDS % 60)))
fi

echo -e "-----------------------------------------\n"
echo -e "${COLORS[SUCCESS]}Audiobooks processing finished!${NC}"
echo -e "-----------------------------------------"
echo -e "${COLORS[INFO]}Elapsed:${NC} ${INFO_TOTAL_ELAPSED}"
echo -e "${COLORS[INFO]}Successfully converted:${NC} ${COLORS[SUCCESS]}${INFO_SUCCESS_COUNT}${NC}"

while IFS= read -r directory; do
  echo -e "  ${COLORS[SUCCESS]}${NC}${directory}"
done < "${TEMP_INFO_SUCCESS_FILE}"

if [[ "${INFO_ERROR_COUNT}" != "0" ]]; then
  echo -e "${COLORS[INFO]}Failed to convert:${NC} ${COLORS[ERROR]}${INFO_ERROR_COUNT}${NC}"
  while IFS= read -r directory; do
    echo -e "  ${COLORS[ERROR]}${NC}${directory}"
  done < "${TEMP_INFO_ERROR_FILE}"
fi

echo -e "-----------------------------------------\n"
