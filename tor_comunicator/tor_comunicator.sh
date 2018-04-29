#!/bin/bash

path=.

echo -e "Protótipo do tor_comunicator\nIn development"

checkconfigjson(){
	#Cria o arquivo config.json como um JSON se ele não existir
	if [ ! -s $path/config.json ]; then echo -n "{}" > $path/config.json; fi
	#Converte o arquivo para um JSON caso ele não seja um
	if (! jq -e . $path/config.json >/dev/null 2>&1); then echo -n "{}" > $path/config.json; fi
	#Checa se uma chave para este usuário existe, se não existir chama função de criar a chave
	if ( ! jq -e '.gpg_keys[] | select(.keyname=="tc_'$username'")' config.json >/dev/null 2>&1 ); then
		if (gpg --list-keys $username >/dev/null 2>&1); then
			#não existe chave no config.json MAS existe chave com esse nome no chaveiro
			echo -e -n "Já existe uma chave no chaveiro GnuPG com o nome '$tc_$username'\nO que você deseja fazer?\n\n1:Deletar a chave existente (default)\n2:Escolher outro nome de usuário\n3:Adicionar uma chave duplicada (Extremamente não recomendado, pode causar bugs)\nEscolher:"
			read gpg_conflict_option
			case $gpg_conflict_option in
				1|"")
					while ( gpg --list-keys $username >/dev/null 2>&1 ); do
						echo "Confirme a remoção da chave privada"
						gpg --delete-secret-keys $username
					done
					while ( gpg --list-keys $username >/dev/null 2>&1 ); do
						echo "Confirme a remoção da chave pública"
						gpg --delete-keys $username
					done ;;
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

teste(){
	gpg --list-keys tc_$username 	#checa se existe uma key no chaveiro com esse nome (retorna false se não tiver)
	#gpg --list-keys tc_$username | grep uid | awk '{print $2;}' | wc -l 	#conta QUANTAS chaves tc_username existem. Não pode existir mais de uma
	#if (gpg --list-keys tc_$username); then


	#[[ $(gpg --list-keys tc_$username | grep uid | awk '{print $2;}' | wc -l) == 1 ]]
}

creategpgkey(){
	echo -e "\nÉ necessário criar uma chave assimétrica para a utilização do software"
	echo "Como a senha será armazenada em plain-text no arquivo 'config.json' recomenda-se não utilizar esta chave para outra coisa"
	echo "O nome da chave será 'tc_$username' e será armazenada no chaveiro padrão do GnuPG"
	echo -n "entre com informações de entropia (isso NÃO será a senha da chave): "
	read password

	timestamp=$(date +%s)
	#A senha da chave será o sha256 da concatenação entre o sha256 da entropia e do timestamp
	password=$(echo -n $(echo -n "$password" | sha256sum | awk '{print $1;}')$(echo -n "$timestamp" | sha256sum | awk '{print $1;}') | sha256sum | awk '{print $1;}')
	#Gera o script temporário que o gpg vai usar para criar a chave
	echo -en "%echo Generating a 2018 bits RSA key\nKey-Type: RSA\nKey-Length: 2048\nSubkey-Type: RSA\nSubkey-Length: 2048\nName-Real: tc_$username\nName-Comment: key for tor_comunicator\nExpire-Date: 0\n%commit\n%echo done" > $path/gpg_script
	gpg --batch --gen-key gpg_script
	rm $path/gpg_script

	
	config_json=$(jq . $path/config.json)
	jq '.gpg_keys[.gpg_keys|length] += { "keyname": "'tc_$username'", "password": "'$password'"}' <<<$config_json > $path/config.json
	unset config_json
}

selectusername(){
	while [ ! $username ]; do
		echo -n -e "\nEnter username: "
		read username
		if [ ! $username ]; then echo "Username não pode ser vazio"; fi
	done
	checkconfigjson
}


selectusername


