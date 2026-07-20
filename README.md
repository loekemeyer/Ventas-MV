# MV Leather Studio

Tienda online de camperas y prendas de cuero **+** panel de control interno, en una misma base de Supabase.

## Estructura

| Archivo | Qué es | Para quién |
|---|---|---|
| `index.html` | **Tienda pública** — catálogo, carrito y checkout (Mercado Pago + WhatsApp) | Clientas |
| `admin.html` | **Panel de control** — Cargar, Seguimiento de Pedidos, Tienda (catálogo), Caja, Stock y Estadística | Equipo MV (con contraseña) |

La tienda y el panel comparten el mismo proyecto Supabase, así que **los pedidos hechos en la web caen directo en "Seguimiento de Pedidos"** del panel (con la etiqueta 🛒 Web) y disparan la notificación push a las socias.

## Tienda pública (`index.html`)

- Catálogo en vivo desde Supabase (tabla `productos`, sólo los `activo`).
- Filtros por categoría, buscador, ficha de producto con galería, selector de color y talle.
- Carrito persistente (localStorage) y checkout.
- **Checkout:** guarda el pedido en Supabase y ofrece pagar con **Mercado Pago** (si está configurado) o coordinar por **WhatsApp** con el resumen del pedido listo.
- Guía de talles, cuidado del cuero, historia de marca, señales de confianza y botón flotante de WhatsApp.
- Responsive y con estética de marca de cuero (paleta cálida, tipografía serif).

## Panel de control (`admin.html`)

Todo lo que antes era "Ventas MV", más una pestaña nueva:

- **Tienda:** alta/baja/edición de productos (nombre, descripción, categoría, material, colores, talles, precio, precio anterior, fotos por URL, stock, destacado, activo/oculto) y ajustes de la tienda (WhatsApp de ventas, Instagram, frase de anuncio, texto de envíos, activar Mercado Pago).
- Acceso con contraseña (la misma app de siempre).

## Configuración

1. **Base de datos:** correr las migraciones de `supabase/migrations/` (la nueva es `0007_tienda.sql`, que crea `productos`, `tienda_config`, la socia *Tienda Online* y agrega columnas de pedido web a `ventas`).
2. **Mercado Pago (opcional):** deployar la Edge Function y cargar el token:
   ```
   supabase functions deploy crear-preferencia-mp --no-verify-jwt
   # Secret en Supabase > Edge Functions:
   MP_ACCESS_TOKEN=<access token de producción de Mercado Pago>
   ```
   Luego activar "Cobrar con Mercado Pago" en el panel (pestaña Tienda). Sin token, el checkout usa WhatsApp automáticamente.
3. **Cargar productos:** desde el panel → pestaña **Tienda** → ＋ Producto.

## Notas

- No requiere servidor propio: son archivos estáticos (ideal para GitHub Pages) + Supabase.
- El modelo de acceso a Supabase es `anon` abierto (igual que la app original); la contraseña del panel es una barrera de conveniencia, no seguridad fuerte.
