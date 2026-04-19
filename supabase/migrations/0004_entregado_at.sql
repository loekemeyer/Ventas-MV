-- Timestamp del momento en que se marcó como Entregado (para calcular demoras)
alter table ventas
  add column if not exists entregado_at timestamptz;

create index if not exists ventas_entregado_at_idx on ventas (entregado_at)
  where entregado_at is not null;
