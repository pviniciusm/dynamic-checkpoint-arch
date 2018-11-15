#!/bin/bash

# Argumentos
for i in "$@"
do
	case $i in
		-F|--fault)
		FAULT=true
		;;
		-e=*|--executorm=*)
		EXECUTORM="${i#*=}"
		;;
		-p=*|--profile=*)
		PROFILES="${i#*=}"
		;;
		*)
		# unknown option
		;;
	esac
done

fault=false
profile="large"
executor="1g"

if [ $FAULT ]; then
	fault="$FAULT"
fi
if [ $EXECUTORM ]; then
	executor="$EXECUTORM"
fi
if [ $PROFILES ]; then
	profile="$PROFILES"
fi

echo "fault is $fault"
echo "executor memory is $executor"
echo "profile is $profile"


sed -i "s/profile=.*/profile=\"$profile\"/g" ~/experimentos/pagerank.sh
sed -i "s/executor=.*/executor=\"$executor\"/g" ~/experimentos/pagerank.sh
sed -i "s/fault=.*/fault=\"$fault\"/g" ~/experimentos/pagerank.sh
