// 工作流画布的显示层：只改变“怎么画”，不改依赖数据。
//  1. 带泳道布局（flow.layout）的工作流：连线走列间通道的圆角折线，跨层线走行间通道，
//     DIM 等分支走分支通道；横向（LR）与纵向（TB）两种方向
//  2. 传递冗余的连线（A→B→C 已成立时的 A→C）默认不画，选中相关节点时再显示
//  3. 选中节点或分组时，相关连线高亮、其余淡化，相邻节点描边
import {groupBounds, hiddenGroup, groupDepth} from './model.mjs';

const CH = 45;   // 分支卡片旁的走线间距

function geometry(flow) {
  const L = flow.layout, TB = L.dir === 'TB';
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
    return j === undefined ? e[1] + 60 : (e[1] + ext[j][0]) / 2;
  };
  const before = i => { const j = [...idx].reverse().find(k => k < i); return j === undefined ? ext[i][0] - 60 : gutter(j); };
  let gridEnd = -Infinity, branchTop = Infinity;
  flow.groups.forEach(g => {
    if (hiddenGroup(flow, g)) return;
    const where = up(g.id); if (where === null) return;
    const b = groupBounds(flow, g); if (!b) return; const x = box(b);
    if (where === 'B') branchTop = Math.min(branchTop, x.c); else gridEnd = Math.max(gridEnd, x.c + x.lc);
  });
  const rowGap = L.rowGap ?? 40;
  const laneOf = item => {
    if (item.ids.length === 1 && item.ids[0] === L.start) return 0;
    if (item.ids.length === 1 && item.ids[0] === L.end) return L.lanes.length + 1;
    return up(item.groupId || groupOfTask.get(item.ids[0]));
  };
  const rowTop = item => {
    const gid = item.groupId || groupOfTask.get(item.ids[0]); const g = G.get(gid); const b = g && groupBounds(flow, g);
    return b ? box(b).c : box(item).c;
  };
  return {TB, box, laneOf, gutter, before, rowTop, rowGap, groupOfTask,
          branchCh: isFinite(branchTop) ? (gridEnd + branchTop) / 2 : gridEnd + 75};
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

function bezier(f, t) {
  const x = f.x + f.w, y = f.y + f.h / 2, x2 = t.x, y2 = t.y + t.h / 2, c = Math.max(40, Math.abs(x2 - x) / 2);
  return `M${x},${y} C${x + c},${y} ${x2 - c},${y2} ${x2},${y2}`;
}

export function portPoint(flow, item, side) {
  if (flow?.layout?.dir === 'TB') return {x: item.x + item.w / 2, y: item.y + (side === 'out' ? item.h : 0)};
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

export function edgeView(flow, projected) {
  if (!flow?.layout?.lanes) return projected.map(({from, to}) => ({d: bezier(from, to), cls: ''}));
  const g = geometry(flow), red = redundant(projected);
  const map = (a, c) => g.TB ? [c, a] : [a, c];
  return projected.map(({from: f, to: t}, i) => {
    const F = g.box(f), T = g.box(t);
    const sa = F.a + F.la, sc = F.c + F.lc / 2, ta = T.a, tc = T.c + T.lc / 2;
    const lf = g.laneOf(f), lt = g.laneOf(t);
    const sameGroup = !f.groupId && !t.groupId && g.groupOfTask.get(f.ids[0]) && g.groupOfTask.get(f.ids[0]) === g.groupOfTask.get(t.ids[0]);
    let pts;
    if (sameGroup || lf === null || lt === null) {
      const k = Math.max(30, Math.abs(ta - sa) / 2);
      const P = [[sa, sc], [sa + k, sc], [ta - k, tc], [ta, tc]].map(([a, c]) => map(a, c));
      return {d: `M${P[0]} C${P[1]} ${P[2]} ${P[3]}`, cls: red[i] ? 'edge-redundant' : ''};
    }
    if (lf === 'B' || lt === 'B') {
      const out = lf === 'B' ? sa + CH : g.gutter(lf), inn = lt === 'B' ? ta - CH : g.before(lt), ch = g.branchCh;
      pts = [[sa, sc], [out, sc], [out, ch], [inn, ch], [inn, tc], [ta, tc]];
    } else if (lt === lf + 1 || (lt > lf && g.gutter(lf) === g.before(lt))) {
      const x = g.gutter(lf);
      pts = [[sa, sc], [x, sc], [x, tc], [ta, tc]];
    } else {
      const ch = g.rowTop(t) - g.rowGap / 2, x1 = g.gutter(lf), x2 = g.before(lt);
      pts = [[sa, sc], [x1, sc], [x1, ch], [x2, ch], [x2, tc], [ta, tc]];
    }
    const cls = [red[i] ? 'edge-redundant' : '', lf === 'B' ? 'edge-branch' : ''].join(' ').trim();
    return {d: roundPath(pts.map(([a, c]) => map(a, c))), cls};
  });
}

// 高亮：keys 为选中卡片（task:ID / group:ID）
export function highlight(svg, keys, root) {
  const on = keys.size > 0, near = new Set();
  svg.classList.toggle('hl-on', on);
  svg.querySelectorAll('[data-edge]').forEach(el => {
    const hit = on && (keys.has(el.dataset.from) || keys.has(el.dataset.to));
    el.classList.toggle('edge-hl', hit);
    el.querySelector('.edge')?.setAttribute('marker-end', hit ? 'url(#arrowHl)' : 'url(#arrow)');
    if (hit) { near.add(el.dataset.from); near.add(el.dataset.to); }
  });
  keys.forEach(k => near.delete(k));
  root.querySelectorAll('.node[data-id]').forEach(el => el.classList.toggle('hl-near', near.has('task:' + el.dataset.id)));
  root.querySelectorAll('[data-group-box]').forEach(el => el.classList.toggle('hl-near', near.has('group:' + el.dataset.groupBox)));
}
