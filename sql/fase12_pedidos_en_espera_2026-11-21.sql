-- =====================================================================
-- CTA Support - PEDIDOS DE MATERIAL EN ESPERA DE STOCK. Fecha: 21/11/2026
-- Requiere: fases 1 a 11. Es re-ejecutable.
--  - Nuevo estado "En espera": el depósito no tiene stock, el pedido NO se
--    rechaza; queda esperando la próxima entrada de mercadería.
--  - Vista v_solicitud_stock: indica si hoy alcanza el stock para entregar
--    todo lo pendiente de cada pedido (para avisar "Listo para retirar").
--  - Los pedidos rechazados por "Falta de stock" de órdenes que siguen
--    abiertas pasan a "En espera".
-- =====================================================================
BEGIN;

ALTER TABLE public.solicitudes_material DROP CONSTRAINT IF EXISTS solicitudes_material_estado_check;
ALTER TABLE public.solicitudes_material DROP CONSTRAINT IF EXISTS ck_sm_estado;
ALTER TABLE public.solicitudes_material ADD CONSTRAINT ck_sm_estado
    CHECK (estado IN ('Pendiente', 'En espera', 'Entregada', 'Entregada parcial', 'Rechazada'));

ALTER TABLE public.solicitudes_material ADD COLUMN IF NOT EXISTS fecha_espera timestamp;
ALTER TABLE public.solicitudes_material ADD COLUMN IF NOT EXISTS id_usuario_espera integer REFERENCES public.usuarios (id_usuario);

-- ¿Alcanza hoy el stock del depósito para entregar el pedido completo?
CREATE OR REPLACE VIEW public.v_solicitud_stock AS
SELECT s.id_solicitud, s.tipo_orden, s.id_orden, s.estado, s.id_usuario_solicita,
       bool_and(COALESCE(r.stock, i.stock, 0) >= d.cantidad_solicitada) AS hay_stock
FROM public.solicitudes_material s
JOIN public.solicitudes_material_detalle d ON d.id_solicitud = s.id_solicitud
LEFT JOIN public.catalogo_repuestos r ON d.tipo_articulo = 'R' AND r.id_repuesto = d.id_articulo
LEFT JOIN public.catalogo_insumos  i ON d.tipo_articulo = 'I' AND i.id_insumo  = d.id_articulo
GROUP BY s.id_solicitud, s.tipo_orden, s.id_orden, s.estado, s.id_usuario_solicita;

-- Rechazos por falta de stock de órdenes todavía abiertas -> En espera
UPDATE public.solicitudes_material s
   SET estado = 'En espera', fecha_espera = COALESCE(s.fecha_entrega, CURRENT_TIMESTAMP),
       id_usuario_espera = s.id_usuario_entrega,
       observacion_entrega = COALESCE(s.observacion_entrega, s.motivo_rechazo),
       motivo_rechazo = NULL, id_usuario_entrega = NULL, fecha_entrega = NULL
 WHERE s.estado = 'Rechazada'
   AND s.motivo_rechazo ILIKE 'Falta de stock%'
   AND ((s.tipo_orden = 'T' AND EXISTS (SELECT 1 FROM public.ticket t WHERE t.id_ticket = s.id_orden
                                         AND t.estado IN ('Pendiente', 'Asignado', 'En Proceso', 'Esperando Repuesto')))
     OR (s.tipo_orden = 'M' AND EXISTS (SELECT 1 FROM public.mantenimientos_preventivos m WHERE m.id_mantenimiento = s.id_orden
                                         AND m.estado IN ('Programado', 'En Proceso'))));

COMMIT;
