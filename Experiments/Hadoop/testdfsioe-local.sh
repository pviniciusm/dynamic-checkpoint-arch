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
HIBENCH="/home/paulo/Grid5000/Benchmarks/HiBench"


nrRepeticoes=20
fault=false
profile=small


if [ $SIZE ]; then
	fileSize="$SIZE"
fi
if [ $FILES ]; then
	nrFiles="$FILES"
fi
if [ $FAULT ]; then
	fault="$FAULT"
fi


# Define workload profile
sed -i "s/hibench\.scale\.profile.*/hibench\.scale\.profile\t$profile/g" ~/experimentos/HiBench/conf/hibench.conf



for rep in $(seq 1 $nrRepeticoes)
do

	# Inicio de tempo para log
	start_time=`date +%s`

	################################################
	# Testes....
	$HIBENCH/bin/workloads/micro/dfsioe/hadoop/run_write.sh
	#
	################################################

	# Fim de tempo para log
	end_time=`date +%s`

	# Escrita de log
	echo ">> Run $rep >> `expr $end_time - $start_time` s." >> results.txt
	
	#cat /etc/hadoop/hadoop-2.7.3/logs/*-namenode-*.log > "log-nn-$rep.txt"
	#cat /etc/hadoop/hadoop-2.7.3/logs/*-datanode-*.log > "log-dn-$rep.txt"
	#cat /etc/hadoop/hadoop-2.7.3/logs/*-secondarynamenode-*.log > "log-snn-$rep.txt"


done
