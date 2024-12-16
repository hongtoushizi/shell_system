#!/bin/bash

threshold=80
logfile="disk_usage_alert.log"

df -h | awk  'NR>1 {print $5 " " $6}'  |  while  read  output;  do
   usep=$(echo  $output  | awk  '{print $1}'  | sed  's/%//g')
   partition=$(echo  $output  | awk  '{print $2}')
    if  [[  $usep  -ge  $threshold  ]];  then
       echo  "$(date): Partition  $partition  is at  ${usep}% usage."  | tee -a  "$logfile"
    fi
done