-- ============================================================================
-- SEED lote 2 — productos desde "FOTOS MV LEATHER" (All Year Basics)
-- Trench Marrón · Tucci Naranja · Camisa Rapsodia · Top Zipper · Capa Myriam
-- ----------------------------------------------------------------------------
-- Requiere la columna `coleccion` (migración 0010). Idempotente por nombre.
-- Precio en 0: completar en el panel (pestaña Tienda). Fotos en GitHub Pages.
-- ============================================================================

insert into productos
  (nombre, descripcion, categoria, material, colores, talles, precio, moneda, imagenes, coleccion, activo, destacado, orden)
select * from (values
  (
    'Trench Marrón',
    'Trench largo de cuero marrón, de silueta fluida y cinturón para marcar la cintura. Solapas amplias y caída impecable. Un clásico de entretiempo que se lleva abierto o cerrado.',
    'Tapado','Vaca',array['Chocolate']::text[],array['S','M','L','XL']::text[],0::numeric(12,2),'ARS',
    array['https://loekemeyer.github.io/Ventas-MV/assets/productos/trench-marron/trench-marron-1.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/trench-marron/trench-marron-2.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/trench-marron/trench-marron-3.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/trench-marron/trench-marron-4.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/trench-marron/trench-marron-5.jpg']::text[],
    'all-year', true, false, 13
  ),
  (
    'Tucci Naranja',
    'Bomber de cuero de corte cropped, en un naranja cálido que se roba la escena. Cuello alto con broches, bolsillos con tapa y puños elastizados. Una pieza statement para animarse al color.',
    'Campera','Vaca',array['Naranja']::text[],array['S','M','L','XL']::text[],0::numeric(12,2),'ARS',
    array['https://loekemeyer.github.io/Ventas-MV/assets/productos/tucci-naranja/tucci-naranja-1.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/tucci-naranja/tucci-naranja-2.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/tucci-naranja/tucci-naranja-3.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/tucci-naranja/tucci-naranja-4.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/tucci-naranja/tucci-naranja-5.jpg']::text[],
    'all-year', true, false, 14
  ),
  (
    'Camisa Rapsodia',
    'Camisa de cuero de silueta oversize y caída relajada. Se lleva abierta sobre una remera o cerrada como campera liviana. Negro absoluto, versátil todo el año.',
    'Campera','Vaca',array['Negro']::text[],array['S','M','L','XL']::text[],0::numeric(12,2),'ARS',
    array['https://loekemeyer.github.io/Ventas-MV/assets/productos/camisa-rapsodia/camisa-rapsodia-1.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/camisa-rapsodia/camisa-rapsodia-2.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/camisa-rapsodia/camisa-rapsodia-3.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/camisa-rapsodia/camisa-rapsodia-4.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/camisa-rapsodia/camisa-rapsodia-5.jpg']::text[],
    'all-year', true, false, 15
  ),
  (
    'Top Zipper',
    'Top de cuero sin mangas con cierre metálico al frente, en tono oxblood profundo. Entallado y moderno, se combina con sastrería o jeans para un look de noche.',
    'Chaleco','Vaca',array['Bordó']::text[],array['S','M','L','XL']::text[],0::numeric(12,2),'ARS',
    array['https://loekemeyer.github.io/Ventas-MV/assets/productos/top-zipper/top-zipper-1.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/top-zipper/top-zipper-2.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/top-zipper/top-zipper-3.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/top-zipper/top-zipper-4.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/top-zipper/top-zipper-5.jpg']::text[],
    'all-year', true, false, 16
  ),
  (
    'Capa Myriam',
    'Capa corta de cuero tipo wrap, con mangas amplias y cinto para atar a la cintura. Color bordó. Envolvente y con movimiento, aporta drama a cualquier base.',
    'Campera','Vaca',array['Bordó']::text[],array['S','M','L','XL']::text[],0::numeric(12,2),'ARS',
    array['https://loekemeyer.github.io/Ventas-MV/assets/productos/capa-myriam/capa-myriam-1.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/capa-myriam/capa-myriam-2.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/capa-myriam/capa-myriam-3.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/capa-myriam/capa-myriam-4.jpg','https://loekemeyer.github.io/Ventas-MV/assets/productos/capa-myriam/capa-myriam-5.jpg']::text[],
    'all-year', true, false, 17
  )
) as v(nombre, descripcion, categoria, material, colores, talles, precio, moneda, imagenes, coleccion, activo, destacado, orden)
where not exists (
  select 1 from productos p where lower(btrim(p.nombre)) = lower(btrim(v.nombre))
);
