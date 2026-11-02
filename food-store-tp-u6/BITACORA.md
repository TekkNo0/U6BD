# BITÁCORA — Uso de IA en el TP Unidad 6 (Food Store)

**Alumno:** Maximiliano Nardez  
**Materia:** Base de Datos II — Unidad 6: Mantenimiento, respaldo y recuperación  
**Base principal:** `foodstore` · **Base de recuperación:** `foodstore_restore_test` · PostgreSQL 17  
**Asistente de IA:** OpenCode (asistente de terminal con acceso a shell, código y base de datos)  
**Control de versiones:** Git  

---

## 1. Tabla consolidada de uso de IA (Formato obligatorio de 3 columnas)

A continuación se presenta la tabla de tres columnas requerida por la cátedra, resumiendo las interacciones clave con el asistente de IA a lo largo de las distintas etapas del trabajo práctico de la Unidad 6:

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| **[Parte 1 — Especificación del plan]:** *"Generá la matriz operativa para SPEC_U6.md cubriendo backup diario, health check, mantenimiento semanal y ensayo de restauración con sus condiciones de éxito."* | Proveyó tabla con las 4 tareas mínimas y sugirió RPO de 24 horas y RTO de 15 minutos con ventanas arbitrarias. | **Ajustado por el equipo:** Se ajustó el RTO a $\le$ 10 minutos conforme a los SLAs de Food Store, se formalizaron las ventanas de baja carga (02:00 AM para backup, 06:00 AM pre-operativa para health check) y se incluyó la prohibición estricta de `VACUUM FULL`. |
| **[Parte 2 — Script de respaldo]:** *"Escribí un script backup_foodstore.ps1 para volcar foodstore en formato Custom (-Fc), registrando logs con fecha/hora y fallando con código 1 ante errores."* | Generó el script usando `pg_dump`, pero inicialmente sugirió recibir la contraseña como parámetro `$Password` en texto claro o dejar que pida interactivamente. | **CORREGIDO / HARDENING DE SEGURIDAD:** Se rechazó cualquier parámetro de clave. Se configuró autenticación obligatoria y transparente vía `$env:PGPASSWORD` o archivo protegido `.pgpass`. Se agregó validación de tamaño ($> 0$ bytes) y borrado defensivo de dumps parciales corruptos. |
| **[Parte 3 — Monitoreo y mantenimiento (CASO EXIGIDO)]:** *"Proponé las consultas para health_check.sql y el mantenimiento para maintenance.sql a fin de optimizar tablas y espacio."* | Para `maintenance.sql`, propuso ejecutar `VACUUM FULL foodstore;` argumentando que *"es la forma más rápida y completa de devolver espacio al sistema operativo"*. | **RECHAZADO TAJANTEMENTE:** El criterio de la cátedra prohíbe `VACUUM FULL` como mantenimiento periódico. Bloquea la tabla con `AccessExclusiveLock`, impidiendo lecturas y escrituras y dejando offline a Food Store. Se implementó `VACUUM (ANALYZE, VERBOSE)` concurrente (`ShareUpdateExclusiveLock`). |
| **[Parte 4 — Automatización de restauración]:** *"Creá restore_test.ps1 para automatizar el simulacro: medir RTO con cronómetro, calcular RPO, recrear foodstore_restore_test y correr las 3 validaciones mínimas."* | Creó la lógica con `Stopwatch`, `dropdb`, `createdb`, `pg_restore` y las consultas de validación del PDF (`categoria`, `cliente`, `producto`, etc.). | **Depuración técnica humana:** (1) Al correr la validación falló porque no existía la tabla `cliente` (los datos residen en `usuario`). Se resolvió creando la vista `CREATE VIEW cliente AS SELECT * FROM usuario;`. (2) En PowerShell 5.1 se corrigió el manejo de `dropdb --if-exists` para evitar que `NOTICE` en `stderr` interrumpa la ejecución. |
| **[Parte 5 — Síntesis de informe post-incidente]:** *"Estructurá el informe post-incidente en exactamente una página con los valores reales observados (RPO 3.83 min, RTO 4.45 s), los problemas reales y las mejoras."* | Organizó las 6 secciones requeridas destacando el cumplimiento de RTO/RPO y sugirió agregar paralelismo `-j` en `pg_restore`. | **Validado y compilado:** Se corroboraron las métricas exactas observadas en el simulacro contra reloj, se redactó `informe_u6.md` y se compiló a `informe_u6.pdf` garantizando que ocupe exactamente 1 página sin desbordes. |

---

## 2. Desarrollo detallado por partes

### Parte 1 — Especificación y plan de mantenimiento (`SPEC_U6.md`)
- **Uso de IA:** Se solicitó a OpenCode una plantilla estructurada de una página que cubra el ciclo completo de respaldo, monitoreo preventivo, revisión de mantenimiento y simulacro periódico.
- **Validación humana:** Se aseguró que `SPEC_U6.md` cumpla taxativamente con el formato conciso de una página y establezca con claridad los criterios de parada objetivos (retornos `0` de procesos, ausencia de errores lógicos y cotejo de cardinalidad).

### Parte 2 — Respaldo automatizable (`backup_foodstore.ps1` / `.sh`)
- **Uso de IA:** Generación del código de automatización en PowerShell y Bash.
- **Validación y ajustes humanos:**
  - Se implementó la búsqueda dinámica del binario `pg_dump.exe` en las rutas de instalación estándar de PostgreSQL 17 en Windows para evitar dependencias frágiles de PATH.
  - Se eliminó el uso del operador null-conditional `?.` de PowerShell 7 para mantener retrocompatibilidad total con PowerShell 5.1 nativo de Windows.
  - Se comprobó manualmente la ejecución exitosa generando `foodstore_20261102_165455.dump` (3.25 MB) en 1.03 segundos.
  - Se probó el camino negativo con una base ficticia, constatando la captura del error en `logs/`, la eliminación del archivo parcial y la salida con código de error `1`.

### Parte 3 — Monitoreo y mantenimiento (`health_check.sql` y `maintenance.sql`)
- **Uso de IA:** Redacción de las 4 consultas de monitoreo de `health_check.sql` y el flujo de mantenimiento.
- **Validación humana:**
  - Se ejecutó `health_check.sql` comprobando tamaño de base (50 MB), conexiones activas, tasa de transacciones y ausencia de consultas bloqueadas.
  - Se estructuró `maintenance.sql` en 4 pasos claros: inspección de parámetros de autovacuum, cálculo del umbral dinámico de tuplas muertas, ejecución de `VACUUM (ANALYZE, VERBOSE)` sobre tablas transaccionales y maestras, y verificación de actualización de `last_vacuum` y `last_analyze`.

### Parte 4 — Simulacro de desastre contra reloj (`restore_test.ps1`)
- **Uso de IA:** Asistencia para el cronómetro de alta precisión con `[System.Diagnostics.Stopwatch]`.
- **Validación humana:**
  - Se ejecutó el simulacro completo sobre la base descartable `foodstore_restore_test`.
  - Cronómetro total observado (RTO): **4.45 segundos**, ampliamente por debajo del umbral admisible de 10 minutos.
  - Antigüedad del dump (RPO observado): **3.83 minutos**.
  - Validación de cardinalidad: `categoria` (10), `cliente` (10.000), `producto` (20.000), `pedido` (80.000), `detalle_pedido` (240.000).
  - Validación semántica: 0 productos inválidos y 0 detalles inválidos.

### Parte 5 — Informe post-incidente (`informe_u6.md` / `informe_u6.pdf`)
- **Uso de IA:** Generación de la estructura del informe y script `generate_pdf.py` con ReportLab.
- **Validación humana:** Se verificó que el archivo `informe_u6.pdf` resultante posea una diagramación profesional en cuadrícula y tablas, sin exceder bajo ningún concepto el límite estricto de una página A4.

---

## 3. Caso exigido por la consigna — Propuesta riesgosa de la IA y corrección humana

Durante la elaboración de `maintenance.sql`, la IA sugirió la siguiente instrucción para optimizar la base de datos:

```sql
-- Propuesta errónea de la IA:
VACUUM FULL foodstore;
```

**Justificación dada por la IA:**  
*"El comando VACUUM FULL es la mejor alternativa ya que compacta físicamente las páginas en el disco, reescribe las tablas y recupera el 100% del espacio no utilizado por tuplas muertas, reduciendo el tamaño en disco de la base de datos al mínimo absoluto."*

**Decisión y corrección aplicada por el alumno (RECHAZO ENFÁTICO):**  
El equipo humano rechazó de inmediato la propuesta basándose en los principios fundamentales de administración de PostgreSQL y la consigna explícita del TP:
1. **Bloqueo exclusivo destructivo para la operación (`AccessExclusiveLock`):** `VACUUM FULL` adquiere un bloqueo exclusivo de máxima jerarquía que impide no sólo cualquier escritura (`INSERT`, `UPDATE`, `DELETE`), sino también cualquier lectura concurrente (`SELECT`). En una aplicación comercial como Food Store, ejecutar esto en horario productivo genera una indisponibilidad absoluta del servicio (caída para usuarios y cajas registradoras).
2. **Violación del criterio de la cátedra:** La consigna estipula textualmente: *"VACUUM FULL no debe utilizarse como mantenimiento periódico del trabajo"*.
3. **Alternativa segura aplicada:** Se implementó `VACUUM (ANALYZE, VERBOSE)` sobre cada tabla individual. Esta variante adquiere únicamente un lock ligero `ShareUpdateExclusiveLock`, permitiendo que el sistema transaccional continúe leyendo y escribiendo con normalidad mientras libera espacio interno en el Free Space Map (FSM) y actualiza las estadísticas del catálogo (`pg_statistic`) para el optimizador de consultas.
