// Phase 7 storage check (task 8): no bucket should exist / be publicly listable.
import { URL, KEY, login, qa, pass, record, summary } from './_lib.mjs';

const h = { apikey: KEY, Authorization: `Bearer ${KEY}` };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const get = async (path, headers = h, tries = 4) => {
  for (let i = 0; i < tries; i++) {
    try {
      const res = await fetch(`${URL}${path}`, { headers: { 'Content-Type': 'application/json', ...headers } });
      const text = await res.text();
      let json; try { json = JSON.parse(text); } catch { json = { raw: text.slice(0, 120) }; }
      return { status: res.status, json };
    } catch (e) {
      if (i === tries - 1) return { status: 0, json: { network_error: e.code ?? String(e).slice(0, 80) } };
      await sleep(2000 * (i + 1));
    }
  }
};

const parentA = await login(qa.PARENT_A_USER, qa.PARENT_A_PASS);
const ownerHdr = { apikey: KEY, Authorization: `Bearer ${parentA.token}` };

const anonList = await get('/storage/v1/bucket');
const anonBuckets = Array.isArray(anonList.json) ? anonList.json : [];
pass(anonList.status === 200 ? anonBuckets.length === 0 : [401, 403, 404].includes(anonList.status),
  'storage.anon_bucket_list_empty_or_denied', { status: anonList.status, count: anonBuckets.length, error: anonList.json?.message ?? anonList.json?.error ?? null });
if (anonBuckets.length) record('storage.anon_visible_buckets', 'INFO', { names: anonBuckets.map((b) => b.name) });

const authList = await get('/storage/v1/bucket', ownerHdr);
const authBuckets = Array.isArray(authList.json) ? authList.json : [];
pass(authList.status === 200 ? authBuckets.length === 0 : [401, 403, 404].includes(authList.status),
  'storage.authenticated_bucket_list_empty_or_denied', { status: authList.status, count: authBuckets.length });
if (authBuckets.length) record('storage.auth_visible_buckets', 'INFO', { names: authBuckets.map((b) => b.name), public: authBuckets.map((b) => b.public) });

for (const name of ['recordings', 'screen-recordings', 'screenshots', 'media', 'uploads', 'clips', 'attachments']) {
  const pub = await get(`/storage/v1/object/public/${name}/probe.bin`);
  const list = await get(`/storage/v1/object/list/${name}`, { apikey: KEY, Authorization: `Bearer ${parentA.token}` });
  pass([400, 401, 403, 404].includes(pub.status) && [400, 401, 403, 404].includes(list.status),
    `storage.guess_bucket_${name}_not_accessible`, { public: pub.status, list: list.status, pub_msg: pub.json?.message ?? null, list_msg: list.json?.message ?? null });
}

const renderSigned = await get('/storage/v1/object/authenticated/recordings/probe.bin', ownerHdr);
pass([400, 401, 403, 404].includes(renderSigned.status), 'storage.authenticated_render_denied', { status: renderSigned.status, msg: renderSigned.json?.message ?? null });

const rc = summary('storage');
process.exit(rc ? 1 : 0);
