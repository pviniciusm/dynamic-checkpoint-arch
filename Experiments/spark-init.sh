#!/bin/bash

SPARK='/etc/spark/spark-2.2.0'

$(cat hosts > $SPARK/conf/slaves)
$(head -n 1 hosts > $SPARK/conf/masters)
$(rm $SPARK/logs/* -rf)

master=$(head -n 1 hosts)
slaves=$(cat hosts | tr "\n" " ")

#ssh-keygen -f "/home/hadoop/.ssh/known_hosts" -R 0.0.0.0

sed -i "s/hibench\.hdfs\.master.*/hibench\.hdfs\.master\thdfs:\/\/$master:9000/g" ~/experimentos/HiBench/conf/hadoop.conf
sed -i "s/hibench\.spark\.master.*/hibench\.spark\.master\tspark:\/\/$master:7077/g" ~/experimentos/HiBench/conf/spark.conf
sed -i "s/hibench\.masters\.hostnames.*/hibench\.masters\.hostnames\t$master/g" ~/experimentos/HiBench/conf/hibench.conf
sed -i "s/hibench\.slaves\.hostnames.*/hibench\.slaves\.hostnames\t$slaves/g" ~/experimentos/HiBench/conf/hibench.conf


for slave in $(cat hosts)
do
	$(scp -o StrictHostKeyChecking=no $SPARK/conf/spark-env.sh hadoop@$slave:$SPARK/conf)
	$(scp $SPARK/conf/masters hadoop@$slave:$SPARK/conf)
	$(scp $SPARK/conf/slaves hadoop@$slave:$SPARK/conf)

	echo "$slave: done."
done

$(scp -o StrictHostKeyChecking=no $SPARK/conf/slaves hadoop@0.0.0.0:$SPARK/conf)
echo "0.0.0.0: done."
