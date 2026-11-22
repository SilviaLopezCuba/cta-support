-- =====================================================================
-- CTA Support - EQUIPOS QUE NO TIENEN ARREGLO. Fecha: 21/11/2026
-- Requiere: fases 1 a 10. Es re-ejecutable.
--  - Resultado "No reparable" en el mantenimiento preventivo.
--  - El movimiento de baja guarda la orden que lo originó (ticket o mantenimiento).
-- =====================================================================
BEGIN;

ALTER TABLE public.mantenimientos_preventivos_detalle DROP CONSTRAINT IF EXISTS ck_mpd_resultado;
ALTER TABLE public.mantenimientos_preventivos_detalle ADD CONSTRAINT ck_mpd_resultado
    CHECK (resultado IS NULL OR resultado IN ('OK', 'Requirió repuesto', 'Derivado a ticket', 'No reparable', 'Reparado', 'Sin reparación'));

ALTER TABLE public.movimientos_equipos ADD COLUMN IF NOT EXISTS origen varchar(40);   -- ej.: "Ticket T-0045"

COMMIT;
