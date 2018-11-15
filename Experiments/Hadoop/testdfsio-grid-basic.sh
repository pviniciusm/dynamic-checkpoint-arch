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


#stop_hdfs
stop_hdfs()
{
	# Stop Hadoop services
	$HADOOP_HOME/sbin/stop-all.sh

	# Remove logs
	rm $HADOOP_HOME/logs/* -rf
}


start_hdfs()
{
	# Start Hadoop again
	$HADOOP_HOME/sbin/start-all.sh

	# Prevents sleep mode
	sleep 60

	# Turn off safemode state
	#$HADOOP_HOME/bin/hdfs dfsadmin -safemode leave
}

#format_hdfs
format_hdfs()
{
	# Remove HDFS files from all nodes
	for slave in $(cat /home/hadoop/hosts)
	do
		ssh hadoop@$slave rm -rf /tmp/hadoop-hadoop/*
		echo "$slave: done."
	done

	# Do format
	$HADOOP_HOME/bin/hdfs namenode -format

	echo "Format done."
	#sleep 10
}



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


# Paths
HADOOP_HOME="/etc/hadoop/hadoop-2.7.3"
RESULTPATH="/home/hadoop/experimentos/results"
application="/etc/hadoop/hadoop-2.7.3/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-2.7.3-tests.jar"

# Configuration
nrRepeticoes=20
fault=true
nrFiles=32
fileSize=32GB
snn="$(cat /home/hadoop/snnhost)"

if [ $SIZE ]; then
	fileSize="$SIZE"
fi
if [ $FILES ]; then
	nrFiles="$FILES"
fi
if [ $FAULT ]; then
	fault="$FAULT"
fi

# Format once
stop_hdfs
format_hdfs


for rep in $(seq 1 $nrRepeticoes)
do
	for checkpoint in 3600 10
	do
		stop_hdfs
		sed -i "s/<!--checkpoint-value--><value>[0-9]\+</\<!--checkpoint-value--\>\<value\>$checkpoint\</g" $HADOOP_HOME/etc/hadoop/hdfs-site.xml

		for slave in $(cat /home/hadoop/hosts)
		do
			scp $HADOOP_HOME/etc/hadoop/hdfs-site.xml hadoop@$slave:$HADOOP_HOME/etc/hadoop
		done

		sleep 10

		format_hdfs

		start_hdfs
	
		# Limpa dados de outras execucoes
		$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -clean
		sleep 10

		if [ $fault = true ]; then
			echo "fault activated" > /home/hadoop/experimentos/logf.txt
			sh /home/hadoop/experimentos/failures.sh &
		fi

		# Init job
		start_time=`date +%s`
		$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -write -nrFiles $nrFiles -fileSize $fileSize
		end_time=`date +%s`

		# Time log	
		echo "TestDFSIO-$checkpoint #$rep = `expr $end_time - $start_time` seg." >> $RESULTPATH/results.txt

		# Logs log
		cat /etc/hadoop/hadoop-2.7.3/logs/hadoop*-namenode*.log > $RESULTPATH/nn-$rep.log
		scp hadoop@$snn:/etc/hadoop/hadoop-2.7.3/logs/hadoop*secondary*.log $RESULTPATH/sn-$rep.log

		truncate -s 0 $HADOOP_HOME/logs/hadoop*-namenode*.log
		ssh hadoop@$snn truncate -s 0 /etc/hadoop/hadoop-2.7.3/logs/hadoop*secondary*.log

		sleep 10
	done
	

done
