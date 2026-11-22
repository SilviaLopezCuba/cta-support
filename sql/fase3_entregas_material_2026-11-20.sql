-- =====================================================================
-- CTA Support - FASE 3: Entrega de material a técnicos
-- Fecha: 20/11/2026
-- Requiere: fase1 y fase2. Ejecutar completo en pgAdmin. Es re-ejecutable.
--
-- Circuito:
--   1. El técnico pide material desde su ticket o mantenimiento (Pendiente).
--   2. El Encargado de depósito entrega (total o parcial) o rechaza.
--      AL ENTREGAR se descuenta el stock (kardex: ENTREGA).
--      Quien pidió no puede entregarse a sí mismo.
--   3. El técnico confirma que recibió el material.
--   4. Al trabajar, registra lo que usó (ticket_repuesto / mantenimiento_repuesto):
--      solo puede usar lo que tiene en su poder para ESA orden. Usar NO toca el stock.
--   5. Lo que sobra lo devuelve; el Encargado lo recibe y vuelve al stock
--      (o al stock dañado si vino roto).
--   6. La orden no se puede finalizar con material sin rendir:
--      entregado = usado + devuelto.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1) Desactivar los triggers viejos que descontaban stock al registrar
--    materiales usados (ahora el stock se descuenta al ENTREGAR).
--    Solo se desactivan los que tocan "stock"; quedan listados en el aviso.
-- ---------------------------------------------------------------------
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT c.relname AS tabla, t.tgname AS trigger_name
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_proc p ON p.oid = t.tgfoid
        WHERE n.nspname = 'public'
          AND c.relname IN ('ticket_repuesto', 'mantenimiento_repuesto', 'donaciones_detalle')
          AND NOT t.tgisinternal
          AND t.tgenabled <> 'D'
          AND p.prosrc ILIKE '%stock%'
    LOOP
        EXECUTE format('ALTER TABLE public.%I DISABLE TRIGGER %I', r.tabla, r.trigger_name);
        RAISE NOTICE 'Trigger desactivado: %.% (descontaba stock al registrar el uso)', r.tabla, r.trigger_name;
    END LOOP;
END $$;

-- Los usos registrados ANTES de esta fase no vienen de una entrega:
-- se marcan para no mezclarlos con el saldo nuevo.
ALTER TABLE public.ticket_repuesto        ADD COLUMN IF NOT EXISTS con_entrega boolean;
ALTER TABLE public.mantenimiento_repuesto ADD COLUMN IF NOT EXISTS con_entrega boolean;
UPDATE public.ticket_repuesto        SET con_entrega = false WHERE con_entrega IS NULL;
UPDATE public.mantenimiento_repuesto SET con_entrega = false WHERE con_entrega IS NULL;
ALTER TABLE public.ticket_repuesto        ALTER COLUMN con_entrega SET DEFAULT true;
ALTER TABLE public.mantenimiento_repuesto ALTER COLUMN con_entrega SET DEFAULT true;
ALTER TABLE public.ticket_repuesto        ALTER COLUMN con_entrega SET NOT NULL;
ALTER TABLE public.mantenimiento_repuesto ALTER COLUMN con_entrega SET NOT NULL;

-- ---------------------------------------------------------------------
-- 2) SOLICITUDES DE MATERIAL (pedido del técnico -> entrega del Encargado)
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_numero_solicitud_material;

CREATE TABLE IF NOT EXISTS public.solicitudes_material (
    id_solicitud          serial PRIMARY KEY,
    numero                varchar(20) NOT NULL UNIQUE
                          DEFAULT 'SM-' || lpad(nextval('public.seq_numero_solicitud_material')::text, 6, '0'),
    tipo_orden            char(1) NOT NULL CHECK (tipo_orden IN ('T', 'M')),   -- T = ticket, M = mantenimiento
    id_orden              integer NOT NULL,
    id_usuario_solicita   integer NOT NULL REFERENCES public.usuarios (id_usuario),
    fecha_solicitud       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacion           varchar(255),
    estado                varchar(20) NOT NULL DEFAULT 'Pendiente'
                          CHECK (estado IN ('Pendiente', 'Entregada', 'Entregada parcial', 'Rechazada')),
    id_usuario_entrega    integer REFERENCES public.usuarios (id_usuario),
    fecha_entrega         timestamp,
    motivo_rechazo        varchar(255),
    recepcion_confirmada  boolean NOT NULL DEFAULT false,
    fecha_confirmacion    timestamp,
    CONSTRAINT ck_sm_entrega_otro CHECK (id_usuario_entrega IS NULL OR id_usuario_entrega <> id_usuario_solicita)
);
CREATE INDEX IF NOT EXISTS ix_sm_orden ON public.solicitudes_material (tipo_orden, id_orden);
CREATE INDEX IF NOT EXISTS ix_sm_estado ON public.solicitudes_material (estado);

CREATE TABLE IF NOT EXISTS public.solicitudes_material_detalle (
    id_detalle           serial PRIMARY KEY,
    id_solicitud         integer NOT NULL REFERENCES public.solicitudes_material (id_solicitud),
    tipo_articulo        char(1) NOT NULL CHECK (tipo_articulo IN ('R', 'I')),
    id_articulo          integer NOT NULL,
    cantidad_solicitada  numeric(12,2) NOT NULL CHECK (cantidad_solicitada > 0),
    cantidad_entregada   numeric(12,2) NOT NULL DEFAULT 0,
    costo_unitario       numeric(14,2),
    CONSTRAINT ck_smd_entregada CHECK (cantidad_entregada >= 0 AND cantidad_entregada <= cantidad_solicitada),
    CONSTRAINT ux_smd_articulo UNIQUE (id_solicitud, tipo_articulo, id_articulo)
);

-- ---------------------------------------------------------------------
-- 3) DEVOLUCIONES (lo que sobra vuelve al depósito)
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_numero_devolucion_material;

CREATE TABLE IF NOT EXISTS public.devoluciones_material (
    id_devolucion        serial PRIMARY KEY,
    numero               varchar(20) NOT NULL UNIQUE
                         DEFAULT 'DV-' || lpad(nextval('public.seq_numero_devolucion_material')::text, 6, '0'),
    tipo_orden           char(1) NOT NULL CHECK (tipo_orden IN ('T', 'M')),
    id_orden             integer NOT NULL,
    id_usuario_devuelve  integer NOT NULL REFERENCES public.usuarios (id_usuario),
    fecha_devolucion     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacion          varchar(255),
    estado               varchar(15) NOT NULL DEFAULT 'Pendiente' CHECK (estado IN ('Pendiente', 'Recibida')),
    id_usuario_recibe    integer REFERENCES public.usuarios (id_usuario),
    fecha_recepcion      timestamp,
    CONSTRAINT ck_dv_recibe_otro CHECK (id_usuario_recibe IS NULL OR id_usuario_recibe <> id_usuario_devuelve)
);
CREATE INDEX IF NOT EXISTS ix_dv_orden ON public.devoluciones_material (tipo_orden, id_orden);

CREATE TABLE IF NOT EXISTS public.devoluciones_material_detalle (
    id_detalle     serial PRIMARY KEY,
    id_devolucion  integer NOT NULL REFERENCES public.devoluciones_material (id_devolucion),
    tipo_articulo  char(1) NOT NULL CHECK (tipo_articulo IN ('R', 'I')),
    id_articulo    integer NOT NULL,
    cantidad       numeric(12,2) NOT NULL CHECK (cantidad > 0),
    condicion      varchar(10) NOT NULL DEFAULT 'Bueno' CHECK (condicion IN ('Bueno', 'Dañado'))
);

-- Ninguno de estos documentos se borra
CREATE OR REPLACE FUNCTION public.fn_no_borrar() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Este registro forma parte del control de inventario y no se puede eliminar.';
END $$;
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['solicitudes_material', 'solicitudes_material_detalle', 'devoluciones_material', 'devoluciones_material_detalle'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS tg_no_borrar ON public.%I', t);
        EXECUTE format('CREATE TRIGGER tg_no_borrar BEFORE DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.fn_no_borrar()', t);
    END LOOP;
END $$;

DROP TRIGGER IF EXISTS tg_auditoria_solicitudes_material ON public.solicitudes_material;
CREATE TRIGGER tg_auditoria_solicitudes_material AFTER INSERT OR UPDATE ON public.solicitudes_material
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria('id_solicitud');
DROP TRIGGER IF EXISTS tg_auditoria_devoluciones_material ON public.devoluciones_material;
CREATE TRIGGER tg_auditoria_devoluciones_material AFTER INSERT OR UPDATE ON public.devoluciones_material
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria('id_devolucion');

-- ---------------------------------------------------------------------
-- 4) SALDO DE MATERIAL POR ORDEN Y ARTÍCULO
--    saldo = entregado (confirmado por el técnico) - usado - devuelto
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_material_orden AS
WITH entregas AS (
    SELECT s.tipo_orden, s.id_orden, d.tipo_articulo, d.id_articulo,
           COALESCE(SUM(d.cantidad_entregada) FILTER (WHERE s.recepcion_confirmada), 0)     AS entregado,
           COALESCE(SUM(d.cantidad_entregada) FILTER (WHERE NOT s.recepcion_confirmada), 0) AS sin_confirmar
    FROM public.solicitudes_material s
    JOIN public.solicitudes_material_detalle d ON d.id_solicitud = s.id_solicitud
    WHERE s.estado IN ('Entregada', 'Entregada parcial') AND d.cantidad_entregada > 0
    GROUP BY 1, 2, 3, 4
), usos AS (
    SELECT 'T'::char(1) AS tipo_orden, tr.id_ticket AS id_orden,
           (CASE WHEN tr.id_repuesto IS NOT NULL THEN 'R' ELSE 'I' END)::char(1) AS tipo_articulo,
           COALESCE(tr.id_repuesto, tr.id_insumo) AS id_articulo, SUM(tr.cantidad) AS usado
    FROM public.ticket_repuesto tr WHERE tr.con_entrega
    GROUP BY 1, 2, 3, 4
    UNION ALL
    SELECT 'M'::char(1), d.id_mantenimiento,
           (CASE WHEN mr.id_repuesto IS NOT NULL THEN 'R' ELSE 'I' END)::char(1),
           COALESCE(mr.id_repuesto, mr.id_insumo), SUM(mr.cantidad)
    FROM public.mantenimiento_repuesto mr
    JOIN public.mantenimientos_preventivos_detalle d ON d.id_detalle = mr.id_detalle
    WHERE mr.con_entrega
    GROUP BY 1, 2, 3, 4
), devoluciones AS (
    SELECT v.tipo_orden, v.id_orden, dd.tipo_articulo, dd.id_articulo, SUM(dd.cantidad) AS devuelto
    FROM public.devoluciones_material v
    JOIN public.devoluciones_material_detalle dd ON dd.id_devolucion = v.id_devolucion
    GROUP BY 1, 2, 3, 4
)
SELECT e.tipo_orden, e.id_orden, e.tipo_articulo, e.id_articulo,
       COALESCE(r.nombre, i.nombre) AS articulo,
       e.entregado, e.sin_confirmar,
       COALESCE(u.usado, 0)    AS usado,
       COALESCE(dv.devuelto, 0) AS devuelto,
       e.entregado - COALESCE(u.usado, 0) - COALESCE(dv.devuelto, 0) AS saldo
FROM entregas e
LEFT JOIN usos u ON u.tipo_orden = e.tipo_orden AND u.id_orden = e.id_orden AND u.tipo_articulo = e.tipo_articulo AND u.id_articulo = e.id_articulo
LEFT JOIN devoluciones dv ON dv.tipo_orden = e.tipo_orden AND dv.id_orden = e.id_orden AND dv.tipo_articulo = e.tipo_articulo AND dv.id_articulo = e.id_articulo
LEFT JOIN public.catalogo_repuestos r ON e.tipo_articulo = 'R' AND r.id_repuesto = e.id_articulo
LEFT JOIN public.catalogo_insumos i ON e.tipo_articulo = 'I' AND i.id_insumo = e.id_articulo;

-- ---------------------------------------------------------------------
-- 5) Regla en la base: no se puede registrar como "usado" más de lo que el
--    técnico tiene en su poder para esa orden.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_validar_uso_material() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_tipo_orden char(1);
    v_id_orden   integer;
    v_tipo_art   char(1) := CASE WHEN NEW.id_repuesto IS NOT NULL THEN 'R' ELSE 'I' END;
    v_id_art     integer := COALESCE(NEW.id_repuesto, NEW.id_insumo);
    v_saldo      numeric;
BEGIN
    IF NOT NEW.con_entrega THEN RETURN NEW; END IF;
    IF TG_TABLE_NAME = 'ticket_repuesto' THEN
        v_tipo_orden := 'T'; v_id_orden := NEW.id_ticket;
    ELSE
        v_tipo_orden := 'M';
        SELECT id_mantenimiento INTO v_id_orden FROM public.mantenimientos_preventivos_detalle WHERE id_detalle = NEW.id_detalle;
    END IF;
    -- Se valida después de aplicar el cambio (AFTER): el saldo no puede quedar negativo
    SELECT saldo INTO v_saldo FROM public.v_material_orden
    WHERE tipo_orden = v_tipo_orden AND id_orden = v_id_orden AND tipo_articulo = v_tipo_art AND id_articulo = v_id_art;
    IF COALESCE(v_saldo, -1) < 0 OR v_saldo IS NULL THEN
        RAISE EXCEPTION 'No tiene en su poder suficiente cantidad de ese material para esta orden. Pídalo al depósito y confirme la recepción.';
    END IF;
    RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS tg_validar_uso_ticket ON public.ticket_repuesto;
CREATE CONSTRAINT TRIGGER tg_validar_uso_ticket AFTER INSERT OR UPDATE ON public.ticket_repuesto
    FOR EACH ROW EXECUTE FUNCTION public.fn_validar_uso_material();
DROP TRIGGER IF EXISTS tg_validar_uso_mantenimiento ON public.mantenimiento_repuesto;
CREATE CONSTRAINT TRIGGER tg_validar_uso_mantenimiento AFTER INSERT OR UPDATE ON public.mantenimiento_repuesto
    FOR EACH ROW EXECUTE FUNCTION public.fn_validar_uso_material();

COMMIT;
