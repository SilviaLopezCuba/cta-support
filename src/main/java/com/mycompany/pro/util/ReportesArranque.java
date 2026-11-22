package com.mycompany.pro.util;

import java.io.File;
import java.util.HashMap;
import java.util.Map;
import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import javax.servlet.annotation.WebListener;
import net.sf.jasperreports.engine.JREmptyDataSource;
import net.sf.jasperreports.engine.JasperExportManager;
import net.sf.jasperreports.engine.JasperFillManager;
import net.sf.jasperreports.engine.JasperPrint;
import net.sf.jasperreports.engine.JasperReport;

/**
 * Precalienta JasperReports al iniciar la aplicacion, en segundo plano.
 *
 * La primera impresion despues de arrancar Tomcat tardaba varios segundos porque
 * JasperReports carga sus clases, las fuentes y el exportador PDF recien en ese
 * momento, y ademas compila el reporte. Este listener hace ese trabajo apenas se
 * despliega la aplicacion, sin demorar el arranque (corre en un hilo aparte):
 *  - compila a .jasper los comprobantes e informes que no esten al dia;
 *  - deja en memoria los reportes de referenciales (ReporteUtil);
 *  - genera un PDF vacio en memoria para cargar el motor de llenado y el exportador.
 * Si algo falla, solo se registra en el log: la impresion normal sigue funcionando.
 */
@WebListener
public class ReportesArranque implements ServletContextListener {

    @Override
    public void contextInitialized(ServletContextEvent evento) {
        final ServletContext ctx = evento.getServletContext();
        Thread hilo = new Thread(() -> precalentar(ctx), "cta-reportes-arranque");
        hilo.setDaemon(true);
        hilo.setPriority(Thread.MIN_PRIORITY);
        hilo.start();
    }

    private void precalentar(ServletContext ctx) {
        long inicio = System.currentTimeMillis();
        String dir = ctx.getRealPath("/reportes");
        if (dir == null) {
            return;
        }
        File[] fuentes = new File(dir).listFiles((d, n) -> n.endsWith(".jrxml"));
        if (fuentes == null) {
            return;
        }
        String carpeta = dir.endsWith(File.separator) ? dir : dir + File.separator;
        JasperReport cualquiera = null;
        int listos = 0;
        for (File f : fuentes) {
            String nombre = f.getName().substring(0, f.getName().length() - ".jrxml".length());
            try {
                if (nombre.startsWith("reporte_")) {
                    cualquiera = ReporteUtil.cargar(ctx, nombre);
                } else {
                    ComprobanteUtil.compilarSiCambio(carpeta, nombre);
                }
                listos++;
            } catch (Exception e) {
                ctx.log("CTA reportes: no se pudo preparar " + nombre + ": " + e.getMessage());
            }
        }
        // Un llenado y una exportacion "en vacio" cargan el motor y el exportador PDF.
        if (cualquiera != null) {
            try {
                Map<String, Object> p = new HashMap<>();
                p.put("LOGO_PATH", carpeta + "logo_cta.jpg");
                JasperPrint jp = JasperFillManager.fillReport(cualquiera, p, new JREmptyDataSource(1));
                JasperExportManager.exportReportToPdf(jp);
            } catch (Exception e) {
                ctx.log("CTA reportes: precalentamiento del exportador omitido: " + e.getMessage());
            }
        }
        ctx.log("CTA reportes: " + listos + " reportes listos en " + (System.currentTimeMillis() - inicio) + " ms");
    }

    @Override
    public void contextDestroyed(ServletContextEvent evento) {
        // Nada que liberar: el hilo es de tipo daemon.
    }
}
