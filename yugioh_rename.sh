#!/bin/bash
db_file=/home/gabriel/Vídeos/Séries/Yu-Gi-Oh/Yu-Gi-Oh\ file\ list
dest_dir=/home/gabriel/Vídeos/Séries/Yu-Gi-Oh
#for file in $(ls -A)
echo "Digite a extensão do arquivo"
echo "Deixe em branco para '.mp4'"
read file_extension
if [ ! "$file_extension" ]; then
	file_extension=mp4
fi
mkdir $dest_dir/conv
for file in *.$file_extension
do
	file_num=${file#YGOEXO Yu-Gi-Oh}
	file_num=${file_num:1:3}
	new_name=$(cat "$db_file" | grep $file_num)
	cp -v "$file" $dest_dir/"$new_name".$file_extension
	mv -v "$file" $dest_dir/conv/"$new_name".$file_extension
done