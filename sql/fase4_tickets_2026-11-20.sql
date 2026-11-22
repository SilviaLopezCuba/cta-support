-- =====================================================================
-- CTA Support - FASE 4: Tickets (solicitud y cierre)
-- Fecha: 20/11/2026
-- Requiere: fases 1 a 3. Ejecutar completo en pgAdmin. Es re-ejecutable.
--
--   1) Tipo de falla del catálogo en los tickets viejos (si el texto coincide)
--   2) Servicios realizados por ticket (catálogo de servicios)
-- =====================================================================

BEGIN;

-- 1) Los tickets anteriores tenían el tipo de falla escrito a mano: si el
--    texto coincide con un tipo del catálogo, se vincula (sirve para las estadísticas).
UPDATE public.ticket t
SET id_tipo_falla = tf.id_tipo_falla
FROM public.tipos_falla tf
WHERE t.id_tipo_falla IS NULL
  AND tf.id_categoria IS NULL
  AND lower(trim(t.tipo_falla)) = lower(trim(tf.nombre_tipo_falla));

-- 2) Servicios realizados en cada ticket
CREATE TABLE IF NOT EXISTS public.ticket_servicios (
    id           serial PRIMARY KEY,
    id_ticket    integer NOT NULL REFERENCES public.ticket (id_ticket),
    id_servicio  integer NOT NULL REFERENCES public.catalogo_servicios (id_servicio),
    id_usuario   integer REFERENCES public.usuarios (id_usuario),
    fecha        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ux_ticket_servicio UNIQUE (id_ticket, id_servicio)
);
CREATE INDEX IF NOT EXISTS ix_ticket_servicios_servicio ON public.ticket_servicios (id_servicio);

COMMIT;
