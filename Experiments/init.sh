#!/bin/bash

# Argumentos
for i in "$@"
do
	case $i in
		-d|--din)
		DIN=true
		;;
		-s|--snn)
		SNNHOST=true
		;;
		-c=*|--checkpoint=*)
		PERIOD="${i#*=}"
		;;
		-mc=*|--max-child=*)
		MAX_CHILD="${i#*=}"
		;;
		-fs=*|--failure-scenario=*)
		FAILURE_SCE="${i#*=}"
		;;
		-app=*|--approximation=*)
		APPROX="${i#*=}"
		;;
		*)
		# unknown option
		;;
	esac
done

SPARK='/etc/spark/spark-2.2.0'
HADOOP='/etc/hadoop/hadoop-2.7.3'
EXPPATH='/home/hadoop/experimentos'
ZOOKEEPER='/opt/zookeeper/zookeeper-3.4.10'


echo "Init all services..."


checkpoint=3600
if [ $PERIOD ]; then
        checkpoint=$PERIOD
		echo "- Checkpoint Period: $checkpoint"
fi

SNN=false
if [ $SNNHOST ]; then
        SNN=true
		echo "- SNN is on another host."
fi

dinamico=false
if [ $DIN ]; then
        dinamico=true
		echo "- Dynamic Config is activated."
fi

max_child=20
if [ $MAX_CHILD ]; then
        max_child=$MAX_CHILD
		echo "- RRD Max child: $max_child."
fi

failure_scenario=1
if [ $FAILURE_SCE ]; then
        failure_scenario=$FAILURE_SCE
		echo "- Failure scenario: $failure_scenario."
fi

approximation=1
if [ $APPROX ]; then
        approximation=$APPROX
		echo "- Approximation: $approximation."
fi

# Hadoop....
$(cat hosts > $HADOOP/etc/hadoop/slaves)
$(head -n 1 hosts > $HADOOP/etc/hadoop/masters)
$(rm $HADOOP/logs/* -rf)

# Spark....
$(cat hosts > $SPARK/conf/slaves)
$(head -n 1 hosts > $SPARK/conf/masters)
$(rm $SPARK/logs/* -rf)


master=$(head -n 1 hosts)
slaves=$(cat hosts | tr "\n" " ")
snnhost=$master
if [ $SNNHOST ]; then
	snnhost=$(head -n 2 hosts | tail -1)
fi

echo "$snnhost" > /home/hadoop/snnhost
echo "$master" > /home/hadoop/master

> /home/hadoop/.ssh/known_hosts

ssh-keygen -f "/home/hadoop/.ssh/known_hosts" -R 0.0.0.0

if [ $dinamico = true ]; then
	cp /home/hadoop/conf/dinamico/*.xml $HADOOP/etc/hadoop
	sed -i "s/PERIOD_INIT\=.*/PERIOD_INIT\=\'$checkpoint\'/g" $EXPPATH/monitor/supervisor.py
	sed -i "s/IS_DYNAMIC_ACTIVE\=.*/IS_DYNAMIC_ACTIVE\=True/g" $EXPPATH/monitor/supervisor.py
	#IS_DYNAMIC_ACTIVE
else
	sed -i "s/PERIOD_INIT\=.*/PERIOD_INIT\=\'$checkpoint\'/g" $EXPPATH/monitor/supervisor.py
	sed -i "s/IS_DYNAMIC_ACTIVE\=.*/IS_DYNAMIC_ACTIVE\=False/g" $EXPPATH/monitor/supervisor.py
	cp /home/hadoop/conf/dinamico/*.xml $HADOOP/etc/hadoop
	#sed -i "s/<!--checkpoint-value--><value>[0-9]\+</\<!--checkpoint-value--\>\<value\>$checkpoint\</g" $HADOOP/etc/hadoop/hdfs-site.xml
	echo "checkpoint period modified"
fi


# Hadoop xml....
sed -i "s/<!--master--><value>.*</\<!--master--\>\<value\>hdfs:\/\/$master:9000\</g" $HADOOP/etc/hadoop/core-site.xml
echo "core site modified"
sed -i "s/<!--host-yarn--><value>.*</\<!--host-yarn--\>\<value\>$master\</g" $HADOOP/etc/hadoop/yarn-site.xml
echo "yarn site modified"
sed -i "s/<!--snn-host--><value>.*</\<!--snn-host--\>\<value\>$snnhost:50090\</g" $HADOOP/etc/hadoop/hdfs-site.xml
echo "snn host is $snnhost"
sed -i "s/<!--zk-host--><value>.*</\<!--zk-host--\>\<value\>$master:2181\</g" $HADOOP/etc/hadoop/hdfs-site.xml
echo "zk host is $master"


# Supervisor....
sed -i "s/MASTER\=.*/MASTER\=\'$master\'/g" $EXPPATH/monitor/supervisor.py
sed -i "s/MASTER\=.*/MASTER\=\'$master\'/g" $EXPPATH/failures.py
sed -i "s/MASTER\=.*/MASTER\=\'$master\'/g" $EXPPATH/exportzk.py
sed -i "s/RRD_MAX_CHILDRENS\=.*/RRD_MAX_CHILDRENS\=$max_child/g" $EXPPATH/monitor/supervisor.py
sed -i "s/RRD_MAX_CHILDRENS\=.*/RRD_MAX_CHILDRENS\=$max_child/g" $EXPPATH/failures.py
sed -i "s/CF\=.*/CF\=$failure_scenario/g" $EXPPATH/failures.py
sed -i "s/APPROXIMATION\=.*/APPROXIMATION\=$approximation/g" $EXPPATH/monitor/supervisor.py

# HiBench....
sed -i "s/hibench\.hdfs\.master.*/hibench\.hdfs\.master\thdfs:\/\/$master:9000/g" ~/experimentos/HiBench/conf/hadoop.conf
sed -i "s/hibench\.spark\.master.*/hibench\.spark\.master\tspark:\/\/$master:7077/g" ~/experimentos/HiBench/conf/spark.conf
sed -i "s/hibench\.masters\.hostnames.*/hibench\.masters\.hostnames\t$master/g" ~/experimentos/HiBench/conf/hibench.conf
sed -i "s/hibench\.slaves\.hostnames.*/hibench\.slaves\.hostnames\t$slaves/g" ~/experimentos/HiBench/conf/hibench.conf

# ZK id
myidzk=1

# Scp for slaves....
for slave in $(cat hosts)
do	
	# Hadoop xml
	scp -o StrictHostKeyChecking=no $HADOOP/etc/hadoop/core-site.xml hadoop@$slave:$HADOOP/etc/hadoop
	scp $HADOOP/etc/hadoop/core-site.xml hadoop@$slave:$HADOOP/etc/hadoop
	scp $HADOOP/etc/hadoop/hdfs-site.xml hadoop@$slave:$HADOOP/etc/hadoop
	scp $HADOOP/etc/hadoop/yarn-site.xml hadoop@$slave:$HADOOP/etc/hadoop
	scp $HADOOP/etc/hadoop/mapred-site.xml hadoop@$slave:$HADOOP/etc/hadoop

	# Hadoop master slaves
	scp $HADOOP/etc/hadoop/masters hadoop@$slave:$HADOOP/etc/hadoop
	scp $HADOOP/etc/hadoop/slaves hadoop@$slave:$HADOOP/etc/hadoop

	# Spark env
	scp $SPARK/conf/spark-env.sh hadoop@$slave:$SPARK/conf

	# Spark master slaves
	scp $SPARK/conf/masters hadoop@$slave:$SPARK/conf
	scp $SPARK/conf/slaves hadoop@$slave:$SPARK/conf

	# Global master slaves
	scp /home/hadoop/master hadoop@$slave:/home/hadoop
	scp /home/hadoop/snnhost hadoop@$slave:/home/hadoop

	# HDFS data clear
	ssh hadoop@$slave rm -rf /tmp/hadoop-hadoop/*

	# Agents
	ssh hadoop@$slave sed -i "s/MASTER\=.*/MASTER\=\'$master\'/g" /home/hadoop/experimentos/monitor/agente.py
	ssh hadoop@$slave sed -i "s/HOST\=.*/HOST\=\'$slave\'/g" /home/hadoop/experimentos/monitor/agente.py

	# ZK copy files
	echo "server.$myidzk=$slave:2888:3888" >> $ZOOKEEPER/conf/zoo.cfg
	echo "$myidzk" > /home/hadoop/myidzk
	scp -o StrictHostKeyChecking=no /home/hadoop/myidzk hadoop@$slave:/var/lib/zookeeper/myid
	myidzk=$(expr $myidzk + 1)

	# Done...
	echo "$slave: done."
done

# 00 host check
scp -o StrictHostKeyChecking=no $HADOOP/etc/hadoop/hdfs-site.xml hadoop@0.0.0.0:$HADOOP/etc/hadoop
echo "0.0.0.0: done."


# Zookeeper start
for slave in $(cat hosts)
do
	scp $ZOOKEEPER/conf/zoo.cfg hadoop@$slave:$ZOOKEEPER/conf
	ssh hadoop@$slave /opt/zookeeper/zookeeper-3.4.10/bin/zkServer.sh start
	echo "zookeeper (server on $slave) started."
	sleep 2

	#ssh hadoop@slave $(nohup python /home/hadoop/experimentos/monitor/agente.py &)
	#echo "external agent of $slave started."
done

sleep 10

# Format HDFS
$HADOOP/bin/hdfs namenode -format
sleep 2

echo "init done."