-- =====================================================================
-- CTA Support - FASE 5: Mantenimiento preventivo (1 o N equipos)
-- Fecha: 20/11/2026
-- Requiere: fases 1 a 4. Ejecutar completo en pgAdmin. Es re-ejecutable.
--
--   Resultado por equipo:
--     Salas:    OK | Requirió repuesto | Derivado a ticket (crea un ticket correctivo)
--     Depósito: Reparado (al finalizar, el equipo vuelve a Activo) | Sin reparación
-- =====================================================================

BEGIN;

ALTER TABLE public.mantenimientos_preventivos_detalle ADD COLUMN IF NOT EXISTS resultado varchar(30);
ALTER TABLE public.mantenimientos_preventivos_detalle ADD COLUMN IF NOT EXISTS id_ticket_derivado integer
    REFERENCES public.ticket (id_ticket);

ALTER TABLE public.mantenimientos_preventivos_detalle DROP CONSTRAINT IF EXISTS ck_mpd_resultado;
ALTER TABLE public.mantenimientos_preventivos_detalle ADD CONSTRAINT ck_mpd_resultado
    CHECK (resultado IS NULL OR resultado IN ('OK', 'Requirió repuesto', 'Derivado a ticket', 'Reparado', 'Sin reparación'));

-- Equipos ya revisados en mantenimientos abiertos: se les pone "OK" para que puedan finalizarse
UPDATE public.mantenimientos_preventivos_detalle d SET resultado = 'OK'
FROM public.mantenimientos_preventivos m
WHERE m.id_mantenimiento = d.id_mantenimiento AND m.estado IN ('Programado', 'En Proceso')
  AND COALESCE(d.realizado, false) AND d.resultado IS NULL;

-- Un mismo equipo no puede estar en dos mantenimientos abiertos a la vez (lo valida la aplicación;
-- este índice ayuda a consultarlo rápido)
CREATE INDEX IF NOT EXISTS ix_mpd_equipo ON public.mantenimientos_preventivos_detalle (id_equipo);

COMMIT;
