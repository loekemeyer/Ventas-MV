-- Caja y Stock: tablas que el front (index.html) ya usa pero que nunca
-- tuvieron migración. Sin estas tablas (o sin policy anon), los insert de
-- movimientos de caja fallan y "no se guardan".
-- Idempotente: se puede correr varias veces sin romper nada.

-- ====== Movimientos de caja (gastos / retiros / ajustes) ======
create table if not exists caja_movimientos (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  socia_id smallint references socias(id),
  fecha date,
  tipo text not null default 'gasto',
  concepto text,
  monto numeric(12,2) not null default 0,
  moneda text not null default 'ARS'
);

-- Si la tabla se creó antes con un CHECK inline, Postgres lo nombró
-- caja_movimientos_tipo_check (auto). Hay que dropear ESE además del _chk:
-- si no, la constraint vieja (sin 'ajuste') sigue viva y bloquea los ajustes.
alter table caja_movimientos
  drop constraint if exists caja_movimientos_tipo_chk;
alter table caja_movimientos
  drop constraint if exists caja_movimientos_tipo_check;
alter table caja_movimientos
  add constraint caja_movimientos_tipo_chk check (tipo in ('gasto','retiro','ajuste'));

alter table caja_movimientos
  drop constraint if exists caja_movimientos_moneda_chk;
alter table caja_movimientos
  drop constraint if exists caja_movimientos_moneda_check;
alter table caja_movimientos
  add constraint caja_movimientos_moneda_chk check (moneda in ('ARS','USD'));

create index if not exists caja_mov_fecha_idx on caja_movimientos (fecha desc);
create index if not exists caja_mov_socia_idx on caja_movimientos (socia_id);

-- ====== Ingresos de stock (prendas) ======
create table if not exists stock_ingresos (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  socia_id smallint references socias(id),
  fecha date,
  prenda text,
  material text,
  color text,
  talle text,
  cantidad integer not null default 1,
  proveedor text,
  costo_fabian numeric(12,2),
  costo_material numeric(12,2),
  costo_corte numeric(12,2),
  costo_confeccion numeric(12,2),
  costo_otros numeric(12,2),
  notas text
);

create index if not exists stock_ing_fecha_idx on stock_ingresos (fecha desc);
create index if not exists stock_ing_socia_idx on stock_ingresos (socia_id);

-- ====== RLS + policy anon (igual que ventas/socias) ======
alter table caja_movimientos enable row level security;
alter table stock_ingresos   enable row level security;

drop policy if exists "anon all" on caja_movimientos;
drop policy if exists "anon all" on stock_ingresos;

create policy "anon all" on caja_movimientos for all to anon using (true) with check (true);
create policy "anon all" on stock_ingresos   for all to anon using (true) with check (true);
