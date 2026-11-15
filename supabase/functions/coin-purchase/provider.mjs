const api = 'https://api.instamojo.com';
export const purpose = order => `Freelan coins ${order.id}`;
export function paise(value) {
  if (typeof value !== 'string' || !/^\d{1,8}(\.\d{1,2})?$/.test(value)) throw Error('Invalid amount');
  const [whole, decimal = ''] = value.split('.');
  return Number(whole) * 100 + Number(decimal.padEnd(2, '0'));
}
export function checkoutUrl(value) {
  const u = new URL(value);
  if (u.protocol !== 'https:' || u.host !== 'www.instamojo.com' || u.username || u.password || u.search || u.hash) throw Error('Invalid checkout');
  return u.href;
}
export function createProvider({clientId, clientSecret, fetcher = fetch}) {
  let token, expires = 0;
  async function json(url, options) {
    const response = await fetcher(url, {...options, redirect: 'error', signal: AbortSignal.timeout(15000)});
    if (!response.ok) throw Error('Payment provider unavailable');
    return response.json();
  }
  async function accessToken() {
    if (!clientId || !clientSecret) throw Error('Payment configuration unavailable');
    if (!token || expires < Date.now()) {
      const result = await json(`${api}/oauth2/token/`, {method: 'POST',
        body: new URLSearchParams({grant_type: 'client_credentials', client_id: clientId, client_secret: clientSecret})});
      if (typeof result.access_token !== 'string' || !result.access_token) throw Error('Payment configuration unavailable');
      token = result.access_token;
      expires = Date.now() + Math.max(0, Math.min(Number(result.expires_in) || 0, 3600) - 60) * 1000;
    }
    return token;
  }
  async function call(path, options = {}) {
    return json(`${api}${path}`, {...options, headers: {authorization: `Bearer ${await accessToken()}`}});
  }
  return {
    async create(order) {
      const result = await call('/v2/payment_requests/', {method: 'POST', body: new URLSearchParams({
        amount: (order.amount_paise / 100).toFixed(2), purpose: purpose(order),
        allow_repeated_payments: 'false', send_email: 'false', send_sms: 'false',
      })});
      if (!/^[a-f0-9]{32}$/.test(result.id) || paise(result.amount) !== order.amount_paise || result.purpose !== purpose(order)
          || result.allow_repeated_payments !== false) throw Error('Checkout mismatch');
      return {requestId: result.id, url: checkoutUrl(result.longurl)};
    },
    async verify(order) {
      if (!/^[a-f0-9]{32}$/.test(order.request_id)) throw Error('Invalid request');
      const requestPath = `/v2/payment_requests/${order.request_id}/`;
      const result = await call(requestPath);
      if (result.id !== order.request_id || result.purpose !== purpose(order) || paise(result.amount) !== order.amount_paise
          || result.allow_repeated_payments !== false || !Array.isArray(result.payments) || result.payments.length > 20) throw Error('Payment mismatch');
      for (const link of result.payments) {
        // Never fetch arbitrary URLs returned by the provider or supplied by clients.
        if (typeof link !== 'string' || !/^https:\/\/api\.instamojo\.com\/v2\/payments\/[A-Za-z0-9_-]{1,100}\/$/.test(link)) throw Error('Invalid payment reference');
        const id = link.split('/').at(-2);
        const payment = await call(`/v2/payments/${id}/`);
        if (payment.id !== id || payment.payment_request !== `${api}${requestPath}` || payment.currency !== 'INR'
            || paise(payment.amount) !== order.amount_paise) throw Error('Payment mismatch');
        if (payment.status === true) return id;
      }
      return null;
    },
  };
}
