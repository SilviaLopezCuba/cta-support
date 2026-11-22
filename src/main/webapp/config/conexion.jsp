<%@page import="java.sql.*"%>
<%@page import="javax.naming.*"%>
<%@page import="javax.sql.DataSource"%>
<%
    // Conexión obtenida desde el POOL de Tomcat (ver META-INF/context.xml).
    // "conexion" sigue llamándose igual para no romper ningún archivo
    // existente, pero ya NO es una conexión física nueva por request:
    // es un préstamo del pool.
    //
    // IMPORTANTE: cada JSP que use este include DEBE llamar a
    // conexion.close() al terminar (idealmente en un finally), aunque haya
    // ocurrido un error. Con el pool, close() no cierra la conexión real:
    // solo la devuelve para que otro request la reutilice. Si no se llama
    // a close(), el pool se agota igual que antes (aunque más lento, y con
    // "removeAbandonedOnBorrow" como red de seguridad configurada en
    // context.xml para autorrecuperarse a los 60s).
    Connection conexion = null;
    try {
        Context initContext = new InitialContext();
        Context envContext = (Context) initContext.lookup("java:/comp/env");
        DataSource ds = (DataSource) envContext.lookup("jdbc/ProyectofinalDB");
        conexion = ds.getConnection();
        // Informa a la base qué usuario está trabajando, para que la auditoría
        // y el historial de ubicación de equipos (triggers) registren quién hizo
        // cada cambio. Como la conexión es del pool, se reinicia en cada request.
        try (PreparedStatement psCtxUsuario = conexion.prepareStatement("SELECT set_config('cta.id_usuario', ?, false)")) {
            javax.servlet.http.HttpSession sesCtxUsuario = request.getSession(false);
            Object idCtxUsuario = sesCtxUsuario != null ? sesCtxUsuario.getAttribute("idUsuario") : null;
            psCtxUsuario.setString(1, idCtxUsuario != null ? idCtxUsuario.toString() : "");
            psCtxUsuario.execute();
        } catch (Exception exCtxUsuario) {
            java.util.logging.Logger.getLogger("pro").log(java.util.logging.Level.WARNING, "No se pudo informar el usuario a la base", exCtxUsuario);
        }
    } catch (Exception e) {
        mensajeError(e);
        out.print("Error: no se pudo conectar con la base de datos");
    }
%>
<%!
    /**
     * Mensaje seguro para mostrar al usuario: el detalle tecnico (SQL, tablas,
     * rutas) se guarda en el log del servidor y NO se envia al navegador.
     */
    static String mensajeError(Exception e) {
        // Mensajes de negocio lanzados a proposito por el codigo
        // (new SQLException("No se puede anular...") / new Exception("...")): se muestran tal cual.
        if (e.getMessage() != null && (e.getClass() == Exception.class
                || (e.getClass() == SQLException.class && ((SQLException) e).getSQLState() == null))) {
            return e.getMessage();
        }
        // Reglas de negocio de la base (RAISE EXCEPTION en los triggers, SQLState P0001):
        // el mensaje fue escrito para el usuario, se muestra solo la primera línea.
        if (e instanceof SQLException && "P0001".equals(((SQLException) e).getSQLState()) && e.getMessage() != null) {
            String msgNegocio = e.getMessage().split("\n")[0].replaceFirst("^(ERROR|ERREUR|ERRO):\\s*", "");
            return msgNegocio;
        }
        java.util.logging.Logger.getLogger("pro").log(java.util.logging.Level.SEVERE, "Error en el sistema", e);
        if (e instanceof SQLException) {
            String estado = ((SQLException) e).getSQLState();
            if (estado != null && estado.startsWith("23")) {
                String msg = e.getMessage() == null ? "" : e.getMessage();
                if ("23505".equals(estado)) {   // duplicado (restriccion UNIQUE)
                    if (msg.contains("equipos_codigo_patrimonial_key")) return "ya existe un equipo con ese codigo patrimonial";
                    if (msg.contains("ux_equipos_nro_serie")) return "ya existe un equipo con ese numero de serie";
                    if (msg.contains("ux_salas_un_deposito")) return "solo puede existir un Deposito";
                    if (msg.contains("donantes_documento_key")) return "ya existe un donante con ese documento";
                    if (msg.contains("personas_documento_key")) return "ya existe una persona con ese documento";
                    if (msg.contains("tecnicos_id_usuario_key")) return "ese usuario ya esta registrado como tecnico";
                    if (msg.contains("ticket_numero_ticket_key")) return "ya existe un ticket con ese numero";
                    return "ya existe un registro con ese dato (valor duplicado)";
                }
                if ("23503".equals(estado)) {   // clave foranea
                    return "el registro esta relacionado con otros datos (tickets, mantenimientos, donaciones, etc.) y no se puede eliminar o modificar asi";
                }
                if ("23502".equals(estado)) {   // NOT NULL
                    return "falta completar un dato obligatorio";
                }
                if ("23514".equals(estado)) {   // regla CHECK: se traduce a un mensaje entendible
                    if (msg.contains("ck_sm_entrega_otro")) return "No podés entregarte material a vos mismo: lo tiene que entregar otro usuario.";
                    if (msg.contains("ck_dv_recibe_otro")) return "No podés recibir tu propia devolución: la tiene que recibir otro usuario.";
                    if (msg.contains("stock")) return "No hay stock suficiente para esta operación: el stock no puede quedar negativo.";
                    if (msg.contains("ck_smd_entregada")) return "La cantidad a entregar no puede ser mayor a lo pedido.";
                    if (msg.contains("cantidad")) return "Las cantidades deben ser mayores a cero.";
                    if (msg.contains("estado")) return "El estado indicado no es válido.";
                    java.util.regex.Matcher mr = java.util.regex.Pattern.compile("constraint \"([^\"]+)\"").matcher(msg);
                    return "Los datos no cumplen una regla de la base de datos" + (mr.find() ? " (" + mr.group(1) + ")" : "") + ".";
                }
                return "los datos no cumplen las reglas de la base de datos";
            }
        }
        return "ocurrio un error interno, intente nuevamente";
    }

    /**
     * Valida que "valor" no esté vacío y que no exista ya en tabla.columna
     * (sin distinguir mayúsculas ni espacios al inicio/fin). idExcluir es el
     * registro que se está modificando (null o vacío al guardar uno nuevo).
     * Lanza una Exception con "mensaje", que mensajeError() muestra tal cual.
     */
    static void exigirUnico(Connection c, String tabla, String columna, String columnaId,
                            String valor, String idExcluir, String mensaje) throws Exception {
        if (valor == null || valor.trim().isEmpty()) {
            throw new Exception("Complete el campo obligatorio.");
        }
        String sql = "SELECT 1 FROM " + tabla + " WHERE lower(trim(CAST(" + columna + " AS text))) = lower(trim(?))";
        boolean excluir = idExcluir != null && !idExcluir.trim().isEmpty();
        if (excluir) sql += " AND " + columnaId + " <> ?";
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setString(1, valor);
            if (excluir) ps.setInt(2, Integer.parseInt(idExcluir.trim()));
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) throw new Exception(mensaje);
            }
        }
    }

    /** Escapa texto de la base de datos para imprimirlo como HTML (evita XSS y tablas rotas). null -> null. */
    static String h(String t) {
        if (t == null) return null;
        StringBuilder sb = new StringBuilder(t.length() + 16);
        for (int i = 0; i < t.length(); i++) {
            char c = t.charAt(i);
            switch (c) {
                case '&': sb.append("&amp;"); break;
                case '<': sb.append("&lt;"); break;
                case '>': sb.append("&gt;"); break;
                case '"': sb.append("&quot;"); break;
                case '\'': sb.append("&#39;"); break;
                default: sb.append(c);
            }
        }
        return sb.toString();
    }

    /** Igual que h() pero para texto dentro de comillas simples de un onclick="f('...')". */
    static String hj(String t) {
        if (t == null) return null;
        return h(t.replace("\\", "\\\\").replace("'", "\\'").replace("\r", " ").replace("\n", " "));
    }
%>
