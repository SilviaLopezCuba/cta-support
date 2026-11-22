package com.mycompany.pro.util;

import java.io.File;
import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import javax.servlet.annotation.WebListener;

import net.sf.jasperreports.engine.JasperCompileManager;

/**
 * Al arrancar la aplicación compila, en segundo plano, los informes y comprobantes
 * (informe*.jrxml y comprobante*.jrxml) que no tengan su .jasper al día.
 * Así la primera impresión después de un "Clean and Build" no tiene que esperar la compilación.
 * Los reporte_*.jrxml ya los prepara ReportesArranque.
 */
@WebListener
public class InformesArranque implements ServletContextListener {

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        final ServletContext ctx = sce.getServletContext();
        Thread hilo = new Thread(new Runnable() {
            @Override
            public void run() {
                long inicio = System.currentTimeMillis();
                int compilados = 0;
                try {
                    String ruta = ctx.getRealPath("/reportes");
                    File[] archivos = ruta == null ? null : new File(ruta).listFiles();
                    if (archivos == null) return;
                    for (File jrxml : archivos) {
                        String n = jrxml.getName();
                        if (!n.endsWith(".jrxml") || !(n.startsWith("informe") || n.startsWith("comprobante"))) continue;
                        File jasper = new File(jrxml.getParent(), n.substring(0, n.length() - 6) + ".jasper");
                        if (jasper.exists() && jasper.lastModified() >= jrxml.lastModified()) continue;
                        try {
                            JasperCompileManager.compileReportToFile(jrxml.getAbsolutePath(), jasper.getAbsolutePath());
                            compilados++;
                        } catch (Exception ex) {
                            System.err.println("CTA informes: no se pudo compilar " + n + ": " + ex.getMessage());
                        }
                    }
                    System.out.println("CTA informes: " + compilados + " informes/comprobantes listos en " + (System.currentTimeMillis() - inicio) + " ms");
                } catch (Exception ex) {
                    System.err.println("CTA informes: arranque omitido: " + ex.getMessage());
                }
            }
        }, "cta-informes-arranque");
        hilo.setDaemon(true);
        hilo.setPriority(Thread.MIN_PRIORITY);
        hilo.start();
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) { }
}
