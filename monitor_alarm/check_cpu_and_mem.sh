#!/bin/bash

echo "Monitoring CPU and Memory Usage. Press Ctrl+C to stop."

while true; do
  cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
  mem=$(free -m | awk '/Mem:/ {print $3 "/" $2 " MB (" $3/$2*100 "%)"}')
  echo "$(date): CPU Usage: $cpu%, Memory Usage: $mem"
  sleep 2
done