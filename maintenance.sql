-- ==============================================================================
-- TRABAJO PRÁCTICO UNIDAD 6: MANTENIMIENTO, RESPALDO Y RECUPERACIÓN
-- Script: maintenance.sql
-- Motor: PostgreSQL 16+ (PostgreSQL 17)
-- Base objetivo: foodstore
-- ==============================================================================
-- CRITERIO Y JUSTIFICACIÓN TÉCNICA:
-- 1. ¿Por qué NO usar VACUUM FULL como mantenimiento periódico?
--    VACUUM FULL adquiere un bloqueo exclusivo de máximo nivel (AccessExclusiveLock)
--    sobre toda la tabla, impidiendo absolutamente cualquier lectura (SELECT) o
--    escritura (INSERT/UPDATE/DELETE). En un sistema transaccional activo como
--    Food Store, esto produce la caída de disponibilidad del servicio para los
--    clientes. Asimismo, reescribe físicamente toda la tabla en un nuevo archivo de
--    disco, generando un impacto severo de I/O y requiriendo el doble de espacio
--    disponible temporalmente.
--
-- 2. ¿Por qué la acción elegida es VACUUM (ANALYZE, VERBOSE)?
--    El VACUUM estándar opera de manera estrictamente concurrente: adquiere sólo un
--    bloqueo ShareUpdateExclusiveLock, permitiendo que las consultas y transacciones
--    de la aplicación sigan operando en línea sin interrupción.
--    Limpia los punteros a tuplas muertas (dead tuples) dentro de las páginas de datos,
--    actualiza el mapa de espacio libre (Free Space Map - FSM) y, al incluir ANALYZE,
--    recalcula las estadísticas del optimizador de consultas (pg_statistic),
--    garantizando que el planificador elija índices eficientes.
-- ==============================================================================

\echo '======================================================================'
\echo 'PASO 1: REVISIÓN DE CONFIGURACIÓN DEL DEMONIO AUTOVACUUM'
\echo '======================================================================'
SELECT 
    name, 
    setting, 
    unit, 
    short_desc
FROM pg_settings 
WHERE name IN (
    'autovacuum', 
    'autovacuum_vacuum_threshold', 
    'autovacuum_vacuum_scale_factor', 
    'autovacuum_analyze_threshold', 
    'autovacuum_analyze_scale_factor',
    'autovacuum_naptime'
)
ORDER BY name;

\echo '======================================================================'
\echo 'PASO 2: DIAGNÓSTICO PREVIO - ESTADO DE TABLAS Y UMBRAL DE VACUUM'
\echo '======================================================================'
-- Se calcula el umbral teórico donde autovacuum se dispararía automáticamente:
-- umbral_teorico = autovacuum_vacuum_threshold + (autovacuum_vacuum_scale_factor * tuplas_vivas)
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    ROUND((50 + (0.2 * n_live_tup))::numeric, 0) AS umbral_autovacuum_estimado,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, n_live_tup DESC;

\echo '======================================================================'
\echo 'PASO 3: EJECUCIÓN DE MANTENIMIENTO CONCURRENTE SEGURO Y JUSTIFICADO'
\echo '======================================================================'
\echo 'Iniciando VACUUM (ANALYZE, VERBOSE) en tablas críticas de Food Store...'

VACUUM (ANALYZE, VERBOSE) categoria;
VACUUM (ANALYZE, VERBOSE) producto;
VACUUM (ANALYZE, VERBOSE) usuario;
VACUUM (ANALYZE, VERBOSE) pedido;
VACUUM (ANALYZE, VERBOSE) detalle_pedido;

\echo '======================================================================'
\echo 'PASO 4: VERIFICACIÓN POST-MANTENIMIENTO'
\echo '======================================================================'
-- Verificación de marcas de tiempo actualizadas y tuplas muertas saneadas
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    last_vacuum AS fecha_ultimo_vacuum,
    last_analyze AS fecha_ultimo_analyze
FROM pg_stat_user_tables
WHERE relname IN ('categoria', 'producto', 'usuario', 'pedido', 'detalle_pedido')
ORDER BY relname;
