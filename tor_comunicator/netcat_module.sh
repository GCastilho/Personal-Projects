#!/bin/bash

buffer_folder=buffer
server_tc_PID=$default_folder/server_tc_PID.pid

shutdown(){
	kill -TERM $PID 2>/dev/null
	kill -TERM $((++PID)) 2>/dev/null	#O PID do netcat (não do script) (tecnicamente) é um sem seguida [gambiarra]
	exit 0
}
trap shutdown SIGINT SIGTERM

echo "Iniciando módulo netcat"
if [[ -d "$buffer_folder" ]]; then
	if [[ -w "$buffer_folder" ]]; then
		echo "Limpando arquivos da última sessão"
		rm -r "$buffer_folder"
	else
		echo -e "Erro: O script não tem permissão de gravação na pasta '$buffer_folder'\nInterrompendo o script!"
		exit 1
	fi
fi
while true; do
	buffer=$(netcat -l 1234)
	netcat_return=$?
	echo -e "NC_return: $netcat_return\nBuffer: '$buffer'"
	#Fecha o módulo se o processo pai não está rodando, esse check só é feito quando o processo fecha, talvez criar thread pra checar? xD
	#if (! kill -0 $(cat "$server_tc_PID" 2>/dev/null) 2>/dev/null); then shutdown; fi
	if [[ $netcat_return != 0 ]]; then
		echo -e "netcat exited with status $netcat_return \nStopping"
		break
	fi
	echo "Conexão encerrada"
	if [[ ! -d $buffer_folder ]]; then
		if (! mkdir $buffer_folder); then
			echo -e "Erro ao criar pasta '$buffer_folder'\nInterrompendo o script!"
			exit 1
		fi
	fi
	files=$(ls -A $buffer_folder/netcat_buffer_* 2>/dev/null | sort)	#organiza os arquivos alfabeticamnte
	file_number=$(ls -A $buffer_folder/netcat_buffer_* 2>/dev/null | sort | wc -l)
	for(( count=0; count <= file_number; count++ )) {
		if [[ ! -f $buffer_folder/netcat_buffer_$count ]]; then
			echo "Salvando buffer em netcat_buffer_$count"
			echo "$buffer" > $buffer_folder/netcat_buffer_$count
			break
		fi
	}
done