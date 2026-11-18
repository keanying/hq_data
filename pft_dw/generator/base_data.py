# -*- coding: utf-8 -*-
"""生成 PFT2.0 数仓分层表清单 + 指标字典 xlsx"""
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from collections import OrderedDict
import os

PART = "travel_date（YYYYMMDD）"

DOMAIN = OrderedDict([
    ("ord", "订单、预订（含票/权益/凭证/核销/退款）"),
    ("fin", "财务、结算（含支付/冻结/资金流水/提现/发票）"),
    ("prd", "产品（SPU/SKU/票属性/售卖规则/价格）"),
    ("inv", "库存（库存池/座位房间/共享配额）"),
    ("cus", "用户、旅客（C端游客/渠道身份/个人凭证）"),
    ("sup", "供应商（租户/员工/组织/岗位/权限）"),
    ("trf", "流量、渠道（接入端/渠道租户绑定/分销关系）"),
    ("opr", "运营（核销点/码池/设备/风控/审批/投诉/通知/审计/套餐/公共码表）"),
    ("mkt", "营销、活动（优惠券）"),
])

def suffix_desc(name):
    for s, d in [("_hrs", "小时级增量"), ("_zip", "拉链表"), ("_di", "天级增量"), ("_df", "天级全量"),
                 ("_wk", "周级增量"), ("_mo", "月级增量"), ("_rt", "实时（后缀待定）"), ("_f", "非分区全量")]:
        if name.endswith(s):
            return d
    return ""

def part_of(name):
    if name.endswith("_f"):
        return "无分区"
    if name.endswith("_hrs"):
        return PART + " + 小时（子分区待确认）"
    if name.endswith("_rt"):
        return "实时（Flink CDC 直读 binlog / StarRocks）"
    return PART

# ---------------------------------------------------------------- ODS
# (源库, 源表, ods表名, 中文名, 备注)
ODS = [
    ("pft-order", "t_order_group", "ods_ord_order_group_di", "聚合单", "联系人证件号/手机号脱敏"),
    ("pft-order", "t_order", "ods_ord_order_di", "子单", ""),
    ("pft-order", "t_ticket", "ods_ord_ticket_di", "票", ""),
    ("pft-order", "t_ticket_person", "ods_ord_ticket_person_di", "票上的人", "id_number/phone 脱敏或加密"),
    ("pft-order", "t_entitlement", "ods_ord_entitlement_di", "权益", ""),
    ("pft-order", "t_person_entitlement_binding", "ods_ord_person_entitlement_binding_di", "人-权益绑定", ""),
    ("pft-order", "t_refund_order", "ods_ord_refund_order_di", "退款单", ""),
    ("pft-order", "t_refund_detail", "ods_ord_refund_detail_di", "退款明细（按支付记录）", ""),
    ("pft-verification", "t_ticket_credential", "ods_ord_ticket_credential_di", "票凭证", "code_value 脱敏"),
    ("pft-verification", "t_verify_record", "ods_ord_verify_record_di", "核销记录", ""),
    ("pft-payment", "t_payment_record", "ods_fin_payment_record_di", "支付记录", "订单库有同构副本，暂定只抽支付库"),
    ("pft-payment", "t_payment_channel_config", "ods_fin_payment_channel_config_df", "支付渠道配置", "剔除 secret_key/cert_path"),
    ("pft-payment", "t_merchant_payment_config", "ods_fin_merchant_payment_config_df", "商户收款配置", ""),
    ("pft-finance", "t_account", "ods_fin_account_df", "统一账户", "余额每日全量快照"),
    ("pft-finance", "t_frozen_record", "ods_fin_frozen_record_di", "冻结记录", ""),
    ("pft-finance", "t_fund_flow", "ods_fin_fund_flow_di", "资金流水", ""),
    ("pft-finance", "t_withdraw_order", "ods_fin_withdraw_order_di", "提现单", ""),
    ("pft-finance", "t_bank_card", "ods_fin_bank_card_df", "银行卡", "剔除 card_number，仅留尾号"),
    ("pft-finance", "t_invoice_config", "ods_fin_invoice_config_df", "商户发票配置", "剔除 provider_secret"),
    ("pft-finance", "t_invoice_order", "ods_fin_invoice_order_di", "发票单", ""),
    ("pft-finance", "t_resource_batch", "ods_fin_resource_batch_df", "资源批次（短信/积分）", ""),
    ("pft-product", "t_spu", "ods_prd_spu_df", "SPU", ""),
    ("pft-product", "t_sku", "ods_prd_sku_df", "SKU", ""),
    ("pft-product", "t_sku_version_snapshot", "ods_prd_sku_version_snapshot_di", "SKU版本快照", ""),
    ("pft-product", "t_ticket_meta", "ods_prd_ticket_meta_df", "票属性元数据", "广播表"),
    ("pft-product", "t_sku_meta_value", "ods_prd_sku_meta_value_df", "SKU票属性值", ""),
    ("pft-product", "t_sale_rule", "ods_prd_sale_rule_df", "售卖规则", ""),
    ("pft-product", "t_sale_rule_item", "ods_prd_sale_rule_item_df", "售卖条件项", ""),
    ("pft-pricing", "t_price_point", "ods_prd_price_point_di", "价格点", ""),
    ("pft-pricing", "t_pricing_rule", "ods_prd_pricing_rule_df", "定价规则", ""),
    ("pft-inventory", "t_inventory_pool", "ods_inv_inventory_pool_di", "库存池", ""),
    ("pft-inventory", "t_inventory_unit", "ods_inv_inventory_unit_di", "UNIT池资源（座位/房间/舱位）", ""),
    ("pft-inventory", "t_shared_inventory_pool", "ods_inv_shared_inventory_pool_df", "共享库存池", "分销域同一张表，只抽一次"),
    ("pft-identity", "t_customer", "ods_cus_customer_di", "C端游客主账号", "phone 脱敏"),
    ("pft-identity", "t_customer_identity", "ods_cus_customer_identity_di", "游客多渠道身份", ""),
    ("pft-identity", "t_customer_credential", "ods_cus_customer_credential_di", "游客个人凭证", "code_value（证件号/faceToken）脱敏"),
    ("pft-identity", "t_tenant", "ods_sup_tenant_df", "租户", ""),
    ("pft-identity", "t_tenant_config", "ods_sup_tenant_config_df", "租户配置KV", ""),
    ("pft-identity", "t_tenant_staff", "ods_sup_tenant_staff_df", "B端员工", ""),
    ("pft-identity", "t_staff_config", "ods_sup_staff_config_df", "员工配置KV", "技术配置，可选接入"),
    ("pft-identity", "t_org", "ods_sup_org_df", "部门架构", ""),
    ("pft-identity", "t_tenant_position", "ods_sup_tenant_position_df", "岗位定义", ""),
    ("pft-identity", "t_sys_role", "ods_sup_sys_role_df", "RBAC角色", ""),
    ("pft-identity", "t_sys_permission", "ods_sup_sys_permission_df", "权限定义", "可选接入"),
    ("pft-identity", "t_sys_resource", "ods_sup_sys_resource_df", "资源定义", "技术配置，可选接入"),
    ("pft-identity", "t_sys_role_permission", "ods_sup_sys_role_permission_df", "角色-权限绑定", "可选接入"),
    ("pft-identity", "t_sys_permission_resource", "ods_sup_sys_permission_resource_df", "权限-资源映射", "技术配置，可选接入"),
    ("pft-identity", "t_sys_user_role", "ods_sup_sys_user_role_df", "员工-角色绑定", ""),
    ("pft-identity", "t_sys_data_permission", "ods_sup_sys_data_permission_df", "ABAC数据权限", "技术配置，可选接入"),
    ("pft-platform", "t_channel", "ods_trf_channel_df", "接入端/渠道", "剔除 app_secret"),
    ("pft-platform", "t_channel_tenant_binding", "ods_trf_channel_tenant_binding_df", "渠道-租户绑定", ""),
    ("pft-platform", "t_tenant_mp_config", "ods_trf_tenant_mp_config_df", "租户小程序配置", "剔除 app_secret"),
    ("pft-distribution", "t_distribution_relation", "ods_trf_distribution_relation_df", "分销关系", ""),
    ("pft-open-platform", "t_api_key", "ods_trf_api_key_df", "API密钥", "剔除 app_secret"),
    ("pft-verification", "t_code_pool", "ods_opr_code_pool_df", "码池", ""),
    ("pft-verification", "t_verify_point", "ods_opr_verify_point_df", "核销点", ""),
    ("pft-risk", "t_risk_rule", "ods_opr_risk_rule_df", "风控规则", ""),
    ("pft-risk", "t_blacklist", "ods_opr_blacklist_di", "黑名单", "dimension_value 脱敏"),
    ("pft-risk", "t_risk_event", "ods_opr_risk_event_di", "风控事件", ""),
    ("pft-risk", "t_account_ban", "ods_opr_account_ban_di", "账号封禁", ""),
    ("pft-device", "t_device", "ods_opr_device_df", "设备", ""),
    ("pft-device", "t_device_group", "ods_opr_device_group_df", "设备分组", ""),
    ("pft-platform", "t_sys_dict", "ods_opr_sys_dict_df", "平台字典", ""),
    ("pft-platform", "t_package", "ods_opr_package_df", "套餐包", ""),
    ("pft-platform", "t_package_subscription", "ods_opr_package_subscription_di", "套餐订购", ""),
    ("pft-platform", "t_approval_flow", "ods_opr_approval_flow_df", "审批流定义", ""),
    ("pft-platform", "t_approval_instance", "ods_opr_approval_instance_di", "审批实例", ""),
    ("pft-platform", "t_complaint", "ods_opr_complaint_di", "投诉工单", ""),
    ("pft-platform", "t_i18n_language", "ods_opr_i18n_language_df", "支持语言", ""),
    ("pft-platform", "t_i18n_currency", "ods_opr_i18n_currency_df", "支持币种", ""),
    ("pft-platform", "t_i18n_translation", "ods_opr_i18n_translation_df", "翻译表", "可选接入"),
    ("pft-platform", "t_country", "ods_opr_country_df", "国家字典", ""),
    ("pft-platform", "t_region", "ods_opr_region_df", "地区字典", ""),
    ("pft-platform", "t_config_meta", "ods_opr_config_meta_df", "配置元数据", "技术配置，可选接入"),
    ("pft-notification", "t_notify_template", "ods_opr_notify_template_df", "通知模板", ""),
    ("pft-notification", "t_notify_record", "ods_opr_notify_record_di", "通知记录", "notify_content 脱敏"),
    ("pft-audit", "t_audit_log", "ods_opr_audit_log_di", "审计日志", ""),
    ("pft-application", "t_app_definition", "ods_opr_app_definition_df", "应用定义", ""),
    ("pft-application", "t_app_binding", "ods_opr_app_binding_df", "套餐-应用绑定", ""),
    ("pft-data-pipeline", "t_cdc_sync_task", "ods_opr_cdc_sync_task_df", "CDC同步任务", "技术配置，可选接入"),
    ("pft-marketing", "t_coupon", "ods_mkt_coupon_df", "优惠券", ""),
]
assert len(ODS) == 81, len(ODS)

# ---------------------------------------------------------------- DWD
# (表名, 中文名, 粒度, 来源, 关键字段/说明)
DWD = [
    ("dwd_ord_order_group_di", "聚合单明细", "1行=1个聚合单（order_group_no）", "ods_ord_order_group_di",
     "卖家租户、入口渠道 channel_id/app_id/app_ref、操作人类型/ID/所属租户、买家类型/ID、总金额、币种、支付状态、支付超时时间"),
    ("dwd_ord_order_di", "子单明细", "1行=1个子单（order_no）", "ods_ord_order_di + ods_ord_order_group_di",
     "冗余聚合单渠道/买家/操作人；套票主子标识 combo_flag/parent_order_no；sale_dims 展开为 play_date（游玩日）/time_slot/seat_zone；sku_version；buy_ticket_qty；unit_price_amt；order_amt"),
    ("dwd_ord_order_status_log_di", "子单状态流转明细", "1行=1次子单状态变更", "ods_ord_order_di（binlog 前后镜像）",
     "before_status/after_status/change_time；还原下单→支付→部分核销→全核销→退款/取消各时点"),
    ("dwd_ord_ticket_di", "票明细（出票）", "1行=1张票（ticket_no）", "ods_ord_ticket_di + dwd_ord_order_di",
     "冗余 sku/卖家/渠道/play_date；valid_start/valid_end；是否延迟激活（首次核销回填）；pass_policy；metadata 展开 seat/cabin/schedule"),
    ("dwd_ord_ticket_status_log_di", "票状态流转明细", "1行=1次票状态变更", "ods_ord_ticket_di（binlog 前后镜像）",
     "AVAILABLE→PARTIALLY_USED→USED/EXPIRED/REFUNDED/CANCELLED 每次变更时点"),
    ("dwd_ord_ticket_person_di", "票游客明细", "1行=1张票上1个人（ticket_no+person_id）", "ods_ord_ticket_person_di",
     "是否主游客、证件类型、global_customer_id 是否已关联；由证件号解析 origin_province/origin_city/age_band/gender（解析后原号脱敏）"),
    ("dwd_ord_entitlement_di", "权益明细", "1行=1个权益（entitlement_no）", "ods_ord_entitlement_di + dwd_ord_ticket_di",
     "6种权益类型；entitlement_detail 展开 max_count/duration_minute/quota_amt/candidate_qty；used_count；权益有效期"),
    ("dwd_ord_entitlement_binding_di", "人-权益绑定明细", "1行=1条绑定（ticket_no+person_id+entitlement_no）", "ods_ord_person_entitlement_binding_di",
     "binding_type：EXCLUSIVE/SHARED/OPEN"),
    ("dwd_ord_ticket_credential_di", "凭证发码/撤销明细", "1行=1个凭证（credential_no）", "ods_ord_ticket_credential_di",
     "credential_type、code_pool_id、状态 ACTIVE/EXPIRED/REVOKED、发码时间、撤销时间"),
    ("dwd_ord_verify_di", "核销明细（权益级）", "1行=1次核销（verify_no）", "ods_ord_verify_record_di + dwd_ord_entitlement_di + dwd_ord_ticket_di",
     "核销点、设备、操作员、在线/离线、离线时序戳、结果 SUCCESS/FAILED/DUPLICATE、权益类型、核销小时、核销金额（按票分摊价）"),
    ("dwd_ord_refund_di", "退款单明细", "1行=1个退款单（refund_no）", "ods_ord_refund_order_di",
     "退款类型、原因、发起方、审批人/审批时间、状态、退款金额"),
    ("dwd_ord_refund_ticket_di", "退款票明细", "1行=1个退款单里的1张票", "ods_ord_refund_order_di（refund_items JSON 展开）+ dwd_ord_ticket_di",
     "refund_no+order_no+ticket_no、分摊退款金额、退票时票状态（未核销/部分核销）"),
    ("dwd_fin_payment_di", "支付明细", "1行=1条支付记录（payment_no）", "ods_fin_payment_record_di",
     "pay_direction INBOUND/OUTBOUND、pay_method、receive_channel、batch_no/item_no/depend_on_item、付款/收款账户、amount/settle_amount、是否外部冻结、ZERO_FEE"),
    ("dwd_fin_refund_payment_di", "退款资金明细", "1行=1条退款明细（refund_detail_no）", "ods_ord_refund_detail_di",
     "原支付记录、退款渠道、退款流水号、状态"),
    ("dwd_fin_frozen_di", "冻结/解冻明细", "1行=1条冻结记录（frozen_no）", "ods_fin_frozen_record_di",
     "account_no、ticket_no、freeze_type PROFIT/SETTLEMENT/FULL、释放事件 VERIFY/REFUND、外部渠道冻结、冻结时间/释放时间"),
    ("dwd_fin_fund_flow_di", "资金流水明细", "1行=1条流水（flow_no）", "ods_fin_fund_flow_di",
     "flow_type（含 TRANSFER_OUT/IN）、变动金额、变动前后余额、关联业务号、支付批次号、费用项"),
    ("dwd_fin_withdraw_di", "提现明细", "1行=1个提现单（withdraw_no）", "ods_fin_withdraw_order_di",
     "提现主体、银行卡、状态、审批号、失败原因"),
    ("dwd_fin_invoice_di", "发票明细", "1行=1个发票单（invoice_no）", "ods_fin_invoice_order_di",
     "发票类型、开票主体（商户→游客/平台→商户）、关联订单、状态"),
    ("dwd_fin_resource_batch_di", "资源包购买/消耗明细", "1行=1个资源批次的1日状态", "ods_fin_resource_batch_df（相邻日快照求差）",
     "资源类型 SMS/POINTS/ALARM_QUOTA、总量、剩余量、当日消耗量"),
    ("dwd_trf_distribution_settle_di", "分销采购链明细", "1行=1张票在分销链上的1个层级", "dwd_fin_payment_di（batch_no 依赖链展开）+ dwd_fin_frozen_di",
     "ticket_no、chain_level（1=游客→末级分销商…）、payer/payee 账户与租户、售价、结算价、本级利润、冻结类型"),
    ("dwd_prd_sku_version_di", "SKU版本变更明细", "1行=1次SKU版本变更", "ods_prd_sku_version_snapshot_di",
     "旧版本号、变更人、变更原因、priceChangeLog 展开（旧价/新价）"),
    ("dwd_prd_price_point_log_di", "价格点变更明细", "1行=1次价格点新增/修改/删除", "ods_prd_price_point_di（binlog）",
     "变更类型、维度键（channel/date_single/date_from~to/weekday_mask/ext_dims）、变更前后价格"),
    ("dwd_prd_sku_price_calendar_df", "SKU每日生效价日历", "1行=1个SKU×1个日期×1个渠道×1组扩展维度", "ods_prd_price_point_di + ods_prd_pricing_rule_df",
     "按价格点优先级（单日10>区间5>星期3>默认0）展开未来N天的生效价、命中价格点编号、是否L2规则价"),
    ("dwd_inv_pool_change_di", "库存池变动明细", "1行=1次库存池数量变化", "ods_inv_inventory_pool_di（binlog 前后镜像）",
     "变动类型（预扣/确认/回滚/调整）、total/available/frozen 前后值与变化量、维度键展开 play_date/room_type/show_time"),
    ("dwd_inv_unit_change_di", "座位/房间锁定释放明细", "1行=1次UNIT资源状态变化", "ods_inv_inventory_unit_di（binlog）",
     "AVAILABLE→FROZEN→OCCUPIED/释放、锁定子单号、座位等级/房型"),
    ("dwd_inv_pool_snapshot_df", "库存池日快照", "1行=1个库存池×1日", "ods_inv_inventory_pool_di",
     "日终 total/available/frozen、池状态、是否售罄"),
    ("dwd_cus_customer_register_di", "游客注册明细", "1行=1个新注册游客", "ods_cus_customer_di",
     "customer_kind（剔除 TENANT_DEFAULT 占位买家）、注册渠道、注册租户、认证状态"),
    ("dwd_cus_identity_bind_di", "渠道身份绑定明细", "1行=1条身份绑定", "ods_cus_customer_identity_di",
     "identity_type（微信/抖音/支付宝/OTA）、绑定渠道、绑定租户"),
    ("dwd_cus_credential_register_di", "个人凭证注册明细", "1行=1条个人凭证", "ods_cus_customer_credential_di",
     "credential_type（身份证/护照/人脸…）、注册租户"),
    ("dwd_opr_risk_event_di", "风控事件明细", "1行=1个风控事件", "ods_opr_risk_event_di",
     "事件类型、规则、主体、动作 BLOCK/WARN/FREEZE、关联审计日志"),
    ("dwd_opr_blacklist_log_di", "黑名单变更明细", "1行=1次黑名单新增/失效/撤销", "ods_opr_blacklist_di",
     "维度、封禁动作、来源（规则/人工）、过期时间"),
    ("dwd_opr_account_ban_di", "账号封禁明细", "1行=1条封禁", "ods_opr_account_ban_di",
     "封禁类型、来源、状态、解封人/时间"),
    ("dwd_opr_approval_di", "审批实例明细", "1行=1个审批实例", "ods_opr_approval_instance_di",
     "审批流编码、关联业务号、申请人、当前节点、状态、审批耗时"),
    ("dwd_opr_complaint_di", "投诉工单明细", "1行=1个投诉工单", "ods_opr_complaint_di",
     "投诉方、类型、关联订单、处理人、SLA截止、是否超时、状态"),
    ("dwd_opr_notify_di", "通知发送明细", "1行=1次通知发送", "ods_opr_notify_record_di",
     "模板、渠道 SMS/小程序/邮件/Webhook、接收人类型、关联业务号、发送状态"),
    ("dwd_opr_audit_log_di", "审计操作明细", "1行=1条操作日志", "ods_opr_audit_log_di",
     "操作人类型/ID、action、资源类型/ID、IP、日志范围、是否凌晨操作"),
    ("dwd_opr_device_status_log_di", "设备状态变更明细", "1行=1次设备状态/心跳变化", "ods_opr_device_df（相邻快照/binlog）",
     "ACTIVE/OFFLINE/MAINTENANCE 变更时点、最后心跳"),
    ("dwd_opr_package_subscription_di", "套餐订购明细", "1行=1笔套餐订购", "ods_opr_package_subscription_di + ods_opr_package_df",
     "订购类型 NEW/RENEW/UPGRADE、套餐价格、生效/到期时间"),
]
assert len(DWD) == 38, len(DWD)

# ---------------------------------------------------------------- DIM
DIM = [
    ("dim_prd_spu_zip", "产品(SPU)维度", "1行=1个SPU×1个有效区间", "ods_prd_spu_df", "产品类型（13业态）、POI、状态"),
    ("dim_prd_sku_zip", "SKU维度", "1行=1个SKU×1个有效区间", "ods_prd_sku_df + ods_prd_spu_df", "冗余SPU/产品类型/商户；成本价、售卖模式、版本、销售渠道、标签"),
    ("dim_prd_sku_attr_df", "SKU票属性维度", "1行=1个SKU×1个票属性", "ods_prd_sku_meta_value_df + ods_prd_ticket_meta_df", "实名制策略、退改策略、核销策略（整批/分批）、PAY_TIMEOUT 等属性值与含义"),
    ("dim_prd_ticket_meta_f", "票属性元数据码表", "1行=1个票属性", "ods_prd_ticket_meta_df", "值类型、适用业态、影响链"),
    ("dim_prd_sale_rule_df", "售卖规则维度", "1行=1条规则×1个条件项", "ods_prd_sale_rule_df + ods_prd_sale_rule_item_df", "条件类型（日期/时段/提前天数/限购/年龄…）与条件值"),
    ("dim_prd_pricing_rule_zip", "定价规则维度", "1行=1条规则×1个有效区间", "ods_prd_pricing_rule_df", "MARGIN/SURCHARGE/DISCOUNT/MEMBER_DISCOUNT、基准价、计算方式、参数"),
    ("dim_inv_pool_df", "库存池维度", "1行=1个库存池", "ods_inv_inventory_pool_di", "COUNTING/UNIT、维度键展开（日期/房型/场次/舱位）"),
    ("dim_inv_unit_df", "座位/房间/舱位维度", "1行=1个UNIT资源", "ods_inv_inventory_unit_di", "所属池、座位等级/房型"),
    ("dim_inv_shared_pool_df", "共享库存配额维度", "1行=1条共享配额", "ods_inv_shared_inventory_pool_df", "分销关系、配额类型 HARD/SOFT/ROLLING、配额量"),
    ("dim_cus_customer_zip", "游客维度", "1行=1个游客×1个有效区间", "ods_cus_customer_di", "账号类型、认证状态、注册渠道/租户、性别、年龄段（脱敏）"),
    ("dim_cus_identity_df", "游客渠道身份维度", "1行=1条渠道身份", "ods_cus_customer_identity_di", "游客-渠道身份桥接"),
    ("dim_sup_tenant_zip", "租户（商户/供应商/分销商）维度", "1行=1个租户×1个有效区间", "ods_sup_tenant_df + ods_sup_tenant_config_df + ods_opr_package_subscription_di", "内部/外部、认证状态、地区、业态、币种/locale、当前套餐"),
    ("dim_sup_staff_zip", "员工维度", "1行=1个员工×1个有效区间", "ods_sup_tenant_staff_df + ods_sup_sys_user_role_df + ods_sup_sys_role_df", "部门、岗位、角色列表、状态"),
    ("dim_sup_org_df", "部门维度", "1行=1个部门", "ods_sup_org_df", "部门树展开为 1~N 级路径"),
    ("dim_sup_position_df", "岗位维度", "1行=1个岗位", "ods_sup_tenant_position_df", ""),
    ("dim_sup_role_df", "角色维度", "1行=1个角色", "ods_sup_sys_role_df + ods_sup_sys_role_permission_df + ods_sup_sys_permission_df", "角色拥有的权限清单"),
    ("dim_trf_channel_df", "渠道/接入端维度", "1行=1个渠道", "ods_trf_channel_df + ods_trf_api_key_df", "渠道类型 MP/PC/API/OFFLINE/H5、作用域、合作方"),
    ("dim_trf_channel_tenant_df", "渠道-租户绑定维度", "1行=1条绑定", "ods_trf_channel_tenant_binding_df", "OTA侧商户ID、子渠道"),
    ("dim_trf_mp_config_df", "小程序配置维度", "1行=1个小程序", "ods_trf_tenant_mp_config_df", "小程序类型（微信/支付宝/抖音）"),
    ("dim_trf_distribution_relation_zip", "分销关系维度", "1行=1条分销关系×1个有效区间", "ods_trf_distribution_relation_df", "分销模式、支付模式、授信额度；4级链路展开 level1~level4 租户"),
    ("dim_fin_account_df", "账户维度", "1行=1个账户", "ods_fin_account_df", "主体、账户类型 MERCHANT/DISTRIBUTOR/PLATFORM"),
    ("dim_fin_bank_card_df", "银行卡维度（脱敏）", "1行=1张卡", "ods_fin_bank_card_df", "银行、卡类型、尾号"),
    ("dim_fin_pay_channel_df", "支付渠道维度", "1行=1个支付渠道配置", "ods_fin_payment_channel_config_df + ods_fin_merchant_payment_config_df", "渠道代码、作用域、商户收款模式（代收/独立）"),
    ("dim_fin_invoice_config_df", "发票配置维度", "1行=1个发票配置", "ods_fin_invoice_config_df", "开票服务商"),
    ("dim_opr_verify_point_df", "核销点维度", "1行=1个核销点", "ods_opr_verify_point_df", "类型 GATE/COUNTER/SELF_SERVICE/HANDHELD、POI、设备分组"),
    ("dim_opr_code_pool_df", "码池维度", "1行=1个码池", "ods_opr_code_pool_df", "单票/套票池、容量、已分配、回收数"),
    ("dim_opr_device_df", "设备维度", "1行=1台设备", "ods_opr_device_df + ods_opr_device_group_df", "设备类型、分组、POI、能力、绑定核销点"),
    ("dim_opr_risk_rule_df", "风控规则维度", "1行=1条规则", "ods_opr_risk_rule_df", "规则类型、维度、阈值、动作"),
    ("dim_opr_package_df", "套餐维度", "1行=1个套餐", "ods_opr_package_df + ods_opr_app_binding_df", "价格、时长、功能、资源额度、含应用"),
    ("dim_opr_app_df", "应用维度", "1行=1个应用", "ods_opr_app_definition_df", ""),
    ("dim_opr_approval_flow_df", "审批流维度", "1行=1个审批流版本", "ods_opr_approval_flow_df", "节点数、超时策略"),
    ("dim_opr_notify_template_df", "通知模板维度", "1行=1个模板", "ods_opr_notify_template_df", "通知渠道、作用域"),
    ("dim_opr_date_f", "日期维度", "1行=1天", "生成", "周几、周末、法定节假日/调休、寒暑假、旺淡季、weekday_mask 位值"),
    ("dim_opr_region_f", "地区维度", "1行=1个末级地区", "ods_opr_region_df + ods_opr_country_df", "国家/省/市/区县 拉平；身份证前6位映射"),
    ("dim_opr_currency_f", "币种维度", "1行=1个币种", "ods_opr_i18n_currency_df", "符号、小数位、对CNY汇率"),
    ("dim_opr_dict_f", "枚举码表", "1行=1个枚举值", "ods_opr_sys_dict_df + 文档状态机枚举", "全部 _type/_status 字段取值及中文含义（满足规范第2条）"),
    ("dim_mkt_coupon_df", "优惠券维度", "1行=1张券模板", "ods_mkt_coupon_df", "券类型、面值、适用SKU、发行量"),
]
assert len(DIM) == 37, len(DIM)

# ---------------------------------------------------------------- DWS
# (表名, 中文名, 粒度, 来源, 指标列表)
DWS = [
    ("dws_ord_tenant_sku_channel_trade_di", "商户×SKU×渠道 交易日汇总",
     "travel_date × seller_tenant_id × sku_id × channel_id × app_ref × operator_type",
     "dwd_ord_order_di, dwd_ord_order_status_log_di, dwd_ord_order_group_di",
     ["order_group_qty", "order_qty", "order_ticket_qty", "order_amt", "pay_order_qty", "pay_ticket_qty", "pay_amt",
      "pay_buyer_qty", "cancel_order_qty", "cancel_amt", "staff_order_qty", "combo_order_qty"]),
    ("dws_ord_sku_play_date_booking_df", "SKU×游玩日 预订存量快照",
     "travel_date（快照日）× sku_id × play_date × time_slot",
     "dwd_ord_order_di, dwd_ord_refund_ticket_di, dwd_ord_verify_di, dwd_inv_pool_snapshot_df",
     ["pay_ticket_qty", "refund_ticket_qty", "net_pay_ticket_qty", "verify_ticket_qty", "advance_book_day_qty", "stock_available_qty"]),
    ("dws_ord_tenant_sku_verify_di", "商户×SKU×核销点 核销日汇总",
     "travel_date × seller_tenant_id × sku_id × verify_point_id × verify_type",
     "dwd_ord_verify_di",
     ["verify_ticket_qty", "verify_entitlement_qty", "verify_person_qty", "verify_fail_qty", "offline_verify_qty", "verify_amt"]),
    ("dws_ord_verify_point_flow_hrs", "核销点分时客流",
     "travel_date × hour × seller_tenant_id × verify_point_id",
     "dwd_ord_verify_di",
     ["verify_person_qty", "verify_fail_qty"]),
    ("dws_ord_tenant_refund_di", "商户×SKU 退款日汇总",
     "travel_date × seller_tenant_id × sku_id × refund_type × initiator_type × refund_reason",
     "dwd_ord_refund_di, dwd_ord_refund_ticket_di",
     ["refund_apply_qty", "refund_success_qty", "refund_ticket_qty", "refund_amt"]),
    ("dws_ord_tenant_entitlement_di", "商户×权益类型 权益使用日汇总",
     "travel_date × seller_tenant_id × sku_id × entitlement_type × binding_type",
     "dwd_ord_entitlement_di, dwd_ord_entitlement_binding_di, dwd_ord_verify_di",
     ["entitlement_issue_qty", "entitlement_used_count", "entitlement_total_count", "quota_total_amt"]),
    ("dws_ord_tenant_ticket_stock_df", "商户×SKU 票状态存量快照",
     "travel_date × seller_tenant_id × sku_id × ticket_status × valid_end_date",
     "dwd_ord_ticket_di, dwd_ord_ticket_status_log_di",
     ["ticket_stock_qty", "unverified_ticket_qty", "unverified_amt", "expire_ticket_qty", "realname_ticket_qty"]),
    ("dws_ord_combo_sku_trade_di", "套票×子项 交易日汇总",
     "travel_date × combo_sku_id × sub_sku_id × sub_seller_tenant_id",
     "dwd_ord_order_di, dwd_ord_refund_ticket_di, dwd_ord_verify_di",
     ["combo_order_qty", "pay_order_qty", "pay_amt", "refund_ticket_qty", "refund_amt", "verify_ticket_qty"]),
    ("dws_cus_customer_trade_di", "游客×商户 交易日汇总",
     "travel_date × buyer_customer_id × seller_tenant_id",
     "dwd_ord_order_di, dwd_ord_refund_ticket_di, dwd_ord_verify_di",
     ["pay_order_qty", "pay_ticket_qty", "pay_amt", "refund_amt", "verify_ticket_qty"]),
    ("dws_cus_customer_lifetime_df", "游客累计至今汇总",
     "travel_date（快照日）× buyer_customer_id × seller_tenant_id",
     "dws_cus_customer_trade_di",
     ["first_pay_date", "last_pay_date", "total_pay_order_qty", "total_pay_amt", "pay_order_qty_30d", "pay_amt_30d", "repurchase_flag"]),
    ("dws_cus_tourist_origin_di", "游客客源画像日汇总",
     "travel_date × seller_tenant_id × sku_id × origin_province × origin_city × age_band × gender",
     "dwd_ord_ticket_person_di, dwd_ord_verify_di",
     ["tourist_qty", "verify_person_qty"]),
    ("dws_sup_tenant_trade_di", "商户经营日汇总",
     "travel_date × seller_tenant_id",
     "dws_ord_tenant_sku_channel_trade_di, dws_ord_tenant_sku_verify_di, dws_ord_tenant_refund_di, dwd_cus_customer_register_di",
     ["pay_order_qty", "pay_ticket_qty", "pay_amt", "refund_amt", "net_pay_amt", "verify_ticket_qty", "verify_amt",
      "pay_buyer_qty", "new_customer_qty", "on_sale_sku_qty"]),
    ("dws_sup_tenant_lifetime_df", "商户累计至今汇总",
     "travel_date（快照日）× seller_tenant_id",
     "dws_sup_tenant_trade_di",
     ["first_pay_date", "last_pay_date", "total_pay_amt", "pay_amt_30d", "active_day_qty_30d"]),
    ("dws_sup_staff_operate_di", "员工操作日汇总（窗口/导游/核销员）",
     "travel_date × tenant_id × staff_id",
     "dwd_ord_order_group_di, dwd_ord_verify_di, dwd_ord_refund_di",
     ["staff_order_qty", "staff_pay_amt", "staff_verify_qty", "staff_refund_qty"]),
    ("dws_trf_distributor_trade_di", "分销商×供应商×SKU×层级 分销日汇总",
     "travel_date × distributor_tenant_id × supplier_tenant_id × sku_id × chain_level",
     "dwd_trf_distribution_settle_di, dwd_ord_refund_ticket_di",
     ["distribution_ticket_qty", "distribution_sale_amt", "distribution_purchase_amt", "distribution_profit_amt", "refund_ticket_qty"]),
    ("dws_trf_distributor_credit_df", "分销关系授信快照",
     "travel_date × relation_no",
     "dim_trf_distribution_relation_zip",
     ["credit_limit_amt", "credit_used_amt", "credit_usage_rate"]),
    ("dws_fin_account_balance_df", "账户余额日快照",
     "travel_date × account_no",
     "ods_fin_account_df, dwd_fin_fund_flow_di",
     ["available_balance_amt", "frozen_balance_amt", "opening_balance_amt", "closing_balance_amt"]),
    ("dws_fin_account_flow_di", "账户×流水类型 资金日汇总",
     "travel_date × account_no × flow_type",
     "dwd_fin_fund_flow_di",
     ["fund_flow_qty", "fund_in_amt", "fund_out_amt"]),
    ("dws_fin_account_frozen_di", "账户×冻结类型 冻结日汇总",
     "travel_date × account_no × freeze_type × external_frozen",
     "dwd_fin_frozen_di",
     ["freeze_amt", "unfreeze_verify_amt", "unfreeze_refund_amt", "freeze_record_qty"]),
    ("dws_fin_tenant_pay_method_di", "商户×支付方式 收付款日汇总",
     "travel_date × tenant_id × pay_direction × pay_method × receive_channel",
     "dwd_fin_payment_di, dwd_fin_refund_payment_di",
     ["pay_record_qty", "inbound_pay_amt", "outbound_pay_amt", "refund_payment_amt", "zero_fee_order_qty"]),
    ("dws_prd_sku_price_di", "SKU×渠道 价格日汇总",
     "travel_date × sku_id × channel",
     "dwd_prd_sku_price_calendar_df, dwd_prd_price_point_log_di, dwd_ord_order_di",
     ["list_price_amt", "price_change_qty", "avg_deal_price_amt", "discount_rate"]),
    ("dws_inv_sku_stock_df", "SKU×库存维度 库存日快照",
     "travel_date × sku_id × pool_no × play_date × room_type/show_time",
     "dwd_inv_pool_snapshot_df, dwd_inv_pool_change_di, dwd_inv_unit_change_di",
     ["stock_total_qty", "stock_available_qty", "stock_frozen_qty", "stock_sold_qty", "sellout_pool_qty", "unit_occupied_qty", "unit_total_qty"]),
    ("dws_opr_device_di", "设备日汇总",
     "travel_date × tenant_id × device_id",
     "dwd_opr_device_status_log_di, dwd_ord_verify_di",
     ["online_minute_qty", "offline_times_qty", "verify_entitlement_qty"]),
    ("dws_opr_risk_rule_hit_di", "风控规则命中日汇总",
     "travel_date × rule_id × action × dimension",
     "dwd_opr_risk_event_di, dwd_opr_blacklist_log_di, dwd_opr_account_ban_di",
     ["risk_hit_qty", "risk_block_qty", "blacklist_add_qty", "ban_qty"]),
    ("dws_opr_complaint_di", "投诉日汇总",
     "travel_date × tenant_id × complaint_type × complainant_type",
     "dwd_opr_complaint_di",
     ["complaint_qty", "complaint_resolved_qty", "complaint_overdue_qty"]),
    ("dws_opr_notify_di", "通知发送日汇总",
     "travel_date × tenant_id × notify_channel × template_code",
     "dwd_opr_notify_di",
     ["notify_send_qty", "notify_success_qty", "sms_send_qty"]),
    ("dws_opr_audit_action_di", "操作审计日汇总",
     "travel_date × tenant_id × operator_type × operator_id × action",
     "dwd_opr_audit_log_di",
     ["audit_action_qty", "night_action_qty"]),
    ("dws_opr_approval_di", "审批日汇总",
     "travel_date × tenant_id × flow_code",
     "dwd_opr_approval_di",
     ["approval_qty", "approval_pass_qty", "approval_reject_qty", "approval_minute_qty"]),
    ("dws_opr_package_subscription_df", "套餐订购存量快照",
     "travel_date × package_id × subscription_type",
     "dwd_opr_package_subscription_di",
     ["active_subscription_qty", "package_amt", "expiring_30d_subscription_qty", "package_renew_qty"]),
]
assert len(DWS) == 29, len(DWS)

# ---------------------------------------------------------------- ADS
# (表名, 中文名, 粒度, 来源, 指标, 使用端)
ADS = [
    ("ads_ord_tenant_trade_overview_di", "商户经营概览", "travel_date × seller_tenant_id", "dws_sup_tenant_trade_di",
     ["pay_amt", "net_pay_amt", "pay_order_qty", "pay_ticket_qty", "verify_ticket_qty", "refund_amt", "per_customer_amt", "avg_ticket_price_amt", "verify_rate", "refund_rate", "pay_amt_dod_rate", "pay_amt_wow_rate"], "商户后台"),
    ("ads_ord_sku_sales_rank_di", "SKU销售排行", "travel_date × seller_tenant_id × sku_id", "dws_ord_tenant_sku_channel_trade_di",
     ["pay_amt", "pay_ticket_qty", "avg_ticket_price_amt", "pay_conversion_rate", "sku_pay_amt_rank"], "商户后台"),
    ("ads_ord_channel_sales_structure_di", "渠道销售结构", "travel_date × seller_tenant_id × channel_id", "dws_ord_tenant_sku_channel_trade_di",
     ["pay_amt", "pay_ticket_qty", "channel_pay_amt_share", "staff_order_qty"], "商户后台"),
    ("ads_ord_verify_flow_hrs", "分时客流（入园人次）", "travel_date × hour × seller_tenant_id × verify_point_id", "dws_ord_verify_point_flow_hrs",
     ["verify_person_qty", "peak_hour_verify_qty", "verify_fail_rate"], "商户后台/大屏"),
    ("ads_ord_play_date_booking_df", "未来游玩日预订看板", "travel_date × sku_id × play_date", "dws_ord_sku_play_date_booking_df, dws_inv_sku_stock_df",
     ["net_pay_ticket_qty", "stock_available_qty", "stock_sell_through_rate", "avg_advance_book_day_qty"], "商户后台"),
    ("ads_ord_refund_analysis_di", "退款分析", "travel_date × seller_tenant_id × refund_reason × initiator_type", "dws_ord_tenant_refund_di, dws_sup_tenant_trade_di",
     ["refund_ticket_qty", "refund_amt", "refund_rate", "refund_amt_rate", "cancel_rate"], "商户后台"),
    ("ads_ord_entitlement_usage_di", "权益使用分析（年卡/次卡/计时/额度）", "travel_date × seller_tenant_id × entitlement_type", "dws_ord_tenant_entitlement_di, dws_ord_tenant_ticket_stock_df",
     ["entitlement_used_count", "entitlement_usage_rate", "unverified_ticket_qty", "expire_rate"], "商户后台"),
    ("ads_cus_tourist_portrait_di", "游客客源画像", "travel_date × seller_tenant_id × origin_province × age_band × gender", "dws_cus_tourist_origin_di",
     ["tourist_qty", "tourist_origin_share", "realname_rate"], "商户后台"),
    ("ads_cus_customer_rfm_df", "会员RFM与复购", "travel_date × seller_tenant_id × rfm_segment", "dws_cus_customer_lifetime_df",
     ["pay_buyer_qty", "repurchase_rate", "per_customer_amt"], "商户后台"),
    ("ads_inv_stock_sellout_df", "库存售罄与上座率", "travel_date × sku_id × play_date", "dws_inv_sku_stock_df",
     ["stock_total_qty", "stock_sold_qty", "stock_sell_through_rate", "stock_sellout_rate"], "商户后台"),
    ("ads_prd_price_discount_di", "价格与折扣分析", "travel_date × sku_id × channel", "dws_prd_sku_price_di",
     ["list_price_amt", "avg_deal_price_amt", "discount_rate", "price_change_qty"], "商户后台"),
    ("ads_trf_distributor_rank_di", "分销商业绩排行", "travel_date × supplier_tenant_id × distributor_tenant_id", "dws_trf_distributor_trade_di",
     ["distribution_ticket_qty", "distribution_sale_amt", "distribution_profit_amt", "active_distributor_qty"], "供应商后台"),
    ("ads_trf_chain_profit_di", "分销链利润分配", "travel_date × supplier_tenant_id × sku_id × chain_level", "dws_trf_distributor_trade_di",
     ["distribution_purchase_amt", "distribution_profit_amt", "distribution_profit_rate"], "供应商/平台"),
    ("ads_fin_tenant_settlement_di", "商户结算对账", "travel_date × tenant_id", "dws_fin_account_frozen_di, dws_fin_account_flow_di, dws_fin_tenant_pay_method_di",
     ["inbound_pay_amt", "outbound_pay_amt", "freeze_amt", "unfreeze_verify_amt", "unfreeze_refund_amt", "refund_payment_amt"], "商户后台/财务"),
    ("ads_fin_account_fund_df", "账户资金看板", "travel_date × account_no", "dws_fin_account_balance_df, dws_trf_distributor_credit_df",
     ["available_balance_amt", "frozen_balance_amt", "credit_usage_rate", "withdraw_success_amt"], "商户后台/财务"),
    ("ads_fin_pay_method_di", "支付方式结构", "travel_date × tenant_id × pay_method", "dws_fin_tenant_pay_method_di",
     ["inbound_pay_amt", "pay_record_qty", "pay_method_amt_share", "zero_fee_order_qty"], "商户后台/财务"),
    ("ads_sup_staff_performance_di", "员工/窗口业绩", "travel_date × tenant_id × staff_id", "dws_sup_staff_operate_di",
     ["staff_order_qty", "staff_pay_amt", "staff_verify_qty", "staff_refund_qty"], "商户后台"),
    ("ads_sup_platform_overview_di", "平台经营大盘", "travel_date", "dws_sup_tenant_trade_di, dws_opr_package_subscription_df",
     ["pay_amt", "net_pay_amt", "verify_ticket_qty", "active_tenant_qty", "new_tenant_qty", "new_customer_qty", "pay_amt_dod_rate"], "平台后台"),
    ("ads_sup_tenant_lifecycle_df", "商户生命周期（活跃/沉默/流失）", "travel_date × tenant_lifecycle_stage", "dws_sup_tenant_lifetime_df",
     ["active_tenant_qty", "tenant_active_rate", "silent_tenant_qty", "churn_tenant_qty"], "平台后台"),
    ("ads_opr_package_revenue_mo", "套餐收入与续费（月）", "月 × package_id", "dws_opr_package_subscription_df",
     ["package_amt", "active_subscription_qty", "package_renew_rate"], "平台后台"),
    ("ads_opr_risk_monitor_di", "风控监控", "travel_date × rule_id × action", "dws_opr_risk_rule_hit_di, dws_opr_audit_action_di",
     ["risk_hit_qty", "risk_block_qty", "risk_block_rate", "blacklist_add_qty", "night_action_qty"], "平台后台"),
    ("ads_opr_device_health_di", "设备健康", "travel_date × tenant_id × device_type", "dws_opr_device_di",
     ["device_online_rate", "offline_times_qty", "offline_verify_rate"], "商户/平台"),
    ("ads_opr_complaint_sla_di", "投诉与SLA", "travel_date × tenant_id × complaint_type", "dws_opr_complaint_di",
     ["complaint_qty", "complaint_sla_rate"], "平台后台"),
    ("ads_opr_notify_cost_di", "通知与短信消耗", "travel_date × tenant_id × notify_channel", "dws_opr_notify_di, dwd_fin_resource_batch_di",
     ["notify_send_qty", "notify_success_rate", "sms_send_qty", "resource_consume_qty"], "商户/平台"),
    ("ads_sup_tenant_trade_wk", "商户经营周报", "自然周 × seller_tenant_id", "dws_sup_tenant_trade_di",
     ["pay_amt", "net_pay_amt", "verify_ticket_qty", "refund_rate", "pay_amt_wow_rate"], "商户后台"),
    ("ads_sup_tenant_trade_mo", "商户经营月报", "自然月 × seller_tenant_id", "dws_sup_tenant_trade_di",
     ["pay_amt", "net_pay_amt", "verify_ticket_qty", "refund_rate", "pay_amt_mom_rate"], "商户后台"),
]
assert len(ADS) == 26, len(ADS)

# ---------------------------------------------------------------- 实时
RT = [
    ("ODS", "ods_ord_order_group_rt", "聚合单 binlog 流", "t_order_group"),
    ("ODS", "ods_ord_order_rt", "子单 binlog 流", "t_order"),
    ("ODS", "ods_ord_ticket_rt", "票 binlog 流", "t_ticket"),
    ("ODS", "ods_ord_entitlement_rt", "权益 binlog 流", "t_entitlement"),
    ("ODS", "ods_ord_verify_record_rt", "核销记录 binlog 流", "t_verify_record"),
    ("ODS", "ods_ord_ticket_credential_rt", "票凭证 binlog 流", "t_ticket_credential"),
    ("ODS", "ods_ord_refund_order_rt", "退款单 binlog 流", "t_refund_order"),
    ("ODS", "ods_fin_payment_record_rt", "支付记录 binlog 流", "t_payment_record"),
    ("ODS", "ods_fin_frozen_record_rt", "冻结记录 binlog 流", "t_frozen_record"),
    ("ODS", "ods_fin_fund_flow_rt", "资金流水 binlog 流", "t_fund_flow"),
    ("ODS", "ods_inv_inventory_pool_rt", "库存池 binlog 流", "t_inventory_pool"),
    ("ODS", "ods_inv_inventory_unit_rt", "座位/房间 binlog 流", "t_inventory_unit"),
    ("ODS", "ods_opr_risk_event_rt", "风控事件 binlog 流", "t_risk_event"),
    ("DWD", "dwd_ord_order_rt", "实时下单明细", "ods_ord_order_rt + ods_ord_order_group_rt"),
    ("DWD", "dwd_fin_payment_rt", "实时支付明细", "ods_fin_payment_record_rt"),
    ("DWD", "dwd_ord_verify_rt", "实时核销明细", "ods_ord_verify_record_rt + ods_ord_entitlement_rt"),
    ("DWD", "dwd_ord_refund_rt", "实时退款明细", "ods_ord_refund_order_rt"),
    ("DWD", "dwd_inv_pool_change_rt", "实时库存变动", "ods_inv_inventory_pool_rt + ods_inv_inventory_unit_rt"),
    ("DWD", "dwd_fin_frozen_rt", "实时冻结/解冻", "ods_fin_frozen_record_rt"),
    ("DWS", "dws_ord_tenant_sku_trade_rt", "商户×SKU 分钟级交易", "dwd_ord_order_rt + dwd_fin_payment_rt + dwd_ord_refund_rt"),
    ("DWS", "dws_ord_verify_point_flow_rt", "核销点 分钟级客流", "dwd_ord_verify_rt"),
    ("DWS", "dws_inv_sku_stock_rt", "SKU 实时库存", "dwd_inv_pool_change_rt"),
    ("ADS", "ads_ord_realtime_sales_rt", "实时销售看板（对应 DP08）", "dws_ord_tenant_sku_trade_rt"),
    ("ADS", "ads_inv_realtime_stock_rt", "实时库存看板（对应 DP09）", "dws_inv_sku_stock_rt"),
    ("ADS", "ads_ord_realtime_flow_rt", "实时客流大屏", "dws_ord_verify_point_flow_rt"),
    ("ADS", "ads_opr_risk_alert_rt", "实时风控预警", "ods_opr_risk_event_rt + dwd_ord_verify_rt"),
]
assert len(RT) == 26

# ---------------------------------------------------------------- 指标字典
# (英文名, 中文名, 类型, 域, 口径, 计算逻辑, 单位, 来源DWD/DWS)
A, D, C = "原子指标", "派生指标", "计算指标"
M = [
    # 交易
    ("order_group_qty", "下单聚合单数", A, "ord", "统计周期内创建的聚合单数（一次购物车结算）", "count(distinct order_group_no)", "单", "dwd_ord_order_group_di"),
    ("order_qty", "下单子单数", A, "ord", "统计周期内创建的子单数；套票只算主单，子项单另计", "count(distinct order_no) where combo 子项除外", "单", "dwd_ord_order_di"),
    ("order_ticket_qty", "下单票数", A, "ord", "下单购买数量合计", "sum(buy_ticket_qty)", "张", "dwd_ord_order_di"),
    ("order_amt", "下单金额", A, "ord", "下单时 单价×数量 合计", "sum(unit_price_amt*buy_ticket_qty)", "元", "dwd_ord_order_di"),
    ("pay_order_qty", "支付子单数", A, "ord", "统计周期内首次变为 PAID 的子单数", "count(distinct order_no) where after_status='PAID'", "单", "dwd_ord_order_status_log_di"),
    ("pay_ticket_qty", "支付票数", A, "ord", "支付成功子单的购买数量合计", "sum(buy_ticket_qty) of paid orders", "张", "dwd_ord_order_di"),
    ("pay_amt", "支付金额（GMV）", A, "ord", "支付成功子单的成交金额，不扣退款", "sum(unit_price_amt*buy_ticket_qty) of paid orders", "元", "dwd_ord_order_di"),
    ("pay_buyer_qty", "支付买家数", A, "ord", "有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家", "count(distinct buyer_customer_id) where buyer_customer_id>0 and kind='REAL'", "人", "dwd_ord_order_di"),
    ("cancel_order_qty", "取消子单数", A, "ord", "超时未付等原因变为 CANCELLED 的子单数", "count(distinct order_no) where after_status='CANCELLED'", "单", "dwd_ord_order_status_log_di"),
    ("cancel_amt", "取消金额", A, "ord", "取消子单的下单金额", "sum(order_amt) of cancelled orders", "元", "dwd_ord_order_di"),
    ("staff_order_qty", "员工代下单数", A, "ord", "操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API）", "count(order_no) where operator_type='TENANT_STAFF'", "单", "dwd_ord_order_di"),
    ("combo_order_qty", "套票主单数", A, "ord", "combo_flag=1 的子单数", "count(order_no) where combo_flag=1", "单", "dwd_ord_order_di"),
    ("issue_ticket_qty", "出票张数", A, "ord", "统计周期内生成的票数", "count(ticket_no)", "张", "dwd_ord_ticket_di"),
    ("issue_credential_qty", "发码数", A, "ord", "统计周期内发放的票凭证数", "count(credential_no)", "个", "dwd_ord_ticket_credential_di"),
    ("revoke_credential_qty", "凭证撤销数", A, "ord", "状态变为 REVOKED 的凭证数", "count(credential_no) where status='REVOKED'", "个", "dwd_ord_ticket_credential_di"),
    ("verify_ticket_qty", "核销票数", A, "ord", "统计周期内有成功核销的票数（同票多次只算1）", "count(distinct ticket_no) where verify_result='SUCCESS'", "张", "dwd_ord_verify_di"),
    ("verify_entitlement_qty", "核销权益次数", A, "ord", "成功核销记录条数（年卡/次卡每次都计）", "count(verify_no) where verify_result='SUCCESS'", "次", "dwd_ord_verify_di"),
    ("verify_person_qty", "核销人次（入园人次）", A, "ord", "成功核销放行人次；源表未存放行人数，暂按核销次数计，待补 pass_count", "count(verify_no) where SUCCESS（待补放行人数后改 sum(pass_count)）", "人次", "dwd_ord_verify_di"),
    ("verify_fail_qty", "核销失败次数", A, "ord", "核销结果为 FAILED/DUPLICATE 的次数", "count(verify_no) where verify_result in ('FAILED','DUPLICATE')", "次", "dwd_ord_verify_di"),
    ("offline_verify_qty", "离线核销次数", A, "ord", "verify_type=OFFLINE 的成功核销次数", "count(verify_no) where verify_type='OFFLINE' and SUCCESS", "次", "dwd_ord_verify_di"),
    ("verify_amt", "核销金额", A, "ord", "成功核销票对应的分摊单价（收入确认口径）", "sum(unit_price_amt) of verified tickets（同票只计1次）", "元", "dwd_ord_verify_di"),
    ("refund_apply_qty", "退款申请单数", A, "ord", "统计周期内创建的退款单数", "count(refund_no)", "单", "dwd_ord_refund_di"),
    ("refund_success_qty", "退款完成单数", A, "ord", "状态为 COMPLETED 的退款单数", "count(refund_no) where refund_status='COMPLETED'", "单", "dwd_ord_refund_di"),
    ("refund_ticket_qty", "退款票数", A, "ord", "退款完成的票数（refund_items 展开）", "count(distinct ticket_no) of completed refunds", "张", "dwd_ord_refund_ticket_di"),
    ("refund_amt", "退款金额", A, "ord", "退款完成的金额", "sum(refund_amt) where COMPLETED", "元", "dwd_ord_refund_ticket_di"),
    ("expire_ticket_qty", "过期票数", A, "ord", "统计周期内变为 EXPIRED 的票数", "count(ticket_no) where after_status='EXPIRED'", "张", "dwd_ord_ticket_status_log_di"),
    ("ticket_stock_qty", "票存量", A, "ord", "快照日各状态票数", "count(ticket_no) group by ticket_status", "张", "dwd_ord_ticket_di"),
    ("unverified_ticket_qty", "未核销在途票数", A, "ord", "快照日状态为 AVAILABLE/PARTIALLY_USED 且未过期的票数", "count(ticket_no) where status in (AVAILABLE,PARTIALLY_USED) and valid_end>=snapshot", "张", "dwd_ord_ticket_di"),
    ("unverified_amt", "未核销在途金额（预收）", A, "ord", "在途票对应的分摊单价合计", "sum(unit_price_amt) of unverified tickets", "元", "dwd_ord_ticket_di"),
    ("realname_ticket_qty", "实名票数", A, "ord", "票上至少登记1名游客的票数", "count(ticket_no) where person_qty>0", "张", "dwd_ord_ticket_person_di"),
    ("tourist_qty", "游客人数", A, "ord", "票上登记的游客人数", "count(ticket_no||person_id)", "人", "dwd_ord_ticket_person_di"),
    ("entitlement_issue_qty", "发放权益数", A, "ord", "统计周期内生成的权益数", "count(entitlement_no)", "个", "dwd_ord_entitlement_di"),
    ("entitlement_used_count", "权益已用次数", A, "ord", "权益 used_count 合计", "sum(used_count)", "次", "dwd_ord_entitlement_di"),
    ("entitlement_total_count", "权益可用总次数", A, "ord", "计次/选择型 maxCount、固定型 1 的合计；不限次型不计", "sum(max_count)", "次", "dwd_ord_entitlement_di"),
    ("quota_total_amt", "额度型权益总额度", A, "ord", "QUOTA 权益 quotaAmount 合计（已用额度源表缺失）", "sum(quota_amt) where type='QUOTA'", "元", "dwd_ord_entitlement_di"),
    ("advance_book_day_qty", "提前预订天数", A, "ord", "游玩日 − 支付日", "datediff(play_date, pay_date)", "天", "dwd_ord_order_di"),
    ("net_pay_ticket_qty", "净支付票数", D, "ord", "支付票数 − 退款票数", "pay_ticket_qty - refund_ticket_qty", "张", "dws_ord_sku_play_date_booking_df"),
    # 游客
    ("new_customer_qty", "新注册游客数", A, "cus", "首次登录建档的真实游客数（剔除 TENANT_DEFAULT）", "count(customer_id) where kind='REAL'", "人", "dwd_cus_customer_register_di"),
    ("first_pay_date", "首次支付日期", A, "cus", "游客/商户首次有支付的日期", "min(pay_date)", "日期", "dws_cus_customer_trade_di"),
    ("last_pay_date", "最近支付日期", A, "cus", "游客/商户最近一次支付的日期", "max(pay_date)", "日期", "dws_cus_customer_trade_di"),
    ("total_pay_order_qty", "累计支付单数", D, "cus", "截至快照日累计支付子单数", "sum(pay_order_qty) 全历史", "单", "dws_cus_customer_trade_di"),
    ("total_pay_amt", "累计支付金额", D, "cus", "截至快照日累计支付金额", "sum(pay_amt) 全历史", "元", "dws_cus_customer_trade_di"),
    ("pay_order_qty_30d", "近30天支付单数", D, "cus", "近30天支付子单数", "sum(pay_order_qty) 近30天", "单", "dws_cus_customer_trade_di"),
    ("pay_amt_30d", "近30天支付金额", D, "cus", "近30天支付金额", "sum(pay_amt) 近30天", "元", "dws_cus_customer_trade_di"),
    ("repurchase_flag", "是否复购", D, "cus", "近30天支付子单数≥2", "case when pay_order_qty_30d>=2 then 1 else 0 end", "0/1", "dws_cus_customer_lifetime_df"),
    # 商户
    ("on_sale_sku_qty", "在售SKU数", A, "prd", "快照日状态为 PUBLISHED 的SKU数", "count(sku_id) where sku_status='PUBLISHED'", "个", "dim_prd_sku_zip"),
    ("active_day_qty_30d", "近30天动销天数", D, "sup", "近30天有支付的天数", "count(distinct travel_date) where pay_amt>0 近30天", "天", "dws_sup_tenant_trade_di"),
    ("active_tenant_qty", "动销商户数", A, "sup", "统计周期内有支付的卖家租户数", "count(distinct seller_tenant_id) where pay_amt>0", "家", "dws_sup_tenant_trade_di"),
    ("new_tenant_qty", "新入驻商户数", A, "sup", "统计周期内新建的外部租户数", "count(tenant_id) where tenant_type='EXTERNAL'", "家", "dim_sup_tenant_zip"),
    ("silent_tenant_qty", "沉默商户数", D, "sup", "近30天无支付但历史有支付的商户数", "count where pay_amt_30d=0 and total_pay_amt>0", "家", "dws_sup_tenant_lifetime_df"),
    ("churn_tenant_qty", "流失商户数", D, "sup", "近90天无支付且套餐已到期的商户数（阈值待定）", "count where last_pay_date<snapshot-90", "家", "dws_sup_tenant_lifetime_df"),
    ("staff_pay_amt", "员工代下单支付金额", A, "sup", "员工代下单且已支付的金额", "sum(pay_amt) where operator_type='TENANT_STAFF'", "元", "dwd_ord_order_di"),
    ("staff_verify_qty", "员工核销次数", A, "sup", "按 operator_id 统计的成功核销次数", "count(verify_no) group by operator_id", "次", "dwd_ord_verify_di"),
    ("staff_refund_qty", "员工发起退款单数", A, "sup", "initiator_type=MERCHANT 的退款单数", "count(refund_no) group by initiator_id", "单", "dwd_ord_refund_di"),
    # 分销
    ("distribution_ticket_qty", "分销票数", A, "trf", "经过分销链（有 OUTBOUND 采购）的票数", "count(distinct ticket_no)", "张", "dwd_trf_distribution_settle_di"),
    ("distribution_sale_amt", "分销售出金额", A, "trf", "本级卖出价（下级付给本级的金额）", "sum(amount) by chain_level", "元", "dwd_trf_distribution_settle_di"),
    ("distribution_purchase_amt", "分销采购金额", A, "trf", "本级向上级采购的金额", "sum(settle_amount) by chain_level", "元", "dwd_trf_distribution_settle_di"),
    ("distribution_profit_amt", "分销利润", A, "trf", "本级售出 − 本级采购", "sum(amount - settle_amount)", "元", "dwd_trf_distribution_settle_di"),
    ("active_distributor_qty", "动销分销商数", A, "trf", "统计周期内有分销票的分销商数", "count(distinct distributor_tenant_id)", "家", "dws_trf_distributor_trade_di"),
    ("credit_limit_amt", "授信额度", A, "trf", "分销关系授信额度", "credit_limit/100", "元", "dim_trf_distribution_relation_zip"),
    ("credit_used_amt", "已用授信", A, "trf", "分销关系已用授信", "credit_used/100", "元", "dim_trf_distribution_relation_zip"),
    # 财务
    ("pay_record_qty", "支付笔数", A, "fin", "状态为 PAID 的支付记录数", "count(payment_no) where pay_status='PAID'", "笔", "dwd_fin_payment_di"),
    ("inbound_pay_amt", "收款金额", A, "fin", "INBOUND 方向已支付金额", "sum(amount) where pay_direction='INBOUND' and PAID", "元", "dwd_fin_payment_di"),
    ("outbound_pay_amt", "采购付款金额", A, "fin", "OUTBOUND 方向已支付金额", "sum(amount) where pay_direction='OUTBOUND' and PAID", "元", "dwd_fin_payment_di"),
    ("zero_fee_order_qty", "0元单数", A, "fin", "pay_method=ZERO_FEE 的支付记录数", "count(payment_no) where pay_method='ZERO_FEE'", "笔", "dwd_fin_payment_di"),
    ("refund_payment_amt", "退款资金金额", A, "fin", "退款明细状态 SUCCESS 的金额", "sum(refund_amount) where status='SUCCESS'", "元", "dwd_fin_refund_payment_di"),
    ("freeze_amt", "冻结金额", A, "fin", "统计周期内新建冻结记录金额", "sum(amount) by create_date", "元", "dwd_fin_frozen_di"),
    ("unfreeze_verify_amt", "核销解冻金额", A, "fin", "因核销释放的冻结金额", "sum(amount) where frozen_status='RELEASED' and frozen_event='VERIFY'", "元", "dwd_fin_frozen_di"),
    ("unfreeze_refund_amt", "退款释放金额", A, "fin", "因退款释放的冻结金额", "sum(amount) where RELEASED and frozen_event='REFUND'", "元", "dwd_fin_frozen_di"),
    ("freeze_record_qty", "冻结记录数", A, "fin", "新建冻结记录条数", "count(frozen_no)", "条", "dwd_fin_frozen_di"),
    ("available_balance_amt", "可用余额", A, "fin", "日终账户可用余额", "available_balance/100", "元", "ods_fin_account_df"),
    ("frozen_balance_amt", "冻结余额", A, "fin", "日终账户冻结余额", "frozen_balance/100", "元", "ods_fin_account_df"),
    ("opening_balance_amt", "期初余额", A, "fin", "当日第一条流水的变动前余额", "first(balance_before)", "元", "dwd_fin_fund_flow_di"),
    ("closing_balance_amt", "期末余额", A, "fin", "当日最后一条流水的变动后余额", "last(balance_after)", "元", "dwd_fin_fund_flow_di"),
    ("fund_flow_qty", "资金流水笔数", A, "fin", "流水条数", "count(flow_no)", "笔", "dwd_fin_fund_flow_di"),
    ("fund_in_amt", "资金流入", A, "fin", "amount>0 的流水金额", "sum(amount) where amount>0", "元", "dwd_fin_fund_flow_di"),
    ("fund_out_amt", "资金流出", A, "fin", "amount<0 的流水金额绝对值", "sum(-amount) where amount<0", "元", "dwd_fin_fund_flow_di"),
    ("withdraw_success_amt", "提现成功金额", A, "fin", "状态 COMPLETED 的提现金额", "sum(withdraw_amount) where COMPLETED", "元", "dwd_fin_withdraw_di"),
    ("resource_consume_qty", "资源包消耗量", A, "fin", "资源批次剩余量日差", "sum(prev_remaining - remaining)", "条/点", "dwd_fin_resource_batch_di"),
    # 价格/库存
    ("list_price_amt", "生效标价", A, "prd", "当日按价格点优先级命中的售价", "price/100 from 价格日历", "元", "dwd_prd_sku_price_calendar_df"),
    ("price_change_qty", "调价次数", A, "prd", "价格点新增/修改/删除次数", "count(*)", "次", "dwd_prd_price_point_log_di"),
    ("stock_total_qty", "库存总量", A, "inv", "日终库存池总量", "sum(total_quantity)", "个", "dwd_inv_pool_snapshot_df"),
    ("stock_available_qty", "可用库存", A, "inv", "日终库存池可用量", "sum(available_quantity)", "个", "dwd_inv_pool_snapshot_df"),
    ("stock_frozen_qty", "预扣库存", A, "inv", "日终库存池预扣冻结量", "sum(frozen_quantity)", "个", "dwd_inv_pool_snapshot_df"),
    ("stock_sold_qty", "已售库存", A, "inv", "总量 − 可用 − 预扣", "sum(total - available - frozen)", "个", "dwd_inv_pool_snapshot_df"),
    ("sellout_pool_qty", "售罄库存池数", A, "inv", "可用量为0且在售的池数", "count(pool_no) where available=0 and status='ON_SALE'", "个", "dwd_inv_pool_snapshot_df"),
    ("unit_occupied_qty", "已占用座位/房间数", A, "inv", "UNIT 资源状态为 OCCUPIED 的数量", "count(unit_no) where status='OCCUPIED'", "个", "dwd_inv_unit_change_di"),
    ("unit_total_qty", "座位/房间总数", A, "inv", "UNIT 资源总数", "count(unit_no)", "个", "dim_inv_unit_df"),
    # 运营
    ("online_minute_qty", "设备在线时长", A, "opr", "状态为 ACTIVE 的累计分钟数", "sum(状态区间分钟) where ACTIVE", "分钟", "dwd_opr_device_status_log_di"),
    ("offline_times_qty", "设备离线次数", A, "opr", "变为 OFFLINE 的次数", "count(*) where after_status='OFFLINE'", "次", "dwd_opr_device_status_log_di"),
    ("risk_hit_qty", "风控命中次数", A, "opr", "风控事件数", "count(event_no)", "次", "dwd_opr_risk_event_di"),
    ("risk_block_qty", "风控拦截次数", A, "opr", "action=BLOCK 的事件数", "count(event_no) where action='BLOCK'", "次", "dwd_opr_risk_event_di"),
    ("blacklist_add_qty", "新增黑名单数", A, "opr", "新增黑名单记录数", "count(blacklist_no) where 新增", "条", "dwd_opr_blacklist_log_di"),
    ("ban_qty", "封禁数", A, "opr", "新增封禁记录数", "count(ban_no)", "条", "dwd_opr_account_ban_di"),
    ("complaint_qty", "投诉数", A, "opr", "新建投诉工单数", "count(complaint_no)", "单", "dwd_opr_complaint_di"),
    ("complaint_resolved_qty", "投诉解决数", A, "opr", "状态为 RESOLVED/CLOSED 的工单数", "count where status in ('RESOLVED','CLOSED')", "单", "dwd_opr_complaint_di"),
    ("complaint_overdue_qty", "投诉超SLA数", A, "opr", "解决时间晚于 sla_deadline 或未解决已过期的工单数", "count where 解决时间>sla_deadline", "单", "dwd_opr_complaint_di"),
    ("notify_send_qty", "通知发送数", A, "opr", "通知记录数", "count(notify_no)", "条", "dwd_opr_notify_di"),
    ("notify_success_qty", "通知成功数", A, "opr", "send_status=SUCCESS 的记录数", "count where SUCCESS", "条", "dwd_opr_notify_di"),
    ("sms_send_qty", "短信发送数", A, "opr", "notify_channel=SMS 的记录数", "count where notify_channel='SMS'", "条", "dwd_opr_notify_di"),
    ("audit_action_qty", "操作次数", A, "opr", "审计日志条数", "count(log_no)", "次", "dwd_opr_audit_log_di"),
    ("night_action_qty", "凌晨操作次数", A, "opr", "0~6点的写操作次数（风控关注）", "count where hour(create_time) between 0 and 5", "次", "dwd_opr_audit_log_di"),
    ("approval_qty", "审批发起数", A, "opr", "新建审批实例数", "count(instance_no)", "个", "dwd_opr_approval_di"),
    ("approval_pass_qty", "审批通过数", A, "opr", "状态 APPROVED 的实例数", "count where APPROVED", "个", "dwd_opr_approval_di"),
    ("approval_reject_qty", "审批拒绝数", A, "opr", "状态 REJECTED 的实例数", "count where REJECTED", "个", "dwd_opr_approval_di"),
    ("approval_minute_qty", "平均审批耗时", A, "opr", "审批结束时间 − 发起时间（分钟）的平均值", "avg(minutes(update_time - create_time)) where 已结束", "分钟", "dwd_opr_approval_di"),
    ("active_subscription_qty", "生效套餐订购数", A, "opr", "快照日处于生效期的订购数", "count where start_at<=snapshot<=expire_at", "个", "dwd_opr_package_subscription_di"),
    ("package_amt", "套餐金额", A, "opr", "订购对应套餐价格", "sum(package_price)/100", "元", "dwd_opr_package_subscription_di"),
    ("expiring_30d_subscription_qty", "30天内到期订购数", A, "opr", "到期时间在未来30天内的生效订购数", "count where expire_at<=snapshot+30", "个", "dwd_opr_package_subscription_di"),
    ("package_renew_qty", "续费订购数", A, "opr", "subscription_type=RENEW 的订购数", "count where type='RENEW'", "个", "dwd_opr_package_subscription_di"),
    # 计算指标
    ("net_pay_amt", "净成交金额", C, "ord", "支付金额 − 退款金额", "pay_amt - refund_amt", "元", "dws_sup_tenant_trade_di"),
    ("pay_conversion_rate", "下单支付转化率", C, "ord", "支付子单数 / 下单子单数", "pay_order_qty / order_qty", "%", "dws_ord_tenant_sku_channel_trade_di"),
    ("avg_ticket_price_amt", "平均票价", C, "ord", "支付金额 / 支付票数", "pay_amt / pay_ticket_qty", "元", "dws_ord_tenant_sku_channel_trade_di"),
    ("per_customer_amt", "客单价", C, "ord", "支付金额 / 支付买家数", "pay_amt / pay_buyer_qty", "元", "dws_sup_tenant_trade_di"),
    ("verify_rate", "核销率", C, "ord", "同一支付日的票中已核销的比例", "verify_ticket_qty / pay_ticket_qty（按支付日 cohort）", "%", "dws_ord_tenant_ticket_stock_df"),
    ("refund_rate", "退票率", C, "ord", "退款票数 / 支付票数", "refund_ticket_qty / pay_ticket_qty", "%", "dws_sup_tenant_trade_di"),
    ("refund_amt_rate", "退款金额率", C, "ord", "退款金额 / 支付金额", "refund_amt / pay_amt", "%", "dws_sup_tenant_trade_di"),
    ("cancel_rate", "取消率", C, "ord", "取消子单数 / 下单子单数", "cancel_order_qty / order_qty", "%", "dws_ord_tenant_sku_channel_trade_di"),
    ("expire_rate", "过期率", C, "ord", "过期票数 / 出票张数", "expire_ticket_qty / issue_ticket_qty", "%", "dws_ord_tenant_ticket_stock_df"),
    ("entitlement_usage_rate", "权益使用率", C, "ord", "已用次数 / 可用总次数", "entitlement_used_count / entitlement_total_count", "%", "dws_ord_tenant_entitlement_di"),
    ("avg_advance_book_day_qty", "平均提前预订天数", C, "ord", "提前预订天数按票加权平均", "sum(advance_book_day_qty*票数)/sum(票数)", "天", "dws_ord_sku_play_date_booking_df"),
    ("realname_rate", "实名率", C, "ord", "实名票数 / 出票张数", "realname_ticket_qty / issue_ticket_qty", "%", "dws_ord_tenant_ticket_stock_df"),
    ("verify_fail_rate", "核销失败率", C, "ord", "失败次数 /（成功+失败次数）", "verify_fail_qty / (verify_entitlement_qty+verify_fail_qty)", "%", "dws_ord_tenant_sku_verify_di"),
    ("offline_verify_rate", "离线核销占比", C, "ord", "离线核销次数 / 核销次数", "offline_verify_qty / verify_entitlement_qty", "%", "dws_ord_tenant_sku_verify_di"),
    ("peak_hour_verify_qty", "峰值小时入园人次", C, "ord", "当日各小时入园人次的最大值", "max(verify_person_qty) over hours", "人次", "dws_ord_verify_point_flow_hrs"),
    ("tourist_origin_share", "客源地占比", C, "cus", "某客源地游客数 / 全部游客数", "tourist_qty / sum(tourist_qty)", "%", "dws_cus_tourist_origin_di"),
    ("repurchase_rate", "复购率", C, "cus", "复购买家数 / 支付买家数", "sum(repurchase_flag) / count(buyer)", "%", "dws_cus_customer_lifetime_df"),
    ("channel_pay_amt_share", "渠道销售占比", C, "trf", "某渠道支付金额 / 全部支付金额", "pay_amt / sum(pay_amt)", "%", "dws_ord_tenant_sku_channel_trade_di"),
    ("sku_pay_amt_rank", "SKU支付金额排名", C, "prd", "商户内按支付金额排序", "rank() over(partition by tenant order by pay_amt desc)", "名", "dws_ord_tenant_sku_channel_trade_di"),
    ("distribution_profit_rate", "分销利润率", C, "trf", "分销利润 / 分销售出金额", "distribution_profit_amt / distribution_sale_amt", "%", "dws_trf_distributor_trade_di"),
    ("credit_usage_rate", "授信使用率", C, "trf", "已用授信 / 授信额度", "credit_used_amt / credit_limit_amt", "%", "dws_trf_distributor_credit_df"),
    ("pay_method_amt_share", "支付方式占比", C, "fin", "某支付方式收款 / 全部收款", "inbound_pay_amt / sum(inbound_pay_amt)", "%", "dws_fin_tenant_pay_method_di"),
    ("avg_deal_price_amt", "平均成交价", C, "prd", "支付金额 / 支付票数（按 SKU×渠道）", "pay_amt / pay_ticket_qty", "元", "dws_prd_sku_price_di"),
    ("discount_rate", "成交折扣率", C, "prd", "平均成交价 / 生效标价", "avg_deal_price_amt / list_price_amt", "%", "dws_prd_sku_price_di"),
    ("stock_sell_through_rate", "库存去化率（上座率/入住率）", C, "inv", "已售库存 / 库存总量", "stock_sold_qty / stock_total_qty", "%", "dws_inv_sku_stock_df"),
    ("stock_sellout_rate", "售罄率", C, "inv", "售罄池数 / 在售池数", "sellout_pool_qty / count(pool)", "%", "dws_inv_sku_stock_df"),
    ("device_online_rate", "设备在线率", C, "opr", "在线时长 / 自然时长", "online_minute_qty / 1440", "%", "dws_opr_device_di"),
    ("risk_block_rate", "风控拦截率", C, "opr", "拦截次数 / 命中次数", "risk_block_qty / risk_hit_qty", "%", "dws_opr_risk_rule_hit_di"),
    ("complaint_sla_rate", "投诉SLA达成率", C, "opr", "1 − 超SLA数 / 投诉数", "1 - complaint_overdue_qty / complaint_qty", "%", "dws_opr_complaint_di"),
    ("notify_success_rate", "通知成功率", C, "opr", "通知成功数 / 通知发送数", "notify_success_qty / notify_send_qty", "%", "dws_opr_notify_di"),
    ("tenant_active_rate", "商户动销率", C, "sup", "动销商户数 / 有效商户数", "active_tenant_qty / count(ACTIVE tenant)", "%", "dws_sup_tenant_lifetime_df"),
    ("package_renew_rate", "套餐续费率", C, "opr", "到期后续费的订购数 / 到期订购数", "package_renew_qty / 到期订购数", "%", "dws_opr_package_subscription_df"),
    ("pay_amt_dod_rate", "支付金额日环比", C, "ord", "（当日 − 前一日）/ 前一日", "(pay_amt_t - pay_amt_t-1)/pay_amt_t-1", "%", "dws_sup_tenant_trade_di"),
    ("pay_amt_wow_rate", "支付金额周同比", C, "ord", "（当日 − 上周同日）/ 上周同日；周报为本周对上周", "(pay_amt_t - pay_amt_t-7)/pay_amt_t-7", "%", "dws_sup_tenant_trade_di"),
    ("pay_amt_mom_rate", "支付金额月环比", C, "ord", "（本月 − 上月）/ 上月", "(pay_amt_m - pay_amt_m-1)/pay_amt_m-1", "%", "dws_sup_tenant_trade_di"),
]
names = [m[0] for m in M]
assert len(names) == len(set(names)), [n for n in names if names.count(n) > 1]

# 校验 DWS/ADS 引用的指标都在字典里
used = {}
for t in DWS:
    for m in t[4]:
        used.setdefault(m, []).append(t[0])
for t in ADS:
    for m in t[4]:
        used.setdefault(m, []).append(t[0])
missing = [m for m in used if m not in names]
assert not missing, missing

ISSUES = [
    [1, "命名规范", "业务域前缀只有 9 个，系统有 18 个领域", "核销→ord、支付→fin、分销/渠道→trf、价格→prd、租户/员工/权限→sup、风控/设备/审计/通知/套餐→opr", "影响约 60 张表名"],
    [2, "命名规范", "日期/地区/币种/枚举码表没有合适的域", "暂挂 opr_，建议规范补一个公共域前缀", "影响 4 张维表"],
    [3, "命名规范", "分区字段 travel_date 的语义", "按数据日期分区、名字统一叫 travel_date；业务游玩日期另起字段 play_date", "影响全部分区表"],
    [4, "命名规范", "小时表的分区方式", "travel_date + 小时子分区，子分区字段名需规范补充", "影响 2 张 _hrs 表"],
    [5, "命名规范", "实时表后缀", "规范最细到 _hrs，建议新增 _rt", "影响 26 张实时表"],
    [6, "口径", "金额单位", "源库存“分”（BIGINT）；建议 DWD 起统一转“元”，字段用 _amt", "影响全部金额字段"],
    [7, "口径", "GMV 口径", "当前按支付成功子单金额，不扣退款；净成交另算", "影响 pay_amt / net_pay_amt"],
    [8, "口径", "套票计数口径", "下单数只算主单，子项单在套票专表单独统计", "避免重复计数"],
    [9, "口径", "买家口径", "剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家", "影响客单价、复购率"],
    [10, "源系统缺口", "价格快照 OrderPriceSnapshot 只有 API 没有 DDL", "缺了它拿不到下单时价格构成；结算价暂从 t_payment_record.settle_amount 推", "需客户补表"],
    [11, "源系统缺口", "t_verify_record 没有扣减金额和项目ID", "额度型权益消费金额、选择型权益选了哪些项目无法统计", "需客户补字段"],
    [12, "源系统缺口", "放行人数 passCount 未落表", "入园人次暂按核销次数计", "需客户补字段"],
    [13, "源系统缺口", "额度型权益已用额度未落表", "只有 used_count，没有 quota_used", "需客户补字段"],
    [14, "源系统缺口", "套票编排定义、游客-租户绑定、用户领券用券、营销活动、租户应用启用、座位图配置无 DDL", "不计入当前表数，补表后 ODS/DWD 再扩", "需客户补表"],
    [15, "源系统缺口", "t_payment_record 订单库与支付库各一份", "暂定以支付库为准", "需客户确认主数据"],
    [16, "合规", "敏感字段", "密钥字段 ODS 不落；证件号/手机号/人脸 token 脱敏或加密；t_staff_credential 不接入", "需客户安全确认"],
    [17, "文档", "表数口径不一致", "HLD 写 69、database.md 写 75，按 DDL 实际 82 张独立表", "以 DDL 为准"],
]


if __name__ == "__main__":  # 单独运行时输出 v1 表格（v2 由 make_all.py 生成）
    # ---------------------------------------------------------------- 写 xlsx
    wb = Workbook()
    HFILL = PatternFill("solid", fgColor="EEF1F5")
    HFONT = Font(bold=True)
    WRAP = Alignment(wrap_text=True, vertical="top")
    TOP = Alignment(vertical="top")

    def sheet(ws, header, rows, widths, wrap_cols=()):
        ws.append(header)
        for c in ws[1]:
            c.fill = HFILL
            c.font = HFONT
            c.alignment = Alignment(vertical="center", wrap_text=True)
        for r in rows:
            ws.append(r)
        for i, w in enumerate(widths, 1):
            ws.column_dimensions[ws.cell(1, i).column_letter].width = w
        for row in ws.iter_rows(min_row=2):
            for c in row:
                c.alignment = WRAP if c.column in wrap_cols else TOP
        ws.freeze_panes = "A2"

    LAYER_CN = {"ODS": "原始数据层", "DWD": "明细层", "DIM": "维度层", "DWS": "汇总层", "ADS": "应用层"}

    # 1 汇总
    ws = wb.active
    ws.title = "分层汇总"
    rows = [
        ["ODS", "原始数据层", 81, "业务库 1:1 镜像；82 张独立业务表剔除 t_staff_credential（密码/MFA密钥）；大流水 _di，配置小表 _df", "ods"],
        ["DWD", "明细层", 38, "按业务过程拆到最细粒度：票、权益、核销、退款票、分销链层级、状态流转（依赖 binlog）", "dwd"],
        ["DIM", "维度层", 37, "会变的实体用 _zip 拉链，其余 _df，码表 _f", "dim"],
        ["DWS", "汇总层", 29, "主题×粒度汇总；日 _di、分时 _hrs、存量/累计 _df", "dws"],
        ["ADS", "应用层", 26, "商户经营 17、平台运营 7、周/月报 2", "ads"],
        ["离线合计", "", "=SUM(C2:C6)", "", ""],
        ["实时链路", "ODS/DWD/DWS/ADS", 26, "ODS 13 + DWD 6 + DWS 3 + ADS 4；表名后缀 _rt 待确认", "同离线库"],
        ["指标", "指标字典", len(M), "原子指标 %d、派生指标 %d、计算指标 %d" % (
            sum(1 for m in M if m[2] == A), sum(1 for m in M if m[2] == D), sum(1 for m in M if m[2] == C)), ""],
    ]
    sheet(ws, ["分层", "层级含义", "表数", "拆分说明", "库名"], rows, [12, 16, 8, 80, 10], wrap_cols=(4,))
    ws.append([])
    ws.append(["业务域前缀", "含义（含本项目映射）"])
    hr = ws.max_row
    for c in ws[hr]:
        c.fill = HFILL
        c.font = HFONT
    for k, v in DOMAIN.items():
        ws.append([k + "_", v])

    # 2 表清单
    ws = wb.create_sheet("表清单")
    hdr = ["序号", "分层", "业务域", "表名（库.表）", "表中文名", "粒度", "后缀含义", "分区", "来源", "关键字段 / 产出指标", "备注"]
    rows = []
    n = 0
    for src_db, src_t, t, cn, note in ODS:
        n += 1
        rows.append([n, "ODS", t.split("_")[1], "ods." + t, cn, "同源表，1行=1条源记录", suffix_desc(t), part_of(t),
                     "%s.%s" % (src_db, src_t), "源表全字段（敏感字段按备注处理）", note])
    for t, cn, grain, src, key in DWD:
        n += 1
        rows.append([n, "DWD", t.split("_")[1], "dwd." + t, cn, grain, suffix_desc(t), part_of(t), src, key, ""])
    for t, cn, grain, src, key in DIM:
        n += 1
        rows.append([n, "DIM", t.split("_")[1], "dim." + t, cn, grain, suffix_desc(t), part_of(t), src, key,
                     "公共维度暂挂 opr_，规范补公共域后改名" if t in ("dim_opr_date_f", "dim_opr_region_f", "dim_opr_currency_f", "dim_opr_dict_f") else ""])
    for t, cn, grain, src, ms in DWS:
        n += 1
        rows.append([n, "DWS", t.split("_")[1], "dws." + t, cn, grain, suffix_desc(t), part_of(t), src, "、".join(ms), ""])
    for t, cn, grain, src, ms, end in ADS:
        n += 1
        rows.append([n, "ADS", t.split("_")[1], "ads." + t, cn, grain, suffix_desc(t), part_of(t), src, "、".join(ms), "使用端：" + end])
    for layer, t, cn, src in RT:
        n += 1
        rows.append([n, layer + "（实时）", t.split("_")[1], layer.lower() + "." + t, cn, "1行=1条事件/1个窗口", suffix_desc(t), part_of(t), src, "", "实时后缀待确认"])
    sheet(ws, hdr, rows, [6, 10, 7, 44, 26, 40, 12, 22, 42, 60, 30], wrap_cols=(6, 9, 10, 11))

    # 3 指标字典
    ws = wb.create_sheet("指标字典")
    hdr = ["指标编码", "指标英文名", "指标中文名", "指标类型", "业务域", "业务口径", "计算逻辑", "单位", "来源表", "可派生周期", "落地表（DWS/ADS）"]
    rows = []
    seq = {A: 0, D: 0, C: 0}
    pref = {A: "A", D: "D", C: "C"}
    for en, cn, tp, dom, kou, calc, unit, src in M:
        seq[tp] += 1
        period = "1d / 7d / 30d / 自然周 / 自然月 / 年累计" if unit not in ("日期", "0/1") and tp != D else ""
        if tp == C and unit == "%":
            period = "按分子分母同周期计算"
        rows.append(["%s%03d" % (pref[tp], seq[tp]), en, cn, tp, dom, kou, calc, unit, src, period, "、".join(used.get(en, []))])
    sheet(ws, hdr, rows, [9, 28, 22, 10, 7, 46, 46, 7, 32, 24, 56], wrap_cols=(6, 7, 9, 11))

    # 4 待确认
    ws = wb.create_sheet("待确认事项")
    rows = ISSUES
    sheet(ws, ["序号", "类别", "问题", "当前处理 / 建议", "影响"], rows, [6, 10, 48, 70, 24], wrap_cols=(3, 4, 5))

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "output", "pft_dw_v1.xlsx")
    wb.save(out)
    print("tables:", 81 + len(DWD) + len(DIM) + len(DWS) + len(ADS), "rt:", len(RT), "metrics:", len(M),
          {k: sum(1 for m in M if m[2] == k) for k in (A, D, C)})
    print(out)
