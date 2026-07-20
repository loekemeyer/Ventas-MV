-- ============================================================================
-- Media de portada: carrusel de fotos y videos gestionable desde el panel.
-- ----------------------------------------------------------------------------
-- La tienda muestra estos slides en el hero (arriba de todo). Cada slide puede
-- ser una imagen o un video (URL directa, ej: .jpg / .mp4 / .webm), con texto
-- y botón opcionales. Si no hay slides activos, la tienda usa el hero por defecto.
-- Idempotente.
-- ============================================================================

create table if not exists tienda_media (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  tipo text not null default 'imagen',   -- 'imagen' | 'video'
  url text not null,
  titulo text,
  subtitulo text,
  cta_texto text,                          -- texto del botón (opcional)
  cta_link text,                           -- destino del botón (ej '#tienda')
  orden integer not null default 0,
  activo boolean not null default true
);

alter table tienda_media drop constraint if exists tienda_media_tipo_chk;
alter table tienda_media add constraint tienda_media_tipo_chk check (tipo in ('imagen','video'));

create index if not exists tienda_media_orden_idx on tienda_media (orden);

alter table tienda_media enable row level security;
drop policy if exists "anon all" on tienda_media;
create policy "anon all" on tienda_media for all to anon using (true) with check (true);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'tienda_media'
  ) then
    execute 'alter publication supabase_realtime add table tienda_media';
  end if;
end $$;
