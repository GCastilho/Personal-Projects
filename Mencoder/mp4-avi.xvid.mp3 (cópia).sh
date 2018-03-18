for arq in *.mkv ; do mencoder "$arq" -of lavf -lavfopts format=mp4 -ovc lavc -oac lavc -lavcopts vcodec=libx264:acodec=ac3:vbitrate=6000:abitrate=256:autoaspect -o "${arq/.mkv/.mp4}"; done


