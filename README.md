# MV Leather Studio

Tienda online de camperas y prendas de cuero **+** panel de control interno, en una misma base de Supabase.

## Estructura

| Archivo | Qué es | Para quién |
|---|---|---|
| `index.html` | **Tienda pública** — catálogo, carrito y checkout (Mercado Pago + WhatsApp) | Clientas |
| `admin.html` | **Panel de control** — Cargar, Seguimiento de Pedidos, Tienda (catálogo), Caja, Stock y Estadística | Equipo MV (con contraseña) |

La tienda y el panel comparten el mismo proyecto Supabase, así que **los pedidos hechos en la web caen directo en "Seguimiento de Pedidos"** del panel (con la etiqueta 🛒 Web) y disparan la notificación push a las socias.

## Tienda pública (`index.html`)

Funcionalidades tipo plan full de TiendaNube:

- **Catálogo** en vivo desde Supabase (sólo productos `activo`), con **filtros** por categoría y material, **orden** (destacados, novedades, precio ↑/↓) y **buscador**.
- **Ficha de producto** con galería, selector de color/talle, **cantidad**, estado de stock (badge "Agotado" + bloqueo de compra), **productos relacionados** y **URL propia compartible** (`?producto=slug`, con botón compartir nativo).
- **Login de clientas con Gmail** (Supabase Auth · Google): historial de "Mis pedidos" y checkout prellenado.
- **Favoritos / wishlist** (persistente) y **reseñas con estrellas** por producto.
- **Cupones de descuento** en el checkout (%, monto fijo, mínimo, vencimiento).
- **Envío gratis desde $X** con barra de progreso en el carrito.
- **Carrito** persistente + **checkout** que guarda el pedido en Supabase (`origen=web`) y ofrece **Mercado Pago** (si está configurado) o **WhatsApp** con el resumen listo.
- **Newsletter**, guía de talles, cuidado del cuero, historia de marca, señales de confianza y botón flotante de WhatsApp.
- **SEO**: Open Graph con imagen, Twitter cards, canonical y **datos estructurados JSON-LD** (`Store` + `Product` con rating).
- Responsive, PWA y con estética de marca de cuero; degradación elegante si Supabase/Mercado Pago no están disponibles.

## Panel de control (`admin.html`)

Todo lo que antes era "Ventas MV", más una pestaña nueva:

- **Tienda:** alta/baja/edición de productos (nombre, descripción, categoría, material, colores, talles, precio, precio anterior, fotos por URL, stock, destacado, activo/oculto) y ajustes de la tienda (WhatsApp de ventas, Instagram, frase de anuncio, texto de envíos, activar Mercado Pago).
- Acceso con contraseña (la misma app de siempre).

## Configuración

1. **Base de datos:** correr las migraciones de `supabase/migrations/` en orden. Las nuevas:
   - `0007_tienda.sql`: `productos`, `tienda_config`, socia *Tienda Online*, columnas de pedido web en `ventas`.
   - `0008_tienda_pro.sql`: `cupones`, `resenas`, `newsletter`, columnas de cliente/descuento en `ventas`, config de envío.
2. **Login con Gmail (Supabase Auth):** en el dashboard de Supabase → *Authentication → Providers → Google*, habilitar Google y cargar el Client ID/Secret (Google Cloud Console). En *Authentication → URL Configuration* agregar la URL del sitio como redirect (p. ej. `https://loekemeyer.github.io/Ventas-MV/`). Sin esto, el botón "Continuar con Google" no inicia sesión (el resto de la tienda funciona igual, como invitada).
3. **Mercado Pago (opcional):** deployar la Edge Function y cargar el token:
   ```
   supabase functions deploy crear-preferencia-mp --no-verify-jwt
   # Secret en Supabase > Edge Functions:
   MP_ACCESS_TOKEN=<access token de producción de Mercado Pago>
   ```
   Luego activar "Cobrar con Mercado Pago" en el panel (pestaña Tienda). Sin token, el checkout usa WhatsApp automáticamente.
4. **Cargar productos y cupones:** desde el panel → pestaña **Tienda** (＋ Producto, cupones, envío gratis, WhatsApp, etc.).

## Loop de mejoras automático

- `.claude/agents/mejoras-tienda.md` es un **agente auditor**: revisa la tienda y devuelve un backlog priorizado de mejoras (paridad TiendaNube + buenas prácticas). No edita, sólo propone.
- Una **rutina programada** corre el loop cada 8 hs: audita, implementa el próximo ítem del backlog de forma segura e incremental, lo verifica (syntax + smoke test en Chromium) y lo pushea a la branch de trabajo. Hace **una** mejora por corrida.
- Para pausar/ajustar el loop: gestionar la rutina "Loop de mejoras — Tienda MV Leather" (o pedirlo por chat).

## Notas

- No requiere servidor propio: son archivos estáticos (ideal para GitHub Pages) + Supabase.
- El modelo de acceso a Supabase es `anon` abierto (igual que la app original); la contraseña del panel es una barrera de conveniencia, no seguridad fuerte.
