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

    try {
        // LISTAR
        if ("listar".equals(tipo)) {
            String sql = "SELECT * FROM public.marcas ORDER BY id_marca ASC";
            PreparedStatement ps = conexion.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
%>
                <tr>
                    <td><%= rs.getInt("id_marca") %></td>
                    <td><%= h(rs.getString("nombre_marca")) %></td>
                    <td class="text-center">
                        <button class="btn btn-warning btn-sm" data-toggle="modal" data-target="#modalMarca" 
                                onclick="campos('<%= rs.getInt("id_marca") %>', '<%= hj(rs.getString("nombre_marca")) %>'); completar('Modificar Marca', 'Modificar')">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-danger btn-sm" onclick="eliminar('<%= rs.getInt("id_marca") %>')">
                            <i class="fas fa-trash"></i>
                        </button>
                        <button class="btn btn-info btn-sm" onclick="window.open('../controladores/marcasControlador.jsp?tipo=ReporteIndividual&pk=<%= rs.getInt("id_marca") %>', '_blank')">
                            <i class="fas fa-file-pdf"></i>
                        </button>
                    </td>
                </tr>
<%
            }
        }

        // GUARDAR
        else if ("Guardar".equals(tipo)) {
            exigirUnico(conexion, "marcas", "nombre_marca", "id_marca", nombre, null, "Ya existe una marca con ese nombre.");
            PreparedStatement ps = conexion.prepareStatement("INSERT INTO marcas (nombre_marca) VALUES (?)");
            ps.setString(1, nombre);
            ps.executeUpdate();
            out.print("success");
        }

        // MODIFICAR
        else if ("Modificar".equals(tipo)) {
            exigirUnico(conexion, "marcas", "nombre_marca", "id_marca", nombre, pk, "Ya existe una marca con ese nombre.");
            PreparedStatement ps = conexion.prepareStatement("UPDATE marcas SET nombre_marca=? WHERE id_marca=?");
            ps.setString(1, nombre);
            ps.setInt(2, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }

        // BORRAR
        else if ("Borrar".equals(tipo)) {
            PreparedStatement ps = conexion.prepareStatement("DELETE FROM marcas WHERE id_marca = ?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }

        // REPORTE GENERAL (PDF)
        else if ("ReporteGeneral".equals(tipo)) {
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_marcas");

            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=reporte_marcas.pdf");

            JRPdfExporter exportador = new JRPdfExporter();
            exportador.setExporterInput(new SimpleExporterInput(jasperPrint));
            exportador.setExporterOutput(new SimpleOutputStreamExporterOutput(response.getOutputStream()));
            exportador.exportReport();
            response.getOutputStream().flush();
            out.clear();
            out = pageContext.pushBody();
        }

        // REPORTE INDIVIDUAL (PDF)
        else if ("ReporteIndividual".equals(tipo)) {
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_marca_individual");
            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_ID_MARCA", Integer.parseInt(pk));
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=ficha_marca_" + pk + ".pdf");

            JRPdfExporter exportador = new JRPdfExporter();
            exportador.setExporterInput(new SimpleExporterInput(jasperPrint));
            exportador.setExporterOutput(new SimpleOutputStreamExporterOutput(response.getOutputStream()));
            exportador.exportReport();
            response.getOutputStream().flush();
            out.clear();
            out = pageContext.pushBody();
        }

    } catch (Exception e) {
        out.print(mensajeError(e));
    } finally {
        if (conexion != null) { try { conexion.close(); } catch (Exception exClose) {} }
    }
%>