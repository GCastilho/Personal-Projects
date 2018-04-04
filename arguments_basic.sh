#!/bin/bash

echo "Argument count: $#"
echo "All arguments: '$*'"
arg_len=$*
echo "All arguments length '${#arg_len}'"

#${#var} returns the length of var (tamanho)
#${var:pos:N} returns N characters from pos onwards 

for args in $*; do
	((var_num++))
	var_len=${#args}
	if [ "${args:0:1}" == "-" ]; then
		for ((count=0; count<$var_len; count++)) {
			arg_char=${args:count:1}
			echo "count=$count, arg_char=$arg_char"
		}
	fi
done