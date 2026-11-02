import os
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_footer(num_pages)
            super().showPage()
        super().save()

    def draw_footer(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 7.5)
        self.setFillColor(colors.HexColor("#64748b"))
        footer_text_left = "Tecnicatura Universitaria en Programación | Base de Datos II — Unidad 6: Food Store"
        footer_text_right = f"Página {self._pageNumber} de {page_count}"
        self.drawString(28, 18, footer_text_left)
        self.drawRightString(A4[0] - 28, 18, footer_text_right)
        self.setStrokeColor(colors.HexColor("#cbd5e1"))
        self.setLineWidth(0.5)
        self.line(28, 28, A4[0] - 28, 28)
        self.restoreState()

def build_pdf():
    pdf_path = os.path.join(os.path.dirname(__file__), "informe_u6.pdf")
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=A4,
        leftMargin=28,
        rightMargin=28,
        topMargin=22,
        bottomMargin=34
    )

    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=14,
        textColor=colors.HexColor("#0f172a"),
        spaceAfter=1
    )
    
    subtitle_style = ParagraphStyle(
        'DocSub',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7.8,
        leading=10,
        textColor=colors.HexColor("#1e40af"),
        spaceAfter=4
    )

    meta_style = ParagraphStyle(
        'DocMeta',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.2,
        leading=9.5,
        textColor=colors.HexColor("#475569")
    )

    section_style = ParagraphStyle(
        'DocSec',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=8.2,
        leading=10.5,
        textColor=colors.HexColor("#1e3a8a"),
        spaceBefore=3,
        spaceAfter=2
    )

    body_style = ParagraphStyle(
        'DocBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.2,
        leading=9.2,
        textColor=colors.HexColor("#1e293b")
    )

    bullet_style = ParagraphStyle(
        'DocBullet',
        parent=body_style,
        leftIndent=10,
        firstLineIndent=-10,
        spaceAfter=1.5
    )

    table_cell_style = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7,
        leading=8.5,
        textColor=colors.HexColor("#0f172a")
    )
    
    table_cell_bold = ParagraphStyle(
        'TableCellBold',
        parent=table_cell_style,
        fontName='Helvetica-Bold'
    )

    story = []

    # Encabezado
    story.append(Paragraph("INFORME POST-INCIDENTE: SIMULACRO DE RECUPERACIÓN (U6)", title_style))
    story.append(Paragraph("Mantenimiento, Respaldo y Recuperación · Proyecto Food Store · PostgreSQL 17", subtitle_style))
    
    # Fila de Metadatos
    meta_text = "<b>Alumno:</b> Maximiliano Nardez &nbsp;|&nbsp; <b>Fecha:</b> 2026-11-02 &nbsp;|&nbsp; <b>Base Producción:</b> foodstore &nbsp;|&nbsp; <b>Base Descartable:</b> foodstore_restore_test"
    story.append(Paragraph(meta_text, meta_style))
    story.append(Spacer(1, 4))

    # Bloque 1 y 2 en 2 columnas (Tablita horizontal)
    b1_content = """<b>1. PARÁMETROS DEL RESPALDO</b><br/>
• <b>Archivo:</b> foodstore_20261102_165455.dump<br/>
• <b>Formato:</b> Custom (-Fc) binario comprimido<br/>
• <b>Tamaño:</b> 3.25 MB (compresión nativa)<br/>
• <b>Timestamp:</b> 2026-11-02 16:54:56<br/>
• <b>Seguridad:</b> Autenticación vía $env:PGPASSWORD"""

    b2_content = """<b>2. TIEMPOS OPERATIVOS: RPO Y RTO</b><br/>
• <b>RPO Previsto:</b> &le; 24 h (respaldo diario nocturno)<br/>
• <b>RPO Observado:</b> <b>3.83 min (0.06 h)</b> (antigüedad de dump)<br/>
• <b>RTO Previsto:</b> &le; 10 min (tiempo admisible)<br/>
• <b>RTO Observado:</b> <b>4.45 s</b> (cronómetro total) [SUPERADO]<br/>
• <b>Alcance RTO:</b> createdb + pg_restore + 3 validaciones"""

    box_data = [
        [Paragraph(b1_content, body_style), Paragraph(b2_content, body_style)]
    ]
    box_table = Table(box_data, colWidths=[265, 274])
    box_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#f8fafc")),
        ('BOX', (0,0), (-1,-1), 0.8, colors.HexColor("#cbd5e1")),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor("#e2e8f0")),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(box_table)
    story.append(Spacer(1, 3))

    # Sección 3: Validaciones
    story.append(Paragraph("3. RESULTADO DE VALIDACIONES DE INTEGRIDAD Y RESTRICCIONES LÓGICAS", section_style))
    val_data = [
        [
            Paragraph("<b>Entidad / Control Lógico</b>", table_cell_bold),
            Paragraph("<b>Filas / Resultado</b>", table_cell_bold),
            Paragraph("<b>Criterio de Aceptación</b>", table_cell_bold),
            Paragraph("<b>Veredicto</b>", table_cell_bold)
        ],
        [
            Paragraph("<code>categoria</code>", table_cell_style),
            Paragraph("10 filas", table_cell_style),
            Paragraph("Coincidencia 100% pre-respaldo", table_cell_style),
            Paragraph("<font color='#047857'><b>VALIDADO (100%)</b></font>", table_cell_style)
        ],
        [
            Paragraph("<code>cliente</code> (vista s/ usuario)", table_cell_style),
            Paragraph("10.000 filas", table_cell_style),
            Paragraph("Coincidencia 100% pre-respaldo", table_cell_style),
            Paragraph("<font color='#047857'><b>VALIDADO (100%)</b></font>", table_cell_style)
        ],
        [
            Paragraph("<code>producto</code>", table_cell_style),
            Paragraph("20.000 filas", table_cell_style),
            Paragraph("Coincidencia 100% pre-respaldo", table_cell_style),
            Paragraph("<font color='#047857'><b>VALIDADO (100%)</b></font>", table_cell_style)
        ],
        [
            Paragraph("<code>pedido</code>", table_cell_style),
            Paragraph("80.000 filas", table_cell_style),
            Paragraph("Coincidencia 100% pre-respaldo", table_cell_style),
            Paragraph("<font color='#047857'><b>VALIDADO (100%)</b></font>", table_cell_style)
        ],
        [
            Paragraph("<code>detalle_pedido</code>", table_cell_style),
            Paragraph("240.000 filas", table_cell_style),
            Paragraph("Coincidencia 100% pre-respaldo", table_cell_style),
            Paragraph("<font color='#047857'><b>VALIDADO (100%)</b></font>", table_cell_style)
        ],
        [
            Paragraph("<b>Productos inválidos</b> (precio &lt; 0 OR stock &lt; 0)", table_cell_style),
            Paragraph("<b>0 registros</b>", table_cell_style),
            Paragraph("Cero absoluto exigido", table_cell_style),
            Paragraph("<font color='#047857'><b>VALIDADO (0 Errores)</b></font>", table_cell_style)
        ],
        [
            Paragraph("<b>Detalles inválidos</b> (cantidad &le; 0 OR precio_unitario &lt; 0)", table_cell_style),
            Paragraph("<b>0 registros</b>", table_cell_style),
            Paragraph("Cero absoluto exigido", table_cell_style),
            Paragraph("<font color='#047857'><b>VALIDADO (0 Errores)</b></font>", table_cell_style)
        ],
    ]
    val_table = Table(val_data, colWidths=[180, 100, 140, 119])
    val_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#f1f5f9")),
        ('BOX', (0,0), (-1,-1), 0.8, colors.HexColor("#cbd5e1")),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor("#e2e8f0")),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(val_table)
    story.append(Spacer(1, 3))

    # Sección 4: Problemas Reales
    story.append(Paragraph("4. PROBLEMAS REALES ENCONTRADOS Y RESOLUCIÓN TÉCNICA", section_style))
    p1 = "• <b>Discrepancia de Nomenclatura (<code>cliente</code> vs. <code>usuario</code>):</b> La consulta de validación unificada requería consultar la entidad <code>cliente</code>, mientras que el modelo relacional canónico almacena a los clientes en la tabla <code>usuario</code>. Se resolvió creando la vista declarativa <code>CREATE VIEW cliente AS SELECT * FROM usuario;</code>, garantizando transparencia e interoperabilidad con las pruebas automáticas sin alterar la integridad estructural."
    p2 = "• <b>Manejo de Flujo en PowerShell 5.1:</b> El comando <code>dropdb --if-exists</code> emitía un <code>NOTICE</code> en <code>stderr</code> cuando la base descartable no existía previamente, lo cual era interpretado como excepción fatal por <code>$ErrorActionPreference = 'Stop'</code>. Se solucionó aislando la invocación mediante <code>Start-Process</code> con captura selectiva de <code>$LASTEXITCODE</code>."
    story.append(Paragraph(p1, bullet_style))
    story.append(Paragraph(p2, bullet_style))
    story.append(Spacer(1, 2))

    # Sección 5: Mejora Concreta
    story.append(Paragraph("5. MEJORA CONCRETA PARA REDUCIR RIESGO Y TIEMPO", section_style))
    m1 = "• <b>Restauración Concurrente Multihilo (<code>pg_restore -j 4</code>):</b> Configurar paralelismo multihilo aprovechando que el formato Custom (<code>-Fc</code>) contiene una tabla de contenidos (TOC). Esto permite que PostgreSQL restaure tablas e índices en paralelo en distintos núcleos de CPU, reduciendo el RTO en más de un 60% en bases productivas de alta volumetría."
    m2 = "• <b>Verificación Criptográfica de Integridad:</b> Incorporar el cómputo automático del hash <code>SHA-256</code> en <code>backup_foodstore.ps1</code> y su cotejo previo en <code>restore_test.ps1</code>, garantizando que el archivo no sufra corrupción o truncamiento previo al despliegue."
    story.append(Paragraph(m1, bullet_style))
    story.append(Paragraph(m2, bullet_style))
    story.append(Spacer(1, 2))

    # Sección 6: Asistencia OpenCode
    story.append(Paragraph("6. ASISTENCIA CON OPENCODE Y VERIFICACIÓN HUMANA SUBORDINADA", section_style))
    op1 = "OpenCode fue utilizado para redactar la primera versión de <code>SPEC_U6.md</code>, los scripts de PowerShell y las consultas de monitoreo. Toda propuesta de la IA fue rigurosamente supervisada y corregida por el equipo humano: (1) Se rechazó terminantemente el uso de <code>VACUUM FULL</code> por ser bloqueante (<code>AccessExclusiveLock</code>), exigiendo <code>VACUUM (ANALYZE)</code> concurrente para garantizar alta disponibilidad; (2) Se auditó que ningún script expusiera contraseñas, imponiendo autenticación mediante variables de entorno protegidas; y (3) Cada procedimiento fue testeado empíricamente en la base descartable <code>foodstore_restore_test</code> antes de su aprobación definitiva."
    story.append(Paragraph(op1, body_style))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF generado exitosamente en: {pdf_path}")

if __name__ == "__main__":
    build_pdf()
