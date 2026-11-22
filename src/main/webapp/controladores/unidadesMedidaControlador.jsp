<%@include file="../config/conexion.jsp"%>
<%@page import="java.sql.*"%>
<%@page import="net.sf.jasperreports.engine.JasperFillManager"%>
<%@page import="net.sf.jasperreports.engine.JasperPrint"%>
<%@page import="net.sf.jasperreports.engine.export.JRPdfExporter"%>
<%@page import="net.sf.jasperreports.export.SimpleExporterInput"%>
<%@page import="net.sf.jasperreports.export.SimpleOutputStreamExporterOutput"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page import="javax.servlet.http.HttpSession"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%!
    // Escapa el texto antes de mostrarlo en HTML (evita XSS)
    private String esc(String s) {
        if (s == null) {
            return "";
        }
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }

    // Indica si ya existe otra unidad con el mismo nombre (sin distinguir mayúsculas)
    private boolean existeNombre(Connection c, String nombre, int idExcluir) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT 1 FROM public.unidades_medida WHERE LOWER(nombre_unidad) = LOWER(?) AND id_unidad <> ?")) {
            ps.setString(1, nombre);
            ps.setInt(2, idExcluir);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        }
    }

    // Nombre y apellido de la persona dueña del usuario logueado (para el pie del reporte)
    private String obtenerNombreGenerador(HttpSession sesion, Connection c) {
        try {
            Object idObj = sesion.getAttribute("idUsuario");
            if (idObj == null) {
                return "-";
            }
            try (PreparedStatement ps = c.prepareStatement(
                    "SELECT p.nombre, p.apellido FROM public.usuarios u "
                    + "JOIN public.personas p ON u.id_persona = p.id_persona WHERE u.id_usuario = ?")) {
                ps.setInt(1, (Integer) idObj);
                try (ResultSet rs = ps.executeQuery()) {
                    return rs.next() ? rs.getString("nombre") + " " + rs.getString("apellido") : "-";
                }
            }
        } catch (Exception e) {
            return "-";
        }
    }

    // El rol ya está guardado en la sesión desde el login
    private String obtenerRolGenerador(HttpSession sesion) {
        Object rol = sesion.getAttribute("nombreRol");
        return rol != null ? rol.toString() : "";
    }
%>
<%
    request.setCharacterEncoding("UTF-8");
    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String nombre = request.getParameter("nombre");
    if (nombre != null) {
        nombre = nombre.trim();
    }

    try {
        if ("listar".equals(tipo)) {
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT id_unidad, nombre_unidad FROM public.unidades_medida ORDER BY id_unidad ASC");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
%>
                <tr>
                    <td><%= rs.getInt("id_unidad") %></td>
                    <td><%= esc(rs.getString("nombre_unidad")) %></td>
                    <td class="text-center">
                        <button class="btn btn-warning btn-sm btn-editar" data-toggle="modal" data-target="#modalUnidad"
                                data-id="<%= rs.getInt("id_unidad") %>" data-nombre="<%= esc(rs.getString("nombre_unidad")) %>"
                                aria-label="Modificar unidad">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-info btn-sm btn-pdf" data-id="<%= rs.getInt("id_unidad") %>"
                                aria-label="Ficha en PDF">
                            <i class="fas fa-file-pdf"></i>
                        </button>
                        <button class="btn btn-danger btn-sm btn-eliminar" data-id="<%= rs.getInt("id_unidad") %>"
                                aria-label="Eliminar unidad">
                            <i class="fas fa-trash"></i>
                        </button>
                    </td>
                </tr>
<%
                }
            }
        } else if ("Guardar".equals(tipo)) {
            if (nombre == null || nombre.isEmpty() || nombre.length() > 50) {
                out.print("error: el nombre es obligatorio y admite hasta 50 caracteres");
            } else if (existeNombre(conexion, nombre, 0)) {
                out.print("error: ya existe una unidad de medida con ese nombre");
            } else {
                try (PreparedStatement ps = conexion.prepareStatement(
                        "INSERT INTO public.unidades_medida (nombre_unidad) VALUES (?)")) {
                    ps.setString(1, nombre);
                    ps.executeUpdate();
                }
                out.print("success");
            }
        } else if ("Modificar".equals(tipo)) {
            int id = Integer.parseInt(pk);
            if (nombre == null || nombre.isEmpty() || nombre.length() > 50) {
                out.print("error: el nombre es obligatorio y admite hasta 50 caracteres");
            } else if (existeNombre(conexion, nombre, id)) {
                out.print("error: ya existe una unidad de medida con ese nombre");
            } else {
                try (PreparedStatement ps = conexion.prepareStatement(
                        "UPDATE public.unidades_medida SET nombre_unidad = ? WHERE id_unidad = ?")) {
                    ps.setString(1, nombre);
                    ps.setInt(2, id);
                    ps.executeUpdate();
                }
                out.print("success");
            }
        } else if ("Borrar".equals(tipo)) {
            try (PreparedStatement ps = conexion.prepareStatement(
                    "DELETE FROM public.unidades_medida WHERE id_unidad = ?")) {
                ps.setInt(1, Integer.parseInt(pk));
                ps.executeUpdate();
                out.print("success");
            } catch (SQLException ex) {
                // 23503 = la unidad está referenciada por algún insumo
                if ("23503".equals(ex.getSQLState())) {
                    out.print("error: la unidad está en uso por uno o más insumos");
                } else {
                    throw ex;
                }
            }
        } else if ("ReporteGeneral".equals(tipo) || "ReporteIndividual".equals(tipo)) {
            boolean individual = "ReporteIndividual".equals(tipo);
            net.sf.jasperreports.engine.JasperReport reporte = com.mycompany.pro.util.ReporteUtil.cargar(
                    application, individual ? "reporte_unidad_medida_individual" : "reporte_unidades_medida");

            Map<String, Object> parametros = new HashMap<String, Object>();
            if (individual) {
                parametros.put("P_ID_UNIDAD", Integer.parseInt(pk));
            }
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reporte, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename="
                    + (individual ? "ficha_unidad_" + Integer.parseInt(pk) : "reporte_unidades_medida") + ".pdf");

            JRPdfExporter exportador = new JRPdfExporter();
            exportador.setExporterInput(new SimpleExporterInput(jasperPrint));
            exportador.setExporterOutput(new SimpleOutputStreamExporterOutput(response.getOutputStream()));
            exportador.exportReport();
            response.getOutputStream().flush();
            out.clear();
            out = pageContext.pushBody();
        }
    } catch (Exception e) {
        application.log("unidadesMedidaControlador: " + e);
        out.print("error: no se pudo completar la operación");
    } finally {
        if (conexion != null) {
            try { conexion.close(); } catch (Exception exClose) { }
        }
    }
%>
