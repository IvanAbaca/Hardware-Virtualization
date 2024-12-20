[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$directorio,  # Ruta del directorio que contiene los CSV de agencias

    [Parameter(Mandatory = $false)]
    [string]$archivo,     # Ruta del archivo JSON de salida

    [Parameter(Mandatory = $false)]
    [switch]$pantalla     # Muestra la salida en pantalla
)

function validar_parametros {
    param (
        [string] $d, 
        [string] $a, 
        [bool] $p
    ) 

    # Validar exclusividad entre -archivo y -pantalla
    if ($a -and $p) {
        Write-Error "No se puede usar -archivo y -pantalla al mismo tiempo."
        exit
    }

    # Validar que el directorio existe
    if (-not (Test-Path $d)) {
        Write-Error "El directorio especificado no existe."
        exit
    }

    # Validar que la ruta del archivo es válida (cuando se pasa como parámetro)
    if ($a -and (Test-Path (Split-Path $a -Parent)) -eq $false) {
        Write-Error "El directorio para el archivo de salida no existe."
        exit
    }
}

function validar_agencias {
    param (
        [string]$directorio,
        [PSCustomObject[]]$path_agencias
    )

    foreach ($archivo in $path_agencias) {
        $filePath = Join-Path -Path $directorio -ChildPath $archivo.Name
        if (-not (Test-Path $filePath)) {
            throw "El archivo '$filePath' no existe."
        }
    }
    Write-Output "Validación de agencias completada."
}

function procesar_jugada {
    param (
        [string]$jugada,          # Registro CSV (e.g., "3,44,55,66,77")
        [int[]]$numeros_ganadores # Lista de números ganadores
    )

    # Dividir la jugada y contar los aciertos
    $numeros = $jugada -split ','
    $aciertos = ($numeros | Where-Object { $numeros_ganadores -contains $_ }).Count

    return $aciertos
}

function obtener_resultados_por_agencia {
    param (
        [string]$directorio,
        [PSCustomObject[]]$path_agencias,
        [int[]]$numeros_ganadores
    )

    # Validar los archivos antes de procesarlos
    validar_agencias -directorio $directorio -path_agencias $path_agencias

    $resultados = @()
    foreach ($archivo in $path_agencias) {
        $jugadas = Get-Content -Path (Join-Path -Path $directorio -ChildPath $archivo.Name)
        $jugada_index = 0

        foreach ($jugada in $jugadas) {
            $jugada_index++
            $aciertos = procesar_jugada -jugada $jugada -numeros_ganadores $numeros_ganadores

            $resultados += [PSCustomObject]@{
                agencia  = [System.IO.Path]::GetFileNameWithoutExtension($archivo.Name)
                jugada   = "$jugada_index"
                aciertos = $aciertos
            }
        }
    }

    return $resultados
}

function clasificar_jugadas { 
    param (
        $aciertos, 
        $resultados
    )

    $json = @{}

    foreach($acierto in $aciertos) {
        $clave = "$acierto"+"_aciertos" 

        $json[$clave] = $resultados | Where-Object { $_.aciertos -eq $acierto } | ForEach-Object {
            @{
                agencia = $_.agencia
                jugada  = $_.jugada
            }
        }
    }
    return $json | ConvertTo-Json -Depth 10
}

# Valido los parámetros enviados por el usuario
validar_parametros -d $directorio -a $archivo -p $pantalla

# Obtengo los números ganadores
$numeros_ganadores = (Get-Content -Path "$directorio/ganadores.csv") -split ',' | ForEach-Object { [int]$_ }

# Obtengo los archivos de cada agencia
$path_agencias = Get-ChildItem -Path "$directorio/" -Filter '?.csv' | Select-Object Name

# Obtengo los resultados de las agencias
$resultados = obtener_resultados_por_agencia -directorio $directorio -path_agencias $path_agencias -numeros_ganadores $numeros_ganadores

# Clasifico los resultados en un JSON
$json = clasificar_jugadas -aciertos @(5,4,3) -resultados $resultados

# Guardo o muestro el JSON
if ($pantalla) {
    $json
} else {
    Set-Content -Path $archivo -Value $json -Encoding UTF8
    Write-Output "JSON guardado en: $archivo"
}