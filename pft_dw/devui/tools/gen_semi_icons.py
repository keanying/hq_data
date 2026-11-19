"""从 Semi Design 源码生成 web/semi-icons.js。

用法：git clone --depth 1 --filter=blob:none --sparse https://github.com/DouyinFE/semi-design /tmp/semi/repo
      (cd /tmp/semi/repo && git sparse-checkout set packages/semi-icons/src/svgs)
      python3 tools/gen_semi_icons.py /tmp/semi/repo/packages/semi-icons/src/svgs
"""
import json, re, sys, pathlib

# 页面用名 → Semi 图标文件名
ICONS = {
    'chevronLeft': 'chevron_left', 'chevronRight': 'chevron_right', 'chevronDown': 'chevron_down', 'chevronUp': 'chevron_up',
    'close': 'close', 'plus': 'plus', 'minus': 'minus', 'search': 'search', 'undo': 'undo', 'redo': 'redo',
    'expand': 'full_screen_stroked', 'flow': 'flow_chart_stroked', 'edit': 'edit_stroked', 'code': 'code', 'wrap': 'indent_right',
    'back': 'arrow_left', 'arrowRight': 'arrow_right', 'pin': 'pin_stroked', 'pinOff': 'pin',
    'treeDown': 'tree_triangle_down', 'treeRight': 'tree_triangle_right',
    # 运行 / 操作
    'play': 'play', 'stop': 'stop', 'external': 'external_open_stroked', 'save': 'save_stroked', 'upload': 'upload',
    'download': 'download_stroked', 'copy': 'copy_stroked', 'copyAdd': 'copy_add', 'tick': 'tick', 'tickCircle': 'tick_circle',
    'folderAdd': 'folder_stroked', 'group': 'layers', 'layout': 'grid_view', 'help': 'help_circle_stroked', 'info': 'info_circle',
    'delete': 'delete_stroked', 'setting': 'setting_stroked', 'refresh': 'refresh', 'clock': 'clock_stroked', 'calendar': 'calendar_clock_stroked',
    'more': 'more', 'link': 'link', 'unlink': 'un_chain_stroked', 'filter': 'filter_stroked',
    # 导航 / 对象
    'navDev': 'code_stroked', 'navQuery': 'search_stroked', 'navOps': 'monitor_stroked', 'tasks': 'apps',
    'table': 'grid_stroked', 'database': 'server_stroked', 'chart': 'histogram', 'history': 'history', 'kpi': 'pulse',
    'folder': 'folder_stroked', 'folderOpen': 'folder_open_stroked',
    # 任务类型
    'typeSql': 'server', 'typePython': 'code', 'typeSparkJar': 'archive', 'typeFlinkJar': 'box', 'typeShell': 'terminal',
}

def main(src):
    src = pathlib.Path(src); out = {}
    for key, name in ICONS.items():
        svg = (src / f'{name}.svg').read_text()
        vb = re.search(r'viewBox="([^"]+)"', svg).group(1)
        body = re.sub(r'^.*?<svg[^>]*>|</svg>\s*$', '', svg, flags=re.S).strip()
        body = re.sub(r'fill="(?:black|#000000|#000|currentColor)"', 'fill="currentColor"', body)
        body = re.sub(r'stroke="(?:black|#000000|#000)"', 'stroke="currentColor"', body)
        out[key] = {'viewBox': vb, 'body': body}
    dst = pathlib.Path(__file__).resolve().parent.parent / 'web' / 'semi-icons.js'
    dst.write_text('// 图标取自 Semi Design 图标库 @douyinfe/semi-icons（MIT License，Copyright (c) 2021 DouyinFE，许可见 vendor/semi-icons-LICENSE）\n'
                   '// 由 tools/gen_semi_icons.py 从 packages/semi-icons/src/svgs 的原始 SVG 生成，颜色改为跟随文字颜色（currentColor）\n'
                   'export const SEMI = ' + json.dumps(out, ensure_ascii=False, indent=1) + ';\n')
    print('wrote', len(out), 'icons ->', dst)

main(sys.argv[1] if len(sys.argv) > 1 else '/tmp/semi/repo/packages/semi-icons/src/svgs')
