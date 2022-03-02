#!/bin/bash

echo "Waiting 5 seconds before staring container monitor"
sleep 5s

echo "Starting docker container monitor"
/opt/monitor/scripts/monitor.sh
