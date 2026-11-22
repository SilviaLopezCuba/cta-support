<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="org.json.JSONObject"%>
<%@page import="org.json.JSONArray"%>
<%@include file="../config/conexion.jsp"%>
<%!
    private static String _fh(java.sql.Timestamp t) { return t == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
    private static String _cant(java.math.BigDecimal v) {
        if (v == null) return "0";
        java.math.BigDecimal s = v.stripTrailingZeros();
        return s.scale() <= 0 ? s.setScale(0).toPlainString() : s.toPlainString().replace('.', ',');
    }
    private static java.math.BigDecimal _numDec(Object v) {
        String s = v == null ? "" : v.toString().trim();
        if (s.isEmpty() || "null".equals(s)) return java.math.BigDecimal.ZERO;
        return new java.math.BigDecimal(s.replace(",", "."));
    }
    /** Cómo ve el técnico su pedido: lo que tiene que hacer, no el estado interno. */
    private static String _estadoTecnico(String estado, boolean hayStock) {
        if ("Pendiente".equals(estado) || "En espera".equals(estado)) {
            if (hayStock) return "Listo para retirar";
            return "En espera".equals(estado) ? "En espera de stock" : "Pedido enviado";
        }
        return estado;
    }
    /**
     * ¿La orden ya tuvo su revisión? Sin revisión no se pide material.
     *  Ticket: "Primera revisión" (ticket.fecha_revision). Mantenimiento: observación inicial.
     *  Devuelve [0]=revisado, [1]=mensaje si falta, [2]=urgencia del ticket (o null).
     */
    private static Object[] revisionOrden(Connection c, String tipoOrden, int idOrden) throws SQLException {
        String sql = "T".equals(tipoOrden)
            ? "SELECT fecha_revision IS NOT NULL AND COALESCE(trim(diagnostico), '') <> '' AS ok, prioridad FROM public.ticket WHERE id_ticket = ?"
            : "SELECT COALESCE(trim(observacion_inicial), '') <> '' AS ok, NULL AS prioridad FROM public.mantenimientos_preventivos WHERE id_mantenimiento = ?";
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, idOrden);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return new Object[]{false, "La orden no existe.", null};
                boolean ok = rs.getBoolean("ok");
                return new Object[]{ok, ok ? "" : ("T".equals(tipoOrden)
                        ? "Primero hacé la primera revisión del ticket (diagnóstico y urgencia). Sin revisión no se puede pedir material."
                        : "Primero guardá la observación inicial del mantenimiento. Sin observación no se puede pedir material."),
                        rs.getString("prioridad")};
            }
        }
    }
    /** Orden de urgencia para la lista del depósito (0 = lo más urgente). */
    private static final String SQL_RANGO_PRIORIDAD =
        "CASE s.prioridad WHEN 'Critica' THEN 0 WHEN 'Urgente' THEN 0 WHEN 'Alta' THEN 1 WHEN 'Media' THEN 2 WHEN 'Normal' THEN 2 ELSE 3 END";
    private static String _prio(String p) { return "Critica".equals(p) ? "CRÍTICA" : (p == null ? "" : p.toUpperCase()); }
    private static String tablaArt(String t) { return "R".equals(t) ? "public.catalogo_repuestos" : "public.catalogo_insumos"; }
    private static String colArt(String t)   { return "R".equals(t) ? "id_repuesto" : "id_insumo"; }

    /** Expresión SQL con el número visible de la orden (ticket o mantenimiento). */
    private static final String SQL_ORDEN =
        "CASE WHEN %1$s.tipo_orden = 'T' THEN COALESCE((SELECT 'Ticket ' || t.numero_ticket FROM public.ticket t WHERE t.id_ticket = %1$s.id_orden), 'Ticket #' || %1$s.id_orden) " +
        "ELSE COALESCE((SELECT 'Mant. ' || m.numero_mantenimiento FROM public.mantenimientos_preventivos m WHERE m.id_mantenimiento = %1$s.id_orden), 'Mant. #' || %1$s.id_orden) END";

    /** Datos de la orden: [0]=existe, [1]=abierta, [2]=autorizado para el usuario, [3]=número visible */
    private Object[] infoOrden(Connection c, String tipoOrden, int idOrden, boolean esAdmin, Integer idTecnico) throws SQLException {
        String sql = "T".equals(tipoOrden)
            ? "SELECT numero_ticket AS numero, estado, id_tecnico_asignado AS t1, id_tecnico_asignado AS t2 FROM public.ticket WHERE id_ticket = ?"
            : "SELECT numero_mantenimiento AS numero, estado, id_tecnico AS t1, id_tecnico_ejecuta AS t2 FROM public.mantenimientos_preventivos WHERE id_mantenimiento = ?";
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, idOrden);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return new Object[]{false, false, false, ""};
                String estado = rs.getString("estado");
                boolean abierta = "T".equals(tipoOrden)
                        ? !("Resuelto".equals(estado) || "Cerrado".equals(estado) || "Cancelado".equals(estado))
                        : ("Programado".equals(estado) || "En Proceso".equals(estado));
                boolean autorizado = esAdmin || (idTecnico != null &&
                        ((rs.getObject("t1") != null && rs.getInt("t1") == idTecnico) || (rs.getObject("t2") != null && rs.getInt("t2") == idTecnico)));
                return new Object[]{true, abierta, autorizado, ("T".equals(tipoOrden) ? "Ticket " : "Mant. ") + rs.getString("numero")};
            }
        }
    }
%>
<%
    // ------------------------------------------------------------------
    // ENTREGA DE MATERIAL A TÉCNICOS
    //  Técnico: pide material desde su ticket o mantenimiento.
    //  Encargado de depósito / Administrador: entrega o rechaza el pedido
    //             (al entregar baja el stock) y registra las devoluciones
    //             (al registrarlas vuelve al stock).
    //  Nadie se entrega ni se recibe a sí mismo (también lo controla la base),
    //  salvo el Administrador, que puede hacerlo (queda en la auditoría).
    // ------------------------------------------------------------------
    String tipo = request.getParameter("tipo");
    String rolM = (String) session.getAttribute("nombreRol");
    boolean esAdminM = "Administrador".equals(rolM);
    boolean esEncargadoM = "Encargado de depósito".equals(rolM);
    boolean esDeposito = esAdminM || esEncargadoM;
    Integer idUsuarioM = (Integer) session.getAttribute("idUsuario");
    Integer idTecnicoM = (Integer) session.getAttribute("idTecnico");

    try {
        if (idUsuarioM == null) { out.print("Error: sesión no válida."); return; }

        // ============================================================
        // TÉCNICO: saldo y movimientos de material de una orden (JSON)
        // ============================================================
        if ("saldo".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            String tipoOrden = "M".equals(request.getParameter("tipo_orden")) ? "M" : "T";
            int idOrden = Integer.parseInt(request.getParameter("id_orden"));
            Object[] info = infoOrden(conexion, tipoOrden, idOrden, esAdminM, idTecnicoM);
            JSONObject j = new JSONObject();
            if (!(Boolean) info[0]) { j.put("ok", false).put("error", "La orden no existe."); out.print(j); return; }
            if (!(Boolean) info[2] && !esDeposito) { j.put("ok", false).put("error", "No tiene permisos sobre esta orden."); out.print(j); return; }
            j.put("ok", true).put("orden", info[3]).put("abierta", info[1]);
            Object[] rev = revisionOrden(conexion, tipoOrden, idOrden);
            j.put("revisado", rev[0]).put("bloqueo", rev[1]).put("prioridad", rev[2] == null ? "" : rev[2]);
            if ("M".equals(tipoOrden)) {
                // Equipos del mantenimiento, para indicar para cuál es el material
                JSONArray eqs = new JSONArray();
                try (PreparedStatement ps = conexion.prepareStatement(
                        "SELECT e.id_equipo, COALESCE(e.codigo_patrimonial, 'S/N') AS cod, COALESCE(e.modelo, '') AS modelo " +
                        "FROM public.mantenimientos_preventivos_detalle d JOIN public.equipos e ON e.id_equipo = d.id_equipo " +
                        "WHERE d.id_mantenimiento = ? ORDER BY e.codigo_patrimonial")) {
                    ps.setInt(1, idOrden);
                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) eqs.put(new JSONObject().put("id", rs.getInt(1)).put("texto", rs.getString(2) + (rs.getString(3).isEmpty() ? "" : " - " + rs.getString(3))));
                    }
                }
                j.put("equipos", eqs);
            }

            JSONArray items = new JSONArray();
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT * FROM public.v_material_orden WHERE tipo_orden = ? AND id_orden = ? ORDER BY articulo")) {
                ps.setString(1, tipoOrden);
                ps.setInt(2, idOrden);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        items.put(new JSONObject()
                            .put("articulo", rs.getString("tipo_articulo") + "-" + rs.getInt("id_articulo"))
                            .put("tipo", "R".equals(rs.getString("tipo_articulo")) ? "Repuesto" : "Insumo")
                            .put("nombre", rs.getString("articulo"))
                            .put("entregado", _cant(rs.getBigDecimal("entregado")))
                            .put("sin_confirmar", _cant(rs.getBigDecimal("sin_confirmar")))
                            .put("usado", _cant(rs.getBigDecimal("usado")))
                            .put("devuelto", _cant(rs.getBigDecimal("devuelto")))
                            .put("saldo", _cant(rs.getBigDecimal("saldo")))
                            .put("saldo_num", rs.getBigDecimal("saldo").doubleValue()));
                    }
                }
            }
            j.put("items", items);

            JSONArray sols = new JSONArray();
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT s.*, (SELECT string_agg(COALESCE(r.nombre, i.nombre) || ': ' || " +
                    "        trim(to_char(d.cantidad_solicitada, 'FM999999990.##')) || " +
                    "        CASE WHEN s.estado LIKE 'Entregada%' THEN ' (entregado ' || trim(to_char(d.cantidad_entregada, 'FM999999990.##')) || ')' ELSE '' END, ', ') " +
                    "        FROM public.solicitudes_material_detalle d " +
                    "        LEFT JOIN public.catalogo_repuestos r ON d.tipo_articulo = 'R' AND r.id_repuesto = d.id_articulo " +
                    "        LEFT JOIN public.catalogo_insumos i ON d.tipo_articulo = 'I' AND i.id_insumo = d.id_articulo " +
                    "        WHERE d.id_solicitud = s.id_solicitud) AS resumen, vs.hay_stock " +
                    "FROM public.solicitudes_material s LEFT JOIN public.v_solicitud_stock vs ON vs.id_solicitud = s.id_solicitud " +
                    "WHERE s.tipo_orden = ? AND s.id_orden = ? ORDER BY s.id_solicitud DESC")) {
                ps.setString(1, tipoOrden);
                ps.setInt(2, idOrden);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        String est = rs.getString("estado");
                        boolean entregada = est.startsWith("Entregada");
                        sols.put(new JSONObject()
                            .put("id", rs.getInt("id_solicitud"))
                            .put("numero", rs.getString("numero"))
                            .put("fecha", _fh(rs.getTimestamp("fecha_solicitud")))
                            .put("estado", est)
                            .put("estado_tecnico", _estadoTecnico(est, rs.getBoolean("hay_stock")))
                            .put("resumen", rs.getString("resumen") == null ? "" : rs.getString("resumen"))
                            .put("motivo_rechazo", rs.getString("motivo_rechazo") != null ? rs.getString("motivo_rechazo")
                                    : (rs.getString("observacion_entrega") == null ? "" : rs.getString("observacion_entrega")))
                            .put("confirmada", rs.getBoolean("recepcion_confirmada"))
                            .put("puede_confirmar", entregada && !rs.getBoolean("recepcion_confirmada") && rs.getInt("id_usuario_solicita") == idUsuarioM));
                    }
                }
            }
            j.put("solicitudes", sols);

            JSONArray devs = new JSONArray();
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT v.numero, v.estado, v.fecha_devolucion, (SELECT string_agg(COALESCE(r.nombre, i.nombre) || ': ' || " +
                    "        trim(to_char(d.cantidad, 'FM999999990.##')) || CASE WHEN d.condicion = 'Dañado' THEN ' (dañado)' ELSE '' END, ', ') " +
                    "        FROM public.devoluciones_material_detalle d " +
                    "        LEFT JOIN public.catalogo_repuestos r ON d.tipo_articulo = 'R' AND r.id_repuesto = d.id_articulo " +
                    "        LEFT JOIN public.catalogo_insumos i ON d.tipo_articulo = 'I' AND i.id_insumo = d.id_articulo " +
                    "        WHERE d.id_devolucion = v.id_devolucion) AS resumen " +
                    "FROM public.devoluciones_material v WHERE v.tipo_orden = ? AND v.id_orden = ? ORDER BY v.id_devolucion DESC")) {
                ps.setString(1, tipoOrden);
                ps.setInt(2, idOrden);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        devs.put(new JSONObject().put("numero", rs.getString("numero")).put("estado", rs.getString("estado"))
                            .put("fecha", _fh(rs.getTimestamp("fecha_devolucion"))).put("resumen", rs.getString("resumen") == null ? "" : rs.getString("resumen")));
                    }
                }
            }
            j.put("devoluciones", devs);

            // Catálogo para pedir (con el stock disponible del depósito, como referencia)
            StringBuilder sb = new StringBuilder("<option value=''>-- Repuesto o insumo --</option><optgroup label='Repuestos'>");
            try (ResultSet rs = conexion.prepareStatement("SELECT id_repuesto, nombre, stock FROM public.catalogo_repuestos ORDER BY nombre").executeQuery()) {
                while (rs.next()) sb.append("<option value='R-").append(rs.getInt(1)).append("' data-stock='").append(_cant(rs.getBigDecimal(3)))
                        .append("'>").append(h(rs.getString(2))).append(" (en depósito: ").append(_cant(rs.getBigDecimal(3))).append(")</option>");
            }
            sb.append("</optgroup><optgroup label='Insumos'>");
            try (ResultSet rs = conexion.prepareStatement(
                    "SELECT i.id_insumo, i.nombre, i.stock, u.nombre_unidad FROM public.catalogo_insumos i LEFT JOIN public.unidades_medida u ON u.id_unidad = i.id_unidad ORDER BY i.nombre").executeQuery()) {
                while (rs.next()) sb.append("<option value='I-").append(rs.getInt(1)).append("' data-stock='").append(_cant(rs.getBigDecimal(3)))
                        .append("'>").append(h(rs.getString(2))).append(" (en depósito: ").append(_cant(rs.getBigDecimal(3)))
                        .append(rs.getString(4) == null ? "" : " " + h(rs.getString(4))).append(")</option>");
            }
            sb.append("</optgroup>");
            j.put("catalogo", sb.toString());
            out.print(j.toString());
        }

        // ============================================================
        // TÉCNICO: pedir material
        // ============================================================
        else if ("solicitar".equals(tipo)) {
            JSONObject d = new JSONObject(request.getParameter("datos"));
            String tipoOrden = "M".equals(d.optString("tipo_orden")) ? "M" : "T";
            int idOrden = d.getInt("id_orden");
            JSONArray items = d.optJSONArray("items");
            Object[] info = infoOrden(conexion, tipoOrden, idOrden, esAdminM, idTecnicoM);
            if (!(Boolean) info[0]) throw new Exception("La orden no existe.");
            if (!(Boolean) info[2]) throw new Exception("Solo el técnico asignado a la orden puede pedir material.");
            if (!(Boolean) info[1]) throw new Exception("La orden ya está finalizada: no se puede pedir material.");
            if (items == null || items.length() == 0) throw new Exception("Agregue al menos un artículo.");
            Object[] rev = revisionOrden(conexion, tipoOrden, idOrden);
            if (!(Boolean) rev[0]) throw new Exception((String) rev[1]);
            // Cómo queda la orden mientras llega el material (obligatorio)
            String queda = d.optString("queda", "");
            if (!"sigue".equals(queda) && !"detenido".equals(queda))
                throw new Exception("Indicá cómo queda la orden mientras llega el material: sigo trabajando o detenida hasta que llegue.");
            boolean detiene = "detenido".equals(queda);
            String obs = d.optString("observacion", "").trim();
            if (obs.length() > 255) obs = obs.substring(0, 255);
            String prioridad; Integer idEquipo = null;
            if ("T".equals(tipoOrden)) {
                prioridad = rev[2] == null ? "Media" : (String) rev[2];   // la urgencia del ticket
            } else {
                prioridad = "Urgente".equals(d.optString("prioridad")) ? "Urgente" : ("Normal".equals(d.optString("prioridad")) ? "Normal" : null);
                if (prioridad == null) throw new Exception("Indicá la urgencia del pedido: Normal o Urgente.");
                idEquipo = d.optInt("id_equipo", 0);
                if (idEquipo == 0) throw new Exception("Indicá para qué equipo es el material.");
                if (obs.length() < 5) throw new Exception("Escribí qué tiene el equipo (al menos 5 caracteres): queda como observación de la revisión.");
                try (PreparedStatement ps = conexion.prepareStatement(
                        "SELECT 1 FROM public.mantenimientos_preventivos_detalle WHERE id_mantenimiento = ? AND id_equipo = ?")) {
                    ps.setInt(1, idOrden); ps.setInt(2, idEquipo);
                    try (ResultSet rs = ps.executeQuery()) { if (!rs.next()) throw new Exception("El equipo no pertenece a este mantenimiento."); }
                }
            }

            try {
                conexion.setAutoCommit(false);
                int idSol;
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.solicitudes_material (tipo_orden, id_orden, id_usuario_solicita, observacion, prioridad, id_equipo, detiene) VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id_solicitud")) {
                    ps.setString(1, tipoOrden);
                    ps.setInt(2, idOrden);
                    ps.setInt(3, idUsuarioM);
                    ps.setString(4, obs.isEmpty() ? null : obs);
                    ps.setString(5, prioridad);
                    if (idEquipo == null) ps.setNull(6, Types.INTEGER); else ps.setInt(6, idEquipo);
                    ps.setBoolean(7, detiene);
                    try (ResultSet rs = ps.executeQuery()) { rs.next(); idSol = rs.getInt(1); }
                }
                if ("T".equals(tipoOrden)) {
                    int pasa = 0;
                    if (detiene) {
                        try (PreparedStatement ps = conexion.prepareStatement(
                                "UPDATE public.ticket SET estado = 'Esperando Repuesto' WHERE id_ticket = ? AND estado IN ('Asignado', 'En Proceso')")) {
                            ps.setInt(1, idOrden);
                            pasa = ps.executeUpdate();
                        }
                    }
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "INSERT INTO public.ticket_detalle (id_ticket, id_usuario, accion, descripcion) " +
                            "SELECT ?, ?, 'Pedido de material', 'Pedido ' || numero || (CASE WHEN ? THEN ': el ticket queda detenido hasta que llegue.' ELSE ': se sigue trabajando mientras llega.' END) " +
                            "FROM public.solicitudes_material WHERE id_solicitud = ?")) {
                        ps.setInt(1, idOrden); ps.setInt(2, idUsuarioM); ps.setBoolean(3, detiene); ps.setInt(4, idSol);
                        ps.executeUpdate();
                    }
                } else {
                    // Mantenimiento: el equipo queda revisado con "Requirió repuesto" y lo que tiene
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "UPDATE public.mantenimientos_preventivos_detalle SET resultado = COALESCE(resultado, 'Requirió repuesto'), " +
                            "observacion = CASE WHEN COALESCE(trim(observacion), '') = '' THEN ? ELSE observacion || ' | ' || ? END " +
                            "WHERE id_mantenimiento = ? AND id_equipo = ?")) {
                        ps.setString(1, obs); ps.setString(2, obs); ps.setInt(3, idOrden); ps.setInt(4, idEquipo);
                        ps.executeUpdate();
                    }
                }
                java.util.Set<String> vistos = new java.util.HashSet<String>();
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.solicitudes_material_detalle (id_solicitud, tipo_articulo, id_articulo, cantidad_solicitada) VALUES (?, ?, ?, ?)")) {
                    for (int i = 0; i < items.length(); i++) {
                        JSONObject it = items.getJSONObject(i);
                        String art = it.optString("articulo", "");
                        java.math.BigDecimal cant = _numDec(it.opt("cantidad"));
                        if (!art.matches("[RI]-\\d+")) throw new Exception("Línea " + (i + 1) + ": seleccione el artículo.");
                        if (!vistos.add(art)) throw new Exception("Línea " + (i + 1) + ": el artículo está repetido.");
                        if (cant.signum() <= 0) throw new Exception("Línea " + (i + 1) + ": la cantidad debe ser mayor a cero.");
                        ps.setInt(1, idSol);
                        ps.setString(2, art.substring(0, 1));
                        ps.setInt(3, Integer.parseInt(art.substring(2)));
                        ps.setBigDecimal(4, cant);
                        ps.addBatch();
                    }
                    ps.executeBatch();
                }
                conexion.commit();
                out.print("success");
            } catch (Exception ex) {
                conexion.rollback();
                throw ex;
            } finally {
                conexion.setAutoCommit(true);
            }
        }

        // ============================================================
        // TÉCNICO: confirmar que recibió el material
        // ============================================================
        else if ("confirmarRecepcion".equals(tipo)) {
            try (PreparedStatement ps = conexion.prepareStatement(
                    "UPDATE public.solicitudes_material SET recepcion_confirmada = true, fecha_confirmacion = CURRENT_TIMESTAMP " +
                    "WHERE id_solicitud = ? AND id_usuario_solicita = ? AND estado IN ('Entregada', 'Entregada parcial') AND NOT recepcion_confirmada")) {
                ps.setInt(1, Integer.parseInt(request.getParameter("id_solicitud")));
                ps.setInt(2, idUsuarioM);
                if (ps.executeUpdate() == 0) throw new Exception("Solo quien pidió el material puede confirmar que lo recibió (y una sola vez).");
            }
            out.print("success");
        }

        // ============================================================
        // TÉCNICO: devolver lo que sobró
        // ============================================================
        else if ("devolver".equals(tipo)) {
            JSONObject d = new JSONObject(request.getParameter("datos"));
            String tipoOrden = "M".equals(d.optString("tipo_orden")) ? "M" : "T";
            int idOrden = d.getInt("id_orden");
            JSONArray items = d.optJSONArray("items");
            Object[] info = infoOrden(conexion, tipoOrden, idOrden, esAdminM, idTecnicoM);
            if (!(Boolean) info[0]) throw new Exception("La orden no existe.");
            if (!(Boolean) info[2]) throw new Exception("Solo el técnico asignado a la orden puede devolver material.");
            if (items == null || items.length() == 0) throw new Exception("Indique qué devuelve.");

            try {
                conexion.setAutoCommit(false);
                // Se bloquean las solicitudes de la orden para que dos devoluciones simultáneas no superen el saldo
                try (PreparedStatement ps = conexion.prepareStatement(
                        "SELECT 1 FROM public.solicitudes_material WHERE tipo_orden = ? AND id_orden = ? FOR UPDATE")) {
                    ps.setString(1, tipoOrden); ps.setInt(2, idOrden); ps.executeQuery().close();
                }
                int idDev;
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.devoluciones_material (tipo_orden, id_orden, id_usuario_devuelve, observacion) VALUES (?, ?, ?, ?) RETURNING id_devolucion")) {
                    ps.setString(1, tipoOrden);
                    ps.setInt(2, idOrden);
                    ps.setInt(3, idUsuarioM);
                    String obs = d.optString("observacion", "").trim();
                    ps.setString(4, obs.isEmpty() ? null : (obs.length() > 255 ? obs.substring(0, 255) : obs));
                    try (ResultSet rs = ps.executeQuery()) { rs.next(); idDev = rs.getInt(1); }
                }
                int lineas = 0;
                for (int i = 0; i < items.length(); i++) {
                    JSONObject it = items.getJSONObject(i);
                    String art = it.optString("articulo", "");
                    java.math.BigDecimal cant = _numDec(it.opt("cantidad"));
                    String cond = "Dañado".equals(it.optString("condicion")) ? "Dañado" : "Bueno";
                    if (cant.signum() == 0) continue;
                    if (!art.matches("[RI]-\\d+") || cant.signum() < 0) throw new Exception("Línea " + (i + 1) + ": datos inválidos.");
                    java.math.BigDecimal saldo = null;
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "SELECT saldo FROM public.v_material_orden WHERE tipo_orden = ? AND id_orden = ? AND tipo_articulo = ? AND id_articulo = ?")) {
                        ps.setString(1, tipoOrden); ps.setInt(2, idOrden);
                        ps.setString(3, art.substring(0, 1)); ps.setInt(4, Integer.parseInt(art.substring(2)));
                        try (ResultSet rs = ps.executeQuery()) { if (rs.next()) saldo = rs.getBigDecimal(1); }
                    }
                    if (saldo == null || saldo.compareTo(cant) < 0)
                        throw new Exception("Línea " + (i + 1) + ": no puede devolver más de lo que tiene en su poder (" + _cant(saldo) + ").");
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "INSERT INTO public.devoluciones_material_detalle (id_devolucion, tipo_articulo, id_articulo, cantidad, condicion) VALUES (?, ?, ?, ?, ?)")) {
                        ps.setInt(1, idDev);
                        ps.setString(2, art.substring(0, 1));
                        ps.setInt(3, Integer.parseInt(art.substring(2)));
                        ps.setBigDecimal(4, cant);
                        ps.setString(5, cond);
                        ps.executeUpdate();
                    }
                    lineas++;
                }
                if (lineas == 0) throw new Exception("Indique al menos una cantidad a devolver.");
                conexion.commit();
                out.print("success");
            } catch (Exception ex) {
                conexion.rollback();
                throw ex;
            } finally {
                conexion.setAutoCommit(true);
            }
        }

        // ------------------------------------------------------------------
        // Desde acá: solo Encargado de depósito y Administrador (salvo "avisos", que es de todos)
        // ------------------------------------------------------------------
        else if (!esDeposito && !"avisos".equals(tipo)) {
            response.setStatus(javax.servlet.http.HttpServletResponse.SC_FORBIDDEN);
            out.print("Error: acceso restringido al Encargado de depósito y al Administrador.");
        }

        // ============================================================
        // DEPÓSITO: combo de pedidos pendientes
        // ============================================================
        else if ("comboPendientes".equals(tipo)) {
            StringBuilder sb = new StringBuilder("<option value=''>-- Seleccione un pedido --</option>");
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT s.id_solicitud, s.numero, s.fecha_solicitud, s.observacion, s.id_usuario_solicita, s.estado, s.prioridad, vs.hay_stock, " + String.format(SQL_ORDEN, "s") + " AS orden, " +
                    "       COALESCE(p.nombre || ' ' || p.apellido, u.login) AS solicitante " +
                    "FROM public.solicitudes_material s " +
                    "JOIN public.v_solicitud_stock vs ON vs.id_solicitud = s.id_solicitud " +
                    "JOIN public.usuarios u ON u.id_usuario = s.id_usuario_solicita LEFT JOIN public.personas p ON p.id_persona = u.id_persona " +
                    "WHERE s.estado IN ('Pendiente', 'En espera') " +
                    // Primero los que estaban en espera y ya tienen stock, después los nuevos, al final los que siguen sin stock
                    // Primero lo más urgente; a igual urgencia, los que ya tienen stock y después por antigüedad
                    "ORDER BY " + SQL_RANGO_PRIORIDAD + ", CASE WHEN s.estado = 'En espera' AND vs.hay_stock THEN 0 WHEN s.estado = 'Pendiente' THEN 1 ELSE 2 END, s.fecha_solicitud");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    boolean propia = !esAdminM && rs.getInt("id_usuario_solicita") == idUsuarioM;
                    boolean enEspera = "En espera".equals(rs.getString("estado"));
                    String marca = "[" + _prio(rs.getString("prioridad")) + "] "
                                 + (enEspera ? (rs.getBoolean("hay_stock") ? "YA HAY STOCK — " : "EN ESPERA DE STOCK — ") : "");
                    sb.append("<option value='").append(rs.getInt("id_solicitud")).append("'")
                      .append(" data-estado='").append(enEspera ? "espera" : "pendiente").append("'")
                      .append(" data-prioridad='").append(h(_prio(rs.getString("prioridad")))).append("'")
                      .append(" data-fecha='").append(h(_fh(rs.getTimestamp("fecha_solicitud")))).append("'")
                      .append(" data-orden='").append(h(rs.getString("orden"))).append("'")
                      .append(" data-tecnico='").append(h(rs.getString("solicitante"))).append("'")
                      .append(" data-obs='").append(h(rs.getString("observacion") == null ? "" : rs.getString("observacion"))).append("'")
                      .append(propia ? " disabled" : "").append(">")
                      .append(marca).append(h(rs.getString("numero"))).append(" — ").append(h(rs.getString("orden"))).append(" — ").append(h(rs.getString("solicitante")))
                      .append(propia ? " (lo entrega otro usuario)" : "").append("</option>");
                }
            }
            out.print(sb);
        }

        // ============================================================
        // DEPÓSITO: combo de órdenes con material por usar o devolver
        // ============================================================
        else if ("comboOrdenesConMaterial".equals(tipo)) {
            StringBuilder sb = new StringBuilder("<option value=''>-- Seleccione la orden --</option>");
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT x.tipo_orden, x.id_orden, " + String.format(SQL_ORDEN, "x") + " AS orden, " +
                    "       (SELECT string_agg(DISTINCT COALESCE(p.nombre || ' ' || p.apellido, u.login), ', ') FROM public.solicitudes_material s " +
                    "        JOIN public.usuarios u ON u.id_usuario = s.id_usuario_solicita LEFT JOIN public.personas p ON p.id_persona = u.id_persona " +
                    "        WHERE s.tipo_orden = x.tipo_orden AND s.id_orden = x.id_orden AND s.estado LIKE 'Entregada%') AS tecnicos " +
                    "FROM (SELECT DISTINCT tipo_orden, id_orden FROM public.v_material_orden WHERE saldo > 0) x ORDER BY 3");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    sb.append("<option value='").append(rs.getString(1)).append("-").append(rs.getInt(2)).append("' data-tecnico='")
                      .append(h(rs.getString(4))).append("'>").append(h(rs.getString(3))).append(" — ").append(h(rs.getString(4))).append("</option>");
                }
            }
            out.print(sb);
        }

        // ============================================================
        // DEPÓSITO: registrar devolución (vuelve al stock en el momento)
        // datos = { tipo_orden, id_orden, observacion, items:[{articulo, cantidad, condicion}] }
        // ============================================================
        else if ("registrarDevolucion".equals(tipo)) {
            JSONObject d = new JSONObject(request.getParameter("datos"));
            String tipoOrden = "M".equals(d.optString("tipo_orden")) ? "M" : "T";
            int idOrden = d.getInt("id_orden");
            JSONArray items = d.optJSONArray("items");
            if (items == null || items.length() == 0) throw new Exception("Indique qué se devuelve.");
            try {
                conexion.setAutoCommit(false);
                // Quién devuelve: el técnico que recibió el material de esa orden
                Integer idTecUsuario = null;
                try (PreparedStatement ps = conexion.prepareStatement(
                        "SELECT id_usuario_solicita FROM public.solicitudes_material WHERE tipo_orden = ? AND id_orden = ? AND estado LIKE 'Entregada%' ORDER BY id_solicitud DESC FOR UPDATE")) {
                    ps.setString(1, tipoOrden); ps.setInt(2, idOrden);
                    try (ResultSet rs = ps.executeQuery()) { if (rs.next()) idTecUsuario = rs.getInt(1); }
                }
                if (idTecUsuario == null) throw new Exception("Esa orden no recibió material.");
                if (!esAdminM && idTecUsuario.intValue() == idUsuarioM) throw new Exception("No puede recibir su propia devolución: debe hacerlo otro usuario.");
                int idDev; String numero;
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.devoluciones_material (tipo_orden, id_orden, id_usuario_devuelve, observacion, estado, id_usuario_recibe, fecha_recepcion) " +
                        "VALUES (?, ?, ?, ?, 'Recibida', ?, CURRENT_TIMESTAMP) RETURNING id_devolucion, numero")) {
                    ps.setString(1, tipoOrden);
                    ps.setInt(2, idOrden);
                    ps.setInt(3, idTecUsuario);
                    String obs = d.optString("observacion", "").trim();
                    ps.setString(4, obs.isEmpty() ? null : (obs.length() > 255 ? obs.substring(0, 255) : obs));
                    ps.setInt(5, idUsuarioM);
                    try (ResultSet rs = ps.executeQuery()) { rs.next(); idDev = rs.getInt(1); numero = rs.getString(2); }
                }
                int lineas = 0;
                for (int i = 0; i < items.length(); i++) {
                    JSONObject it = items.getJSONObject(i);
                    String art = it.optString("articulo", "");
                    java.math.BigDecimal cant = _numDec(it.opt("cantidad"));
                    boolean danado = "Dañado".equals(it.optString("condicion"));
                    if (cant.signum() == 0) continue;
                    if (!art.matches("[RI]-\\d+") || cant.signum() < 0) throw new Exception("Línea " + (i + 1) + ": datos inválidos.");
                    String ta = art.substring(0, 1); int ia = Integer.parseInt(art.substring(2));
                    java.math.BigDecimal saldo = null;
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "SELECT saldo FROM public.v_material_orden WHERE tipo_orden = ? AND id_orden = ? AND tipo_articulo = ? AND id_articulo = ?")) {
                        ps.setString(1, tipoOrden); ps.setInt(2, idOrden); ps.setString(3, ta); ps.setInt(4, ia);
                        try (ResultSet rs = ps.executeQuery()) { if (rs.next()) saldo = rs.getBigDecimal(1); }
                    }
                    if (saldo == null || saldo.compareTo(cant) < 0)
                        throw new Exception("Línea " + (i + 1) + ": no se puede devolver más de lo que tiene el técnico (" + _cant(saldo) + ").");
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "INSERT INTO public.devoluciones_material_detalle (id_devolucion, tipo_articulo, id_articulo, cantidad, condicion) VALUES (?, ?, ?, ?, ?)")) {
                        ps.setInt(1, idDev); ps.setString(2, ta); ps.setInt(3, ia); ps.setBigDecimal(4, cant); ps.setString(5, danado ? "Dañado" : "Bueno");
                        ps.executeUpdate();
                    }
                    try (PreparedStatement ps = conexion.prepareStatement("SELECT public.fn_kardex_contexto('DEVOLUCION', 'DEVOLUCION', ?, ?, NULL)")) {
                        ps.setInt(1, idDev); ps.setString(2, numero + (danado ? " (devuelto dañado)" : "")); ps.execute();
                    }
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "UPDATE " + tablaArt(ta) + " SET " + (danado ? "stock_danado = stock_danado" : "stock = stock") + " + ? WHERE " + colArt(ta) + " = ?")) {
                        ps.setBigDecimal(1, cant); ps.setInt(2, ia); ps.executeUpdate();
                    }
                    lineas++;
                }
                if (lineas == 0) throw new Exception("Indique al menos una cantidad a devolver.");
                conexion.commit();
                out.print("success|" + numero);
            } catch (Exception ex) {
                conexion.rollback();
                throw ex;
            } finally {
                conexion.setAutoCommit(true);
            }
        }

        // ============================================================
        // DEPÓSITO: historial de devoluciones
        // ============================================================
        else if ("historialDevoluciones".equals(tipo)) {
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT v.*, " + String.format(SQL_ORDEN, "v") + " AS orden, " +
                    "       COALESCE(p.nombre || ' ' || p.apellido, u.login) AS devuelve, " +
                    "       COALESCE(pr.nombre || ' ' || pr.apellido, ur.login) AS recibe, " +
                    "       (SELECT string_agg(COALESCE(r.nombre, i.nombre) || ': ' || trim(to_char(d.cantidad, 'FM999999990.##')) || " +
                    "               CASE WHEN d.condicion = 'Dañado' THEN ' (dañado)' ELSE '' END, '<br>' ORDER BY d.id_detalle) " +
                    "        FROM public.devoluciones_material_detalle d " +
                    "        LEFT JOIN public.catalogo_repuestos r ON d.tipo_articulo = 'R' AND r.id_repuesto = d.id_articulo " +
                    "        LEFT JOIN public.catalogo_insumos i ON d.tipo_articulo = 'I' AND i.id_insumo = d.id_articulo " +
                    "        WHERE d.id_devolucion = v.id_devolucion) AS resumen " +
                    "FROM public.devoluciones_material v " +
                    "JOIN public.usuarios u ON u.id_usuario = v.id_usuario_devuelve LEFT JOIN public.personas p ON p.id_persona = u.id_persona " +
                    "LEFT JOIN public.usuarios ur ON ur.id_usuario = v.id_usuario_recibe LEFT JOIN public.personas pr ON pr.id_persona = ur.id_persona " +
                    "ORDER BY v.id_devolucion DESC LIMIT 100");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    filas++;
                    String resumen = rs.getString("resumen") == null ? "" : h(rs.getString("resumen")).replace("&lt;br&gt;", "<br>");
                    boolean pendiente = "Pendiente".equals(rs.getString("estado"));
                    out.print("<tr><td><b>" + h(rs.getString("numero")) + "</b></td><td>" + _fh(pendiente ? rs.getTimestamp("fecha_devolucion") : rs.getTimestamp("fecha_recepcion")) + "</td>"
                        + "<td>" + h(rs.getString("orden")) + "</td><td>" + h(rs.getString("devuelve")) + "</td><td class='small'>" + resumen + "</td>"
                        + "<td>" + (pendiente
                            ? "<button class='btn btn-primary btn-sm' onclick='recibirDevolucion(" + rs.getInt("id_devolucion") + ", \"" + hj(rs.getString("numero")) + "\")'><i class='fas fa-check'></i> Recibir</button>"
                            : h(rs.getString("recibe"))) + "</td></tr>");
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='6' class='text-center text-muted py-3'>Todavía no hay devoluciones.</td></tr>");
        }

        // ============================================================
        // DEPÓSITO: pedidos pendientes de entrega (filas)
        // ============================================================
        else if ("pendientes".equals(tipo)) {
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT s.*, " + String.format(SQL_ORDEN, "s") + " AS orden, " +
                    "       COALESCE(p.nombre || ' ' || p.apellido, u.login) AS solicitante, " +
                    "       (SELECT string_agg(COALESCE(r.nombre, i.nombre) || ': ' || trim(to_char(d.cantidad_solicitada, 'FM999999990.##')) || " +
                    "               ' (stock ' || trim(to_char(COALESCE(r.stock, i.stock), 'FM999999990.##')) || ')', '<br>' ORDER BY d.id_detalle) " +
                    "        FROM public.solicitudes_material_detalle d " +
                    "        LEFT JOIN public.catalogo_repuestos r ON d.tipo_articulo = 'R' AND r.id_repuesto = d.id_articulo " +
                    "        LEFT JOIN public.catalogo_insumos i ON d.tipo_articulo = 'I' AND i.id_insumo = d.id_articulo " +
                    "        WHERE d.id_solicitud = s.id_solicitud) AS resumen " +
                    "FROM public.solicitudes_material s " +
                    "JOIN public.usuarios u ON u.id_usuario = s.id_usuario_solicita LEFT JOIN public.personas p ON p.id_persona = u.id_persona " +
                    "WHERE s.estado IN ('Pendiente', 'En espera') ORDER BY " + SQL_RANGO_PRIORIDAD + ", CASE WHEN s.estado = 'Pendiente' THEN 0 ELSE 1 END, s.fecha_solicitud");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    filas++;
                    boolean propia = !esAdminM && rs.getInt("id_usuario_solicita") == idUsuarioM;
                    // El nombre de los artículos viene de la base: se escapa todo menos los <br> que arma la consulta
                    String resumen = rs.getString("resumen") == null ? "" : h(rs.getString("resumen")).replace("&lt;br&gt;", "<br>");
                    out.print("<tr><td class='text-nowrap'><b>" + h(rs.getString("numero")) + "</b><small class='d-block text-muted'>" + _fh(rs.getTimestamp("fecha_solicitud")) + "</small></td>"
                        + "<td>" + h(rs.getString("orden")) + "</td><td>" + h(rs.getString("solicitante")) + "</td>"
                        + "<td class='small'>" + resumen + (rs.getString("observacion") == null ? "" : "<div class='text-muted'><i>" + h(rs.getString("observacion")) + "</i></div>") + "</td>"
                        + "<td class='text-center text-nowrap'>"
                        + (propia ? "<span class='small text-muted'>Lo entrega otro usuario</span>"
                                  : "<button class='btn btn-success btn-sm' onclick='abrirEntrega(" + rs.getInt("id_solicitud") + ")'><i class='fas fa-hand-holding' aria-hidden='true'></i> Entregar</button> "
                                  + "<button class='btn btn-outline-danger btn-sm' title='Rechazar' aria-label='Rechazar' onclick='rechazar(" + rs.getInt("id_solicitud") + ")'><i class='fas fa-ban' aria-hidden='true'></i></button>")
                        + "</td></tr>");
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='5' class='text-center text-muted py-3'>No hay pedidos pendientes.</td></tr>");
        }

        // ============================================================
        // DEPÓSITO: detalle de un pedido para entregar (JSON)
        // ============================================================
        else if ("detalleSolicitud".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            int idSol = Integer.parseInt(request.getParameter("id_solicitud"));
            JSONObject j = new JSONObject();
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT s.numero, " + String.format(SQL_ORDEN, "s") + " AS orden FROM public.solicitudes_material s WHERE s.id_solicitud = ?")) {
                ps.setInt(1, idSol);
                try (ResultSet rs = ps.executeQuery()) { if (rs.next()) j.put("numero", rs.getString(1)).put("orden", rs.getString(2)); }
            }
            JSONArray lineas = new JSONArray();
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT d.id_detalle, d.cantidad_solicitada, COALESCE(r.nombre, i.nombre) AS nombre, COALESCE(r.stock, i.stock) AS stock " +
                    "FROM public.solicitudes_material_detalle d " +
                    "LEFT JOIN public.catalogo_repuestos r ON d.tipo_articulo = 'R' AND r.id_repuesto = d.id_articulo " +
                    "LEFT JOIN public.catalogo_insumos i ON d.tipo_articulo = 'I' AND i.id_insumo = d.id_articulo " +
                    "WHERE d.id_solicitud = ? ORDER BY d.id_detalle")) {
                ps.setInt(1, idSol);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        java.math.BigDecimal sol = rs.getBigDecimal("cantidad_solicitada"), st = rs.getBigDecimal("stock");
                        lineas.put(new JSONObject().put("id_detalle", rs.getInt("id_detalle")).put("nombre", rs.getString("nombre"))
                            .put("solicitada", _cant(sol)).put("stock", _cant(st))
                            .put("sugerida", _cant(sol.min(st.max(java.math.BigDecimal.ZERO))))
                            .put("falta", st.compareTo(sol) < 0));
                    }
                }
            }
            j.put("lineas", lineas);
            out.print(j.toString());
        }

        // ============================================================
        // DEPÓSITO: entregar (descuenta el stock)
        // ============================================================
        else if ("entregar".equals(tipo)) {
            int idSol = Integer.parseInt(request.getParameter("id_solicitud"));
            JSONObject cants = new JSONObject(request.getParameter("cantidades"));   // { id_detalle: cantidad }
            String comentario = request.getParameter("comentario") == null ? "" : request.getParameter("comentario").trim();
            if (comentario.length() > 255) comentario = comentario.substring(0, 255);
            try {
                conexion.setAutoCommit(false);
                String numero, tipoOrden; int idOrden;
                try (PreparedStatement ps = conexion.prepareStatement(
                        "SELECT * FROM public.solicitudes_material WHERE id_solicitud = ? FOR UPDATE")) {
                    ps.setInt(1, idSol);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new Exception("El pedido no existe.");
                        if (!"Pendiente".equals(rs.getString("estado")) && !"En espera".equals(rs.getString("estado"))) throw new Exception("El pedido ya fue atendido.");
                        if (!esAdminM && rs.getInt("id_usuario_solicita") == idUsuarioM) throw new Exception("No puede entregarse material a sí mismo: debe hacerlo otro usuario.");
                        numero = rs.getString("numero"); tipoOrden = rs.getString("tipo_orden"); idOrden = rs.getInt("id_orden");
                    }
                }
                Object[] info = infoOrden(conexion, tipoOrden, idOrden, true, null);
                if (!(Boolean) info[1]) throw new Exception("La orden ya está finalizada: rechace el pedido.");

                boolean completo = true; int entregadas = 0;
                try (PreparedStatement psDet = conexion.prepareStatement("SELECT * FROM public.solicitudes_material_detalle WHERE id_solicitud = ? ORDER BY id_detalle");
                     PreparedStatement psCtx = conexion.prepareStatement("SELECT public.fn_kardex_contexto('ENTREGA', 'SOLICITUD MATERIAL', ?, ?, NULL)")) {
                    psDet.setInt(1, idSol);
                    try (ResultSet rs = psDet.executeQuery()) {
                        while (rs.next()) {
                            int idDet = rs.getInt("id_detalle");
                            String ta = rs.getString("tipo_articulo"); int ia = rs.getInt("id_articulo");
                            java.math.BigDecimal sol = rs.getBigDecimal("cantidad_solicitada");
                            java.math.BigDecimal ent = _numDec(cants.opt(String.valueOf(idDet)));
                            if (ent.signum() < 0 || ent.compareTo(sol) > 0) throw new Exception("La cantidad a entregar debe estar entre 0 y lo pedido.");
                            if (ent.compareTo(sol) < 0) completo = false;
                            java.math.BigDecimal costo = null;
                            if (ent.signum() > 0) {
                                String nombre;
                                try (PreparedStatement psSt = conexion.prepareStatement(
                                        "SELECT nombre, stock, ultimo_costo FROM " + tablaArt(ta) + " WHERE " + colArt(ta) + " = ? FOR UPDATE")) {
                                    psSt.setInt(1, ia);
                                    try (ResultSet rsSt = psSt.executeQuery()) {
                                        if (!rsSt.next()) throw new Exception("Un artículo del pedido ya no existe.");
                                        nombre = rsSt.getString("nombre");
                                        if (rsSt.getBigDecimal("stock").compareTo(ent) < 0)
                                            throw new Exception("No hay stock suficiente de " + nombre + ": querés entregar " + _cant(ent) + " y en el depósito hay "
                                                    + _cant(rsSt.getBigDecimal("stock")) + ". Entregá lo que hay con un comentario o rechazá el pedido por falta de stock.");
                                        costo = rsSt.getBigDecimal("ultimo_costo");
                                    }
                                }
                                psCtx.setInt(1, idSol);
                                psCtx.setString(2, numero + " - " + info[3]);
                                psCtx.execute();
                                try (PreparedStatement psUp = conexion.prepareStatement(
                                        "UPDATE " + tablaArt(ta) + " SET stock = stock - ? WHERE " + colArt(ta) + " = ?")) {
                                    psUp.setBigDecimal(1, ent);
                                    psUp.setInt(2, ia);
                                    psUp.executeUpdate();
                                }
                                entregadas++;
                            }
                            try (PreparedStatement psU = conexion.prepareStatement(
                                    "UPDATE public.solicitudes_material_detalle SET cantidad_entregada = ?, costo_unitario = ? WHERE id_detalle = ?")) {
                                psU.setBigDecimal(1, ent);
                                psU.setBigDecimal(2, costo);
                                psU.setInt(3, idDet);
                                psU.executeUpdate();
                            }
                        }
                    }
                }
                if (entregadas == 0) throw new Exception("No indicaste ninguna cantidad para entregar. Si no hay stock, usá \"Rechazar por falta de stock\".");
                if (!completo && comentario.length() < 5) throw new Exception("Entregás menos de lo pedido: escribí un comentario explicando por qué (por ejemplo, \"solo había 1 en el depósito\").");
                try (PreparedStatement ps = conexion.prepareStatement(
                        "UPDATE public.solicitudes_material SET estado = ?, id_usuario_entrega = ?, fecha_entrega = CURRENT_TIMESTAMP, " +
                        "recepcion_confirmada = true, fecha_confirmacion = CURRENT_TIMESTAMP, observacion_entrega = ? WHERE id_solicitud = ?")) {
                    ps.setString(1, completo ? "Entregada" : "Entregada parcial");
                    ps.setInt(2, idUsuarioM);
                    ps.setString(3, comentario.isEmpty() ? null : comentario);
                    ps.setInt(4, idSol);
                    ps.executeUpdate();
                }
                // Si el ticket estaba detenido esperando el repuesto, vuelve a "En Proceso" para que el técnico lo continúe
                if ("T".equals(tipoOrden)) {
                    int vuelve;
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "UPDATE public.ticket SET estado = 'En Proceso' WHERE id_ticket = ? AND estado = 'Esperando Repuesto'")) {
                        ps.setInt(1, idOrden);
                        vuelve = ps.executeUpdate();
                    }
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "INSERT INTO public.ticket_detalle (id_ticket, id_usuario, accion, descripcion) VALUES (?, ?, 'Material entregado', ?)")) {
                        ps.setInt(1, idOrden);
                        ps.setInt(2, idUsuarioM);
                        ps.setString(3, numero + (completo ? " entregado completo" : " entregado en parte") + (vuelve > 0 ? ". El ticket vuelve a En Proceso: continuar." : ".")
                                + (comentario.isEmpty() ? "" : " " + (comentario.length() > 150 ? comentario.substring(0, 150) : comentario)));
                        ps.executeUpdate();
                    }
                }
                conexion.commit();
                out.print("success");
            } catch (Exception ex) {
                conexion.rollback();
                throw ex;
            } finally {
                conexion.setAutoCommit(true);
            }
        }

        // ============================================================
        // DEPÓSITO: rechazar un pedido (con motivo)
        // ============================================================
        else if ("rechazar".equals(tipo)) {
            String motivo = request.getParameter("motivo");
            if (motivo == null || motivo.trim().length() < 5) throw new Exception("Indique el motivo (al menos 5 caracteres).");
            try (PreparedStatement ps = conexion.prepareStatement(
                    "UPDATE public.solicitudes_material SET estado = 'Rechazada', motivo_rechazo = ?, id_usuario_entrega = ?, fecha_entrega = CURRENT_TIMESTAMP " +
                    "WHERE id_solicitud = ? AND estado IN ('Pendiente', 'En espera') AND (id_usuario_solicita <> ? OR ?)")) {
                ps.setString(1, motivo.trim().length() > 255 ? motivo.trim().substring(0, 255) : motivo.trim());
                ps.setInt(2, idUsuarioM);
                ps.setInt(3, Integer.parseInt(request.getParameter("id_solicitud")));
                ps.setInt(4, idUsuarioM);
                ps.setBoolean(5, esAdminM);
                if (ps.executeUpdate() == 0) throw new Exception("El pedido ya fue atendido o es suyo.");
            }
            out.print("success");
        }

        // ============================================================
        // DEPÓSITO: sin stock -> el pedido queda EN ESPERA (no se rechaza).
        //  Si es de un ticket abierto, el ticket pasa a "Esperando Repuesto".
        //  Cuando entre mercadería, el pedido aparece arriba como "YA HAY STOCK".
        // ============================================================
        else if ("enEspera".equals(tipo)) {
            if (!esDeposito) throw new Exception("Solo el depósito puede dejar un pedido en espera.");
            int idSol = Integer.parseInt(request.getParameter("id_solicitud"));
            String comentario = request.getParameter("comentario") == null ? "" : request.getParameter("comentario").trim();
            comentario = "Sin stock" + (comentario.isEmpty() ? "" : ": " + comentario);
            if (comentario.length() > 255) comentario = comentario.substring(0, 255);
            try {
                conexion.setAutoCommit(false);
                String numero, tipoOrden; int idOrden; boolean detieneSol;
                try (PreparedStatement ps = conexion.prepareStatement(
                        "SELECT * FROM public.solicitudes_material WHERE id_solicitud = ? FOR UPDATE")) {
                    ps.setInt(1, idSol);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new Exception("El pedido no existe.");
                        detieneSol = rs.getBoolean("detiene");
                        if ("En espera".equals(rs.getString("estado"))) throw new Exception("El pedido ya está en espera de stock.");
                        if (!"Pendiente".equals(rs.getString("estado"))) throw new Exception("El pedido ya fue atendido.");
                        numero = rs.getString("numero"); tipoOrden = rs.getString("tipo_orden"); idOrden = rs.getInt("id_orden");
                    }
                }
                try (PreparedStatement ps = conexion.prepareStatement(
                        "UPDATE public.solicitudes_material SET estado = 'En espera', fecha_espera = CURRENT_TIMESTAMP, id_usuario_espera = ?, observacion_entrega = ? WHERE id_solicitud = ?")) {
                    ps.setInt(1, idUsuarioM);
                    ps.setString(2, comentario);
                    ps.setInt(3, idSol);
                    ps.executeUpdate();
                }
                if ("T".equals(tipoOrden)) {
                    // Solo se detiene el ticket si el técnico indicó que no puede seguir sin el material
                    int pasa = 0;
                    if (detieneSol) {
                        try (PreparedStatement ps = conexion.prepareStatement(
                                "UPDATE public.ticket SET estado = 'Esperando Repuesto' WHERE id_ticket = ? AND estado IN ('Asignado', 'En Proceso')")) {
                            ps.setInt(1, idOrden);
                            pasa = ps.executeUpdate();
                        }
                    }
                    try (PreparedStatement ps = conexion.prepareStatement(
                            "INSERT INTO public.ticket_detalle (id_ticket, id_usuario, accion, descripcion) VALUES (?, ?, 'Esperando repuesto', ?)")) {
                        ps.setInt(1, idOrden);
                        ps.setInt(2, idUsuarioM);
                        ps.setString(3, numero + ": el depósito no tiene stock, el pedido queda en espera"
                                + (pasa > 0 ? " y el ticket pasa a Esperando Repuesto." : "."));
                        ps.executeUpdate();
                    }
                }
                conexion.commit();
                out.print("success");
            } catch (Exception ex) {
                conexion.rollback();
                throw ex;
            } finally {
                conexion.setAutoCommit(true);
            }
        }

        // ============================================================
        // AVISOS del menú superior (JSON)
        //  Técnico: pedidos listos para retirar / en espera de stock.
        //  Depósito: pedidos por entregar / de esos, cuántos en espera ya tienen stock.
        // ============================================================
        else if ("avisos".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            JSONObject j = new JSONObject().put("ok", true);
            if (esDeposito) {
                try (PreparedStatement ps = conexion.prepareStatement(
                        "SELECT count(*) FILTER (WHERE estado = 'Pendiente') AS nuevos, " +
                        "       count(*) FILTER (WHERE estado = 'En espera' AND hay_stock) AS con_stock, " +
                        "       count(*) FILTER (WHERE estado = 'En espera' AND NOT hay_stock) AS sin_stock " +
                        "FROM public.v_solicitud_stock WHERE estado IN ('Pendiente', 'En espera') AND (id_usuario_solicita <> ? OR ?)")) {
                    ps.setInt(1, idUsuarioM);
                    ps.setBoolean(2, esAdminM);
                    try (ResultSet rs = ps.executeQuery()) {
                        rs.next();
                        j.put("deposito", new JSONObject().put("nuevos", rs.getInt("nuevos")).put("con_stock", rs.getInt("con_stock")).put("sin_stock", rs.getInt("sin_stock")));
                    }
                }
            }
            // Pedidos propios (técnico, o el Administrador cuando atiende órdenes)
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT count(*) FILTER (WHERE hay_stock AND tipo_orden = 'T') AS listos_t, count(*) FILTER (WHERE hay_stock AND tipo_orden = 'M') AS listos_m, " +
                    "       count(*) FILTER (WHERE estado = 'En espera' AND NOT hay_stock AND tipo_orden = 'T') AS espera_t, " +
                    "       count(*) FILTER (WHERE estado = 'En espera' AND NOT hay_stock AND tipo_orden = 'M') AS espera_m " +
                    "FROM public.v_solicitud_stock WHERE estado IN ('Pendiente', 'En espera') AND id_usuario_solicita = ?")) {
                ps.setInt(1, idUsuarioM);
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    // T = tickets, M = mantenimientos (cada aviso lleva a su pantalla)
                    j.put("tecnico", new JSONObject()
                        .put("listos", rs.getInt("listos_t") + rs.getInt("listos_m")).put("espera", rs.getInt("espera_t") + rs.getInt("espera_m"))
                        .put("listos_t", rs.getInt("listos_t")).put("listos_m", rs.getInt("listos_m"))
                        .put("espera_t", rs.getInt("espera_t")).put("espera_m", rs.getInt("espera_m")));
                }
            }
            if (idTecnicoM != null) {
                try (PreparedStatement ps = conexion.prepareStatement(
                        "SELECT count(*) FROM public.ticket WHERE id_tecnico_asignado = ? AND fecha_revision IS NULL " +
                        "AND estado IN ('Asignado', 'En Proceso', 'Esperando Repuesto')")) {
                    ps.setInt(1, idTecnicoM);
                    try (ResultSet rs = ps.executeQuery()) { rs.next(); j.getJSONObject("tecnico").put("sin_revisar", rs.getInt(1)); }
                }
            }
            out.print(j.toString());
        }

        // ============================================================
        // DEPÓSITO: devoluciones pendientes de recibir (filas)
        // ============================================================
        else if ("devolucionesPendientes".equals(tipo)) {
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT v.*, " + String.format(SQL_ORDEN, "v") + " AS orden, " +
                    "       COALESCE(p.nombre || ' ' || p.apellido, u.login) AS devuelve, " +
                    "       (SELECT string_agg(COALESCE(r.nombre, i.nombre) || ': ' || trim(to_char(d.cantidad, 'FM999999990.##')) || " +
                    "               CASE WHEN d.condicion = 'Dañado' THEN ' [DAÑADO]' ELSE '' END, '<br>' ORDER BY d.id_detalle) " +
                    "        FROM public.devoluciones_material_detalle d " +
                    "        LEFT JOIN public.catalogo_repuestos r ON d.tipo_articulo = 'R' AND r.id_repuesto = d.id_articulo " +
                    "        LEFT JOIN public.catalogo_insumos i ON d.tipo_articulo = 'I' AND i.id_insumo = d.id_articulo " +
                    "        WHERE d.id_devolucion = v.id_devolucion) AS resumen " +
                    "FROM public.devoluciones_material v " +
                    "JOIN public.usuarios u ON u.id_usuario = v.id_usuario_devuelve LEFT JOIN public.personas p ON p.id_persona = u.id_persona " +
                    "WHERE v.estado = 'Pendiente' ORDER BY v.fecha_devolucion");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    filas++;
                    boolean propia = !esAdminM && rs.getInt("id_usuario_devuelve") == idUsuarioM;
                    String resumen = rs.getString("resumen") == null ? "" : h(rs.getString("resumen")).replace("&lt;br&gt;", "<br>");
                    out.print("<tr><td class='text-nowrap'><b>" + h(rs.getString("numero")) + "</b><small class='d-block text-muted'>" + _fh(rs.getTimestamp("fecha_devolucion")) + "</small></td>"
                        + "<td>" + h(rs.getString("orden")) + "</td><td>" + h(rs.getString("devuelve")) + "</td>"
                        + "<td class='small'>" + resumen + (rs.getString("observacion") == null ? "" : "<div class='text-muted'><i>" + h(rs.getString("observacion")) + "</i></div>") + "</td>"
                        + "<td class='text-center'>"
                        + (propia ? "<span class='small text-muted'>La recibe otro usuario</span>"
                                  : "<button class='btn btn-primary btn-sm' onclick='recibirDevolucion(" + rs.getInt("id_devolucion") + ", \"" + hj(rs.getString("numero")) + "\")'><i class='fas fa-check' aria-hidden='true'></i> Recibir</button>")
                        + "</td></tr>");
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='5' class='text-center text-muted py-3'>No hay devoluciones pendientes.</td></tr>");
        }

        // ============================================================
        // DEPÓSITO: recibir devolución (vuelve al stock o al stock dañado)
        // ============================================================
        else if ("recibirDevolucion".equals(tipo)) {
            int idDev = Integer.parseInt(request.getParameter("id_devolucion"));
            try {
                conexion.setAutoCommit(false);
                String numero;
                try (PreparedStatement ps = conexion.prepareStatement("SELECT * FROM public.devoluciones_material WHERE id_devolucion = ? FOR UPDATE")) {
                    ps.setInt(1, idDev);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new Exception("La devolución no existe.");
                        if (!"Pendiente".equals(rs.getString("estado"))) throw new Exception("La devolución ya fue recibida.");
                        if (!esAdminM && rs.getInt("id_usuario_devuelve") == idUsuarioM) throw new Exception("No puede recibir su propia devolución: debe hacerlo otro usuario.");
                        numero = rs.getString("numero");
                    }
                }
                try (PreparedStatement psDet = conexion.prepareStatement("SELECT * FROM public.devoluciones_material_detalle WHERE id_devolucion = ?");
                     PreparedStatement psCtx = conexion.prepareStatement("SELECT public.fn_kardex_contexto('DEVOLUCION', 'DEVOLUCION', ?, ?, NULL)")) {
                    psDet.setInt(1, idDev);
                    try (ResultSet rs = psDet.executeQuery()) {
                        while (rs.next()) {
                            String ta = rs.getString("tipo_articulo");
                            boolean danado = "Dañado".equals(rs.getString("condicion"));
                            psCtx.setInt(1, idDev);
                            psCtx.setString(2, numero + (danado ? " (devuelto dañado)" : ""));
                            psCtx.execute();
                            try (PreparedStatement psUp = conexion.prepareStatement(
                                    "UPDATE " + tablaArt(ta) + " SET " + (danado ? "stock_danado = stock_danado" : "stock = stock") + " + ? WHERE " + colArt(ta) + " = ?")) {
                                psUp.setBigDecimal(1, rs.getBigDecimal("cantidad"));
                                psUp.setInt(2, rs.getInt("id_articulo"));
                                psUp.executeUpdate();
                            }
                        }
                    }
                }
                try (PreparedStatement ps = conexion.prepareStatement(
                        "UPDATE public.devoluciones_material SET estado = 'Recibida', id_usuario_recibe = ?, fecha_recepcion = CURRENT_TIMESTAMP WHERE id_devolucion = ?")) {
                    ps.setInt(1, idUsuarioM);
                    ps.setInt(2, idDev);
                    ps.executeUpdate();
                }
                conexion.commit();
                out.print("success");
            } catch (Exception ex) {
                conexion.rollback();
                throw ex;
            } finally {
                conexion.setAutoCommit(true);
            }
        }

        // ============================================================
        // DEPÓSITO: material en poder de técnicos (sin rendir)
        // ============================================================
        else if ("enPoder".equals(tipo)) {
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT v.*, " + String.format(SQL_ORDEN, "v") + " AS orden, " +
                    "       (SELECT string_agg(DISTINCT COALESCE(p.nombre || ' ' || p.apellido, u.login), ', ') FROM public.solicitudes_material s " +
                    "        JOIN public.usuarios u ON u.id_usuario = s.id_usuario_solicita LEFT JOIN public.personas p ON p.id_persona = u.id_persona " +
                    "        WHERE s.tipo_orden = v.tipo_orden AND s.id_orden = v.id_orden AND s.estado LIKE 'Entregada%') AS tecnicos " +
                    "FROM public.v_material_orden v WHERE v.saldo > 0 OR v.sin_confirmar > 0 ORDER BY 12, v.articulo");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    filas++;
                    out.print("<tr><td>" + h(rs.getString("tecnicos")) + "</td><td>" + h(rs.getString("orden")) + "</td><td>" + h(rs.getString("articulo")) + "</td>"
                        + "<td class='text-right'>" + _cant(rs.getBigDecimal("entregado").add(rs.getBigDecimal("sin_confirmar"))) + "</td>"
                        + "<td class='text-right'>" + _cant(rs.getBigDecimal("usado")) + "</td>"
                        + "<td class='text-right'>" + _cant(rs.getBigDecimal("devuelto")) + "</td>"
                        + "<td class='text-right font-weight-bold text-danger'>" + _cant(rs.getBigDecimal("saldo")) + "</td>"
                        + "<td>" + (rs.getBigDecimal("sin_confirmar").signum() > 0 ? "<span class='badge badge-warning'>Falta confirmar recepción</span>" : "<span class='badge badge-info'>Sin rendir</span>") + "</td></tr>");
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='8' class='text-center text-muted py-3'>Todo el material entregado está rendido.</td></tr>");
        }

        // ============================================================
        // DEPÓSITO: historial de pedidos atendidos
        // ============================================================
        else if ("historial".equals(tipo)) {
            int filas = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT s.*, " + String.format(SQL_ORDEN, "s") + " AS orden, " +
                    "       COALESCE(p.nombre || ' ' || p.apellido, u.login) AS solicitante, " +
                    "       COALESCE(pe.nombre || ' ' || pe.apellido, ue.login) AS entrego " +
                    "FROM public.solicitudes_material s " +
                    "JOIN public.usuarios u ON u.id_usuario = s.id_usuario_solicita LEFT JOIN public.personas p ON p.id_persona = u.id_persona " +
                    "LEFT JOIN public.usuarios ue ON ue.id_usuario = s.id_usuario_entrega LEFT JOIN public.personas pe ON pe.id_persona = ue.id_persona " +
                    "WHERE s.estado NOT IN ('Pendiente', 'En espera') ORDER BY s.fecha_entrega DESC NULLS LAST LIMIT 100");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    filas++;
                    String est = rs.getString("estado");
                    String badge = "Rechazada".equals(est) ? "badge-danger" : ("Entregada".equals(est) ? "badge-success" : "badge-primary");
                    out.print("<tr><td><b>" + h(rs.getString("numero")) + "</b></td><td>" + h(rs.getString("orden")) + "</td><td>" + h(rs.getString("solicitante")) + "</td>"
                        + "<td>" + h(rs.getString("entrego")) + "<small class='d-block text-muted'>" + _fh(rs.getTimestamp("fecha_entrega")) + "</small></td>"
                        + "<td><span class='badge " + badge + "'>" + h(est) + "</span>"
                        + ("Rechazada".equals(est) ? "<small class='d-block text-muted'>" + h(rs.getString("motivo_rechazo")) + "</small>"
                           : (rs.getString("observacion_entrega") == null ? "" : "<small class='d-block text-muted'>" + h(rs.getString("observacion_entrega")) + "</small>"))
                        + "</td><td class='text-center'>"
                        + ("Rechazada".equals(est) ? "" : "<button class='btn btn-info btn-sm' title='Acta de entrega' aria-label='Acta de entrega' onclick=\"window.open('../controladores/materialesControlador.jsp?tipo=actaPdf&id=" + rs.getInt("id_solicitud") + "', '_blank')\"><i class='fas fa-file-pdf' aria-hidden='true'></i></button>")
                        + "</td></tr>");
                }
            }
            if (filas == 0) out.print("<tr class='cta-empty-row'><td colspan='6' class='text-center text-muted py-3'>Todavía no hay pedidos atendidos.</td></tr>");
        }

        // ============================================================
        // ACTA DE ENTREGA (PDF)
        // ============================================================
        else if ("actaPdf".equals(tipo)) {
            java.util.List<Integer> ids = new java.util.ArrayList<Integer>();
            ids.add(Integer.parseInt(request.getParameter("id")));
            byte[] pdf = com.mycompany.pro.util.ComprobanteUtil.generar(conexion, application.getRealPath("reportes"),
                    "comprobanteEntregaMaterial", new String[]{"comprobanteEntregaMaterialDetalle"}, "ID_SOLICITUD", ids, idUsuarioM);
            response.setContentType("application/pdf");
            response.setContentLength(pdf.length);
            response.setHeader("Content-Disposition", "inline; filename=acta_entrega_" + ids.get(0) + ".pdf");
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
