#!/bin/bash

gpg2 --quick-gen-key GCastilho

echo "Hello Word" | gpg -r Server_Key -a -e -o Hello-Word.txt.asc
echo "Hello Word!" | gpg -r Server_Key -a -e

echo "$var" | xxd -p | xxd -r -p

echo your_password | gpg --passphrase-fd 0 your_file.gpg

É necessário encryptar a mensagem com a public key do server (sem senha)
É necessário assinar os dados da mensagem ($username $password_hash $timestamp $tor_ip $public_key) por exemplo (provavelmente precisará de senha)