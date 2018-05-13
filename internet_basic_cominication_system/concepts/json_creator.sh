#!/bin/bash

username=GCastilho
tor_ip="thehiddenwiki.onion"
keyname=$(jq --raw-output .keyname config.json)
#NOTA: msg_sig está encriptando o HEX não a public key em si. Atenção qdo verificar
public_key="$(gpg -a -r $keyname --export | xxd -p)"	#Converte a public key pra hex

echo -e "\nEnter password: "
read -s password

timestamp=$(date +%s)
password_hash=$(echo -n $(echo -n "$password" | sha256sum | awk '{print $1;}')$(echo -n "$timestamp" | sha256sum | awk '{print $1;}') | sha256sum | awk '{print $1;}')
msg_sig=$(echo -n "$username$password_hash$timestamp$tor_ip$public_key" | gpg --no-tty -u $keyname --detach-sign -a --passphrase $password | xxd -p)
unset password

json=$(jq -n '{ "username": "'$username'", "password_hash": "'$password_hash'", "timestamp": "'$timestamp'", "tor_ip": "'$tor_ip'", "public_key": "'"$public_key"'", "msg_sig": "'"$msg_sig"'" }')

echo
jq . <<<$json
jq . --tab --ascii-output <<<$json > json_created.json