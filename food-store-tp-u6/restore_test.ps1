<#
.SYNOPSIS
    Simulacro automatizado de desastre contra reloj - Food Store (PostgreSQL 16+).
.DESCRIPTION
    Toma el último respaldo disponible, crea la base descartable foodstore_restore_test,
    ejecuta pg_restore con medición cronometrada (RTO), valida restricciones lógicas
    y calcula la antigüedad del respaldo (RPO observado).
.PARAMETER DbHost
    Host de PostgreSQL (predeterminado: localhost).
.PARAMETER DbPort
    Puerto de PostgreSQL (predeterminado: 5432).
.PARAMETER DbUser
    Usuario de PostgreSQL (predeterminado: postgres).
.PARAMETER TargetDb
    Base de datos de prueba descartable (predeterminado: foodstore_restore_test).
.PARAMETER DumpFile
    Ruta opcional al archivo .dump. Si se omite, toma el más reciente de backups/.
.PARAMETER LogDir
    Directorio de logs (predeterminado: logs/).
#>

[CmdletBinding()]
param(
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [string]$DbUser = "postgres",
    [string]$TargetDb = "foodstore_restore_test",
    [string]$DumpFile = "",
    [string]$LogDir = ""
)

$ErrorActionPreference = "Stop"

# Directorios base relativos al script
$BaseDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BaseDir)) { $BaseDir = (Get-Location).Path }

$BackupDir = Join-Path $BaseDir "backups"
if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $LogDir = Join-Path $BaseDir "logs"
}

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$LogFilePath = Join-Path $LogDir "restore_test_${Timestamp}.log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $NowStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $LogLine = "[$NowStr] [$Level] $Message"
    Write-Host $LogLine
    Add-Content -Path $LogFilePath -Value $LogLine
}

Write-Log "=========================================================="
Write-Log "SIMULACRO DE DESASTRE Y RECUPERACION CONTRA RELOJ"
Write-Log "Host: $DbHost | Puerto: $DbPort | Usuario: $DbUser | Base Destino: $TargetDb"
Write-Log "Archivo Log: $LogFilePath"
Write-Log "=========================================================="

# 1. Localización de binarios PostgreSQL
function Find-PgBinary {
    param([string]$BinaryName)
    $Cmd = Get-Command $BinaryName -ErrorAction SilentlyContinue
    if ($Cmd) { return $Cmd.Source }
    $StandardPaths = @(
        "C:\Program Files\PostgreSQL\17\bin\$BinaryName.exe",
        "C:\Program Files\PostgreSQL\16\bin\$BinaryName.exe"
    )
    foreach ($p in $StandardPaths) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

$CreatedbCmd  = Find-PgBinary "createdb"
$DropdbCmd    = Find-PgBinary "dropdb"
$PgRestoreCmd = Find-PgBinary "pg_restore"
$PsqlCmd      = Find-PgBinary "psql"

if (-not $CreatedbCmd -or -not $DropdbCmd -or -not $PgRestoreCmd -or -not $PsqlCmd) {
    Write-Log "ERROR FATAL: Faltan binarios requeridos de PostgreSQL (createdb, dropdb, pg_restore, psql)." "ERROR"
    exit 1
}

# 2. Selección del archivo .dump
if ([string]::IsNullOrWhiteSpace($DumpFile)) {
    $LatestDump = Get-ChildItem -Path $BackupDir -Filter "foodstore_*.dump" | Where-Object { $_.Length -gt 0 } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $LatestDump) {
        Write-Log "ERROR FATAL: No se encontraron archivos foodstore_*.dump validos en $BackupDir." "ERROR"
        exit 1
    }
    $DumpFile = $LatestDump.FullName
}

if (-not (Test-Path $DumpFile)) {
    Write-Log "ERROR FATAL: El archivo de respaldo especificado no existe: $DumpFile" "ERROR"
    exit 1
}

$DumpFileInfo = Get-Item $DumpFile
$DumpAge = (Get-Date) - $DumpFileInfo.LastWriteTime
$RPO_Minutos = [math]::Round($DumpAge.TotalMinutes, 2)
$RPO_Horas = [math]::Round($DumpAge.TotalHours, 2)
$DumpSizeMb = [math]::Round($DumpFileInfo.Length / 1MB, 2)

Write-Log "Respaldo seleccionado: $($DumpFileInfo.FullName)"
Write-Log "Tamano del respaldo: $DumpSizeMb MB"
Write-Log "Fecha/Hora de creacion del dump: $($DumpFileInfo.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Log "RPO Observado (antiguedad al inicio): $RPO_Minutos minutos ($RPO_Horas horas)"

# 3. Disparo del Cronómetro (Comienza inmediatamente antes de crear la base de prueba)
Write-Log "----------------------------------------------------------"
Write-Log "INICIANDO CRONOMETRO DE RECUPERACION (MEDICION DE RTO)..."
Write-Log "----------------------------------------------------------"
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# 3.1 Eliminación de la base de prueba si existía de un simulacro previo
Write-Log "Preparando entorno descartable: verificando si '$TargetDb' existe..."
$DropArgs = @("-h", $DbHost, "-p", $DbPort.ToString(), "-U", $DbUser, "-w", "--if-exists", $TargetDb)
$null = Start-Process -FilePath $DropdbCmd -ArgumentList $DropArgs -NoNewWindow -Wait -PassThru -RedirectStandardError (Join-Path $LogDir "temp_dropdb.log")
Remove-Item (Join-Path $LogDir "temp_dropdb.log") -Force -ErrorAction SilentlyContinue

# 3.2 Creación de la base descartable
Write-Log "Ejecutando createdb $TargetDb..."
$CreateArgs = @("-h", $DbHost, "-p", $DbPort.ToString(), "-U", $DbUser, "-w", $TargetDb)
$CreateProcess = Start-Process -FilePath $CreatedbCmd -ArgumentList $CreateArgs -NoNewWindow -Wait -PassThru -RedirectStandardError (Join-Path $LogDir "temp_createdb_err.log")

if ($CreateProcess.ExitCode -ne 0) {
    $ErrContent = ""
    if (Test-Path (Join-Path $LogDir "temp_createdb_err.log")) { $ErrContent = Get-Content (Join-Path $LogDir "temp_createdb_err.log") -Raw }
    Write-Log "ERROR FATAL: createdb fallo con codigo $($CreateProcess.ExitCode): $ErrContent" "ERROR"
    exit 1
}

# 3.3 Restauración con pg_restore
Write-Log "Ejecutando pg_restore sobre $TargetDb..."
$RestoreArgs = @(
    "-h", $DbHost,
    "-p", $DbPort.ToString(),
    "-U", $DbUser,
    "-d", $TargetDb,
    "-w",
    "--no-owner",
    "--no-privileges",
    $DumpFile
)

$RestoreProcess = Start-Process -FilePath $PgRestoreCmd -ArgumentList $RestoreArgs -NoNewWindow -Wait -PassThru -RedirectStandardError (Join-Path $LogDir "temp_restore_err.log")

# En pg_restore código 0 es éxito, código 1 son warnings no fatales
if ($RestoreProcess.ExitCode -gt 1) {
    $ErrContent = ""
    if (Test-Path (Join-Path $LogDir "temp_restore_err.log")) { $ErrContent = Get-Content (Join-Path $LogDir "temp_restore_err.log") -Raw }
    Write-Log "ERROR FATAL: pg_restore fallo con codigo $($RestoreProcess.ExitCode): $ErrContent" "ERROR"
    exit 1
}
Write-Log "Restauracion de estructura y datos finalizada."

# 3.4 Validaciones mínimas de integridad
Write-Log "Ejecutando validaciones minimas de integridad sobre $TargetDb..."

# Control 1: Conteo de filas
$QueryFilas = "SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria UNION ALL SELECT 'cliente', COUNT(*) FROM cliente UNION ALL SELECT 'producto', COUNT(*) FROM producto UNION ALL SELECT 'pedido', COUNT(*) FROM pedido UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido ORDER BY tabla;"

$FilasOutput = & $PsqlCmd -h $DbHost -p $DbPort -U $DbUser -d $TargetDb -w -t -A -F "," -c $QueryFilas

# Control 2: Productos inválidos
$QueryProdInv = "SELECT COUNT(*) FROM producto WHERE precio < 0 OR stock < 0;"
$ProdInvCount = (& $PsqlCmd -h $DbHost -p $DbPort -U $DbUser -d $TargetDb -w -t -A -c $QueryProdInv).Trim()

# Control 3: Detalles inválidos
$QueryDetInv = "SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0;"
$DetInvCount = (& $PsqlCmd -h $DbHost -p $DbPort -U $DbUser -d $TargetDb -w -t -A -c $QueryDetInv).Trim()

# Fin del cronómetro
$Stopwatch.Stop()
$RTO_Segundos = [math]::Round($Stopwatch.Elapsed.TotalSeconds, 2)

Write-Log "----------------------------------------------------------"
Write-Log "FIN DEL SIMULACRO - CRONOMETRO DETENIDO"
Write-Log "RTO OBSERVADO (Tiempo total de recuperacion): $RTO_Segundos segundos"
Write-Log "----------------------------------------------------------"

# 4. Procesamiento y exhibición de evidencias
Write-Log "RESULTADOS DE VALIDACION:"
Write-Log "Conteo de filas recuperadas:"
$ValidationPassed = $true

foreach ($line in $FilasOutput) {
    if (-not [string]::IsNullOrWhiteSpace($line)) {
        $parts = $line.Split(",")
        $tName = $parts[0]
        $tCount = [int]$parts[1]
        Write-Log "  - Tabla/Vista $tName : $tCount filas"
        if ($tCount -le 0) {
            Write-Log "    ALERTA: $tName tiene 0 filas!" "WARN"
            $ValidationPassed = $false
        }
    }
}

Write-Log "Control de integridad semantica de productos:"
Write-Log "  - Productos con precio < 0 o stock < 0: $ProdInvCount (esperado: 0)"
if ($ProdInvCount -ne "0") {
    Write-Log "ERROR: Se encontraron productos invalidos." "ERROR"
    $ValidationPassed = $false
}

Write-Log "Control de integridad semantica de detalle_pedido:"
Write-Log "  - Detalles con cantidad <= 0 o precio_unitario < 0: $DetInvCount (esperado: 0)"
if ($DetInvCount -ne "0") {
    Write-Log "ERROR: Se encontraron detalles de pedido invalidos." "ERROR"
    $ValidationPassed = $false
}

# Limpieza de archivos temporales
Remove-Item (Join-Path $LogDir "temp_*.log") -Force -ErrorAction SilentlyContinue

Write-Log "=========================================================="
if ($ValidationPassed) {
    Write-Log "VEREDICTO FINAL: SIMULACRO EXITOSO (100% VALIDADO)" "INFO"
    Write-Log "RPO Observado: $RPO_Minutos minutos"
    Write-Log "RTO Observado: $RTO_Segundos segundos"
    Write-Log "=========================================================="
    exit 0
} else {
    Write-Log "VEREDICTO FINAL: SIMULACRO CON ANOMALIAS" "ERROR"
    Write-Log "=========================================================="
    exit 1
}
