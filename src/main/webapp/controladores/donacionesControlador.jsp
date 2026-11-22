<%@page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="org.json.JSONObject"%>
<%@page import="org.json.JSONArray"%>
<%@page import="java.math.BigDecimal"%>
<%@include file="../config/conexion.jsp"%>
<%!
    private static String _f(java.util.Date d) { return d == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _f(java.util.Date d, String def) { return d == null ? def : new java.text.SimpleDateFormat("dd/MM/yyyy").format(d); }
    private static String _fh(java.sql.Timestamp t) { return t == null ? "-" : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
    private static String _fh(java.sql.Timestamp t, String def) { return t == null ? def : new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(t); }
%>

<%
    // Controlador de Donaciones recibidas (aumenta el stock via trigger de BD).
    // La institucion NO compra: recibe donaciones, por eso no se registran
    // precios ni totales; solo donante, comprobante, fecha y cantidades.
    //
    // tipo = cargarCombosDonacion | listarDonaciones | registrarDonacion | obtenerComprobante
    String tipo = request.getParameter("tipo");

    try {
        // 1. Combos: donantes y articulos (repuestos + insumos)
        if ("cargarCombosDonacion".equals(tipo)) {
            StringBuilder donHTML = new StringBuilder("<option value=''>-- Seleccione Donante --</option>");
            PreparedStatement psD = conexion.prepareStatement("SELECT id_donante, nombre FROM public.donantes ORDER BY nombre");
            ResultSet rsD = psD.executeQuery();
            while (rsD.next()) {
                donHTML.append("<option value='").append(rsD.getInt("id_donante")).append("'>")
                       .append(rsD.getString("nombre")).append("</option>");
            }
            rsD.close(); psD.close();

            StringBuilder matHTML = new StringBuilder("<option value=''>-- Seleccione Artículo --</option>");
            matHTML.append("<optgroup label='REPUESTOS'>");
            PreparedStatement psR = conexion.prepareStatement("SELECT id_repuesto, nombre, stock FROM public.catalogo_repuestos ORDER BY nombre");
            ResultSet rsR = psR.executeQuery();
            while (rsR.next()) {
                matHTML.append("<option value='R-").append(rsR.getInt("id_repuesto")).append("'>")
                       .append(rsR.getString("nombre")).append(" (Stock actual: ").append(com.mycompany.pro.util.NumUtil.entero(rsR.getDouble("stock"))).append(")</option>");
            }
            rsR.close(); psR.close();
            matHTML.append("</optgroup><optgroup label='INSUMOS'>");
            PreparedStatement psI = conexion.prepareStatement("SELECT id_insumo, nombre, stock FROM public.catalogo_insumos ORDER BY nombre");
            ResultSet rsI = psI.executeQuery();
            while (rsI.next()) {
                matHTML.append("<option value='I-").append(rsI.getInt("id_insumo")).append("'>")
                       .append(rsI.getString("nombre")).append(" (Stock actual: ").append(com.mycompany.pro.util.NumUtil.entero(rsI.getDouble("stock"))).append(")</option>");
            }
            rsI.close(); psI.close();
            matHTML.append("</optgroup>");

            out.print(donHTML.toString() + "|||" + matHTML.toString());
            return;
        }

        // 2. Historial de donaciones (filas <tr>)
        if ("listarDonaciones".equals(tipo)) {
            String sql = "SELECT d.id_donacion, d.nro_comprobante, d.fecha_donacion, n.nombre, d.estado, "
                    + "(SELECT COUNT(*) FROM public.donaciones_detalle x WHERE x.id_donacion = d.id_donacion) AS articulos, "
                    + "(SELECT COALESCE(SUM(x.cantidad), 0) FROM public.donaciones_detalle x WHERE x.id_donacion = d.id_donacion) AS unidades "
                    + "FROM public.donaciones d JOIN public.donantes n ON d.id_donante = n.id_donante "
                    + "ORDER BY d.fecha_donacion DESC, d.id_donacion DESC LIMIT 50";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
            int cont = 0;
            boolean esAdminLista = Boolean.TRUE.equals(session.getAttribute("esAdmin"));
            while (rs.next()) {
                cont++;
                boolean anulada = "Anulada".equals(rs.getString("estado"));
%>
                <tr class="<%= anulada ? "text-muted" : "" %>">
                    <td><%= rs.getInt("id_donacion") %></td>
                    <td><%= rs.getString("nro_comprobante") %></td>
                    <td><%= rs.getString("nombre") %></td>
                    <td><%= _f(rs.getDate("fecha_donacion")) %></td>
                    <td class="text-center"><%= rs.getInt("articulos") %></td>
                    <td class="text-right"><%= rs.getBigDecimal("unidades").stripTrailingZeros().toPlainString() %></td>
                    <td class="text-center"><span class="badge <%= anulada ? "badge-danger" : "badge-success" %>"><%= rs.getString("estado") %></span></td>
                    <td class="text-center">
                        <button class="btn btn-secondary btn-sm" title="Imprimir comprobante" onclick="imprimirDonacion(<%= rs.getInt("id_donacion") %>)">
                            <i class="fas fa-print"></i>
                        </button>
<%                      if (esAdminLista && !anulada) { %>
                        <button class="btn btn-outline-danger btn-sm" title="Anular donación (solo Administrador)" onclick="anularDonacion(<%= rs.getInt("id_donacion") %>, '<%= rs.getString("nro_comprobante") %>')">
                            <i class="fas fa-ban"></i>
                        </button>
<%                      } %>
                    </td>
                </tr>
<%
            }
            rs.close(); ps.close();
            if (cont == 0) {
                out.print("<tr><td colspan='8' class='text-center text-muted py-3'>Todavía no hay donaciones registradas.</td></tr>");
            }
            return;
        }

        // 2-bis. Anular donación (SOLO Administrador). Cabecera + detalle en UNA transacción:
        //  - revierte el stock que el trigger había sumado por cada línea del detalle
        //  - deja la donación en estado 'Anulada' con motivo, fecha y usuario que anula
        //  - si parte de lo donado ya se usó (stock actual < cantidad donada) se rechaza y se hace rollback
        // Desde la fase 2 todo ingreso se registra en Recepción de equipos e insumos
        // (con confirmación del Administrador y kardex). Este módulo queda solo como
        // historial de las donaciones anteriores: ya no registra ni anula.
        if ("registrarDonacion".equals(tipo) || "anularDonacion".equals(tipo)) {
            out.print("error: las donaciones ahora se registran en Recepción de equipos e insumos");
            return;
        }
        if ("anularDonacion".equals(tipo)) {
            Integer idUsuarioAnula = (Integer) session.getAttribute("idUsuario");
            if (idUsuarioAnula == null || !Boolean.TRUE.equals(session.getAttribute("esAdmin"))) {
                out.print("error: solo el administrador puede anular donaciones");
                return;
            }
            Integer idDonAnula = tryParseInt(request.getParameter("idDonacion"));
            String motivoAnula = request.getParameter("motivo");
            if (idDonAnula == null || motivoAnula == null || motivoAnula.trim().length() < 5) {
                out.print("error: indique la donación y un motivo de al menos 5 caracteres");
                return;
            }
            try {
                conexion.setAutoCommit(false);

                PreparedStatement psEst = conexion.prepareStatement(
                    "SELECT estado FROM public.donaciones WHERE id_donacion = ? FOR UPDATE");
                psEst.setInt(1, idDonAnula);
                ResultSet rsEst = psEst.executeQuery();
                String estadoActual = rsEst.next() ? rsEst.getString(1) : null;
                rsEst.close(); psEst.close();
                if (!"Registrada".equals(estadoActual)) {
                    throw new SQLException("La donación no existe o ya está anulada.");
                }

                PreparedStatement psLin = conexion.prepareStatement(
                    "SELECT id_repuesto, id_insumo, cantidad FROM public.donaciones_detalle WHERE id_donacion = ?");
                psLin.setInt(1, idDonAnula);
                ResultSet rsLin = psLin.executeQuery();
                while (rsLin.next()) {
                    boolean esRepuesto = rsLin.getObject("id_repuesto") != null;
                    int idItem = esRepuesto ? rsLin.getInt("id_repuesto") : rsLin.getInt("id_insumo");
                    BigDecimal cantDon = rsLin.getBigDecimal("cantidad");
                    String tablaItem = esRepuesto ? "public.catalogo_repuestos" : "public.catalogo_insumos";
                    String colItem = esRepuesto ? "id_repuesto" : "id_insumo";

                    PreparedStatement psSt = conexion.prepareStatement(
                        "SELECT stock FROM " + tablaItem + " WHERE " + colItem + " = ? FOR UPDATE");
                    psSt.setInt(1, idItem);
                    ResultSet rsSt = psSt.executeQuery();
                    BigDecimal stockActual = rsSt.next() ? rsSt.getBigDecimal(1) : null;
                    rsSt.close(); psSt.close();
                    if (stockActual == null || stockActual.compareTo(cantDon) < 0) {
                        throw new SQLException("No se puede anular: parte de lo donado ya fue utilizado "
                                + "(stock actual " + (stockActual == null ? "0" : stockActual.stripTrailingZeros().toPlainString())
                                + ", donado " + cantDon.stripTrailingZeros().toPlainString() + ").");
                    }
                    PreparedStatement psRev = conexion.prepareStatement(
                        "UPDATE " + tablaItem + " SET stock = stock - ? WHERE " + colItem + " = ?");
                    psRev.setBigDecimal(1, cantDon);
                    psRev.setInt(2, idItem);
                    psRev.executeUpdate();
                    psRev.close();
                }
                rsLin.close(); psLin.close();

                PreparedStatement psAn = conexion.prepareStatement(
                    "UPDATE public.donaciones SET estado = 'Anulada', motivo_anulacion = ?, "
                    + "fecha_anulacion = CURRENT_TIMESTAMP, id_usuario_anula = ? WHERE id_donacion = ?");
                psAn.setString(1, motivoAnula.trim());
                psAn.setInt(2, idUsuarioAnula);
                psAn.setInt(3, idDonAnula);
                psAn.executeUpdate();
                psAn.close();

                conexion.commit();
                out.print("success");
            } catch (Exception exAn) {
                conexion.rollback();
                out.print("error: " + exAn.getMessage());
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

        // 3. Registrar donacion (cabecera + detalle -> el trigger suma stock)
        if ("registrarDonacion".equals(tipo)) {
            Integer idDonante = tryParseInt(request.getParameter("idDonante"));
            String nroComprobante = request.getParameter("nroComprobante");   // opcional: si va vacio se genera DON-000001
            String fechaDonacion = request.getParameter("fechaDonacion");
            Integer detCount = tryParseInt(request.getParameter("det_count"));
            Integer idUsuario = (Integer) session.getAttribute("idUsuario");

            if (idDonante == null || fechaDonacion == null || fechaDonacion.trim().isEmpty()
                    || detCount == null || detCount == 0) {
                out.print("error: complete donante, fecha y al menos un artículo");
                return;
            }
            if (idUsuario == null) {
                out.print("error: sesión no válida, vuelva a iniciar sesión");
                return;
            }

            try {
                conexion.setAutoCommit(false);

                PreparedStatement psCab = conexion.prepareStatement(
                    "INSERT INTO public.donaciones (id_donante, nro_comprobante, fecha_donacion, id_usuario_registro) "
                    + "VALUES (?, ?, ?, ?) RETURNING id_donacion, nro_comprobante");
                psCab.setInt(1, idDonante);
                if (nroComprobante == null || nroComprobante.trim().isEmpty()) {
                    psCab.setNull(2, Types.VARCHAR);
                } else {
                    psCab.setString(2, nroComprobante.trim());
                }
                psCab.setDate(3, java.sql.Date.valueOf(fechaDonacion));
                psCab.setInt(4, idUsuario);
                ResultSet rsCab = psCab.executeQuery();
                rsCab.next();
                int idDonacion = rsCab.getInt("id_donacion");
                String nroGenerado = rsCab.getString("nro_comprobante");
                rsCab.close(); psCab.close();

                for (int i = 0; i < detCount; i++) {
                    String rawTipo = request.getParameter("det_tipo_" + i);
                    int itemId = Integer.parseInt(request.getParameter("det_id_" + i));
                    BigDecimal cantidad = new BigDecimal(request.getParameter("det_cantidad_" + i));
                    if (cantidad.signum() <= 0) {
                        throw new SQLException("La cantidad debe ser mayor a cero");
                    }
                    PreparedStatement psDet = conexion.prepareStatement(
                        "INSERT INTO public.donaciones_detalle (id_donacion, id_repuesto, id_insumo, cantidad) VALUES (?, ?, ?, ?)");
                    psDet.setInt(1, idDonacion);
                    if ("R".equals(rawTipo)) {
                        psDet.setInt(2, itemId);
                        psDet.setNull(3, Types.INTEGER);
                    } else {
                        psDet.setNull(2, Types.INTEGER);
                        psDet.setInt(3, itemId);
                    }
                    psDet.setBigDecimal(4, cantidad);
                    psDet.executeUpdate();
                    psDet.close();
                }

                conexion.commit();
                out.print("success|" + nroGenerado + "|" + idDonacion);

            } catch (Exception ex) {
                conexion.rollback();
                out.print("Error: " + ex.getMessage());
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

        // 4-bis. Comprobante formal en PDF (JasperReports, con membrete)
        if ("comprobantePdf".equals(tipo)) {
            Integer idDonPdf = tryParseInt(request.getParameter("idDonacion"));
            if (idDonPdf == null) {
                response.setContentType("text/plain;charset=UTF-8");
                out.print("error: ID inválido");
                return;
            }
            java.util.List<Integer> idsPdf = new java.util.ArrayList<Integer>();
            idsPdf.add(idDonPdf);
            byte[] bytesPdf = com.mycompany.pro.util.ComprobanteUtil.generar(conexion, application.getRealPath("reportes"),
                    "comprobanteDonacion", new String[]{"comprobanteDonacionDetalle"},
                    "ID_DONACION", idsPdf, (Integer) session.getAttribute("idUsuario"));
            response.setContentType("application/pdf");
            response.setContentLength(bytesPdf.length);
            response.setHeader("Content-Disposition", "inline; filename=comprobante_donacion_" + idDonPdf + ".pdf");
            javax.servlet.ServletOutputStream salidaPdf = response.getOutputStream();
            salidaPdf.write(bytesPdf, 0, bytesPdf.length);
            salidaPdf.flush();
            salidaPdf.close();
            return;
        }

        // 4. Datos del comprobante (JSON, sin precios)
        if ("obtenerComprobante".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            Integer idDonacion = tryParseInt(request.getParameter("idDonacion"));
            JSONObject json = new JSONObject();
            if (idDonacion == null) {
                json.put("ok", false).put("error", "ID inválido");
                out.print(json.toString());
                return;
            }

            PreparedStatement psCab = conexion.prepareStatement(
                "SELECT d.id_donacion, d.nro_comprobante, d.fecha_donacion, n.nombre, n.documento, n.telefono, n.email, "
                + "per.nombre AS usu_nombre, per.apellido AS usu_apellido "
                + "FROM public.donaciones d JOIN public.donantes n ON d.id_donante = n.id_donante "
                + "LEFT JOIN public.usuarios u ON d.id_usuario_registro = u.id_usuario "
                + "LEFT JOIN public.personas per ON u.id_persona = per.id_persona WHERE d.id_donacion = ?");
            psCab.setInt(1, idDonacion);
            ResultSet rsCab = psCab.executeQuery();
            if (!rsCab.next()) {
                json.put("ok", false).put("error", "La donación no existe");
                out.print(json.toString());
                return;
            }
            json.put("ok", true);
            json.put("idDonacion", idDonacion);
            json.put("nroComprobante", rsCab.getString("nro_comprobante"));
            json.put("fecha", _f(rsCab.getDate("fecha_donacion")));
            json.put("donante", rsCab.getString("nombre"));
            json.put("documento", rsCab.getString("documento") != null ? rsCab.getString("documento") : "-");
            json.put("telefono", rsCab.getString("telefono") != null ? rsCab.getString("telefono") : "-");
            json.put("email", rsCab.getString("email") != null ? rsCab.getString("email") : "-");
            json.put("usuario", rsCab.getString("usu_apellido") != null
                    ? rsCab.getString("usu_apellido") + ", " + rsCab.getString("usu_nombre") : "Usuario no disponible");
            rsCab.close(); psCab.close();

            PreparedStatement psDet = conexion.prepareStatement(
                "SELECT d.cantidad, COALESCE(r.nombre, i.nombre) AS descripcion, "
                + "CASE WHEN d.id_repuesto IS NOT NULL THEN 'Repuesto' ELSE 'Insumo' END AS categoria "
                + "FROM public.donaciones_detalle d "
                + "LEFT JOIN public.catalogo_repuestos r ON d.id_repuesto = r.id_repuesto "
                + "LEFT JOIN public.catalogo_insumos i ON d.id_insumo = i.id_insumo "
                + "WHERE d.id_donacion = ? ORDER BY d.id_detalle");
            psDet.setInt(1, idDonacion);
            ResultSet rsDet = psDet.executeQuery();
            JSONArray items = new JSONArray();
            while (rsDet.next()) {
                JSONObject item = new JSONObject();
                item.put("categoria", rsDet.getString("categoria"));
                item.put("descripcion", rsDet.getString("descripcion"));
                item.put("cantidad", com.mycompany.pro.util.NumUtil.entero(rsDet.getBigDecimal("cantidad")));
                items.put(item);
            }
            rsDet.close(); psDet.close();
            json.put("items", items);
            out.print(json.toString());
            return;
        }

    } catch (Exception e) {
        out.print("Error crítico en el controlador: " + e.getMessage());
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
<%!
    private Integer tryParseInt(String value) {
        if (value == null || value.trim().isEmpty()) return null;
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
%>
