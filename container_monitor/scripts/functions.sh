#!/usr/bin/env bash

# read the env variables with their default values
LOOP_WAIT_INTERVAL="${LOOP_WAIT_INTERVAL:-5s}"
MAX_LOG_LINES="${MAX_LOG_LINES:-1000}"
EXCLUDED_CONTAINER_NAMES="${EXCLUDED_CONTAINER_NAMES:-userver-loki;userver-grafana;userver-promtail;userver-container-monitor}"
LOG_FILES_PREFIX="${LOG_FILES_PREFIX:-container_monitor_}"
DATA_FOLDER="${DATA_FOLDER:-/monitor/data}"
LOGS_FOLDER="${LOGS_FOLDER:-/monitor/logs}"
PREVIOUS_CONTAINERS_LIST_FILENAME="${PREVIOUS_CONTAINERS_LIST_FILENAME:-previous_containers_list.txt}"
CURRENT_CONTAINERS_LIST_FILENAME="${CURRENT_CONTAINERS_LIST_FILENAME:-current_containers_list.txt}"
PREVIOUS_TIMESTAMP_FILENAME="${PREVIOUS_TIMESTAMP_FILENAME:-last_timestamp.txt}"
MONITOR_LOG_FILENAME="${MONITOR_LOG_FILENAME:-userver-container-monitor.log}"
COPY_NGINX_LOGS="${COPY_NGINX_LOGS:-1}"
NGINX_CONTAINER_NAME="${NGINX_CONTAINER_NAME:-server-nginx-proxy}"
NGINX_CONTAINER_LOGS_FOLDER="${NGINX_CONTAINER_LOGS_FOLDER:-/var/log/nginx}"

function clone_nginx_logs {
    if [ "${COPY_NGINX_LOGS}" != "1" ]; then
        echo "Skipping nginx logs cloning as COPY_NGINX_LOGS is not enabled"
        return
    fi

    container_is_running="$(docker ps -a | grep "${NGINX_CONTAINER_NAME}")"

    if [ "${container_is_running}" == "" ]; then
        echo "The nginx container '${NGINX_CONTAINER_NAME}' is not running!"
        return
    fi

    current_access_log_file="${LOGS_FOLDER}"/nginx_access.log
    current_error_log_file="${LOGS_FOLDER}"/nginx_error.log

    temp_access_log_file="${DATA_FOLDER}"/nginx_access.tmp
    temp_error_log_file="${DATA_FOLDER}"/nginx_error.tmp

    docker cp "${NGINX_CONTAINER_NAME}":"${NGINX_CONTAINER_LOGS_FOLDER}"/access.log "${temp_access_log_file}"
    docker cp "${NGINX_CONTAINER_NAME}":"${NGINX_CONTAINER_LOGS_FOLDER}"/error.log "${temp_error_log_file}"

    if ! cmp "${current_access_log_file}" "${temp_access_log_file}" >/dev/null 2>&1; then
        echo "Saving new nginx access logs to ${current_access_log_file}"
        mv "${temp_access_log_file}" "${current_access_log_file}"
    else
        rm "${temp_access_log_file}"
    fi

    if ! cmp "${current_error_log_file}" "${temp_error_log_file}" >/dev/null 2>&1; then
        echo "Saving new nginx error logs to ${current_error_log_file}"
        mv "${temp_error_log_file}" "${current_error_log_file}"
    else
        rm "${temp_error_log_file}"
    fi
}

function truncate_log_file {
    # $1 = log file path
    log_file_path=$1

    echo "$(tail -n ${MAX_LOG_LINES} ${log_file_path})" > "${log_file_path}"
}

function check_big_container_log_files {
    shopt -s nullglob

    for log_file in "${LOGS_FOLDER}"/"${LOG_FILES_PREFIX}"*.log; do
        total_log_file_lines=$(wc -l < "${log_file}")
        if [ "${total_log_file_lines}" -gt "${MAX_LOG_LINES}" ]; then
            echo "Log file ${log_file} is has more than ${MAX_LOG_LINES} lines and will be truncated"
            truncate_log_file "${log_file}"
        fi
    done
}

function write_last_timestamp {
    last_timestamp_file="${DATA_FOLDER}/${PREVIOUS_TIMESTAMP_FILENAME}"
    current_timestamp=$(date -I'seconds')
    echo "${current_timestamp}" > "${last_timestamp_file}"
}

function get_last_timestamp_command {
    last_timestamp_file="${DATA_FOLDER}/${PREVIOUS_TIMESTAMP_FILENAME}"
    last_timestamp_command=""

    if [ -f "${last_timestamp_file}" ]; then
        last_timestamp="$(cat "${last_timestamp_file}")"
        last_timestamp_command="--since=${last_timestamp}"
    fi

    echo "${last_timestamp_command}"
}

function fetch_containers_logs {
    # Get all running docker container names
    container_names=$(docker ps | awk '{if(NR>1) print $NF}')

    # Loop through all containers
    for container_name in ${container_names}; do
        # Check if container must be skipped
        if echo "${EXCLUDED_CONTAINER_NAMES}" | grep -q "${container_name}"
        then
            continue
        fi

        # Save container logs
        last_timestamp_command=$(get_last_timestamp_command)
        docker_output="$(docker logs "$last_timestamp_command" "${container_name}" 2> /dev/null)"
        if [ -n "$docker_output" ]; then
            container_log_file="${LOGS_FOLDER}/${LOG_FILES_PREFIX}${container_name}.log"
            echo "$docker_output" > "${container_log_file}"
            echo "Saved new log output from container ${container_name} to ${container_log_file}"
        fi
    done
}

function check_containers_list_changes {
    monitor_log_file="${LOGS_FOLDER}/${MONITOR_LOG_FILENAME}"
    previous_containers_file="${DATA_FOLDER}/${PREVIOUS_CONTAINERS_LIST_FILENAME}"
    current_containers_file="${DATA_FOLDER}/${CURRENT_CONTAINERS_LIST_FILENAME}"

    # Get all running docker container names
    container_names=$(docker ps | awk '{if(NR>1) print $NF}')

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
}
