#!/bin/bash

shutdown(){
	kill -TERM $PID 2>/dev/null
	exit 0
}
trap shutdown EXIT SIGINT SIGTERM

teste(){
	echo "Hi there"
	sleep 5
	((var++))
	echo "inner var: '$var'"
	teste
}

var=0
teste &
PID=$!
for((count=0; count<3; count++)){
	echo "for executado $count vezes"
	echo "var: '$var'"
	sleep 10
}

#Conclusão: Variáveis modificadas em um processo filho não são alteradas no processo pai.
#Usar 'env' resolve isso, mas aparentemente não tem como usá-lo redirecionando a saída pra null