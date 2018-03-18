#!/bin/bash

echo "Argument count: $#"
echo "All arguments: $*"
case $1 in
	start)
		echo "start" ;;
	stop)
		echo "stop" ;;
	*)
		echo "Foi utilizado um argumento inválido"
		echo "Interrompendo script"
		exit 1 ;;
esac