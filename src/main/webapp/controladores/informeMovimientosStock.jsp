<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%><%@page import="com.mycompany.pro.util.InformeVistaUtil"%><%@page import="com.mycompany.pro.util.InformeUtil"%><%@page import="com.mycompany.pro.util.ComprobanteUtil"%><%@include file="../config/conexion.jsp"%><%@include file="../config/informeComun.jsp"%><%
    // Informe de Movimientos de Stock
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
        String fechaDesde = request.getParameter("fechaInicio");
        String fechaHasta = request.getParameter("fechaFin");
        if (fechaDesde == null || fechaDesde.trim().isEmpty() || fechaHasta == null || fechaHasta.trim().isEmpty()) {
            response.setContentType("text/plain;charset=UTF-8");
            out.print("error: debe indicar Fecha Inicio y Fecha Fin");
            return;
        }
        java.util.List<String> condiciones = new java.util.ArrayList<String>();
        condiciones.add(InformeUtil.condicionExacta("m.tipo_movimiento", request.getParameter("movimiento"), new java.util.HashSet<String>(java.util.Arrays.asList("ENTRADA", "ENTREGA", "DEVOLUCION", "AJUSTE", "SALDO INICIAL"))));
        condiciones.add(InformeUtil.condicionExacta("m.tipo_articulo", request.getParameter("tipoArticulo"), new java.util.HashSet<String>(java.util.Arrays.asList("R", "I"))));
        condiciones.add(InformeUtil.condicionTexto("COALESCE(r.nombre, i.nombre)", request.getParameter("articulo")));
        String filtros = InformeUtil.combinar(condiciones.toArray(new String[0]));
        if (filtros == null || filtros.trim().isEmpty()) filtros = "1=1";
        String origen = "FROM public.movimientos_stock m LEFT JOIN public.catalogo_repuestos r ON m.tipo_articulo = 'R' AND r.id_repuesto = m.id_articulo LEFT JOIN public.catalogo_insumos i ON m.tipo_articulo = 'I' AND i.id_insumo = m.id_articulo LEFT JOIN public.usuarios u ON u.id_usuario = m.id_usuario LEFT JOIN public.personas p ON p.id_persona = u.id_persona WHERE m.fecha::date BETWEEN CAST(? AS date) AND CAST(? AS date)" + " AND (" + filtros + ")";
        String[][] metricas = {
            {"Movimientos", "COUNT(*)", "N", "fa-exchange-alt", "info"},
            {"Entradas", "COUNT(*) FILTER (WHERE m.tipo_movimiento = 'ENTRADA')", "N", "fa-truck-loading", "success"},
            {"Entregas a técnicos", "COUNT(*) FILTER (WHERE m.tipo_movimiento = 'ENTREGA')", "N", "fa-hand-holding", "primary"},
            {"Devoluciones", "COUNT(*) FILTER (WHERE m.tipo_movimiento = 'DEVOLUCION')", "N", "fa-undo", "secondary"},
            {"Ajustes", "COUNT(*) FILTER (WHERE m.tipo_movimiento = 'AJUSTE')", "N", "fa-balance-scale", "warning"},
            {"Unidades que entraron", "COALESCE(SUM(m.cantidad) FILTER (WHERE m.cantidad > 0), 0)", "D", "fa-arrow-down", "success"},
            {"Unidades que salieron", "COALESCE(-SUM(m.cantidad) FILTER (WHERE m.cantidad < 0), 0)", "D", "fa-arrow-up", "danger"}
        };
        if ("datos".equals(accion) || "detalle".equals(accion)) {
            InformeVistaUtil.Informe inf = new InformeVistaUtil.Informe("Informe de Movimientos de Stock")
                .columnas("to_char(m.fecha, 'DD/MM/YYYY HH24:MI') AS fecha, CASE m.tipo_movimiento WHEN 'ENTRADA' THEN 'Entrada por recepción' WHEN 'ENTREGA' THEN 'Entrega a técnico' WHEN 'DEVOLUCION' THEN 'Devolución del técnico' WHEN 'AJUSTE' THEN 'Ajuste de inventario' WHEN 'SALDO INICIAL' THEN 'Saldo inicial' WHEN 'DAÑO' THEN 'Daño' WHEN 'SALIDA' THEN 'Salida' ELSE initcap(lower(m.tipo_movimiento)) END AS movimiento, COALESCE(r.nombre, i.nombre, '—') AS articulo, CASE m.tipo_articulo WHEN 'R' THEN 'Repuesto' ELSE 'Insumo' END AS tipo, CASE WHEN m.cantidad > 0 THEN replace(rtrim(to_char(m.cantidad, 'FM999999990.99'), '.'), '.', ',') ELSE '' END AS entra, CASE WHEN m.cantidad < 0 THEN replace(rtrim(to_char(-m.cantidad, 'FM999999990.99'), '.'), '.', ',') ELSE '' END AS sale, replace(rtrim(to_char(m.stock_nuevo, 'FM999999990.99'), '.'), '.', ',') AS saldo, COALESCE(m.observacion, '') AS documento, COALESCE(p.apellido || ', ' || p.nombre, u.login, '—') AS usuario",
                        "Fecha", "Movimiento", "Artículo", "Tipo", "Entra", "Sale", "Saldo", "Documento", "Usuario")
                .origen(origen)
                .orden("m.fecha, m.id_movimiento");
            { String v_movimiento = request.getParameter("movimiento"); inf.filtro("Movimiento", v_movimiento == null || v_movimiento.isEmpty() ? null : ("ENTRADA".equals(v_movimiento) ? "Entrada por recepción" : "ENTREGA".equals(v_movimiento) ? "Entrega a técnico" : "DEVOLUCION".equals(v_movimiento) ? "Devolución del técnico" : "AJUSTE".equals(v_movimiento) ? "Ajuste de inventario" : "SALDO INICIAL".equals(v_movimiento) ? "Saldo inicial" : v_movimiento)); }
            { String v_tipoArticulo = request.getParameter("tipoArticulo"); inf.filtro("Tipo", v_tipoArticulo == null || v_tipoArticulo.isEmpty() ? null : ("R".equals(v_tipoArticulo) ? "Repuesto" : "I".equals(v_tipoArticulo) ? "Insumo" : v_tipoArticulo)); }
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
        enviarInformePdf(response, application, conexion, "informeMovimientosStock", par, "informeMovimientosStock");
    } catch (Exception ex) {
        response.setContentType("text/plain;charset=UTF-8");
        out.print("error al generar el informe: " + mensajeError(ex));
        ex.printStackTrace();
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
