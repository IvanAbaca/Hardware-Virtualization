# Declaraciones
$resultados = @()

# Ruta del archivo de ganadores
$path = 'Ejercicio1'

# Obtengo los números ganadores
$numeros_ganadores = (Get-Content -Path "$path/ganadores.csv") -split ','

# Obtengo los archivos de cada agencia
$path_agencias = Get-ChildItem -Path "$path/" -Filter '?.csv' | Select-Object Name

foreach ($path_agencia in $path_agencias) {
    $jugada_index = 0
    $jugadas = Get-Content -Path ($path + '/' + $path_agencia.Name)

    foreach ($jugada in $jugadas) {
        $jugada_index++
        $numeros = $jugada -split ','

        # Contar los aciertos
        $aciertos = 0
        foreach ($numero in $numeros) {
            if ($numeros_ganadores -contains $numero) {
                $aciertos++
            }
        }

        # Crear un objeto con los resultados
        $resultado = [PSCustomObject]@{
            agencia  = [System.IO.Path]::GetFileNameWithoutExtension($path_agencia.Name)
            jugada   = "$jugada_index"
            aciertos = $aciertos
        }

        $resultados += $resultado
    }
}

# Clasificar los resultados por número de aciertos
$json_resultado = @{
    "5_aciertos" = $resultados | Where-Object { $_.aciertos -gt 5 } | ForEach-Object {
        @{
            agencia = $_.agencia
            jugada  = $_.jugada
        }
    }
    "4_aciertos" = $resultados | Where-Object { $_.aciertos -eq 4 } | ForEach-Object {
        @{
            agencia = $_.agencia
            jugada  = $_.jugada
        }
    }
    "3_aciertos" = $resultados | Where-Object { $_.aciertos -eq 3 } | ForEach-Object {
        @{
            agencia = $_.agencia
            jugada  = $_.jugada
        }
    }
}

# Convertir a JSON
$json = $json_resultado | ConvertTo-Json -Depth 10

# Guardar el JSON en un archivo
$jsonFilePath = "$path/resultados.json"
Set-Content -Path $jsonFilePath -Value $json -Encoding UTF8

# Confirmar que el archivo se guardó
Write-Output "JSON guardado en: $jsonFilePath"