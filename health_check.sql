-- ==============================================================================
-- TRABAJO PRÁCTICO UNIDAD 6: MANTENIMIENTO, RESPALDO Y RECUPERACIÓN
-- Script: health_check.sql
-- Motor: PostgreSQL 16+ (PostgreSQL 17)
-- Base objetivo: foodstore
-- Propósito: Monitoreo periódico del estado operativo, concurrencia y recursos.
-- ==============================================================================

\echo '======================================================================'
\echo '1. TAMAÑO GENERAL DE LA BASE DE DATOS'
\echo '======================================================================'
SELECT 
    current_database() AS base_datos,
    pg_size_pretty(pg_database_size('foodstore')) AS tamano;

\echo '======================================================================'
\echo '2. ACTIVIDAD DE CONEXIONES Y BALANCE TRANSACCIONAL'
\echo '======================================================================'
SELECT 
    datname AS base_datos,
    numbackends AS conexiones_activas,
    xact_commit AS transacciones_exitosas,
    xact_rollback AS transacciones_abortadas,
    ROUND((xact_rollback::numeric / NULLIF(xact_commit + xact_rollback, 0)) * 100, 2) AS pct_rollback
FROM pg_stat_database 
WHERE datname = 'foodstore';

\echo '======================================================================'
\echo '3. ESTADO DE TABLAS DE USUARIO Y TUPLAS MUERTAS (DEAD TUPLES)'
\echo '======================================================================'
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    ROUND((n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0)) * 100, 2) AS pct_tuplas_muertas,
    last_autovacuum AS ultimo_autovacuum,
    last_autoanalyze AS ultimo_autoanalyze
FROM pg_stat_user_tables 
ORDER BY n_dead_tup DESC, n_live_tup DESC;

\echo '======================================================================'
\echo '4. CONSULTAS ACTIVAS EN EJECUCIÓN (CONCURRENCIA Y TIEMPOS)'
\echo '======================================================================'
SELECT 
    pid,
    usename AS usuario,
    client_addr AS ip_cliente,
    state AS estado,
    now() - query_start AS duracion,
    query AS consulta_sql
FROM pg_stat_activity 
WHERE datname = 'foodstore' 
  AND state <> 'idle'
  AND pid <> pg_backend_pid()
ORDER BY duracion DESC;
