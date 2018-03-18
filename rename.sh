#!/bin/bash
for file in $(ls -A)
do
	modfile=${file#.} #seta "modfile" para "file" sem o que vem depois do # ou seja, (nesse momento) o ponto
	mv -v .$modfile $modfile
done