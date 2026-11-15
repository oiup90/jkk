import test from 'node:test';
import assert from 'node:assert/strict';
import {createProvider, purpose, paise, checkoutUrl} from './provider.mjs';
import {createHandler} from './handler.mjs';
const order = {id:'12345678-1234-1234-1234-123456789012',user_id:'owner',amount_paise:4900,coins:100,request_id:'a'.repeat(32),status:'pending',checkout_url:'https://www.instamojo.com/@test/abc'};
const paymentId = 'MOJOtest1';
const requestUrl = `https://api.instamojo.com/v2/payment_requests/${order.request_id}/`;
function provider(overrides = {}) {
  const request = {id:order.request_id,amount:'49.00',purpose:purpose(order),allow_repeated_payments:false,payments:[`https://api.instamojo.com/v2/payments/${paymentId}/`],longurl:order.checkout_url,...overrides.request};
  const payment = {id:paymentId,amount:'49.00',currency:'INR',status:true,payment_request:requestUrl,...overrides.payment};
  const calls=[];
  const client = createProvider({clientId:'synthetic',clientSecret:'synthetic',fetcher:async (url,options)=>{
    calls.push({url,options});
    const data = url.endsWith('/oauth2/token/') ? {access_token:'synthetic-token',expires_in:3600} : url.includes('/payments/') ? payment : request;
    return new Response(JSON.stringify(data),{status:200});
  }});
  return {client,calls};
}
test('provider creates frozen-price, non-repeatable request and verifies matching settled payment',async()=>{
  const {client,calls}=provider();
  assert.deepEqual(await client.create(order),{requestId:order.request_id,url:order.checkout_url});
  assert.equal(await client.verify(order),paymentId);
  const fields=calls[1].options.body;
  assert.equal(fields.get('amount'),'49.00');
  assert.equal(fields.get('purpose'),purpose(order));
  assert.equal(fields.get('allow_repeated_payments'),'false');
  assert.equal(calls.filter(c=>c.url.endsWith('/oauth2/token/')).length,1);
});
for (const status of [false,null,'Credit','true',1]) test(`unconfirmed status ${status} cannot credit`,async()=>{
  assert.equal(await provider({payment:{status}}).client.verify(order),null);
});
for (const changes of [
  {payment:{amount:'48.99'}},{payment:{currency:'USD'}},{payment:{payment_request:'https://api.instamojo.com/v2/payment_requests/wrong/'}},
  {payment:{id:'wrong'}},{request:{amount:'50'}},{request:{purpose:'Other'}},{request:{allow_repeated_payments:true}},
  {request:{payments:['https://attacker.test/steal']}},{request:{id:'b'.repeat(32)}},
]) test(`reject mismatched provider data ${JSON.stringify(changes)}`,async()=>{
  await assert.rejects(provider(changes).client.verify(order));
});
test('amount parsing and checkout redirect reject unsafe values',()=>{
  for(const value of [49, '49.001', '-49','4.9e1','NaN']) assert.throws(()=>paise(value));
  for(const value of ['http://www.instamojo.com/test','https://www.instamojo.com.evil.test/test','https://user@www.instamojo.com/test','https://www.instamojo.com/test?redirect=x']) assert.throws(()=>checkoutUrl(value));
});
function harness(overrides={}) {
  const calls=[];
  const handler=createHandler({
    configured:true,authorize:async header=>header==='Bearer user'?{id:'owner'}:null,
    createOrder:async()=>({order,created:true}),getOrder:async()=>order,
    attach:async()=>calls.push('attach'),fail:async()=>calls.push('fail'),credit:async()=>calls.push('credit'),
    provider:{create:async()=>({requestId:order.request_id,url:order.checkout_url}),verify:async()=>paymentId},...overrides,
  });
  const send=(input,auth='Bearer user')=>handler(new Request('https://example.test',{method:'POST',headers:{authorization:auth},body:JSON.stringify(input)}));
  return {send,calls};
}
test('auth, body and ownership enforced without credit',async()=>{
  const h=harness();
  assert.equal((await h.send({action:'verify',order:order.id},'')).status,401);
  assert.equal((await h.send({action:'verify',order:'bad'})).status,400);
  assert.equal((await h.send({action:'create',plan:'starter',padding:'x'.repeat(1100)})).status,400);
  const foreign=harness({getOrder:async()=>({...order,user_id:'another'})});
  assert.equal((await foreign.send({action:'verify',order:order.id})).status,404);
  assert.deepEqual(foreign.calls,[]);
});
test('successful payment credits only after provider verification; ignores forged client amounts/status',async()=>{
  const h=harness();
  assert.deepEqual(await (await h.send({action:'verify',order:order.id,status:true,coins:9999})).json(),{status:'credited',coins:100});
  assert.deepEqual(h.calls,['credit']);
});
test('pending and provider exceptions cannot credit',async()=>{
  const h=harness({provider:{verify:async()=>null}});
  assert.deepEqual(await (await h.send({action:'verify',order:order.id})).json(),{status:'pending'});
  assert.deepEqual(h.calls,[]);
  const failed=harness({provider:{verify:async()=>{throw Error('sensitive upstream');}}});
  const r=await failed.send({action:'verify',order:order.id});
  assert.equal(r.status,503);assert.equal((await r.text()).includes('sensitive'),false);assert.deepEqual(failed.calls,[]);
});
test('checkout reservation reuse never invokes provider twice',async()=>{
  const h=harness({createOrder:async()=>({order,created:false}),provider:{create:async()=>{throw Error('must not call');}}});
  assert.equal((await h.send({action:'create',plan:'starter'})).status,200);
  assert.deepEqual(h.calls,[]);
  const creating=harness({createOrder:async()=>({order:{...order,status:'creating'},created:false})});
  assert.equal((await creating.send({action:'create',plan:'starter'})).status,409);
});
test('failed persistence never exposes a payable checkout',async()=>{
  const h=harness({attach:async()=>{throw Error('database failure');}});
  const r=await h.send({action:'create',plan:'starter'});
  assert.equal(r.status,503);assert.deepEqual(h.calls,['fail']);assert.equal((await r.text()).includes('checkout_url'),false);
});
test('already credited retry works without provider and disabled configuration is fail closed',async()=>{
  const h=harness({configured:false,getOrder:async()=>({...order,status:'credited'}),provider:{verify:async()=>{throw Error('must not call');}}});
  assert.equal((await h.send({action:'create',plan:'starter'})).status,503);
  assert.equal((await (await h.send({action:'verify',order:order.id})).json()).status,'credited');
});
