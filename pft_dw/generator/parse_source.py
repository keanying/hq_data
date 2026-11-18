# -*- coding: utf-8 -*-
"""解析客户数据库设计文档中的 MySQL DDL → source_ddl.json（源表字段 / 注释 / 唯一键）
用法：python3 parse_source.py <database.md>
"""
import re, json, sys, os
txt = open(sys.argv[1], encoding="utf-8").read()
out = {}
for m in re.finditer(r"CREATE TABLE (t_[a-z_0-9]+) \((.*?)\n\)\s*(?:ENGINE[^;]*?)?COMMENT\s*=\s*'(.*?)'", txt, re.S):
    name, body, tc = m.group(1), m.group(2), m.group(3)
    lines, cur = [], ""
    for ln in body.split("\n"):
        s = ln.strip()
        if not s or s.startswith("--"):
            continue
        if re.match(r"^(PRIMARY|UNIQUE|KEY|INDEX|CONSTRAINT|FULLTEXT)\b", s):
            if cur: lines.append(cur); cur = ""
            lines.append(s); continue
        if re.match(r"^[a-z_0-9]+\s+[A-Z]", s):
            if cur: lines.append(cur)
            cur = s
        else:
            cur += " " + s
    if cur: lines.append(cur)
    cols, uks = [], []
    for s in lines:
        u = re.match(r"UNIQUE KEY \w+ \(([^)]*)\)", s)
        if u:
            uks.append([x.strip() for x in u.group(1).split(",")]); continue
        if re.match(r"^(PRIMARY|KEY|INDEX|CONSTRAINT|FULLTEXT)\b", s):
            continue
        cm = re.match(r"([a-z_0-9]+)\s+([A-Z]+(?:\([0-9, ]+\))?(?: UNSIGNED)?)\s*(.*)$", s)
        if not cm:
            continue
        c = re.search(r"COMMENT\s+'(.*?)'\s*,?\s*$", cm.group(3))
        cols.append([cm.group(1), cm.group(2), c.group(1) if c else ""])
    out[name] = {"comment": tc, "cols": cols, "uks": uks}
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "source_ddl.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
empty = [(t, c[0]) for t, v in out.items() for c in v["cols"] if not c[2]]
print(len(out), "tables;", sum(len(v["cols"]) for v in out.values()), "cols; empty comments:", empty)
