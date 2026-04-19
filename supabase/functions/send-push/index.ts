// Edge Function: send-push
// Trigger: Database Webhook (INSERT on public.ventas)
// Envía Web Push a todas las socias menos la autora.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Direct REST calls (evitamos importar @supabase/supabase-js: Edge Functions aquí
// corren con --no-remote y sin import_map no resuelven specifiers remotos).
async function restSelect(table: string, query: string): Promise<any[]> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}`, {
    headers: {
      apikey: SERVICE_ROLE,
      Authorization: `Bearer ${SERVICE_ROLE}`,
      Accept: "application/json",
    },
  });
  if (!res.ok) throw new Error(`REST ${table} ${res.status}: ${await res.text()}`);
  return await res.json();
}
async function restDelete(table: string, query: string): Promise<void> {
  await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}`, {
    method: "DELETE",
    headers: {
      apikey: SERVICE_ROLE,
      Authorization: `Bearer ${SERVICE_ROLE}`,
    },
  });
}
const VAPID_PUBLIC = Deno.env.get("VAPID_PUBLIC_KEY")!;
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY")!;
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") ?? "mailto:admin@example.com";

// ---------- utilidades base64url ----------
function b64urlEncode(buf: Uint8Array): string {
  let s = btoa(String.fromCharCode(...buf));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64urlDecode(s: string): Uint8Array {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
function concatBytes(...parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let off = 0;
  for (const p of parts) { out.set(p, off); off += p.length; }
  return out;
}

// ---------- VAPID JWT (ES256) ----------
async function importVapidKey(pub: string, priv: string): Promise<CryptoKey> {
  const pubRaw = b64urlDecode(pub);
  const x = pubRaw.slice(1, 33);
  const y = pubRaw.slice(33, 65);
  const d = b64urlDecode(priv);
  const jwk: JsonWebKey = {
    kty: "EC",
    crv: "P-256",
    x: b64urlEncode(x),
    y: b64urlEncode(y),
    d: b64urlEncode(d),
    ext: true,
  };
  return await crypto.subtle.importKey(
    "jwk", jwk,
    { name: "ECDSA", namedCurve: "P-256" },
    false, ["sign"],
  );
}

async function buildVapidHeader(audience: string): Promise<string> {
  const header = { typ: "JWT", alg: "ES256" };
  const payload = {
    aud: audience,
    exp: Math.floor(Date.now() / 1000) + 12 * 3600,
    sub: VAPID_SUBJECT,
  };
  const enc = new TextEncoder();
  const headerB64 = b64urlEncode(enc.encode(JSON.stringify(header)));
  const payloadB64 = b64urlEncode(enc.encode(JSON.stringify(payload)));
  const toSign = enc.encode(`${headerB64}.${payloadB64}`);
  const key = await importVapidKey(VAPID_PUBLIC, VAPID_PRIVATE);
  const sig = new Uint8Array(await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key, toSign,
  ));
  const jwt = `${headerB64}.${payloadB64}.${b64urlEncode(sig)}`;
  return `vapid t=${jwt}, k=${VAPID_PUBLIC}`;
}

// ---------- HKDF + aes128gcm payload encryption (RFC 8291) ----------
async function hkdf(salt: Uint8Array, ikm: Uint8Array, info: Uint8Array, len: number): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", salt, { name: "HKDF" }, false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "HKDF", hash: "SHA-256", salt: salt, info: info },
    key, len * 8,
  );
  return new Uint8Array(bits);
}

// HKDF extract + expand separately to match Web Push RFC 8291 usage
async function hkdfExtractExpand(
  salt: Uint8Array, ikm: Uint8Array, info: Uint8Array, len: number,
): Promise<Uint8Array> {
  // HMAC-SHA256 as extract
  const saltKey = await crypto.subtle.importKey("raw", salt, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const prkBuf = await crypto.subtle.sign("HMAC", saltKey, ikm);
  const prk = new Uint8Array(prkBuf);
  // Expand (one block, since our outputs are <= 32 bytes)
  const prkKey = await crypto.subtle.importKey("raw", prk, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const t = await crypto.subtle.sign("HMAC", prkKey, concatBytes(info, new Uint8Array([0x01])));
  return new Uint8Array(t).slice(0, len);
}

interface Subscription { endpoint: string; p256dh: string; auth: string; }

async function encryptPayload(sub: Subscription, plaintext: Uint8Array): Promise<{ body: Uint8Array; }> {
  // Ephemeral EC key pair
  const ephKeyPair = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"],
  ) as CryptoKeyPair;
  const ephPubJwk = await crypto.subtle.exportKey("jwk", ephKeyPair.publicKey);
  const ephPubRaw = concatBytes(
    new Uint8Array([0x04]),
    b64urlDecode(ephPubJwk.x!),
    b64urlDecode(ephPubJwk.y!),
  );

  // User public key (uncompressed)
  const userPubRaw = b64urlDecode(sub.p256dh);
  const userX = userPubRaw.slice(1, 33);
  const userY = userPubRaw.slice(33, 65);
  const userPub = await crypto.subtle.importKey("jwk", {
    kty: "EC", crv: "P-256",
    x: b64urlEncode(userX), y: b64urlEncode(userY), ext: true,
  }, { name: "ECDH", namedCurve: "P-256" }, false, []);

  const sharedBits = await crypto.subtle.deriveBits(
    { name: "ECDH", public: userPub }, ephKeyPair.privateKey, 256,
  );
  const shared = new Uint8Array(sharedBits);

  const auth = b64urlDecode(sub.auth);
  const salt = crypto.getRandomValues(new Uint8Array(16));

  // RFC 8291: PRK_key = HKDF(salt=auth, ikm=ecdh, info="WebPush: info\0" || ua_public || as_public, 32)
  const keyInfo = concatBytes(
    new TextEncoder().encode("WebPush: info\0"),
    userPubRaw,
    ephPubRaw,
  );
  const ikm = await hkdfExtractExpand(auth, shared, keyInfo, 32);

  // CEK = HKDF(salt=salt, ikm=ikm, info="Content-Encoding: aes128gcm\0", 16)
  const cek = await hkdfExtractExpand(salt, ikm, new TextEncoder().encode("Content-Encoding: aes128gcm\0"), 16);
  // NONCE = HKDF(salt=salt, ikm=ikm, info="Content-Encoding: nonce\0", 12)
  const nonce = await hkdfExtractExpand(salt, ikm, new TextEncoder().encode("Content-Encoding: nonce\0"), 12);

  // Plaintext + 0x02 padding delimiter (last record)
  const padded = concatBytes(plaintext, new Uint8Array([0x02]));

  const cekKey = await crypto.subtle.importKey("raw", cek, { name: "AES-GCM" }, false, ["encrypt"]);
  const ctBuf = await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, cekKey, padded);
  const ct = new Uint8Array(ctBuf);

  // aes128gcm header: salt(16) || rs(4, big-endian, typically 4096) || idlen(1) || keyid(keyid bytes=ephemeral pubkey)
  const rs = 4096;
  const rsBytes = new Uint8Array([ (rs>>>24)&0xff, (rs>>>16)&0xff, (rs>>>8)&0xff, rs&0xff ]);
  const keyid = ephPubRaw; // 65 bytes
  const header = concatBytes(
    salt,
    rsBytes,
    new Uint8Array([keyid.length]),
    keyid,
  );

  return { body: concatBytes(header, ct) };
}

async function sendPushTo(sub: Subscription, jsonPayload: string): Promise<Response> {
  const payload = new TextEncoder().encode(jsonPayload);
  const { body } = await encryptPayload(sub, payload);
  const url = new URL(sub.endpoint);
  const audience = `${url.protocol}//${url.host}`;
  const authHeader = await buildVapidHeader(audience);
  return await fetch(sub.endpoint, {
    method: "POST",
    headers: {
      "Authorization": authHeader,
      "Content-Encoding": "aes128gcm",
      "Content-Type": "application/octet-stream",
      "TTL": "86400",
      "Urgency": "high",
    },
    body,
  });
}

// ---------- formato importe ----------
function fmtMoney(v: any): string {
  const n = typeof v === "number" ? v : parseFloat(v);
  if (!isFinite(n)) return "";
  try {
    return "$" + n.toLocaleString("es-AR", { minimumFractionDigits: 0, maximumFractionDigits: 0 });
  } catch {
    return "$" + Math.round(n).toString();
  }
}

// ---------- handler ----------
Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  let event: any;
  try {
    event = await req.json();
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }

  const row = event?.record ?? event?.new ?? event;
  if (!row || !row.socia_id || !row.id) {
    return new Response(JSON.stringify({ skipped: "no row/socia_id" }), { status: 200 });
  }

  // Lookup socia nombre
  let autorNombre = "Alguien";
  try {
    const sociaRows = await restSelect("socias", `select=nombre&id=eq.${row.socia_id}`);
    if (sociaRows[0]?.nombre) autorNombre = sociaRows[0].nombre;
  } catch (_) { /* ignore */ }

  // Lookup subscriptions of OTHER socias
  let subs: any[] = [];
  try {
    subs = await restSelect("push_subscriptions", `select=endpoint,p256dh,auth&socia_id=neq.${row.socia_id}`);
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
  if (subs.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
  }

  const clienteTxt = (row.cliente ?? "").toString().trim() || "sin nombre";
  const importeTxt = row.importe != null ? fmtMoney(row.importe) : "";
  const title = `${autorNombre} cargó una venta`;
  const body = importeTxt
    ? `${clienteTxt} — ${importeTxt}`
    : clienteTxt;
  const payload = JSON.stringify({ v: row.id, t: title, b: body });

  const results = await Promise.allSettled(subs.map(async (s: any) => {
    try {
      const res = await sendPushTo(s, payload);
      if (res.status === 404 || res.status === 410) {
        await restDelete("push_subscriptions", `endpoint=eq.${encodeURIComponent(s.endpoint)}`);
        return { endpoint: s.endpoint, status: res.status, cleaned: true };
      }
      return { endpoint: s.endpoint, status: res.status };
    } catch (e) {
      return { endpoint: s.endpoint, error: String(e) };
    }
  }));

  return new Response(JSON.stringify({
    sent: results.length,
    results: results.map(r => r.status === "fulfilled" ? r.value : { error: String(r.reason) }),
  }), { status: 200, headers: { "content-type": "application/json" } });
});
