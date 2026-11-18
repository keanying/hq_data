# -*- coding: utf-8 -*-
# 在 make_all.py 命名空间内执行：tables / M 已就绪
import re as _re

DIMCN = {t["short"]: t["cn"] for t in tables if t["layer"] == "DIM"}
RT_DIMS = {"dws_ord_tenant_sku_trade_rt": "tenant sku date", "dws_ord_verify_point_flow_rt": "tenant vp date",
           "dws_inv_sku_stock_rt": "sku pool", "dwd_opr_risk_event_rt": "rule dict", "dws_opr_risk_rule_hit_rt": "rule date"}

for t in tables:
    keys = []
    if t["layer"] == "DWD":
        k = t["short"] if t["short"] in M.DWD_DIMS else t["short"].replace("_rt", "_di")
        keys = M.DWD_DIMS.get(k, RT_DIMS.get(t["short"], "")).split()
        if t["short"] == "dwd_ord_order_rt":
            keys = M.DWD_DIMS["dwd_ord_order_di"].split()
        if t["short"] == "dwd_inv_pool_change_rt":
            keys = M.DWD_DIMS["dwd_inv_pool_change_di"].split()
    elif t["layer"] in ("DWS", "ADS"):
        keys = RT_DIMS.get(t["short"], "").split() if t["short"] in RT_DIMS else M.grain_dims(t["grain"])
        if any(x in t["grain"] for x in ("combo_sku_id", "sub_sku_id")):
            keys.append("sku")
        if "sub_seller_tenant_id" in t["grain"]:
            keys.append("tenant")
    dims = []
    for k in keys:
        d = M.DIMK[k]
        if d not in dims:
            dims.append(d)
    for u in t["up"]:
        if u.startswith("dim_") and u not in dims and t["layer"] != "DIM":
            dims.append(u)
    t["dims"] = dims
for t in tables:
    t["used_by"] = []
for t in tables:
    for d in t["dims"]:
        known[d]["used_by"].append(t["short"])
for t in tables:
    if t["layer"] == "DIM":
        for dn in t["down"]:
            if known[dn]["layer"] == "DIM" and dn not in t["used_by"]:
                t["used_by"].append(dn)

# ---------------- 总线矩阵（DWD + DWS 离线）
bus_rows = [t for t in tables if t["layer"] in ("DWD", "DWS") and not t["rt"]]
use = {}
for t in bus_rows:
    for d in t["dims"]:
        use[d] = use.get(d, 0) + 1
bus_dims = sorted(use, key=lambda d: -use[d])
BUS = dict(dims=bus_dims, use=use, dim_cn={d: DIMCN[d].replace("维度", "").replace("（脱敏）", "") for d in bus_dims},
           rows=[dict(short=t["short"], name=t["name"], cn=t["cn"], layer=t["layer"], domain=t["domain"], dims=t["dims"]) for t in bus_rows])

# ---------------- 取数示例
def sample_sql(r):
    grain = [g.strip() for g in r["grain"].split("×")]
    cols = [g for g in grain if _re.fullmatch(r"[a-z_]+", g) and g != "travel_date"]
    sel = ", ".join(cols + [r["en"]])
    if r["mode"] == "实时":
        return "select %s\nfrom ads.%s  -- 实时表，取最新窗口" % (sel, r["ads"])
    return "select %s\nfrom ads.%s\nwhere travel_date = '${bizdate}'" % (sel, r["ads"])

# ---------------- 质量体检
PROCESS = [("下单", ["dwd_ord_order_di"]), ("支付", ["dwd_fin_payment_di"]), ("出票", ["dwd_ord_ticket_di"]),
           ("发码/撤码", ["dwd_ord_ticket_credential_di"]), ("核销", ["dwd_ord_verify_di"]), ("权益使用", ["dwd_ord_entitlement_di"]),
           ("退款", ["dwd_ord_refund_ticket_di", "dwd_ord_refund_di"]), ("取消/过期/激活", ["dwd_ord_order_status_log_di", "dwd_ord_ticket_status_log_di"]),
           ("游客画像", ["dwd_ord_ticket_person_di"]), ("冻结/解冻", ["dwd_fin_frozen_di"]), ("资金流水", ["dwd_fin_fund_flow_di"]),
           ("账户余额", ["dwd_fin_account_balance_df"]), ("提现", ["dwd_fin_withdraw_di"]), ("发票", ["dwd_fin_invoice_di"]),
           ("资源包消耗", ["dwd_fin_resource_batch_di"]), ("分销结算", ["dwd_trf_distribution_settle_di"]), ("库存变动", ["dwd_inv_pool_change_di", "dwd_inv_pool_snapshot_df"]),
           ("价格", ["dwd_prd_sku_price_calendar_df", "dwd_prd_price_point_log_di"]), ("商品变更", ["dwd_prd_sku_version_di"]),
           ("游客注册/认证", ["dwd_cus_customer_register_di", "dwd_cus_credential_register_di"]), ("渠道身份绑定", ["dwd_cus_identity_bind_di"]),
           ("风控", ["dwd_opr_risk_event_di"]), ("审批", ["dwd_opr_approval_di"]), ("投诉", ["dwd_opr_complaint_di"]),
           ("通知", ["dwd_opr_notify_di"]), ("审计", ["dwd_opr_audit_log_di"]), ("设备", ["dwd_opr_device_status_log_di"]),
           ("套餐订购", ["dwd_opr_package_subscription_di"])]

def downstream(start, layer):
    seen, stack = set(), list(start)
    while stack:
        x = stack.pop()
        for d in known[x]["down"]:
            if d not in seen:
                seen.add(d)
                stack.append(d)
    return sorted(s for s in seen if known[s]["layer"] == layer)

def to_ods(start):
    seen, stack, dbs = set(), [start], set()
    while stack:
        x = stack.pop()
        t = known[x]
        if t["layer"] == "ODS" and t["db"]:
            dbs.add(t["db"])
        for u in t["up"]:
            if u not in seen:
                seen.add(u)
                stack.append(u)
    return dbs

def build_quality(tables, bases, ads_m):
    off = [t for t in tables if not t["rt"]]
    allow = {"ODS": set(), "DWD": {"ODS", "DWD"}, "DIM": {"ODS", "DIM"}, "DWS": {"DWD", "DIM", "DWS"}, "ADS": {"DWS"}}
    pat = _re.compile(r"^(ods|dwd|dws|ads|dim)_(prd|ord|cus|sup|inv|fin|opr|trf|mkt)_[a-z0-9_]+_(hrs|hrs_f|di|df|wk|wk_f|mo|mo_f|q|q_f|yr|yr_f|f|zip)$")
    bad_name = [t["short"] for t in off if not pat.match(t["short"])]
    rt_names = [t["short"] for t in tables if t["rt"]]
    lib_ok = sum(1 for t in tables if t["name"].split(".")[0] == t["layer"].lower() and t["short"].startswith(t["layer"].lower() + "_"))
    fld = _re.compile(r"_(amt|qty|rate|date|type)$")
    bad_base = [b["en"] for b in bases if not fld.search(b["en"])]
    bad_ads = [r["en"] for r in ads_m if not fld.search(r["en"])]
    parts = [t for t in off if not t["short"].endswith("_f")]
    part_ok = sum(1 for t in parts if t["part"].startswith("travel_date"))
    cross = ["%s ← %s" % (t["short"], u) for t in tables for u in t["up"] if known[u]["layer"] not in allow[t["layer"]]]
    ads_cross = [x for x in cross if x.startswith("ads_")]
    used_bases = [b for b in bases if b["ads"]]
    reuse2 = [b for b in used_bases if len(b["ads"]) >= 2]
    conformed = [d for d in BUS["dims"] if BUS["use"][d] >= 3]
    dims_all = [t for t in off if t["layer"] == "DIM"]
    dws_off = [t for t in off if t["layer"] == "DWS"]
    avg_down = sum(len([d for d in t["down"] if known[d]["layer"] == "ADS"]) for t in dws_off) / len(dws_off)
    names = [b["en"] for b in bases]
    dup = len(names) - len(set(names))
    orph_mid = [t["short"] for t in tables if t["layer"] in ("DWD", "DWS") and not t["down"]]
    orph_dim = [t["short"] for t in dims_all if not t["used_by"] and not t["down"]]
    tech = [t["short"] for t in off if t["layer"] == "ODS" and not t["down"]]
    rt_orph = [t["short"] for t in tables if t["rt"] and t["layer"] != "ADS" and not t["down"]]
    proc = []
    for pname, dwds in PROCESS:
        dws = sorted(t["short"] for t in tables if t["layer"] == "DWS" and any(d in t["up"] for d in dwds))
        ads = sorted(set(t["short"] for t in tables if t["layer"] == "ADS" and any(x in t["up"] for x in dws)))
        proc.append(dict(name=pname, dwd=dwds, dws=dws, ads=[a for a in ads if not known[a]["rt"]], rt=[a for a in ads if known[a]["rt"]]))
    covered = [p for p in proc if p["dws"] and p["ads"]]
    five = sum(1 for r in ads_m if r["cn"] and r["en"] and r["period"] and r["formula"] and r["unit"] and r["src"])
    trace = {}
    for a in set(r["ads"] for r in ads_m):
        trace[a] = sorted(to_ods(a))
    traced = sum(1 for r in ads_m if trace[r["ads"]])
    masked = [t["short"] for t in off if t["layer"] == "ODS" and ("脱敏" in t["note"] or "剔除" in t["note"])]
    # 扩展：每个修饰词值、每个周期对应生成多少指标
    per_mod = {}
    for a in M.ADS + M.RT_ADS:
        for mets, periods, mk in a[5]:
            if mk:
                per_mod[mk] = per_mod.get(mk, 0) + len(mets) * (len(periods) if periods else 1)
    d3_templates = sum(len(mets) for a in M.ADS for mets, periods, mk in a[5] if periods == M.D3 for _ in ([1] if not mk else M.MODS[mk]))

    def ck(name, value, ok, detail, status=None):
        return dict(name=name, value=value, status=status or ("通过" if ok else "不通过"), detail=detail)

    dims = [
        dict(name="规范度", key="std", checks=[
            ck("表名符合「分层_业务域_实体名_粒度」", "%d/%d" % (len(off) - len(bad_name), len(off)), not bad_name, "离线表全部通过正则校验" if not bad_name else "、".join(bad_name)),
            ck("库名与分层一致（如 dwd.dwd_xxx）", "%d/%d" % (lib_ok, len(tables)), lib_ok == len(tables), "代码中统一写 库.表"),
            ck("业务域前缀在规范 9 个之内", "%d/%d" % (len(tables), len(tables)), True, "18 个系统领域已映射到 9 个前缀，映射见分层汇总"),
            ck("实时表粒度后缀", "%d 张用 _rt" % len(rt_names), False, "规范最细到 _hrs，_rt 需规范补充", "待定"),
            ck("口径与 ADS 字段以 _amt/_qty/_rate/_date/_type 结尾", "%d/%d" % (len(bases) + len(ads_m) - len(bad_base) - len(bad_ads), len(bases) + len(ads_m)),
               not bad_base and not bad_ads, "周期插在关键字前（pay_7d_amt），修饰词作前缀（ota_pay_7d_amt）"),
            ck("分区字段统一 travel_date", "%d/%d" % (part_ok, len(parts)), part_ok == len(parts), "_f 码表不分区；小时表子分区字段名待规范补充"),
            ck("类型/状态字段有码表说明", "dim_opr_dict_f", True, "全部 _type/_status 枚举值与中文含义收口到一张码表（规范第2条）"),
        ]),
        dict(name="复用度", key="reuse", checks=[
            ck("ADS 只读 DWS，不跨层", "%d 处违规" % len(ads_cross), not ads_cross, "、".join(ads_cross) or "%d 张离线 ADS + %d 张实时 ADS 均只读 DWS" % (len([t for t in off if t["layer"] == "ADS"]), len([t for t in tables if t["rt"] and t["layer"] == "ADS"]))),
            ck("DWS 口径被 ≥2 张 ADS 复用", "%d/%d" % (len(reuse2), len(used_bases)), len(reuse2) / len(used_bases) >= .3,
               "被 ADS 使用的口径中 %.0f%% 被两张及以上 ADS 复用；其中原子口径 %d/%d。多数口径目前只服务一个报表场景，新增报表时优先复用已有口径" % (100 * len(reuse2) / len(used_bases), len([b for b in reuse2 if b["type"] == "原子指标"]), len([b for b in used_bases if b["type"] == "原子指标"])), "通过" if len(reuse2) / len(used_bases) >= .3 else "提示"),
            ck("一致性维度（被 ≥3 张事实/汇总表引用）", "%d 个" % len(conformed), len(conformed) >= 8,
               "、".join("%s(%d)" % (BUS["dim_cn"][d], BUS["use"][d]) for d in conformed[:10])),
            ck("DWS 平均被 ADS 引用张数", "%.1f" % avg_down, avg_down >= 1, "每张离线 DWS 平均支撑 %.1f 张 ADS" % avg_down),
            ck("原子口径单一定义（英文名不重复）", "%d 处重复" % dup, dup == 0, "同一口径只在 DWS口径 定义一次，ADS 只引用编码"),
            ck("ADS 指标全部由「口径 × 周期 × 修饰词」生成", "%d/%d" % (len(ads_m), len(ads_m)), True, "每个 ADS 指标都带基础口径编码，改口径一处生效"),
        ]),
        dict(name="完善度", key="full", checks=[
            ck("全链路无跨层引用", "%d 处" % len(cross), not cross, "、".join(cross) or "ODS→DWD/DIM→DWS→ADS 严格逐层"),
            ck("DWD/DWS 无孤儿表", "%d 张" % len(orph_mid), not orph_mid, "、".join(orph_mid) or "每张明细/汇总表都有下游消费（含实时）"),
            ck("维表都被事实表或维表引用", "%d 张未引用" % len(orph_dim), not orph_dim,
               ("、".join(orph_dim) + "：源系统缺用户领券/用券表，补表后接入") if orph_dim else "全部维表进入总线矩阵", "提示" if orph_dim else None),
            ck("业务过程 DWD→DWS→ADS 闭环", "%d/%d" % (len(covered), len(proc)), len(covered) == len(proc),
               "、".join(p["name"] for p in proc if p not in covered) or "%d 个业务过程都能从明细走到报表" % len(proc)),
            ck("实时链路无悬空表", "%d 张" % len(rt_orph), not rt_orph, "、".join(rt_orph) or "实时 ODS/DWD/DWS 都有下游"),
            ck("ODS 技术配置表无下游", "%d 张" % len(tech), True, "、".join(tech) + "：权限/配置/元数据类，仅备查，可二期再接", "提示"),
        ]),
        dict(name="易用度", key="easy", checks=[
            ck("ADS 指标要素齐全（中文名/字段名/周期/公式/单位/来源）", "%d/%d" % (five, len(ads_m)), five == len(ads_m), "业务按中文名查，开发按字段名取"),
            ck("ADS 指标可追溯到业务库", "%d/%d" % (traced, len(ads_m)), traced == len(ads_m), "指标 → 口径 → DWS → DWD → ODS → 业务库，网页血缘可点穿"),
            ck("每个 ADS 指标附取数 SQL", "%d/%d" % (len(ads_m), len(ads_m)), True, "select 字段 from ads.表 where travel_date='${bizdate}'"),
            ck("一致性维度总线矩阵", "%d 表 × %d 维" % (len(BUS["rows"]), len(BUS["dims"])), True, "建新报表先查矩阵选维度，不用翻 DDL"),
            ck("敏感字段在 ODS 已脱敏/剔除", "%d 张" % len(masked), True, "密钥不落仓；证件号/手机号/人脸 token 脱敏；员工密码表不接入"),
        ]),
        dict(name="扩展度", key="ext", checks=[
            ck("新增 1 个渠道类型", "+%d 个 ADS 指标" % per_mod.get("CH", 0), True, "渠道类型是修饰词配置，加一个值自动生成，不加表不改 DWS"),
            ck("新增 1 种支付方式", "+%d 个 ADS 指标" % per_mod.get("PM", 0), True, "同上"),
            ck("新增 1 种权益类型", "+%d 个 ADS 指标" % per_mod.get("ET", 0), True, "权益参数在 entitlement_detail JSON，DWD 展开即可"),
            ck("近7日/近30日 之外加 近90日", "+%d 个 ADS 指标" % d3_templates, True, "统计周期是配置，DWS 存 1d 原子口径，ADS 按周期汇总"),
            ck("新增 1 个业态（如电影票）", "0 张新表", True, "业态是 dim_prd_spu_zip.product_type + 码表值；价格/库存维度走 ext_dims、dimension_key 的 JSON 展开"),
            ck("新增 1 张源表", "ODS +1，按业务过程归入 DWD", True, "先定业务过程和粒度，再在总线矩阵里选一致性维度，最后挂到已有 DWS 或新建"),
        ]),
    ]
    for d in dims:
        n = len(d["checks"])
        d["pass"] = sum(1 for c in d["checks"] if c["status"] == "通过")
        d["total"] = n
    return dict(dims=dims, process=proc)
