<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="org.json.JSONObject"%>
<%@page import="org.json.JSONArray"%>
<%@include file="../config/conexion.jsp"%>
<%@include file="../config/inventarioComun.jsp"%>
<%!

    private static String _f(java.util.Date d) { return d == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _fh(java.sql.Timestamp t) { return t == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
    private static String _gs(java.math.BigDecimal v) {
        if (v == null) return "0";
        java.text.DecimalFormatSymbols sim = new java.text.DecimalFormatSymbols();
        sim.setGroupingSeparator('.');
        return new java.text.DecimalFormat("#,##0", sim).format(v.setScale(0, java.math.RoundingMode.HALF_UP));
    }
    private static String _cant(java.math.BigDecimal v) {
        if (v == null) return "0";
        v = v.stripTrailingZeros();
        return v.scale() <= 0 ? v.setScale(0).toPlainString() : v.toPlainString().replace('.', ',');
    }
    private static Integer _int(Object v) {
        if (v == null) return null;
        String s = v.toString().trim();
        return (s.isEmpty() || "null".equals(s)) ? null : Integer.valueOf(s);
    }
    private static java.math.BigDecimal _num(Object v) {
        String s = v == null ? "" : v.toString().trim();
        if (s.isEmpty()) return java.math.BigDecimal.ZERO;
        return new java.math.BigDecimal(s.replace(".", "").replace(",", "."));
    }
    private static java.math.BigDecimal _numDec(Object v) {   // cantidades: "2,5" o "2.5"
        String s = v == null ? "" : v.toString().trim();
        if (s.isEmpty()) return java.math.BigDecimal.ZERO;
        return new java.math.BigDecimal(s.replace(",", "."));
    }
%>
<%
    // ------------------------------------------------------------------
    // RECEPCIÓN DE EQUIPOS E INSUMOS
    //  Al registrarla, los equipos se crean en el Depósito y los repuestos
    //  e insumos se suman al stock. Registrada, ya no se modifica.
    // ------------------------------------------------------------------
    String tipo = request.getParameter("tipo");
    String rolRec = (String) session.getAttribute("nombreRol");
    boolean esAdminRec = "Administrador".equals(rolRec);
    boolean esEncargadoRec = "Encargado de depósito".equals(rolRec);
    Integer idUsuarioRec = (Integer) session.getAttribute("idUsuario");

    try {
        if ((!esAdminRec && !esEncargadoRec) || idUsuarioRec == null) {
            response.setStatus(javax.servlet.http.HttpServletResponse.SC_FORBIDDEN);
            out.print("Error: acceso restringido al Administrador y al Encargado de depósito.");
            return;
        }

        // ============================================================
        // COMBOS
        // ============================================================
        if ("combos".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            JSONObject j = new JSONObject();
            StringBuilder sb = new StringBuilder("<option value=''>-- Seleccione --</option>");
            try (ResultSet rs = conexion.prepareStatement(
                    "SELECT id_concepto, nombre_concepto, es_sistema FROM public.conceptos_entrada WHERE activo ORDER BY es_sistema, nombre_concepto").executeQuery()) {
                // Los conceptos del sistema (Reposición) se ven pero no se eligen: los genera el pedido de reposición
                while (rs.next()) sb.append("<option value='").append(rs.getInt(1)).append("'").append(rs.getBoolean(3) ? " disabled" : "").append(">")
                        .append(h(rs.getString(2))).append(rs.getBoolean(3) ? " (desde un pedido)" : "").append("</option>");
            }
            j.put("conceptos", sb.toString());

            sb = new StringBuilder("<option value=''>-- Seleccione la institución --</option>");
            try (ResultSet rs = conexion.prepareStatement("SELECT id_donante, nombre, documento FROM public.donantes ORDER BY nombre").executeQuery()) {
                while (rs.next()) sb.append("<option value='").append(rs.getInt(1)).append("'>").append(h(rs.getString(2)))
                        .append(rs.getString(3) == null ? "" : " (" + h(rs.getString(3)) + ")").append("</option>");
            }
            j.put("instituciones", sb.toString());

            sb = new StringBuilder("<option value=''>-- Categoría --</option>");
            try (ResultSet rs = conexion.prepareStatement("SELECT id_categoria, nombre_categoria FROM public.categorias ORDER BY nombre_categoria").executeQuery()) {
                while (rs.next()) sb.append("<option value='").append(rs.getInt(1)).append("'>").append(h(rs.getString(2))).append("</option>");
            }
            j.put("categorias", sb.toString());

            sb = new StringBuilder("<option value=''>-- Marca --</option>");
            try (ResultSet rs = conexion.prepareStatement("SELECT id_marca, nombre_marca FROM public.marcas ORDER BY nombre_marca").executeQuery()) {
                while (rs.next()) sb.append("<option value='").append(rs.getInt(1)).append("'>").append(h(rs.getString(2))).append("</option>");
            }
            j.put("marcas", sb.toString());

            sb = new StringBuilder("<option value=''>-- Repuesto o insumo --</option><optgroup label='Repuestos'>");
            try (ResultSet rs = conexion.prepareStatement(
                    "SELECT id_repuesto, nombre, ultimo_costo FROM public.catalogo_repuestos ORDER BY nombre").executeQuery()) {
                while (rs.next()) sb.append("<option value='R-").append(rs.getInt(1)).append("' data-costo='")
                        .append(rs.getBigDecimal(3).setScale(0, java.math.RoundingMode.HALF_UP).toPlainString()).append("'>").append(h(rs.getString(2))).append("</option>");
            }
            sb.append("</optgroup><optgroup label='Insumos'>");
            try (ResultSet rs = conexion.prepareStatement(
                    "SELECT i.id_insumo, i.nombre, i.ultimo_costo, u.nombre_unidad FROM public.catalogo_insumos i " +
                    "LEFT JOIN public.unidades_medida u ON u.id_unidad = i.id_unidad ORDER BY i.nombre").executeQuery()) {
                while (rs.next()) sb.append("<option value='I-").append(rs.getInt(1)).append("' data-costo='")
                        .append(rs.getBigDecimal(3).setScale(0, java.math.RoundingMode.HALF_UP).toPlainString()).append("'>").append(h(rs.getString(2)))
                        .append(rs.getString(4) == null ? "" : " (" + h(rs.getString(4)) + ")").append("</option>");
            }
            sb.append("</optgroup>");
            j.put("articulos", sb.toString());
            j.put("esAdmin", esAdminRec);
            j.put("idUsuario", idUsuarioRec);
            out.print(j.toString());
        }

        // ============================================================
        // LISTAR
        // ============================================================
        else if ("listar".equals(tipo)) {
            String filtroEstado = request.getParameter("estado");
            boolean filtrar = filtroEstado != null && !filtroEstado.isEmpty();
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT r.*, c.nombre_concepto, d.nombre AS institucion, " +
                    "       (SELECT sc.numero_solicitud FROM public.solicitudes_compra sc WHERE sc.id_solicitud = r.id_solicitud_origen) AS pedido, " +
                    "       COALESCE(pr.nombre || ' ' || pr.apellido, ur.login) AS registro, " +
                    "       COALESCE(pc.nombre || ' ' || pc.apellido, uc.login) AS confirmo, " +
                    "       (SELECT COALESCE(sum(cantidad), 0) FROM public.recepciones_detalle_equipos x WHERE x.id_recepcion = r.id_recepcion) AS cant_equipos, " +
                    "       (SELECT count(*) FROM public.recepciones_detalle_articulos x WHERE x.id_recepcion = r.id_recepcion) AS cant_articulos, " +
                    "       (SELECT COALESCE(sum(cantidad * costo_unitario), 0) FROM public.recepciones_detalle_equipos x WHERE x.id_recepcion = r.id_recepcion) + " +
                    "       (SELECT COALESCE(sum(cantidad * costo_unitario), 0) FROM public.recepciones_detalle_articulos x WHERE x.id_recepcion = r.id_recepcion) AS total " +
                    "FROM public.recepciones r " +
                    "JOIN public.conceptos_entrada c ON c.id_concepto = r.id_concepto " +
                    "JOIN public.donantes d ON d.id_donante = r.id_donante " +
                    "LEFT JOIN public.usuarios ur ON ur.id_usuario = r.id_usuario_registro LEFT JOIN public.personas pr ON pr.id_persona = ur.id_persona " +
                    "LEFT JOIN public.usuarios uc ON uc.id_usuario = r.id_usuario_confirma LEFT JOIN public.personas pc ON pc.id_persona = uc.id_persona " +
                    (filtrar ? "WHERE r.estado = ? " : "") +
                    "ORDER BY (r.estado = 'Confirmada'), r.id_recepcion DESC")) {
                if (filtrar) ps.setString(1, filtroEstado);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        filas++;
                        int id = rs.getInt("id_recepcion");
                        String estado = rs.getString("estado");
                        boolean confirmada = "Confirmada".equals(estado);
%>
                <tr>
                    <td class="text-nowrap"><b><%= h(rs.getString("numero_recepcion")) %></b><% if (!confirmada) { %><span class="badge badge-warning d-block">Sin ingresar</span><% } %></td>
                    <td><%= _f(rs.getDate("fecha_recepcion")) %></td>
                    <td><%= h(rs.getString("nombre_concepto")) %><% if (rs.getString("pedido") != null) { %><small class="d-block text-muted">Pedido <%= h(rs.getString("pedido")) %></small><% } %></td>
                    <td><%= h(rs.getString("institucion")) %></td>
                    <td><%= rs.getString("nro_comprobante") == null ? "-" : h(rs.getString("nro_comprobante")) %></td>
                    <td class="text-center"><%= rs.getInt("cant_equipos") %></td>
                    <td class="text-center"><%= rs.getInt("cant_articulos") %></td>
                    <td class="text-right"><%= _gs(rs.getBigDecimal("total")) %></td>
                    <td class="small"><%= h(rs.getString("registro")) %></td>
                    <td class="text-center text-nowrap">
                        <button class="btn btn-secondary btn-sm" title="Ver detalle" aria-label="Ver detalle" onclick="verRecepcion(<%= id %>)"><i class="fas fa-eye" aria-hidden="true"></i></button>
                        <% if (!confirmada) { %>
                        <button class="btn btn-success btn-sm" title="Ingresar al inventario" aria-label="Ingresar al inventario" onclick="ingresarRecepcion(<%= id %>, '<%= hj(rs.getString("numero_recepcion")) %>')"><i class="fas fa-check" aria-hidden="true"></i></button>
                        <% } %>
                        <button class="btn btn-info btn-sm" title="Imprimir" aria-label="Imprimir" onclick="window.open('../controladores/recepcionesControlador.jsp?tipo=comprobantePdf&id=<%= id %>', '_blank')"><i class="fas fa-print" aria-hidden="true"></i></button>
                    </td>
                </tr>
<%
                    }
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='10' class='text-center text-muted py-3'>No hay recepciones registradas.</td></tr>");
        }

        // ============================================================
        // OBTENER (JSON con cabecera y detalle)
        // ============================================================
        else if ("obtener".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            int id = Integer.parseInt(request.getParameter("id"));
            JSONObject j = new JSONObject();
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT r.*, c.nombre_concepto, d.nombre AS institucion FROM public.recepciones r " +
                    "JOIN public.conceptos_entrada c ON c.id_concepto = r.id_concepto JOIN public.donantes d ON d.id_donante = r.id_donante " +
                    "WHERE r.id_recepcion = ?")) {
                ps.setInt(1, id);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) { out.print("{}"); return; }
                    j.put("id_recepcion", id);
                    j.put("numero", rs.getString("numero_recepcion"));
                    j.put("id_concepto", rs.getInt("id_concepto"));
                    j.put("concepto", rs.getString("nombre_concepto"));
                    j.put("id_donante", rs.getInt("id_donante"));
                    j.put("institucion", rs.getString("institucion"));
                    j.put("nro_comprobante", rs.getString("nro_comprobante") == null ? "" : rs.getString("nro_comprobante"));
                    j.put("fecha", rs.getDate("fecha_recepcion").toString());
                    j.put("observacion", rs.getString("observacion") == null ? "" : rs.getString("observacion"));
                    j.put("estado", rs.getString("estado"));
                    j.put("observacion_revision", rs.getString("observacion_revision") == null ? "" : rs.getString("observacion_revision"));
                }
            }
            JSONArray eqs = new JSONArray();
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT x.*, c.nombre_categoria, m.nombre_marca FROM public.recepciones_detalle_equipos x " +
                    "JOIN public.categorias c ON c.id_categoria = x.id_categoria LEFT JOIN public.marcas m ON m.id_marca = x.id_marca " +
                    "WHERE x.id_recepcion = ? ORDER BY x.id_detalle")) {
                ps.setInt(1, id);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        JSONObject e = new JSONObject();
                        e.put("id_categoria", rs.getInt("id_categoria"));
                        e.put("categoria", rs.getString("nombre_categoria"));
                        e.put("id_marca", rs.getObject("id_marca") == null ? "" : rs.getString("id_marca"));
                        e.put("marca", rs.getString("nombre_marca") == null ? "-" : rs.getString("nombre_marca"));
                        e.put("modelo", rs.getString("modelo"));
                        e.put("especificaciones", rs.getString("especificaciones") == null ? "" : rs.getString("especificaciones"));
                        e.put("condicion", rs.getString("condicion_ingreso"));
                        e.put("cantidad", rs.getInt("cantidad"));
                        e.put("costo", rs.getBigDecimal("costo_unitario").setScale(0, java.math.RoundingMode.HALF_UP).toPlainString());
                        e.put("garantia", rs.getDate("fecha_garantia") == null ? "" : rs.getDate("fecha_garantia").toString());
                        eqs.put(e);
                    }
                }
            }
            j.put("equipos", eqs);
            JSONArray arts = new JSONArray();
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT x.*, COALESCE(r.nombre, i.nombre) AS nombre FROM public.recepciones_detalle_articulos x " +
                    "LEFT JOIN public.catalogo_repuestos r ON r.id_repuesto = x.id_repuesto LEFT JOIN public.catalogo_insumos i ON i.id_insumo = x.id_insumo " +
                    "WHERE x.id_recepcion = ? ORDER BY x.id_detalle")) {
                ps.setInt(1, id);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        JSONObject a = new JSONObject();
                        boolean esRep = rs.getObject("id_repuesto") != null;
                        a.put("articulo", (esRep ? "R-" + rs.getInt("id_repuesto") : "I-" + rs.getInt("id_insumo")));
                        a.put("tipo", esRep ? "Repuesto" : "Insumo");
                        a.put("nombre", rs.getString("nombre"));
                        a.put("cantidad", _cant(rs.getBigDecimal("cantidad")));
                        a.put("costo", rs.getBigDecimal("costo_unitario").setScale(0, java.math.RoundingMode.HALF_UP).toPlainString());
                        arts.put(a);
                    }
                }
            }
            j.put("articulos", arts);
            out.print(j.toString());
        }

        // ============================================================
        // GUARDAR (nueva o corrección de una Pendiente/Observada)
        // Recibe "datos" = JSON { id, id_concepto, id_donante, nro_comprobante, fecha, observacion,
        //                         equipos:[{id_categoria,id_marca,modelo,especificaciones,condicion,cantidad,costo,garantia}],
        //                         articulos:[{articulo:"R-3"|"I-5", cantidad, costo}] }
        // ============================================================
        else if ("guardar".equals(tipo)) {
            JSONObject d = new JSONObject(request.getParameter("datos"));
            Integer id = _int(d.opt("id"));
            Integer idConcepto = _int(d.opt("id_concepto"));
            Integer idDonante = _int(d.opt("id_donante"));
            String comprobante = d.optString("nro_comprobante", "").trim();
            String fecha = d.optString("fecha", "").trim();
            String observacion = d.optString("observacion", "").trim();
            JSONArray eqs = d.optJSONArray("equipos");
            JSONArray arts = d.optJSONArray("articulos");
            if (eqs == null) eqs = new JSONArray();
            if (arts == null) arts = new JSONArray();

            if (idConcepto == null) throw new Exception("Seleccione el concepto de entrada.");
            if (idDonante == null) throw new Exception("Seleccione la institución de origen.");
            if (comprobante.isEmpty()) throw new Exception("Ingrese el número de comprobante (factura, nota de donación, etc.).");
            if (eqs.length() == 0 && arts.length() == 0) throw new Exception("Agregue al menos un equipo o un artículo.");
            if (id != null) throw new Exception("Las recepciones registradas no se modifican.");
            // Un concepto del sistema (Reposición) solo se mantiene al corregir una recepción que ya lo tenía
            try (PreparedStatement psC = conexion.prepareStatement(
                    "SELECT 1 FROM public.conceptos_entrada c WHERE c.id_concepto = ? AND c.activo AND " +
                    "(NOT c.es_sistema OR EXISTS (SELECT 1 FROM public.recepciones r WHERE r.id_recepcion = ? AND r.id_concepto = c.id_concepto))")) {
                psC.setInt(1, idConcepto);
                psC.setInt(2, id == null ? -1 : id);
                try (ResultSet rsC = psC.executeQuery()) { if (!rsC.next()) throw new Exception("Concepto no válido."); }
            }

            try {
                conexion.setAutoCommit(false);
                if (id == null) {
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "INSERT INTO public.recepciones (id_concepto, id_donante, nro_comprobante, fecha_recepcion, observacion, id_usuario_registro) " +
                            "VALUES (?, ?, ?, COALESCE(?, CURRENT_DATE), ?, ?) RETURNING id_recepcion")) {
                        ps.setInt(1, idConcepto);
                        ps.setInt(2, idDonante);
                        ps.setString(3, comprobante);
                        ps.setDate(4, fecha.isEmpty() ? null : Date.valueOf(fecha));
                        ps.setString(5, observacion.isEmpty() ? null : observacion);
                        ps.setInt(6, idUsuarioRec);
                        try (ResultSet rs = ps.executeQuery()) { rs.next(); id = rs.getInt(1); }
                    }
                } else {
                    // Solo quien la cargó (o el Administrador) y mientras no esté confirmada
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "SELECT estado, id_usuario_registro FROM public.recepciones WHERE id_recepcion = ? FOR UPDATE")) {
                        ps.setInt(1, id);
                        try (ResultSet rs = ps.executeQuery()) {
                            if (!rs.next()) throw new Exception("La recepción no existe.");
                            if ("Confirmada".equals(rs.getString("estado"))) throw new Exception("La recepción ya está confirmada y no se puede modificar.");
                            if (!esAdminRec && rs.getInt("id_usuario_registro") != idUsuarioRec) throw new Exception("Solo quien cargó la recepción puede corregirla.");
                        }
                    }
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "UPDATE public.recepciones SET id_concepto = ?, id_donante = ?, nro_comprobante = ?, fecha_recepcion = COALESCE(?, fecha_recepcion), " +
                            "observacion = ?, estado = 'Pendiente' WHERE id_recepcion = ?")) {
                        ps.setInt(1, idConcepto);
                        ps.setInt(2, idDonante);
                        ps.setString(3, comprobante);
                        ps.setDate(4, fecha.isEmpty() ? null : Date.valueOf(fecha));
                        ps.setString(5, observacion.isEmpty() ? null : observacion);
                        ps.setInt(6, id);
                        ps.executeUpdate();
                    }
                    for (String tablaDet : new String[]{"recepciones_detalle_equipos", "recepciones_detalle_articulos"}) {
                        try (PreparedStatement ps = conexion.prepareStatement("DELETE FROM public." + tablaDet + " WHERE id_recepcion = ?")) {
                            ps.setInt(1, id);
                            ps.executeUpdate();
                        }
                    }
                }

                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.recepciones_detalle_equipos (id_recepcion, id_categoria, id_marca, modelo, especificaciones, condicion_ingreso, cantidad, costo_unitario, fecha_garantia) " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")) {
                    for (int i = 0; i < eqs.length(); i++) {
                        JSONObject e = eqs.getJSONObject(i);
                        Integer cat = _int(e.opt("id_categoria"));
                        Integer mar = _int(e.opt("id_marca"));
                        String modelo = e.optString("modelo", "").trim();
                        String cond = e.optString("condicion", "Nuevo");
                        Integer cant = _int(e.opt("cantidad"));
                        java.math.BigDecimal costo = _num(e.opt("costo"));
                        String gar = e.optString("garantia", "").trim();
                        if (cat == null || modelo.isEmpty()) throw new Exception("Equipo " + (i + 1) + ": complete la categoría y el modelo.");
                        if (cant == null || cant < 1 || cant > 500) throw new Exception("Equipo " + (i + 1) + ": la cantidad debe estar entre 1 y 500.");
                        if (costo.signum() < 0) throw new Exception("Equipo " + (i + 1) + ": el costo no puede ser negativo.");
                        if (!"Nuevo".equals(cond) && !"Seminuevo".equals(cond) && !"Usado".equals(cond)) cond = "Nuevo";
                        ps.setInt(1, id);
                        ps.setInt(2, cat);
                        if (mar == null) ps.setNull(3, Types.INTEGER); else ps.setInt(3, mar);
                        ps.setString(4, modelo);
                        ps.setString(5, e.optString("especificaciones", "").trim().isEmpty() ? null : e.optString("especificaciones").trim());
                        ps.setString(6, cond);
                        ps.setInt(7, cant);
                        ps.setBigDecimal(8, costo);
                        ps.setDate(9, gar.isEmpty() ? null : Date.valueOf(gar));
                        ps.addBatch();
                    }
                    ps.executeBatch();
                }

                java.util.Set<String> repetidos = new java.util.HashSet<String>();
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.recepciones_detalle_articulos (id_recepcion, id_repuesto, id_insumo, cantidad, costo_unitario) VALUES (?, ?, ?, ?, ?)")) {
                    for (int i = 0; i < arts.length(); i++) {
                        JSONObject a = arts.getJSONObject(i);
                        String art = a.optString("articulo", "");
                        java.math.BigDecimal cant = _numDec(a.opt("cantidad"));
                        java.math.BigDecimal costo = _num(a.opt("costo"));
                        if (!art.matches("[RI]-\\d+")) throw new Exception("Artículo " + (i + 1) + ": seleccione el repuesto o insumo.");
                        if (!repetidos.add(art)) throw new Exception("Artículo " + (i + 1) + ": está repetido, sume las cantidades en una sola línea.");
                        if (cant.signum() <= 0) throw new Exception("Artículo " + (i + 1) + ": la cantidad debe ser mayor a cero.");
                        if (costo.signum() < 0) throw new Exception("Artículo " + (i + 1) + ": el costo no puede ser negativo.");
                        int idArt = Integer.parseInt(art.substring(2));
                        ps.setInt(1, id);
                        if (art.startsWith("R")) { ps.setInt(2, idArt); ps.setNull(3, Types.INTEGER); }
                        else { ps.setNull(2, Types.INTEGER); ps.setInt(3, idArt); }
                        ps.setBigDecimal(4, cant);
                        ps.setBigDecimal(5, costo);
                        ps.addBatch();
                    }
                    ps.executeBatch();
                }
                // Al registrar, entra directamente al inventario
                int creados = aplicarRecepcion(conexion, id, idUsuarioRec);
                conexion.commit();
                out.print("success|" + id + "|" + creados);
            } catch (Exception ex) {
                conexion.rollback();
                throw ex;
            } finally {
                conexion.setAutoCommit(true);
            }
        }

        // ============================================================
        // CONFIRMAR (solo Administrador): impacta en el inventario
        // ============================================================
        else if ("confirmar".equals(tipo)) {
            // Solo para recepciones antiguas que quedaron pendientes
            int id = Integer.parseInt(request.getParameter("id"));
            try {
                conexion.setAutoCommit(false);
                int creados = aplicarRecepcion(conexion, id, idUsuarioRec);
                conexion.commit();
                out.print("success|" + creados);
            } catch (Exception ex) {
                conexion.rollback();
                throw ex;
            } finally {
                conexion.setAutoCommit(true);
            }
        }

        // ============================================================
        // OBSERVAR (solo Administrador): vuelve al Encargado para corregir
        // ============================================================
        else if ("observar".equals(tipo)) {
            if (!esAdminRec) throw new Exception("Solo el Administrador puede observar recepciones.");
            String motivo = request.getParameter("motivo");
            if (motivo == null || motivo.trim().length() < 5) throw new Exception("Indique qué hay que corregir (al menos 5 caracteres).");
            try (PreparedStatement ps = conexion.prepareStatement(
                    "UPDATE public.recepciones SET estado = 'Observada', observacion_revision = ? WHERE id_recepcion = ? AND estado = 'Pendiente'")) {
                ps.setString(1, motivo.trim());
                ps.setInt(2, Integer.parseInt(request.getParameter("id")));
                if (ps.executeUpdate() == 0) throw new Exception("Solo se pueden observar recepciones en estado Pendiente.");
            }
            out.print("success");
        }

        // ============================================================
        // ACTA DE RECEPCIÓN (PDF)
        // ============================================================
        else if ("comprobantePdf".equals(tipo)) {
            java.util.List<Integer> ids = new java.util.ArrayList<Integer>();
            ids.add(Integer.parseInt(request.getParameter("id")));
            byte[] pdf = com.mycompany.pro.util.ComprobanteUtil.generar(conexion, application.getRealPath("reportes"),
                    "comprobanteRecepcion", new String[]{"comprobanteRecepcionEquipos", "comprobanteRecepcionArticulos"},
                    "ID_RECEPCION", ids, idUsuarioRec);
            response.setContentType("application/pdf");
            response.setContentLength(pdf.length);
            response.setHeader("Content-Disposition", "inline; filename=acta_recepcion_" + ids.get(0) + ".pdf");
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
