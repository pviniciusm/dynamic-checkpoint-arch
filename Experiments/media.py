import sys
import statistics as sts

def mediana(execution_times):
    return str(sts.median_grouped(execution_times))

def media(execution_times):
    return str(sts.mean(execution_times))

def desvio(execution_times):
    return str(sts.pstdev(execution_times))

def open_file(path):
    print("Opening file %s ...." % path)

    f = open(path, 'r')
    data = f.read()

    return [int(x.split("=")[-1].split(" ")[1]) for x in data.split("\n") if x is not ""] #and x.split(" ")[1] == "(DF)"]



if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("[error] usage: python media.py <baseline>")
        exit(-1)
    
    baseline = sys.argv[1]
    print("baseline "+str(baseline))
    execution_times = open_file("times.txt")

    print("Media: %s" % media(execution_times))
    print("Mediana: %s" % mediana(execution_times))
    print("Desvio padrao: %s" % desvio(execution_times))

    media = sts.mean(execution_times)
    overhead = 100-(int(baseline)*100.00/media)
    print("Overhead: %s" % str(overhead))
