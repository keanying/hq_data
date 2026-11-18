// 后端存储适配：页面启动时从 /api/kv 取回全部 dataflow-* 键，之后对这些键的读写走内存缓存，
// 写入时异步 PUT 到 Python 后端（SQLite）。后端不可用时退回浏览器 localStorage。
const API = '/api/kv';
const cache = new Map();
const pending = new Map();   // key -> 最新值（null 表示删除）
let online = false, flushing = false, lastError = '';

try {
  const r = await fetch(API, {cache: 'no-store'});
  if (r.ok) { const j = await r.json(); for (const [k, v] of Object.entries(j.kv || {})) cache.set(k, v); online = true; }
} catch { /* 后端未启动 */ }

const ours = (store, key) => online && store === window.localStorage && typeof key === 'string' && key.startsWith('dataflow-');

function report(ok, msg) {
  lastError = ok ? '' : msg;
  window.dispatchEvent(new CustomEvent('dataflow:backend', {detail: {ok, message: msg, pending: pending.size}}));
}

async function flush() {
  if (flushing) return;
  flushing = true;
  try {
    while (pending.size) {
      const [key, value] = pending.entries().next().value;
      pending.delete(key);
      try {
        const r = await fetch(API + '/' + encodeURIComponent(key), value === null
          ? {method: 'DELETE'}
          : {method: 'PUT', headers: {'Content-Type': 'application/json; charset=utf-8'}, body: value});
        if (!r.ok) { const j = await r.json().catch(() => ({})); throw Error(j.error || ('HTTP ' + r.status)); }
        report(true, '已保存到服务器');
      } catch (e) {
        if (!pending.has(key)) pending.set(key, value);   // 失败重排，稍后重试
        report(false, '服务器保存失败：' + e.message);
        await new Promise(res => setTimeout(res, 3000));
      }
    }
  } finally { flushing = false; }
}

if (online) {
  const P = Storage.prototype, get = P.getItem, set = P.setItem, rm = P.removeItem;
  P.getItem = function (k) { return ours(this, k) ? (cache.has(k) ? cache.get(k) : null) : get.call(this, k); };
  P.setItem = function (k, v) {
    if (!ours(this, k)) return set.call(this, k, v);
    v = String(v);
    if (cache.get(k) === v) return;
    cache.set(k, v); pending.set(k, v); flush();
  };
  P.removeItem = function (k) {
    if (!ours(this, k)) return rm.call(this, k);
    cache.delete(k); pending.set(k, null); flush();
  };
  // 关闭页面前尽量把未发出的小数据用 keepalive 送出
  window.addEventListener('pagehide', () => {
    for (const [k, v] of pending) {
      if (v !== null && v.length < 60000) fetch(API + '/' + encodeURIComponent(k), {method: 'PUT', body: v, keepalive: true});
    }
  });
  window.addEventListener('beforeunload', e => { if (pending.size || flushing) { e.preventDefault(); e.returnValue = ''; } });
}

// 等待未完成的写入（切换项目刷新页面前调用）
window.__dataflowFlush = (timeout = 8000) => new Promise(res => {
  const t0 = Date.now();
  (function wait() { if ((!pending.size && !flushing) || Date.now() - t0 > timeout) res(); else setTimeout(wait, 50); })();
});

export const backend = {
  get online() { return online; },
  get pending() { return pending.size; },
  get error() { return lastError; },
  label: online ? '服务器 · SQLite' : '当前浏览器',
};
