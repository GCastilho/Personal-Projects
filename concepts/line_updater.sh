#!/bin/bash

echo -e "Inicializando\n"
for((var=0; var<=100; var++)){
	tput cuu1 # move cursor up by one line
	tput el # clear the line
	echo "var: $var"
	sleep 0.1
}