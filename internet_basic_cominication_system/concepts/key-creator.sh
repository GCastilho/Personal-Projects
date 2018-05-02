#!/bin/bash

#echo "Enter username: "
#read username
username=GCastilho

#echo "Enter password: "
#read -s password
#echo "Re-Enter password: "
#read -s re_password
#if [[ $password != $password ]]; then echo "As senhas não conferem"; exit; fi
#unset re_password
password=password

#O password será "aléatório" e diferente do password digitado
password=$(echo -n $(echo -n "$password" | sha256sum | awk '{print $1;}')$(echo -n "$timestamp" | sha256sum | awk '{print $1;}') | sha256sum | awk '{print $1;}')

#cat > gpg_script <<EOF
#	%echo Generating a 2018 bits RSA key
#	Key-Type: RSA
#	Key-Length: 2048
#	Subkey-Type: RSA
#	Subkey-Length: 2048
#	Name-Real: tc_$username
#	Name-Comment: key for tor_comunicator
#	Expire-Date: 0
#	%pubring gpg_script.pub
#	%secring gpg_script.sec
#	# Do a commit here, so that we can later print "done" :-)
#	%commit
#	%echo done
#EOF

echo -en "%echo Generating a 2018 bits RSA key\nKey-Type: RSA\nKey-Length: 2048\nSubkey-Type: RSA\nSubkey-Length: 2048\nName-Real: tc_$username\nName-Comment: key for tor_comunicator\nExpire-Date: 0\n%pubring gpg_script.pub\n%secring gpg_script.sec\n%commit\n%echo done" > gpg_script

gpg --batch --gen-key gpg_script

rm gpg_script

jq -n '{"keys": [{ "keyname": "'tc_$username'", "password": "'$password'"}]}' > config.json