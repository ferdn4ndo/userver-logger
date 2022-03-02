#!/bin/bash

echo "Starting docker container monitor"

# Env variables and default values
DATA_FOLDER="${DATA_FOLDER:-/monitor/data}"
LAST_TIMESTAMP_FILENAME=${LAST_TIMESTAMP_FILENAME:-last_timestamp.txt}
PREVIOUS_CONTAINERS_FILENAME=${PREVIOUS_CONTAINERS_FILENAME:-previous_containers.txt}
CURRENT_CONTAINERS_FILENAME=${CURRENT_CONTAINERS_FILENAME:-current_containers.txt}
LOGS_FOLDER="${LOGS_FOLDER:-/monitor/logs}"
LOG_FILES_PREFIX="${LOG_FILES_PREFIX:-container_monitor_}"
MONITOR_LOG_FILENAME="${MONITOR_LOG_FILENAME:-userver-container-monitor.log}"
MAX_LOG_SIZE="${MAX_LOG_SIZE:-1048576}"

# Computed vars
monitor_log_file="${LOGS_FOLDER}/${MONITOR_LOG_FILENAME}"
last_timestamp_file="${DATA_FOLDER}/${LAST_TIMESTAMP_FILENAME}"
previous_containers_file="${DATA_FOLDER}/${PREVIOUS_CONTAINERS_FILENAME}"
current_containers_file="${DATA_FOLDER}/${CURRENT_CONTAINERS_FILENAME}"

# Check for last timestamp to start the monitoring
last_timestamp_command=""
if [ -f "${last_timestamp_file}" ]; then
    last_timestamp="$(cat "${last_timestamp_file}")"
    echo "Last timestamp found (${last_timestamp})!"
    last_timestamp_command="--since=${last_timestamp}"
fi

# Main loop
while true; do
    # Write current timestamp to file
    current_timestamp=$(date -I'seconds')
    echo "${current_timestamp}" > "${last_timestamp_file}"

    # Get all running docker container names
    container_names=$(docker ps | awk '{if(NR>1) print $NF}')

    # Check for too big log files
    shopt -s nullglob
    for log_file in "${LOGS_FOLDER}"/*.log; do
        log_file_size=$(stat -c%s "${log_file}")
        if [ "${log_file_size}" -ge "${MAX_LOG_SIZE}" ]; then
            echo "Log file ${log_file} is bigger than ${MAX_LOG_SIZE} bytes and will be truncated"
            : > "${log_file}"
        fi
    done

    # Loop through all containers
    for container_name in ${container_names}; do
        # Check if container must be skipped
        if echo "${EXCLUDED_CONTAINER_NAMES}" | grep -q "${container_name}"
        then
            continue
        fi

        # Save container logs
        docker_output="$(docker logs "$last_timestamp_command" "${container_name}" 2> /dev/null)"
        if [ -n "$docker_output" ]; then
            container_log_file="${LOGS_FOLDER}/${LOG_FILES_PREFIX}${container_name}.log"
            echo "$docker_output" > "${container_log_file}"
            echo "Saved new log output from container ${container_name} to ${container_log_file}"
        fi
    done

    # Check for running containers list changes
    echo "$container_names" > "${current_containers_file}"
    if [ ! -f "${previous_containers_file}" ]; then
        touch "${previous_containers_file}"
    fi
    containers_stopped="$(comm -23 "${previous_containers_file}" "${current_containers_file}")"
    if [ -n "${containers_stopped}" ]; then
        message="The following containers were stopped since last checking: ${containers_stopped//$'\n'/ }"
        echo "$message"
        echo "[WARNING] ${message}" >> "${monitor_log_file}"
    fi
    containers_started="$(comm -13 "${previous_containers_file}" "${current_containers_file}")"
    if [ -n "${containers_started}" ]; then
        message="The following containers were started since last checking: ${containers_started//$'\n'/ }"
        echo "$message"
        echo "[WARNING] ${message}" >> "${monitor_log_file}"
    fi
    echo "${container_names}" > "${previous_containers_file}"

    # Chown log files as non-root to allow local access by other apps
    chown -R 1000:1000 "${LOGS_FOLDER}"

    # Update last timestamp and sleep
    last_timestamp_command="--since=${current_timestamp}"
    sleep "${LOOP_WAIT_INTERVAL:-5s}"
done
