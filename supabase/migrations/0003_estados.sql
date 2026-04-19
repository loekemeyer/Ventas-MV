-- Tracking de estado de pedido
alter table ventas
  add column if not exists estado text not null default 'Recepcionado',
  add column if not exists hecho_por_fabian boolean,
  add column if not exists fecha_promesa_fabian date,
  add column if not exists quien_retira text;

create index if not exists ventas_estado_idx on ventas (estado);
