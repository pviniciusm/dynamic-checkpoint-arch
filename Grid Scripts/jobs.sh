#!/bin/bash

# jobs.sh


# Arguments
for i in "$@"
do
	case $i in
		-j=*|--jobs=*)
		JOBS="${i#*=}"
		;;
        -n=*|--nodes=*)
		NODES="${i#*=}"
		;;
		*)
		# unknown option
		;;
	esac
done

# Default values
jobs=1
nodes=8

# Argument values
if [ $JOBS ]; then
	jobs="$JOBS"
fi
if [ $NODES ]; then
	nodes="$NODES"
fi


# Get available nodes
path="/home/pcardoso"
mkdir $path 2>$path/.scr-output
uniq $OAR_NODEFILE > "$path/hosts-$OAR_JOB_ID"
available_nodes=$(cat $path/hosts-$OAR_JOB_ID | wc -l)

if [ "$(expr $jobs \* $nodes)" -gt "$available_nodes" ]; then
    echo "[ERROR]: There are $available_nodes nodes and you want $(expr $jobs \* $nodes )!"
    exit 1
else
    echo "Starting $jobs jobs with $nodes nodes each."
fi

echo ""

mkdir "$path/jobs-$OAR_JOB_ID" 2>$path/.output
rm $path/jobs-$OAR_JOB_ID/* -rf

pointer=0
relative_pointer=0
job=0

#Current jobs
for node in $(cat "$path/hosts-$OAR_JOB_ID"); do
    if [ "$job" -lt "$jobs" ]; then
        if [ "$relative_pointer" -eq 0 ]; then
            echo $node > "$path/jobs-$OAR_JOB_ID/job-$job"
        else 
            echo $node >> "$path/jobs-$OAR_JOB_ID/job-$job"
        fi
        
        pointer=$(expr $pointer + 1)
        relative_pointer=$(expr $relative_pointer + 1)

        if [ "$relative_pointer" -ge "$nodes" ]; then
            echo "Job #$job:"
            cat "$path/jobs-$OAR_JOB_ID/job-$job"
            echo "----"
            echo ""
            job=$(expr $job + 1)
            relative_pointer=0
        fi

    else
        echo "node $node will not be in any job"
    fi

done

