// ==UserScript==
// @name         携程POI核对面板（景区 ↔ 携程POI）
// @namespace    hq_data
// @version      0.1.0
// @description  从本地 MySQL 读取客户景区，在携程页面内实时调用携程搜索，人工确认保留哪些携程 POI，结果写回 MySQL
// @match        https://you.ctrip.com/*
// @match        https://www.ctrip.com/*
// @match        https://m.ctrip.com/*
// @grant        GM_xmlhttpRequest
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        unsafeWindow
// @connect      127.0.0.1
// @connect      localhost
// @connect      ctrip.com
// @run-at       document-idle
// ==/UserScript==

(function () {
  'use strict';

  // ------------------------------------------------------------------ storage / config
  const W = typeof unsafeWindow !== 'undefined' ? unsafeWindow : window;
  const store = {
    get: (k, d) => { try { const v = GM_getValue(k); return v === undefined ? d : v; } catch (e) { return d; } },
    set: (k, v) => GM_setValue(k, v),
  };
  const cfg = Object.assign({
    backend: 'http://127.0.0.1:8765',
    reviewer: '',
    throttleMs: 1200,
    autoSearch: true,
    sightOnly: false,
    filters: { city: '', grade: '', status: 'todo', q: '' },
    template: null, // {url, method, headers, body, referrer}
  }, store.get('cfg', {}));
  const saveCfg = () => store.set('cfg', cfg);

  // ------------------------------------------------------------------ utils
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const stripTags = (s) => String(s ?? '').replace(/<[^>]+>/g, '');
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const num = (v) => { const n = parseFloat(v); return Number.isFinite(n) ? n : null; };
  function haversine(lat1, lng1, lat2, lng2) {
    if ([lat1, lng1, lat2, lng2].some((v) => v == null)) return null;
    const r = (d) => (d * Math.PI) / 180;
    const a = Math.sin(r(lat2 - lat1) / 2) ** 2 + Math.cos(r(lat1)) * Math.cos(r(lat2)) * Math.sin(r(lng2 - lng1) / 2) ** 2;
    return 6371000 * 2 * Math.asin(Math.sqrt(a));
  }
  const fmtDist = (m) => (m == null ? '' : m < 1000 ? `≈${Math.round(m)}m` : `≈${(m / 1000).toFixed(1)}km`);

  // ------------------------------------------------------------------ backend (GM_xmlhttpRequest 绕开 CORS / 私有网络限制)
  function api(method, path, body) {
    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method, url: cfg.backend.replace(/\/$/, '') + path,
        headers: { 'Content-Type': 'application/json' },
        data: body ? JSON.stringify(body) : undefined,
        timeout: 15000,
        onload: (r) => {
          let j = null; try { j = JSON.parse(r.responseText); } catch (e) { /* not json */ }
          if (r.status >= 200 && r.status < 300) resolve(j); else reject(new Error((j && j.error) || `HTTP ${r.status}`));
        },
        onerror: () => reject(new Error('连不上本地后端 ' + cfg.backend + '，确认 server.py 已启动')),
        ontimeout: () => reject(new Error('后端超时')),
      });
    });
  }

  // ------------------------------------------------------------------ 携程搜索模板：解析 F12「Copy as fetch」
  const KW = '{{kw}}';
  function parseFetchSnippet(text, probe) {
    const t = text.trim().replace(/;\s*$/, '');
    const m = t.match(/^(?:await\s+)?fetch\s*\(([\s\S]*)\)$/);
    if (!m) throw new Error('没识别到 fetch(...)，请在 F12 Network 里右键该请求 → Copy → Copy as fetch');
    let args;
    try { args = JSON.parse('[' + m[1] + ']'); } catch (e) { throw new Error('fetch 参数不是合法 JSON：' + e.message); }
    const [url, opt = {}] = args;
    const tpl = { url, method: (opt.method || 'GET').toUpperCase(), headers: opt.headers || {}, body: opt.body ?? null, referrer: opt.referrer || null };
    if (probe) {
      const variants = [
        [probe, KW],
        [JSON.stringify(probe).slice(1, -1).replace(/[\u0080-￿]/g, (c) => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0')), KW + '__U'],
        [encodeURIComponent(probe), KW + '__URL'],
      ];
      let hit = false;
      for (const [from, to] of variants) {
        if (tpl.body && tpl.body.includes(from)) { tpl.body = tpl.body.split(from).join(to); hit = true; }
        if (tpl.url.includes(from)) { tpl.url = tpl.url.split(from).join(to); hit = true; }
      }
      if (!hit) throw new Error(`在请求里没找到关键词「${probe}」，请确认填的是抓包时搜索的那个词`);
    } else if (!(tpl.body || '').includes(KW) && !tpl.url.includes(KW)) {
      throw new Error('请填写抓包时搜索的关键词（用来定位替换位置），或手工把关键词改成 {{kw}}');
    }
    return tpl;
  }
  function fillTemplate(tpl, kw) {
    const u = (s) => s
      .split(KW + '__URL').join(encodeURIComponent(kw))
      .split(KW + '__U').join(JSON.stringify(kw).slice(1, -1).replace(/[\u0080-￿]/g, (c) => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0')))
      .split(KW).join(kw);
    const bodyKw = (s) => s
      .split(KW + '__URL').join(encodeURIComponent(kw))
      .split(KW + '__U').join(JSON.stringify(kw).slice(1, -1).replace(/[\u0080-￿]/g, (c) => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0')))
      .split(KW).join(JSON.stringify(kw).slice(1, -1));
    return { url: u(tpl.url), method: tpl.method, headers: tpl.headers, body: tpl.body == null ? null : bodyKw(tpl.body), referrer: tpl.referrer };
  }

  let lastSearchAt = 0;
  const searchCache = new Map();
  async function ctripSearch(kw) {
    if (!cfg.template) throw new Error('还没配置携程搜索请求：点 ⚙ 粘贴 F12 的 Copy as fetch');
    if (searchCache.has(kw)) return searchCache.get(kw);
    const wait = lastSearchAt + Number(cfg.throttleMs || 0) - Date.now();
    if (wait > 0) await sleep(wait);
    lastSearchAt = Date.now();
    const req = fillTemplate(cfg.template, kw);
    const headers = Object.assign({}, req.headers);
    delete headers.cookie; delete headers.Cookie;
    let json;
    try {
      const opt = { method: req.method, headers, credentials: 'include', mode: 'cors' };
      if (req.body != null && req.method !== 'GET') opt.body = req.body;
      if (req.referrer) opt.referrer = req.referrer;
      const res = await W.fetch(req.url, opt);
      if (!res.ok) throw new Error('携程 HTTP ' + res.status);
      json = await res.json();
    } catch (e) {
      // 页面 fetch 失败（如在非 ctrip 子域打开）时，退回 GM_xmlhttpRequest
      json = await new Promise((resolve, reject) => GM_xmlhttpRequest({
        method: req.method, url: req.url, headers, data: req.body ?? undefined, timeout: 15000, anonymous: false,
        onload: (r) => { try { resolve(JSON.parse(r.responseText)); } catch (err) { reject(new Error('携程返回非 JSON（HTTP ' + r.status + '），可能需要重新抓包')); } },
        onerror: () => reject(e), ontimeout: () => reject(new Error('携程请求超时')),
      }));
    }
    const ack = json && json.ResponseStatus && json.ResponseStatus.Ack;
    if (ack && ack !== 'Success') throw new Error('携程返回 Ack=' + ack + '，可能需要重新抓包');
    const items = parseItems(json);
    const out = { items, total: json.total, raw: json };
    searchCache.set(kw, out);
    return out;
  }

  // 返回结构示例：{ data: [{ id:758, word:'上海野生动物园', type:'sight', url:'.../sight/xxx/758.html', lat, lon, cityName, districtName, poiId:75624 }], total }
  function findArray(o, depth = 0) {
    if (!o || typeof o !== 'object' || depth > 4) return null;
    for (const v of Object.values(o)) {
      if (Array.isArray(v) && v.length && typeof v[0] === 'object' && v[0] && ('word' in v[0] || 'name' in v[0] || 'poiId' in v[0])) return v;
    }
    for (const v of Object.values(o)) { const r = findArray(v, depth + 1); if (r) return r; }
    return null;
  }
  function parseItems(json) {
    const arr = Array.isArray(json && json.data) ? json.data : findArray(json) || [];
    return arr.map((it, i) => {
      const url = (it.url || it.jumpUrl || '').replace(/^http:\/\//, 'https://');
      const bm = url.match(/\/sight\/[^/]+\/(\d+)\.html/i);
      const businessId = bm ? bm[1] : (it.type === 'sight' && it.id != null ? String(it.id) : null);
      const poiId = it.poiId != null && it.poiId !== 0 ? String(it.poiId) : null;
      return {
        idx: i + 1,
        name: stripTags(it.word || it.name || it.title || ''),
        type: it.type || '', childType: it.childType || '',
        poiId, businessId, id: it.id,
        url, lat: num(it.lat), lng: num(it.lon ?? it.lng),
        cityName: it.cityName || '', districtName: it.districtName || '',
        isSight: it.type === 'sight' || !!bm,
        key: poiId ? 'poi:' + poiId : businessId ? 'biz:' + businessId : null,
        raw: it,
      };
    });
  }

  // ------------------------------------------------------------------ state
  const S = { list: [], total: 0, i: -1, detail: null, decisions: {}, results: [], keyword: '', loading: false, rawOpen: {} };

  // ------------------------------------------------------------------ UI
  const host = document.createElement('div');
  host.id = 'hq-poi-review-host';
  document.documentElement.appendChild(host);
  const root = host.attachShadow({ mode: 'open' });
  root.innerHTML = `
<style>
  :host { all: initial; }
  * { box-sizing: border-box; font-family: -apple-system, "PingFang SC", "Microsoft YaHei", Arial, sans-serif; }
  .fab { position: fixed; right: 16px; bottom: 16px; z-index: 2147483646; background: #0b6bcb; color: #fff; border: 0; border-radius: 20px; padding: 9px 14px; font-size: 13px; cursor: pointer; box-shadow: 0 2px 8px rgba(0,0,0,.25); }
  .panel { position: fixed; top: 0; right: 0; width: 560px; height: 100vh; z-index: 2147483647; background: #fff; border-left: 1px solid #d0d7de; box-shadow: -4px 0 16px rgba(0,0,0,.12); display: flex; flex-direction: column; font-size: 13px; color: #1f2328; }
  .panel.hidden { display: none; }
  header { display: flex; align-items: center; gap: 6px; padding: 8px 10px; background: #f6f8fa; border-bottom: 1px solid #d0d7de; }
  header b { font-size: 14px; }
  header .grow { flex: 1; color: #57606a; font-size: 12px; }
  button { font-size: 12px; padding: 4px 8px; border: 1px solid #d0d7de; border-radius: 6px; background: #fff; cursor: pointer; color: #1f2328; }
  button:hover { background: #f3f4f6; }
  button.primary { background: #1f883d; border-color: #1a7f37; color: #fff; }
  button.keep.on { background: #1f883d; border-color: #1a7f37; color: #fff; }
  button.drop.on { background: #cf222e; border-color: #a40e26; color: #fff; }
  button:disabled { opacity: .4; cursor: not-allowed; }
  .filters { display: flex; gap: 6px; padding: 6px 10px; border-bottom: 1px solid #eaeef2; flex-wrap: wrap; }
  select, input[type=text], input[type=number], textarea { font-size: 12px; padding: 4px 6px; border: 1px solid #d0d7de; border-radius: 6px; }
  .body { flex: 1; overflow: auto; padding: 8px 10px 80px; }
  .card { border: 1px solid #d0d7de; border-radius: 8px; padding: 8px 10px; margin-bottom: 8px; background: #fbfcfd; }
  .card h3 { margin: 0 0 4px; font-size: 16px; }
  .muted { color: #57606a; font-size: 12px; }
  .tag { display: inline-block; padding: 0 6px; border-radius: 10px; font-size: 11px; line-height: 18px; background: #eaeef2; color: #424a53; margin-right: 4px; }
  .tag.g5 { background: #fff1e5; color: #bc4c00; } .tag.sight { background: #ddf4ff; color: #0969da; }
  .tag.cand { background: #dafbe1; color: #1a7f37; } .tag.warn { background: #fff8c5; color: #7d4e00; }
  .chips { display: flex; flex-wrap: wrap; gap: 4px; margin: 6px 0; align-items: center; }
  .chip { border-radius: 12px; padding: 2px 8px; }
  .chip.active { background: #0969da; color: #fff; border-color: #0969da; }
  .sec { margin: 10px 0 4px; font-weight: 600; display: flex; align-items: center; gap: 6px; }
  .row { border: 1px solid #eaeef2; border-radius: 6px; padding: 6px 8px; margin-bottom: 4px; display: grid; grid-template-columns: 26px 1fr auto; gap: 6px; align-items: start; }
  .row.keep { border-color: #1a7f37; background: #f0fff4; } .row.drop { border-color: #cf222e; background: #fff5f5; opacity: .75; }
  .row.dim { opacity: .55; }
  .idx { font-weight: 700; color: #0969da; text-align: center; }
  .name { font-weight: 600; } .name a { color: inherit; text-decoration: none; } .name a:hover { text-decoration: underline; }
  .acts { display: flex; gap: 4px; }
  pre { white-space: pre-wrap; word-break: break-all; font-size: 11px; background: #f6f8fa; padding: 6px; border-radius: 6px; margin: 4px 0 0; max-height: 200px; overflow: auto; }
  footer { position: absolute; bottom: 0; left: 0; right: 0; background: #fff; border-top: 1px solid #d0d7de; padding: 8px 10px; display: flex; gap: 6px; align-items: center; }
  footer input { flex: 1; }
  .toast { position: absolute; left: 10px; right: 10px; bottom: 54px; background: #24292f; color: #fff; padding: 6px 10px; border-radius: 6px; font-size: 12px; display: none; }
  .toast.err { background: #a40e26; }
  .settings { padding: 10px; border-bottom: 1px solid #d0d7de; background: #fffbea; display: none; }
  .settings.open { display: block; }
  .settings label { display: block; margin: 6px 0 2px; font-weight: 600; }
  .settings textarea { width: 100%; height: 90px; font-family: Menlo, Consolas, monospace; }
  .kbd { font-family: Menlo, Consolas, monospace; background: #eaeef2; border-radius: 4px; padding: 0 4px; font-size: 11px; }
  .help { font-size: 11px; color: #57606a; margin-top: 6px; line-height: 1.6; }
</style>
<button class="fab" id="fab">POI核对</button>
<div class="panel hidden" id="panel">
  <header>
    <b>景区 ↔ 携程POI</b>
    <span class="grow" id="progress"></span>
    <button id="prev" title="上一个 (←)">‹</button>
    <button id="next" title="下一个 (→)">›</button>
    <button id="gear" title="设置">⚙</button>
    <button id="close" title="收起 (Esc)">✕</button>
  </header>
  <div class="settings" id="settings">
    <label>本地后端地址</label><input type="text" id="s-backend" style="width:100%">
    <label>核对人</label><input type="text" id="s-reviewer" style="width:100%" placeholder="写入 reviewer 字段">
    <label>携程搜索请求（F12 → Network → 选中 soa2/30668/search → 右键 Copy → Copy as fetch，粘贴到这里）</label>
    <textarea id="s-fetch" placeholder='fetch("https://m.ctrip.com/restapi/soa2/30668/search?...", { "headers": {...}, "body": "{...}", "method": "POST" });'></textarea>
    <label>抓包时在携程搜索框里输入的关键词</label><input type="text" id="s-probe" style="width:100%" placeholder="例如：上海野生动物园">
    <label>请求间隔（毫秒，防止被限流）</label><input type="number" id="s-throttle" min="0" step="100">
    <div style="margin-top:8px;display:flex;gap:6px;align-items:center">
      <button class="primary" id="s-save">保存</button><button id="s-test">保存并测试搜索</button>
      <span class="muted" id="s-state"></span>
    </div>
    <div class="help">快捷键：<span class="kbd">1</span>–<span class="kbd">9</span> 保留第 n 条搜索结果（再按取消），<span class="kbd">Shift</span>+数字 标记不留，<span class="kbd">Enter</span> 完成并下一个，<span class="kbd">S</span> 跳过，<span class="kbd">←</span>/<span class="kbd">→</span> 翻景区，<span class="kbd">/</span> 输入自定义关键词，<span class="kbd">Esc</span> 收起。</div>
  </div>
  <div class="filters">
    <select id="f-city"><option value="">后端默认城市</option></select>
    <select id="f-grade"><option value="">全部等级</option><option>5A</option><option>4A</option><option>5A,4A</option><option>3A</option><option>2A</option><option>1A</option></select>
    <select id="f-status"><option value="todo">待核对</option><option value="done">已完成</option><option value="skip">已跳过</option><option value="all">全部</option></select>
    <input type="text" id="f-q" placeholder="景区名/ID" style="width:110px">
    <button id="f-apply">筛选</button>
    <button id="export" title="下载最终映射 CSV">导出</button>
  </div>
  <div class="body" id="body"><div class="muted">加载中…</div></div>
  <div class="toast" id="toast"></div>
  <footer>
    <input type="text" id="note" placeholder="景区备注（可选）">
    <button id="skip" title="跳过 (S)">跳过</button>
    <button class="primary" id="done" title="完成并下一个 (Enter)">完成 ↵</button>
  </footer>
</div>`;
  const $ = (sel) => root.querySelector(sel);

  let toastTimer = null;
  function toast(msg, err) {
    const t = $('#toast'); t.textContent = msg; t.className = 'toast' + (err ? ' err' : ''); t.style.display = 'block';
    clearTimeout(toastTimer); toastTimer = setTimeout(() => (t.style.display = 'none'), err ? 6000 : 1800);
  }

  // ------------------------------------------------------------------ list / navigation
  async function loadList(reset) {
    const f = cfg.filters;
    const offset = reset || f.status === 'todo' ? 0 : S.list.length;
    const qs = new URLSearchParams({ city: f.city || '', grade: f.grade || '', status: f.status || 'todo', q: f.q || '', offset, limit: 200 });
    const r = await api('GET', '/api/scenic?' + qs);
    S.total = r.total;
    if (reset) { S.list = r.items; S.i = -1; } else {
      const seen = new Set(S.list.map((x) => x.id));
      S.list = S.list.concat(r.items.filter((x) => !seen.has(x.id)));
    }
    return r.items.length;
  }
  async function go(delta) {
    let j = S.i + delta;
    if (j >= S.list.length) {
      const added = await loadList(false);
      if (!added || j >= S.list.length) { toast('当前筛选下没有更多景区了'); renderProgress(); return; }
    }
    if (j < 0) j = 0;
    S.i = j;
    await openScenic(S.list[j].id);
  }
  async function openScenic(sid) {
    S.detail = await api('GET', '/api/scenic/' + encodeURIComponent(sid));
    S.decisions = {};
    for (const d of S.detail.decisions) S.decisions[d.ctrip_key] = d.decision;
    S.results = []; S.keyword = ''; S.rawOpen = {};
    $('#note').value = (S.detail.status && S.detail.status.note) || '';
    render();
    if (cfg.autoSearch && cfg.template) await doSearch(S.detail.scenic.name);
  }
  function renderProgress() {
    const st = { todo: '待核对', done: '已完成', skip: '已跳过', all: '全部' }[cfg.filters.status] || '';
    $('#progress').textContent = S.detail ? `${st} 第 ${S.i + 1} / ${S.total}` : `${st} 共 ${S.total}`;
  }

  // ------------------------------------------------------------------ search
  function keywordChips(s) {
    const set = [];
    const add = (k) => { k = (k || '').trim(); if (k && !set.includes(k)) set.push(k); };
    add(s.name);
    (s.alias || '').split(/[,，、;；/]/).forEach(add);
    const city = (s.city || '').replace(/市$/, '');
    if (city && !(s.name || '').startsWith(city)) add(city + s.name);
    return set;
  }
  async function doSearch(kw) {
    kw = (kw || '').trim(); if (!kw) return;
    S.keyword = kw; S.loading = true; render();
    try {
      const r = await ctripSearch(kw);
      S.results = r.items; S.searchTotal = r.total; S.lastRaw = r.raw;
    } catch (e) {
      S.results = []; toast(e.message, true);
    } finally { S.loading = false; render(); }
  }

  // ------------------------------------------------------------------ decisions
  async function setDecision(item, decision, source) {
    const s = S.detail.scenic;
    const key = item.key;
    if (!key) { toast('该条没有 poiId/景点ID，无法保存（通常是酒店、目的地等非景点结果）', true); return; }
    const cur = S.decisions[key];
    const next = cur === decision ? null : decision; // 再点一次 = 取消
    const body = {
      scenic_id: s.id, decision: next, source, keyword: S.keyword || null, reviewer: cfg.reviewer || null,
      ctrip_poi_id: item.poiId, ctrip_business_id: item.businessId, ctrip_poi_name: item.name, ctrip_type: item.type,
      ctrip_city_name: item.cityName, ctrip_district_name: item.districtName, ctrip_lat: item.lat, ctrip_lng: item.lng,
      ctrip_url: item.url, raw_json: item.raw || null,
    };
    try {
      await api('POST', '/api/decision', body);
      if (next) S.decisions[key] = next; else delete S.decisions[key];
      const arr = S.detail.decisions.filter((d) => d.ctrip_key !== key);
      if (next) arr.push({ ctrip_key: key, ctrip_poi_id: item.poiId, ctrip_business_id: item.businessId, ctrip_poi_name: item.name, source, keyword: S.keyword || null, decision: next });
      S.detail.decisions = arr;
      render();
    } catch (e) { toast('保存失败：' + e.message, true); }
  }
  function candAsItem(c) {
    return {
      key: 'poi:' + c.ctrip_poi_id, poiId: c.ctrip_poi_id, businessId: c.ctrip_business_id || null, name: c.ctrip_poi_name,
      type: 'sight', cityName: c.city_name, districtName: c.ctrip_district_name, lat: null, lng: null, url: c.ctrip_url,
      raw: { from: 'offline_candidate', relation_type: c.relation_type, confidence: c.confidence, match_evidence: c.match_evidence },
    };
  }
  async function applyOffline(mode) {
    const cands = (S.detail && S.detail.candidates) || [];
    let n = 0;
    for (const c of cands) {
      const it = candAsItem(c);
      let d = null;
      if (mode === 'high') d = c.confidence === '高' ? 'keep' : null;
      if (mode === 'triage') d = c.triage_result === '自动保留' ? 'keep' : c.triage_result === '自动删除' ? 'drop' : null;
      if (!d || S.decisions[it.key]) continue; // 已经人工判过的不覆盖
      await setDecision(it, d, 'candidate'); n++;
    }
    toast(`已批量写入 ${n} 条`);
  }
  async function finish(status) {
    if (!S.detail) return;
    try {
      await api('POST', '/api/status', { scenic_id: S.detail.scenic.id, status, note: $('#note').value || null, reviewer: cfg.reviewer || null });
      toast(status === 'done' ? '已完成' : '已跳过');
      if (cfg.filters.status === 'todo') { S.list.splice(S.i, 1); S.total = Math.max(0, S.total - 1); S.i -= 1; }
      await go(1);
    } catch (e) { toast('保存失败：' + e.message, true); }
  }

  // ------------------------------------------------------------------ render
  function render() {
    renderProgress();
    const b = $('#body');
    if (!S.detail) { b.innerHTML = `<div class="muted">${S.total === 0 ? '当前筛选下没有景区。' : '加载中…'}</div>`; return; }
    const s = S.detail.scenic, st = S.detail.status;
    const slat = num(s.lat), slng = num(s.lng);
    const candByPoi = {};
    for (const c of S.detail.candidates) candByPoi[c.ctrip_poi_id] = c;
    const chips = keywordChips(s).map((k) => `<button class="chip ${k === S.keyword ? 'active' : ''}" data-kw="${esc(k)}">${esc(k)}</button>`).join('');
    const results = S.results.filter((r) => !cfg.sightOnly || r.isSight);
    const decTag = (key) => S.decisions[key] === 'keep' ? 'keep' : S.decisions[key] === 'drop' ? 'drop' : '';
    const resHtml = S.loading ? '<div class="muted">搜索中…</div>' : results.length ? results.map((r) => {
      const c = r.poiId && candByPoi[r.poiId];
      const d = haversine(slat, slng, r.lat, r.lng);
      return `<div class="row ${decTag(r.key)} ${r.isSight ? '' : 'dim'}">
        <div class="idx">${r.idx}</div>
        <div>
          <div class="name">${r.url ? `<a href="${esc(r.url)}" target="_blank" rel="noopener">${esc(r.name)} ↗</a>` : esc(r.name)}</div>
          <div class="muted">
            <span class="tag ${r.isSight ? 'sight' : ''}">${esc(r.type || '?')}${r.childType ? '/' + esc(r.childType) : ''}</span>
            ${esc([r.cityName, r.districtName].filter(Boolean).join(' / '))}
            ${r.poiId ? ' · poiId ' + esc(r.poiId) : ''}${r.businessId ? ' · 景点ID ' + esc(r.businessId) : ''}
            ${d != null ? ' · 距客户坐标 ' + fmtDist(d) : ''}
          </div>
          <div>${c ? `<span class="tag ${c.triage_result === '自动删除' ? 'warn' : c.triage_result === '自动保留' ? 'cand' : ''}">离线候选 ${esc(c.relation_type.slice(0, 2))} ${esc(c.confidence)} · ${esc(c.triage_result || '')}</span>` : ''}
            ${d != null && d > 5000 ? '<span class="tag warn">距离较远</span>' : ''}
            <button data-raw="${r.idx}" style="padding:0 6px;font-size:11px">原始</button></div>
          ${S.rawOpen[r.idx] ? `<pre>${esc(JSON.stringify(r.raw, null, 2))}</pre>` : ''}
        </div>
        <div class="acts">
          <button class="keep ${S.decisions[r.key] === 'keep' ? 'on' : ''}" data-keep="${r.idx}" ${r.key ? '' : 'disabled'}>保留</button>
          <button class="drop ${S.decisions[r.key] === 'drop' ? 'on' : ''}" data-drop="${r.idx}" ${r.key ? '' : 'disabled'}>不留</button>
        </div></div>`;
    }).join('') : `<div class="muted">${S.keyword ? '无结果' : cfg.template ? '点上面的关键词搜索' : '先点 ⚙ 配置携程搜索请求'}</div>`;

    const searchedPoi = new Set(S.results.map((r) => r.poiId).filter(Boolean));
    const candHtml = S.detail.candidates.length ? S.detail.candidates.map((c, i) => {
      const key = 'poi:' + c.ctrip_poi_id;
      return `<div class="row ${decTag(key)}">
        <div class="idx" style="color:#57606a">${String.fromCharCode(97 + (i % 26))}</div>
        <div>
          <div class="name">${c.ctrip_url ? `<a href="${esc(c.ctrip_url)}" target="_blank" rel="noopener">${esc(c.ctrip_poi_name)} ↗</a>` : esc(c.ctrip_poi_name)}</div>
          <div class="muted"><span class="tag">${esc(c.relation_type)}</span><span class="tag">${esc(c.confidence)}</span>${esc(c.triage_result || '')}
            · poiId ${esc(c.ctrip_poi_id)} ${c.ctrip_district_name ? '· ' + esc(c.ctrip_district_name) : ''} ${c.dist_to_anchor_m != null ? '· ' + fmtDist(c.dist_to_anchor_m) : ''} · 图${esc(c.image_qty ?? 0)}
            ${searchedPoi.has(String(c.ctrip_poi_id)) ? '<span class="tag sight">搜索结果中也有</span>' : ''}</div>
          <div class="muted">${esc(c.match_evidence || '')}${c.also_in_scenic_ids ? ' · 也挂在 ' + esc(c.also_in_scenic_ids) : ''}</div>
        </div>
        <div class="acts">
          <button class="keep ${S.decisions[key] === 'keep' ? 'on' : ''}" data-ckeep="${i}">保留</button>
          <button class="drop ${S.decisions[key] === 'drop' ? 'on' : ''}" data-cdrop="${i}">不留</button>
        </div></div>`;
    }).join('') : '<div class="muted">无离线候选（未导入候选表，或规则没匹配到）</div>';

    const keptOther = S.detail.decisions.filter((d) => !S.results.some((r) => r.key === d.ctrip_key) && !S.detail.candidates.some((c) => 'poi:' + c.ctrip_poi_id === d.ctrip_key));
    const keptCount = Object.values(S.decisions).filter((v) => v === 'keep').length;

    b.innerHTML = `
      <div class="card">
        <h3>${esc(s.name)} <span class="tag ${s.grade === '5A' ? 'g5' : ''}">${esc(s.grade || '')}</span>
          ${st ? `<span class="tag ${st.status === 'done' ? 'cand' : 'warn'}">${st.status === 'done' ? '已完成' : '已跳过'}</span>` : ''}</h3>
        <div class="muted">${esc(s.id)} · ${esc([s.province, s.city, s.district].filter(Boolean).join(' / '))}</div>
        <div class="muted">${esc(s.address || '')}${slat != null ? ` · (${slng}, ${slat})` : ''}</div>
        ${s.alias ? `<div class="muted">别名：${esc(s.alias)}</div>` : ''}
        ${s.core_spots ? `<div class="muted">核心景点：${esc(s.core_spots)}</div>` : ''}
        <div class="muted">已保留 <b>${keptCount}</b> 个携程POI</div>
      </div>
      <div class="chips">${chips}
        <input type="text" id="kw" placeholder="自定义关键词 /" style="width:140px" value="">
        <button id="kw-go">搜索</button>
        <label class="muted"><input type="checkbox" id="sight-only" ${cfg.sightOnly ? 'checked' : ''}> 只看景点</label>
      </div>
      <div class="sec">携程实时搜索 ${S.keyword ? `<span class="muted">「${esc(S.keyword)}」${S.searchTotal != null ? ' total=' + esc(S.searchTotal) : ''}</span>` : ''}</div>
      ${resHtml}
      <div class="sec">离线候选（${S.detail.candidates.length}）
        ${S.detail.candidates.length ? '<button id="apply-triage" title="自动保留→保留，自动删除→不留；已人工判过的不覆盖">采纳自动分流</button><button id="apply-high">高置信全保留</button>' : ''}</div>
      ${candHtml}
      ${keptOther.length ? `<div class="sec">其他已判定（${keptOther.length}）</div>` + keptOther.map((d) => `<div class="row ${d.decision}"><div></div><div><div class="name">${esc(d.ctrip_poi_name || d.ctrip_key)}</div><div class="muted">${esc(d.ctrip_key)} · ${esc(d.source)} · ${esc(d.keyword || '')}</div></div><div></div></div>`).join('') : ''}`;
  }

  // ------------------------------------------------------------------ events
  root.addEventListener('click', async (ev) => {
    const t = ev.target.closest('button'); if (!t) return;
    const ds = t.dataset;
    try {
      if (t.id === 'fab') { $('#panel').classList.remove('hidden'); t.style.display = 'none'; if (!S.list.length) await start(); }
      else if (t.id === 'close') { $('#panel').classList.add('hidden'); $('#fab').style.display = ''; }
      else if (t.id === 'gear') $('#settings').classList.toggle('open');
      else if (t.id === 'prev') await go(-1);
      else if (t.id === 'next') await go(1);
      else if (t.id === 'done') await finish('done');
      else if (t.id === 'skip') await finish('skip');
      else if (t.id === 'f-apply') { readFilters(); await start(); }
      else if (t.id === 'export') window.open(cfg.backend.replace(/\/$/, '') + '/api/export.csv', '_blank');
      else if (t.id === 's-save' || t.id === 's-test') await saveSettings(t.id === 's-test');
      else if (t.id === 'kw-go') await doSearch($('#kw').value);
      else if (t.id === 'apply-triage') await applyOffline('triage');
      else if (t.id === 'apply-high') await applyOffline('high');
      else if (ds.kw) await doSearch(ds.kw);
      else if (ds.raw) { S.rawOpen[ds.raw] = !S.rawOpen[ds.raw]; render(); }
      else if (ds.keep) await setDecision(S.results.find((r) => r.idx == ds.keep), 'keep', 'search');
      else if (ds.drop) await setDecision(S.results.find((r) => r.idx == ds.drop), 'drop', 'search');
      else if (ds.ckeep) await setDecision(candAsItem(S.detail.candidates[ds.ckeep]), 'keep', 'candidate');
      else if (ds.cdrop) await setDecision(candAsItem(S.detail.candidates[ds.cdrop]), 'drop', 'candidate');
    } catch (e) { toast(e.message, true); }
  });
  root.addEventListener('change', (ev) => {
    if (ev.target.id === 'sight-only') { cfg.sightOnly = ev.target.checked; saveCfg(); render(); }
  });
  root.addEventListener('keydown', async (ev) => {
    if (ev.target.id === 'kw' && ev.key === 'Enter') { ev.preventDefault(); ev.stopPropagation(); await doSearch(ev.target.value); }
  }, true);
  document.addEventListener('keydown', async (ev) => {
    if ($('#panel').classList.contains('hidden')) return;
    const path = ev.composedPath ? ev.composedPath() : [ev.target];
    const inField = path.some((el) => el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT' || el.isContentEditable));
    if (ev.key === 'Escape') { $('#close').click(); return; }
    if (inField || ev.ctrlKey || ev.metaKey || ev.altKey) return;
    const m = ev.code && ev.code.match(/^Digit([1-9])$/);
    try {
      if (m) {
        const r = S.results.find((x) => x.idx == m[1]);
        if (r) { ev.preventDefault(); await setDecision(r, ev.shiftKey ? 'drop' : 'keep', 'search'); }
      } else if (ev.key === 'Enter') { ev.preventDefault(); await finish('done'); }
      else if (ev.key === 's' || ev.key === 'S') { ev.preventDefault(); await finish('skip'); }
      else if (ev.key === 'ArrowRight') { ev.preventDefault(); await go(1); }
      else if (ev.key === 'ArrowLeft') { ev.preventDefault(); await go(-1); }
      else if (ev.key === '/') { ev.preventDefault(); const k = $('#kw'); if (k) k.focus(); }
    } catch (e) { toast(e.message, true); }
  }, true);

  function readFilters() {
    cfg.filters = { city: $('#f-city').value, grade: $('#f-grade').value, status: $('#f-status').value, q: $('#f-q').value.trim() };
    saveCfg();
  }
  async function saveSettings(test) {
    cfg.backend = $('#s-backend').value.trim() || cfg.backend;
    cfg.reviewer = $('#s-reviewer').value.trim();
    cfg.throttleMs = Number($('#s-throttle').value || 0);
    const snippet = $('#s-fetch').value.trim();
    if (snippet) {
      try { cfg.template = parseFetchSnippet(snippet, $('#s-probe').value.trim()); }
      catch (e) { $('#s-state').textContent = '✗ ' + e.message; return; }
    }
    saveCfg();
    searchCache.clear();
    $('#s-state').textContent = cfg.template ? '✓ 已保存（模板：' + cfg.template.method + ' ' + cfg.template.url.slice(0, 60) + '…）' : '已保存（尚未配置搜索请求）';
    if (test) {
      const kw = $('#s-probe').value.trim() || (S.detail && S.detail.scenic.name) || '故宫博物院';
      try { const r = await ctripSearch(kw); $('#s-state').textContent = `✓ 测试「${kw}」返回 ${r.items.length} 条（total=${r.total}）`; }
      catch (e) { $('#s-state').textContent = '✗ ' + e.message; }
    }
  }
  function fillSettings() {
    $('#s-backend').value = cfg.backend; $('#s-reviewer').value = cfg.reviewer; $('#s-throttle').value = cfg.throttleMs;
    $('#s-state').textContent = cfg.template ? '已配置搜索请求：' + cfg.template.method + ' ' + cfg.template.url.slice(0, 60) + '…' : '尚未配置携程搜索请求';
    $('#f-grade').value = cfg.filters.grade || ''; $('#f-status').value = cfg.filters.status || 'todo'; $('#f-q').value = cfg.filters.q || '';
  }
  async function start() {
    fillSettings();
    try {
      const h = await api('GET', '/api/health');
      const cities = await api('GET', '/api/cities');
      const sel = $('#f-city');
      sel.innerHTML = `<option value="">默认城市（${esc(h.cities.join('、') || '全部')}）</option>` +
        cities.filter((c) => c.city).map((c) => `<option value="${esc(c.city)}">${esc(c.city)}（${c.reviewed || 0}/${c.n}）</option>`).join('');
      sel.value = cfg.filters.city || '';
      if (!cfg.template) $('#settings').classList.add('open');
      await loadList(true);
      S.detail = null;
      if (S.list.length) await go(1); else render();
    } catch (e) { $('#body').innerHTML = `<div class="muted">${esc(e.message)}</div>`; toast(e.message, true); }
  }
})();
