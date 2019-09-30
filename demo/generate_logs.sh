#!/bin/bash

set -x

LOG=/var/log/demo.log

[ ! -f "$LOG" ] &&  touch $LOG


for i in {1..1000}; do 
	echo $(date +"%d.%m.%y")" "$(date +"%T") "Some logs for elk demo" >> $LOG
	sleep 1
done
