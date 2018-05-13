#!/bin/bash

function finish {
	# Your cleanup code here
	echo "Worked"
}
trap finish EXIT SIGINT SIGTERM

read -t 10