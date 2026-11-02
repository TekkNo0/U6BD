# INFORME POST-INCIDENTE: SIMULACRO DE RECUPERACIÓN (U6)
**Tecnicatura Universitaria en Programación — Base de Datos II (Semana 10)**  
**Proyecto:** Food Store | **Motor:** PostgreSQL 17 | **Alumno:** Maximiliano Nardez  
**Base Producción:** `foodstore` | **Base Descartable:** `foodstore_restore_test`

---

### 1. Parámetros del Respaldo Utilizado
- **Archivo origen:** `foodstore_20261102_165455.dump` (Formato Custom `-Fc`, tamaño: 3.25 MB).
- **Fecha y hora de generación:** 2026-11-02 16:54:56.
- **Herramienta:** `pg_dump` 17.x con compresión nativa y autenticación vía `$env:PGPASSWORD`.

### 2. Tiempos Operativos: RPO y RTO (Previsto vs. Observado)
- **RPO (Recovery Point Objective):**
  - *Previsto en el Plan:* $\le$ 24 horas (respaldo diario programado fuera de horario pico a las 02:00 AM).
  - *Observado en el simulacro:* **3.83 minutos** (antigüedad de la copia al momento de lanzar la contingencia). En un escenario real de pérdida total a mitad de jornada, el RPO máximo observado equivaldría al diferencial transaccional acumulado desde el último snapshot diario.
- **RTO (Recovery Time Objective):**
  - *Previsto en el Plan:* $\le$ 10 minutos (tiempo máximo tolerable para recrear base, restaurar datos y validar).
  - *Observado en el simulacro:* **4.45 segundos** (cronometrado desde la preparación de `foodstore_restore_test`, invocación de `createdb`, ejecución de `pg_restore` y culminación de las 3 validaciones de integridad). Cumplimiento del 100% dentro del umbral operativo.

### 3. Resultado de Validaciones de Integridad y Restricciones Lógicas
| Entidad / Chequeo | Filas / Resultado | Estado | Criterio de Aceptación |
|---|---|---|---|
| `categoria` | 10 filas | OK | Coincide 100% con pre-respaldo |
| `cliente` (vista s/ `usuario`) | 10.000 filas | OK | Coincide 100% con pre-respaldo |
| `producto` | 20.000 filas | OK | Coincide 100% con pre-respaldo |
| `pedido` | 80.000 filas | OK | Coincide 100% con pre-respaldo |
| `detalle_pedido` | 240.000 filas | OK | Coincide 100% con pre-respaldo |
| *Productos inválidos* (`precio < 0 OR stock < 0`) | **0 anomalías** | OK | Cero absoluto exigido |
| *Detalles inválidos* (`cantidad <= 0 OR precio_unitario < 0`) | **0 anomalías** | OK | Cero absoluto exigido |

### 4. Problema Real Encontrado y Resolución
Durante la validación automatizada se presentaron dos contingencias técnicas:
1. **Discrepancia de Nomenclatura (`cliente` vs. `usuario`):** El script de validación unificada de la cátedra consultaba la relación `cliente`, mientras que el modelo relacional canónico de Food Store almacena los registros en `usuario`. Para resolverlo sin alterar la integridad estructural, se definió la vista `CREATE VIEW cliente AS SELECT * FROM usuario;`, garantizando transparencia e interoperabilidad con las pruebas.
2. **Manejo de Stderr en PowerShell:** El comando `dropdb --if-exists` emitía un `NOTICE` informativo en `stderr` al no existir la base en el primer intento, interpretado como excepción fatal por `$ErrorActionPreference = "Stop"`. Se refactorizó encapsulándolo con `Start-Process` y captura selectiva de `$LASTEXITCODE`.

### 5. Mejora Concreta para la Siguiente Ejecución
- **Restauración Concurrente Multihilo (`pg_restore -j`):** Configurar `pg_restore -j 4` para paralelizar la creación de tablas, índices y carga de datos sobre múltiples cores. Si bien para 3.25 MB el tiempo fue de 4.45 s, en bases de producción de decenas de gigabytes el flag `-j 4` reduce el RTO en más de un 60%.
- **Validación Criptográfica de Integridad:** Incorporar el cómputo del hash `SHA-256` en `backup_foodstore.ps1` y su comprobación previa en `restore_test.ps1`, evitando restaurar archivos truncados por fallas de red o disco.

### 6. Asistencia con OpenCode y Verificación Humana
OpenCode generó los esqueletos de los scripts de respaldo, monitoreo y restauración a partir de `SPEC_U6.md`. La intervención humana subordinó estrictamente a la IA en tres aspectos críticos:
1. **Prohibición de Bloqueos:** Se rechazó cualquier variante de `VACUUM FULL`, forzando el uso exclusivo de `VACUUM (ANALYZE)` concurrente para no generar denegación de servicio transaccional.
2. **Seguridad de Credenciales:** Se eliminó todo parámetro con claves en texto claro, forzando la autenticación mediante variable de entorno segura `PGPASSWORD`.
3. **Prueba Empírica en Terminal:** Los scripts se ejecutaron y ajustaron manualmente en PowerShell antes de su integración definitiva.
