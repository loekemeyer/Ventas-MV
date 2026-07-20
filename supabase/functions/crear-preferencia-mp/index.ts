// Edge Function: crear-preferencia-mp
// La tienda pública la llama para crear una preferencia de pago de Mercado Pago
// y devolver el init_point (URL del checkout). El token secreto nunca sale al front.
//
// Secrets necesarios (Supabase > Edge Functions > Secrets):
//   MP_ACCESS_TOKEN   -> Access Token de producción de Mercado Pago
//
// Deploy:  supabase functions deploy crear-preferencia-mp --no-verify-jwt
//
// Body esperado (JSON):
// {
//   "items":  [{ "title": "Campera Aviador", "quantity": 1, "unit_price": 189000 }],
//   "payer":  { "name": "Ana", "email": "ana@mail.com", "phone": "1150..." },
//   "external_reference": "<uuid de la venta en Supabase>",
//   "back_urls": { "success": "https://.../?pago=ok", "failure": "...", "pending": "..." }
// }

const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  if (!MP_ACCESS_TOKEN) {
    // La tienda usa esto como señal para caer al checkout por WhatsApp.
    return json({ error: "mp_no_configurado" }, 503);
  }

  let payload: any;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }

  const items = Array.isArray(payload?.items) ? payload.items : [];
  if (!items.length) return json({ error: "sin_items" }, 400);

  // Normalizar items al formato de Mercado Pago
  const mpItems = items.map((it: any) => ({
    title: String(it.title ?? "Producto").slice(0, 250),
    quantity: Math.max(1, parseInt(it.quantity, 10) || 1),
    unit_price: Math.round((Number(it.unit_price) || 0) * 100) / 100,
    currency_id: it.currency_id ?? "ARS",
  }));

  const preference: Record<string, unknown> = {
    items: mpItems,
    external_reference: payload?.external_reference ?? undefined,
    statement_descriptor: "MV LEATHER",
    binary_mode: false,
  };

  if (payload?.payer?.email || payload?.payer?.name) {
    preference.payer = {
      name: payload.payer.name ?? undefined,
      email: payload.payer.email ?? undefined,
      phone: payload.payer.phone ? { number: String(payload.payer.phone) } : undefined,
    };
  }
  if (payload?.back_urls) {
    preference.back_urls = payload.back_urls;
    preference.auto_return = "approved";
  }
  if (payload?.notification_url) {
    preference.notification_url = payload.notification_url;
  }

  try {
    const res = await fetch("https://api.mercadopago.com/checkout/preferences", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${MP_ACCESS_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(preference),
    });
    const data = await res.json();
    if (!res.ok) {
      return json({ error: "mp_error", detail: data }, 502);
    }
    return json({
      id: data.id,
      init_point: data.init_point,
      sandbox_init_point: data.sandbox_init_point,
    });
  } catch (e) {
    return json({ error: "fetch_failed", detail: String(e) }, 502);
  }
});
