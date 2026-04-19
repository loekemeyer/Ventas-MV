-- Trigger that invokes the send-push Edge Function on INSERT in ventas.
-- Uses the pg_net HTTP client.

create or replace function public.notify_on_venta_insert()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  req_id bigint;
begin
  select net.http_post(
    url     := 'https://__PROJECT_REF__.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer __SERVICE_ROLE__'
    ),
    body    := jsonb_build_object('record', to_jsonb(NEW)),
    timeout_milliseconds := 5000
  ) into req_id;
  return NEW;
end;
$fn$;

drop trigger if exists venta_push_trigger on public.ventas;
create trigger venta_push_trigger
after insert on public.ventas
for each row
execute function public.notify_on_venta_insert();
