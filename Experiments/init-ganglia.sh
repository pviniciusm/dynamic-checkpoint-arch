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
		*)
		# unknown option
		;;
	esac
done


HADOOP='/etc/hadoop/hadoop-2.7.3'
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


$(cat hosts > $HADOOP/etc/hadoop/slaves)
$(head -n 1 hosts > $HADOOP/etc/hadoop/masters)
$(rm $HADOOP/logs/* -rf)


master=$(head -n 1 hosts)
snnhost=$master
if [ $SNN ]; then
	snnhost=$(head -n 2 hosts | tail -1)
fi

echo "$snnhost" > /home/hadoop/snnhost
echo "$master" > /home/hadoop/master

> /home/hadoop/.ssh/known_hosts

ssh-keygen -f "/home/hadoop/.ssh/known_hosts" -R 0.0.0.0

if [ $dinamico = true ]; then
	cp /home/hadoop/conf/dinamico/*.xml $HADOOP/etc/hadoop
else
	cp /home/hadoop/conf/est/*.xml $HADOOP/etc/hadoop
	sed -i "s/<!--checkpoint-value--><value>[0-9]\+</\<!--checkpoint-value--\>\<value\>$checkpoint\</g" $HADOOP/etc/hadoop/hdfs-site.xml
	echo "checkpoint period modified"
fi


sed -i "s/<!--master--><value>.*</\<!--master--\>\<value\>hdfs:\/\/$master:9000\</g" $HADOOP/etc/hadoop/core-site.xml
echo "core site modified"
sed -i "s/<!--host-yarn--><value>.*</\<!--host-yarn--\>\<value\>$master\</g" $HADOOP/etc/hadoop/yarn-site.xml
echo "yarn site modified"
sed -i "s/<!--snn-host--><value>.*</\<!--snn-host--\>\<value\>$snnhost:50090\</g" $HADOOP/etc/hadoop/hdfs-site.xml
echo "snn host is $snnhost"


#sudo sed -i "s/gmondrechost/$master/g" /etc/ganglia/gmond.conf
#sudo sed -i "s/gmondhost/$master/g" /etc/ganglia/gmond.conf
#sudo sed -i "s/gmondsendhost/$master/g" /etc/ganglia/gmond.conf
#sudo sed -i "s/gangliahost/$master:8649/g" /etc/ganglia/gmetad.conf

#sudo cp /etc/ganglia/gmetad-back.conf /etc/ganglia/gmetad.conf

#echo "lets restart ganglia..."
#sudo service ganglia-monitor restart
#sudo service gmetad restart
#sudo service apache2 restart
#echo "done."

for slave in $(cat hosts)
do	
	$(scp -o StrictHostKeyChecking=no $HADOOP/etc/hadoop/*.xml hadoop@$slave:$HADOOP/etc/hadoop)
	$(scp $HADOOP/etc/hadoop/masters hadoop@$slave:$HADOOP/etc/hadoop)
	$(scp $HADOOP/etc/hadoop/slaves hadoop@$slave:$HADOOP/etc/hadoop)

	scp /home/hadoop/master hadoop@$slave:/home/hadoop
	scp /home/hadoop/snnhost hadoop@$slave:/home/hadoop

done

'''
#for slave in $(tail hosts -n +2)
#do
#	sudo cp /etc/ganglia/gmond.conf.clients /etc/ganglia/gmondtoscp.conf.clients
#	sudo sed -i "s/gmondhost/$slave/g" /etc/ganglia/gmondtoscp.conf.clients
	sudo sed -i "s/gmondsendhost/$master/g" /etc/ganglia/gmondtoscp.conf.clients

	scp /etc/ganglia/gmondtoscp.conf.clients hadoop@$slave:/etc/ganglia/gmond.conf

	echo "$slave: done."
done
'''

$(scp -o StrictHostKeyChecking=no $HADOOP/etc/hadoop/*.xml hadoop@0.0.0.0:$HADOOP/etc/hadoop)
echo "0.0.0.0: done."

'''
echo "wait for ganglia restarting..."
sleep 10
sh /home/hadoop/restart-ganglia.sh
echo "ganglia running."
'''

print "init done."