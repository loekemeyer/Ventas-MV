-- Moneda de la venta: ARS (pesos) o USD (dólares)
alter table ventas
  add column if not exists moneda text not null default 'ARS';

alter table ventas
  drop constraint if exists ventas_moneda_chk;
alter table ventas
  add constraint ventas_moneda_chk check (moneda in ('ARS','USD'));
