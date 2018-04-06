#!/bin/bash

echo "Argument count: $#"
echo "All arguments: '$*'"
arg_len=$*
echo "All arguments length '${#arg_len}'"
echo

#${#var} returns the length of var (tamanho)
#${var:pos:N} returns N characters from pos onwards 

arg=($*)			#coloca os argumentos em um array
unset arg_list
opt_args=qt			#Os argumentos dessa variável são os que OBRIGATORIAMENTE precisam de uma opção passada como outro argumento (ex: -d /bin/bash)
for ((count=0; count < ${#arg[*]}; count++)) {		#Lista recursivamente os itens do array dos argumentos
	if [ "${arg[count]:0:1}" == "-" ]; then			#Testa se o argumento começa com traço '-'
		if [ "${arg[count]:1:1}" == "-" ]; then		#Testa se o argumento tem um segundo traço ('--')
			arg_list="$arg_list ${arg[count]}"
		else
			i=0		#i controla em qual palavra a opção passada como argumento está, relativamente a posição do array sendo analisada
			for ((char=1; char<${#arg[count]}; char++)) {	#Lista recursivamente os caracteres do item do array; char=1 para ignorar o '-'
				arg_list="$arg_list -${arg[count]:char:1}"			#Coloca o char do argumento na lista de argumentos
				if [[ ! -z $opt_args ]]; then		#If necessário se $opt_args estiver vazia
					if echo ${arg[count]:char:1} | grep [$opt_args] >/dev/null; then	#Verifica se ${arg[count]:char:1} contêm algum char de $opt_args
						((i++))											#Incrementa o controle de organização das opções passadas como argumentos
						arg_list="$arg_list ${arg[count+i]}"			#Coloca a opção do cada argumento em seguida dele (-ab opa opb)
						arg[count+i]=""									#Limpa a posição no array, para impedir que o argumento seja duplicado na lsita
					fi
				fi
			}
		fi
	else
		arg_list="$arg_list ${arg[count]}"			#Adiciona argumentos que não começam com traço na lista
	fi
}
arg_list=($arg_list)	#Transforma a lista de argumentos em um vetor
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
			if [ "${arg:1:1}" == "-" ]; then
				data_arg_teste=${arg#*=}
			else
				((count++))		#Incrementa o count para que a opção do argumento seja ignorada
				data_arg_teste=${arg_list[count]}
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