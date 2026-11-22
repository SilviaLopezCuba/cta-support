-- CTA Support - Corrección de la prueba PI-09: el login de usuarios no puede repetirse.
-- 1) Revisar que no haya logins repetidos (debe devolver 0 filas):
SELECT login, count(*) FROM public.usuarios GROUP BY login HAVING count(*) > 1;
-- 2) Crear la restricción:
CREATE UNIQUE INDEX IF NOT EXISTS ux_usuarios_login ON public.usuarios (login);
