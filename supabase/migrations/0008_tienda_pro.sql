-- ============================================================================
-- Tienda PRO: login de clientas + funcionalidades tipo plan full de TiendaNube
-- ----------------------------------------------------------------------------
--   * cupones      -> códigos de descuento (%, monto fijo) con mínimo y vencimiento
--   * resenas      -> reseñas/estrellas de productos (moderables)
--   * newsletter   -> suscriptores al newsletter
--   * ventas.cliente_email / cliente_user_id / cupon / descuento
--   * tienda_config: envío gratis desde, costo de envío
-- El login de clientas usa Supabase Auth (Google) — no requiere tabla propia,
-- auth.users lo maneja Supabase. Habilitá el provider Google en el dashboard.
-- Idempotente.
-- ============================================================================

-- ====== Cupones de descuento ======
create table if not exists cupones (
  codigo text primary key,
  created_at timestamptz not null default now(),
  tipo text not null default 'porcentaje',   -- 'porcentaje' | 'fijo'
  valor numeric(12,2) not null default 0,     -- 10 (%) o 5000 ($)
  minimo numeric(12,2) not null default 0,    -- compra mínima para aplicar
  vence date,                                 -- null = sin vencimiento
  activo boolean not null default true,
  usos integer not null default 0,
  max_usos integer                            -- null = ilimitado
);

alter table cupones drop constraint if exists cupones_tipo_chk;
alter table cupones add constraint cupones_tipo_chk check (tipo in ('porcentaje','fijo'));

-- ====== Reseñas de productos ======
create table if not exists resenas (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  producto_id uuid references productos(id) on delete cascade,
  nombre text,
  rating smallint not null default 5,
  comentario text,
  aprobada boolean not null default true
);

alter table resenas drop constraint if exists resenas_rating_chk;
alter table resenas add constraint resenas_rating_chk check (rating between 1 and 5);
create index if not exists resenas_producto_idx on resenas (producto_id);

-- ====== Newsletter ======
create table if not exists newsletter (
  email text primary key,
  created_at timestamptz not null default now()
);

-- ====== Datos de cliente + descuento en ventas ======
alter table ventas
  add column if not exists cliente_email text,
  add column if not exists cliente_user_id uuid,
  add column if not exists cupon text,
  add column if not exists descuento numeric(12,2);

create index if not exists ventas_cliente_email_idx on ventas (lower(cliente_email));

-- ====== Config de envío ======
insert into tienda_config (clave, valor) values
  ('envio_gratis_desde', '0'),   -- 0 = sin umbral de envío gratis
  ('costo_envio',        '0')    -- informativo
on conflict (clave) do nothing;

-- ====== RLS + policy anon (modelo abierto, igual que el resto) ======
alter table cupones    enable row level security;
alter table resenas    enable row level security;
alter table newsletter enable row level security;

drop policy if exists "anon all" on cupones;
drop policy if exists "anon all" on resenas;
drop policy if exists "anon all" on newsletter;

create policy "anon all" on cupones    for all to anon using (true) with check (true);
create policy "anon all" on resenas    for all to anon using (true) with check (true);
create policy "anon all" on newsletter for all to anon using (true) with check (true);

-- Realtime opcional para reseñas (que aparezcan sin refrescar)
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'resenas'
  ) then
    execute 'alter publication supabase_realtime add table resenas';
  end if;
end $$;
