package com.mycompany.pro.util;

import java.io.File;
import net.sf.jasperreports.engine.JasperCompileManager;

/**
 * Compila TODOS los .jrxml de la carpeta de reportes a .jasper
 * (el .jasper queda junto al .jrxml).
 *
 * Uso en NetBeans: clic derecho sobre este archivo > Run File (Mayus+F6).
 * Por defecto toma src/main/webapp/reportes relativo a la carpeta del proyecto.
 */
public class CompilarReportes {

    public static void main(String[] args) throws Exception {
        String ruta = args.length > 0 ? args[0] : "src/main/webapp/reportes";
        File dir = new File(ruta);
        File[] jrxmls = dir.listFiles((d, n) -> n.endsWith(".jrxml"));
        if (jrxmls == null || jrxmls.length == 0) {
            System.out.println("No se encontraron .jrxml en: " + dir.getAbsolutePath());
            return;
        }
        int ok = 0;
        int fallos = 0;
        for (File f : jrxmls) {
            String salida = f.getAbsolutePath().replaceAll("\\.jrxml$", ".jasper");
            try {
                JasperCompileManager.compileReportToFile(f.getAbsolutePath(), salida);
                System.out.println("OK     " + f.getName());
                ok++;
            } catch (Exception e) {
                System.out.println("FALLO  " + f.getName() + " -> " + e.getMessage());
                fallos++;
            }
        }
        System.out.println("Listo: " + ok + " compilados, " + fallos + " con error.");
    }
}
