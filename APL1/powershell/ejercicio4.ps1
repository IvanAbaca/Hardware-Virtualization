param(
    [Parameter(Mandatory=$true)]
    [string]$directorio,
    [Parameter(Mandatory=$true)]
    [string]$salida,
    [switch]$kill
)

# Si se usa el parámetro -kill, detener el monitoreo y salir
if ($kill) {
    try {
        # Verificar si hay eventos registrados con el identificador 'FileCreated'
        $event = Get-EventSubscriber -SourceIdentifier FileCreated
        if ($event) {
            Write-Host "Deteniendo el monitoreo del evento 'FileCreated'." -ForegroundColor Yellow
            Unregister-Event -SourceIdentifier FileCreated
            Write-Host "Monitoreo detenido exitosamente." -ForegroundColor Green
        } else {
            Write-Host "No se encontró un evento 'FileCreated' para detener." -ForegroundColor Red
        }
    } catch {
        Write-Host "Error al intentar detener el monitoreo: $($_.Exception.Message)" -ForegroundColor Red
    }
    exit
}

# Validar si el directorio existe
if (-not (Test-Path $directorio)) {
    Write-Host "Error: El directorio '$directorio' no existe. Por favor, proporcione un directorio válido." -ForegroundColor Red
    exit
}

if (-not (Test-Path $salida)) {
    Write-Host "Error: El directorio de salida '$salida' no existe. Por favor, proporcione un directorio válido." -ForegroundColor Red
    exit
}

# Convertir las rutas a absolutas
$absolutePath = (Resolve-Path $directorio).Path
$absoluteOutputDir = (Resolve-Path $salida).Path

Write-Host "Directorio monitoreado: $absolutePath" -ForegroundColor Green
Write-Host "Directorio de salida: $absoluteOutputDir" -ForegroundColor Green

# Configurar FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $absolutePath
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# Registrar evento para creación de archivos
Unregister-Event -SourceIdentifier FileCreated -ErrorAction SilentlyContinue
Register-ObjectEvent $watcher -MessageData $absoluteOutputDir Created -SourceIdentifier FileCreated -Action {
    param($sender, $eventArgs)

    # Variables
    $filePath = $eventArgs.FullPath
    $outputDir = $event.MessageData

    # Obtener información del archivo creado
    try {
        $fileInfo = Get-Item -Path $filePath
        $fileName = $fileInfo.Name
        $fileSize = $fileInfo.Length
        Write-Host "Archivo detectado: $fileName ($fileSize bytes)" -ForegroundColor Cyan
    } catch {
        Write-Host "No se pudo obtener información del archivo: $filePath" -ForegroundColor Red
        return
    }

    # Buscar duplicados en el mismo directorio (mismo nombre y tamaño)
    $duplicates = Get-ChildItem -Path $sender.Path -Recurse | Where-Object {
        $_.Name -eq $fileName -and $_.Length -eq $fileSize -and $_.FullName -ne $filePath
    }

    if ($duplicates.Count -gt 0) {
        Write-Host "Duplicado detectado para: $fileName" -ForegroundColor Yellow

        # Obtener la ruta del archivo original que causó el conflicto
        $originalFilePath = $duplicates[0].FullName

        # Crear el archivo comprimido
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $zipFile = Join-Path $outputDir "$timestamp-$fileName.zip"
        $logFileContent = @"
$((Get-Date).ToString()): 
Duplicado detectado para el archivo $fileName.
Archivo original: $originalFilePath.
"@

        try {
            # Crear archivo log temporal
            $tempLog = Join-Path $outputDir "temp_log.txt"
            $logFileContent | Out-File -FilePath $tempLog

            # Comprimir el archivo duplicado y el log
            Compress-Archive -Path $filePath, $tempLog -DestinationPath $zipFile -Force
            Write-Host "Archivo comprimido creado: $zipFile" -ForegroundColor Green

            # Eliminar el archivo duplicado del directorio original
            Remove-Item -Path $filePath -Force
            Write-Host "Duplicado eliminado del directorio original: $filePath" -ForegroundColor Magenta

            # Eliminar el archivo log temporal
            Remove-Item -Path $tempLog -Force
        } catch {
            Write-Host "Error al procesar el duplicado: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "No se detectaron duplicados para: $fileName" -ForegroundColor Magenta
    }
}

Write-Host "Evento registrado. Monitoreo iniciado. Prueba creando archivos en el directorio monitoreado." -ForegroundColor Green

# Mantener el proceso activo
while ($true) {
    Start-Sleep -Seconds 1
}