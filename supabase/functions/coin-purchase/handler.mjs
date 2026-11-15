const cors = {'access-control-allow-origin': '*', 'access-control-allow-headers': 'authorization, apikey, x-client-info, content-type', 'access-control-allow-methods': 'POST, OPTIONS'};
const uuid = /^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$/i;
function reply(data, status = 200) {
  return new Response(JSON.stringify(data), {status, headers: {...cors, 'content-type': 'application/json', 'cache-control': 'no-store'}});
}
async function body(req) {
  const reader = req.body?.getReader();
  if (!reader) throw Error('Invalid body');
  let bytes = 0, text = '';
  const decoder = new TextDecoder();
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      bytes += chunk.value.byteLength;
      if (bytes > 1024) throw Error('Body too large');
      text += decoder.decode(chunk.value, {stream: true});
    }
    return JSON.parse(text + decoder.decode());
  } finally { await reader.cancel(); }
}
export function createHandler({authorize, createOrder, getOrder, attach, fail, credit, provider, configured}) {
  return async req => {
    if (req.method === 'OPTIONS') return new Response(null, {headers: cors});
    if (req.method !== 'POST') return reply({error: 'method_not_allowed'}, 405);
    let user;
    try { user = await authorize(req.headers.get('authorization')); } catch { /* invalid session */ }
    if (!user) return reply({error: 'sign_in_required'}, 401);
    let input;
    try { input = await body(req); } catch { return reply({error: 'invalid_request'}, 400); }
    if (!input || typeof input !== 'object' || Array.isArray(input)) return reply({error: 'invalid_request'}, 400);
    if (input.action !== 'create' && input.action !== 'verify') return reply({error: 'invalid_request'}, 400);
    if (input.action === 'create' && (typeof input.plan !== 'string' || !/^[a-z]{1,30}$/.test(input.plan))) return reply({error: 'invalid_plan'}, 400);
    if (input.action === 'verify' && (typeof input.order !== 'string' || !uuid.test(input.order))) return reply({error: 'invalid_order'}, 400);
    try {
      if (input.action === 'create') {
        if (!configured) return reply({error: 'payments_unavailable'}, 503);
        const {order, created} = await createOrder(user, input.plan);
        if (order.user_id !== user.id) throw Error('Owner mismatch');
        if (!created) {
          if (order.status !== 'pending') return reply({error: 'checkout_preparing'}, 409);
          return reply({order: order.id, checkout_url: order.checkout_url});
        }
        try {
          const result = await provider.create(order);
          // Expose the checkout only after it has been persistently bound to this order.
          await attach(order.id, result.requestId, result.url);
          return reply({order: order.id, checkout_url: result.url});
        } catch {
          try { await fail(order.id); } catch { /* safe to retry after reservation expires */ }
          return reply({error: 'payments_unavailable'}, 503);
        }
      }
      const order = await getOrder(user, input.order);
      if (!order || order.user_id !== user.id) return reply({error: 'order_unavailable'}, 404);
      if (order.status === 'credited') return reply({status: 'credited', coins: order.coins});
      if (order.status !== 'pending') return reply({status: 'pending'});
      if (!configured) return reply({error: 'payments_unavailable'}, 503);
      const payment = await provider.verify(order);
      if (!payment) return reply({status: 'pending'});
      await credit(order, payment);
      return reply({status: 'credited', coins: order.coins});
    } catch { return reply({error: 'payment_check_unavailable'}, 503); }
  };
}
