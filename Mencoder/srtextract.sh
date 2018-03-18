#!/bin/bash

n_fluxos_pt=0
dir=/home/gabriel/Videos/Séries/Rick\ and\ Morty/Rick\ and\ Morty\ S01
arq=rick.and.morty.s01e01.pilot.1080p.web.dl.x264-mRs.mkv
filename=${arq%.$extensao*}
ffprobe_command="ffprobe -v quiet -show_format -show_streams -print_format json"

stream_indexes=$($ffprobe_command "$dir"/"$arq" | jq .streams[].index | wc -l)

stream_num=0
while [ $stream_num -lt $stream_indexes ]; do
	if [ "$($ffprobe_command "$dir"/"$arq" | jq .streams[$stream_num].codec_type)" == "\"subtitle\"" ]; then
		srt_streams="${srt_streams} $stream_num"
	fi
	echo $stream_num
	((stream_num++))
done

for fluxo in $srt_streams; do
	fluxo_lang=$($ffprobe_command "$dir"/"$arq" | jq .streams[$fluxo].tags.language)
	echo "O fluxo $fluxo tem idioma $fluxo_lang"
	if [ "$fluxo_lang" == "\"por\"" ]; then
		por_stream="${por_stream} $fluxo"
		((n_fluxos_pt++))
	fi
done

if [ $n_fluxos_pt -eq 1 ]; then
	echo mkvextract tracks "$arq" $por_stream:"$filename".srt
	mkvextract tracks "$dir"/"$arq" $por_stream:"$filename.srt"
else
	echo "Há nenhuma ou mais de uma legenda PT"
fi