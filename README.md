# CTA Support

Sistema web de soporte técnico para aulas y equipos del CTA: solicitudes de asistencia, mesa de ayuda (tickets), mantenimiento preventivo y correctivo, inventario de equipos e insumos (recepciones, entregas, devoluciones, ajustes, pedidos de reposición) e informes en PDF.

Proyecto final de Silvia Andrea López Cuba.

## Tecnologías

- Java EE 8 (Servlet/JSP), Maven
- Apache Tomcat 8.5
- PostgreSQL
- AdminLTE 3 / Bootstrap 4, jQuery, SweetAlert2
- JasperReports para comprobantes e informes

## Roles

Administrador, Técnico, Encargado de depósito, Maestro y Alumno. Cada rol ve solo el menú y los datos que le corresponden.

## Cómo ejecutarlo

1. Crear la base de datos `Proyectofinal` en PostgreSQL y restaurar el respaldo de la base.
2. Ejecutar, en orden, los scripts de la carpeta `sql/`.
3. En `src/main/webapp/META-INF/context.xml`, reemplazar `TU_CONTRASENA` por la contraseña de PostgreSQL.
4. Abrir el proyecto en NetBeans, hacer *Clean and Build* y desplegarlo en Tomcat.
5. Entrar a `http://localhost:8080/pro`.
