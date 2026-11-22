-- =====================================================================
-- CTA Support - AJUSTES. Fecha: 21/11/2026
-- Requiere: fases 1 a 9. Es re-ejecutable.
--  - Comentario del Encargado en la entrega de material (ej.: entrega parcial).
--  - Servicio "Otros" con descripción libre al cerrar un ticket.
--  - Movimientos de equipos (cabecera-detalle): asignación a salas, retiro al
--    Depósito, baja/inactivación y reactivación.
--  - Ajuste de inventario: numeración AJ- (reemplaza a la toma).
-- =====================================================================
BEGIN;

ALTER TABLE public.solicitudes_material ADD COLUMN IF NOT EXISTS observacion_entrega varchar(255);

-- Servicio "Otros": el técnico describe lo que hizo
ALTER TABLE public.ticket_servicios ADD COLUMN IF NOT EXISTS detalle varchar(255);
INSERT INTO public.catalogo_servicios (nombre_servicio, descripcion, activo)
SELECT 'Otros', 'Otro trabajo no listado (el técnico lo describe)', true
WHERE NOT EXISTS (SELECT 1 FROM public.catalogo_servicios WHERE lower(trim(nombre_servicio)) = 'otros');

-- ---------------------------------------------------------------------
-- Movimientos de equipos
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.movimientos_equipos (
    id_movimiento   serial PRIMARY KEY,
    numero          varchar(20) UNIQUE,
    tipo            varchar(15) NOT NULL CHECK (tipo IN ('ASIGNACION', 'RETIRO', 'BAJA', 'REACTIVACION')),
    id_sala_destino integer REFERENCES public.salas (id_sala),
    id_motivo       integer REFERENCES public.motivos_inactivo (id_motivo),
    fecha           date NOT NULL DEFAULT CURRENT_DATE,
    observacion     varchar(255),
    id_usuario      integer NOT NULL REFERENCES public.usuarios (id_usuario),
    fecha_registro  timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS public.movimientos_equipos_detalle (
    id_detalle          serial PRIMARY KEY,
    id_movimiento       integer NOT NULL REFERENCES public.movimientos_equipos (id_movimiento),
    id_equipo           integer NOT NULL REFERENCES public.equipos (id_equipo),
    id_sala_origen      integer REFERENCES public.salas (id_sala),
    codigo_patrimonial  varchar(50),
    UNIQUE (id_movimiento, id_equipo)
);

CREATE OR REPLACE FUNCTION public.fn_mov_equipo_numero() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.numero IS NULL THEN
        NEW.numero := CASE NEW.tipo WHEN 'ASIGNACION' THEN 'AS-' WHEN 'RETIRO' THEN 'RT-' WHEN 'BAJA' THEN 'BJ-' ELSE 'RA-' END
                      || lpad(NEW.id_movimiento::text, 6, '0');
    END IF;
    RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS tg_mov_equipo_numero ON public.movimientos_equipos;
CREATE TRIGGER tg_mov_equipo_numero BEFORE INSERT ON public.movimientos_equipos
    FOR EACH ROW EXECUTE FUNCTION public.fn_mov_equipo_numero();

DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['movimientos_equipos', 'movimientos_equipos_detalle'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS tg_no_borrar ON public.%I', t);
        EXECUTE format('CREATE TRIGGER tg_no_borrar BEFORE DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.fn_no_borrar()', t);
    END LOOP;
END $$;
DROP TRIGGER IF EXISTS tg_auditoria_movimientos_equipos ON public.movimientos_equipos;
CREATE TRIGGER tg_auditoria_movimientos_equipos AFTER INSERT OR UPDATE ON public.movimientos_equipos
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria('id_movimiento');

-- El historial de salas guarda el número del movimiento que lo causó
CREATE OR REPLACE FUNCTION public.fn_equipos_historial_ubicacion() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.historial_ubicacion_equipo (id_equipo, id_sala_origen, id_sala_destino, id_usuario, observacion)
        VALUES (NEW.id_equipo, NULL, NEW.id_sala, public.fn_usuario_actual(), 'Alta del equipo');
    ELSIF NEW.id_sala IS DISTINCT FROM OLD.id_sala THEN
        INSERT INTO public.historial_ubicacion_equipo (id_equipo, id_sala_origen, id_sala_destino, id_usuario, observacion)
        VALUES (NEW.id_equipo, OLD.id_sala, NEW.id_sala, public.fn_usuario_actual(), NULLIF(current_setting('cta.obs_ubicacion', true), ''));
    END IF;
    RETURN NEW;
END $$;

-- Mensaje más claro al registrar material usado de más
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
        RAISE EXCEPTION 'No tiene suficiente cantidad de ese material para esta orden: solo puede registrar lo que recibió del depósito y no devolvió.';
    END IF;
    RETURN NULL;
END $$;

-- Ajuste de inventario: los nuevos se numeran AJ-
CREATE OR REPLACE FUNCTION public.fn_toma_numero() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.numero_toma IS NULL THEN
        NEW.numero_toma := 'AJ-' || lpad(NEW.id_toma::text, 6, '0');
    END IF;
    RETURN NEW;
END $$;

COMMIT;
