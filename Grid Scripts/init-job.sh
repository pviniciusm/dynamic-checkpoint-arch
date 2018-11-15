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

job_file="$path/jobs-$OAR_JOB_ID/job-$job"

ssh hadoop@$(head -n 1 $job_file)