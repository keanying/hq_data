// 核对面板：由 review.py 通过 Playwright add_init_script 注入携程页面。
// 与 Python 的通信只走 window.hqCall(method, payload)（Playwright expose_binding）。
(() => {
  'use strict';
  if (window.top !== window || window.__hqPanel) return;
  window.__hqPanel = true;

  const call = async (method, payload) => {
    for (let i = 0; !window.hqCall && i < 100; i++) await new Promise((r) => setTimeout(r, 100));
    if (!window.hqCall) throw new Error('没连上 review.py：请用 python review.py run 打开的那个浏览器窗口');
    const r = await window.hqCall(method, payload || {});
    if (r && r.error) throw new Error(r.error);
    return r;
  };
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const num = (v) => { const n = parseFloat(v); return Number.isFinite(n) ? n : null; };
  function haversine(lat1, lng1, lat2, lng2) {
    if ([lat1, lng1, lat2, lng2].some((v) => v == null)) return null;
    const r = (d) => (d * Math.PI) / 180;
    const a = Math.sin(r(lat2 - lat1) / 2) ** 2 + Math.cos(r(lat1)) * Math.cos(r(lat2)) * Math.sin(r(lng2 - lng1) / 2) ** 2;
    return 6371000 * 2 * Math.asin(Math.sqrt(a));
  }
  const fmtDist = (m) => (m == null ? '' : m < 1000 ? `≈${Math.round(m)}m` : `≈${(m / 1000).toFixed(1)}km`);
  const normAddr = (a) => String(a || '').replace(/[（(][^)）]*[)）]/g, '').replace(/^中国/, '').replace(/^[^省]{2,8}省/, '')
    .replace(/^(北京|上海|天津|重庆)市/, '').replace(/^[^市]{2,8}市/, '').replace(/[\s,，。·\-—]/g, '');
  function addrSim(a, b) {
    a = normAddr(a); b = normAddr(b);
    if (a.length < 2 || b.length < 2) return null;
    const g = (x) => { const o = new Set(); for (let i = 0; i < x.length - 1; i++) o.add(x.slice(i, i + 2)); return o; };
    const A = g(a), B = g(b); let n = 0; A.forEach((x) => { if (B.has(x)) n++; });
    return n / (A.size + B.size - n || 1);
  }

  let prefs = {};
  const S = { list: [], total: 0, i: -1, detail: null, decisions: {}, res: null, keyword: '', loading: false, rawOpen: {}, domOpen: false };

  async function boot() {
    const ui = mount(); // 先把按钮放出来，出错也能看到原因
    let h;
    try { h = await call('hello'); }
    catch (e) { console.log('[hq] 面板初始化失败：' + e.message); ui.fail(e.message); return; }
    if (!h.main) { ui.remove(); return; } // 只在主窗口显示面板
    prefs = h.prefs;
    ui.ready(h);
  }

  function mount() {
    let hello = null, bootError = null;
    const host = document.createElement('div');
    host.id = 'hq-poi-review-host';
    document.documentElement.appendChild(host);
    const root = host.attachShadow({ mode: 'open' });
    root.innerHTML = `
<style>
  :host { all: initial; }
  * { box-sizing: border-box; font-family: -apple-system, "PingFang SC", "Microsoft YaHei", Arial, sans-serif; }
  .fab.err { background: #cf222e; }
  .fab { position: fixed; right: 16px; bottom: 16px; z-index: 2147483646; background: #0b6bcb; color: #fff; border: 0; border-radius: 20px; padding: 9px 14px; font-size: 13px; cursor: pointer; box-shadow: 0 2px 8px rgba(0,0,0,.25); }
  .panel { position: fixed; top: 0; right: 0; width: 600px; height: 100vh; z-index: 2147483647; background: #fff; border-left: 1px solid #d0d7de; box-shadow: -4px 0 16px rgba(0,0,0,.10); display: flex; flex-direction: column; font-size: 13px; color: #1f2328; }
  .panel.hidden { display: none; }
  .grip { position: absolute; left: -4px; top: 0; bottom: 0; width: 8px; cursor: ew-resize; z-index: 2; }
  .grip:hover, .grip.on { background: rgba(9,105,218,.25); }
  header { display: flex; align-items: center; gap: 6px; padding: 8px 12px; background: #f6f8fa; border-bottom: 1px solid #d0d7de; }
  header b { font-size: 14px; }
  header .grow { flex: 1; color: #57606a; font-size: 12px; }
  button { font-size: 12px; padding: 3px 8px; border: 1px solid #d0d7de; border-radius: 6px; background: #fff; cursor: pointer; color: #1f2328; white-space: nowrap; }
  button:hover { background: #f3f4f6; }
  button.primary { background: #1f883d; border-color: #1a7f37; color: #fff; }
  button.keep.on { background: #1f883d; border-color: #1a7f37; color: #fff; }
  button.drop.on { background: #cf222e; border-color: #a40e26; color: #fff; }
  button.link { border: 0; background: none; color: #0969da; padding: 0 2px; }
  button.link:hover { text-decoration: underline; background: none; }
  button:disabled { opacity: .4; cursor: not-allowed; }
  .filters { display: flex; gap: 6px; padding: 6px 12px; border-bottom: 1px solid #eaeef2; flex-wrap: wrap; align-items: center; }
  select, input[type=text], input[type=number] { font-size: 12px; padding: 4px 6px; border: 1px solid #d0d7de; border-radius: 6px; }
  .body { flex: 1; overflow: auto; padding: 10px 12px 80px; }
  .card { border: 1px solid #d0d7de; border-radius: 8px; padding: 10px 12px; margin-bottom: 10px; background: #fbfcfd; }
  .ttl { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-bottom: 6px; }
  .ttl h3 { margin: 0; font-size: 16px; }
  .ttl .kept { margin-left: auto; font-size: 12px; color: #1a7f37; }
  .kv { display: grid; grid-template-columns: 58px 1fr; gap: 3px 8px; font-size: 12px; line-height: 1.5; }
  .kv > span { color: #57606a; }
  .kv > div { color: #1f2328; word-break: break-all; }
  .muted { color: #57606a; font-size: 12px; }
  .tag { display: inline-block; padding: 0 6px; border-radius: 10px; font-size: 11px; line-height: 18px; background: #eaeef2; color: #424a53; white-space: nowrap; }
  .tag.g5 { background: #fff1e5; color: #bc4c00; } .tag.sight { background: #ddf4ff; color: #0969da; }
  .tag.good { background: #dafbe1; color: #1a7f37; } .tag.warn { background: #fff8c5; color: #7d4e00; } .tag.bad { background: #ffebe9; color: #cf222e; }
  .tools { display: flex; flex-wrap: wrap; gap: 4px; margin: 0 0 6px; align-items: center; }
  .chip { border-radius: 12px; padding: 2px 9px; }
  .chip.active { background: #0969da; color: #fff; border-color: #0969da; }
  .sec { margin: 12px 0 6px; display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
  .sec b { font-size: 13px; }
  .row { border: 1px solid #eaeef2; border-radius: 8px; padding: 8px 10px; margin-bottom: 6px; display: grid; grid-template-columns: 22px 1fr auto; gap: 4px 8px; align-items: start; background: #fff; }
  .row.keep { border-color: #1a7f37; background: #f6fff8; } .row.drop { border-color: #cf222e; background: #fffafa; opacity: .7; }
  .row.dim { opacity: .55; }
  .idx { font-weight: 700; color: #0969da; text-align: center; line-height: 20px; }
  .idx.c { color: #8c959f; }
  .l1 { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; line-height: 20px; }
  .l1 a { font-weight: 600; font-size: 14px; color: #1f2328; text-decoration: none; } .l1 a:hover { color: #0969da; text-decoration: underline; }
  .addr { margin-top: 3px; font-size: 13px; color: #1f2328; display: flex; gap: 6px; align-items: baseline; flex-wrap: wrap; }
  .addr .pin { color: #cf222e; }
  .addr .src { font-size: 11px; color: #8c959f; }
  .addr.none { color: #8c959f; }
  .meta { margin-top: 3px; font-size: 12px; color: #57606a; display: flex; gap: 4px 10px; flex-wrap: wrap; align-items: center; }
  .acts { display: flex; gap: 4px; }
  pre { grid-column: 2 / 4; white-space: pre-wrap; word-break: break-all; font-size: 11px; background: #f6f8fa; padding: 6px; border-radius: 6px; margin: 4px 0 0; max-height: 220px; overflow: auto; }
  footer { position: absolute; bottom: 0; left: 0; right: 0; background: #fff; border-top: 1px solid #d0d7de; padding: 8px 12px; display: flex; gap: 6px; align-items: center; }
  footer input { flex: 1; }
  .toast { position: absolute; left: 12px; right: 12px; bottom: 54px; background: #24292f; color: #fff; padding: 6px 10px; border-radius: 6px; font-size: 12px; display: none; }
  .toast.err { background: #a40e26; }
  .settings { padding: 10px 12px; border-bottom: 1px solid #d0d7de; background: #fffbea; display: none; }
  .settings.open { display: block; }
  .settings label { display: block; margin: 6px 0 2px; font-weight: 600; }
  .kbd { font-family: Menlo, Consolas, monospace; background: #eaeef2; border-radius: 4px; padding: 0 4px; font-size: 11px; }
  .help { font-size: 11px; color: #57606a; margin-top: 6px; line-height: 1.6; }
</style>
<button class="fab" id="fab">POI核对</button>
<div class="panel hidden" id="panel">
  <div class="grip" id="grip" title="拖动调整宽度"></div>
  <header>
    <b>景区 ↔ 携程POI</b>
    <span class="grow" id="progress"></span>
    <button id="prev" title="上一个 (←)">‹</button>
    <button id="next" title="下一个 (→)">›</button>
    <button id="gear" title="设置">⚙</button>
    <button id="close" title="收起 (Esc)">✕</button>
  </header>
  <div class="settings" id="settings">
    <label>核对人</label><input type="text" id="s-reviewer" style="width:100%" placeholder="写入 reviewer 字段">
    <label>两次搜索最小间隔（毫秒，实际会随机加 0–40%）</label><input type="number" id="s-throttle" min="500" step="100">
    <label><input type="checkbox" id="s-auto"> 打开景区时自动搜索景区名</label>
    <label><input type="checkbox" id="s-push"> 打开面板时把携程页面往左挤（不遮挡搜索框和下拉框）</label>
    <label><input type="checkbox" id="s-autoaddr"> 搜索后自动补全缺失地址（会逐个打开详情页，较慢）</label>
    <label>携程搜索框</label>
    <div style="display:flex;gap:6px;align-items:center"><button id="s-locate">定位搜索框</button><span class="muted" id="s-sel"></span></div>
    <div style="margin-top:8px;display:flex;gap:6px;align-items:center"><button class="primary" id="s-save">保存</button><span class="muted" id="s-state"></span></div>
    <div class="help">搜索方式：程序点击携程页面的搜索框并逐字输入，读取下拉框结果（页面自己发出的请求），不直接调接口。<br>
      快捷键：<span class="kbd">1</span>–<span class="kbd">9</span> 保留第 n 条（再按取消），<span class="kbd">Shift</span>+数字 不留，<span class="kbd">Enter</span> 完成并下一个，<span class="kbd">S</span> 跳过，<span class="kbd">←</span>/<span class="kbd">→</span> 翻景区，<span class="kbd">R</span> 重新搜索，<span class="kbd">/</span> 自定义关键词，<span class="kbd">Esc</span> 收起。</div>
  </div>
  <div class="filters">
    <select id="f-city"></select>
    <select id="f-grade"><option value="">全部等级</option><option>5A</option><option>4A</option><option>5A,4A</option><option>3A</option><option>2A</option><option>1A</option></select>
    <select id="f-status"><option value="todo">待核对</option><option value="done">已完成</option><option value="skip">已跳过</option><option value="all">全部</option></select>
    <input type="text" id="f-q" placeholder="景区名/ID" style="width:110px">
    <button id="f-apply">筛选</button>
    <button id="export" title="导出最终映射 CSV 到工具目录">导出</button>
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
    const savePrefs = async (p) => { prefs = await call('prefs', p); };
    const panelWidth = () => Math.min(Math.max(Number(prefs.panel_width) || 600, 420), Math.max(480, window.innerWidth - 360));
    function applyLayout() {
      const open = !$('#panel').classList.contains('hidden');
      const w = panelWidth();
      $('#panel').style.width = w + 'px';
      document.documentElement.style.setProperty('margin-right', open && prefs.push_page !== false ? w + 'px' : '', 'important');
    }
    (() => { // 拖动左边缘调整宽度
      let drag = null;
      $('#grip').addEventListener('mousedown', (e) => { drag = { x: e.clientX, w: panelWidth() }; $('#grip').classList.add('on'); e.preventDefault(); });
      window.addEventListener('mousemove', (e) => { if (!drag) return; prefs.panel_width = drag.w + (drag.x - e.clientX); applyLayout(); });
      window.addEventListener('mouseup', () => { if (!drag) return; drag = null; $('#grip').classList.remove('on'); savePrefs({ panel_width: panelWidth() }).catch(() => {}); });
      window.addEventListener('resize', applyLayout);
    })();

    // ---------------------------------------------------------------- navigation
    async function loadList(reset) {
      const f = prefs.filters || {};
      const offset = reset || f.status === 'todo' ? 0 : S.list.length;
      const r = await call('list', { filters: f, offset, limit: 200 });
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
      S.detail = await call('detail', { scenic_id: sid });
      S.decisions = {};
      for (const d of S.detail.decisions) S.decisions[d.ctrip_key] = d.decision;
      S.res = null; S.keyword = ''; S.rawOpen = {}; S.domOpen = false; S.othersOpen = false;
      $('#note').value = (S.detail.status && S.detail.status.note) || '';
      render();
      if (prefs.auto_search) await doSearch(S.detail.scenic.name, false);
    }
    function renderProgress() {
      const st = { todo: '待核对', done: '已完成', skip: '已跳过', all: '全部' }[(prefs.filters || {}).status] || '';
      $('#progress').textContent = S.detail ? `${st} 第 ${S.i + 1} / ${S.total}` : `${st} 共 ${S.total}`;
    }

    // ---------------------------------------------------------------- search
    function keywordChips(s) {
      const set = [];
      const add = (k) => { k = (k || '').trim(); if (k && !set.includes(k)) set.push(k); };
      add(s.name);
      (s.alias || '').split(/[,，、;；/]/).forEach(add);
      const city = (s.city || '').replace(/市$/, '');
      if (city && !(s.name || '').startsWith(city)) add(city + s.name);
      return set;
    }
    async function doSearch(kw, force) {
      kw = (kw || '').trim(); if (!kw) return;
      const sid = S.detail && S.detail.scenic.id;
      S.keyword = kw; S.loading = true; render();
      try {
        const r = await call('search', { keyword: kw, force: !!force });
        if (!S.detail || S.detail.scenic.id !== sid || S.keyword !== kw) return; // 已切走
        S.res = r;
      } catch (e) {
        S.res = null; toast(e.message, true);
      } finally { S.loading = false; render(); }
      if (prefs.auto_address && S.res && S.detail && S.detail.scenic.id === sid) await fillAddresses();
    }

    // ---------------------------------------------------------------- decisions
    async function setDecision(item, decision, source) {
      if (!item) return;
      const s = S.detail.scenic, key = item.key;
      if (!key) { toast('该条没有 poiId/景点ID，无法保存（通常是酒店、目的地等非景点结果）', true); return; }
      const next = S.decisions[key] === decision ? null : decision;
      try {
        const r = await call('decision', {
          scenic_id: s.id, decision: next, source, keyword: S.keyword || null, reviewer: prefs.reviewer || null,
          ctrip_poi_id: item.poiId, ctrip_business_id: item.businessId, ctrip_poi_name: item.name, ctrip_type: item.type,
          ctrip_city_name: item.cityName, ctrip_district_name: item.districtName, ctrip_lat: item.lat, ctrip_lng: item.lng,
          ctrip_url: item.url, raw_json: item.raw || null,
        });
        const k = r.ctrip_key || key;
        delete S.decisions[key];
        if (next) S.decisions[k] = next; else delete S.decisions[k];
        const arr = S.detail.decisions.filter((d) => d.ctrip_key !== k);
        if (next) arr.push({ ctrip_key: k, ctrip_poi_id: item.poiId, ctrip_business_id: item.businessId, ctrip_poi_name: item.name, source, keyword: S.keyword || null, decision: next });
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
      let n = 0;
      for (const c of (S.detail && S.detail.candidates) || []) {
        const it = candAsItem(c);
        let d = null;
        if (mode === 'high') d = c.confidence === '高' ? 'keep' : null;
        if (mode === 'triage') d = c.triage_result === '自动保留' ? 'keep' : c.triage_result === '自动删除' ? 'drop' : null;
        if (!d || S.decisions[it.key]) continue; // 已人工判过的不覆盖
        await setDecision(it, d, 'candidate'); n++;
      }
      toast(`已批量写入 ${n} 条`);
    }
    async function finish(status) {
      if (!S.detail) return;
      try {
        await call('status', { scenic_id: S.detail.scenic.id, status, note: $('#note').value || null, reviewer: prefs.reviewer || null });
        toast(status === 'done' ? '已完成' : '已跳过');
        if ((prefs.filters || {}).status === 'todo') { S.list.splice(S.i, 1); S.total = Math.max(0, S.total - 1); S.i -= 1; }
        await go(1);
      } catch (e) { toast('保存失败：' + e.message, true); }
    }

    // ---------------------------------------------------------------- address
    async function fetchAddr(it, quiet) {
      if (!it || !it.url || it.addrLoading) return;
      it.addrLoading = true; render();
      try {
        const r = await call('fetch_address', { url: it.url, poiId: it.poiId || it.ctrip_poi_id, businessId: it.businessId || it.ctrip_business_id, name: it.name || it.ctrip_poi_name });
        it.address = r.address; it.addressSource = r.addressSource;
      } catch (e) { it.addrError = e.message; if (!quiet) toast(e.message, true); }
      finally { it.addrLoading = false; render(); }
    }
    async function fillAddresses() {
      const todo = [...shown().sights, ...((S.detail && S.detail.candidates) || [])].filter((x) => !x.address && (x.url || x.ctrip_url) && !x.addrError);
      if (!todo.length) { toast('当前没有需要补地址的条目'); return; }
      const sid = S.detail.scenic.id;
      for (let i = 0; i < todo.length; i++) {
        if (!S.detail || S.detail.scenic.id !== sid) return;
        const x = todo[i];
        if (!x.url) x.url = x.ctrip_url;
        toast(`补地址 ${i + 1}/${todo.length}：${x.name || x.ctrip_poi_name}`);
        await fetchAddr(x, true);
      }
      toast('地址补全完成');
    }

    // ---------------------------------------------------------------- render
    // 结果显示顺序：景点在前（编号 1..n，对应数字快捷键），酒店等非景点折叠在后
    // 带 poiId 的、或类型是景点/购物/玩乐/美食等的都算 POI，参与核对；酒店、目的地等折叠
    const POI_TYPES = new Set(['sight', 'shop', 'shopping', 'play', 'entertainment', 'restaurant', 'food', 'poi', 'scenic', '景点', '购物', '玩乐', '娱乐', '美食']);
    const isPoi = (r) => !!(r.isPoi || r.isSight || r.poiId || POI_TYPES.has(String(r.type || '').toLowerCase()));
    function shown() {
      const all = (S.res && S.res.items) || [];
      const sights = all.filter(isPoi), others = all.filter((r) => !isPoi(r));
      const list = [...sights, ...(S.othersOpen && !prefs.sight_only ? others : [])];
      list.forEach((r, i) => { r.n = i + 1; });
      return { sights, others, list };
    }
    const byN = (n) => shown().list.find((r) => r.n == n);

    function addrBadges(addr, s) {
      if (!addr) return '';
      const out = [];
      const sim = addrSim(addr, s.address);
      if (sim != null && sim >= 0.4) out.push('<span class="tag good">地址相近</span>');
      if (s.district) {
        if (addr.includes(s.district)) out.push('<span class="tag good">同区</span>');
        else if (/[区县]/.test(normAddr(addr).slice(0, 8))) out.push('<span class="tag bad">不同区</span>');
      }
      return out.join('');
    }
    function addrLine(it, s, fetchAttr) {
      if (it.address) {
        return `<div class="addr"><span class="pin">📍</span><span>${esc(it.address)}</span>${addrBadges(it.address, s)}<span class="src">${esc(it.addressSource || '')}</span></div>`;
      }
      if (it.addrLoading) return '<div class="addr none">📍 正在打开详情页读取地址…</div>';
      const url = it.url || it.ctrip_url;
      return `<div class="addr none">📍 ${it.addrError ? '没读到地址' : '暂无地址'}${url ? ` <button class="link" ${fetchAttr}>查地址</button>` : ''}</div>`;
    }
    function candTag(c) {
      if (!c) return '';
      const cls = c.triage_result === '自动删除' ? 'warn' : c.triage_result === '自动保留' ? 'good' : '';
      return `<span class="tag ${cls}" title="${esc(c.match_evidence || '')}">离线候选 ${esc(c.relation_type.slice(0, 2))}·${esc(c.confidence)}${c.triage_result ? '·' + esc(c.triage_result) : ''}</span>`;
    }

    function render() {
      renderProgress();
      const b = $('#body');
      if (!S.detail) { b.innerHTML = `<div class="muted">${S.total === 0 ? '当前筛选下没有景区。' : '加载中…'}</div>`; return; }
      const s = S.detail.scenic, st = S.detail.status;
      const slat = num(s.lat), slng = num(s.lng);
      const candByPoi = {}, candByBiz = {};
      for (const c of S.detail.candidates) { candByPoi[c.ctrip_poi_id] = c; if (c.ctrip_business_id) candByBiz[c.ctrip_business_id] = c; }
      const dec = (key) => S.decisions[key] || '';
      const { sights, others, list } = shown();
      const capLabel = S.res ? ({ network: '下拉框结果', 'network?': '接口有返回但没解析出条目', dom: '只读到下拉框文字（没有ID，不能保存）' }[S.res.capture] || S.res.capture) : '';
      const capHint = S.res && S.res.capture !== 'network' && !S.loading
        ? '<div class="muted" style="color:#9a6700;margin:2px 0 6px">没读到携程接口返回。按 R 重新搜索；仍不行请把 tools/ctrip_poi_review/debug/last_search.json 发给开发排查。</div>' : '';

      const resRow = (r) => {
        const c = (r.poiId && candByPoi[r.poiId]) || (r.businessId && candByBiz[r.businessId]);
        const d = haversine(slat, slng, r.lat, r.lng);
        const poi = isPoi(r);
        return `<div class="row ${dec(r.key)} ${poi ? '' : 'dim'}">
          <div class="idx">${r.n}</div>
          <div>
            <div class="l1">${r.url ? `<a href="${esc(r.url)}" target="_blank" rel="noopener" title="在新标签页打开携程页面">${esc(r.name)}</a>` : `<b>${esc(r.name)}</b>`}
              <span class="tag ${poi ? 'sight' : ''}">${esc(r.type || '?')}</span>${r.level ? `<span class="tag ${r.level === '5A' ? 'g5' : ''}">${esc(r.level)}</span>` : ''}${candTag(c)}</div>
            ${poi ? addrLine(r, s, `data-fetch="${r.n}"`) : ''}
            <div class="meta">
              ${[r.cityName, r.districtName].filter(Boolean).length ? `<span>${esc([...new Set([r.cityName, r.districtName].filter(Boolean))].join(' / '))}</span>` : ''}
              ${r.poiId ? `<span>poiId ${esc(r.poiId)}</span>` : ''}${r.businessId ? `<span>景点ID ${esc(r.businessId)}</span>` : ''}
              ${d != null ? `<span>距客户坐标 ${fmtDist(d)}</span>` : ''}${d != null && d > 5000 ? '<span class="tag warn">距离较远</span>' : ''}
              <button class="link" data-raw="${r.n}">原始</button>
            </div>
          </div>
          <div class="acts">
            <button class="keep ${dec(r.key) === 'keep' ? 'on' : ''}" data-keep="${r.n}" ${r.key ? '' : 'disabled'} title="保留 (${r.n})">保留</button>
            <button class="drop ${dec(r.key) === 'drop' ? 'on' : ''}" data-drop="${r.n}" ${r.key ? '' : 'disabled'} title="不留 (Shift+${r.n})">不留</button>
          </div>
          ${S.rawOpen[r.key || r.name] ? `<pre>${esc(JSON.stringify(r.raw, null, 2))}</pre>` : ''}
        </div>`;
      };
      let resHtml;
      if (S.loading) resHtml = '<div class="muted">正在携程页面输入并等待下拉结果…</div>';
      else if (!(S.res && S.res.items && S.res.items.length)) resHtml = `<div class="muted">${S.keyword ? '无结果' : '点上面的关键词搜索'}</div>`;
      else {
        resHtml = list.map(resRow).join('') || '<div class="muted">没有景点/购物等 POI 类结果</div>';
        if (others.length && !prefs.sight_only) resHtml += `<div class="muted" style="margin:2px 0 6px"><button class="link" id="others-toggle">${S.othersOpen ? '收起' : '展开'}其他结果（酒店/目的地等 ${others.length} 条）</button></div>`;
      }

      const searched = new Set(((S.res && S.res.items) || []).map((r) => r.poiId).filter(Boolean));
      const candHtml = S.detail.candidates.length ? S.detail.candidates.map((c, i) => {
        const key = 'poi:' + c.ctrip_poi_id;
        return `<div class="row ${dec(key)}">
          <div class="idx c">${String.fromCharCode(97 + (i % 26))}</div>
          <div>
            <div class="l1">${c.ctrip_url ? `<a href="${esc(c.ctrip_url)}" target="_blank" rel="noopener">${esc(c.ctrip_poi_name)}</a>` : `<b>${esc(c.ctrip_poi_name)}</b>`}
              ${c.level ? `<span class="tag ${c.level === '5A' ? 'g5' : ''}">${esc(c.level)}</span>` : ''}<span class="tag">${esc(c.relation_type)}</span><span class="tag">${esc(c.confidence)}</span>
              ${c.triage_result ? `<span class="tag ${c.triage_result === '自动删除' ? 'warn' : c.triage_result === '自动保留' ? 'good' : ''}">${esc(c.triage_result)}</span>` : ''}
              ${searched.has(String(c.ctrip_poi_id)) ? '<span class="tag sight">搜索结果中也有</span>' : ''}</div>
            ${addrLine(c, s, `data-cfetch="${i}"`)}
            <div class="meta"><span>poiId ${esc(c.ctrip_poi_id)}</span>${c.ctrip_business_id ? `<span>景点ID ${esc(c.ctrip_business_id)}</span>` : ''}
              ${c.dist_to_anchor_m != null ? `<span>距锚点 ${fmtDist(c.dist_to_anchor_m)}</span>` : ''}<span>图片 ${esc(c.image_qty ?? 0)}</span>
              <span>${esc(c.match_evidence || '')}</span>${c.also_in_scenic_ids ? `<span class="tag warn">也挂在 ${esc(c.also_in_scenic_ids)}</span>` : ''}</div>
          </div>
          <div class="acts">
            <button class="keep ${dec(key) === 'keep' ? 'on' : ''}" data-ckeep="${i}">保留</button>
            <button class="drop ${dec(key) === 'drop' ? 'on' : ''}" data-cdrop="${i}">不留</button>
          </div></div>`;
      }).join('') : '<div class="muted">无离线候选（未导入候选表，或规则没匹配到）</div>';

      const shownKeys = new Set([...((S.res && S.res.items) || []).map((r) => r.key), ...S.detail.candidates.map((c) => 'poi:' + c.ctrip_poi_id)]);
      const other = S.detail.decisions.filter((d) => !shownKeys.has(d.ctrip_key));
      const keptCount = Object.values(S.decisions).filter((v) => v === 'keep').length;
      const dom = (S.res && S.res.dom) || [];
      const missingAddr = sights.filter((r) => !r.address && r.url).length + S.detail.candidates.filter((c) => !c.address && c.ctrip_url).length;
      const chips = keywordChips(s).map((k) => `<button class="chip ${k === S.keyword ? 'active' : ''}" data-kw="${esc(k)}">${esc(k)}</button>`).join('');

      b.innerHTML = `
        <div class="card">
          <div class="ttl"><h3>${esc(s.name)}</h3><span class="tag ${s.grade === '5A' ? 'g5' : ''}">${esc(s.grade || '')}</span>
            ${st ? `<span class="tag ${st.status === 'done' ? 'good' : 'warn'}">${st.status === 'done' ? '已完成' : '已跳过'}</span>` : ''}
            <span class="kept">已保留 <b>${keptCount}</b> 个携程POI</span></div>
          <div class="kv">
            <span>景区ID</span><div>${esc(s.id)}</div>
            <span>省市区</span><div>${esc([s.province, s.city, s.district].filter(Boolean).join(' / '))}</div>
            <span>地址</span><div><b>${esc(s.address || '—')}</b></div>
            <span>坐标</span><div>${slat != null ? `${slng}, ${slat}` : '—'}</div>
            ${s.alias ? `<span>别名</span><div>${esc(s.alias)}</div>` : ''}
            ${s.core_spots ? `<span>核心景点</span><div>${esc(s.core_spots)}</div>` : ''}
          </div>
        </div>
        <div class="tools">${chips}</div>
        <div class="tools">
          <input type="text" id="kw" placeholder="自定义关键词（按 / 聚焦）" style="flex:1;min-width:140px">
          <button id="kw-go">搜索</button>
          <label class="muted"><input type="checkbox" id="sight-only" ${prefs.sight_only ? 'checked' : ''}> 不显示酒店等非POI</label>
        </div>
        <div class="sec"><b>携程搜索</b>${S.keyword ? `<span class="muted">「${esc(S.keyword)}」${capLabel ? ' · ' + esc(capLabel) : ''}${S.res && S.res.cached ? ' · 缓存 ' + esc(S.res.searched_at) : ''}</span>
          <button id="re-search" title="在携程页面重新输入搜索 (R)">重新搜索</button>` : ''}
          ${missingAddr ? `<button id="fill-addr" title="逐个打开携程详情页读取地址">补全地址（${missingAddr}）</button>` : ''}</div>
        ${capHint}${resHtml}
        ${dom.length ? `<div class="muted"><button class="link" id="dom-toggle">${S.domOpen ? '收起' : '查看'}下拉框原文（${dom.length}）</button></div>
          ${S.domOpen ? '<pre style="grid-column:auto">' + esc(dom.map((d) => d.text + (d.href ? '  ' + d.href : '')).join('\n')) + '</pre>' : ''}` : ''}
        <div class="sec"><b>离线候选（${S.detail.candidates.length}）</b>
          ${S.detail.candidates.length ? '<button id="apply-triage" title="自动保留→保留，自动删除→不留；已人工判过的不覆盖">采纳自动分流</button><button id="apply-high">高置信全保留</button>' : ''}</div>
        ${candHtml}
        ${other.length ? `<div class="sec"><b>其他已判定（${other.length}）</b></div>` + other.map((d) => `<div class="row ${d.decision}"><div></div><div><div class="l1"><b>${esc(d.ctrip_poi_name || d.ctrip_key)}</b></div><div class="meta"><span>${esc(d.ctrip_key)}</span><span>${esc(d.source)}</span><span>${esc(d.keyword || '')}</span></div></div><div></div></div>`).join('') : ''}`;
    }

    // ---------------------------------------------------------------- events
    root.addEventListener('click', async (ev) => {
      const t = ev.target.closest('button'); if (!t) return;
      const ds = t.dataset;
      try {
        if (t.id === 'fab') {
          $('#panel').classList.remove('hidden'); t.style.display = 'none';
          if (bootError) { $('#body').innerHTML = '<div class="muted" style="color:#cf222e;white-space:pre-wrap">面板没能连上数据：\n' + esc(bootError) + '\n\n请看运行 review.py 的终端里的提示。</div>'; return; }
          if (!hello) { $('#body').innerHTML = '<div class="muted">正在连接 review.py…</div>'; return; }
          applyLayout();
          if (!S.list.length && !S.detail) await start();
        }
        else if (t.id === 'close') { $('#panel').classList.add('hidden'); $('#fab').style.display = ''; applyLayout(); }
        else if (t.id === 'gear') $('#settings').classList.toggle('open');
        else if (t.id === 'prev') await go(-1);
        else if (t.id === 'next') await go(1);
        else if (t.id === 'done') await finish('done');
        else if (t.id === 'skip') await finish('skip');
        else if (t.id === 'f-apply') { await savePrefs({ filters: { city: $('#f-city').value, grade: $('#f-grade').value, status: $('#f-status').value, q: $('#f-q').value.trim() } }); await start(); }
        else if (t.id === 'export') { const r = await call('export'); toast('已导出：' + r.path); }
        else if (t.id === 's-save') {
          await savePrefs({ reviewer: $('#s-reviewer').value.trim(), throttle_ms: Number($('#s-throttle').value || 2500), auto_search: $('#s-auto').checked,
            push_page: $('#s-push').checked, auto_address: $('#s-autoaddr').checked });
          applyLayout(); $('#s-state').textContent = '✓ 已保存';
        }
        else if (t.id === 's-locate') {
          $('#s-sel').textContent = '请在左边携程页面上点一下搜索框…';
          $('#panel').style.opacity = '0.35';
          try { const r = await call('locate_input'); prefs.input_selector = r.selector; $('#s-sel').textContent = '✓ ' + r.selector; }
          finally { $('#panel').style.opacity = ''; }
        }
        else if (t.id === 'kw-go') await doSearch($('#kw').value, false);
        else if (t.id === 're-search') await doSearch(S.keyword, true);
        else if (t.id === 'dom-toggle') { S.domOpen = !S.domOpen; render(); }
        else if (t.id === 'others-toggle') { S.othersOpen = !S.othersOpen; render(); }
        else if (t.id === 'fill-addr') await fillAddresses();
        else if (ds.fetch) await fetchAddr(byN(ds.fetch));
        else if (ds.cfetch) { const c = S.detail.candidates[ds.cfetch]; c.url = c.ctrip_url; await fetchAddr(c); }
        else if (t.id === 'apply-triage') await applyOffline('triage');
        else if (t.id === 'apply-high') await applyOffline('high');
        else if (ds.kw) await doSearch(ds.kw, false);
        else if (ds.raw) { const r = byN(ds.raw); const k = r.key || r.name; S.rawOpen[k] = !S.rawOpen[k]; render(); }
        else if (ds.keep) await setDecision(byN(ds.keep), 'keep', 'search');
        else if (ds.drop) await setDecision(byN(ds.drop), 'drop', 'search');
        else if (ds.ckeep) await setDecision(candAsItem(S.detail.candidates[ds.ckeep]), 'keep', 'candidate');
        else if (ds.cdrop) await setDecision(candAsItem(S.detail.candidates[ds.cdrop]), 'drop', 'candidate');
      } catch (e) { toast(e.message, true); }
    });
    root.addEventListener('change', async (ev) => {
      if (ev.target.id === 'sight-only') { await savePrefs({ sight_only: ev.target.checked }); render(); }
    });
    root.addEventListener('keydown', async (ev) => {
      if (ev.target.id === 'kw' && ev.key === 'Enter') { ev.preventDefault(); ev.stopPropagation(); await doSearch(ev.target.value, false); }
    }, true);
    document.addEventListener('keydown', async (ev) => {
      if ($('#panel').classList.contains('hidden') || !ev.isTrusted) return;
      const path = ev.composedPath ? ev.composedPath() : [ev.target];
      const inField = path.some((el) => el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT' || el.isContentEditable));
      if (ev.key === 'Escape' && !inField) { $('#close').click(); return; }
      if (inField || ev.ctrlKey || ev.metaKey || ev.altKey || S.loading) return;
      const m = ev.code && ev.code.match(/^Digit([1-9])$/);
      try {
        if (m) {
          const r = byN(m[1]);
          if (r) { ev.preventDefault(); ev.stopPropagation(); await setDecision(r, ev.shiftKey ? 'drop' : 'keep', 'search'); }
        } else if (ev.key === 'Enter') { ev.preventDefault(); await finish('done'); }
        else if (ev.key === 's' || ev.key === 'S') { ev.preventDefault(); await finish('skip'); }
        else if (ev.key === 'r' || ev.key === 'R') { ev.preventDefault(); if (S.keyword) await doSearch(S.keyword, true); }
        else if (ev.key === 'ArrowRight') { ev.preventDefault(); await go(1); }
        else if (ev.key === 'ArrowLeft') { ev.preventDefault(); await go(-1); }
        else if (ev.key === '/') { ev.preventDefault(); const k = $('#kw'); if (k) k.focus(); }
      } catch (e) { toast(e.message, true); }
    }, true);

    function fillSettings() {
      $('#s-reviewer').value = prefs.reviewer || ''; $('#s-throttle').value = prefs.throttle_ms || 2500; $('#s-auto').checked = !!prefs.auto_search;
      $('#s-push').checked = prefs.push_page !== false; $('#s-autoaddr').checked = !!prefs.auto_address;
      $('#s-sel').textContent = prefs.input_selector ? '当前：' + prefs.input_selector : '未指定（自动识别）';
      const f = prefs.filters || {};
      $('#f-grade').value = f.grade || ''; $('#f-status').value = f.status || 'todo'; $('#f-q').value = f.q || '';
    }
    async function start() {
      fillSettings();
      try {
        const sel = $('#f-city');
        sel.innerHTML = `<option value="">默认城市（${esc((hello.health.cities || []).join('、') || '全部')}）</option>` +
          hello.cities.filter((c) => c.city).map((c) => `<option value="${esc(c.city)}">${esc(c.city)}（${c.reviewed || 0}/${c.n}）</option>`).join('');
        sel.value = (prefs.filters || {}).city || '';
        await loadList(true);
        S.detail = null;
        if (S.list.length) await go(1); else render();
      } catch (e) { $('#body').innerHTML = `<div class="muted">${esc(e.message)}</div>`; toast(e.message, true); }
    }

    return {
      ready(h) { hello = h; $('#fab').title = '景区 ↔ 携程POI 核对'; },
      fail(msg) { bootError = msg; const f = $('#fab'); f.classList.add('err'); f.textContent = 'POI核对（出错，点我看原因）'; },
      remove() { host.remove(); },
    };
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
})();
