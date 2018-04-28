#!/bin/bash

echo "Iniciando módulo netcat"

while true; do
	buffer=$(netcat -l 1234)
	echo "$buffer"
done