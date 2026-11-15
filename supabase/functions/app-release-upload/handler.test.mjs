import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHandler} from './handler.mjs';
import {preventDestinationOverwrite} from './r2_destination.mjs';
import {failureLog, runStage, StageFailure} from './diagnostics.mjs';

const user = '12345678-1234-4234-8234-123456789abc';
const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const key = `staging/${user}/${id}.apk`;
const metadata = {action: 'publish', key, size: 100, versionCode: 8, versionName: '1.2.0', notes: 'update', sha256: 'a'.repeat(64)};
const request = body => new Request('https://example.test', {method: 'POST', headers: {authorization: 'Bearer test'}, body: JSON.stringify(body)});
function fixture(overrides = {}) {
  const calls = [];
  const handler = createHandler({
    authorize: async () => user,
    signUpload: async (path, size) => {calls.push(['sign', path, size]); return 'https://upload.example.test';},
    copyUpload: async (...args) => {calls.push(['copy', ...args]);},
    publish: async args => {calls.push(['publish', args]);},
    publicBase: 'https://releases.example.test', randomUUID: () => id, logFailure: () => {}, ...overrides,
  });
  return {handler, calls};
}
test('only an authorized editor can prepare or publish', async () => {
  const {handler, calls} = fixture({authorize: async () => null});
  assert.equal((await handler(request({action: 'prepare', size: 100}))).status, 403);
  assert.equal((await handler(request(metadata))).status, 403);
  assert.deepEqual(calls, []);
});
test('prepare signs a bounded staging upload owned by the editor', async () => {
  const {handler, calls} = fixture();
  const result = await handler(request({action: 'prepare', size: 100}));
  assert.deepEqual(await result.json(), {key, url: 'https://upload.example.test'});
  assert.deepEqual(calls, [['sign', key, 100]]);
  assert.equal((await handler(request({action: 'prepare', size: 209715201}))).status, 400);
});
test('publication copies first to a separate immutable release key', async () => {
  const {handler, calls} = fixture();
  assert.equal((await handler(request(metadata))).status, 200);
  assert.deepEqual(calls[0], ['copy', key, 'releases/freelan-space-v1.2.0-8.apk', 100, {sha256: metadata.sha256, versionCode: 8, versionName: '1.2.0'}]);
  assert.equal(calls[1][1].downloadUrl, 'https://releases.example.test/releases/freelan-space-v1.2.0-8.apk');
  assert.equal(calls[1][1].name, `${id}.apk`);
  assert.equal(calls[1][1].userId, user);
});
test('version names cannot escape the object path and metadata stays correct', async () => {
  const {handler, calls} = fixture();
  assert.equal((await handler(request({...metadata, versionName: ' 1.2.0/../beta ' }))).status, 200);
  assert.equal(calls[0][2], 'releases/freelan-space-v1.2.0-..-beta-8.apk');
  assert.equal(calls[0][4].versionName, '1.2.0/../beta');
  assert.equal(calls[1][1].data.versionName, '1.2.0/../beta');
});
test('build number distinguishes releases and existing objects are not published', async () => {
  const objects = new Set();
  const {handler, calls} = fixture({copyUpload: async (_source, target) => {
    if (objects.has(target)) throw Error('destination exists');
    objects.add(target);
  }});
  assert.equal((await handler(request(metadata))).status, 200);
  assert.equal((await handler(request(metadata))).status, 503);
  assert.equal((await handler(request({...metadata, versionCode: 9}))).status, 200);
  assert.deepEqual([...objects], ['releases/freelan-space-v1.2.0-8.apk', 'releases/freelan-space-v1.2.0-9.apk']);
  assert.equal(calls.filter(c => c[0] === 'publish').length, 2);
});
test('R2 copy signs a destination condition that rejects overwrites', async () => {
  let middleware, options;
  const command = {middlewareStack: {add: (fn, config) => {middleware = fn; options = config;}}};
  assert.equal(preventDestinationOverwrite(command), command);
  assert.equal(options.step, 'build');
  const request = {headers: {'existing': 'value'}};
  await middleware(async args => {assert.equal(args.request.headers['cf-copy-destination-if-none-match'], '*'); return args;})({request});
  assert.equal(request.headers.existing, 'value');
});
test('rejects foreign staging paths, invalid metadata and failed copies', async () => {
  const {handler, calls} = fixture({copyUpload: async () => {throw Error('copy failed');}});
  assert.equal((await handler(request({...metadata, key: `staging/other/${id}.apk`}))).status, 400);
  assert.equal((await handler(request({...metadata, sha256: 'bad'}))).status, 400);
  assert.equal((await handler(request(metadata))).status, 503);
  assert.deepEqual(calls, []);
});
test('rejects invalid public endpoint before copying', async () => {
  const {handler, calls} = fixture({publicBase: 'http://example.test'});
  assert.equal((await handler(request(metadata))).status, 503);
  assert.deepEqual(calls, []);
});

test('rechecks editor access before publishing after a copy', async () => {
  let checks = 0;
  const {handler, calls} = fixture({authorize: async () => ++checks === 1 ? user : null});
  assert.equal((await handler(request(metadata))).status, 403);
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], 'copy');
});

test('validator rejection records only its stage/status and blocks publication', async () => {
  for (const status of [401, 422, 502]) {
    const logs = [];
    const {handler, calls} = fixture({
      copyUpload: () => runStage('validator_request', () => { throw new StageFailure('validator_request', status); }),
      logFailure: message => logs.push(JSON.parse(message)),
    });
    const response = await handler(request(metadata));
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), {error: 'publication_unconfirmed'});
    assert.deepEqual(calls, []);
    assert.deepEqual(logs, [{event: 'app_release_failure', stage: 'validator_request', httpStatus: status}]);
  }
});

test('SDK exceptions and malformed diagnostic fields cannot leak to logs or responses', async () => {
  const secret = 'https://r2.example/staging/private.apk?X-Amz-Signature=private-secret';
  const logs = [];
  const {handler} = fixture({
    copyUpload: () => runStage('staging_head', () => { throw Object.assign(new Error(secret), {$metadata: {httpStatusCode: 403}, response: secret}); }),
    logFailure: message => logs.push(message),
  });
  const response = await handler(request(metadata));
  assert.equal(response.status, 503);
  assert.equal((await response.text()).includes(secret), false);
  assert.deepEqual(logs, [JSON.stringify({event: 'app_release_failure', stage: 'staging_head', httpStatus: 403})]);
  assert.deepEqual(JSON.parse(failureLog(new StageFailure(secret, secret))), {event: 'app_release_failure', stage: 'unknown', httpStatus: null});
});

test('logging failures preserve the uncertain-publication response after a failed RPC', async () => {
  const {handler, calls} = fixture({
    publish: () => runStage('publish_rpc', () => { throw new StageFailure('publish_rpc', 409); }),
    logFailure: () => { throw new Error('logger unavailable'); },
  });
  const response = await handler(request(metadata));
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {error: 'publication_unconfirmed'});
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], 'copy');
});
