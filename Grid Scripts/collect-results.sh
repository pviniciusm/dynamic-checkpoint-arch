#!/bin/bash

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

mkdir "$path/result-$OAR_JOBID-$job"
job_file="$path/jobs-$OAR_JOB_ID/job-$job"
master=$(head -n 1 $job_file)

scp -r hadoop@$master:/home/hadoop/experimentos/results/sn*.log "$path/result-$OAR_JOBID-$job"
scp hadoop@$master:/home/hadoop/experimentos/results.txt "$path/result-$OAR_JOBID-$job"
scp -r hadoop@$master:/home/hadoop/experimentos/Test*.log "$path/result-$OAR_JOBID-$job"
scp hadoop@$master:/home/hadoop/experimentos/*.json "$path/result-$OAR_JOBID-$job"




