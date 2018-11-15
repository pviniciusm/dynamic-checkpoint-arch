
log = open('/home/paulo/results-grid/result-844492/log-nn-4.txt', 'r+')
modified = open('log-modified.txt', 'w')

lines = log.readlines()

for line in lines:
    if "STARTUP_MSG:" in line:
        continue
    elif "org.apache.hadoop.hdfs.StateChange:" in line:
        continue
    elif "BlockStateChange: BLOCK*" in line:
        continue
    else:
        modified.write(line)

log.close()
modified.close()
