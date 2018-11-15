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
RESULTPATH="/home/hadoop/experimentos/results"
application="/etc/hadoop/hadoop-2.7.3/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-2.7.3-tests.jar"
snn="$(cat /home/hadoop/snnhost)"

# Script configuration
nrRepeticoes=20
fault=false
nrFiles=32
fileSize=8GB

if [ $SIZE ]; then
	fileSize="$SIZE"
fi
if [ $FILES ]; then
	nrFiles="$FILES"
fi
if [ $FAULT ]; then
	fault="$FAULT"
fi


###############################


# Hadoop pre-work steps
$HADOOP_HOME/sbin/stop-all.sh
rm $HADOOP_HOME/logs/* -rf

for slave in $(cat ~/hosts)
do
	ssh hadoop@$slave 'rm -rf /tmp/hadoop-hadoop/*'
	echo "$slave: done."
done

$HADOOP_HOME/bin/hdfs namenode -format
$HADOOP_HOME/sbin/start-all.sh

# Sleep for safemode avoid
sleep 120
#$HADOOP_HOME/bin/hdfs dfsadmin -safemode leave



###############################


# Main loop
for rep in $(seq 1 $nrRepeticoes)
do
	# Clear data
	rm $HADOOP_HOME/logs/*.log
	for slave in $(cat /home/hadoop/hosts)
	do
		ssh hadoop@$slave 'rm -rf /etc/hadoop/hadoop-2.7.3/logs/*.log'
	done

	$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -clean

	# Free fault running
	start_time=`date +%s`
	$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -write -nrFiles $nrFiles -fileSize $fileSize
	end_time=`date +%s`

	# Induced failure
	if [ $fault = true ]; then
		echo "fault is activated." >> $RESULTPATH/logfault.txt
		
		proce=$(jps | grep -w "NameNode" | cut -d' ' -f1)
		kill -9 $proce
		sleep 30

		/etc/hadoop/hadoop-2.7.3/sbin/hadoop-daemon.sh start namenode
		#/etc/hadoop/hadoop-2.7.3/bin/hdfs dfsadmin -safemode leave
	fi

	# Recovery running
	start_time_two=`date +%s`
	$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -read "/benchmarks/TestDFSIO"
	end_time_two=`date +%s`


	# Logging	
	echo "[AF] TestDFSIO #$rep = `expr $end_time - $start_time` seg." >> $RESULTPATH/results.txt
	echo "[DF] TestDFSIO #$rep = `expr $end_time_two - $start_time_two` seg." >> $RESULTPATH/results.txt

	cat $HADOOP_HOME/logs/hadoop*-namenode*.log > $RESULTPATH/nn$rep.log
	ssh hadoop@$snn cat $HADOOP_HOME/logs/hadoop*secondary*.log > $RESULTPATH/sn$rep.log

done
