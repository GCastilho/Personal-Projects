#!/bin/bash
db_file=/home/gabriel/gf.list
all_extensions="mkv mp4"
for file_extension in $all_extensions
do
	for file in *.$file_extension
	do
		if [ $file_extension = mkv ]; then
			file_num=${file#Gravity Falls 1ª Temporada Dublada EP }
			file_num=${file_num:0:2}
			file_num=S1E$file_num
		else
			file_num=${file#Gravity Falls.S0}
			file_num=${file_num:0:4}
		fi
#		echo $file_num
		new_name=$(cat "$db_file" | grep $file_num)
		if [ "$new_name" ]; then	#Só muda o nome se achar na lista
			mv -v "$file" "$new_name".$file_extension
			#echo "$file" "$new_name".$file_extension
		fi
		#fazer um jeito de impedir que ele sobrescreva arquivos
	done
done