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
HADOOP_HOME="/etc/hadoop/hadoop-2.7.3"
application="/etc/hadoop/hadoop-2.7.3/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-2.7.3-tests.jar"

nrRepeticoes=20
fault=true
nrFiles=2
fileSize="256MB"


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

		# Interrompe o Hadoop
		#/etc/hadoop/hadoop-2.7.3/sbin/stop-all.sh

		#rm /etc/hadoop/hadoop-2.7.3/logs/* -rf

		
		#rm -rf /tmp/hadoop-paulo/*
		
		#/etc/hadoop/hadoop-2.7.3/bin/hdfs namenode -format

		# Inicia o Hadoop
		#/etc/hadoop/hadoop-2.7.3/sbin/start-all.sh

		#Dorme por 30 segundos para evitar safe mode
		#sleep 30

		# Inicio de tempo para log

		################################################
		# Testes....
		$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -clean

		#start_time=`date +%s`
		#$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -write -nrFiles $nrFiles -fileSize $fileSize
		#end_time=`date +%s`


		if [ $fault = true ]; then

			sh failures.sh &
			#proce=$(jps | grep -w "NameNode" | cut -d' ' -f1)
			#kill -9 $proce
			#sleep 30

			#/etc/hadoop/hadoop-2.7.3/sbin/hadoop-daemon.sh start namenode
			#/etc/hadoop/hadoop-2.7.3/bin/hdfs dfsadmin -safemode leave
		fi

		start_time=`date +%s`
		$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -write -nrFiles $nrFiles -fileSize $fileSize
		end_time=`date +%s`


		# Recovery running
		#start_time_two=`date +%s`
		#$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -read -nrFiles $nrFiles -fileSize $fileSize
		#end_time_two=`date +%s`


		# Escrita de log
		#echo ">> Run $rep >> `expr $end_time - $start_time` s." >> results.txt
		echo "[AF] TestDFSIO #$rep = `expr $end_time - $start_time` seg." >> results.txt
		#echo "[DF] TestDFSIO #$rep = `expr $end_time_two - $start_time_two` seg." results.txt

		#cat /etc/hadoop/hadoop-2.7.3/logs/*-namenode-*.log > "log-nn-$rep.txt"
		#cat /etc/hadoop/hadoop-2.7.3/logs/*-datanode-*.log > "log-dn-$rep.txt"
		#cat /etc/hadoop/hadoop-2.7.3/logs/*-secondarynamenode-*.log > "log-snn-$rep.txt"

		echo "Wait..........."
		sleep 20

	done
	echo "\n\n"
done
