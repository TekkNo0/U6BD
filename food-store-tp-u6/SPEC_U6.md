# SPEC_U6: Plan de Mantenimiento, Respaldo y Recuperación — Food Store

**Proyecto integrador:** Food Store · **Motor:** PostgreSQL 16+ (PostgreSQL 17)  
**Base principal:** `foodstore` · **Base de recuperación:** `foodstore_restore_test`  
**Objetivos:** RPO objetivo $\le$ 24 h | RTO objetivo $\le$ 10 min

---

## 1. Alcance y Políticas de Seguridad

1. **Protección de Credenciales:** Prohibido almacenar contraseñas en scripts o repositorios. La autenticación se resuelve mediante variable de entorno `PGPASSWORD` o archivo protegido `.pgpass` (permisos 0600 / ACLs restrictivas en SO).
2. **Aislamiento de Entornos:** La base de producción `foodstore` es intocable y jamás se elimina ni sobrescribe en simulacros. Todo ensayo destructivo o de restauración se ejecuta sobre la base descartable `foodstore_restore_test`.
3. **Formato de Respaldo:** Exclusivamente formato Custom (`-Fc`), que garantiza compresión integrada, compatibilidad con restauración concurrente multihilo (`pg_restore -j`) y selección granular de esquemas/tablas.
4. **Mínimo Bloqueo en Mantenimiento:** Prohibido el uso de `VACUUM FULL` como tarea periódica. El mantenimiento rutinario se realiza exclusivamente mediante `VACUUM (ANALYZE)` concurrente para no degradar el servicio.

---

## 2. Matriz Operativa del Plan de Mantenimiento

| Tarea mínima | Frecuencia | Ventana / Horario | Condición de éxito (Criterio de parada) | Evidencia requerida |
|---|---|---|---|---|
| **Respaldo automatizado** | Diaria | 02:00 AM (baja carga) | `pg_dump` con código de salida `0`, tamaño $> 0$ bytes y verificación de integridad de cabecera. | Archivo `backups/foodstore_YYYYMMDD_HHMMSS.dump` y log en `logs/`. |
| **Chequeo de salud (Health Check)** | Diaria | 06:00 AM (pre-operativo) | `health_check.sql` ejecuta sin errores; conexiones activas dentro de límites de pool y sin transacciones colgadas. | Reporte / salida de `health_check.sql`. |
| **Revisión de mantenimiento** | Semanal | Domingo 03:00 AM | `maintenance.sql` analiza bloat de tuplas muertas; ejecuta `VACUUM ANALYZE` en tablas críticas sin locks exclusivos. | Métrica de tuplas muertas y `last_vacuum` actualizado. |
| **Restauración de prueba (Simulacro)** | Semanal | Domingo 04:00 AM | Recreación limpia de `foodstore_restore_test`, restauración íntegra y validaciones lógicas con 0 anomalías. | Base de prueba validada, medición de RTO y log de restauración. |

---

## 3. Condiciones de Verificación y Validación

- **Verificación de Respaldo:** El script de backup debe validar `$LASTEXITCODE == 0`. Ante cualquier error, registra el traceback en log y retorna código de salida `1` para activar alarmas.
- **Validación de Restauración:**
  - Conteo idéntico de registros pre y post respaldo en tablas transaccionales y maestras: `categoria`, `cliente`/`usuario`, `producto`, `pedido`, `detalle_pedido`.
  - Integridad semántica: `COUNT(*) == 0` para productos con `precio < 0` o `stock < 0`.
  - Integridad transaccional: `COUNT(*) == 0` para detalles de pedido con `cantidad <= 0` o `precio_unitario < 0`.
  - Medición cronometrada de RTO desde la inicialización de la base descartable hasta el fin de las validaciones.
