SPARK='/etc/spark/spark-2.2.0'

workload="tiny"

if [ -n "$1" ]; then
        workload=$1
fi

echo "workload is $workload"
sed -i "s/hibench\.scale\.profile.*/hibench\.scale\.profile\t$workload/g" ~/experimentos/HiBench/conf/hibench.conf
echo "done."