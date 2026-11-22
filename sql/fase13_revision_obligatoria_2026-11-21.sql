-- =====================================================================
-- CTA Support - REVISIÓN OBLIGATORIA Y URGENCIA DE LOS PEDIDOS. Fecha: 21/11/2026
-- Requiere: fases 1 a 12. Es re-ejecutable.
--  - Ticket: "Primera revisión" (diagnóstico + urgencia + cómo sigue) al tomarlo.
--    Sin revisión no se puede pedir material.
--  - Mantenimiento: "Observación inicial" antes de pedir material.
--  - Pedido de material: urgencia, equipo (en mantenimiento) y si la orden
--    queda detenida hasta que llegue.
-- =====================================================================
BEGIN;

ALTER TABLE public.ticket ADD COLUMN IF NOT EXISTS fecha_revision timestamp;

ALTER TABLE public.mantenimientos_preventivos ADD COLUMN IF NOT EXISTS observacion_inicial varchar(500);
ALTER TABLE public.mantenimientos_preventivos ADD COLUMN IF NOT EXISTS fecha_observacion timestamp;

ALTER TABLE public.solicitudes_material ADD COLUMN IF NOT EXISTS prioridad varchar(10) NOT NULL DEFAULT 'Media';
ALTER TABLE public.solicitudes_material DROP CONSTRAINT IF EXISTS ck_sm_prioridad;
ALTER TABLE public.solicitudes_material ADD CONSTRAINT ck_sm_prioridad
    CHECK (prioridad IN ('Baja', 'Media', 'Alta', 'Critica', 'Normal', 'Urgente'));
ALTER TABLE public.solicitudes_material ADD COLUMN IF NOT EXISTS id_equipo integer REFERENCES public.equipos (id_equipo);
ALTER TABLE public.solicitudes_material ADD COLUMN IF NOT EXISTS detiene boolean NOT NULL DEFAULT false;

-- Tickets que ya se estaban trabajando: se consideran revisados.
-- Los "Asignado" quedan SIN REVISAR (el técnico tiene que hacer la primera revisión).
UPDATE public.ticket
   SET fecha_revision = COALESCE(fecha_inicio, fecha_creacion, CURRENT_TIMESTAMP)
 WHERE fecha_revision IS NULL
   AND estado IN ('En Proceso', 'Esperando Repuesto', 'Resuelto', 'Cerrado');

-- Mantenimientos en curso que ya tienen pedidos: se consideran con observación inicial.
UPDATE public.mantenimientos_preventivos m
   SET observacion_inicial = 'Registrado antes de la observación obligatoria.', fecha_observacion = COALESCE(m.fecha_inicio, CURRENT_TIMESTAMP)
 WHERE m.observacion_inicial IS NULL
   AND EXISTS (SELECT 1 FROM public.solicitudes_material s WHERE s.tipo_orden = 'M' AND s.id_orden = m.id_mantenimiento);

-- Pedidos ya cargados: toman la urgencia de su ticket; los de mantenimiento quedan "Normal".
UPDATE public.solicitudes_material s SET prioridad = t.prioridad
  FROM public.ticket t
 WHERE s.tipo_orden = 'T' AND t.id_ticket = s.id_orden AND t.prioridad IN ('Baja', 'Media', 'Alta', 'Critica')
   AND s.prioridad IS DISTINCT FROM t.prioridad;
UPDATE public.solicitudes_material SET prioridad = 'Normal' WHERE tipo_orden = 'M' AND prioridad NOT IN ('Normal', 'Urgente');

-- Pedidos de tickets que hoy están "Esperando Repuesto": la orden está detenida.
UPDATE public.solicitudes_material s SET detiene = true
  FROM public.ticket t
 WHERE s.tipo_orden = 'T' AND t.id_ticket = s.id_orden AND t.estado = 'Esperando Repuesto'
   AND s.estado IN ('Pendiente', 'En espera') AND NOT s.detiene;

COMMIT;
