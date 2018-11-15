from kazoo.client import KazooClient
import sys
import socket
import time
import subprocess as sbp
import os
import datetime
import time
import random

MASTER='127.0.0.1'

def zkexists(zk, path):
    if not zk.exists(path):
        print("Path "+path+" does not exist on zookeeper!")
        return False
    return True
    

def average_historic(path, zk):
    children = zk.get_children(path)
    if len(children) <= 0: return -1

    sum = 0
    count = 0
    for child in children:
        if not str(child).startswith('zn'):
            continue
        zkdata, stat = zk.get(path+"/"+str(child))
        sum = sum + float(zkdata)
        count = count + 1
    
    if count <= 0:
        print("Error: count is 0")
        return -1

    return sum/count

        
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
    CC_NODE = "/historic/checkpoint"

    cost = average_historic(CC_NODE, zk)

    res_file = open("/home/hadoop/experimentos/results/cc-costs.txt", "a+")
    res_file.write(str(cost)+"\n")
    res_file.close()



    zk.stop()



if __name__ == "__main__":
	run()