-- ============================================================================
-- SEED lote 1 — productos nuevos desde "FOTOS MV LEATHER" (All Year Basics)
-- ----------------------------------------------------------------------------
-- Cómo usarlo:
--   1. Corré antes la migración 0010_coleccion.sql (agrega la columna `coleccion`).
--   2. Pegá este archivo en Supabase → SQL Editor → Run.
--   3. En el panel (pestaña Tienda) completá el PRECIO de cada uno (quedan en 0).
-- Idempotente: no duplica un producto si ya existe otro con el mismo nombre.
-- Fotos servidas por GitHub Pages: assets/productos/<slug>/<slug>-1..5.jpg
-- ============================================================================

insert into productos
  (nombre, descripcion, categoria, material, colores, talles, precio, moneda, imagenes, coleccion, activo, destacado, orden)
select * from (values
  (
    'Trench Classic Black',
    'Trench largo de cuero, sobrio y atemporal. Solapas amplias, puños con hebilla y cinturón del mismo cuero para marcar la silueta. Cae impecable, abierto o cerrado. Una pieza statement para el entretiempo y el frío.',
    'Tapado',
    'Vaca',
    array['Negro']::text[],
    array['S','M','L','XL']::text[],
    0::numeric(12,2),
    'ARS',
    array[
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/trench-black/trench-black-1.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/trench-black/trench-black-2.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/trench-black/trench-black-3.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/trench-black/trench-black-4.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/trench-black/trench-black-5.jpg'
    ]::text[],
    'all-year', true, false, 10
  ),
  (
    'Napalán',
    'Campera aviador de napa con detalles de corderito. Cuello, puños y ruedo en shearling, cierre metálico y hebillas de ajuste. Abriga de verdad, con una impronta atemporal.',
    'Camperas',
    'Oveja',
    array['Camel']::text[],
    array['S','M','L','XL']::text[],
    0::numeric(12,2),
    'ARS',
    array[
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/napalan/napalan-1.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/napalan/napalan-2.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/napalan/napalan-3.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/napalan/napalan-4.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/napalan/napalan-5.jpg'
    ]::text[],
    'all-year', true, false, 11
  ),
  (
    'Camisa Oveja',
    'Camisa-campera (overshirt) de cuero suave. Cuello camisero, botones a presión y bolsillos al pecho. Se lleva abierta sobre una remera o cerrada como campera liviana. Versátil todo el año.',
    'Camperas',
    'Vaca',
    array['Camel']::text[],
    array['S','M','L','XL']::text[],
    0::numeric(12,2),
    'ARS',
    array[
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/camisa-oveja/camisa-oveja-1.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/camisa-oveja/camisa-oveja-2.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/camisa-oveja/camisa-oveja-3.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/camisa-oveja/camisa-oveja-4.jpg',
      'https://loekemeyer.github.io/Ventas-MV/assets/productos/camisa-oveja/camisa-oveja-5.jpg'
    ]::text[],
    'all-year', true, false, 12
  )
) as v(nombre, descripcion, categoria, material, colores, talles, precio, moneda, imagenes, coleccion, activo, destacado, orden)
where not exists (
  select 1 from productos p where lower(btrim(p.nombre)) = lower(btrim(v.nombre))
);
