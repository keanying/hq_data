// 开发页“数仓信息”标签：表 DDL、字段与血缘、质量规则、调度依赖（数据来自后端 /api/meta/task/<任务标识>）
const $ = s => document.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c]));
const cache = new Map();
let current = null, tab = 'code', filter = '';

const view = $('#codeView');
const tabs = document.createElement('div');
tabs.id = 'metaTabs'; tabs.className = 'meta-tabs hidden'; tabs.setAttribute('role', 'tablist');
const panel = document.createElement('div');
panel.id = 'metaPanel'; panel.className = 'meta-panel';
view.querySelector('.editor-meta').after(tabs);
view.querySelector('.editor-foot').before(panel);

const KW = /\b(CREATE|TABLE|TEMPORARY|VIEW|IF|NOT|EXISTS|INSERT|OVERWRITE|INTO|PARTITION|PARTITIONED|BY|SELECT|FROM|WHERE|AND|OR|LEFT|JOIN|ON|AS|GROUP|ORDER|UNION|ALL|WITH|CASE|WHEN|THEN|ELSE|END|COMMENT|STORED|ORC|TBLPROPERTIES|PRIMARY|KEY|ENFORCED|DISTRIBUTED|HASH|BUCKETS|PROPERTIES|USING|OPTIONS|NULL|IS|IN|DISTINCT|COUNT|SUM|MAX|MIN|CAST|FOR|SYSTEM_TIME|OF|METADATA|VIRTUAL|HAVING|BETWEEN|STRING|BIGINT|INT|DECIMAL|VARCHAR|TINYINT|TIMESTAMP|DATETIME|DATE)\b/g;
function highlight(sql) {
  return String(sql).split('\n').map(line => {
    const i = line.indexOf('--');
    const code = i >= 0 ? line.slice(0, i) : line, cm = i >= 0 ? line.slice(i) : '';
    const parts = code.split(/('(?:[^']|'')*')/);
    const html = parts.map((p, k) => k % 2 ? `<span class="sq-str">${esc(p)}</span>` : esc(p).replace(KW, '<span class="sq-kw">$1</span>')).join('');
    return html + (cm ? `<span class="sq-cm">${esc(cm)}</span>` : '');
  }).join('\n');
}

const chip = (t, f, extra = '') => `<button class="meta-chip ${extra}" data-open="${esc(t)}" title="打开 ${esc(t)}">${esc(t)}${f ? '<i>.' + esc(f) + '</i>' : ''}</button>`;
const levelBadge = l => `<span class="meta-level ${l === '强' ? 'strong' : 'weak'}">${l === '强' ? '强 · 阻断' : '弱 · 告警'}</span>`;

function renderTabs(m) {
  const t = m?.table, n = m?.node;
  const items = [['code', '开发代码']];
  if (t) items.push(['ddl', '表 DDL'], ['cols', `字段与血缘 <span>${m.columns.length}</span>`]);
  if (m?.rules?.length) items.push(['rules', `质量规则 <span>${m.rules.length}</span>`]);
  if (n) items.push(['sched', '调度依赖']);
  tabs.innerHTML = items.map(([id, label]) => `<button role="tab" aria-selected="${tab === id}" class="meta-tab ${tab === id ? 'active' : ''}" data-tab="${id}">${label}</button>`).join('') +
    (t ? `<span class="meta-tabs-info">${esc(t.db)}.${esc(t.name)} · ${esc(t.engine)}${t.rt ? ' · 实时' : ''}</span>` : '');
  tabs.querySelectorAll('[data-tab]').forEach(b => b.onclick = () => { tab = b.dataset.tab; render(); });
}

function renderDDL(m) {
  const t = m.table;
  return `<div class="meta-head"><div><h3>${esc(t.cn)}</h3><p>${esc(t.db)}.${esc(t.name)} · ${esc(t.layer)} · ${esc(t.domain)} · ${esc(t.engine)}</p></div>
    <button class="btn" data-copy="ddl">复制 DDL</button></div>
    ${t.grain ? `<p class="meta-note"><b>粒度</b>${esc(t.grain)}</p>` : ''}
    ${t.src ? `<p class="meta-note"><b>来源</b>${esc(t.src)}</p>` : ''}
    ${t.note ? `<p class="meta-note"><b>说明</b>${esc(t.note)}</p>` : ''}
    <pre class="meta-code">${highlight(t.ddl)}</pre>`;
}

function renderCols(m) {
  const t = m.table, q = filter.trim().toLowerCase();
  const rows = m.columns.filter(c => !q || (c.name + c.comment + c.kind + c.source).toLowerCase().includes(q));
  const ups = t.up || [], downs = t.down || [];
  const dims = (t.dims || []).filter(d => !ups.includes(d));
  return `<div class="meta-head"><div><h3>字段与血缘</h3><p>${m.columns.length} 个字段 · 点击上下游可直接打开对应任务</p></div>
      <input class="meta-filter" placeholder="筛选字段 / 口径" value="${esc(filter)}"></div>
    <div class="meta-lineage">
      <div><b>上游表</b>${ups.length ? ups.map(u => chip(u)).join('') : '<span class="meta-muted">业务库 ' + esc(t.src || '') + '</span>'}</div>
      ${dims.length ? `<div><b>关联维度</b>${dims.map(u => chip(u)).join('')}</div>` : ''}
      <div><b>下游表</b>${downs.length ? downs.map(u => chip(u)).join('') : '<span class="meta-muted">无（应用层出口）</span>'}</div>
    </div>
    <div class="meta-table-wrap"><table class="meta-table"><thead><tr><th>#</th><th>字段</th><th>类型</th><th>角色</th><th>说明</th><th>加工口径</th><th>上游字段</th><th>下游字段</th></tr></thead><tbody>
    ${rows.map(c => `<tr><td>${m.columns.indexOf(c) + 1}</td><td class="mono">${esc(c.name)}</td><td class="mono muted">${esc(c.type)}</td>
      <td><span class="meta-kind" data-kind="${esc(c.kind)}">${esc(c.kind)}</span></td><td>${esc(c.comment)}</td><td class="meta-src">${esc(c.source)}</td>
      <td>${c.refs.map(([a, b]) => chip(a, b, 'small')).join('')}</td>
      <td>${c.downs.slice(0, 3).map(([a, b]) => chip(a, b, 'small')).join('')}${c.downs.length > 3 ? `<span class="meta-muted">等 ${c.downs.length} 个</span>` : ''}</td></tr>`).join('')}
    </tbody></table></div>`;
}

function renderRules(m) {
  const strong = m.rules.filter(r => r.level === '强').length;
  return `<div class="meta-head"><div><h3>质量规则</h3><p>${m.rules.length} 条 · 强规则 ${strong} 条失败即阻断下游，弱规则 ${m.rules.length - strong} 条只告警</p></div></div>
    ${m.rules.map(r => `<article class="meta-rule"><header><span class="mono">${esc(r.id)}</span><span class="meta-kind">${esc(r.code)}</span>${levelBadge(r.level)}<b>${esc(r.name)}</b>
      <button class="text-btn" data-open="${esc(r.node.startsWith('dq.recon.') ? 'recon_' + r.node.slice(9) : r.node.startsWith('dq.') ? 'dq_' + r.node.slice(3) : r.node)}">打开质检任务 ↗</button></header>
      <p><b>期望</b>${esc(r.expect)}</p>${r.desc ? `<p class="meta-muted">${esc(r.desc)}</p>` : ''}
      <pre class="meta-code small">${highlight(r.sql)}</pre></article>`).join('')}`;
}

function renderSched(m) {
  const n = m.node, f = m.flow || {};
  const kv = (k, v) => v === undefined || v === '' || v === null ? '' : `<div><dt>${k}</dt><dd>${esc(v)}</dd></div>`;
  const list = items => items.length ? items.map(x => `<button class="meta-dep" data-open="${esc(x.task_key)}"><span class="meta-kind">${esc({task: '任务', dq: '质检', recon: '对账', ext: '外部依赖', start: '开始', end: '结束'}[x.kind] || x.kind)}</span>${esc(x.cn)}<i>${esc(x.id)}</i></button>`).join('') : '<span class="meta-muted">无</span>';
  return `<div class="meta-head"><div><h3>${esc(f.name || n.flow)}</h3><p>${esc(f.when || '')}${f.sla ? ' · SLA：' + esc(f.sla) : ''}</p></div><span class="mono meta-cron">${esc(f.cron || '')}</span></div>
    <dl class="meta-kv">${kv('调度节点', n.id)}${kv('阶段', n.stage)}${kv('引擎', n.engine)}${kv('优先级', n.priority)}${kv('失败重试', n.retries)}${kv('超时（分钟）', n.timeout_min)}${kv('Flink 作业', n.job)}${kv('执行命令', n.cmd)}${kv('说明', n.desc)}</dl>
    ${(n.cut || []).length ? `<p class="meta-note"><b>跨周期依赖</b>${esc([].concat(n.cut).join(' '))}</p>` : ''}
    <div class="meta-deps"><section><h4>上游（全部成功后触发）</h4>${list(m.upstream || [])}</section><section><h4>下游</h4>${list(m.downstream || [])}</section></div>`;
}

function render() {
  const m = current?.meta;
  renderTabs(m);
  view.classList.toggle('meta-mode', tab !== 'code' && !!m);
  if (tab === 'code' || !m) { panel.innerHTML = ''; return; }
  panel.innerHTML = tab === 'ddl' ? renderDDL(m) : tab === 'cols' ? renderCols(m) : tab === 'rules' ? renderRules(m) : renderSched(m);
  panel.querySelectorAll('[data-open]').forEach(b => b.onclick = () => window.dispatchEvent(new CustomEvent('dataflow:request-open', {detail: {table: b.dataset.open}})));
  panel.querySelector('[data-copy]')?.addEventListener('click', async e => { try { await navigator.clipboard.writeText(m.table.ddl); e.target.textContent = '已复制'; } catch { e.target.textContent = '复制失败'; } });
  const fi = panel.querySelector('.meta-filter');
  if (fi) fi.oninput = () => { filter = fi.value; const pos = fi.selectionStart; render(); const f2 = panel.querySelector('.meta-filter'); f2.focus(); f2.setSelectionRange(pos, pos); };
}

async function load(key) {
  if (cache.has(key)) return cache.get(key);
  let meta = null;
  try { const r = await fetch('/api/meta/task/' + encodeURIComponent(key)); if (r.ok) meta = await r.json(); } catch { /* 无后端 */ }
  cache.set(key, meta);
  return meta;
}

window.addEventListener('dataflow:open-task', async e => {
  const key = e.detail.table;
  current = {key, meta: null};
  tab = 'code'; filter = '';
  tabs.classList.add('hidden'); render();
  const meta = await load(key);
  if (current?.key !== key) return;
  current.meta = meta;
  tabs.classList.toggle('hidden', !meta);
  render();
});
