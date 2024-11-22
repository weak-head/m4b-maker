#!/bin/bash

ARGS=()
WORKERS=5

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --workers) WORKERS="$2"; shift 2 ;;
    --) shift; ARGS=("$@"); break ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

DIRECTORY=$(realpath "${ARGS[-1]}")
unset 'ARGS[-1]'

echo "Workers: ${WORKERS}"
echo "Arguments: ${ARGS[@]}"
echo "Directory: ${DIRECTORY}"

readonly TEMP_QUEUE_FILE=$(mktemp)
readonly TEMP_LOCK_FILE=$(mktemp)
trap 'rm -f "${TEMP_QUEUE_FILE}" "${TEMP_LOCK_FILE}"' EXIT

# Discover books and initialize the queue with the list of directories
find "${DIRECTORY}" -mindepth 1 -maxdepth 1 -type d > "${TEMP_QUEUE_FILE}"

function get_next_directory {
  local queue=$1 
  local lock=$2
  {
    flock -x 200
    local item=$(head -n 1 "${queue}")

    if [[ -n $item ]]; then
      sed -i '1d' "${queue}"
    fi

    echo "${item}"
  } 200>>"${lock}"
}

function worker {
  local worker_id=$1 
  local queue=$2 
  local lock=$3
  shift 3
  local args=("$@") 

  while true; do
    local directory=$(get_next_directory "${queue}" "${lock}")

    if [[ -z $directory ]]; then
      echo "Worker ${worker_id}: No more items to process. Exiting."
      break
    fi

    #echo "Worker ${worker_id}: Processing '${directory}'"
    echo "m4bify ${args[@]} '${directory}'"

    # Simulate work
    sleep $((RANDOM % 3 + 1))

  done
}

for ((i = 0; i < WORKERS; i++)); do
  worker "${i}" "${TEMP_QUEUE_FILE}" "${TEMP_LOCK_FILE}" "${ARGS[@]}" &
done

wait

echo "All tasks completed."
