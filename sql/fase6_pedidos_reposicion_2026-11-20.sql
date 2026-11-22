-- =====================================================================
-- CTA Support - FASE 6: Pedidos de reposición formales
-- Fecha: 20/11/2026
-- Requiere: fases 1 a 5. Ejecutar completo en pgAdmin. Es re-ejecutable.
--
--   Generada -> Enviada (a la institución) -> Recibida parcial -> Recibida
--   Lo que llega se registra como una RECEPCIÓN (concepto "Reposición") vinculada
--   al pedido; recién cuando el Administrador la confirma entra al stock y se
--   actualiza lo recibido del pedido.
-- =====================================================================

BEGIN;

ALTER TABLE public.solicitudes_compra ADD COLUMN IF NOT EXISTS id_donante integer REFERENCES public.donantes (id_donante);  -- institución a la que se pide
ALTER TABLE public.solicitudes_compra ADD COLUMN IF NOT EXISTS fecha_envio timestamp;
ALTER TABLE public.solicitudes_compra ADD COLUMN IF NOT EXISTS id_usuario_envia integer REFERENCES public.usuarios (id_usuario);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_recepciones_solicitud_origen') THEN
        ALTER TABLE public.recepciones ADD CONSTRAINT fk_recepciones_solicitud_origen
            FOREIGN KEY (id_solicitud_origen) REFERENCES public.solicitudes_compra (id_solicitud);
    END IF;
END $$;

COMMIT;
