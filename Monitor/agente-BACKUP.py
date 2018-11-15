import atexit
import sys
import socket
import time
import psutil as psu
from concurrent.futures import as_completed, ThreadPoolExecutor


class Agente(object):

	def __init__(self):
		self.shouldRun = True
		self.host="localhost"
		self.supervisor="localhost"
		self.supervisor_port=5000

		self.old_cpu = -1
		self.old_ram = -1
		self.old_io = -1

		self.sleep_time = 5
		self.old_io_ps = -1

		self.ram_threshold = 0.4

		#atexit.register(self.stop_monitoring)

		try:
			self.udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
		except:
			print("Error at creating socket...")
			sys.exit()

		self.dest = (self.supervisor, self.supervisor_port)
		self.udp.sendto("IN", self.dest)
		self.executor = ThreadPoolExecutor(max_workers=5)

		print("Agente object created.")
		print("Waiting for supervisor ("+str(self.dest)+") ACK....")
		try:
			msg, client = self.udp.recvfrom(1024)
		except:
			print("\nACK nao recebido")
			sys.exit()

		if msg=="ACK-SERVER":
			print("Successfully connected at Supervisor.")
			pass
		else:
			sys.exit()



	def start_monitoring(self):
		self.shouldRun = True
		time.sleep(3)
		
		#waits = {self.executor.submit(self.take_results, component): component for component in ["io"]}
		self.take_results(["io"])
		

	def stop_monitoring(self):
		self.shouldRun = False
		print("Exiting...")
		self.dest = (self.supervisor, self.supervisor_port)
		self.udp.sendto("OUT", self.dest)

		self.udp.close()
		sys.exit()

	def take_results(self, component="cpu"):
		while True:
			for comp in component:
				result = self.f(component)
				print("Result:\n"+str(result)+"\n")
			time.sleep(self.sleep_time)
		
			

	def cputimes(self):
		t_cpu = psu.cpu_percent(interval=None)
		#self.udp.sendto("UPDATE:"+str(t_cpu), self.dest)
		return "CPU TIMES"

	def ramtimes(self):
		#not using
		#print("Caiu aqui na RAM")
		t_ram = psu.virtual_memory()
		a_ram = t_ram.percent

		if a_ram >= (self.ram_threshold * 100): # threshold * 100 pq o percent tem escala 0 a 100
			self.udp.sendto("UPDATE-RAM:"+str(a_ram), self.dest)
			print("RAM acima do threshold")

		return str(a_ram)

	def iotimes(self):
		
		t_io = psu.disk_io_counters(perdisk=False)
		
		if self.old_io <= 0:
			# do nothing at the first time
			self.old_io = t_io.write_count
			return "No need for changes at the first time"

		# Atualiza em 1 segundo
		self.old_io = t_io.write_count
		time.sleep(2)
		n_t_io = psu.disk_io_counters(perdisk=False)

		new_io_ps = (n_t_io.write_count - self.old_io)/2

		#print(">>>> "+str(new_io_ps))

		if new_io_ps < 25:
			return "No need for changes"

		self.udp.sendto("UPDATE:"+str(new_io_ps), self.dest)
		return "Update sent to supervisor"


	def f(self, x):
		if x == "cpu":
			return self.cputimes()
		elif x == "ram":
			return self.ramtimes()
		else:
			return self.iotimes()


if __name__ == "__main__":
	a = Agente()
	try:
		a.start_monitoring()
	except:
		a.stop_monitoring()

	

