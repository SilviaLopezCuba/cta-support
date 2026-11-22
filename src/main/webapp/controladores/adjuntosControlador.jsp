<%@page contentType="text/plain;charset=UTF-8" pageEncoding="UTF-8" trimDirectiveWhitespaces="true"%>
<%@page import="java.sql.*"%>
<%@page import="org.json.JSONObject"%>
<%@page import="org.json.JSONArray"%>
<%@include file="../config/conexion.jsp"%>
<%!
    // Archivos adjuntos de los tickets (tabla ticket_adjuntos, contenido guardado en la base).
    //   tipo=subir   (POST, cuerpo = bytes del archivo; idTicket, nombre y etapa van en la URL)
    //   tipo=listar  (GET idTicket)      -> JSON con los adjuntos del ticket
    //   tipo=ver     (GET id_adjunto)    -> muestra o descarga el archivo
    // Pueden ver y subir: el administrador, quien pidió el ticket y el técnico asignado.

    static final int MAX_BYTES = 5 * 1024 * 1024;   // 5 MB por archivo (las fotos llegan comprimidas)
    static final int MAX_POR_TICKET = 8;

    /** Tipo real del archivo según sus primeros bytes (no se confía en la extensión). */
    static String tipoReal(byte[] b) {
        if (b.length > 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF) return "image/jpeg";
        if (b.length > 8 && (b[0] & 0xFF) == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') return "image/png";
        if (b.length > 12 && b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F' && b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P') return "image/webp";
        if (b.length > 5 && b[0] == '%' && b[1] == 'P' && b[2] == 'D' && b[3] == 'F') return "application/pdf";
        return null;
    }

    static String extension(String tipo) {
        switch (tipo) {
            case "image/jpeg": return ".jpg";
            case "image/png": return ".png";
            case "image/webp": return ".webp";
            default: return ".pdf";
        }
    }

    /** Nombre seguro: sin rutas ni caracteres raros, máximo 100 caracteres, con la extensión real. */
    static String nombreSeguro(String nombre, String tipo) {
        if (nombre == null) nombre = "";
        nombre = nombre.replace('\\', '/');
        nombre = nombre.substring(nombre.lastIndexOf('/') + 1);
        int punto = nombre.lastIndexOf('.');
        String base = punto > 0 ? nombre.substring(0, punto) : nombre;
        base = base.replaceAll("[^\\p{L}\\p{N} ._()-]", "_").trim();
        if (base.isEmpty()) base = "adjunto";
        if (base.length() > 90) base = base.substring(0, 90);
        return base + extension(tipo);
    }

    /** null si puede acceder; si no, el motivo. */
    static String permiso(Connection cn, int idTicket, Integer idUsuario, Integer idTecnico, boolean esAdmin, boolean paraSubir) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement(
                "SELECT id_usuario_solicita, id_tecnico_asignado, estado FROM public.ticket WHERE id_ticket = ?")) {
            ps.setInt(1, idTicket);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return "el ticket no existe";
                if (esAdmin) return null;
                boolean esSolicitante = idUsuario != null && rs.getInt(1) == idUsuario;
                boolean esTecnico = idTecnico != null && rs.getObject(2) != null && rs.getInt(2) == idTecnico;
                String estado = rs.getString(3);
                if (esTecnico) return null;
                if (esSolicitante) {
                    if (paraSubir && ("Resuelto".equals(estado) || "Cerrado".equals(estado))) return "el ticket ya está finalizado";
                    return null;
                }
                return "no tiene acceso a este ticket";
            }
        }
    }
%>
<%
    String tipo = request.getParameter("tipo");
    Integer idUsuario = (Integer) session.getAttribute("idUsuario");
    Integer idTecnico = (Integer) session.getAttribute("idTecnico");
    boolean esAdmin = Boolean.TRUE.equals(session.getAttribute("esAdmin"));
    try {
        if (idUsuario == null) {
            response.setStatus(401);
            out.print("error: sesión no válida, inicie sesión nuevamente");
            return;
        }

        // ---------------------------------------------------------------- subir
        if ("subir".equals(tipo)) {
            if (!"POST".equalsIgnoreCase(request.getMethod())) { response.setStatus(405); out.print("error: método no permitido"); return; }
            int idTicket;
            try { idTicket = Integer.parseInt(request.getParameter("idTicket")); }
            catch (Exception e) { out.print("error: ticket inválido"); return; }
            String etapa = "cierre".equals(request.getParameter("etapa")) ? "cierre" : "solicitud";

            String motivo = permiso(conexion, idTicket, idUsuario, idTecnico, esAdmin, true);
            if (motivo != null) { response.setStatus(403); out.print("error: " + motivo); return; }

            if (request.getContentLength() > MAX_BYTES) { out.print("error: el archivo supera los 5 MB"); return; }
            java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream();
            try (java.io.InputStream in = request.getInputStream()) {
                byte[] trozo = new byte[16384];
                int n;
                while ((n = in.read(trozo)) != -1) {
                    buf.write(trozo, 0, n);
                    if (buf.size() > MAX_BYTES) { out.print("error: el archivo supera los 5 MB"); return; }
                }
            }
            byte[] datos = buf.toByteArray();
            if (datos.length == 0) { out.print("error: el archivo está vacío"); return; }
            String tipoArchivo = tipoReal(datos);
            if (tipoArchivo == null) { out.print("error: solo se aceptan imágenes (JPG, PNG, WEBP) o PDF"); return; }

            try (PreparedStatement ps = conexion.prepareStatement("SELECT COUNT(*) FROM public.ticket_adjuntos WHERE id_ticket = ?")) {
                ps.setInt(1, idTicket);
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    if (rs.getInt(1) >= MAX_POR_TICKET) { out.print("error: el ticket ya tiene " + MAX_POR_TICKET + " archivos adjuntos"); return; }
                }
            }

            String nombre = nombreSeguro(request.getParameter("nombre"), tipoArchivo);
            conexion.setAutoCommit(false);
            try {
                int idAdjunto;
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.ticket_adjuntos (id_ticket, nombre_archivo, ruta_archivo, contenido) VALUES (?, ?, ?, ?) RETURNING id_adjunto")) {
                    ps.setInt(1, idTicket);
                    ps.setString(2, nombre);
                    // El archivo se guarda en la base (columna contenido); la ruta queda como referencia.
                    ps.setString(3, "bd/ticket_" + idTicket + "/" + nombre);
                    ps.setBytes(4, datos);
                    try (ResultSet rs = ps.executeQuery()) { rs.next(); idAdjunto = rs.getInt(1); }
                }
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.ticket_detalle (id_ticket, id_usuario, accion, descripcion) VALUES (?, ?, 'Archivo adjunto', ?)")) {
                    ps.setInt(1, idTicket);
                    ps.setInt(2, idUsuario);
                    ps.setString(3, nombre + ("cierre".equals(etapa) ? " (evidencia del trabajo)" : " (enviado con la solicitud)"));
                    ps.executeUpdate();
                }
                conexion.commit();
                out.print("success:" + idAdjunto);
            } catch (SQLException e) {
                conexion.rollback();
                e.printStackTrace();
                out.print("error: no se pudo guardar el archivo");
            } finally {
                conexion.setAutoCommit(true);
            }
            return;
        }

        // ---------------------------------------------------------------- listar
        if ("listar".equals(tipo)) {
            response.setContentType("application/json;charset=UTF-8");
            JSONObject res = new JSONObject();
            int idTicket;
            try { idTicket = Integer.parseInt(request.getParameter("idTicket")); }
            catch (Exception e) { res.put("ok", false).put("error", "ticket inválido"); out.print(res); return; }
            String motivo = permiso(conexion, idTicket, idUsuario, idTecnico, esAdmin, false);
            if (motivo != null) { res.put("ok", false).put("error", motivo); out.print(res); return; }
            JSONArray lista = new JSONArray();
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT id_adjunto, nombre_archivo, fecha_subida, octet_length(contenido) FROM public.ticket_adjuntos WHERE id_ticket = ? ORDER BY id_adjunto")) {
                ps.setInt(1, idTicket);
                try (ResultSet rs = ps.executeQuery()) {
                    java.text.SimpleDateFormat f = new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm");
                    while (rs.next()) {
                        String n = rs.getString(2);
                        lista.put(new JSONObject()
                                .put("id", rs.getInt(1))
                                .put("nombre", n)
                                .put("fecha", rs.getTimestamp(3) == null ? "" : f.format(rs.getTimestamp(3)))
                                .put("kb", Math.max(1, rs.getLong(4) / 1024))
                                .put("imagen", !n.toLowerCase().endsWith(".pdf")));
                    }
                }
            }
            res.put("ok", true).put("adjuntos", lista);
            out.print(res);
            return;
        }

        // ---------------------------------------------------------------- ver
        if ("ver".equals(tipo)) {
            int idAdjunto;
            try { idAdjunto = Integer.parseInt(request.getParameter("id_adjunto")); }
            catch (Exception e) { response.sendError(400); return; }
            byte[] datos = null; String nombre = null; int idTicket = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT id_ticket, nombre_archivo, contenido FROM public.ticket_adjuntos WHERE id_adjunto = ?")) {
                ps.setInt(1, idAdjunto);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) { idTicket = rs.getInt(1); nombre = rs.getString(2); datos = rs.getBytes(3); }
                }
            }
            if (datos == null) { response.sendError(404); return; }
            if (permiso(conexion, idTicket, idUsuario, idTecnico, esAdmin, false) != null) { response.sendError(403); return; }
            String tipoArchivo = tipoReal(datos);
            if (tipoArchivo == null) tipoArchivo = "application/octet-stream";
            boolean descargar = "1".equals(request.getParameter("descargar"));
            String nombreUrl = java.net.URLEncoder.encode(nombre, "UTF-8").replace("+", "%20");
            out.clear();
            out = pageContext.pushBody();   // evita que el JSP escriba texto después del archivo
            response.setContentType(tipoArchivo);
            response.setContentLength(datos.length);
            response.setHeader("Content-Disposition", (descargar ? "attachment" : "inline") + "; filename*=UTF-8''" + nombreUrl);
            response.setHeader("X-Content-Type-Options", "nosniff");
            response.setHeader("Cache-Control", "private, max-age=3600");
            javax.servlet.ServletOutputStream salida = response.getOutputStream();
            salida.write(datos);
            salida.flush();
            return;
        }

        out.print("error: acción no reconocida");
    } catch (Exception e) {
        e.printStackTrace();
        if (!response.isCommitted()) out.print("error: no se pudo completar la operación");
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception ex) {} }
    }
%>
