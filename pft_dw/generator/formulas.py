# -*- coding: utf-8 -*-
"""计算公式（业务可读版）
原子口径：ATOM[en] = (表达式, 业务条件)，字段用中文
计算口径：COMP[en] = 模板；{x} 代入同周期同修饰词的指标名，{!x} 代入同周期不带修饰词的指标名（占比的分母）
比率统一 *100，保留 6 位小数；金额、平均值保留 2 位小数；分母为 0 时结果为空
"""
ATOM = {
    # ---- 交易
    "order_group_qty": ("COUNT(DISTINCT 聚合单号)", ""),
    "order_qty": ("COUNT(DISTINCT 子单号)", "不含套票子项单"),
    "order_ticket_qty": ("SUM(购买数量)", ""),
    "order_amt": ("SUM(单价*购买数量)", ""),
    "pay_order_qty": ("COUNT(DISTINCT 子单号)", "子单状态变为已支付"),
    "pay_ticket_qty": ("SUM(购买数量)", "子单已支付"),
    "pay_amt": ("SUM(单价*购买数量)", "子单已支付；不扣退款"),
    "pay_buyer_qty": ("COUNT(DISTINCT 买家ID)", "子单已支付；剔除匿名买家和租户代下单占位买家"),
    "cancel_order_qty": ("COUNT(DISTINCT 子单号)", "子单状态变为已取消"),
    "cancel_amt": ("SUM(单价*购买数量)", "子单已取消"),
    "staff_order_qty": ("COUNT(DISTINCT 子单号)", "操作人类型=B端员工"),
    "combo_order_qty": ("COUNT(DISTINCT 子单号)", "套票主单标识=是"),
    "pay_order_group_qty": ("COUNT(DISTINCT 聚合单号)", "聚合单支付状态=已支付"),
    "cost_amt": ("SUM(下单时SKU版本成本价*购买数量)", "子单已支付"),
    "pay_minute_qty": ("SUM(支付时间-下单时间)，按分钟", "子单已支付"),
    "timeout_cancel_order_qty": ("COUNT(DISTINCT 子单号)", "子单已取消；取消原因=支付超时"),
    "advance_book_day_qty": ("SUM((游玩日期-支付日期)*购买数量)，按天", "子单已支付"),
    # ---- 出票 / 核销 / 权益
    "issue_ticket_qty": ("COUNT(DISTINCT 票号)", ""),
    "issue_credential_qty": ("COUNT(DISTINCT 凭证号)", ""),
    "revoke_credential_qty": ("COUNT(DISTINCT 凭证号)", "凭证状态=已撤销"),
    "verify_ticket_qty": ("COUNT(DISTINCT 票号)", "核销结果=成功"),
    "verify_entitlement_qty": ("COUNT(核销记录号)", "核销结果=成功"),
    "verify_person_qty": ("COUNT(核销记录号)", "核销结果=成功（源系统补放行人数后改为 SUM(放行人数)）"),
    "verify_fail_qty": ("COUNT(核销记录号)", "核销结果=失败或重复"),
    "offline_verify_qty": ("COUNT(核销记录号)", "核销方式=离线；核销结果=成功"),
    "verify_amt": ("SUM(票分摊单价)", "核销结果=成功；同一张票只计一次"),
    "duplicate_verify_qty": ("COUNT(核销记录号)", "核销结果=重复"),
    "offline_conflict_qty": ("COUNT(核销记录号)", "核销方式=离线；核销结果=重复"),
    "verify_after_pay_day_qty": ("SUM(首次核销日期-支付日期)，按天", "核销结果=成功；按票计首次核销"),
    "expire_ticket_qty": ("COUNT(DISTINCT 票号)", "票状态变为已过期"),
    "ticket_stock_qty": ("COUNT(票号)", "按票状态分组"),
    "unverified_ticket_qty": ("COUNT(票号)", "票状态=可用或部分使用；有效期截止>=统计日"),
    "unverified_amt": ("SUM(票分摊单价)", "票状态=可用或部分使用；有效期截止>=统计日"),
    "realname_ticket_qty": ("COUNT(DISTINCT 票号)", "票上登记游客数>=1"),
    "tourist_qty": ("COUNT(票上游客)", ""),
    "person_linked_qty": ("COUNT(票上游客)", "已关联会员账号"),
    "entitlement_issue_qty": ("COUNT(权益号)", ""),
    "entitlement_used_qty": ("SUM(权益已用次数)", ""),
    "entitlement_total_qty": ("SUM(权益可用次数)", "不限次型不计；固定型按 1 次"),
    "quota_total_amt": ("SUM(额度型权益总额度)", "权益类型=额度型"),
    "activate_ticket_qty": ("COUNT(DISTINCT 票号)", "延迟激活类票；首次核销回填有效期起始"),
    "activate_delay_day_qty": ("SUM(激活日期-支付日期)，按天", "延迟激活类票"),
    "pending_activate_ticket_qty": ("COUNT(DISTINCT 票号)", "延迟激活类票；截至统计日仍未激活"),
    # ---- 退款
    "refund_apply_qty": ("COUNT(DISTINCT 退款单号)", ""),
    "refund_success_qty": ("COUNT(DISTINCT 退款单号)", "退款状态=已完成"),
    "refund_ticket_qty": ("COUNT(DISTINCT 票号)", "退款状态=已完成"),
    "refund_amt": ("SUM(退款金额)", "退款状态=已完成"),
    "refund_process_hour_qty": ("SUM(退款完成时间-退款申请时间)，按小时", "退款状态=已完成"),
    "auto_approve_refund_qty": ("COUNT(DISTINCT 退款单号)", "审核超过 48 小时自动通过"),
    "refund_reject_qty": ("COUNT(DISTINCT 退款单号)", "退款状态=已驳回"),
    "verified_refund_ticket_qty": ("COUNT(DISTINCT 票号)", "退款状态=已完成；退款时票状态=部分使用或已使用"),
    # ---- 游客 / 商户
    "new_customer_qty": ("COUNT(DISTINCT 游客ID)", "账号类型=真人注册"),
    "first_pay_date": ("MIN(支付日期)", ""),
    "last_pay_date": ("MAX(支付日期)", ""),
    "first_pay_customer_qty": ("COUNT(DISTINCT 买家ID)", "首次支付日期在统计周期内"),
    "repeat_buyer_qty": ("COUNT(DISTINCT 买家ID)", "统计周期内有支付；首次支付日期早于统计周期"),
    "register_pay_customer_qty": ("COUNT(DISTINCT 游客ID)", "注册时间和首次支付时间都在统计周期内"),
    "certified_customer_qty": ("COUNT(DISTINCT 游客ID)", "认证状态变为已实名认证"),
    "face_register_qty": ("COUNT(个人凭证号)", "凭证类型=人脸"),
    "identity_bind_qty": ("COUNT(渠道身份记录)", ""),
    "on_sale_sku_qty": ("COUNT(DISTINCT SKU ID)", "SKU 状态=已发布"),
    "sold_sku_qty": ("COUNT(DISTINCT SKU ID)", "支付金额>0"),
    "active_tenant_qty": ("COUNT(DISTINCT 卖家租户ID)", "支付金额>0"),
    "new_tenant_qty": ("COUNT(DISTINCT 租户ID)", "租户类型=外部租户"),
    "tenant_cert_apply_qty": ("COUNT(DISTINCT 租户ID)", "认证状态变为审核中"),
    "tenant_cert_pass_qty": ("COUNT(DISTINCT 租户ID)", "认证状态变为已认证"),
    "staff_pay_amt": ("SUM(单价*购买数量)", "子单已支付；操作人类型=B端员工"),
    "staff_verify_qty": ("COUNT(核销记录号)", "核销结果=成功；按操作员统计"),
    "staff_refund_qty": ("COUNT(DISTINCT 退款单号)", "发起方=商户"),
    # ---- 分销
    "distribution_ticket_qty": ("COUNT(DISTINCT 票号)", "存在采购付款（经过分销链）"),
    "distribution_sale_amt": ("SUM(本级售出金额)", ""),
    "distribution_purchase_amt": ("SUM(本级采购金额)", ""),
    "distribution_profit_amt": ("SUM(本级售出金额-本级采购金额)", ""),
    "active_distributor_qty": ("COUNT(DISTINCT 分销商租户ID)", "分销票数>0"),
    "chain_level_qty": ("SUM(每张分销票的最大分销层级)", ""),
    "new_distribution_relation_qty": ("COUNT(DISTINCT 分销关系编号)", ""),
    "credit_limit_amt": ("SUM(授信额度)", ""),
    "credit_used_amt": ("SUM(已用授信)", ""),
    # ---- 财务
    "pay_record_qty": ("COUNT(DISTINCT 支付流水号)", "支付状态=已支付"),
    "inbound_pay_amt": ("SUM(支付金额)", "资金方向=收款；支付状态=已支付"),
    "outbound_pay_amt": ("SUM(支付金额)", "资金方向=采购付款；支付状态=已支付"),
    "zero_fee_order_qty": ("COUNT(DISTINCT 支付流水号)", "支付方式=0元单"),
    "credit_pay_amt": ("SUM(支付金额)", "支付方式=授信；支付状态=已支付"),
    "refund_payment_amt": ("SUM(退款金额)", "退款明细状态=成功"),
    "freeze_amt": ("SUM(冻结金额)", ""),
    "freeze_record_qty": ("COUNT(冻结记录号)", ""),
    "external_freeze_amt": ("SUM(冻结金额)", "外部渠道冻结=是"),
    "unfreeze_verify_amt": ("SUM(冻结金额)", "冻结状态=已释放；释放事件=核销"),
    "unfreeze_refund_amt": ("SUM(冻结金额)", "冻结状态=已释放；释放事件=退款"),
    "expire_release_amt": ("SUM(冻结金额)", "释放原因=票过期超 30 天兜底释放"),
    "available_balance_amt": ("SUM(账户可用余额)", ""),
    "frozen_balance_amt": ("SUM(账户冻结余额)", ""),
    "opening_balance_amt": ("取当日第一条流水的变动前余额", ""),
    "closing_balance_amt": ("取当日最后一条流水的变动后余额", ""),
    "fund_flow_qty": ("COUNT(流水号)", ""),
    "fund_in_amt": ("SUM(变动金额)", "变动金额>0"),
    "fund_out_amt": ("SUM(ABS(变动金额))", "变动金额<0"),
    "fee_amt": ("SUM(ABS(变动金额))", "流水类型=手续费"),
    "withdraw_apply_amt": ("SUM(提现金额)", ""),
    "withdraw_success_amt": ("SUM(提现金额)", "提现状态=已完成"),
    "withdraw_fail_qty": ("COUNT(DISTINCT 提现单号)", "提现状态=失败或已驳回"),
    "invoice_amt": ("SUM(开票金额)", "发票状态=已开票"),
    "invoice_order_qty": ("COUNT(DISTINCT 聚合单号)", "发票状态=已开票；开票主体=商户给游客"),
    "resource_consume_qty": ("SUM(前一日剩余量-当日剩余量)", ""),
    # ---- 价格 / 库存
    "list_price_amt": ("取命中优先级最高的价格点售价（单日>区间>星期>默认）", ""),
    "price_change_qty": ("COUNT(价格点变更记录)", ""),
    "sku_change_qty": ("COUNT(SKU 版本快照号)", ""),
    "stock_total_qty": ("SUM(库存总量)", ""),
    "stock_available_qty": ("SUM(可用库存)", ""),
    "stock_frozen_qty": ("SUM(预扣库存)", ""),
    "stock_sold_qty": ("SUM(库存总量-可用库存-预扣库存)", ""),
    "sellout_pool_qty": ("COUNT(DISTINCT 库存池编号)", "可用库存=0；池状态=在售"),
    "unit_occupied_qty": ("COUNT(DISTINCT 资源编号)", "资源状态=已占用"),
    "unit_total_qty": ("COUNT(DISTINCT 资源编号)", ""),
    "prededuct_qty": ("SUM(预扣数量)", "变动类型=预扣"),
    "prededuct_confirm_qty": ("SUM(变动数量)", "变动类型=确认"),
    "prededuct_release_qty": ("SUM(变动数量)", "变动类型=回滚；来源为预扣"),
    "code_capacity_qty": ("SUM(码池容量)", ""),
    "code_allocated_qty": ("SUM(已分配码数)", ""),
    "code_recycled_qty": ("SUM(回收复用码数)", ""),
    # ---- 运营
    "device_total_qty": ("COUNT(DISTINCT 设备ID)", "设备状态<>停用"),
    "online_minute_qty": ("SUM(在线状态持续时长)，按分钟", ""),
    "offline_times_qty": ("COUNT(设备状态变更记录)", "变更后状态=离线"),
    "risk_hit_qty": ("COUNT(风控事件号)", ""),
    "risk_block_qty": ("COUNT(风控事件号)", "执行动作=拦截"),
    "blacklist_add_qty": ("COUNT(黑名单记录号)", "变更类型=新增"),
    "ban_qty": ("COUNT(封禁记录号)", ""),
    "complaint_qty": ("COUNT(DISTINCT 工单号)", ""),
    "complaint_resolved_qty": ("COUNT(DISTINCT 工单号)", "工单状态=已解决或已关闭"),
    "complaint_overdue_qty": ("COUNT(DISTINCT 工单号)", "解决时间晚于 SLA 截止时间，或已过截止时间仍未解决"),
    "notify_send_qty": ("COUNT(通知记录号)", ""),
    "notify_success_qty": ("COUNT(通知记录号)", "发送状态=成功"),
    "notify_fail_qty": ("COUNT(通知记录号)", "发送状态=失败"),
    "sms_send_qty": ("COUNT(通知记录号)", "通知渠道=短信"),
    "audit_action_qty": ("COUNT(审计日志号)", ""),
    "night_action_qty": ("COUNT(审计日志号)", "操作时间在 0 点至 6 点"),
    "approval_qty": ("COUNT(DISTINCT 审批实例号)", ""),
    "approval_pass_qty": ("COUNT(DISTINCT 审批实例号)", "审批状态=通过"),
    "approval_reject_qty": ("COUNT(DISTINCT 审批实例号)", "审批状态=拒绝"),
    "approval_timeout_qty": ("COUNT(DISTINCT 审批实例号)", "完成时间晚于节点截止时间"),
    "approval_minute_qty": ("SUM(审批结束时间-审批发起时间)，按分钟", "审批已结束"),
    "active_subscription_qty": ("COUNT(DISTINCT 订购编号)", "生效时间<=统计日<=到期时间"),
    "expiring_30d_subscription_qty": ("COUNT(DISTINCT 订购编号)", "生效中；到期时间在统计日后 30 天内"),
    "package_amt": ("SUM(套餐价格)", ""),
    "package_renew_qty": ("COUNT(DISTINCT 订购编号)", "订购类型=续费"),
    # ---- 累计类（派生，DWS 累计表使用）
    "net_pay_ticket_qty": ("{pay_ticket_qty}-{refund_ticket_qty}", ""),
    "total_pay_order_qty": ("SUM(支付子单数)", "截至统计日全部历史"),
    "total_pay_amt": ("SUM(支付金额)", "截至统计日全部历史"),
    "pay_order_30d_qty": ("SUM(支付子单数)", "统计日及前 29 天"),
    "pay_30d_amt": ("SUM(支付金额)", "统计日及前 29 天"),
    "active_day_30d_qty": ("COUNT(DISTINCT 有支付的日期)", "统计日及前 29 天"),
    "buyer_type": ("CASE WHEN 近30日支付子单数>=2 THEN 1（复购） ELSE 0（首购） END", ""),
    "silent_tenant_qty": ("COUNT(DISTINCT 租户ID)", "近30日支付金额=0；累计支付金额>0"),
    "churn_tenant_qty": ("COUNT(DISTINCT 租户ID)", "最近支付日期早于统计日前 90 天"),
}

COMP = {
    "net_pay_amt": "{pay_amt}-{refund_amt}",
    "gross_profit_amt": "{pay_amt}-{cost_amt}",
    "pay_conversion_rate": "{pay_order_qty}*100/{order_qty}",
    "avg_ticket_price_amt": "{pay_amt}/{pay_ticket_qty}",
    "per_customer_amt": "{pay_amt}/{pay_buyer_qty}",
    "verify_rate": "{verify_ticket_qty}*100/{pay_ticket_qty}（按支付日追踪：分子为该支付日卖出的票中已核销的票数）",
    "refund_rate": "{refund_ticket_qty}*100/{pay_ticket_qty}",
    "refund_amt_rate": "{refund_amt}*100/{pay_amt}",
    "cancel_rate": "{cancel_order_qty}*100/{order_qty}",
    "expire_rate": "{expire_ticket_qty}*100/{issue_ticket_qty}",
    "entitlement_usage_rate": "{entitlement_used_qty}*100/{entitlement_total_qty}",
    "avg_advance_book_day_qty": "{advance_book_day_qty}/{pay_ticket_qty}",
    "realname_rate": "{realname_ticket_qty}*100/{issue_ticket_qty}",
    "verify_fail_rate": "{verify_fail_qty}*100/({verify_entitlement_qty}+{verify_fail_qty})",
    "offline_verify_rate": "{offline_verify_qty}*100/{verify_entitlement_qty}",
    "peak_hour_verify_qty": "MAX(当日各小时的核销人次)",
    "tourist_origin_share_rate": "当前客源地{tourist_qty}*100/全部客源地{tourist_qty}",
    "repurchase_rate": "复购买家数（近30日支付子单数>=2）*100/{pay_buyer_qty}",
    "channel_pay_share_rate": "{pay_amt}*100/{!pay_amt}",
    "pay_method_share_rate": "{inbound_pay_amt}*100/{!inbound_pay_amt}",
    "distribution_profit_rate": "{distribution_profit_amt}*100/{distribution_sale_amt}",
    "credit_usage_rate": "{credit_used_amt}*100/{credit_limit_amt}",
    "avg_deal_price_amt": "{pay_amt}/{pay_ticket_qty}",
    "discount_rate": "{avg_deal_price_amt}*100/{list_price_amt}",
    "stock_sell_through_rate": "{stock_sold_qty}*100/{stock_total_qty}",
    "stock_sellout_rate": "{sellout_pool_qty}*100/在售库存池数",
    "device_online_rate": "{online_minute_qty}*100/(1440*统计天数*{device_total_qty})",
    "risk_block_rate": "{risk_block_qty}*100/{risk_hit_qty}",
    "complaint_sla_rate": "({complaint_qty}-{complaint_overdue_qty})*100/{complaint_qty}",
    "notify_success_rate": "{notify_success_qty}*100/{notify_send_qty}",
    "tenant_active_rate": "{active_tenant_qty}*100/状态为有效的租户数",
    "package_renew_rate": "{package_renew_qty}*100/到期订购数",
    "pay_amt_dod_rate": "(本期支付金额-上期支付金额)*100/上期支付金额；本期=统计日，上期=统计日前一日",
    "pay_amt_wow_rate": "(本期支付金额-上期支付金额)*100/上期支付金额；日表：本期=统计日，上期=上周同一天；周报：本期=本周，上期=上周",
    "pay_amt_mom_rate": "(本期支付金额-上期支付金额)*100/上期支付金额；本期=本月，上期=上月",
    "gross_profit_rate": "{gross_profit_amt}*100/{pay_amt}",
    "avg_pay_minute_qty": "{pay_minute_qty}/{pay_order_qty}",
    "timeout_cancel_rate": "{timeout_cancel_order_qty}*100/{order_qty}",
    "avg_refund_process_hour_qty": "{refund_process_hour_qty}/{refund_success_qty}",
    "avg_verify_after_pay_day_qty": "{verify_after_pay_day_qty}/{verify_ticket_qty}",
    "avg_activate_delay_day_qty": "{activate_delay_day_qty}/{activate_ticket_qty}",
    "activate_rate": "{activate_ticket_qty}*100/({activate_ticket_qty}+{pending_activate_ticket_qty})",
    "person_link_rate": "{person_linked_qty}*100/{tourist_qty}",
    "new_buyer_share_rate": "{first_pay_customer_qty}*100/{pay_buyer_qty}",
    "register_pay_conversion_rate": "{register_pay_customer_qty}*100/{new_customer_qty}",
    "face_register_rate": "{face_register_qty}*100/{new_customer_qty}",
    "tenant_cert_pass_rate": "{tenant_cert_pass_qty}*100/{tenant_cert_apply_qty}",
    "sku_sell_rate": "{sold_sku_qty}*100/{on_sale_sku_qty}",
    "avg_chain_level_qty": "{chain_level_qty}/{distribution_ticket_qty}",
    "external_freeze_rate": "{external_freeze_amt}*100/{freeze_amt}",
    "invoice_rate": "{invoice_order_qty}*100/{pay_order_group_qty}",
    "withdraw_success_rate": "{withdraw_success_amt}*100/{withdraw_apply_amt}",
    "prededuct_convert_rate": "{prededuct_confirm_qty}*100/{prededuct_qty}",
    "code_pool_usage_rate": "{code_allocated_qty}*100/{code_capacity_qty}",
    "code_recycle_rate": "{code_recycled_qty}*100/{code_allocated_qty}",
    "approval_pass_rate": "{approval_pass_qty}*100/{approval_qty}",
    "avg_approval_minute_qty": "{approval_minute_qty}/({approval_pass_qty}+{approval_reject_qty})",
    "combo_refund_rate": "{refund_ticket_qty}*100/{pay_ticket_qty}（限套票子项）",
}

# ------------------------------------------------------------ 组装
import re
_PH = re.compile(r"\{(!?)([a-z0-9_]+)\}")
PERIOD_RANGE = {
    "当日": "统计日当天", "近7日": "统计日及前 6 天", "近30日": "统计日及前 29 天", "近90日": "统计日及前 89 天",
    "本月累计": "本月 1 日至统计日", "本年累计": "本年 1 月 1 日至统计日", "当小时": "统计小时内", "本周": "统计周（周一至周日）内",
    "本月": "统计月内", "今日实时": "今日 0 点至当前", "近1小时": "最近 1 小时内", "近5分钟": "最近 5 分钟内",
}
SNAP = ("截至当日", "当前")

def precision_tail(en, base=None, body=""):
    base = base or en
    sep = "；" if "；" in body else "，"
    if en.endswith("_rate"):
        return sep + "保留 6 位小数；分母为 0 时结果为空"
    if en.endswith("_amt") or en.startswith("avg_"):
        return sep + "保留 2 位小数" + ("；分母为 0 时结果为空" if "/" in COMP.get(base, "") else "")
    return ""

def _name(cn_of, x, pcn, mcn, bare=False):
    return (pcn or "") + ("" if bare else (mcn or "")) + cn_of[x]

def base_formula(en, cn_of):
    """DWS 口径层的计算逻辑（不带周期）"""
    if en in COMP:
        body = _PH.sub(lambda m: cn_of[m.group(2)], COMP[en])
        return "%s = %s%s" % (cn_of[en], body, precision_tail(en, en, body))
    e, c = ATOM[en]
    e = _PH.sub(lambda m: cn_of[m.group(2)], e)
    return "%s = %s%s%s" % (cn_of[en], e, ("；条件：" + c) if c else "", precision_tail(en, en, c))

def ads_formula(r, cn_of, time_basis):
    """ADS 具体指标的计算公式：带统计周期和修饰词"""
    base, en, cn = r["base"], r["en"], r["cn"]
    pcn = r["period"] if r["period"] not in ("自带周期",) else ""
    mcn = r.get("mod_cn", "")
    if base in COMP:
        if r["period"] == "自带周期":
            body = _PH.sub(lambda m: cn_of[m.group(2)], COMP[base])
        else:
            body = _PH.sub(lambda m: _name(cn_of, m.group(2), pcn, mcn, bare=m.group(1) == "!"), COMP[base])
        return "%s = %s%s" % (cn, body, precision_tail(en, base, body))
    e, c = ATOM[base]
    e = _PH.sub(lambda m: _name(cn_of, m.group(2), pcn, mcn), e)
    conds = [c] if c else []
    if mcn:
        conds.append(r["mod"].replace("=", "="))
    tb = re.sub(r"（.*?）", "", time_basis)
    if r["period"] in SNAP:
        conds.append("取%s值" % ("统计日日终" if r["period"] == "截至当日" else "当前最新"))
    elif r["period"] in PERIOD_RANGE:
        rng = PERIOD_RANGE[r["period"]]
        conds.append("%s在%s%s" % (tb, rng, "" if rng.endswith(("内", "当前", "当天")) else "内"))
    return "%s = %s；条件：%s%s" % (cn, e, "；".join(conds), precision_tail(en, base, "；"))
