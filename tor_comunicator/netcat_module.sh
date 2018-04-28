#!/bin/bash

folder=buffer
echo "Iniciando módulo netcat"
while true; do
	buffer=$(netcat -l 1234)
	netcat_return=$?
	if [[ $netcat_return != 0 ]]; then
		echo -e "netcat exited with status $netcat_return \nStopping"
		break
	fi
	echo "Conexão encerrada"
	if [[ ! -d $folder ]]; then
		mkdir $folder
	fi
	files=$(ls -A $folder/netcat_buffer_* 2>/dev/null | sort)	#organiza os arquivos alfabeticamnte
	file_number=$(ls -A $folder/netcat_buffer_* 2>/dev/null | sort | wc -l)
	for(( count=0; count <= file_number; count++ )) {
		if [[ ! -f $folder/netcat_buffer_$count ]]; then
			echo "Salvando buffer em netcat_buffer_$count"
			echo "$buffer" > $folder/netcat_buffer_$count
			break
		fi
	}
done