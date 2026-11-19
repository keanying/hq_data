// 后端存储适配
//  · 页面启动时从 /api/kv 取回全部 dataflow-* 键，之后对这些键的读写走内存缓存。
//  · 开发草稿（dataflow-ui-draft-v2[:项目]）：自动保存只写本地草稿（浏览器 IndexedDB），
//    用户点「提交」或按 Ctrl+S 才写入数据库；刷新或重新打开时优先恢复未提交的本地草稿。
//  · 其余键（项目列表、定时运行、即席查询）由对话框确认等明确操作触发，直接写入数据库。
//  · 撤销历史按“浏览器标签页会话”保存在 IndexedDB（gzip 压缩），同一会话内刷新页面仍可撤销/重做。
//  · 后端不可用时退回浏览器 localStorage。
const API = '/api/kv';
const cache = new Map(), server = new Map();
const pending = new Map();          // 待写入数据库：key -> 值（null 表示删除）
const localDirty = new Set();       // 有未提交本地草稿的键
let online = false, flushing = false, lastError = '', idbBusy = 0;
const isDraft = k => k.startsWith('dataflow-ui-draft-v2');

// ---------- IndexedDB ----------
const idb = await new Promise(res => {
  try {
    const r = indexedDB.open('dataflow-local', 1);
    r.onupgradeneeded = () => { r.result.createObjectStore('drafts'); r.result.createObjectStore('history'); };
    r.onsuccess = () => res(r.result); r.onerror = () => res(null);
  } catch { res(null); }
});
function idbDo(store, mode, fn) {
  if (!idb) return Promise.resolve(null);
  idbBusy++;
  return new Promise(res => {
    try {
      const tx = idb.transaction(store, mode), req = fn(tx.objectStore(store));
      tx.oncomplete = () => res(req?.result ?? null); tx.onerror = tx.onabort = () => res(null);
    } catch { res(null); }
  }).finally(() => idbBusy--);
}
const idbGet = (s, k) => idbDo(s, 'readonly', st => st.get(k));
const idbPut = (s, k, v) => idbDo(s, 'readwrite', st => st.put(v, k));
const idbDel = (s, k) => idbDo(s, 'readwrite', st => st.delete(k));

try {
  const r = await fetch(API, {cache: 'no-store'});
  if (r.ok) { const j = await r.json(); for (const [k, v] of Object.entries(j.kv || {})) { cache.set(k, v); server.set(k, v); } online = true; }
} catch { /* 后端未启动 */ }
if (online && idb) {
  const keys = await idbDo('drafts', 'readonly', st => st.getAllKeys()) || [];
  for (const k of keys) {
    const d = await idbGet('drafts', k);
    if (d?.value && d.value !== server.get(k)) { cache.set(k, d.value); localDirty.add(k); }
    else await idbDel('drafts', k);
  }
}

const ours = (store, key) => online && store === window.localStorage && typeof key === 'string' && key.startsWith('dataflow-');
const emit = () => window.dispatchEvent(new CustomEvent('dataflow:backend', {detail: {ok: !lastError, message: lastError, pending: pending.size, dirty: [...localDirty]}}));

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
        if (value === null) server.delete(key); else server.set(key, value);
        lastError = '';
      } catch (e) {
        if (!pending.has(key)) pending.set(key, value);
        lastError = '服务器保存失败：' + e.message;
        emit();
        await new Promise(res => setTimeout(res, 3000));
      }
    }
  } finally { flushing = false; emit(); }
}

if (online) {
  const P = Storage.prototype, get = P.getItem, set = P.setItem, rm = P.removeItem;
  P.getItem = function (k) { return ours(this, k) ? (cache.has(k) ? cache.get(k) : null) : get.call(this, k); };
  P.setItem = function (k, v) {
    if (!ours(this, k)) return set.call(this, k, v);
    v = String(v);
    if (cache.get(k) === v) return;
    cache.set(k, v);
    if (isDraft(k)) {           // 自动保存：只写本地草稿
      if (v === server.get(k)) { localDirty.delete(k); idbDel('drafts', k); }
      else { localDirty.add(k); idbPut('drafts', k, {value: v, savedAt: Date.now()}); }
      emit();
      return;
    }
    pending.set(k, v); flush();
  };
  P.removeItem = function (k) {
    if (!ours(this, k)) return rm.call(this, k);
    cache.delete(k); localDirty.delete(k); idbDel('drafts', k); pending.set(k, null); flush();
  };
}

// 等待未完成的写入（切换项目刷新页面前调用）
window.__dataflowFlush = (timeout = 8000) => new Promise(res => {
  const t0 = Date.now();
  (function wait() { if ((!pending.size && !flushing && !idbBusy) || Date.now() - t0 > timeout) res(); else setTimeout(wait, 50); })();
});

// ---------- 撤销历史（同一标签页会话内跨刷新保留） ----------
const SESSION_KEY = 'dataflow-session-id';
let sessionId = '';
try { sessionId = sessionStorage.getItem(SESSION_KEY) || ''; if (!sessionId) { sessionId = Date.now().toString(36) + Math.random().toString(36).slice(2, 8); sessionStorage.setItem(SESSION_KEY, sessionId); } } catch { /* 无 sessionStorage */ }
const packed = new Map();   // 快照字符串 -> 压缩后的 Blob（每个快照只压缩一次）
async function pack(s) {
  if (packed.has(s)) return packed.get(s);
  let v;
  try { v = {blob: await new Response(new Blob([s]).stream().pipeThrough(new CompressionStream('gzip'))).blob(), gz: true}; }
  catch { v = {blob: new Blob([s]), gz: false}; }
  packed.set(s, v);
  return v;
}
async function unpack(v) {
  const s = v.gz ? await new Response(v.blob.stream().pipeThrough(new DecompressionStream('gzip'))).text() : await v.blob.text();
  packed.set(s, v);
  return s;
}
let histTimer;
function saveHistory(key, undo, redo) {
  clearTimeout(histTimer);
  const u0 = [...undo], r0 = [...redo];
  histTimer = setTimeout(async () => {
    const u = await Promise.all(u0.map(pack)), r = await Promise.all(r0.map(pack));
    const live = new Set([...u0, ...r0]); for (const s of packed.keys()) if (!live.has(s)) packed.delete(s);
    await idbPut('history', key, {session: sessionId, undo: u, redo: r, savedAt: Date.now()});
  }, 800);
}
async function loadHistory(key) {
  const h = await idbGet('history', key);
  if (!h || h.session !== sessionId) { if (h) idbDel('history', key); return null; }
  try { return {undo: await Promise.all(h.undo.map(unpack)), redo: await Promise.all(h.redo.map(unpack))}; } catch { return null; }
}

export const backend = {
  get online() { return online; },
  get pending() { return pending.size; },
  get error() { return lastError; },
  label: online ? '数据库（SQLite）' : '当前浏览器',
  isDirty: key => localDirty.has(key),
  // 提交：把本地草稿写入数据库
  async commit(key) {
    if (!online) return {ok: true};
    if (!cache.has(key)) return {ok: false, error: '没有可提交的内容'};
    const value = cache.get(key);
    try {
      const r = await fetch(API + '/' + encodeURIComponent(key), {method: 'PUT', headers: {'Content-Type': 'application/json; charset=utf-8'}, body: value});
      if (!r.ok) { const j = await r.json().catch(() => ({})); throw Error(j.error || ('HTTP ' + r.status)); }
      server.set(key, value);
      if (cache.get(key) === value) { localDirty.delete(key); await idbDel('drafts', key); }
      lastError = ''; emit();
      return {ok: true};
    } catch (e) { lastError = '提交失败：' + e.message; emit(); return {ok: false, error: e.message}; }
  },
  // 放弃本地草稿：回到数据库中的版本
  async discard(key) { localDirty.delete(key); await idbDel('drafts', key); cache.set(key, server.get(key) ?? null); emit(); },
  saveHistory, loadHistory,
};
