<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@include file="../config/conexion.jsp"%>
<%!
    private static String _fh(java.sql.Timestamp t) { return t == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
    private static String _cant(java.math.BigDecimal v, boolean signo) {
        if (v == null) return "0";
        java.math.BigDecimal s = v.stripTrailingZeros();
        String txt = (s.scale() <= 0 ? s.setScale(0).toPlainString() : s.toPlainString().replace('.', ','));
        return (signo && v.signum() > 0 ? "+" : "") + txt;
    }
    /** Nombre del movimiento en palabras simples */
    private static String _mov(String t) {
        if (t == null) return "";
        switch (t) {
            case "ENTRADA": return "Entró por recepción";
            case "ENTREGA": return "Se entregó a técnico";
            case "DEVOLUCION": return "Devolución del técnico";
            case "AJUSTE": return "Ajuste de inventario";
            case "SALDO INICIAL": return "Saldo inicial";
            default: return t.substring(0, 1) + t.substring(1).toLowerCase();
        }
    }
%>
<%
    // ------------------------------------------------------------------
    // KARDEX: historial de movimientos de stock de repuestos e insumos.
    // Solo lectura: los movimientos los genera la base (trigger) en cada
    // cambio de stock y no se pueden modificar ni borrar.
    // ------------------------------------------------------------------
    String tipo = request.getParameter("tipo");
    String rolK = (String) session.getAttribute("nombreRol");
    if (!"Administrador".equals(rolK) && !"Encargado de depósito".equals(rolK)) {
        response.setStatus(javax.servlet.http.HttpServletResponse.SC_FORBIDDEN);
        out.print("Error: acceso restringido al Administrador y al Encargado de depósito.");
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
        return;
    }
    try {
        if ("articulos".equals(tipo)) {
            out.print("<option value=''>Todos los artículos</option><optgroup label='Repuestos'>");
            try (ResultSet rs = conexion.prepareStatement("SELECT id_repuesto, nombre FROM public.catalogo_repuestos ORDER BY nombre").executeQuery()) {
                while (rs.next()) out.print("<option value='R-" + rs.getInt(1) + "'>" + h(rs.getString(2)) + "</option>");
            }
            out.print("</optgroup><optgroup label='Insumos'>");
            try (ResultSet rs = conexion.prepareStatement("SELECT id_insumo, nombre FROM public.catalogo_insumos ORDER BY nombre").executeQuery()) {
                while (rs.next()) out.print("<option value='I-" + rs.getInt(1) + "'>" + h(rs.getString(2)) + "</option>");
            }
            out.print("</optgroup>");
        }
        else if ("ficha".equals(tipo)) {
            // Cabecera de la ficha del artículo
            response.setContentType("application/json;charset=UTF-8");
            String art = request.getParameter("articulo");
            org.json.JSONObject j = new org.json.JSONObject();
            if (art != null && art.matches("[RI]-\\d+")) {
                boolean rep = art.startsWith("R");
                try (PreparedStatement ps = conexion.prepareStatement(rep
                        ? "SELECT nombre, NULL AS unidad, stock, stock_minimo, stock_danado, ultimo_costo FROM public.catalogo_repuestos WHERE id_repuesto = ?"
                        : "SELECT i.nombre, u.nombre_unidad AS unidad, i.stock, i.stock_minimo, i.stock_danado, i.ultimo_costo FROM public.catalogo_insumos i LEFT JOIN public.unidades_medida u ON u.id_unidad = i.id_unidad WHERE i.id_insumo = ?")) {
                    ps.setInt(1, Integer.parseInt(art.substring(2)));
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            j.put("ok", true).put("tipo", rep ? "Repuesto" : "Insumo").put("nombre", rs.getString("nombre"))
                             .put("unidad", rs.getString("unidad") == null ? "" : rs.getString("unidad"))
                             .put("stock", _cant(rs.getBigDecimal("stock"), false)).put("minimo", _cant(rs.getBigDecimal("stock_minimo"), false))
                             .put("danado", _cant(rs.getBigDecimal("stock_danado"), false))
                             .put("costo", rs.getBigDecimal("ultimo_costo") == null ? "0" : String.format(new java.util.Locale("es", "PY"), "%,d", rs.getBigDecimal("ultimo_costo").longValue()).replace(',', '.'))
                             .put("bajo", rs.getBigDecimal("stock_minimo") != null && rs.getBigDecimal("stock").compareTo(rs.getBigDecimal("stock_minimo")) < 0);
                        }
                    }
                }
            }
            if (!j.has("ok")) j.put("ok", false);
            out.print(j.toString());
        }
        else if ("listar".equals(tipo)) {
            String art = request.getParameter("articulo");
            String desde = request.getParameter("desde");
            String hasta = request.getParameter("hasta");
            String mov = request.getParameter("movimiento");
            StringBuilder sql = new StringBuilder(
                "SELECT m.*, COALESCE(r.nombre, i.nombre, '(eliminado)') AS articulo, " +
                "       COALESCE(p.nombre || ' ' || p.apellido, u.login, 'Sistema') AS usuario " +
                "FROM public.movimientos_stock m " +
                "LEFT JOIN public.catalogo_repuestos r ON m.tipo_articulo = 'R' AND r.id_repuesto = m.id_articulo " +
                "LEFT JOIN public.catalogo_insumos i ON m.tipo_articulo = 'I' AND i.id_insumo = m.id_articulo " +
                "LEFT JOIN public.usuarios u ON u.id_usuario = m.id_usuario " +
                "LEFT JOIN public.personas p ON p.id_persona = u.id_persona WHERE true ");
            java.util.List<Object> params = new java.util.ArrayList<Object>();
            if (art != null && art.matches("[RI]-\\d+")) {
                sql.append("AND m.tipo_articulo = ? AND m.id_articulo = ? ");
                params.add(art.substring(0, 1));
                params.add(Integer.valueOf(art.substring(2)));
            }
            if (desde != null && !desde.isEmpty()) { sql.append("AND m.fecha >= ? "); params.add(Date.valueOf(desde)); }
            if (hasta != null && !hasta.isEmpty()) { sql.append("AND m.fecha < ?::date + 1 "); params.add(Date.valueOf(hasta)); }
            if (mov != null && !mov.isEmpty()) { sql.append("AND m.tipo_movimiento = ? "); params.add(mov); }
            sql.append("ORDER BY m.fecha DESC, m.id_movimiento DESC LIMIT 1000");

            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(sql.toString())) {
                for (int k = 0; k < params.size(); k++) ps.setObject(k + 1, params.get(k));
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        filas++;
                        java.math.BigDecimal cant = rs.getBigDecimal("cantidad");
                        boolean dan = "dañado".equals(rs.getString("saldo"));
                        String ref = rs.getString("observacion") == null ? "" : rs.getString("observacion");
                        out.print("<tr>"
                            + "<td class='text-nowrap'>" + _fh(rs.getTimestamp("fecha")) + "</td>"
                            + "<td>" + h(rs.getString("articulo")) + " <span class='badge badge-light border'>" + ("R".equals(rs.getString("tipo_articulo")) ? "Repuesto" : "Insumo") + "</span></td>"
                            + "<td><span class='badge " + (cant.signum() >= 0 ? "badge-success" : "badge-danger") + "'>" + h(_mov(rs.getString("tipo_movimiento"))) + "</span>"
                            + (dan ? " <span class='badge badge-secondary'>stock dañado</span>" : "") + "</td>"
                            + "<td>" + h(ref) + "</td>"
                            + "<td class='text-right font-weight-bold " + (cant.signum() >= 0 ? "text-success" : "text-danger") + "'>" + _cant(cant, true) + "</td>"
                            + "<td class='text-right'>" + _cant(rs.getBigDecimal("stock_anterior"), false) + " &rarr; <b>" + _cant(rs.getBigDecimal("stock_nuevo"), false) + "</b></td>"
                            + "<td>" + h(rs.getString("usuario")) + "</td>"
                            + "</tr>");
                    }
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='7' class='text-center text-muted py-3'>No hay movimientos para este filtro.</td></tr>");
        }
    } catch (Exception e) {
        out.print("Error: " + mensajeError(e));
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
