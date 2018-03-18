#!/bin/bash
db_file=/home/gabriel/Vídeos/Séries/Star\ vs\ as\ forças\ do\ mal/Star\ vs\ -\ episode\ list.list
echo "Digite a extensão do arquivo"
echo "Deixe em branco para '.mp4'"
read file_extension
if [ ! "$file_extension" ]; then
	file_extension=mp4
fi
for file in *.$file_extension
do
	file_num=${file#Star}
	file_num=${file_num:0:6}
	new_name=$(cat "$db_file" | grep $file_num)
	if [ "$new_name" ]; then	#Só muda o nome se achar na lista
		mv -v "$file" "$new_name".$file_extension
	fi
	#fazer um jeito de impedir que ele sobrescreva arquivos

	#echo $file_num
	#echo $file $new_name.$file_extension
done