#!/bin/bash

default_folder=.
buffer_folder=buffer
server_tc_PID=$default_folder/server_tc_PID.pid
port=1234

shutdown(){
	kill -TERM $netcat_PID 2>/dev/null
	if (kill -0 $netcat_PID 2>/dev/null); then kill -9 $netcat_PID 2>/dev/null; fi 	#Caso o SIGTERM não feche o processo, ele dá SIGKILL
	rm -r $default_folder/$buffer_folder 2>/dev/null
	exit 0
}
trap shutdown SIGINT SIGTERM

echo "Started netcat module"
if [[ -d "$buffer_folder" ]]; then
	if [[ -w "$buffer_folder" ]]; then
		echo "Limpando arquivos da última sessão"
		rm -r "$buffer_folder/*"
	else
		echo -e "Erro: O script não tem permissão de gravação na pasta '$buffer_folder'\nInterrompendo o script!"
		exit 1
	fi
fi
while true; do
	if [[ ! -d $buffer_folder ]]; then
		if (! mkdir $buffer_folder); then
			echo -e "Erro ao criar pasta '$buffer_folder'\nInterrompendo o script!"
			exit 1
		fi
	fi
	echo "Iniciando monitoramento da porta $port"
	netcat -l 1234 > $buffer_folder/buffer &
	netcat_PID=$!
	echo "NC PID: $netcat_PID"
	wait $netcat_PID
	netcat_return=$?
	if (! kill -0 $(cat "$server_tc_PID" 2>/dev/null) 2>/dev/null); then shutdown; fi
	echo "Conexão encerrada"
	if [[ $netcat_return != 0 ]]; then
		echo -e "netcat exited with status $netcat_return \nStopping"
		shutdown
	fi
	files=$(ls -A $buffer_folder/netcat_buffer_* 2>/dev/null | sort)	#organiza os arquivos alfabeticamnte
	file_number=$(ls -A $buffer_folder/netcat_buffer_* 2>/dev/null | wc -l)
	for(( count=0; count <= file_number; count++ )) {
		if [[ ! -f $buffer_folder/netcat_buffer_$count ]]; then
			echo "Salvando buffer em '$buffer_folder/netcat_buffer_$count'"
			mv $buffer_folder/buffer $buffer_folder/netcat_buffer_$count
			break
		fi
	}
done