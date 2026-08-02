-- ============================================================================
-- Colección por producto: permite agrupar productos en el drop-down "Shop All"
-- de la tienda (ej. Foundations · AW 26 / All Year Basics).
-- ----------------------------------------------------------------------------
-- La tienda (index.html) ya lee `productos.coleccion` (un slug). Si un producto
-- no tiene colección, cae por defecto en 'foundations-aw26'. El panel (admin.html)
-- tiene un selector para elegirla al crear/editar cada producto.
-- Slugs usados por la tienda:
--   'foundations-aw26'  -> "Foundations · AW 26" (temporada actual, default)
--   'all-year'          -> "All Year Basics"     (piezas de todo el año)
-- Idempotente.
-- ============================================================================

alter table productos
  add column if not exists coleccion text not null default 'foundations-aw26';

create index if not exists productos_coleccion_idx on productos (coleccion);
