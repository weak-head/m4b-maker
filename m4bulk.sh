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

# Strip ANSI escape codes
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
  local id=$1 queue=$2 lock=$3; success=$4; failure=$5; shift 5
  local args=("$@") 

  while true; do
    local directory=$(next_directory "${queue}" "${lock}")
    local log_file="${directory}.log"

    # No more items to process, this worker can exit
    if [[ -z $directory ]]; then
      break
    fi

    echo -e "${BLUE}Processing:${NC} ${directory}"

    # Create the M4B book using m4bify, capturing the output 
    # to the log file and stripping the color codes
    ${M4BIFY} "${args[@]}" "${directory}" 2>&1 \
      | stdbuf -oL sed -r "${REGEX_STRIP_ANSI_EC}" > "${log_file}"

    # Exit status of the first command (m4bify)
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
      echo -e "${GREEN}✔ Completed:${NC} ${directory}"
      echo "${directory}" >> "${success}"
    else
      echo -e "${RED}✘ Error: ${directory}${NC}"
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

if ! [[ "${WORKERS}" =~ ^[0-9]+$ ]] || ((WORKERS < 1)) || ((WORKERS > $(nproc))); then
  echo -e "\n${RED}Error: Invalid number of workers '${WORKERS}'. Must be an integer between 1 and $(nproc).${NC}"
  exit 1
fi

echo -e "\n${GREEN}Starting audiobooks conversion...${NC}"
echo -e "-----------------------------------------"
echo -e "${BLUE}Workers:${NC} ${WORKERS}"
echo -e "${BLUE}Arguments:${NC} ${ARGS[@]}"
echo -e "${BLUE}Source Directory:${NC} ${DIRECTORY}"
echo -e "-----------------------------------------\n"

readonly TEMP_QUEUE_FILE=$(mktemp)
readonly TEMP_LOCK_FILE=$(mktemp)
readonly TEMP_INFO_SUCCESS_FILE=$(mktemp)
readonly TEMP_INFO_ERROR_FILE=$(mktemp)

> "${TEMP_INFO_SUCCESS_FILE}"
> "${TEMP_INFO_ERROR_FILE}"

trap 'rm -f "${TEMP_QUEUE_FILE}" "${TEMP_LOCK_FILE}" "${TEMP_INFO_SUCCESS_FILE}" "${TEMP_INFO_ERROR_FILE}"' EXIT

# Discover books and initialize the queue with the list of directories
find "${DIRECTORY}" -mindepth 1 -maxdepth 1 -type d > "${TEMP_QUEUE_FILE}"

echo -e "${GREEN}Discovering audiobooks...${NC}"
echo -e "-----------------------------------------"

while IFS= read -r directory; do
  echo -e "${BLUE}Discovered:${NC} ${directory}"
done < "${TEMP_QUEUE_FILE}"

echo -e "\n${BLUE}Total:${NC} $(awk 'END {print NR}' "${TEMP_QUEUE_FILE}")"
echo -e "-----------------------------------------\n"
echo -e "${GREEN}Converting audiobooks...${NC}"
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
echo -e "${YELLOW}Processing finished. Summary:${NC}"
echo -e "-----------------------------------------"
echo -e "${BLUE}Elapsed:${NC} ${INFO_TOTAL_ELAPSED}"
echo -e "${BLUE}Successfully converted:${NC} ${GREEN}${INFO_SUCCESS_COUNT}${NC}"

while IFS= read -r directory; do
  echo -e "  ${GREEN}✔${NC} ${directory}"
done < "${TEMP_INFO_SUCCESS_FILE}"

if [[ "${INFO_ERROR_COUNT}" != "0" ]]; then
  echo -e "${BLUE}Failed to convert:${NC} ${RED}${INFO_ERROR_COUNT}${NC}"
  while IFS= read -r directory; do
    echo -e "  ${RED}✘${NC} ${directory}"
  done < "${TEMP_INFO_ERROR_FILE}"
fi

echo -e "-----------------------------------------\n"