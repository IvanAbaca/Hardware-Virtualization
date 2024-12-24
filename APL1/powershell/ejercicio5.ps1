<#
.SYNOPSIS
    Script para consultar información de personajes y películas de la API swapi.tech con salida formateada.

.DESCRIPTION
    Permite buscar personajes y/o películas por sus IDs, generar un caché para optimizar consultas y mostrar resultados.

.PARAMETER People
    Array de IDs de los personajes a buscar.

.PARAMETER Film
    Array de IDs de las películas a buscar.

.NOTES
    Autor: [Tu Nombre]
    Fecha: [Fecha de creación]
#>

param (
    [Parameter(Mandatory=$false)]
    [int[]]$People,
    
    [Parameter(Mandatory=$false)]
    [int[]]$Film
)

# Función para realizar la consulta a la API
function Get-ApiData {
    param (
        [string]$Url
    )

    try {
        $Response = Invoke-RestMethod -Uri $Url -Method Get -ErrorAction Stop
        return $Response.result
    } catch {
        Write-Host "Error al consultar la API: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Función para gestionar el caché
function Get-FromCache {
    param (
        [string]$Type,
        [int]$Id
    )
    $CacheDir = "$PSScriptRoot/cache"
    if (-not (Test-Path -Path $CacheDir)) {
        New-Item -ItemType Directory -Path $CacheDir | Out-Null
    }

    $CacheFile = "$CacheDir/$Type-$Id.json"
    if (Test-Path -Path $CacheFile) {
        return Get-Content -Path $CacheFile | ConvertFrom-Json
    } else {
        return $null
    }
}

function Save-ToCache {
    param (
        [string]$Type,
        [int]$Id,
        [object]$Data
    )
    $CacheDir = "$PSScriptRoot/cache"
    if (-not (Test-Path -Path $CacheDir)) {
        New-Item -ItemType Directory -Path $CacheDir | Out-Null
    }

    $CacheFile = "$CacheDir/$Type-$Id.json"
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $CacheFile
}

# Procesamiento de IDs de personajes
if ($People) {
    Write-Host "Personajes:" -ForegroundColor Cyan
    foreach ($PersonId in $People) {
        $CachedPerson = Get-FromCache -Type "person" -Id $PersonId
        if ($CachedPerson) {
            Write-Host " (Caché)" -NoNewline
            $PersonData = $CachedPerson
        } else {
            $PersonData = Get-ApiData -Url "https://www.swapi.tech/api/people/$PersonId"
            if ($PersonData) {
                Save-ToCache -Type "person" -Id $PersonId -Data $PersonData
            }
        }
        if ($PersonData) {
            Write-Host "`nId: $($PersonData.uid)"
            Write-Host "Nombre: $($PersonData.properties.name)"
            Write-Host "Género: $($PersonData.properties.gender)"
            Write-Host "Altura: $($PersonData.properties.height)"
            Write-Host "Masa: $($PersonData.properties.mass)"
            Write-Host "Año de nacimiento: $($PersonData.properties.birth_year)"
        }
    }
}

# Procesamiento de IDs de películas
if ($Film) {
    Write-Host "`nPelículas:" -ForegroundColor Cyan
    foreach ($FilmId in $Film) {
        $CachedFilm = Get-FromCache -Type "film" -Id $FilmId
        if ($CachedFilm) {
            Write-Host " (Caché)" -NoNewline
            $FilmData = $CachedFilm
        } else {
            $FilmData = Get-ApiData -Url "https://www.swapi.tech/api/films/$FilmId"
            if ($FilmData) {
                Save-ToCache -Type "film" -Id $FilmId -Data $FilmData
            }
        }
        if ($FilmData) {
            Write-Host "`nTítulo: $($FilmData.properties.title)"
            Write-Host "Episodio: $($FilmData.properties.episode_id)"
            Write-Host "Fecha de estreno: $($FilmData.properties.release_date)"
            Write-Host "Crawl de apertura: $($FilmData.properties.opening_crawl -replace '\r?\n', ' ')"
        }
    }
}
