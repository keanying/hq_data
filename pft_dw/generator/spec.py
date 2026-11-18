# -*- coding: utf-8 -*-
"""指标规格补充：时间口径（归属时间）、数据类型与精度、业务口径文字、更新频率"""
import re

# ------------------------------------------------------------ 时间口径：指标按哪个时间点归属到统计日
_TB = {
    "下单时间（子单 create_time）": "order_group_qty order_qty order_ticket_qty order_amt staff_order_qty combo_order_qty pay_conversion_rate",
    "支付成功时间（pay_time）": "pay_order_qty pay_ticket_qty pay_amt pay_buyer_qty net_pay_ticket_qty pay_order_group_qty cost_amt "
                          "staff_pay_amt sold_sku_qty first_pay_customer_qty repeat_buyer_qty pay_minute_qty advance_book_day_qty "
                          "net_pay_amt avg_ticket_price_amt per_customer_amt gross_profit_amt gross_profit_rate avg_pay_minute_qty "
                          "avg_advance_book_day_qty channel_pay_share_rate avg_deal_price_amt discount_rate new_buyer_share_rate "
                          "pay_amt_dod_rate pay_amt_wow_rate pay_amt_mom_rate active_tenant_qty tenant_active_rate "
                          "pay_record_qty inbound_pay_amt outbound_pay_amt zero_fee_order_qty credit_pay_amt pay_method_share_rate sku_sell_rate",
    "支付成功时间（分销批次 INBOUND 到账）": "distribution_ticket_qty distribution_sale_amt distribution_purchase_amt distribution_profit_amt "
                                   "active_distributor_qty chain_level_qty distribution_profit_rate avg_chain_level_qty",
    "取消时间（子单变为 CANCELLED）": "cancel_order_qty cancel_amt timeout_cancel_order_qty cancel_rate timeout_cancel_rate",
    "出票/发码时间（ticket create_time）": "issue_ticket_qty issue_credential_qty realname_ticket_qty tourist_qty person_linked_qty "
                                    "entitlement_issue_qty realname_rate person_link_rate tourist_origin_share_rate",
    "凭证撤销时间": "revoke_credential_qty",
    "核销时间（verify_record create_time，离线核销按回连时间）": "verify_ticket_qty verify_entitlement_qty verify_person_qty verify_fail_qty "
        "offline_verify_qty verify_amt duplicate_verify_qty offline_conflict_qty staff_verify_qty peak_hour_verify_qty "
        "verify_fail_rate offline_verify_rate entitlement_used_qty entitlement_usage_rate verify_after_pay_day_qty avg_verify_after_pay_day_qty",
    "支付成功时间（按支付日 cohort 追踪核销）": "verify_rate",
    "退款申请时间": "refund_apply_qty staff_refund_qty",
    "退款完成时间（refund_status 变为 COMPLETED）": "refund_success_qty refund_ticket_qty refund_amt verified_refund_ticket_qty "
        "auto_approve_refund_qty refund_process_hour_qty avg_refund_process_hour_qty refund_rate refund_amt_rate combo_refund_rate",
    "退款驳回时间": "refund_reject_qty",
    "退款资金到账时间（退款明细 SUCCESS）": "refund_payment_amt",
    "过期时间（票变为 EXPIRED）": "expire_ticket_qty expire_rate",
    "激活时间（首次核销回填有效期起始）": "activate_ticket_qty activate_delay_day_qty avg_activate_delay_day_qty activate_rate",
    "统计日日终快照": "ticket_stock_qty unverified_ticket_qty unverified_amt pending_activate_ticket_qty entitlement_total_qty quota_total_amt "
               "on_sale_sku_qty stock_total_qty stock_available_qty stock_frozen_qty stock_sold_qty sellout_pool_qty unit_occupied_qty "
               "unit_total_qty stock_sell_through_rate stock_sellout_rate available_balance_amt frozen_balance_amt credit_limit_amt "
               "credit_used_amt credit_usage_rate code_capacity_qty code_allocated_qty code_recycled_qty code_pool_usage_rate "
               "code_recycle_rate device_total_qty active_subscription_qty expiring_30d_subscription_qty",
    "统计日日终快照（截至统计日的累计）": "first_pay_date last_pay_date total_pay_order_qty total_pay_amt pay_order_30d_qty pay_30d_amt buyer_type "
                                "active_day_30d_qty silent_tenant_qty churn_tenant_qty repurchase_rate",
    "冻结发生时间": "freeze_amt freeze_record_qty external_freeze_amt external_freeze_rate",
    "冻结释放时间": "unfreeze_verify_amt unfreeze_refund_amt expire_release_amt",
    "资金流水发生时间": "opening_balance_amt closing_balance_amt fund_flow_qty fund_in_amt fund_out_amt fee_amt",
    "提现申请时间": "withdraw_apply_amt withdraw_success_rate",
    "提现完成时间": "withdraw_success_amt withdraw_fail_qty",
    "开票时间（invoice_status 变为 INVOICED）": "invoice_amt invoice_order_qty invoice_rate",
    "资源批次相邻日快照差": "resource_consume_qty",
    "价格生效日（price_point 按日展开）": "list_price_amt",
    "变更时间": "price_change_qty sku_change_qty",
    "库存变动时间": "prededuct_qty prededuct_confirm_qty prededuct_release_qty prededuct_convert_rate",
    "游客注册时间（首次登录建档）": "new_customer_qty register_pay_customer_qty register_pay_conversion_rate face_register_rate",
    "认证/凭证登记时间": "certified_customer_qty face_register_qty",
    "渠道身份绑定时间": "identity_bind_qty",
    "租户创建/认证状态变更时间": "new_tenant_qty tenant_cert_apply_qty tenant_cert_pass_qty tenant_cert_pass_rate",
    "分销关系创建时间": "new_distribution_relation_qty",
    "设备状态变更时间": "online_minute_qty offline_times_qty device_online_rate",
    "风控事件时间": "risk_hit_qty risk_block_qty risk_block_rate",
    "黑名单/封禁生效时间": "blacklist_add_qty ban_qty",
    "工单创建时间": "complaint_qty complaint_sla_rate",
    "工单解决时间": "complaint_resolved_qty complaint_overdue_qty",
    "通知发送时间": "notify_send_qty notify_success_qty sms_send_qty notify_fail_qty notify_success_rate",
    "操作时间（审计日志）": "audit_action_qty night_action_qty",
    "审批发起时间": "approval_qty approval_pass_rate",
    "审批结束时间": "approval_pass_qty approval_reject_qty approval_minute_qty approval_timeout_qty avg_approval_minute_qty",
    "套餐订购时间": "package_amt package_renew_qty package_renew_rate",
}
TIME_BASIS = {}
for k, v in _TB.items():
    for en in v.split():
        assert en not in TIME_BASIS, en
        TIME_BASIS[en] = k

# ------------------------------------------------------------ 数据类型与精度
def dtype(en, unit):
    if en.endswith("_amt"):
        return "DECIMAL(18,2)", "元，保留 2 位小数"
    if en.endswith("_rate"):
        return "DECIMAL(20,6)", "百分数数值（已乘 100），保留 6 位小数，如 12.345678 表示 12.345678%"
    if en.endswith("_date"):
        return "STRING", "YYYYMMDD"
    if en.endswith("_type"):
        return "TINYINT", "枚举，含义见 dim_opr_dict_f"
    if en.startswith("avg_"):
        return "DECIMAL(18,2)", "%s，保留 2 位小数" % unit
    return "BIGINT", "整数，单位：%s" % unit

# ------------------------------------------------------------ 统计周期的业务说法
PERIOD_TXT = {
    "当日": "统计日当天（00:00–24:00）内",
    "近7日": "统计日及之前共 7 个自然日内",
    "近30日": "统计日及之前共 30 个自然日内",
    "近90日": "统计日及之前共 90 个自然日内",
    "本月累计": "统计日所在自然月 1 日至统计日",
    "本年累计": "统计日所在自然年 1 月 1 日至统计日",
    "截至当日": "截至统计日日终",
    "当小时": "统计小时内",
    "本周": "统计日所在自然周（周一至周日）内",
    "本月": "统计月（自然月）内",
    "今日实时": "今日 00:00 至当前时刻",
    "近1小时": "当前时刻往前 1 小时的滑动窗口内",
    "近5分钟": "当前时刻往前 5 分钟的滑动窗口内",
    "当前": "当前最新值",
    "自带周期": "",
}
FREQ = [("_rt", "实时（分钟级刷新）"), ("_hrs", "每小时（T+1h）"), ("_wk", "每周一产出上周"), ("_mo", "每月 1 日产出上月"),
        ("_df", "每日 T+1（快照）"), ("_di", "每日 T+1")]

def freq(table):
    for s, f in FREQ:
        if table.endswith(s):
            return f
    return "每日 T+1"

def ads_kou(r, base):
    """业务口径：周期 + 限定条件 + 基础口径；比率类说明分子分母同周期"""
    p = PERIOD_TXT.get(r["period"], r["period"])
    mod = "" if r["mod"] == "—" else "，限定" + r["mod"].replace("=", "为")
    k = KOU_BIZ.get(base["en"], base["kou"]).rstrip("。")
    k = re.sub(r"^统计周期内(的)?", "", k)
    if r["period"] == "自带周期":
        return k + "。"
    if r["type"] == "计算指标":
        if base["en"].endswith("share_rate"):
            return "%s%s：%s；分子按限定条件统计，分母为同周期全部。" % (p, mod, k)
        return "%s%s：%s；分子分母取同一统计周期%s。" % (p, mod, k, "、同一限定条件" if mod else "")
    if r["period"] in ("截至当日", "当前"):
        return "%s%s的值：%s。" % (p, mod, k)
    return "%s%s：%s。" % (p, mod, k)

# ------------------------------------------------------------ 业务口径改写成业务语言（原口径含字段名的）
KOU_BIZ = {
    "combo_order_qty": "套票主单数（一单套票只算 1，子项单不计）",
    "verify_person_qty": "核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段",
    "offline_verify_qty": "闸机/手持机离线状态下完成、回连后确认成功的核销次数",
    "refund_ticket_qty": "退款完成的票张数（一张退款单可含多张票，按票计）",
    "entitlement_used_qty": "权益已被使用的次数合计（年卡、次卡每入园一次计 1 次）",
    "entitlement_total_qty": "权益可用总次数合计：计次型、选择型按可用次数，固定型按 1 次，不限次型不计",
    "quota_total_amt": "额度型权益（如园区消费金）的发放总额度；已用额度源系统暂未记录",
    "staff_verify_qty": "员工（核销员/窗口）操作的成功核销次数",
    "staff_refund_qty": "商户员工发起的退款单数",
    "zero_fee_order_qty": "0 元单笔数（走支付流程但不产生资金）",
    "fund_in_amt": "账户资金流入金额（充值、收款、转入、解冻等入账）",
    "fund_out_amt": "账户资金流出金额（提现、退款、采购转出、手续费等出账）",
    "risk_block_qty": "风控规则命中后直接拦截（拒绝操作）的次数",
    "complaint_overdue_qty": "超过 SLA 截止时间才解决、或到截止时间仍未解决的投诉工单数",
    "notify_success_qty": "发送成功的通知条数",
    "sms_send_qty": "通过短信渠道发送的通知条数",
    "package_renew_qty": "续费类套餐订购笔数",
    "verify_rate": "支付成功的票中已经核销的比例，按支付日追踪（某天卖出的票后来核销了多少）",
    "person_linked_qty": "票上登记的游客中，已关联到会员账号的人数",
    "credit_pay_amt": "分销商用授信额度支付的金额",
    "external_freeze_amt": "由第三方支付渠道（如易宝分账）原生冻结的金额",
    "fee_amt": "账户被扣的手续费金额（提现手续费、短信费等）",
    "notify_fail_qty": "发送失败的通知条数",
}
