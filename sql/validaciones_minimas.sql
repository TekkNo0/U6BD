-- ==============================================================================
-- TRABAJO PRÁCTICO UNIDAD 6: MANTENIMIENTO, RESPALDO Y RECUPERACIÓN
-- Script: validaciones_minimas.sql
-- Motor: PostgreSQL 16+ (PostgreSQL 17)
-- Base objetivo: foodstore_restore_test
-- Propósito: Verificación de integridad estructural y lógica post-restauración.
-- ==============================================================================

\echo '======================================================================'
\echo 'CONTROL 1: CONTEO DE FILAS POR ENTIDAD (TABLAS Y VISTAS CLAVE)'
\echo '======================================================================'
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido
ORDER BY tabla;

\echo '======================================================================'
\echo 'CONTROL 2: PRODUCTOS CON PRECIO O STOCK INVÁLIDOS (DEBE SER CERO)'
\echo '======================================================================'
SELECT COUNT(*) AS productos_invalidos
FROM producto
WHERE precio < 0 OR stock < 0;

\echo '======================================================================'
\echo 'CONTROL 3: DETALLES DE PEDIDO CON CANTIDAD O PRECIO UNITARIO INVÁLIDOS (DEBE SER CERO)'
\echo '======================================================================'
SELECT COUNT(*) AS detalles_invalidos
FROM detalle_pedido
WHERE cantidad <= 0 OR precio_unitario < 0;
