<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%><%@page import="com.mycompany.pro.util.InformeVistaUtil"%><%@page import="com.mycompany.pro.util.InformeUtil"%><%@page import="com.mycompany.pro.util.ComprobanteUtil"%><%@include file="../config/conexion.jsp"%><%@include file="../config/informeComun.jsp"%><%
    // Informe de Existencias
    //  accion=datos   -> indicadores + tabla en pantalla
    //  (sin accion)   -> PDF general del período con los mismos filtros
    //  accion=combos  -> opciones de los filtros (JSON)
    String rolInf = (String) session.getAttribute("nombreRol");
    boolean esAdminInf = "Administrador".equals(rolInf), esEncInf = "Encargado de depósito".equals(rolInf), esTecInf = "Técnico".equals(rolInf);
    Integer idUsuarioInf = (Integer) session.getAttribute("idUsuario");
    try {
        if (!(esAdminInf || esEncInf) || idUsuarioInf == null) {
            response.setContentType("text/plain;charset=UTF-8");
            out.print("error: no tiene permiso para este informe");
            return;
        }
        String accion = request.getParameter("accion");
        String hoyInf = java.time.LocalDate.now().toString();
        String fechaDesde = hoyInf, fechaHasta = hoyInf;
        java.util.List<String> condiciones = new java.util.ArrayList<String>();
        condiciones.add(InformeUtil.condicionExacta("a.tipo", request.getParameter("tipo"), new java.util.HashSet<String>(java.util.Arrays.asList("Repuesto", "Insumo"))));
        condiciones.add(InformeUtil.condicionExacta("CASE WHEN a.stock <= 0 THEN 'Sin stock' WHEN a.minimo > 0 AND a.stock < a.minimo THEN 'Bajo mínimo' ELSE 'Normal' END", request.getParameter("situacion"), new java.util.HashSet<String>(java.util.Arrays.asList("Sin stock", "Bajo mínimo", "Normal"))));
        condiciones.add(InformeUtil.condicionTexto("a.nombre", request.getParameter("articulo")));
        String filtros = InformeUtil.combinar(condiciones.toArray(new String[0]));
        if (filtros == null || filtros.trim().isEmpty()) filtros = "1=1";
        String origen = "FROM (SELECT 'Repuesto'::text AS tipo, r.nombre, COALESCE(cat.nombre_categoria, '—') AS grupo, r.stock::numeric AS stock, COALESCE(r.stock_minimo, 0)::numeric AS minimo, COALESCE(r.stock_danado, 0) AS danado, COALESCE(r.ultimo_costo, 0) AS costo FROM public.catalogo_repuestos r LEFT JOIN public.categorias cat ON cat.id_categoria = r.id_categoria UNION ALL SELECT 'Insumo', i.nombre, COALESCE(um.nombre_unidad, '—'), COALESCE(i.stock, 0), COALESCE(i.stock_minimo, 0), COALESCE(i.stock_danado, 0), COALESCE(i.ultimo_costo, 0) FROM public.catalogo_insumos i LEFT JOIN public.unidades_medida um ON um.id_unidad = i.id_unidad) a WHERE CAST(? AS date) IS NOT NULL AND CAST(? AS date) IS NOT NULL" + " AND (" + filtros + ")";
        String[][] metricas = {
            {"Artículos", "COUNT(*)", "N", "fa-boxes", "info"},
            {"Bajo el mínimo", "COUNT(*) FILTER (WHERE a.minimo > 0 AND a.stock < a.minimo AND a.stock > 0)", "N", "fa-arrow-down", "warning"},
            {"Sin stock", "COUNT(*) FILTER (WHERE a.stock <= 0)", "N", "fa-times-circle", "danger"},
            {"Unidades dañadas", "COALESCE(SUM(a.danado), 0)", "D", "fa-heart-broken", "secondary"},
            {"Valor del depósito", "COALESCE(SUM(a.stock * a.costo), 0)", "M", "fa-coins", "success"}
        };
        if ("datos".equals(accion) || "detalle".equals(accion)) {
            InformeVistaUtil.Informe inf = new InformeVistaUtil.Informe("Informe de Existencias")
                .columnas("a.tipo AS tipo, a.nombre AS nombre, a.grupo AS grupo, replace(rtrim(to_char(a.stock, 'FM999999990.99'), '.'), '.', ',') AS stock, replace(rtrim(to_char(a.minimo, 'FM999999990.99'), '.'), '.', ',') AS minimo, replace(rtrim(to_char(a.danado, 'FM999999990.99'), '.'), '.', ',') AS danado, CASE WHEN a.stock <= 0 THEN 'Sin stock' WHEN a.minimo > 0 AND a.stock < a.minimo THEN 'Bajo mínimo' ELSE 'Normal' END AS situacion, replace(to_char(round(a.costo), 'FM999,999,999,990'), ',', '.') AS costo, replace(to_char(round(a.stock * a.costo), 'FM999,999,999,990'), ',', '.') AS valor",
                        "Tipo", "Artículo", "Categoría / unidad", "Stock", "Mínimo", "Dañado", "Situación", "Último costo", "Valor (Gs.)")
                .origen(origen)
                .orden("a.tipo DESC, a.nombre");
            inf.filtro("Situación al", new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(new java.util.Date()));
            { String v_tipo = request.getParameter("tipo"); inf.filtro("Tipo", v_tipo == null || v_tipo.isEmpty() ? null : ("Repuesto".equals(v_tipo) ? "Repuesto" : "Insumo".equals(v_tipo) ? "Insumo" : v_tipo)); }
            { String v_situacion = request.getParameter("situacion"); inf.filtro("Situación", v_situacion == null || v_situacion.isEmpty() ? null : ("Sin stock".equals(v_situacion) ? "Sin stock" : "Bajo mínimo".equals(v_situacion) ? "Bajo mínimo" : "Normal".equals(v_situacion) ? "Normal" : v_situacion)); }
            inf.filtro("Artículo contiene", request.getParameter("articulo"));
            if ("datos".equals(accion)) {
                response.setContentType("text/html;charset=UTF-8");
                try {
                    out.print(metricasHtml(conexion, origen, metricas, fechaDesde, fechaHasta));
                    out.print(InformeVistaUtil.pantalla(conexion, inf, fechaDesde, fechaHasta));
                } catch (Exception exVista) {
                    out.print(InformeVistaUtil.errorHtml(exVista));
                    exVista.printStackTrace();
                }
                return;
            }
            response.setContentType("text/plain;charset=UTF-8");
            out.print("error: este informe no tiene comprobante detallado");
            return;
        }
        // PDF general
        java.util.Map<String, Object> par = new java.util.HashMap<String, Object>();
        par.put("DESDE", fechaDesde);
        par.put("HASTA", fechaHasta);
        par.put("FILTROS", filtros);
        par.put("USUARIO_GENERA", ComprobanteUtil.nombreUsuario(conexion, idUsuarioInf));
        par.put("RESUMEN", resumenInforme(conexion, origen, metricas, fechaDesde, fechaHasta));
        par.put("SUBTITULO", "Situación al " + new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(new java.util.Date()));
        enviarInformePdf(response, application, conexion, "informeExistencias", par, "informeExistencias");
    } catch (Exception ex) {
        response.setContentType("text/plain;charset=UTF-8");
        out.print("error al generar el informe: " + mensajeError(ex));
        ex.printStackTrace();
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
