package com.mycompany.pro.web.filter;

import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

import java.io.IOException;

/**
 * Bloquea el acceso a /controladores/*, /vistas/* y al dashboard
 * si no hay una sesión con "idUsuario" activa.
 * Reemplaza la dependencia de incluir seguridad.jsp manualmente
 * en cada archivo.
 */
@WebFilter(urlPatterns = {
        "/controladores/*",
        "/vistas/*",
        "/dashboard.jsp"
})
public class AuthFilter implements Filter {

    @Override
    public void init(FilterConfig filterConfig) { }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse res = (HttpServletResponse) response;

        HttpSession session = req.getSession(false);
        boolean logueado = session != null && session.getAttribute("idUsuario") != null;

        if (!logueado) {
            if (req.getRequestURI().contains("/controladores/")) {
                res.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Sesión requerida");
            } else {
                res.sendRedirect(req.getContextPath() + "/login.jsp");
            }
            return;
        }

        res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
        res.setHeader("Pragma", "no-cache");
        res.setDateHeader("Expires", 0);

        chain.doFilter(request, response);
    }

    @Override
    public void destroy() { }
}