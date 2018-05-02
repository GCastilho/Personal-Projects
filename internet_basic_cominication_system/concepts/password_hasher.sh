#!/bin/bash
#'read -s' lê sem mostrar na tela

read -s password
timestamp=$(date +%s)
echo "timestamp: '$timestamp'"
#O comando a seguir calcula o sha256 da concatenação entre sha256 do password e do sha256 do timestamp
echo "$(echo -n $(echo -n "$password" | sha256sum | awk '{print $1;}')$(echo -n "$timestamp" | sha256sum | awk '{print $1;}') | sha256sum | awk '{print $1;}')"
unset password