from kazoo.client import KazooClient
#import sys
#import socket
import time
import subprocess as sbp
import os
import datetime
import time

RRD_MAX_CHILDRENS = 3
MTBF_NODE = "/historic/mtbf"

def zkexists(zk, path):
    if not zk.exists(path):
        print("Path "+path+" does not exist on zookeeper!")
        return False
    return True 

def connect_zk(zkhost, port=0):
    zkhost = str(zkhost)+':2181'
    zk = KazooClient(hosts=zkhost)
    try:
        zk.start()
    except:
        print("Error at connecting Zookeeper!!")
        sys.exit()

    return zk

def close_tebi(zk, path, value):
    if not zkexists(zk, path+"/tslf"): return -1
    
    tslf, stat_tslf = zk.get(path+'/tslf')
    try:
        tslf = int(float(tslf))
    except:
        print "Error at close tebi - tslf"

    new_tebi = int(float(value)) - tslf

    zk.set(path+"/tebi", str(new_tebi))


def run():
    zk = connect_zk("127.0.0.1", 5000)
    

    #historic_update(zk, MTBF_NODE, str(time.mktime(time.localtime())))
    close_tebi(zk, MTBF_NODE, str(time.mktime(time.localtime())))
    
    zk.stop()



if __name__ == "__main__":
	run()