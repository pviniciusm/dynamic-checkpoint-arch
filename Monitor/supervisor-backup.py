from kazoo.client import KazooClient

import sys
import socket
import time
import psutil as psu
from concurrent.futures import as_completed, ThreadPoolExecutor


class AgentStatus(object):
	
	def __init__(self):
		self.iocount = 0
		self.ramcount = 0
		self.cpucount = 0


	def __init__(self, client):
		self.iocount = 0
		self.ramcount = 0
		self.cpucount = 0

		self.client = client
	
	def io(self):
		return self.iocount
	
	def ram(self):
		return self.ramcount
	
	def setio(self, val):
		self.iocount = val

	def setram(self, val):
		self.ramcount = val




class Agente(object):

	def __init__(self):
		self.shouldRun = True

		self.host="graphene-101.nancy.grid5000.fr"
		self.port = 5000
		self.clients = {}
		self.old_checkpoint = -1

		self.udp = self.create_socket()
		self.udp.bind((self.host, self.port))
		self.connect_zk()
		self.set_newcheckpoint(500)

		self.iometric = self.read_metrics("io.txt")

		while True:
			#print("waiting for contact...")
			try:
				msg, client = self.udp.recvfrom(1024)
			except:
				print("Exiting...")
				self.udp.close()
				self.zk.stop()
				sys.exit()

			if msg == "IN":
				self.ack_to_client(client)
			elif msg.split(':')[0] == "UPDATE":
				try:
					metrics = msg.split(':')[1]
				except:
					print("Message error")
					continue
				self.update(client, metrics)
			elif msg.split(':')[0] == "UPDATE-RAM":
				try:
					metrics = msg.split(':')[1]
				except:
					print("Message error")
					continue
				self.updateram(client, metrics)
			elif msg == "OUT":
				#print("client out")
				self.clients.pop(client)
			else:
				print("Unknown message from "+client)
		self.udp.close()


	def create_socket(self):
		try:
			udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
		except:
			print("Error at creating socket...")
			sys.exit()
		return udp

	def read_metrics(self, filen):
		file_name = 'metrics/'+str(filen)
		with open(file_name, 'r') as f:
			ssf = f.read()
			iometric = eval(ssf)
		return iometric

	def connect_zk(self):
		zkhost = str(self.host)+':2181'
		try:
			self.zk = KazooClient(hosts=zkhost)
			self.zk.start()
		except:
			print("Error at connecting Zookeeper!!")
			sys.exit()


	def set_newcheckpoint(self, value):
		try:
			self.zk.set("/checkpoint/period", str(value))
		except:
			print("Error at setting new checkpoint on Zookeeper!!")


	def ack_to_client(self, client):
		self.udp.sendto("ACK-SERVER", client)
		print("New client: " + str(client))
		cli = AgentStatus(client)
		self.clients[client] = cli


	def alert_spark_ram(self, percent):
		try:
			self.zk.set("/checkpoint/spark/ram", str(percent))
		except:
			print("Error at setting a ram alert for Zookeeper Spark znode!!")


	def updateram(self, client, metrics):
		#verificar se hadoop ta configurado pra aceitar updates de ram
		# ....

		#verificar se spark ta configurado pra aceitar updates de ram
		# ....
		print("SUPERVISOR: it is time to checkpoint some rdd")
		percent = 0.0
		try:
			percent = float(metrics)
		except:
			print("Message error: it is not an integer number")
		self.alert_spark_ram(percent)

	def iofromclients(self):
		sum = 0
		for cl in self.clients:
			sum += self.clients[cl].io()
		return sum

	def update(self, client, metrics):

		new_checkpoint = self.iometric[-1]
		valuefromup = int(metrics)

		self.clients[client].setio(valuefromup)

		valuefromup = self.iofromclients()

		for mval in sorted(self.iometric):
			if(mval < valuefromup): continue
			else: 
				new_checkpoint = self.iometric[mval]
				break

		if self.old_checkpoint == new_checkpoint:
			return

		self.old_checkpoint = new_checkpoint
		print("SUPERVISOR: new checkpoint period is: "+str(new_checkpoint))
		self.set_newcheckpoint(new_checkpoint)




if __name__ == "__main__":
	a = Agente()

