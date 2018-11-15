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
		-p=*|--prof=*)
		PROFILES="${i#*=}"
		;;
		*)
		# unknown option
		;;
	esac
done


# Hadoop environment paths
HADOOP_HOME="/etc/hadoop/hadoop-2.7.3"
application="/etc/hadoop/hadoop-2.7.3/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-2.7.3-tests.jar"
HADOOP="/etc/hadoop/hadoop-2.7.3"


nrRepeticoes=20
fault=false
nrFiles=16
fileSize=32GB
profile=large


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
REPORTS="/home/hadoop/experimentos/results"
HIBENCH="/home/hadoop/experimentos/HiBench"

# Define workload profile
sed -i "s/hibench\.scale\.profile.*/hibench\.scale\.profile\t$profile/g" $HIBENCH/conf/hibench.conf

echo "------ PageRank benchmark ------" >> $REPORTS/results.txt
echo "Profile: $profile" >> $REPORTS/results.txt

for rep in $(seq 1 $nrRepeticoes)
do

	# Interrompe o Hadoop
	$HADOOP/sbin/stop-all.sh

	# Renove os logs
	rm $HADOOP/logs/* -rf

	# Processo de formatacao do HDFS para consistencia dos testes
	for slave in $(cat ~/hosts)
	do
		ssh hadoop@$slave 'rm -rf /tmp/hadoop-hadoop/*'
		echo "$slave: done."
	done
	
	$HADOOP/bin/hdfs namenode -format

	# Inicia o Hadoop
	$HADOOP/sbin/start-all.sh

	#Dorme por 30 segundos para evitar safe mode
	sleep 30

	#$HADOOP/bin/hdfs dfsadmin -safemode leave

	# Testdfsio-e
	start_time=`date +%s`
	$HIBENCH/bin/workloads/micro/dfsioe/hadoop/run_write.sh
	end_time=`date +%s`

	# Logging
	echo "TestDFSIOe #$rep = `expr $end_time - $start_time` seg." >> $RESULTPATH/results.txt

	cp $HIBENCH/report/hibench.report $REPORTS
	
	mkdir $REPORTS/report-$rep
	cp -r $HIBENCH/report/dfsioe/* $REPORTS/report-$rep

done
