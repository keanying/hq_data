# -*- coding: utf-8 -*-
"""数仓模型 v2：在 build.py 基础数据上
1) DWD 补度量/退化维度  2) 补漏掉的原子/计算口径  3) 新增 DWS/ADS 表
4) ADS 按 周期×修饰词 生成具体业务指标（离线+实时）
"""
import os, re, runpy, io, contextlib
HERE = os.path.dirname(os.path.abspath(__file__))

with contextlib.redirect_stdout(io.StringIO()):
    ns = runpy.run_path(os.path.join(HERE, "base_data.py"))
ODS, DWD, DIM, DOMAIN = ns["ODS"], ns["DWD"], ns["DIM"], ns["DOMAIN"]
suffix_desc, part_of = ns["suffix_desc"], ns["part_of"]
ISSUES = [list(r) for r in ns["ISSUES"]]
A, D, C = "原子指标", "派生指标", "计算指标"

# ------------------------------------------------------------ 基础口径（DWS 层）
RENAME = {"entitlement_used_count": "entitlement_used_qty", "entitlement_total_count": "entitlement_total_qty",
          "channel_pay_amt_share": "channel_pay_share_rate", "pay_method_amt_share": "pay_method_share_rate",
          "tourist_origin_share": "tourist_origin_share_rate"}
BASE = []
for en, cn, tp, dom, kou, calc, unit, src in ns["M"]:
    if en == "sku_pay_amt_rank":
        continue
    en = RENAME.get(en, en)
    for o, n in RENAME.items():
        calc = calc.replace(o, n)
    BASE.append([en, cn, tp, dom, kou, calc, unit, src])

def upd(en, **kw):
    for b in BASE:
        if b[0] == en:
            for k, v in kw.items():
                b[["en", "cn", "tp", "dom", "kou", "calc", "unit", "src"].index(k)] = v

upd("approval_minute_qty", cn="审批总耗时", kou="已结束审批实例的耗时合计（分钟）", calc="sum(minutes(end_time - create_time)) where 已结束")
upd("advance_book_day_qty", cn="提前预订天数合计", kou="每张支付票的（游玩日 − 支付日）合计", calc="sum(datediff(play_date, pay_date) * buy_ticket_qty)")
upd("channel_pay_share_rate", calc="pay_amt / total(pay_amt)")
upd("pay_method_share_rate", calc="inbound_pay_amt / total(inbound_pay_amt)")
upd("tourist_origin_share_rate", calc="tourist_qty / total(tourist_qty)")
upd("avg_advance_book_day_qty", calc="advance_book_day_qty / pay_ticket_qty")
upd("device_online_rate", calc="online_minute_qty / (1440 × 统计天数 × device_total_qty)")
upd("verify_rate", calc="verify_ticket_qty / pay_ticket_qty", kou="支付票中已核销的比例（按支付日 cohort）")

NEW = [
    # 交易 · 毛利 / 时效 / 取消
    ("pay_order_group_qty", "支付聚合单数", A, "ord", "统计周期内支付成功的聚合单数", "count(distinct order_group_no) where pay_status='PAID'", "单", "dwd_ord_order_group_di"),
    ("cost_amt", "成本金额", A, "ord", "支付子单按下单时 SKU 版本成本价 × 数量", "sum(cost_price_amt * buy_ticket_qty) of paid orders", "元", "dwd_ord_order_di"),
    ("pay_minute_qty", "下单到支付总时长", A, "ord", "支付子单从创建到支付的分钟数合计", "sum(minutes(pay_time - create_time))", "分钟", "dwd_ord_order_status_log_di"),
    ("timeout_cancel_order_qty", "超时取消子单数", A, "ord", "因支付超时（PAY_TIMEOUT）取消的子单数", "count(order_no) where after_status='CANCELLED' and reason='PAY_TIMEOUT'", "单", "dwd_ord_order_status_log_di"),
    ("refund_process_hour_qty", "退款处理总时长", A, "ord", "已完成退款单从申请到完成的小时数合计", "sum(hours(complete_time - create_time))", "小时", "dwd_ord_refund_di"),
    ("auto_approve_refund_qty", "超时自动通过退款单数", A, "ord", "审核超过 48 小时自动通过的退款单数", "count(refund_no) where approve_type='AUTO_TIMEOUT'", "单", "dwd_ord_refund_di"),
    ("refund_reject_qty", "退款驳回单数", A, "ord", "状态为 REJECTED 的退款单数", "count(refund_no) where refund_status='REJECTED'", "单", "dwd_ord_refund_di"),
    ("verified_refund_ticket_qty", "核销后退款票数", A, "ord", "退款时票状态为 PARTIALLY_USED/USED 的票数", "count(ticket_no) where ticket_status_at_refund in ('PARTIALLY_USED','USED')", "张", "dwd_ord_refund_ticket_di"),
    ("verify_after_pay_day_qty", "支付到首次核销天数合计", A, "ord", "首次核销日 − 支付日，按票合计", "sum(datediff(first_verify_date, pay_date))", "天", "dwd_ord_verify_di"),
    ("activate_ticket_qty", "激活票数", A, "ord", "延迟激活类票（年卡/入园后N天有效）首次核销回填有效期起始的票数", "count(ticket_no) where valid_start 由默认值变为实际时间", "张", "dwd_ord_ticket_status_log_di"),
    ("activate_delay_day_qty", "激活延迟天数合计", A, "ord", "激活日 − 支付日，按票合计", "sum(datediff(activate_date, pay_date))", "天", "dwd_ord_ticket_status_log_di"),
    ("pending_activate_ticket_qty", "待激活票数", A, "ord", "快照日仍未激活的延迟激活类票数", "count(ticket_no) where 延迟激活 and valid_start='1970-01-01'", "张", "dwd_ord_ticket_di"),
    ("duplicate_verify_qty", "重复核销次数", A, "ord", "核销结果为 DUPLICATE 的次数", "count(verify_no) where verify_result='DUPLICATE'", "次", "dwd_ord_verify_di"),
    ("offline_conflict_qty", "离线核销冲突次数", A, "ord", "离线核销回连后仲裁为 DUPLICATE 的次数", "count(verify_no) where verify_type='OFFLINE' and verify_result='DUPLICATE'", "次", "dwd_ord_verify_di"),
    ("person_linked_qty", "已关联会员的游客数", A, "cus", "票上游客 global_customer_id>0 的人数", "count(*) where global_customer_id>0", "人", "dwd_ord_ticket_person_di"),
    # 游客增长
    ("first_pay_customer_qty", "首单买家数", A, "cus", "统计周期内首次支付的真实买家数", "count(buyer) where first_pay_date in 周期", "人", "dws_cus_customer_lifetime_df"),
    ("repeat_buyer_qty", "老客买家数", A, "cus", "统计周期内支付且此前已有支付的买家数", "count(buyer) where first_pay_date < 周期起始", "人", "dws_cus_customer_lifetime_df"),
    ("register_pay_customer_qty", "注册当期下单新客数", A, "cus", "统计周期内注册且在同周期内支付的游客数", "count(customer) where register_date and first_pay_date in 周期", "人", "dwd_cus_customer_register_di"),
    ("certified_customer_qty", "新增实名认证游客数", A, "cus", "认证状态变为 PERSON_CERTIFIED 的游客数", "count(customer) where auth_status 变为 PERSON_CERTIFIED", "人", "dim_cus_customer_zip"),
    ("face_register_qty", "人脸注册数", A, "cus", "新增 FACE 类型个人凭证数", "count(credential_no) where credential_type='FACE'", "个", "dwd_cus_credential_register_di"),
    # 商户
    ("tenant_cert_apply_qty", "提交认证商户数", A, "sup", "认证状态变为 PENDING_REVIEW 的租户数", "count(tenant) where auth_status 变为 PENDING_REVIEW", "家", "dim_sup_tenant_zip"),
    ("tenant_cert_pass_qty", "认证通过商户数", A, "sup", "认证状态变为 CERTIFIED 的租户数", "count(tenant) where auth_status 变为 CERTIFIED", "家", "dim_sup_tenant_zip"),
    ("sold_sku_qty", "动销SKU数", A, "prd", "统计周期内有支付的 SKU 数", "count(distinct sku_id) where pay_amt>0", "个", "dws_ord_tenant_sku_channel_trade_di"),
    # 分销
    ("chain_level_qty", "分销层级合计", A, "trf", "分销票所在最大层级合计（求平均层级用）", "sum(max(chain_level)) by ticket", "级", "dwd_trf_distribution_settle_di"),
    ("new_distribution_relation_qty", "新建分销关系数", A, "trf", "统计周期内新建的分销关系数", "count(relation_no) where create_date in 周期", "条", "dim_trf_distribution_relation_zip"),
    # 财务
    ("credit_pay_amt", "授信支付金额", A, "fin", "pay_method=CREDIT 的已支付金额", "sum(amount) where pay_method='CREDIT' and PAID", "元", "dwd_fin_payment_di"),
    ("external_freeze_amt", "外部渠道冻结金额", A, "fin", "external_frozen=1 的冻结金额", "sum(amount) where external_frozen=1", "元", "dwd_fin_frozen_di"),
    ("expire_release_amt", "过期兜底释放金额", A, "fin", "票过期 30 天后由定时任务释放的冻结金额", "sum(amount) where release_reason='EXPIRE_TIMEOUT'", "元", "dwd_fin_frozen_di"),
    ("fee_amt", "手续费金额", A, "fin", "flow_type=FEE 的流水金额", "sum(-amount) where flow_type='FEE'", "元", "dwd_fin_fund_flow_di"),
    ("withdraw_apply_amt", "提现申请金额", A, "fin", "统计周期内发起的提现金额", "sum(withdraw_amount)", "元", "dwd_fin_withdraw_di"),
    ("withdraw_fail_qty", "提现失败笔数", A, "fin", "状态 FAILED/REJECTED 的提现单数", "count(withdraw_no) where status in ('FAILED','REJECTED')", "笔", "dwd_fin_withdraw_di"),
    ("invoice_amt", "开票金额", A, "fin", "状态 INVOICED 的发票金额", "sum(invoice_amount) where INVOICED", "元", "dwd_fin_invoice_di"),
    ("invoice_order_qty", "开票订单数", A, "fin", "已开票的聚合单数（商户给游客）", "count(distinct order_group_no) where INVOICED and subject='MERCHANT_TO_VISITOR'", "单", "dwd_fin_invoice_di"),
    # 库存
    ("prededuct_qty", "预扣量", A, "inv", "下单预扣的库存数量", "sum(frozen_change_qty) where change_type='PRE_DEDUCT'", "个", "dwd_inv_pool_change_di"),
    ("prededuct_confirm_qty", "预扣确认量", A, "inv", "预扣转正式扣减的数量", "sum(qty) where change_type='CONFIRM'", "个", "dwd_inv_pool_change_di"),
    ("prededuct_release_qty", "预扣释放量", A, "inv", "取消/超时释放的预扣数量", "sum(qty) where change_type='ROLLBACK' and 来源为预扣", "个", "dwd_inv_pool_change_di"),
    # 运营
    ("code_capacity_qty", "码池容量", A, "opr", "码池最大并发码数", "sum(capacity)", "个", "dim_opr_code_pool_df"),
    ("code_allocated_qty", "已分配码数", A, "opr", "码池已分配码数", "sum(allocated_count)", "个", "dim_opr_code_pool_df"),
    ("code_recycled_qty", "回收复用码数", A, "opr", "码池已回收复用码数", "sum(recycled_count)", "个", "dim_opr_code_pool_df"),
    ("device_total_qty", "设备数", A, "opr", "状态非 INACTIVE 的设备数", "count(device_id)", "台", "dim_opr_device_df"),
    ("approval_timeout_qty", "审批超时数", A, "opr", "超过节点截止时间的审批实例数", "count(instance_no) where 完成时间>timeout_at", "个", "dwd_opr_approval_di"),
    ("notify_fail_qty", "通知失败数", A, "opr", "send_status=FAILED 的记录数", "count where FAILED", "条", "dwd_opr_notify_di"),
    # 计算口径
    ("gross_profit_amt", "毛利额", C, "ord", "支付金额 − 成本金额（支付口径，未扣退款）", "pay_amt - cost_amt", "元", "dws_sup_tenant_trade_di"),
    ("gross_profit_rate", "毛利率", C, "ord", "毛利额 / 支付金额", "gross_profit_amt / pay_amt", "%", "dws_sup_tenant_trade_di"),
    ("avg_pay_minute_qty", "平均支付时长", C, "ord", "下单到支付总时长 / 支付子单数", "pay_minute_qty / pay_order_qty", "分钟", "dws_ord_tenant_sku_channel_trade_di"),
    ("timeout_cancel_rate", "超时取消率", C, "ord", "超时取消子单数 / 下单子单数", "timeout_cancel_order_qty / order_qty", "%", "dws_ord_tenant_sku_channel_trade_di"),
    ("avg_refund_process_hour_qty", "平均退款处理时长", C, "ord", "退款处理总时长 / 退款完成单数", "refund_process_hour_qty / refund_success_qty", "小时", "dws_ord_tenant_refund_di"),
    ("avg_verify_after_pay_day_qty", "平均支付到核销天数", C, "ord", "支付到首次核销天数合计 / 核销票数", "verify_after_pay_day_qty / verify_ticket_qty", "天", "dws_ord_tenant_sku_verify_di"),
    ("avg_activate_delay_day_qty", "平均激活延迟天数", C, "ord", "激活延迟天数合计 / 激活票数", "activate_delay_day_qty / activate_ticket_qty", "天", "dws_ord_tenant_entitlement_di"),
    ("activate_rate", "激活率", C, "ord", "激活票数 /（激活票数 + 待激活票数）", "activate_ticket_qty / (activate_ticket_qty + pending_activate_ticket_qty)", "%", "dws_ord_tenant_entitlement_di"),
    ("person_link_rate", "游客会员关联率", C, "cus", "已关联会员的游客数 / 游客人数", "person_linked_qty / tourist_qty", "%", "dws_cus_tourist_origin_di"),
    ("new_buyer_share_rate", "新客占比", C, "cus", "首单买家数 / 支付买家数", "first_pay_customer_qty / pay_buyer_qty", "%", "dws_cus_tenant_growth_di"),
    ("register_pay_conversion_rate", "注册下单转化率", C, "cus", "注册当期下单新客数 / 新注册游客数", "register_pay_customer_qty / new_customer_qty", "%", "dws_cus_tenant_growth_di"),
    ("face_register_rate", "人脸注册率", C, "cus", "人脸注册数 / 新注册游客数", "face_register_qty / new_customer_qty", "%", "dws_cus_tenant_growth_di"),
    ("tenant_cert_pass_rate", "商户认证通过率", C, "sup", "认证通过商户数 / 提交认证商户数", "tenant_cert_pass_qty / tenant_cert_apply_qty", "%", "dws_sup_tenant_onboard_di"),
    ("sku_sell_rate", "SKU动销率", C, "prd", "动销SKU数 / 在售SKU数", "sold_sku_qty / on_sale_sku_qty", "%", "dws_sup_tenant_trade_di"),
    ("avg_chain_level_qty", "平均分销层级", C, "trf", "分销层级合计 / 分销票数", "chain_level_qty / distribution_ticket_qty", "级", "dws_trf_distributor_trade_di"),
    ("external_freeze_rate", "外部冻结占比", C, "fin", "外部渠道冻结金额 / 冻结金额", "external_freeze_amt / freeze_amt", "%", "dws_fin_account_frozen_di"),
    ("invoice_rate", "开票率", C, "fin", "开票订单数 / 支付聚合单数", "invoice_order_qty / pay_order_group_qty", "%", "dws_fin_tenant_pay_method_di"),
    ("withdraw_success_rate", "提现成功率", C, "fin", "提现成功金额 / 提现申请金额", "withdraw_success_amt / withdraw_apply_amt", "%", "dws_fin_account_flow_di"),
    ("prededuct_convert_rate", "预扣转化率", C, "inv", "预扣确认量 / 预扣量", "prededuct_confirm_qty / prededuct_qty", "%", "dws_inv_sku_stock_df"),
    ("code_pool_usage_rate", "码池使用率", C, "opr", "已分配码数 / 码池容量", "code_allocated_qty / code_capacity_qty", "%", "dws_opr_code_pool_df"),
    ("code_recycle_rate", "码回收复用率", C, "opr", "回收复用码数 / 已分配码数", "code_recycled_qty / code_allocated_qty", "%", "dws_opr_code_pool_df"),
    ("approval_pass_rate", "审批通过率", C, "opr", "审批通过数 / 审批发起数", "approval_pass_qty / approval_qty", "%", "dws_opr_approval_di"),
    ("avg_approval_minute_qty", "平均审批耗时", C, "opr", "审批总耗时 /（通过数 + 拒绝数）", "approval_minute_qty / (approval_pass_qty + approval_reject_qty)", "分钟", "dws_opr_approval_di"),
]
BASE += [list(x) for x in NEW]
BNAME = {b[0]: b for b in BASE}
assert len(BNAME) == len(BASE)

# ------------------------------------------------------------ DWD 度量 / 退化维度
DWD_MD = {
    "dwd_ord_order_group_di": ("total_amt", "order_group_no、app_ref、contact_phone（脱敏）"),
    "dwd_ord_order_di": ("buy_ticket_qty、unit_price_amt、order_amt、cost_price_amt", "order_no、order_group_no、parent_order_no、play_date、time_slot、seat_zone（sale_dims 展开）"),
    "dwd_ord_order_status_log_di": ("status_change_qty、stay_minute_qty（状态停留时长）", "order_no、before_status、after_status、change_reason"),
    "dwd_ord_ticket_di": ("ticket_qty、unit_price_amt（分摊）", "ticket_no、order_no、seat_no、cabin_no、schedule_time（metadata 展开）"),
    "dwd_ord_ticket_status_log_di": ("status_change_qty", "ticket_no、before_status、after_status"),
    "dwd_ord_ticket_person_di": ("person_qty", "ticket_no、person_id、id_number（脱敏）、age、origin_city_code"),
    "dwd_ord_entitlement_di": ("max_qty、used_qty、quota_amt、duration_minute_qty", "entitlement_no、ticket_no、project_id"),
    "dwd_ord_entitlement_binding_di": ("无（无事实事实表）", "ticket_no、person_id、entitlement_no"),
    "dwd_ord_ticket_credential_di": ("credential_qty", "credential_no、code_value（脱敏）"),
    "dwd_ord_verify_di": ("verify_qty、verify_amt", "verify_no、ticket_no、entitlement_no、offline_timestamp"),
    "dwd_ord_refund_di": ("refund_amt、process_hour_qty", "refund_no、order_group_no、refund_reason"),
    "dwd_ord_refund_ticket_di": ("refund_ticket_qty、refund_amt", "refund_no、order_no、ticket_no"),
    "dwd_fin_payment_di": ("pay_amt、settle_amt、profit_amt", "payment_no、batch_no、item_no、depend_on_item、transaction_no"),
    "dwd_fin_refund_payment_di": ("refund_amt", "refund_detail_no、payment_no、refund_transaction_no"),
    "dwd_fin_frozen_di": ("freeze_amt", "frozen_no、ticket_no、external_frozen_no"),
    "dwd_fin_fund_flow_di": ("change_amt、balance_before_amt、balance_after_amt", "flow_no、related_no、payment_batch_no、fee_item"),
    "dwd_fin_withdraw_di": ("withdraw_amt", "withdraw_no、approval_no、transaction_no"),
    "dwd_fin_invoice_di": ("invoice_amt", "invoice_no、order_group_no"),
    "dwd_fin_resource_batch_di": ("total_qty、remaining_qty、consume_qty", "batch_no、purchase_no"),
    "dwd_trf_distribution_settle_di": ("sale_amt、settle_amt、profit_amt", "ticket_no、batch_no、item_no"),
    "dwd_prd_sku_version_di": ("old_price_amt、new_price_amt", "snapshot_no、version"),
    "dwd_prd_price_point_log_di": ("before_price_amt、after_price_amt", "price_no、ext_dims"),
    "dwd_prd_sku_price_calendar_df": ("list_price_amt", "hit_price_no、ext_dims"),
    "dwd_inv_pool_change_di": ("total_change_qty、available_change_qty、frozen_change_qty", "pool_no、order_no、dimension_key"),
    "dwd_inv_unit_change_di": ("unit_change_qty", "unit_no、order_no"),
    "dwd_inv_pool_snapshot_df": ("total_qty、available_qty、frozen_qty", "pool_no、dimension_key"),
    "dwd_cus_customer_register_di": ("register_qty", "customer_no"),
    "dwd_cus_identity_bind_di": ("bind_qty", "identity_value（脱敏）"),
    "dwd_cus_credential_register_di": ("register_qty", "credential_no"),
    "dwd_opr_risk_event_di": ("event_qty", "event_no、audit_log_id、dimension_values"),
    "dwd_opr_blacklist_log_di": ("change_qty", "blacklist_no、dimension_value（脱敏）"),
    "dwd_opr_account_ban_di": ("ban_qty、ban_hour_qty", "ban_no"),
    "dwd_opr_approval_di": ("approval_qty、approval_minute_qty", "instance_no、business_no"),
    "dwd_opr_complaint_di": ("complaint_qty、resolve_hour_qty", "complaint_no、order_group_no"),
    "dwd_opr_notify_di": ("notify_qty", "notify_no、related_business_no"),
    "dwd_opr_audit_log_di": ("action_qty", "log_no、resource_id、ip_address"),
    "dwd_opr_device_status_log_di": ("status_minute_qty", "device_no"),
    "dwd_opr_package_subscription_di": ("package_amt、duration_day_qty", "subscription_no"),
}
assert set(DWD_MD) == {d[0] for d in DWD}
DWD_MD["dwd_ord_entitlement_binding_di"] = ("无（无事实的事实表，只记绑定关系）", DWD_MD["dwd_ord_entitlement_binding_di"][1])

# ------------------------------------------------------------ DWS（v2）
DWS = [list(t) for t in ns["DWS"]]
def dws_add(name, metrics, src_add=None):
    for t in DWS:
        if t[0] == name:
            t[4] = list(t[4]) + [m for m in metrics if m not in t[4]]
            if src_add:
                t[3] += ", " + src_add
            return
    raise KeyError(name)
for t in DWS:
    t[4] = [RENAME.get(m, m) for m in t[4]]
dws_add("dws_ord_tenant_sku_channel_trade_di", ["pay_order_group_qty", "cost_amt", "pay_minute_qty", "timeout_cancel_order_qty", "advance_book_day_qty"])
dws_add("dws_ord_tenant_sku_verify_di", ["duplicate_verify_qty", "offline_conflict_qty", "verify_after_pay_day_qty"])
dws_add("dws_ord_verify_point_flow_hrs", ["verify_entitlement_qty"])
dws_add("dws_ord_tenant_refund_di", ["refund_process_hour_qty", "auto_approve_refund_qty", "refund_reject_qty", "verified_refund_ticket_qty"])
dws_add("dws_ord_tenant_entitlement_di", ["activate_ticket_qty", "activate_delay_day_qty", "pending_activate_ticket_qty"], "dwd_ord_ticket_status_log_di")
dws_add("dws_ord_tenant_ticket_stock_df", ["pending_activate_ticket_qty", "issue_ticket_qty", "pay_ticket_qty", "verify_ticket_qty"])
dws_add("dws_ord_combo_sku_trade_di", ["pay_ticket_qty"])
dws_add("dws_cus_tourist_origin_di", ["person_linked_qty", "realname_ticket_qty", "issue_ticket_qty"], "dwd_ord_ticket_di")
dws_add("dws_cus_customer_lifetime_df", ["pay_buyer_qty", "repeat_buyer_qty"])
dws_add("dws_sup_tenant_trade_di", ["cost_amt", "sold_sku_qty", "first_pay_customer_qty", "pay_order_group_qty", "refund_ticket_qty", "order_qty", "pay_conversion_rate"], "dws_cus_customer_lifetime_df")
dws_add("dws_sup_tenant_lifetime_df", ["active_tenant_qty"])
dws_add("dws_trf_distributor_trade_di", ["chain_level_qty", "active_distributor_qty"])
dws_add("dws_trf_distributor_credit_df", ["new_distribution_relation_qty"])
dws_add("dws_fin_account_flow_di", ["fee_amt", "withdraw_apply_amt", "withdraw_success_amt", "withdraw_fail_qty"], "dwd_fin_withdraw_di")
dws_add("dws_fin_account_frozen_di", ["external_freeze_amt", "expire_release_amt"])
dws_add("dws_fin_tenant_pay_method_di", ["credit_pay_amt", "invoice_amt", "invoice_order_qty", "pay_order_group_qty"], "dwd_fin_invoice_di")
dws_add("dws_prd_sku_price_di", ["pay_amt", "pay_ticket_qty"])
dws_add("dws_inv_sku_stock_df", ["prededuct_qty", "prededuct_confirm_qty", "prededuct_release_qty"])
dws_add("dws_opr_device_di", ["device_total_qty", "offline_verify_qty"])
dws_add("dws_opr_approval_di", ["approval_timeout_qty"])
dws_add("dws_opr_notify_di", ["notify_fail_qty", "resource_consume_qty"], "dwd_fin_resource_batch_di")
dws_add("dws_ord_tenant_sku_channel_trade_di", ["pay_buyer_qty"])
DWS += [
    ["dws_cus_tenant_growth_di", "商户×注册渠道 游客增长日汇总", "travel_date × tenant_id × register_channel_id",
     "dwd_cus_customer_register_di, dwd_cus_credential_register_di, dim_cus_customer_zip, dws_cus_customer_lifetime_df",
     ["new_customer_qty", "certified_customer_qty", "face_register_qty", "first_pay_customer_qty", "register_pay_customer_qty", "repeat_buyer_qty", "pay_buyer_qty"]],
    ["dws_sup_tenant_onboard_di", "平台×地区×业态 商户入驻日汇总", "travel_date × country_code × region_id × business_type",
     "dim_sup_tenant_zip", ["new_tenant_qty", "tenant_cert_apply_qty", "tenant_cert_pass_qty"]],
    ["dws_opr_code_pool_df", "码池使用快照", "travel_date × tenant_id × code_pool_id × pool_type",
     "dim_opr_code_pool_df, dwd_ord_ticket_credential_di", ["code_capacity_qty", "code_allocated_qty", "code_recycled_qty", "issue_credential_qty", "revoke_credential_qty"]],
]

# ------------------------------------------------------------ 周期 / 修饰词
D5 = [("1d", "当日"), ("7d", "近7日"), ("30d", "近30日"), ("mtd", "本月累计"), ("ytd", "本年累计")]
D3 = [("1d", "当日"), ("7d", "近7日"), ("30d", "近30日")]
P1 = [("1d", "当日")]
S = [("td", "截至当日")]
H = [("1h", "当小时")]
W = [("1w", "本周")]
MO = [("1m", "本月")]
P30 = [("30d", "近30日")]
P90 = [("90d", "近90日")]
YTD = [("ytd", "本年累计")]
RT3 = [("today", "今日实时"), ("1h", "近1小时"), ("5m", "近5分钟")]
TODAY = [("today", "今日实时")]
NOW = [("now", "当前")]
M5 = [("5m", "近5分钟")]
NOP = None  # 不加周期（同比/环比/峰值等本身已含周期）

CH = [("mp", "小程序"), ("h5", "H5"), ("pc", "PC后台代下"), ("offline", "线下窗口"), ("api", "OTA/API")]
PM = [("wechat", "微信"), ("alipay", "支付宝"), ("balance", "余额"), ("credit", "授信"), ("offline", "线下收款")]
ET = [("fixed", "固定型"), ("selectable", "选择型"), ("counted", "计次型"), ("timed", "计时型"), ("unlimited", "不限次型"), ("quota", "额度型")]
INIT = [("visitor", "游客发起"), ("merchant", "商户发起"), ("ota", "OTA发起"), ("system", "系统发起")]
CL = [("l1", "一级"), ("l2", "二级"), ("l3", "三级"), ("l4", "四级")]
FT = [("profit", "利润冻结"), ("settlement", "采购款冻结"), ("full", "全款冻结")]
NC = [("sms", "短信"), ("mini", "小程序消息"), ("email", "邮件"), ("webhook", "Webhook")]
MOD_DESC = {"CH": "渠道类型（由 t_channel.channel_type + operator_type 归类）", "PM": "支付方式", "ET": "权益类型",
            "INIT": "退款发起方", "CL": "分销层级", "FT": "冻结类型", "NC": "通知渠道"}
MODS = {"CH": CH, "PM": PM, "ET": ET, "INIT": INIT, "CL": CL, "FT": FT, "NC": NC}

# ADS: 表名, 中文名, 分析粒度, 来源DWS, 使用端, [(指标列表, 周期, 修饰词组)]
ADS = [
    ("ads_ord_tenant_trade_overview_di", "商户经营概览", "travel_date × seller_tenant_id", "dws_sup_tenant_trade_di", "商户后台", [
        (["pay_amt", "net_pay_amt", "pay_order_qty", "pay_ticket_qty", "pay_buyer_qty", "verify_ticket_qty", "verify_amt", "refund_amt", "cost_amt", "gross_profit_amt"], D5, None),
        (["per_customer_amt", "avg_ticket_price_amt", "verify_rate", "refund_rate", "gross_profit_rate", "pay_conversion_rate"], D3, None),
        (["pay_amt_dod_rate", "pay_amt_wow_rate"], NOP, None)]),
    ("ads_ord_sku_sales_rank_di", "SKU销售排行", "travel_date × seller_tenant_id × sku_id", "dws_ord_tenant_sku_channel_trade_di, dws_ord_tenant_refund_di", "商户后台", [
        (["pay_amt", "pay_ticket_qty", "net_pay_amt", "gross_profit_amt", "refund_ticket_qty", "avg_ticket_price_amt", "gross_profit_rate", "pay_conversion_rate", "refund_rate"], D3, None)]),
    ("ads_ord_channel_sales_structure_di", "渠道销售结构", "travel_date × seller_tenant_id", "dws_ord_tenant_sku_channel_trade_di", "商户后台", [
        (["pay_amt", "pay_ticket_qty", "pay_order_qty", "channel_pay_share_rate"], D3, "CH"),
        (["staff_order_qty", "staff_pay_amt"], D3, None)]),
    ("ads_ord_verify_flow_hrs", "分时客流（入园人次）", "travel_date × hour × seller_tenant_id × verify_point_id", "dws_ord_verify_point_flow_hrs", "商户后台/大屏", [
        (["verify_person_qty", "verify_fail_qty", "verify_fail_rate"], H, None),
        (["verify_person_qty"], D3, None),
        (["peak_hour_verify_qty"], NOP, None)]),
    ("ads_ord_play_date_booking_df", "未来游玩日预订看板", "travel_date × sku_id × play_date", "dws_ord_sku_play_date_booking_df, dws_inv_sku_stock_df", "商户后台", [
        (["pay_ticket_qty", "refund_ticket_qty", "net_pay_ticket_qty", "stock_available_qty", "stock_sell_through_rate", "avg_advance_book_day_qty"], S, None)]),
    ("ads_ord_refund_analysis_di", "退款分析", "travel_date × seller_tenant_id × refund_reason", "dws_ord_tenant_refund_di, dws_sup_tenant_trade_di", "商户后台", [
        (["refund_apply_qty", "refund_success_qty", "refund_ticket_qty", "refund_amt", "refund_reject_qty", "auto_approve_refund_qty", "verified_refund_ticket_qty", "refund_rate", "refund_amt_rate", "cancel_rate", "timeout_cancel_rate"], D3, None),
        (["refund_ticket_qty", "refund_amt"], D3, "INIT")]),
    ("ads_ord_entitlement_usage_di", "权益使用分析（年卡/次卡/计时/额度）", "travel_date × seller_tenant_id × sku_id", "dws_ord_tenant_entitlement_di, dws_ord_tenant_ticket_stock_df", "商户后台", [
        (["entitlement_used_qty", "entitlement_usage_rate"], D3, "ET"),
        (["activate_ticket_qty", "activate_rate", "avg_activate_delay_day_qty", "expire_ticket_qty", "expire_rate"], D3, None),
        (["unverified_ticket_qty", "unverified_amt", "pending_activate_ticket_qty", "quota_total_amt"], S, None)]),
    ("ads_ord_trade_efficiency_di", "交易时效分析", "travel_date × seller_tenant_id × sku_id", "dws_ord_tenant_sku_channel_trade_di, dws_ord_tenant_refund_di, dws_ord_tenant_sku_verify_di", "商户后台", [
        (["avg_pay_minute_qty", "avg_refund_process_hour_qty", "avg_verify_after_pay_day_qty", "avg_advance_book_day_qty", "timeout_cancel_order_qty"], D3, None)]),
    ("ads_cus_tourist_portrait_di", "游客客源画像", "travel_date × seller_tenant_id × origin_province × age_band × gender", "dws_cus_tourist_origin_di", "商户后台", [
        (["tourist_qty", "verify_person_qty", "tourist_origin_share_rate", "realname_rate", "person_link_rate"], D3, None)]),
    ("ads_cus_customer_rfm_df", "会员RFM与复购", "travel_date × seller_tenant_id × rfm_segment", "dws_cus_customer_lifetime_df", "商户后台", [
        (["pay_buyer_qty", "repeat_buyer_qty", "repurchase_rate", "per_customer_amt"], P30, None),
        (["pay_buyer_qty", "repeat_buyer_qty", "repurchase_rate", "per_customer_amt"], P90, None)]),
    ("ads_cus_customer_growth_di", "游客增长", "travel_date × tenant_id × register_channel_id", "dws_cus_tenant_growth_di", "商户/平台", [
        (["new_customer_qty", "first_pay_customer_qty", "face_register_qty", "certified_customer_qty"], D5, None),
        (["register_pay_conversion_rate", "new_buyer_share_rate", "face_register_rate", "repeat_buyer_qty"], D3, None)]),
    ("ads_inv_stock_sellout_df", "库存售罄与上座率", "travel_date × sku_id × play_date", "dws_inv_sku_stock_df", "商户后台", [
        (["stock_total_qty", "stock_available_qty", "stock_frozen_qty", "stock_sold_qty", "sellout_pool_qty", "stock_sell_through_rate", "stock_sellout_rate", "unit_occupied_qty"], S, None),
        (["prededuct_qty", "prededuct_release_qty", "prededuct_convert_rate"], D3, None)]),
    ("ads_prd_price_discount_di", "价格与折扣分析", "travel_date × sku_id × channel", "dws_prd_sku_price_di", "商户后台", [
        (["list_price_amt"], P1, None),
        (["avg_deal_price_amt", "discount_rate", "price_change_qty"], D3, None)]),
    ("ads_trf_distributor_rank_di", "分销商业绩排行", "travel_date × supplier_tenant_id × distributor_tenant_id", "dws_trf_distributor_trade_di, dws_trf_distributor_credit_df", "供应商后台", [
        (["distribution_ticket_qty", "distribution_sale_amt", "distribution_profit_amt", "distribution_profit_rate", "active_distributor_qty", "new_distribution_relation_qty"], D3, None)]),
    ("ads_trf_chain_profit_di", "分销链利润分配", "travel_date × supplier_tenant_id × sku_id", "dws_trf_distributor_trade_di", "供应商/平台", [
        (["distribution_purchase_amt", "distribution_profit_amt", "distribution_profit_rate"], D3, "CL"),
        (["avg_chain_level_qty"], D3, None)]),
    ("ads_fin_tenant_settlement_di", "商户结算对账", "travel_date × tenant_id", "dws_fin_account_frozen_di, dws_fin_account_flow_di, dws_fin_tenant_pay_method_di", "商户后台/财务", [
        (["inbound_pay_amt", "outbound_pay_amt", "refund_payment_amt", "freeze_amt", "unfreeze_verify_amt", "unfreeze_refund_amt", "fee_amt"], D5, None),
        (["freeze_amt"], D3, "FT"),
        (["external_freeze_amt", "external_freeze_rate", "expire_release_amt", "invoice_amt", "invoice_order_qty", "invoice_rate"], D3, None)]),
    ("ads_fin_account_fund_df", "账户资金看板", "travel_date × account_no", "dws_fin_account_balance_df, dws_trf_distributor_credit_df, dws_fin_account_flow_di", "商户后台/财务", [
        (["available_balance_amt", "frozen_balance_amt", "credit_limit_amt", "credit_used_amt", "credit_usage_rate"], S, None),
        (["withdraw_apply_amt", "withdraw_success_amt"], D5, None),
        (["withdraw_fail_qty", "withdraw_success_rate"], D3, None)]),
    ("ads_fin_pay_method_di", "支付方式结构", "travel_date × tenant_id", "dws_fin_tenant_pay_method_di", "商户后台/财务", [
        (["inbound_pay_amt", "pay_record_qty", "pay_method_share_rate"], D3, "PM"),
        (["zero_fee_order_qty"], D3, None)]),
    ("ads_sup_staff_performance_di", "员工/窗口业绩", "travel_date × tenant_id × staff_id", "dws_sup_staff_operate_di", "商户后台", [
        (["staff_order_qty", "staff_pay_amt", "staff_verify_qty", "staff_refund_qty"], D5, None)]),
    ("ads_sup_platform_overview_di", "平台经营大盘", "travel_date", "dws_sup_tenant_trade_di, dws_sup_tenant_onboard_di, dws_cus_tenant_growth_di", "平台后台", [
        (["pay_amt", "net_pay_amt", "verify_ticket_qty", "gross_profit_amt", "active_tenant_qty", "new_tenant_qty", "new_customer_qty", "pay_buyer_qty"], D5, None),
        (["tenant_cert_apply_qty", "tenant_cert_pass_qty", "tenant_cert_pass_rate", "sku_sell_rate"], D3, None),
        (["pay_amt_dod_rate", "pay_amt_wow_rate"], NOP, None)]),
    ("ads_sup_tenant_lifecycle_df", "商户生命周期（活跃/沉默/流失）", "travel_date × tenant_lifecycle_stage", "dws_sup_tenant_lifetime_df", "平台后台", [
        (["active_tenant_qty", "tenant_active_rate", "silent_tenant_qty"], P30, None),
        (["churn_tenant_qty"], P90, None)]),
    ("ads_opr_package_revenue_mo", "套餐收入与续费（月）", "月 × package_id", "dws_opr_package_subscription_df", "平台后台", [
        (["package_amt", "package_renew_qty", "package_renew_rate", "active_subscription_qty", "expiring_30d_subscription_qty"], MO, None),
        (["package_amt"], YTD, None)]),
    ("ads_opr_risk_monitor_di", "风控监控", "travel_date × rule_id × action", "dws_opr_risk_rule_hit_di, dws_opr_audit_action_di, dws_ord_tenant_sku_verify_di", "平台后台", [
        (["risk_hit_qty", "risk_block_qty", "risk_block_rate", "blacklist_add_qty", "ban_qty", "night_action_qty", "duplicate_verify_qty"], D3, None)]),
    ("ads_opr_device_health_di", "设备健康", "travel_date × tenant_id × device_type", "dws_opr_device_di, dws_ord_tenant_sku_verify_di", "商户/平台", [
        (["device_online_rate", "offline_times_qty", "offline_verify_rate", "offline_conflict_qty"], D3, None),
        (["device_total_qty"], S, None)]),
    ("ads_opr_complaint_sla_di", "投诉SLA与审批时效", "travel_date × tenant_id × complaint_type", "dws_opr_complaint_di, dws_opr_approval_di", "平台后台", [
        (["complaint_qty", "complaint_resolved_qty", "complaint_overdue_qty", "complaint_sla_rate"], D3, None),
        (["approval_qty", "approval_pass_rate", "approval_timeout_qty", "avg_approval_minute_qty"], D3, None)]),
    ("ads_opr_notify_cost_di", "通知与短信消耗", "travel_date × tenant_id", "dws_opr_notify_di", "商户/平台", [
        (["notify_send_qty", "notify_success_rate"], D3, "NC"),
        (["resource_consume_qty"], D5, None),
        (["notify_fail_qty"], D3, None)]),
    ("ads_opr_code_pool_usage_df", "码池使用", "travel_date × tenant_id × code_pool_id", "dws_opr_code_pool_df", "商户/平台", [
        (["code_capacity_qty", "code_allocated_qty", "code_recycled_qty", "code_pool_usage_rate", "code_recycle_rate"], S, None),
        (["issue_credential_qty", "revoke_credential_qty"], D3, None)]),
    ("ads_sup_tenant_trade_wk", "商户经营周报", "自然周 × seller_tenant_id", "dws_sup_tenant_trade_di", "商户后台", [
        (["pay_amt", "net_pay_amt", "verify_ticket_qty", "refund_amt", "refund_rate", "gross_profit_amt", "per_customer_amt"], W, None),
        (["pay_amt_wow_rate"], NOP, None)]),
    ("ads_sup_tenant_trade_mo", "商户经营月报", "自然月 × seller_tenant_id", "dws_sup_tenant_trade_di", "商户后台", [
        (["pay_amt", "net_pay_amt", "verify_ticket_qty", "refund_amt", "refund_rate", "gross_profit_amt", "per_customer_amt"], MO, None),
        (["pay_amt_mom_rate"], NOP, None)]),
]

# ------------------------------------------------------------ 实时
RT = [list(r) + [[]] for r in ns["RT"]]
RT_DWS_METRICS = {
    "dws_ord_tenant_sku_trade_rt": ["pay_amt", "pay_order_qty", "pay_ticket_qty", "pay_buyer_qty", "refund_amt"],
    "dws_ord_verify_point_flow_rt": ["verify_person_qty", "verify_fail_qty", "verify_entitlement_qty", "duplicate_verify_qty", "offline_conflict_qty"],
    "dws_inv_sku_stock_rt": ["stock_total_qty", "stock_available_qty", "stock_frozen_qty", "stock_sold_qty", "sellout_pool_qty", "prededuct_qty", "prededuct_release_qty"],
}
for r in RT:
    if r[1] in RT_DWS_METRICS:
        r[4] = RT_DWS_METRICS[r[1]]
RT_ADS = [
    ("ads_ord_realtime_sales_rt", "实时销售看板（对应 DP08）", "tenant_id × 窗口", "dws_ord_tenant_sku_trade_rt", "商户后台/大屏", [
        (["pay_amt", "pay_order_qty", "pay_ticket_qty", "pay_buyer_qty", "refund_amt", "avg_ticket_price_amt"], RT3, None),
        (["pay_amt"], TODAY, "CH")]),
    ("ads_inv_realtime_stock_rt", "实时库存看板（对应 DP09）", "sku_id × pool_no", "dws_inv_sku_stock_rt", "商户后台", [
        (["stock_available_qty", "stock_frozen_qty", "stock_sell_through_rate", "sellout_pool_qty"], NOW, None),
        (["prededuct_qty", "prededuct_release_qty"], M5, None)]),
    ("ads_ord_realtime_flow_rt", "实时客流大屏", "tenant_id × verify_point_id × 窗口", "dws_ord_verify_point_flow_rt", "大屏", [
        (["verify_person_qty", "verify_fail_qty", "verify_fail_rate"], RT3, None)]),
    ("ads_opr_risk_alert_rt", "实时风控预警", "rule_id × 窗口", "ods_opr_risk_event_rt, dws_ord_verify_point_flow_rt", "平台后台", [
        (["risk_hit_qty", "risk_block_qty", "duplicate_verify_qty", "offline_conflict_qty"], M5 + TODAY, None)]),
]


# ============================================================ v2.1 打磨补丁（规范/复用/完善）
# 1) 字段名后缀合规
REN2 = {"pay_order_qty_30d": "pay_order_30d_qty", "pay_amt_30d": "pay_30d_amt", "active_day_qty_30d": "active_day_30d_qty",
        "repurchase_flag": "buyer_type"}
for b in BASE:
    if b[0] in REN2:
        b[0] = REN2[b[0]]
    for o, n in REN2.items():
        b[5] = b[5].replace(o, n)
upd("buyer_type", cn="买家类型", kou="0-首购 1-复购（近30天支付子单数≥2 记为复购）", calc="case when pay_order_30d_qty>=2 then 1 else 0 end", unit="0/1")
upd("silent_tenant_qty", calc="count(tenant) where pay_30d_amt=0 and total_pay_amt>0")
upd("repurchase_rate", calc="count(buyer) where buyer_type=1 / pay_buyer_qty")
for t in DWS:
    t[4] = [REN2.get(m, m) for m in t[4]]
# 2) 账户余额快照下沉到 DWD，消除 DWS 直读 ODS
DWD.append(("dwd_fin_account_balance_df", "账户余额日快照", "1行=1个账户×1日", "ods_fin_account_df",
            "日终可用余额、冻结余额、账户类型、主体"))
DWD_MD["dwd_fin_account_balance_df"] = ("available_balance_amt、frozen_balance_amt", "account_no")
for t in DWS:
    if t[0] == "dws_fin_account_balance_df":
        t[3] = "dwd_fin_account_balance_df, dwd_fin_fund_flow_di"
upd("available_balance_amt", src="dwd_fin_account_balance_df")
upd("frozen_balance_amt", src="dwd_fin_account_balance_df")
# 3) 孤儿表补消费：SKU 版本、渠道身份绑定、套票汇总
BASE.append(["sku_change_qty", "SKU属性变更次数", A, "prd", "SKU 版本号变化次数（属性/成本价/退改等变更）", "count(snapshot_no)", "次", "dwd_prd_sku_version_di"])
BASE.append(["identity_bind_qty", "渠道身份绑定数", A, "cus", "新增的游客渠道身份（微信/抖音/支付宝/OTA）", "count(*)", "个", "dwd_cus_identity_bind_di"])
BASE.append(["combo_refund_rate", "套票部分退率", C, "ord", "套票子项退款票数 / 套票子项支付票数", "refund_ticket_qty / pay_ticket_qty", "%", "dws_ord_combo_sku_trade_di"])
BNAME.clear(); BNAME.update({b[0]: b for b in BASE})
dws_add("dws_prd_sku_price_di", ["sku_change_qty"], "dwd_prd_sku_version_di")
dws_add("dws_cus_tenant_growth_di", ["identity_bind_qty"], "dwd_cus_identity_bind_di")
for a in ADS:
    if a[0] == "ads_prd_price_discount_di":
        a[5].append((["sku_change_qty"], D3, None))
    if a[0] == "ads_cus_customer_growth_di":
        a[5].append((["identity_bind_qty"], D3, None))
ADS.insert(7, ("ads_ord_combo_analysis_di", "套票分析（主子单/跨商户/部分退）", "travel_date × combo_sku_id × sub_sku_id", "dws_ord_combo_sku_trade_di", "商户后台", [
    (["combo_order_qty", "pay_amt", "pay_ticket_qty", "verify_ticket_qty", "refund_ticket_qty", "refund_amt", "combo_refund_rate"], D3, None)]))
# 4) 实时链路只落有人消费的表；风控走实时 DWD
RT = [r for r in RT if r[1] not in ("ods_ord_ticket_rt", "ods_ord_ticket_credential_rt", "ods_fin_fund_flow_rt", "ods_fin_frozen_record_rt", "dwd_fin_frozen_rt")]
RT.insert([i for i, r in enumerate(RT) if r[0] == "DWD"][-1] + 1, ["DWD", "dwd_opr_risk_event_rt", "实时风控事件", "ods_opr_risk_event_rt", []])
RT_ADS = [list(a) for a in RT_ADS]
for a in RT_ADS:
    if a[0] == "ads_opr_risk_alert_rt":
        a[3] = "dws_opr_risk_rule_hit_rt, dws_ord_verify_point_flow_rt"
RT_ADS = [tuple(a) for a in RT_ADS]
RT.insert([i for i, r in enumerate(RT) if r[0] == "DWS"][-1] + 1, ["DWS", "dws_opr_risk_rule_hit_rt", "风控规则 分钟级命中", "dwd_opr_risk_event_rt", ["risk_hit_qty", "risk_block_qty"]])
for r in RT:
    if r[1] == "dwd_opr_risk_event_rt":
        r[4] = ["risk_hit_qty", "risk_block_qty"]

# 5) 维度关联（一致性维度 / 总线矩阵）
DIMK = {
    "tenant": "dim_sup_tenant_zip", "sku": "dim_prd_sku_zip", "spu": "dim_prd_spu_zip", "channel": "dim_trf_channel_df",
    "date": "dim_opr_date_f", "vp": "dim_opr_verify_point_df", "customer": "dim_cus_customer_zip", "account": "dim_fin_account_df",
    "staff": "dim_sup_staff_zip", "device": "dim_opr_device_df", "rule": "dim_opr_risk_rule_df", "package": "dim_opr_package_df",
    "pool": "dim_inv_pool_df", "unit": "dim_inv_unit_df", "relation": "dim_trf_distribution_relation_zip", "codepool": "dim_opr_code_pool_df",
    "template": "dim_opr_notify_template_df", "flow": "dim_opr_approval_flow_df", "region": "dim_opr_region_f", "dict": "dim_opr_dict_f",
    "paych": "dim_fin_pay_channel_df", "currency": "dim_opr_currency_f", "mp": "dim_trf_mp_config_df", "chtenant": "dim_trf_channel_tenant_df",
    "bank": "dim_fin_bank_card_df", "invcfg": "dim_fin_invoice_config_df", "prule": "dim_prd_pricing_rule_zip", "shared": "dim_inv_shared_pool_df",
    "identity": "dim_cus_identity_df", "attr": "dim_prd_sku_attr_df",
}
DWD_DIMS = {
    "dwd_ord_order_group_di": "tenant channel chtenant mp customer staff date currency dict",
    "dwd_ord_order_di": "tenant sku spu attr channel customer date dict",
    "dwd_ord_order_status_log_di": "date dict",
    "dwd_ord_ticket_di": "tenant sku attr date dict",
    "dwd_ord_ticket_status_log_di": "date dict",
    "dwd_ord_ticket_person_di": "region customer dict",
    "dwd_ord_entitlement_di": "sku date dict",
    "dwd_ord_entitlement_binding_di": "dict",
    "dwd_ord_ticket_credential_di": "codepool date dict",
    "dwd_ord_verify_di": "tenant sku vp device staff date dict",
    "dwd_ord_refund_di": "tenant staff date dict",
    "dwd_ord_refund_ticket_di": "tenant sku date dict",
    "dwd_fin_payment_di": "tenant account paych date dict",
    "dwd_fin_refund_payment_di": "paych date dict",
    "dwd_fin_frozen_di": "account date dict",
    "dwd_fin_fund_flow_di": "account date dict",
    "dwd_fin_withdraw_di": "account bank date dict",
    "dwd_fin_invoice_di": "tenant invcfg date dict",
    "dwd_fin_resource_batch_di": "tenant package date dict",
    "dwd_fin_account_balance_df": "account date",
    "dwd_trf_distribution_settle_di": "tenant relation account sku date",
    "dwd_prd_sku_version_di": "sku staff date",
    "dwd_prd_price_point_log_di": "sku channel date",
    "dwd_prd_sku_price_calendar_df": "sku channel prule date",
    "dwd_inv_pool_change_di": "pool sku date dict",
    "dwd_inv_unit_change_di": "unit pool date",
    "dwd_inv_pool_snapshot_df": "pool shared sku date",
    "dwd_cus_customer_register_di": "customer channel tenant date",
    "dwd_cus_identity_bind_di": "identity customer channel tenant date",
    "dwd_cus_credential_register_di": "customer tenant date dict",
    "dwd_opr_risk_event_di": "rule date dict",
    "dwd_opr_blacklist_log_di": "rule date dict",
    "dwd_opr_account_ban_di": "rule date dict",
    "dwd_opr_approval_di": "flow staff tenant date dict",
    "dwd_opr_complaint_di": "tenant staff date dict",
    "dwd_opr_notify_di": "template tenant date dict",
    "dwd_opr_audit_log_di": "staff tenant date dict",
    "dwd_opr_device_status_log_di": "device tenant date dict",
    "dwd_opr_package_subscription_di": "package tenant date dict",
}
GRAIN_KEY = [("seller_tenant_id", "tenant"), ("supplier_tenant_id", "tenant"), ("distributor_tenant_id", "tenant"), ("tenant_id", "tenant"),
             ("sku_id", "sku"), ("channel", "channel"), ("travel_date", "date"), ("play_date", "date"), ("verify_point_id", "vp"),
             ("buyer_customer_id", "customer"), ("account_no", "account"), ("staff_id", "staff"), ("operator_id", "staff"), ("device_id", "device"),
             ("rule_id", "rule"), ("package_id", "package"), ("pool_no", "pool"), ("relation_no", "relation"), ("chain_level", "relation"),
             ("code_pool_id", "codepool"), ("template_code", "template"), ("flow_code", "flow"), ("origin_province", "region"),
             ("region_id", "region"), ("_type", "dict"), ("_status", "dict"), ("pay_method", "paych"), ("refund_reason", "dict"), ("action", "dict")]
def grain_dims(grain):
    out = []
    for k, d in GRAIN_KEY:
        if k in grain and d not in out:
            out.append(d)
    return out
DIM_SRC_ADD = {"dim_sup_staff_zip": "dim_sup_org_df, dim_sup_position_df, dim_sup_role_df",
               "dim_opr_package_df": "dim_opr_app_df", "dim_prd_sku_zip": "dim_prd_spu_zip, dim_prd_sale_rule_df",
               "dim_prd_sku_attr_df": "dim_prd_ticket_meta_f"}

# ------------------------------------------------------------ 生成 ADS 具体指标
KEYS = ("_amt", "_qty", "_rate", "_date")
def with_period(en, p):
    for k in KEYS:
        if en.endswith(k):
            return en[: -len(k)] + "_" + p + k
    return en + "_" + p

TOKEN = re.compile(r"[a-z][a-z0-9_]*")
def sub_formula(calc, p, mod):
    calc = re.sub(r"total\(([a-z0-9_]+)\)", lambda m: "§" + with_period(m.group(1), p) if m.group(1) in BNAME else m.group(0), calc)
    def rep(m):
        t = m.group(0)
        if t in BNAME:
            v = with_period(t, p) if p else t
            return (mod + "_" + v) if mod else v
        return t
    out = TOKEN.sub(rep, calc)
    return out.replace("§", "")

def gen(ads_list, mode):
    rows = []
    for tname, tcn, grain, src, end, groups in ads_list:
        for mets, periods, modkey in groups:
            mods = MODS[modkey] if modkey else [(None, None)]
            for m in mets:
                b = BNAME[m]
                for mk, mcn in mods:
                    for p, pcn in (periods or [(None, None)]):
                        en = with_period(m, p) if p else m
                        if mk:
                            en = mk + "_" + en
                        cn = (pcn or "") + (mcn or "") + b[1]
                        if b[2] == A:
                            f = "sum(%s)" % m if b[6] not in ("个", "台") or periods != S else m
                            f = "%s.%s%s%s" % ("dws", m, "" if not p else "，周期=" + pcn, "" if not mk else "，" + MOD_DESC[modkey] + "=" + mcn)
                            formula = "取 DWS 原子口径 %s（%s）" % (m, b[5]) + ("，按" + pcn + "汇总" if p else "") + ("，限定" + mcn if mk else "")
                        else:
                            formula = sub_formula(b[5], p, mk)
                        rows.append(dict(en=en, cn=cn, base=m, base_cn=b[1], type=b[2], unit=b[6], period=pcn or "自带周期",
                                         mod=(MOD_DESC[modkey].split("（")[0] + "=" + mcn) if mk else "—",
                                         formula=formula, ads=tname, ads_cn=tcn, grain=grain, src=src, end=end, mode=mode, domain=b[3]))
    return rows

ADS_M = gen(ADS, "离线") + gen(RT_ADS, "实时")
for i, r in enumerate(ADS_M, 1):
    r["code"] = "B%04d" % i
# 同表内不能重名
seen = {}
for r in ADS_M:
    k = (r["ads"], r["en"])
    assert k not in seen, k
    seen[k] = 1

# ------------------------------------------------------------ 校验：ADS 用到的原子口径必须在 DWS 落地
dws_metrics = set()
for t in DWS:
    dws_metrics |= set(t[4])
for r in RT:
    dws_metrics |= set(r[4])
need = set()
for r in ADS_M:
    b = BNAME[r["base"]]
    if b[2] == A:
        need.add(r["base"])
    else:
        for tok in TOKEN.findall(b[5]):
            if tok in BNAME and BNAME[tok][2] == A:
                need.add(tok)
missing = sorted(need - dws_metrics - {"stock_available_qty"})
# DWS 层基础口径：每个原子/计算口径落在哪些 DWS / ADS 表
base_tables = {}
for t in DWS:
    for m in t[4]:
        base_tables.setdefault(m, []).append(t[0])
for r in RT:
    for m in r[4]:
        base_tables.setdefault(m, []).append(r[1])
ads_by_base = {}
for r in ADS_M:
    ads_by_base.setdefault(r["base"], set()).add(r["ads"])

# 待确认：补两条
ISSUES.append([len(ISSUES) + 1, "口径", "ADS 指标命名", "周期插在关键字后缀之前（pay_7d_amt），修饰词作前缀（ota_pay_7d_amt），保证字段仍以 _amt/_qty/_rate 结尾", "影响全部 ADS 指标字段名"])
ISSUES.append([len(ISSUES) + 1, "口径", "毛利口径", "毛利额 = 支付金额 − 成本金额（下单时 SKU 版本成本价），未扣退款；是否改为净额口径待定", "影响毛利额/毛利率"])

if __name__ == "__main__":
    from collections import Counter
    print("DWS", len(DWS), "ADS", len(ADS), "RT_ADS", len(RT_ADS))
    print("base", len(BASE), Counter(b[2] for b in BASE))
    print("ADS metrics", len(ADS_M), Counter(r["mode"] for r in ADS_M))
    print(Counter(r["ads"] for r in ADS_M).most_common(40))
    print("MISSING in DWS:", missing)
    print([ (r["en"], r["formula"]) for r in ADS_M if r["type"] != A][:6])
