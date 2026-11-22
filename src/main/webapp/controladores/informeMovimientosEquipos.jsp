<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%><%@page import="com.mycompany.pro.util.InformeVistaUtil"%><%@page import="com.mycompany.pro.util.InformeUtil"%><%@page import="com.mycompany.pro.util.ComprobanteUtil"%><%@include file="../config/conexion.jsp"%><%@include file="../config/informeComun.jsp"%><%
    // Informe de Movimientos de Equipos
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
        condiciones.add(InformeUtil.condicionExacta("mv.tipo", request.getParameter("tipo"), new java.util.HashSet<String>(java.util.Arrays.asList("ASIGNACION", "RETIRO", "BAJA", "REACTIVACION"))));
        if ("1".equals(request.getParameter("noReparables"))) condiciones.add("(mv.tipo = 'BAJA' AND mv.origen IS NOT NULL)");
        condiciones.add(InformeUtil.condicionTexto("(SELECT string_agg(COALESCE(dd.codigo_patrimonial, e.codigo_patrimonial, 'S/N') || COALESCE(' ' || e.modelo, ''), ', ' ORDER BY dd.id_detalle) FROM public.movimientos_equipos_detalle dd LEFT JOIN public.equipos e ON e.id_equipo = dd.id_equipo WHERE dd.id_movimiento = mv.id_movimiento)", request.getParameter("equipo")));
        String filtros = InformeUtil.combinar(condiciones.toArray(new String[0]));
        if (filtros == null || filtros.trim().isEmpty()) filtros = "1=1";
        String origen = "FROM public.movimientos_equipos mv LEFT JOIN public.salas sd ON sd.id_sala = mv.id_sala_destino LEFT JOIN public.motivos_inactivo mi ON mi.id_motivo = mv.id_motivo LEFT JOIN public.usuarios u ON u.id_usuario = mv.id_usuario LEFT JOIN public.personas p ON p.id_persona = u.id_persona WHERE mv.fecha BETWEEN CAST(? AS date) AND CAST(? AS date)" + " AND (" + filtros + ")";
        String[][] metricas = {
            {"Movimientos", "COUNT(*)", "N", "fa-exchange-alt", "info"},
            {"Asignaciones a salas", "COUNT(*) FILTER (WHERE mv.tipo = 'ASIGNACION')", "N", "fa-sign-in-alt", "primary"},
            {"Retiros al depósito", "COUNT(*) FILTER (WHERE mv.tipo = 'RETIRO')", "N", "fa-warehouse", "secondary"},
            {"Bajas", "COUNT(*) FILTER (WHERE mv.tipo = 'BAJA')", "N", "fa-power-off", "danger"},
            {"Reactivaciones", "COUNT(*) FILTER (WHERE mv.tipo = 'REACTIVACION')", "N", "fa-redo", "success"},
            {"Equipos movidos", "COALESCE(SUM((SELECT count(*) FROM public.movimientos_equipos_detalle dd WHERE dd.id_movimiento = mv.id_movimiento)), 0)", "N", "fa-desktop", "info"},
            {"No reparables (desde ticket o mantenimiento)", "COUNT(*) FILTER (WHERE mv.tipo = 'BAJA' AND mv.origen IS NOT NULL)", "N", "fa-tools", "warning"}
        };
        if ("datos".equals(accion) || "detalle".equals(accion)) {
            InformeVistaUtil.Informe inf = new InformeVistaUtil.Informe("Informe de Movimientos de Equipos")
                .columnas("mv.numero AS numero, to_char(mv.fecha, 'DD/MM/YYYY') AS fecha, CASE mv.tipo WHEN 'ASIGNACION' THEN 'Asignación a sala' WHEN 'RETIRO' THEN 'Retiro al depósito' WHEN 'BAJA' THEN 'Baja / inactivación' WHEN 'REACTIVACION' THEN 'Reactivación' ELSE mv.tipo END AS movimiento, (SELECT string_agg(COALESCE(dd.codigo_patrimonial, e.codigo_patrimonial, 'S/N') || COALESCE(' ' || e.modelo, ''), ', ' ORDER BY dd.id_detalle) FROM public.movimientos_equipos_detalle dd LEFT JOIN public.equipos e ON e.id_equipo = dd.id_equipo WHERE dd.id_movimiento = mv.id_movimiento) AS equipos, COALESCE((SELECT string_agg(DISTINCT so.nombre_sala, ', ') FROM public.movimientos_equipos_detalle dd JOIN public.salas so ON so.id_sala = dd.id_sala_origen WHERE dd.id_movimiento = mv.id_movimiento), '—') AS desde, COALESCE(sd.nombre_sala, CASE WHEN mv.tipo = 'BAJA' THEN 'Queda en su sala' ELSE '—' END) AS hacia, COALESCE(mi.nombre_motivo, '') AS motivo, COALESCE(mv.origen, '') AS origen, COALESCE(p.apellido || ', ' || p.nombre, u.login, '—') AS usuario",
                        "N°", "Fecha", "Movimiento", "Equipos", "Desde", "Hacia", "Motivo", "Originado en", "Usuario")
                .origen(origen)
                .orden("mv.fecha, mv.id_movimiento");
            { String v_tipo = request.getParameter("tipo"); inf.filtro("Movimiento", v_tipo == null || v_tipo.isEmpty() ? null : ("ASIGNACION".equals(v_tipo) ? "Asignación a sala" : "RETIRO".equals(v_tipo) ? "Retiro al depósito" : "BAJA".equals(v_tipo) ? "Baja / inactivación" : "REACTIVACION".equals(v_tipo) ? "Reactivación" : v_tipo)); }
            if ("1".equals(request.getParameter("noReparables"))) inf.filtro("Solo equipos no reparables", "Sí");
            inf.filtro("Equipo contiene", request.getParameter("equipo"));
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
        enviarInformePdf(response, application, conexion, "informeMovimientosEquipos", par, "informeMovimientosEquipos");
    } catch (Exception ex) {
        response.setContentType("text/plain;charset=UTF-8");
        out.print("error al generar el informe: " + mensajeError(ex));
        ex.printStackTrace();
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
