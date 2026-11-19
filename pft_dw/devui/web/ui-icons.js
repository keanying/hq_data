// 界面图标：统一替换页面上的文字符号（‹ › ⌄ × ＋ ⌘ ↶ ↷ ⌕ ⛶ − ✎）为线性 SVG 图标。
// 风格参照 Semi Design 图标（24×24 画布、圆角线条、继承文字颜色）；图标为本项目自绘。
// 页面各处会反复重绘，这里用 MutationObserver 持续处理新出现的符号；代码编辑器与画布内的卡片不处理。
const P = {
  chevronLeft: '<path d="M15 5l-7 7 7 7"/>',
  chevronRight: '<path d="M9 5l7 7-7 7"/>',
  chevronDown: '<path d="M5 9l7 7 7-7"/>',
  close: '<path d="M6 6l12 12M18 6L6 18"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  minus: '<path d="M5 12h14"/>',
  search: '<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5"/>',
  undo: '<path d="M9 7L4.5 11.5 9 16"/><path d="M5 11.5h9.5a5 5 0 010 10H11"/>',
  redo: '<path d="M15 7l4.5 4.5L15 16"/><path d="M19 11.5H9.5a5 5 0 000 10H13"/>',
  expand: '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>',
  flow: '<rect x="3" y="4" width="7" height="5" rx="1.5"/><rect x="14" y="15" width="7" height="5" rx="1.5"/><path d="M6.5 9v3.5a3 3 0 003 3H14"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13 7l4 4"/>',
  code: '<path d="M8.5 7L3.5 12l5 5M15.5 7l5 5-5 5"/>',
  wrap: '<path d="M4 6h16M4 12h12.5a3 3 0 010 6H12"/><path d="M14 15.5L11.5 18l2.5 2.5"/><path d="M4 18h4"/>',
  back: '<path d="M10 6l-6 6 6 6"/><path d="M4 12h16"/>',
  grid: '<rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/>',
  pin: '<path d="M9 4h6l-1 6 4 4H6l4-4z"/><path d="M12 14v6"/>',
};
export const icon = (name, cls = '') => `<svg class="ui-ic ${cls}" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${P[name]}</svg>`;

const GLYPH = {'‹': 'chevronLeft', '›': 'chevronRight', '⌄': 'chevronDown', '×': 'close', '＋': 'plus', '+': 'plus', '−': 'minus',
  '⌘': 'flow', '↶': 'undo', '↷': 'redo', '⌕': 'search', '⛶': 'expand', '✎': 'edit', '⇱': 'pin'};
const ROOTS = '.sidebar,.document-bar,.zoom,.code-tools,.dev-parameters header,.editor-toolbar,.rail,.view-bar,.cm-search';
const SKIP = '#textEditor .cm-content,#stage,#modalFields,.parameter-row,textarea,input,select,.search kbd';
// 没有符号但需要图标的按钮
const LEAD = {'#searchCode': 'search', '#wrapCode': 'wrap', '#formatCode': 'code'};

function fixText(node) {
  const el = node.parentElement;
  if (!el || el.closest(SKIP) || !el.closest(ROOTS)) return;
  const t = node.nodeValue, m = t.match(/^\s*([‹›⌄×＋+−⌘↶↷⌕⛶✎⇱])(\s*)/);
  if (!m || !GLYPH[m[1]]) return;
  if (m[1] === '+' && t.trim() !== '+') return;     // 普通文字里的加号不处理
  const span = document.createElement('span');
  span.className = 'ui-ic-wrap';
  span.innerHTML = icon(el.closest('#formatCode') ? 'code' : GLYPH[m[1]]);
  const rest = t.slice(m[0].length);
  el.insertBefore(span, node);
  if (rest) node.nodeValue = (m[2] ? ' ' : '') + rest; else node.remove();
}
function lead(root) {
  for (const [sel, name] of Object.entries(LEAD)) {
    const el = root.querySelector?.(sel) || (root.matches?.(sel) ? root : null);
    if (el && !el.querySelector('.ui-ic-wrap')) el.insertAdjacentHTML('afterbegin', `<span class="ui-ic-wrap">${icon(name)}</span>`);
  }
}
function scan(root) {
  if (root.nodeType === 3) { fixText(root); return; }
  if (root.nodeType !== 1) return;
  const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const list = [];
  for (let n = w.nextNode(); n; n = w.nextNode()) if (/[‹›⌄×＋+−⌘↶↷⌕⛶✎⇱]/.test(n.nodeValue)) list.push(n);
  list.forEach(fixText);
  lead(root);
}
let queued = new Set(), timer = 0;
const mo = new MutationObserver(ms => {
  for (const m of ms) {
    if (m.type === 'characterData') queued.add(m.target);
    else m.addedNodes.forEach(n => queued.add(n));
  }
  if (!timer) timer = requestAnimationFrame(() => { timer = 0; const q = [...queued]; queued = new Set(); q.forEach(n => n.isConnected && scan(n)); });
});
scan(document.body);
mo.observe(document.body, {subtree: true, childList: true, characterData: true});
