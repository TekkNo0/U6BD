#!/usr/bin/env bash
# ==============================================================================
# Script automatizado de simulacro de recuperación y medición de RPO/RTO
# Motor: PostgreSQL 16+ | Base descartable: foodstore_restore_test
# ==============================================================================
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
TARGET_DB="${TARGET_DB:-foodstore_restore_test}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"

mkdir -p "$LOG_DIR"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="$LOG_DIR/restore_test_${TIMESTAMP}.log"

log() {
    local level="$1"
    shift
    local msg="$*"
    local ts
    ts="$(date +"%Y-%m-%d %H:%M:%S")"
    echo "[$ts] [$level] $msg" | tee -a "$LOG_FILE"
}

log "INFO" "=========================================================="
log "INFO" "SIMULACRO DE DESASTRE Y RECUPERACIÓN CONTRA RELOJ"
log "INFO" "Host: $DB_HOST | Puerto: $DB_PORT | Usuario: $DB_USER | Base: $TARGET_DB"
log "INFO" "Archivo Log: $LOG_FILE"
log "INFO" "=========================================================="

# Buscar el dump más reciente
DUMP_FILE=$(ls -t "$BACKUP_DIR"/*.dump 2>/dev/null | head -n 1 || true)
if [ -z "$DUMP_FILE" ] || [ ! -f "$DUMP_FILE" ]; then
    log "ERROR" "No se encontraron archivos .dump en $BACKUP_DIR"
    exit 1
fi

DUMP_MOD_TIME=$(stat -c %Y "$DUMP_FILE" 2>/dev/null || stat -f %m "$DUMP_FILE")
NOW_TIME=$(date +%s)
RPO_SEGUNDOS=$((NOW_TIME - DUMP_MOD_TIME))
RPO_MINUTOS=$(awk -v s="$RPO_SEGUNDOS" 'BEGIN { printf "%.2f", s / 60 }')

log "INFO" "Respaldo seleccionado: $DUMP_FILE"
log "INFO" "RPO Observado (antigüedad): $RPO_MINUTOS minutos"

log "INFO" "INICIANDO CRONÓMETRO DE RECUPERACIÓN..."
START_STOPWATCH=$(date +%s%N 2>/dev/null || date +%s)

# Borrar base si existe y crear de cero
dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -w --if-exists "$TARGET_DB" 2>/dev/null || true
createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -w "$TARGET_DB"

# Restaurar
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TARGET_DB" -w --no-owner --no-privileges "$DUMP_FILE" || true

# Validaciones mínimas
log "INFO" "Ejecutando validaciones mínimas..."
QUERY_FILAS="SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria UNION ALL SELECT 'cliente', COUNT(*) FROM cliente UNION ALL SELECT 'producto', COUNT(*) FROM producto UNION ALL SELECT 'pedido', COUNT(*) FROM pedido UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido ORDER BY tabla;"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TARGET_DB" -w -c "$QUERY_FILAS" | tee -a "$LOG_FILE"

PROD_INV=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TARGET_DB" -w -t -A -c "SELECT COUNT(*) FROM producto WHERE precio < 0 OR stock < 0;")
DET_INV=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TARGET_DB" -w -t -A -c "SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0;")

END_STOPWATCH=$(date +%s%N 2>/dev/null || date +%s)
RTO_SEGUNDOS=$(awk -v s="$START_STOPWATCH" -v e="$END_STOPWATCH" 'BEGIN { printf "%.2f", (e - s)/1000000000 }' 2>/dev/null || echo $((END_STOPWATCH - START_STOPWATCH)))

log "INFO" "----------------------------------------------------------"
log "INFO" "RTO OBSERVADO: ${RTO_SEGUNDOS} segundos"
log "INFO" "Productos inválidos: $PROD_INV (esperado 0)"
log "INFO" "Detalles inválidos: $DET_INV (esperado 0)"

if [ "$PROD_INV" -eq 0 ] && [ "$DET_INV" -eq 0 ]; then
    log "INFO" "VEREDICTO: SIMULACRO EXITOSO"
    exit 0
else
    log "ERROR" "VEREDICTO: FALLO DE INTEGRIDAD"
    exit 1
fi
