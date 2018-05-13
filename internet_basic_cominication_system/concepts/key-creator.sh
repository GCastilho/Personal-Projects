#!/bin/bash

username=GCastilho
password=password

#O password será "aléatório" e diferente do password digitado
password=$(echo -n $(echo -n "$password" | sha256sum | awk '{print $1;}')$(echo -n "$timestamp" | sha256sum | awk '{print $1;}') | sha256sum | awk '{print $1;}')

echo -en "%echo Generating a 2018 bits RSA key\nKey-Type: RSA\nKey-Length: 2048\nSubkey-Type: RSA\nSubkey-Length: 2048\nName-Real: tc_$username\nName-Comment: key for tor_comunicator\nExpire-Date: 0\n%pubring gpg_script.pub\n%secring gpg_script.sec\n%commit\n%echo done" > gpg_script

gpg --batch --gen-key gpg_script

rm gpg_script

jq -n '{"keys": [{ "keyname": "'tc_$username'", "password": "'$password'"}]}' > config.json