<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="org.json.JSONObject"%>
<%@page import="org.json.JSONArray"%>
<%@include file="../config/conexion.jsp"%>
<%!
    private static String _f(java.util.Date d) { return d == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _cant(java.math.BigDecimal v) {
        if (v == null) return "0";
        v = v.stripTrailingZeros();
        return v.scale() <= 0 ? v.setScale(0).toPlainString() : v.toPlainString().replace('.', ',');
    }
    private static java.math.BigDecimal _numDec(Object v) {
        String s = v == null ? "" : v.toString().trim();
        if (s.isEmpty() || "null".equals(s)) return null;
        return new java.math.BigDecimal(s.replace(",", "."));
    }
%>
<%
    // ------------------------------------------------------------------
    // AJUSTE DE INVENTARIO
    //  Se cargan solo los artículos a corregir con su cantidad real y, al
    //  registrar, el stock queda en esa cantidad (sale en la ficha del artículo).
    // ------------------------------------------------------------------
    String tipo = request.getParameter("tipo");
    String rolTI = (String) session.getAttribute("nombreRol");
    boolean esAdminTI = "Administrador".equals(rolTI);
    boolean esEncargadoTI = "Encargado de depósito".equals(rolTI);
    Integer idUsuarioTI = (Integer) session.getAttribute("idUsuario");

    try {
        if ((!esAdminTI && !esEncargadoTI) || idUsuarioTI == null) {
            response.setStatus(javax.servlet.http.HttpServletResponse.SC_FORBIDDEN);
            out.print("Error: acceso restringido al Administrador y al Encargado de depósito.");
            return;
        }

        // ============================================================
        // COMBO DE SALAS (Depósito primero, luego por departamento)
        // ============================================================
        if ("combos".equals(tipo)) {
            StringBuilder sb = new StringBuilder("<option value=''>-- Seleccione la sala --</option>");
            String grupo = null;
            try (ResultSet rs = conexion.prepareStatement(
                    "SELECT s.id_sala, s.nombre_sala, s.es_deposito, d.nombre_departamento " +
                    "FROM public.salas s LEFT JOIN public.departamentos d ON d.id_departamento = s.id_departamento " +
                    "ORDER BY s.es_deposito DESC, d.nombre_departamento NULLS LAST, s.nombre_sala").executeQuery()) {
                while (rs.next()) {
                    String g = rs.getBoolean(3) ? "Depósito" : (rs.getString(4) == null ? "Sin departamento" : rs.getString(4));
                    if (!g.equals(grupo)) { if (grupo != null) sb.append("</optgroup>"); sb.append("<optgroup label='").append(h(g)).append("'>"); grupo = g; }
                    sb.append("<option value='").append(rs.getInt(1)).append("'>").append(h(rs.getString(2))).append("</option>");
                }
            }
            if (grupo != null) sb.append("</optgroup>");
            out.print(sb);
        }

        // ============================================================
        // PLANILLA: lo que hay en el sistema, para cargar lo contado
        // ============================================================
        else if ("planilla".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            JSONArray filas = new JSONArray();
            if ("EQUIPOS".equals(request.getParameter("tipoToma"))) {
                int idSala = Integer.parseInt(request.getParameter("idSala"));
                try (PreparedStatement ps = conexion.prepareStatement(
                        "SELECT e.id_equipo, COALESCE(e.codigo_patrimonial, '(sin código)') AS codigo, " +
                        "TRIM(COALESCE(c.nombre_categoria, '') || ' ' || COALESCE(m.nombre_marca, '') || ' ' || COALESCE(e.modelo, '')) AS descripcion, " +
                        "COALESCE(e.nro_serie, '') AS serie, e.estado " +
                        "FROM public.equipos e LEFT JOIN public.categorias c ON c.id_categoria = e.id_categoria " +
                        "LEFT JOIN public.marcas m ON m.id_marca = e.id_marca LEFT JOIN public.motivos_inactivo mi ON mi.id_motivo = e.id_motivo_inactivo " +
                        "WHERE e.id_sala = ? AND (e.estado = 'Activo' OR NOT COALESCE(mi.descuenta, false)) " +
                        "ORDER BY c.nombre_categoria, e.codigo_patrimonial NULLS LAST, e.id_equipo")) {
                    ps.setInt(1, idSala);
                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) filas.put(new JSONObject().put("id", rs.getInt(1)).put("codigo", rs.getString(2))
                                .put("descripcion", rs.getString(3)).put("serie", rs.getString(4)).put("estado", rs.getString(5)));
                    }
                }
            } else {
                try (ResultSet rs = conexion.prepareStatement(
                        "SELECT 'R' AS t, r.id_repuesto AS id, r.nombre, NULL::varchar AS unidad, r.stock FROM public.catalogo_repuestos r " +
                        "UNION ALL SELECT 'I', i.id_insumo, i.nombre, u.nombre_unidad, i.stock FROM public.catalogo_insumos i " +
                        "LEFT JOIN public.unidades_medida u ON u.id_unidad = i.id_unidad ORDER BY 1 DESC, 3").executeQuery()) {
                    while (rs.next()) filas.put(new JSONObject().put("tipo", rs.getString(1)).put("id", rs.getInt(2))
                            .put("nombre", rs.getString(3) + (rs.getString(4) == null ? "" : " (" + rs.getString(4) + ")"))
                            .put("sistema", _cant(rs.getBigDecimal(5))));
                }
            }
            out.print(new JSONObject().put("filas", filas).toString());
        }

        // ============================================================
        // HISTORIAL
        // ============================================================
        else if ("listar".equals(tipo)) {
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT t.id_toma, t.numero_toma, t.tipo_toma, s.nombre_sala, t.estado, t.fecha_creacion, t.observacion, " +
                    "COALESCE(pc.nombre || ' ' || pc.apellido, uc.login) AS registro, " +
                    "(SELECT COUNT(*) FROM public.tomas_inventario_articulos a WHERE a.id_toma = t.id_toma AND a.cantidad_sistema IS NOT NULL AND a.cantidad_contada <> a.cantidad_sistema) + " +
                    "(SELECT COUNT(*) FROM public.tomas_inventario_equipos q WHERE q.id_toma = t.id_toma AND q.encontrado = false) AS diferencias " +
                    "FROM public.tomas_inventario t LEFT JOIN public.salas s ON s.id_sala = t.id_sala " +
                    "LEFT JOIN public.usuarios uc ON uc.id_usuario = t.id_usuario_crea LEFT JOIN public.personas pc ON pc.id_persona = uc.id_persona " +
                    "WHERE t.estado = 'Aprobada' ORDER BY t.id_toma DESC LIMIT 200");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    filas++;
                    int id = rs.getInt("id_toma");
                    boolean art = "ARTICULOS".equals(rs.getString("tipo_toma"));
                    int dif = rs.getInt("diferencias");
                    out.print("<tr><td><b>" + h(rs.getString("numero_toma")) + "</b></td><td>" + _f(rs.getTimestamp("fecha_creacion")) + "</td>"
                        + "<td class='text-center'>" + (art ? (dif == 0 ? "<span class='badge badge-success'>Sin cambios</span>" : "<span class='badge badge-info'>" + dif + " artículo(s) corregido(s)</span>")
                              : "<span class='badge badge-secondary'>Equipos — " + h(rs.getString("nombre_sala")) + "</span>") + "</td>"
                        + "<td>" + h(rs.getString("registro")) + "</td><td class='small'>" + (rs.getString("observacion") == null ? "" : h(rs.getString("observacion"))) + "</td>"
                        + "<td class='text-center'><button class='btn btn-info btn-sm' title='Imprimir' aria-label='Imprimir' onclick=\"window.open('../controladores/tomaInventarioControlador.jsp?tipo=comprobantePdf&id=" + id + "', '_blank')\"><i class='fas fa-print'></i></button></td></tr>");
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='6' class='text-center text-muted py-3'>Todavía no hay ajustes de inventario.</td></tr>");
        }

        // ============================================================
        // REGISTRAR: guarda la toma y ajusta el stock
        // datos = { tipoToma, idSala, observacion,
        //           articulos:[{tipo:"R"|"I", id, contada, observacion}]  o
        //           equipos:[{id, encontrado:true|false, observacion}] }
        // ============================================================
        else if ("registrar".equals(tipo)) {
            JSONObject d = new JSONObject(request.getParameter("datos"));
            String tipoToma = "EQUIPOS".equals(d.optString("tipoToma")) ? "EQUIPOS" : "ARTICULOS";
            Integer idSala = null;
            if ("EQUIPOS".equals(tipoToma)) {
                try { idSala = Integer.valueOf(d.get("idSala").toString()); } catch (Exception ex) { throw new Exception("Seleccione la sala."); }
            }
            String obs = d.optString("observacion", "").trim();
            if ("ARTICULOS".equals(tipoToma) && obs.length() < 5) throw new Exception("Escribí el motivo del ajuste (por ejemplo, \"conteo de fin de mes\" o \"se encontró roto\").");
            int idToma; String numero; int ajustados = 0, noEncontrados = 0;
            try {
                conexion.setAutoCommit(false);
                try (PreparedStatement ps = conexion.prepareStatement("SELECT set_config('cta.toma_mismo_usuario', 'si', true)")) { ps.execute(); }
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.tomas_inventario (tipo_toma, id_sala, observacion, id_usuario_crea) VALUES (?, ?, ?, ?) RETURNING id_toma, numero_toma")) {
                    ps.setString(1, tipoToma);
                    if (idSala == null) ps.setNull(2, Types.INTEGER); else ps.setInt(2, idSala);
                    ps.setString(3, obs.isEmpty() ? null : (obs.length() > 255 ? obs.substring(0, 255) : obs));
                    ps.setInt(4, idUsuarioTI);
                    try (ResultSet rs = ps.executeQuery()) { rs.next(); idToma = rs.getInt(1); numero = rs.getString(2); }
                } catch (SQLException ex) {
                    if ("23505".equals(ex.getSQLState())) throw new Exception("Hay una toma sin terminar para esto: avise al Administrador.");
                    throw ex;
                }

                if ("ARTICULOS".equals(tipoToma)) {
                    JSONArray arts = d.optJSONArray("articulos");
                    int lineas = 0;
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "INSERT INTO public.tomas_inventario_articulos (id_toma, tipo_articulo, id_articulo, cantidad_contada, observacion) VALUES (?, ?, ?, ?, ?)")) {
                        for (int i = 0; arts != null && i < arts.length(); i++) {
                            JSONObject a = arts.getJSONObject(i);
                            java.math.BigDecimal c = _numDec(a.opt("contada"));
                            if (c == null) continue;                 // lo que no se cargó, no se contó
                            if (c.signum() < 0) throw new Exception("Las cantidades contadas no pueden ser negativas.");
                            String t = "R".equals(a.optString("tipo")) ? "R" : "I";
                            String o = a.optString("observacion", "").trim();
                            ps.setInt(1, idToma); ps.setString(2, t); ps.setInt(3, a.getInt("id")); ps.setBigDecimal(4, c);
                            ps.setString(5, o.isEmpty() ? null : (o.length() > 255 ? o.substring(0, 255) : o));
                            ps.addBatch();
                            lineas++;
                        }
                        ps.executeBatch();
                    }
                    if (lineas == 0) throw new Exception("Agregá al menos un artículo con su cantidad real.");
                    // Stock del sistema en este momento
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "UPDATE public.tomas_inventario_articulos a SET " +
                            "cantidad_sistema = COALESCE(CASE WHEN a.tipo_articulo = 'R' THEN (SELECT r.stock FROM public.catalogo_repuestos r WHERE r.id_repuesto = a.id_articulo) " +
                            "                                ELSE (SELECT i.stock FROM public.catalogo_insumos i WHERE i.id_insumo = a.id_articulo) END, 0), " +
                            "costo_unitario = COALESCE(CASE WHEN a.tipo_articulo = 'R' THEN (SELECT r.ultimo_costo FROM public.catalogo_repuestos r WHERE r.id_repuesto = a.id_articulo) " +
                            "                                ELSE (SELECT i.ultimo_costo FROM public.catalogo_insumos i WHERE i.id_insumo = a.id_articulo) END, 0) " +
                            "WHERE a.id_toma = ?")) {
                        ps.setInt(1, idToma);
                        ps.executeUpdate();
                    }
                    try (PreparedStatement ps = conexion.prepareStatement("SELECT public.fn_kardex_contexto('AJUSTE', 'TOMA', ?, ?, NULL)")) {
                        ps.setInt(1, idToma);
                        ps.setString(2, "Ajuste de inventario " + numero + (obs.isEmpty() ? "" : " - " + obs));
                        ps.execute();
                    }
                    java.util.List<Object[]> difs = new java.util.ArrayList<Object[]>();
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "SELECT id_detalle, tipo_articulo, id_articulo, cantidad_contada - cantidad_sistema FROM public.tomas_inventario_articulos " +
                            "WHERE id_toma = ? AND cantidad_contada <> cantidad_sistema")) {
                        ps.setInt(1, idToma);
                        try (ResultSet rs = ps.executeQuery()) { while (rs.next()) difs.add(new Object[]{rs.getInt(1), rs.getString(2), rs.getInt(3), rs.getBigDecimal(4)}); }
                    }
                    for (Object[] x : difs) {
                        boolean rep = "R".equals(x[1]);
                        try (PreparedStatement ps = conexion.prepareStatement(
                                "UPDATE public." + (rep ? "catalogo_repuestos" : "catalogo_insumos") + " SET stock = COALESCE(stock, 0) + ? WHERE " + (rep ? "id_repuesto" : "id_insumo") + " = ?")) {
                            ps.setBigDecimal(1, (java.math.BigDecimal) x[3]); ps.setInt(2, (Integer) x[2]); ps.executeUpdate();
                        }
                        try (PreparedStatement ps = conexion.prepareStatement("UPDATE public.tomas_inventario_articulos SET ajuste_aplicado = ? WHERE id_detalle = ?")) {
                            ps.setBigDecimal(1, (java.math.BigDecimal) x[3]); ps.setInt(2, (Integer) x[0]); ps.executeUpdate();
                        }
                        ajustados++;
                    }
                } else {
                    JSONArray eqs = d.optJSONArray("equipos");
                    if (eqs == null || eqs.length() == 0) throw new Exception("La sala no tiene equipos para contar.");
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "INSERT INTO public.tomas_inventario_equipos (id_toma, id_equipo, encontrado, observacion) VALUES (?, ?, ?, ?)")) {
                        for (int i = 0; i < eqs.length(); i++) {
                            JSONObject e = eqs.getJSONObject(i);
                            boolean enc = e.optBoolean("encontrado", true);
                            if (!enc) noEncontrados++;
                            String o = e.optString("observacion", "").trim();
                            ps.setInt(1, idToma); ps.setInt(2, e.getInt("id")); ps.setBoolean(3, enc);
                            ps.setString(4, o.isEmpty() ? null : (o.length() > 255 ? o.substring(0, 255) : o));
                            ps.addBatch();
                        }
                        ps.executeBatch();
                    }
                }
                try (PreparedStatement ps = conexion.prepareStatement(
                        "UPDATE public.tomas_inventario SET estado = 'Aprobada', id_usuario_envia = ?, fecha_envio = CURRENT_TIMESTAMP, " +
                        "id_usuario_resuelve = ?, fecha_resolucion = CURRENT_TIMESTAMP WHERE id_toma = ?")) {
                    ps.setInt(1, idUsuarioTI); ps.setInt(2, idUsuarioTI); ps.setInt(3, idToma);
                    ps.executeUpdate();
                }
                conexion.commit();
            } catch (SQLException ex) {
                conexion.rollback();
                if ("23514".equals(ex.getSQLState())) throw new Exception("El ajuste dejaría un stock negativo. Revise las cantidades.");
                throw ex;
            } catch (Exception ex) {
                conexion.rollback();
                throw ex;
            } finally {
                conexion.setAutoCommit(true);
            }
            out.print("success|" + idToma + "|" + ajustados + "|" + noEncontrados);
        }

        // ============================================================
        // IMPRIMIR
        // ============================================================
        else if ("comprobantePdf".equals(tipo)) {
            java.util.List<Integer> ids = new java.util.ArrayList<Integer>();
            ids.add(Integer.parseInt(request.getParameter("id")));
            byte[] pdf = com.mycompany.pro.util.ComprobanteUtil.generar(conexion, application.getRealPath("reportes"),
                    "comprobanteTomaInventario", new String[]{"comprobanteTomaInventarioArticulos", "comprobanteTomaInventarioEquipos"},
                    "ID_TOMA", ids, idUsuarioTI);
            response.setContentType("application/pdf");
            response.setContentLength(pdf.length);
            response.setHeader("Content-Disposition", "inline; filename=toma_inventario_" + ids.get(0) + ".pdf");
            javax.servlet.ServletOutputStream salida = response.getOutputStream();
            salida.write(pdf, 0, pdf.length);
            salida.flush();
            salida.close();
            return;
        }
    } catch (Exception e) {
        out.print("Error: " + mensajeError(e));
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
