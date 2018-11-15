import sys
import re
import os, os.path


#delimiter = 'Checkpoint done'
delimiter = 'Roll Edit Log'

if len(sys.argv) < 3:
    print("error")
    exit(-1)

oarjob = str(sys.argv[1])
job = str(sys.argv[2])

path = '/home/pcardoso/result-'+oarjob+'-'+job
nrLogs = len([name for name in os.listdir(path) if re.match('nn[0-9]+.log', name)])

print('There are '+str(nrLogs)+' nn logs')

files = []
lines = []

checkpoints = []
sums = []


for i in range(0,nrLogs):
    files.append(open(path+'/'+'nn'+str(i+1)+'.log', 'r+'))
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
    print("%d checkpoints found on nn%d.log" % (sums[i], i))

sum = 0
#finalmean = mean(checkpoints)
print('\nmean = '+str(checkpoints))

print("\nMean = "+str(float((1.0*checkpoints[-1])/nrLogs)))

