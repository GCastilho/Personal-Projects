#!/bin/bash

shutdown(){
	netcat_PID=$(cat $netcat_PID_file 2>/dev/null)
	kill -TERM $netcat_module_PID 2>/dev/null
	kill -TERM $netcat_PID 2>/dev/null
	if ( kill -0 $netcat_PID 2>/dev/null ); then kill -9 $netcat_PID 2>/dev/null; fi 	#Caso o SIGTERM não feche o processo, ele dá SIGKILL
	rm -r "$PID_file" "$netcat_module_PID_file" "$netcat_PID_file" "$buffer_folder" 2>/dev/null
	exit 0	#O exit não está funcionando. Na verdade ele provavelmente está, mas todos os módulos executam a função shutdown qdo fecham, então o exit fecha O MÓDULO
}
trap shutdown EXIT SIGINT SIGTERM

var_set(){
	PID=$$
	root_dir=.
	PID_file=$root_dir/ibcs_server_PID.pid
	echo -n $PID > "$PID_file"
	netcat_module_PID_file=$root_dir/netcat_module_PID.pid
	netcat_PID_file=$root_dir/netcat_PID.pid
	buffer_folder=buffer
	local_port=1234
}

logit(){
	local thread_name=$1
	local echo_arg=$2
	local color_arg
	if [[ $thread_name == main ]]; then echo -e "\e[0m$(date  "+%F %T") ${echo_arg}\e[0m"; return				#Normal (No color)
	elif [[ $thread_name == start_netcat_module ]]; then thread_name=Start_Netcat_Module; color_arg='\e[34m'	#Blue
	elif [[ $thread_name == netcat_module ]]; then thread_name=Netcat_Module;color_arg='\e[33m'					#Yellow
	elif [[ $thread_name == buffer_analyzer ]]; then thread_name=Buffer_Analyzer;color_arg='\e[95m';fi			#Light magenta
	echo -e "$color_arg$(date  "+%F %T") $thread_name - ${echo_arg}\e[0m"
}

#-------------netcat-------------
start_netcat_module(){
	local logit="logit start_netcat_module"
	if [[ "$netcat_module_PID" ]]; then
		if ( kill -0 $netcat_module_PID 2>/dev/null ); then
			$logit "Error: Can't start netcat_module cause netcat_module is already running"
			return 1
		fi
	fi
	$logit "Starting netcat_module"
	netcat_module &
	netcat_module_PID=$!
	$logit "Detected netcat module PID: '$netcat_module_PID'"
	$logit -n $netcat_module_PID > "$netcat_module_PID_file"
}

netcat_module(){
	local logit="logit netcat_module"
	$logit "Started netcat module"
	if [[ -d "$buffer_folder" ]]; then
		if [[ -w "$buffer_folder" ]]; then
			if [[ $(ls -A $buffer_folder/ | wc -l) > 0 ]]; then
				$logit "Limpando arquivos da última sessão"
				rm -r "$buffer_folder/*" 2>/dev/null
			fi
		else
			$logit "Erro: O script não tem permissão de gravação na pasta '$buffer_folder'\nInterrompendo o script!"
			exit 1
		fi
	fi
	while true; do
		if [[ ! -d $buffer_folder ]]; then
			if ( ! mkdir $buffer_folder ); then
				$logit "Erro ao criar pasta '$buffer_folder'\nInterrompendo o script!"
				exit 1
			fi
		fi
		$logit "Iniciando netcat na porta $local_port"
		netcat -l $local_port > $buffer_folder/buffer &
		netcat_PID=$!
		$logit "Detected netcat PID: '$netcat_PID'"
		echo -n "$netcat_PID" > "$netcat_PID_file"
		wait $netcat_PID
		netcat_return=$?
		if ( ! kill -0 "$PID" 2>/dev/null ); then exit; fi
		$logit "netcat: Conexão encerrada"
		if [[ $netcat_return != 0 ]]; then
			$logit "netcat exited with status $netcat_return \nStopping module"
			exit 1
		fi
		files=$(ls -A $buffer_folder/netcat_buffer_* 2>/dev/null | sort)	#organiza os arquivos alfabeticamnte
		file_number=$(ls -A $buffer_folder/netcat_buffer_* 2>/dev/null | wc -l)
		for(( count=0; count <= file_number; count++ )) {
			if [[ ! -f $buffer_folder/netcat_buffer_$count ]]; then
				$logit "Salvando buffer em '$buffer_folder/netcat_buffer_$count'"
				mv $buffer_folder/buffer $buffer_folder/netcat_buffer_$count
				$logit "Calling data analyzer function"
				buffer_analyzer $count &
				buffer_analyzer_PID_[$count]=$!
				$logit "Data Analyzer (thread_$count) PID: ${buffer_analyzer_PID_[$count]}"
				break
			fi
		}
	done
}
#-------------End netcat-------------

#-------------Send and receive-------------
buffer_analyzer(){
	local logit="logit buffer_analyzer"
	local count=$1
	buffer=$(cat $buffer_folder/netcat_buffer_$count 2>/dev/null)
	case $(jq .msg_type --raw-output <<<"$buffer" 2>/dev/null) in
		ping)
			ping_reply ;;
		ping_reply)
			#colocar numero do ping ou algum tipo de identificação nene, pra suportar várias solicitações
			mv $buffer_folder/netcat_buffer_$count $buffer_folder/ping_received ;;
		*)
			$logit "buffer não reconhecido:\n'$buffer'" ;;
	esac
	if [[ -f $buffer_folder/netcat_buffer_$count ]]; then rm $buffer_folder/netcat_buffer_$count 2>/dev/null; fi
}

#Fazer um check se existe endereço e porta na variável
send_data(){
	local to_send_address=$1
	local to_send_data=$2
	netcat $to_send_address <<<"$to_send_data"
}
#-------------Fim send and receive-------------

#-------------Data validators-------------
ping_reply(){
	response_addr=$(jq .response_addr --raw-output <<<"$buffer")
	if [[ ! "$response_addr" ]]; then return 1; fi
	if ( ! is_valid_timestamp ); then return 1; fi
	$logit "Respondendo solicitação de ping para '$response_addr'"
	send_data "$response_addr" "$(jq '.ping_reply | .timestamp="'$(date +%s)'"' $root_dir/models/ping.json)"
}

is_valid_timestamp(){
	local msg_timestamp
	msg_timestamp=$(jq .timestamp --raw-output <<<"$buffer")
	if [[ $(($msg_timestamp+60)) -ge $(date +%s) ]] && [[ $(date +%s) -le $(($msg_timestamp+5)) ]]; then return 0; else return 1; fi
}
#-------------Fim data validators-------------

thread_monitor(){
	if ( ! kill -0 "$PID" 2>/dev/null ); then shutdown; fi
	if ( ! kill -0 $netcat_module_PID 2>/dev/null ); then start_netcat_module; fi
	sleep 60
	thread_monitor
}

main(){
	local logit="logit main"
	$logit "Starting IBCS Server"
	var_set
	start_netcat_module
	thread_monitor &
	while [[ true ]]; do
		sleep 120
	done
}

main