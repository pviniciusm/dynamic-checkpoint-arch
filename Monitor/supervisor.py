from kazoo.client import KazooClient
from kazoo.recipe import watchers

import sys
import socket
import time
import psutil as psu
import math
import json
from concurrent.futures import as_completed, ThreadPoolExecutor

MASTER='127.0.0.1'

# PATHS
PATH 			  =  "/home/hadoop/experimentos"
MTBF_NODE         =  "/historic/mtbf"
CHECKPOINT_COST   =  "/historic/checkpoint"
CHECKPOINT_PERIOD =  "/checkpoint/period"

# CONSTANTS
RRD_MAX_CHILDRENS=50
PERIOD_THRESHOLD = 5
PERIOD_MINIMAL   = 10
PERIOD_INIT=1000
IS_DYNAMIC_ACTIVE= True


# 1 for young, 2 for daly
APPROXIMATION=1


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

	# INIT CLASS
	def __init__(self, historic):
		self.shouldRun = True
		self.first_alerts = True

		# Supervisor attributes
		self.host = MASTER
		self.port = 5000
		self.clients = {}
		self.old_checkpoint = -1

		# Socket bind
		self.udp = self.create_socket()
		self.udp.bind((self.host, self.port))
		
		# ZK connection
		self.connect_zk()
		self.zk.delete("/checkpoint", recursive=True)
		self.zk.delete("/historic", recursive=True)

		#self.output_log = open(str(PATH)+"/results/output-supervisor.txt", "w")

		if historic is None:
			print "Creating Historic from scratch..."
			self.ensure_paths(CHECKPOINT_COST)
			self.ensure_paths(CHECKPOINT_COST+"/last")
			self.ensure_paths_and_set(CHECKPOINT_PERIOD, PERIOD_INIT)
			self.ensure_paths(MTBF_NODE)
			self.ensure_paths(MTBF_NODE+"/last")
			self.ensure_paths(MTBF_NODE+"/tslf")
			self.ensure_paths_and_set(MTBF_NODE+"/tebi", 0)
			self.old_checkpoint = PERIOD_INIT
			print "Done."
			print "===================================="
		else:
			print "Importing Historic..."
			self.import_historic(historic)
		
			oldc, stats = self.zk.get(CHECKPOINT_PERIOD)
			try:
				self.old_checkpoint = int(oldc)
			except:
				self.old_checkpoint = 0
			print "Done."
			print "===================================="

		self.zk.set(MTBF_NODE+"/tslf", str(time.mktime(time.localtime())))
		
		
		# WATCHERS
		@self.zk.DataWatch(MTBF_NODE+"/last")
		def watch_children(data, stat, event):
			if self.first_alerts:
				return
			#self.newmtbf()
			self.updatemtbf(data)
		
		@self.zk.DataWatch(CHECKPOINT_COST+"/last")
		def watch_cc(data, stat, event):
			if self.first_alerts:
				return
			self.updatecc(data)



		# Static IO metrics
		self.iometric = self.read_metrics("io.txt")

		self.first_alerts = False

		# Main loop
		while True:
			# Message receiver
			try:
				msg, client = self.udp.recvfrom(1024)
			except:
				self.settebi(time.mktime(time.localtime()))
				print("Exiting...")
				self.udp.close()
				self.zk.stop()
				#self.output_log.close()
				sys.exit()

			# Message parsing
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
			elif msg.split(':')[0] == "UPDATE-CC":
				try:
					metrics = msg.split(':')[1]
				except:
					print("Message error")
					continue
				self.updatecc(metrics)
			elif msg.split(':')[0] == "UPDATE-MTBF":
				try:
					metrics = msg.split(':')[1]
				except:
					print("Message error")
					continue
				self.updatemtbf(metrics)	
			elif msg == "OUT":
				self.clients.pop(client)
				print("Client "+str(client)+" has stopped.")
			else:
				print("Unknown message from "+client)
		self.udp.close()







	# AUXILIAR METHODS
	def settebi(self, value):
		try:
			data, stat = self.zk.get(MTBF_NODE+"/tslf")
			data = int(float(data))

			tebi = int(float(value)) - data
			if(tebi <= 0):
				return
			
			self.zk.set(MTBF_NODE+"/tebi", str(tebi))
		except:
			print("Error at updating TEBI")

	def create_socket(self):
		try:
			udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
		except:
			print("Error at creating socket...")
			sys.exit()
		return udp

	def read_metrics(self, filen):
		file_name = str(PATH)+"/monitor/metrics/"+str(filen)
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
			
	def exists(self, path):
		if not self.zk.exists(path):
			print("Path "+path+" does not exist on zookeeper!")
			return False
		return True
	
	def set_newdata(self, path, value):
		try:
			self.zk.set(path, str(value))
		except:
			print("Error at setting new data on Zookeeper!!")

	def set_newcheckpoint(self, value):
		self.set_newdata(CHECKPOINT_PERIOD, value)

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

	def iofromclients(self):
		sum = 0
		for cl in self.clients:
			sum += self.clients[cl].io()
		return sum
	
	def ensure_paths(self, path):
		self.zk.ensure_path(path)
		try:
			data, stat = self.zk.get(path)
			#x = float(data)
		except:
			self.zk.set(path, b'0')
	
	def ensure_paths_and_set(self, path, value):
		try:
			data, stat = self.zk.get(path)
			x = float(data)
		except:
			self.zk.ensure_path(path)
			self.zk.set(path, str(value))


	# Historic import
	def import_historic(self, historic):
		try:
			hist_file = open(historic, "r")
			historic = hist_file.read()
			hist_file.close()

			historic = json.loads(str(historic))
		except:
			print "Error: historic json not loaded"
			return
		self.importall(historic, "/")

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
			self.importall(zkdata[node][2], "")



	# OPTIMAL CHECKPOINT PERIOD APPROACHES
	def young(self, c, m):
		try:
			period = math.sqrt(2*c*m)
		except:
			print("[ERROR] argument error on young formula.")
			period = -1
		return period

	def daly_firstorder(self, c, m, r):
		try:
			period = math.sqrt(2*c*(m+r))
		except:
			print("[ERROR] argument error on young formula.")
			period = -1
		return period

	def daly_highorder(self, c, m):
		c = float(c)
		m = float(m)
		try:
			if(c>=(2*m)): 
				period = m
				return m
			pfh = math.sqrt(2*m*c)
			psh = 1+((1/3)*(c/(2*m))**(1/2))+((1/9)*(c/(2*m)))

			period = pfh*psh-c
		except:
			period = -1
		return period


	# GET CURRENT DATA ON ZOOKEEPER HISTORIC
	def checkpoint_cost(self):
		cost = self.average_historic(CHECKPOINT_COST)
		print("Current checkpoint cost is: "+cost)

	def mean_time_between_failure(self):
		cost = self.average_historic(MTBF_NODE)
		print("Current MTBF is: "+cost)

	def average_historic(self, path):
		if not self.exists(path): return -1

		children = self.zk.get_children(path)
		if len(children) <= 0: return -1

		sum = 0
		count = 0
		for child in children:
			if not str(child).startswith('zn'):
				continue
			zkdata, stat = self.zk.get(path+"/"+str(child))
			sum = sum + float(zkdata)
			count = count + 1
		
		if count <= 0:
			print("Error: count is 0")
			return -1

		return sum/count


	# HISTORIC UPDATE
	def historic_update(self, path, value):
		if not self.zk.exists(path): return -1

		# Obtain current node, current time since last failure and time elapsed before interrupt
		current, stat = self.zk.get(path)

		try:
			next_znode = int(float(current)) + 1
		except:
			next_znode = 0

		if next_znode >= RRD_MAX_CHILDRENS:
			next_znode = 0
		
		next_path = path+"/zn"+str(next_znode)
		self.zk.ensure_path(next_path)
		
		# New value
		new_value = int(float(value))

		# Set the new value
		self.zk.set(next_path, str(new_value))
		self.zk.set(path, str(next_znode))
		




	# MONITORING ELEMENTS UPDATE
	def updateram(self, client, metrics):
		percent = 0.0
		try:
			percent = float(metrics)
		except:
			print("Message error: it is not an integer number")
		self.alert_spark_ram(percent)	


	'''
		update(): updates client i/o information and calculates a new checkpoint period
		args:
		  client:   client which send new i/o rate
		  metrics:  new i/o rate obtained
		returns:
		  nothing, but updates znode
	'''
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


	'''
		updatecc(): updates checkpoint cost information from hadoop snn host
		args:
		  value: new checkpoint cost
		returns:
		  nothing, but updates znode
	'''
	def updatecc(self, value):
		self.historic_update(CHECKPOINT_COST, value)
		if(IS_DYNAMIC_ACTIVE):
			self.update_checkpoint(self.average_historic(CHECKPOINT_COST), -1)
	
	def updatemtbf(self, value):
		try:
			tslf, stat_tslf = self.zk.get(MTBF_NODE+'/tslf')
			tebi, stat_tebi = self.zk.get(MTBF_NODE+'/tebi')

			tslf = int(float(tslf))
			tebi = int(float(tebi))
		except:
			print "tslf and tebi not defined"
			return

		# Time since last failure
		new_value = int(float(value)) - tslf + tebi
		self.historic_update(MTBF_NODE, new_value)
		
		# Set last time failure as now
		self.zk.set(MTBF_NODE+'/tslf', str(value))

		# Set empty any failure time dependency 
		self.zk.set(MTBF_NODE+'/tebi', str(0))

		if(IS_DYNAMIC_ACTIVE):
			self.update_checkpoint(-1, self.average_historic(MTBF_NODE))
	

	def newmtbf(self):
		#print (self.average_historic(MTBF_NODE))
		if(IS_DYNAMIC_ACTIVE):
			self.update_checkpoint(-1, -1)
	

	'''
		update_checkpoint(): set a new checkpoint period based on
			checkpoint costs and mean time between failure stored
			on zookeeper historic
		args:
			cost: last checkpoint cost (-1 for unknown)
			mtbf: last mean time between failure (-1 for unknown)
		returns:
			nothing, zookeeper znodes are updated
	'''
	
	def update_checkpoint(self, cost, mtbf):
		# Retrieve checkpoint cost and MTBF from historic
		if cost < 0:
			cost = self.average_historic(CHECKPOINT_COST)
		if mtbf < 0:
			mtbf = self.average_historic(MTBF_NODE)
		
		# Choose what checkpoint policy must be used
		if APPROXIMATION == 1:
			new_check = int(self.young(float(cost)/1000, float(mtbf)))	
		else:
			new_check = int(self.daly_highorder(float(cost)/1000, float(mtbf)))
		
		# Previne value errors
		if new_check < 0:
			print "ERROR: Checkpoint less than 0 -> "+str(new_check)
			return
		if new_check < PERIOD_MINIMAL:
			new_check = PERIOD_MINIMAL
		
		# Control period updates
		if new_check == self.old_checkpoint:
			print "Same checkpoint period -> "+str(new_check)
			return
		if abs(new_check - self.old_checkpoint) < PERIOD_THRESHOLD:
			print "New checkpoint diff is less than threshold ("+str(PERIOD_THRESHOLD)+") -> "+str(new_check)
			return

		# Set a new checkpoint period if everything is ok
		self.old_checkpoint = new_check

		print("New checkpoint period: "+str(new_check))
		self.set_newcheckpoint(new_check)

	


if __name__ == "__main__":
	historic = None
	if len(sys.argv) > 1:
		historic = str(sys.argv[1])
	a = Agente(historic)

