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

  function Card({ title, sub, extra, children, className = '', bodyClass = '', style }) {
    return html`<div className=${'card ' + className} style=${style}>
      ${(title || extra) && html`<div className="hd"><h3>${title}</h3>${sub && html`<span className="sub">${sub}</span>`}<span className="grow"></span>${extra}</div>`}
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
      return /^自动审核/.test(x.note || '') ? html`<${Tag} color="green" size="small">自动通过<//>` : html`<${Tag} color="violet" size="small">人工通过<//>`;
    }
    if (x.status === 'skip') return html`<${Tag} color="orange" size="small">已跳过<//>`;
    return html`<${Tag} color="grey" size="small">待核对<//>`;
  }
  const CRAWL_ST = { done: ['green', '完成'], partial: ['orange', '部分'], failed: ['red', '失败'], running: ['blue', '采集中'] };
  const crawlTag = (s) => { const [c, t] = CRAWL_ST[s] || ['grey', s || '—']; return html`<${Tag} color=${c} size="small">${t}<//>`; };
  const JOB_ST = { queued: ['grey', '排队中'], running: ['blue', '运行中'], done: ['green', '完成'], failed: ['red', '失败'], cancelled: ['grey', '已取消'], need_human: ['orange', '需要人工'] };
  const jobTag = (s) => { const [c, t] = JOB_ST[s] || ['grey', s]; return html`<${Tag} color=${c} size="small">${t}<//>`; };
  const STATUS_OPTS = [{ value: 'all', label: '全部状态' }, { value: 'todo', label: '待核对' }, { value: 'done', label: '已审核' },
    { value: 'auto', label: '自动通过' }, { value: 'skip', label: '已跳过' }];

  function CitySelect({ value, onChange, cities, style }) {
    const opts = [{ value: '', label: '全部城市' }].concat((cities || []).filter((c) => c.city).map((c) => ({ value: c.city, label: shortCity(c.city) })));
    return html`<${Select} value=${value} onChange=${onChange} optionList=${opts} style=${style || { width: 130 }} filter />`;
  }

  // ------------------------------------------------------------ 采集状态（边核对边采集 + 正在采集的 POI）
  function followState(f) {
    if (!f || !f.enabled) return ['grey', '已关闭'];
    if (f.paused) return ['orange', '已暂停'];
    if (f.current) return ['blue', '采集中'];
    return ['green', '待命'];
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
    const [c, t] = followState(f);
    return html`<span className="toolbar" style=${{ gap: 8 }}>
      <${Switch} size="small" checked=${!!f.enabled} onChange=${(v) => setFollow({ enabled: v }, refresh)} />
      <${Text} strong>边核对边采集<//>
      <${Tag} color=${c} size="small">${t}<//>
      <${Text} type="tertiary" size="small">排队 ${f.pending || 0} · 已采景区 ${f.done || 0} · 新增图片 ${fmt(f.images || 0)}${f.failed ? ` · 失败 ${f.failed}` : ''}<//>
      ${f.enabled && (f.paused
        ? html`<${Button} size="small" theme="solid" icon=${html`<${Ic.IconPlay} />`} onClick=${() => setFollow({ resume: true }, refresh)}>继续<//>`
        : html`<${Button} size="small" type="tertiary" icon=${html`<${Ic.IconPause} />`} onClick=${() => setFollow({ pause: true }, refresh)}>暂停<//>`)}
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
  function Overview({ follow, refreshFollow }) {
    const [ov] = usePoll(() => api('/api/overview'), 15000);
    const [jobs] = usePoll(() => api('/api/jobs'), 5000);
    const o = ov || {};
    const crawl = o.crawl || {};
    const cityCols = [
      { title: '城市', dataIndex: 'city', width: 90, render: (v) => shortCity(v) },
      { title: '景区', dataIndex: 'n', width: 70, align: 'right', render: fmt },
      { title: '已审核', dataIndex: 'reviewed', render: (v, r) => html`<div style=${{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <${Progress} percent=${pct(v || 0, r.n)} showInfo=${false} size="small" style=${{ flex: 1, margin: 0 }} />
          <span className="nw" style=${{ width: 110, textAlign: 'right' }}>${fmt(v || 0)}（${pct(v || 0, r.n)}%）</span></div>` },
      { title: '跳过', dataIndex: 'skipped', width: 60, align: 'right', render: fmt },
      { title: '已采 POI', dataIndex: 'pois', width: 80, align: 'right', render: fmt },
      { title: '图片', dataIndex: 'images', width: 80, align: 'right', render: fmt },
    ];
    const box = useRef(null); const h = useHeight(box);
    const recent = (jobs || []).slice(0, 8);
    return html`<div className="page">
      <div className="stats">
        <${Stat} icon=${html`<${Ic.IconMapPin} />`} color="violet" k="景区总数" v=${fmt(o.total)} s=${`${(o.cities || []).length} 个城市`} />
        <${Stat} icon=${html`<${Ic.IconTick} />`} color="green" k="已审核" v=${fmt(o.approved)} s=${`自动 ${fmt(o.auto_approved)} · 人工 ${fmt(o.manual_approved)} · ${pct(o.approved, o.total)}%`} />
        <${Stat} icon=${html`<${Ic.IconCheckboxTick} />`} color="grey" k="待核对" v=${fmt(o.todo)} s=${html`<a onClick=${() => go('review')}>去核对</a>`} />
        <${Stat} icon=${html`<${Ic.IconAlertTriangle} />`} color="orange" k="已跳过（待人定）" v=${fmt(o.skipped)} s="核对页筛选「已跳过」处理" />
        <${Stat} icon=${html`<${Ic.IconCamera} />`} color="blue" k="已采 POI" v=${fmt(crawl.done || 0)} s=${`可采 ${fmt(o.crawlable_pois)} · 部分 ${crawl.partial || 0} · 失败 ${crawl.failed || 0}`} />
        <${Stat} icon=${html`<${Ic.IconGallery} />`} color="pink" k="点评图片" v=${fmt(o.images)} s=${`${o.ods_table || 'ODS'}：${fmt(o.ods_rows)} 行`} />
      </div>
      <div className="row2 fill">
        <${Card} title="各城市进度" sub="审核 approval=1 / 图片按 POI 统计" bodyClass="flush">
          <div className="fill" ref=${box}>${h > 0 && html`<${Table} size="small" columns=${cityCols} dataSource=${o.cities || []} rowKey="city"
            pagination=${false} scroll=${{ y: h - 41 }} loading=${!ov} onRow=${(r) => ({ onClick: () => go('data', { city: r.city }), style: { cursor: 'pointer' } })} />`}</div>
        <//>
        <div className="page" style=${{ gap: 12 }}>
          <${Card} title="正在采集" bodyClass="scroll" style=${{ flex: 'none', maxHeight: '50%' }}>
            <div style=${{ marginBottom: 10 }}><${FollowControls} follow=${follow} refresh=${refreshFollow} /></div>
            ${follow && follow.paused && follow.message && html`<${Banner} type="warning" description=${follow.message} closeIcon=${null} style=${{ marginBottom: 8 }} />`}
            <${CrawlNow} active=${follow && follow.active} refresh=${refreshFollow} />
          <//>
          <${Card} title="最近任务" extra=${html`<${Button} size="small" theme="borderless" onClick=${() => go('jobs')}>任务中心<//>`} className="fill" bodyClass="scroll">
            ${recent.length ? recent.map((j) => html`<div key=${j.id} style=${{ padding: '6px 0', borderBottom: '1px solid var(--app-line)', cursor: 'pointer' }} onClick=${() => go('jobs', { id: j.id })}>
              <div style=${{ display: 'flex', gap: 8, alignItems: 'center' }}><b>#${j.id} ${j.type_name}</b>${jobTag(j.status)}<span className="grow" style=${{ flex: 1 }}></span>
                <${Text} type="tertiary" size="small">${(j.started || j.created || '').slice(5, 16)}<//></div>
              <${Text} type="tertiary" size="small" ellipsis=${{ showTooltip: true }} style=${{ width: '100%' }}>${(j.last || '').slice(9)}<//>
            </div>`) : html`<${Empty} description="还没有任务" />`}
          <//>
        </div>
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
          : html`<${Text} type="tertiary" size="small">审核完成（含自动通过）的景区会自动排进图片采集<//>`}</div>
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
      { title: '景区 / POI', dataIndex: 'poi_name', width: 260, render: (v, r) => html`<div className="cell-2"><div className="t">${v || '—'} <${Text} type="tertiary" size="small">poiId ${r.poi_id}<//></div>
          <div className="d">${r.scenic_name || r.scenic_id}${r.city ? ' · ' + shortCity(r.city) : ''}</div></div>` },
      { title: '状态', dataIndex: 'status', width: 80, render: crawlTag },
      { title: '页数', dataIndex: 'pages_done', width: 64, align: 'right' },
      { title: '点评', dataIndex: 'review_qty', width: 100, align: 'right', render: (v, r) => html`<span className="nw">${fmt(v)} / ${fmt(r.total_count)}</span>` },
      { title: '新增图片', dataIndex: 'image_qty', width: 96, align: 'right', render: fmt },
      { title: '说明', dataIndex: 'message', render: (v) => html`<${Text} type="tertiary" size="small" ellipsis=${{ showTooltip: true }} style=${{ width: 220 }}>${v || '—'}<//>` },
      { title: '更新时间', dataIndex: 'updated_at', width: 150, render: (v) => html`<span className="nw">${v || ''}</span>` },
      { title: '', dataIndex: 'op', width: 190, render: (v, r) => html`<span className="toolbar nw" style=${{ flexWrap: 'nowrap' }}>
          <${Button} size="small" theme="borderless" onClick=${() => go('gallery', { poi_id: r.poi_id })}>看图片<//>
          ${r.poi_uri && html`<${Button} size="small" theme="borderless" type="tertiary" onClick=${() => window.open(r.poi_uri, '_blank', 'noreferrer')}>携程页面<//>`}</span>` },
    ];
    const statusOpts = [{ value: '', label: '全部' }, { value: 'done', label: '完成' }, { value: 'partial', label: '部分' }, { value: 'failed', label: '失败' }, { value: 'running', label: '采集中' }];
    return html`<div className="page">
      <div className="row2 even" style=${{ height: 300, flex: 'none' }}>
        <${Card} title="批量采集" sub="对已审核（approval=1）景区保留的 POI，进主页翻点评、存图片" bodyClass="scroll">
          <div className="toolbar" style=${{ marginBottom: 12 }}>
            <${CitySelect} value=${p.city} onChange=${set('city')} cities=${cities} />
            <${Input} value=${p.grade} onChange=${set('grade')} placeholder="等级，如 5A,4A" style=${{ width: 140 }} showClear />
            <${Input} value=${p.q} onChange=${set('q')} placeholder="景区名 / 景区ID" style=${{ width: 180 }} showClear />
          </div>
          <div className="toolbar" style=${{ marginBottom: 12 }}>
            <span className="lbl">每个 POI 最多</span><${InputNumber} hideButtons value=${p.max_pages} onChange=${set('max_pages')} min=${1} style=${{ width: 110 }} suffix="页" />
            <${InputNumber} hideButtons value=${p.max_images} onChange=${set('max_images')} min=${0} style=${{ width: 120 }} suffix="张" />
            <span className="lbl">连续</span><${InputNumber} hideButtons value=${p.empty_pages} onChange=${set('empty_pages')} min=${0} style=${{ width: 110 }} suffix="页" />
            <span className="lbl">没有新图片就换下一个 POI</span>
          </div>
          <div className="toolbar">
            <span className="lbl">最多采</span><${InputNumber} hideButtons value=${p.limit} onChange=${set('limit')} min=${0} style=${{ width: 120 }} suffix="个 POI" />
            <${Checkbox} checked=${p.refresh} onChange=${(e) => set('refresh')(e.target.checked)}>已采完的也重采<//>
            <span className="grow" style=${{ flex: 1 }}></span>
            <${Button} theme="solid" icon=${html`<${Ic.IconPlay} />`} onClick=${submit}>开始采集<//>
          </div>
          <div className="muted" style=${{ fontSize: 12, marginTop: 10 }}>第一页读页面里的 __NEXT_DATA__，之后点「下一页」读 getCommentCollapseList；最多张数填 0 表示不限，连续页数填 0 表示不按这个规则换。</div>
        <//>
        <${Card} title="正在采集" extra=${html`<${FollowControls} follow=${follow} refresh=${refreshFollow} />`} bodyClass="flush">
          <div style=${{ padding: '12px 16px 8px', flex: 'none' }}>
            ${follow && follow.paused && follow.message && html`<${Banner} type="warning" description=${follow.message} closeIcon=${null} style=${{ marginBottom: 8 }} />`}
            <${CrawlNow} active=${follow && follow.active} refresh=${refreshFollow} />
          </div>
          <div style=${{ flex: 1, minHeight: 0, padding: '0 16px 12px', display: 'flex' }}><${LogBox} lines=${follow && follow.log} style=${{ flex: 1 }} /></div>
        <//>
      </div>
      <${Card} title="POI 采集记录" sub=${list.total != null ? `共 ${fmt(list.total)} 个 POI` : ''} className="fill" bodyClass="flush"
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
      { title: '图片', dataIndex: 'images', width: 70, align: 'right', render: fmt },
      { title: '核对', dataIndex: 'updated_at', width: 150, render: (v, r) => html`<div className="cell-2"><div className="d">${r.reviewer || (/^自动审核/.test(r.note || '') ? 'auto' : '')}</div><div className="d nw">${v || ''}</div></div>` },
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
        <div className="t"><b>${p.poiName}</b><${Text} type="tertiary" size="small">poiId ${p.poiId}<//><span style=${{ flex: 1 }}></span><${Tag} size="small" color=${p.images ? 'green' : 'grey'}>图片 ${p.images || 0}<//></div>
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
      <div className="cap"><b>${x.poi_name}</b><span>${x.review_score != null ? `${x.review_score} 分 · ` : ''}${(x.review_publish_time || '').slice(0, 10)}</span></div>
    </div>`;
  }

  function GalleryPage({ query, cities }) {
    const init = () => ({ city: query.city || '', q: query.q || '', scenic_id: query.scenic_id || '', poi_id: query.poi_id || '' });
    const [f, setF] = useState(init);
    const [kw, setKw] = useState(query.q || '');
    useEffect(() => { setF(init()); setKw(query.q || ''); }, [query.city, query.q, query.scenic_id, query.poi_id]); // eslint-disable-line
    const list = useInfinite('/api/images', f, 60);
    const box = useRef(null); const sentinel = useRef(null);
    const [pv, setPv] = useState({ visible: false, index: 0 });
    useEffect(() => {
      if (!sentinel.current) return undefined;
      const io = new IntersectionObserver(([e]) => { if (e.isIntersecting) list.loadMore(); }, { root: box.current, rootMargin: '400px' });
      io.observe(sentinel.current);
      return () => io.disconnect();
    });
    useEffect(() => { if (box.current) box.current.scrollTop = 0; }, [JSON.stringify(f)]); // eslint-disable-line
    const setK = (k) => (v) => setF((o) => ({ ...o, [k]: v }));
    const cur = list.items[pv.index];
    return html`<div className="page">
      <${Card} title="点评图片" sub=${list.total != null ? `共 ${fmt(list.total)} 张` : ''} className="fill" bodyClass="flush"
        extra=${html`<span className="toolbar">
          <${CitySelect} value=${f.city} onChange=${setK('city')} cities=${cities} />
          <${Input} value=${kw} onChange=${setKw} onEnterPress=${() => setK('q')(kw.trim())} placeholder="景区名 / POI 名，回车" prefix=${html`<${Ic.IconSearch} />`}
            style=${{ width: 200 }} showClear onClear=${() => setK('q')('')} />
          <${Input} value=${f.scenic_id} onChange=${setK('scenic_id')} placeholder="景区ID" style=${{ width: 160 }} showClear />
          <${Input} value=${f.poi_id} onChange=${setK('poi_id')} placeholder="poiId" style=${{ width: 120 }} showClear />
        </span>`}>
        <div className="gallery" ref=${box}>
          ${list.items.length ? html`<div className="grid">${list.items.map((x, i) => html`<${Thumb} key=${x.record_id} x=${x} onOpen=${() => setPv({ visible: true, index: i })} />`)}</div>`
            : !list.loading && html`<${Empty} description=${list.error || '没有图片'} style=${{ padding: 60 }} />`}
          <div ref=${sentinel} className="more">${listFoot(list, '张')}</div>
        </div>
      <//>
      ${list.items.length > 0 && html`<${ImagePreview} src=${list.items.map((x) => x.image_url)} visible=${pv.visible} currentIndex=${pv.index}
        onVisibleChange=${(v) => setPv((o) => ({ ...o, visible: v }))} onChange=${(i) => setPv((o) => ({ ...o, index: i }))}
        infinite=${false} />`}
      ${pv.visible && cur && html`<div style=${{ position: 'fixed', left: 0, right: 0, bottom: 72, zIndex: 2000, textAlign: 'center', pointerEvents: 'none' }}>
        <span style=${{ background: 'rgba(0,0,0,.55)', color: '#fff', padding: '6px 12px', borderRadius: 6, fontSize: 13 }}>
          ${cur.scenic_name} / ${cur.poi_name} · ${pv.index + 1} / ${fmt(list.total)} · ${cur.review_score != null ? cur.review_score + ' 分 · ' : ''}${(cur.review_publish_time || '').slice(0, 10)} · ${cur.width}×${cur.height}</span></div>`}
    </div>`;
  }

  // ------------------------------------------------------------ 任务中心
  function JobsPage({ query, cities }) {
    const [jobs, refresh] = usePoll(() => api('/api/jobs'), 2500);
    const [sel, setSel] = useState(query.id ? Number(query.id) : null);
    const selId = sel || (jobs && jobs[0] && jobs[0].id);
    const [detail] = usePoll(() => (selId ? api(`/api/jobs/${selId}?tail=500`) : null), 2000, [selId]);
    const [ar, setAr] = useState({ city: '', grade: '', q: '', limit: 0, spots: false, cache_only: false, dry_run: false });
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
        <${Card} title="自动审核" sub="名称一致且（地址相近 / 门牌一致 / 同省市区）直接通过，通过后自动排进图片采集">
          <div className="toolbar" style=${{ marginBottom: 12 }}>
            <${CitySelect} value=${ar.city} onChange=${sa('city')} cities=${cities} />
            <${Input} value=${ar.grade} onChange=${sa('grade')} placeholder="等级，如 5A,4A" style=${{ width: 130 }} showClear />
            <${Input} value=${ar.q} onChange=${sa('q')} placeholder="景区名 / ID" style=${{ width: 150 }} showClear />
            <span className="lbl">最多</span><${InputNumber} hideButtons value=${ar.limit} onChange=${sa('limit')} min=${0} style=${{ width: 120 }} suffix="个" />
          </div>
          <div className="toolbar">
            <${Checkbox} checked=${ar.spots} onChange=${(e) => sa('spots')(e.target.checked)}>再搜核心景点<//>
            <${Checkbox} checked=${ar.cache_only} onChange=${(e) => sa('cache_only')(e.target.checked)}>只用缓存<//>
            <${Checkbox} checked=${ar.dry_run} onChange=${(e) => sa('dry_run')(e.target.checked)}>试运行（不写库）<//>
            <span style=${{ flex: 1 }}></span>
            <${Button} theme="solid" icon=${html`<${Ic.IconPlay} />`} onClick=${() => submit('auto_review', ar)}>开始<//>
          </div>
        <//>
        <${Card} title="采集点评图片" sub="已审核景区保留的 POI；已采完的自动跳过">
          <div className="toolbar" style=${{ marginBottom: 12 }}>
            <${CitySelect} value=${im.city} onChange=${si('city')} cities=${cities} />
            <${Input} value=${im.grade} onChange=${si('grade')} placeholder="等级" style=${{ width: 100 }} showClear />
            <${Input} value=${im.q} onChange=${si('q')} placeholder="景区名 / ID" style=${{ width: 150 }} showClear />
            <${InputNumber} hideButtons value=${im.max_pages} onChange=${si('max_pages')} min=${1} style=${{ width: 110 }} suffix="页" />
            <${InputNumber} hideButtons value=${im.max_images} onChange=${si('max_images')} min=${0} style=${{ width: 120 }} suffix="张" />
          </div>
          <div className="toolbar">
            <span className="lbl">连续</span><${InputNumber} hideButtons value=${im.empty_pages} onChange=${si('empty_pages')} min=${0} style=${{ width: 110 }} suffix="页" />
            <span className="lbl">无新图换下一个</span>
            <${Checkbox} checked=${im.refresh} onChange=${(e) => si('refresh')(e.target.checked)}>重采<//>
            <span style=${{ flex: 1 }}></span>
            <${Button} theme="solid" icon=${html`<${Ic.IconPlay} />`} onClick=${() => submit('images', im)}>开始<//>
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

  // ------------------------------------------------------------ 顶栏
  const PAGES = {
    overview: ['总览', '审核与图片采集进度'],
    review: ['核对', '服务端浏览器在携程搜索框里输入、读下拉结果；快捷键 1–9 保留、Enter 审核完成、S 跳过、←/→ 翻景区'],
    images: ['图片采集', '进已审核 POI 的携程主页翻点评，把点评图片写进 MySQL'],
    data: ['数据预览', '客户景区表 + ctrip_poi_info + approval，点一行看详情'],
    gallery: ['图片预览', '已采集的点评图片，点开看大图（← → 翻页、Esc 关闭）'],
    jobs: ['任务中心', '任务按提交顺序逐个执行；遇到登录 / 验证会停在「需要人工」，在服务打开的浏览器里处理后重新提交'],
  };

  function TopBar({ route, health, follow, onReviewer }) {
    const [kw, setKw] = useState('');
    const [title, sub] = PAGES[route] || PAGES.overview;
    const alerts = [];
    if (health && health.need_human) alerts.push({ text: `${health.need_human} 个任务需要人工处理（登录 / 验证）`, to: 'jobs' });
    if (follow && follow.paused) alerts.push({ text: `边核对边采集已暂停：${follow.message || '手动暂停'}`, to: 'images' });
    if (health && health.ok === false) alerts.push({ text: `数据库异常：${health.error || ''}`, to: 'overview' });
    const reviewer = (health && health.reviewer) || '';
    return html`<div className="topbar">
      <div className="ttl"><h1>${title}</h1><span title=${sub}>${sub}</span></div>
      <span className="grow"></span>
      <${Input} value=${kw} onChange=${setKw} prefix=${html`<${Ic.IconSearch} />`} placeholder="搜索景区名 / 景区ID，回车" style=${{ width: 260 }}
        onEnterPress=${() => { if (kw.trim()) go('data', { q: kw.trim() }); }} showClear />
      <${Popover} trigger="click" position="bottomRight" content=${html`<div style=${{ width: 320, padding: '8px 12px' }}>
          <div style=${{ fontWeight: 600, marginBottom: 4 }}>提醒</div>
          ${alerts.length ? alerts.map((a, i) => html`<div className="alert-item" key=${i} onClick=${() => go(a.to)}>${a.text}</div>`)
            : html`<div className="muted" style=${{ padding: '8px 0' }}>没有需要处理的事项</div>`}</div>`}>
        <span><${Badge} dot=${alerts.length > 0} type="danger"><${Button} theme="borderless" type="tertiary" icon=${html`<${Ic.IconBell} />`} /><//></span>
      <//>
      <${Dropdown} position="bottomRight" render=${html`<${Dropdown.Menu}>
          <${Dropdown.Item} icon=${html`<${Ic.IconUser} />`} onClick=${onReviewer}>设置核对人<//>
          <${Dropdown.Item} icon=${html`<${Ic.IconFile} />`} onClick=${() => window.open('/docs')}>接口文档<//>
          <${Dropdown.Item} icon=${html`<${Ic.IconDownload} />`} onClick=${() => window.open('/api/export.csv')}>导出核对结果 CSV<//>
        <//>`}>
        <div className="who">
          <${Avatar} size="small" color="violet">${reviewer ? reviewer.slice(0, 1) : html`<${Ic.IconUser} />`}<//>
          <span>${reviewer || '未设置核对人'}</span><${Ic.IconChevronDown} size="small" />
        </div>
      <//>
    </div>`;
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
  const NAV = [
    { itemKey: 'overview', text: '总览', icon: html`<${Ic.IconHome} />` },
    { itemKey: 'review', text: '核对', icon: html`<${Ic.IconCheckboxTick} />` },
    { itemKey: 'images', text: '图片采集', icon: html`<${Ic.IconCamera} />` },
    { itemKey: 'data', text: '数据预览', icon: html`<${Ic.IconGridView} />` },
    { itemKey: 'gallery', text: '图片预览', icon: html`<${Ic.IconGallery} />` },
    { itemKey: 'jobs', text: '任务中心', icon: html`<${Ic.IconList} />` },
  ];

  function App() {
    const { path, query } = useHash();
    const route = PAGES[path] ? path : 'overview';
    const [health, refreshHealth] = usePoll(() => api('/api/health'), 5000);
    const [follow, refreshFollow] = usePoll(() => api('/api/follow'), 2000);
    const [stats] = usePoll(() => api('/api/stats'), 60000);
    const cities = stats && stats.cities;
    const [rv, setRv] = useState(false);
    const [collapsed, setCollapsed] = useState(window.innerWidth < 1440);
    const props = { query, follow, refreshFollow, cities };
    let page = null;
    if (route === 'overview') page = html`<${Overview} ...${props} />`;
    else if (route === 'images') page = html`<${ImagesPage} ...${props} />`;
    else if (route === 'data') page = html`<${DataPage} ...${props} />`;
    else if (route === 'gallery') page = html`<${GalleryPage} ...${props} />`;
    else if (route === 'jobs') page = html`<${JobsPage} ...${props} />`;
    return html`<${Layout} className="app">
      <${Layout.Sider}>
        <${Nav} items=${NAV} selectedKeys=${[route]} onSelect=${({ itemKey }) => go(itemKey)} isCollapsed=${collapsed}
          onCollapseChange=${setCollapsed} style=${{ height: '100%' }}
          header=${{ logo: html`<${Ic.IconMapPin} style=${{ fontSize: 28 }} />`, text: html`<span className="brand">POI 数据工作台</span>` }}
          footer=${{ collapseButton: true }} />
      <//>
      <${Layout}>
        <${TopBar} route=${route} health=${health} follow=${follow} onReviewer=${() => setRv(true)} />
        <div className="content">
          <${ReviewPage} visible=${route === 'review'} ...${props} />
          ${page}
        </div>
      <//>
      <${ReviewerModal} visible=${rv} current=${health && health.reviewer} onClose=${() => setRv(false)} onSaved=${refreshHealth} />
    <//>`;
  }

  ReactDOM.createRoot(document.getElementById('root')).render(html`<${App} />`);
})();
