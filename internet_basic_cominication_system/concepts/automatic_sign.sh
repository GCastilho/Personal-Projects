#/bin/bash

#teste.sec está em ascii
gpg --import teste.sec
gpg --default-key teste --passphrase teste --sign to-do.list
GPG_KEY=teste

#remove a secrete key
gpg --fingerprint --with-colons ${GPG_KEY} | grep "^fpr" | sed -n 's/^fpr:::::::::\([[:alnum:]]\+\):/\1/p' | xargs gpg --batch --delete-secret-keys
#remove a public key da lista
gpg --delete-keys --batch --yes teste