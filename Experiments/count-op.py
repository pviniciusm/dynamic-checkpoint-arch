import re
import os, os.path
from statistics import mean

delimiter = 'INFO org.apache.hadoop.hdfs.server.namenode.FSImage: Edits file'

path = '/home/paulo/results-grid/WPerformance/'
prefix = 'result-846804/'
nrLogs = len([name for name in os.listdir(path+prefix) if re.match('log-nn-[0-9]+.txt', name)])

files = []
lines = []

operations = []

for i in range(0,nrLogs):
    files.append(open(path+prefix+'log-nn-'+str(i+1)+'.txt', 'r+'))
    lines.append(files[i].readlines())

    for line in lines[i]:
        if not delimiter in line:
            continue
        
        operation = line.split(' ')[-5]
        print('operation = '+operation)
        operations.append(int(operation))
    
    files[i].close()

sum = 0
#for op in operations:
finalmean = mean(operations)
print('\nmean = '+str(finalmean))

