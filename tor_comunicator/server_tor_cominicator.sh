#!/bin/bash

echo "Starting 'tor_comunicator' Server"

shutdown(){
	if (kill -TERM $nc_PID 2>/dev/null); then
		rm "$PID_file"
		rm "$netcat_PID_file"
	fi
	exit 0
}
trap shutdown EXIT SIGINT SIGTERM


var_set(){
	PID=$$
	default_folder=.
	PID_file=$default_folder/server_tc_PID.pid
	echo -n $PID > "$PID_file"
	netcat_PID_file=$default_folder/netcat_PID.pid
}

netcat_module(){
	if [[ ! -f $default_folder/netcat_module.sh ]]; then
		echo -e "Não foi encontrado módulo do netcat\nInterrompendo script"
		exit 1
	fi
	echo "Starting netcat_module"
	$default_folder/netcat_module.sh &
	#nohup $default_folder/netcat_module.sh >/dev/null 2>&1 &
	nc_PID=$!
	echo "Detected netcat PID: '$nc_PID'"
	echo -n $nc_PID > "$netcat_PID_file"
}

main(){
	var_set
	netcat_module
	read
}



main
shutdown