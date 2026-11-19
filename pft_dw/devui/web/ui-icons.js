// 界面图标：统一替换页面上的文字符号（‹ › ⌄ × ＋ ⌘ ↶ ↷ ⌕ ⛶ − ✎）为线性 SVG 图标。
// 图标为 Semi Design 官方图标（@douyinfe/semi-icons，MIT），见 semi-icons.js。
// 页面各处会反复重绘，这里用 MutationObserver 持续处理新出现的符号；代码编辑器与画布内的卡片不处理。
import {SEMI} from './semi-icons.js';
export const icon = (name, cls = '') => {
  const i = SEMI[name];
  return i ? `<svg class="ui-ic ${cls}" viewBox="${i.viewBox}" aria-hidden="true" fill="none">${i.body}</svg>` : '';
};

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
  let name = el.closest('#formatCode') ? 'code' : GLYPH[m[1]];
  if (el.closest('.folder-toggle')) name = m[1] === '⌄' ? 'treeDown' : 'treeRight';   // 目录树用 Semi Tree 的三角
  span.innerHTML = icon(name);
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
