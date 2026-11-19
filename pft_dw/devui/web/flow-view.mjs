// 工作流画布的显示层：只改变“怎么画”，不改依赖数据。
//  1. 连线两种画法：折线（ortho，走卡片之间的通道）与曲线（curve，贝塞尔）
//  2. 折线按“通道 + 轨道”分配：同一通道里不同来源的竖线各占一条轨道，互不重叠；
//     同一来源的线共用一条主干（看起来像一棵树），到了目标卡片再按来向分开落点
//  3. 每张卡片的入口按来向上下（纵向布局为左右）错开，几条线不会挤在同一个点上
//  4. 方向：左右（LR）或上下（TB）；带泳道的工作流按泳道网格重排，普通工作流整体转置
//  5. 传递冗余的连线（A→B→C 已成立时的 A→C）不画；选中节点时相关连线按流向流动
import {groupBounds, hiddenGroup, groupDepth} from './model.mjs';

const CH = 45;          // 分支卡片旁的走线间距
const TRACK = 12;       // 轨道最大间距
const SIDE = 0.18;      // 卡片边缘留白比例（入口错开时不贴边）

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
  // 车道沿流向的起止：0=开始节点，1..N=泳道，N+1=结束节点
  const ext = [];
  const addExt = (i, b) => { if (!b) return; const e = ext[i] || [Infinity, -Infinity]; ext[i] = [Math.min(e[0], b.a), Math.max(e[1], b.a + b.la)]; };
  addExt(0, L.start && nodeBox(L.start));
  laneOfGroup.forEach((i, gid) => {
    const g = G.get(gid); if (!g || hiddenGroup(flow, g)) return;
    const lg = L.laneGroups?.[L.lanes[i - 1]];
    if (lg && lg !== gid) return;            // 有泳道外框时以外框为准
    const b = groupBounds(flow, g); if (b) addExt(i, box(b));
  });
  addExt(L.lanes.length + 1, L.end && nodeBox(L.end));
  const idx = ext.map((e, i) => e ? i : null).filter(i => i !== null);
  const gutter = i => {   // 车道 i 与其后第一条非空车道之间的通道
    const j = idx.find(k => k > i), e = ext[i];
    if (!e) return null;
    if (j === undefined) return {center: e[1] + 60, width: 100};
    return {center: (e[1] + ext[j][0]) / 2, width: ext[j][0] - e[1] - 24};
  };
  const before = i => { const j = [...idx].reverse().find(k => k < i); return j === undefined ? {center: ext[i][0] - 60, width: 100} : gutter(j); };
  let gridStart = Infinity, gridEnd = -Infinity, branchTop = Infinity;
  flow.groups.forEach(g => {
    if (hiddenGroup(flow, g)) return;
    const where = up(g.id); if (where === null) return;
    const b = groupBounds(flow, g); if (!b) return; const x = box(b);
    if (where === 'B') branchTop = Math.min(branchTop, x.c);
    else { gridEnd = Math.max(gridEnd, x.c + x.lc); gridStart = Math.min(gridStart, x.c); }
  });
  const rowGap = L.rowGap ?? 40, wrapped = !!L.laneGroups;
  const laneOf = item => {
    if (item.ids.length === 1 && item.ids[0] === L.start) return 0;
    if (item.ids.length === 1 && item.ids[0] === L.end) return L.lanes.length + 1;
    return up(item.groupId || groupOfTask.get(item.ids[0]));
  };
  // 目标所在行上方的横向通道；第一行放到泳道外框之外，避开外框标题
  const rowChannel = item => {
    const gid = item.groupId || groupOfTask.get(item.ids[0]); const g = G.get(gid); const b = g && groupBounds(flow, g);
    const top = b ? box(b).c : box(item).c;
    if (top <= gridStart + 50) return {center: gridStart - (wrapped ? 34 : 22), width: 28};
    return {center: top - rowGap / 2, width: rowGap - 12};
  };
  const bch = isFinite(branchTop) ? {center: (gridEnd + branchTop) / 2 - 10, width: Math.max(30, Math.min(110, branchTop - gridEnd - 70))}
                                  : {center: gridEnd + 75, width: 60};
  return {TB, box, laneOf, gutter, before, rowChannel, groupOfTask, bch, endLane: L.lanes.length + 1};
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
        const list = [...p.keys].sort((a, b) => a[1][0] - b[1][0] || a[1][1] - b[1][1]);
        const ends = [], slot = new Map();
        for (const [key, [lo, hi]] of list) {
          let t = ends.findIndex(e => e < lo - 14);
          if (t < 0) { t = ends.length; ends.push(hi); } else ends[t] = hi;
          slot.set(key, t);
        }
        const n = ends.length, gap = n > 1 ? Math.min(TRACK, Math.max(3, p.spec.width) / (n - 1)) : 0;
        p.pos = new Map([...slot].map(([k, t]) => [k, p.spec.center + (t - (n - 1) / 2) * gap]));
      }
    },
  };
}

// 每张卡片的一侧按来向（或去向）排序后均匀错开落点
function spread(groups, box) {
  const at = new Map();
  for (const [, list] of groups) {
    list.sort((p, q) => p.order - q.order);
    const b = box(list[0].item), k = list.length;
    list.forEach((e, j) => at.set(e.i, k === 1 ? b.c + b.lc / 2 : b.c + b.lc * (SIDE + (1 - 2 * SIDE) * (j + .5) / k)));
  }
  return at;
}

export function edgeView(flow, projected) {
  const TB = viewDir(flow) === 'TB', style = edgeStyle(flow);
  const box = b => TB ? {a: b.y, c: b.x, la: b.h, lc: b.w} : {a: b.x, c: b.y, la: b.w, lc: b.h};
  const map = (a, c) => TB ? [c, a] : [a, c];
  const lanes = !!flow?.layout?.lanes;
  const red = lanes ? redundant(projected) : projected.map(() => false);
  const g = lanes ? geometry(flow) : null;
  const plans = projected.map(({from: f, to: t}, i) => {
    const F = box(f), T = box(t);
    const lf = g?.laneOf(f), lt = g?.laneOf(t);
    const same = g && !f.groupId && !t.groupId && g.groupOfTask.get(f.ids[0]) && g.groupOfTask.get(f.ids[0]) === g.groupOfTask.get(t.ids[0]);
    let kind = 'simple';
    if (g && !same && lf !== null && lt !== null && lf !== undefined && lt !== undefined) {
      if (lf === 'B' || lt === 'B') kind = 'branch';
      else if (lt > lf && g.gutter(lf)?.center === g.before(lt)?.center) kind = 'adj';
      else kind = 'skip';
    }
    const approachIn = kind === 'adj' || kind === 'simple' ? F.c + F.lc / 2 : kind === 'skip' ? -1e9 : (lt === 'B' ? -1e9 : 1e9);
    const approachOut = kind === 'adj' || kind === 'simple' ? T.c + T.lc / 2 : kind === 'skip' ? -1e9 : (lf === 'B' ? -1e9 : 1e9);
    return {i, f, t, F, T, lf, lt, kind, approachIn, approachOut};
  });
  // 落点错开：入口始终错开；出口在曲线模式下错开，折线模式共用主干从中点出发
  const ins = new Map(), outs = new Map();
  plans.forEach(p => {
    if (!red[p.i]) {
      (ins.get(p.t.key) || ins.set(p.t.key, []).get(p.t.key)).push({i: p.i, item: p.t, order: p.approachIn});
      (outs.get(p.f.key) || outs.set(p.f.key, []).get(p.f.key)).push({i: p.i, item: p.f, order: p.approachOut});
    }
  });
  const inAt = spread(ins, box), outAt = style === 'curve' ? spread(outs, box) : new Map();
  const tc = p => inAt.get(p.i) ?? p.T.c + p.T.lc / 2, sc = p => outAt.get(p.i) ?? p.F.c + p.F.lc / 2;
  // 开始/结束节点的线是调度控制（就绪检查、发布），不是数据流向，画得更淡
  const ctl = p => g && (p.lf === 0 || p.lt === g.endLane);
  const cls = p => [red[p.i] ? 'edge-redundant' : '', p.lf === 'B' ? 'edge-branch' : '', ctl(p) ? 'edge-ctl' : ''].join(' ').trim();
  const bez = pts => { const P = pts.map(([a, c]) => map(a, c)); return `M${P[0]} C${P[1]} ${P[2]} ${P[3]}`; };

  if (!g) {
    return plans.map(p => {
      const sa = p.F.a + p.F.la, ta = p.T.a, s = sc(p), e = tc(p);
      let d;
      if (style === 'curve') {
        const k = Math.max(40, Math.abs(ta - sa) / 2);
        d = bez([[sa, s], [sa + k, s], [ta - k, e], [ta, e]]);
      } else if (ta > sa + 24) {
        const m = (sa + ta) / 2;
        d = roundPath([[sa, s], [m, s], [m, e], [ta, e]].map(([a, c]) => map(a, c)));
      } else {   // 目标在后方：绕到两张卡片之外
        const out = Math.max(p.F.c + p.F.lc, p.T.c + p.T.lc) + 30;
        d = roundPath([[sa, s], [sa + 20, s], [sa + 20, out], [ta - 20, out], [ta - 20, e], [ta, e]].map(([a, c]) => map(a, c)));
      }
      return {d, cls: cls(p)};
    });
  }

  // 折线：登记通道线段 -> 分配轨道 -> 生成路径
  const T = tracks();
  const routes = plans.map(p => {
    const sa = p.F.a + p.F.la, ta = p.T.a, s = sc(p), e = tc(p), S = 'S:' + p.f.key, D = 'T:' + p.t.key;
    if (p.kind === 'simple') {
      const k = Math.max(30, Math.abs(ta - sa) / 2);
      return {curve: [[sa, s], [sa + k, s], [ta - k, e], [ta, e]]};
    }
    if (red[p.i]) {   // 冗余线只在高亮时显示，不占轨道
      const x = g.gutter(p.lf)?.center ?? sa + 30, y = (p.kind === 'branch' ? g.bch : g.rowChannel(p.t)).center;
      const x2 = (p.lt === 'B' ? ta - CH : g.before(p.lt)?.center) ?? ta - 30;
      return {pts: () => p.kind === 'adj' ? [[sa, s], [x, s], [x, e], [ta, e]] : [[sa, s], [x, s], [x, y], [x2, y], [x2, e], [ta, e]]};
    }
    if (p.kind === 'adj' && style === 'curve') {
      const k = Math.max(40, Math.abs(ta - sa) / 2);
      return {curve: [[sa, s], [sa + k, s], [ta - k, e], [ta, e]]};
    }
    if (p.kind === 'adj') {
      const x = T.use(g.gutter(p.lf), S, s, e);
      return {pts: () => [[sa, s], [x(), s], [x(), e], [ta, e]]};
    }
    const outG = p.lf === 'B' ? {center: sa + CH, width: 70} : g.gutter(p.lf);
    const inG = p.lt === 'B' ? {center: ta - CH, width: 70} : g.before(p.lt);
    const ch = p.kind === 'branch' ? g.bch : g.rowChannel(p.t);
    const x1 = T.use(outG, S, s, ch.center), x2 = T.use(inG, D, ch.center, e);
    const y = T.use(ch, D, outG.center, inG.center);   // 横向通道按目标合流：同一目标的线汇成一条总线
    return {pts: () => [[sa, s], [x1(), s], [x1(), y()], [x2(), y()], [x2(), e], [ta, e]]};
  });
  T.solve();
  return plans.map((p, i) => {
    const r = routes[i];
    // 曲线模式下跨层/分支的线仍沿通道绕开中间的卡片，只是拐角改成大圆弧
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
    if (hit) { near.add(el.dataset.from); near.add(el.dataset.to); }
  });
  keys.forEach(k => near.delete(k));
  const host = root.closest('.canvas');
  let legend = host?.querySelector('.flow-legend');
  if (!legend && host) { legend = document.createElement('div'); legend.className = 'flow-legend'; host.append(legend); }
  if (legend) { legend.hidden = !on; legend.innerHTML = `<span class="lg-in">上游流入 ${ins}</span><span class="lg-out">下游流出 ${outs}</span>`; }
  root.querySelectorAll('.node[data-id]').forEach(el => el.classList.toggle('hl-near', near.has('task:' + el.dataset.id)));
  root.querySelectorAll('[data-group-box]').forEach(el => el.classList.toggle('hl-near', near.has('group:' + el.dataset.groupBox)));
}
