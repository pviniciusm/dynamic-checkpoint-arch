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

RESULTPATH="/home/hadoop/experimentos/results"


$HADOOP_HOME/sbin/stop-all.sh

# Renove os logs
rm $HADOOP_HOME/logs/* -rf

# Processo de formatacao do HDFS para consistencia dos testes
for slave in $(cat ~/hosts)
do
	ssh hadoop@$slave 'rm -rf /tmp/hadoop-hadoop/*'
	echo "$slave: done."
done

$HADOOP_HOME/bin/hdfs namenode -format

# Inicia o Hadoop
$HADOOP_HOME/sbin/start-all.sh

#Dorme por 30 segundos para evitar safe mode
sleep 120
#$HADOOP_HOME/bin/hdfs dfsadmin -safemode leave


snn="$(cat /home/hadoop/snnhost)"


for rep in $(seq 1 $nrRepeticoes)
do

	echo "start: $rep" > $HADOOP_HOME/logs/hadoop*-namenode*.log

	for slave in $(cat /home/hadoop/hosts)
	do
		ssh hadoop@$slave '> /etc/hadoop/hadoop-2.7.3/logs/*.log'
	done

	# Limpa dados de outras execucoes
	$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -clean

	# Inicio de tempo para log
	start_time=`date +%s`
	$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -write -nrFiles $nrFiles -fileSize $fileSize
	end_time=`date +%s`

	cat /etc/hadoop/hadoop-2.7.3/logs/hadoop*-namenode*.log > $RESULTPATH/nn$rep-af.log

	if [ $fault = true ]; then
		proce=$(jps | grep -w "NameNode" | cut -d' ' -f1)
		kill -9 $proce

		sleep 5
		/etc/hadoop/hadoop-2.7.3/sbin/hadoop-daemon.sh start namenode
		/etc/hadoop/hadoop-2.7.3/bin/hdfs dfsadmin -safemode leave
	fi

	# Inicio de tempo para log 2
	start_time_two=`date +%s`
	$HADOOP_HOME/bin/hadoop jar $application TestDFSIO -read -nrFiles $nrFiles -fileSize $fileSize
	end_time_two=`date +%s`



	# Log de tempo	
	echo "TestDFSIO [AF] #$rep = `expr $end_time - $start_time` seg." >> $RESULTPATH/results.txt
	echo "TestDFSIO [DF] #$rep = `expr $end_time_two - $start_time_two` seg." >> $RESULTPATH/results.txt

	# Log de logs
	cat /etc/hadoop/hadoop-2.7.3/logs/hadoop*-namenode*.log > $RESULTPATH/nn$rep-df.log
	scp hadoop@$snn /etc/hadoop/hadoop-2.7.3/logs/hadoop*secondary*.log $RESULTPATH/sn$rep.log

done
