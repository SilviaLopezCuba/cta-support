<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="org.json.JSONObject"%>
<%@include file="../config/conexion.jsp"%>
<%!
    private static String _cant(java.math.BigDecimal v) {
        if (v == null) return "0";
        java.math.BigDecimal s = v.stripTrailingZeros();
        return s.scale() <= 0 ? s.setScale(0).toPlainString() : s.toPlainString().replace('.', ',');
    }
    private static String _gs(long n) { return String.format(new java.util.Locale("es", "PY"), "%,d", n).replace(',', '.'); }
    private int _contar(Connection c, String sql) {
        try (PreparedStatement ps = c.prepareStatement(sql); ResultSet rs = ps.executeQuery()) { return rs.next() ? rs.getInt(1) : 0; } catch (Exception e) { return 0; }
    }
    private long _suma(Connection c, String sql) {
        try (PreparedStatement ps = c.prepareStatement(sql); ResultSet rs = ps.executeQuery()) { return rs.next() ? rs.getLong(1) : 0; } catch (Exception e) { return 0; }
    }
%>
<%
    // ------------------------------------------------------------------
    // INVENTARIO: consulta de todo lo que hay (equipos, repuestos e insumos)
    // ------------------------------------------------------------------
    String tipo = request.getParameter("tipo");
    String rolI = (String) session.getAttribute("nombreRol");
    try {
        if (!"Administrador".equals(rolI) && !"Encargado de depósito".equals(rolI)) {
            response.setStatus(javax.servlet.http.HttpServletResponse.SC_FORBIDDEN);
            out.print("Error: acceso restringido al Administrador y al Encargado de depósito.");
            return;
        }

        if ("resumen".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            String EQ = " FROM public.equipos e JOIN public.salas s ON s.id_sala = e.id_sala LEFT JOIN public.categorias c ON c.id_categoria = e.id_categoria " +
                        "LEFT JOIN public.motivos_inactivo mi ON mi.id_motivo = e.id_motivo_inactivo WHERE (e.estado = 'Activo' OR NOT COALESCE(mi.descuenta, false))";
            String VAL = "COALESCE(ROUND(e.costo * GREATEST(0, 1 - ((CURRENT_DATE - e.fecha_ingreso) / 365.25) / NULLIF(c.vida_util_anios, 0))), e.costo, 0)";
            String ART = "SELECT stock, stock_minimo, ultimo_costo FROM public.catalogo_repuestos UNION ALL SELECT stock, stock_minimo, ultimo_costo FROM public.catalogo_insumos";
            JSONObject j = new JSONObject();
            j.put("valorPatrimonio", _gs(_suma(conexion, "SELECT COALESCE(SUM(" + VAL + "), 0)::bigint" + EQ)));
            j.put("costoPatrimonio", _gs(_suma(conexion, "SELECT COALESCE(SUM(e.costo), 0)::bigint" + EQ)));
            j.put("eqUso", _contar(conexion, "SELECT COUNT(*)" + EQ + " AND e.estado = 'Activo' AND NOT s.es_deposito"));
            j.put("eqDeposito", _contar(conexion, "SELECT COUNT(*)" + EQ + " AND e.estado = 'Activo' AND s.es_deposito"));
            j.put("eqInactivos", _contar(conexion, "SELECT COUNT(*)" + EQ + " AND e.estado = 'Inactivo'"));
            j.put("bajoMinimo", _contar(conexion, "SELECT COUNT(*) FROM (" + ART + ") a WHERE COALESCE(a.stock_minimo, 0) > 0 AND COALESCE(a.stock, 0) < a.stock_minimo"));
            j.put("valorArticulos", _gs(_suma(conexion, "SELECT COALESCE(SUM(COALESCE(a.stock, 0) * COALESCE(a.ultimo_costo, 0)), 0)::bigint FROM (" + ART + ") a")));
            j.put("pedidosMaterial", _contar(conexion, "SELECT COUNT(*) FROM public.solicitudes_material WHERE estado IN ('Pendiente', 'En espera')"));
            j.put("sinDevolver", _contar(conexion, "SELECT COUNT(DISTINCT (tipo_orden, id_orden)) FROM public.v_material_orden WHERE saldo > 0"));
            j.put("reposiciones", _contar(conexion, "SELECT COUNT(*) FROM public.solicitudes_compra WHERE estado IN ('Enviada', 'Recibida parcial')"));
            out.print(j.toString());
        }

        else if ("existencias".equals(tipo)) {
            int filas = 0;
            try (ResultSet rs = conexion.prepareStatement(
                    "SELECT 'R' AS t, r.id_repuesto AS id, r.nombre, NULL::varchar AS unidad, r.stock, r.stock_minimo, r.stock_danado, r.ultimo_costo FROM public.catalogo_repuestos r " +
                    "UNION ALL SELECT 'I', i.id_insumo, i.nombre, u.nombre_unidad, i.stock, i.stock_minimo, i.stock_danado, i.ultimo_costo FROM public.catalogo_insumos i " +
                    "LEFT JOIN public.unidades_medida u ON u.id_unidad = i.id_unidad ORDER BY 1 DESC, 3").executeQuery()) {
                while (rs.next()) {
                    filas++;
                    java.math.BigDecimal st = rs.getBigDecimal("stock") == null ? java.math.BigDecimal.ZERO : rs.getBigDecimal("stock");
                    java.math.BigDecimal mn = rs.getBigDecimal("stock_minimo") == null ? java.math.BigDecimal.ZERO : rs.getBigDecimal("stock_minimo");
                    java.math.BigDecimal costo = rs.getBigDecimal("ultimo_costo") == null ? java.math.BigDecimal.ZERO : rs.getBigDecimal("ultimo_costo");
                    boolean bajo = mn.signum() > 0 && st.compareTo(mn) < 0;
                    String art = rs.getString("t") + "-" + rs.getInt("id");
                    out.print("<tr" + (bajo ? " class='table-warning'" : "") + "><td>" + ("R".equals(rs.getString("t")) ? "Repuesto" : "Insumo") + "</td>"
                        + "<td>" + h(rs.getString("nombre")) + (rs.getString("unidad") == null ? "" : " <small class='text-muted'>(" + h(rs.getString("unidad")) + ")</small>") + "</td>"
                        + "<td class='text-right font-weight-bold'>" + _cant(st) + "</td><td class='text-right'>" + _cant(mn) + "</td>"
                        + "<td class='text-right'>" + _cant(rs.getBigDecimal("stock_danado")) + "</td>"
                        + "<td class='text-right'>" + _gs(costo.longValue()) + "</td><td class='text-right'>" + _gs(st.multiply(costo).longValue()) + "</td>"
                        + "<td>" + (bajo ? "<span class='badge badge-danger'>Bajo mínimo</span>" : "<span class='badge badge-success'>Normal</span>") + "</td>"
                        + "<td class='text-center text-nowrap'><button class='btn btn-secondary btn-sm' title='Ver ficha' aria-label='Ver ficha' onclick=\"verFicha('" + art + "')\"><i class='fas fa-list'></i></button> "
                        + "<a class='btn btn-outline-primary btn-sm' title='Ajustar stock' aria-label='Ajustar stock' href='tomaInventarioVista.jsp?art=" + art + "'><i class='fas fa-sliders-h'></i></a></td></tr>");
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='9' class='text-center text-muted py-3'>No hay repuestos ni insumos registrados.</td></tr>");
        }
    } catch (Exception e) {
        out.print("Error: " + mensajeError(e));
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
