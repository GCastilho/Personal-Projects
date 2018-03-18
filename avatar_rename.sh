#!/bin/bash
db_file=/home/gabriel/MEGAsync/Avatar/TLA_EP_list.list
extensions="mkv srt"

echo "Digite o numero do livro"
read book_num

file_dir=BOOK\ $book_num

for file_extension in $extensions; do
	for file in "$file_dir"/*.$file_extension; do
		file_name=${file#$file_dir/}
		file_season=${file_name#S0}
		file_season=${file_season:0:1}
		file_ep=${file_name:4}
		file_ep=${file_ep:0:2}
		file_num=$file_season\x$file_ep
		new_name=$(cat "$db_file" | grep $file_num)
		if [ "$new_name" ]; then	#Só muda o nome se achar na lista
			#echo "$file" "$file_dir/$new_name".$file_extension
			mv "$file" "$file_dir/$new_name".$file_extension
		fi
		#fazer um jeito de impedir que ele sobrescreva arquivos

		#echo $file_num
		#echo $file $new_name.$file_extension
	done
done