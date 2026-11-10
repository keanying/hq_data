// 景区 POI 数据工作台（无构建、无第三方库）
(() => {
  'use strict';
  const $ = (s, el = document) => el.querySelector(s);
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const fmt = (n) => (n == null ? '—' : Number(n).toLocaleString('zh-CN'));
  const pct = (a, b) => (b ? (a / b) * 100 : 0);
  async function api(path, opt) {
    const r = await fetch(path, opt);
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(j.detail || `HTTP ${r.status}`);
    return j;
  }
  const post = (path, body) => api(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) });
  let toastT = null;
  function toast(msg, err) {
    const t = $('#toast'); t.textContent = msg; t.className = 'toast' + (err ? ' err' : ''); t.hidden = false;
    clearTimeout(toastT); toastT = setTimeout(() => (t.hidden = true), err ? 5000 : 2200);
  }
  const STATUS = { queued: ['排队中', 'gray'], running: ['运行中', 'run'], done: ['完成', 'ok'], failed: ['失败', 'bad'], cancelled: ['已取消', 'warn'], need_human: ['需要人工', 'bad'] };
  const statusPill = (s) => { const [t, c] = STATUS[s] || [s, 'gray']; return `<span class="pill ${c}">${t}</span>`; };
  const shortCity = (c) => String(c || '').replace(/(市|地区|自治州|盟)$/, '');
  const COLORS = ['#ff9ccc', '#9a7bff', '#5fd0e6', '#ffb36b', '#7ed6a5', '#f774b5', '#6c4dff'];
  const S = { cities: [], timers: {}, view: null };

  // ---------------------------------------------------------------- 图表（SVG）
  let gid = 0;
  function ring(p, label, colors = ['#7fd8ff', '#9a7bff'], size = 110) {
    const id = 'g' + (++gid), r = size / 2 - 11, c = 2 * Math.PI * r, v = Math.max(0, Math.min(100, p));
    return `<svg class="chart" viewBox="0 0 ${size} ${size}" style="width:${size}px;height:${size}px;flex:none">
      <defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${colors[0]}"/><stop offset="1" stop-color="${colors[1]}"/></linearGradient></defs>
      <circle cx="${size / 2}" cy="${size / 2}" r="${r}" stroke="#f1edff" stroke-width="16" fill="none"/>
      <circle cx="${size / 2}" cy="${size / 2}" r="${r}" stroke="url(#${id})" stroke-width="16" fill="none" stroke-linecap="round"
        stroke-dasharray="${(c * v) / 100} ${c}" transform="rotate(-90 ${size / 2} ${size / 2})"/>
      <text x="50%" y="50%" text-anchor="middle" dominant-baseline="central" style="font:700 17px Poppins,sans-serif;fill:#231c45">${label ?? v.toFixed(0) + '%'}</text></svg>`;
  }
  function gauge(p) {
    const id = 'g' + (++gid), v = Math.max(0, Math.min(100, p)), a = Math.PI * (1 - v / 100);
    const cx = 130, cy = 130, r = 100, x = cx + r * Math.cos(a), y = cy - r * Math.sin(a), nx = cx + 62 * Math.cos(a), ny = cy - 62 * Math.sin(a);
    return `<svg class="chart" viewBox="0 0 260 175" style="width:100%;max-width:300px;height:auto;display:block;margin:0 auto">
      <defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffd1e7"/><stop offset="1" stop-color="#f65a9f"/></linearGradient></defs>
      <path d="M30 130 A100 100 0 0 1 230 130" stroke="#f6eefb" stroke-width="30" fill="none" stroke-linecap="round"/>
      <path d="M30 130 A100 100 0 0 1 ${x.toFixed(1)} ${y.toFixed(1)}" stroke="url(#${id})" stroke-width="30" fill="none" stroke-linecap="round"/>
      <circle cx="${cx}" cy="${cy}" r="40" fill="#f1edff"/>
      <line x1="${cx}" y1="${cy}" x2="${nx.toFixed(1)}" y2="${ny.toFixed(1)}" stroke="#f774b5" stroke-width="12" stroke-linecap="round"/>
      <circle cx="${cx}" cy="${cy}" r="17" fill="#f774b5"/><circle cx="${cx}" cy="${cy}" r="8" fill="#fff"/></svg>
      <div style="text-align:center;font-size:26px;font-weight:700;margin-top:-6px">${v.toFixed(1)}%</div>`;
  }
  let barSeq = 0;
  function bars(labels, series, height = 230) {
    const n = labels.length || 1, w = Math.max(300, n * 64), max = Math.max(1, ...series.flatMap((s) => s.values));
    const top = 16, base = height - 26, bw = 12, gap = 6, gw = series.length * bw + (series.length - 1) * gap;
    const nice = (m) => { const p = Math.pow(10, Math.floor(Math.log10(m))); return Math.ceil(m / p) * p; };
    const ymax = nice(max), ticks = [0, .25, .5, .75, 1].map((t) => t * ymax);
    const uid = 'b' + (++barSeq) + '_';
    let g = '';
    ticks.forEach((t) => { const y = base - (base - top) * (t / ymax); g += `<line x1="40" x2="${w}" y1="${y}" y2="${y}" stroke="#f1edff"/><text x="34" y="${y + 4}" text-anchor="end" style="font:11px sans-serif;fill:#a9a3c2">${t >= 1000 ? (t / 1000).toFixed(t >= 10000 ? 0 : 1) + 'k' : t}</text>`; });
    labels.forEach((l, i) => {
      const cx = 40 + ((w - 40) / n) * (i + .5);
      series.forEach((s, k) => {
        const v = s.values[i] || 0, h = (base - top) * (v / ymax), x = cx - gw / 2 + k * (bw + gap);
        g += `<rect x="${x}" y="${base - h}" width="${bw}" height="${Math.max(h, 0)}" rx="6" fill="url(#${uid}${k})"><title>${esc(l)} ${esc(s.name)}：${fmt(v)}</title></rect>`;
      });
      g += `<text x="${cx}" y="${height - 6}" text-anchor="middle" style="font:12px sans-serif;fill:#8a84a6">${esc(l)}</text>`;
    });
    const defs = series.map((s, k) => `<linearGradient id="${uid}${k}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${s.color[0]}"/><stop offset="1" stop-color="${s.color[1]}"/></linearGradient>`).join('');
    const legend = series.map((s) => `<span style="display:inline-flex;align-items:center;gap:6px;margin-right:14px"><i style="width:10px;height:10px;border-radius:3px;background:${s.color[0]}"></i>${esc(s.name)}</span>`).join('');
    return `<div class="muted" style="margin-bottom:6px">${legend}</div><div style="overflow-x:auto"><svg class="chart" viewBox="0 0 ${w} ${height}" style="width:100%;min-width:${Math.min(w, 600)}px;height:${height}px"><defs>${defs}</defs>${g}</svg></div>`;
  }
  const PINK = ['#ffa9d2', '#f774b5'], PURPLE = ['#b9a2ff', '#7b5cff'], CYAN = ['#9fe7f5', '#4fb8e8'];

  const HERO_ART = `<svg class="art chart" viewBox="0 0 360 250">
    <ellipse cx="190" cy="240" rx="150" ry="10" fill="rgba(40,20,120,.18)"/>
    <rect x="70" y="150" width="240" height="10" rx="5" fill="#5b3fe0"/><rect x="95" y="160" width="8" height="78" fill="#5b3fe0"/><rect x="278" y="160" width="8" height="78" fill="#5b3fe0"/>
    <rect x="110" y="56" width="120" height="82" rx="10" fill="#fff"/><rect x="118" y="64" width="104" height="66" rx="6" fill="#efeaff"/>
    <path d="M150 116 l14 -22 l12 16 l8 -10 l14 16z" fill="#b9a2ff"/><circle cx="196" cy="82" r="7" fill="#ffd36b"/>
    <rect x="160" y="138" width="20" height="12" fill="#e9e3ff"/>
    <g transform="translate(250 40) rotate(10)"><rect width="70" height="56" rx="8" fill="#fff"/><rect x="6" y="6" width="58" height="34" rx="5" fill="#ffd1e7"/><path d="M14 36 l12 -14 l10 10 l8 -8 l14 12z" fill="#f774b5"/></g>
    <g transform="translate(244 100)"><path d="M22 0 a22 22 0 0 1 22 22 c0 16 -22 38 -22 38 s-22 -22 -22 -38 a22 22 0 0 1 22 -22z" fill="#ff8cc6"/><circle cx="22" cy="22" r="8" fill="#fff"/></g>
    <g transform="translate(60 92)"><rect x="6" y="40" width="20" height="18" rx="4" fill="#e86a8c"/><ellipse cx="16" cy="26" rx="14" ry="22" fill="#7ed6a5"/></g>
    <circle cx="70" cy="40" r="10" fill="rgba(255,255,255,.35)"/><circle cx="330" cy="20" r="6" fill="rgba(255,255,255,.35)"/></svg>`;

  // ---------------------------------------------------------------- 公共
  async function loadCities(force) {
    if (!S.cities.length || force) S.cities = (await api('/api/overview')).cities;
    return S.cities;
  }
  const cityOptions = (cur) => '<option value="">全部城市</option>' + S.cities.filter((c) => c.city).map((c) => `<option ${c.city === cur ? 'selected' : ''} value="${esc(c.city)}">${esc(c.city)}</option>`).join('');
  function every(key, ms, fn) { clearInterval(S.timers[key]); fn(); S.timers[key] = setInterval(() => { if (S.view === key.split(':')[0]) fn(); }, ms); }
  const formData = (form) => Object.fromEntries([...form.elements].filter((e) => e.name).map((e) => [e.name, e.type === 'checkbox' ? e.checked : e.value.trim()]));
  const params = () => Object.fromEntries(new URLSearchParams((location.hash.split('?')[1]) || ''));

  async function submitJob(type, p) {
    const j = await post('/api/jobs', { type, params: p });
    toast(`已提交任务 #${j.id}`);
    return j;
  }
  function jobsTable(js, opts = {}) {
    if (!js.length) return '<div class="empty">还没有任务</div>';
    return `<table><thead><tr><th>#</th><th>类型</th><th>状态</th><th>进度</th><th>开始</th><th>最新</th><th></th></tr></thead><tbody>${js.map((j) => {
      const p = j.total ? pct(j.done, j.total) : j.status === 'done' ? 100 : 0;
      return `<tr class="click ${opts.sel === j.id ? 'sel' : ''}" data-job="${j.id}"><td>${j.id}</td><td class="nw">${esc(j.type_name)}</td><td>${statusPill(j.status)}</td>
        <td style="min-width:140px"><div class="bar"><i style="width:${p.toFixed(1)}%"></i></div><span class="muted">${j.done}/${j.total || '?'}</span></td>
        <td class="muted nw">${esc((j.started || j.created || '').slice(5, 16))}</td><td class="muted" title="${esc(j.last)}" style="max-width:240px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${esc(j.last.slice(9))}</td>
        <td>${['queued', 'running'].includes(j.status) ? `<button class="btn line sm" data-cancel="${j.id}">取消</button>` : ''}</td></tr>`;
    }).join('')}</tbody></table>`;
  }
  async function bindJobsTable(root, onSelect) {
    root.addEventListener('click', async (e) => {
      const c = e.target.closest('[data-cancel]');
      if (c) { e.stopPropagation(); await post(`/api/jobs/${c.dataset.cancel}/cancel`); toast('已请求取消'); return; }
      const tr = e.target.closest('[data-job]');
      if (tr && onSelect) onSelect(+tr.dataset.job);
    });
  }
  function followHtml(f, compact) {
    const state = !f.enabled ? '<span class="pill gray">已关闭</span>' : f.paused ? '<span class="pill bad">已暂停</span>' : f.current ? '<span class="pill run">采集中</span>' : '<span class="pill ok">待命</span>';
    return `<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap"><b>边核对边采集</b>${state}
      <span class="muted">排队 ${f.pending} · 已采景区 ${f.done} · 新增图片 ${fmt(f.images)}${f.failed ? ' · 失败 ' + f.failed : ''}</span>
      <span class="grow" style="flex:1"></span>
      <label class="muted"><input type="checkbox" data-follow-toggle ${f.enabled ? 'checked' : ''}> 开启</label>
      ${f.paused ? '<button class="btn pri sm" data-follow="resume">继续</button>' : f.enabled ? '<button class="btn line sm" data-follow="pause">暂停</button>' : ''}</div>
      ${f.current ? `<div class="muted" style="margin-top:6px">正在采：${esc(f.current)}</div>` : ''}
      ${f.message ? `<div class="pill bad" style="margin-top:8px;white-space:normal">${esc(f.message)}</div>` : ''}
      ${compact ? '' : `<pre class="log short" style="margin-top:10px">${esc((f.log || []).join('\n') || '审核通过的景区会自动排进来，用服务端浏览器单独的标签页采集点评图片')}</pre>`}`;
  }
  document.addEventListener('click', async (e) => {
    const b = e.target.closest('[data-follow]');
    if (b) { await post('/api/follow', { [b.dataset.follow]: true }); refreshFollow(); }
  });
  document.addEventListener('change', async (e) => {
    if (e.target.matches('[data-follow-toggle]')) { await post('/api/follow', { enabled: e.target.checked }); refreshFollow(); }
  });
  async function refreshFollow() {
    const f = await api('/api/follow');
    document.querySelectorAll('[data-follow-box]').forEach((el) => (el.innerHTML = followHtml(f, el.dataset.followBox === 'compact')));
    return f;
  }

  // ---------------------------------------------------------------- 顶栏
  async function refreshTop() {
    try {
      const h = await api('/api/health');
      $('#reviewer').textContent = h.reviewer ? `核对人：${h.reviewer}` : '设置核对人';
      const f = await api('/api/follow');
      $('#bell .dot').hidden = !(h.need_human || f.paused);
      $('#bell').title = f.paused ? '图片采集已暂停（需要人工处理）' : `边核对边采集：排队 ${f.pending}`;
    } catch (e) { $('#reviewer').textContent = '服务未连接'; }
  }
  $('#user-chip').addEventListener('click', async () => {
    const name = prompt('核对人（写入进度表 reviewer 字段）', $('#reviewer').textContent.replace(/^核对人：|设置核对人/g, ''));
    if (name == null) return;
    await post('/api/rpc/prefs', { reviewer: name.trim() });
    refreshTop(); toast('已保存核对人');
  });
  $('#g-search').addEventListener('keydown', (e) => { if (e.key === 'Enter') location.hash = '#/data?q=' + encodeURIComponent(e.target.value.trim()); });

  // ---------------------------------------------------------------- 总览
  const V = {};
  V.overview = {
    async enter() { every('overview', 10000, () => this.render().catch((e) => toast(e.message, true))); },
    async render() {
      const [o, js, f] = await Promise.all([api('/api/overview'), api('/api/jobs'), api('/api/follow')]);
      S.cities = o.cities;
      const top = [...o.cities].sort((a, b) => b.n - a.n).slice(0, 8);
      const crawled = (o.crawl.done || 0) + (o.crawl.partial || 0);
      const today = new Date().toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'short' });
      $('#v-overview').innerHTML = `<div class="grid ov">
        <div class="card hero"><h1>景区 POI<br><span>数据工作台</span></h1><p>携程 POI 核对、点评图片采集、数据与图片预览，一个地方完成。审核通过的景区会自动采集图片。</p>
          <div class="btns"><a class="btn white" href="#/review">开始核对</a><a class="btn ghost" href="#/images">采集图片</a></div>${HERO_ART}</div>
        <div class="card right"><div class="label">已审核景区</div><div class="big">${fmt(o.approved)}</div><div class="date">${today}</div>
          <div class="muted" style="text-align:center;margin-top:6px">共 ${fmt(o.total)} · 待核对 ${fmt(o.todo)} · 跳过 ${fmt(o.skipped)}</div>
          <h3 style="margin-top:26px">各城市审核进度</h3>${bars(top.map((c) => shortCity(c.city)), [{ name: '已审核', values: top.map((c) => +c.reviewed || 0), color: PINK }, { name: '景区数', values: top.map((c) => +c.n || 0), color: PURPLE }], 260)}
          <h3 style="margin-top:18px">各城市图片</h3>${bars(top.map((c) => shortCity(c.city)), [{ name: '图片', values: top.map((c) => +c.images || 0), color: CYAN }], 170)}</div>
        <div class="card gauge-card"><h3>审核完成度</h3>${gauge(pct(o.approved, o.total))}
          <div class="stat-row"><div class="stat"><i style="background:linear-gradient(135deg,#8be3f2,#4fb8e8)"><svg viewBox="0 0 24 24"><path d="M13 2 3 14h9l-1 8 10-12h-9z"/></svg></i><div><span class="muted">自动通过</span><b>${fmt(o.auto_approved)}</b></div></div>
          <div class="stat"><i style="background:linear-gradient(135deg,#b9a2ff,#7b5cff)"><svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg></i><div><span class="muted">人工审核</span><b>${fmt(o.manual_approved)}</b></div></div></div></div>
        <div class="rings"><div class="card ring-card">${ring(pct(crawled, o.crawlable_pois), null, ['#7fd8ff', '#9a7bff'])}<div><b>POI 图片采集</b><span class="muted">${fmt(crawled)} / ${fmt(o.crawlable_pois)} 个 POI · 图片 ${fmt(o.images)} 张</span></div></div>
          <div class="card ring-card">${ring(pct(o.skipped, o.approved + o.skipped), null, ['#ffc3e0', '#f774b5'])}<div><b>待人工复核</b><span class="muted">已跳过 ${fmt(o.skipped)} 个，在核对页筛「已跳过」处理</span></div></div></div>
        <div class="card jobs-card"><h3>最近任务 <a class="muted" href="#/jobs" style="float:right">任务中心 →</a></h3>${jobsTable(js.slice(0, 5))}</div>
        <div class="card follow-card"><div data-follow-box="compact">${followHtml(f, true)}</div>
          <div class="muted" style="margin-top:14px">交付表 ${esc(o.ods_table)}：${o.ods_rows == null ? '未建' : fmt(o.ods_rows) + ' 行'}</div></div></div>`;
    },
  };

  // ---------------------------------------------------------------- 核对（嵌入核对面板 panel.js）
  V.review = {
    loaded: false,
    async enter() {
      if (!this.loaded) {
        this.loaded = true;
        $('#v-review').innerHTML = `<div class="page-head"><h2>核对</h2><span class="muted">搜索由服务端浏览器在携程搜索框里输入、读下拉结果；快捷键 1–9 保留、Enter 审核完成、S 跳过</span><span class="grow"></span></div>
          <div class="card" style="padding:14px 18px;margin-bottom:16px" data-follow-box="compact"></div>
          <div class="card review-wrap" id="review-host"></div>`;
        window.hqCall = (m, p) => post('/api/rpc/' + m, p).catch((e) => ({ error: e.message }));
        window.HQ_EMBED = $('#review-host');
        const sc = document.createElement('script'); sc.src = '/panel.js'; document.body.appendChild(sc);
      }
      const q = params().scenic_id;
      if (q) setTimeout(() => window.dispatchEvent(new CustomEvent('hq:open', { detail: { scenic_id: q } })), 600);
      every('review:follow', 4000, () => refreshFollow().catch(() => {}));
    },
  };

  // ---------------------------------------------------------------- 图片采集
  V.images = {
    async enter() {
      await loadCities();
      $('#v-images').innerHTML = `<div class="page-head"><h2>图片采集</h2><span class="muted">进入已审核 POI 的携程主页，翻点评页，把点评图片写进 MySQL</span></div>
        <div class="grid" style="grid-template-columns:1.2fr 1fr">
          <div class="card"><h3>批量采集</h3><form class="form" id="f-img">
            <select name="city">${cityOptions()}</select><input name="grade" placeholder="等级，如 5A,4A" style="width:130px"><input name="q" placeholder="景区名 / ID" style="width:140px">
            <label>每个 POI 最多 <input type="number" name="max_pages" value="20" min="1"> 页</label><label><input type="number" name="max_images" value="300" min="0"> 张</label>
            <label>最多 <input type="number" name="limit" value="0" min="0"> 个 POI</label><label><input type="checkbox" name="refresh"> 已采完的也重采</label>
            <button class="btn pri" type="submit">开始采集</button></form>
            <div class="muted" style="margin-top:12px">对已审核（approval=1）景区里保留的 POI：第一页读页面里的 __NEXT_DATA__，之后点「下一页」读 getCommentCollapseList；已采完的自动跳过。</div></div>
          <div class="card" data-follow-box="full"></div>
          <div class="card"><h3>各城市图片</h3><div id="img-bars"></div></div>
          <div class="card"><h3>POI 采集状态</h3><div id="img-rings" style="display:flex;gap:22px;flex-wrap:wrap"></div></div>
          <div class="card" style="grid-column:1/3"><h3>采集任务</h3><div id="img-jobs"></div></div></div>`;
      $('#f-img').addEventListener('submit', async (e) => { e.preventDefault(); await submitJob('images', formData(e.target)); this.render(); });
      bindJobsTable($('#img-jobs'), (id) => (location.hash = '#/jobs?id=' + id));
      every('images', 4000, () => this.render().catch(() => {}));
    },
    async render() {
      const [o, js] = await Promise.all([api('/api/overview'), api('/api/jobs'), refreshFollow()]);
      const cs = [...o.cities].sort((a, b) => b.images - a.images || b.n - a.n).slice(0, 10);
      $('#img-bars').innerHTML = bars(cs.map((c) => shortCity(c.city)), [{ name: '图片', values: cs.map((c) => c.images), color: CYAN }, { name: '已采 POI', values: cs.map((c) => c.pois), color: PURPLE }], 230);
      const cr = o.crawl, all = o.crawlable_pois || 0;
      $('#img-rings').innerHTML = [['完成', cr.done || 0, ['#9be9c0', '#2fbf71']], ['部分', cr.partial || 0, ['#ffe0a3', '#ffb020']], ['失败', cr.failed || 0, ['#ffc3d0', '#f0476c']]]
        .map(([n, v, c]) => `<div class="ring-card">${ring(pct(v, all), fmt(v), c, 96)}<div><b>${n}</b><span class="muted">共 ${fmt(all)} 个 POI</span></div></div>`).join('');
      $('#img-jobs').innerHTML = jobsTable(js.filter((j) => j.type === 'images').slice(0, 8));
    },
  };

  // ---------------------------------------------------------------- 数据预览
  V.data = {
    st: { offset: 0, limit: 30 },
    async enter() {
      await loadCities();
      const p = params();
      $('#v-data').innerHTML = `<div class="page-head"><h2>数据预览</h2><span class="grow"></span><a class="btn line sm" href="/api/export.csv">导出 CSV</a></div>
        <div class="card"><form class="form" id="f-data">
          <select name="city">${cityOptions()}</select>
          <select name="status"><option value="all">全部状态</option><option value="done">已审核</option><option value="todo">待核对</option><option value="skip">已跳过</option><option value="auto">自动通过</option></select>
          <input name="grade" placeholder="等级" style="width:90px"><input name="q" placeholder="景区名 / ID" value="${esc(p.q || '')}" style="width:200px">
          <button class="btn pri sm" type="submit">查询</button><span class="muted" id="data-info"></span></form>
          <div id="data-table" style="margin-top:12px"></div><div class="pager" id="data-pager"></div></div>`;
      $('#f-data').addEventListener('submit', (e) => { e.preventDefault(); this.st.offset = 0; this.load(); });
      $('#data-table').addEventListener('click', (e) => { const tr = e.target.closest('[data-sid]'); if (tr) this.open(tr.dataset.sid); });
      $('#data-pager').addEventListener('click', (e) => { const b = e.target.closest('[data-off]'); if (b) { this.st.offset = +b.dataset.off; this.load(); } });
      this.st.offset = 0; this.load();
    },
    async load() {
      const f = formData($('#f-data'));
      const qs = new URLSearchParams(Object.assign(f, { limit: this.st.limit, offset: this.st.offset }));
      const r = await api('/api/scenic_table?' + qs);
      this.rows = r.items;
      $('#data-info').textContent = `共 ${fmt(r.total)} 个景区`;
      const st = (x) => Number(x.approval) === 1 ? ((x.note || '').startsWith('自动审核') ? '<span class="pill ok">自动通过</span>' : '<span class="pill ok">已审核</span>') : x.status === 'skip' ? '<span class="pill warn">已跳过</span>' : '<span class="pill gray">待核对</span>';
      $('#data-table').innerHTML = r.items.length ? `<table><thead><tr><th>景区</th><th class="nw">城市 / 区县</th><th class="nw">等级</th><th class="nw">状态</th><th>保留的携程 POI</th><th class="num">图片</th><th>备注</th></tr></thead><tbody>${r.items.map((x) => `
        <tr class="click" data-sid="${esc(x.id)}"><td><b>${esc(x.name)}</b><div class="muted">${esc(x.id)}</div></td><td class="nw">${esc(shortCity(x.city))} / ${esc(x.district || '')}</td><td class="nw">${esc(x.grade || '')}</td><td class="nw">${st(x)}</td>
        <td><div class="chips">${x.pois.slice(0, 6).map((p) => `<span class="chip">${esc(p.poiName)}${p.images ? `<small>${p.images}</small>` : ''}</span>`).join('')}${x.pois.length > 6 ? `<span class="muted">+${x.pois.length - 6}</span>` : ''}</div></td>
        <td class="num">${fmt(x.images)}</td><td class="muted" style="max-width:260px">${esc((x.note || '').slice(0, 60))}</td></tr>`).join('')}</tbody></table>` : '<div class="empty">没有符合条件的景区</div>';
      const o = this.st.offset, l = this.st.limit;
      $('#data-pager').innerHTML = `<span class="muted">${fmt(o + 1)}–${fmt(Math.min(o + l, r.total))} / ${fmt(r.total)}</span>
        <button class="btn line sm" ${o <= 0 ? 'disabled' : ''} data-off="${Math.max(0, o - l)}">上一页</button><button class="btn line sm" ${o + l >= r.total ? 'disabled' : ''} data-off="${o + l}">下一页</button>`;
    },
    open(sid) {
      const x = (this.rows || []).find((r) => r.id === sid); if (!x) return;
      $('#drawer-body').innerHTML = `<div style="display:flex;align-items:center;gap:10px"><h2 style="margin:0">${esc(x.name)}</h2><span class="pill">${esc(x.grade || '')}</span><span class="grow" style="flex:1"></span><button class="btn line sm" data-close>关闭</button></div>
        <div class="kv" style="margin-top:14px"><span>景区ID</span><div>${esc(x.id)}</div><span>省市区</span><div>${esc([x.province, x.city, x.district].filter(Boolean).join(' / '))}</div>
          <span>地址</span><div>${esc(x.address || '—')}</div><span>坐标</span><div>${esc(x.lng || '')}, ${esc(x.lat || '')}</div><span>别名</span><div>${esc(x.alias || '—')}</div>
          <span>审核</span><div>${Number(x.approval) === 1 ? '已审核' : x.status === 'skip' ? '已跳过' : '待核对'} ${x.reviewer ? '· ' + esc(x.reviewer) : ''} ${x.updated_at ? '· ' + esc(x.updated_at) : ''}</div>
          <span>备注</span><div>${esc(x.note || '—')}</div></div>
        <div style="display:flex;gap:10px;margin:18px 0 6px"><a class="btn pri sm" href="#/review?scenic_id=${encodeURIComponent(x.id)}">去核对</a><a class="btn line sm" href="#/gallery?scenic_id=${encodeURIComponent(x.id)}">看图片（${fmt(x.images)}）</a></div>
        <h3 style="margin:18px 0 4px">保留的携程 POI（${x.pois.length}）</h3>
        ${x.pois.map((p) => `<div class="poi-item"><b>${esc(p.poiName)}</b> <span class="muted">poiId ${esc(p.poiId)} · 图片 ${fmt(p.images)}</span>
          <div class="muted" style="margin-top:4px">📍 ${esc(p.addr || '—')}${p.lat != null ? ` · ${p.lon}, ${p.lat}` : ''}</div>
          <div style="margin-top:6px;display:flex;gap:12px">${p.poiUri ? `<a class="muted" style="color:#6c4dff" target="_blank" rel="noopener" href="${esc(p.poiUri)}">携程页面 ↗</a>` : ''}<a class="muted" style="color:#6c4dff" href="#/gallery?scenic_id=${encodeURIComponent(x.id)}&poi_id=${encodeURIComponent(p.poiId)}">看这个 POI 的图片</a></div></div>`).join('') || '<div class="empty">还没有保留的 POI</div>'}`;
      $('#drawer').hidden = false;
    },
  };
  $('#drawer').addEventListener('click', (e) => { if (e.target.matches('.drawer-mask,[data-close]') || e.target.closest('a[href^="#/"]')) $('#drawer').hidden = true; });

  // ---------------------------------------------------------------- 图片预览
  V.gallery = {
    st: { offset: 0, limit: 60, items: [] },
    async enter() {
      await loadCities();
      const p = params();
      $('#v-gallery').innerHTML = `<div class="page-head"><h2>图片预览</h2><span class="muted" id="gal-info"></span></div>
        <div class="card"><form class="form" id="f-gal"><select name="city">${cityOptions(p.city)}</select>
          <input name="q" placeholder="景区名 / POI 名" style="width:180px" value="${esc(p.q || '')}"><input name="scenic_id" placeholder="景区ID" value="${esc(p.scenic_id || '')}" style="width:170px">
          <input name="poi_id" placeholder="poiId" value="${esc(p.poi_id || '')}" style="width:110px"><button class="btn pri sm" type="submit">查看</button></form></div>
        <div class="gallery" id="gal"></div><div style="text-align:center;margin:10px 0 20px"><button class="btn line" id="gal-more" hidden>加载更多</button></div>`;
      $('#f-gal').addEventListener('submit', (e) => { e.preventDefault(); this.load(true); });
      $('#gal-more').addEventListener('click', () => this.load(false));
      $('#gal').addEventListener('click', (e) => { const f = e.target.closest('[data-i]'); if (f) this.show(+f.dataset.i); });
      this.load(true);
    },
    async load(reset) {
      if (reset) this.st = { offset: 0, limit: 60, items: [] };
      const f = formData($('#f-gal'));
      const r = await api('/api/images?' + new URLSearchParams(Object.assign(f, { limit: this.st.limit, offset: this.st.offset })));
      const start = this.st.items.length;
      this.st.items.push(...r.items); this.st.offset += r.items.length; this.st.total = r.total;
      $('#gal-info').textContent = `共 ${fmt(r.total)} 张，已显示 ${fmt(this.st.items.length)} 张`;
      const html = r.items.map((x, k) => `<figure data-i="${start + k}"><img loading="lazy" referrerpolicy="no-referrer" src="${esc(x.image_thumb_url || x.image_url)}" alt="" style="aspect-ratio:${x.width && x.height ? x.width + '/' + x.height : 'auto'}">
        <figcaption><b>${esc(x.poi_name)}</b><span class="muted">${esc(x.scenic_name)} · ${x.width}×${x.height}</span></figcaption></figure>`).join('');
      if (reset) $('#gal').innerHTML = html || '<div class="empty" style="column-span:all">还没有图片</div>'; else $('#gal').insertAdjacentHTML('beforeend', html);
      $('#gal-more').hidden = this.st.items.length >= r.total;
    },
    show(i) {
      const items = this.st.items, x = items[i]; if (!x) return;
      this.cur = i;
      const lb = $('#lightbox');
      lb.innerHTML = `<div class="lb-img"><img referrerpolicy="no-referrer" src="${esc(x.image_url)}" alt="">
          <button class="lb-nav prev" data-nav="-1" ${i <= 0 ? 'hidden' : ''}><svg viewBox="0 0 24 24"><path d="m15 18-6-6 6-6"/></svg></button>
          <button class="lb-nav next" data-nav="1" ${i >= items.length - 1 ? 'hidden' : ''}><svg viewBox="0 0 24 24"><path d="m9 18 6-6-6-6"/></svg></button></div>
        <div class="lb-meta"><div style="display:flex;align-items:center"><h3 style="margin:0;flex:1">${esc(x.poi_name)}</h3><button class="btn line sm" data-lb-close>关闭</button></div>
          <div class="muted">${esc(x.scenic_name)} · ${i + 1} / ${fmt(this.st.total)}</div>
          <dl><dt>record_id</dt><dd>${esc(x.record_id)}</dd><dt>poi_id</dt><dd>${esc(x.poi_id)}</dd><dt>scenic_id</dt><dd>${esc(x.scenic_id)}</dd>
            <dt>省市区</dt><dd>${esc([x.province, x.city, x.district].filter(Boolean).join(' / '))}</dd><dt>坐标</dt><dd>${esc(x.lon)}, ${esc(x.lat)}</dd>
            <dt>review_id</dt><dd>${esc(x.review_id)}</dd><dt>image_id</dt><dd>${esc(x.image_id)}</dd><dt>尺寸</dt><dd>${x.width} × ${x.height}</dd>
            <dt>POI 图片数</dt><dd>${fmt(x.total_count)}</dd><dt>点评总数</dt><dd>${fmt(x.comment_total)}</dd><dt>点评评分</dt><dd>${esc(x.review_score ?? '—')}</dd>
            <dt>点评时间</dt><dd>${esc(x.review_publish_time || '—')}</dd><dt>采集时间</dt><dd>${esc(x.collect_time)}</dd><dt>来源</dt><dd>${esc(x.data_source)}</dd></dl>
          <a class="btn pri sm" target="_blank" rel="noopener" href="${esc(x.image_url)}">打开原图 ↗</a></div>`;
      lb.hidden = false;
    },
  };
  $('#lightbox').addEventListener('click', (e) => {
    const n = e.target.closest('[data-nav]');
    if (n) { V.gallery.show(V.gallery.cur + +n.dataset.nav); return; }
    if (e.target.closest('[data-lb-close]') || e.target.classList.contains('lb-img')) $('#lightbox').hidden = true;
  });
  document.addEventListener('keydown', (e) => {
    if ($('#lightbox').hidden) return;
    if (e.key === 'Escape') $('#lightbox').hidden = true;
    if (e.key === 'ArrowLeft' && V.gallery.cur > 0) V.gallery.show(V.gallery.cur - 1);
    if (e.key === 'ArrowRight') V.gallery.show(V.gallery.cur + 1);
  });

  // ---------------------------------------------------------------- 任务中心
  V.jobs = {
    sel: null,
    async enter() {
      await loadCities();
      this.sel = +params().id || this.sel;
      $('#v-jobs').innerHTML = `<div class="page-head"><h2>任务中心</h2><span class="muted">任务按提交顺序逐个执行；遇到登录 / 验证会停在「需要人工」，在服务打开的浏览器里处理后重新提交</span></div>
        <div class="grid" style="grid-template-columns:1fr 1fr">
          <div class="card"><h3>自动审核</h3><form class="form" id="f-auto"><select name="city">${cityOptions()}</select><input name="grade" placeholder="等级，如 5A,4A" style="width:130px">
            <input name="q" placeholder="景区名 / ID" style="width:140px"><label>最多 <input type="number" name="limit" value="0" min="0"> 个</label>
            <label><input type="checkbox" name="spots"> 再搜核心景点</label><label><input type="checkbox" name="cache_only"> 只用缓存</label><label><input type="checkbox" name="dry_run"> 试运行</label>
            <button class="btn pri" type="submit">开始</button></form><div class="muted" style="margin-top:10px">名称一致且（地址相近 / 门牌一致 / 同省市区）的直接通过，通过后自动排进图片采集。</div></div>
          <div class="card"><h3>采集点评图片</h3><form class="form" id="f-img2"><select name="city">${cityOptions()}</select><input name="grade" placeholder="等级" style="width:90px">
            <input name="q" placeholder="景区名 / ID" style="width:140px"><label>最多 <input type="number" name="max_pages" value="20" min="1"> 页</label><label><input type="number" name="max_images" value="300" min="0"> 张</label>
            <label><input type="checkbox" name="refresh"> 重采</label><button class="btn pri" type="submit">开始</button></form></div>
          <div class="card"><h3>任务</h3><div id="job-table"></div></div>
          <div class="card"><h3>日志 <span class="muted" id="log-title"></span></h3><pre class="log" id="job-log">点左边的任务查看日志</pre></div></div>`;
      $('#f-auto').addEventListener('submit', async (e) => { e.preventDefault(); this.sel = (await submitJob('auto_review', Object.assign(formData(e.target), { verbose: true }))).id; this.render(); });
      $('#f-img2').addEventListener('submit', async (e) => { e.preventDefault(); this.sel = (await submitJob('images', formData(e.target))).id; this.render(); });
      bindJobsTable($('#job-table'), (id) => { this.sel = id; this.render(); });
      every('jobs', 2000, () => this.render().catch(() => {}));
    },
    async render() {
      const js = await api('/api/jobs');
      $('#job-table').innerHTML = jobsTable(js, { sel: this.sel });
      if (!this.sel && js.length) this.sel = js[0].id;
      if (this.sel) {
        const j = await api(`/api/jobs/${this.sel}?tail=500`), pre = $('#job-log');
        const atBottom = pre.scrollTop + pre.clientHeight >= pre.scrollHeight - 20;
        pre.textContent = j.log.join('\n') + (j.error ? '\n\n' + j.error : '');
        $('#log-title').textContent = `#${j.id} ${j.type_name} · ${(STATUS[j.status] || [j.status])[0]}`;
        if (atBottom) pre.scrollTop = pre.scrollHeight;
      }
    },
  };

  // ---------------------------------------------------------------- 路由
  function route() {
    const name = (location.hash.replace(/^#\/?/, '').split('?')[0]) || 'overview';
    const view = V[name] ? name : 'overview';
    S.view = view;
    document.querySelectorAll('.view').forEach((el) => el.classList.toggle('on', el.id === 'v-' + view));
    document.querySelectorAll('.side a[data-view]').forEach((a) => a.classList.toggle('active', a.dataset.view === view));
    $('.side .logo').classList.toggle('active', view === 'overview');
    V[view].enter().catch((e) => toast(e.message, true));
  }
  window.addEventListener('hashchange', route);
  loadCities().then(() => {
    $('#avatars').innerHTML = S.cities.slice(0, 5).map((c, i) => `<span title="${esc(c.city)}" style="background:${COLORS[i % COLORS.length]}">${esc(shortCity(c.city).slice(0, 1))}</span>`).join('');
  }).catch(() => {});
  refreshTop(); setInterval(refreshTop, 5000);
  route();
})();
