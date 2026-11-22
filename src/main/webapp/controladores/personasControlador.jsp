<%@include file="../config/conexion.jsp"%>
<%@page import="java.sql.*"%>
<%@page import="net.sf.jasperreports.engine.JasperFillManager"%>
<%@page import="net.sf.jasperreports.engine.JasperPrint"%>
<%@page import="net.sf.jasperreports.engine.export.JRPdfExporter"%>
<%@page import="net.sf.jasperreports.export.SimpleExporterInput"%>
<%@page import="net.sf.jasperreports.export.SimpleOutputStreamExporterOutput"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page import="java.io.InputStream"%>
<%@page import="javax.servlet.http.HttpSession"%>
<%!
    // Busca nombre y apellido de la persona dueña del usuario logueado (sesión)
    private String obtenerNombreGenerador(HttpSession sesion, Connection conexion) {
        try {
            Object idObj = sesion.getAttribute("idUsuario");
            if (idObj == null) {
                return "-";
            }
            int idUsuario = (Integer) idObj;
            PreparedStatement psGen = conexion.prepareStatement(
                "SELECT p.nombre, p.apellido FROM public.usuarios u " +
                "JOIN public.personas p ON u.id_persona = p.id_persona " +
                "WHERE u.id_usuario = ?");
            psGen.setInt(1, idUsuario);
            ResultSet rsGen = psGen.executeQuery();
            String nombreCompleto = "-";
            if (rsGen.next()) {
                nombreCompleto = rsGen.getString("nombre") + " " + rsGen.getString("apellido");
            }
            rsGen.close();
            psGen.close();
            return nombreCompleto;
        } catch (Exception e) {
            return "-";
        }
    }

    // El rol ya viene guardado en la sesión desde el login, no hace falta ir a la base
    private String obtenerRolGenerador(HttpSession sesion) {
        Object rol = sesion.getAttribute("nombreRol");
        return rol != null ? rol.toString() : "";
    }
%>
<%
    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String nombre = request.getParameter("nombre");
    String apellido = request.getParameter("apellido");
    String documento = request.getParameter("documento");
    String correo = request.getParameter("correo");
    String telefono = request.getParameter("telefono");
    try {
        // LISTAR
        if ("listar".equals(tipo)) {
            String sql = "SELECT * FROM public.personas ORDER BY id_persona ASC";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
%>
                <tr>
                    <td><%= rs.getInt("id_persona") %></td>
                    <td><%= h(rs.getString("nombre")) %></td>
                    <td><%= h(rs.getString("apellido")) %></td>
                    <td><%= h(rs.getString("documento")) %></td>
                    <td><%= h(rs.getString("correo")) %></td>
                    <td><%= h(rs.getString("telefono")) %></td>
                    <td>
                        <button class="btn btn-warning btn-sm" data-toggle="modal" data-target="#modalPersona" 
                                onclick="campos('<%= rs.getInt("id_persona") %>', '<%= hj(rs.getString("nombre")) %>', '<%= hj(rs.getString("apellido")) %>', '<%= hj(rs.getString("documento")) %>', '<%= hj(rs.getString("correo")) %>', '<%= hj(rs.getString("telefono")) %>'); completar('Modificar Persona', 'Modificar')">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-danger btn-sm" onclick="eliminar('<%= rs.getInt("id_persona") %>')">
                            <i class="fas fa-trash"></i>
                        </button>
                        <button class="btn btn-info btn-sm" onclick="window.open('../controladores/personasControlador.jsp?tipo=ReporteIndividual&pk=<%= rs.getInt("id_persona") %>', '_blank')">
                            <i class="fas fa-file-pdf"></i>
                        </button>
                    </td>
                </tr>
<%
            }
        }
        // VALIDAR datos obligatorios antes de guardar o modificar
        else if (("Guardar".equals(tipo) || "Modificar".equals(tipo))
                && (nombre == null || nombre.trim().isEmpty() || documento == null || documento.trim().isEmpty())) {
            out.print("El nombre y el documento son obligatorios.");
        }
        // GUARDAR
        else if ("Guardar".equals(tipo)) {
            PreparedStatement ps = conexion.prepareStatement("INSERT INTO personas (nombre, apellido, documento, correo, telefono) VALUES (?, ?, ?, ?, ?)");
            ps.setString(1, nombre);
            ps.setString(2, apellido);
            ps.setString(3, documento);
            ps.setString(4, correo);
            ps.setString(5, telefono);
            ps.executeUpdate();
            out.print("success");
        }
        // MODIFICAR
        else if ("Modificar".equals(tipo)) {
            PreparedStatement ps = conexion.prepareStatement("UPDATE personas SET nombre=?, apellido=?, documento=?, correo=?, telefono=? WHERE id_persona=?");
            ps.setString(1, nombre);
            ps.setString(2, apellido);
            ps.setString(3, documento);
            ps.setString(4, correo);
            ps.setString(5, telefono);
            ps.setInt(6, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        // BORRAR
        else if ("Borrar".equals(tipo)) {
            PreparedStatement ps = conexion.prepareStatement("DELETE FROM personas WHERE id_persona = ?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        // REPORTE GENERAL (PDF)
        else if ("ReporteGeneral".equals(tipo)) {
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_personas");

            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=reporte_personas.pdf");

            JRPdfExporter exportador = new JRPdfExporter();
            exportador.setExporterInput(new SimpleExporterInput(jasperPrint));
            exportador.setExporterOutput(new SimpleOutputStreamExporterOutput(response.getOutputStream()));
            exportador.exportReport();
            response.getOutputStream().flush();
            out.clear();
            out = pageContext.pushBody();
        }
        else if ("ReporteIndividual".equals(tipo)) {
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_persona_individual");
            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_ID_PERSONA", Integer.parseInt(pk));
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=ficha_persona_" + pk + ".pdf");

            JRPdfExporter exportador = new JRPdfExporter();
            exportador.setExporterInput(new SimpleExporterInput(jasperPrint));
            exportador.setExporterOutput(new SimpleOutputStreamExporterOutput(response.getOutputStream()));
            exportador.exportReport();
            response.getOutputStream().flush();
            out.clear();
            out = pageContext.pushBody();
        }
    } catch (Exception e) {
        out.print("Error: " + mensajeError(e));
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>
