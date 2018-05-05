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
	PID_file=$root_dir/ibcs_client_PID.pid
	echo -n $PID > "$PID_file"
	netcat_module_PID_file=$root_dir/client_netcat_module_PID.pid
	netcat_PID_file=$root_dir/client_netcat_PID.pid
	config_json=$(jq . $root_dir/config.json)
	buffer_folder=client_buffer
	local_ip="localhost"
	local_port=1235
	response_addr="$local_ip $local_port"
}

updateconfigfile(){
	jq . --tab <<<"$config_json" > $root_dir/config.json
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

#O comando  de sign tem q ser configurado pra usuário e senha corretos
sign_message(){
	msg_sig=$(echo -n "$1" | gpg --no-tty --detach-sign --armor --local-user ibcs_$username --passphrase $(jq --raw-output '.gpg_keys[] | select(.keyname=="ibcs_'$username'") | .password' <<<"$config_json") | xxd -p)	#O msg_sign será armazenado em HEX
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
		handshake_response)
			mv $buffer_folder/netcat_buffer_$count $buffer_folder/handshake_received ;;
		*)
			$logit "buffer não reconhecido: '$buffer'" ;;
	esac
	if [[ -f $buffer_folder/netcat_buffer_$count ]]; then rm $buffer_folder/netcat_buffer_$count 2>/dev/null; fi
}

send_data(){
	local to_send_address=$1
	local to_send_data=$2
	netcat $to_send_address <<<"$to_send_data"
}
#-------------Fim send and receive-------------

#-------------Data validators-------------
ping_reply(){
	response_addr=$(jq .response_addr --raw-output <<<"$buffer")
	if [[ ! "$response_addr" ]]; then return; fi
	if ( ! is_valid_timestamp ); then return; fi
	$logit "Respondendo solicitação de ping para '$response_addr'"
	send_data "$response_addr" "$(jq -n '{ "msg_type": "ping_reply", "timestamp": "'$(date +%s)'"}')"
}

is_valid_timestamp(){
	local msg_timestamp
	msg_timestamp=$(jq .timestamp --raw-output <<<"$buffer")
	if [[ $(($msg_timestamp+60)) -ge $(date +%s) ]] && [[ $(date +%s) -le $(($msg_timestamp+5)) ]]; then return 0; else return 1; fi
}

is_handshake(){
	local msg_type
	local msg_timestamp
	msg_type="$(jq --raw-output .msg_type <<<"$buffer")"
	if [[ $msg_type != handshake ]]; then
		echo "Erro de comunicação, o sistema não recebeu um retorno válido do servidor"
		main_menu
	fi
	if (! is_valid_timestamp ); then
		echo "O timestamp da mensagem é um valor inválido"
		main_menu
	fi
	#Checar a assinatura da mensagem
	jq . <<<"$buffer"
}
#-------------Fim data validators-------------

#-------------Connect to server-------------
connect_server(){
	local escolha
	echo -e "\n1 Selecionar um servidor salvo"
	echo "2 Entrar um IP manualmente"
	echo "9 Voltar ao Menu Principal"
	echo -n "Escolha: "
	read escolha
	case $escolha in
		1)
			#echo "Não implementado"
			#connect_server ;;
			server_ip=localhost
			server_port=1234 ;;
		2)
			echo -n "Entre com o IP: "
			read server_ip
			echo -n "Entre com a porta: "
			read server_port ;;
		9)
			main_menu ;;
		*)
			echo "Opção inválida"
			connect_server ;;
	esac
	if ( ! send_ping_to_server ); then return; fi
	selectusername
	check_pgp_key
	get_handshake
	echo "Sending handshake..."
	send_data "$server_ip $server_port" "$handshake_json"
	while true; do if [[ -f $buffer_folder/handshake_received ]]; then break; else sleep 1; fi; done &	#Aguarda uma resposta de ping chegar
	local handshake_checker=$!
	#Sub função de timeout
	echo "Timeout is 60 seconds"
	( sleep 60; if ( kill -0 $handshake_checker 2>/dev/null ); then kill -TERM $handshake_checker >/dev/null 2>&1; rm $buffer_folder/handshake_received >/dev/null 2>&1; fi ) &
	wait $handshake_checker
	if [[ $? -eq 0 ]]; then
		is_handshake
		rm $buffer_folder/ping_received	#redirecionar erro pra null
		if (! is_valid_timestamp); then echo "Erro: O servidor respondeu a solicitação com um timestamp inválido"; return 1; fi
	else
		echo "Timeout"
		return 1
	fi
	echo "fim da connect"
	read
}

send_ping_to_server(){
	local msg_timestamp
	local ping_data="$(jq -n --raw-output '{ "msg_type": "ping", "response_addr": "'"$response_addr"'", "timestamp": "'$(date +%s)'" }')"
	echo "Testando conexão com o servidor"
	send_data "$server_ip $server_port" "$ping_data"
	while true; do if [[ -f $buffer_folder/ping_received ]]; then break; else sleep 1; fi; done &	#Aguarda uma resposta de ping chegar
	local ping_checker=$!
	#Sub função de timeout
	( sleep 60; if ( kill -0 $ping_checker 2>/dev/null ); then kill -TERM $ping_checker >/dev/null 2>&1; rm $buffer_folder/ping_received >/dev/null 2>&1; fi ) &
	wait $ping_checker
	if [[ $? -eq 0 ]]; then
		buffer=$(cat $buffer_folder/ping_received)
		rm $buffer_folder/ping_received	#redirecionar erro pra null
		if (is_valid_timestamp); then
			echo "Conexão com o servidor bem-sucedida"
			return 0
		else
			echo "Erro: O servidor respondeu a solicitação com um timestamp inválido"
			return 1
		fi
	else
		echo "Timeout"
		return 1
	fi
}

selectusername(){
	unset username
	while [ ! $username ]; do
		echo -n -e "\nEnter username: "
		read username
		if [ ! $username ]; then echo "Username não pode ser vazio"; fi
	done
}

get_handshake(){
	#NOTA: msg_sig encriptará o HEX não a public key em si. Atenção qdo verificar
	public_key="$(gpg --armor --export ibcs_$username | xxd -p)"	#Converte a public key pra hex
	
	unset password
	while [ ! $password ]; do
		echo -n "Enter password: "
		read -s password
		if [ ! $password ]; then echo "Password não pode ser vazio"; else echo; fi
	done
	timestamp=$(date +%s)
	password_hash=$(echo -n $(echo -n "$password" | sha256sum | awk '{print $1;}')$(echo -n "$timestamp" | sha256sum | awk '{print $1;}') | sha256sum | awk '{print $1;}')
	unset password

	sign_message "$username$password_hash$timestamp$response_addr$public_key"
	handshake_json=$(jq -n '{ "msg_type": "handshake", "username": "'$username'", "timestamp": "'$timestamp'", "password_hash": "'$password_hash'", "response_addr": "'"$response_addr"'", "public_key": "'"$public_key"'", "msg_sig": "'"$msg_sig"'" }')
	unset timestamp
}
#-------------Fim connect to server-------------

check_config_file(){
	local gpg_conflict_option
	local gpg_key_list
	if [ ! $config_json ]; then echo "Erro, o arquivo de configurações não foi carregado corretamente"; shutdown; fi
	#Cria o arquivo config.json como um JSON se ele não existir
	if [ ! -s $root_dir/config.json ]; then echo -n "{}" > $root_dir/config.json; fi
	#Converte o arquivo para um JSON caso ele não seja um
	if (! jq -e . $root_dir/config.json >/dev/null 2>&1); then echo -n "{}" > $root_dir/config.json; fi
	#Testa por chaves no config.json que não existem no chaveiro
	gpg_key_list="$(gpg --list-keys | grep uid | awk '{print $2;}')"
	for var in $(jq --raw-output '.gpg_keys[] | .keyname' <<<"$config_json" ); do
		if ( ! echo "$gpg_key_list" | grep -w "$var" >/dev/null 2>&1); then
			config_json=$(jq 'del(.gpg_keys[] | select(.keyname=="'$var'"))' <<<"$config_json")
			updateconfigfile
		fi
	done
}

#-------------PGP Key-------------
check_pgp_key(){
	#Checa se uma chave para este usuário existe, se não existir chama função de criar a chave
	if ( ! jq -e '.gpg_keys[] | select(.keyname=="ibcs_'$username'")' <<<"$config_json" >/dev/null 2>&1 ); then
		#não existe chave no config.json MAS existe chave com esse nome no chaveiro
		if (gpg --list-keys ibcs_$username >/dev/null 2>&1); then
			gpg_keys_num=$(gpg --list-keys ibcs_$username | grep uid | awk '{print $2;}' | wc -l)	#Conta QUANTAS chaves ibcs_username existem
			if [[ $gpg_keys_num > 1 ]]; then mul_gpg_key="s" braquet=[$gpg_keys_num]; else mul_gpg_key=""; fi
			echo -e -n "Já existe outra$mul_gpg_key $braquet chave$mul_gpg_key no chaveiro GnuPG com o nome 'ibcs_$username'\nO que você deseja fazer?\n\n1:Deletar a$mul_gpg_key chave$mul_gpg_key existente$mul_gpg_key (default)\n2:Escolher outro nome de usuário\n3:Adicionar chave duplicada (Extremamente não recomendado, pode causar bugs)\nSelecionar opção: "
			read gpg_conflict_option
			case $gpg_conflict_option in
				1|"")
					while ( gpg --list-keys ibcs_$username >/dev/null 2>&1 ); do
						echo -e "\nConfirme a remoção da chave privada"
						gpg --delete-secret-keys ibcs_$username
						echo -e "\nConfirme a remoção da chave pública"
						gpg --delete-keys ibcs_$username
					done
					checkconfigjson ;;
				2)
					selectusername ;;
				3)
					echo -n "Uma chave duplicada pode tornar a comunicação com o servidor impossível, para continuar digite: 'Sim, faça o que eu digo': "
					read option_3
					if [[ "$option_3" != "Sim, faça o que eu digo" ]]; then
						echo "Frase incorreta, interrompendo script"
						exit 1
					fi ;;
				*)
					echo "Opção inválida"
					checkconfigjson ;;
			esac
		else
			creategpgkey
		fi
	fi
}

creategpgkey(){
	local entropy
	echo -e "\nÉ necessário criar uma chave assimétrica para a utilização do software"
	echo "Como a senha será armazenada em plain-text no arquivo 'config.json' recomenda-se não utilizar esta chave para outra coisa"
	echo "O nome da chave será 'ibcs_$username' e será armazenada no chaveiro padrão do GnuPG"
	echo -n "Por favor, entre com informações de entropia (isso NÃO será a senha da chave): "
	read entropy
	while [ ! $entropy ]; do
		echo "Não é permitido deixar em branco"
		read entropy
	done

	timestamp=$(date +%s)
	#A senha da chave gpg será o sha256 da concatenação entre o sha256 da entropia e do timestamp
	password=$(echo -n $(echo -n "$entropy" | sha256sum | awk '{print $1;}')$(echo -n "$timestamp" | sha256sum | awk '{print $1;}') | sha256sum | awk '{print $1;}')
	#Gera o script temporário que o gpg vai usar para criar a chave
	echo -en "%echo Generating a 2018 bits RSA key\nKey-Type: RSA\nKey-Length: 2048\nSubkey-Type: RSA\nSubkey-Length: 2048\nName-Real: ibcs_$username\nName-Comment: key for tor_comunicator\nExpire-Date: 0\n%commit\n%echo done" > $root_dir/gpg_script
	gpg --batch --gen-key gpg_script
	rm $root_dir/gpg_script

	config_json=$(jq '.gpg_keys[.gpg_keys|length] += { "keyname": "'ibcs_$username'", "password": "'$password'"}' <<<"$config_json")
	updateconfigfile
}
#-------------Fim PGP Key-------------

main_menu(){
	local escolha
	echo "Menu principal"
	echo "1 Conectar-se a um servidor"
	echo "9 Sair"
	echo -n "Escolha: "
	read escolha
	case $escolha in
		1)
			connect_server ;;
		9)
			exit 0 ;;
		*)
			echo "Opção inválida"
			main_menu ;;
	esac
	main_menu
}

thread_monitor(){
	if ( ! kill -0 "$PID" 2>/dev/null ); then shutdown; fi
	if ( ! kill -0 $netcat_module_PID 2>/dev/null ); then start_netcat_module; fi
	sleep 60
	thread_monitor
}

main(){
	echo "Welcome to IBCS"
	var_set
	check_config_file
	start_netcat_module
	thread_monitor &
	main_menu
}

main