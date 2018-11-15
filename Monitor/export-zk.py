import sys
import json
import time
import socket
import psutil as psu

from kazoo.client import KazooClient
from concurrent.futures import as_completed, ThreadPoolExecutor


MASTER='localhost'

EXPPATH = "/home/hadoop/experimentos"

class Agente(object):

	def __init__(self):

		self.host = MASTER
		self.connect_zk()

		zkdata = self.recurs_export("/")
		tosave = json.dumps(zkdata)

		zkfile = open("zkbackup.json", "w")
		zkfile.write(tosave)
		zkfile.close()
		self.zk.stop()

	def connect_zk(self):
		zkhost = str(self.host)+':2181'
		try:
			self.zk = KazooClient(hosts=zkhost)
			self.zk.start()
		except:
			print("Error at connecting Zookeeper!!")
			sys.exit()

	def recurs_export(self, root, absolute=""):
		if(absolute!=""):
			absolute = absolute + root + "/"
		else: 
			absolute = root

		try:
			zkd, stat = self.zk.get(absolute)
			print("[Exported] "+absolute+" = "+str(zkd))
		except:
			zkd = 0
		
		try:
			zkc = self.zk.get_children(absolute)
			childs = {}
			for ch in zkc:
				childs[str(ch)] = self.recurs_export(str(ch), absolute)
		except:
			pass
		
		dt = [zkd, absolute, childs]

		if(absolute=="/"):
			return {"/":dt}
		
		return dt


if __name__ == "__main__":
	a = Agente()

