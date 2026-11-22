package com.mycompany.pro.web.filter;

import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Restringe controladores administrativos según el ROL (por nombre,
 * no por id, porque los id_rol de esta base no son estables/predecibles).
 * Se apoya en session.getAttribute("nombreRol"), que login.jsp ya guarda.
 */
@WebFilter(urlPatterns = {"/controladores/*"})
public class RoleFilter implements Filter {

    private static final String ADMIN = "Administrador";
    private static final String TECNICO = "Técnico";
    private static final String MAESTRO = "Maestro";
    private static final String ALUMNO = "Alumno";
    private static final String ENCARGADO = "Encargado de depósito";

    private static final Map<String, Set<String>> PERMISOS = crearMapaPermisos();

    private static Map<String, Set<String>> crearMapaPermisos() {
        Map<String, Set<String>> m = new HashMap<>();

        m.put("ordenControlador.jsp", setOf(ADMIN, TECNICO, MAESTRO, ALUMNO));
        // Adjuntos: el controlador verifica además que el usuario sea el solicitante, el técnico asignado o un administrador.
        m.put("adjuntosControlador.jsp", setOf(ADMIN, TECNICO, MAESTRO, ALUMNO));
        // Tipos de falla: quienes piden asistencia cargan el combo; solo el Administrador modifica (lo controla el propio controlador).
        // El Encargado de depósito NO solicita asistencia correctiva.
        m.put("tiposFallaControlador.jsp", setOf(ADMIN, TECNICO, MAESTRO, ALUMNO));

        m.put("mantenimientoUnificadoControlador.jsp", setOf(ADMIN, TECNICO));
        m.put("ordenUnificadaControlador.jsp", setOf(ADMIN, TECNICO));
        m.put("insumosControlador.jsp", setOf(ADMIN, TECNICO));
        m.put("repuestosControlador.jsp", setOf(ADMIN, TECNICO));

        // Material para técnicos: el técnico pide material desde el ticket o el mantenimiento;
        // el Encargado entrega y recibe devoluciones (cada acción se valida en el controlador).
        m.put("materialesControlador.jsp", setOf(ADMIN, TECNICO, ENCARGADO));

        // Inventario (Administrador y Encargado de depósito)
        m.put("equiposControlador.jsp", setOf(ADMIN, TECNICO, ENCARGADO));
        m.put("controlStockControlador.jsp", setOf(ADMIN, TECNICO, ENCARGADO));
        m.put("inventarioControlador.jsp", setOf(ADMIN, ENCARGADO));
        m.put("kardexControlador.jsp", setOf(ADMIN, ENCARGADO));
        m.put("recepcionesControlador.jsp", setOf(ADMIN, ENCARGADO));
        m.put("tomaInventarioControlador.jsp", setOf(ADMIN, ENCARGADO));
        m.put("movimientosEquiposControlador.jsp", setOf(ADMIN, ENCARGADO));

        // Informes (PDF): mismos permisos que el proceso que reportan.
        m.put("informeSolicitudes.jsp", setOf(ADMIN, TECNICO));
        m.put("informeOrdenesCorrectivas.jsp", setOf(ADMIN, TECNICO));
        m.put("informeMantenimiento.jsp", setOf(ADMIN, TECNICO));
        // Informes de inventario: el técnico solo ve sus propios pedidos de material (lo restringe el controlador)
        m.put("informeMaterial.jsp", setOf(ADMIN, ENCARGADO, TECNICO));
        m.put("informeEntradas.jsp", setOf(ADMIN, ENCARGADO));
        m.put("informeExistencias.jsp", setOf(ADMIN, ENCARGADO));
        m.put("informeMovimientosStock.jsp", setOf(ADMIN, ENCARGADO));
        m.put("informeMovimientosEquipos.jsp", setOf(ADMIN, ENCARGADO));
        m.put("informeInventario.jsp", setOf(ADMIN, ENCARGADO));   // Pedidos de reposición

        m.put("tecnicosControlador.jsp", setOf(ADMIN));
        m.put("categoriasControlador.jsp", setOf(ADMIN));
        m.put("marcasControlador.jsp", setOf(ADMIN));
        m.put("salasControlador.jsp", setOf(ADMIN));
        m.put("especialidadesControlador.jsp", setOf(ADMIN));
        m.put("personasControlador.jsp", setOf(ADMIN));
        m.put("usuariosControlador.jsp", setOf(ADMIN));
        m.put("rolesControlador.jsp", setOf(ADMIN));
        m.put("unidadesMedidaControlador.jsp", setOf(ADMIN));

        return m;
    }

    private static Set<String> setOf(String... valores) {
        return new HashSet<>(Arrays.asList(valores));
    }

    private static final Set<String> DEFAULT_PERMITIDOS = setOf(ADMIN);

    @Override
    public void init(FilterConfig filterConfig) { }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse res = (HttpServletResponse) response;
        HttpSession session = req.getSession(false);

        String nombreRol = session != null ? (String) session.getAttribute("nombreRol") : null;

        String uri = req.getRequestURI();
        String recurso = uri.substring(uri.lastIndexOf('/') + 1);

        Set<String> permitidos = PERMISOS.getOrDefault(recurso, DEFAULT_PERMITIDOS);

        if (nombreRol == null || !permitidos.contains(nombreRol)) {
            res.sendError(HttpServletResponse.SC_FORBIDDEN, "No autorizado para este recurso");
            return;
        }

        chain.doFilter(request, response);
    }

    @Override
    public void destroy() { }
}