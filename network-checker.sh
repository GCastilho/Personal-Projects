#!/bin/bash

log=/home/gabriel/Nabucodonosor/logs/network-checker.log
router=192.168.0.1
irede=enp0s4
n=0
echo "[$(date)] - Iniciando script" > $log #reseta o arquivo de log (ao usar apenas um '>') e coloca a mensagem de boas-vindas nele

logit() 	#os argumentos dados a esta função são enviados ao arquivo de log
{
    echo "[$(date)] - ${*}" >> ${log}
}

monitoramento ()				#com resultado bem sucedido, essa função checa a conexão a cada 3 min, se mal sucedido, 10 segundos, mas alguns testes mostraram que 
{								#o 'ifup' não conclui se o cabo n está conectado, então é pra ele ficar esperando e só voltar quando a conxão tiver normalizada
	ping -c 1 $router > /dev/null	#de qqer modo, se mal sucedido ele chama o reset a cada 10 segundos
	if [[ $? -eq 0 ]]; then #o resultado bem sucedido aguarda 3 min e checa novamente, chamando a funão (caracterizando um loop)				
		sleep 180
		monitoramento
	else
		logit "Foi detectado um erro de conexão com $router"
		logit "Fazendo novo teste em 10 segundos"
		sleep 10
		ping -c 1 $router > /dev/null		#testa a conexão com o roteador, igual o comando acima
		if [[ $? -eq 0 ]]; then
			logit "O novo teste de conexão foi bem sucedido"
			logit "Continuando processo de monitoramento"
			logit ""
			monitoramento		#chama a função novamente e continua o loop
		else
			logit "O novo teste de conexão foi mal sucedido"
			logit "Iniciando função para reiniciar a interface de rede"
			logit ""
			reset_interface
		fi
	fi
}

reset_interface ()
{
	n=$(( n+1 ))
	logit "A função reset está sendo executada pela $nª vez"
	logit "Reiniciando interface de rede $irede"
	ip addr flush $irede
	exit_flush=$?
	systemctl restart networking.service
	exit_systemctl=$?
	if [[ $(($exit_flush + $exit_systemctl)) -eq 0 ]];then
		logit "Reinicio de interface bem sucedido"
	else
		logit "Erro ao reiniciar interface"
	fi
	logit "Fim do processo de reset da interface de rede"
	logit "Chamando função para monitoramento da rede"
	monitoramento
}

logit "Iniciando sleep de 2 minutos"
sleep 120
logit "Fim do sleep"
logit "Iniciando função para monitoramento da conexão"
monitoramento