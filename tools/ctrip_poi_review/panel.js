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
  select, input[type=text], input[type=number] { font-size: 12px; padding: 4px 6px; border: 1px solid #d0d7de; border-radius: 6px; }
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
  .sec { margin: 10px 0 4px; font-weight: 600; display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
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
    <label>核对人</label><input type="text" id="s-reviewer" style="width:100%" placeholder="写入 reviewer 字段">
    <label>两次搜索最小间隔（毫秒，实际会随机加 0–40%）</label><input type="number" id="s-throttle" min="500" step="100">
    <label><input type="checkbox" id="s-auto"> 打开景区时自动搜索景区名</label>
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
      S.res = null; S.keyword = ''; S.rawOpen = {}; S.domOpen = false;
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

    // ---------------------------------------------------------------- render
    const results = () => ((S.res && S.res.items) || []).filter((r) => !prefs.sight_only || r.isSight);
    function render() {
      renderProgress();
      const b = $('#body');
      if (!S.detail) { b.innerHTML = `<div class="muted">${S.total === 0 ? '当前筛选下没有景区。' : '加载中…'}</div>`; return; }
      const s = S.detail.scenic, st = S.detail.status;
      const slat = num(s.lat), slng = num(s.lng);
      const candByPoi = {}, candByBiz = {};
      for (const c of S.detail.candidates) { candByPoi[c.ctrip_poi_id] = c; if (c.ctrip_business_id) candByBiz[c.ctrip_business_id] = c; }
      const dec = (key) => S.decisions[key] || '';
      const chips = keywordChips(s).map((k) => `<button class="chip ${k === S.keyword ? 'active' : ''}" data-kw="${esc(k)}">${esc(k)}</button>`).join('');
      const items = results();
      const capLabel = S.res ? ({ network: '下拉框结果', 'network?': '下拉框结果（关键词未完全匹配）', dom: '下拉框 DOM' }[S.res.capture] || S.res.capture) : '';
      const resHtml = S.loading ? '<div class="muted">正在携程页面输入并等待下拉结果…</div>' : items.length ? items.map((r) => {
        const c = (r.poiId && candByPoi[r.poiId]) || (r.businessId && candByBiz[r.businessId]);
        const d = haversine(slat, slng, r.lat, r.lng);
        return `<div class="row ${dec(r.key)} ${r.isSight ? '' : 'dim'}">
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
            <button class="keep ${dec(r.key) === 'keep' ? 'on' : ''}" data-keep="${r.idx}" ${r.key ? '' : 'disabled'}>保留</button>
            <button class="drop ${dec(r.key) === 'drop' ? 'on' : ''}" data-drop="${r.idx}" ${r.key ? '' : 'disabled'}>不留</button>
          </div></div>`;
      }).join('') : `<div class="muted">${S.keyword ? '无结果' : '点上面的关键词搜索'}</div>`;

      const searched = new Set(((S.res && S.res.items) || []).map((r) => r.poiId).filter(Boolean));
      const candHtml = S.detail.candidates.length ? S.detail.candidates.map((c, i) => {
        const key = 'poi:' + c.ctrip_poi_id;
        return `<div class="row ${dec(key)}">
          <div class="idx" style="color:#57606a">${String.fromCharCode(97 + (i % 26))}</div>
          <div>
            <div class="name">${c.ctrip_url ? `<a href="${esc(c.ctrip_url)}" target="_blank" rel="noopener">${esc(c.ctrip_poi_name)} ↗</a>` : esc(c.ctrip_poi_name)}</div>
            <div class="muted"><span class="tag">${esc(c.relation_type)}</span><span class="tag">${esc(c.confidence)}</span>${esc(c.triage_result || '')}
              · poiId ${esc(c.ctrip_poi_id)} ${c.ctrip_district_name ? '· ' + esc(c.ctrip_district_name) : ''} ${c.dist_to_anchor_m != null ? '· ' + fmtDist(c.dist_to_anchor_m) : ''} · 图${esc(c.image_qty ?? 0)}
              ${searched.has(String(c.ctrip_poi_id)) ? '<span class="tag sight">搜索结果中也有</span>' : ''}</div>
            <div class="muted">${esc(c.match_evidence || '')}${c.also_in_scenic_ids ? ' · 也挂在 ' + esc(c.also_in_scenic_ids) : ''}</div>
          </div>
          <div class="acts">
            <button class="keep ${dec(key) === 'keep' ? 'on' : ''}" data-ckeep="${i}">保留</button>
            <button class="drop ${dec(key) === 'drop' ? 'on' : ''}" data-cdrop="${i}">不留</button>
          </div></div>`;
      }).join('') : '<div class="muted">无离线候选（未导入候选表，或规则没匹配到）</div>';

      const shownKeys = new Set([...items.map((r) => r.key), ...S.detail.candidates.map((c) => 'poi:' + c.ctrip_poi_id)]);
      const other = S.detail.decisions.filter((d) => !shownKeys.has(d.ctrip_key));
      const keptCount = Object.values(S.decisions).filter((v) => v === 'keep').length;
      const dom = (S.res && S.res.dom) || [];

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
          <input type="text" id="kw" placeholder="自定义关键词 /" style="width:140px">
          <button id="kw-go">搜索</button>
          <label class="muted"><input type="checkbox" id="sight-only" ${prefs.sight_only ? 'checked' : ''}> 只看景点</label>
        </div>
        <div class="sec">携程搜索 ${S.keyword ? `<span class="muted">「${esc(S.keyword)}」${capLabel ? ' · ' + esc(capLabel) : ''}${S.res && S.res.total != null ? ' · total=' + esc(S.res.total) : ''}${S.res && S.res.cached ? ' · 缓存 ' + esc(S.res.searched_at) : ''}</span>
          <button id="re-search" title="在携程页面重新输入搜索 (R)">重新搜索</button>` : ''}</div>
        ${resHtml}
        ${dom.length ? `<div class="sec"><button id="dom-toggle">${S.domOpen ? '收起' : '查看'}下拉框原文（${dom.length}）</button></div>
          ${S.domOpen ? '<pre>' + esc(dom.map((d) => d.text + (d.href ? '  ' + d.href : '')).join('\n')) + '</pre>' : ''}` : ''}
        <div class="sec">离线候选（${S.detail.candidates.length}）
          ${S.detail.candidates.length ? '<button id="apply-triage" title="自动保留→保留，自动删除→不留；已人工判过的不覆盖">采纳自动分流</button><button id="apply-high">高置信全保留</button>' : ''}</div>
        ${candHtml}
        ${other.length ? `<div class="sec">其他已判定（${other.length}）</div>` + other.map((d) => `<div class="row ${d.decision}"><div></div><div><div class="name">${esc(d.ctrip_poi_name || d.ctrip_key)}</div><div class="muted">${esc(d.ctrip_key)} · ${esc(d.source)} · ${esc(d.keyword || '')}</div></div><div></div></div>`).join('') : ''}`;
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
          if (!S.list.length && !S.detail) await start();
        }
        else if (t.id === 'close') { $('#panel').classList.add('hidden'); $('#fab').style.display = ''; }
        else if (t.id === 'gear') $('#settings').classList.toggle('open');
        else if (t.id === 'prev') await go(-1);
        else if (t.id === 'next') await go(1);
        else if (t.id === 'done') await finish('done');
        else if (t.id === 'skip') await finish('skip');
        else if (t.id === 'f-apply') { await savePrefs({ filters: { city: $('#f-city').value, grade: $('#f-grade').value, status: $('#f-status').value, q: $('#f-q').value.trim() } }); await start(); }
        else if (t.id === 'export') { const r = await call('export'); toast('已导出：' + r.path); }
        else if (t.id === 's-save') { await savePrefs({ reviewer: $('#s-reviewer').value.trim(), throttle_ms: Number($('#s-throttle').value || 2500), auto_search: $('#s-auto').checked }); $('#s-state').textContent = '✓ 已保存'; }
        else if (t.id === 's-locate') {
          $('#s-sel').textContent = '请在左边携程页面上点一下搜索框…';
          $('#panel').style.opacity = '0.35';
          try { const r = await call('locate_input'); prefs.input_selector = r.selector; $('#s-sel').textContent = '✓ ' + r.selector; }
          finally { $('#panel').style.opacity = ''; }
        }
        else if (t.id === 'kw-go') await doSearch($('#kw').value, false);
        else if (t.id === 're-search') await doSearch(S.keyword, true);
        else if (t.id === 'dom-toggle') { S.domOpen = !S.domOpen; render(); }
        else if (t.id === 'apply-triage') await applyOffline('triage');
        else if (t.id === 'apply-high') await applyOffline('high');
        else if (ds.kw) await doSearch(ds.kw, false);
        else if (ds.raw) { S.rawOpen[ds.raw] = !S.rawOpen[ds.raw]; render(); }
        else if (ds.keep) await setDecision(results().find((r) => r.idx == ds.keep), 'keep', 'search');
        else if (ds.drop) await setDecision(results().find((r) => r.idx == ds.drop), 'drop', 'search');
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
          const r = results().find((x) => x.idx == m[1]);
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
