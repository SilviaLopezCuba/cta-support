-- =====================================================================
-- CTA Support - Correcciones del recorrido QA (17/11/2026)
-- Ejecutar en pgAdmin sobre la base del proyecto.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Revisar duplicados ANTES de crear los índices únicos.
--    Si alguna consulta devuelve filas, unificá o renombrá esos registros
--    primero; si no, el CREATE UNIQUE INDEX correspondiente va a fallar.
-- ---------------------------------------------------------------------
SELECT 'marcas' AS tabla, lower(trim(nombre_marca)) AS valor, count(*) FROM public.marcas GROUP BY 2 HAVING count(*) > 1
UNION ALL
SELECT 'categorias', lower(trim(nombre_categoria)), count(*) FROM public.categorias GROUP BY 2 HAVING count(*) > 1
UNION ALL
SELECT 'especialidades', lower(trim(nombre_especialidad)), count(*) FROM public.especialidades GROUP BY 2 HAVING count(*) > 1
UNION ALL
SELECT 'roles', lower(trim(nombre_rol)), count(*) FROM public.roles GROUP BY 2 HAVING count(*) > 1
UNION ALL
SELECT 'salas', lower(trim(nombre_sala)), count(*) FROM public.salas GROUP BY 2 HAVING count(*) > 1
UNION ALL
SELECT 'unidades_medida', lower(trim(nombre_unidad)), count(*) FROM public.unidades_medida GROUP BY 2 HAVING count(*) > 1
UNION ALL
SELECT 'catalogo_repuestos', lower(trim(nombre)), count(*) FROM public.catalogo_repuestos GROUP BY 2 HAVING count(*) > 1
UNION ALL
SELECT 'catalogo_insumos', lower(trim(nombre)), count(*) FROM public.catalogo_insumos GROUP BY 2 HAVING count(*) > 1
UNION ALL
SELECT 'usuarios (id_persona)', id_persona::text, count(*) FROM public.usuarios GROUP BY 2 HAVING count(*) > 1;

-- ---------------------------------------------------------------------
-- 2) Índices únicos (sin distinguir mayúsculas ni espacios).
--    Son la red de seguridad de la base; los controladores ya validan antes.
-- ---------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS ux_marcas_nombre          ON public.marcas            (lower(trim(nombre_marca)));
CREATE UNIQUE INDEX IF NOT EXISTS ux_categorias_nombre      ON public.categorias        (lower(trim(nombre_categoria)));
CREATE UNIQUE INDEX IF NOT EXISTS ux_especialidades_nombre  ON public.especialidades    (lower(trim(nombre_especialidad)));
CREATE UNIQUE INDEX IF NOT EXISTS ux_roles_nombre           ON public.roles             (lower(trim(nombre_rol)));
CREATE UNIQUE INDEX IF NOT EXISTS ux_salas_nombre           ON public.salas             (lower(trim(nombre_sala)));
CREATE UNIQUE INDEX IF NOT EXISTS ux_unidades_nombre        ON public.unidades_medida   (lower(trim(nombre_unidad)));
CREATE UNIQUE INDEX IF NOT EXISTS ux_repuestos_nombre       ON public.catalogo_repuestos(lower(trim(nombre)));
CREATE UNIQUE INDEX IF NOT EXISTS ux_insumos_nombre         ON public.catalogo_insumos  (lower(trim(nombre)));
CREATE UNIQUE INDEX IF NOT EXISTS ux_usuarios_persona       ON public.usuarios          (id_persona);

-- ---------------------------------------------------------------------
-- 3) Mantenimientos programados que quedaron SIN equipos.
--    Primero se listan; después se les cargan todos los equipos de su sala.
-- ---------------------------------------------------------------------
SELECT m.id_mantenimiento, m.numero_mantenimiento, m.fecha_programada, s.nombre_sala
FROM public.mantenimientos_preventivos m
JOIN public.salas s ON s.id_sala = m.id_sala
WHERE m.estado IN ('Programado', 'En Proceso')
  AND NOT EXISTS (SELECT 1 FROM public.mantenimientos_preventivos_detalle d
                  WHERE d.id_mantenimiento = m.id_mantenimiento);

INSERT INTO public.mantenimientos_preventivos_detalle (id_mantenimiento, id_equipo)
SELECT m.id_mantenimiento, e.id_equipo
FROM public.mantenimientos_preventivos m
JOIN public.equipos e ON e.id_sala = m.id_sala
WHERE m.estado IN ('Programado', 'En Proceso')
  AND NOT EXISTS (SELECT 1 FROM public.mantenimientos_preventivos_detalle d
                  WHERE d.id_mantenimiento = m.id_mantenimiento);

-- ---------------------------------------------------------------------
-- 4) Registros que quedaron en estado Cancelado/Cancelada (solo consulta).
--    El sistema ya no permite anular; decidí qué hacer con estos.
-- ---------------------------------------------------------------------
SELECT 'ticket' AS tabla, count(*) FROM public.ticket WHERE estado = 'Cancelado'
UNION ALL
SELECT 'mantenimientos_preventivos', count(*) FROM public.mantenimientos_preventivos WHERE estado = 'Cancelado'
UNION ALL
SELECT 'solicitudes_compra', count(*) FROM public.solicitudes_compra WHERE estado = 'Cancelada';
