#!/bin/bash

set -x

LOG=/var/log/demo.log

[ ! -f "$LOG" ] &&  touch $LOG


for i in {1..100}; do 
	su root -c 'echo Some kernel message for demo > /dev/kmsg'
	sleep 1
done
