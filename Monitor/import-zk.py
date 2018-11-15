from kazoo.client import KazooClient

import sys
import socket
import time
import psutil as psu
from concurrent.futures import as_completed, ThreadPoolExecutor

import json

MASTER='graphene-24.nancy.grid5000.fr'
EXPPATH = "/home/hadoop/experimentos"


class Agente(object):

	def __init__(self):
		self.shouldRun = True

		self.host = MASTER

		self.connect_zk()


		zkfile = open(EXPPATH+"zkbackup.json", "r")
		zkdata = zkfile.read()
		zkfile.close()

		zkdata =json.loads(str(zkdata))

		self.importall(zkdata, "/")


	def connect_zk(self):
		zkhost = str(self.host)+':2181'
		try:
			self.zk = KazooClient(hosts=zkhost)
			self.zk.start()
		except:
			print("Error at connecting Zookeeper!!")
			sys.exit()

	def importall(self, zkdata, root):
		
		
		for node in zkdata:
			absolute = zkdata[node][1]
			data = zkdata[node][0]

			try:
				if(self.zk.exists(absolute)):
					self.zk.set(absolute, b"{}".format(data))
					print("[Modified] "+absolute+" = "+data)
				else:
					self.zk.create(absolute, b"{}".format(data))
					print("[Created]  "+absolute+" = "+data)
			except:
				print("Error at create!!")
		
			#print(zkdata[node][2])
			self.importall(zkdata[node][2], "")



	def recurs_export(self, root, absolute=""):
		print("get informations about "+root)
		if(absolute!=""):
			absolute = absolute + root + "/"
		#elif(absolute=="/"):
		#	absolute = absolute + root
		else: 
			absolute = root
		print("absolute path is "+absolute)

		try:
			zkd, stat = self.zk.get(absolute)
			print("Data from "+absolute+" is "+str(zkd))
			#zkdata[absolute_path][1] = zkd
		except:
			zkd = 0
			print("No data from "+absolute)
		
		try:
			zkc = self.zk.get_children(absolute)
			print("zNode "+root+" has "+str(len(zkc))+" children: "+str(zkc))
			#children.extend(zkc)

			childs = {}
			
			for ch in zkc:
				childs[str(ch)] = self.recurs_export(str(ch), absolute)
		except:
			print("No child from "+absolute)
		
		dt = [root, absolute, childs]
		#print(dt)
		return dt


if __name__ == "__main__":
	a = Agente()

