#!/bin/bash

updateconfigfile(){
	jq . --tab <<<"$config_json" > $root_dir/config.json
}

var_set(){
	root_dir=.
	config_json=$(jq . $root_dir/config.json)
}

#------------------Funções processadoras de dados------------------
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

send_data(){
	local to_send_data=$1
	netcat $server_ip $server_port <<<"$to_send_data"
}

receive_data(){
	echo "Aguardado recebimento de dados pela porta $local_port"
	echo "timeout é de 60 segundos"
	netcat -l $local_port > $root_dir/buffer_client &
	netcat_PID=$!
	echo "netcat PID: $netcat_PID"
	#Sub função de timeout
	( sleep 60; if ( kill -0 $netcat_PID 2>/dev/null ); then echo "timeout"; kill -TERM $netcat_PID >/dev/null 2>&1; rm $root_dir/buffer_client 2>/dev/null; fi ) &
	wait $netcat_PID
	if [[ $? -ne 0 ]]; then return 1; fi
	buffer=$(cat $root_dir/buffer_client)
	rm $root_dir/buffer_client
	return 0
}

is_valid_timestamp(){
	local msg_timestamp
	msg_timestamp=$(jq .timestamp --raw-output <<<"$buffer")
	if [[ $(($msg_timestamp+60)) -ge $(date +%s) ]] && [[ $(date +%s) -le $(($msg_timestamp+5)) ]]; then return 0; else return 1; fi
}
#------------------Fim das funções processadoras de dados------------------

check_config_file(){
	local gpg_conflict_option
	local gpg_key_list
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

check_pqp_key(){
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

	sign_message "$username$password_hash$timestamp$my_tor_ip$public_key"
	handshake_json=$(jq -n '{ "msg_type": "handshake", "username": "'$username'", "password_hash": "'$password_hash'", "timestamp": "'$timestamp'", "my_tor_ip": "'$my_tor_ip'", "public_key": "'"$public_key"'", "msg_sig": "'"$msg_sig"'" }')
	unset timestamp
}

#O comando  de sign tem q ser configurado pra usuário e senha corretos
sign_message(){
	msg_sig=$(echo -n "$1" | gpg --no-tty --detach-sign --armor --local-user ibcs_$username --passphrase $(jq --raw-output '.gpg_keys[] | select(.keyname=="ibcs_'$username'") | .password' <<<"$config_json") | xxd -p)	#O msg_sign será armazenado em HEX
}

ping_server(){
	local msg_timestamp
	local ping_data="$(jq -n --raw-output '{ "msg_type": "ping", "response_addr": "'$local_ip' '$local_port'", "timestamp": "'$(date +%s)'" }')"
	echo "Testando conexão com o servidor"
	send_data "$ping_data"
	receive_data
	if [[ $? -ne 0 ]]; then echo "Erro de conexão"; main_menu; else
		if [[ $(jq --raw-output .msg_type <<<"$buffer") == ping_response ]]; then
			if (is_valid_timestamp); then
				echo "Conexão com o servidor bem-sucedida"
				return 0
			else
				echo "Erro: O servidor respondeu a solicitação com um timestamp inválido"
				main_menu
			fi
		else
			echo "Erro: Os dados recebidos não são uma resposta de ping"
			return 1
		fi
	fi
}

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
}

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
	temp_local_ipconfig
	if ( ! ping_server ); then main_menu; fi
	selectusername
	check_pqp_key
	get_handshake
	send_data "$handshake_json"
	receive_data
	if [[ $? -eq 0 ]]; then is_handshake; else echo "Erro de conexão"; main_menu; fi
}

selectusername(){
	unset username
	while [ ! $username ]; do
		echo -n -e "\nEnter username: "
		read username
		if [ ! $username ]; then echo "Username não pode ser vazio"; fi
	done
}

temp_local_ipconfig(){
	local_ip="localhost"
	local_port=1235
}

main(){
	echo "Welcome to IBCS"
	var_set
	check_config_file
	main_menu
}

main