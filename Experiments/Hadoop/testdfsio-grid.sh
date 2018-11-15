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

RESULTPATH="/home/hadoop/experimentos/results"


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
		rm /etc/hadoop/hadoop-2.7.3/logs/*-secondarynamenode-*.log

		# Inicia o Hadoop
		/etc/hadoop/hadoop-2.7.3/sbin/start-all.sh

		#Dorme por 30 segundos para evitar safe mode
		sleep 60


		#### Teragen
		# Inicio de tempo para log
		start_time=`date +%s`
		# Testes....
		echo "lets start the job"
		t1=$($HADOOP_HOME/bin/hadoop jar $application TestDFSIO -write -nrFiles $nrFiles -fileSize $fileSize)
		# Fim de tempo para log
		end_time=`date +%s`
		# Escrita de log
		echo "TestDFSIO (AF) #$rep = `expr $end_time - $start_time` seg." >> $RESULTPATH/results.txt

		$HADOOP_HOME/bin/hadoop fs -mkdir /benchmark-af
		$HADOOP_HOME/bin/hadoop fs -mv /benchmarks /benchmark-af


		# Falha deve ser inserida aqui!!!!
		if [ $fault = true ]; then
			echo "fault is activated." >> $RESULTPATH/logfault.txt
			#Inicia a thread de insercao de falha
			#/home/hadoop/experimentos/failures.sh &
			proce=$(jps | grep -w "NameNode" | cut -d' ' -f1)
			kill -9 $proce

			sleep 30

			echo "fault is really activated."
			start_time2=`date +%s`
			/etc/hadoop/hadoop-2.7.3/sbin/hadoop-daemon.sh start namenode
			/etc/hadoop/hadoop-2.7.3/bin/hdfs dfsadmin -safemode leave

			# Testes....
			t2=$($HADOOP_HOME/bin/hadoop jar $application TestDFSIO -write -nrFiles $nrFiles -fileSize $fileSize)
			# Fim de tempo para log
			end_time2=`date +%s`
			# Escrita de log
			echo "TestDFSIO (DF) #$rep = `expr $end_time2 - $start_time2` seg." >> $RESULTPATH/results.txt
		else
			start_time3=`date +%s`
			# Testes....
			t3=$($HADOOP_HOME/bin/hadoop jar $application TestDFSIO -write -nrFiles $nrFiles -fileSize $fileSize)
			# Fim de tempo para log
			end_time3=`date +%s`
			# Escrita de log
			echo "TestDFSIO (DF) #$rep = `expr $end_time3 - $start_time3` seg." >> $RESULTPATH/results.txt
		fi

		

		cat /etc/hadoop/hadoop-2.7.3/logs/*-namenode-*.log > $RESULTPATH/"log-nn-$rep.txt"
		cat /etc/hadoop/hadoop-2.7.3/logs/*-datanode-*.log > $RESULTPATH/"log-dn-$rep.txt"
		cat /etc/hadoop/hadoop-2.7.3/logs/*-secondarynamenode-*.log > $RESULTPATH/"log-snn-$rep.txt"

	done
	echo "\n\n"
done
