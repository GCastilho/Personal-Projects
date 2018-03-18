#!/bin/bash

ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
UPDATE_PATH=/home/gabriel/Nabucodonosor/scripts/geth_instance_manager_update.sh
default_dir=/home/gabriel
geth_network=$1

logit() 	#os argumentos dados a esta função são enviados ao arquivo de log
{
    echo "[$(date)] - ${*}" >> ${log}
}

#Função de definição do arquivo de log
case $geth_network in
	main)
		log=$default_dir/Nabucodonosor/logs/geth.log
		log_old=$default_dir/Nabucodonosor/logs/geth.log.old ;;
	test)
		log=$default_dir/Nabucodonosor/logs/testnet_geth.log
		log_old=$default_dir/Nabucodonosor/logs/testnet_geth.log.old ;;
	light)
		log=$default_dir/Nabucodonosor/logs/light_geth.log
		log_old=$default_dir/Nabucodonosor/logs/light_geth.log.old ;;
	*)
		exit 2 ;;
esac

echo "" >> $log
echo "" >> $log
logit "---------Script iniciado---------"

#Função de atualização
logit "Checando por atualizações"
cmp --silent $ABSOLUTE_PATH $UPDATE_PATH
sucess_check=$?
if [ $sucess_check -ne 0 ]; then
	logit "O arquivo update é diferente do atual, atualizando"
	cp $UPDATE_PATH $ABSOLUTE_PATH
	sucess_check=$?
	if [ $sucess_check -eq 0 ]; then
		logit "Atualização bem-sucedida, reiniciando script"
		$ABSOLUTE_PATH $geth_network
		exit 0
	else
		logit "Erro na atualização, interrompendo"
		exit 1
	fi
else
	logit "Nenhuma atualização encontrada, continuando normalmente"
fi

#Função de seleção da rede do geth
case $geth_network in
	main)
		logit "Selecting geth mainnet"
		pid_file=.geth_PID.pid
		w_dir=.ethereum/geth
		geth_command="geth --syncmode fast --cache 1024 --maxpeers=50 --rpc --rpcapi "eth,net,web3,personal" --rpcaddr 192.168.0.101"
		;;
	light)
		logit "Selecting geth mainnet light"
		pid_file=.geth_PID.pid
		w_dir=.ethereum/geth
		geth_command="geth --syncmode light --cache 1024 --maxpeers=50 --rpc --rpcapi "eth,net,web3,personal" --rpcaddr 192.168.0.101"
		;;
	test)
		logit "Selecting geth testnet"
		pid_file=.geth_testnet_PID.pid
		w_dir=.ethereum/testnet
		geth_command="geth --syncmode fast --testnet --rpc --rpcapi "eth,net,web3,personal" --rpcaddr 192.168.0.101 --rpcport 8546 --port 30304"
		;;
esac

#função de descarte de logs antigos
if [ $(wc -c < "$log") -ge 1048576 ]; then
	logit "Detectado arquivo de log maior que o permitido"
	logit "---------Finalizando arquivo de log---------"
	mv "$log" "$log_old"
	logit "---------Iniciando novo arquivo de log---------"
fi

#Função de check se a pasta $w_dir existe
if [ ! -d $default_dir/$w_dir ]; then
	logit "A pasta '$w_dir' não foi encontrada"
	logit "Encerrando o script sem sincronizar"
	logit "---------Script finalizado---------"
	echo "" >> $log
	exit 1
fi

logit "Iniciando nova instancia do geth"
$geth_command >> $log 2>&1 &
echo $! > $default_dir/$pid_file
wait $(cat $default_dir/$pid_file)
logit "Instancia finalizada"
logit "---------Script finalizado---------"
echo "" >> $log
