for arq in *.mp4 ; do mencoder "$arq" -oac mp3lame -lameopts br=256 -af resample=48000 -ovc lavc -ffourcc XVID -o "${arq/.mp4/.avi}"; done 
