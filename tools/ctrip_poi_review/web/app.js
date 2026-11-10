/* 景区 POI 数据工作台（React + Semi Design 本地副本 + htm，无需构建）。
 * 每个页面固定一屏：表格 / 图片在各自区域内滚动，滚到底自动加载下一页。 */
(() => {
  const { useState, useEffect, useRef, useCallback } = React;
  const html = htm.bind(React.createElement);
  const {
    Layout, Nav, Button, Table, Tag, Progress, Select, Input, InputNumber, Checkbox, Switch, SideSheet, ImagePreview,
    Toast, Modal, Dropdown, Avatar, Badge, Typography, Descriptions, Tooltip, Popover, Empty, Banner, Spin,
  } = SemiUI;
  const { Text } = Typography;
  const Ic = SemiIcons;

  // ------------------------------------------------------------ 工具
  const fmt = (n) => (n == null || n === '' ? '—' : Number(n).toLocaleString('zh-CN'));
  const pct = (a, b) => (b ? Math.round((a / b) * 1000) / 10 : 0);
  const shortCity = (c) => (c || '').replace(/市$/, '');
  const qs = (o) => Object.entries(o || {}).filter(([, v]) => v !== '' && v != null && v !== false)
    .map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&');
  async function errText(r) {
    try { const j = await r.json(); return typeof j.detail === 'string' ? j.detail : JSON.stringify(j.detail || j); } catch (e) { return `${r.status} ${r.statusText}`; }
  }
  async function api(path) { const r = await fetch(path); if (!r.ok) throw new Error(await errText(r)); return r.json(); }
  async function post(path, body) {
    const r = await fetch(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) });
    if (!r.ok) throw new Error(await errText(r));
    return r.json();
  }
  const go = (path, q) => { const s = qs(q); location.hash = `#/${path}${s ? '?' + s : ''}`; };

  function useHash() {
    const parse = () => {
      const h = location.hash.replace(/^#\/?/, '');
      const [p, q = ''] = h.split('?');
      return { path: p || 'overview', query: Object.fromEntries(new URLSearchParams(q)), raw: h };
    };
    const [st, set] = useState(parse);
    useEffect(() => { const f = () => set(parse()); window.addEventListener('hashchange', f); return () => window.removeEventListener('hashchange', f); }, []);
    return st;
  }

  /** 定时拉取（页面在后台时不拉）。deps 变化时立即重拉。 */
  function usePoll(fn, ms, deps = []) {
    const [data, setData] = useState(null);
    const ref = useRef(fn); ref.current = fn;
    const tick = useCallback(async () => { try { setData(await ref.current()); } catch (e) { /* 下次再试 */ } }, []);
    useEffect(() => {
      tick();
      if (!ms) return undefined;
      const t = setInterval(() => { if (!document.hidden) tick(); }, ms);
      return () => clearInterval(t);
    }, deps); // eslint-disable-line
    return [data, tick];
  }

  /** 分页自动加载：url 返回 {total, items}；params 变化时从头加载。 */
  function useInfinite(url, params, size = 50) {
    const [st, setSt] = useState({ items: [], total: null, loading: false, error: null });
    const cur = useRef(st); cur.current = st;
    const req = useRef(0); const busy = useRef(false);
    const key = `${url}?${qs(params)}`;
    const load = useCallback(async (reset) => {
      if (busy.current && !reset) return;
      const base = reset ? { items: [], total: null } : cur.current;
      if (!reset && base.total != null && base.items.length >= base.total) return;
      const id = ++req.current; busy.current = true;
      setSt((s) => ({ ...(reset ? { items: [], total: null } : s), loading: true, error: null }));
      try {
        const r = await api(`${url}?${qs({ ...params, offset: base.items.length, limit: size })}`);
        if (id !== req.current) return;
        setSt((s) => ({ items: (reset ? [] : s.items).concat(r.items || []), total: r.total, loading: false, error: null }));
      } catch (e) {
        if (id === req.current) setSt((s) => ({ ...s, loading: false, error: e.message }));
      } finally {
        if (id === req.current) busy.current = false;
      }
    }, [key]); // eslint-disable-line
    useEffect(() => { load(true); }, [key]); // eslint-disable-line
    const hasMore = st.total == null || st.items.length < st.total;
    return { ...st, hasMore, loadMore: () => load(false), reload: () => load(true) };
  }

  function useHeight(ref) {
    const [h, setH] = useState(0);
    useEffect(() => {
      if (!ref.current) return undefined;
      const ro = new ResizeObserver(([e]) => setH(Math.floor(e.contentRect.height)));
      ro.observe(ref.current);
      return () => ro.disconnect();
    }, []); // eslint-disable-line
    return h;
  }

  const listFoot = (l, unit = '条') => (l.error ? html`<${Text} type="danger">${l.error}<//>`
    : l.loading ? '加载中…'
      : l.total == null ? ''
        : l.items.length >= l.total ? `共 ${fmt(l.total)} ${unit}，已全部加载`
          : `已加载 ${fmt(l.items.length)} / ${fmt(l.total)} ${unit}，滚到底部自动加载`);

  /** 固定区域表格：表头固定，表体在区域内滚动，滚到底自动加载。 */
  function InfiniteTable({ list, columns, rowKey, onRowClick, emptyText = '暂无数据', unit }) {
    const box = useRef(null);
    const h = useHeight(box);
    useEffect(() => {
      const body = box.current && box.current.querySelector('.semi-table-body');
      if (!body) return undefined;
      const f = () => { if (body.scrollTop + body.clientHeight >= body.scrollHeight - 160) list.loadMore(); };
      body.addEventListener('scroll', f);
      if (list.hasMore && !list.loading && list.items.length && body.scrollHeight <= body.clientHeight + 8) list.loadMore();
      return () => body.removeEventListener('scroll', f);
    });
    return html`<div className=${'table-fill' + (onRowClick ? ' clickable' : '')}>
      <div className="fill" ref=${box}>
        ${h > 0 && html`<${Table} size="small" columns=${columns} dataSource=${list.items} rowKey=${rowKey} pagination=${false}
          scroll=${{ y: Math.max(80, h - 41) }} loading=${list.loading && !list.items.length}
          onRow=${onRowClick ? (r) => ({ onClick: () => onRowClick(r) }) : undefined}
          empty=${html`<${Empty} description=${list.error || emptyText} />`} />`}
      </div>
      <div className="table-foot">${listFoot(list, unit)}</div>
    </div>`;
  }

  function Help({ text }) {
    return html`<${Tooltip} content=${html`<div style=${{ maxWidth: 340, lineHeight: 1.7 }}>${text}</div>`}>
      <span className="help"><${Ic.IconInfoCircle} /></span><//>`;
  }
  function Field({ label, children }) {
    return html`<label className="f-l">${label}</label><div className="f-c">${children}</div>`;
  }
  function Card({ title, sub, help, extra, children, className = '', bodyClass = '', style }) {
    return html`<div className=${'card ' + className} style=${style}>
      ${(title || extra) && html`<div className="hd"><h3>${title}</h3>${help && html`<${Help} text=${help} />`}${sub && html`<span className="sub">${sub}</span>`}<span className="grow"></span>${extra}</div>`}
      <div className=${'bd ' + bodyClass}>${children}</div>
    </div>`;
  }

  function Stat({ icon, color, k, v, s }) {
    return html`<div className="stat"><div className=${'ic ' + color}>${icon}</div>
      <div style=${{ minWidth: 0 }}><div className="k">${k}</div><div className="v">${v}</div>${s && html`<div className="s">${s}</div>`}</div></div>`;
  }

  // ------------------------------------------------------------ 状态标签
  function scenicTag(x) {
    if (Number(x.approval) === 1) {
      if (/^AI审核/.test(x.note || '')) return html`<${Tooltip} content=${x.note}><${Tag} color="cyan" size="small">AI 通过<//><//>`;
      return /^自动审核/.test(x.note || '') ? html`<${Tag} color="green" size="small">自动通过<//>` : html`<${Tag} color="violet" size="small">人工通过<//>`;
    }
    if (x.status === 'skip') return html`<${Tag} color="orange" size="small">已跳过<//>`;
    return html`<${Tag} color="grey" size="small">待核对<//>`;
  }
  function collectTag(x) {
    if (!x.collect) return html`<${Text} type="quaternary">—<//>`;
    if (x.collect === 'done') return html`<${Tag} color="green" size="small">已采<//>`;
    if (x.collect === 'partial') return html`<${Tag} color="orange" size="small">部分 ${x.collect_n}/${x.pois.length}<//>`;
    return html`<${Tag} color="grey" size="small">未采<//>`;
  }
  const CRAWL_ST = { done: ['green', '完成'], empty: ['grey', '无图'], partial: ['orange', '部分'], failed: ['red', '失败'], running: ['blue', '采集中'] };
  const crawlTag = (s) => { const [c, t] = CRAWL_ST[s] || ['grey', s || '—']; return html`<${Tag} color=${c} size="small">${t}<//>`; };
  const JOB_ST = { queued: ['grey', '排队中'], running: ['blue', '运行中'], done: ['green', '完成'], failed: ['red', '失败'], cancelled: ['grey', '已取消'], need_human: ['orange', '需要人工'] };
  const jobTag = (s) => { const [c, t] = JOB_ST[s] || ['grey', s]; return html`<${Tag} color=${c} size="small">${t}<//>`; };
  const STATUS_OPTS = [{ value: 'all', label: '全部状态' }, { value: 'todo', label: '待核对' }, { value: 'done', label: '已审核' },
    { value: 'auto', label: '自动通过' }, { value: 'ai', label: 'AI 通过（待复核）' }, { value: 'skip', label: '已跳过' }];

  function CitySelect({ value, onChange, cities, style }) {
    const opts = [{ value: '', label: '全部城市' }].concat((cities || []).filter((c) => c.city).map((c) => ({ value: c.city, label: shortCity(c.city) })));
    return html`<${Select} value=${value} onChange=${onChange} optionList=${opts} style=${style || { width: 130 }} filter />`;
  }

  // ------------------------------------------------------------ 采集状态（边核对边采集 + 正在采集的 POI）
  /** 边核对边采集的状态：[颜色, 短状态, 说明] */
  function followState(f) {
    if (!f || !f.enabled) return ['grey', '已关闭', '审核通过后不会自动采图片'];
    if (f.paused) return ['orange', '已暂停', f.message ? `原因：${f.message}` : '队列保留着，点「继续采集」接着采'];
    if (f.current) return ['blue', '采集中', `正在采 ${f.current}`];
    if (f.pending) return ['blue', '排队中', `还有 ${f.pending} 个景区等着采`];
    return ['green', '空闲', '审核通过（含规则自动通过、AI 通过）的景区会自动开始采'];
  }
  async function skipPoi(source, refresh) {
    try {
      const r = await post('/api/crawl/skip', { source });
      if (r.skipped) Toast.success('已跳到下一个 POI'); else Toast.info('当前没有在采集的 POI');
    } catch (e) { Toast.error(e.message); }
    if (refresh) refresh();
  }
  async function setFollow(body, refresh) {
    try { await post('/api/follow', body); } catch (e) { Toast.error(e.message); }
    if (refresh) refresh();
  }

  function FollowControls({ follow, refresh }) {
    const f = follow || {};
    const [c, t, desc] = followState(f);
    return html`<span className="fc">
      <${Switch} size="small" checked=${!!f.enabled} onChange=${(v) => setFollow({ enabled: v }, refresh)} />
      <b className="fc-name">边核对边采集</b>
      <${Help} text="打开后，核对页里审核通过（含规则自动通过、AI 通过）的景区会自动排进队列，服务在后台另一个标签页里打开它保留的携程 POI，翻点评、把图片写进 MySQL。下面的数字是本次启动服务以来的累计，重启后从 0 开始。" />
      <${Tooltip} content=${desc}><span className=${'fc-state ' + c}><i></i>${t}</span><//>
      <span className="fc-sep"></span>
      <span className="fc-chip"><em>队列</em><b>${fmt(f.pending || 0)}</b> 个景区</span>
      <${Tooltip} content="本次启动服务以来的累计，重启后从 0 开始"><span className="fc-chip"><em>本次已采</em><b>${fmt(f.done || 0)}</b> 个景区 · 新增 <b>${fmt(f.images || 0)}</b> 张图</span><//>
      ${f.failed ? html`<span className="fc-chip bad"><em>失败</em><b>${fmt(f.failed)}</b> 个景区</span>` : null}
      ${f.enabled && (f.paused
        ? html`<${Button} size="small" theme="solid" icon=${html`<${Ic.IconPlay} />`} onClick=${() => setFollow({ resume: true }, refresh)}>继续采集<//>`
        : html`<${Button} size="small" type="tertiary" icon=${html`<${Ic.IconPause} />`} onClick=${() => setFollow({ pause: true }, refresh)}>暂停采集<//>`)}
    </span>`;
  }

  function CrawlNow({ active, refresh, empty = '当前没有在采集的 POI' }) {
    if (!active || !active.length) return html`<${Text} type="tertiary" size="small">${empty}<//>`;
    return active.map((a) => html`<div className="crawl-now" key=${a.source}>
      <div className="t">
        <${Tag} size="small" color=${a.source === 'follow' ? 'violet' : 'blue'}>${a.source === 'follow' ? '边核对边采集' : `任务 #${a.job_id}`}<//>
        <${Tooltip} content=${`${a.scenic_name} / ${a.poi_name}（poiId ${a.poi_id}）`}><b>${a.scenic_name} / ${a.poi_name}</b><//>
        ${a.poi_uri && html`<a href=${a.poi_uri} target="_blank" rel="noreferrer" title="打开携程页面"><${Ic.IconExternalOpen} size="small" /></a>`}
      </div>
      <${Progress} percent=${pct(a.pages, a.max_pages)} size="small" showInfo=${false} />
      <div className="m">
        <span>第 ${a.pages} / ${a.max_pages} 页</span><span>新增图片 ${fmt(a.images)}</span>
        <span>连续无新图 ${a.empty_run}${a.empty_limit ? ` / ${a.empty_limit} 页` : ''}</span><span className="grow"></span>
        <${Button} size="small" type="primary" theme="light" icon=${html`<${Ic.IconChevronRight} />`} iconPosition="right"
          onClick=${() => skipPoi(a.source, refresh)}>下一个 POI<//>
      </div>
    </div>`);
  }

  function LogBox({ lines, style }) {
    const ref = useRef(null);
    useEffect(() => { const el = ref.current; if (el && el.scrollHeight - el.scrollTop - el.clientHeight < 80) el.scrollTop = el.scrollHeight; });
    return html`<pre className="log" ref=${ref} style=${style}>${(lines || []).join('\n') || '暂无日志'}</pre>`;
  }

  // ------------------------------------------------------------ 总览
  const HERO_SVG = `<svg viewBox="0 0 420 300" xmlns="http://www.w3.org/2000/svg" width="100%" aria-hidden="true">
    <defs><linearGradient id="hq-hp" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#9c82ff"/><stop offset="1" stop-color="#6c4dff"/></linearGradient>
    <linearGradient id="hq-hc" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffa477"/><stop offset="1" stop-color="#e0703a"/></linearGradient></defs>
    <ellipse cx="220" cy="276" rx="160" ry="13" fill="rgba(60,40,120,.10)"/>
    <g transform="translate(176 34) rotate(11)"><rect width="172" height="132" rx="14" fill="#fff"/><rect x="10" y="10" width="152" height="92" rx="9" fill="#ffe3d2"/>
      <path d="M22 94 l40-46 l28 31 l18-19 l44 34z" fill="#f2a27a"/><circle cx="128" cy="34" r="10" fill="#fff5d6"/><rect x="12" y="112" width="70" height="7" rx="3.5" fill="#f1eef0"/></g>
    <g transform="translate(66 72) rotate(-8)"><rect width="196" height="154" rx="16" fill="#fff"/><rect x="12" y="12" width="172" height="108" rx="10" fill="#e8e2ff"/>
      <path d="M26 112 l48-54 l33 37 l22-23 l51 40z" fill="#8b6cff"/><circle cx="148" cy="40" r="12" fill="#ffd36b"/><rect x="14" y="130" width="96" height="8" rx="4" fill="#efedf5"/></g>
    <g transform="translate(296 118)"><path d="M36 0a36 36 0 0 1 36 36c0 27-36 66-36 66S0 63 0 36A36 36 0 0 1 36 0z" fill="url(#hq-hc)"/><circle cx="36" cy="36" r="14" fill="#fff"/></g>
    <g transform="translate(36 196)"><rect x="18" y="-10" width="30" height="16" rx="5" fill="#17171c"/><rect width="100" height="66" rx="15" fill="#17171c"/>
      <circle cx="50" cy="33" r="21" fill="#34343c"/><circle cx="50" cy="33" r="13" fill="url(#hq-hp)"/><circle cx="83" cy="16" r="5" fill="#ffd36b"/></g>
    <circle cx="56" cy="44" r="6" fill="#fff" opacity=".85"/><circle cx="388" cy="70" r="4" fill="#fff" opacity=".9"/><circle cx="372" cy="246" r="5" fill="#8b6cff" opacity=".45"/>
  </svg>`;

  /** 审核完成度：已审核 / 已跳过 / 待核对，段与段之间留 2px 空隙 */
  function Donut({ parts, size = 128, stroke = 16 }) {
    const r = (size - stroke) / 2, C = 2 * Math.PI * r, total = parts.reduce((a, p) => a + p.v, 0) || 1;
    let start = 0;
    const segs = parts.filter((p) => p.v > 0).map((p) => {
      const len = (C * p.v) / total, gap = parts.filter((q) => q.v > 0).length > 1 ? 2 : 0;
      const seg = html`<circle key=${p.k} cx=${size / 2} cy=${size / 2} r=${r} fill="none" stroke=${p.c} strokeWidth=${stroke}
        strokeDasharray=${`${Math.max(len - gap, 0.5)} ${C}`} strokeDashoffset=${-start}><title>${p.k}：${fmt(p.v)}（${pct(p.v, total)}%）</title></circle>`;
      start += len;
      return seg;
    });
    return html`<svg className="donut" viewBox=${`0 0 ${size} ${size}`} style=${{ transform: 'rotate(-90deg)' }}>
      <circle cx=${size / 2} cy=${size / 2} r=${r} fill="none" stroke="#f4f4f6" strokeWidth=${stroke} />${segs}</svg>`;
  }

  function Overview({ follow, refreshFollow }) {
    const [ov] = usePoll(() => api('/api/overview'), 15000);
    const [jobs] = usePoll(() => api('/api/jobs'), 5000);
    const o = ov || {};
    const crawl = o.crawl || {};
    const cities = (o.cities || []).filter((c) => c.city)
      .sort((a, b) => (a.province || '').localeCompare(b.province || '', 'zh') || (+b.n || 0) - (+a.n || 0));
    const rate = (c) => pct(+c.reviewed || 0, +c.n || 0);
    // 柱状图只放景区最多的 12 个城市（全国 300 多个城市放不下），完整的在下面的表里
    const big = [...cities].sort((a, b) => (+b.n || 0) - (+a.n || 0)).slice(0, 12);
    const top = Math.max(5, ...big.map(rate));
    const T = +o.total || 0, A = +o.approved || 0, S = +o.skipped || 0, R = Math.max(0, T - A - S);
    const cityCols = [
      { title: '省份', dataIndex: 'province', width: 96, render: (v) => html`<div className="ell muted" title=${v || ''}>${(v || '').replace(/(省|市|自治区|壮族|回族|维吾尔)+$/, '')}</div>` },
      { title: '城市', dataIndex: 'city', width: 130, render: (v) => html`<div className="ell" title=${v}>${shortCity(v)}</div>` },
      { title: '景区', dataIndex: 'n', width: 64, align: 'right', render: fmt },
      { title: '审核进度', dataIndex: 'reviewed', render: (v, r) => html`<div style=${{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div className="bar-track" style=${{ flex: 1 }}><i style=${{ width: `${Math.min(100, rate(r))}%` }}></i></div>
          <span className="nw" style=${{ width: 92, textAlign: 'right' }}><b>${fmt(v || 0)}</b><span className="muted">/${fmt(r.n)}</span></span></div>` },
      { title: '跳过', dataIndex: 'skipped', width: 56, align: 'right', render: (v) => fmt(v || 0) },
      { title: '已采 POI', dataIndex: 'pois', width: 76, align: 'right', render: fmt },
      { title: '图片', dataIndex: 'images', width: 80, align: 'right', render: fmt },
    ];
    const box = useRef(null); const h = useHeight(box);
    const recent = (jobs || []).slice(0, 6);
    return html`<div className="ov">
      <div className="hero">
        <h2>景区 POI<br />数据工作台</h2>
        <div className="acts">
          <${Button} className="btn-dark" icon=${html`<${Ic.IconChevronRight} />`} iconPosition="right" onClick=${() => go('review')}>开始核对<//>
          <${Button} theme="borderless" style=${{ height: 40, borderRadius: 12, background: 'rgba(255,255,255,.6)' }} onClick=${() => go('gallery')}>看图片<//>
        </div>
        <div className="art" dangerouslySetInnerHTML=${{ __html: HERO_SVG }}></div>
        <div className="glass">
          <div className="kpi"><div className="k">已审核景区</div><div className="v">${fmt(A)}</div>
            <div className="s">规则 ${fmt(o.auto_approved)} · AI ${fmt(o.ai_approved)} · 人工 ${fmt(o.manual_approved)} · 共 ${fmt(T)}</div></div>
          <div className="kpi"><div className="k">已采景区</div><div className="v">${fmt(o.scenics_collected)}</div>
            <div className="s">可采 ${fmt(o.scenics_with_pois)} · POI ${fmt((crawl.done || 0) + (crawl.empty || 0))}/${fmt(o.crawlable_pois)}</div></div>
          <div className="kpi"><div className="k">点评图片</div><div className="v">${fmt(o.images)}</div>
            <div className="s">${o.ods_table || '交付表'} ${fmt(o.ods_rows)} 行</div></div>
        </div>
      </div>
      <div className="ov-right">
        <${Card} title="各城市审核完成率" sub=${cities.length > 12 ? '景区最多的 12 个城市' : '已审核 / 景区数'} className="chart-card">
          <div style=${{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
            <div className="cols">${big.map((c) => html`<${Tooltip} key=${c.city} content=${`${shortCity(c.city)}：已审核 ${fmt(c.reviewed || 0)} / ${fmt(c.n)}（${rate(c)}%）`}>
              <div className="c"><span className="val">${rate(c)}%</span><div className="col" style=${{ height: `${(rate(c) / top) * 82}%` }}></div></div><//>`)}</div>
            <div className="cols-x">${big.map((c) => html`<span key=${c.city}>${shortCity(c.city)}</span>`)}</div>
          </div>
        <//>
        <${Card} title="审核完成度" sub=${`共 ${fmt(T)} 个景区`} className="chart-card">
          <div className="donut-wrap">
            <${Donut} parts=${[{ k: '已审核', v: A, c: '#6c4dff' }, { k: '已跳过', v: S, c: '#e0703a' }, { k: '待核对', v: R, c: '#e7e5e4' }]} />
            <div>
              <div className="big">${pct(A, T)}%</div>
              <div className="legend">
                <span><i style=${{ background: '#6c4dff' }}></i>已审核 ${fmt(A)}</span>
                <span><i style=${{ background: '#e0703a' }}></i>已跳过 ${fmt(S)}<a style=${{ marginLeft: 6, fontSize: 12 }} onClick=${() => go('review')}>去处理</a></span>
                <span><i style=${{ background: '#e7e5e4' }}></i>待核对 ${fmt(R)}</span>
              </div>
            </div>
          </div>
        <//>
      </div>
      <${Card} title="各城市进度" sub=${`${fmt(cities.length)} 个城市 · 点一行看该城市的景区`} bodyClass="flush">
        <div className="fill" ref=${box}>${h > 0 && html`<${Table} size="small" columns=${cityCols} dataSource=${cities} rowKey="city"
          pagination=${false} scroll=${{ y: h - 41 }} loading=${!ov} onRow=${(r) => ({ onClick: () => go('data', { city: r.city }), style: { cursor: 'pointer' } })} />`}</div>
      <//>
      <div className="ov-bottom-right">
        <${Card} title="正在采集" bodyClass="scroll" style=${{ maxHeight: 260 }}>
          <div style=${{ marginBottom: 10 }}><${FollowControls} follow=${follow} refresh=${refreshFollow} /></div>
          ${follow && follow.paused && follow.message && html`<${Banner} type="warning" description=${follow.message} closeIcon=${null} style=${{ marginBottom: 8 }} />`}
          <${CrawlNow} active=${follow && follow.active} refresh=${refreshFollow} />
        <//>
        <${Card} title="最近任务" extra=${html`<a onClick=${() => go('jobs')}>任务中心</a>`} bodyClass="scroll">
          ${recent.length ? recent.map((j) => html`<div className="job-item" key=${j.id} onClick=${() => go('jobs', { id: j.id })}>
            <div style=${{ display: 'flex', gap: 8, alignItems: 'center' }}><b>#${j.id} ${j.type_name}</b>${jobTag(j.status)}<span style=${{ flex: 1 }}></span>
              <${Text} type="tertiary" size="small">${(j.started || j.created || '').slice(5, 16)}<//></div>
            <${Text} type="tertiary" size="small" ellipsis=${{ showTooltip: true }} style=${{ width: '100%' }}>${(j.last || '').slice(9)}<//>
          </div>`) : html`<${Empty} description="还没有任务" />`}
        <//>
      </div>
    </div>`;
  }

  // ------------------------------------------------------------ 核对（嵌入 panel.js，常驻不卸载）
  let panelLoaded = false;
  function ReviewPage({ visible, query, follow, refreshFollow }) {
    const host = useRef(null);
    useEffect(() => {
      if (!visible || panelLoaded) return;
      panelLoaded = true;
      window.hqCall = (m, p) => post('/api/rpc/' + m, p).catch((e) => ({ error: e.message }));
      window.HQ_EMBED = host.current;
      const sc = document.createElement('script'); sc.src = '/panel.js?v=' + Date.now(); document.body.appendChild(sc);
    }, [visible]);
    useEffect(() => {
      if (visible && query.scenic_id) {
        const t = setTimeout(() => window.dispatchEvent(new CustomEvent('hq:open', { detail: { scenic_id: query.scenic_id } })), panelLoaded ? 600 : 1500);
        return () => clearTimeout(t);
      }
      return undefined;
    }, [visible, query.scenic_id]);
    const a = ((follow && follow.active) || []).find((x) => x.source === 'follow');
    return html`<div className="page" style=${{ display: visible ? 'flex' : 'none' }}>
      <div className="follow-strip">
        <${FollowControls} follow=${follow} refresh=${refreshFollow} />
        <div className="now">${a ? html`
          <${Spin} size="small" />
          <span className="txt">正在采：<b>${a.scenic_name} / ${a.poi_name}</b> · 第 ${a.pages}/${a.max_pages} 页 · 新增 ${a.images} 张</span>
          <${Button} size="small" type="primary" theme="light" icon=${html`<${Ic.IconChevronRight} />`} iconPosition="right" onClick=${() => skipPoi('follow', refreshFollow)}>下一个 POI<//>`
          : html`<${Text} type="tertiary" size="small">${followState(follow)[2]}<//>`}</div>
      </div>
      <div className="card review-card"><div id="review-host" ref=${host}></div></div>
    </div>`;
  }

  // ------------------------------------------------------------ 图片采集
  function ImagesPage({ follow, refreshFollow, cities }) {
    const [p, setP] = useState({ city: '', grade: '', q: '', max_pages: 20, max_images: 300, empty_pages: 10, limit: 0, refresh: false });
    const [flt, setFlt] = useState({ status: '', q: '' });
    const [kw, setKw] = useState('');
    const list = useInfinite('/api/crawl_records', flt, 50);
    const set = (k) => (v) => setP((o) => ({ ...o, [k]: v }));
    const submit = async () => {
      try {
        const j = await post('/api/jobs', { type: 'images', params: p });
        Toast.success(`已提交采集任务 #${j.id}`);
        refreshFollow();
      } catch (e) { Toast.error(e.message); }
    };
    // 正在采集时，每 5 秒刷新一次记录表的第一屏
    useEffect(() => {
      const t = setInterval(() => { if (!document.hidden && (follow && follow.active && follow.active.length)) list.reload(); }, 8000);
      return () => clearInterval(t);
    });
    const cols = [
      { title: 'POI', dataIndex: 'poi_name', width: 340, render: (v, r) => html`<div className="cell-2">
          <div className="t ell" title=${v}>${v || '—'}</div>
          <div className="d ell">${r.scenic_name || r.scenic_id}${r.city ? ' · ' + shortCity(r.city) : ''} · poiId ${r.poi_id}</div></div>` },
      { title: '状态', dataIndex: 'status', width: 84, render: crawlTag },
      { title: '页数', dataIndex: 'pages_done', width: 64, align: 'right', render: (v) => html`<span className="num">${fmt(v)}</span>` },
      { title: '点评', dataIndex: 'review_qty', width: 110, align: 'right', render: (v, r) => html`<span className="num nw">${fmt(v)}<span className="muted"> / ${fmt(r.total_count)}</span></span>` },
      { title: '新增图片', dataIndex: 'image_qty', width: 96, align: 'right', render: (v) => html`<span className="num">${fmt(v)}</span>` },
      { title: '说明', dataIndex: 'message', render: (v) => html`<div className="ell muted sm" title=${v || ''}>${v || '—'}</div>` },
      { title: '更新', dataIndex: 'updated_at', width: 112, render: (v) => html`<span className="num muted sm nw" title=${v || ''}>${(v || '').slice(5, 16)}</span>` },
      { title: '', dataIndex: 'op', width: 150, render: (v, r) => html`<span className="links nw">
          <a onClick=${() => go('gallery', { scenic_id: r.scenic_id, poi_id: r.poi_id })}>看图片</a>
          ${r.poi_uri && html`<a className="sec" href=${r.poi_uri} target="_blank" rel="noreferrer">携程页面</a>`}</span>` },
    ];
    const statusOpts = [{ value: '', label: '全部' }, { value: 'done', label: '完成' }, { value: 'empty', label: '无图' }, { value: 'partial', label: '部分' }, { value: 'failed', label: '失败' }, { value: 'running', label: '采集中' }];
    return html`<div className="page">
      <div className="row2 even" style=${{ flex: 'none' }}>
        <${Card} title="批量采集" sub="已审核景区保留的 POI"
          help="对已审核（approval=1）景区保留的每个 POI：打开携程主页，第一页读页面里的 __NEXT_DATA__，之后点「下一页」读 getCommentCollapseList，把点评图片写进 MySQL。采过的 POI 自动跳过；没有图片的 POI 记为「无图」并立即换下一个。数字填 0 表示不限。">
          <div className="form">
            <${Field} label="采集范围">
              <${CitySelect} value=${p.city} onChange=${set('city')} cities=${cities} style=${{ width: 130 }} />
              <${Input} value=${p.grade} onChange=${set('grade')} placeholder="等级，如 5A,4A" style=${{ width: 140 }} showClear />
              <${Input} value=${p.q} onChange=${set('q')} placeholder="景区名 / 景区ID" style=${{ width: 180 }} showClear />
            <//>
            <${Field} label="每个 POI">
              <span className="lbl">最多</span><${InputNumber} hideButtons value=${p.max_pages} onChange=${set('max_pages')} min=${1} style=${{ width: 96 }} suffix="页" />
              <${InputNumber} hideButtons value=${p.max_images} onChange=${set('max_images')} min=${0} style=${{ width: 106 }} suffix="张" />
            <//>
            <${Field} label="换下一个">
              <span className="lbl">连续</span><${InputNumber} hideButtons value=${p.empty_pages} onChange=${set('empty_pages')} min=${0} style=${{ width: 96 }} suffix="页" />
              <span className="lbl">没有新图片</span>
            <//>
            <${Field} label="本次">
              <span className="lbl">最多</span><${InputNumber} hideButtons value=${p.limit} onChange=${set('limit')} min=${0} style=${{ width: 116 }} suffix="个 POI" />
              <${Checkbox} checked=${p.refresh} onChange=${(e) => set('refresh')(e.target.checked)}>已采过的也重采<//>
              <span style=${{ flex: 1 }}></span>
              <${Button} theme="solid" icon=${html`<${Ic.IconPlay} />`} onClick=${submit}>开始采集<//>
            <//>
          </div>
        <//>
        <${Card} title="正在采集" extra=${html`<${FollowControls} follow=${follow} refresh=${refreshFollow} />`} bodyClass="flush">
          <div style=${{ padding: '4px 18px 10px', flex: 'none' }}>
            ${follow && follow.paused && follow.message && html`<${Banner} type="warning" description=${follow.message} closeIcon=${null} style=${{ marginBottom: 8 }} />`}
            <${CrawlNow} active=${follow && follow.active} refresh=${refreshFollow} />
          </div>
          <div style=${{ flex: 1, minHeight: 90, padding: '0 18px 16px', display: 'flex' }}><${LogBox} lines=${follow && follow.log} style=${{ flex: 1 }} /></div>
        <//>
      </div>
      <${Card} title="POI 采集记录" sub=${list.total != null ? `${fmt(list.total)} 个` : ''} className="fill" bodyClass="flush"
        extra=${html`<span className="toolbar">
          <${Select} value=${flt.status} onChange=${(v) => setFlt((o) => ({ ...o, status: v }))} optionList=${statusOpts} style=${{ width: 110 }} />
          <${Input} value=${kw} onChange=${setKw} onEnterPress=${() => setFlt((o) => ({ ...o, q: kw.trim() }))} placeholder="POI 名 / poiId / 景区ID，回车"
            prefix=${html`<${Ic.IconSearch} />`} style=${{ width: 260 }} showClear onClear=${() => setFlt((o) => ({ ...o, q: '' }))} />
          <${Button} icon=${html`<${Ic.IconRefresh} />`} onClick=${list.reload} />
        </span>`}>
        <${InfiniteTable} list=${list} columns=${cols} rowKey=${(r) => `${r.scenic_id}_${r.poi_id}`} emptyText="还没有采集记录" unit="个 POI" />
      <//>
    </div>`;
  }

  // ------------------------------------------------------------ 数据预览
  function DataPage({ query, cities }) {
    const init = () => ({ city: query.city || '', status: query.status || 'all', grade: query.grade || '', q: query.q || '' });
    const [f, setF] = useState(init);
    const [kw, setKw] = useState(query.q || '');
    useEffect(() => { setF(init()); setKw(query.q || ''); }, [query.city, query.status, query.grade, query.q]); // eslint-disable-line
    const list = useInfinite('/api/scenic_table', f, 50);
    const [cur, setCur] = useState(null);
    const cols = [
      { title: '景区', dataIndex: 'name', render: (v, r) => html`<div className="cell-2"><div className="t">${v}</div><div className="d">${r.id}</div></div>` },
      { title: '城市 / 区县', dataIndex: 'city', width: 140, render: (v, r) => html`<span className="nw">${shortCity(v)} / ${r.district || '—'}</span>` },
      { title: '等级', dataIndex: 'grade', width: 64 },
      { title: '状态', dataIndex: 'status', width: 92, render: (v, r) => scenicTag(r) },
      { title: '保留的携程 POI', dataIndex: 'pois', render: (v) => html`<div className="tags">${(v || []).slice(0, 4).map((p) => html`<${Tag} key=${p.poiId} size="small" color="violet" type="light">${p.poiName}${p.images ? ` · ${p.images}` : ''}<//>`)}
          ${(v || []).length > 4 && html`<${Tag} size="small" color="grey">+${v.length - 4}<//>`}${!(v || []).length && html`<${Text} type="quaternary">—<//>`}</div>` },
      { title: '图片采集', dataIndex: 'collect', width: 96, render: (v, r) => collectTag(r) },
      { title: '图片', dataIndex: 'images', width: 70, align: 'right', render: fmt },
      { title: '核对', dataIndex: 'updated_at', width: 120, render: (v, r) => html`<div className="cell-2"><div className="d">${r.reviewer || (/^自动审核/.test(r.note || '') ? 'auto' : '')}</div>
          <div className="d num nw" title=${v || ''}>${(v || '').slice(5, 16)}</div></div>` },

    ];
    const setK = (k) => (v) => setF((o) => ({ ...o, [k]: v }));
    return html`<div className="page">
      <${Card} title="景区数据" sub=${list.total != null ? `共 ${fmt(list.total)} 个景区` : ''} className="fill" bodyClass="flush"
        extra=${html`<span className="toolbar">
          <${CitySelect} value=${f.city} onChange=${setK('city')} cities=${cities} />
          <${Select} value=${f.status} onChange=${setK('status')} optionList=${STATUS_OPTS} style=${{ width: 120 }} />
          <${Select} value=${f.grade} onChange=${setK('grade')} style=${{ width: 110 }}
            optionList=${[{ value: '', label: '全部等级' }].concat(['5A', '4A', '3A', '2A', '1A'].map((g) => ({ value: g, label: g })))} />
          <${Input} value=${kw} onChange=${setKw} onEnterPress=${() => setK('q')(kw.trim())} placeholder="景区名 / 别名 / 景区ID，回车" prefix=${html`<${Ic.IconSearch} />`}
            style=${{ width: 240 }} showClear onClear=${() => setK('q')('')} />
          <${Button} icon=${html`<${Ic.IconDownload} />`} onClick=${() => window.open('/api/export.csv')}>导出 CSV<//>
        </span>`}>
        <${InfiniteTable} list=${list} columns=${cols} rowKey="id" onRowClick=${setCur} emptyText="没有符合条件的景区" unit="个景区" />
      <//>
      <${ScenicSheet} x=${cur} onClose=${() => setCur(null)} />
    </div>`;
  }

  function ScenicSheet({ x, onClose }) {
    if (!x) return html`<${SideSheet} visible=${false} onCancel=${onClose} />`;
    const data = [
      { key: '景区ID', value: x.id }, { key: '省市区', value: [x.province, x.city, x.district].filter(Boolean).join(' / ') },
      { key: '地址', value: x.address || '—' }, { key: '坐标', value: x.lng ? `${x.lng}, ${x.lat}` : '—' },
      { key: '别名', value: x.alias || '—' }, { key: '核心景点', value: x.core_spots || '—' },
      { key: '审核', value: html`<span>${scenicTag(x)} ${x.reviewer ? ' ' + x.reviewer : ''} ${x.updated_at || ''}</span>` },
      { key: '备注', value: x.note || '—' },
    ];
    return html`<${SideSheet} visible=${true} onCancel=${onClose} width=${560}
      title=${html`<span>${x.name} ${x.grade && html`<${Tag} color="violet" size="small" style=${{ marginLeft: 6 }}>${x.grade}<//>`}</span>`}>
      <${Descriptions} data=${data} align="left" size="small" />
      <div className="toolbar" style=${{ margin: '16px 0' }}>
        <${Button} theme="solid" icon=${html`<${Ic.IconCheckboxTick} />`} onClick=${() => { onClose(); go('review', { scenic_id: x.id }); }}>去核对<//>
        <${Button} icon=${html`<${Ic.IconGallery} />`} onClick=${() => { onClose(); go('gallery', { scenic_id: x.id }); }}>看图片（${fmt(x.images)}）<//>
      </div>
      <h4 style=${{ margin: '8px 0' }}>保留的携程 POI（${(x.pois || []).length}）</h4>
      ${(x.pois || []).length ? x.pois.map((p) => html`<div className="poi-item" key=${p.poiId}>
        <div className="t"><b>${p.poiName}</b><${Text} type="tertiary" size="small">poiId ${p.poiId}<//><span style=${{ flex: 1 }}></span>
          ${p.crawl ? crawlTag(p.crawl) : html`<${Tag} size="small" color="grey">未采<//>`}<${Tag} size="small" color=${p.images ? 'green' : 'grey'}>图片 ${p.images || 0}<//></div>
        ${p.crawl_msg && html`<div className="d">采集：${p.crawl_msg}</div>`}
        <div className="d"><${Ic.IconMapPin} size="small" /> ${p.addr || '—'}${p.lat ? ` · ${p.lon}, ${p.lat}` : ''}</div>
        <div className="a">${p.poiUri && html`<a href=${p.poiUri} target="_blank" rel="noreferrer">携程页面 <${Ic.IconExternalOpen} size="small" /></a>`}
          <a onClick=${() => { onClose(); go('gallery', { poi_id: p.poiId }); }}>看这个 POI 的图片</a></div>
      </div>`) : html`<${Empty} description="还没有保留的 POI" />`}
    <//>`;
  }

  // ------------------------------------------------------------ 图片预览
  function Thumb({ x, onOpen }) {
    const [bad, setBad] = useState(false);
    return html`<div className="ph" onClick=${onOpen} title=${`${x.scenic_name} / ${x.poi_name}`}>
      ${bad ? html`<div className="broken"><div><${Ic.IconImage} size="extra-large" /><div>图片加载失败</div></div></div>`
        : html`<img loading="lazy" referrerPolicy="no-referrer" src=${x.image_thumb_url || x.image_url} onError=${() => setBad(true)} alt="" />`}
      ${x.review_score != null && html`<span className="score">★ ${x.review_score}</span>`}
      <div className="cap"><b>${x.poi_name}</b><span>${x.scenic_name} · ${(x.review_publish_time || '').slice(0, 10)}</span></div>
    </div>`;
  }

  /** 大图 + 右侧图片信息；← → 翻页，Esc 关闭，翻到已加载的末尾会自动加载下一页 */
  function Viewer({ list, index, setIndex, onClose }) {
    const x = list.items[index];
    const [bad, setBad] = useState(false);
    useEffect(() => setBad(false), [index]);
    const prev = () => { if (index > 0) setIndex(index - 1); };
    const next = () => { if (index < list.items.length - 1) setIndex(index + 1); };
    useEffect(() => {
      const f = (e) => {
        if (e.key === 'Escape') onClose();
        else if (e.key === 'ArrowLeft') prev();
        else if (e.key === 'ArrowRight') next();
      };
      window.addEventListener('keydown', f);
      return () => window.removeEventListener('keydown', f);
    });
    useEffect(() => { if (index >= list.items.length - 6 && list.hasMore && !list.loading) list.loadMore(); }, [index, list.items.length]); // eslint-disable-line
    if (!x) return null;
    const close = (e) => { if (e.target === e.currentTarget) onClose(); };
    const row = (k, v) => html`<span>${k}</span><div>${v == null || v === '' ? '—' : v}</div>`;
    return html`<div className="viewer">
      <div className="stage" onClick=${close}>
        <div className="top">
          <span>${fmt(index + 1)} / ${fmt(list.total)}</span><span style=${{ flex: 1 }}></span>
          <span className="muted">← → 翻页 · Esc 关闭</span>
          <button className="close" title="关闭 (Esc)" onClick=${onClose}><${Ic.IconClose} /></button>
        </div>
        ${bad ? html`<div className="broken"><${Ic.IconImage} size="extra-large" /><div>图片加载失败</div><a href=${x.image_url} target="_blank" rel="noreferrer">打开原链接</a></div>`
          : html`<img key=${x.record_id} src=${x.image_url} referrerPolicy="no-referrer" onError=${() => setBad(true)} alt="" />`}
        <button className="nav l" disabled=${index === 0} onClick=${prev} title="上一张 (←)"><${Ic.IconChevronLeft} /></button>
        <button className="nav r" disabled=${index >= list.items.length - 1} onClick=${next} title="下一张 (→)"><${Ic.IconChevronRight} /></button>
      </div>
      <aside className="info">
        <h2>${x.poi_name}</h2>
        <div className="scn">${x.scenic_name} · ${x.scenic_id}</div>
        <div className="tags">
          ${x.review_score != null && html`<${Tag} color="amber">★ ${x.review_score} 分<//>`}
          <${Tag} color="grey">${shortCity(x.city)}${x.district ? ' · ' + x.district : ''}<//>
          ${x.tourist_type && html`<${Tag} color="violet">${x.tourist_type}<//>`}
          ${x.width && html`<${Tag} color="grey">${x.width} × ${x.height}<//>`}
        </div>
        <div className="quote">${x.review_content || html`<span className="muted">没有存点评内容（之前采的图片没存，重采后会有）</span>`}</div>
        <div className="sec">图片</div>
        <div className="kv">
          <span>record_id</span><div><${Text} copyable size="small">${x.record_id}<//></div>
          <span>image_id</span><div><${Text} copyable size="small">${String(x.image_id)}<//></div>
          ${row('携程 imageId', x.ctrip_image_id)}${row('采集时间', x.collect_time)}${row('数据来源', x.data_source)}
        </div>
        <div className="sec">点评</div>
        <div className="kv">${row('点评 ID', x.review_id)}${row('发布时间', x.review_publish_time)}${row('出游类型', x.tourist_type)}</div>
        <div className="sec">POI / 景区</div>
        <div className="kv">${row('poiId', x.poi_id)}${row('POI 图片总数', fmt(x.total_count))}${row('POI 点评总数', fmt(x.comment_total))}
          ${row('省市区', [x.province, x.city, x.district].filter(Boolean).join(' / '))}${row('景区坐标', x.lon != null ? `${x.lon}, ${x.lat}` : null)}</div>
        <div className="links">
          <${Button} size="small" theme="solid" icon=${html`<${Ic.IconExternalOpen} />`} onClick=${() => window.open(x.image_url, '_blank', 'noreferrer')}>打开原图<//>
          ${x.review_url && html`<${Button} size="small" onClick=${() => window.open(x.review_url, '_blank', 'noreferrer')}>点评详情<//>`}
          ${x.poi_uri && html`<${Button} size="small" onClick=${() => window.open(x.poi_uri, '_blank', 'noreferrer')}>携程 POI 页面<//>`}
          <${Button} size="small" theme="borderless" onClick=${() => { onClose(); go('gallery', { scenic_id: x.scenic_id, poi_id: x.poi_id }); }}>只看这个 POI<//>
          <${Button} size="small" theme="borderless" onClick=${() => { onClose(); go('data', { q: x.scenic_id }); }}>景区数据<//>
        </div>
      </aside>
    </div>`;
  }

  const SCORE_OPTS = [{ value: '', label: '全部评分' }, { value: '5', label: '5 分' }, { value: '4', label: '4 分及以上' }, { value: '3', label: '3 分及以上' }];
  const SORT_OPTS = [{ value: 'collect', label: '最新采集' }, { value: 'publish', label: '最新点评' }, { value: 'score', label: '评分最高' }, { value: 'size', label: '尺寸最大' }];

  function GalleryPage({ query }) {
    const init = () => ({ city: query.city || '', scenic_id: query.scenic_id || '', poi_id: query.poi_id || '', score_min: query.score_min || '',
      sort: query.sort || 'collect', q: query.q || '' });
    const [f, setF] = useState(init);
    useEffect(() => { setF(init()); }, [query.city, query.scenic_id, query.poi_id, query.q]); // eslint-disable-line
    const [scq, setScq] = useState('');
    const deb = useRef(null);
    const onScenicSearch = (v) => { clearTimeout(deb.current); deb.current = setTimeout(() => setScq(v || ''), 250); };
    const [fac] = usePoll(() => api(`/api/image_facets?${qs({ city: f.city, scenic_id: f.scenic_id, q: scq })}`), 0, [f.city, f.scenic_id, scq]);
    const facets = fac || { scenics: [], pois: [], cities: [] };
    const list = useInfinite('/api/images', f, 60);
    const box = useRef(null); const sentinel = useRef(null);
    const [vi, setVi] = useState(-1);
    useEffect(() => {
      if (!sentinel.current) return undefined;
      const io = new IntersectionObserver(([e]) => { if (e.isIntersecting) list.loadMore(); }, { root: box.current, rootMargin: '400px' });
      io.observe(sentinel.current);
      return () => io.disconnect();
    });
    useEffect(() => { if (box.current) box.current.scrollTop = 0; setVi(-1); }, [JSON.stringify(f)]); // eslint-disable-line
    const set = (patch) => setF((o) => ({ ...o, ...patch }));
    const cityOpts = [{ value: '', label: '全部城市' }].concat((facets.cities || []).filter((c) => c.city).map((c) => ({ value: c.city, label: `${shortCity(c.city)} · ${fmt(c.n)}` })));
    let scenicOpts = (facets.scenics || []).map((x) => ({ value: x.id, label: `${x.name} · ${fmt(x.n)}` }));
    if (f.scenic_id && !scenicOpts.some((o) => o.value === f.scenic_id)) scenicOpts = [{ value: f.scenic_id, label: f.scenic_id }].concat(scenicOpts);
    const poiOpts = (facets.pois || []).map((x) => ({ value: String(x.id), label: `${x.name} · ${fmt(x.n)}` }));
    const filtered = f.city || f.scenic_id || f.poi_id || f.score_min || f.q || f.sort !== 'collect';
    return html`<div className="page">
      <${Card} title="点评图片" sub=${list.total != null ? `共 ${fmt(list.total)} 张` : ''} className="fill" bodyClass="flush"
        extra=${html`<span className="toolbar">
          <${Select} value=${f.city} onChange=${(v) => set({ city: v || '', scenic_id: '', poi_id: '' })} optionList=${cityOpts} style=${{ width: 140 }} />
          <${Select} value=${f.scenic_id || undefined} placeholder="全部景区（可搜索）" optionList=${scenicOpts} style=${{ width: 240 }} filter remote
            onSearch=${onScenicSearch} showClear onChange=${(v) => set({ scenic_id: v || '', poi_id: '' })} emptyContent="没有有图片的景区" />
          <${Select} value=${f.poi_id || undefined} placeholder=${f.scenic_id ? '全部 POI' : '先选景区'} disabled=${!f.scenic_id} optionList=${poiOpts}
            style=${{ width: 220 }} showClear onChange=${(v) => set({ poi_id: v || '' })} />
          <${Select} value=${f.score_min} onChange=${(v) => set({ score_min: v })} optionList=${SCORE_OPTS} style=${{ width: 120 }} />
          <${Select} value=${f.sort} onChange=${(v) => set({ sort: v })} optionList=${SORT_OPTS} style=${{ width: 140 }}
            prefix=${html`<${Ic.IconSort} style=${{ marginLeft: 8, color: 'var(--ink-3)' }} />`} />
          ${filtered && html`<${Button} theme="borderless" type="tertiary" onClick=${() => { setF({ city: '', scenic_id: '', poi_id: '', score_min: '', sort: 'collect', q: '' }); go('gallery'); }}>重置<//>`}
        </span>`}>
        <div className="gallery" ref=${box}>
          ${list.items.length ? html`<div className="grid">${list.items.map((x, i) => html`<${Thumb} key=${x.record_id} x=${x} onOpen=${() => setVi(i)} />`)}</div>`
            : !list.loading && html`<${Empty} description=${list.error || '没有符合条件的图片'} style=${{ padding: 60 }} />`}
          <div ref=${sentinel} className="more">${listFoot(list, '张')}</div>
        </div>
      <//>
      ${vi >= 0 && html`<${Viewer} list=${list} index=${vi} setIndex=${setVi} onClose=${() => setVi(-1)} />`}
    </div>`;
  }

  // ------------------------------------------------------------ 任务中心
  function JobsPage({ query, cities }) {
    const [jobs, refresh] = usePoll(() => api('/api/jobs'), 2500);
    const [sel, setSel] = useState(query.id ? Number(query.id) : null);
    const selId = sel || (jobs && jobs[0] && jobs[0].id);
    const [detail] = usePoll(() => (selId ? api(`/api/jobs/${selId}?tail=500`) : null), 2000, [selId]);
    const [ar, setAr] = useState({ city: '', grade: '', q: '', limit: 0, spots: false, cache_only: false, dry_run: false, use_ai: true });
    const [im, setIm] = useState({ city: '', grade: '', q: '', max_pages: 20, max_images: 300, empty_pages: 10, refresh: false });
    const submit = async (type, params) => {
      try { const j = await post('/api/jobs', { type, params }); Toast.success(`已提交任务 #${j.id}`); setSel(j.id); refresh(); } catch (e) { Toast.error(e.message); }
    };
    const cancel = async (id) => { try { await post(`/api/jobs/${id}/cancel`); refresh(); } catch (e) { Toast.error(e.message); } };
    const sa = (k) => (v) => setAr((o) => ({ ...o, [k]: v }));
    const si = (k) => (v) => setIm((o) => ({ ...o, [k]: v }));
    const cols = [
      { title: '#', dataIndex: 'id', width: 50 },
      { title: '类型', dataIndex: 'type_name', width: 110, render: (v) => html`<span className="nw">${v}</span>` },
      { title: '状态', dataIndex: 'status', width: 90, render: jobTag },
      { title: '进度', dataIndex: 'done', width: 160, render: (v, r) => html`<div style=${{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <${Progress} percent=${r.total ? pct(v, r.total) : r.status === 'done' ? 100 : 0} showInfo=${false} size="small" style=${{ flex: 1, margin: 0 }} />
          <span className="nw muted">${v}/${r.total || '?'}</span></div>` },
      { title: '开始', dataIndex: 'started', width: 110, render: (v, r) => html`<span className="nw">${(v || r.created || '').slice(5, 16)}</span>` },
      { title: '最新', dataIndex: 'last', render: (v) => html`<${Text} type="tertiary" size="small" ellipsis=${{ showTooltip: true }} style=${{ width: 300 }}>${(v || '').slice(9)}<//>` },
      { title: '', dataIndex: 'op', width: 70, render: (v, r) => (['queued', 'running'].includes(r.status)
        ? html`<${Button} size="small" type="danger" theme="borderless" onClick=${(e) => { e.stopPropagation(); cancel(r.id); }}>取消<//>` : null) },
    ];
    const box = useRef(null); const h = useHeight(box);
    return html`<div className="page">
      <div className="row2 even" style=${{ flex: 'none' }}>
        <${Card} title="自动审核" help="名称一致且（地址相近 / 门牌一致 / 同省市区）的直接通过；规则判不了的交给 AI（在「设置」里开启并填 Key），AI 有把握的也通过，备注以「AI审核：」开头，最后在核对页筛「AI 通过（待复核）」复核。通过后自动排进图片采集；拿不准的留给人工。试运行只看结果不写库。">
          <div className="form">
            <${Field} label="范围">
              <${CitySelect} value=${ar.city} onChange=${sa('city')} cities=${cities} style=${{ width: 130 }} />
              <${Input} value=${ar.grade} onChange=${sa('grade')} placeholder="等级，如 5A,4A" style=${{ width: 140 }} showClear />
              <${Input} value=${ar.q} onChange=${sa('q')} placeholder="景区名 / ID" style=${{ width: 160 }} showClear />
            <//>
            <${Field} label="数量">
              <span className="lbl">最多</span><${InputNumber} hideButtons value=${ar.limit} onChange=${sa('limit')} min=${0} style=${{ width: 110 }} suffix="个景区" />
              <span className="lbl">0 = 不限</span>
            <//>
            <${Field} label="选项">
              <${Checkbox} checked=${ar.spots} onChange=${(e) => sa('spots')(e.target.checked)}>再搜核心景点<//>
              <${Checkbox} checked=${ar.cache_only} onChange=${(e) => sa('cache_only')(e.target.checked)}>只用缓存<//>
              <${Checkbox} checked=${ar.dry_run} onChange=${(e) => sa('dry_run')(e.target.checked)}>试运行<//>
              <${Checkbox} checked=${ar.use_ai} onChange=${(e) => sa('use_ai')(e.target.checked)}>规则判不了的交给 AI<//>
              <span style=${{ flex: 1 }}></span>
              <${Button} theme="solid" icon=${html`<${Ic.IconPlay} />`} onClick=${() => submit('auto_review', ar)}>开始<//>
            <//>
          </div>
        <//>
        <${Card} title="采集点评图片" help="已审核景区保留的 POI；采过的自动跳过，没有图片的记为「无图」立即换下一个。数字填 0 表示不限。">
          <div className="form">
            <${Field} label="范围">
              <${CitySelect} value=${im.city} onChange=${si('city')} cities=${cities} style=${{ width: 130 }} />
              <${Input} value=${im.grade} onChange=${si('grade')} placeholder="等级" style=${{ width: 110 }} showClear />
              <${Input} value=${im.q} onChange=${si('q')} placeholder="景区名 / ID" style=${{ width: 160 }} showClear />
            <//>
            <${Field} label="每个 POI">
              <span className="lbl">最多</span><${InputNumber} hideButtons value=${im.max_pages} onChange=${si('max_pages')} min=${1} style=${{ width: 96 }} suffix="页" />
              <${InputNumber} hideButtons value=${im.max_images} onChange=${si('max_images')} min=${0} style=${{ width: 106 }} suffix="张" />
              <span className="lbl">连续</span><${InputNumber} hideButtons value=${im.empty_pages} onChange=${si('empty_pages')} min=${0} style=${{ width: 96 }} suffix="页" />
              <span className="lbl">无新图换下一个</span>
            <//>
            <${Field} label="选项">
              <${Checkbox} checked=${im.refresh} onChange=${(e) => si('refresh')(e.target.checked)}>已采过的也重采<//>
              <span style=${{ flex: 1 }}></span>
              <${Button} theme="solid" icon=${html`<${Ic.IconPlay} />`} onClick=${() => submit('images', im)}>开始<//>
            <//>
          </div>
        <//>
      </div>
      <div className="row2 even fill">
        <${Card} title="任务" sub=${jobs ? `共 ${jobs.length} 个` : ''} bodyClass="flush">
          <div className="fill" ref=${box}>${h > 0 && html`<${Table} size="small" columns=${cols} dataSource=${jobs || []} rowKey="id" pagination=${false}
            scroll=${{ y: h - 41 }} loading=${!jobs} empty=${html`<${Empty} description="还没有任务" />`}
            onRow=${(r) => ({ onClick: () => setSel(r.id), style: { cursor: 'pointer', background: r.id === selId ? 'var(--semi-color-primary-light-default)' : undefined } })} />`}</div>
        <//>
        <${Card} title=${detail ? `日志 #${detail.id} ${detail.type_name}` : '日志'} extra=${detail && jobTag(detail.status)} bodyClass="flush">
          <div style=${{ flex: 1, minHeight: 0, padding: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
            ${detail && detail.type === 'images' && detail.status === 'running' && html`<${CrawlNowForJob} jobId=${detail.id} />`}
            <${LogBox} lines=${detail && detail.log} style=${{ flex: 1, minHeight: 0 }} />
          </div>
        <//>
      </div>
    </div>`;
  }

  function CrawlNowForJob({ jobId }) {
    const [d, refresh] = usePoll(() => api('/api/crawl'), 2000);
    const a = ((d && d.active) || []).filter((x) => x.source === 'job' && x.job_id === jobId);
    return html`<${CrawlNow} active=${a} refresh=${refresh} empty="正在切换 POI…" />`;
  }

  // ------------------------------------------------------------ 设置
  function SettingsPage({ refreshHealth }) {
    const [st, setSt] = useState(null);
    const [key, setKey] = useState('');
    const [busy, setBusy] = useState(false);
    const [test, setTest] = useState(null);
    const load = async () => { try { setSt(await api('/api/settings')); } catch (e) { Toast.error(e.message); } };
    useEffect(() => { load(); }, []);
    if (!st) return html`<div className="page"><${Spin} /></div>`;
    const set = (k) => (v) => setSt((o) => ({ ...o, [k]: v }));
    const sw = (k) => html`<${Switch} checked=${!!st[k]} onChange=${set(k)} />`;
    const AI_FIELDS = ['ai_enabled', 'ai_base_url', 'ai_model', 'ai_web_search', 'ai_max_keyword', 'ai_min_confidence', 'ai_auto_approve', 'ai_timeout_s'];
    const save = async () => {
      setBusy(true);
      try {
        const body = {};
        for (const k of [...AI_FIELDS, 'reviewer', 'throttle_ms', 'auto_search', 'auto_keep_similar', 'auto_approve', 'auto_approve_delay_ms', 'idle_skip',
          'idle_skip_sec', 'search_more', 'search_core_spots', 'max_extra', 'auto_address', 'auto_collect', 'collect_max_pages', 'collect_max_images',
          'collect_empty_pages']) body[k] = st[k];
        if (key.trim()) body.ai_api_key = key.trim();
        const r = await post('/api/settings', body);
        setSt(r); setKey('');
        window.dispatchEvent(new CustomEvent('hq:prefs', { detail: r })); // 核对面板立即用上新设置
        Toast.success('已保存'); refreshHealth && refreshHealth();
      } catch (e) { Toast.error(e.message); }
      setBusy(false);
    };
    const clearKey = async () => {
      try { const r = await post('/api/settings', { ai_api_key: '__clear__' }); setSt(r); window.dispatchEvent(new CustomEvent('hq:prefs', { detail: r })); Toast.success('已清除'); } catch (e) { Toast.error(e.message); }
    };
    const runTest = async () => {
      setTest({ loading: true });
      const body = {}; for (const k of AI_FIELDS) body[k] = st[k];
      if (key.trim()) body.ai_api_key = key.trim();
      try { setTest(await post('/api/ai/test', body)); } catch (e) { setTest({ ok: false, error: e.message }); }
    };
    const keyHint = st.ai_key_set ? `已设置（${st.ai_api_key || '环境变量'}，来自${st.ai_key_source || '设置页'}）；留空表示不修改` : '填写火山方舟 API Key（也可用环境变量 ARK_API_KEY）';
    return html`<div className="page">
      <div className="row2" style=${{ gridTemplateColumns: 'minmax(0, 1.15fr) minmax(0, 1fr)', flex: 1 }}>
        <${Card} title="AI 判断" sub=${st.ai_enabled ? (st.ai_key_set ? '已启用' : '已启用，缺 API Key') : '未启用'} bodyClass="scroll"
          help="规则判不了的景区（名称不一致、同名不同区、地址对不上…），把景区名称 / 别名 / 省市区 / 地址 / 坐标 / 核心景点和携程候选的名称 / 类型 / 城市区县 / 地址 / 距离发给大模型，判断每个 POI 是否属于这个景区。有把握（置信度达到下限）就自动保留并通过，备注以「AI审核：」开头，最后在核对页筛「AI 通过（待复核）」由人复核。结果按景区缓存，不重复调用。">
          <div className="form" style=${{ gridTemplateColumns: '96px minmax(0, 1fr)' }}>
            <${Field} label="启用">${sw('ai_enabled')}<span className="lbl">核对页搜完规则判不了时自动调用；任务中心的批量自动审核也会用</span><//>
            <${Field} label="接口地址"><${Input} value=${st.ai_base_url} onChange=${set('ai_base_url')} placeholder=${st.ai_defaults.ai_base_url} style=${{ flex: 1 }} /><//>
            <${Field} label="模型"><${Input} value=${st.ai_model} onChange=${set('ai_model')} placeholder=${st.ai_defaults.ai_model} style=${{ flex: 1 }} /><//>
            <${Field} label="API Key">
              <${Input} mode="password" value=${key} onChange=${setKey} placeholder=${keyHint} style=${{ flex: 1 }} autoComplete="new-password" />
              ${st.ai_key_set && st.ai_key_source === '设置页' && html`<${Button} type="danger" theme="borderless" onClick=${clearKey}>清除<//>`}
            <//>
            <${Field} label="联网搜索">${sw('ai_web_search')}<span className="lbl">让模型先上网查（web_search），更准但更慢、费用更高；最多</span>
              <${InputNumber} hideButtons value=${st.ai_max_keyword} onChange=${set('ai_max_keyword')} min=${1} max=${10} disabled=${!st.ai_web_search} style=${{ width: 90 }} suffix="个词" /><//>
            <${Field} label="自动通过">${sw('ai_auto_approve')}<span className="lbl">置信度 ≥</span>
              <${InputNumber} hideButtons value=${st.ai_min_confidence} onChange=${set('ai_min_confidence')} min=${0.5} max=${1} step=${0.05} precision=${2} style=${{ width: 90 }} />
              <span className="lbl">时自动保留并审核通过；低于这个只打标签、留给人</span><//>
            <${Field} label="超时"><${InputNumber} hideButtons value=${st.ai_timeout_s} onChange=${set('ai_timeout_s')} min=${10} max=${300} style=${{ width: 100 }} suffix="秒" /><//>
            <${Field} label="">
              <${Button} onClick=${runTest} loading=${test && test.loading} icon=${html`<${Ic.IconPulse} />`}>测试连接<//>
              <${Button} theme="solid" onClick=${save} loading=${busy}>保存<//>
            <//>
          </div>
          ${test && !test.loading && html`<${Banner} style=${{ marginTop: 14 }} type=${test.ok ? 'success' : 'danger'} closeIcon=${null}
            description=${test.ok ? `连通了：${test.model}${test.web_search ? '（联网搜索）' : ''}，用时 ${test.elapsed} 秒；返回：${test.text}` : `没连通：${test.error}`} />`}
        <//>
        <div className="page" style=${{ gap: 14 }}>
          <${Card} title="核对" bodyClass="scroll" className="fill">
            <div className="form" style=${{ gridTemplateColumns: '96px minmax(0, 1fr)' }}>
              <${Field} label="核对人"><${Input} value=${st.reviewer} onChange=${set('reviewer')} placeholder="写入审核记录的 reviewer" style=${{ width: 220 }} /><//>
              <${Field} label="自动搜索">${sw('auto_search')}<span className="lbl">打开景区时自动搜景区名；</span>${sw('search_more')}<span className="lbl">没通过再搜别名</span>
                ${sw('search_core_spots')}<span className="lbl">再搜核心景点，最多</span><${InputNumber} hideButtons value=${st.max_extra} onChange=${set('max_extra')} min=${0} max=${20} style=${{ width: 80 }} suffix="个" /><//>
              <${Field} label="自动保留">${sw('auto_keep_similar')}<span className="lbl">地址相近、名称一致 / 子景点且同省市区的自动保留</span><//>
              <${Field} label="自动通过">${sw('auto_approve')}<span className="lbl">倒计时</span><${InputNumber} hideButtons value=${st.auto_approve_delay_ms} onChange=${set('auto_approve_delay_ms')} min=${0} step=${500} style=${{ width: 110 }} suffix="毫秒" /><//>
              <${Field} label="无人接管">${sw('idle_skip')}<${InputNumber} hideButtons value=${st.idle_skip_sec} onChange=${set('idle_skip_sec')} min=${3} style=${{ width: 90 }} suffix="秒" /><span className="lbl">没人操作就跳过、进入下一个</span><//>
              <${Field} label="搜索间隔"><${InputNumber} hideButtons value=${st.throttle_ms} onChange=${set('throttle_ms')} min=${500} step=${100} style=${{ width: 120 }} suffix="毫秒" /><span className="lbl">两次携程搜索的最小间隔</span><//>
              <${Field} label="补全地址">${sw('auto_address')}<span className="lbl">搜索后自动打开详情页补地址（较慢）</span><//>
            </div>
          <//>
          <${Card} title="图片采集" bodyClass="scroll">
            <div className="form" style=${{ gridTemplateColumns: '96px minmax(0, 1fr)' }}>
              <${Field} label="边核对边采集">${sw('auto_collect')}<span className="lbl">审核通过后自动采集图片</span><//>
              <${Field} label="每个 POI"><span className="lbl">最多</span><${InputNumber} hideButtons value=${st.collect_max_pages} onChange=${set('collect_max_pages')} min=${1} style=${{ width: 90 }} suffix="页" />
                <${InputNumber} hideButtons value=${st.collect_max_images} onChange=${set('collect_max_images')} min=${0} style=${{ width: 100 }} suffix="张" />
                <span className="lbl">连续</span><${InputNumber} hideButtons value=${st.collect_empty_pages} onChange=${set('collect_empty_pages')} min=${0} style=${{ width: 90 }} suffix="页" /><span className="lbl">无新图换下一个</span><//>
            </div>
            <div style=${{ marginTop: 14, textAlign: 'right' }}><${Button} theme="solid" onClick=${save} loading=${busy}>保存<//></div>
          <//>
        </div>
      </div>
    </div>`;
  }

  // ------------------------------------------------------------ 顶栏 / 侧栏
  const PAGES = {
    overview: ['总览', '审核与图片采集进度'],
    review: ['核对', '快捷键 1–9 保留、Enter 审核完成、S 跳过、←/→ 翻景区'],
    images: ['图片采集', '进已审核 POI 的携程主页翻点评，把点评图片写进 MySQL'],
    data: ['数据预览', '客户景区表 + ctrip_poi_info + approval，点一行看详情'],
    gallery: ['图片预览', '按城市 / 景区 / POI 筛选，点开看大图和图片信息'],
    jobs: ['任务中心', '任务按提交顺序逐个执行；遇到登录 / 验证会停在「需要人工」'],
    settings: ['设置', 'AI 判断、核对、图片采集的开关和参数'],
  };
  const NAV = [
    ['overview', '总览', Ic.IconHome], ['review', '核对', Ic.IconCheckboxTick], ['images', '图片采集', Ic.IconCamera],
    ['data', '数据预览', Ic.IconGridView], ['gallery', '图片预览', Ic.IconGallery], ['jobs', '任务中心', Ic.IconList],
  ];

  /** 左侧深色图标栏：导航 + 搜索 / 提醒 / 核对人（不再单独占一行顶栏，页面用满高度） */
  function Rail({ route, health, follow, onReviewer }) {
    const [kw, setKw] = useState('');
    const alerts = [];
    if (health && health.need_human) alerts.push({ text: `${health.need_human} 个任务需要人工处理（登录 / 验证）`, to: 'jobs' });
    if (follow && follow.paused) alerts.push({ text: `边核对边采集已暂停：${follow.message || '手动暂停'}`, to: 'images' });
    if (health && health.ok === false) alerts.push({ text: `数据库异常：${health.error || ''}`, to: 'overview' });
    const reviewer = (health && health.reviewer) || '';
    const search = () => { if (kw.trim()) go('data', { q: kw.trim() }); };
    return html`<nav className="rail">
      <div className="logo" title="景区 POI 数据工作台"><${Ic.IconMapPin} /></div>
      ${NAV.map(([k, t, I]) => html`<${Tooltip} key=${k} content=${t} position="right">
        <a className=${route === k ? 'on' : ''} href=${'#/' + k} aria-label=${t}><${I} /></a><//>`)}
      <span className="grow"></span>
      <${Tooltip} content="设置（AI 判断 / 核对 / 采集）" position="right"><a className=${route === 'settings' ? 'on' : ''} href="#/settings" aria-label="设置"><${Ic.IconSetting} /></a><//>
      <${Popover} trigger="click" position="rightBottom" content=${html`<div style=${{ padding: 12, width: 300 }}>
          <${Input} value=${kw} onChange=${setKw} onEnterPress=${search} autoFocus showClear placeholder="景区名 / 别名 / 景区ID，回车"
            prefix=${html`<${Ic.IconSearch} style=${{ marginLeft: 6 }} />`} /></div>`}>
        <a aria-label="搜索景区" title="搜索景区"><${Ic.IconSearch} /></a>
      <//>
      <${Popover} trigger="click" position="rightBottom" content=${html`<div style=${{ width: 320, padding: '10px 14px' }}>
          <div style=${{ fontWeight: 600, marginBottom: 4 }}>提醒</div>
          ${alerts.length ? alerts.map((x, i) => html`<div className="alert-item" key=${i} onClick=${() => go(x.to)}>${x.text}</div>`)
            : html`<div className="muted" style=${{ padding: '8px 0' }}>没有需要处理的事项</div>`}</div>`}>
        <a aria-label="提醒" title="提醒" className="bell"><${Ic.IconBell} />${alerts.length > 0 && html`<i className="dot"></i>`}</a>
      <//>
      <${Dropdown} position="rightBottom" render=${html`<${Dropdown.Menu}>
          <${Dropdown.Title}>${reviewer ? `核对人：${reviewer}` : '还没设置核对人'}<//>
          <${Dropdown.Item} icon=${html`<${Ic.IconUser} />`} onClick=${onReviewer}>设置核对人<//>
          <${Dropdown.Item} icon=${html`<${Ic.IconDownload} />`} onClick=${() => window.open('/api/export.csv')}>导出核对结果 CSV<//>
          <${Dropdown.Item} icon=${html`<${Ic.IconFile} />`} onClick=${() => window.open('/docs')}>接口文档<//>
        <//>`}>
        <span className="me" title=${reviewer || '设置核对人'}><${Avatar} size="small" style=${{ background: 'linear-gradient(135deg,#8b6cff,#e0703a)' }}>
          ${reviewer ? reviewer.slice(0, 1) : html`<${Ic.IconUser} />`}<//></span>
      <//>
    </nav>`;
  }

  function ReviewerModal({ visible, current, onClose, onSaved }) {
    const [v, setV] = useState(current || '');
    useEffect(() => { if (visible) setV(current || ''); }, [visible]); // eslint-disable-line
    const save = async () => {
      try {
        const prefs = await post('/api/rpc/prefs', { reviewer: v.trim() });
        window.dispatchEvent(new CustomEvent('hq:prefs', { detail: { reviewer: prefs.reviewer } }));
        Toast.success('已保存'); onSaved(); onClose();
      } catch (e) { Toast.error(e.message); }
    };
    return html`<${Modal} title="设置核对人" visible=${visible} onOk=${save} onCancel=${onClose} okText="保存" cancelText="取消" width=${420}>
      <${Input} value=${v} onChange=${setV} placeholder="写入审核记录的 reviewer 字段" onEnterPress=${save} autoFocus />
    <//>`;
  }

  // ------------------------------------------------------------ 应用
  function App() {
    const { path, query } = useHash();
    const route = PAGES[path] ? path : 'overview';
    const [health, refreshHealth] = usePoll(() => api('/api/health'), 5000);
    const [follow, refreshFollow] = usePoll(() => api('/api/follow'), 2000);
    const [stats] = usePoll(() => api('/api/stats'), 60000);
    const cities = stats && stats.cities;
    const [rv, setRv] = useState(false);
    const props = { query, follow, refreshFollow, cities };
    let page = null;
    if (route === 'overview') page = html`<${Overview} ...${props} />`;
    else if (route === 'images') page = html`<${ImagesPage} ...${props} />`;
    else if (route === 'data') page = html`<${DataPage} ...${props} />`;
    else if (route === 'gallery') page = html`<${GalleryPage} ...${props} />`;
    else if (route === 'jobs') page = html`<${JobsPage} ...${props} />`;
    else if (route === 'settings') page = html`<${SettingsPage} refreshHealth=${refreshHealth} />`;
    useEffect(() => { document.title = `${PAGES[route][0]} · 景区 POI 数据工作台`; }, [route]);
    return html`<div className="frame">
      <${Rail} route=${route} health=${health} follow=${follow} onReviewer=${() => setRv(true)} />
      <div className="main">
        <div className="content">
          <${ReviewPage} visible=${route === 'review'} ...${props} />
          ${page}
        </div>
      </div>
      <${ReviewerModal} visible=${rv} current=${health && health.reviewer} onClose=${() => setRv(false)} onSaved=${refreshHealth} />
    </div>`;
  }

  ReactDOM.createRoot(document.getElementById('root')).render(html`<${App} />`);
})();
