#!/bin/bash

HADOOP='/etc/hadoop/hadoop-2.7.3'
ZOOKEEPER='/opt/zookeeper/zookeeper-3.4.10'


# Argumentos
checkpoint=3600
if [ -n "$1" ]; then
        checkpoint=$1
fi

if [ -n "$2" ]; then
        SNN=true
fi

echo "checkpoint period: $checkpoint"

rm /etc/hadoop/hadoop-2.7.3/* -rf
cp ~/hadoop/hadoop-dinamico/* /etc/hadoop/hadoop-2.7.3 -r

echo "hadoop is now dynamic"

$(cat hosts > $HADOOP/etc/hadoop/slaves)
$(head -n 1 hosts > $HADOOP/etc/hadoop/masters)
$(rm $HADOOP/logs/* -rf)

master=$(head -n 1 hosts)
snnhost=$master
if [ $SNN ]; then
	snnhost=$(head -n 2 hosts | tail -1)
fi

echo "$snnhost" > /home/hadoop/snnhost

ssh-keygen -f "/home/hadoop/.ssh/known_hosts" -R 0.0.0.0


sed -i "s/<!--master--><value>.*</\<!--master--\>\<value\>hdfs:\/\/$master:9000\</g" $HADOOP/etc/hadoop/core-site.xml
echo "core site modified"
sed -i "s/<!--host-yarn--><value>.*</\<!--host-yarn--\>\<value\>$master\</g" $HADOOP/etc/hadoop/yarn-site.xml
echo "yarn site modified"
sed -i "s/<!--snn-host--><value>.*</\<!--snn-host--\>\<value\>$snnhost:50090\</g" $HADOOP/etc/hadoop/hdfs-site.xml
echo "snn host is $snnhost"

sed -i "s/self\.host\=.*/self\.host\='$master'/g" /home/hadoop/experimentos/monitor/supervisor.py
echo "supervisor updated"

myidzk=1
for slave in $(cat hosts)
do
	echo "server.$myidzk=$slave:2888:3888" >> $ZOOKEEPER/conf/zoo.cfg
	echo "$myidzk" > /home/hadoop/myidzk
	$(scp -o StrictHostKeyChecking=no /home/hadoop/myidzk hadoop@$slave:/var/lib/zookeeper/myid)
	myidzk=$(expr $myidzk + 1)
done


for slave in $(cat hosts)
do
	
	$(scp -o StrictHostKeyChecking=no -r /etc/hadoop/* hadoop@$slave:/etc/hadoop)
	$(scp -o StrictHostKeyChecking=no $HADOOP/etc/hadoop/*.xml hadoop@$slave:$HADOOP/etc/hadoop)
	$(scp $HADOOP/etc/hadoop/masters hadoop@$slave:$HADOOP/etc/hadoop)
	$(scp $HADOOP/etc/hadoop/slaves hadoop@$slave:$HADOOP/etc/hadoop)

	$(scp $ZOOKEEPER/conf/zoo.cfg hadoop@$slave:$ZOOKEEPER/conf)

	ssh hadoop@$slave sed -i "s/self\.host\=.*/self\.host\='$slave'/g" /home/hadoop/experimentos/monitor/agente.py
	ssh hadoop@$slave sed -i "s/self\.supervisor\=.*/self\.supervisor\='$master'/g" /home/hadoop/experimentos/monitor/agente.py

	echo "$slave: done."
done

$(scp -o StrictHostKeyChecking=no $HADOOP/etc/hadoop/*.xml hadoop@0.0.0.0:$HADOOP/etc/hadoop)
echo "0.0.0.0: done."


echo ""
for slave in $(cat hosts)
do
	ssh hadoop@$slave /opt/zookeeper/zookeeper-3.4.10/bin/zkServer.sh start
	echo "zookeeper (server on $slave) started."
done

sleep 10

/opt/zookeeper/zookeeper-3.4.10/bin/zkServer.sh status
echo ""
echo "done."