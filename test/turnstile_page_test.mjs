import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const page = fs.readFileSync(new URL('../turnstile/index.html', import.meta.url), 'utf8');
const script = page.match(/<script>\s*([\s\S]*?)<\/script>/)?.[1];

test('challenge produces and expires a token without sending it to a URL', () => {
  assert.ok(script);
  let load, options;
  const window = { addEventListener: (name, handler) => { if (name === 'load') load = handler; } };
  const status = { textContent: '' };
  vm.runInNewContext(script, {
    window,
    document: { getElementById: () => status },
    turnstile: { render: (_element, value) => { options = value; } },
  });
  window.turnstile = true;
  load();
  assert.equal(options.sitekey, '0x4AAAAAAGGqmh6aNhxMsLsE');
  assert.equal(options.size, 'compact');
  options.callback('synthetic-token');
  assert.equal(window.__freelanCaptchaToken, 'synthetic-token');
  options['expired-callback']();
  assert.equal(window.__freelanCaptchaToken, null);
  assert.match(status.textContent, /expired/i);
});
