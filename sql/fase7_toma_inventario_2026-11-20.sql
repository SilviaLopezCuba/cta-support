-- =====================================================================
-- FASE 7 — TOMA DE INVENTARIO (conteo físico) — CTA Support
-- Ejecutar DESPUÉS de las fases 1 a 6.
--
-- Flujo:
--   1. El Encargado de depósito (o el Administrador) abre una toma:
--        - ARTICULOS: todos los repuestos e insumos del depósito, o
--        - EQUIPOS: los equipos de una sala (o del Depósito).
--   2. Cuenta "a ciegas": la pantalla de conteo NO muestra lo que dice el
--      sistema, para que el conteo sea real y no se copie el número.
--   3. Envía la toma: en ese momento se guarda el stock del sistema.
--   4. El Administrador (otra persona) ve las diferencias y APRUEBA:
--        - artículos: el stock se ajusta (sobrante +, faltante -) y queda en
--          el kardex como AJUSTE con referencia a la toma;
--        - equipos no encontrados: quedan listados en el acta para que el
--          Administrador los dé de baja (Robo / Pérdida) desde Equipos.
--      O la ANULA (con motivo). Aprobada o anulada, no se modifica más.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public.tomas_inventario (
    id_toma              serial PRIMARY KEY,
    numero_toma          varchar(20) UNIQUE,
    tipo_toma            varchar(10) NOT NULL CHECK (tipo_toma IN ('ARTICULOS', 'EQUIPOS')),
    id_sala              integer REFERENCES public.salas (id_sala),
    estado               varchar(12) NOT NULL DEFAULT 'En conteo'
                         CHECK (estado IN ('En conteo', 'Enviada', 'Aprobada', 'Anulada')),
    observacion          text,
    id_usuario_crea      integer NOT NULL REFERENCES public.usuarios (id_usuario),
    fecha_creacion       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_envia     integer REFERENCES public.usuarios (id_usuario),
    fecha_envio          timestamp,
    id_usuario_resuelve  integer REFERENCES public.usuarios (id_usuario),
    fecha_resolucion     timestamp,
    observacion_resolucion text,
    CONSTRAINT ck_toma_sala CHECK ((tipo_toma = 'EQUIPOS') = (id_sala IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS public.tomas_inventario_articulos (
    id_detalle        serial PRIMARY KEY,
    id_toma           integer NOT NULL REFERENCES public.tomas_inventario (id_toma),
    tipo_articulo     char(1) NOT NULL CHECK (tipo_articulo IN ('R', 'I')),
    id_articulo       integer NOT NULL,
    cantidad_contada  numeric(12,2) CHECK (cantidad_contada >= 0),
    cantidad_sistema  numeric(12,2),              -- se guarda al ENVIAR
    costo_unitario    numeric(14,2),              -- último costo al enviar
    ajuste_aplicado   numeric(12,2),              -- se guarda al APROBAR
    observacion       varchar(255),
    UNIQUE (id_toma, tipo_articulo, id_articulo)
);

CREATE TABLE IF NOT EXISTS public.tomas_inventario_equipos (
    id_detalle   serial PRIMARY KEY,
    id_toma      integer NOT NULL REFERENCES public.tomas_inventario (id_toma),
    id_equipo    integer NOT NULL REFERENCES public.equipos (id_equipo),
    encontrado   boolean,
    observacion  varchar(255),
    UNIQUE (id_toma, id_equipo)
);

-- Número correlativo TI-000001
CREATE OR REPLACE FUNCTION public.fn_toma_numero() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.numero_toma IS NULL THEN
        NEW.numero_toma := 'TI-' || lpad(NEW.id_toma::text, 6, '0');
    END IF;
    RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS tg_toma_numero ON public.tomas_inventario;
CREATE TRIGGER tg_toma_numero BEFORE INSERT ON public.tomas_inventario
    FOR EACH ROW EXECUTE FUNCTION public.fn_toma_numero();

-- Una toma aprobada o anulada no se modifica. El conteo solo se carga
-- mientras está "En conteo". Nada se borra.
CREATE OR REPLACE FUNCTION public.fn_toma_inmutable() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_estado varchar;
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Las tomas de inventario no se eliminan; se anulan.';
    END IF;
    IF TG_TABLE_NAME = 'tomas_inventario' THEN
        IF OLD.estado IN ('Aprobada', 'Anulada') THEN
            RAISE EXCEPTION 'La toma % ya está % y no se puede modificar.', OLD.numero_toma, lower(OLD.estado);
        END IF;
        IF NEW.estado = 'Aprobada' AND NEW.id_usuario_resuelve IS NOT DISTINCT FROM OLD.id_usuario_crea
           AND current_setting('cta.toma_mismo_usuario', true) IS DISTINCT FROM 'si' THEN
            RAISE EXCEPTION 'La toma debe aprobarla una persona distinta de quien la contó.';
        END IF;
        RETURN NEW;
    END IF;
    SELECT estado INTO v_estado FROM public.tomas_inventario WHERE id_toma = NEW.id_toma;
    IF v_estado IN ('Aprobada', 'Anulada') THEN
        RAISE EXCEPTION 'La toma ya está cerrada: su detalle no se puede modificar.';
    END IF;
    -- Con la toma enviada, el conteo queda congelado: solo el sistema completa
    -- cantidad_sistema / costo / ajuste_aplicado.
    IF v_estado = 'Enviada' AND TG_OP = 'UPDATE' THEN
        -- (se compara vía jsonb porque cada tabla tiene su propia columna de conteo)
        IF (to_jsonb(NEW) -> 'cantidad_contada') IS DISTINCT FROM (to_jsonb(OLD) -> 'cantidad_contada')
           OR (to_jsonb(NEW) -> 'encontrado') IS DISTINCT FROM (to_jsonb(OLD) -> 'encontrado') THEN
            RAISE EXCEPTION 'La toma ya fue enviada: el conteo no se puede cambiar.';
        END IF;
    END IF;
    IF v_estado = 'Enviada' AND TG_OP = 'INSERT' THEN
        RAISE EXCEPTION 'La toma ya fue enviada: no se agregan renglones.';
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS tg_toma_inmutable ON public.tomas_inventario;
CREATE TRIGGER tg_toma_inmutable BEFORE UPDATE OR DELETE ON public.tomas_inventario
    FOR EACH ROW EXECUTE FUNCTION public.fn_toma_inmutable();
DROP TRIGGER IF EXISTS tg_toma_art_inmutable ON public.tomas_inventario_articulos;
CREATE TRIGGER tg_toma_art_inmutable BEFORE INSERT OR UPDATE OR DELETE ON public.tomas_inventario_articulos
    FOR EACH ROW EXECUTE FUNCTION public.fn_toma_inmutable();
DROP TRIGGER IF EXISTS tg_toma_eq_inmutable ON public.tomas_inventario_equipos;
CREATE TRIGGER tg_toma_eq_inmutable BEFORE INSERT OR UPDATE OR DELETE ON public.tomas_inventario_equipos
    FOR EACH ROW EXECUTE FUNCTION public.fn_toma_inmutable();

DROP TRIGGER IF EXISTS tg_auditoria_tomas ON public.tomas_inventario;
CREATE TRIGGER tg_auditoria_tomas AFTER INSERT OR UPDATE OR DELETE ON public.tomas_inventario
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria('id_toma');

-- Una sola toma abierta (En conteo / Enviada) por tipo y sala a la vez
CREATE UNIQUE INDEX IF NOT EXISTS ux_toma_abierta
    ON public.tomas_inventario (tipo_toma, COALESCE(id_sala, 0))
    WHERE estado IN ('En conteo', 'Enviada');

COMMIT;
