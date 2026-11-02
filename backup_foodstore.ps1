<#
.SYNOPSIS
    Script automatizado de respaldo para la base de datos Food Store (PostgreSQL 16+).
.DESCRIPTION
    Genera un dump en formato Custom (-Fc), registra logs detallados de ejecución,
    calcula tiempos y verifica la integridad del archivo generado.
    Cumple con las directivas de seguridad: no expone contraseñas en código.
.PARAMETER DbHost
    Host del servidor PostgreSQL (predeterminado: localhost).
.PARAMETER DbPort
    Puerto del servidor PostgreSQL (predeterminado: 5432).
.PARAMETER DbUser
    Usuario de conexión a PostgreSQL (predeterminado: postgres).
.PARAMETER DbName
    Nombre de la base de datos a respaldar (predeterminado: foodstore).
.PARAMETER BackupDir
    Directorio de destino para los archivos .dump.
.PARAMETER LogDir
    Directorio de destino para los archivos de log.
#>

[CmdletBinding()]
param(
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [string]$DbUser = "postgres",
    [string]$DbName = "foodstore",
    [string]$BackupDir = "",
    [string]$LogDir = ""
)

$ErrorActionPreference = "Stop"

# Directorios base relativos al script
$BaseDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BaseDir)) { $BaseDir = (Get-Location).Path }

if ([string]::IsNullOrWhiteSpace($BackupDir)) {
    $BackupDir = Join-Path $BaseDir "backups"
}
if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $LogDir = Join-Path $BaseDir "logs"
}

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$DumpFilename = "${DbName}_${Timestamp}.dump"
$DumpFilePath = Join-Path $BackupDir $DumpFilename
$LogFilePath  = Join-Path $LogDir "backup_${DbName}_${Timestamp}.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $LogLine = "[{0}] [{1}] {2}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $LogLine
    Add-Content -Path $LogFilePath -Value $LogLine
}

Write-Log "=========================================================="
Write-Log "INICIO DE RESPALDO AUTOMATIZADO - FOOD STORE"
Write-Log "Host: $DbHost | Puerto: $DbPort | Usuario: $DbUser | DB: $DbName"
Write-Log "Destino Dump: $DumpFilePath"
Write-Log "Destino Log:  $LogFilePath"
Write-Log "=========================================================="

# 1. Localización del binario pg_dump
$PgDumpCmd = $null
$Cmd = Get-Command "pg_dump" -ErrorAction SilentlyContinue
if ($Cmd) {
    $PgDumpCmd = $Cmd.Source
}

if (-not $PgDumpCmd) {
    # Búsqueda en rutas estándar de instalación de PostgreSQL en Windows
    $StandardPaths = @(
        "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe",
        "C:\Program Files\PostgreSQL\16\bin\pg_dump.exe"
    )
    foreach ($path in $StandardPaths) {
        if (Test-Path $path) {
            $PgDumpCmd = $path
            break
        }
    }
}

if (-not $PgDumpCmd) {
    Write-Log "ERROR FATAL: No se encontró 'pg_dump' en PATH ni en rutas conocidas de PostgreSQL." "ERROR"
    exit 1
}

Write-Log "Binario pg_dump detectado: $PgDumpCmd"

# 2. Verificación de autenticación segura (sin contraseña en texto claro)
if ([string]::IsNullOrWhiteSpace($env:PGPASSWORD) -and -not (Test-Path "$env:APPDATA\postgresql\pgpass.conf") -and -not (Test-Path "$env:USERPROFILE\.pgpass")) {
    Write-Log "ADVERTENCIA: No se detectó PGPASSWORD ni archivo .pgpass. PostgreSQL podría solicitar contraseña interactivamente." "WARN"
}

# 3. Ejecución del respaldo con medición de tiempo
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$DumpArgs = @(
    "-h", $DbHost,
    "-p", $DbPort.ToString(),
    "-U", $DbUser,
    "-d", $DbName,
    "-w",
    "-Fc",
    "-f", $DumpFilePath
)

Write-Log "Ejecutando comando: & `"$PgDumpCmd`" $($DumpArgs -join ' ')"

try {
    $Process = Start-Process -FilePath $PgDumpCmd -ArgumentList $DumpArgs -NoNewWindow -Wait -PassThru -RedirectStandardError (Join-Path $LogDir "temp_dump_err.log")
    $ExitCode = $Process.ExitCode
} catch {
    Write-Log "Excepción al iniciar el proceso pg_dump: $_" "ERROR"
    $ExitCode = 1
}

$Stopwatch.Stop()
$DurationSec = [math]::Round($Stopwatch.Elapsed.TotalSeconds, 2)

# Incorporar salida de error temporal al log general si hubo
$TempErrLog = Join-Path $LogDir "temp_dump_err.log"
if (Test-Path $TempErrLog) {
    $ErrContent = Get-Content $TempErrLog -Raw
    if (-not [string]::IsNullOrWhiteSpace($ErrContent)) {
        Write-Log "Detalle stderr de pg_dump: $ErrContent" "WARN"
    }
    Remove-Item $TempErrLog -Force -ErrorAction SilentlyContinue
}

# 4. Verificación de resultado
if ($ExitCode -ne 0) {
    Write-Log "ERROR FATAL: pg_dump finalizó con código de error $ExitCode tras ${DurationSec}s." "ERROR"
    if (Test-Path $DumpFilePath) {
        Remove-Item $DumpFilePath -Force -ErrorAction SilentlyContinue
        Write-Log "Archivo parcial corrupto eliminado: $DumpFilePath" "WARN"
    }
    Write-Log "Respaldo fallido. Abortando con código de salida 1." "ERROR"
    exit 1
}

if (-not (Test-Path $DumpFilePath)) {
    Write-Log "ERROR FATAL: pg_dump retornó 0 pero el archivo $DumpFilePath no existe." "ERROR"
    exit 1
}

$DumpFileInfo = Get-Item $DumpFilePath
$SizeMb = [math]::Round($DumpFileInfo.Length / 1MB, 2)

if ($DumpFileInfo.Length -le 0) {
    Write-Log "ERROR FATAL: El archivo generado tiene tamaño 0 bytes." "ERROR"
    Remove-Item $DumpFilePath -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Log "RESPALDO COMPLETADO EXITOSAMENTE"
Write-Log "Archivo generado: $($DumpFileInfo.FullName)"
Write-Log "Tamaño: $($DumpFileInfo.Length) bytes ($SizeMb MB)"
Write-Log "Duración total: ${DurationSec} segundos"
Write-Log "Código de salida: 0"
Write-Log "=========================================================="

exit 0
