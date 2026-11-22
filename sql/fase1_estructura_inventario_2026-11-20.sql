-- =====================================================================
-- CTA Support - FASE 1: estructura base de inventario y depósito
-- Fecha: 20/11/2026
-- Ejecutar completo en pgAdmin (Query Tool) sobre la base del proyecto.
-- Es re-ejecutable: usa IF NOT EXISTS / ON CONFLICT donde corresponde.
--
-- Contenido:
--   1) Departamentos (nuevo) y salas con departamento + sala "Depósito"
--   2) Motivos de inactivo (nuevo)
--   3) Equipos: nuevos campos, estado Activo/Inactivo, código patrimonial
--      opcional solo en el Depósito
--   4) Categorías: vida útil (depreciación)
--   5) Repuestos e insumos: stock dañado, último costo, stock no negativo
--   6) Referenciales nuevos: tipos de falla, catálogo de servicios,
--      conceptos de entrada
--   7) Ticket: tipo de falla del catálogo
--   8) Rol "Encargado de depósito"
--   9) Historial de ubicación de equipos (automático, por trigger)
--  10) Auditoría de cambios (automática, por trigger)
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1) DEPARTAMENTOS Y SALAS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.departamentos (
    id_departamento     serial PRIMARY KEY,
    nombre_departamento varchar(100) NOT NULL,
    descripcion         varchar(255),
    activo              boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_departamentos_nombre
    ON public.departamentos (lower(trim(nombre_departamento)));

INSERT INTO public.departamentos (nombre_departamento)
SELECT v.n FROM (VALUES ('Formación'), ('Instructores'), ('Administrativo'), ('Académico')) AS v(n)
WHERE NOT EXISTS (SELECT 1 FROM public.departamentos d
                  WHERE lower(trim(d.nombre_departamento)) = lower(v.n));

ALTER TABLE public.salas ADD COLUMN IF NOT EXISTS id_departamento integer
    REFERENCES public.departamentos (id_departamento);
ALTER TABLE public.salas ADD COLUMN IF NOT EXISTS es_deposito boolean NOT NULL DEFAULT false;

-- Solo puede existir UN depósito
CREATE UNIQUE INDEX IF NOT EXISTS ux_salas_un_deposito ON public.salas (es_deposito) WHERE es_deposito;

-- Si ya existía una sala llamada "Depósito", se la marca como tal; si no, se crea.
UPDATE public.salas SET es_deposito = true, id_departamento = NULL
WHERE lower(trim(nombre_sala)) IN ('deposito', 'depósito')
  AND NOT EXISTS (SELECT 1 FROM public.salas WHERE es_deposito);

INSERT INTO public.salas (nombre_sala, ubicacion_piso, capacidad, es_deposito, id_departamento)
SELECT 'Depósito', 'Depósito institucional', 1, true, NULL
WHERE NOT EXISTS (SELECT 1 FROM public.salas WHERE es_deposito);

-- El depósito no pertenece a ningún departamento
ALTER TABLE public.salas DROP CONSTRAINT IF EXISTS ck_salas_deposito_sin_departamento;
ALTER TABLE public.salas ADD CONSTRAINT ck_salas_deposito_sin_departamento
    CHECK (NOT es_deposito OR id_departamento IS NULL);

-- ---------------------------------------------------------------------
-- 2) MOTIVOS DE INACTIVO
--    descuenta = true  -> sale del inventario y del patrimonio (robo, pérdida)
--    descuenta = false -> queda registrado, no se usa (descompuesto, daño)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.motivos_inactivo (
    id_motivo        serial PRIMARY KEY,
    nombre_motivo    varchar(60) NOT NULL,
    descuenta        boolean NOT NULL DEFAULT false,
    aplica_equipos   boolean NOT NULL DEFAULT true,
    aplica_articulos boolean NOT NULL DEFAULT true,
    activo           boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_motivos_inactivo_nombre
    ON public.motivos_inactivo (lower(trim(nombre_motivo)));

INSERT INTO public.motivos_inactivo (nombre_motivo, descuenta, aplica_equipos, aplica_articulos)
SELECT v.n, v.d, v.e, v.a
FROM (VALUES ('Descompuesto',     false, true,  false),
             ('Daño irreparable', false, true,  true),
             ('Robo',             true,  true,  true),
             ('Pérdida',          true,  true,  true)) AS v(n, d, e, a)
WHERE NOT EXISTS (SELECT 1 FROM public.motivos_inactivo m
                  WHERE lower(trim(m.nombre_motivo)) = lower(v.n));

-- ---------------------------------------------------------------------
-- 3) EQUIPOS
-- ---------------------------------------------------------------------
ALTER TABLE public.equipos ADD COLUMN IF NOT EXISTS especificaciones     text;
ALTER TABLE public.equipos ADD COLUMN IF NOT EXISTS condicion_ingreso    varchar(15) NOT NULL DEFAULT 'Nuevo';
ALTER TABLE public.equipos ADD COLUMN IF NOT EXISTS costo                numeric(14,2) NOT NULL DEFAULT 0;
ALTER TABLE public.equipos ADD COLUMN IF NOT EXISTS fecha_ingreso        date NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE public.equipos ADD COLUMN IF NOT EXISTS id_motivo_inactivo   integer REFERENCES public.motivos_inactivo (id_motivo);
ALTER TABLE public.equipos ADD COLUMN IF NOT EXISTS fecha_inactivo       date;
ALTER TABLE public.equipos ADD COLUMN IF NOT EXISTS observacion_inactivo text;
ALTER TABLE public.equipos ADD COLUMN IF NOT EXISTS estado               varchar(30);

-- El código patrimonial deja de ser obligatorio (los equipos en el Depósito
-- todavía no lo tienen). Sigue siendo ÚNICO cuando existe.
ALTER TABLE public.equipos ALTER COLUMN codigo_patrimonial DROP NOT NULL;
UPDATE public.equipos SET codigo_patrimonial = NULL WHERE trim(codigo_patrimonial) = '';
UPDATE public.equipos SET nro_serie = NULL WHERE trim(nro_serie) = '';

-- Migración del estado viejo: antes el equipo dado de baja guardaba el motivo
-- como estado (Robo, Pérdida, Rotura...). Ahora: estado Activo/Inactivo + motivo.
INSERT INTO public.motivos_inactivo (nombre_motivo, descuenta, aplica_equipos, aplica_articulos)
SELECT DISTINCT trim(e.estado), false, true, false
FROM public.equipos e
WHERE e.estado IS NOT NULL AND trim(e.estado) NOT IN ('', 'Activo', 'Inactivo', 'Rotura')
  AND NOT EXISTS (SELECT 1 FROM public.motivos_inactivo m
                  WHERE lower(trim(m.nombre_motivo)) = lower(trim(e.estado)));

UPDATE public.equipos e
SET id_motivo_inactivo = m.id_motivo,
    fecha_inactivo     = COALESCE(e.fecha_inactivo, CURRENT_DATE),
    estado             = 'Inactivo'
FROM public.motivos_inactivo m
WHERE e.estado IS NOT NULL AND trim(e.estado) NOT IN ('', 'Activo', 'Inactivo')
  AND lower(trim(m.nombre_motivo)) =
      CASE WHEN trim(e.estado) = 'Rotura' THEN 'daño irreparable' ELSE lower(trim(e.estado)) END;

UPDATE public.equipos SET estado = 'Activo' WHERE estado IS NULL OR trim(estado) = '';
UPDATE public.equipos SET id_motivo_inactivo = (SELECT id_motivo FROM public.motivos_inactivo WHERE nombre_motivo = 'Descompuesto'),
                          fecha_inactivo = COALESCE(fecha_inactivo, CURRENT_DATE)
WHERE estado = 'Inactivo' AND id_motivo_inactivo IS NULL;

ALTER TABLE public.equipos ALTER COLUMN estado SET DEFAULT 'Activo';
ALTER TABLE public.equipos ALTER COLUMN estado SET NOT NULL;

ALTER TABLE public.equipos DROP CONSTRAINT IF EXISTS ck_equipos_estado;
ALTER TABLE public.equipos ADD CONSTRAINT ck_equipos_estado
    CHECK (estado IN ('Activo', 'Inactivo'));
ALTER TABLE public.equipos DROP CONSTRAINT IF EXISTS ck_equipos_inactivo_con_motivo;
ALTER TABLE public.equipos ADD CONSTRAINT ck_equipos_inactivo_con_motivo
    CHECK (estado = 'Activo' OR (id_motivo_inactivo IS NOT NULL AND fecha_inactivo IS NOT NULL));
ALTER TABLE public.equipos DROP CONSTRAINT IF EXISTS ck_equipos_condicion;
ALTER TABLE public.equipos ADD CONSTRAINT ck_equipos_condicion
    CHECK (condicion_ingreso IN ('Nuevo', 'Seminuevo', 'Usado'));
ALTER TABLE public.equipos DROP CONSTRAINT IF EXISTS ck_equipos_costo;
ALTER TABLE public.equipos ADD CONSTRAINT ck_equipos_costo CHECK (costo >= 0);

-- Número de serie único cuando existe (si hay duplicados viejos, avisa y sigue)
DO $$
BEGIN
    CREATE UNIQUE INDEX IF NOT EXISTS ux_equipos_nro_serie
        ON public.equipos (lower(trim(nro_serie))) WHERE nro_serie IS NOT NULL;
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'Hay números de serie repetidos en equipos: corregilos y volvé a ejecutar este bloque.';
END $$;

-- Equipos que no tenían ubicación pasan al Depósito
UPDATE public.equipos SET id_sala = (SELECT id_sala FROM public.salas WHERE es_deposito)
WHERE id_sala IS NULL;

-- Regla: fuera del Depósito, el código patrimonial es obligatorio.
CREATE OR REPLACE FUNCTION public.fn_equipos_validar() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_deposito boolean;
BEGIN
    NEW.codigo_patrimonial := NULLIF(trim(NEW.codigo_patrimonial), '');
    NEW.nro_serie          := NULLIF(trim(NEW.nro_serie), '');

    SELECT es_deposito INTO v_deposito FROM public.salas WHERE id_sala = NEW.id_sala;
    IF NEW.id_sala IS NULL THEN
        RAISE EXCEPTION 'Debe indicar la ubicación del equipo (sala o Depósito).';
    END IF;
    IF NOT COALESCE(v_deposito, false) AND NEW.codigo_patrimonial IS NULL THEN
        RAISE EXCEPTION 'El código patrimonial es obligatorio para ubicar el equipo en una sala.';
    END IF;
    IF NEW.estado = 'Activo' THEN
        NEW.id_motivo_inactivo   := NULL;
        NEW.fecha_inactivo       := NULL;
        NEW.observacion_inactivo := NULL;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS tg_equipos_validar ON public.equipos;
CREATE TRIGGER tg_equipos_validar
    BEFORE INSERT OR UPDATE ON public.equipos
    FOR EACH ROW EXECUTE FUNCTION public.fn_equipos_validar();

-- ---------------------------------------------------------------------
-- 4) CATEGORÍAS: vida útil para la depreciación
-- ---------------------------------------------------------------------
ALTER TABLE public.categorias ADD COLUMN IF NOT EXISTS vida_util_anios integer NOT NULL DEFAULT 5;
ALTER TABLE public.categorias DROP CONSTRAINT IF EXISTS ck_categorias_vida_util;
ALTER TABLE public.categorias ADD CONSTRAINT ck_categorias_vida_util CHECK (vida_util_anios > 0);

-- ---------------------------------------------------------------------
-- 5) REPUESTOS E INSUMOS
--    stock         = disponible para entregar
--    stock_danado  = registrado pero no se entrega (daño irreparable)
-- ---------------------------------------------------------------------
ALTER TABLE public.catalogo_insumos   ADD COLUMN IF NOT EXISTS stock_danado numeric(12,2) NOT NULL DEFAULT 0;
ALTER TABLE public.catalogo_insumos   ADD COLUMN IF NOT EXISTS ultimo_costo numeric(14,2) NOT NULL DEFAULT 0;
ALTER TABLE public.catalogo_repuestos ADD COLUMN IF NOT EXISTS stock_danado numeric(12,2) NOT NULL DEFAULT 0;
ALTER TABLE public.catalogo_repuestos ADD COLUMN IF NOT EXISTS ultimo_costo numeric(14,2) NOT NULL DEFAULT 0;

-- Stock nunca negativo (NOT VALID: no frena si quedaron negativos viejos,
-- pero impide cualquier negativo nuevo de acá en adelante).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_insumos_stock_no_negativo') THEN
        ALTER TABLE public.catalogo_insumos ADD CONSTRAINT ck_insumos_stock_no_negativo
            CHECK (stock >= 0 AND stock_danado >= 0) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_repuestos_stock_no_negativo') THEN
        ALTER TABLE public.catalogo_repuestos ADD CONSTRAINT ck_repuestos_stock_no_negativo
            CHECK (stock >= 0 AND stock_danado >= 0) NOT VALID;
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 6) REFERENCIALES NUEVOS
-- ---------------------------------------------------------------------
-- 6.1 Tipos de falla (generales o por categoría de equipo)
CREATE TABLE IF NOT EXISTS public.tipos_falla (
    id_tipo_falla     serial PRIMARY KEY,
    nombre_tipo_falla varchar(100) NOT NULL,
    id_categoria      integer REFERENCES public.categorias (id_categoria),  -- NULL = aplica a todas
    activo            boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_tipos_falla_nombre_categoria
    ON public.tipos_falla (lower(trim(nombre_tipo_falla)), COALESCE(id_categoria, 0));

INSERT INTO public.tipos_falla (nombre_tipo_falla)
SELECT v.n FROM (VALUES ('No enciende'), ('Pantalla en negro / sin imagen'), ('Funciona lento'),
                        ('Sin conexión a internet / red'), ('Se reinicia o se apaga solo'),
                        ('Ruido o sobrecalentamiento'), ('Teclado o mouse no responde'),
                        ('Error de sistema operativo o programa'), ('Daño físico visible'),
                        ('Otro')) AS v(n)
WHERE NOT EXISTS (SELECT 1 FROM public.tipos_falla t
                  WHERE lower(trim(t.nombre_tipo_falla)) = lower(v.n) AND t.id_categoria IS NULL);

-- 6.2 Catálogo de servicios (lo que hace el técnico al cerrar)
CREATE TABLE IF NOT EXISTS public.catalogo_servicios (
    id_servicio     serial PRIMARY KEY,
    nombre_servicio varchar(100) NOT NULL,
    descripcion     varchar(255),
    activo          boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_servicios_nombre
    ON public.catalogo_servicios (lower(trim(nombre_servicio)));

INSERT INTO public.catalogo_servicios (nombre_servicio)
SELECT v.n FROM (VALUES ('Limpieza interna y externa'), ('Formateo e instalación de sistema operativo'),
                        ('Instalación / actualización de programas'), ('Cambio de pieza o repuesto'),
                        ('Configuración de red'), ('Eliminación de virus'),
                        ('Revisión y diagnóstico'), ('Cambio de pasta térmica')) AS v(n)
WHERE NOT EXISTS (SELECT 1 FROM public.catalogo_servicios s
                  WHERE lower(trim(s.nombre_servicio)) = lower(v.n));

-- 6.3 Conceptos de entrada (por qué ingresó lo recibido)
CREATE TABLE IF NOT EXISTS public.conceptos_entrada (
    id_concepto     serial PRIMARY KEY,
    nombre_concepto varchar(60) NOT NULL,
    es_sistema      boolean NOT NULL DEFAULT false,  -- true = lo usa el sistema, no se edita
    activo          boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_conceptos_entrada_nombre
    ON public.conceptos_entrada (lower(trim(nombre_concepto)));

INSERT INTO public.conceptos_entrada (nombre_concepto, es_sistema)
SELECT v.n, v.s FROM (VALUES ('Donación', false), ('Compra', false),
                             ('Reposición', true), ('Transferencia', false),
                             ('Otro', false)) AS v(n, s)
WHERE NOT EXISTS (SELECT 1 FROM public.conceptos_entrada c
                  WHERE lower(trim(c.nombre_concepto)) = lower(v.n));

-- ---------------------------------------------------------------------
-- 7) TICKET: tipo de falla del catálogo (la columna de texto vieja queda
--    para los tickets anteriores)
-- ---------------------------------------------------------------------
ALTER TABLE public.ticket ADD COLUMN IF NOT EXISTS id_tipo_falla integer
    REFERENCES public.tipos_falla (id_tipo_falla);

-- ---------------------------------------------------------------------
-- 8) ROL NUEVO
-- ---------------------------------------------------------------------
INSERT INTO public.roles (nombre_rol)
SELECT 'Encargado de depósito'
WHERE NOT EXISTS (SELECT 1 FROM public.roles WHERE lower(trim(nombre_rol)) = 'encargado de depósito');

-- ---------------------------------------------------------------------
-- Usuario que hace el cambio: la aplicación lo informa en cada request
-- (config/conexion.jsp -> set_config('cta.id_usuario', ...)).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_usuario_actual() RETURNS integer
LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('cta.id_usuario', true), '')::integer
$$;

-- ---------------------------------------------------------------------
-- 9) HISTORIAL DE UBICACIÓN DE EQUIPOS (automático)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.historial_ubicacion_equipo (
    id_historial    serial PRIMARY KEY,
    id_equipo       integer NOT NULL REFERENCES public.equipos (id_equipo),
    id_sala_origen  integer REFERENCES public.salas (id_sala),
    id_sala_destino integer NOT NULL REFERENCES public.salas (id_sala),
    id_usuario      integer REFERENCES public.usuarios (id_usuario),
    fecha           timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacion     varchar(255)
);
CREATE INDEX IF NOT EXISTS ix_historial_ubicacion_equipo ON public.historial_ubicacion_equipo (id_equipo, fecha);

CREATE OR REPLACE FUNCTION public.fn_equipos_historial_ubicacion() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.historial_ubicacion_equipo (id_equipo, id_sala_origen, id_sala_destino, id_usuario, observacion)
        VALUES (NEW.id_equipo, NULL, NEW.id_sala, public.fn_usuario_actual(), 'Alta del equipo');
    ELSIF NEW.id_sala IS DISTINCT FROM OLD.id_sala THEN
        INSERT INTO public.historial_ubicacion_equipo (id_equipo, id_sala_origen, id_sala_destino, id_usuario)
        VALUES (NEW.id_equipo, OLD.id_sala, NEW.id_sala, public.fn_usuario_actual());
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS tg_equipos_historial_ubicacion ON public.equipos;
CREATE TRIGGER tg_equipos_historial_ubicacion
    AFTER INSERT OR UPDATE OF id_sala ON public.equipos
    FOR EACH ROW EXECUTE FUNCTION public.fn_equipos_historial_ubicacion();

-- Punto de partida: ubicación actual de los equipos que ya existen
INSERT INTO public.historial_ubicacion_equipo (id_equipo, id_sala_origen, id_sala_destino, observacion)
SELECT e.id_equipo, NULL, e.id_sala, 'Ubicación inicial (migración fase 1)'
FROM public.equipos e
WHERE e.id_sala IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.historial_ubicacion_equipo h WHERE h.id_equipo = e.id_equipo);

-- ---------------------------------------------------------------------
-- 10) AUDITORÍA (automática): quién cambió qué, valor anterior y nuevo.
--     Funciona aunque alguien modifique la base por fuera del sistema.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.auditoria (
    id_auditoria     bigserial PRIMARY KEY,
    tabla            varchar(60) NOT NULL,
    id_registro      integer,
    operacion        varchar(10) NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos     jsonb,
    id_usuario       integer,
    usuario_bd       varchar(60) NOT NULL DEFAULT current_user,
    fecha            timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_auditoria_tabla_registro ON public.auditoria (tabla, id_registro, fecha);

CREATE OR REPLACE FUNCTION public.fn_auditoria() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_old jsonb;
    v_new jsonb;
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN v_old := to_jsonb(OLD); END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN v_new := to_jsonb(NEW); END IF;

    IF TG_OP = 'UPDATE' THEN
        -- Solo se guardan los campos que cambiaron
        SELECT jsonb_object_agg(o.key, o.value) INTO v_old
        FROM jsonb_each(to_jsonb(OLD)) o
        WHERE (to_jsonb(NEW) -> o.key) IS DISTINCT FROM o.value;
        SELECT jsonb_object_agg(n.key, n.value) INTO v_new
        FROM jsonb_each(to_jsonb(NEW)) n
        WHERE (to_jsonb(OLD) -> n.key) IS DISTINCT FROM n.value;
        IF v_new IS NULL THEN RETURN NEW; END IF;   -- no cambió nada
    END IF;

    INSERT INTO public.auditoria (tabla, id_registro, operacion, datos_anteriores, datos_nuevos, id_usuario)
    VALUES (TG_TABLE_NAME,
            (COALESCE(to_jsonb(NEW), to_jsonb(OLD)) ->> TG_ARGV[0])::integer,
            TG_OP, v_old, v_new, public.fn_usuario_actual());
    RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS tg_auditoria_equipos ON public.equipos;
CREATE TRIGGER tg_auditoria_equipos
    AFTER INSERT OR UPDATE OR DELETE ON public.equipos
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria('id_equipo');

DROP TRIGGER IF EXISTS tg_auditoria_insumos ON public.catalogo_insumos;
CREATE TRIGGER tg_auditoria_insumos
    AFTER INSERT OR UPDATE OR DELETE ON public.catalogo_insumos
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria('id_insumo');

DROP TRIGGER IF EXISTS tg_auditoria_repuestos ON public.catalogo_repuestos;
CREATE TRIGGER tg_auditoria_repuestos
    AFTER INSERT OR UPDATE OR DELETE ON public.catalogo_repuestos
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria('id_repuesto');

DROP TRIGGER IF EXISTS tg_auditoria_salas ON public.salas;
CREATE TRIGGER tg_auditoria_salas
    AFTER INSERT OR UPDATE OR DELETE ON public.salas
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria('id_sala');

COMMIT;

-- ---------------------------------------------------------------------
-- VERIFICACIÓN (ejecutar después, solo consulta)
-- ---------------------------------------------------------------------
-- Salas sin departamento (excepto el Depósito): asignarles uno desde "Salas"
SELECT id_sala, nombre_sala FROM public.salas WHERE id_departamento IS NULL AND NOT es_deposito;
-- Estado de los equipos después de la migración
SELECT e.estado, COALESCE(m.nombre_motivo, '-') AS motivo, count(*)
FROM public.equipos e LEFT JOIN public.motivos_inactivo m ON m.id_motivo = e.id_motivo_inactivo
GROUP BY 1, 2 ORDER BY 1, 2;
