-- =====================================================================
-- CTA Support - FASE 2: Recepción de equipos e insumos + Kardex
-- Fecha: 20/11/2026
-- Requiere haber ejecutado antes: fase1_estructura_inventario_2026-11-20.sql
-- Ejecutar completo en pgAdmin. Es re-ejecutable.
--
--   1) Recepciones (cabecera + detalle de equipos + detalle de artículos)
--      Estados: Pendiente -> Confirmada   (o Observada: el Administrador la
--      devuelve al Encargado para corregir; nunca se borra ni se anula)
--   2) Kardex (movimientos_stock): TODO cambio de stock de repuestos e insumos
--      queda registrado automáticamente por trigger, con saldo anterior/nuevo.
--   3) Migración de las donaciones ya registradas a Recepciones
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1) RECEPCIONES
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_numero_recepcion;

CREATE TABLE IF NOT EXISTS public.recepciones (
    id_recepcion          serial PRIMARY KEY,
    numero_recepcion      varchar(20) NOT NULL UNIQUE
                          DEFAULT 'REC-' || lpad(nextval('public.seq_numero_recepcion')::text, 6, '0'),
    id_concepto           integer NOT NULL REFERENCES public.conceptos_entrada (id_concepto),
    id_donante            integer NOT NULL REFERENCES public.donantes (id_donante),   -- institución de origen
    nro_comprobante       varchar(50),
    fecha_recepcion       date NOT NULL DEFAULT CURRENT_DATE,
    observacion           text,
    estado                varchar(15) NOT NULL DEFAULT 'Pendiente',
    id_usuario_registro   integer NOT NULL REFERENCES public.usuarios (id_usuario),
    fecha_registro        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_confirma   integer REFERENCES public.usuarios (id_usuario),
    fecha_confirmacion    timestamp,
    observacion_revision  text,                     -- lo que el Administrador pide corregir
    id_solicitud_origen   integer,                  -- reposición: pedido que se está recibiendo (fase 6)
    id_donacion_origen    integer UNIQUE,           -- migración: donación vieja de la que viene
    CONSTRAINT ck_recepciones_estado CHECK (estado IN ('Pendiente', 'Observada', 'Confirmada')),
    CONSTRAINT ck_recepciones_confirmada CHECK (estado <> 'Confirmada' OR (id_usuario_confirma IS NOT NULL AND fecha_confirmacion IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS ix_recepciones_estado ON public.recepciones (estado, fecha_recepcion);

CREATE TABLE IF NOT EXISTS public.recepciones_detalle_equipos (
    id_detalle         serial PRIMARY KEY,
    id_recepcion       integer NOT NULL REFERENCES public.recepciones (id_recepcion) ON DELETE CASCADE,
    id_categoria       integer NOT NULL REFERENCES public.categorias (id_categoria),
    id_marca           integer REFERENCES public.marcas (id_marca),
    modelo             varchar(100) NOT NULL,
    especificaciones   text,
    condicion_ingreso  varchar(15) NOT NULL DEFAULT 'Nuevo'
                       CHECK (condicion_ingreso IN ('Nuevo', 'Seminuevo', 'Usado')),
    cantidad           integer NOT NULL CHECK (cantidad > 0 AND cantidad <= 500),
    costo_unitario     numeric(14,2) NOT NULL DEFAULT 0 CHECK (costo_unitario >= 0),
    fecha_garantia     date
);

CREATE TABLE IF NOT EXISTS public.recepciones_detalle_articulos (
    id_detalle      serial PRIMARY KEY,
    id_recepcion    integer NOT NULL REFERENCES public.recepciones (id_recepcion) ON DELETE CASCADE,
    id_repuesto     integer REFERENCES public.catalogo_repuestos (id_repuesto),
    id_insumo       integer REFERENCES public.catalogo_insumos (id_insumo),
    cantidad        numeric(12,2) NOT NULL CHECK (cantidad > 0),
    costo_unitario  numeric(14,2) NOT NULL DEFAULT 0 CHECK (costo_unitario >= 0),
    CONSTRAINT ck_rec_articulo_uno CHECK ((id_repuesto IS NULL) <> (id_insumo IS NULL))
);

-- De qué recepción salió cada equipo
ALTER TABLE public.equipos ADD COLUMN IF NOT EXISTS id_recepcion integer REFERENCES public.recepciones (id_recepcion);

-- Una recepción confirmada no se puede modificar ni borrar (ni su detalle).
CREATE OR REPLACE FUNCTION public.fn_recepcion_inmutable() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_estado varchar;
    v_id integer;
BEGIN
    IF TG_TABLE_NAME = 'recepciones' THEN
        IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION 'Las recepciones no se eliminan.';
        END IF;
        IF OLD.estado = 'Confirmada' THEN
            RAISE EXCEPTION 'La recepción % ya está confirmada y no se puede modificar.', OLD.numero_recepcion;
        END IF;
        RETURN NEW;
    END IF;
    v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id_recepcion ELSE NEW.id_recepcion END;
    SELECT estado INTO v_estado FROM public.recepciones WHERE id_recepcion = v_id;
    IF v_estado = 'Confirmada' THEN
        RAISE EXCEPTION 'La recepción ya está confirmada: su detalle no se puede modificar.';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;

DROP TRIGGER IF EXISTS tg_recepciones_inmutable ON public.recepciones;
CREATE TRIGGER tg_recepciones_inmutable BEFORE UPDATE OR DELETE ON public.recepciones
    FOR EACH ROW EXECUTE FUNCTION public.fn_recepcion_inmutable();
DROP TRIGGER IF EXISTS tg_rec_det_equipos_inmutable ON public.recepciones_detalle_equipos;
CREATE TRIGGER tg_rec_det_equipos_inmutable BEFORE INSERT OR UPDATE OR DELETE ON public.recepciones_detalle_equipos
    FOR EACH ROW EXECUTE FUNCTION public.fn_recepcion_inmutable();
DROP TRIGGER IF EXISTS tg_rec_det_articulos_inmutable ON public.recepciones_detalle_articulos;
CREATE TRIGGER tg_rec_det_articulos_inmutable BEFORE INSERT OR UPDATE OR DELETE ON public.recepciones_detalle_articulos
    FOR EACH ROW EXECUTE FUNCTION public.fn_recepcion_inmutable();

DROP TRIGGER IF EXISTS tg_auditoria_recepciones ON public.recepciones;
CREATE TRIGGER tg_auditoria_recepciones AFTER INSERT OR UPDATE OR DELETE ON public.recepciones
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria('id_recepcion');

-- ---------------------------------------------------------------------
-- 2) KARDEX
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.movimientos_stock (
    id_movimiento    bigserial PRIMARY KEY,
    tipo_articulo    char(1) NOT NULL CHECK (tipo_articulo IN ('R', 'I')),   -- R = repuesto, I = insumo
    id_articulo      integer NOT NULL,
    saldo            varchar(12) NOT NULL DEFAULT 'disponible'
                     CHECK (saldo IN ('disponible', 'dañado')),
    tipo_movimiento  varchar(20) NOT NULL,      -- SALDO INICIAL, ENTRADA, ENTREGA, DEVOLUCION, AJUSTE, DAÑO
    cantidad         numeric(12,2) NOT NULL,    -- + entra, - sale
    stock_anterior   numeric(12,2) NOT NULL,
    stock_nuevo      numeric(12,2) NOT NULL,
    costo_unitario   numeric(14,2),
    referencia_tipo  varchar(30),               -- RECEPCION, ENTREGA, AJUSTE, SOLICITUD...
    referencia_id    integer,
    observacion      varchar(255),
    id_usuario       integer,
    fecha            timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_movimientos_articulo ON public.movimientos_stock (tipo_articulo, id_articulo, fecha);

-- El kardex no se edita ni se borra
CREATE OR REPLACE FUNCTION public.fn_kardex_inmutable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Los movimientos del kardex no se modifican ni se eliminan.';
END $$;
DROP TRIGGER IF EXISTS tg_kardex_inmutable ON public.movimientos_stock;
CREATE TRIGGER tg_kardex_inmutable BEFORE UPDATE OR DELETE ON public.movimientos_stock
    FOR EACH ROW EXECUTE FUNCTION public.fn_kardex_inmutable();

-- La aplicación informa el contexto del movimiento dentro de su transacción:
--   SELECT public.fn_kardex_contexto('ENTRADA', 'RECEPCION', 15, 'REC-000015', 125000);
CREATE OR REPLACE FUNCTION public.fn_kardex_contexto(p_tipo text, p_ref_tipo text, p_ref_id integer,
                                                     p_obs text, p_costo numeric DEFAULT NULL) RETURNS void
LANGUAGE sql AS $$
    SELECT set_config('cta.mov_tipo',     COALESCE(p_tipo, ''), true),
           set_config('cta.mov_ref_tipo', COALESCE(p_ref_tipo, ''), true),
           set_config('cta.mov_ref_id',   COALESCE(p_ref_id::text, ''), true),
           set_config('cta.mov_obs',      COALESCE(left(p_obs, 255), ''), true),
           set_config('cta.mov_costo',    COALESCE(p_costo::text, ''), true);
$$;

-- Cualquier cambio de stock (por el sistema o por fuera) deja su movimiento.
CREATE OR REPLACE FUNCTION public.fn_kardex_registrar() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_tipo_art char(1) := CASE WHEN TG_TABLE_NAME = 'catalogo_repuestos' THEN 'R' ELSE 'I' END;
    v_id       integer := CASE WHEN TG_TABLE_NAME = 'catalogo_repuestos' THEN (to_jsonb(NEW) ->> 'id_repuesto')::integer
                                                                         ELSE (to_jsonb(NEW) ->> 'id_insumo')::integer END;
    v_tipo     text := NULLIF(current_setting('cta.mov_tipo', true), '');
    v_ref_tipo text := NULLIF(current_setting('cta.mov_ref_tipo', true), '');
    v_ref_id   integer := NULLIF(current_setting('cta.mov_ref_id', true), '')::integer;
    v_obs      text := NULLIF(current_setting('cta.mov_obs', true), '');
    v_costo    numeric := NULLIF(current_setting('cta.mov_costo', true), '')::numeric;
    v_old_stock numeric := CASE WHEN TG_OP = 'INSERT' THEN 0 ELSE COALESCE(OLD.stock, 0) END;
    v_old_dan   numeric := CASE WHEN TG_OP = 'INSERT' THEN 0 ELSE COALESCE(OLD.stock_danado, 0) END;
BEGIN
    IF COALESCE(NEW.stock, 0) <> v_old_stock THEN
        INSERT INTO public.movimientos_stock (tipo_articulo, id_articulo, saldo, tipo_movimiento, cantidad,
               stock_anterior, stock_nuevo, costo_unitario, referencia_tipo, referencia_id, observacion, id_usuario)
        VALUES (v_tipo_art, v_id, 'disponible',
                COALESCE(v_tipo, CASE WHEN TG_OP = 'INSERT' THEN 'SALDO INICIAL'
                                      WHEN NEW.stock > v_old_stock THEN 'ENTRADA' ELSE 'SALIDA' END),
                COALESCE(NEW.stock, 0) - v_old_stock, v_old_stock, COALESCE(NEW.stock, 0),
                v_costo, v_ref_tipo, v_ref_id,
                COALESCE(v_obs, CASE WHEN v_tipo IS NULL THEN 'Cambio de stock sin referencia' END),
                public.fn_usuario_actual());
    END IF;
    IF COALESCE(NEW.stock_danado, 0) <> v_old_dan THEN
        INSERT INTO public.movimientos_stock (tipo_articulo, id_articulo, saldo, tipo_movimiento, cantidad,
               stock_anterior, stock_nuevo, costo_unitario, referencia_tipo, referencia_id, observacion, id_usuario)
        VALUES (v_tipo_art, v_id, 'dañado', COALESCE(v_tipo, 'DAÑO'),
                COALESCE(NEW.stock_danado, 0) - v_old_dan, v_old_dan, COALESCE(NEW.stock_danado, 0),
                v_costo, v_ref_tipo, v_ref_id, v_obs, public.fn_usuario_actual());
    END IF;
    RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS tg_kardex_insumos ON public.catalogo_insumos;
CREATE TRIGGER tg_kardex_insumos AFTER INSERT OR UPDATE OF stock, stock_danado ON public.catalogo_insumos
    FOR EACH ROW EXECUTE FUNCTION public.fn_kardex_registrar();
DROP TRIGGER IF EXISTS tg_kardex_repuestos ON public.catalogo_repuestos;
CREATE TRIGGER tg_kardex_repuestos AFTER INSERT OR UPDATE OF stock, stock_danado ON public.catalogo_repuestos
    FOR EACH ROW EXECUTE FUNCTION public.fn_kardex_registrar();

-- Saldo inicial: el stock que ya existe hoy (una sola vez por artículo)
INSERT INTO public.movimientos_stock (tipo_articulo, id_articulo, tipo_movimiento, cantidad, stock_anterior, stock_nuevo, observacion)
SELECT 'I', i.id_insumo, 'SALDO INICIAL', i.stock, 0, i.stock, 'Saldo al habilitar el kardex (fase 2)'
FROM public.catalogo_insumos i
WHERE COALESCE(i.stock, 0) <> 0
  AND NOT EXISTS (SELECT 1 FROM public.movimientos_stock m WHERE m.tipo_articulo = 'I' AND m.id_articulo = i.id_insumo);
INSERT INTO public.movimientos_stock (tipo_articulo, id_articulo, tipo_movimiento, cantidad, stock_anterior, stock_nuevo, observacion)
SELECT 'R', r.id_repuesto, 'SALDO INICIAL', r.stock, 0, r.stock, 'Saldo al habilitar el kardex (fase 2)'
FROM public.catalogo_repuestos r
WHERE COALESCE(r.stock, 0) <> 0
  AND NOT EXISTS (SELECT 1 FROM public.movimientos_stock m WHERE m.tipo_articulo = 'R' AND m.id_articulo = r.id_repuesto);

-- ---------------------------------------------------------------------
-- 3) MIGRACIÓN: donaciones ya registradas -> Recepciones confirmadas
--    (su stock ya está sumado y figura en el saldo inicial: no se vuelve a sumar)
-- ---------------------------------------------------------------------
INSERT INTO public.recepciones (id_concepto, id_donante, nro_comprobante, fecha_recepcion, observacion, estado,
                                id_usuario_registro, id_usuario_confirma, fecha_confirmacion, id_donacion_origen)
SELECT (SELECT id_concepto FROM public.conceptos_entrada WHERE lower(nombre_concepto) = 'donación'),
       d.id_donante, d.nro_comprobante, COALESCE(d.fecha_donacion, CURRENT_DATE),
       'Migrado de la donación #' || d.id_donacion, 'Confirmada',
       d.id_usuario_registro, d.id_usuario_registro, CURRENT_TIMESTAMP, d.id_donacion
FROM public.donaciones d
WHERE COALESCE(d.estado, 'Registrada') <> 'Anulada'
  AND d.id_usuario_registro IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.recepciones r WHERE r.id_donacion_origen = d.id_donacion)
ORDER BY d.id_donacion;

-- El detalle se inserta con la recepción todavía "abierta" para el trigger:
-- se desactiva solo durante la migración.
ALTER TABLE public.recepciones_detalle_articulos DISABLE TRIGGER tg_rec_det_articulos_inmutable;
INSERT INTO public.recepciones_detalle_articulos (id_recepcion, id_repuesto, id_insumo, cantidad, costo_unitario)
SELECT r.id_recepcion, dd.id_repuesto, dd.id_insumo, dd.cantidad, 0
FROM public.donaciones_detalle dd
JOIN public.recepciones r ON r.id_donacion_origen = dd.id_donacion
WHERE (dd.id_repuesto IS NULL) <> (dd.id_insumo IS NULL) AND dd.cantidad > 0
  AND NOT EXISTS (SELECT 1 FROM public.recepciones_detalle_articulos x WHERE x.id_recepcion = r.id_recepcion);
ALTER TABLE public.recepciones_detalle_articulos ENABLE TRIGGER tg_rec_det_articulos_inmutable;

COMMIT;

-- Verificación
SELECT estado, count(*) FROM public.recepciones GROUP BY estado;
SELECT tipo_movimiento, count(*) FROM public.movimientos_stock GROUP BY tipo_movimiento;
