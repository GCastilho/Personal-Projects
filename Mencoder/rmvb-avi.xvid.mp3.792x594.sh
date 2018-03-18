for arq in *.rmvb ; do mencoder "$arq" -oac mp3lame -lameopts br=256 -af resample=48000 -ovc lavc -vf scale=792:594 -ffourcc XVID -o "${arq/.rmvb/.avi}"; done 
