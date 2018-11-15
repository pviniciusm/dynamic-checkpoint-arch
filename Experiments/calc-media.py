import statistics as sts
import sys

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

    
    lisst = [int(x.split("=")[-1].split(" ")[1]) for x in data.split("\n") if x is not ""]

    return lisst



if __name__ == "__main__":

    if(len(sys.argv) > 1):
        execution_times = open_file(str(sys.argv[1]))
    else:
        execution_times = open_file("times.txt")

    if(len(sys.argv) > 2):
        baseline = int(sys.argv[2])
    else:
        baseline = 1260

    print("Media: %s" % media(execution_times))
    print("Mediana: %s" % mediana(execution_times))
    print("Desvio padrao: %s" % desvio(execution_times))

    media = sts.mean(execution_times)
    overhead = 100-(baseline*100.00/media)
    print("Overhead: %s" % str(overhead))
