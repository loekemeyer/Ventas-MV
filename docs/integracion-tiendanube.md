# Integración TiendaNube → Ventas MV

**Estado:** planeada, no implementada (guardada para el futuro).
**Fecha plan:** 2026-04-18

## Objetivo
Que los pedidos realizados en la tienda online de TiendaNube (Nuvemshop) de MV Leather Studio entren automáticamente en la base de Supabase y disparen el mismo flujo que una venta cargada a mano (push a las socias, seguimiento de estado, Stats, etc.).

## Arquitectura recomendada (Opción A — webhook)

```
TiendaNube (nueva orden)
    ↓ POST webhook (solo {event, store_id, order_id})
Edge Function `tiendanube-webhook` en Supabase
    ↓ GET /v1/{store_id}/orders/{order_id} con Bearer token
TiendaNube API → order completa
    ↓ mapear campos
INSERT en `public.ventas`
    ↓ trigger existente
Edge Function `send-push` → push iOS a las socias
```

### Alternativa B — polling
Cron cada 15 minutos que consulta pedidos nuevos y los inserta. Más simple pero no es tiempo real. Quedaría como fallback si el webhook falla por autenticación o quota.

## Lo que hay que hacer

1. **Crear "socia virtual"** para los pedidos de la web:
   ```sql
   insert into socias (nombre) values ('Tienda Online');
   -- socia_id = 4
   ```

2. **Generar Access Token en TiendaNube:**
   - Panel TN → "Mi Nuvem" → "Aplicaciones" → "API / Integraciones"
   - Generar Personal Access Token
   - Anotar `store_id` (numérico)

3. **Guardar secrets en Supabase:**
   ```
   TIENDANUBE_STORE_ID=<numero>
   TIENDANUBE_ACCESS_TOKEN=<token>
   ```

4. **Deployar Edge Function `tiendanube-webhook`:**
   - Endpoint público (verify_jwt=false)
   - Valida HMAC del header `X-Linkedstore-Hmac-Sha256` (compartido con TN)
   - Parsea `{event, store_id, id}` del body
   - Si el event es `order/created` o `order/paid`:
     - Fetch `GET https://api.tiendanube.com/v1/{store_id}/orders/{id}` con `Authentication: bearer <token>` y `User-Agent: <app-name> (<email>)`
     - Mapear campos (ver abajo)
     - `upsert` en `ventas` con `onConflict=external_id` para evitar duplicados si TN reenvía

5. **Configurar webhook en TiendaNube** apuntando a la URL de la Edge Function:
   ```
   POST https://hkdirqgkauenehvorweb.supabase.co/functions/v1/tiendanube-webhook
   Events: order/created, order/paid, order/updated, order/cancelled
   ```

## Schema — columna nueva a agregar

```sql
alter table ventas
  add column if not exists external_id text,
  add column if not exists origen text default 'manual';

create unique index if not exists ventas_external_id_idx
  on ventas (external_id) where external_id is not null;
```

- `external_id`: el ID del pedido en TiendaNube (p.ej. `"tn:12345"`). Evita doble insert si TN reenvía el webhook.
- `origen`: `'manual' | 'tiendanube'`. Útil para filtrar y separar stats.

## Mapeo de campos

| TiendaNube (order) | ventas (Supabase) | Notas |
|---|---|---|
| `id` | `external_id` (prefix `tn:`) | Dedupe |
| `contact_name` | `cliente` | Si viene split en `first_name`+`last_name`, concatenar |
| `contact_phone` / `shipping_phone` | `telefono` | |
| `products[0].name` | `prenda` | Si hay varios productos, concatenar con " + " |
| `products[0].variant_values` | `color`, `talle` | Según qué variantes use cada producto (mirá nombres de atributos en cada tienda) |
| `total` | `importe` | Número sin símbolo |
| `currency` | `moneda` | `"ARS"` o `"USD"` (TN devuelve ISO code) |
| `created_at` | `fecha` | Convertir a `YYYY-MM-DD` |
| `payment_details.method` | `forma_pago` | Mapear: "cash"→Efectivo, "wire_transfer"→Transferencia, otro→Otro |
| — | `socia_id` | Fijo en **4** (Tienda Online) |
| — | `estado` | Según evento: `order/created`→Recepcionado, `order/paid`→Pagado a Fabian (o "Pedido"), `order/packed`/`fulfilled`→Entregado |
| `shipping_status`=`fulfilled` → | `entregado_at` = now() | Para que demora se calcule bien |

## Push notification

El trigger existente `venta_push_trigger` dispara `send-push` en cualquier INSERT — esto ya funciona. Las socias recibirán:

**"Tienda Online cargó una venta"**
*"Juan Pérez — $45.000"*

Si querés diferenciar push de web vs manual, se puede editar `send-push/index.ts` para que cuando `socia_id=4` use un título distinto (ej: "🛒 Nueva venta en la web").

## Costos
**Gratis.** Supabase Free Tier cubre las invocaciones de Edge Function + DB + Realtime. TiendaNube no cobra extra por API/webhooks (incluidos en cualquier plan pago).

## Referencias API

- Docs TN: https://tiendanube.github.io/api-documentation
- Webhooks: https://tiendanube.github.io/api-documentation/resources/webhook
- Orders: https://tiendanube.github.io/api-documentation/resources/order
- Base URL: `https://api.tiendanube.com/v1/{store_id}`
- Rate limit: 40 req / 10s / token
- Required headers:
  - `Authentication: bearer <access_token>`
  - `User-Agent: VentasMV (loekemeyer.n8n@gmail.com)`

## Paso 0 que falta hoy
- Que la usuaria genere el Access Token en su panel TN
- Compartir el `store_id` y el token
- Ahí arrancamos con la migración de schema + Edge Function + webhook registration
