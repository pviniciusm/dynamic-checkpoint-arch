#!/bin/bash

failtime=450
sleep $failtime

proce=$(jps | grep -w "NameNode" | cut -d' ' -f1)
kill -9 $proce

sleep 10
/etc/hadoop/hadoop-2.7.3/sbin/hadoop-daemon.sh start namenode
/etc/hadoop/hadoop-2.7.3/bin/hdfs dfsadmin -safemode leave