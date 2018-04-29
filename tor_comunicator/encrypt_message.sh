#!/bin/bash

sig_file=./sigfile.asc
msg_file=./msg_file

#gpg2 --quick-gen-key GCastilho
#
#echo "Hello Word" | gpg -r Server_Key -a -e -o Hello-Word.txt.asc
#echo "Hello Word!" | gpg -r Server_Key -a -e
#
#echo "$var" | xxd -p | xxd -r -p
#
#echo your_password | gpg --passphrase-fd 0 your_file.gpg
#
#gpg2 --verify teste.json.gpg --detach-sig teste.json
#gpg2 --verify teste.json.sig teste.json
#
#É necessário encryptar a mensagem com a public key do server (sem senha)
#É necessário assinar os dados da mensagem ($username $password_hash $timestamp $tor_ip $public_key) por exemplo (provavelmente precisará de senha)
#jq '.keys[.keys|length] += {"name": "teste"}' config.json	#Adiciona item na próxima posição do array
#
#Assinar a mensagem:

message="GCastilholalalathththfdfdbbwwb"
echo -n "$message" > $msg_file

signature=$(echo -n "$message" | gpg -r GCastilho --detach-sign -a --passphrase test)
echo "$signature" > $sig_file

gpg --verify "$sig_file" "$msg_file"

rm $msg_file $sig_file