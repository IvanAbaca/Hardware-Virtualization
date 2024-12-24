[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$directorio  # Ruta del directorio a analizar
)

function encontrar_duplicados {
    param (
        [string]$directorio
    )

    # Validar que el directorio existe
    if (-not (Test-Path $directorio)) {
        throw "El directorio '$directorio' no existe."
    }

    # Normalizar el directorio para que siempre termine con una barra invertida
    if (-not $directorio.EndsWith("\")) {
        $directorio += "\"
    }

    # Crear un hash table para almacenar archivos por nombre y tamaño
    $archivos = @{}

    # Buscar todos los archivos en el directorio y subdirectorios
    Get-ChildItem -Path $directorio -Recurse -File | ForEach-Object {
        $nombre = $_.Name
        $tamano = $_.Length
        $rutaCompleta = $_.FullName

        # Obtener la ruta relativa al directorio base
        $rutaRelativa = [System.IO.Path]::GetRelativePath($directorio, $rutaCompleta)

        # Crear clave única basada en nombre y tamaño
        $clave = "$nombre|$tamano"

        # Agrupar archivos duplicados en el hash table
        if (-not $archivos[$clave]) {
            $archivos[$clave] = @()  # Inicializar array para esa clave
        }
        $archivos[$clave] += $rutaRelativa
    }

    # Filtrar las claves con más de un archivo (duplicados)
    $duplicados = @{}
    foreach ($clave in $archivos.Keys) {
        if ($archivos[$clave].Count -gt 1) {
            $duplicados[$clave] = $archivos[$clave]
        }
    }

    return $duplicados
}

function mostrar_duplicados {
    param (
        [hashtable]$duplicados,
        [string]$directorio
    )

    foreach ($item in $duplicados.GetEnumerator()) {
        Write-Output "Archivo duplicado:"
        foreach ($ruta in $item.Value) {
            # Mostrar solo el directorio sin el nombre del archivo
            $directorioRelativo = [System.IO.Path]::GetDirectoryName($ruta)

            # Agregar el directorio raíz al resultado si es necesario
            if ([string]::IsNullOrEmpty($directorioRelativo)) {
                Write-Output $directorio  # Si está vacío, incluir el directorio raíz
            } else {
                Write-Output (Join-Path $directorio $directorioRelativo)
            }
        }
    }
}

# Llamar a la función para encontrar duplicados
try {
    $duplicados = encontrar_duplicados -directorio $directorio

    # Mostrar los duplicados
    if ($duplicados.Count -eq 0) {
        Write-Output "No se encontraron archivos duplicados."
    } else {
        mostrar_duplicados -duplicados $duplicados -directorio $directorio
    }
} catch {
    Write-Error "Ocurrió un error: $_"
}
