for arq in *.mkv ; do mencoder "$arq" -oac mp3lame -lameopts br=256 -af resample=48000 -ovc lavc -vf scale=670:378 -ffourcc XVID -o "${arq/.mkv/.avi}"; done 
