#!/bin/bash

path=.
config_json=$(jq . $path/config.json)

echo -e "Protótipo do tor_comunicator\nIn development"

updateconfigfile(){
	jq . <<<"$config_json" > $path/config.json
}

selectusername(){
	while [ ! $username ]; do
		echo -n -e "\nEnter username: "
		read username
		if [ ! $username ]; then echo "Username não pode ser vazio"; fi
	done
	checkconfigjson
}

checkconfigjson(){
	#Cria o arquivo config.json como um JSON se ele não existir
	if [ ! -s $path/config.json ]; then echo -n "{}" > $path/config.json; fi
	#Converte o arquivo para um JSON caso ele não seja um
	if (! jq -e . $path/config.json >/dev/null 2>&1); then echo -n "{}" > $path/config.json; fi
	#Testa por chaves no config.json que não existem no chaveiro
	gpg_key_list="$(gpg --list-keys | grep uid | awk '{print $2;}')"
	for var in $(jq --raw-output '.gpg_keys[] | .keyname' <<<"$config_json" ); do
		if ( ! echo "$gpg_key_list" | grep -w "$var" >/dev/null 2>&1); then
			config_json=$(jq 'del(.gpg_keys[] | select(.keyname=="'$var'"))' <<<"$config_json")
			updateconfigfile
		fi
	done
	unset gpg_key_list
	#Checa se uma chave para este usuário existe, se não existir chama função de criar a chave
	if ( ! jq -e '.gpg_keys[] | select(.keyname=="tc_'$username'")' config.json >/dev/null 2>&1 ); then
		#não existe chave no config.json MAS existe chave com esse nome no chaveiro
		if (gpg --list-keys tc_$username >/dev/null 2>&1); then
			gpg_keys_num=$(gpg --list-keys tc_$username | grep uid | awk '{print $2;}' | wc -l)	#Conta QUANTAS chaves tc_username existem
			if [[ $gpg_keys_num > 1 ]]; then mul_gpg_key="s" braquet=[$gpg_keys_num]; else mul_gpg_key=""; fi
			echo -e -n "Já existe outra$mul_gpg_key $braquet chave$mul_gpg_key no chaveiro GnuPG com o nome 'tc_$username'\nO que você deseja fazer?\n\n1:Deletar a$mul_gpg_key chave$mul_gpg_key existente$mul_gpg_key (default)\n2:Escolher outro nome de usuário\n3:Adicionar chave duplicada (Extremamente não recomendado, pode causar bugs)\nSelecionar opção: "
			read gpg_conflict_option
			case $gpg_conflict_option in
				1|"")
					while ( gpg --list-keys tc_$username >/dev/null 2>&1 ); do
						echo -e "\nConfirme a remoção da chave privada"
						gpg --delete-secret-keys tc_$username
						echo -e "\nConfirme a remoção da chave pública"
						gpg --delete-keys tc_$username
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
	echo -e "\nÉ necessário criar uma chave assimétrica para a utilização do software"
	echo "Como a senha será armazenada em plain-text no arquivo 'config.json' recomenda-se não utilizar esta chave para outra coisa"
	echo "O nome da chave será 'tc_$username' e será armazenada no chaveiro padrão do GnuPG"
	echo -n "Por favor, entre com informações de entropia (isso NÃO será a senha da chave): "
	read password
	while [ ! $password ]; do
		echo "Não é permitido deixar em branco"
		read password
	done

	timestamp=$(date +%s)
	#A senha da chave gpg será o sha256 da concatenação entre o sha256 da entropia e do timestamp
	password=$(echo -n $(echo -n "$password" | sha256sum | awk '{print $1;}')$(echo -n "$timestamp" | sha256sum | awk '{print $1;}') | sha256sum | awk '{print $1;}')
	#Gera o script temporário que o gpg vai usar para criar a chave
	echo -en "%echo Generating a 2018 bits RSA key\nKey-Type: RSA\nKey-Length: 2048\nSubkey-Type: RSA\nSubkey-Length: 2048\nName-Real: tc_$username\nName-Comment: key for tor_comunicator\nExpire-Date: 0\n%commit\n%echo done" > $path/gpg_script
	gpg --batch --gen-key gpg_script
	rm $path/gpg_script

	config_json=$(jq '.gpg_keys[.gpg_keys|length] += { "keyname": "'tc_$username'", "password": "'$password'"}' <<<"$config_json")
	updateconfigfile
}

gethandshake(){
	#NOTA: msg_sig encriptará o HEX não a public key em si. Atenção qdo verificar
	public_key="$(gpg --armor --export tc_$username | xxd -p)"	#Converte a public key pra hex
	
	unset password
	while [ ! $password ]; do
		echo -n "Enter password: "
		read -s password
		if [ ! $password ]; then echo "Password não pode ser vazio"; fi
	done
	timestamp=$(date +%s)
	password_hash=$(echo -n $(echo -n "$password" | sha256sum | awk '{print $1;}')$(echo -n "$timestamp" | sha256sum | awk '{print $1;}') | sha256sum | awk '{print $1;}')
	unset password

	#O comando  de sign tem q ser configurado pra usuário e senha corretos
	handshake_sig=$(echo -n "$username$password_hash$timestamp$my_tor_ip$public_key" | gpg --no-tty --detach-sign --armor --local-user tc_$username --passphrase $(jq --raw-output '.gpg_keys[] | select(.keyname=="tc_'$username'") | .password' <<<"$config_json") | xxd -p)	#O handshake_sign será armazenado em HEX

	handshake_json=$(jq -n '{ "msg_type": "handshake", "username": "'$username'", "password_hash": "'$password_hash'", "timestamp": "'$timestamp'", "my_tor_ip": "'$my_tor_ip'", "public_key": "'"$public_key"'", "handshake_sig": "'"$handshake_sig"'" }')
	unset timestamp
}

senddatatoserver(){
	to_send_pkg=$1
	netcat localhost 1234 <<<"$to_send_pkg"
	unset to_send_pkg
}

receivedatafromserver(){
	received_data=$(netcat -l $my_tor_port)
}

tor_temp(){
	my_tor_ip="thehiddenwiki.onion"
	server_tor_ip="localhost 1234"
	my_tor_port=1234
}

main(){
	selectusername
	tor_temp
	gethandshake
	senddatatoserver "$handshake_json"
	receivedatafromserver
}

main