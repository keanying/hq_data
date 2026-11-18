# -*- coding: utf-8 -*-
"""全表字段 + DDL 生成
每个字段：{n:字段名, t:类型, c:注释, k:字段类别, s:加工说明, r:[[上游表, 上游字段], ...]}
字段类别：主键 / 外键 / 业务主键 / 退化维度 / 维度属性 / 状态类型 / 时间 / 度量 / 指标 / 粒度键 / 拉链 / ETL
"""
import os, re, json
from enums import ENUM_CN

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = json.load(open(os.path.join(HERE, "source_ddl.json"), encoding="utf-8"))
ECN = {k: v.replace("/", "或") for k, v in ENUM_CN.items() if k != v}

# ============================================================ 注释增强：枚举值补中文含义
CODE = re.compile(r"(?<![A-Za-z0-9_])([A-Z][A-Z0-9_]+)(?![A-Za-z0-9_(（\-])")
PAREN = re.compile(r"(?<![A-Za-z0-9_])([A-Z][A-Z0-9_]{2,})[(（]([^()（）]*)[)）]")
def enrich(comment):
    comment = PAREN.sub(lambda m: "%s-%s" % (m.group(1), m.group(2).replace(",", "，")), comment)
    out = CODE.sub(lambda m: "%s-%s" % (m.group(1), ECN[m.group(1)]) if m.group(1) in ECN else m.group(1), comment)
    if len(re.findall(r"\b[A-Z][A-Z0-9_]+\b", out)) >= 2:  # 枚举清单：分隔符统一为中文逗号
        out = re.sub(r"(?<=[\u4e00-\u9fa5A-Za-z0-9）)])/(?=[A-Z])", "，", out)
    return out.replace("'", "’")

def htype(mysql):
    t = mysql.upper()
    if t.startswith(("VARCHAR", "TEXT", "JSON", "CHAR", "DATETIME", "TIMESTAMP", "DATE")):
        return "STRING"
    if t.startswith("DECIMAL"):
        return t.replace(" ", "")
    if t.startswith("TINYINT"):
        return "INT"
    return t.split("(")[0].split(" ")[0]

def is_amount(col, comment):
    if col in ("coupon_value",) or "分库" in comment and not re.search(r"[（(]分[，,）)/]|分[，,）)]", comment.replace("分库", "")):
        return False
    return bool(re.search(r"[（(]分|分[，,）)/]", comment.replace("分库", "")))

# ============================================================ 规范化改名（源字段 → 数仓字段）
REN = {
    "total_amount": "total_amt", "refund_amount": "refund_amt", "withdraw_amount": "withdraw_amt", "invoice_amount": "invoice_amt",
    "settle_amount": "settle_amt", "unit_price": "unit_price_amt", "cost_price": "cost_price_amt", "price": "price_amt",
    "package_price": "package_price_amt", "available_balance": "available_balance_amt", "frozen_balance": "frozen_balance_amt",
    "balance_before": "balance_before_amt", "balance_after": "balance_after_amt", "credit_limit": "credit_limit_amt",
    "credit_used": "credit_used_amt", "quota_used": "quota_used_qty", "coupon_value": "coupon_value_num",
    "pay_timeout_at": "pay_timeout_time", "expires_at": "expire_time", "expire_at": "expire_time", "revoked_at": "revoke_time",
    "start_at": "start_time", "last_sync_at": "last_sync_time", "sla_deadline": "sla_deadline_time", "timeout_at": "timeout_time",
    "valid_start": "valid_start_time", "valid_end": "valid_end_time", "effective_from": "effective_start_time",
    "effective_to": "effective_end_time", "valid_from": "valid_start_time", "valid_to": "valid_end_time",
    "last_heartbeat": "last_heartbeat_time", "is_primary": "primary_person_type", "combo_flag": "combo_type",
    "external_frozen": "external_frozen_type", "pass_policy": "pass_policy_type", "pay_method": "pay_method_type",
    "pay_direction": "pay_direction_type", "receive_channel": "receive_channel_type", "refund_channel": "refund_channel_type",
    "frozen_event": "release_event_type", "verify_result": "verify_result_type", "action": "action_type",
    "dimension": "dimension_type", "scope": "scope_type", "channel": "price_channel_code", "sale_mode": "sale_mode_type",
    "collection_mode": "collection_mode_type", "ban_source": "ban_source_type", "calculator": "calculator_type",
    "base_price_ref": "base_price_ref_type", "unit": "unit_type", "gender": "gender_type", "notify_channel": "notify_channel_type",
    "log_scope": "log_scope_type", "distribution_mode": "distribution_mode_type", "payment_mode": "payment_mode_type",
    "register_source": "register_source_code", "customer_kind": "customer_type", "account_kind": "account_type",
    "id_type": "cert_type", "id_number": "cert_no", "contact_id_type": "contact_cert_type", "contact_id_number": "contact_cert_no",
    "birthday": "birth_date", "code_value": "credential_code", "identity_value": "identity_code", "version": "version_no",
    "sku_version": "sku_version_no", "sort_order": "sort_no", "dict_order": "sort_no", "time_window": "time_window_second_qty",
    "date_single": "price_date", "date_from": "price_start_date", "date_to": "price_end_date", "weekday_mask": "weekday_mask_code",
    "priority": "priority_no", "capacity": "capacity_qty", "offline_timestamp": "offline_device_time", "sync_mode": "sync_mode_type",
    "duration_days": "duration_day_qty", "used_count": "used_qty", "total_count": "total_qty", "rate_limit_qps": "rate_limit_qps_qty",
    "exchange_rate_to_cny": "exchange_to_cny_rate", "region_level": "region_level_no", "current_node": "current_node_name",
    "threshold": "threshold_desc", "reason": "reason_desc", "remark": "remark_desc", "detail": "detail_desc",
    "description": "description_desc", "fail_reason": "fail_reason_desc", "refund_reason": "refund_reason_desc",
    "change_reason": "change_reason_desc", "complaint_content": "complaint_content_desc", "notify_content": "notify_content_desc",
    "enabled_when": "enabled_when_desc", "disabled_when": "disabled_when_desc", "validation_rule": "validation_rule_desc",
    "default_value": "default_value_desc", "attribute_value": "attribute_value_code", "region_path": "region_path_desc",
    "phone": "phone_no", "contact_phone": "contact_phone_no", "email": "email_addr_desc", "card_holder": "card_holder_name",
    "bank_branch": "bank_branch_name", "address_phone": "address_phone_desc", "fee_item": "fee_item_code",
    "currency": "currency_code", "external_channel": "external_channel_code", "invoice_subject": "invoice_subject_type",
    "changed_by": "change_operator_name", "revoked_by": "revoke_operator_name", "point_name": "verify_point_name",
    "point_type": "verify_point_type", "point_status": "verify_point_status", "module": "module_code", "locale": "locale_code",
    "dict_type": "dict_type_code", "tags": "tag_list_desc", "sale_channels": "sale_channel_list_desc", "business_types": "business_type_list_desc",
    "allowed_sku_ids": "allowed_sku_list_desc", "capabilities": "capability_list_desc", "banned_actions": "banned_action_list_desc",
    "feature_permissions": "feature_permission_list_desc", "resource_limits": "resource_limit_desc", "params": "rule_param_desc",
    "rule_value": "rule_value_desc", "impacts": "impact_list_desc", "conflicts": "conflict_list_desc", "depends_on": "depend_list_desc",
    "dimension_values": "dimension_value_desc", "allowed_interfaces": "allowed_interface_list_desc", "custom_values": "custom_value_desc",
    "ip_whitelist": "ip_whitelist_desc", "resource_value": "resource_value_desc", "permission_desc": "permission_desc",
    "config_value": "config_value_desc", "field_value": "field_value_desc", "ext_dims": "ext_dim_desc", "depend_on_item": "depend_on_item_no",
    "applicant_name": "applicant_name", "dimension_value": "dimension_value_desc", "app_ref": "app_ref_code",
    "ip_address": "client_ip_code", "channel_scope": "channel_scope_type", "ota_sub_channel": "ota_sub_channel_code",
    "invoice_title": "invoice_title_name", "default_content": "default_content_desc", "invoice_provider": "invoice_provider_code",
    "provider_terminal": "provider_terminal_code", "currency_name_en": "currency_en_name", "currency_symbol": "currency_symbol_code",
    "dict_name_en": "dict_en_name", "applicable_sku_ids": "applicable_sku_list_desc", "invoice_file_url": "invoice_file_url_desc",
    "cover_image": "cover_image_url_desc", "complainant_id": "complainant_id", "ui_hint": "ui_hint_desc",
}
AUDIT_DROP = {"create_by", "update_by", "deleted"}
CMT = {  # 源注释未列取值的枚举字段：补全取值
    ("ods_opr_notify_record_di", "notify_channel"): "实际发送渠道：SMS/MINI_PROGRAM_MSG/EMAIL/WEBHOOK/IN_APP",
}

def std(n, t_mysql, entity):
    if n == "id":
        return entity + "_id"
    if n in REN:
        return REN[n]
    if n == "amount":
        return entity + "_amt"
    if n == "status":
        return entity + "_status"
    if n == "name":
        return entity + "_name"
    if n == "quantity":
        return "buy_ticket_qty"
    if n.endswith("_id") and t_mysql.upper().startswith("VARCHAR"):
        return n[:-3] + "_code"
    if n.endswith("_quantity"):
        return n[:-9] + "_qty"
    if n.endswith("_count"):
        return n[:-6] + "_qty"
    if n.endswith("_kind"):
        return n[:-5] + "_type"
    if n.endswith("_at"):
        return n[:-3] + "_time"
    return n

def kind_of(n):
    if n in ("etl_time", "binlog_op_type", "binlog_time", "proc_time"):
        return "ETL"
    if n in ("start_date", "end_date"):
        return "拉链"
    if n.endswith(("_amt", "_qty", "_rate", "_num")):
        return "度量"
    if n.endswith(("_status", "_type")):
        return "状态类型"
    if n.endswith(("_time", "_date")):
        return "时间"
    if n.endswith("_id"):
        return "外键"
    if n.endswith("_no"):
        return "退化维度"
    return "维度属性"

def col(n, t, c, k=None, s="", r=None):
    return dict(n=n, t=t, c=c.replace("'", "’"), k=k or kind_of(n), s=s, r=r or [])

def lines(spec, default_refs=None):
    """多行规格：字段|类型|注释|加工说明 ；加工说明中的 表.字段 自动识别为上游字段"""
    out = []
    for ln in spec.strip().splitlines():
        ln = ln.strip()
        if not ln or ln.startswith("#"):
            continue
        p = [x.strip() for x in ln.split("|")]
        n, t, c = p[0], p[1], p[2]
        s = p[3] if len(p) > 3 else ""
        k = p[4] if len(p) > 4 else None
        refs = [[a, b] for a, b in re.findall(r"\b((?:ods|dwd|dim|dws|ads)_[a-z0-9_]+)\.([a-z0-9_]+)", s)]
        out.append(col(n, t, enrich(c), k, s, refs))
    return out

ETL = lambda: [col("etl_time", "STRING", "ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss", "ETL", "调度写入")]
ZIP = lambda: [col("start_date", "STRING", "拉链开始日期，格式 yyyy-MM-dd", "拉链", "拉链计算"),
               col("end_date", "STRING", "拉链结束日期，格式 yyyy-MM-dd；9999-12-31 表示当前有效", "拉链", "拉链计算")]

# ============================================================ ODS：贴源，按备注剔除 / 脱敏
SENS_DROP = {"ods_fin_payment_channel_config_df": {"secret_key", "cert_path"}, "ods_fin_bank_card_df": {"card_number"},
             "ods_fin_invoice_config_df": {"provider_secret"}, "ods_trf_channel_df": {"app_secret"},
             "ods_trf_tenant_mp_config_df": {"app_secret"}, "ods_trf_api_key_df": {"app_secret"}}
SENS_MASK = {"ods_ord_order_group_di": {"contact_id_number", "contact_phone"}, "ods_ord_ticket_person_di": {"id_number", "phone"},
             "ods_ord_ticket_credential_di": {"code_value"}, "ods_cus_customer_di": {"phone"}, "ods_cus_customer_credential_di": {"code_value"},
             "ods_opr_blacklist_di": {"dimension_value"}, "ods_opr_notify_record_di": {"notify_content"}}
for k in list(SENS_MASK):
    SENS_MASK[k.replace("_di", "_rt")] = SENS_MASK[k]

def flink_type(mysql):
    """MySQL → Flink CDC 类型映射（mysql-cdc 连接器要求声明类型与源端兼容）"""
    t = mysql.upper()
    uns = "UNSIGNED" in t
    if t.startswith("BIGINT"):
        return "DECIMAL(20,0)" if uns else "BIGINT"
    if t.startswith("INT"):
        return "BIGINT" if uns else "INT"
    if t.startswith("TINYINT"):
        return "SMALLINT" if uns else "TINYINT"
    if t.startswith("DECIMAL"):
        return t.replace(" ", "")
    if t.startswith("DATETIME"):
        return "TIMESTAMP(3)"
    if t.startswith("TIMESTAMP"):
        return "TIMESTAMP_LTZ(3)"
    if t.startswith("DATE"):
        return "DATE"
    return "STRING"

def ods_cols(short, db, st, rt):
    """离线 ODS：Hive 贴源表；实时 ODS：Flink CDC 源表（直读 MySQL binlog，不经 Kafka）"""
    src = SRC[st]
    base = short.rsplit("_", 1)[0] + "_di"
    drop, mask = SENS_DROP.get(short, set()), SENS_MASK.get(short, SENS_MASK.get(base, set()))
    if rt:  # 实时只声明需要的列：敏感列不声明即不读取
        drop = drop | mask | {"contact_name", "name", "email", "wechat_unionid", "alipay_user_id", "avatar", "birthday", "phone",
                              "notify_content", "complaint_content", "detail"}
        mask = set()
    uk = {u[0] for u in src.get("uks", []) if len(u) == 1}
    out = []
    for n, t, c in src["cols"]:
        if n in drop:
            continue
        cc = enrich(c) or n
        if n in mask:
            cc += "（脱敏）"
        k = "主键" if n == "id" else ("业务主键" if n in uk else None)
        how = "%s.%s.%s%s" % (db, st, n, "，脱敏" if n in mask else "") + ("，Flink CDC 读 binlog" if rt else "")
        out.append(col(n, flink_type(t) if rt else htype(t), cc, k, how, []))
    if short == "ods_fin_bank_card_df":
        out.append(col("card_tail_no", "STRING", "卡号后 4 位（抽取时由 card_number 截取，完整卡号不落仓）", None, "%s.%s.card_number 截取后 4 位" % (db, st)))
    if rt:
        c = col("binlog_time", "TIMESTAMP_LTZ(3)", "binlog 变更时间（Flink CDC 元数据 op_ts；全量快照阶段为 0）", "ETL", "Flink CDC 元数据 op_ts")
        c["meta"] = "op_ts"
        out.append(c)
    else:
        if short.endswith("_di"):
            out.append(col("binlog_op_type", "STRING", "变更类型：I-新增，U-更新，D-删除（取自 binlog）", "ETL", "增量采集"))
            out.append(col("binlog_time", "STRING", "binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss", "ETL", "增量采集"))
        out += ETL()
    return out, src["comment"]

# ============================================================ DWD / DIM：从主 ODS 规范化 + 扩展字段
def derive(ods, ODS, entity, drop=(), mask=(), rename=None, json_keep=()):
    rename = rename or {}
    st = ODS[ods]["st"]
    mysql_t = {n: t for n, t, c in SRC[st]["cols"]}
    out = []
    for c in ODS[ods]["cols"]:
        n = c["n"]
        if c["k"] == "ETL" or n in AUDIT_DROP or n in drop:
            continue
        mt = mysql_t.get(n, "VARCHAR")
        if mt.upper().startswith(("JSON", "TEXT")) and n not in json_keep:
            continue
        nn = rename.get(n) or std(n, mt, entity)
        raw_c = enrich(CMT[(ods, n)]) if (ods, n) in CMT else c["c"]
        amt = is_amount(n, raw_c)
        t = "DECIMAL(18,2)" if amt else c["t"]
        cc = raw_c
        if amt:
            cc = re.sub(r"[（(]分[）)]", "（元）", cc)
            cc = re.sub(r"[（(]分[，,]", "（元，", cc).replace("（分/年）", "（元/年）")
            cc += "；源字段单位为分，入仓 ÷100"
        if n == "id":
            cc = "%sID（源表主键 id）" % ODS[ods]["cn"]
        if n in mask and "脱敏" not in cc:
            cc += "（脱敏）"
        how = "%s.%s" % (ods, n) + ("，÷100 转元" if amt else "") + ("，改名" if nn != n else "") + ("，JSON 原样保留" if n in json_keep else "")
        k = "主键" if n == "id" else ("业务主键" if c["k"] == "业务主键" else None)
        out.append(col(nn, t, cc, k, how, [[ods, n]]))
    return out

# ---------------------------------------------------- DWD 规格
DWD = {}
def D(name, base, entity, extra="", **kw):
    DWD[name] = dict(base=base, entity=entity, extra=extra, kw=kw)

D("dwd_ord_order_group_di", "ods_ord_order_group_di", "order_group", mask=("contact_id_number", "contact_phone", "contact_name"), extra="""
order_date|STRING|下单日期，格式 yyyy-MM-dd|ods_ord_order_group_di.create_time 取日期
first_pay_time|STRING|首次支付成功时间，格式 yyyy-MM-dd HH:mm:ss；未支付为空|ods_fin_payment_record_di.pay_time 按 order_group_no 取 INBOUND 且 PAID 的最小值
order_ticket_qty|BIGINT|聚合单内购买票数合计|ods_ord_order_di.quantity 按 order_group_no 汇总
sub_order_qty|BIGINT|聚合单内子单数（套票子项单除外）|ods_ord_order_di.order_no 按 order_group_no 计数
channel_type|STRING|入口渠道类型：MP/PC/API/OFFLINE/H5|dim_trf_channel_df.channel_type 按 channel_id 关联
""")
D("dwd_ord_order_di", "ods_ord_order_di", "order", extra="""
channel_id|BIGINT|入口渠道ID，关联 dim_trf_channel_df|ods_ord_order_group_di.channel_id 按 order_group_no 冗余
channel_type|STRING|入口渠道类型：MP/PC/API/OFFLINE/H5|dim_trf_channel_df.channel_type
app_code|STRING|对接端标识（取自 t_channel.app_id）|ods_ord_order_group_di.app_id 冗余
app_ref_code|STRING|对接端引用|ods_ord_order_group_di.app_ref 冗余
operator_type|STRING|操作人类型：CUSTOMER/TENANT_STAFF|ods_ord_order_group_di.operator_type 冗余
operator_id|BIGINT|操作人ID（游客或员工）|ods_ord_order_group_di.operator_id 冗余
buyer_type|STRING|付款方类型：CUSTOMER/ANONYMOUS|ods_ord_order_group_di.buyer_type 冗余
buyer_customer_id|BIGINT|买家游客ID，关联 dim_cus_customer_zip|ods_ord_order_group_di.buyer_customer_id 冗余
currency_code|STRING|币种编码，关联 dim_opr_currency_f|ods_ord_order_group_di.currency 冗余
spu_id|BIGINT|产品(SPU)ID，关联 dim_prd_spu_zip|dim_prd_sku_zip.spu_id 按 sku_id 关联
product_type|STRING|产品业态：SCENIC/HOTEL/SHOW/…|dim_prd_sku_zip.product_type
play_date|STRING|游玩日期，格式 yyyy-MM-dd|ods_ord_order_di.sale_dims 展开 date
time_slot_code|STRING|游玩时段，如 10:00-11:00|ods_ord_order_di.sale_dims 展开 timeSlot
seat_zone_code|STRING|座位区域，如 VIP|ods_ord_order_di.sale_dims 展开 seatZone
order_amt|DECIMAL(18,2)|子单金额（元）= 单价 × 购买数量|ods_ord_order_di.unit_price × ods_ord_order_di.quantity ÷100
cost_price_amt|DECIMAL(18,2)|下单时 SKU 成本价（元）|dim_prd_sku_zip.cost_price_amt 按下单时间取拉链
order_date|STRING|下单日期，格式 yyyy-MM-dd|ods_ord_order_di.create_time 取日期
pay_time|STRING|支付成功时间；未支付为空|ods_ord_order_di.order_status 首次变为 PAID 的 binlog_time
cancel_time|STRING|取消时间；未取消为空|ods_ord_order_di.order_status 变为 CANCELLED 的 binlog_time
advance_book_day_qty|BIGINT|提前预订天数 = 游玩日期 - 下单日期|play_date 与 order_date 相减
""")
STATUS_LOG = """
{key}|STRING|{keycn}|{ods}.{key}
order_group_no|STRING|所属聚合单号|{grp}
seller_tenant_id|BIGINT|卖家租户ID，关联 dim_sup_tenant_zip|{seller}
sku_id|BIGINT|SKU ID，关联 dim_prd_sku_zip|{sku}
before_status|STRING|变更前状态：{vals}|{ods}.{st} 取 binlog 前镜像
after_status|STRING|变更后状态：{vals}|{ods}.{st} 取 binlog 后镜像
change_time|STRING|状态变更时间，格式 yyyy-MM-dd HH:mm:ss|{ods}.binlog_time
status_change_qty|BIGINT|状态变更次数，固定为 1|常量 1
stay_minute_qty|BIGINT|前一状态停留时长（分钟）|change_time 与上一条变更时间相减
tenant_id|BIGINT|租户ID（分库维度）|{ods}.tenant_id
"""
D("dwd_ord_order_status_log_di", None, "order", extra=STATUS_LOG.format(
    key="order_no", keycn="子单号", ods="ods_ord_order_di", grp="ods_ord_order_di.order_group_no", seller="ods_ord_order_di.seller_tenant_id",
    sku="ods_ord_order_di.sku_id", st="order_status", vals="PENDING_PAY/PAID/PARTIALLY_VERIFIED/FULLY_VERIFIED/REFUNDED/CANCELLED"))
D("dwd_ord_ticket_di", "ods_ord_ticket_di", "ticket", extra="""
order_group_no|STRING|所属聚合单号|dwd_ord_order_di.order_group_no 按 order_no 冗余
seller_tenant_id|BIGINT|卖家租户ID，关联 dim_sup_tenant_zip|dwd_ord_order_di.seller_tenant_id
sku_id|BIGINT|SKU ID，关联 dim_prd_sku_zip|dwd_ord_order_di.sku_id
spu_id|BIGINT|产品(SPU)ID|dwd_ord_order_di.spu_id
channel_id|BIGINT|入口渠道ID|dwd_ord_order_di.channel_id
buyer_customer_id|BIGINT|买家游客ID|dwd_ord_order_di.buyer_customer_id
play_date|STRING|游玩日期，格式 yyyy-MM-dd|dwd_ord_order_di.play_date
valid_end_date|STRING|有效期截止日期，格式 yyyy-MM-dd|ods_ord_ticket_di.valid_end 取日期
seat_no|STRING|座位号（演出/场馆）|ods_ord_ticket_di.metadata 展开 seatInfo
cabin_no|STRING|舱位号（游船）|ods_ord_ticket_di.metadata 展开 cabinInfo
schedule_time|STRING|场次/班次时间|ods_ord_ticket_di.metadata 展开 schedule
unit_price_amt|DECIMAL(18,2)|票分摊单价（元）|dwd_ord_order_di.unit_price_amt
ticket_qty|BIGINT|票数，固定为 1|常量 1
delay_active_type|INT|是否延迟激活：0-否，1-是（首次核销后回填有效期）|ods_ord_ticket_di.valid_start 为空判定
first_verify_time|STRING|首次核销时间；未核销为空|dwd_ord_verify_di.create_time 按 ticket_no 取最小
issue_time|STRING|出票时间|ods_ord_ticket_di.create_time
""")
D("dwd_ord_ticket_status_log_di", None, "ticket", extra=STATUS_LOG.format(
    key="ticket_no", keycn="票号", ods="ods_ord_ticket_di", grp="dwd_ord_ticket_di.order_group_no", seller="dwd_ord_ticket_di.seller_tenant_id",
    sku="dwd_ord_ticket_di.sku_id", st="ticket_status", vals="AVAILABLE/PARTIALLY_USED/USED/EXPIRED/REFUNDED/CANCELLED").replace(
    "order_group_no|", "order_no|STRING|所属子单号|ods_ord_ticket_di.order_no\norder_group_no|"))
D("dwd_ord_ticket_person_di", "ods_ord_ticket_person_di", "person", mask=("id_number", "phone", "name"), extra="""
order_no|STRING|所属子单号|dwd_ord_ticket_di.order_no 按 ticket_no 冗余
seller_tenant_id|BIGINT|卖家租户ID|dwd_ord_ticket_di.seller_tenant_id
sku_id|BIGINT|SKU ID|dwd_ord_ticket_di.sku_id
play_date|STRING|游玩日期|dwd_ord_ticket_di.play_date
origin_country_code|STRING|客源国家编码|dim_opr_region_f.country_code 按证件号前 6 位映射
origin_province_code|STRING|客源省份编码|dim_opr_region_f.province_code 按证件号前 6 位映射
origin_province_name|STRING|客源省份名称|dim_opr_region_f.province_name
origin_city_code|STRING|客源城市编码|dim_opr_region_f.city_code
origin_city_name|STRING|客源城市名称|dim_opr_region_f.city_name
age_year_qty|BIGINT|游玩时年龄（岁）|ods_ord_ticket_person_di.id_number 第 7~14 位出生日期 与 play_date 计算
age_band_code|STRING|年龄段：0_17-未成年，18_25-18~25岁，26_35-26~35岁，36_45-36~45岁，46_60-46~60岁，60_PLUS-60岁以上，UNKNOWN-未知|age_year_qty 分段
gender_type|STRING|性别：MALE-男，FEMALE-女，UNKNOWN-未知|ods_ord_ticket_person_di.id_number 第 17 位奇偶
person_qty|BIGINT|游客人数，固定为 1|常量 1
""")
D("dwd_ord_entitlement_di", "ods_ord_entitlement_di", "entitlement", extra="""
order_no|STRING|所属子单号|dwd_ord_ticket_di.order_no 按 ticket_no 冗余
seller_tenant_id|BIGINT|卖家租户ID|dwd_ord_ticket_di.seller_tenant_id
sku_id|BIGINT|SKU ID|dwd_ord_ticket_di.sku_id
project_id|BIGINT|权益对应项目ID|ods_ord_entitlement_di.entitlement_detail 展开 projectId
max_qty|BIGINT|最大可用次数（COUNTED/SELECTABLE）|ods_ord_entitlement_di.entitlement_detail 展开 maxCount
candidate_qty|BIGINT|可选项目数（SELECTABLE）|ods_ord_entitlement_di.entitlement_detail 展开 candidateRefs 长度
duration_minute_qty|BIGINT|可用时长（分钟，TIMED）|ods_ord_entitlement_di.entitlement_detail 展开 durationMinutes
quota_amt|DECIMAL(18,2)|额度（元，QUOTA）|ods_ord_entitlement_di.entitlement_detail 展开 quotaAmount ÷100
remain_qty|BIGINT|剩余可用次数 = 最大可用次数 - 已使用次数|max_qty - used_qty
issue_time|STRING|发放时间|ods_ord_entitlement_di.create_time
""")
D("dwd_ord_entitlement_binding_di", "ods_ord_person_entitlement_binding_di", "binding", extra="""
seller_tenant_id|BIGINT|卖家租户ID|dwd_ord_ticket_di.seller_tenant_id 按 ticket_no 冗余
sku_id|BIGINT|SKU ID|dwd_ord_ticket_di.sku_id
entitlement_type|STRING|权益类型：FIXED/COUNTED/SELECTABLE/TIMED/QUOTA/UNLIMITED|dwd_ord_entitlement_di.entitlement_type 按 entitlement_no 冗余
bind_time|STRING|绑定时间|ods_ord_person_entitlement_binding_di.create_time
""")
D("dwd_ord_ticket_credential_di", "ods_ord_ticket_credential_di", "credential", mask=("code_value",), extra="""
order_no|STRING|所属子单号|dwd_ord_ticket_di.order_no 按 ticket_no 冗余
seller_tenant_id|BIGINT|卖家租户ID|dwd_ord_ticket_di.seller_tenant_id
sku_id|BIGINT|SKU ID|dwd_ord_ticket_di.sku_id
issue_time|STRING|发码时间|ods_ord_ticket_credential_di.create_time
revoke_time|STRING|撤销时间；未撤销为空|ods_ord_ticket_credential_di.status 变为 REVOKED 的 binlog_time
credential_qty|BIGINT|凭证数，固定为 1|常量 1
""")
D("dwd_ord_verify_di", "ods_ord_verify_record_di", "verify", extra="""
order_no|STRING|所属子单号|dwd_ord_ticket_di.order_no 按 ticket_no 冗余
seller_tenant_id|BIGINT|卖家租户ID|dwd_ord_ticket_di.seller_tenant_id
sku_id|BIGINT|SKU ID|dwd_ord_ticket_di.sku_id
spu_id|BIGINT|产品(SPU)ID|dwd_ord_ticket_di.spu_id
play_date|STRING|游玩日期|dwd_ord_ticket_di.play_date
entitlement_type|STRING|权益类型：FIXED/COUNTED/SELECTABLE/TIMED/QUOTA/UNLIMITED|dwd_ord_entitlement_di.entitlement_type 按 entitlement_no
verify_point_type|STRING|核销点类型：GATE/COUNTER/SELF_SERVICE/HANDHELD|dim_opr_verify_point_df.verify_point_type
device_type|STRING|设备类型：GATE/POS/HANDHELD/SELF_SERVICE/KIOSK/FACE_RECOGNITION|dim_opr_device_df.device_type
verify_time|STRING|核销时间，格式 yyyy-MM-dd HH:mm:ss|ods_ord_verify_record_di.create_time
verify_hour_no|INT|核销小时：0~23|verify_time 取小时
verify_person_qty|BIGINT|本次核销人数|dwd_ord_entitlement_binding_di 按 ticket_no+entitlement_no 计人数，开放模式记 1
verify_qty|BIGINT|核销次数，固定为 1|常量 1
verify_amt|DECIMAL(18,2)|核销金额（元，按票分摊单价 ÷ 可核销次数）|dwd_ord_ticket_di.unit_price_amt ÷ dwd_ord_entitlement_di.max_qty
offline_conflict_type|INT|是否离线冲突：0-否，1-是（离线核销回传时票已被核销）|ods_ord_verify_record_di.verify_result=DUPLICATE 且 verify_type=OFFLINE
""")
D("dwd_ord_refund_di", "ods_ord_refund_order_di", "refund", extra="""
seller_tenant_id|BIGINT|卖家租户ID|dwd_ord_order_group_di.seller_tenant_id 按 order_group_no 冗余
channel_id|BIGINT|入口渠道ID|dwd_ord_order_group_di.channel_id
apply_time|STRING|退款申请时间|ods_ord_refund_order_di.create_time
finish_time|STRING|退款完成时间；未完成为空|ods_ord_refund_order_di.refund_status 变为 COMPLETED 的 binlog_time
process_hour_qty|DECIMAL(18,2)|退款处理时长（小时）= 完成时间 - 申请时间|finish_time - apply_time
refund_ticket_qty|BIGINT|退款票数|ods_ord_refund_order_di.refund_items 展开 ticketNos 计数
""")
D("dwd_ord_refund_ticket_di", None, "refund_ticket", extra="""
refund_no|STRING|退款单号|ods_ord_refund_order_di.refund_no
order_group_no|STRING|聚合单号|ods_ord_refund_order_di.order_group_no
order_no|STRING|子单号|ods_ord_refund_order_di.refund_items 展开 orderNo
ticket_no|STRING|票号|ods_ord_refund_order_di.refund_items 展开 ticketNos
seller_tenant_id|BIGINT|卖家租户ID|dwd_ord_ticket_di.seller_tenant_id 按 ticket_no
sku_id|BIGINT|SKU ID|dwd_ord_ticket_di.sku_id
play_date|STRING|游玩日期|dwd_ord_ticket_di.play_date
refund_type|STRING|退款类型：ORDER_REFUND/COMPENSATION/PARTIAL_REFUND|ods_ord_refund_order_di.refund_type
refund_status|STRING|退款状态：PENDING/APPROVED/PROCESSING/COMPLETED/REJECTED|ods_ord_refund_order_di.refund_status
initiator_type|STRING|发起方：VISITOR/MERCHANT/PLATFORM/SYSTEM/OTA|ods_ord_refund_order_di.initiator_type
refund_reason_desc|STRING|退款原因|ods_ord_refund_order_di.refund_reason
before_ticket_status|STRING|退票时票状态：AVAILABLE/PARTIALLY_USED|dwd_ord_ticket_status_log_di.after_status 取退款申请前最后一条
refund_ticket_qty|BIGINT|退款票数，固定为 1|常量 1
refund_amt|DECIMAL(18,2)|本票分摊退款金额（元）|ods_ord_refund_order_di.refund_items 展开 amount ÷ 票数 ÷100
apply_time|STRING|退款申请时间|ods_ord_refund_order_di.create_time
finish_time|STRING|退款完成时间|dwd_ord_refund_di.finish_time
tenant_id|BIGINT|租户ID（分库维度）|ods_ord_refund_order_di.tenant_id
""")
D("dwd_fin_payment_di", "ods_fin_payment_record_di", "payment", rename={"amount": "pay_amt"}, extra="""
seller_tenant_id|BIGINT|卖家租户ID|dwd_ord_order_group_di.seller_tenant_id 按 order_group_no
payer_tenant_id|BIGINT|付款方租户ID|dim_fin_account_df.subject_id 按 payer_account_no
payee_tenant_id|BIGINT|收款方租户ID|dim_fin_account_df.subject_id 按 payee_account_no
sku_id|BIGINT|SKU ID（按票关联）|dwd_ord_ticket_di.sku_id 按 ticket_no
freeze_type|STRING|冻结类型：PROFIT/SETTLEMENT/FULL|ods_fin_payment_record_di.freeze_instructions 展开 freezeType
profit_amt|DECIMAL(18,2)|本级利润（元）= 支付金额 - 结算金额|ods_fin_payment_record_di.amount - ods_fin_payment_record_di.settle_amount ÷100
pay_date|STRING|支付日期，格式 yyyy-MM-dd|ods_fin_payment_record_di.pay_time 取日期
""")
D("dwd_fin_refund_payment_di", "ods_ord_refund_detail_di", "refund_detail", extra="""
order_group_no|STRING|聚合单号|dwd_fin_payment_di.order_group_no 按 payment_no
pay_method_type|STRING|原支付方式：BALANCE/WECHAT/ALIPAY/CREDIT/OFFLINE/ZERO_FEE|dwd_fin_payment_di.pay_method_type
pay_direction_type|STRING|原资金方向：INBOUND/OUTBOUND|dwd_fin_payment_di.pay_direction_type
finish_time|STRING|退款到账时间；未完成为空|ods_ord_refund_detail_di.refund_detail_status 变为 SUCCESS 的 binlog_time
""")
D("dwd_fin_frozen_di", "ods_fin_frozen_record_di", "frozen", rename={"amount": "freeze_amt"}, extra="""
account_type|STRING|账户类型：MERCHANT/DISTRIBUTOR/PLATFORM|dim_fin_account_df.account_type 按 account_no
subject_id|BIGINT|账户主体ID|dim_fin_account_df.subject_id
sku_id|BIGINT|SKU ID|dwd_ord_ticket_di.sku_id 按 ticket_no
freeze_time|STRING|冻结时间|ods_fin_frozen_record_di.create_time
release_time|STRING|解冻时间；未解冻为空|ods_fin_frozen_record_di.frozen_status 变为 RELEASED 的 binlog_time
freeze_hour_qty|DECIMAL(18,2)|冻结时长（小时）|release_time - freeze_time
""")
D("dwd_fin_fund_flow_di", "ods_fin_fund_flow_di", "flow", rename={"amount": "change_amt"}, extra="""
account_type|STRING|账户类型：MERCHANT/DISTRIBUTOR/PLATFORM|dim_fin_account_df.account_type 按 account_no
subject_id|BIGINT|账户主体ID|dim_fin_account_df.subject_id
flow_direction_type|INT|资金方向：1-入账，2-出账|ods_fin_fund_flow_di.amount 正负判定
flow_time|STRING|流水发生时间|ods_fin_fund_flow_di.create_time
""")
D("dwd_fin_withdraw_di", "ods_fin_withdraw_order_di", "withdraw", extra="""
account_type|STRING|账户类型：MERCHANT/DISTRIBUTOR/PLATFORM|dim_fin_account_df.account_type 按 account_no
bank_name|STRING|提现银行|dim_fin_bank_card_df.bank_name 按 bank_card_id
apply_time|STRING|提现申请时间|ods_fin_withdraw_order_di.create_time
finish_time|STRING|提现完成时间；未完成为空|ods_fin_withdraw_order_di.withdraw_status 变为 COMPLETED 的 binlog_time
""")
D("dwd_fin_invoice_di", "ods_fin_invoice_order_di", "invoice", extra="""
invoice_provider_code|STRING|开票服务商|dim_fin_invoice_config_df.invoice_provider_code 按 invoice_config_id
apply_time|STRING|开票申请时间|ods_fin_invoice_order_di.create_time
""")
D("dwd_fin_resource_batch_di", "ods_fin_resource_batch_df", "resource_batch", extra="""
package_id|BIGINT|来源套餐ID|dwd_opr_package_subscription_di.package_id 按 purchase_no
consume_qty|BIGINT|当日消耗量 = 昨日剩余量 - 今日剩余量（不含新购）|ods_fin_resource_batch_df.remaining_quantity 日差
""")
D("dwd_fin_account_balance_df", "ods_fin_account_df", "account", extra="""
total_balance_amt|DECIMAL(18,2)|账户总余额（元）= 可用余额 + 冻结余额|ods_fin_account_df.available_balance + ods_fin_account_df.frozen_balance ÷100
""")
D("dwd_trf_distribution_settle_di", None, "settle", extra="""
ticket_no|STRING|票号|dwd_fin_payment_di.ticket_no
order_no|STRING|子单号|dwd_ord_ticket_di.order_no
order_group_no|STRING|聚合单号|dwd_fin_payment_di.order_group_no
batch_no|STRING|支付批次号|dwd_fin_payment_di.batch_no
item_no|STRING|支付批次内明细号|dwd_fin_payment_di.item_no
payment_no|STRING|支付记录号|dwd_fin_payment_di.payment_no
chain_level_no|INT|分销链层级：1-游客→末级分销商，2~4-逐级向上采购|dwd_fin_payment_di.depend_on_item_no 递归计算
relation_no|STRING|分销关系编号|dim_trf_distribution_relation_zip.relation_no 按付款方/收款方租户匹配
supplier_tenant_id|BIGINT|本级供应商（收款方）租户ID|dwd_fin_payment_di.payee_tenant_id
distributor_tenant_id|BIGINT|本级分销商（付款方）租户ID；第 1 级为空|dwd_fin_payment_di.payer_tenant_id
payer_account_no|STRING|付款账户号|dwd_fin_payment_di.payer_account_no
payee_account_no|STRING|收款账户号|dwd_fin_payment_di.payee_account_no
sku_id|BIGINT|SKU ID|dwd_ord_ticket_di.sku_id
sale_amt|DECIMAL(18,2)|本级售价（元）|dwd_fin_payment_di.pay_amt
settle_amt|DECIMAL(18,2)|本级结算价（元）|dwd_fin_payment_di.settle_amt
profit_amt|DECIMAL(18,2)|本级利润（元）= 售价 - 结算价|dwd_fin_payment_di.profit_amt
freeze_type|STRING|冻结类型：PROFIT/SETTLEMENT/FULL|dwd_fin_frozen_di.freeze_type 按 ticket_no+account_no
pay_method_type|STRING|支付方式：BALANCE/WECHAT/ALIPAY/CREDIT/OFFLINE/ZERO_FEE|dwd_fin_payment_di.pay_method_type
pay_time|STRING|支付时间|dwd_fin_payment_di.pay_time
tenant_id|BIGINT|租户ID（分库维度）|dwd_fin_payment_di.tenant_id
""")
D("dwd_prd_sku_version_di", "ods_prd_sku_version_snapshot_di", "snapshot", extra="""
new_version_no|INT|变更后版本号|dim_prd_sku_zip.version_no 当前值
old_price_amt|DECIMAL(18,2)|变更前价格（元）|ods_prd_sku_version_snapshot_di.snapshot_data 展开 priceChangeLog.oldPrice ÷100
new_price_amt|DECIMAL(18,2)|变更后价格（元）|ods_prd_sku_version_snapshot_di.snapshot_data 展开 priceChangeLog.newPrice ÷100
price_change_type|INT|本次是否改价：0-否，1-是|old_price_amt 与 new_price_amt 比较
change_time|STRING|变更时间|ods_prd_sku_version_snapshot_di.create_time
""")
D("dwd_prd_price_point_log_di", "ods_prd_price_point_di", "price_point", drop=("price",), json_keep=("ext_dims",), extra="""
change_type|STRING|变更类型：I-新增，U-修改，D-删除|ods_prd_price_point_di.binlog_op_type
before_price_amt|DECIMAL(18,2)|变更前价格（元）；新增时为空|ods_prd_price_point_di.price binlog 前镜像 ÷100
after_price_amt|DECIMAL(18,2)|变更后价格（元）；删除时为空|ods_prd_price_point_di.price binlog 后镜像 ÷100
change_time|STRING|变更时间|ods_prd_price_point_di.binlog_time
""")
D("dwd_prd_sku_price_calendar_df", None, "price_calendar", extra="""
sku_id|BIGINT|SKU ID|ods_prd_price_point_di.sku_id
price_date|STRING|价格日期（日历展开，未来 N 天），格式 yyyy-MM-dd|dim_opr_date_f.date_code
price_channel_code|STRING|价格渠道编码|ods_prd_price_point_di.channel
ext_dim_desc|STRING|扩展维度组合（JSON 字符串，如场次/座位等级）|ods_prd_price_point_di.ext_dims
hit_price_no|STRING|命中的价格点编号|ods_prd_price_point_di.price_no 按优先级取第一
hit_priority_no|INT|命中优先级：10-单日价，5-区间价，3-星期价，0-默认价|ods_prd_price_point_di.priority
list_price_amt|DECIMAL(18,2)|当日生效挂牌价（元）|ods_prd_price_point_di.price ÷100
pricing_rule_no|STRING|叠加的定价规则编号；无规则为空|ods_prd_pricing_rule_df.rule_no
rule_price_type|INT|是否 L2 规则价：0-否，1-是|ods_prd_pricing_rule_df.rule_no 是否命中
final_price_amt|DECIMAL(18,2)|规则计算后成交参考价（元）|list_price_amt 按 ods_prd_pricing_rule_df.calculator 计算
tenant_id|BIGINT|租户ID（分库维度）|ods_prd_price_point_di.tenant_id
""")
D("dwd_inv_pool_change_di", "ods_inv_inventory_pool_di", "pool", drop=("total_quantity", "available_quantity", "frozen_quantity"), extra="""
change_type|STRING|变动类型：PRE_DEDUCT-预扣，CONFIRM-确认，ROLLBACK-回滚，ADJUST-调整|ods_inv_inventory_pool_di.frozen_quantity 与 ods_inv_inventory_pool_di.available_quantity 前后变化方向判定
order_no|STRING|引起变动的子单号；人工调整为空|ods_inv_inventory_unit_di.order_no 或库存流水关联
play_date|STRING|库存日期|ods_inv_inventory_pool_di.dimension_key 展开 date
room_type_code|STRING|房型编码（酒店）|ods_inv_inventory_pool_di.dimension_key 展开 roomType
show_time|STRING|场次时间（演出）|ods_inv_inventory_pool_di.dimension_key 展开 showTime
before_total_qty|BIGINT|变动前总库存|ods_inv_inventory_pool_di.total_quantity 前镜像
after_total_qty|BIGINT|变动后总库存|ods_inv_inventory_pool_di.total_quantity 后镜像
total_change_qty|BIGINT|总库存变化量|after_total_qty - before_total_qty
available_change_qty|BIGINT|可售库存变化量|ods_inv_inventory_pool_di.available_quantity 前后差
frozen_change_qty|BIGINT|冻结库存变化量|ods_inv_inventory_pool_di.frozen_quantity 前后差
change_time|STRING|变动时间|ods_inv_inventory_pool_di.binlog_time
""")
D("dwd_inv_unit_change_di", "ods_inv_inventory_unit_di", "unit", extra="""
sku_id|BIGINT|SKU ID|dim_inv_pool_df.sku_id 按 pool_no
seat_level_code|STRING|座位等级|ods_inv_inventory_unit_di.metadata 展开 seatLevel
room_type_code|STRING|房型编码|ods_inv_inventory_unit_di.metadata 展开 roomType
before_status|STRING|变更前状态：AVAILABLE/FROZEN/OCCUPIED|ods_inv_inventory_unit_di.unit_status 前镜像
after_status|STRING|变更后状态：AVAILABLE/FROZEN/OCCUPIED|ods_inv_inventory_unit_di.unit_status 后镜像
unit_change_qty|BIGINT|变更次数，固定为 1|常量 1
change_time|STRING|变更时间|ods_inv_inventory_unit_di.binlog_time
""")
D("dwd_inv_pool_snapshot_df", "ods_inv_inventory_pool_di", "pool", rename={"total_quantity": "total_qty", "available_quantity": "available_qty", "frozen_quantity": "frozen_qty"}, extra="""
play_date|STRING|库存日期|ods_inv_inventory_pool_di.dimension_key 展开 date
room_type_code|STRING|房型编码|ods_inv_inventory_pool_di.dimension_key 展开 roomType
show_time|STRING|场次时间|ods_inv_inventory_pool_di.dimension_key 展开 showTime
shared_pool_no|STRING|关联的共享配额池编号；无共享为空|dim_inv_shared_pool_df.shared_pool_no 按 source_pool_no
sold_qty|BIGINT|已售库存 = 总库存 - 可售 - 冻结|total_qty - available_qty - frozen_qty
sellout_type|INT|是否售罄：0-否，1-是|available_qty = 0
""")
D("dwd_cus_customer_register_di", "ods_cus_customer_di", "customer", drop=("wechat_unionid", "alipay_user_id", "email", "avatar", "name", "phone", "birthday"), extra="""
register_channel_id|BIGINT|注册渠道ID|dim_trf_channel_df.channel_id 按 register_source=channel_code
age_band_code|STRING|注册时年龄段：0_17-未成年，18_25-18~25岁，26_35-26~35岁，36_45-36~45岁，46_60-46~60岁，60_PLUS-60岁以上，UNKNOWN-未知|ods_cus_customer_di.birthday 计算
register_time|STRING|注册时间|ods_cus_customer_di.create_time
register_qty|BIGINT|注册人数，固定为 1；剔除 TENANT_DEFAULT 占位买家|常量 1
""")
D("dwd_cus_identity_bind_di", "ods_cus_customer_identity_di", "customer_identity", mask=("identity_value",), extra="""
bind_time|STRING|绑定时间|ods_cus_customer_identity_di.create_time
bind_qty|BIGINT|绑定次数，固定为 1|常量 1
""")
D("dwd_cus_credential_register_di", "ods_cus_customer_credential_di", "customer_credential", drop=("code_value",), extra="""
register_time|STRING|凭证注册时间|ods_cus_customer_credential_di.create_time
register_qty|BIGINT|注册凭证数，固定为 1|常量 1
""")
D("dwd_opr_risk_event_di", "ods_opr_risk_event_di", "risk_event", json_keep=("dimension_values",), extra="""
rule_type|STRING|规则类型：BLACKLIST/PURCHASE_LIMIT/GEO_FENCE/ABNORMAL_OP/DEFAULT_BREAK|dim_opr_risk_rule_df.rule_type 按 rule_id
dimension_type|STRING|规则维度：USER_ID/ID_CARD/PHONE/IP/DEVICE_ID|dim_opr_risk_rule_df.dimension_type
event_time|STRING|事件发生时间|ods_opr_risk_event_di.create_time
event_qty|BIGINT|事件数，固定为 1|常量 1
""")
D("dwd_opr_blacklist_log_di", "ods_opr_blacklist_di", "blacklist", mask=("dimension_value",), json_keep=("banned_actions",), extra="""
change_type|STRING|变更类型：ADD-新增，EXPIRE-到期失效，REVOKE-撤销|ods_opr_blacklist_di.blacklist_status 变化判定
change_time|STRING|变更时间|ods_opr_blacklist_di.binlog_time
change_qty|BIGINT|变更次数，固定为 1|常量 1
""")
D("dwd_opr_account_ban_di", "ods_opr_account_ban_di", "ban", json_keep=("banned_actions",), extra="""
ban_time|STRING|封禁时间|ods_opr_account_ban_di.create_time
ban_hour_qty|DECIMAL(18,2)|封禁时长（小时）= 解封或到期时间 - 封禁时间|ods_opr_account_ban_di.revoked_at / expires_at - create_time
ban_qty|BIGINT|封禁次数，固定为 1|常量 1
""")
D("dwd_opr_approval_di", "ods_opr_approval_instance_di", "instance", extra="""
flow_name|STRING|审批流名称|dim_opr_approval_flow_df.flow_name 按 flow_id
apply_time|STRING|发起时间|ods_opr_approval_instance_di.create_time
finish_time|STRING|审批结束时间；进行中为空|ods_opr_approval_instance_di.instance_status 终态的 binlog_time
approval_minute_qty|BIGINT|审批耗时（分钟）|finish_time - apply_time
timeout_type|INT|是否超时：0-否，1-是|finish_time 晚于 timeout_at 或进行中已超时
approval_qty|BIGINT|审批实例数，固定为 1|常量 1
""")
D("dwd_opr_complaint_di", "ods_opr_complaint_di", "complaint", drop=("complaint_content",), extra="""
seller_tenant_id|BIGINT|被投诉的卖家租户ID|dwd_ord_order_group_di.seller_tenant_id 按 order_group_no
create_time_hour_no|INT|投诉提交小时：0~23|ods_opr_complaint_di.create_time 取小时
resolve_time|STRING|处理完成时间；未完成为空|ods_opr_complaint_di.complaint_status 变为 RESOLVED/CLOSED 的 binlog_time
resolve_hour_qty|DECIMAL(18,2)|处理时长（小时）|resolve_time - create_time
sla_timeout_type|INT|是否超 SLA：0-否，1-是|resolve_time 或当前时间晚于 sla_deadline
complaint_qty|BIGINT|投诉数，固定为 1|常量 1
""")
D("dwd_opr_notify_di", "ods_opr_notify_record_di", "notify", drop=("notify_content",), extra="""
template_code|STRING|模板编码|dim_opr_notify_template_df.template_code 按 template_id
send_success_type|INT|是否发送成功：0-否，1-是|ods_opr_notify_record_di.send_status = SUCCESS
notify_qty|BIGINT|发送次数，固定为 1|常量 1
""")
D("dwd_opr_audit_log_di", "ods_opr_audit_log_di", "audit_log", extra="""
action_time|STRING|操作时间|ods_opr_audit_log_di.create_time
action_hour_no|INT|操作小时：0~23|action_time 取小时
night_action_type|INT|是否凌晨操作：0-否，1-是（0~6 点）|action_hour_no 判定
action_qty|BIGINT|操作次数，固定为 1|常量 1
""")
D("dwd_opr_device_status_log_di", None, "device", extra="""
device_id|BIGINT|设备ID|ods_opr_device_df.id
device_no|STRING|设备编号|ods_opr_device_df.device_no
tenant_id|BIGINT|租户ID|ods_opr_device_df.tenant_id
device_type|STRING|设备类型：GATE/POS/HANDHELD/SELF_SERVICE/KIOSK/FACE_RECOGNITION|ods_opr_device_df.device_type
device_group_id|BIGINT|设备分组ID|ods_opr_device_df.device_group_id
poi_id|BIGINT|所属 POI ID|ods_opr_device_df.poi_id
before_status|STRING|变更前状态：ACTIVE/OFFLINE/MAINTENANCE/INACTIVE|ods_opr_device_df.device_status 昨日快照
after_status|STRING|变更后状态：ACTIVE/OFFLINE/MAINTENANCE/INACTIVE|ods_opr_device_df.device_status 今日快照
last_heartbeat_time|STRING|最后心跳时间|ods_opr_device_df.last_heartbeat
change_time|STRING|状态变更时间|ods_opr_device_df.update_time
status_minute_qty|BIGINT|前一状态持续时长（分钟）|change_time 相邻相减
""")
D("dwd_opr_package_subscription_di", "ods_opr_package_subscription_di", "subscription", extra="""
package_name|STRING|套餐名称|ods_opr_package_df.package_name 按 package_id
package_amt|DECIMAL(18,2)|套餐价格（元）|ods_opr_package_df.package_price ÷100
duration_day_qty|BIGINT|订购时长（天）|ods_opr_package_df.duration_days
""")

# ---------------------------------------------------- DIM 规格
DIM = {}
def M(name, base, entity, extra="", **kw):
    DIM[name] = dict(base=base, entity=entity, extra=extra, kw=kw)

M("dim_prd_spu_zip", "ods_prd_spu_df", "spu", extra="""
tenant_name|STRING|所属商户名称|dim_sup_tenant_zip.tenant_name 按 tenant_id
""")
M("dim_prd_sku_zip", "ods_prd_sku_df", "sku", json_keep=("tags", "sale_channels"), extra="""
spu_no|STRING|SPU 编号|ods_prd_spu_df.spu_no 按 spu_id
spu_name|STRING|产品名称|ods_prd_spu_df.spu_name
product_type|STRING|产品业态：SCENIC/HOTEL/SHOW/…（13 种）|ods_prd_spu_df.product_type
poi_id|BIGINT|POI ID（景区/场馆）|ods_prd_spu_df.poi_id
tenant_name|STRING|所属商户名称|dim_sup_tenant_zip.tenant_name
sale_rule_qty|BIGINT|生效中的售卖规则数|dim_prd_sale_rule_df.sale_rule_item_id 按 sku_id 计数
real_name_policy_code|STRING|实名制策略|dim_prd_sku_attr_df.attribute_value_code 取 REAL_NAME
refund_policy_code|STRING|退改策略|dim_prd_sku_attr_df.attribute_value_code 取 REFUND_POLICY
""")
M("dim_prd_sku_attr_df", "ods_prd_sku_meta_value_df", "sku_attr", extra="""
attribute_name|STRING|属性名称|ods_prd_ticket_meta_df.attribute_name 按 attribute_code
value_type|STRING|值类型：POLICY_CHOICE/TOGGLE/NUMERIC/TEXT/DATE_RANGE|ods_prd_ticket_meta_df.value_type
attribute_value_name|STRING|属性值中文含义|dim_opr_dict_f.dict_name 按 attribute_code+attribute_value
""")
M("dim_prd_ticket_meta_f", "ods_prd_ticket_meta_df", "ticket_meta", json_keep=("impacts", "conflicts", "depends_on"), rename={"scope": "applicable_business_list_desc"})
M("dim_prd_sale_rule_df", "ods_prd_sale_rule_item_df", "sale_rule_item", json_keep=("rule_value",), extra="""
rule_no|STRING|售卖规则编号|ods_prd_sale_rule_df.rule_no 按 rule_id
sku_id|BIGINT|SKU ID|ods_prd_sale_rule_df.sku_id
effective_start_time|STRING|规则生效开始时间|ods_prd_sale_rule_df.effective_from
effective_end_time|STRING|规则生效结束时间|ods_prd_sale_rule_df.effective_to
rule_status|STRING|规则状态：ACTIVE/INACTIVE|ods_prd_sale_rule_df.rule_status
""")
M("dim_prd_pricing_rule_zip", "ods_prd_pricing_rule_df", "pricing_rule", json_keep=("params",))
M("dim_inv_pool_df", "ods_inv_inventory_pool_di", "pool", drop=("total_quantity", "available_quantity", "frozen_quantity"), extra="""
play_date|STRING|库存日期|ods_inv_inventory_pool_di.dimension_key 展开 date
room_type_code|STRING|房型编码|ods_inv_inventory_pool_di.dimension_key 展开 roomType
show_time|STRING|场次时间|ods_inv_inventory_pool_di.dimension_key 展开 showTime
cabin_code|STRING|舱位编码|ods_inv_inventory_pool_di.dimension_key 展开 cabin
""")
M("dim_inv_unit_df", "ods_inv_inventory_unit_di", "unit", drop=("order_no",), extra="""
sku_id|BIGINT|SKU ID|ods_inv_inventory_pool_di.sku_id 按 pool_no
seat_level_code|STRING|座位等级|ods_inv_inventory_unit_di.metadata 展开 seatLevel
room_type_code|STRING|房型编码|ods_inv_inventory_unit_di.metadata 展开 roomType
""")
M("dim_inv_shared_pool_df", "ods_inv_shared_inventory_pool_df", "shared_pool", extra="""
supplier_tenant_id|BIGINT|供应商租户ID|ods_trf_distribution_relation_df.supplier_tenant_id 按 relation_id
distributor_tenant_id|BIGINT|分销商租户ID|ods_trf_distribution_relation_df.distributor_tenant_id
""")
M("dim_cus_customer_zip", "ods_cus_customer_di", "customer", drop=("wechat_unionid", "alipay_user_id", "email", "avatar", "birthday"), mask=("phone", "name"), extra="""
register_channel_id|BIGINT|注册渠道ID|dim_trf_channel_df.channel_id 按 register_source=channel_code
age_band_code|STRING|年龄段：0_17-未成年，18_25-18~25岁，26_35-26~35岁，36_45-36~45岁，46_60-46~60岁，60_PLUS-60岁以上，UNKNOWN-未知（由生日计算，生日本身不入仓）|ods_cus_customer_di.birthday 计算
wechat_bind_type|INT|是否绑定微信：0-否，1-是|ods_cus_customer_di.wechat_unionid 非空
alipay_bind_type|INT|是否绑定支付宝：0-否，1-是|ods_cus_customer_di.alipay_user_id 非空
""")
M("dim_cus_identity_df", "ods_cus_customer_identity_di", "customer_identity", mask=("identity_value",))
M("dim_sup_tenant_zip", "ods_sup_tenant_df", "tenant", mask=("contact_phone",), json_keep=("business_types",), extra="""
country_name|STRING|国家名称|dim_opr_region_f.country_name 按 country_code
province_name|STRING|省份名称|dim_opr_region_f.province_name 按 region_id
city_name|STRING|城市名称|dim_opr_region_f.city_name 按 region_id
currency_code|STRING|结算币种|ods_sup_tenant_config_df.config_value 取 config_key=CURRENCY
locale_code|STRING|默认语言|ods_sup_tenant_config_df.config_value 取 config_key=LOCALE
package_id|BIGINT|当前生效套餐ID|ods_opr_package_subscription_di.package_id 取生效中最新一笔
package_expire_time|STRING|当前套餐到期时间|ods_opr_package_subscription_di.expire_at
""")
M("dim_sup_staff_zip", "ods_sup_tenant_staff_df", "staff", drop=("email",), mask=("phone",), extra="""
org_name|STRING|所属部门名称|dim_sup_org_df.org_name 按 org_id
org_path_desc|STRING|部门完整路径，如 总部/运营中心/票务部|dim_sup_org_df.org_path_desc
position_name|STRING|岗位名称|dim_sup_position_df.position_name 按 position_id
role_code_list_desc|STRING|角色编码列表，逗号分隔|ods_sup_sys_role_df.role_code 经 ods_sup_sys_user_role_df.role_id 聚合
role_name_list_desc|STRING|角色名称列表，逗号分隔|dim_sup_role_df.role_name 聚合
""")
M("dim_sup_org_df", "ods_sup_org_df", "org", extra="""
org_level_no|INT|部门层级：1-一级部门，依次递增|ods_sup_org_df.parent_org_id 递归
org_path_desc|STRING|部门完整路径|ods_sup_org_df.org_name 递归拼接
level1_org_id|BIGINT|一级部门ID|ods_sup_org_df.parent_org_id 递归
level1_org_name|STRING|一级部门名称|ods_sup_org_df.org_name 递归
level2_org_id|BIGINT|二级部门ID|ods_sup_org_df.parent_org_id 递归
level2_org_name|STRING|二级部门名称|ods_sup_org_df.org_name 递归
""")
M("dim_sup_position_df", "ods_sup_tenant_position_df", "position")
M("dim_sup_role_df", "ods_sup_sys_role_df", "role", extra="""
permission_qty|BIGINT|拥有权限数|ods_sup_sys_role_permission_df.permission_id 按 role_id 计数
permission_code_list_desc|STRING|权限编码列表，逗号分隔|ods_sup_sys_permission_df.permission_code 聚合
""")
M("dim_trf_channel_df", "ods_trf_channel_df", "channel", drop=("ip_whitelist", "callback_url", "app_key"), extra="""
api_key_qty|BIGINT|有效 API Key 数|ods_trf_api_key_df.key_no 按 channel_id 计数（key_status=ACTIVE）
rate_limit_qps_qty|BIGINT|API 限流 QPS（取最大）|ods_trf_api_key_df.rate_limit_qps
""")
M("dim_trf_channel_tenant_df", "ods_trf_channel_tenant_binding_df", "channel_tenant_binding", extra="""
channel_code|STRING|渠道编码|dim_trf_channel_df.channel_code 按 channel_id
channel_type|STRING|渠道类型：MP/PC/API/OFFLINE/H5|dim_trf_channel_df.channel_type
""")
M("dim_trf_mp_config_df", "ods_trf_tenant_mp_config_df", "mp_config")
M("dim_trf_distribution_relation_zip", "ods_trf_distribution_relation_df", "relation", extra="""
chain_level_no|INT|本关系在采购链中的层级：1~4|ods_trf_distribution_relation_df.parent_relation_id 递归
level1_tenant_id|BIGINT|1 级（源头供应商）租户ID|ods_trf_distribution_relation_df.supplier_tenant_id 递归至根
level2_tenant_id|BIGINT|2 级分销商租户ID|ods_trf_distribution_relation_df.distributor_tenant_id 递归
level3_tenant_id|BIGINT|3 级分销商租户ID|ods_trf_distribution_relation_df.distributor_tenant_id 递归
level4_tenant_id|BIGINT|4 级分销商租户ID|ods_trf_distribution_relation_df.distributor_tenant_id 递归
credit_available_amt|DECIMAL(18,2)|剩余授信额度（元）= 授信额度 - 已用授信|ods_trf_distribution_relation_df.credit_limit - ods_trf_distribution_relation_df.credit_used ÷100
""")
M("dim_fin_account_df", "ods_fin_account_df", "account", drop=("available_balance", "frozen_balance"), extra="""
subject_name|STRING|主体名称|dim_sup_tenant_zip.tenant_name 按 subject_id
""")
M("dim_fin_bank_card_df", "ods_fin_bank_card_df", "bank_card", mask=("card_holder",), extra="""
card_tail_no|STRING|卡号后 4 位|ods_fin_bank_card_df.card_tail_no
""")
M("dim_fin_pay_channel_df", "ods_fin_payment_channel_config_df", "pay_channel", drop=("callback_url",), extra="""
collection_mode_type|STRING|商户收款模式：PLATFORM_COLLECT-平台代收，INDEPENDENT-商户独立收款|ods_fin_merchant_payment_config_df.collection_mode 按 tenant_id+channel_code
merchant_config_status|STRING|商户支付配置状态：ACTIVE/PENDING_APPROVAL/INACTIVE|ods_fin_merchant_payment_config_df.config_status
""")
M("dim_fin_invoice_config_df", "ods_fin_invoice_config_df", "invoice_config")
M("dim_opr_verify_point_df", "ods_opr_verify_point_df", "verify_point", json_keep=("allowed_sku_ids",), extra="""
device_qty|BIGINT|绑定设备数|ods_opr_device_df.id 按 device_group_id 计数
""")
M("dim_opr_code_pool_df", "ods_opr_code_pool_df", "code_pool", extra="""
remain_qty|BIGINT|剩余可分配码数 = 容量 - 已分配 + 已回收|capacity_qty - allocated_qty + recycled_qty
""")
M("dim_opr_device_df", "ods_opr_device_df", "device", json_keep=("capabilities",), extra="""
device_group_no|STRING|设备分组编号|ods_opr_device_group_df.group_no 按 device_group_id
device_group_name|STRING|设备分组名称|ods_opr_device_group_df.group_name
verify_point_id|BIGINT|绑定核销点ID|ods_opr_device_group_df.verify_point_id
""")
M("dim_opr_risk_rule_df", "ods_opr_risk_rule_df", "risk_rule")
M("dim_opr_package_df", "ods_opr_package_df", "package", json_keep=("feature_permissions", "resource_limits"), extra="""
app_qty|BIGINT|包含应用数|ods_opr_app_binding_df.app_id 按 package_id 计数
app_code_list_desc|STRING|包含应用编码列表，逗号分隔|dim_opr_app_df.app_code 聚合
""")
M("dim_opr_app_df", "ods_opr_app_definition_df", "app")
M("dim_opr_approval_flow_df", "ods_opr_approval_flow_df", "approval_flow", extra="""
node_qty|BIGINT|审批节点数|ods_opr_approval_flow_df.flow_definition 展开 nodes 长度
timeout_hour_qty|BIGINT|单节点超时时长（小时）|ods_opr_approval_flow_df.flow_definition 展开 timeoutHours
""")
M("dim_opr_notify_template_df", "ods_opr_notify_template_df", "notify_template")
M("dim_opr_region_f", "ods_opr_region_df", "region", extra="""
region_name|STRING|地区名称（中文）|ods_opr_i18n_translation_df.field_value 取 zh-CN
country_name|STRING|国家名称|ods_opr_i18n_translation_df.field_value 按 country_code
iso3_code|STRING|国家三位码|ods_opr_country_df.iso3_code
province_code|STRING|所属省份编码|ods_opr_region_df.parent_id 递归到 region_level=1
province_name|STRING|所属省份名称|region_path_desc 第 2 段
city_code|STRING|所属城市编码|ods_opr_region_df.parent_id 递归到 region_level=2
city_name|STRING|所属城市名称|region_path_desc 第 3 段
district_code|STRING|区县编码|ods_opr_region_df.region_code（region_level=3 时）
district_name|STRING|区县名称|region_path_desc 第 4 段
id_card_prefix_code|STRING|身份证前 6 位行政区划码（客源地解析用）|ods_opr_region_df.region_code
""")
M("dim_opr_currency_f", "ods_opr_i18n_currency_df", "currency", extra="""
decimal_digit_qty|BIGINT|金额小数位数|常量映射（JPY=0，其余=2）
""")
M("dim_opr_dict_f", "ods_opr_sys_dict_df", "dict")
M("dim_mkt_coupon_df", "ods_mkt_coupon_df", "coupon", json_keep=("applicable_sku_ids",))

DATE_DIM = """
date_code|STRING|日期，格式 yyyy-MM-dd|生成|主键
date_no|STRING|日期，格式 YYYYMMDD（与分区一致）|生成
year_no|INT|年，如 2026|生成
quarter_no|INT|季度：1~4|生成
month_no|INT|月：1~12|生成
week_of_year_no|INT|ISO 周序号：1~53|生成
weekday_no|INT|星期几：1-周一 … 7-周日|生成
weekday_mask_code|STRING|星期位值：周一=1，周二=2，周三=4 … 周日=64（与价格点 weekday_mask 对应）|生成
weekend_type|INT|是否周末：0-否，1-是|生成
holiday_type|INT|日期类型：0-工作日，1-周末，2-法定节假日，3-调休上班日|国务院节假日安排
holiday_name|STRING|节假日名称，如 国庆节；非节假日为空|国务院节假日安排
vacation_type|INT|是否寒暑假：0-否，1-寒假，2-暑假|运营配置
season_type|INT|旺淡季：1-旺季，2-平季，3-淡季|运营配置
week_start_date|STRING|所在自然周周一日期|生成
month_start_date|STRING|所在自然月第一天|生成
"""

# ============================================================ DWS / ADS：粒度键 + 指标列
GCOL = {  # 粒度 token → (字段名, 类型, 注释)
    "seller_tenant_id": ("seller_tenant_id", "BIGINT", "卖家租户ID，关联 dim_sup_tenant_zip"),
    "supplier_tenant_id": ("supplier_tenant_id", "BIGINT", "供应商租户ID，关联 dim_sup_tenant_zip"),
    "distributor_tenant_id": ("distributor_tenant_id", "BIGINT", "分销商租户ID，关联 dim_sup_tenant_zip"),
    "sub_seller_tenant_id": ("sub_seller_tenant_id", "BIGINT", "套票子项卖家租户ID"),
    "tenant_id": ("tenant_id", "BIGINT", "租户ID，关联 dim_sup_tenant_zip"),
    "sku_id": ("sku_id", "BIGINT", "SKU ID，关联 dim_prd_sku_zip"),
    "combo_sku_id": ("combo_sku_id", "BIGINT", "套票主 SKU ID"), "sub_sku_id": ("sub_sku_id", "BIGINT", "套票子项 SKU ID"),
    "channel_id": ("channel_id", "BIGINT", "入口渠道ID，关联 dim_trf_channel_df"),
    "register_channel_id": ("register_channel_id", "BIGINT", "注册渠道ID，关联 dim_trf_channel_df"),
    "app_ref": ("app_ref_code", "STRING", "对接端引用"),
    "operator_type": ("operator_type", "STRING", "操作人类型：CUSTOMER/TENANT_STAFF"),
    "operator_id": ("operator_id", "BIGINT", "操作人ID"),
    "play_date": ("play_date", "STRING", "游玩日期，格式 yyyy-MM-dd"),
    "time_slot": ("time_slot_code", "STRING", "游玩时段，如 10:00-11:00"),
    "verify_point_id": ("verify_point_id", "BIGINT", "核销点ID，关联 dim_opr_verify_point_df"),
    "verify_type": ("verify_type", "STRING", "核销类型：ONLINE/OFFLINE"),
    "hour": ("stat_hour_no", "INT", "统计小时：0~23"),
    "refund_type": ("refund_type", "STRING", "退款类型：ORDER_REFUND/COMPENSATION/PARTIAL_REFUND"),
    "initiator_type": ("initiator_type", "STRING", "发起方：VISITOR/MERCHANT/PLATFORM/SYSTEM/OTA"),
    "refund_reason": ("refund_reason_desc", "STRING", "退款原因"),
    "entitlement_type": ("entitlement_type", "STRING", "权益类型：FIXED/COUNTED/SELECTABLE/TIMED/QUOTA/UNLIMITED"),
    "binding_type": ("binding_type", "STRING", "绑定方式：EXCLUSIVE/SHARED/OPEN"),
    "ticket_status": ("ticket_status", "STRING", "票状态：AVAILABLE/PARTIALLY_USED/USED/EXPIRED/REFUNDED/CANCELLED"),
    "valid_end_date": ("valid_end_date", "STRING", "有效期截止日期，格式 yyyy-MM-dd"),
    "buyer_customer_id": ("buyer_customer_id", "BIGINT", "买家游客ID，关联 dim_cus_customer_zip"),
    "origin_province": ("origin_province_code", "STRING", "客源省份编码"),
    "origin_city": ("origin_city_code", "STRING", "客源城市编码"),
    "age_band": ("age_band_code", "STRING", "年龄段：0_17-未成年，18_25-18~25岁，26_35-26~35岁，36_45-36~45岁，46_60-46~60岁，60_PLUS-60岁以上，UNKNOWN-未知"),
    "gender": ("gender_type", "STRING", "性别：MALE-男，FEMALE-女，UNKNOWN-未知"),
    "staff_id": ("staff_id", "BIGINT", "员工ID，关联 dim_sup_staff_zip"),
    "chain_level": ("chain_level_no", "INT", "分销链层级：1~4"),
    "relation_no": ("relation_no", "STRING", "分销关系编号"),
    "account_no": ("account_no", "STRING", "账户编号，关联 dim_fin_account_df"),
    "flow_type": ("flow_type", "STRING", "流水类型：RECHARGE/PAYMENT/REFUND/FREEZE/UNFREEZE/WITHDRAW/FEE/RESOURCE/TRANSFER_OUT/TRANSFER_IN"),
    "freeze_type": ("freeze_type", "STRING", "冻结类型：PROFIT/SETTLEMENT/FULL"),
    "external_frozen": ("external_frozen_type", "INT", "是否外部渠道冻结：0-否，1-是"),
    "pay_direction": ("pay_direction_type", "STRING", "资金方向：INBOUND/OUTBOUND"),
    "pay_method": ("pay_method_type", "STRING", "支付方式：BALANCE/WECHAT/ALIPAY/CREDIT/OFFLINE/ZERO_FEE"),
    "receive_channel": ("receive_channel_type", "STRING", "收款渠道：CASH/WECHAT_QR/ALIPAY_QR/BANK_TRANSFER/OFFLINE_SYSTEM_OUT"),
    "channel": ("price_channel_code", "STRING", "价格渠道编码"),
    "pool_no": ("pool_no", "STRING", "库存池编号，关联 dim_inv_pool_df"),
    "room_type": ("room_type_code", "STRING", "房型编码"), "show_time": ("show_time", "STRING", "场次时间"),
    "device_id": ("device_id", "BIGINT", "设备ID，关联 dim_opr_device_df"),
    "device_type": ("device_type", "STRING", "设备类型：GATE/POS/HANDHELD/SELF_SERVICE/KIOSK/FACE_RECOGNITION"),
    "rule_id": ("rule_id", "BIGINT", "风控规则ID，关联 dim_opr_risk_rule_df"),
    "action": ("action_type", "STRING", "处置动作：BLOCK/WARN/FREEZE"),
    "dimension": ("dimension_type", "STRING", "规则维度：USER_ID/ID_CARD/PHONE/IP/DEVICE_ID"),
    "complaint_type": ("complaint_type", "STRING", "投诉类型：ORDER_ISSUE/SERVICE_ISSUE/BUG/OTHER"), "complainant_type": ("complainant_type", "STRING", "投诉方：VISITOR/MERCHANT"),
    "notify_channel": ("notify_channel_type", "STRING", "通知渠道：SMS/MINI_PROGRAM_MSG/EMAIL/WEBHOOK/IN_APP"),
    "template_code": ("template_code", "STRING", "通知模板编码"),
    "flow_code": ("flow_code", "STRING", "审批流编码"),
    "package_id": ("package_id", "BIGINT", "套餐ID，关联 dim_opr_package_df"),
    "subscription_type": ("subscription_type", "STRING", "订购类型：NEW/RENEW/UPGRADE"),
    "country_code": ("country_code", "STRING", "国家编码"), "region_id": ("region_id", "BIGINT", "地区ID，关联 dim_opr_region_f"),
    "business_type": ("business_type", "STRING", "业态：SCENIC/HOTEL/SHOW/…"),
    "code_pool_id": ("code_pool_id", "BIGINT", "码池ID，关联 dim_opr_code_pool_df"),
    "pool_type": ("pool_type", "STRING", "码池类型：SINGLE_TICKET-单票码池，COMBO_TICKET-套票码池"),
    "rfm_segment": ("rfm_segment_code", "STRING", "RFM 分层：HIGH_VALUE-重要价值，HIGH_KEEP-重要保持，HIGH_DEVELOP-重要发展，HIGH_RETAIN-重要挽留，GENERAL-一般"),
    "tenant_lifecycle_stage": ("tenant_lifecycle_stage_code", "STRING", "租户生命周期：NEW-新入驻，ACTIVE-活跃，SILENT-沉默，CHURN-流失"),
}
GALIAS = {"stat_hour_no": ["stat_hour_no", "verify_hour_no"], "combo_sku_id": ["combo_sku_id", "sku_id"], "sub_sku_id": ["sub_sku_id", "sku_id"],
          "window_start_time": ["window_start_time", "event_time"], "window_end_time": ["window_end_time", "event_time"], "sub_seller_tenant_id": ["seller_tenant_id"],
          "staff_id": ["operator_id", "approver_id", "staff_id"], "tenant_id": ["tenant_id", "seller_tenant_id", "register_tenant_id"],
          "seller_tenant_id": ["seller_tenant_id", "tenant_id"], "business_type": ["business_type_list_desc"], "travel_date": ["travel_date", "event_time"],
          "register_channel_id": ["register_channel_id", "bind_channel_id"], "time_slot_code": ["time_slot_code"],
          "stat_week_code": [], "stat_month_code": []}
GDERIVE = {  # 无同名上游字段的粒度键：显式上游
    "rfm_segment_code": ("按 R=最近支付距今天数、F=累计支付子单数、M=累计支付金额 打分分层",
                         [["dws_cus_customer_lifetime_df", "last_pay_date"], ["dws_cus_customer_lifetime_df", "total_pay_order_qty"], ["dws_cus_customer_lifetime_df", "total_pay_amt"]]),
    "tenant_lifecycle_stage_code": ("按首单日期、最近支付日期、近30日支付金额判定阶段",
                                    [["dws_sup_tenant_lifetime_df", "first_pay_date"], ["dws_sup_tenant_lifetime_df", "last_pay_date"], ["dws_sup_tenant_lifetime_df", "pay_30d_amt"]]),
    "device_type": ("按 device_id 关联设备维度", [["dim_opr_device_df", "device_type"]]),
}
RT_GRAIN = {"dws_ord_tenant_sku_trade_rt": "seller_tenant_id × sku_id × channel_id × operator_type × 窗口",
            "dws_ord_tenant_sku_verify_rt": "seller_tenant_id × sku_id × 窗口", "dws_fin_account_fund_rt": "account_no",
            "dws_trf_distributor_credit_rt": "relation_no", "dws_cus_tenant_growth_rt": "tenant_id × register_channel_id × 窗口",
            "dws_opr_device_rt": "tenant_id × device_id", "dws_opr_notify_rt": "tenant_id × notify_channel × 窗口",
            "dws_opr_complaint_rt": "tenant_id × complaint_type", "dws_opr_code_pool_rt": "tenant_id × code_pool_id",
            "_old_trade": "seller_tenant_id × sku_id × 窗口", "dws_ord_verify_point_flow_rt": "seller_tenant_id × verify_point_id × 窗口",
            "dws_inv_sku_stock_rt": "sku_id × pool_no", "dws_opr_risk_rule_hit_rt": "rule_id × action × 窗口",
            "ads_ord_realtime_sales_rt": "seller_tenant_id × 窗口"}
NAME_COL = {"seller_tenant_id": ("seller_tenant_name", "卖家租户名称", "dim_sup_tenant_zip", "tenant_name"),
            "supplier_tenant_id": ("supplier_tenant_name", "供应商名称", "dim_sup_tenant_zip", "tenant_name"),
            "distributor_tenant_id": ("distributor_tenant_name", "分销商名称", "dim_sup_tenant_zip", "tenant_name"),
            "tenant_id": ("tenant_name", "租户名称", "dim_sup_tenant_zip", "tenant_name"),
            "sku_id": ("sku_name", "SKU 名称", "dim_prd_sku_zip", "sku_name"), "combo_sku_id": ("combo_sku_name", "套票名称", "dim_prd_sku_zip", "sku_name"),
            "sub_sku_id": ("sub_sku_name", "子项 SKU 名称", "dim_prd_sku_zip", "sku_name"),
            "verify_point_id": ("verify_point_name", "核销点名称", "dim_opr_verify_point_df", "verify_point_name"),
            "staff_id": ("staff_name", "员工姓名", "dim_sup_staff_zip", "staff_name"), "rule_id": ("rule_name", "规则名称", "dim_opr_risk_rule_df", "rule_name"),
            "package_id": ("package_name", "套餐名称", "dim_opr_package_df", "package_name"),
            "register_channel_id": ("register_channel_name", "注册渠道名称", "dim_trf_channel_df", "channel_name"),
            "code_pool_id": ("code_pool_no", "码池编号", "dim_opr_code_pool_df", "pool_no"),
            "origin_province_code": ("origin_province_name", "客源省份名称", "dim_opr_region_f", "province_name")}

def grain_tokens(short, grain):
    g = RT_GRAIN.get(short, grain)
    toks = [t for t in re.findall(r"[a-z][a-z_0-9]*", g) if t != "travel_date"]
    return toks, g

def grain_cols(short, grain, rt, period):
    toks, g = grain_tokens(short, grain)
    out = []
    if "窗口" in g:
        out += [col("window_start_time", "STRING", "窗口开始时间，格式 yyyy-MM-dd HH:mm:ss", "粒度键", "Flink 窗口"),
                col("window_end_time", "STRING", "窗口结束时间，格式 yyyy-MM-dd HH:mm:ss", "粒度键", "Flink 窗口")]
    if period == "wk":
        out += [col("stat_week_code", "STRING", "统计自然周，格式 YYYY-Www，如 2026-W46", "粒度键", "dim_opr_date_f.week_of_year_no", [["dim_opr_date_f", "week_of_year_no"]]),
                col("week_start_date", "STRING", "自然周开始日期（周一）", "粒度键", "dim_opr_date_f.week_start_date", [["dim_opr_date_f", "week_start_date"]])]
    if period == "mo":
        out += [col("stat_month_code", "STRING", "统计自然月，格式 YYYYMM", "粒度键", "dim_opr_date_f.month_no", [["dim_opr_date_f", "month_no"]])]
    for tk in toks:
        n, t, c = GCOL[tk]
        if n in GDERIVE:
            out.append(col(n, t, enrich(c), "粒度键", GDERIVE[n][0], GDERIVE[n][1]))
        else:
            out.append(col(n, t, enrich(c), "粒度键", "", []))
    if rt:
        out.insert(0, col("travel_date", "STRING", "数据日期，格式 YYYYMMDD", "粒度键", "事件时间取日期"))
    return out

def ddl_hive(name, cn, cols, part=True):
    w = max(len(c["n"]) for c in cols) + 1
    body = ",\n".join("    %s %s COMMENT '%s'" % (c["n"].ljust(w), c["t"].ljust(14), c["c"]) for c in cols)
    s = "CREATE TABLE IF NOT EXISTS %s (\n%s\n)\nCOMMENT '%s'\n" % (name, body, cn.replace("'", "’"))
    if part:
        s += "PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')\n"
    return s + "STORED AS ORC\nTBLPROPERTIES ('orc.compress' = 'SNAPPY');"

def ddl_flink_cdc(name, cn, cols, db, st, server_id):
    w = max(len(c["n"]) for c in cols) + 3
    body = []
    for c in cols:
        if c.get("meta"):
            body.append("    %s %s METADATA FROM '%s' VIRTUAL COMMENT '%s'" % (("`%s`" % c["n"]).ljust(w), c["t"], c["meta"], c["c"]))
        else:
            body.append("    %s %s COMMENT '%s'" % (("`%s`" % c["n"]).ljust(w), c["t"].ljust(16), c["c"]))
    body.append("    %s AS PROCTIME()" % "`proc_time`".ljust(w))
    body.append("    PRIMARY KEY (`id`) NOT ENFORCED")
    return ("-- Flink CDC 源表：直读 MySQL binlog（先全量快照、再增量），不经 Kafka\n"
            "CREATE TABLE %s (\n%s\n) COMMENT '%s'\nWITH (\n"
            "    'connector' = 'mysql-cdc',\n"
            "    'hostname' = '${mysql.%s.host}',\n    'port' = '${mysql.%s.port}',\n"
            "    'username' = '${cdc.username}',\n    'password' = '${cdc.password}',\n"
            "    'database-name' = '%s',\n    'table-name' = '%s',\n"
            "    'server-id' = '%s',\n    'server-time-zone' = 'Asia/Shanghai',\n"
            "    'scan.startup.mode' = 'initial',\n    'scan.incremental.snapshot.enabled' = 'true'\n);"
            ) % (name, ",\n".join(body), cn.replace("'", "’"), db, db, db, st, server_id)

def ddl_starrocks(name, cn, cols, keys):
    tmap = {c["n"]: c["t"] for c in cols}
    def tt(n):
        t = tmap[n]
        if t != "STRING":
            return t
        return "VARCHAR(32)" if n.endswith(("_date", "_time", "_code", "_no", "_type", "_status")) else "VARCHAR(256)"
    w = max(len(c["n"]) for c in cols) + 3
    body = ",\n".join("    %s %s %s COMMENT '%s'" % (("`%s`" % c["n"]).ljust(w), tt(c["n"]).ljust(14),
                                                       "NOT NULL" if c["n"] in keys else "NULL    ", c["c"]) for c in cols)
    k = ", ".join("`%s`" % x for x in keys)
    return ("-- StarRocks 主键模型（Flink 实时 upsert）\nCREATE TABLE IF NOT EXISTS %s (\n%s\n)\nPRIMARY KEY (%s)\nCOMMENT '%s'\n"
            "PARTITION BY (`travel_date`)\nDISTRIBUTED BY HASH(%s) BUCKETS 8\nPROPERTIES (\"replication_num\" = \"3\");") % (
        name, body, k, cn.replace("'", "’"), "`%s`" % next((x for x in keys if x.endswith(("_id", "_no"))), keys[0]))
