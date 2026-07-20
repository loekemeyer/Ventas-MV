-- ============================================================================
-- SEED: productos de ejemplo para la tienda, usando los NOMBRES de las ventas
--       ya cargadas en la tabla `ventas`.
-- ----------------------------------------------------------------------------
-- Cómo usarlo:
--   1. Corré antes las migraciones 0007_tienda.sql y 0008_tienda_pro.sql.
--   2. Pegá este archivo en Supabase → SQL Editor → Run.
--   3. Editá foto, descripción y precio de cada uno desde el panel (pestaña Tienda).
--
-- Qué hace:
--   - Toma cada prenda distinta que aparece en `ventas` y crea un producto con ese nombre.
--   - Junta los materiales, colores y talles que se usaron en esas ventas.
--   - Usa el importe promedio de esas ventas como precio inicial.
--   - Marca como "destacados" los 3 más vendidos.
-- Idempotente: no duplica un producto si ya existe otro con el mismo nombre.
-- ============================================================================

with ventas_norm as (
  select
    initcap(nullif(btrim(prenda), '')) as nombre,
    nullif(btrim(material), '')        as material,
    nullif(btrim(color), '')           as color,
    nullif(btrim(talle), '')           as talle,
    importe,
    coalesce(nullif(btrim(moneda), ''), 'ARS') as moneda
  from ventas
  where nullif(btrim(prenda), '') is not null
    and char_length(btrim(prenda)) between 2 and 60
),
agg as (
  select
    nombre,
    (array_agg(distinct material) filter (where material is not null))[1]                 as material,
    coalesce(array_agg(distinct color) filter (where color is not null), '{}')::text[]    as colores,
    coalesce(array_agg(distinct talle) filter (where talle is not null), '{}')::text[]    as talles,
    round(avg(importe) filter (where importe is not null and importe > 0))::numeric(12,2) as precio_prom,
    mode() within group (order by moneda)                                                 as moneda,
    count(*)                                                                              as ventas_cnt
  from ventas_norm
  group by nombre
)
insert into productos
  (nombre, descripcion, categoria, material, colores, talles, precio, moneda, activo, destacado, orden)
select
  a.nombre,
  'Pieza de cuero de nuestra colección, confeccionada a mano. (Producto de ejemplo: editá la foto, la descripción y el precio desde el panel.)',
  'Campera',
  a.material,
  a.colores,
  case when cardinality(a.talles) > 0 then a.talles else array['S','M','L','XL'] end,
  coalesce(nullif(a.precio_prom, 0), 150000),
  coalesce(a.moneda, 'ARS'),
  true,
  (row_number() over (order by a.ventas_cnt desc)) <= 3,        -- top 3 = destacados
  (row_number() over (order by a.ventas_cnt desc))::int
from agg a
where not exists (
  select 1 from productos p where lower(p.nombre) = lower(a.nombre)
)
order by a.ventas_cnt desc
limit 24;

-- Ver el resultado:
-- select nombre, material, colores, talles, precio, destacado from productos order by orden;
