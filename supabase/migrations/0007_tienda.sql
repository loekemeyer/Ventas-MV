-- ============================================================================
-- Tienda pública (storefront) + integración de pedidos web con el admin
-- ----------------------------------------------------------------------------
-- Agrega:
--   * productos       -> catálogo que administra el panel y muestra la tienda
--   * tienda_config   -> ajustes de la tienda (WhatsApp, envío, textos, MP)
--   * ventas.origen / external_id / pedido_json / pago_estado
--   * socia "Tienda Online" (id 4) para que los pedidos web caigan en Seguimiento
-- Idempotente: se puede correr varias veces sin romper nada.
-- ============================================================================

-- ====== Socia virtual para los pedidos de la web ======
insert into socias (nombre) values ('Tienda Online')
on conflict (nombre) do nothing;

-- ====== Catálogo de productos ======
create table if not exists productos (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  nombre text not null,
  descripcion text,
  categoria text,                 -- Campera, Tapado, Chaleco, Accesorio...
  material text,                  -- Oveja / Vaca / Gamuza
  colores text[] not null default '{}',
  talles text[] not null default '{}',
  precio numeric(12,2) not null default 0,
  precio_anterior numeric(12,2),  -- opcional, para mostrar % off
  moneda text not null default 'ARS',
  imagenes text[] not null default '{}',   -- URLs de fotos
  stock integer,                  -- opcional (null = sin control de stock)
  destacado boolean not null default false,
  activo boolean not null default true,
  orden integer not null default 0,
  slug text
);

alter table productos
  drop constraint if exists productos_moneda_chk;
alter table productos
  add constraint productos_moneda_chk check (moneda in ('ARS','USD'));

create index if not exists productos_activo_idx   on productos (activo);
create index if not exists productos_orden_idx    on productos (orden);
create index if not exists productos_categoria_idx on productos (categoria);

-- ====== Configuración de la tienda (key-value) ======
create table if not exists tienda_config (
  clave text primary key,
  valor text,
  updated_at timestamptz not null default now()
);

insert into tienda_config (clave, valor) values
  ('whatsapp',      '5491100000000'),
  ('nombre_tienda', 'MV Leather Studio'),
  ('envio_texto',   'Envíos a todo el país. Retiro sin cargo en el taller.'),
  ('anuncio',       'Cuero genuino argentino · Hecho a mano'),
  ('instagram',     'mvleatherstudio'),
  ('mp_activo',     '0')
on conflict (clave) do nothing;

-- ====== Integración de pedidos web con la tabla ventas existente ======
alter table ventas
  add column if not exists origen text not null default 'manual',
  add column if not exists external_id text,
  add column if not exists pedido_json jsonb,
  add column if not exists pago_estado text;   -- pendiente / pagado / rechazado

create unique index if not exists ventas_external_id_idx
  on ventas (external_id) where external_id is not null;
create index if not exists ventas_origen_idx on ventas (origen);

-- ====== RLS + policy anon (igual que el resto de las tablas) ======
alter table productos     enable row level security;
alter table tienda_config enable row level security;

drop policy if exists "anon all"  on productos;
drop policy if exists "anon read" on productos;
drop policy if exists "anon all"  on tienda_config;
drop policy if exists "anon read" on tienda_config;

-- La tienda pública (anon) sólo necesita LEER productos/config.
-- El admin usa el mismo anon key, así que le damos ALL para poder editar.
-- (El modelo de seguridad actual ya es anon-abierto en todas las tablas.)
create policy "anon all" on productos     for all to anon using (true) with check (true);
create policy "anon all" on tienda_config for all to anon using (true) with check (true);

-- ====== Realtime: cambios de catálogo en vivo ======
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'productos'
  ) then
    execute 'alter publication supabase_realtime add table productos';
  end if;
end $$;
