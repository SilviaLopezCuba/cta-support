<%@page import="java.sql.*"%>
<%!
    /**
     * Ingresa al inventario una recepción ya cargada (cabecera + detalle):
     *  - crea un equipo por unidad en el Depósito,
     *  - suma repuestos e insumos al stock (queda en Movimientos de stock),
     *  - si viene de un pedido de reposición, actualiza lo recibido,
     *  - la deja Confirmada (ya no se modifica).
     * Debe llamarse dentro de una transacción. Devuelve los equipos creados.
     */
    static int aplicarRecepcion(Connection c, int id, int idUsuario) throws Exception {
        String numero; java.sql.Date fechaRec;
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT estado, numero_recepcion, fecha_recepcion FROM public.recepciones WHERE id_recepcion = ? FOR UPDATE")) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) throw new Exception("La recepción no existe.");
                if ("Confirmada".equals(rs.getString("estado"))) throw new Exception("La recepción ya fue registrada.");
                numero = rs.getString("numero_recepcion");
                fechaRec = rs.getDate("fecha_recepcion");
            }
        }
        Integer idDeposito;
        try (ResultSet rs = c.prepareStatement("SELECT id_sala FROM public.salas WHERE es_deposito").executeQuery()) {
            if (!rs.next()) throw new Exception("No existe el Depósito: ejecute el script de la fase 1.");
            idDeposito = rs.getInt(1);
        }

        // 1) Equipos: uno por unidad, en el Depósito, sin código patrimonial
        int equiposCreados = 0;
        try (PreparedStatement psDet = c.prepareStatement("SELECT * FROM public.recepciones_detalle_equipos WHERE id_recepcion = ? ORDER BY id_detalle");
             PreparedStatement psIns = c.prepareStatement(
                "INSERT INTO public.equipos (modelo, id_marca, id_categoria, id_sala, especificaciones, condicion_ingreso, costo, fecha_ingreso, " +
                "fecha_vencimiento_garantia, estado, id_recepcion) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Activo', ?)")) {
            psDet.setInt(1, id);
            try (ResultSet rs = psDet.executeQuery()) {
                while (rs.next()) {
                    for (int u = 0; u < rs.getInt("cantidad"); u++) {
                        psIns.setString(1, rs.getString("modelo"));
                        if (rs.getObject("id_marca") == null) psIns.setNull(2, Types.INTEGER); else psIns.setInt(2, rs.getInt("id_marca"));
                        psIns.setInt(3, rs.getInt("id_categoria"));
                        psIns.setInt(4, idDeposito);
                        psIns.setString(5, rs.getString("especificaciones"));
                        psIns.setString(6, rs.getString("condicion_ingreso"));
                        psIns.setBigDecimal(7, rs.getBigDecimal("costo_unitario"));
                        psIns.setDate(8, fechaRec);
                        psIns.setDate(9, rs.getDate("fecha_garantia"));
                        psIns.setInt(10, id);
                        psIns.addBatch();
                        equiposCreados++;
                    }
                }
            }
            psIns.executeBatch();
        }

        // 2) Repuestos e insumos: suman al stock disponible; el trigger deja el kardex
        try (PreparedStatement psDet = c.prepareStatement("SELECT * FROM public.recepciones_detalle_articulos WHERE id_recepcion = ? ORDER BY id_detalle");
             PreparedStatement psCtx = c.prepareStatement("SELECT public.fn_kardex_contexto('ENTRADA', 'RECEPCION', ?, ?, ?)")) {
            psDet.setInt(1, id);
            try (ResultSet rs = psDet.executeQuery()) {
                while (rs.next()) {
                    boolean esRep = rs.getObject("id_repuesto") != null;
                    java.math.BigDecimal costo = rs.getBigDecimal("costo_unitario");
                    psCtx.setInt(1, id);
                    psCtx.setString(2, numero);
                    psCtx.setBigDecimal(3, costo);
                    psCtx.execute();
                    String sqlStock = esRep
                        ? "UPDATE public.catalogo_repuestos SET stock = stock + ?, ultimo_costo = CASE WHEN ? > 0 THEN ? ELSE ultimo_costo END WHERE id_repuesto = ?"
                        : "UPDATE public.catalogo_insumos SET stock = stock + ?, ultimo_costo = CASE WHEN ? > 0 THEN ? ELSE ultimo_costo END WHERE id_insumo = ?";
                    try (PreparedStatement psUp = c.prepareStatement(sqlStock)) {
                        psUp.setBigDecimal(1, rs.getBigDecimal("cantidad"));
                        psUp.setBigDecimal(2, costo);
                        psUp.setBigDecimal(3, costo);
                        psUp.setInt(4, esRep ? rs.getInt("id_repuesto") : rs.getInt("id_insumo"));
                        if (psUp.executeUpdate() == 0) throw new Exception("Un artículo de la recepción ya no existe en el catálogo.");
                    }
                }
            }
        }

        // 3) Fase 6: si viene de un pedido de reposición, se actualiza lo recibido y el estado del pedido
        Integer idPedido = null;
        try (PreparedStatement ps = c.prepareStatement("SELECT id_solicitud_origen FROM public.recepciones WHERE id_recepcion = ?")) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) { if (rs.next() && rs.getObject(1) != null) idPedido = rs.getInt(1); }
        }
        if (idPedido != null) {
            try (PreparedStatement ps = c.prepareStatement(
                    "UPDATE public.solicitudes_compra_detalle d SET cantidad_recibida = d.cantidad_recibida + ra.cantidad " +
                    "FROM public.recepciones_detalle_articulos ra " +
                    "WHERE ra.id_recepcion = ? AND d.id_solicitud = ? " +
                    "AND ra.id_repuesto IS NOT DISTINCT FROM d.id_repuesto AND ra.id_insumo IS NOT DISTINCT FROM d.id_insumo")) {
                ps.setInt(1, id);
                ps.setInt(2, idPedido);
                ps.executeUpdate();
            }
            try (PreparedStatement ps = c.prepareStatement(
                    "UPDATE public.solicitudes_compra s SET estado = CASE " +
                    "  WHEN NOT EXISTS (SELECT 1 FROM public.solicitudes_compra_detalle d WHERE d.id_solicitud = s.id_solicitud AND d.cantidad_recibida < d.cantidad_solicitada) THEN 'Recibida' " +
                    "  ELSE 'Recibida parcial' END " +
                    "WHERE s.id_solicitud = ?")) {
                ps.setInt(1, idPedido);
                ps.executeUpdate();
            }
        }

        try (PreparedStatement ps = c.prepareStatement(
                "UPDATE public.recepciones SET estado = 'Confirmada', id_usuario_confirma = ?, fecha_confirmacion = CURRENT_TIMESTAMP WHERE id_recepcion = ?")) {
            ps.setInt(1, idUsuario);
            ps.setInt(2, id);
            ps.executeUpdate();
        }
        return equiposCreados;
    }

    /**
     * Un técnico determinó que el equipo no tiene arreglo (desde un ticket o un
     * mantenimiento): pasa a Inactivo con el motivo indicado y queda registrado el
     * movimiento de baja con la orden de origen. El equipo sigue figurando en su
     * sala hasta que el Encargado lo recibe en el Depósito.
     * Debe llamarse dentro de una transacción. Devuelve el número del movimiento
     * (o null si el equipo ya estaba inactivo).
     */
    static String bajaPorOrden(Connection c, int idEquipo, Integer idMotivo, String origen, String observacion, int idUsuario) throws Exception {
        try (PreparedStatement ps = c.prepareStatement("SELECT estado FROM public.equipos WHERE id_equipo = ? FOR UPDATE")) {
            ps.setInt(1, idEquipo);
            try (ResultSet rs = ps.executeQuery()) { if (!rs.next() || !"Activo".equals(rs.getString(1))) return null; }
        }
        if (idMotivo == null) {
            try (ResultSet rs = c.prepareStatement(
                    "SELECT id_motivo FROM public.motivos_inactivo WHERE activo AND aplica_equipos AND NOT descuenta " +
                    "ORDER BY (lower(nombre_motivo) LIKE 'daño%') DESC, id_motivo LIMIT 1").executeQuery()) {
                if (!rs.next()) throw new Exception("Falta el motivo \"Daño irreparable\" en Motivos de inactivo.");
                idMotivo = rs.getInt(1);
            }
        }
        String obs = (origen + (observacion == null || observacion.trim().isEmpty() ? "" : ": " + observacion.trim()));
        if (obs.length() > 255) obs = obs.substring(0, 255);
        String numero; int idMov;
        try (PreparedStatement ps = c.prepareStatement(
                "INSERT INTO public.movimientos_equipos (tipo, id_motivo, observacion, id_usuario, origen) VALUES ('BAJA', ?, ?, ?, ?) RETURNING id_movimiento, numero")) {
            ps.setInt(1, idMotivo); ps.setString(2, obs); ps.setInt(3, idUsuario); ps.setString(4, origen);
            try (ResultSet rs = ps.executeQuery()) { rs.next(); idMov = rs.getInt(1); numero = rs.getString(2); }
        }
        try (PreparedStatement ps = c.prepareStatement(
                "INSERT INTO public.movimientos_equipos_detalle (id_movimiento, id_equipo, id_sala_origen) SELECT ?, id_equipo, id_sala FROM public.equipos WHERE id_equipo = ?")) {
            ps.setInt(1, idMov); ps.setInt(2, idEquipo); ps.executeUpdate();
        }
        try (PreparedStatement ps = c.prepareStatement(
                "UPDATE public.equipos SET estado = 'Inactivo', id_motivo_inactivo = ?, observacion_inactivo = ?, fecha_inactivo = CURRENT_DATE WHERE id_equipo = ?")) {
            ps.setInt(1, idMotivo); ps.setString(2, numero + " - " + obs); ps.setInt(3, idEquipo); ps.executeUpdate();
        }
        return numero;
    }
%>
<%!
    /**
     * Columnas con el estado del material pedido para una orden (ticket 'T' o mantenimiento 'M').
     * colId es la columna con el id de la orden en la consulta (ej.: "t.id_ticket", "m.id_mantenimiento").
     * Se usan con badgeMaterial(rs) en las bandejas del técnico.
     */
    static String sqlMaterialOrden(String tipoOrden, String colId) {
        String w = "v.tipo_orden = '" + ("M".equals(tipoOrden) ? "M" : "T") + "' AND v.id_orden = " + colId;
        return "(SELECT count(*) FROM public.v_solicitud_stock v WHERE " + w + " AND v.estado IN ('Pendiente','En espera') AND v.hay_stock) AS mat_listos, " +
               "(SELECT count(*) FROM public.v_solicitud_stock v WHERE " + w + " AND v.estado = 'En espera' AND NOT v.hay_stock) AS mat_espera, " +
               "(SELECT count(*) FROM public.v_solicitud_stock v WHERE " + w + " AND v.estado = 'Pendiente' AND NOT v.hay_stock) AS mat_enviados, " +
               "(SELECT count(*) FROM public.solicitudes_material v WHERE " + w + " AND v.estado LIKE 'Entregada%') AS mat_entregados, " +
               "(SELECT min(v.fecha_espera) FROM public.solicitudes_material v WHERE " + w + " AND v.estado = 'En espera') AS mat_desde, " +
               "(SELECT count(*) FROM public.solicitudes_material v WHERE " + w + " AND v.estado IN ('Pendiente','En espera') AND v.detiene) AS mat_detiene ";
    }

    /** Lo que el técnico tiene que saber de su material: si puede ir a retirar o tiene que esperar. */
    static String badgeMaterial(ResultSet rs) throws SQLException {
        if (rs.getInt("mat_listos") > 0)
            return "<span class='badge badge-success' title='Hay stock en el depósito: pasá a retirarlo'><i class='fas fa-check-circle'></i> Listo para retirar</span>";
        if (rs.getInt("mat_espera") > 0) {
            Timestamp desde = rs.getTimestamp("mat_desde");
            return "<span class='badge badge-danger' title='El depósito no tiene stock. Te avisamos cuando entre.'><i class='fas fa-hourglass-half'></i> En espera de stock</span>"
                 + (desde != null ? "<div class='small text-muted'>desde " + new java.text.SimpleDateFormat("dd/MM/yyyy").format(desde) + "</div>" : "");
        }
        if (rs.getInt("mat_enviados") > 0)
            return "<span class='badge badge-warning' title='El depósito todavía no lo atendió'><i class='fas fa-paper-plane'></i> Pedido enviado</span>";
        if (rs.getInt("mat_entregados") > 0)
            return "<span class='badge badge-light border'><i class='fas fa-check'></i> Entregado</span>";
        return "<span class='small text-muted'>Sin pedidos</span>";
    }
%>
