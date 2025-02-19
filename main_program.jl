using LinearAlgebra
using DataFrames
using CSV
using StatsPlots
using SparseArrays

##---------------------------------------------------------------------------
# Calcular la matriz de admitancia nodal sin considerar transformadores

"""Ejemplo hecho en clase"""

function calcular_ybus(lin, nod) # Función para calcular la matriz de admitancias nodales
    """
    Entradas: lin: DataFrame
              nod: DataFrame
    Salidas:  Ybus: Matriz
    """
    num_nod = nrow(nod) # Número de nodos  
    num_lin = nrow(lin) # Número de líneas
    ybus = zeros(num_nod, num_nod) * 1im # Matriz de admitancias nodales
    for k in 1:num_lin # Se recorre cada línea
        n1 = lin.FROM[k] # Nodo de inicio
        n2 = lin.TO[k] # Nodo final
        yL = 1 / (lin.R[k] + lin.X[k] * 1im) # Admitancia de la línea
        Bs = lin.B[k] * 1im / 2 # Admitancia shunt

        ybus[n1, n1] += yL + Bs # Diagonal
        ybus[n1, n2] -= yL # Fuera
        ybus[n2, n1] -= yL # Fuera
        ybus[n2, n2] += yL + Bs # Diagonal
    end
    return ybus
end

## Función principal que
lin = DataFrame(CSV.File("lines.csv")) # Datos de las líneas
nod = DataFrame(CSV.File("nodes.csv")) # Datos de los nodos
ybus1 = calcular_ybus(lin, nod) # Matriz de admitancias nodales sin transformadores

"""EJEMPLO VISTO EN CLASE"""
##---------------------------------------------------------------------------

"""ahora se crea una nueva funcion para agregar los transformadores en su posicion de tap en la Ybus"""

##___________________________________________________________________________

# Calcular la matriz de admitancia con transformadores
function calcular_ybus_2(lin, nod) # Función para calcular la matriz de admitancias con transformadores

    num_nod = nrow(nod) # Número de nodos
    num_lin = nrow(lin) # Número de líneas
    Ybus = zeros(num_nod, num_nod) * 1im # Matriz de admitancias 

    for k = 1:num_lin # Se recorre cada línea del sistema
        n1 = lin.FROM[k] # Nodo de inicio
        n2 = lin.TO[k] # Nodo final
        tap = lin.TAP[k] # Relación de transformación

        """Se añade la condición para los transformadores"""

        if tap != 0 # Se detecta si hay un transformador
            yL = 1 / (lin.R[k] + lin.X[k] * 1im) # Admitancia de la línea 
            Bs = (1 - tap) * yL           # Admitancia shunt del BT
            Bs2 = (tap^2 - tap) * yL      # Admitancia shunt del AT
            
            # Elementos de la matriz Ybus con transformadores
            Ybus[n1, n1] += yL*tap + Bs            # Diagonal 
            Ybus[n1, n2] -= yL*tap            # Fuera de la diagonal
            Ybus[n2, n1] -= yL*tap            # Fuera de la diagonal
            Ybus[n2, n2] += yL*tap + Bs2           # Diagonal 

        else # si no se detecta el transformador
            yL = 1 / (lin.R[k] + lin.X[k] * 1im) # Admitancia de la línea
            Bs = lin.B[k] * 1im / 2 # Admitancia shunt

            Ybus[n1, n1] += yL + Bs       # Diagonal
            Ybus[n1, n2] -= yL            # Fuera de la diagonal
            Ybus[n2, n1] -= yL            # Fuera de la diagonal
            Ybus[n2, n2] += yL + Bs       # Diagonal
        end
    end

    return Ybus
end
##___________________________________________________________________________

"""ahora se crean las funciones necesarias para los parametros del flujo de carga DC""" 

##___________________________________________________________________________
function carga_datos() # Función para cargar los datos

    # Importando los datos y creando los DataFrames
    lin = DataFrame(CSV.File("lines.csv")) # Datos de las líneas
    nod = DataFrame(CSV.File("nodes.csv")) # Datos de los nodos
    num_nod = nrow(nod) # Número de nodos
    num_lin = nrow(lin) # Número de líneas
    
    return lin, nod, num_lin, num_nod # Se retornan los DataFrames y el número de nodos y líneas
end
##___________________________________________________________________________
function crear_Ykm(lin) # Función para crear la matriz de admitancias
    num_nod = nrow(nod) # Número de nodos 
    num_lin = nrow(lin) # Número de líneas
    
    Ykm = zeros(num_nod, num_nod) # Matriz de admitancias
    
    for i in 1:num_lin # Se recorre cada línea
        k = lin.FROM[i] # Nodo de inicio
        m = lin.TO[i] # Nodo final
        Y_km =  1 / (lin.X[i]) # Admitancia de la línea
        Ykm[k, m] = Ykm[k, m] - Y_km # Fuera
        Ykm[m, k] = Ykm[m, k] - Y_km # Fuera
        Ykm[k, k] = Ykm[k, k] + Y_km # Diagonal
        Ykm[m, m] = Ykm[m, m] + Y_km # Diagonal
    end
    return Ykm # Se retorna la matriz de admitancias
end
##___________________________________________________________________________
function crear_vector_P(lin, nod) # Función para crear el vector de potencias
    num_nod = nrow(nod) # Número de nodos ------> num_nod = maximum(vcat(lin.From, lin.To)) # Número de nodos 
    P = zeros(num_nod) # Vector de potencias
    Sbase = 100 # Potencia base Mva
    for i in 1:num_nod # Se recorre cada nodo
        Pd = nod.PLOAD[i] # Carga
        Pg = nod.PGEN[i] # Generación
        P[i] = Pg - Pd # Potencia neta
    end
    P = P / Sbase # Se normaliza la potencia
    return P
end
##___________________________________________________________________________
function flujo_potencia_DC(Ykm, P, num_lin, num_nod, lin) # Funbción para el flujo de potencia
    slack = findfirst(nod.ANG .== 0) # Nodo slack -------------> #slack = 1 # Nodo slack
    dslack = 0 # Voltaje en el nodo slack
    num_lin = num_lin # Número de líneas
    num_nod = num_nod # Número de nodos
    Ykm = Ykm # Matriz de admitancias
    P = P # Vector de potencias
    nodos = setdiff(1:num_nod, slack) # Nodos sin slack ---------------> #nodos = [i for i in 1:num_nod if i != slack] o #nodos = filter(x -> x != slack, 1:num_nod)
    Ykm1 = Ykm[nodos, nodos] # Matriz de admitancias reducida
    P = P[nodos] # Vector de potencias
    d = zeros(num_nod) # Vector de voltajes
    d = Ykm1 \ P # Cálculo de los voltajes
    pf = zeros(num_lin) # Vector de potencia de flujo en las líneas
    d = pushfirst!(d, dslack) # Se añade el slack al vector de voltajes --------------------> #d = [dslack; d] 
    for i in 1:num_lin # Cálculo de la potencia de flujo en las líneas
        k = lin.FROM[i] # Nodo de inicio
        m = lin.TO[i] # Nodo final
        pf[i] = (d[k] - d[m]) / lin.X[i] # Potencia de flujo en la línea
    end
    return d, pf # Se retornan los voltajes y las potencias de flujo
end
##___________________________________________________________________________
function Contingencia(num_lin, Ykm, P, num_nod, lin) # Función para el análisis de contingencias
    num_conting = num_lin # Número de contingencias
    Ykm1 = crear_Ykm(lin) # Matriz de admitancias
    P = P # Vector de potencias
    alm = zeros(num_conting, num_lin) # Almacenamiento de las potencias de flujo
    
    dref, pfref = flujo_potencia_DC(Ykm, P, num_lin, num_nod, lin) # Flujo de potencia en operación normal
    alm = [] # Almacenamiento de las potencias de flujo

    for j in 1:num_conting # Se recorre cada contingencia
        k = lin.FROM[j]  # Nodo de inicio
        m = lin.TO[j] # Nodo final
        Ykm1[k, m] = 0 # Se elimina la línea
        Ykm1[m, k] = 0 # Se elimina la línea
        df, pf = flujo_potencia_DC(Ykm1, P, num_lin, num_nod, lin) # Flujo de potencia en contingencia
        push!(alm, pf) # Se almacena la potencia de flujo
    end
    # Ranking
    almrank = []
    for k in 1:num_conting # Se recorre cada contingencia
        for i in 1:num_conting # Se recorre cada contingencia
            rank = sqrt((alm[k][i] / pfref[k])^2) # Índice de contingencia
            push!(almrank, rank) # Se almacena el índice de contingencia
        end
    end
    for i in 1:num_conting # Se recorre cada contingencia
        almrank[i] = almrank[(i - 1) * num_conting + 1:i * num_conting] # Se descompone el vector
    end

    return alm, almrank 
end
##___________________________________________________________________________
function graficar_contingencias(rank, num_conting) # Función para graficar los análisis de contingencias
    # Convertir los datos de rank en un formato adecuado para boxplot
    data = [rank[i] for i in 1:num_conting] # Datos de las contingencias
    
    # Graficar los boxplots
    p = @df DataFrame(data, :auto) boxplot(cols(1:num_conting), legend=false, xlabel="Contingencias", ylabel="Índice de Contingencia", title="Análisis de Contingencias", size=(900, 600), color=:yellow, boxwidth=0.9) # Boxplot
    display(p) # Mostrar el boxplot
end
##___________________________________________________________________________
function main() # Función principal
    lin, nod, num_lin, num_nod = carga_datos() # Cargar los datos
    Ykm = crear_Ykm(lin) # Crear la matriz de admitancias
    P = crear_vector_P(lin, nod) # Crear el vector de potencias
    dref, pfref = flujo_potencia_DC(Ykm, P, num_lin, num_nod, lin) # Flujo de potencia en operación normal
    ybus2 = calcular_ybus_2(lin, nod) # Matriz de admitancias nodales con transformadores


    pfconting, rank = Contingencia(num_lin, Ykm, P, num_nod, lin) # Flujo de potencia en contingencia
    println("  ") # Se imprime un espacio en blanco
    for i in 1:num_lin # Se recorre cada línea
        k = lin.FROM[i] # Nodo de inicio
        m = lin.TO[i] # Nodo final
        println("  ") # Se imprime un espacio en blanco 
        println("El flujo de potencia ante contingencia en la línea $i del nodo $k al $m es: ", pfconting[i]) # Se imprime el flujo de potencia ante contingencia
    end
    println("  ") # Se imprime un espacio en blanco
    
    x = 0 # Variable para almacenar el índice de contingencia
    # Se crea el ciclo para clasificar las líneas más críticas según el índice correspondiente a cada contingencia
    for j in 1:num_lin # Se recorre cada línea
        k = lin.FROM[j] # Nodo de inicio
        m = lin.TO[j] # Nodo final
        indice_ordenado = sortperm(rank[j]) # Índice de contingencia ordenado
        num_lineas_criticas = 3 # Número de líneas más críticas
        lineas_criticas = indice_ordenado[end - num_lineas_criticas + 1:end] # Líneas más críticas
        println("  ") # Se imprime un espacio en blanco
        println("Las $num_lineas_criticas líneas más críticas ante contingencia en la línea $j del nodo $k al $m son:") # Se imprime las líneas más críticas
        println("  ") # Se imprime un espacio en blanco
       
        for i in lineas_criticas # Se recorre cada línea
            k = lin.FROM[i] # Nodo de inicio
            m = lin.TO[i] # Nodo final
            println("Línea $i del nodo $k al $m - Índice de Contingencia: ", rank[j][i]) # Se muestran los datos
        end
    end
    
    # Llamar a la función para graficar los análisis de contingencia
    graficar_contingencias(rank, num_lin) 

    # se implime la Ybus incluyendo los transformadores de la red
    println("  ") # Se imprime un espacio en blanco
    println("La matriz de admitancia con transformadores es: ", ybus2) # Se imprime la matriz de admitancia nodal
    println("  ") # Se imprime un espacio en blanco

    # Se imprime el flujo de potencia en operación normal
    println("  ") # Se imprime un espacio en blanco
    print("El flujo de potencia en operación normal en las líneas es: ", pfref) # Se imprime el flujo de potencia en operación normal
    println("  ") # Se imprime un espacio en blanco
    println("Los ángulos de voltaje en los nodos son: ", dref)
    println("  ")
    return nothing
end

# Llamada a la función principal
main()