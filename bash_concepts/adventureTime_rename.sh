#!/bin/bash
cd /home/gabriel/Vídeos/Adventure\ Time/S05
ep_list=/home/gabriel/Vídeos/Adventure\ Time/S05/ep.list

for file in *.mkv; do
	file_num=${file#S05E}
	file_num=${file_num:0:2}
	new_name=$(cat "$ep_list" | cut -f 2-3 | grep $file_num | cut -f2)
	new_name="${new_name%\"}"	#remove aspas finais
	new_name="${new_name#\"}"	#remove aspas iniciais
	if [ "$new_name" ]; then	#Só muda o nome se achar na lista
		mv -v "$file" "${file:0:6} - $new_name.mkv"
	fi
	#fazer um jeito de impedir que ele sobrescreva arquivos

	#echo $file_num
	#echo $file $new_name.$file_extension
done