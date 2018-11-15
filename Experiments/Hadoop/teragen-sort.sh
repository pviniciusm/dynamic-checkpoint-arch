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
#application="/etc/hadoop/hadoop-2.7.3/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-2.7.3-tests.jar"
application="/etc/hadoop/hadoop-2.7.3/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.3.jar"

nrRepeticoes=20
fault=false
nrFiles=1
## 5GB
#fileSize=50000000

## 10GB
#fileSize=100000000

## 50GB
#fileSize=500000000

## 100GB
#fileSize=1000000000

## 100GB
fileSize=1000000000

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
		/etc/hadoop/hadoop-2.7.3/sbin/stop-all.sh

		rm /etc/hadoop/hadoop-2.7.3/logs/* -rf

		# Processo de formatacao do HDFS para consistencia dos testes
		for slave in $(cat ~/hosts)
		do
			ssh hadoop@$slave 'rm -rf /tmp/hadoop-hadoop/*'
			echo "$slave: done."
		done
		/etc/hadoop/hadoop-2.7.3/bin/hdfs namenode -format

		rm /etc/hadoop/hadoop-2.7.3/logs/*-namenode-*.log
		rm /etc/hadoop/hadoop-2.7.3/logs/*-datanode-*.log

		# Inicia o Hadoop
		/etc/hadoop/hadoop-2.7.3/sbin/start-all.sh

		#Dorme por 30 segundos para evitar safe mode
		sleep 30


		


		#### Teragen
		# Inicio de tempo para log
		start_time=`date +%s`
		# Testes....
		t1=$($HADOOP_HOME/bin/hadoop jar $application teragen -Dmapred.map.tasks=20 $fileSize /terasort-input)
		# Fim de tempo para log
		end_time=`date +%s`
		# Escrita de log
		echo "TeraGen #$rep = `expr $end_time - $start_time` seg." >> results.txt

		# Falha deve ser inserida aqui!!!!
		if [ $fault = true ]; then
			echo "fault is activated."
			#Inicia a thread de insercao de falha
			#/home/hadoop/experimentos/failures.sh &
			proce=$(jps | grep -w "NameNode" | cut -d' ' -f1)
			kill -9 $proce

			sleep 30
		fi

		#### Terasort
		# Inicio de tempo para log
		start_time=`date +%s`
		
		if [ $fault = true ]; then
			/etc/hadoop/hadoop-2.7.3/sbin/hadoop-daemon.sh start namenode
			/etc/hadoop/hadoop-2.7.3/bin/hdfs dfsadmin -safemode leave
		fi

		# Testes....
		t1=$($HADOOP_HOME/bin/hadoop jar $application terasort -Dmapred.map.tasks=20 -Dmapred.reduce.tasks=20 /terasort-input /terasort-output)
		# Fim de tempo para log
		end_time=`date +%s`
		# Escrita de log
		echo "TeraSort #$rep = `expr $end_time - $start_time` seg." >> results.txt

		cat /etc/hadoop/hadoop-2.7.3/logs/*-namenode-*.log > "log-nn-$rep.txt"
		cat /etc/hadoop/hadoop-2.7.3/logs/*-datanode-*.log > "log-dn-$rep.txt"


	done
	echo "\n\n"
done
