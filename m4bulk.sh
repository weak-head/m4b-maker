#!/bin/bash

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

# Regex to strip ANSI escape codes
readonly REGEX_STRIP_ANSI_EC="s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"

readonly M4BIFY=$(command -v m4bify)

function print_usage {
  echo "TBD"
}

function next_directory {
  local queue=$1 lock=$2
  {
    flock -x 200 
    local directory=$(head -n 1 "${queue}")

    # If a directory is retrieved, remove it from the queue    
    if [[ -n $directory ]]; then
      sed -i '1d' "${queue}"
    fi

    echo "${directory}"
  } 200>>"${lock}"
}

function worker {
  local id=$1 queue=$2 lock=$3; shift 3
  local args=("$@") 

  while true; do
    local directory=$(next_directory "${queue}" "${lock}")
    local log_file="${directory}.log"

    # No more items to process, this worker can exit
    if [[ -z $directory ]]; then
      break
    fi

    echo -e "${BLUE}Processing '${directory}'...${NC}"

    # Create the M4B book using m4bify, capturing the output 
    # to the log file and stripping the color codes
    ${M4BIFY} "${args[@]}" "${directory}" 2>&1 \
      | stdbuf -oL sed -r "${REGEX_STRIP_ANSI_EC}" > "${log_file}"

    # Exit status of the first command (m4bify)
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
      echo -e "${GREEN}✔ Audiobook successfully created '${directory}'.${NC}"
    else
      echo -e "${RED}✘ Error creating audiobook '${directory}'${NC}"
    fi
  done
}

ARGS=()   # Default is nothing
WORKERS=8 # Default is 8 workers

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
  echo -e "\n${RED}Error: Input directory is required.${NC}"
  print_usage
  exit 1
fi

if [[ -z "${M4BIFY}" ]]; then
  echo -e "${RED}Missing required binaries: m4bify.${NC}"
  exit 1
fi

DIRECTORY=$(realpath "${ARGS[-1]}")
unset 'ARGS[-1]'

if [[ ! -d "${DIRECTORY}" ]]; then
  echo -e "\n${RED}Error: Input directory does not exist.${NC}"
  exit 1
fi

echo "Workers: ${WORKERS}"
echo "Arguments: ${ARGS[@]}"
echo "Directory: ${DIRECTORY}"

readonly TEMP_QUEUE_FILE=$(mktemp)
readonly TEMP_LOCK_FILE=$(mktemp)
trap 'rm -f "${TEMP_QUEUE_FILE}" "${TEMP_LOCK_FILE}"' EXIT

# Discover books and initialize the queue with the list of directories
find "${DIRECTORY}" -mindepth 1 -maxdepth 1 -type d > "${TEMP_QUEUE_FILE}"

for ((i = 0; i < WORKERS; i++)); do
  worker "${i}" "${TEMP_QUEUE_FILE}" "${TEMP_LOCK_FILE}" "${ARGS[@]}" &
done

wait

echo "All tasks completed."
