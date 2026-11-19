// 工作流画布的显示层：只改变“怎么画”，不改依赖数据。
//  1. 连线两种画法：折线（ortho，走卡片之间的通道）与曲线（curve，贝塞尔）
//  2. 折线按“通道 + 轨道”分配：同一通道里不同来源的竖线各占一条轨道，互不重叠；
//     同一来源的线共用一条主干（看起来像一棵树），到了目标卡片再按来向分开落点
//  3. 连线一律从卡片的连接点画出、画入
//  4. 方向：左右（LR）或上下（TB）；带泳道的工作流按泳道网格重排，普通工作流整体转置
//  5. 依赖照实画；收起的分组把组内外的多条线收敛成一条；选中节点时相关连线按流向流动
//  6. 依赖分层：每张卡片右上角标出它在所在容器（分组内或全局）里的依赖层级
import {groupBounds, hiddenGroup, groupDepth, levelsOf} from './model.mjs';

const TRACK = 12;       // 轨道最大间距

export const viewDir = flow => (flow?.layout?.lanes ? flow.layout.dir : flow?.view?.dir) === 'TB' ? 'TB' : 'LR';
export const edgeStyle = flow => flow?.view?.edge === 'curve' ? 'curve' : 'ortho';

function geometry(flow) {
  const L = flow.layout, TB = viewDir(flow) === 'TB';
  const box = b => TB ? {a: b.y, c: b.x, la: b.h, lc: b.w} : {a: b.x, c: b.y, la: b.w, lc: b.h};
  const G = new Map(flow.groups.map(g => [g.id, g]));
  const laneOfGroup = new Map(), branch = new Set([...(L.branch?.groups || []), ...(L.branch?.group ? [L.branch.group] : [])]);
  L.lanes.forEach((lane, i) => {
    Object.values(L.cells[lane] || {}).forEach(gid => laneOfGroup.set(gid, i + 1));
    if (L.laneGroups?.[lane]) laneOfGroup.set(L.laneGroups[lane], i + 1);
  });
  const groupOfTask = new Map(), depth = new Map(flow.groups.map(g => [g.id, groupDepth(flow, g)]));
  flow.groups.forEach(g => g.ids.forEach(id => { const cur = groupOfTask.get(id); if (!cur || depth.get(g.id) > depth.get(cur)) groupOfTask.set(id, g.id); }));
  const up = gid => { const seen = new Set(); for (let g = G.get(gid); g && !seen.has(g.id); g = G.get(g.parent)) { seen.add(g.id); if (laneOfGroup.has(g.id)) return laneOfGroup.get(g.id); if (branch.has(g.id)) return 'B'; } return null; };
  const nodeBox = id => { const n = flow.nodes.find(n => n.taskId === id); return n ? box({x: n.x, y: n.y, w: 192, h: 96}) : null; };
  // 车道沿流向的起止：0=开始节点，1..N=泳道，N+1=结束节点。
  // 优先用排布时记录的几何（layout.geo）：拖动单张卡片不会挪动通道，其他连线保持不变
  const ext = [];
  const geo = L.geo && L.geo.dir === (TB ? 'TB' : 'LR') && L.geo.lanes?.length === L.lanes.length ? L.geo : null;
  if (geo) {
    if (L.start) ext[0] = geo.start;
    geo.lanes.forEach((r, i) => { if (r[1] > r[0]) ext[i + 1] = r; });
    if (L.end) ext[L.lanes.length + 1] = geo.end;
  } else {
    const addExt = (i, b) => { if (!b) return; const e = ext[i] || [Infinity, -Infinity]; ext[i] = [Math.min(e[0], b.a), Math.max(e[1], b.a + b.la)]; };
    addExt(0, L.start && nodeBox(L.start));
    laneOfGroup.forEach((i, gid) => {
      const g = G.get(gid); if (!g || hiddenGroup(flow, g)) return;
      const lg = L.laneGroups?.[L.lanes[i - 1]];
      if (lg && lg !== gid) return;            // 有泳道外框时以外框为准
      const b = groupBounds(flow, g); if (b) addExt(i, box(b));
    });
    addExt(L.lanes.length + 1, L.end && nodeBox(L.end));
  }
  const idx = ext.map((e, i) => e ? i : null).filter(i => i !== null);
  const gutter = i => {   // 车道 i 与其后第一条非空车道之间的通道
    const j = idx.find(k => k > i), e = ext[i];
    if (!e) return null;
    if (j === undefined) return {center: e[1] + 60, width: 100};
    return {center: (e[1] + ext[j][0]) / 2, width: ext[j][0] - e[1] - 24};
  };
  const before = i => { const j = [...idx].reverse().find(k => k < i); return j === undefined ? {center: ext[i][0] - 60, width: 100} : gutter(j); };
  let gridStart = geo ? geo.c0 : Infinity;
  if (!geo) flow.groups.forEach(g => {
    if (hiddenGroup(flow, g)) return;
    const where = up(g.id); if (where === null || where === 'B') return;
    const b = groupBounds(flow, g); if (b) gridStart = Math.min(gridStart, box(b).c);
  });
  const rowGap = L.rowGap ?? 40, wrapped = !!L.laneGroups;
  const laneOf = item => {
    if (item.ids.length === 1 && item.ids[0] === L.start) return 0;
    if (item.ids.length === 1 && item.ids[0] === L.end) return L.lanes.length + 1;
    return up(item.groupId || groupOfTask.get(item.ids[0]));
  };
  // 卡片仍在所属泳道范围内（被拖出泳道的卡片，连线改为按实际位置走）
  const inLane = (item, i) => {
    if (typeof i !== 'number' || !geo) return true;
    const b = box(item), r = ext[i];
    return !!r && b.a >= r[0] - 40 && b.a + b.la <= r[1] + 40;
  };
  // 目标所在行上方的横向通道；第一行放到泳道外框之外，避开外框标题
  const rowChannel = item => {
    const gid = item.groupId || groupOfTask.get(item.ids[0]); const g = G.get(gid); const b = g && groupBounds(flow, g);
    const top = b ? box(b).c : box(item).c;
    if (top <= gridStart + 50) return {center: gridStart - (wrapped ? 34 : 22), width: 28};
    return {center: top - rowGap / 2, width: rowGap - 12};
  };
  return {TB, box, laneOf, inLane, gutter, before, rowChannel, groupOfTask, endLane: L.lanes.length + 1};
}

function roundPath(pts, r = 10) {
  const p = pts.filter((q, i) => i === 0 || Math.abs(q[0] - pts[i - 1][0]) > .5 || Math.abs(q[1] - pts[i - 1][1]) > .5);
  if (p.length < 2) return '';
  let d = `M${p[0][0]},${p[0][1]}`;
  for (let i = 1; i < p.length - 1; i++) {
    const [x0, y0] = p[i - 1], [x1, y1] = p[i], [x2, y2] = p[i + 1];
    const l1 = Math.hypot(x1 - x0, y1 - y0), l2 = Math.hypot(x2 - x1, y2 - y1), k = Math.min(r, l1 / 2, l2 / 2);
    const ax = x1 - (x1 - x0) / l1 * k, ay = y1 - (y1 - y0) / l1 * k, bx = x1 + (x2 - x1) / l2 * k, by = y1 + (y2 - y1) / l2 * k;
    d += ` L${ax},${ay} Q${x1},${y1} ${bx},${by}`;
  }
  const last = p.at(-1);
  return d + ` L${last[0]},${last[1]}`;
}

export function portPoint(flow, item, side) {
  if (viewDir(flow) === 'TB') return {x: item.x + item.w / 2, y: item.y + (side === 'out' ? item.h : 0)};
  return {x: item.x + (side === 'out' ? item.w : 0), y: item.y + item.h / 2};
}

// 传递冗余：去掉这条边后，起点仍能到达终点
function redundant(edges) {
  const adj = new Map();
  edges.forEach(({from, to}, i) => { if (!adj.has(from.key)) adj.set(from.key, []); adj.get(from.key).push([to.key, i]); });
  return edges.map(({from, to}, skip) => {
    const seen = new Set(), stack = (adj.get(from.key) || []).filter(([, i]) => i !== skip).map(([k]) => k);
    while (stack.length) {
      const k = stack.pop(); if (k === to.key) return true; if (seen.has(k)) continue; seen.add(k);
      (adj.get(k) || []).forEach(([n]) => stack.push(n));
    }
    return false;
  });
}

// 通道轨道分配：同一通道里 key 不同且区间重叠的线段放在不同轨道上
function tracks() {
  const pools = new Map();
  return {
    use(spec, key, lo, hi) {
      const id = Math.round(spec.center) + ':' + Math.round(spec.width);
      if (!pools.has(id)) pools.set(id, {spec, keys: new Map()});
      const k = pools.get(id).keys, cur = k.get(key);
      k.set(key, cur ? [Math.min(cur[0], lo, hi), Math.max(cur[1], lo, hi)] : [Math.min(lo, hi), Math.max(lo, hi)]);
      return () => pools.get(id).pos.get(key);
    },
    solve() {
      for (const p of pools.values()) {
        // 每个来源/目标固定一条轨道（按名称排序），拖动某张卡片不会让其他线换轨
        const list = [...p.keys.keys()].sort(), slot = new Map(list.map((k, t) => [k, t]));
        const n = list.length, gap = n > 1 ? Math.min(TRACK, Math.max(3, p.spec.width) / (n - 1)) : 0;
        p.pos = new Map([...slot].map(([k, t]) => [k, p.spec.center + (t - (n - 1) / 2) * gap]));
      }
    },
  };
}

// 按两张卡片的实际位置走线（拖动后随之变化）：
//  曲线：端口到端口的贝塞尔；目标在后方时控制点外伸，画成平滑的 S 形
//  折线：目标在前方走中线；目标在后方/并排时，从两卡之间（或外侧）绕过去
function freeCurve(sa, s, ta, e) {
  const d = ta - sa, k = d > 40 ? Math.max(40, d / 2) : Math.max(70, -d / 2 + 50, Math.abs(e - s) / 3);
  return [[sa, s], [sa + k, s], [ta - k, e], [ta, e]];
}
function freeRoute(sa, s, ta, e, F, T) {
  if (ta > sa + 24) { const m = (sa + ta) / 2; return [[sa, s], [m, s], [m, e], [ta, e]]; }
  const fEnd = F.c + F.lc, tEnd = T.c + T.lc;
  if (T.c >= fEnd + 16 || F.c >= tEnd + 16) {     // 两卡在垂直方向上分开：从两卡之间穿过
    const mid = T.c >= fEnd + 16 ? (fEnd + T.c) / 2 : (tEnd + F.c) / 2;
    return [[sa, s], [sa + 20, s], [sa + 20, mid], [ta - 20, mid], [ta - 20, e], [ta, e]];
  }
  // 两卡并排或重叠：从两张卡片的外侧整体绕过去
  const out = Math.max(sa, T.a + T.la) + 20, inn = Math.min(ta, F.a) - 20, side = Math.max(fEnd, tEnd) + 30;
  return [[sa, s], [out, s], [out, side], [inn, side], [inn, e], [ta, e]];
}

export function edgeView(flow, projected) {
  const TB = viewDir(flow) === 'TB', style = edgeStyle(flow);
  const box = b => TB ? {a: b.y, c: b.x, la: b.h, lc: b.w} : {a: b.x, c: b.y, la: b.w, lc: b.h};
  const map = (a, c) => TB ? [c, a] : [a, c];
  const lanes = !!flow?.layout?.lanes;
  // 依赖照实画：E 直接依赖 A、B 就画 A→E、B→E（不再隐藏传递依赖）；收起分组后同一对卡片之间只留一条线
  const red = projected.map(() => false);
  const g = lanes ? geometry(flow) : null;
  const plans = projected.map(({from: f, to: t}, i) => {
    const F = box(f), T = box(t), sa = F.a + F.la, ta = T.a;
    const lf = g?.laneOf(f), lt = g?.laneOf(t);
    const same = g && !f.groupId && !t.groupId && g.groupOfTask.get(f.ids[0]) && g.groupOfTask.get(f.ids[0]) === g.groupOfTask.get(t.ids[0]);
    // 只有“泳道之间、目标在前方”的线走泳道通道；分支线、组内线、被拖到后方/并排的线都按实际位置走
    // nominal：按排布应走的通道类型（用于预留轨道，保证拖动一张卡片时其他线不换轨）
    let nominal = 'free';
    if (g && !same && typeof lf === 'number' && typeof lt === 'number' && lt > lf)
      nominal = g.gutter(lf)?.center === g.before(lt)?.center ? 'adj' : 'skip';
    const kind = nominal !== 'free' && ta > sa + 24 && g.inLane(f, lf) && g.inLane(t, lt) ? nominal : 'free';
    return {i, f, t, F, T, lf, lt, kind, nominal, sa, ta, s: F.c + F.lc / 2, e: T.c + T.lc / 2};
  });
  // 开始/结束节点的线是调度控制（就绪检查、发布），不是数据流向
  const ctl = p => g && (p.lf === 0 || p.lt === g.endLane);
  const cls = p => [red[p.i] ? 'edge-redundant' : '', p.lf === 'B' ? 'edge-branch' : '', ctl(p) ? 'edge-ctl' : ''].join(' ').trim();
  const bez = pts => { const P = pts.map(([a, c]) => map(a, c)); return `M${P[0]} C${P[1]} ${P[2]} ${P[3]}`; };
  const T = tracks();
  const routes = plans.map(p => {
    const {sa, ta, s, e} = p, S = 'S:' + p.f.key, D = 'T:' + p.t.key;
    if (!red[p.i] && p.kind === 'free' && p.nominal !== 'free') {   // 预留原本的轨道
      T.use(g.gutter(p.lf), S, 0, 0);
      if (p.nominal === 'skip') { const ch = g.rowChannel(p.t); T.use(g.before(p.lt), D, 0, 0); T.use(ch, D, 0, 0); }
    }
    if (p.kind === 'free' || red[p.i] || (style === 'curve' && p.kind === 'adj'))
      return style === 'curve' ? {curve: freeCurve(sa, s, ta, e)} : {pts: () => freeRoute(sa, s, ta, e, p.F, p.T)};
    if (p.kind === 'adj') {
      const x = T.use(g.gutter(p.lf), S, s, e);
      return {pts: () => [[sa, s], [x(), s], [x(), e], [ta, e]]};
    }
    // 跨层：沿出发泳道后的通道 → 目标所在行上方的通道 → 目标泳道前的通道（曲线模式下拐角为大圆弧）
    const outG = g.gutter(p.lf), inG = g.before(p.lt), ch = g.rowChannel(p.t);
    const x1 = T.use(outG, S, s, ch.center), x2 = T.use(inG, D, ch.center, e);
    const y = T.use(ch, D, outG.center, inG.center);   // 横向通道按目标合流
    return {pts: () => [[sa, s], [x1(), s], [x1(), y()], [x2(), y()], [x2(), e], [ta, e]]};
  });
  T.solve();
  return plans.map((p, i) => {
    const r = routes[i];
    const d = r.curve ? bez(r.curve) : roundPath(r.pts().map(([a, c]) => map(a, c)), style === 'curve' ? 40 : 8);
    return {d, cls: cls(p)};
  });
}

// 普通工作流（无泳道）切换方向：以左上角为基准整体转置，沿流向与垂直方向的间距按卡片宽高比换算
export function transposeFlow(flow) {
  if (!flow.nodes.length) return;
  const x0 = Math.min(...flow.nodes.map(n => n.x)), y0 = Math.min(...flow.nodes.map(n => n.y)), k = 2;
  for (const n of flow.nodes) { const x = n.x, y = n.y; n.x = Math.round(x0 + (y - y0) * k); n.y = Math.round(y0 + (x - x0) / k); }
}

// 高亮：keys 为选中卡片（task:ID / group:ID）
export function highlight(svg, keys, root) {
  const on = keys.size > 0, near = new Set();
  svg.classList.toggle('hl-on', on);
  let ins = 0, outs = 0;
  svg.querySelectorAll('[data-edge]').forEach(el => {
    const vis = !el.classList.contains('edge-redundant');   // 冗余线始终不画，收起后两张卡片之间只留一条线
    const out = on && vis && keys.has(el.dataset.from), inn = on && vis && keys.has(el.dataset.to), hit = out || inn;
    el.classList.toggle('edge-hl', hit);
    el.classList.toggle('edge-out', out);              // 从选中节点流出（下游）
    el.classList.toggle('edge-in', inn && !out);       // 流入选中节点（上游）
    el.querySelector('.edge')?.setAttribute('marker-end', out ? 'url(#arrowOut)' : inn ? 'url(#arrowIn)' : 'url(#arrow)');
    if (out) outs++; if (inn && !out) ins++;
    if (hit) { near.add(el.dataset.from); near.add(el.dataset.to); svg.append(el); }   // 移到最上层，流动的线不被静态线压住
  });
  keys.forEach(k => near.delete(k));
  const host = root.closest('.canvas');
  let legend = host?.querySelector('.flow-legend');
  if (!legend && host) { legend = document.createElement('div'); legend.className = 'flow-legend'; host.append(legend); }
  if (legend) { legend.hidden = !on; legend.innerHTML = `<span class="lg-in">上游流入 ${ins}</span><span class="lg-out">下游流出 ${outs}</span>`; }
  root.querySelectorAll('.node[data-id]').forEach(el => el.classList.toggle('hl-near', near.has('task:' + el.dataset.id)));
  root.querySelectorAll('[data-group-box]').forEach(el => el.classList.toggle('hl-near', near.has('group:' + el.dataset.groupBox)));
}

// 依赖分层标记：卡片在所在容器（展开的分组，或整个工作流）里的层级。没有上游的为第 1 层。
// 泳道工作流的顶层（ODS/DWD/…）本身就是分层，不再标注。
export function levelBadges(flow, items) {
  const G = new Map(flow.groups.map(g => [g.id, g])), lanes = !!flow?.layout?.lanes;
  const depth = new Map(flow.groups.map(g => [g.id, groupDepth(flow, g)]));
  const inner = new Map();   // 任务 -> 最内层分组
  flow.groups.forEach(g => g.ids.forEach(id => { const c = inner.get(id); if (!c || depth.get(g.id) > depth.get(c)) inner.set(id, g.id); }));
  const containerOf = it => {
    if (it.groupId) return G.get(it.groupId)?.parent || '';
    return inner.get(it.ids[0]) || '';
  };
  const byC = new Map();
  for (const it of items) { const c = containerOf(it); if (!byC.has(c)) byC.set(c, []); byC.get(c).push(it); }
  const out = [];
  for (const [c, list] of byC) {
    if (!c && lanes) continue;
    if (list.length < 2) continue;
    const unitOf = new Map();
    list.forEach(it => it.ids.forEach(id => unitOf.set(id, it.key)));
    const edges = flow.edges.map(([a, b]) => [unitOf.get(a), unitOf.get(b)]).filter(([a, b]) => a && b);
    if (!edges.some(([a, b]) => a !== b)) continue;
    const {level} = levelsOf(list.map(it => it.key), edges);
    list.forEach(it => out.push({it, level: level.get(it.key) + 1}));
  }
  return out;
}
