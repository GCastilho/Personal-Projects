#!/bin/bash
# programas utilizados: mencoder ffprobe bc mkvtoolnix jq

setresolucao() {
	local json_probe=$(ffprobe -v quiet -show_format -show_streams -print_format json "$datual"/"$arq")
	local coded_width=$(jq '.streams[] | select(.codec_type=="video") | .coded_width' <<<"$json_probe")
	local coded_height=$(jq '.streams[] | select(.codec_type=="video") | .coded_height' <<<"$json_probe")
	if [ -z $coded_width ] || [ -z $coded_height ]; then
		echo "Erro na definição da resolução: Leitura de variáveis incorreta"
		skip_file=1
		sleep 5
	else
		altura=$(echo "670/($coded_width/$coded_height)" | bc -l)	#Calcula precisamente o valor da altura por regra de 3
		altura=$(echo "($altura+0.5)/1" | bc )						#Arredonda o valor da altura para um inteiro
		echo "A resolução será 670x$altura"
		skip_file=0
	fi
}

converter() {
	echo -e "\nA conversão começará em 10 segundos"
	sleep 10
	if [ ! -d "$datual"/convertidos ]; then		#Checa se a pasta convertidos não existe
		mkdir "$datual/convertidos"				#Cria ela apenas se não existir
	fi
	for((count=1; count<=$n_ext; count++)){
		for arq in "$datual"/*.${extensao[count]}; do 	#Dá bug se nenhum arquivo com a extensão existir
			arq=${arq#$datual/}					#Remove o caminho do arquivo da variável
			echo -e "\n\e[1;35mConvertendo $arq\e[0m"
			setresolucao						#chama a função que configura a resolução individualmente para cada arquivo
			srtextract							#chama a função que irá extrair a legenda do arquivo de vídeo para um arquivo srt
			if [ $skip_file -eq 0 ]; then
				sleep 2
				mencoder "$datual"/"$arq" -oac mp3lame -lameopts br=256 -af resample=48000 -ovc lavc -vf scale=670:$altura -ffourcc XVID -alang $a_lang -lavcopts vbitrate=16000:autoaspect -nosub -msgcolor -o "$datual"/convertidos/"${arq/.$extensao[count]/.avi}"
			else
				echo "Pulando conversão do arquivo devido a erro na definição de variáveis"
				sleep 5
			fi
		done
	}
	echo "Fim do processo de conversão"
}

copia() {
	echo -e "\nIniciando cópia dos arquivos"
	sleep 5
	while read origem destino; do
		if [[ $(ls -1 "$datual"/convertidos/"$origem"* 2>/dev/null | wc -l) > 0 ]]; then	#Check se um arquivo que começa com '$origem' existe
			mv -v "$datual"/convertidos/"$origem"* ~/"$destino"								#Copia os arquivos que começam com '$origem' para '$destino'
		fi
	done < "$db_file"
	if [[ $(ls -A "$datual"/convertidos 2>/dev/null | wc -l) > 0 ]]; then	#Checa se há arquivos restantes na pasta convertidos
		mv -v "$datual"/convertidos/*    ~/Public/Videos/    				#Copia arquivos restantes da pasta convertidos para a '~/Public/Videos/'
	fi
	echo "Fim da cópia dos arquivos"
}

montar() {
	echo -e "\nTentando conexão com $file_host_name ($file_host)"
	if ( ping -c 1 $file_host &> /dev/null ); then
		echo "Conexão com $file_host_name bem-sucedida"
		if ( mountpoint -q ~/Public/Videos/ ); then
			echo "Pasta Videos já montada, pulando montagem"
			montada=1
		else
			echo "Montando a pasta Videos de $file_host_name"
			montada=0
			mount ~/Public/Videos/
			if ( mountpoint -q ~/Public/Videos/ ); then
				echo "Montagem bem sucedida"
			else
				echo -e "Erro na montagem, a pasta não foi montada\nInterrompendo script"
				exit 1
			fi
		fi
	else
		echo -e "Erro na conexão com $file_host_name\nInterrompendo o script"
		exit 1
	fi
}

desmontar() {
	if [ $montada -eq 0 ]; then
		echo -e "\nDesmontando a pasta Vídeos"
		umount ~/Public/Videos/
		if ( mountpoint -q ~/Public/Videos/ ); then
			echo -e "Houve um erro na desmontagem\nA Pasta não foi desmontada"
		else
			echo "Desmontagem bem sucedida"
		fi
	else
		echo -e "\nA pasta vídeos não será desmontada pois já estava montada antes da execução do script"
	fi
}

delete() {
	echo -e "\nRemovendo pasta convertidos"
	if [[ $(ls -A "$datual"/convertidos 2>/dev/null | wc -l) == 0 ]]; then
		if ( ! rm -vrf "$datual"/convertidos ); then
			echo -e "Erro ao deletar pasta 'convertidos'\nInterrompendo script"
			exit 1
		fi
	else
		echo "A pasta 'convertidos' não está vazia, isso significa que houve um erro ao copiar os arquivos para a pasta Vídeos"
		exit 1
	fi
	if [ $autodelete -eq 1 ]; then
		echo "Deletando pasta '$datual'"
		rm -vrf "$datual"
	else
		unset deletar
		while [ ! $deletar ]; do
			echo -e "Deletar a pasta '$datual'?\ns/N"
			read deletar
			case $deletar in
				S|s)
					echo "Deletando pasta '$datual'"
					rm -vrf "$datual" ;;
				N|""|n)
					echo "A pasta '$datual' não foi deletada"
					break ;;
				*)
					echo "Deixe em branco ou responda 'S' para Sim, 'n' para Não"
					unset deletar ;;
			esac
		done
	fi
}

checkempty() {
	if [[ ! $(ls -A "$datual"/convertidos) ]]; then
		echo -e "A pasta 'convertidos' está vazia, isso provavelmente ocorreu por um erro na conversão\nEncerrando o script"
		sleep 10
		exit 1
	fi
}

setextensao() {
	echo -en "\nSelecione o número de extensões diferentes dos arquivos de origem\nDeixe em branco para 1: "
	read n_ext
	if [ ! "$n_ext" ]; then
		n_ext=1
	fi
	for((count=1; count<=$n_ext; count++)){
		echo -n "Selecione a extensão $count "
		if [ $count -eq 1 ]; then
			echo -n "(deixe em branco para 'mkv') "
		fi
		read leitura_extensao
		if [ $count -eq 1 ] && [ ! "$leitura_extensao" ]; then
			leitura_extensao=mkv
		fi
		if [ ! "$leitura_extensao" ]; then
			echo "Você deve digitar uma extensão"
			((count--))
		fi
		extensao[count]=$leitura_extensao
	}
}

setlang() {
	echo -en "\nPor favor, selecione o idioma preferencial que deve ser utilizado na conversão "
	unset a_lang
	while [ ! $a_lang ]; do
		echo -n "(deixe em branco para 'por') "
		read a_lang
		if [ ! "$a_lang" ]; then
			a_lang=por
		fi
		case $a_lang in
			*[0-9]*)
				echo -n "Números não são permitidos "
				unset a_lang ;;
		esac
	done
	echo "O idioma preferencial que será usado na conversão será o '$a_lang'"
}

checkargumento() {
	unset arg_list
	opt_args="d"			#Os argumentos dessa variável são os que OBRIGATORIAMENTE precisam de uma opção passada como outro argumento (ex: -d /bin/bash)
	for ((count=0; count < ${#arg[*]}; count++)) {		#Lista recursivamente os itens do array dos argumentos
		if [[ "${arg[count]:0:1}" == "-" ]]; then		#Testa se o argumento começa com traço '-'
			if [[ "${arg[count]:1:1}" == "-" ]]; then	#Testa se o argumento tem um segundo traço ('--')
				if [[ ! -z ${arg[count]} ]]; then		#Adiciona o item no array apenas se o ítem não é nulo
					arg_list[arr++]="${arg[count]}"
				fi
			else
				i=0		#i controla em qual palavra a opção passada como argumento está, relativamente a posição do array sendo analisada
				for ((char=1; char<${#arg[count]}; char++)) {	#Lista recursivamente os caracteres do item do array; char=1 para ignorar o '-'
					if [[ ! -z ${arg[count]:char:1} ]]; then	#Adiciona o item no array apenas se o ítem não é nulo
						arg_list[arr++]="-${arg[count]:char:1}"	#Coloca o char do argumento na lista de argumentos
						if [[ ! -z $opt_args ]]; then			#If necessário se $opt_args estiver vazia
							if ( echo ${arg[count]:char:1} | grep [$opt_args] >/dev/null ); then	#Verifica se ${arg[count]:char:1} contêm algum char de $opt_args
								((i++))											#Incrementa o controle de organização das opções passadas como argumentos
								if [[ ! -z ${arg[count+i]} ]]; then				#Adiciona o item no array apenas se o ítem não é nulo
									arg_list[arr++]="${arg[count+i]}"			#Coloca a opção do cada argumento em seguida dele (-ab opa opb)
									arg[count+i]=""								#Limpa a posição no array, para impedir que o argumento seja duplicado na lsita
								fi
							fi
						fi
					fi
				}
			fi
		else
			if [[ ! -z ${arg[count]} ]]; then			#Adiciona o item no array apenas se o ítem não é nulo
				arg_list[arr++]="${arg[count]}"			#Adiciona argumentos que não começam com traço na lista
			fi
		fi
	}
	for ((count=0; count < ${#arg_list[*]}; count++)) {
		arg=${arg_list[count]}
		case $arg in
			-D)
				autodelete=1 ;;
			-d|--dir=*)
				custom_dir=1
				if [[ $arg == "-d" ]]; then
					((count++))	#Os dados do argumento sempre estão na posição seguinte do array, já que foram organizados assim pela primeira parte do script
					datual=${arg_list[count]}
				else
					datual=${arg#*=}
				fi ;;
			*)
				echo "O argumento '${arg#*-}' é um argumento inválido"	#Remove o '-' do argumento ao mostrar para o usuário
				echo "Interrompendo script"
				exit 2 ;;
			#X) Um argumento que permita juntar todas as saídas em um único arquivo, como esse comando "mencoder -oac copy -ovc copy file1.avi file2.avi file3.avi -o full_movie.avi"
		esac
	}
	if [ $autodelete -eq 1 ]; then
		echo -e "\n\e[01;31mAVISO:\e[0m\nO argumento \"-D\" foi utilizado, autorizando a remoção automática do diretório atual no fim do script sem questionar"
	fi
	if [[ $custom_dir == 1 ]]; then
		datual=${datual%/}	#remove o último '/' se existir
		if [[ -d $(pwd)/$datual ]]; then	#Essa sequencia de if tenta detectar posições relativas passadas como argumento, e reoganizá-lo
			datual=$(pwd)/$datual
		elif [[ -d $HOME${arg#*~} ]]; then	#Para pastas relativas ao diretório do script (ex: -d folder/subfolder)
			datual=$HOME${arg#*~}
		elif [[ ! -d $datual ]]; then		#Para argumentos relativos a home (ex: ~/folder/subfolder)
			echo "'$datual' não foi reconhecido como um diretório válido"
			echo "Interrompendo o script"
			exit 2
		fi
	fi
}

checkconvertidos() {
	if [[ $(ls -A "$datual"/convertidos 2>/dev/null) ]]; then
		echo -e "Já existem arquivos na pasta convertidos\nDeseja pular a conversão e simplesmente copiá-los para a pasta Videos?\nS/n: "
		read pular
		case $pular in
			S|""|s)
				echo "Pulando a conversão"
				onlycopy=1 ;;
			*)
				echo "A conversão NÃO será ignorada, e os arquivos já convertidos TAMBÉM SERÃO copiados para a pasta Videos" ;;
		esac
	fi
}

checkdbfile() {
	if [ ! -e "$db_file" ]; then  #Checa a existência do arquivo de banco de dados; esse comando está depois da função 'checkargumento' caso algum argumento dela utilize outro DB
		echo -e "Erro na localização do banco de dados ($db_file)\nInterrompendo Script"
		exit 1
	fi
}

ambientvar() {
	db_file=/home/gabriel/Documentos/Shell\ Scripts/Mencoder/SMS_autocopy.db
	datual=$(pwd)
	onlycopy=0
	autodelete=0
	ffprobe_command="ffprobe -v quiet -show_format -show_streams -print_format json"
	file_host=192.168.0.101
	file_host_name=Nabucodonosor
}

srtextract() {
	filename=${arq%.$extensao*}
	#Uma função que detecta se existe uma faixa em 'por' no vídeo é melhor que o áudio setado para por
	if [ ! -f "$datual"/"$filename.srt" ] && [[ "$a_lang" != "por" ]]; then
		local json_probe=$($ffprobe_command "$datual"/"$arq")
		local n_fluxos_pt=$(jq '.streams[] | select(.codec_type=="subtitle") | select(.tags.language=="por") | .index' <<<"$json_probe" | wc -l)
		if [ $n_fluxos_pt -eq 1 ]; then
			echo -e "\nFoi encontrado um fluxo de legenda em portugues dentro do arquivo de vídeo\nExtraindo fluxo de legenda para arquivo srt..."
			local por_stream=$(jq '.streams[] | select(.codec_type=="subtitle") | select(.tags.language=="por") | .index' <<<"$json_probe")
			if (mkvextract tracks "$datual/$arq" $por_stream:"$datual/convertidos/$filename.srt"); then
				echo "Extração completa"
			else
				echo -e "Erro na extração da legenda\nInterrompendo Script"
				exit 1
			fi
		elif [ $n_fluxos_pt -gt 1 ]; then
			echo -e "\n\e[01;31mALERTA:\e[0m Não há arquivo externo de legenda para '$arq' MAS foi encontrado mais de um fluxo de legenda em portugues no arquivo de video\nO script não irá fazer nada"
			sleep 5
		fi
	fi
}

copiasrt() {
	if [ $(ls -1 "$datual"/*.srt 2>/dev/null | wc -l) -gt 0 ]; then
		echo -e "\nDetectado arquivos de legenda em '$datual'\nCopiando arquivos de legenda para a pasta 'convertidos'"
		if ( cp -v "$datual"/*.srt "$datual"/convertidos/ ); then
			echo "Arquivos copiados com sucesso"
		else
			echo -e "Erro na cópia do arquivos de legenda\nInterrompendo script"
			exit 1
		fi
	fi
}

main() {
	echo "Bem vindo ao programa de conversão e cópia automática para o SMS do PS2"
	echo "Esse programa usa mencoder"
	echo
	ambientvar          #Seta variáveis que serão as mesmas em todas as funções e são necessárias desde sempre
	checkargumento		#Checa os argumentos dados ao script e toma as medidas para tal
	echo -e "\nO diretório atual é: \"$datual\""
	checkdbfile         #Checa se o arquivo de banco de dados existe (lembrando que um argumento pode indicar outro DB, por isso ele checa depois da função 'checkargumento')
	checkconvertidos    #checa se a pasta 'convertidos' existe
	if [ $onlycopy -eq 0 ]; then	#se 'onlycopy' for igual a 1, todos os passos referentes a conversão dos arquivos serão pulados
		setextensao
		setlang			#Chama a função que configura o idioma
		converter		#Função da conversão propriamente dita
		copiasrt 		#Função que copia os arquivos de legenda para a pasta 'convertidos'
	fi
	checkempty		#Esta função checa se a pasta convertidos está vazia
	montar          #chama a função que monta a pasta videos
	copia           #Copia os arquivos para a pasta Videos
	desmontar       #desmonta a pasta Videos
	delete			#chama a função delete, que (obviamente) irá deletar a pasta do script e tudo contido nela
	echo "Fim do script"
	sleep 2
	exit 0
}

#coloca os argumentos em um array
arg=("$@")

#inicia a função main
main
