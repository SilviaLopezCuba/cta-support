-- =====================================================================
-- CTA Support - AJUSTE: el Administrador puede entregarse material
-- (y recibir su propia devolución). Fecha: 20/11/2026
-- Requiere: fase 3. Es re-ejecutable.
--
-- Antes: nadie podía entregarse material a sí mismo (regla fija en la base).
-- Ahora: la regla sigue para el Encargado de depósito y el resto de los
-- roles, pero el Administrador sí puede. Queda registrado en la auditoría
-- (quién pidió y quién entregó es el mismo usuario).
-- =====================================================================
BEGIN;

ALTER TABLE public.solicitudes_material  DROP CONSTRAINT IF EXISTS ck_sm_entrega_otro;
ALTER TABLE public.devoluciones_material DROP CONSTRAINT IF EXISTS ck_dv_recibe_otro;

CREATE OR REPLACE FUNCTION public.fn_validar_otro_usuario() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_origen  integer;
    v_destino integer;
    v_es_admin boolean;
BEGIN
    IF TG_TABLE_NAME = 'solicitudes_material' THEN
        v_origen := NEW.id_usuario_solicita; v_destino := NEW.id_usuario_entrega;
    ELSE
        v_origen := NEW.id_usuario_devuelve; v_destino := NEW.id_usuario_recibe;
    END IF;
    IF v_destino IS NULL OR v_destino <> v_origen THEN
        RETURN NEW;
    END IF;
    SELECT r.nombre_rol = 'Administrador' INTO v_es_admin
    FROM public.usuarios u JOIN public.roles r ON r.id_rol = u.id_rol
    WHERE u.id_usuario = v_destino;
    IF NOT COALESCE(v_es_admin, false) THEN
        IF TG_TABLE_NAME = 'solicitudes_material' THEN
            RAISE EXCEPTION 'No puede entregarse material a sí mismo: debe hacerlo otro usuario.';
        ELSE
            RAISE EXCEPTION 'No puede recibir su propia devolución: debe hacerlo otro usuario.';
        END IF;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS tg_sm_otro_usuario ON public.solicitudes_material;
CREATE TRIGGER tg_sm_otro_usuario BEFORE INSERT OR UPDATE ON public.solicitudes_material
    FOR EACH ROW EXECUTE FUNCTION public.fn_validar_otro_usuario();
DROP TRIGGER IF EXISTS tg_dv_otro_usuario ON public.devoluciones_material;
CREATE TRIGGER tg_dv_otro_usuario BEFORE INSERT OR UPDATE ON public.devoluciones_material
    FOR EACH ROW EXECUTE FUNCTION public.fn_validar_otro_usuario();

COMMIT;
