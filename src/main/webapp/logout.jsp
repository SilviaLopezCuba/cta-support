<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="javax.servlet.http.HttpSession"%>
<%
    HttpSession sesion = request.getSession(false);
    if (sesion != null) {
        sesion.invalidate(); // cerrar sesión
    }
    response.sendRedirect("login.jsp"); // volver al login
%>
