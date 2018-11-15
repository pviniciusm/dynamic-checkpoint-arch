from kazoo.client import KazooClient
import sys
import socket
import time
import subprocess as sbp
import os
import datetime
import time
import random

RRD_MAX_CHILDRENS=20

MASTER='127.0.0.1'

CF=1
#FAILURE_SCENARIO=CF

def zkexists(zk, path):
    if not zk.exists(path):
        print("Path "+path+" does not exist on zookeeper!")
        return False
    return True

def historic_update(zk, path, value):
    if not zkexists(zk, path): return -1

    # Obtain current node, current time since last failure and time elapsed before interrupt
    current, stat = zk.get(path)
    tslf, stat_tslf = zk.get(path+'/tslf')
    tebi, stat_tebi = zk.get(path+'/tebi')

    try:
        next_znode = int(float(current)) + 1
    except:
        next_znode = 0
    tslf = int(float(tslf))
    tebi = int(float(tebi))

    if next_znode >= RRD_MAX_CHILDRENS:
        next_znode = 0
    
    next_path = path+"/zn"+str(next_znode)
    zk.ensure_path(next_path)
    
    # Time between this and last failure is 
    # time since last observation added time of previous observations
    new_value = int(float(value)) - tslf + tebi

    #print("new value is = " + str(value) + " - " + str(tslf) + " + " + str(tebi))

    # Set a new MTBF value
    zk.set(next_path, str(new_value))
    
    # Set new current child zn of MTBF
    zk.set(path, str(next_znode))
    
    # Set last time failure as now
    zk.set(path+'/tslf', str(value))

    # Set empty any failure time dependency 
    zk.set(path+'/tebi', str(0))

def update_last_mtbf(zk, path, value):
    if not zkexists(zk, path): 
        print "Error: path does not exist."
        return -1
    
    zk.set(path, str(value))
    


def connect_zk(zkhost, port=0):
    zk = KazooClient(hosts=zkhost)
    try:
        zk.start()
    except:
        print("Error at connecting Zookeeper!!")
        sys.exit()

    return zk


def run():
    zk = connect_zk(MASTER, 5000)
    MTBF_NODE = "/historic/mtbf"

    FAILURE_SCENARIO=CF

    if FAILURE_SCENARIO==1:
        failtime = 450
    elif FAILURE_SCENARIO==2:
        failtime = 920
    else:
        failtime = random.randint(450,920)

    # Sleep N secons and induce failure
    sbp.call(["sleep", str(failtime)])

    try:
        NNprocess = int(os.popen("jps | grep -w 'NameNode' | cut -d' ' -f1").read().split('\n')[0].split(' ')[0])
        sbp.call(["kill", "-9", str(NNprocess)])
        current_time = str(time.mktime(time.localtime()))
        print "NameNode kill done."
    except:
        print "Error - NN kill not successfull."
        zk.stop()
        sys.exit()

    # Wait 10 seconds to NN wake up
    sbp.call(["sleep", "10"])
    sbp.call(["/etc/hadoop/hadoop-2.7.3/sbin/hadoop-daemon.sh", "start", "namenode"])
    sbp.call(["/etc/hadoop/hadoop-2.7.3/bin/hdfs", "dfsadmin", "-safemode", "leave"])

    #historic_update(zk, MTBF_NODE, str(time.mktime(time.localtime())))
    update_last_mtbf(zk, MTBF_NODE+"/last", str(time.mktime(time.localtime())))
    
    zk.stop()



if __name__ == "__main__":
	run()