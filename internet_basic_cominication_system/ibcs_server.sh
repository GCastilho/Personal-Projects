#!/bin/bash

echo "Starting 'tor_comunicator' Server"

shutdown(){
	kill -TERM $netcat_module_PID 2>/dev/null
	if (kill -0 $netcat_PID 2>/dev/null); then kill -9 $netcat_PID 2>/dev/null; fi 	#Caso o SIGTERM não feche o processo, ele dá SIGKILL
	rm "$PID_file" "$netcat_module_PID_file" 2>/dev/null
	exit 0	#O exit não está funcionando
}
trap shutdown EXIT SIGINT SIGTERM


var_set(){
	PID=$$
	root_dir=.
	PID_file=$root_dir/server_tc_PID.pid
	echo -n $PID > "$PID_file"
	netcat_module_PID_file=$root_dir/netcat_module_PID.pid
	buffer_folder=buffer
}

start_netcat_module(){
	if [[ -f "$netcat_module_PID_file" ]]; then
		netcat_module_PID=$(cat "$netcat_module_PID_file")
		if (kill -0 $netcat_module_PID 2>/dev/null); then
			echo "Error: Can't start netcat_module cause netcat_module is already running"
			return 1
		fi
	fi
	if [[ ! -f $root_dir/netcat_module.sh ]]; then
		echo -e "Não foi encontrado módulo do netcat\nInterrompendo script"
		exit 1
	fi
	echo "Starting netcat_module"
	$root_dir/netcat_module.sh &
	netcat_module_PID=$!
	echo "Detected netcat module PID: '$netcat_module_PID'"
	echo -n $netcat_module_PID > "$netcat_module_PID_file"
}

buffer_monitor(){
	unset buffer_set
	if (! kill -0 $netcat_module_PID 2>/dev/null); then start_netcat_module; fi 	#Checa se o módulo do netcat está rodando e inicia-o se não estiver
	buffer_files_number=$(ls -A $buffer_folder/netcat_buffer_* 2>/dev/null | wc -l)	#organiza os arquivos alfabeticamnte
	if [ $buffer_files_number -lt 1 ]; then
		echo "Sleeping"
		sleep 10
		buffer_monitor
	else
		buffer_files=$(ls -A $buffer_folder/netcat_buffer_* 2>/dev/null | sort)
		for(( count=0; count <= buffer_files_number; count++ )){
			if [ ! $buffer_set ]; then buffer=$(cat $buffer_folder/netcat_buffer_$count 2>/dev/null); buffer_set=1; fi
			if [ $buffer_files_number -eq 1 ]; then
				rm $buffer_folder/netcat_buffer_$count 2>/dev/null
				break
			else
				while [ -f  $buffer_folder/netcat_buffer_$((count+1)) ]; do
					mv $buffer_folder/netcat_buffer_$((count+1)) $buffer_folder/netcat_buffer_$count 2>/dev/null
				done
			fi
		}
	fi
	loop
}

loop(){
	echo "$buffer"
	buffer_monitor
}

main(){
	var_set
	start_netcat_module
	buffer_monitor
}



main
shutdown