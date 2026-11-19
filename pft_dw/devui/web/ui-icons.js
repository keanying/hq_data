// 界面图标：页面上所有图标统一使用 Semi Design 官方图标（@douyinfe/semi-icons，MIT），见 semi-icons.js。
// - 文字符号按钮（‹ › ⌄ × ＋ ⌘ ↶ ↷ ⌕ ⛶ ✎ ▷ ■ ↗ → …）替换为 SVG
// - icons/*.png 位图图标替换为 SVG
// 页面各处会反复重绘，这里用 MutationObserver 持续处理新出现的符号与图片。
// 画布卡片（#nodes/#groups）数量大，直接在 app.js 模板里输出图标，不走这里。
import {SEMI} from './semi-icons.js';
export const icon = (name, cls = '') => {
  const i = SEMI[name];
  return i ? `<svg class="ui-ic ${cls}" viewBox="${i.viewBox}" aria-hidden="true" fill="none">${i.body}</svg>` : '';
};
window.semiIcon = icon;

// 文字开头的符号
const LEADING = {'‹': 'chevronLeft', '›': 'chevronRight', '⌄': 'chevronDown', '×': 'close', '＋': 'plus', '+': 'plus', '−': 'minus',
  '⌘': 'flow', '↶': 'undo', '↷': 'redo', '⌕': 'search', '⛶': 'expand', '✎': 'edit', '⇱': 'pin', '▷': 'play', '■': 'stop',
  '⌑': 'copyAdd', '▱': 'group', '▥': 'layout', '⇩': 'save', '⇧': 'upload', '◈': 'kpi', '▤': 'table', '▦': 'chart', '✓': 'tick', '⧉': 'copy', '◉': 'database'};
// 文字结尾的符号（如“进入项目 →”“编写代码 ↗”“收起结果 ∨”）
const TRAILING = {'↗': 'external', '→': 'arrowRight', '∨': 'chevronDown', '∧': 'chevronUp'};
// 位图图标
const IMAGES = {'development.png': 'navDev', 'query.png': 'navQuery', 'data-operations.png': 'navOps', 'task.png': 'tasks', 'help.png': 'help', 'export.png': 'download'};
const SKIP = '#textEditor .cm-content,.cm-editor .cm-line,#nodes,#groups,#edges,textarea,input,select,option,script,style,.search kbd,pre,code';
// 没有符号但需要图标的按钮
const LEAD = {'#searchCode': 'search', '#wrapCode': 'wrap', '#formatCode': 'code'};
const LEAD_RE = new RegExp('^\\s*([' + Object.keys(LEADING).join('').replace(/[-\]\\^]/g, '\\$&') + '])(\\s*)');
const TRAIL_RE = new RegExp('(\\s*)([' + Object.keys(TRAILING).join('') + '])\\s*$');
const ANY_RE = new RegExp('[' + (Object.keys(LEADING).join('') + Object.keys(TRAILING).join('')).replace(/[-\]\\^]/g, '\\$&') + ']');

function wrap(name) {
  const span = document.createElement('span');
  span.className = 'ui-ic-wrap';
  span.innerHTML = icon(name);
  return span;
}
function leadingName(ch, el, text) {
  if (el.closest('#formatCode')) return 'code';
  if (el.closest('.folder-toggle')) return ch === '⌄' ? 'treeDown' : 'treeRight';     // 目录树用 Semi Tree 的三角
  if (ch === '▱' && /文件夹/.test(text)) return 'folderAdd';
  return LEADING[ch];
}
function fixText(node) {
  const el = node.parentElement;
  if (!el || el.closest(SKIP)) return;
  let t = node.nodeValue;
  const m = t.match(LEAD_RE);
  if (m && !(m[1] === '+' && t.trim() !== '+')) {           // 普通文字里的加号不处理
    el.insertBefore(wrap(leadingName(m[1], el, t)), node);
    t = t.slice(m[0].length);
    if (m[2] && t) t = ' ' + t;
  }
  const n = t.match(TRAIL_RE);
  if (n && t.trim().length > 1) {                           // 只处理“文字 + 符号”，单独的箭头（如 左→右）不处理
    t = t.slice(0, n.index) + ' ';
    const tw = wrap(TRAILING[n[2]]); tw.classList.add('ui-ic-trail'); el.insertBefore(tw, node.nextSibling);
  }
  if (t !== node.nodeValue) { if (t.trim()) node.nodeValue = t; else node.remove(); }
}
function fixImg(img) {
  const file = (img.getAttribute('src') || '').split('/').pop();
  if (!IMAGES[file] || img.closest(SKIP)) return;
  const span = wrap(IMAGES[file]);
  span.className = 'ui-ic-wrap ui-ic-img ' + img.className;
  img.replaceWith(span);
}
function lead(root) {
  for (const [sel, name] of Object.entries(LEAD)) {
    const el = root.querySelector?.(sel) || (root.matches?.(sel) ? root : null);
    if (el && !el.querySelector('.ui-ic-wrap')) el.insertAdjacentHTML('afterbegin', `<span class="ui-ic-wrap">${icon(name)}</span>`);
  }
}
function scan(root) {
  if (root.nodeType === 3) { if (ANY_RE.test(root.nodeValue)) fixText(root); return; }
  if (root.nodeType !== 1 || root.closest?.(SKIP)) return;
  const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const list = [];
  for (let n = w.nextNode(); n; n = w.nextNode()) if (ANY_RE.test(n.nodeValue)) list.push(n);
  list.forEach(fixText);
  (root.tagName === 'IMG' ? [root] : root.querySelectorAll('img[src*="icons/"]')).forEach(fixImg);
  lead(root);
}
let queued = new Set(), timer = 0;
const flush = () => { timer = 0; const q = [...queued]; queued = new Set(); q.forEach(n => n.isConnected && scan(n)); };
const mo = new MutationObserver(ms => {
  for (const m of ms) {
    if (m.type === 'characterData') queued.add(m.target);
    else m.addedNodes.forEach(n => queued.add(n));
  }
  if (!timer) timer = requestAnimationFrame(flush);
});
scan(document.body);
mo.observe(document.body, {subtree: true, childList: true, characterData: true});
