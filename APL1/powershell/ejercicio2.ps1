[CmdletBinding()]
param(
    [Parameter (Mandatory=$true)]
    [string]$matriz, # Ruta del archivo de la matriz.

    [Parameter (Mandatory=$false)]
    [Nullable[int]]$producto, # Valor entero para utilizarse en el producto escalar.

    [Parameter (Mandatory=$false)]
    [switch]$transponer, # Indica que se debe realizar la operación de trasposición sobre la matriz.

    [Parameter (Mandatory=$true)]
    [char]$separador # Carácter para utilizarse como separador de columnas.
)

function validar_parametros {
    param (
        [string]$m,
        [Nullable[int]]$p,
        [bool]$t,
        [char]$s
    )

    # Validar exclusividad entre -producto y -transponer
    if ($null -ne $p -and $t) {
        Write-Error "No se puede usar -producto y -transponer al mismo tiempo."
        exit 1
    }

    # Validar que el directorio existe
    if (-not (Test-Path $m)) {
        Write-Error "La ruta $m no existe."
        exit 1
    }

    # Validar que el separador es válido
    if ($s -match '[0-9-]') {
        Write-Error "El carácter separador no es válido."
        exit 1
    }
}

function obtener_matriz {
    param (
        [string]$directorio,
        [char]$separador
    )
    [string[]]$lineas = Get-Content -Path $directorio
    $matrix = @() # Arreglo de arreglos

    foreach ($linea in $lineas) {
        # Convertir la línea dividida en enteros y agregarla como una fila
        $matrix += ,(($linea -split $separador) | ForEach-Object { [int]$_ })
    }

    return $matrix
}

function transponer_matriz {
    param (
        [int[][]]$matrizOriginal
    )

    # Crear una nueva matriz para almacenar la matriz traspuesta
    $transposed = @()

    # Validar que la matriz no esté vacía
    if ($matrizOriginal.Count -eq 0) {
        Write-Error "La matriz está vacía. No se puede trasponer."
        return @()
    }

    # Recorrer las columnas de la matriz original
    for ($colum = 0; $colum -lt $matrizOriginal[0].Count; $colum++) {
        $newRow = @() # Crear una nueva fila para la matriz traspuesta

        # Recorrer las filas de la matriz original
        for ($fila = 0; $fila -lt $matrizOriginal.Count; $fila++) {
            $newRow += $matrizOriginal[$fila][$colum] # Agregar el elemento a la nueva fila
        }

        $transposed += ,$newRow # Agregar la nueva fila a la matriz traspuesta
    }

    return $transposed
}

function producto_matriz {
    param (
        [int[][]]$matriz_obt,
        [int]$producto
    )

    for ($fila = 0; $fila -lt $matriz_obt.Count; $fila++) {
        for ($colum = 0; $colum -lt $matriz_obt[$fila].Count; $colum++) {
            $matriz_obt[$fila][$colum] *= $producto
        }
    }

    return $matriz_obt
}

# Validar parámetros
validar_parametros -m $matriz -p $producto -t $transponer.IsPresent -s $separador

# Obtener la matriz
[int[][]]$matriz_obt = obtener_matriz -directorio $matriz -separador $separador

# Operar con la matriz
if ($transponer.IsPresent) {
    Write-Output "Trasponiendo la matriz..."
    $matriz_obt = transponer_matriz -matrizOriginal $matriz_obt

} 
else {
    $matriz_obt = producto_matriz -matriz_obt $matriz_obt -producto $producto
}

# Mostrar la matriz resultante
Write-Output "Matriz resultante:"
$matriz_obt | ForEach-Object { ($_ -join $separador) }