param(
    [Parameter(Mandatory=$true)]
    [string]$directorio,
    [Parameter(Mandatory=$true)]
    [string]$salida
)

# Convertir las rutas a absolutas
$absolutePath = (Resolve-Path $directorio).Path
$absoluteOutputDir = (Resolve-Path $salida).Path

Write-Host "Directorio monitoreado: $absolutePath" -ForegroundColor Green
Write-Host "Directorio de salida: $absoluteOutputDir" -ForegroundColor Green

# Crear un objeto compartido para encapsular el directorio de salida
$sharedState = New-Object PSObject -Property @{
    OutputDir = $absoluteOutputDir
}

# Configurar FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $absolutePath
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# Mostrar estado de FileSystemWatcher
Write-Host "FileSystemWatcher habilitado: $($watcher.EnableRaisingEvents)" -ForegroundColor Green

# Mostrar archivos iniciales en el directorio
Write-Host "Archivos en el directorio monitoreado:" -ForegroundColor Green
Get-ChildItem -Path $absolutePath -Recurse | ForEach-Object {
    Write-Host $_.FullName -ForegroundColor Yellow
}

# Eliminar eventos anteriores para evitar conflictos
Unregister-Event -SourceIdentifier FileCreated -ErrorAction SilentlyContinue

# Registrar evento para creación de archivos
Register-ObjectEvent $watcher Created -MessageData $absoluteOutputDir -SourceIdentifier FileCreated -Action {
    param($sender, $eventArgs)

    $salida_evento = $event.MessageData

    # Obtener el directorio de salida desde el objeto compartido
    $outputDir = $sharedState.OutputDir

    # Ruta completa del archivo creado
    $filePath = $eventArgs.FullPath
    # Nombre del archivo
    $fileName = [System.IO.Path]::GetFileName($filePath)

    # Detalles del archivo
    try {
        $fileInfo = Get-Item -Path $filePath
        $fileSize = $fileInfo.Length
        $fileDate = $fileInfo.CreationTime
    } catch {
        Write-Host "No se pudo obtener información del archivo: $filePath" -ForegroundColor Red
        return
    }

    # Mostrar información detallada
    Write-Host "===== Archivo Creado =====" -ForegroundColor Cyan
    Write-Host "Ruta Completa: $filePath" -ForegroundColor Yellow
    Write-Host "Nombre del Archivo: $fileName" -ForegroundColor Green
    Write-Host "Tamaño del Archivo: $fileSize bytes" -ForegroundColor Magenta
    Write-Host "Fecha de Creación: $fileDate" -ForegroundColor White
    Write-Host "Directorio de Salida: $salida_evento" -ForegroundColor Blue
    Write-Host "==========================" -ForegroundColor Cyan
}

Write-Host "Evento registrado. Monitoreo iniciado. Prueba creando archivos en el directorio monitoreado." -ForegroundColor Green

# Mantener el proceso activo
while ($true) {
    Start-Sleep -Seconds 1
}
