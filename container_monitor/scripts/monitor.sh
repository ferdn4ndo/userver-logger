#!/bin/bash

echo "Starting docker container monitor"

# Common functions
. /opt/monitor/scripts/functions.sh --source-only

# Main loop
while true; do
    # Clone nginx logs
    clone_nginx_logs

    # Loop through all containers to fetch their logs
    fetch_containers_logs

    # Check for too big log files
    check_big_container_log_files

    # Check for running containers list changes
    check_containers_list_changes

    # Chown log files as non-root to allow local access by other apps
    chown -R 1000:1000 "${LOGS_FOLDER}"

    # Update last timestamp to file
    write_last_timestamp

    # Sleep for the configured interval before running again
    sleep "${LOOP_WAIT_INTERVAL:-5s}"
done
