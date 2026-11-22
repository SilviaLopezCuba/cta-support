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
    String id_marca = request.getParameter("id_marca");
    String id_categoria = request.getParameter("id_categoria");
    String tecnica = request.getParameter("tecnica");
    String notas = request.getParameter("notas");
    String stock = request.getParameter("stock");
    String stockMinimo = request.getParameter("stockMinimo");

    try {
        // LISTAR con JOIN para obtener nombres reales
        if ("listar".equals(tipo)) {
            String sql = "SELECT r.*, m.nombre_marca, c.nombre_categoria " +
                         "FROM catalogo_repuestos r " +
                         "JOIN marcas m ON r.id_marca = m.id_marca " +
                         "JOIN categorias c ON r.id_categoria = c.id_categoria " +
                         "ORDER BY r.id_repuesto ASC";

            PreparedStatement ps = conexion.prepareStatement(sql);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                double stockActual = rs.getDouble("stock");
                double stockMin = rs.getDouble("stock_minimo");
                String badgeStock = stockActual <= stockMin ? "badge-danger" : "badge-success";
%>
                <tr>
                    <td><%= rs.getInt("id_repuesto") %></td>
                    <td><%= h(rs.getString("nombre")) %></td>
                    <td><span class="badge badge-info"><%= h(rs.getString("nombre_marca")) %></span></td>
                    <td><%= h(rs.getString("nombre_categoria")) %></td>
                    <td><small><%= h(rs.getString("especificacion_tecnica")) %></small></td>
                    <td><%= com.mycompany.pro.util.NumUtil.entero(stockMin) %></td>
                    <td>
                        <button class="btn btn-warning btn-sm" data-toggle="modal" data-target="#modalRepuesto" 
                                onclick="campos('<%= rs.getInt("id_repuesto") %>', '<%= hj(rs.getString("nombre")) %>', '<%= rs.getInt("id_marca") %>', '<%= rs.getInt("id_categoria") %>', '<%= hj(rs.getString("especificacion_tecnica")) %>', '<%= hj(rs.getString("compatibilidad_notas")) %>', '<%= com.mycompany.pro.util.NumUtil.entero(stockActual) %>', '<%= com.mycompany.pro.util.NumUtil.entero(stockMin) %>'); completar('Modificar Repuesto', 'Modificar')">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-danger btn-sm" onclick="eliminar('<%= rs.getInt("id_repuesto") %>')">
                            <i class="fas fa-trash"></i>
                        </button>
                        <button class="btn btn-info btn-sm" onclick="window.open('../controladores/repuestosControlador.jsp?tipo=ReporteIndividual&pk=<%= rs.getInt("id_repuesto") %>', '_blank')">
                            <i class="fas fa-file-pdf"></i>
                        </button>
                    </td>
                </tr>
<%
            }
        }

        // CARGAR COMBOS
        else if ("cargarMarcas".equals(tipo)) {
            ResultSet rs = conexion.prepareStatement("SELECT id_marca, nombre_marca FROM marcas ORDER BY nombre_marca").executeQuery();
            while(rs.next()){
                out.print("<option value='"+rs.getInt("id_marca")+"'>"+h(rs.getString("nombre_marca"))+"</option>");
            }
        }
        else if ("cargarCategorias".equals(tipo)) {
            ResultSet rs = conexion.prepareStatement("SELECT id_categoria, nombre_categoria FROM categorias ORDER BY nombre_categoria").executeQuery();
            while(rs.next()){
                out.print("<option value='"+rs.getInt("id_categoria")+"'>"+h(rs.getString("nombre_categoria"))+"</option>");
            }
        }

        // ACCIONES (GUARDAR, MODIFICAR, BORRAR)
        else if ("Guardar".equals(tipo)) {
            exigirUnico(conexion, "catalogo_repuestos", "nombre", "id_repuesto", nombre, null, "Ya existe un repuesto con ese nombre.");
            PreparedStatement ps = conexion.prepareStatement("INSERT INTO catalogo_repuestos (nombre, id_marca, id_categoria, especificacion_tecnica, compatibilidad_notas, stock, stock_minimo) VALUES (?, ?, ?, ?, ?, ?, ?)");
            ps.setString(1, nombre);
            ps.setInt(2, Integer.parseInt(id_marca));
            ps.setInt(3, Integer.parseInt(id_categoria));
            ps.setString(4, tecnica);
            ps.setString(5, notas);
            // El stock arranca en 0: solo cambia por Recepción, Entregas o Ajustes (queda en el kardex)
            ps.setDouble(6, 0);
            ps.setDouble(7, stockMinimo == null || stockMinimo.trim().isEmpty() ? 0 : Math.round(Double.parseDouble(stockMinimo)));
            ps.executeUpdate();
            out.print("success");
        }
        else if ("Modificar".equals(tipo)) {
            exigirUnico(conexion, "catalogo_repuestos", "nombre", "id_repuesto", nombre, pk, "Ya existe un repuesto con ese nombre.");
            PreparedStatement ps = conexion.prepareStatement("UPDATE catalogo_repuestos SET nombre=?, id_marca=?, id_categoria=?, especificacion_tecnica=?, compatibilidad_notas=?, stock_minimo=? WHERE id_repuesto=?");
            ps.setString(1, nombre);
            ps.setInt(2, Integer.parseInt(id_marca));
            ps.setInt(3, Integer.parseInt(id_categoria));
            ps.setString(4, tecnica);
            ps.setString(5, notas);
            // El stock no se edita desde acá (ver Kardex)
            ps.setDouble(6, stockMinimo == null || stockMinimo.trim().isEmpty() ? 0 : Math.round(Double.parseDouble(stockMinimo)));
            ps.setInt(7, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        else if ("Borrar".equals(tipo)) {
            // Un artículo con movimientos en el kardex no se elimina (se perdería la trazabilidad)
            try (PreparedStatement psMov = conexion.prepareStatement(
                    "SELECT 1 FROM public.movimientos_stock WHERE tipo_articulo = 'R' AND id_articulo = ? LIMIT 1")) {
                psMov.setInt(1, Integer.parseInt(pk));
                try (ResultSet rsMov = psMov.executeQuery()) {
                    if (rsMov.next()) throw new Exception("Este repuesto tiene movimientos de stock registrados y no se puede eliminar.");
                }
            }
            PreparedStatement ps = conexion.prepareStatement("DELETE FROM catalogo_repuestos WHERE id_repuesto = ?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        // REPORTE GENERAL (PDF)
        else if ("ReporteGeneral".equals(tipo)) {
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_repuestos");

            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=reporte_repuestos.pdf");

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
            net.sf.jasperreports.engine.JasperReport reportStream = com.mycompany.pro.util.ReporteUtil.cargar(application, "reporte_repuesto_individual");
            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("P_ID_REPUESTO", Integer.parseInt(pk));
            parametros.put("P_GENERADOR_NOMBRE", obtenerNombreGenerador(session, conexion));
            parametros.put("LOGO_PATH", application.getRealPath("reportes/logo_cta.jpg"));
            parametros.put("P_GENERADOR_ROL", obtenerRolGenerador(session));

            JasperPrint jasperPrint = JasperFillManager.fillReport(reportStream, parametros, conexion);

            response.reset();
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=ficha_repuesto_" + pk + ".pdf");

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
