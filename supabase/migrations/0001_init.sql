-- Ventas MV: initial schema

create table if not exists socias (
  id smallserial primary key,
  nombre text not null unique,
  created_at timestamptz not null default now()
);

insert into socias (nombre) values ('Martu'), ('Baby'), ('Loqui')
on conflict (nombre) do nothing;

create table if not exists ventas (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  socia_id smallint not null references socias(id),
  fecha date,
  cliente text,
  telefono text,
  prenda text,
  material text,
  color text,
  talle text,
  importe numeric(12,2),
  forma_pago text,
  forma_pago_otro text,
  hombro_hombro numeric(6,2),
  largo_brazo numeric(6,2),
  busto numeric(6,2),
  cintura numeric(6,2),
  cadera numeric(6,2),
  largo_total numeric(6,2)
);

create index if not exists ventas_fecha_idx on ventas (fecha desc);
create index if not exists ventas_socia_idx on ventas (socia_id);

create table if not exists push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  socia_id smallint not null references socias(id),
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

create index if not exists push_subs_socia_idx on push_subscriptions (socia_id);

alter table socias enable row level security;
alter table ventas enable row level security;
alter table push_subscriptions enable row level security;

drop policy if exists "anon all" on socias;
drop policy if exists "anon all" on ventas;
drop policy if exists "anon all" on push_subscriptions;

create policy "anon all" on socias for all to anon using (true) with check (true);
create policy "anon all" on ventas for all to anon using (true) with check (true);
create policy "anon all" on push_subscriptions for all to anon using (true) with check (true);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ventas'
  ) then
    execute 'alter publication supabase_realtime add table ventas';
  end if;
end $$;
