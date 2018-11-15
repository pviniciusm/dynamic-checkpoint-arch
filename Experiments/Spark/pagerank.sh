#!/bin/bash

###############################################################################
##  Benchmark PageRank para o Spark (HiBench)
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
		-e=*|--executorm=*)
		EXECUTORM="${i#*=}"
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
HADOOP="/etc/hadoop/hadoop-2.7.3"
SPARK="/etc/spark/spark-2.2.0"

HIBENCH="/home/hadoop/experimentos/HiBench"
REPORTS="/home/hadoop/experimentos/results"

APP="$HIBENCH/bin/workloads/websearch/pagerank"

#application="/etc/hadoop/hadoop-2.7.3/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-2.7.3-tests.jar"
#application="/home/paulo/Grid5000/Benchmarks/HiBench/bin/workloads/micro/wordcount/spark/run.sh"

nrRepeticoes=20
fault=false
nrFiles=20
fileSize=24GB
profile="large"
executor="1g"


rm $HIBENCH/report/* -rf


sed -i "s/spark\.executor\.memory.*/spark\.executor\.memory\t$executor/g" ~/experimentos/HiBench/conf/spark.conf


echo "Profile is: $profile"
echo "Executor memory is: $executor"


# Create dataset

$SPARK/sbin/stop-all.sh
$HADOOP/sbin/stop-all.sh
# Processo de formatacao do HDFS para consistencia dos testes
for slave in $(cat ~/hosts)
do
	ssh hadoop@$slave 'rm -rf /tmp/hadoop-hadoop/*'
	echo "$slave: done."
done
$HADOOP/bin/hdfs namenode -format

# Spark and Hadoop start
$HADOOP/sbin/start-all.sh
$SPARK/sbin/start-all.sh

# Sleep for 30 secs to avoid safe mode
sleep 30

# Define workload profile
sed -i "s/hibench\.scale\.profile.*/hibench\.scale\.profile\t$profile/g" ~/experimentos/HiBench/conf/hibench.conf

# Prepare dataset
$APP/prepare/prepare.sh
echo "Dataset created"


echo "------ PageRank benchmark ------" >> $REPORTS/results.txt
echo "Profile: $profile" >> $REPORTS/results.txt

for rep in $(seq 1 $nrRepeticoes)
do
	mkdir $REPORTS/report-$rep
	mkdir $REPORTS/report-$rep/pagerank

	# Interrompe Spark e Hadoop
	$SPARK/sbin/stop-all.sh
	#$HADOOP/sbin/stop-all.sh

	#rm $HADOOP/logs/* -rf

	$SPARK/sbin/start-all.sh

	# Sleep for 30 secs to avoid safe mode
	echo "\n\n---------------------------------"
	echo "---------- SLEEP TIME -----------"
	echo "---------------------------------\n\n"
	sleep 30


	#### Testes
	# Inicio de tempo para log
	start_time=`date +%s`
	$APP/spark/run.sh
	cp $HIBENCH/report/pagerank/spark/monitor.html $REPORTS/report-$rep
	# Fim de tempo para log
	end_time=`date +%s`

	# Escrita de log
	echo "#$rep = `expr $end_time - $start_time` sec." >> $REPORTS/results.txt
	cp $HIBENCH/report/hibench.report $REPORTS
	
	
	mv $HIBENCH/report/pagerank $REPORTS/report-$rep/pagerank

done

echo "\n\n"
