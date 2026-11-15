import {createHandler} from './handler.mjs';
import {createProvider} from './provider.mjs';

const url = Deno.env.get('SUPABASE_URL')!;
const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const clientId = Deno.env.get('INSTAMOJO_CLIENT_ID');
const clientSecret = Deno.env.get('INSTAMOJO_CLIENT_SECRET');
async function api(path: string, key: string, authorization: string, body?: unknown) {
  const response = await fetch(`${url}${path}`, {
    method: body === undefined ? 'GET' : 'POST',
    headers: {apikey: key, authorization, 'content-type': 'application/json'},
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(15000), redirect: 'error',
  });
  if (!response.ok) throw Error('Request unavailable');
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}
const rpc = (name: string, body: unknown) => api(`/rest/v1/rpc/${name}`, service, `Bearer ${service}`, body);
Deno.serve(createHandler({
  configured: !!clientId && !!clientSecret,
  provider: createProvider({clientId, clientSecret}),
  authorize: async (authorization: string | null) => {
    if (!authorization?.startsWith('Bearer ')) return null;
    const user = await api('/auth/v1/user', anon, authorization);
    return typeof user?.id === 'string' ? {id: user.id, authorization} : null;
  },
  createOrder: (user: {authorization: string}, plan: string) =>
    api('/rest/v1/rpc/create_coin_purchase', anon, user.authorization, {p_plan: plan}),
  getOrder: async (user: {authorization: string}, id: string) => {
    const rows = await api(`/rest/v1/coin_purchase_orders?id=eq.${encodeURIComponent(id)}&select=*&limit=1`, anon, user.authorization);
    return rows[0];
  },
  attach: (id: string, request: string, checkout: string) => rpc('attach_coin_checkout', {p_order: id, p_request: request, p_url: checkout}),
  fail: (id: string) => rpc('fail_coin_checkout', {p_order: id}),
  credit: (order: {id: string; request_id: string; amount_paise: number}, payment: string) =>
    rpc('credit_coin_purchase', {p_order: order.id, p_request: order.request_id, p_payment: payment, p_amount: order.amount_paise}),
}));
