<%@page import="javax.servlet.http.HttpSession"%>
<%
HttpSession sesion = request.getSession(false);
if (sesion == null || sesion.getAttribute("logueado") == null) {
    response.sendRedirect("login.jsp");
}
response.setHeader("Cache-Control","no-cache, no-store, must-revalidate");
response.setHeader("Pragma","no-cache");
response.setDateHeader("Expires", 0);
%>

