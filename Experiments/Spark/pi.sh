#!/bin/bash

nrRepeticoes=1

for rep in $(seq 1 $nrRepeticoes)
	do

		# Inicio de tempo para log
		start_time=`date +%s`

		################################################
		# Testes....
		/etc/spark/spark-2.2.0/bin/spark-submit --master spark://graphene-119.nancy.grid5000.fr:7077 --deploy-mode client /home/hadoop/experimentos/pi.py 50
		#
		################################################

		# Fim de tempo para log
		end_time=`date +%s`

		# Escrita de log
		echo ">> Run $rep >> `expr $end_time - $start_time` s." >> result-pi.txt


	done
