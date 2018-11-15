#!/bin/bash

# job.sh


# Arguments
for i in "$@"
do
	case $i in
		-j=*|--job=*)
		JOB="${i#*=}"
		;;
		*)
		# unknown option
		;;
	esac
done

path="/home/pcardoso"

# Default values
job=0

# Argument values
if [ $JOB ]; then
	job="$JOB"
fi

job_file="$path/jobs-$OAR_JOB_ID/job-$job"

if [ -e $path/jobs-$OAR_JOB_ID/job-$job ]; then
    kadeploy3 -e ubuntu-spark -f $job_file -k

    master=$(head -n 1 $job_file)

    ssh-keygen -f "$path/.ssh/known_hosts" -R $master
    scp $job_file hadoop@$master:/home/hadoop/hosts

    echo "Success. Here the hosts:"
    ssh hadoop@$master cat /home/hadoop/hosts
else
    echo "Job is not running."
fi

