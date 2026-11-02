# Trabajo Práctico - Unidad 6: Mantenimiento, Respaldo y Recuperación
**Proyecto Integrador:** Food Store | **Motor:** PostgreSQL 16+ (PostgreSQL 17)  
**Materia:** Base de Datos II — Semana 10 | **Alumno:** Maximiliano Nardez

---

## 📁 Estructura del Entregable

```text
food-store-tp-u6/
├── SPEC_U6.md               # [Parte 1] Especificación y plan de mantenimiento (1 página)
├── backup_foodstore.ps1     # [Parte 2] Script automatizado de respaldo (PowerShell)
├── backup_foodstore.sh      # [Parte 2] Script automatizado de respaldo (Bash/Linux)
├── health_check.sql         # [Parte 3] 4 controles de monitoreo y diagnóstico
├── maintenance.sql          # [Parte 3] Revisión y mantenimiento seguro sin VACUUM FULL
├── restore_test.ps1         # [Parte 4] Simulacro de desastre contra reloj y medición RTO/RPO
├── restore_test.sh          # [Parte 4] Simulacro contra reloj (Bash/Linux)
├── informe_u6.pdf           # [Parte 5] Informe post-incidente en 1 página (A4)
├── informe_u6.md            # Fuente Markdown del informe post-incidente
├── informe_u6.html          # Diagramación visual del informe
├── BITACORA.md              # Bitácora de asistencia con OpenCode (tabla de 3 columnas y caso exigido)
├── backups/                 # Almacenamiento de archivos .dump en formato custom (-Fc)
│   └── foodstore_20261102_165455.dump
├── docs/                    # Evidencias de ejecución capturadas
│   ├── backup_output.txt
│   ├── health_check_output.txt
│   ├── maintenance_output.txt
│   └── restore_test_output.txt
├── logs/                    # Trazas y registros de ejecución detallados
└── sql/
    └── validaciones_minimas.sql # Consultas de validación de integridad
```

---

## 🚀 Guía de Ejecución Rápida

### 1. Variables de entorno de autenticación (Sin contraseñas en código)
En PowerShell:
```powershell
$env:PGPASSWORD = "tu_password"
```

### 2. Generar Respaldo Automatizado
```powershell
powershell -ExecutionPolicy Bypass -File .\backup_foodstore.ps1
```
*Genera el dump custom en `backups/` y el log con duración y tamaño en `logs/`.*

### 3. Ejecutar Chequeo de Salud (Health Check)
```powershell
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -h localhost -p 5432 -d foodstore -f .\health_check.sql
```

### 4. Ejecutar Mantenimiento Concurrente Justificado
```powershell
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -h localhost -p 5432 -d foodstore -f .\maintenance.sql
```
*(No utiliza `VACUUM FULL`, garantizando cero bloqueos a usuarios concurrentes).*

### 5. Ejecutar Simulacro de Desastre Contra Reloj (Medición de RTO y RPO)
```powershell
powershell -ExecutionPolicy Bypass -File .\restore_test.ps1
```
*Crea la base descartable `foodstore_restore_test`, restaura el último dump, ejecuta las 3 validaciones de integridad y calcula el RTO cronometrado y el RPO.*

---

## 📊 Resumen de Resultados del Simulacro

- **Base de producción:** `foodstore` (inalterada durante todo el simulacro).
- **Base descartable de prueba:** `foodstore_restore_test`.
- **RPO Observado:** **3.83 minutos** (Objetivo planificado: $\le 24$ h).
- **RTO Observado:** **4.45 segundos** (Objetivo planificado: $\le 10$ min).
- **Validación de tablas:**
  - `categoria`: 10 filas (100% OK)
  - `cliente`: 10.000 filas (100% OK)
  - `producto`: 20.000 filas (100% OK)
  - `pedido`: 80.000 filas (100% OK)
  - `detalle_pedido`: 240.000 filas (100% OK)
- **Controles de integridad semántica:**
  - Productos inválidos (`precio < 0 OR stock < 0`): **0**
  - Detalles inválidos (`cantidad <= 0 OR precio_unitario < 0`): **0**
- **Estado final:** **100% APROBADO TÉCNICAMENTE**.
