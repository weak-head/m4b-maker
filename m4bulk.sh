#!/bin/bash

input_dir=""
workers=5

queue_file=$(mktemp)
lock_file=$(mktemp)
trap 'rm -f "${queue_file}" "${lock_file}"' EXIT

# Initialize the queue file with the list of directories
find "${input_dir}" -mindepth 1 -maxdepth 1 -type d > "${queue_file}"

function get_next_item {
  local item
  {
    flock -x 200
    item=$(head -n 1 "${queue_file}")

    # Remove the first line from the queue
    if [[ -n $item ]]; then
      tail -n +2 "${queue_file}" > "${queue_file}.tmp" 
      mv "${queue_file}.tmp" "${queue_file}"
    fi

    echo "${item}"
  } 200>>"${lock_file}"
}

function worker {
  local worker_id=$1
  while true; do
    local item
    item=$(get_next_item)

    if [[ -z $item ]]; then
      echo "Worker ${worker_id}: No more items to process. Exiting."
      break
    fi

    # Process the item
    echo "Worker ${worker_id}: Processing '${item}'"

    # Simulate work
    sleep $((RANDOM % 3 + 1))
  done
}

# Start workers
for ((i = 0; i < workers; i++)); do
  worker "${i}" &
done

wait

echo "All tasks completed."
