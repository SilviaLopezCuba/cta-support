<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%><%@page import="com.mycompany.pro.util.InformeVistaUtil"%><%@page import="com.mycompany.pro.util.InformeUtil"%><%@page import="com.mycompany.pro.util.ComprobanteUtil"%><%@include file="../config/conexion.jsp"%><%@include file="../config/informeComun.jsp"%><%
    // Informe de Entradas al Depósito
    //  accion=datos   -> indicadores + tabla en pantalla
    //  (sin accion)   -> PDF general del período con los mismos filtros
    //  accion=combos  -> opciones de los filtros (JSON)
    //  accion=detalle / comprobante -> comprobantes detallados en PDF
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
        if ("combos".equals(accion)) {
            response.setContentType("application/json;charset=UTF-8");
            org.json.JSONObject jc = new org.json.JSONObject();
            {
                StringBuilder sbc = new StringBuilder("<option value=''>-- Todos --</option>");
                try (java.sql.ResultSet rc = conexion.prepareStatement("SELECT id_concepto, nombre_concepto FROM public.conceptos_entrada ORDER BY nombre_concepto").executeQuery()) {
                    while (rc.next()) sbc.append("<option value='").append(rc.getInt(1)).append("'>").append(h(rc.getString(2))).append("</option>");
                }
                jc.put("idConcepto", sbc.toString());
            }
            out.print(jc.toString());
            return;
        }
        if ("comprobante".equals(accion)) {
            java.util.List<Integer> pedidos = InformeVistaUtil.parsearIds(request.getParameter("ids"));
            StringBuilder csv = new StringBuilder();
            for (Integer idp : pedidos) { if (csv.length() > 0) csv.append(","); csv.append(idp.intValue()); }
            if (csv.length() == 0) { response.setContentType("text/plain;charset=UTF-8"); out.print("error: no se indico ningun registro"); return; }
            java.util.List<Integer> permitidos = InformeVistaUtil.consultarIds(conexion, "SELECT r.id_recepcion " + "FROM public.recepciones r LEFT JOIN public.conceptos_entrada ce ON ce.id_concepto = r.id_concepto LEFT JOIN public.donantes d ON d.id_donante = r.id_donante" + " WHERE r.id_recepcion IN (" + csv + ")" + (esTecInf ? "" : "") + " ORDER BY r.id_recepcion");
            String errC = enviarComprobantesInf(response, application, conexion, permitidos, idUsuarioInf, "comprobante_entrada");
            if (errC != null) { response.setContentType("text/plain;charset=UTF-8"); out.print(errC); }
            return;
        }
        String fechaDesde = request.getParameter("fechaInicio");
        String fechaHasta = request.getParameter("fechaFin");
        if (fechaDesde == null || fechaDesde.trim().isEmpty() || fechaHasta == null || fechaHasta.trim().isEmpty()) {
            response.setContentType("text/plain;charset=UTF-8");
            out.print("error: debe indicar Fecha Inicio y Fecha Fin");
            return;
        }
        java.util.List<String> condiciones = new java.util.ArrayList<String>();
        condiciones.add(InformeUtil.condicionEntero("r.id_concepto", request.getParameter("idConcepto")));
        condiciones.add(InformeUtil.condicionTexto("d.nombre", request.getParameter("donante")));
        String filtros = InformeUtil.combinar(condiciones.toArray(new String[0]));
        if (filtros == null || filtros.trim().isEmpty()) filtros = "1=1";
        String origen = "FROM public.recepciones r LEFT JOIN public.conceptos_entrada ce ON ce.id_concepto = r.id_concepto LEFT JOIN public.donantes d ON d.id_donante = r.id_donante WHERE r.estado = 'Confirmada' AND r.fecha_recepcion BETWEEN CAST(? AS date) AND CAST(? AS date)" + " AND (" + filtros + ")";
        String[][] metricas = {
            {"Entradas", "COUNT(*)", "N", "fa-truck-loading", "info"},
            {"Donaciones", "COUNT(*) FILTER (WHERE ce.nombre_concepto ILIKE '%don%')", "N", "fa-hand-holding-heart", "success"},
            {"Compras", "COUNT(*) FILTER (WHERE ce.nombre_concepto ILIKE '%compr%')", "N", "fa-shopping-cart", "primary"},
            {"Unidades de repuestos e insumos", "COALESCE(SUM((SELECT SUM(x.cantidad) FROM public.recepciones_detalle_articulos x WHERE x.id_recepcion = r.id_recepcion)), 0)", "D", "fa-boxes", "warning"},
            {"Equipos recibidos", "COALESCE(SUM((SELECT SUM(y.cantidad) FROM public.recepciones_detalle_equipos y WHERE y.id_recepcion = r.id_recepcion)), 0)", "N", "fa-desktop", "secondary"},
            {"Valor total", "COALESCE(SUM((COALESCE((SELECT SUM(x.cantidad * COALESCE(x.costo_unitario, 0)) FROM public.recepciones_detalle_articulos x WHERE x.id_recepcion = r.id_recepcion), 0) + COALESCE((SELECT SUM(y.cantidad * COALESCE(y.costo_unitario, 0)) FROM public.recepciones_detalle_equipos y WHERE y.id_recepcion = r.id_recepcion), 0))), 0)", "M", "fa-coins", "danger"}
        };
        if ("datos".equals(accion) || "detalle".equals(accion)) {
            InformeVistaUtil.Informe inf = new InformeVistaUtil.Informe("Informe de Entradas al Depósito")
                .columnas("r.numero_recepcion AS numero, to_char(r.fecha_recepcion, 'DD/MM/YYYY') AS fecha, ce.nombre_concepto AS concepto, COALESCE(d.nombre, '—') AS donante, COALESCE(r.nro_comprobante, '—') AS comprobante, (SELECT string_agg(COALESCE(cr.nombre, ci.nombre) || ' x' || replace(rtrim(to_char(x.cantidad, 'FM999999990.99'), '.'), '.', ','), ', ' ORDER BY x.id_detalle) FROM public.recepciones_detalle_articulos x LEFT JOIN public.catalogo_repuestos cr ON cr.id_repuesto = x.id_repuesto LEFT JOIN public.catalogo_insumos ci ON ci.id_insumo = x.id_insumo WHERE x.id_recepcion = r.id_recepcion) AS articulos, (SELECT string_agg(COALESCE(cat.nombre_categoria, 'Equipo') || COALESCE(' ' || y.modelo, '') || ' x' || y.cantidad, ', ' ORDER BY y.id_detalle) FROM public.recepciones_detalle_equipos y LEFT JOIN public.categorias cat ON cat.id_categoria = y.id_categoria WHERE y.id_recepcion = r.id_recepcion) AS equipos, replace(to_char(round((COALESCE((SELECT SUM(x.cantidad * COALESCE(x.costo_unitario, 0)) FROM public.recepciones_detalle_articulos x WHERE x.id_recepcion = r.id_recepcion), 0) + COALESCE((SELECT SUM(y.cantidad * COALESCE(y.costo_unitario, 0)) FROM public.recepciones_detalle_equipos y WHERE y.id_recepcion = r.id_recepcion), 0))), 'FM999,999,999,990'), ',', '.') AS valor",
                        "N° Entrada", "Fecha", "Concepto", "Donante / proveedor", "Comprobante", "Repuestos e insumos", "Equipos", "Valor (Gs.)")
                .origen(origen)
                .orden("r.fecha_recepcion, r.id_recepcion")
                .idRegistro("r.id_recepcion");
            inf.filtro("Concepto", InformeVistaUtil.etiqueta(conexion, "SELECT nombre_concepto FROM public.conceptos_entrada WHERE id_concepto = ?", request.getParameter("idConcepto")));
            inf.filtro("Donante / proveedor contiene", request.getParameter("donante"));
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
            String errD = enviarComprobantesInf(response, application, conexion, InformeVistaUtil.listarIds(conexion, inf, fechaDesde, fechaHasta), idUsuarioInf, "comprobante_entrada_detallado");
            if (errD != null) { response.setContentType("text/plain;charset=UTF-8"); out.print(errD); }
            return;
        }
        // PDF general
        java.util.Map<String, Object> par = new java.util.HashMap<String, Object>();
        par.put("DESDE", fechaDesde);
        par.put("HASTA", fechaHasta);
        par.put("FILTROS", filtros);
        par.put("USUARIO_GENERA", ComprobanteUtil.nombreUsuario(conexion, idUsuarioInf));
        par.put("RESUMEN", resumenInforme(conexion, origen, metricas, fechaDesde, fechaHasta));
        enviarInformePdf(response, application, conexion, "informeEntradas", par, "informeEntradas");
    } catch (Exception ex) {
        response.setContentType("text/plain;charset=UTF-8");
        out.print("error al generar el informe: " + mensajeError(ex));
        ex.printStackTrace();
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
<%!
    /** PDF con un comprobante por cada registro. Devuelve el mensaje de error, o null si el PDF ya se envió. */
    private String enviarComprobantesInf(javax.servlet.http.HttpServletResponse resp, javax.servlet.ServletContext ctx, java.sql.Connection cn,
                                       java.util.List<Integer> ids, Integer idUsuario, String archivo) throws Exception {
        if (ids == null || ids.isEmpty()) return "No hay registros para imprimir.";
        if (ids.size() > ComprobanteUtil.MAX_COMPROBANTES)
            return "El informe detallado admite hasta " + ComprobanteUtil.MAX_COMPROBANTES + " registros (se encontraron " + ids.size() + "). Acote el periodo o los filtros.";
        byte[] bytes = ComprobanteUtil.generar(cn, ctx.getRealPath("reportes"), "comprobanteRecepcion", new String[]{"comprobanteRecepcionEquipos", "comprobanteRecepcionArticulos"}, "ID_RECEPCION", ids, idUsuario);
        resp.setContentType("application/pdf");
        resp.setContentLength(bytes.length);
        resp.setHeader("Content-Disposition", "inline; filename=" + archivo + ".pdf");
        javax.servlet.ServletOutputStream so = resp.getOutputStream();
        so.write(bytes, 0, bytes.length);
        so.flush();
        so.close();
        return null;
    }
%>
