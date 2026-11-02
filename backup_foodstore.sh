#!/usr/bin/env bash
# ==============================================================================
# Script automatizado de respaldo para la base de datos Food Store (PostgreSQL 16+)
# Formato: Custom (-Fc) | Rotación y Logs detallados
# ==============================================================================
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-foodstore}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
DUMP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"
LOG_FILE="$LOG_DIR/backup_${DB_NAME}_${TIMESTAMP}.log"

log() {
    local level="$1"
    shift
    local msg="$*"
    local ts
    ts="$(date +"%Y-%m-%d %H:%M:%S")"
    echo "[$ts] [$level] $msg" | tee -a "$LOG_FILE"
}

log "INFO" "=========================================================="
log "INFO" "INICIO DE RESPALDO AUTOMATIZADO - FOOD STORE"
log "INFO" "Host: $DB_HOST | Puerto: $DB_PORT | Usuario: $DB_USER | DB: $DB_NAME"
log "INFO" "Destino Dump: $DUMP_FILE"
log "INFO" "Destino Log:  $LOG_FILE"
log "INFO" "=========================================================="

if ! command -v pg_dump &>/dev/null; then
    log "ERROR" "No se encontró el comando 'pg_dump' en el PATH del sistema."
    exit 1
fi

START_TIME=$(date +%s)

if pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -Fc -f "$DUMP_FILE" 2>>"$LOG_FILE"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    FILE_SIZE=$(wc -c < "$DUMP_FILE" | tr -d ' ')
    FILE_SIZE_MB=$(awk -v size="$FILE_SIZE" 'BEGIN { printf "%.2f", size / 1048576 }')

    if [ "$FILE_SIZE" -le 0 ]; then
        log "ERROR" "El archivo generado tiene tamaño 0 bytes."
        rm -f "$DUMP_FILE"
        exit 1
    fi

    log "INFO" "RESPALDO COMPLETADO EXITOSAMENTE"
    log "INFO" "Archivo generado: $DUMP_FILE"
    log "INFO" "Tamaño: $FILE_SIZE bytes ($FILE_SIZE_MB MB)"
    log "INFO" "Duración total: ${DURATION} segundos"
    log "INFO" "Código de salida: 0"
    log "INFO" "=========================================================="
    exit 0
else
    EXIT_CODE=$?
    log "ERROR" "pg_dump falló con código $EXIT_CODE."
    rm -f "$DUMP_FILE"
    exit "$EXIT_CODE"
fi
