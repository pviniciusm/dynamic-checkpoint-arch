#!/bin/bash

###############################################################################
##  Benchmark TestDFSIO para o hadoop
##  Uso: sh testdfsio [ args ] &
##
##  [ args ]:
##     -F | --fault         = ativa a thread de falha        default:false
##     -s=nGB | --size=nGB  = define o tamanho dos arquivos  default:16GB
##     -f=n | --files=n     = define o numero de arquivos    default:20
##  Obs.:
##    1) o testdfsio guarda um log proprio da aplicacao
##       com t.exec, vazão, etc.
###############################################################################


# Argumentos
for i in "$@"
do
	case $i in
		-F|--fault)
		FAULT=true
		;;
		-s=*|--size=*)
		SIZE="${i#*=}"
		;;
		-f=*|--files=*)
		FILES="${i#*=}"
		;;
		*)
		# unknown option
		;;
	esac
done


# Hadoop environment paths
HADOOP="/etc/hadoop/hadoop-2.7.3"
SPARK="/usr/spark/spark-2.2.0"
HIBENCH="/home/paulo/Grid5000/Benchmarks/HiBench"
#application="/etc/hadoop/hadoop-2.7.3/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-2.7.3-tests.jar"
application="$HIBENCH/bin/workloads/micro/wordcount/spark/run.sh"
prepare="$HIBENCH/bin/workloads/micro/wordcount/prepare/prepare.sh"

nrRepeticoes=1
fault=false
nrFiles=20
fileSize=24GB

if [ $SIZE ]; then
	fileSize="$SIZE"
fi
if [ $FILES ]; then
	nrFiles="$FILES"
fi
if [ $FAULT ]; then
	fault="$FAULT"
fi


for checkpoint in 3600
do
	echo "================= Checkpoint $checkpoint ===================\n"

	for rep in $(seq 1 $nrRepeticoes)
	do

		# Interrompe os servicos
		#$HADOOP/sbin/stop-all.sh
		#$SPARK/sbin/stop-all.sh


		#rm $HADOOP/logs/* -rf
		#rm $SPARK/logs/* -rf

		# Processo de formatacao do HDFS para consistencia dos testes
		#rm -rf /tmp/hadoop-paulo/*
		#$HADOOP/bin/hdfs namenode -format

		# Inicia os servicos
		#$HADOOP/sbin/start-all.sh
		#$SPARK/sbin/start-all.sh


		#Dorme por 30 segundos para evitar safe mode
		#sleep 30



		#### HiBench
		# Inicio de tempo para log
		start_time=`date +%s`
		# Testes....
		echo "lets start the job"
		
		$prepare

		$application
		
		# Fim de tempo para log
		end_time=`date +%s`
		# Escrita de log
		echo "Spark HiBench (AF) #$rep = `expr $end_time - $start_time` seg." >> results.txt

		#cat $HADOOP/logs/*-namenode-*.log > "Hadoop-logs/log-nn-$rep.txt"
		#cat $HADOOP/logs/*-datanode-*.log > "Hadoop-logs/log-dn-$rep.txt"
		#cat $HADOOP/logs/*-secondarynamenode-*.log > "Hadoop-logs/log-snn-$rep.txt"

		#cp $SPARK/logs/*Master* "Spark-logs/log/master-$rep.txt"
		#cp $SPARK/logs/*Worker* "Spark-logs/log/worker-$rep.txt"

		#mkdir "Spark-logs/report/r-$rep"
		#cp $HIBENCH/reports/* "Spark-logs/report/r-$rep"



	done
	echo "\n\n"
done
