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


#format_hdfs
format_hdfs()
{
	# Stop Hadoop services
	$HADOOP_HOME/sbin/stop-all.sh

	# Remove logs
	rm $HADOOP_HOME/logs/* -rf

	# Remove HDFS files from all nodes
	rm -rf /tmp/hadoop-paulo/*

	# Do format
	$HADOOP_HOME/bin/hdfs namenode -format

	# Start Hadoop again
	$HADOOP_HOME/sbin/start-all.sh

	sleep 10
	# Turn off safemode state
	$HADOOP_HOME/bin/hdfs dfsadmin -safemode leave

	echo "Format done."
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
HADOOP_HOME="/etc/hadoop/hadoop-2.7.4"
#RESULTPATH="/home/hadoop/experimentos/results"
application="/etc/hadoop/hadoop-2.7.4/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-2.7.4-tests.jar"

# Configuration
nrRepeticoes=5
fault=true
nrFiles=2
fileSize=200MB
#snn="$(cat /home/hadoop/snnhost)"

if [ $SIZE ]; then
	fileSize="$SIZE"
fi
if [ $FILES ]; then
	nrFiles="$FILES"
fi
if [ $FAULT ]; then
	fault="$FAULT"
fi

format_hdfs

for rep in $(seq 1 $nrRepeticoes)
do

	#format_hdfs
	
	# Limpa dados de outras execucoes
	$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -clean

	sleep 1

	if [ $fault = true ]; then
		#echo "fault activated" > /home/hadoop/experimentos/logf.txt
		sh failures.sh &
	fi

	# Init job
	start_time=`date +%s`
	$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -write -nrFiles $nrFiles -fileSize $fileSize
	end_time=`date +%s`

	# Time log	
	echo "TestDFSIO #$rep = `expr $end_time - $start_time` seg." >> results.txt

	# Logs log
	#cat /etc/hadoop/hadoop-2.7.3/logs/hadoop*-namenode*.log > $RESULTPATH/nn-$rep.log
	#scp hadoop@$snn:/etc/hadoop/hadoop-2.7.3/logs/hadoop*secondary*.log $RESULTPATH/sn-$rep.log

	#truncate -s 0 $HADOOP_HOME/logs/hadoop*-namenode*.log
	#ssh hadoop@$snn truncate -s 0 /etc/hadoop/hadoop-2.7.3/logs/hadoop*secondary*.log

done
