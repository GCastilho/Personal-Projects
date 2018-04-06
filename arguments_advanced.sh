#!/bin/bash

OPTIONS=d
LONGOPTIONS=teste:	#os : são para dado depois do argumento usando =
PARSED=$(getopt --quiet --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")

if [[ $? -ne 0 ]]; then #if getopt has complained about wrong arguments to stdout
	echo "Foi utilizado um argumento inválido"
	echo "Interrompendo script"
	exit 2
fi
eval set -- "$PARSED"
while true; do
	case "$1" in
		-d)
			autodelete=1
			shift ;;
		--teste)
			echo "Testando!"
			echo "dado='$2'"
			shift 2 ;;
		--)
			shift
			break ;;
		*)
			echo "Erro de programação ao lidar com argumentos"
			exit 3 ;;
	esac
done

if [[ $autodelete == 1 ]]; then
	echo -e "\e[01;31mAVISO:\e[0m"
	echo "O argumento \"-d\" foi utilizado, autorizando a remoção automática do diretório atual no fim do script sem questionar"
	echo
fi

echo "verbose: $v, force: $f, debug: $d, in: $1, out: $outFile"
