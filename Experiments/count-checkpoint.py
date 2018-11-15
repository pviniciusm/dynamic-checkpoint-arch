import re
import os, os.path
from statistics import mean

delimiter = 'Roll Edit Log'


path = '/home/paulo/results-grid/WPerformance/'
prefix = 'result-846802/'
nrLogs = len([name for name in os.listdir(path+prefix) if re.match('log-nn-[0-9]+.txt', name)])

print('there are '+str(nrLogs)+' logs')

files = []
lines = []

checkpoints = []
sums = []


for i in range(0,nrLogs):
    files.append(open(path+prefix+'log-nn-'+str(i+1)+'.txt', 'r+'))
    lines.append(files[i].readlines())

    sums.append(0)

    for line in lines[i]:
        if not delimiter in line:
            continue

        #checkpoint = line.split(' ')[-5]
        ##print('checkpoint = '+checkpoint)
        #checkpoints.append(int(checkpoint))
        sums[i] = sums[i] + 1
    
    checkpoints.append(sums[i])

    files[i].close()

sum = 0
finalmean = mean(checkpoints)
print('\nmean = '+str(finalmean))

