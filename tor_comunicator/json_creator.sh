#!/bin/bash

echo "Enter username: "
read username

echo -e "\nEnter tor ip: "
read tor_ip

#echo -e "\nEnter public key: "
#read public_key

public_key="$(echo -n "Hello Word\!" | gpg -r Server_Key -a -e | xxd -p)"	#Converte mensagem pra hex
#var=$(echo -n "$public_key" | xxd -r -p)

echo -e "\nEnter password: "
read -s password

timestamp=$(date +%s)
password_hash=$(echo -n $(echo -n "$password" | sha256sum | awk '{print $1;}')$(echo -n "$timestamp" | sha256sum | awk '{print $1;}') | sha256sum | awk '{print $1;}')
unset password
echo
msg_hash=$(echo -n "$username$password_hash$timestamp$tor_ip$public_key" | sha256sum | awk '{print $1;}')

json=$(jq -n '{ "username": "'$username'", "password_hash": "'$password_hash'", "timestamp": "'$timestamp'", "tor_ip": "'$tor_ip'", "public_key": "'"$public_key"'", "msg_hash": "'$msg_hash'" }')

jq . <<<$json