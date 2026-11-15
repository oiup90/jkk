import test from 'node:test';
import assert from 'node:assert/strict';

test('runtime adapter uses caller JWT for owner queries and service key only for verified credit', async () => {
  const savedFetch = globalThis.fetch, savedDeno = globalThis.Deno;
  let handler;
  const calls=[];
  const oid='12345678-1234-1234-1234-123456789012', request='a'.repeat(32);
  const order={id:oid,user_id:'owner',coins:100,amount_paise:4900,request_id:request,status:'pending'};
  globalThis.Deno={env:{get:key=>({SUPABASE_URL:'https://project.test',SUPABASE_ANON_KEY:'synthetic-public',SUPABASE_SERVICE_ROLE_KEY:'synthetic-service',INSTAMOJO_CLIENT_ID:'synthetic-client',INSTAMOJO_CLIENT_SECRET:'synthetic-secret'})[key]},serve:fn=>{handler=fn;}};
  globalThis.fetch=async (url, options) => {
    calls.push({url,options});
    let data;
    if(url==='https://project.test/auth/v1/user') data={id:'owner'};
    else if(url.startsWith('https://project.test/rest/v1/coin_purchase_orders?')) data=[order];
    else if(url==='https://api.instamojo.com/oauth2/token/') data={access_token:'synthetic-oauth',expires_in:3600};
    else if(url===`https://api.instamojo.com/v2/payment_requests/${request}/`) data={id:request,amount:'49.00',purpose:`Freelan coins ${oid}`,allow_repeated_payments:false,payments:['https://api.instamojo.com/v2/payments/MOJOtest/']};
    else if(url==='https://api.instamojo.com/v2/payments/MOJOtest/') data={id:'MOJOtest',status:true,amount:'49.00',currency:'INR',payment_request:`https://api.instamojo.com/v2/payment_requests/${request}/`};
    else if(url==='https://project.test/rest/v1/rpc/credit_coin_purchase') data=true;
    else throw Error('Unexpected outbound endpoint');
    return new Response(JSON.stringify(data),{status:200});
  };
  try {
    await import('./index.ts');
    const response=await handler(new Request('https://edge.test',{method:'POST',headers:{authorization:'Bearer synthetic-session'},body:JSON.stringify({action:'verify',order:oid})}));
    assert.equal(response.status,200);
    assert.deepEqual(await response.json(),{status:'credited',coins:100});
    assert.equal(calls[0].options.headers.authorization,'Bearer synthetic-session');
    assert.equal(calls[1].options.headers.authorization,'Bearer synthetic-session');
    const credit=calls.at(-1);
    assert.equal(credit.options.headers.authorization,'Bearer synthetic-service');
    assert.deepEqual(JSON.parse(credit.options.body),{p_order:oid,p_request:request,p_payment:'MOJOtest',p_amount:4900});
    assert.equal(calls.filter(c=>!c.url.startsWith('https://project.test')&&JSON.stringify(c.options).includes('synthetic-service')).length,0);
  } finally {globalThis.fetch=savedFetch;globalThis.Deno=savedDeno;}
});
