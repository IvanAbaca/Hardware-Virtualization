param(
    [Parameter(Mandatory=$true)]
    [string]$directorio,

    [Parameter(Mandatory=$false)]
    [string]$salida,

    [switch]$kill
)

function Iniciar-Monitoreo {
    param(
        [string]$Path,
        [string]$OutputDir
    )

    # Convertir las rutas a absolutas
    try {
        $absolutePath = (Resolve-Path $Path).Path
    } catch {
        Write-Host "Error: El directorio '$Path' no existe o no es accesible." -ForegroundColor Red
        return
    }

    try {
        $absoluteOutputDir = (Resolve-Path $OutputDir).Path
        Write-Host "Directorio de salida absoluto resuelto: $absoluteOutputDir" -ForegroundColor Green
    } catch {
        Write-Host "El directorio de salida '$OutputDir' no existe. Se intentará crear automáticamente." -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Path $OutputDir | Out-Null
            $absoluteOutputDir = (Resolve-Path $OutputDir).Path
            Write-Host "Directorio de salida creado exitosamente: $absoluteOutputDir" -ForegroundColor Green
        } catch {
            Write-Host "Error: No se pudo crear el directorio de salida '$OutputDir'. Deteniendo el proceso." -ForegroundColor Red
            return
        }
    }

    # Validar que el directorio esté configurado correctamente
    if (-not $absoluteOutputDir) {
        Write-Host "Error crítico: La variable \$absoluteOutputDir no está configurada." -ForegroundColor Red
        return
    }

    # Verificar si ya hay un demonio ejecutándose
    $pidFile = Join-Path $absoluteOutputDir "demonio.pid"
    if (Test-Path $pidFile) {
        Write-Host "Ya existe un proceso demonio monitoreando este directorio." -ForegroundColor Yellow
        return
    }

    # Guardar el PID del proceso actual
    $currentPID = [System.Diagnostics.Process]::GetCurrentProcess().Id
    $currentPID | Out-File -FilePath $pidFile

    # Configuración de FileSystemWatcher
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $absolutePath
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true
    $watcher.Filter = "*.*"  # Monitorea todos los archivos

    Write-Host "FileSystemWatcher configurado para el directorio: $absolutePath" -ForegroundColor Green

    # Eliminar suscriptores previos para evitar conflictos
    Unregister-Event -SourceIdentifier FileCreated -ErrorAction SilentlyContinue

    # Capturar el valor dinámico de `$absoluteOutputDir` en el bloque
    $capturedOutputDir = $absoluteOutputDir
    Register-ObjectEvent $watcher Created -SourceIdentifier FileCreated -Action {
        param($sender, $eventArgs)

        # Usar `$capturedOutputDir` para mantener el valor dinámico de salida
        $filePath = $eventArgs.FullPath

        Write-Host "Evento de creación detectado para: $filePath" -ForegroundColor Cyan

        Start-Sleep -Milliseconds 500 # Espera para evitar conflictos con archivos en uso

        if (-not (Test-Path $filePath)) {
            Write-Host "El archivo '$filePath' no existe. Ignorando." -ForegroundColor Yellow
            return # Si el archivo no existe, salir
        }

        # Verifica duplicados (mismo nombre y tamaño)
        $fileName = [System.IO.Path]::GetFileName($filePath)
        $files = Get-ChildItem -Path $sender.Path -Recurse | Where-Object { $_.Name -eq $fileName -and $_.FullName -ne $filePath }
        if ($files) {
            Write-Host "Archivos duplicados detectados para: $filePath" -ForegroundColor Green
        } else {
            Write-Host "No se detectaron duplicados para: $filePath" -ForegroundColor Yellow
            return
        }

        foreach ($file in $files) {
            Write-Host "Procesando archivo duplicado: $($file.FullName)" -ForegroundColor Cyan

            if ($file.Length -eq (Get-Item $filePath).Length) {
                Write-Host "Archivo duplicado confirmado por tamaño: $($file.FullName)" -ForegroundColor Green

                # Generar respaldo comprimido
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $zipFile = Join-Path $capturedOutputDir "$timestamp.zip"
                Write-Host "Ruta del archivo comprimido: $zipFile" -ForegroundColor Cyan

                # Crear o actualizar el log
                $logFile = Join-Path $capturedOutputDir "demonio.log"
                Write-Host "Ruta del log: $logFile" -ForegroundColor Cyan

                try {
                    "${$timestamp}: Archivo duplicado detectado entre $($file.FullName) y $filePath. Respaldo creado en $zipFile." | Out-File -Append -FilePath $logFile
                    Write-Host "Log actualizado exitosamente: $logFile" -ForegroundColor Green
                } catch {
                    Write-Host "Error al escribir en el log: $($_.Exception.Message)" -ForegroundColor Red
                    return
                }

                try {
                    Compress-Archive -Path $file.FullName, $filePath, $logFile -DestinationPath $zipFile -Force
                    Write-Host "Archivo comprimido creado exitosamente: $zipFile" -ForegroundColor Green
                } catch {
                    Write-Host "Error al crear el archivo comprimido: $($_.Exception.Message)" -ForegroundColor Red
                    return
                }
            } else {
                Write-Host "Archivo con nombre igual pero diferente tamaño detectado: $($file.FullName)" -ForegroundColor Yellow
            }
        }
    }

    Write-Host "Monitoreo iniciado en el directorio: $absolutePath" -ForegroundColor Green

    # Mantener el proceso activo
    while ($true) {
        Start-Sleep -Seconds 1
    }
}

function Detener-Monitoreo {
    param(
        [string]$OutputDir
    )

    # Convertir la ruta de salida a absoluta
    try {
        $absoluteOutputDir = (Resolve-Path $OutputDir).Path
    } catch {
        Write-Host "Error: El directorio de salida '$OutputDir' no existe o no es accesible." -ForegroundColor Red
        return
    }

    # Verificar el archivo demonio.pid
    $pidFile = Join-Path $absoluteOutputDir "demonio.pid"
    if (Test-Path $pidFile) {
        $currentPID = Get-Content $pidFile
        Stop-Process -Id $currentPID -Force -ErrorAction SilentlyContinue
        Remove-Item $pidFile
        Write-Host "Demonio detenido." -ForegroundColor Yellow
    } else {
        Write-Host "No se encontró un demonio en ejecución para este directorio." -ForegroundColor Red
    }
}

# Lógica principal
if ($kill) {
    # Detener el demonio
    if (-not $salida) {
        Write-Host "Debe especificar el directorio de salida para detener el demonio." -ForegroundColor Red
        return
    }
    Detener-Monitoreo -OutputDir $salida
} else {
    # Iniciar el demonio
    if (-not $salida) {
        Write-Host "Debe proporcionar un directorio de salida al iniciar el demonio." -ForegroundColor Red
        return
    }
    Iniciar-Monitoreo -Path $directorio -OutputDir $salida
}
