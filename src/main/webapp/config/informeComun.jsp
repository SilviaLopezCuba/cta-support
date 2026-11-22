<%!
    /**
     * Ayudas comunes de los INFORMES.
     *  resumenInforme: arma el texto de resumen del PDF ("Pendientes: 2 · Entregados: 5 ...")
     *                  con las mismas métricas que se ven en pantalla.
     *  enviarInformePdf: compila (si cambió) y llena el .jrxml del informe y lo envía como PDF.
     */
    /** Ejecuta las métricas y devuelve sus valores ya formateados (o null si falla). */
    static String[] valoresMetricas(java.sql.Connection c, String origen, String[][] metricas, String desde, String hasta) {
        if (metricas == null || metricas.length == 0) return null;
        StringBuilder sel = new StringBuilder("SELECT ");
        for (int i = 0; i < metricas.length; i++) sel.append(i == 0 ? "" : ", ").append(metricas[i][1]);
        sel.append(" ").append(origen);
        try (java.sql.PreparedStatement ps = c.prepareStatement(sel.toString())) {
            ps.setString(1, desde);
            ps.setString(2, hasta);
            try (java.sql.ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return null;
                java.text.DecimalFormatSymbols sim = new java.text.DecimalFormatSymbols(new java.util.Locale("es", "PY"));
                sim.setGroupingSeparator('.'); sim.setDecimalSeparator(',');
                java.text.DecimalFormat fEnt = new java.text.DecimalFormat("#,##0", sim), fDec = new java.text.DecimalFormat("#,##0.0", sim);
                String[] r = new String[metricas.length];
                for (int i = 0; i < metricas.length; i++) {
                    Object v = rs.getObject(i + 1);
                    if (v == null) r[i] = "—";
                    else if (v instanceof Number) {
                        double d = ((Number) v).doubleValue();
                        r[i] = "D".equals(metricas[i][2]) ? fDec.format(d) : fEnt.format(Math.round(d));
                        if ("M".equals(metricas[i][2])) r[i] = "Gs. " + r[i];
                    } else r[i] = v.toString();
                }
                return r;
            }
        } catch (Exception e) {
            return null;
        }
    }

    /** Indicadores de la parte superior del informe en pantalla (metricas: etiqueta, sql, formato N/D/M, ícono, color). */
    static String metricasHtml(java.sql.Connection c, String origen, String[][] metricas, String desde, String hasta) {
        String[] v = valoresMetricas(c, origen, metricas, desde, hasta);
        if (v == null) return "";
        StringBuilder sb = new StringBuilder("<div class='row'>");
        for (int i = 0; i < metricas.length; i++) {
            String color = metricas[i].length > 4 ? metricas[i][4] : "info", icono = metricas[i].length > 3 ? metricas[i][3] : "fa-chart-bar";
            sb.append("<div class='col-6 col-md-4 col-xl-2'><div class='info-box shadow-sm mb-3'><span class='info-box-icon bg-").append(color)
              .append("'><i class='fas ").append(icono).append("'></i></span><div class='info-box-content'><span class='info-box-text text-wrap' style='font-size:.8rem'>")
              .append(InformeEsc(metricas[i][0])).append("</span><span class='info-box-number'>").append(InformeEsc(v[i])).append("</span></div></div></div>");
        }
        return sb.append("</div>").toString();
    }
    private static String InformeEsc(String s) { return s == null ? "" : s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"); }

    static String resumenInforme(java.sql.Connection c, String origen, String[][] metricas, String desde, String hasta) {
        String[] v = valoresMetricas(c, origen, metricas, desde, hasta);
        if (v == null) return null;
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < metricas.length; i++) {
            if (sb.length() > 0) sb.append("     ");
            sb.append(metricas[i][0]).append(": ").append(v[i]);
        }
        return sb.toString();
    }

    /**
     * Reportes ya compilados, en memoria: así cada impresión no vuelve a leer ni compilar el .jrxml.
     * Se recompila solo si el .jrxml cambió (fecha de modificación distinta).
     */
    private static final java.util.concurrent.ConcurrentHashMap<String, Object[]> CACHE_INFORMES = new java.util.concurrent.ConcurrentHashMap<String, Object[]>();

    static net.sf.jasperreports.engine.JasperReport informeCompilado(javax.servlet.ServletContext ctx, String reporte) throws Exception {
        String rutaJrxml = ctx.getRealPath("reportes/" + reporte + ".jrxml");
        long modif = new java.io.File(rutaJrxml).lastModified();
        Object[] c = CACHE_INFORMES.get(rutaJrxml);
        if (c != null && ((Long) c[0]).longValue() == modif) return (net.sf.jasperreports.engine.JasperReport) c[1];
        synchronized (CACHE_INFORMES) {
            c = CACHE_INFORMES.get(rutaJrxml);
            if (c != null && ((Long) c[0]).longValue() == modif) return (net.sf.jasperreports.engine.JasperReport) c[1];
            String rutaJasper = ctx.getRealPath("reportes/" + reporte + ".jasper");
            java.io.File jasper = new java.io.File(rutaJasper);
            net.sf.jasperreports.engine.JasperReport jr;
            if (jasper.exists() && jasper.lastModified() >= modif) {
                jr = (net.sf.jasperreports.engine.JasperReport) net.sf.jasperreports.engine.util.JRLoader.loadObject(jasper);
            } else {
                jr = net.sf.jasperreports.engine.JasperCompileManager.compileReport(rutaJrxml);
                try { net.sf.jasperreports.engine.util.JRSaver.saveObject(jr, jasper); } catch (Exception exGuardar) { /* solo cache en memoria */ }
            }
            CACHE_INFORMES.put(rutaJrxml, new Object[]{Long.valueOf(modif), jr});
            return jr;
        }
    }

    static void enviarInformePdf(javax.servlet.http.HttpServletResponse resp, javax.servlet.ServletContext ctx, java.sql.Connection c,
                                 String reporte, java.util.Map<String, Object> parametros, String archivo) throws Exception {
        net.sf.jasperreports.engine.JasperReport jr = informeCompilado(ctx, reporte);
        parametros.put("LOGO_PATH", ctx.getRealPath("reportes/logo_cta.jpg"));
        net.sf.jasperreports.engine.JasperPrint jp = net.sf.jasperreports.engine.JasperFillManager.fillReport(jr, parametros, c);
        byte[] bytes = net.sf.jasperreports.engine.JasperExportManager.exportReportToPdf(jp);
        resp.setContentType("application/pdf");
        resp.setContentLength(bytes.length);
        resp.setHeader("Content-Disposition", "inline; filename=" + archivo + ".pdf");
        javax.servlet.ServletOutputStream salida = resp.getOutputStream();
        salida.write(bytes, 0, bytes.length);
        salida.flush();
        salida.close();
    }
%>
