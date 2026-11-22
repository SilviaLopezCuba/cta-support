-- =====================================================================
-- CTA Support - SIMPLIFICACIÓN DE PROCESOS. Fecha: 21/11/2026
-- Requiere: fases 1 a 8. Es re-ejecutable.
--
--  - El técnico ya no confirma que recibió el material: la entrega del
--    Encargado alcanza. Se marcan como recibidas las entregas anteriores.
--  - Las recepciones y las tomas de inventario se registran en un solo paso
--    (no hace falta cambiar la base para eso).
-- =====================================================================
BEGIN;

UPDATE public.solicitudes_material
   SET recepcion_confirmada = true,
       fecha_confirmacion   = COALESCE(fecha_confirmacion, fecha_entrega, CURRENT_TIMESTAMP)
 WHERE estado IN ('Entregada', 'Entregada parcial')
   AND NOT recepcion_confirmada;

ALTER TABLE public.solicitudes_material ALTER COLUMN recepcion_confirmada SET DEFAULT true;

COMMIT;
