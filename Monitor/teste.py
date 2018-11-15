def one():
    print("FUNCAO NUMERO UM")
    return 1

def duos():
    print("FUNCAO NUMERO DUES")
    return 20

def tres():
    print("FUNCAO NUMERO treis")
    return 15

def quarto():
    print("FUNCAO NUMERO UM QUARTO")
    return 46


options = {
    0: one,
    1: duos,
    6: tres,
    10: quarto,
}




numero = 10

x = options[numero]()

print("x is "+str(x))
