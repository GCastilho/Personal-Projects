#!/bin/bash

echo "Argument count: $#"
echo "All arguments: '$*'"
arg_len=$*
echo "All arguments length '${#arg_len}'"
echo

#${#var} returns the length of var (tamanho)
#${var:pos:N} returns N characters from pos onwards 

arg=("$@")			#coloca os argumentos em um array
unset arg_list
opt_args="qtd"			#Os argumentos dessa variável são os que OBRIGATORIAMENTE precisam de uma opção passada como outro argumento (ex: -d /bin/bash)
for ((count=0; count < ${#arg[*]}; count++)) {		#Lista recursivamente os itens do array dos argumentos
	if [ "${arg[count]:0:1}" == "-" ]; then			#Testa se o argumento começa com traço '-'
		if [ "${arg[count]:1:1}" == "-" ]; then		#Testa se o argumento tem um segundo traço ('--')
			if [[ ! -z ${arg[count]} ]]; then		#Adiciona o item no array apenas se ele não é nulo
				arg_list[arr++]="${arg[count]}"
			fi
		else
			i=0		#i controla em qual palavra a opção passada como argumento está, relativamente a posição do array sendo analisada
			for ((char=1; char<${#arg[count]}; char++)) {	#Lista recursivamente os caracteres do item do array; char=1 para ignorar o '-'
				if [[ ! -z ${arg[count]:char:1} ]]; then	#Adiciona o item no array apenas se ele não é nulo
					arg_list[arr++]="-${arg[count]:char:1}"		#Coloca o char do argumento no array de argumentos
					if [[ ! -z $opt_args ]]; then				#If necessário se $opt_args estiver vazia
						if echo ${arg[count]:char:1} | grep [$opt_args] >/dev/null; then	#Verifica se ${arg[count]:char:1} contêm algum char de $opt_args
							((i++))											#Incrementa o controle de organização das opções passadas como argumentos
							if [[ ! -z ${arg[count+i]} ]]; then				#Adiciona o item no array apenas se ele não é nulo
								arg_list[arr++]="${arg[count+i]}"			#Coloca a opção do cada argumento em ordem no array (-ab opa opb)
								arg[count+i]=""								#Limpa a posição no array, para impedir que o argumento seja duplicado na lsita
							fi
						fi
					fi
				fi
			}
		fi
	else											#Para argumentos que não começam com traço '-'
		if [[ ! -z ${arg[count]} ]]; then			#Adiciona o item no array apenas se ele não é nulo
			arg_list[arr++]="${arg[count]}"			#Adiciona argumentos que não começam com traço na lista
		fi
	fi
}
for ((count=0; count < ${#arg_list[*]}; count++)) {
	arg=${arg_list[count]}
	case $arg in
		-q)
			arg_q=1
			((count++))		#Como a opção tem um argumento, e esse rgumento foi reorganizado para a posição seguinte no array, esse comando pula ele na análise
			data_arg_q=${arg_list[count]} ;;
		-w)
			arg_w=1 ;;
		-t|--teste=*)
			arg_teste=1
			if [[ ${arg:1:1} == "-" ]]; then
				data_arg_teste=${arg#*=}
			else
				((count++))		#Incrementa o count para que a opção do argumento seja ignorada
				data_arg_teste=${arg_list[count]}
			fi ;;
		-d|--dir=*)
			arg_dir=1
			if [[ $arg == "-d" ]]; then
				((count++))		#Os dados do argumento sempre estão na posição seguinte do array, já que foram organizados assim pela primeira parte do script
				datual=${arg_list[count]}
			else
				datual=${arg#*=}
			fi
			if [[ -d $(pwd)/$datual ]]; then	#Essa sequencia de if tenta detectar posições relativas passadas como argumento, e reoganizá-lo
				datual=$(pwd)/$datual
			elif [[ -d $HOME${arg#*~} ]]; then	#Para pastas relativas ao diretório do script (ex: -d folder/subfolder)
				datual=$HOME${arg#*~}
			elif [[ ! -d $datual ]]; then		#Para argumentos relativos a home (ex: ~/folder/subfolder)
				echo "'$datual' não foi reconhecido como um diretório válido"
				exit 2
			fi ;;
		*)
			echo "$arg é um argumento inválido"
			exit 2 ;;
	esac
}

if [[ $arg_q == 1 ]]; then
	echo "Argumento Q"
	echo "Dado argumento Q: $data_arg_q"
fi
if [[ $arg_w == 1 ]]; then
	echo "Argumento W"
fi
if [[ $arg_teste == 1 ]]; then
	echo "Argumento teste"
	echo "Dado argumento teste: $data_arg_teste"
fi
if [[ $arg_dir == 1 ]]; then
	echo "Argumento dir usado"
	echo "Diretório selecionado como '$datual'"
fi