-- PFT 2.0 数仓数据质量规则（1433 条：强 504 / 弱 929）
-- 强：失败阻断下游；弱：只告警。${bizdate} 为 T-1，格式 YYYYMMDD

-- ==================== dq.ods_ord_order_group_di  聚合单 质检 ====================
-- R0001 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_ord_order_group_di WHERE travel_date = '${bizdate}';

-- R0002 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-order）
SELECT COUNT(*) FROM `pft-order`.t_order_group WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_ord_order_group_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_ord_order_di  子单 质检 ====================
-- R0003 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_ord_order_di WHERE travel_date = '${bizdate}';

-- R0004 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-order）
SELECT COUNT(*) FROM `pft-order`.t_order WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_ord_order_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_ord_ticket_di  票 质检 ====================
-- R0005 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_ord_ticket_di WHERE travel_date = '${bizdate}';

-- R0006 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-order）
SELECT COUNT(*) FROM `pft-order`.t_ticket WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_ord_ticket_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_ord_ticket_person_di  票上的人 质检 ====================
-- R0007 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_ord_ticket_person_di WHERE travel_date = '${bizdate}';

-- R0008 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-order）
SELECT COUNT(*) FROM `pft-order`.t_ticket_person WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_ord_ticket_person_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_ord_entitlement_di  权益 质检 ====================
-- R0009 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_ord_entitlement_di WHERE travel_date = '${bizdate}';

-- R0010 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-order）
SELECT COUNT(*) FROM `pft-order`.t_entitlement WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_ord_entitlement_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_ord_person_entitlement_binding_di  人-权益绑定 质检 ====================
-- R0011 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_ord_person_entitlement_binding_di WHERE travel_date = '${bizdate}';

-- R0012 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-order）
SELECT COUNT(*) FROM `pft-order`.t_person_entitlement_binding WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_ord_person_entitlement_binding_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_ord_refund_order_di  退款单 质检 ====================
-- R0013 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_ord_refund_order_di WHERE travel_date = '${bizdate}';

-- R0014 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-order）
SELECT COUNT(*) FROM `pft-order`.t_refund_order WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_ord_refund_order_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_ord_refund_detail_di  退款明细（按支付记录） 质检 ====================
-- R0015 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_ord_refund_detail_di WHERE travel_date = '${bizdate}';

-- R0016 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-order）
SELECT COUNT(*) FROM `pft-order`.t_refund_detail WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_ord_refund_detail_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_ord_ticket_credential_di  票凭证 质检 ====================
-- R0017 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_ord_ticket_credential_di WHERE travel_date = '${bizdate}';

-- R0018 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-verification）
SELECT COUNT(*) FROM `pft-verification`.t_ticket_credential WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_ord_ticket_credential_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_ord_verify_record_di  核销记录 质检 ====================
-- R0019 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_ord_verify_record_di WHERE travel_date = '${bizdate}';

-- R0020 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-verification）
SELECT COUNT(*) FROM `pft-verification`.t_verify_record WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_ord_verify_record_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_fin_payment_record_di  支付记录 质检 ====================
-- R0021 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_fin_payment_record_di WHERE travel_date = '${bizdate}';

-- R0022 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-payment）
SELECT COUNT(*) FROM `pft-payment`.t_payment_record WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_fin_payment_record_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_fin_payment_channel_config_df  支付渠道配置 质检 ====================
-- R0023 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_fin_payment_channel_config_df WHERE travel_date = '${bizdate}';

-- R0024 [强][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-payment，抽数时刻快照）
SELECT COUNT(*) FROM `pft-payment`.t_payment_channel_config;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_fin_payment_channel_config_df WHERE travel_date = '${bizdate}';

-- R0025 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_fin_payment_channel_config_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0026 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_fin_payment_channel_config_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_fin_merchant_payment_config_df  商户收款配置 质检 ====================
-- R0027 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_fin_merchant_payment_config_df WHERE travel_date = '${bizdate}';

-- R0028 [强][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-payment，抽数时刻快照）
SELECT COUNT(*) FROM `pft-payment`.t_merchant_payment_config;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_fin_merchant_payment_config_df WHERE travel_date = '${bizdate}';

-- R0029 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_fin_merchant_payment_config_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0030 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_fin_merchant_payment_config_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_fin_account_df  统一账户 质检 ====================
-- R0031 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_fin_account_df WHERE travel_date = '${bizdate}';

-- R0032 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-finance，抽数时刻快照）
SELECT COUNT(*) FROM `pft-finance`.t_account;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_fin_account_df WHERE travel_date = '${bizdate}';

-- R0033 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_fin_account_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0034 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_fin_account_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_fin_frozen_record_di  冻结记录 质检 ====================
-- R0035 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_fin_frozen_record_di WHERE travel_date = '${bizdate}';

-- R0036 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-finance）
SELECT COUNT(*) FROM `pft-finance`.t_frozen_record WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_fin_frozen_record_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_fin_fund_flow_di  资金流水 质检 ====================
-- R0037 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_fin_fund_flow_di WHERE travel_date = '${bizdate}';

-- R0038 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-finance）
SELECT COUNT(*) FROM `pft-finance`.t_fund_flow WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_fin_fund_flow_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_fin_withdraw_order_di  提现单 质检 ====================
-- R0039 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_fin_withdraw_order_di WHERE travel_date = '${bizdate}';

-- R0040 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-finance）
SELECT COUNT(*) FROM `pft-finance`.t_withdraw_order WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_fin_withdraw_order_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_fin_bank_card_df  银行卡 质检 ====================
-- R0041 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_fin_bank_card_df WHERE travel_date = '${bizdate}';

-- R0042 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-finance，抽数时刻快照）
SELECT COUNT(*) FROM `pft-finance`.t_bank_card;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_fin_bank_card_df WHERE travel_date = '${bizdate}';

-- R0043 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_fin_bank_card_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0044 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_fin_bank_card_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_fin_invoice_config_df  商户发票配置 质检 ====================
-- R0045 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_fin_invoice_config_df WHERE travel_date = '${bizdate}';

-- R0046 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-finance，抽数时刻快照）
SELECT COUNT(*) FROM `pft-finance`.t_invoice_config;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_fin_invoice_config_df WHERE travel_date = '${bizdate}';

-- R0047 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_fin_invoice_config_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0048 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_fin_invoice_config_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_fin_invoice_order_di  发票单 质检 ====================
-- R0049 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_fin_invoice_order_di WHERE travel_date = '${bizdate}';

-- R0050 [强][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-finance）
SELECT COUNT(*) FROM `pft-finance`.t_invoice_order WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_fin_invoice_order_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_fin_resource_batch_df  资源批次（短信/积分） 质检 ====================
-- R0051 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_fin_resource_batch_df WHERE travel_date = '${bizdate}';

-- R0052 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-finance，抽数时刻快照）
SELECT COUNT(*) FROM `pft-finance`.t_resource_batch;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_fin_resource_batch_df WHERE travel_date = '${bizdate}';

-- R0053 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_fin_resource_batch_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0054 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_fin_resource_batch_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_prd_spu_df  SPU 质检 ====================
-- R0055 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_prd_spu_df WHERE travel_date = '${bizdate}';

-- R0056 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-product，抽数时刻快照）
SELECT COUNT(*) FROM `pft-product`.t_spu;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_prd_spu_df WHERE travel_date = '${bizdate}';

-- R0057 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_prd_spu_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0058 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_prd_spu_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_prd_sku_df  SKU 质检 ====================
-- R0059 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_prd_sku_df WHERE travel_date = '${bizdate}';

-- R0060 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-product，抽数时刻快照）
SELECT COUNT(*) FROM `pft-product`.t_sku;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_prd_sku_df WHERE travel_date = '${bizdate}';

-- R0061 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_prd_sku_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0062 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_prd_sku_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_prd_sku_version_snapshot_di  SKU版本快照 质检 ====================
-- R0063 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_prd_sku_version_snapshot_di WHERE travel_date = '${bizdate}';

-- R0064 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-product）
SELECT COUNT(*) FROM `pft-product`.t_sku_version_snapshot WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_prd_sku_version_snapshot_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_prd_ticket_meta_df  票属性元数据 质检 ====================
-- R0065 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_prd_ticket_meta_df WHERE travel_date = '${bizdate}';

-- R0066 [强][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-product，抽数时刻快照）
SELECT COUNT(*) FROM `pft-product`.t_ticket_meta;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_prd_ticket_meta_df WHERE travel_date = '${bizdate}';

-- R0067 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_prd_ticket_meta_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0068 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_prd_ticket_meta_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_prd_sku_meta_value_df  SKU票属性值 质检 ====================
-- R0069 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_prd_sku_meta_value_df WHERE travel_date = '${bizdate}';

-- R0070 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-product，抽数时刻快照）
SELECT COUNT(*) FROM `pft-product`.t_sku_meta_value;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_prd_sku_meta_value_df WHERE travel_date = '${bizdate}';

-- R0071 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_prd_sku_meta_value_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0072 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_prd_sku_meta_value_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_prd_sale_rule_df  售卖规则 质检 ====================
-- R0073 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_prd_sale_rule_df WHERE travel_date = '${bizdate}';

-- R0074 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-product，抽数时刻快照）
SELECT COUNT(*) FROM `pft-product`.t_sale_rule;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_prd_sale_rule_df WHERE travel_date = '${bizdate}';

-- R0075 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_prd_sale_rule_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0076 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_prd_sale_rule_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_prd_sale_rule_item_df  售卖条件项 质检 ====================
-- R0077 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_prd_sale_rule_item_df WHERE travel_date = '${bizdate}';

-- R0078 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-product，抽数时刻快照）
SELECT COUNT(*) FROM `pft-product`.t_sale_rule_item;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_prd_sale_rule_item_df WHERE travel_date = '${bizdate}';

-- R0079 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_prd_sale_rule_item_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0080 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_prd_sale_rule_item_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_prd_price_point_di  价格点 质检 ====================
-- R0081 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_prd_price_point_di WHERE travel_date = '${bizdate}';

-- R0082 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-pricing）
SELECT COUNT(*) FROM `pft-pricing`.t_price_point WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_prd_price_point_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_prd_pricing_rule_df  定价规则 质检 ====================
-- R0083 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_prd_pricing_rule_df WHERE travel_date = '${bizdate}';

-- R0084 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-pricing，抽数时刻快照）
SELECT COUNT(*) FROM `pft-pricing`.t_pricing_rule;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_prd_pricing_rule_df WHERE travel_date = '${bizdate}';

-- R0085 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_prd_pricing_rule_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0086 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_prd_pricing_rule_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_inv_inventory_pool_di  库存池 质检 ====================
-- R0087 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_inv_inventory_pool_di WHERE travel_date = '${bizdate}';

-- R0088 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-inventory）
SELECT COUNT(*) FROM `pft-inventory`.t_inventory_pool WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_inv_inventory_pool_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_inv_inventory_unit_di  UNIT池资源（座位/房间/舱位） 质检 ====================
-- R0089 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_inv_inventory_unit_di WHERE travel_date = '${bizdate}';

-- R0090 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-inventory）
SELECT COUNT(*) FROM `pft-inventory`.t_inventory_unit WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_inv_inventory_unit_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_inv_shared_inventory_pool_df  共享库存池 质检 ====================
-- R0091 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_inv_shared_inventory_pool_df WHERE travel_date = '${bizdate}';

-- R0092 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-inventory，抽数时刻快照）
SELECT COUNT(*) FROM `pft-inventory`.t_shared_inventory_pool;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_inv_shared_inventory_pool_df WHERE travel_date = '${bizdate}';

-- R0093 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_inv_shared_inventory_pool_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0094 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_inv_shared_inventory_pool_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_cus_customer_di  C端游客主账号 质检 ====================
-- R0095 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_cus_customer_di WHERE travel_date = '${bizdate}';

-- R0096 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-identity）
SELECT COUNT(*) FROM `pft-identity`.t_customer WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_cus_customer_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_cus_customer_identity_di  游客多渠道身份 质检 ====================
-- R0097 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_cus_customer_identity_di WHERE travel_date = '${bizdate}';

-- R0098 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-identity）
SELECT COUNT(*) FROM `pft-identity`.t_customer_identity WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_cus_customer_identity_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_cus_customer_credential_di  游客个人凭证 质检 ====================
-- R0099 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_cus_customer_credential_di WHERE travel_date = '${bizdate}';

-- R0100 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-identity）
SELECT COUNT(*) FROM `pft-identity`.t_customer_credential WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_cus_customer_credential_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_sup_tenant_df  租户 质检 ====================
-- R0101 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_tenant_df WHERE travel_date = '${bizdate}';

-- R0102 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_tenant;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_tenant_df WHERE travel_date = '${bizdate}';

-- R0103 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_tenant_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0104 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_tenant_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_tenant_config_df  租户配置KV 质检 ====================
-- R0105 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_tenant_config_df WHERE travel_date = '${bizdate}';

-- R0106 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_tenant_config;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_tenant_config_df WHERE travel_date = '${bizdate}';

-- R0107 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_tenant_config_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0108 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_tenant_config_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_tenant_staff_df  B端员工 质检 ====================
-- R0109 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_tenant_staff_df WHERE travel_date = '${bizdate}';

-- R0110 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_tenant_staff;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_tenant_staff_df WHERE travel_date = '${bizdate}';

-- R0111 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_tenant_staff_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0112 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_tenant_staff_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_staff_config_df  员工配置KV 质检 ====================
-- R0113 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_staff_config_df WHERE travel_date = '${bizdate}';

-- R0114 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_staff_config;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_staff_config_df WHERE travel_date = '${bizdate}';

-- R0115 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_staff_config_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0116 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_staff_config_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_org_df  部门架构 质检 ====================
-- R0117 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_org_df WHERE travel_date = '${bizdate}';

-- R0118 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_org;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_org_df WHERE travel_date = '${bizdate}';

-- R0119 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_org_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0120 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_org_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_tenant_position_df  岗位定义 质检 ====================
-- R0121 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_tenant_position_df WHERE travel_date = '${bizdate}';

-- R0122 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_tenant_position;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_tenant_position_df WHERE travel_date = '${bizdate}';

-- R0123 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_tenant_position_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0124 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_tenant_position_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_sys_role_df  RBAC角色 质检 ====================
-- R0125 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_sys_role_df WHERE travel_date = '${bizdate}';

-- R0126 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_sys_role;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_sys_role_df WHERE travel_date = '${bizdate}';

-- R0127 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_sys_role_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0128 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_sys_role_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_sys_permission_df  权限定义 质检 ====================
-- R0129 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_sys_permission_df WHERE travel_date = '${bizdate}';

-- R0130 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_sys_permission;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_sys_permission_df WHERE travel_date = '${bizdate}';

-- R0131 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_sys_permission_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0132 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_sys_permission_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_sys_resource_df  资源定义 质检 ====================
-- R0133 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_sys_resource_df WHERE travel_date = '${bizdate}';

-- R0134 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_sys_resource;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_sys_resource_df WHERE travel_date = '${bizdate}';

-- R0135 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_sys_resource_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0136 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_sys_resource_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_sys_role_permission_df  角色-权限绑定 质检 ====================
-- R0137 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_sys_role_permission_df WHERE travel_date = '${bizdate}';

-- R0138 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_sys_role_permission;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_sys_role_permission_df WHERE travel_date = '${bizdate}';

-- R0139 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_sys_role_permission_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0140 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_sys_role_permission_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_sys_permission_resource_df  权限-资源映射 质检 ====================
-- R0141 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_sys_permission_resource_df WHERE travel_date = '${bizdate}';

-- R0142 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_sys_permission_resource;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_sys_permission_resource_df WHERE travel_date = '${bizdate}';

-- R0143 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_sys_permission_resource_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0144 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_sys_permission_resource_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_sys_user_role_df  员工-角色绑定 质检 ====================
-- R0145 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_sys_user_role_df WHERE travel_date = '${bizdate}';

-- R0146 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_sys_user_role;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_sys_user_role_df WHERE travel_date = '${bizdate}';

-- R0147 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_sys_user_role_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0148 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_sys_user_role_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_sup_sys_data_permission_df  ABAC数据权限 质检 ====================
-- R0149 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_sup_sys_data_permission_df WHERE travel_date = '${bizdate}';

-- R0150 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-identity，抽数时刻快照）
SELECT COUNT(*) FROM `pft-identity`.t_sys_data_permission;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_sup_sys_data_permission_df WHERE travel_date = '${bizdate}';

-- R0151 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_sup_sys_data_permission_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0152 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_sup_sys_data_permission_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_trf_channel_df  接入端/渠道 质检 ====================
-- R0153 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_trf_channel_df WHERE travel_date = '${bizdate}';

-- R0154 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_channel;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_trf_channel_df WHERE travel_date = '${bizdate}';

-- R0155 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_trf_channel_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0156 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_trf_channel_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_trf_channel_tenant_binding_df  渠道-租户绑定 质检 ====================
-- R0157 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_trf_channel_tenant_binding_df WHERE travel_date = '${bizdate}';

-- R0158 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_channel_tenant_binding;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_trf_channel_tenant_binding_df WHERE travel_date = '${bizdate}';

-- R0159 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_trf_channel_tenant_binding_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0160 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_trf_channel_tenant_binding_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_trf_tenant_mp_config_df  租户小程序配置 质检 ====================
-- R0161 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_trf_tenant_mp_config_df WHERE travel_date = '${bizdate}';

-- R0162 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_tenant_mp_config;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_trf_tenant_mp_config_df WHERE travel_date = '${bizdate}';

-- R0163 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_trf_tenant_mp_config_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0164 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_trf_tenant_mp_config_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_trf_distribution_relation_df  分销关系 质检 ====================
-- R0165 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_trf_distribution_relation_df WHERE travel_date = '${bizdate}';

-- R0166 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-distribution，抽数时刻快照）
SELECT COUNT(*) FROM `pft-distribution`.t_distribution_relation;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_trf_distribution_relation_df WHERE travel_date = '${bizdate}';

-- R0167 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_trf_distribution_relation_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0168 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_trf_distribution_relation_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_trf_api_key_df  API密钥 质检 ====================
-- R0169 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_trf_api_key_df WHERE travel_date = '${bizdate}';

-- R0170 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-open-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-open-platform`.t_api_key;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_trf_api_key_df WHERE travel_date = '${bizdate}';

-- R0171 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_trf_api_key_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0172 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_trf_api_key_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_code_pool_df  码池 质检 ====================
-- R0173 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_code_pool_df WHERE travel_date = '${bizdate}';

-- R0174 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-verification，抽数时刻快照）
SELECT COUNT(*) FROM `pft-verification`.t_code_pool;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_code_pool_df WHERE travel_date = '${bizdate}';

-- R0175 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_code_pool_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0176 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_code_pool_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_verify_point_df  核销点 质检 ====================
-- R0177 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_verify_point_df WHERE travel_date = '${bizdate}';

-- R0178 [强][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-verification，抽数时刻快照）
SELECT COUNT(*) FROM `pft-verification`.t_verify_point;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_verify_point_df WHERE travel_date = '${bizdate}';

-- R0179 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_verify_point_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0180 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_verify_point_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_risk_rule_df  风控规则 质检 ====================
-- R0181 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_risk_rule_df WHERE travel_date = '${bizdate}';

-- R0182 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-risk，抽数时刻快照）
SELECT COUNT(*) FROM `pft-risk`.t_risk_rule;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_risk_rule_df WHERE travel_date = '${bizdate}';

-- R0183 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_risk_rule_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0184 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_risk_rule_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_blacklist_di  黑名单 质检 ====================
-- R0185 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_blacklist_di WHERE travel_date = '${bizdate}';

-- R0186 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-risk）
SELECT COUNT(*) FROM `pft-risk`.t_blacklist WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_opr_blacklist_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_opr_risk_event_di  风控事件 质检 ====================
-- R0187 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_risk_event_di WHERE travel_date = '${bizdate}';

-- R0188 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-risk）
SELECT COUNT(*) FROM `pft-risk`.t_risk_event WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_opr_risk_event_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_opr_account_ban_di  账号封禁 质检 ====================
-- R0189 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_account_ban_di WHERE travel_date = '${bizdate}';

-- R0190 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-risk）
SELECT COUNT(*) FROM `pft-risk`.t_account_ban WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_opr_account_ban_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_opr_device_df  设备 质检 ====================
-- R0191 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_device_df WHERE travel_date = '${bizdate}';

-- R0192 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-device，抽数时刻快照）
SELECT COUNT(*) FROM `pft-device`.t_device;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_device_df WHERE travel_date = '${bizdate}';

-- R0193 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_device_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0194 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_device_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_device_group_df  设备分组 质检 ====================
-- R0195 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_device_group_df WHERE travel_date = '${bizdate}';

-- R0196 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-device，抽数时刻快照）
SELECT COUNT(*) FROM `pft-device`.t_device_group;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_device_group_df WHERE travel_date = '${bizdate}';

-- R0197 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_device_group_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0198 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_device_group_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_sys_dict_df  平台字典 质检 ====================
-- R0199 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_sys_dict_df WHERE travel_date = '${bizdate}';

-- R0200 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_sys_dict;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_sys_dict_df WHERE travel_date = '${bizdate}';

-- R0201 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_sys_dict_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0202 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_sys_dict_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_package_df  套餐包 质检 ====================
-- R0203 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_package_df WHERE travel_date = '${bizdate}';

-- R0204 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_package;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_package_df WHERE travel_date = '${bizdate}';

-- R0205 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_package_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0206 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_package_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_package_subscription_di  套餐订购 质检 ====================
-- R0207 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_package_subscription_di WHERE travel_date = '${bizdate}';

-- R0208 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-platform）
SELECT COUNT(*) FROM `pft-platform`.t_package_subscription WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_opr_package_subscription_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_opr_approval_flow_df  审批流定义 质检 ====================
-- R0209 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_approval_flow_df WHERE travel_date = '${bizdate}';

-- R0210 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_approval_flow;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_approval_flow_df WHERE travel_date = '${bizdate}';

-- R0211 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_approval_flow_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0212 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_approval_flow_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_approval_instance_di  审批实例 质检 ====================
-- R0213 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_approval_instance_di WHERE travel_date = '${bizdate}';

-- R0214 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-platform）
SELECT COUNT(*) FROM `pft-platform`.t_approval_instance WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_opr_approval_instance_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_opr_complaint_di  投诉工单 质检 ====================
-- R0215 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_complaint_di WHERE travel_date = '${bizdate}';

-- R0216 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-platform）
SELECT COUNT(*) FROM `pft-platform`.t_complaint WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_opr_complaint_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_opr_i18n_language_df  支持语言 质检 ====================
-- R0217 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_i18n_language_df WHERE travel_date = '${bizdate}';

-- R0218 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_i18n_language;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_i18n_language_df WHERE travel_date = '${bizdate}';

-- R0219 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_i18n_language_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0220 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_i18n_language_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_i18n_currency_df  支持币种 质检 ====================
-- R0221 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_i18n_currency_df WHERE travel_date = '${bizdate}';

-- R0222 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_i18n_currency;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_i18n_currency_df WHERE travel_date = '${bizdate}';

-- R0223 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_i18n_currency_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0224 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_i18n_currency_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_i18n_translation_df  翻译表 质检 ====================
-- R0225 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_i18n_translation_df WHERE travel_date = '${bizdate}';

-- R0226 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_i18n_translation;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_i18n_translation_df WHERE travel_date = '${bizdate}';

-- R0227 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_i18n_translation_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0228 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_i18n_translation_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_country_df  国家字典 质检 ====================
-- R0229 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_country_df WHERE travel_date = '${bizdate}';

-- R0230 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_country;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_country_df WHERE travel_date = '${bizdate}';

-- R0231 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_country_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0232 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_country_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_region_df  地区字典 质检 ====================
-- R0233 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_region_df WHERE travel_date = '${bizdate}';

-- R0234 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_region;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_region_df WHERE travel_date = '${bizdate}';

-- R0235 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_region_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0236 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_region_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_config_meta_df  配置元数据 质检 ====================
-- R0237 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_config_meta_df WHERE travel_date = '${bizdate}';

-- R0238 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-platform，抽数时刻快照）
SELECT COUNT(*) FROM `pft-platform`.t_config_meta;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_config_meta_df WHERE travel_date = '${bizdate}';

-- R0239 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_config_meta_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0240 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_config_meta_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_notify_template_df  通知模板 质检 ====================
-- R0241 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_notify_template_df WHERE travel_date = '${bizdate}';

-- R0242 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-notification，抽数时刻快照）
SELECT COUNT(*) FROM `pft-notification`.t_notify_template;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_notify_template_df WHERE travel_date = '${bizdate}';

-- R0243 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_notify_template_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0244 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_notify_template_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_notify_record_di  通知记录 质检 ====================
-- R0245 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_notify_record_di WHERE travel_date = '${bizdate}';

-- R0246 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-notification）
SELECT COUNT(*) FROM `pft-notification`.t_notify_record WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_opr_notify_record_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_opr_audit_log_di  审计日志 质检 ====================
-- R0247 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_audit_log_di WHERE travel_date = '${bizdate}';

-- R0248 [弱][一致性] 与业务库行数对账；期望：|数仓 − 源端| / 源端 ≤ 0.1%
-- MySQL 源端（pft-audit）
SELECT COUNT(*) FROM `pft-audit`.t_audit_log WHERE update_time >= '${bizdate_begin}' AND update_time < '${bizdate_end}';
-- 数仓端
SELECT COUNT(DISTINCT id) FROM ods.ods_opr_audit_log_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ods_opr_app_definition_df  应用定义 质检 ====================
-- R0249 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_app_definition_df WHERE travel_date = '${bizdate}';

-- R0250 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-application，抽数时刻快照）
SELECT COUNT(*) FROM `pft-application`.t_app_definition;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_app_definition_df WHERE travel_date = '${bizdate}';

-- R0251 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_app_definition_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0252 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_app_definition_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_app_binding_df  套餐-应用绑定 质检 ====================
-- R0253 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_app_binding_df WHERE travel_date = '${bizdate}';

-- R0254 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-application，抽数时刻快照）
SELECT COUNT(*) FROM `pft-application`.t_app_binding;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_app_binding_df WHERE travel_date = '${bizdate}';

-- R0255 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_app_binding_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0256 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_app_binding_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_opr_cdc_sync_task_df  CDC同步任务 质检 ====================
-- R0257 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_opr_cdc_sync_task_df WHERE travel_date = '${bizdate}';

-- R0258 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-data-pipeline，抽数时刻快照）
SELECT COUNT(*) FROM `pft-data-pipeline`.t_cdc_sync_task;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_opr_cdc_sync_task_df WHERE travel_date = '${bizdate}';

-- R0259 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_opr_cdc_sync_task_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0260 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_opr_cdc_sync_task_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.ods_mkt_coupon_df  优惠券 质检 ====================
-- R0261 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ods.ods_mkt_coupon_df WHERE travel_date = '${bizdate}';

-- R0262 [弱][一致性] 与业务库行数对账；期望：数仓 = 源端
-- MySQL 源端（pft-marketing，抽数时刻快照）
SELECT COUNT(*) FROM `pft-marketing`.t_coupon;
-- 数仓端
SELECT COUNT(*) FROM ods.ods_mkt_coupon_df WHERE travel_date = '${bizdate}';

-- R0263 [强][唯一性] 主键/粒度唯一（id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT id, COUNT(*) AS c FROM ods.ods_mkt_coupon_df WHERE travel_date = '${bizdate}' GROUP BY id HAVING COUNT(*) > 1
) x;

-- R0264 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ods.ods_mkt_coupon_df WHERE travel_date = '${bizdate}' AND (id IS NULL);

-- ==================== dq.dwd_ord_order_group_di  聚合单明细 质检 ====================
-- R0265 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_order_group_di WHERE travel_date = '${bizdate}';

-- R0266 [强][唯一性] 主键/粒度唯一（order_group_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT order_group_id, COUNT(*) AS c FROM dwd.dwd_ord_order_group_di WHERE travel_date = '${bizdate}' GROUP BY order_group_id HAVING COUNT(*) > 1
) x;

-- R0267 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_order_group_di WHERE travel_date = '${bizdate}' AND (order_group_id IS NULL);

-- R0268 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_order_group_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0269 [弱][一致性] channel_id 能关联到 dim_trf_channel_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.channel_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_order_group_di f
LEFT JOIN dim.dim_trf_channel_df d ON f.channel_id = d.channel_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.channel_id IS NOT NULL AND CAST(f.channel_id AS STRING) NOT IN ('0', '');

-- R0270 [弱][一致性] buyer_customer_id 能关联到 dim_cus_customer_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.customer_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_order_group_di f
LEFT JOIN dim.dim_cus_customer_zip d ON f.buyer_customer_id = d.customer_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.buyer_customer_id IS NOT NULL AND CAST(f.buyer_customer_id AS STRING) NOT IN ('0', '');

-- R0271 [弱][有效性] operator_type 取值在枚举内；期望：无返回行
SELECT operator_type, COUNT(*) AS cnt FROM dwd.dwd_ord_order_group_di WHERE travel_date = '${bizdate}' AND operator_type IS NOT NULL
  AND operator_type NOT IN ('CUSTOMER', 'TENANT_STAFF')
GROUP BY operator_type;

-- R0272 [弱][有效性] buyer_type 取值在枚举内；期望：无返回行
SELECT buyer_type, COUNT(*) AS cnt FROM dwd.dwd_ord_order_group_di WHERE travel_date = '${bizdate}' AND buyer_type IS NOT NULL
  AND buyer_type NOT IN ('CUSTOMER', 'ANONYMOUS')
GROUP BY buyer_type;

-- R0273 [弱][有效性] contact_cert_type 取值在枚举内；期望：无返回行
SELECT contact_cert_type, COUNT(*) AS cnt FROM dwd.dwd_ord_order_group_di WHERE travel_date = '${bizdate}' AND contact_cert_type IS NOT NULL
  AND contact_cert_type NOT IN ('ID_CARD', 'PASSPORT')
GROUP BY contact_cert_type;

-- R0274 [弱][有效性] pay_status 取值在枚举内；期望：无返回行
SELECT pay_status, COUNT(*) AS cnt FROM dwd.dwd_ord_order_group_di WHERE travel_date = '${bizdate}' AND pay_status IS NOT NULL
  AND pay_status NOT IN ('UNPAID', 'PARTIAL_PAID', 'PAID')
GROUP BY pay_status;

-- R0275 [弱][有效性] channel_type 取值在枚举内；期望：无返回行
SELECT channel_type, COUNT(*) AS cnt FROM dwd.dwd_ord_order_group_di WHERE travel_date = '${bizdate}' AND channel_type IS NOT NULL
  AND channel_type NOT IN ('MP', 'API', 'OFFLINE')
GROUP BY channel_type;

-- R0276 [弱][有效性] 金额/数量非负（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN total_amt < 0 THEN 1 ELSE 0 END) AS total_amt_neg,
  SUM(CASE WHEN order_ticket_qty < 0 THEN 1 ELSE 0 END) AS order_ticket_qty_neg,
  SUM(CASE WHEN sub_order_qty < 0 THEN 1 ELSE 0 END) AS sub_order_qty_neg
FROM dwd.dwd_ord_order_group_di WHERE travel_date = '${bizdate}';

-- R0277 [弱][及时性/波动] order_ticket_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(order_ticket_qty) AS v FROM dwd.dwd_ord_order_group_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_ord_order_di  子单明细 质检 ====================
-- R0278 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}';

-- R0279 [强][唯一性] 主键/粒度唯一（order_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT order_id, COUNT(*) AS c FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}' GROUP BY order_id HAVING COUNT(*) > 1
) x;

-- R0280 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}' AND (order_id IS NULL);

-- R0281 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_order_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0282 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_order_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0283 [弱][一致性] channel_id 能关联到 dim_trf_channel_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.channel_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_order_di f
LEFT JOIN dim.dim_trf_channel_df d ON f.channel_id = d.channel_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.channel_id IS NOT NULL AND CAST(f.channel_id AS STRING) NOT IN ('0', '');

-- R0284 [弱][一致性] buyer_customer_id 能关联到 dim_cus_customer_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.customer_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_order_di f
LEFT JOIN dim.dim_cus_customer_zip d ON f.buyer_customer_id = d.customer_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.buyer_customer_id IS NOT NULL AND CAST(f.buyer_customer_id AS STRING) NOT IN ('0', '');

-- R0285 [弱][一致性] spu_id 能关联到 dim_prd_spu_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.spu_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_order_di f
LEFT JOIN dim.dim_prd_spu_zip d ON f.spu_id = d.spu_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.spu_id IS NOT NULL AND CAST(f.spu_id AS STRING) NOT IN ('0', '');

-- R0286 [弱][有效性] combo_type 取值在枚举内；期望：无返回行
SELECT combo_type, COUNT(*) AS cnt FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}' AND combo_type NOT IN (1, 0) GROUP BY combo_type;

-- R0287 [弱][有效性] order_status 取值在枚举内；期望：无返回行
SELECT order_status, COUNT(*) AS cnt FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}' AND order_status IS NOT NULL
  AND order_status NOT IN ('PENDING_PAY', 'PAID', 'PARTIALLY_VERIFIED', 'FULLY_VERIFIED', 'REFUNDED', 'CANCELLED')
GROUP BY order_status;

-- R0288 [弱][有效性] channel_type 取值在枚举内；期望：无返回行
SELECT channel_type, COUNT(*) AS cnt FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}' AND channel_type IS NOT NULL
  AND channel_type NOT IN ('MP', 'API', 'OFFLINE')
GROUP BY channel_type;

-- R0289 [弱][有效性] operator_type 取值在枚举内；期望：无返回行
SELECT operator_type, COUNT(*) AS cnt FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}' AND operator_type IS NOT NULL
  AND operator_type NOT IN ('CUSTOMER', 'TENANT_STAFF')
GROUP BY operator_type;

-- R0290 [弱][有效性] buyer_type 取值在枚举内；期望：无返回行
SELECT buyer_type, COUNT(*) AS cnt FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}' AND buyer_type IS NOT NULL
  AND buyer_type NOT IN ('CUSTOMER', 'ANONYMOUS')
GROUP BY buyer_type;

-- R0291 [弱][有效性] product_type 取值在枚举内；期望：无返回行
SELECT product_type, COUNT(*) AS cnt FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}' AND product_type IS NOT NULL
  AND product_type NOT IN ('SCENIC', 'HOTEL', 'SHOW')
GROUP BY product_type;

-- R0292 [弱][有效性] 金额/数量非负（5 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN buy_ticket_qty < 0 THEN 1 ELSE 0 END) AS buy_ticket_qty_neg,
  SUM(CASE WHEN unit_price_amt < 0 THEN 1 ELSE 0 END) AS unit_price_amt_neg,
  SUM(CASE WHEN order_amt < 0 THEN 1 ELSE 0 END) AS order_amt_neg,
  SUM(CASE WHEN cost_price_amt < 0 THEN 1 ELSE 0 END) AS cost_price_amt_neg,
  SUM(CASE WHEN advance_book_day_qty < 0 THEN 1 ELSE 0 END) AS advance_book_day_qty_neg
FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}';

-- R0293 [弱][及时性/波动] order_amt 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(order_amt) AS v FROM dwd.dwd_ord_order_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_ord_order_status_log_di  子单状态流转明细 质检 ====================
-- R0294 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_order_status_log_di WHERE travel_date = '${bizdate}';

-- R0295 [强][唯一性] 主键/粒度唯一（order_no + change_time + after_status）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT order_no, change_time, after_status, COUNT(*) AS c FROM dwd.dwd_ord_order_status_log_di WHERE travel_date = '${bizdate}' GROUP BY order_no, change_time, after_status HAVING COUNT(*) > 1
) x;

-- R0296 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_order_status_log_di WHERE travel_date = '${bizdate}' AND (order_no IS NULL OR change_time IS NULL OR after_status IS NULL);

-- R0297 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_order_status_log_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0298 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_order_status_log_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0299 [弱][有效性] before_status 取值在枚举内；期望：无返回行
SELECT before_status, COUNT(*) AS cnt FROM dwd.dwd_ord_order_status_log_di WHERE travel_date = '${bizdate}' AND before_status IS NOT NULL
  AND before_status NOT IN ('PENDING_PAY', 'PAID', 'PARTIALLY_VERIFIED', 'FULLY_VERIFIED', 'REFUNDED', 'CANCELLED')
GROUP BY before_status;

-- R0300 [弱][有效性] after_status 取值在枚举内；期望：无返回行
SELECT after_status, COUNT(*) AS cnt FROM dwd.dwd_ord_order_status_log_di WHERE travel_date = '${bizdate}' AND after_status IS NOT NULL
  AND after_status NOT IN ('PENDING_PAY', 'PAID', 'PARTIALLY_VERIFIED', 'FULLY_VERIFIED', 'REFUNDED', 'CANCELLED')
GROUP BY after_status;

-- R0301 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN stay_minute_qty < 0 THEN 1 ELSE 0 END) AS stay_minute_qty_neg
FROM dwd.dwd_ord_order_status_log_di WHERE travel_date = '${bizdate}';

-- R0302 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_ord_order_status_log_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_ord_ticket_di  票明细（出票） 质检 ====================
-- R0303 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_di WHERE travel_date = '${bizdate}';

-- R0304 [强][唯一性] 主键/粒度唯一（ticket_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT ticket_id, COUNT(*) AS c FROM dwd.dwd_ord_ticket_di WHERE travel_date = '${bizdate}' GROUP BY ticket_id HAVING COUNT(*) > 1
) x;

-- R0305 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_ticket_di WHERE travel_date = '${bizdate}' AND (ticket_id IS NULL);

-- R0306 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0307 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0308 [弱][一致性] spu_id 能关联到 dim_prd_spu_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.spu_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_di f
LEFT JOIN dim.dim_prd_spu_zip d ON f.spu_id = d.spu_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.spu_id IS NOT NULL AND CAST(f.spu_id AS STRING) NOT IN ('0', '');

-- R0309 [弱][一致性] channel_id 能关联到 dim_trf_channel_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.channel_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_di f
LEFT JOIN dim.dim_trf_channel_df d ON f.channel_id = d.channel_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.channel_id IS NOT NULL AND CAST(f.channel_id AS STRING) NOT IN ('0', '');

-- R0310 [弱][一致性] buyer_customer_id 能关联到 dim_cus_customer_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.customer_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_di f
LEFT JOIN dim.dim_cus_customer_zip d ON f.buyer_customer_id = d.customer_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.buyer_customer_id IS NOT NULL AND CAST(f.buyer_customer_id AS STRING) NOT IN ('0', '');

-- R0311 [弱][有效性] ticket_status 取值在枚举内；期望：无返回行
SELECT ticket_status, COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_di WHERE travel_date = '${bizdate}' AND ticket_status IS NOT NULL
  AND ticket_status NOT IN ('AVAILABLE', 'PARTIALLY_USED', 'USED', 'EXPIRED', 'REFUNDED', 'CANCELLED')
GROUP BY ticket_status;

-- R0312 [弱][有效性] pass_policy_type 取值在枚举内；期望：无返回行
SELECT pass_policy_type, COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_di WHERE travel_date = '${bizdate}' AND pass_policy_type IS NOT NULL
  AND pass_policy_type NOT IN ('SINGLE', 'BATCH')
GROUP BY pass_policy_type;

-- R0313 [弱][有效性] delay_active_type 取值在枚举内；期望：无返回行
SELECT delay_active_type, COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_di WHERE travel_date = '${bizdate}' AND delay_active_type NOT IN (0, 1) GROUP BY delay_active_type;

-- R0314 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN unit_price_amt < 0 THEN 1 ELSE 0 END) AS unit_price_amt_neg,
  SUM(CASE WHEN ticket_qty < 0 THEN 1 ELSE 0 END) AS ticket_qty_neg
FROM dwd.dwd_ord_ticket_di WHERE travel_date = '${bizdate}';

-- R0315 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_ord_ticket_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_ord_ticket_status_log_di  票状态流转明细 质检 ====================
-- R0316 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_status_log_di WHERE travel_date = '${bizdate}';

-- R0317 [强][唯一性] 主键/粒度唯一（ticket_no + change_time + after_status）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT ticket_no, change_time, after_status, COUNT(*) AS c FROM dwd.dwd_ord_ticket_status_log_di WHERE travel_date = '${bizdate}' GROUP BY ticket_no, change_time, after_status HAVING COUNT(*) > 1
) x;

-- R0318 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_ticket_status_log_di WHERE travel_date = '${bizdate}' AND (ticket_no IS NULL OR change_time IS NULL OR after_status IS NULL);

-- R0319 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_status_log_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0320 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_status_log_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0321 [弱][有效性] before_status 取值在枚举内；期望：无返回行
SELECT before_status, COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_status_log_di WHERE travel_date = '${bizdate}' AND before_status IS NOT NULL
  AND before_status NOT IN ('AVAILABLE', 'PARTIALLY_USED', 'USED', 'EXPIRED', 'REFUNDED', 'CANCELLED')
GROUP BY before_status;

-- R0322 [弱][有效性] after_status 取值在枚举内；期望：无返回行
SELECT after_status, COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_status_log_di WHERE travel_date = '${bizdate}' AND after_status IS NOT NULL
  AND after_status NOT IN ('AVAILABLE', 'PARTIALLY_USED', 'USED', 'EXPIRED', 'REFUNDED', 'CANCELLED')
GROUP BY after_status;

-- R0323 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN stay_minute_qty < 0 THEN 1 ELSE 0 END) AS stay_minute_qty_neg
FROM dwd.dwd_ord_ticket_status_log_di WHERE travel_date = '${bizdate}';

-- R0324 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_ord_ticket_status_log_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_ord_ticket_person_di  票游客明细 质检 ====================
-- R0325 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_person_di WHERE travel_date = '${bizdate}';

-- R0326 [强][唯一性] 主键/粒度唯一（person_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT person_id, COUNT(*) AS c FROM dwd.dwd_ord_ticket_person_di WHERE travel_date = '${bizdate}' GROUP BY person_id HAVING COUNT(*) > 1
) x;

-- R0327 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_ticket_person_di WHERE travel_date = '${bizdate}' AND (person_id IS NULL);

-- R0328 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_person_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0329 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_person_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0330 [弱][有效性] cert_type 取值在枚举内；期望：无返回行
SELECT cert_type, COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_person_di WHERE travel_date = '${bizdate}' AND cert_type IS NOT NULL
  AND cert_type NOT IN ('ID_CARD', 'PASSPORT')
GROUP BY cert_type;

-- R0331 [弱][有效性] gender_type 取值在枚举内；期望：无返回行
SELECT gender_type, COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_person_di WHERE travel_date = '${bizdate}' AND gender_type IS NOT NULL
  AND gender_type NOT IN ('MALE', 'FEMALE', 'UNKNOWN')
GROUP BY gender_type;

-- R0332 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN age_year_qty < 0 THEN 1 ELSE 0 END) AS age_year_qty_neg,
  SUM(CASE WHEN person_qty < 0 THEN 1 ELSE 0 END) AS person_qty_neg
FROM dwd.dwd_ord_ticket_person_di WHERE travel_date = '${bizdate}';

-- R0333 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_ord_ticket_person_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_ord_entitlement_di  权益明细 质检 ====================
-- R0334 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_entitlement_di WHERE travel_date = '${bizdate}';

-- R0335 [强][唯一性] 主键/粒度唯一（entitlement_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT entitlement_id, COUNT(*) AS c FROM dwd.dwd_ord_entitlement_di WHERE travel_date = '${bizdate}' GROUP BY entitlement_id HAVING COUNT(*) > 1
) x;

-- R0336 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_entitlement_di WHERE travel_date = '${bizdate}' AND (entitlement_id IS NULL);

-- R0337 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_entitlement_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0338 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_entitlement_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0339 [弱][有效性] entitlement_type 取值在枚举内；期望：无返回行
SELECT entitlement_type, COUNT(*) AS cnt FROM dwd.dwd_ord_entitlement_di WHERE travel_date = '${bizdate}' AND entitlement_type IS NOT NULL
  AND entitlement_type NOT IN ('FIXED', 'SELECTABLE', 'COUNTED', 'TIMED', 'UNLIMITED', 'QUOTA')
GROUP BY entitlement_type;

-- R0340 [弱][有效性] entitlement_status 取值在枚举内；期望：无返回行
SELECT entitlement_status, COUNT(*) AS cnt FROM dwd.dwd_ord_entitlement_di WHERE travel_date = '${bizdate}' AND entitlement_status IS NOT NULL
  AND entitlement_status NOT IN ('ACTIVE', 'USED', 'EXPIRED', 'REFUNDED')
GROUP BY entitlement_status;

-- R0341 [弱][有效性] 金额/数量非负（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN used_qty < 0 THEN 1 ELSE 0 END) AS used_qty_neg,
  SUM(CASE WHEN max_qty < 0 THEN 1 ELSE 0 END) AS max_qty_neg,
  SUM(CASE WHEN candidate_qty < 0 THEN 1 ELSE 0 END) AS candidate_qty_neg,
  SUM(CASE WHEN duration_minute_qty < 0 THEN 1 ELSE 0 END) AS duration_minute_qty_neg,
  SUM(CASE WHEN quota_amt < 0 THEN 1 ELSE 0 END) AS quota_amt_neg,
  SUM(CASE WHEN remain_qty < 0 THEN 1 ELSE 0 END) AS remain_qty_neg
FROM dwd.dwd_ord_entitlement_di WHERE travel_date = '${bizdate}';

-- R0342 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_ord_entitlement_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_ord_entitlement_binding_di  人-权益绑定明细 质检 ====================
-- R0343 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_entitlement_binding_di WHERE travel_date = '${bizdate}';

-- R0344 [强][唯一性] 主键/粒度唯一（binding_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT binding_id, COUNT(*) AS c FROM dwd.dwd_ord_entitlement_binding_di WHERE travel_date = '${bizdate}' GROUP BY binding_id HAVING COUNT(*) > 1
) x;

-- R0345 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_entitlement_binding_di WHERE travel_date = '${bizdate}' AND (binding_id IS NULL);

-- R0346 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_entitlement_binding_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0347 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_entitlement_binding_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0348 [弱][有效性] binding_type 取值在枚举内；期望：无返回行
SELECT binding_type, COUNT(*) AS cnt FROM dwd.dwd_ord_entitlement_binding_di WHERE travel_date = '${bizdate}' AND binding_type IS NOT NULL
  AND binding_type NOT IN ('EXCLUSIVE', 'SHARED', 'OPEN')
GROUP BY binding_type;

-- R0349 [弱][有效性] entitlement_type 取值在枚举内；期望：无返回行
SELECT entitlement_type, COUNT(*) AS cnt FROM dwd.dwd_ord_entitlement_binding_di WHERE travel_date = '${bizdate}' AND entitlement_type IS NOT NULL
  AND entitlement_type NOT IN ('FIXED', 'COUNTED', 'SELECTABLE', 'TIMED', 'QUOTA', 'UNLIMITED')
GROUP BY entitlement_type;

-- R0350 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_ord_entitlement_binding_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_ord_ticket_credential_di  凭证发码/撤销明细 质检 ====================
-- R0351 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_credential_di WHERE travel_date = '${bizdate}';

-- R0352 [强][唯一性] 主键/粒度唯一（credential_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT credential_id, COUNT(*) AS c FROM dwd.dwd_ord_ticket_credential_di WHERE travel_date = '${bizdate}' GROUP BY credential_id HAVING COUNT(*) > 1
) x;

-- R0353 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_ticket_credential_di WHERE travel_date = '${bizdate}' AND (credential_id IS NULL);

-- R0354 [弱][一致性] code_pool_id 能关联到 dim_opr_code_pool_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.code_pool_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_credential_di f
LEFT JOIN dim.dim_opr_code_pool_df d ON f.code_pool_id = d.code_pool_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.code_pool_id IS NOT NULL AND CAST(f.code_pool_id AS STRING) NOT IN ('0', '');

-- R0355 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_credential_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0356 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_ticket_credential_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0357 [弱][有效性] credential_type 取值在枚举内；期望：无返回行
SELECT credential_type, COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_credential_di WHERE travel_date = '${bizdate}' AND credential_type IS NOT NULL
  AND credential_type NOT IN ('QR_CODE', 'BAR_CODE', 'ID_CARD', 'FACE')
GROUP BY credential_type;

-- R0358 [弱][有效性] credential_status 取值在枚举内；期望：无返回行
SELECT credential_status, COUNT(*) AS cnt FROM dwd.dwd_ord_ticket_credential_di WHERE travel_date = '${bizdate}' AND credential_status IS NOT NULL
  AND credential_status NOT IN ('ACTIVE', 'EXPIRED', 'REVOKED')
GROUP BY credential_status;

-- R0359 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN credential_qty < 0 THEN 1 ELSE 0 END) AS credential_qty_neg
FROM dwd.dwd_ord_ticket_credential_di WHERE travel_date = '${bizdate}';

-- R0360 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_ord_ticket_credential_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_ord_verify_di  核销明细（权益级） 质检 ====================
-- R0361 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_verify_di WHERE travel_date = '${bizdate}';

-- R0362 [强][唯一性] 主键/粒度唯一（verify_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT verify_id, COUNT(*) AS c FROM dwd.dwd_ord_verify_di WHERE travel_date = '${bizdate}' GROUP BY verify_id HAVING COUNT(*) > 1
) x;

-- R0363 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_verify_di WHERE travel_date = '${bizdate}' AND (verify_id IS NULL);

-- R0364 [弱][一致性] verify_point_id 能关联到 dim_opr_verify_point_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.verify_point_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_verify_di f
LEFT JOIN dim.dim_opr_verify_point_df d ON f.verify_point_id = d.verify_point_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.verify_point_id IS NOT NULL AND CAST(f.verify_point_id AS STRING) NOT IN ('0', '');

-- R0365 [弱][一致性] device_id 能关联到 dim_opr_device_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.device_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_verify_di f
LEFT JOIN dim.dim_opr_device_df d ON f.device_id = d.device_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.device_id IS NOT NULL AND CAST(f.device_id AS STRING) NOT IN ('0', '');

-- R0366 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_verify_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0367 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_verify_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0368 [弱][一致性] spu_id 能关联到 dim_prd_spu_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.spu_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_verify_di f
LEFT JOIN dim.dim_prd_spu_zip d ON f.spu_id = d.spu_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.spu_id IS NOT NULL AND CAST(f.spu_id AS STRING) NOT IN ('0', '');

-- R0369 [弱][有效性] verify_type 取值在枚举内；期望：无返回行
SELECT verify_type, COUNT(*) AS cnt FROM dwd.dwd_ord_verify_di WHERE travel_date = '${bizdate}' AND verify_type IS NOT NULL
  AND verify_type NOT IN ('ONLINE', 'OFFLINE')
GROUP BY verify_type;

-- R0370 [弱][有效性] verify_result_type 取值在枚举内；期望：无返回行
SELECT verify_result_type, COUNT(*) AS cnt FROM dwd.dwd_ord_verify_di WHERE travel_date = '${bizdate}' AND verify_result_type IS NOT NULL
  AND verify_result_type NOT IN ('SUCCESS', 'FAILED', 'DUPLICATE')
GROUP BY verify_result_type;

-- R0371 [弱][有效性] entitlement_type 取值在枚举内；期望：无返回行
SELECT entitlement_type, COUNT(*) AS cnt FROM dwd.dwd_ord_verify_di WHERE travel_date = '${bizdate}' AND entitlement_type IS NOT NULL
  AND entitlement_type NOT IN ('FIXED', 'COUNTED', 'SELECTABLE', 'TIMED', 'QUOTA', 'UNLIMITED')
GROUP BY entitlement_type;

-- R0372 [弱][有效性] verify_point_type 取值在枚举内；期望：无返回行
SELECT verify_point_type, COUNT(*) AS cnt FROM dwd.dwd_ord_verify_di WHERE travel_date = '${bizdate}' AND verify_point_type IS NOT NULL
  AND verify_point_type NOT IN ('GATE', 'COUNTER', 'SELF_SERVICE', 'HANDHELD')
GROUP BY verify_point_type;

-- R0373 [弱][有效性] device_type 取值在枚举内；期望：无返回行
SELECT device_type, COUNT(*) AS cnt FROM dwd.dwd_ord_verify_di WHERE travel_date = '${bizdate}' AND device_type IS NOT NULL
  AND device_type NOT IN ('GATE', 'POS', 'HANDHELD', 'SELF_SERVICE', 'KIOSK', 'FACE_RECOGNITION')
GROUP BY device_type;

-- R0374 [弱][有效性] offline_conflict_type 取值在枚举内；期望：无返回行
SELECT offline_conflict_type, COUNT(*) AS cnt FROM dwd.dwd_ord_verify_di WHERE travel_date = '${bizdate}' AND offline_conflict_type NOT IN (0, 1) GROUP BY offline_conflict_type;

-- R0375 [弱][有效性] 金额/数量非负（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN verify_person_qty < 0 THEN 1 ELSE 0 END) AS verify_person_qty_neg,
  SUM(CASE WHEN verify_qty < 0 THEN 1 ELSE 0 END) AS verify_qty_neg,
  SUM(CASE WHEN verify_amt < 0 THEN 1 ELSE 0 END) AS verify_amt_neg
FROM dwd.dwd_ord_verify_di WHERE travel_date = '${bizdate}';

-- R0376 [弱][及时性/波动] verify_person_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(verify_person_qty) AS v FROM dwd.dwd_ord_verify_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_ord_refund_di  退款单明细 质检 ====================
-- R0377 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_refund_di WHERE travel_date = '${bizdate}';

-- R0378 [强][唯一性] 主键/粒度唯一（refund_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT refund_id, COUNT(*) AS c FROM dwd.dwd_ord_refund_di WHERE travel_date = '${bizdate}' GROUP BY refund_id HAVING COUNT(*) > 1
) x;

-- R0379 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_refund_di WHERE travel_date = '${bizdate}' AND (refund_id IS NULL);

-- R0380 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_refund_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0381 [弱][一致性] channel_id 能关联到 dim_trf_channel_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.channel_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_refund_di f
LEFT JOIN dim.dim_trf_channel_df d ON f.channel_id = d.channel_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.channel_id IS NOT NULL AND CAST(f.channel_id AS STRING) NOT IN ('0', '');

-- R0382 [弱][有效性] refund_type 取值在枚举内；期望：无返回行
SELECT refund_type, COUNT(*) AS cnt FROM dwd.dwd_ord_refund_di WHERE travel_date = '${bizdate}' AND refund_type IS NOT NULL
  AND refund_type NOT IN ('ORDER_REFUND', 'COMPENSATION', 'PARTIAL_REFUND')
GROUP BY refund_type;

-- R0383 [弱][有效性] refund_status 取值在枚举内；期望：无返回行
SELECT refund_status, COUNT(*) AS cnt FROM dwd.dwd_ord_refund_di WHERE travel_date = '${bizdate}' AND refund_status IS NOT NULL
  AND refund_status NOT IN ('PENDING', 'APPROVED', 'PROCESSING', 'COMPLETED', 'REJECTED')
GROUP BY refund_status;

-- R0384 [弱][有效性] initiator_type 取值在枚举内；期望：无返回行
SELECT initiator_type, COUNT(*) AS cnt FROM dwd.dwd_ord_refund_di WHERE travel_date = '${bizdate}' AND initiator_type IS NOT NULL
  AND initiator_type NOT IN ('VISITOR', 'MERCHANT', 'PLATFORM', 'SYSTEM')
GROUP BY initiator_type;

-- R0385 [弱][有效性] 金额/数量非负（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN refund_amt < 0 THEN 1 ELSE 0 END) AS refund_amt_neg,
  SUM(CASE WHEN process_hour_qty < 0 THEN 1 ELSE 0 END) AS process_hour_qty_neg,
  SUM(CASE WHEN refund_ticket_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_qty_neg
FROM dwd.dwd_ord_refund_di WHERE travel_date = '${bizdate}';

-- R0386 [弱][及时性/波动] refund_amt 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(refund_amt) AS v FROM dwd.dwd_ord_refund_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_ord_refund_ticket_di  退款票明细 质检 ====================
-- R0387 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_ord_refund_ticket_di WHERE travel_date = '${bizdate}';

-- R0388 [强][唯一性] 主键/粒度唯一（refund_no + ticket_no）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT refund_no, ticket_no, COUNT(*) AS c FROM dwd.dwd_ord_refund_ticket_di WHERE travel_date = '${bizdate}' GROUP BY refund_no, ticket_no HAVING COUNT(*) > 1
) x;

-- R0389 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_ord_refund_ticket_di WHERE travel_date = '${bizdate}' AND (refund_no IS NULL OR ticket_no IS NULL);

-- R0390 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_refund_ticket_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0391 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_ord_refund_ticket_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0392 [弱][有效性] refund_type 取值在枚举内；期望：无返回行
SELECT refund_type, COUNT(*) AS cnt FROM dwd.dwd_ord_refund_ticket_di WHERE travel_date = '${bizdate}' AND refund_type IS NOT NULL
  AND refund_type NOT IN ('ORDER_REFUND', 'COMPENSATION', 'PARTIAL_REFUND')
GROUP BY refund_type;

-- R0393 [弱][有效性] refund_status 取值在枚举内；期望：无返回行
SELECT refund_status, COUNT(*) AS cnt FROM dwd.dwd_ord_refund_ticket_di WHERE travel_date = '${bizdate}' AND refund_status IS NOT NULL
  AND refund_status NOT IN ('PENDING', 'APPROVED', 'PROCESSING', 'COMPLETED', 'REJECTED')
GROUP BY refund_status;

-- R0394 [弱][有效性] initiator_type 取值在枚举内；期望：无返回行
SELECT initiator_type, COUNT(*) AS cnt FROM dwd.dwd_ord_refund_ticket_di WHERE travel_date = '${bizdate}' AND initiator_type IS NOT NULL
  AND initiator_type NOT IN ('VISITOR', 'MERCHANT', 'PLATFORM', 'SYSTEM')
GROUP BY initiator_type;

-- R0395 [弱][有效性] before_ticket_status 取值在枚举内；期望：无返回行
SELECT before_ticket_status, COUNT(*) AS cnt FROM dwd.dwd_ord_refund_ticket_di WHERE travel_date = '${bizdate}' AND before_ticket_status IS NOT NULL
  AND before_ticket_status NOT IN ('AVAILABLE', 'PARTIALLY_USED')
GROUP BY before_ticket_status;

-- R0396 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN refund_ticket_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_qty_neg,
  SUM(CASE WHEN refund_amt < 0 THEN 1 ELSE 0 END) AS refund_amt_neg
FROM dwd.dwd_ord_refund_ticket_di WHERE travel_date = '${bizdate}';

-- R0397 [弱][及时性/波动] refund_ticket_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(refund_ticket_qty) AS v FROM dwd.dwd_ord_refund_ticket_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_fin_payment_di  支付明细 质检 ====================
-- R0398 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_fin_payment_di WHERE travel_date = '${bizdate}';

-- R0399 [强][唯一性] 主键/粒度唯一（payment_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT payment_id, COUNT(*) AS c FROM dwd.dwd_fin_payment_di WHERE travel_date = '${bizdate}' GROUP BY payment_id HAVING COUNT(*) > 1
) x;

-- R0400 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_fin_payment_di WHERE travel_date = '${bizdate}' AND (payment_id IS NULL);

-- R0401 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_fin_payment_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0402 [弱][一致性] payer_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_fin_payment_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.payer_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.payer_tenant_id IS NOT NULL AND CAST(f.payer_tenant_id AS STRING) NOT IN ('0', '');

-- R0403 [弱][一致性] payee_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_fin_payment_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.payee_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.payee_tenant_id IS NOT NULL AND CAST(f.payee_tenant_id AS STRING) NOT IN ('0', '');

-- R0404 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_fin_payment_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0405 [弱][有效性] pay_direction_type 取值在枚举内；期望：无返回行
SELECT pay_direction_type, COUNT(*) AS cnt FROM dwd.dwd_fin_payment_di WHERE travel_date = '${bizdate}' AND pay_direction_type IS NOT NULL
  AND pay_direction_type NOT IN ('INBOUND', 'OUTBOUND')
GROUP BY pay_direction_type;

-- R0406 [弱][有效性] pay_method_type 取值在枚举内；期望：无返回行
SELECT pay_method_type, COUNT(*) AS cnt FROM dwd.dwd_fin_payment_di WHERE travel_date = '${bizdate}' AND pay_method_type IS NOT NULL
  AND pay_method_type NOT IN ('BALANCE', 'WECHAT', 'ALIPAY', 'CREDIT', 'OFFLINE', 'ZERO_FEE')
GROUP BY pay_method_type;

-- R0407 [弱][有效性] receive_channel_type 取值在枚举内；期望：无返回行
SELECT receive_channel_type, COUNT(*) AS cnt FROM dwd.dwd_fin_payment_di WHERE travel_date = '${bizdate}' AND receive_channel_type IS NOT NULL
  AND receive_channel_type NOT IN ('INBOUND', 'CASH', 'WECHAT_QR', 'ALIPAY_QR', 'BANK_TRANSFER', 'OFFLINE_SYSTEM_OUT')
GROUP BY receive_channel_type;

-- R0408 [弱][有效性] external_frozen_type 取值在枚举内；期望：无返回行
SELECT external_frozen_type, COUNT(*) AS cnt FROM dwd.dwd_fin_payment_di WHERE travel_date = '${bizdate}' AND external_frozen_type NOT IN (1, 0) GROUP BY external_frozen_type;

-- R0409 [弱][有效性] pay_status 取值在枚举内；期望：无返回行
SELECT pay_status, COUNT(*) AS cnt FROM dwd.dwd_fin_payment_di WHERE travel_date = '${bizdate}' AND pay_status IS NOT NULL
  AND pay_status NOT IN ('CREATED', 'PAID', 'PARTIAL_REFUNDED', 'REFUNDED')
GROUP BY pay_status;

-- R0410 [弱][有效性] freeze_type 取值在枚举内；期望：无返回行
SELECT freeze_type, COUNT(*) AS cnt FROM dwd.dwd_fin_payment_di WHERE travel_date = '${bizdate}' AND freeze_type IS NOT NULL
  AND freeze_type NOT IN ('PROFIT', 'SETTLEMENT', 'FULL')
GROUP BY freeze_type;

-- R0411 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_amt < 0 THEN 1 ELSE 0 END) AS pay_amt_neg,
  SUM(CASE WHEN settle_amt < 0 THEN 1 ELSE 0 END) AS settle_amt_neg
FROM dwd.dwd_fin_payment_di WHERE travel_date = '${bizdate}';

-- R0412 [弱][及时性/波动] pay_amt 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_amt) AS v FROM dwd.dwd_fin_payment_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_fin_refund_payment_di  退款资金明细 质检 ====================
-- R0413 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_fin_refund_payment_di WHERE travel_date = '${bizdate}';

-- R0414 [强][唯一性] 主键/粒度唯一（refund_detail_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT refund_detail_id, COUNT(*) AS c FROM dwd.dwd_fin_refund_payment_di WHERE travel_date = '${bizdate}' GROUP BY refund_detail_id HAVING COUNT(*) > 1
) x;

-- R0415 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_fin_refund_payment_di WHERE travel_date = '${bizdate}' AND (refund_detail_id IS NULL);

-- R0416 [弱][有效性] refund_channel_type 取值在枚举内；期望：无返回行
SELECT refund_channel_type, COUNT(*) AS cnt FROM dwd.dwd_fin_refund_payment_di WHERE travel_date = '${bizdate}' AND refund_channel_type IS NOT NULL
  AND refund_channel_type NOT IN ('WECHAT', 'ALIPAY', 'BALANCE', 'CREDIT')
GROUP BY refund_channel_type;

-- R0417 [弱][有效性] refund_detail_status 取值在枚举内；期望：无返回行
SELECT refund_detail_status, COUNT(*) AS cnt FROM dwd.dwd_fin_refund_payment_di WHERE travel_date = '${bizdate}' AND refund_detail_status IS NOT NULL
  AND refund_detail_status NOT IN ('PENDING', 'PROCESSING', 'SUCCESS', 'FAILED')
GROUP BY refund_detail_status;

-- R0418 [弱][有效性] pay_method_type 取值在枚举内；期望：无返回行
SELECT pay_method_type, COUNT(*) AS cnt FROM dwd.dwd_fin_refund_payment_di WHERE travel_date = '${bizdate}' AND pay_method_type IS NOT NULL
  AND pay_method_type NOT IN ('BALANCE', 'WECHAT', 'ALIPAY', 'CREDIT', 'OFFLINE', 'ZERO_FEE')
GROUP BY pay_method_type;

-- R0419 [弱][有效性] pay_direction_type 取值在枚举内；期望：无返回行
SELECT pay_direction_type, COUNT(*) AS cnt FROM dwd.dwd_fin_refund_payment_di WHERE travel_date = '${bizdate}' AND pay_direction_type IS NOT NULL
  AND pay_direction_type NOT IN ('INBOUND', 'OUTBOUND')
GROUP BY pay_direction_type;

-- R0420 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN refund_amt < 0 THEN 1 ELSE 0 END) AS refund_amt_neg
FROM dwd.dwd_fin_refund_payment_di WHERE travel_date = '${bizdate}';

-- R0421 [弱][及时性/波动] refund_amt 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(refund_amt) AS v FROM dwd.dwd_fin_refund_payment_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_fin_frozen_di  冻结/解冻明细 质检 ====================
-- R0422 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}';

-- R0423 [强][唯一性] 主键/粒度唯一（frozen_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT frozen_id, COUNT(*) AS c FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}' GROUP BY frozen_id HAVING COUNT(*) > 1
) x;

-- R0424 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}' AND (frozen_id IS NULL);

-- R0425 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_fin_frozen_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0426 [弱][有效性] freeze_type 取值在枚举内；期望：无返回行
SELECT freeze_type, COUNT(*) AS cnt FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}' AND freeze_type IS NOT NULL
  AND freeze_type NOT IN ('PROFIT', 'SETTLEMENT', 'FULL')
GROUP BY freeze_type;

-- R0427 [弱][有效性] frozen_status 取值在枚举内；期望：无返回行
SELECT frozen_status, COUNT(*) AS cnt FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}' AND frozen_status IS NOT NULL
  AND frozen_status NOT IN ('FROZEN', 'RELEASED')
GROUP BY frozen_status;

-- R0428 [弱][有效性] release_event_type 取值在枚举内；期望：无返回行
SELECT release_event_type, COUNT(*) AS cnt FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}' AND release_event_type IS NOT NULL
  AND release_event_type NOT IN ('VERIFY', 'REFUND')
GROUP BY release_event_type;

-- R0429 [弱][有效性] external_frozen_type 取值在枚举内；期望：无返回行
SELECT external_frozen_type, COUNT(*) AS cnt FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}' AND external_frozen_type NOT IN (1, 0) GROUP BY external_frozen_type;

-- R0430 [弱][有效性] account_type 取值在枚举内；期望：无返回行
SELECT account_type, COUNT(*) AS cnt FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}' AND account_type IS NOT NULL
  AND account_type NOT IN ('MERCHANT', 'DISTRIBUTOR', 'PLATFORM')
GROUP BY account_type;

-- R0431 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN freeze_amt < 0 THEN 1 ELSE 0 END) AS freeze_amt_neg,
  SUM(CASE WHEN freeze_hour_qty < 0 THEN 1 ELSE 0 END) AS freeze_hour_qty_neg
FROM dwd.dwd_fin_frozen_di WHERE travel_date = '${bizdate}';

-- R0432 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_fin_frozen_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_fin_fund_flow_di  资金流水明细 质检 ====================
-- R0433 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_fin_fund_flow_di WHERE travel_date = '${bizdate}';

-- R0434 [强][唯一性] 主键/粒度唯一（flow_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT flow_id, COUNT(*) AS c FROM dwd.dwd_fin_fund_flow_di WHERE travel_date = '${bizdate}' GROUP BY flow_id HAVING COUNT(*) > 1
) x;

-- R0435 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_fin_fund_flow_di WHERE travel_date = '${bizdate}' AND (flow_id IS NULL);

-- R0436 [弱][有效性] flow_type 取值在枚举内；期望：无返回行
SELECT flow_type, COUNT(*) AS cnt FROM dwd.dwd_fin_fund_flow_di WHERE travel_date = '${bizdate}' AND flow_type IS NOT NULL
  AND flow_type NOT IN ('RECHARGE', 'PAYMENT', 'REFUND', 'FREEZE', 'UNFREEZE', 'WITHDRAW', 'FEE', 'RESOURCE', 'TRANSFER_OUT', 'TRANSFER_IN')
GROUP BY flow_type;

-- R0437 [弱][有效性] account_type 取值在枚举内；期望：无返回行
SELECT account_type, COUNT(*) AS cnt FROM dwd.dwd_fin_fund_flow_di WHERE travel_date = '${bizdate}' AND account_type IS NOT NULL
  AND account_type NOT IN ('MERCHANT', 'DISTRIBUTOR', 'PLATFORM')
GROUP BY account_type;

-- R0438 [弱][有效性] flow_direction_type 取值在枚举内；期望：无返回行
SELECT flow_direction_type, COUNT(*) AS cnt FROM dwd.dwd_fin_fund_flow_di WHERE travel_date = '${bizdate}' AND flow_direction_type NOT IN (1, 2) GROUP BY flow_direction_type;

-- R0439 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_fin_fund_flow_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_fin_withdraw_di  提现明细 质检 ====================
-- R0440 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_fin_withdraw_di WHERE travel_date = '${bizdate}';

-- R0441 [强][唯一性] 主键/粒度唯一（withdraw_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT withdraw_id, COUNT(*) AS c FROM dwd.dwd_fin_withdraw_di WHERE travel_date = '${bizdate}' GROUP BY withdraw_id HAVING COUNT(*) > 1
) x;

-- R0442 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_fin_withdraw_di WHERE travel_date = '${bizdate}' AND (withdraw_id IS NULL);

-- R0443 [弱][一致性] bank_card_id 能关联到 dim_fin_bank_card_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.bank_card_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_fin_withdraw_di f
LEFT JOIN dim.dim_fin_bank_card_df d ON f.bank_card_id = d.bank_card_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.bank_card_id IS NOT NULL AND CAST(f.bank_card_id AS STRING) NOT IN ('0', '');

-- R0444 [弱][有效性] withdraw_status 取值在枚举内；期望：无返回行
SELECT withdraw_status, COUNT(*) AS cnt FROM dwd.dwd_fin_withdraw_di WHERE travel_date = '${bizdate}' AND withdraw_status IS NOT NULL
  AND withdraw_status NOT IN ('PENDING', 'APPROVED', 'PROCESSING', 'COMPLETED', 'REJECTED', 'FAILED')
GROUP BY withdraw_status;

-- R0445 [弱][有效性] account_type 取值在枚举内；期望：无返回行
SELECT account_type, COUNT(*) AS cnt FROM dwd.dwd_fin_withdraw_di WHERE travel_date = '${bizdate}' AND account_type IS NOT NULL
  AND account_type NOT IN ('MERCHANT', 'DISTRIBUTOR', 'PLATFORM')
GROUP BY account_type;

-- R0446 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN withdraw_amt < 0 THEN 1 ELSE 0 END) AS withdraw_amt_neg
FROM dwd.dwd_fin_withdraw_di WHERE travel_date = '${bizdate}';

-- R0447 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_fin_withdraw_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_fin_invoice_di  发票明细 质检 ====================
-- R0448 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_fin_invoice_di WHERE travel_date = '${bizdate}';

-- R0449 [强][唯一性] 主键/粒度唯一（invoice_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT invoice_id, COUNT(*) AS c FROM dwd.dwd_fin_invoice_di WHERE travel_date = '${bizdate}' GROUP BY invoice_id HAVING COUNT(*) > 1
) x;

-- R0450 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_fin_invoice_di WHERE travel_date = '${bizdate}' AND (invoice_id IS NULL);

-- R0451 [弱][一致性] invoice_config_id 能关联到 dim_fin_invoice_config_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.invoice_config_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_fin_invoice_di f
LEFT JOIN dim.dim_fin_invoice_config_df d ON f.invoice_config_id = d.invoice_config_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.invoice_config_id IS NOT NULL AND CAST(f.invoice_config_id AS STRING) NOT IN ('0', '');

-- R0452 [弱][有效性] invoice_type 取值在枚举内；期望：无返回行
SELECT invoice_type, COUNT(*) AS cnt FROM dwd.dwd_fin_invoice_di WHERE travel_date = '${bizdate}' AND invoice_type IS NOT NULL
  AND invoice_type NOT IN ('E_NORMAL', 'E_SPECIAL')
GROUP BY invoice_type;

-- R0453 [弱][有效性] invoice_subject_type 取值在枚举内；期望：无返回行
SELECT invoice_subject_type, COUNT(*) AS cnt FROM dwd.dwd_fin_invoice_di WHERE travel_date = '${bizdate}' AND invoice_subject_type IS NOT NULL
  AND invoice_subject_type NOT IN ('MERCHANT_TO_VISITOR', 'PLATFORM_TO_MERCHANT')
GROUP BY invoice_subject_type;

-- R0454 [弱][有效性] invoice_status 取值在枚举内；期望：无返回行
SELECT invoice_status, COUNT(*) AS cnt FROM dwd.dwd_fin_invoice_di WHERE travel_date = '${bizdate}' AND invoice_status IS NOT NULL
  AND invoice_status NOT IN ('PENDING', 'APPROVED', 'INVOICED', 'RED_INVOICED', 'REJECTED')
GROUP BY invoice_status;

-- R0455 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN invoice_amt < 0 THEN 1 ELSE 0 END) AS invoice_amt_neg
FROM dwd.dwd_fin_invoice_di WHERE travel_date = '${bizdate}';

-- R0456 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_fin_invoice_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_fin_resource_batch_di  资源包购买/消耗明细 质检 ====================
-- R0457 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_fin_resource_batch_di WHERE travel_date = '${bizdate}';

-- R0458 [强][唯一性] 主键/粒度唯一（resource_batch_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT resource_batch_id, COUNT(*) AS c FROM dwd.dwd_fin_resource_batch_di WHERE travel_date = '${bizdate}' GROUP BY resource_batch_id HAVING COUNT(*) > 1
) x;

-- R0459 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_fin_resource_batch_di WHERE travel_date = '${bizdate}' AND (resource_batch_id IS NULL);

-- R0460 [弱][一致性] package_id 能关联到 dim_opr_package_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.package_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_fin_resource_batch_di f
LEFT JOIN dim.dim_opr_package_df d ON f.package_id = d.package_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.package_id IS NOT NULL AND CAST(f.package_id AS STRING) NOT IN ('0', '');

-- R0461 [弱][有效性] unit_type 取值在枚举内；期望：无返回行
SELECT unit_type, COUNT(*) AS cnt FROM dwd.dwd_fin_resource_batch_di WHERE travel_date = '${bizdate}' AND unit_type IS NOT NULL
  AND unit_type NOT IN ('COUNT', 'POINT', 'YUAN')
GROUP BY unit_type;

-- R0462 [弱][有效性] batch_status 取值在枚举内；期望：无返回行
SELECT batch_status, COUNT(*) AS cnt FROM dwd.dwd_fin_resource_batch_di WHERE travel_date = '${bizdate}' AND batch_status IS NOT NULL
  AND batch_status NOT IN ('ACTIVE', 'EXPIRED', 'CONSUMED')
GROUP BY batch_status;

-- R0463 [弱][有效性] 金额/数量非负（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN total_qty < 0 THEN 1 ELSE 0 END) AS total_qty_neg,
  SUM(CASE WHEN remaining_qty < 0 THEN 1 ELSE 0 END) AS remaining_qty_neg,
  SUM(CASE WHEN consume_qty < 0 THEN 1 ELSE 0 END) AS consume_qty_neg
FROM dwd.dwd_fin_resource_batch_di WHERE travel_date = '${bizdate}';

-- R0464 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_fin_resource_batch_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_trf_distribution_settle_di  分销采购链明细 质检 ====================
-- R0465 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_trf_distribution_settle_di WHERE travel_date = '${bizdate}';

-- R0466 [强][唯一性] 主键/粒度唯一（payment_no）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT payment_no, COUNT(*) AS c FROM dwd.dwd_trf_distribution_settle_di WHERE travel_date = '${bizdate}' GROUP BY payment_no HAVING COUNT(*) > 1
) x;

-- R0467 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_trf_distribution_settle_di WHERE travel_date = '${bizdate}' AND (payment_no IS NULL);

-- R0468 [弱][一致性] supplier_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_trf_distribution_settle_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.supplier_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.supplier_tenant_id IS NOT NULL AND CAST(f.supplier_tenant_id AS STRING) NOT IN ('0', '');

-- R0469 [弱][一致性] distributor_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_trf_distribution_settle_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.distributor_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.distributor_tenant_id IS NOT NULL AND CAST(f.distributor_tenant_id AS STRING) NOT IN ('0', '');

-- R0470 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_trf_distribution_settle_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0471 [弱][有效性] freeze_type 取值在枚举内；期望：无返回行
SELECT freeze_type, COUNT(*) AS cnt FROM dwd.dwd_trf_distribution_settle_di WHERE travel_date = '${bizdate}' AND freeze_type IS NOT NULL
  AND freeze_type NOT IN ('PROFIT', 'SETTLEMENT', 'FULL')
GROUP BY freeze_type;

-- R0472 [弱][有效性] pay_method_type 取值在枚举内；期望：无返回行
SELECT pay_method_type, COUNT(*) AS cnt FROM dwd.dwd_trf_distribution_settle_di WHERE travel_date = '${bizdate}' AND pay_method_type IS NOT NULL
  AND pay_method_type NOT IN ('BALANCE', 'WECHAT', 'ALIPAY', 'CREDIT', 'OFFLINE', 'ZERO_FEE')
GROUP BY pay_method_type;

-- R0473 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN sale_amt < 0 THEN 1 ELSE 0 END) AS sale_amt_neg,
  SUM(CASE WHEN settle_amt < 0 THEN 1 ELSE 0 END) AS settle_amt_neg
FROM dwd.dwd_trf_distribution_settle_di WHERE travel_date = '${bizdate}';

-- R0474 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_trf_distribution_settle_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_prd_sku_version_di  SKU版本变更明细 质检 ====================
-- R0475 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_prd_sku_version_di WHERE travel_date = '${bizdate}';

-- R0476 [强][唯一性] 主键/粒度唯一（snapshot_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT snapshot_id, COUNT(*) AS c FROM dwd.dwd_prd_sku_version_di WHERE travel_date = '${bizdate}' GROUP BY snapshot_id HAVING COUNT(*) > 1
) x;

-- R0477 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_prd_sku_version_di WHERE travel_date = '${bizdate}' AND (snapshot_id IS NULL);

-- R0478 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_prd_sku_version_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0479 [弱][有效性] price_change_type 取值在枚举内；期望：无返回行
SELECT price_change_type, COUNT(*) AS cnt FROM dwd.dwd_prd_sku_version_di WHERE travel_date = '${bizdate}' AND price_change_type NOT IN (0, 1) GROUP BY price_change_type;

-- R0480 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN old_price_amt < 0 THEN 1 ELSE 0 END) AS old_price_amt_neg,
  SUM(CASE WHEN new_price_amt < 0 THEN 1 ELSE 0 END) AS new_price_amt_neg
FROM dwd.dwd_prd_sku_version_di WHERE travel_date = '${bizdate}';

-- R0481 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_prd_sku_version_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_prd_price_point_log_di  价格点变更明细 质检 ====================
-- R0482 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_prd_price_point_log_di WHERE travel_date = '${bizdate}';

-- R0483 [强][唯一性] 主键/粒度唯一（price_point_id + change_time）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT price_point_id, change_time, COUNT(*) AS c FROM dwd.dwd_prd_price_point_log_di WHERE travel_date = '${bizdate}' GROUP BY price_point_id, change_time HAVING COUNT(*) > 1
) x;

-- R0484 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_prd_price_point_log_di WHERE travel_date = '${bizdate}' AND (price_point_id IS NULL OR change_time IS NULL);

-- R0485 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_prd_price_point_log_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0486 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_prd_price_point_log_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_prd_sku_price_calendar_df  SKU每日生效价日历 质检 ====================
-- R0487 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_prd_sku_price_calendar_df WHERE travel_date = '${bizdate}';

-- R0488 [强][唯一性] 主键/粒度唯一（sku_id + price_date + price_channel_code + ext_dim_desc）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT sku_id, price_date, price_channel_code, ext_dim_desc, COUNT(*) AS c FROM dwd.dwd_prd_sku_price_calendar_df WHERE travel_date = '${bizdate}' GROUP BY sku_id, price_date, price_channel_code, ext_dim_desc HAVING COUNT(*) > 1
) x;

-- R0489 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_prd_sku_price_calendar_df WHERE travel_date = '${bizdate}' AND (sku_id IS NULL OR price_date IS NULL OR price_channel_code IS NULL OR ext_dim_desc IS NULL);

-- R0490 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_prd_sku_price_calendar_df f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0491 [弱][有效性] rule_price_type 取值在枚举内；期望：无返回行
SELECT rule_price_type, COUNT(*) AS cnt FROM dwd.dwd_prd_sku_price_calendar_df WHERE travel_date = '${bizdate}' AND rule_price_type NOT IN (0, 1) GROUP BY rule_price_type;

-- R0492 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN list_price_amt < 0 THEN 1 ELSE 0 END) AS list_price_amt_neg,
  SUM(CASE WHEN final_price_amt < 0 THEN 1 ELSE 0 END) AS final_price_amt_neg
FROM dwd.dwd_prd_sku_price_calendar_df WHERE travel_date = '${bizdate}';

-- R0493 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_prd_sku_price_calendar_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_inv_pool_change_di  库存池变动明细 质检 ====================
-- R0494 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_inv_pool_change_di WHERE travel_date = '${bizdate}';

-- R0495 [强][唯一性] 主键/粒度唯一（pool_id + change_time）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT pool_id, change_time, COUNT(*) AS c FROM dwd.dwd_inv_pool_change_di WHERE travel_date = '${bizdate}' GROUP BY pool_id, change_time HAVING COUNT(*) > 1
) x;

-- R0496 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_inv_pool_change_di WHERE travel_date = '${bizdate}' AND (pool_id IS NULL OR change_time IS NULL);

-- R0497 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_inv_pool_change_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0498 [弱][有效性] pool_type 取值在枚举内；期望：无返回行
SELECT pool_type, COUNT(*) AS cnt FROM dwd.dwd_inv_pool_change_di WHERE travel_date = '${bizdate}' AND pool_type IS NOT NULL
  AND pool_type NOT IN ('COUNTING', 'UNIT')
GROUP BY pool_type;

-- R0499 [弱][有效性] pool_status 取值在枚举内；期望：无返回行
SELECT pool_status, COUNT(*) AS cnt FROM dwd.dwd_inv_pool_change_di WHERE travel_date = '${bizdate}' AND pool_status IS NOT NULL
  AND pool_status NOT IN ('ON_SALE', 'STOP_SALE', 'EXPIRED')
GROUP BY pool_status;

-- R0500 [弱][有效性] change_type 取值在枚举内；期望：无返回行
SELECT change_type, COUNT(*) AS cnt FROM dwd.dwd_inv_pool_change_di WHERE travel_date = '${bizdate}' AND change_type IS NOT NULL
  AND change_type NOT IN ('PRE_DEDUCT', 'CONFIRM', 'ROLLBACK', 'ADJUST')
GROUP BY change_type;

-- R0501 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_inv_pool_change_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_inv_unit_change_di  座位/房间锁定释放明细 质检 ====================
-- R0502 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_inv_unit_change_di WHERE travel_date = '${bizdate}';

-- R0503 [强][唯一性] 主键/粒度唯一（unit_id + change_time）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT unit_id, change_time, COUNT(*) AS c FROM dwd.dwd_inv_unit_change_di WHERE travel_date = '${bizdate}' GROUP BY unit_id, change_time HAVING COUNT(*) > 1
) x;

-- R0504 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_inv_unit_change_di WHERE travel_date = '${bizdate}' AND (unit_id IS NULL OR change_time IS NULL);

-- R0505 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_inv_unit_change_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0506 [弱][有效性] unit_status 取值在枚举内；期望：无返回行
SELECT unit_status, COUNT(*) AS cnt FROM dwd.dwd_inv_unit_change_di WHERE travel_date = '${bizdate}' AND unit_status IS NOT NULL
  AND unit_status NOT IN ('AVAILABLE', 'FROZEN', 'OCCUPIED')
GROUP BY unit_status;

-- R0507 [弱][有效性] before_status 取值在枚举内；期望：无返回行
SELECT before_status, COUNT(*) AS cnt FROM dwd.dwd_inv_unit_change_di WHERE travel_date = '${bizdate}' AND before_status IS NOT NULL
  AND before_status NOT IN ('AVAILABLE', 'FROZEN', 'OCCUPIED')
GROUP BY before_status;

-- R0508 [弱][有效性] after_status 取值在枚举内；期望：无返回行
SELECT after_status, COUNT(*) AS cnt FROM dwd.dwd_inv_unit_change_di WHERE travel_date = '${bizdate}' AND after_status IS NOT NULL
  AND after_status NOT IN ('AVAILABLE', 'FROZEN', 'OCCUPIED')
GROUP BY after_status;

-- R0509 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_inv_unit_change_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_inv_pool_snapshot_df  库存池日快照 质检 ====================
-- R0510 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_inv_pool_snapshot_df WHERE travel_date = '${bizdate}';

-- R0511 [强][唯一性] 主键/粒度唯一（pool_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT pool_id, COUNT(*) AS c FROM dwd.dwd_inv_pool_snapshot_df WHERE travel_date = '${bizdate}' GROUP BY pool_id HAVING COUNT(*) > 1
) x;

-- R0512 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_inv_pool_snapshot_df WHERE travel_date = '${bizdate}' AND (pool_id IS NULL);

-- R0513 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_inv_pool_snapshot_df f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0514 [弱][有效性] pool_type 取值在枚举内；期望：无返回行
SELECT pool_type, COUNT(*) AS cnt FROM dwd.dwd_inv_pool_snapshot_df WHERE travel_date = '${bizdate}' AND pool_type IS NOT NULL
  AND pool_type NOT IN ('COUNTING', 'UNIT')
GROUP BY pool_type;

-- R0515 [弱][有效性] pool_status 取值在枚举内；期望：无返回行
SELECT pool_status, COUNT(*) AS cnt FROM dwd.dwd_inv_pool_snapshot_df WHERE travel_date = '${bizdate}' AND pool_status IS NOT NULL
  AND pool_status NOT IN ('ON_SALE', 'STOP_SALE', 'EXPIRED')
GROUP BY pool_status;

-- R0516 [弱][有效性] sellout_type 取值在枚举内；期望：无返回行
SELECT sellout_type, COUNT(*) AS cnt FROM dwd.dwd_inv_pool_snapshot_df WHERE travel_date = '${bizdate}' AND sellout_type NOT IN (0, 1) GROUP BY sellout_type;

-- R0517 [弱][有效性] 金额/数量非负（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN total_qty < 0 THEN 1 ELSE 0 END) AS total_qty_neg,
  SUM(CASE WHEN available_qty < 0 THEN 1 ELSE 0 END) AS available_qty_neg,
  SUM(CASE WHEN frozen_qty < 0 THEN 1 ELSE 0 END) AS frozen_qty_neg,
  SUM(CASE WHEN sold_qty < 0 THEN 1 ELSE 0 END) AS sold_qty_neg
FROM dwd.dwd_inv_pool_snapshot_df WHERE travel_date = '${bizdate}';

-- R0518 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_inv_pool_snapshot_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_cus_customer_register_di  游客注册明细 质检 ====================
-- R0519 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_cus_customer_register_di WHERE travel_date = '${bizdate}';

-- R0520 [强][唯一性] 主键/粒度唯一（customer_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT customer_id, COUNT(*) AS c FROM dwd.dwd_cus_customer_register_di WHERE travel_date = '${bizdate}' GROUP BY customer_id HAVING COUNT(*) > 1
) x;

-- R0521 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_cus_customer_register_di WHERE travel_date = '${bizdate}' AND (customer_id IS NULL);

-- R0522 [弱][一致性] register_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_cus_customer_register_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.register_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.register_tenant_id IS NOT NULL AND CAST(f.register_tenant_id AS STRING) NOT IN ('0', '');

-- R0523 [弱][一致性] register_channel_id 能关联到 dim_trf_channel_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.channel_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_cus_customer_register_di f
LEFT JOIN dim.dim_trf_channel_df d ON f.register_channel_id = d.channel_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.register_channel_id IS NOT NULL AND CAST(f.register_channel_id AS STRING) NOT IN ('0', '');

-- R0524 [弱][有效性] customer_type 取值在枚举内；期望：无返回行
SELECT customer_type, COUNT(*) AS cnt FROM dwd.dwd_cus_customer_register_di WHERE travel_date = '${bizdate}' AND customer_type IS NOT NULL
  AND customer_type NOT IN ('REAL', 'TENANT_DEFAULT', 'PLATFORM')
GROUP BY customer_type;

-- R0525 [弱][有效性] gender_type 取值在枚举内；期望：无返回行
SELECT gender_type, COUNT(*) AS cnt FROM dwd.dwd_cus_customer_register_di WHERE travel_date = '${bizdate}' AND gender_type IS NOT NULL
  AND gender_type NOT IN ('MALE', 'FEMALE', 'UNKNOWN')
GROUP BY gender_type;

-- R0526 [弱][有效性] auth_status 取值在枚举内；期望：无返回行
SELECT auth_status, COUNT(*) AS cnt FROM dwd.dwd_cus_customer_register_di WHERE travel_date = '${bizdate}' AND auth_status IS NOT NULL
  AND auth_status NOT IN ('UNAUTHENTICATED', 'PHONE_VERIFIED', 'PERSON_CERTIFIED')
GROUP BY auth_status;

-- R0527 [弱][有效性] customer_status 取值在枚举内；期望：无返回行
SELECT customer_status, COUNT(*) AS cnt FROM dwd.dwd_cus_customer_register_di WHERE travel_date = '${bizdate}' AND customer_status IS NOT NULL
  AND customer_status NOT IN ('ACTIVE', 'BANNED', 'CANCELLED')
GROUP BY customer_status;

-- R0528 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN register_qty < 0 THEN 1 ELSE 0 END) AS register_qty_neg
FROM dwd.dwd_cus_customer_register_di WHERE travel_date = '${bizdate}';

-- R0529 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_cus_customer_register_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_cus_identity_bind_di  渠道身份绑定明细 质检 ====================
-- R0530 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_cus_identity_bind_di WHERE travel_date = '${bizdate}';

-- R0531 [强][唯一性] 主键/粒度唯一（customer_identity_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT customer_identity_id, COUNT(*) AS c FROM dwd.dwd_cus_identity_bind_di WHERE travel_date = '${bizdate}' GROUP BY customer_identity_id HAVING COUNT(*) > 1
) x;

-- R0532 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_cus_identity_bind_di WHERE travel_date = '${bizdate}' AND (customer_identity_id IS NULL);

-- R0533 [弱][一致性] customer_id 能关联到 dim_cus_customer_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.customer_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_cus_identity_bind_di f
LEFT JOIN dim.dim_cus_customer_zip d ON f.customer_id = d.customer_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.customer_id IS NOT NULL AND CAST(f.customer_id AS STRING) NOT IN ('0', '');

-- R0534 [弱][一致性] bind_channel_id 能关联到 dim_trf_channel_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.channel_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_cus_identity_bind_di f
LEFT JOIN dim.dim_trf_channel_df d ON f.bind_channel_id = d.channel_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.bind_channel_id IS NOT NULL AND CAST(f.bind_channel_id AS STRING) NOT IN ('0', '');

-- R0535 [弱][一致性] bind_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_cus_identity_bind_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.bind_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.bind_tenant_id IS NOT NULL AND CAST(f.bind_tenant_id AS STRING) NOT IN ('0', '');

-- R0536 [弱][有效性] identity_type 取值在枚举内；期望：无返回行
SELECT identity_type, COUNT(*) AS cnt FROM dwd.dwd_cus_identity_bind_di WHERE travel_date = '${bizdate}' AND identity_type IS NOT NULL
  AND identity_type NOT IN ('WECHAT_OPENID', 'DOUYIN_OPENID', 'OTA_UID', 'ALIPAY_OPENID', 'OTHER')
GROUP BY identity_type;

-- R0537 [弱][有效性] identity_status 取值在枚举内；期望：无返回行
SELECT identity_status, COUNT(*) AS cnt FROM dwd.dwd_cus_identity_bind_di WHERE travel_date = '${bizdate}' AND identity_status IS NOT NULL
  AND identity_status NOT IN ('ACTIVE', 'REVOKED')
GROUP BY identity_status;

-- R0538 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN bind_qty < 0 THEN 1 ELSE 0 END) AS bind_qty_neg
FROM dwd.dwd_cus_identity_bind_di WHERE travel_date = '${bizdate}';

-- R0539 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_cus_identity_bind_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_cus_credential_register_di  个人凭证注册明细 质检 ====================
-- R0540 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_cus_credential_register_di WHERE travel_date = '${bizdate}';

-- R0541 [强][唯一性] 主键/粒度唯一（customer_credential_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT customer_credential_id, COUNT(*) AS c FROM dwd.dwd_cus_credential_register_di WHERE travel_date = '${bizdate}' GROUP BY customer_credential_id HAVING COUNT(*) > 1
) x;

-- R0542 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_cus_credential_register_di WHERE travel_date = '${bizdate}' AND (customer_credential_id IS NULL);

-- R0543 [弱][一致性] customer_id 能关联到 dim_cus_customer_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.customer_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_cus_credential_register_di f
LEFT JOIN dim.dim_cus_customer_zip d ON f.customer_id = d.customer_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.customer_id IS NOT NULL AND CAST(f.customer_id AS STRING) NOT IN ('0', '');

-- R0544 [弱][一致性] register_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_cus_credential_register_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.register_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.register_tenant_id IS NOT NULL AND CAST(f.register_tenant_id AS STRING) NOT IN ('0', '');

-- R0545 [弱][有效性] credential_type 取值在枚举内；期望：无返回行
SELECT credential_type, COUNT(*) AS cnt FROM dwd.dwd_cus_credential_register_di WHERE travel_date = '${bizdate}' AND credential_type IS NOT NULL
  AND credential_type NOT IN ('ID_CARD', 'PASSPORT', 'DRIVER_LICENSE', 'FACE')
GROUP BY credential_type;

-- R0546 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN register_qty < 0 THEN 1 ELSE 0 END) AS register_qty_neg
FROM dwd.dwd_cus_credential_register_di WHERE travel_date = '${bizdate}';

-- R0547 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_cus_credential_register_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_opr_risk_event_di  风控事件明细 质检 ====================
-- R0548 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_opr_risk_event_di WHERE travel_date = '${bizdate}';

-- R0549 [强][唯一性] 主键/粒度唯一（risk_event_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT risk_event_id, COUNT(*) AS c FROM dwd.dwd_opr_risk_event_di WHERE travel_date = '${bizdate}' GROUP BY risk_event_id HAVING COUNT(*) > 1
) x;

-- R0550 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_opr_risk_event_di WHERE travel_date = '${bizdate}' AND (risk_event_id IS NULL);

-- R0551 [弱][一致性] rule_id 能关联到 dim_opr_risk_rule_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.risk_rule_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_opr_risk_event_di f
LEFT JOIN dim.dim_opr_risk_rule_df d ON f.rule_id = d.risk_rule_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.rule_id IS NOT NULL AND CAST(f.rule_id AS STRING) NOT IN ('0', '');

-- R0552 [弱][有效性] event_type 取值在枚举内；期望：无返回行
SELECT event_type, COUNT(*) AS cnt FROM dwd.dwd_opr_risk_event_di WHERE travel_date = '${bizdate}' AND event_type IS NOT NULL
  AND event_type NOT IN ('RULE_HIT', 'MANUAL_BAN', 'MANUAL_UNBAN', 'ABNORMAL_OP_DETECTED')
GROUP BY event_type;

-- R0553 [弱][有效性] action_type 取值在枚举内；期望：无返回行
SELECT action_type, COUNT(*) AS cnt FROM dwd.dwd_opr_risk_event_di WHERE travel_date = '${bizdate}' AND action_type IS NOT NULL
  AND action_type NOT IN ('BLOCK', 'WARN', 'FREEZE')
GROUP BY action_type;

-- R0554 [弱][有效性] rule_type 取值在枚举内；期望：无返回行
SELECT rule_type, COUNT(*) AS cnt FROM dwd.dwd_opr_risk_event_di WHERE travel_date = '${bizdate}' AND rule_type IS NOT NULL
  AND rule_type NOT IN ('BLACKLIST', 'PURCHASE_LIMIT', 'GEO_FENCE', 'ABNORMAL_OP', 'DEFAULT_BREAK')
GROUP BY rule_type;

-- R0555 [弱][有效性] dimension_type 取值在枚举内；期望：无返回行
SELECT dimension_type, COUNT(*) AS cnt FROM dwd.dwd_opr_risk_event_di WHERE travel_date = '${bizdate}' AND dimension_type IS NOT NULL
  AND dimension_type NOT IN ('USER_ID', 'ID_CARD', 'PHONE', 'DEVICE_ID')
GROUP BY dimension_type;

-- R0556 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN event_qty < 0 THEN 1 ELSE 0 END) AS event_qty_neg
FROM dwd.dwd_opr_risk_event_di WHERE travel_date = '${bizdate}';

-- R0557 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_opr_risk_event_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_opr_blacklist_log_di  黑名单变更明细 质检 ====================
-- R0558 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_opr_blacklist_log_di WHERE travel_date = '${bizdate}';

-- R0559 [强][唯一性] 主键/粒度唯一（blacklist_id + change_time）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT blacklist_id, change_time, COUNT(*) AS c FROM dwd.dwd_opr_blacklist_log_di WHERE travel_date = '${bizdate}' GROUP BY blacklist_id, change_time HAVING COUNT(*) > 1
) x;

-- R0560 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_opr_blacklist_log_di WHERE travel_date = '${bizdate}' AND (blacklist_id IS NULL OR change_time IS NULL);

-- R0561 [弱][一致性] rule_id 能关联到 dim_opr_risk_rule_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.risk_rule_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_opr_blacklist_log_di f
LEFT JOIN dim.dim_opr_risk_rule_df d ON f.rule_id = d.risk_rule_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.rule_id IS NOT NULL AND CAST(f.rule_id AS STRING) NOT IN ('0', '');

-- R0562 [弱][有效性] dimension_type 取值在枚举内；期望：无返回行
SELECT dimension_type, COUNT(*) AS cnt FROM dwd.dwd_opr_blacklist_log_di WHERE travel_date = '${bizdate}' AND dimension_type IS NOT NULL
  AND dimension_type NOT IN ('USER_ID', 'ID_CARD', 'PHONE')
GROUP BY dimension_type;

-- R0563 [弱][有效性] scope_type 取值在枚举内；期望：无返回行
SELECT scope_type, COUNT(*) AS cnt FROM dwd.dwd_opr_blacklist_log_di WHERE travel_date = '${bizdate}' AND scope_type IS NOT NULL
  AND scope_type NOT IN ('GLOBAL', 'TENANT')
GROUP BY scope_type;

-- R0564 [弱][有效性] blacklist_status 取值在枚举内；期望：无返回行
SELECT blacklist_status, COUNT(*) AS cnt FROM dwd.dwd_opr_blacklist_log_di WHERE travel_date = '${bizdate}' AND blacklist_status IS NOT NULL
  AND blacklist_status NOT IN ('ACTIVE', 'EXPIRED', 'REVOKED')
GROUP BY blacklist_status;

-- R0565 [弱][有效性] created_by_type 取值在枚举内；期望：无返回行
SELECT created_by_type, COUNT(*) AS cnt FROM dwd.dwd_opr_blacklist_log_di WHERE travel_date = '${bizdate}' AND created_by_type IS NOT NULL
  AND created_by_type NOT IN ('RISK_RULE', 'MANUAL')
GROUP BY created_by_type;

-- R0566 [弱][有效性] change_type 取值在枚举内；期望：无返回行
SELECT change_type, COUNT(*) AS cnt FROM dwd.dwd_opr_blacklist_log_di WHERE travel_date = '${bizdate}' AND change_type IS NOT NULL
  AND change_type NOT IN ('ADD', 'EXPIRE', 'REVOKE')
GROUP BY change_type;

-- R0567 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_opr_blacklist_log_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_opr_account_ban_di  账号封禁明细 质检 ====================
-- R0568 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_opr_account_ban_di WHERE travel_date = '${bizdate}';

-- R0569 [强][唯一性] 主键/粒度唯一（ban_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT ban_id, COUNT(*) AS c FROM dwd.dwd_opr_account_ban_di WHERE travel_date = '${bizdate}' GROUP BY ban_id HAVING COUNT(*) > 1
) x;

-- R0570 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_opr_account_ban_di WHERE travel_date = '${bizdate}' AND (ban_id IS NULL);

-- R0571 [弱][一致性] rule_id 能关联到 dim_opr_risk_rule_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.risk_rule_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_opr_account_ban_di f
LEFT JOIN dim.dim_opr_risk_rule_df d ON f.rule_id = d.risk_rule_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.rule_id IS NOT NULL AND CAST(f.rule_id AS STRING) NOT IN ('0', '');

-- R0572 [弱][有效性] ban_type 取值在枚举内；期望：无返回行
SELECT ban_type, COUNT(*) AS cnt FROM dwd.dwd_opr_account_ban_di WHERE travel_date = '${bizdate}' AND ban_type IS NOT NULL
  AND ban_type NOT IN ('LOGIN', 'BUSINESS')
GROUP BY ban_type;

-- R0573 [弱][有效性] ban_source_type 取值在枚举内；期望：无返回行
SELECT ban_source_type, COUNT(*) AS cnt FROM dwd.dwd_opr_account_ban_di WHERE travel_date = '${bizdate}' AND ban_source_type IS NOT NULL
  AND ban_source_type NOT IN ('RISK_RULE', 'MANUAL')
GROUP BY ban_source_type;

-- R0574 [弱][有效性] ban_status 取值在枚举内；期望：无返回行
SELECT ban_status, COUNT(*) AS cnt FROM dwd.dwd_opr_account_ban_di WHERE travel_date = '${bizdate}' AND ban_status IS NOT NULL
  AND ban_status NOT IN ('ACTIVE', 'EXPIRED', 'REVOKED')
GROUP BY ban_status;

-- R0575 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN ban_hour_qty < 0 THEN 1 ELSE 0 END) AS ban_hour_qty_neg,
  SUM(CASE WHEN ban_qty < 0 THEN 1 ELSE 0 END) AS ban_qty_neg
FROM dwd.dwd_opr_account_ban_di WHERE travel_date = '${bizdate}';

-- R0576 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_opr_account_ban_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_opr_approval_di  审批实例明细 质检 ====================
-- R0577 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_opr_approval_di WHERE travel_date = '${bizdate}';

-- R0578 [强][唯一性] 主键/粒度唯一（instance_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT instance_id, COUNT(*) AS c FROM dwd.dwd_opr_approval_di WHERE travel_date = '${bizdate}' GROUP BY instance_id HAVING COUNT(*) > 1
) x;

-- R0579 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_opr_approval_di WHERE travel_date = '${bizdate}' AND (instance_id IS NULL);

-- R0580 [弱][一致性] flow_id 能关联到 dim_opr_approval_flow_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.approval_flow_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_opr_approval_di f
LEFT JOIN dim.dim_opr_approval_flow_df d ON f.flow_id = d.approval_flow_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.flow_id IS NOT NULL AND CAST(f.flow_id AS STRING) NOT IN ('0', '');

-- R0581 [弱][有效性] instance_status 取值在枚举内；期望：无返回行
SELECT instance_status, COUNT(*) AS cnt FROM dwd.dwd_opr_approval_di WHERE travel_date = '${bizdate}' AND instance_status IS NOT NULL
  AND instance_status NOT IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')
GROUP BY instance_status;

-- R0582 [弱][有效性] timeout_type 取值在枚举内；期望：无返回行
SELECT timeout_type, COUNT(*) AS cnt FROM dwd.dwd_opr_approval_di WHERE travel_date = '${bizdate}' AND timeout_type NOT IN (0, 1) GROUP BY timeout_type;

-- R0583 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN approval_minute_qty < 0 THEN 1 ELSE 0 END) AS approval_minute_qty_neg,
  SUM(CASE WHEN approval_qty < 0 THEN 1 ELSE 0 END) AS approval_qty_neg
FROM dwd.dwd_opr_approval_di WHERE travel_date = '${bizdate}';

-- R0584 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_opr_approval_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_opr_complaint_di  投诉工单明细 质检 ====================
-- R0585 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_opr_complaint_di WHERE travel_date = '${bizdate}';

-- R0586 [强][唯一性] 主键/粒度唯一（complaint_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT complaint_id, COUNT(*) AS c FROM dwd.dwd_opr_complaint_di WHERE travel_date = '${bizdate}' GROUP BY complaint_id HAVING COUNT(*) > 1
) x;

-- R0587 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_opr_complaint_di WHERE travel_date = '${bizdate}' AND (complaint_id IS NULL);

-- R0588 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_opr_complaint_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0589 [弱][有效性] complainant_type 取值在枚举内；期望：无返回行
SELECT complainant_type, COUNT(*) AS cnt FROM dwd.dwd_opr_complaint_di WHERE travel_date = '${bizdate}' AND complainant_type IS NOT NULL
  AND complainant_type NOT IN ('VISITOR', 'MERCHANT')
GROUP BY complainant_type;

-- R0590 [弱][有效性] complaint_type 取值在枚举内；期望：无返回行
SELECT complaint_type, COUNT(*) AS cnt FROM dwd.dwd_opr_complaint_di WHERE travel_date = '${bizdate}' AND complaint_type IS NOT NULL
  AND complaint_type NOT IN ('ORDER_ISSUE', 'SERVICE_ISSUE', 'BUG', 'OTHER')
GROUP BY complaint_type;

-- R0591 [弱][有效性] complaint_status 取值在枚举内；期望：无返回行
SELECT complaint_status, COUNT(*) AS cnt FROM dwd.dwd_opr_complaint_di WHERE travel_date = '${bizdate}' AND complaint_status IS NOT NULL
  AND complaint_status NOT IN ('PENDING', 'ASSIGNED', 'PROCESSING', 'RESOLVED', 'CLOSED')
GROUP BY complaint_status;

-- R0592 [弱][有效性] sla_timeout_type 取值在枚举内；期望：无返回行
SELECT sla_timeout_type, COUNT(*) AS cnt FROM dwd.dwd_opr_complaint_di WHERE travel_date = '${bizdate}' AND sla_timeout_type NOT IN (0, 1) GROUP BY sla_timeout_type;

-- R0593 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN resolve_hour_qty < 0 THEN 1 ELSE 0 END) AS resolve_hour_qty_neg,
  SUM(CASE WHEN complaint_qty < 0 THEN 1 ELSE 0 END) AS complaint_qty_neg
FROM dwd.dwd_opr_complaint_di WHERE travel_date = '${bizdate}';

-- R0594 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_opr_complaint_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_opr_notify_di  通知发送明细 质检 ====================
-- R0595 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_opr_notify_di WHERE travel_date = '${bizdate}';

-- R0596 [强][唯一性] 主键/粒度唯一（notify_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT notify_id, COUNT(*) AS c FROM dwd.dwd_opr_notify_di WHERE travel_date = '${bizdate}' GROUP BY notify_id HAVING COUNT(*) > 1
) x;

-- R0597 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_opr_notify_di WHERE travel_date = '${bizdate}' AND (notify_id IS NULL);

-- R0598 [弱][一致性] template_id 能关联到 dim_opr_notify_template_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.notify_template_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_opr_notify_di f
LEFT JOIN dim.dim_opr_notify_template_df d ON f.template_id = d.notify_template_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.template_id IS NOT NULL AND CAST(f.template_id AS STRING) NOT IN ('0', '');

-- R0599 [弱][有效性] recipient_type 取值在枚举内；期望：无返回行
SELECT recipient_type, COUNT(*) AS cnt FROM dwd.dwd_opr_notify_di WHERE travel_date = '${bizdate}' AND recipient_type IS NOT NULL
  AND recipient_type NOT IN ('CUSTOMER', 'TENANT_STAFF', 'SYSTEM')
GROUP BY recipient_type;

-- R0600 [弱][有效性] notify_channel_type 取值在枚举内；期望：无返回行
SELECT notify_channel_type, COUNT(*) AS cnt FROM dwd.dwd_opr_notify_di WHERE travel_date = '${bizdate}' AND notify_channel_type IS NOT NULL
  AND notify_channel_type NOT IN ('SMS', 'MINI_PROGRAM_MSG', 'EMAIL', 'WEBHOOK', 'IN_APP')
GROUP BY notify_channel_type;

-- R0601 [弱][有效性] send_status 取值在枚举内；期望：无返回行
SELECT send_status, COUNT(*) AS cnt FROM dwd.dwd_opr_notify_di WHERE travel_date = '${bizdate}' AND send_status IS NOT NULL
  AND send_status NOT IN ('PENDING', 'SUCCESS', 'FAILED')
GROUP BY send_status;

-- R0602 [弱][有效性] send_success_type 取值在枚举内；期望：无返回行
SELECT send_success_type, COUNT(*) AS cnt FROM dwd.dwd_opr_notify_di WHERE travel_date = '${bizdate}' AND send_success_type NOT IN (0, 1) GROUP BY send_success_type;

-- R0603 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN notify_qty < 0 THEN 1 ELSE 0 END) AS notify_qty_neg
FROM dwd.dwd_opr_notify_di WHERE travel_date = '${bizdate}';

-- R0604 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_opr_notify_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_opr_audit_log_di  审计操作明细 质检 ====================
-- R0605 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_opr_audit_log_di WHERE travel_date = '${bizdate}';

-- R0606 [强][唯一性] 主键/粒度唯一（audit_log_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT audit_log_id, COUNT(*) AS c FROM dwd.dwd_opr_audit_log_di WHERE travel_date = '${bizdate}' GROUP BY audit_log_id HAVING COUNT(*) > 1
) x;

-- R0607 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_opr_audit_log_di WHERE travel_date = '${bizdate}' AND (audit_log_id IS NULL);

-- R0608 [弱][有效性] operator_type 取值在枚举内；期望：无返回行
SELECT operator_type, COUNT(*) AS cnt FROM dwd.dwd_opr_audit_log_di WHERE travel_date = '${bizdate}' AND operator_type IS NOT NULL
  AND operator_type NOT IN ('CUSTOMER', 'TENANT_STAFF', 'SYSTEM', 'ANONYMOUS')
GROUP BY operator_type;

-- R0609 [弱][有效性] action_type 取值在枚举内；期望：无返回行
SELECT action_type, COUNT(*) AS cnt FROM dwd.dwd_opr_audit_log_di WHERE travel_date = '${bizdate}' AND action_type IS NOT NULL
  AND action_type NOT IN ('PLACE_ORDER', 'REFUND', 'WITHDRAW', 'MODIFY_BANK_CARD')
GROUP BY action_type;

-- R0610 [弱][有效性] resource_type 取值在枚举内；期望：无返回行
SELECT resource_type, COUNT(*) AS cnt FROM dwd.dwd_opr_audit_log_di WHERE travel_date = '${bizdate}' AND resource_type IS NOT NULL
  AND resource_type NOT IN ('ORDER', 'PRODUCT', 'ACCOUNT', 'DEVICE')
GROUP BY resource_type;

-- R0611 [弱][有效性] log_scope_type 取值在枚举内；期望：无返回行
SELECT log_scope_type, COUNT(*) AS cnt FROM dwd.dwd_opr_audit_log_di WHERE travel_date = '${bizdate}' AND log_scope_type IS NOT NULL
  AND log_scope_type NOT IN ('PLATFORM', 'MERCHANT')
GROUP BY log_scope_type;

-- R0612 [弱][有效性] night_action_type 取值在枚举内；期望：无返回行
SELECT night_action_type, COUNT(*) AS cnt FROM dwd.dwd_opr_audit_log_di WHERE travel_date = '${bizdate}' AND night_action_type NOT IN (0, 1) GROUP BY night_action_type;

-- R0613 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN action_qty < 0 THEN 1 ELSE 0 END) AS action_qty_neg
FROM dwd.dwd_opr_audit_log_di WHERE travel_date = '${bizdate}';

-- R0614 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_opr_audit_log_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_opr_device_status_log_di  设备状态变更明细 质检 ====================
-- R0615 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_opr_device_status_log_di WHERE travel_date = '${bizdate}';

-- R0616 [强][唯一性] 主键/粒度唯一（device_id + change_time）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT device_id, change_time, COUNT(*) AS c FROM dwd.dwd_opr_device_status_log_di WHERE travel_date = '${bizdate}' GROUP BY device_id, change_time HAVING COUNT(*) > 1
) x;

-- R0617 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_opr_device_status_log_di WHERE travel_date = '${bizdate}' AND (device_id IS NULL OR change_time IS NULL);

-- R0618 [弱][有效性] device_type 取值在枚举内；期望：无返回行
SELECT device_type, COUNT(*) AS cnt FROM dwd.dwd_opr_device_status_log_di WHERE travel_date = '${bizdate}' AND device_type IS NOT NULL
  AND device_type NOT IN ('GATE', 'POS', 'HANDHELD', 'SELF_SERVICE', 'KIOSK', 'FACE_RECOGNITION')
GROUP BY device_type;

-- R0619 [弱][有效性] before_status 取值在枚举内；期望：无返回行
SELECT before_status, COUNT(*) AS cnt FROM dwd.dwd_opr_device_status_log_di WHERE travel_date = '${bizdate}' AND before_status IS NOT NULL
  AND before_status NOT IN ('ACTIVE', 'OFFLINE', 'MAINTENANCE', 'INACTIVE')
GROUP BY before_status;

-- R0620 [弱][有效性] after_status 取值在枚举内；期望：无返回行
SELECT after_status, COUNT(*) AS cnt FROM dwd.dwd_opr_device_status_log_di WHERE travel_date = '${bizdate}' AND after_status IS NOT NULL
  AND after_status NOT IN ('ACTIVE', 'OFFLINE', 'MAINTENANCE', 'INACTIVE')
GROUP BY after_status;

-- R0621 [弱][有效性] 金额/数量非负（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN status_minute_qty < 0 THEN 1 ELSE 0 END) AS status_minute_qty_neg
FROM dwd.dwd_opr_device_status_log_di WHERE travel_date = '${bizdate}';

-- R0622 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_opr_device_status_log_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_opr_package_subscription_di  套餐订购明细 质检 ====================
-- R0623 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_opr_package_subscription_di WHERE travel_date = '${bizdate}';

-- R0624 [强][唯一性] 主键/粒度唯一（subscription_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT subscription_id, COUNT(*) AS c FROM dwd.dwd_opr_package_subscription_di WHERE travel_date = '${bizdate}' GROUP BY subscription_id HAVING COUNT(*) > 1
) x;

-- R0625 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_opr_package_subscription_di WHERE travel_date = '${bizdate}' AND (subscription_id IS NULL);

-- R0626 [弱][一致性] package_id 能关联到 dim_opr_package_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.package_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dwd.dwd_opr_package_subscription_di f
LEFT JOIN dim.dim_opr_package_df d ON f.package_id = d.package_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.package_id IS NOT NULL AND CAST(f.package_id AS STRING) NOT IN ('0', '');

-- R0627 [弱][有效性] subscription_type 取值在枚举内；期望：无返回行
SELECT subscription_type, COUNT(*) AS cnt FROM dwd.dwd_opr_package_subscription_di WHERE travel_date = '${bizdate}' AND subscription_type IS NOT NULL
  AND subscription_type NOT IN ('NEW', 'RENEW', 'UPGRADE')
GROUP BY subscription_type;

-- R0628 [弱][有效性] subscription_status 取值在枚举内；期望：无返回行
SELECT subscription_status, COUNT(*) AS cnt FROM dwd.dwd_opr_package_subscription_di WHERE travel_date = '${bizdate}' AND subscription_status IS NOT NULL
  AND subscription_status NOT IN ('ACTIVE', 'EXPIRED', 'CANCELLED')
GROUP BY subscription_status;

-- R0629 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN package_amt < 0 THEN 1 ELSE 0 END) AS package_amt_neg,
  SUM(CASE WHEN duration_day_qty < 0 THEN 1 ELSE 0 END) AS duration_day_qty_neg
FROM dwd.dwd_opr_package_subscription_di WHERE travel_date = '${bizdate}';

-- R0630 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_opr_package_subscription_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dwd_fin_account_balance_df  账户余额日快照 质检 ====================
-- R0631 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dwd.dwd_fin_account_balance_df WHERE travel_date = '${bizdate}';

-- R0632 [强][唯一性] 主键/粒度唯一（account_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT account_id, COUNT(*) AS c FROM dwd.dwd_fin_account_balance_df WHERE travel_date = '${bizdate}' GROUP BY account_id HAVING COUNT(*) > 1
) x;

-- R0633 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dwd.dwd_fin_account_balance_df WHERE travel_date = '${bizdate}' AND (account_id IS NULL);

-- R0634 [弱][有效性] account_type 取值在枚举内；期望：无返回行
SELECT account_type, COUNT(*) AS cnt FROM dwd.dwd_fin_account_balance_df WHERE travel_date = '${bizdate}' AND account_type IS NOT NULL
  AND account_type NOT IN ('MERCHANT', 'DISTRIBUTOR', 'PLATFORM')
GROUP BY account_type;

-- R0635 [弱][有效性] 金额/数量非负（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN available_balance_amt < 0 THEN 1 ELSE 0 END) AS available_balance_amt_neg,
  SUM(CASE WHEN frozen_balance_amt < 0 THEN 1 ELSE 0 END) AS frozen_balance_amt_neg,
  SUM(CASE WHEN total_balance_amt < 0 THEN 1 ELSE 0 END) AS total_balance_amt_neg
FROM dwd.dwd_fin_account_balance_df WHERE travel_date = '${bizdate}';

-- R0636 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dwd.dwd_fin_account_balance_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dim_prd_spu_zip  产品(SPU)维度 质检 ====================
-- R0637 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_prd_spu_zip WHERE travel_date = '${bizdate}';

-- R0638 [强][唯一性] 主键/粒度唯一（spu_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT spu_id, COUNT(*) AS c FROM dim.dim_prd_spu_zip WHERE end_date = '9999-12-31' GROUP BY spu_id HAVING COUNT(*) > 1
) x;

-- R0639 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_prd_spu_zip WHERE end_date = '9999-12-31' AND (spu_id IS NULL);

-- R0640 [强][一致性] 拉链区间不重叠；期望：overlap_cnt = 0
SELECT COUNT(*) AS overlap_cnt FROM (
  SELECT spu_id, start_date, end_date,
         LEAD(start_date) OVER (PARTITION BY spu_id ORDER BY start_date) AS next_start
  FROM dim.dim_prd_spu_zip
) x WHERE next_start IS NOT NULL AND next_start <= end_date;

-- R0641 [强][一致性] 每个主键恰有 1 条当前有效记录；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM (
  SELECT spu_id, SUM(CASE WHEN end_date = '9999-12-31' THEN 1 ELSE 0 END) AS cur
  FROM dim.dim_prd_spu_zip GROUP BY spu_id
) x WHERE cur <> 1;

-- R0642 [弱][有效性] product_type 取值在枚举内；期望：无返回行
SELECT product_type, COUNT(*) AS cnt FROM dim.dim_prd_spu_zip WHERE travel_date = '${bizdate}' AND product_type IS NOT NULL
  AND product_type NOT IN ('SCENIC', 'HOTEL', 'SHOW', 'RESTAURANT', 'ANNUAL_PASS', 'SPECIALTY', 'TIMED', 'COUPON', 'LINE')
GROUP BY product_type;

-- R0643 [弱][有效性] spu_status 取值在枚举内；期望：无返回行
SELECT spu_status, COUNT(*) AS cnt FROM dim.dim_prd_spu_zip WHERE travel_date = '${bizdate}' AND spu_status IS NOT NULL
  AND spu_status NOT IN ('DRAFT', 'PUBLISHED', 'UNPUBLISHED')
GROUP BY spu_status;

-- ==================== dq.dim_prd_sku_zip  SKU维度 质检 ====================
-- R0644 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_prd_sku_zip WHERE travel_date = '${bizdate}';

-- R0645 [强][唯一性] 主键/粒度唯一（sku_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT sku_id, COUNT(*) AS c FROM dim.dim_prd_sku_zip WHERE end_date = '9999-12-31' GROUP BY sku_id HAVING COUNT(*) > 1
) x;

-- R0646 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_prd_sku_zip WHERE end_date = '9999-12-31' AND (sku_id IS NULL);

-- R0647 [强][一致性] 拉链区间不重叠；期望：overlap_cnt = 0
SELECT COUNT(*) AS overlap_cnt FROM (
  SELECT sku_id, start_date, end_date,
         LEAD(start_date) OVER (PARTITION BY sku_id ORDER BY start_date) AS next_start
  FROM dim.dim_prd_sku_zip
) x WHERE next_start IS NOT NULL AND next_start <= end_date;

-- R0648 [强][一致性] 每个主键恰有 1 条当前有效记录；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM (
  SELECT sku_id, SUM(CASE WHEN end_date = '9999-12-31' THEN 1 ELSE 0 END) AS cur
  FROM dim.dim_prd_sku_zip GROUP BY sku_id
) x WHERE cur <> 1;

-- R0649 [弱][有效性] sale_mode_type 取值在枚举内；期望：无返回行
SELECT sale_mode_type, COUNT(*) AS cnt FROM dim.dim_prd_sku_zip WHERE travel_date = '${bizdate}' AND sale_mode_type IS NOT NULL
  AND sale_mode_type NOT IN ('FIXED_DATE', 'TIMED_RESERVATION', 'PRE_SALE')
GROUP BY sale_mode_type;

-- R0650 [弱][有效性] sku_status 取值在枚举内；期望：无返回行
SELECT sku_status, COUNT(*) AS cnt FROM dim.dim_prd_sku_zip WHERE travel_date = '${bizdate}' AND sku_status IS NOT NULL
  AND sku_status NOT IN ('DRAFT', 'PUBLISHED', 'UNPUBLISHED')
GROUP BY sku_status;

-- R0651 [弱][有效性] product_type 取值在枚举内；期望：无返回行
SELECT product_type, COUNT(*) AS cnt FROM dim.dim_prd_sku_zip WHERE travel_date = '${bizdate}' AND product_type IS NOT NULL
  AND product_type NOT IN ('SCENIC', 'HOTEL', 'SHOW')
GROUP BY product_type;

-- ==================== dq.dim_prd_sku_attr_df  SKU票属性维度 质检 ====================
-- R0652 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_prd_sku_attr_df WHERE travel_date = '${bizdate}';

-- R0653 [强][唯一性] 主键/粒度唯一（sku_attr_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT sku_attr_id, COUNT(*) AS c FROM dim.dim_prd_sku_attr_df WHERE travel_date = '${bizdate}' GROUP BY sku_attr_id HAVING COUNT(*) > 1
) x;

-- R0654 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_prd_sku_attr_df WHERE travel_date = '${bizdate}' AND (sku_attr_id IS NULL);

-- R0655 [弱][有效性] value_type 取值在枚举内；期望：无返回行
SELECT value_type, COUNT(*) AS cnt FROM dim.dim_prd_sku_attr_df WHERE travel_date = '${bizdate}' AND value_type IS NOT NULL
  AND value_type NOT IN ('POLICY_CHOICE', 'TOGGLE', 'NUMERIC', 'TEXT', 'DATE_RANGE')
GROUP BY value_type;

-- ==================== dq.dim_prd_ticket_meta_f  票属性元数据码表 质检 ====================
-- R0656 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_prd_ticket_meta_f WHERE 1 = 1;

-- R0657 [强][唯一性] 主键/粒度唯一（ticket_meta_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT ticket_meta_id, COUNT(*) AS c FROM dim.dim_prd_ticket_meta_f WHERE 1 = 1 GROUP BY ticket_meta_id HAVING COUNT(*) > 1
) x;

-- R0658 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_prd_ticket_meta_f WHERE 1 = 1 AND (ticket_meta_id IS NULL);

-- R0659 [弱][有效性] value_type 取值在枚举内；期望：无返回行
SELECT value_type, COUNT(*) AS cnt FROM dim.dim_prd_ticket_meta_f WHERE 1 = 1 AND value_type IS NOT NULL
  AND value_type NOT IN ('POLICY_CHOICE', 'TOGGLE', 'NUMERIC', 'TEXT', 'DATE_RANGE')
GROUP BY value_type;

-- R0660 [弱][有效性] attribute_status 取值在枚举内；期望：无返回行
SELECT attribute_status, COUNT(*) AS cnt FROM dim.dim_prd_ticket_meta_f WHERE 1 = 1 AND attribute_status IS NOT NULL
  AND attribute_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY attribute_status;

-- ==================== dq.dim_prd_sale_rule_df  售卖规则维度 质检 ====================
-- R0661 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_prd_sale_rule_df WHERE travel_date = '${bizdate}';

-- R0662 [强][唯一性] 主键/粒度唯一（sale_rule_item_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT sale_rule_item_id, COUNT(*) AS c FROM dim.dim_prd_sale_rule_df WHERE travel_date = '${bizdate}' GROUP BY sale_rule_item_id HAVING COUNT(*) > 1
) x;

-- R0663 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_prd_sale_rule_df WHERE travel_date = '${bizdate}' AND (sale_rule_item_id IS NULL);

-- R0664 [弱][有效性] rule_type 取值在枚举内；期望：无返回行
SELECT rule_type, COUNT(*) AS cnt FROM dim.dim_prd_sale_rule_df WHERE travel_date = '${bizdate}' AND rule_type IS NOT NULL
  AND rule_type NOT IN ('DATE_RANGE', 'TIME_SLOT', 'PRE_SALE_DAYS', 'DAILY_BUY_WINDOW', 'PURCHASE_DEADLINE', 'BLACKOUT_DATE', 'WEEKDAY_MASK', 'REGION_LIMIT', 'AGE_RANGE', 'CERT_TYPE', 'MEMBER_LEVEL', 'CUSTOMER_TAG', 'GEO_FENCE', 'PURCHASE_POI', 'MIN_PURCHASE', 'MAX_PURCHASE', 'DAILY_LIMIT_PER_USER')
GROUP BY rule_type;

-- R0665 [弱][有效性] rule_status 取值在枚举内；期望：无返回行
SELECT rule_status, COUNT(*) AS cnt FROM dim.dim_prd_sale_rule_df WHERE travel_date = '${bizdate}' AND rule_status IS NOT NULL
  AND rule_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY rule_status;

-- ==================== dq.dim_prd_pricing_rule_zip  定价规则维度 质检 ====================
-- R0666 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_prd_pricing_rule_zip WHERE travel_date = '${bizdate}';

-- R0667 [强][唯一性] 主键/粒度唯一（pricing_rule_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT pricing_rule_id, COUNT(*) AS c FROM dim.dim_prd_pricing_rule_zip WHERE end_date = '9999-12-31' GROUP BY pricing_rule_id HAVING COUNT(*) > 1
) x;

-- R0668 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_prd_pricing_rule_zip WHERE end_date = '9999-12-31' AND (pricing_rule_id IS NULL);

-- R0669 [强][一致性] 拉链区间不重叠；期望：overlap_cnt = 0
SELECT COUNT(*) AS overlap_cnt FROM (
  SELECT pricing_rule_id, start_date, end_date,
         LEAD(start_date) OVER (PARTITION BY pricing_rule_id ORDER BY start_date) AS next_start
  FROM dim.dim_prd_pricing_rule_zip
) x WHERE next_start IS NOT NULL AND next_start <= end_date;

-- R0670 [强][一致性] 每个主键恰有 1 条当前有效记录；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM (
  SELECT pricing_rule_id, SUM(CASE WHEN end_date = '9999-12-31' THEN 1 ELSE 0 END) AS cur
  FROM dim.dim_prd_pricing_rule_zip GROUP BY pricing_rule_id
) x WHERE cur <> 1;

-- R0671 [弱][有效性] rule_type 取值在枚举内；期望：无返回行
SELECT rule_type, COUNT(*) AS cnt FROM dim.dim_prd_pricing_rule_zip WHERE travel_date = '${bizdate}' AND rule_type IS NOT NULL
  AND rule_type NOT IN ('MARGIN', 'SURCHARGE', 'DISCOUNT', 'MEMBER_DISCOUNT')
GROUP BY rule_type;

-- R0672 [弱][有效性] base_price_ref_type 取值在枚举内；期望：无返回行
SELECT base_price_ref_type, COUNT(*) AS cnt FROM dim.dim_prd_pricing_rule_zip WHERE travel_date = '${bizdate}' AND base_price_ref_type IS NOT NULL
  AND base_price_ref_type NOT IN ('RETAIL', 'COUNTER', 'BASE', 'CURRENT')
GROUP BY base_price_ref_type;

-- R0673 [弱][有效性] calculator_type 取值在枚举内；期望：无返回行
SELECT calculator_type, COUNT(*) AS cnt FROM dim.dim_prd_pricing_rule_zip WHERE travel_date = '${bizdate}' AND calculator_type IS NOT NULL
  AND calculator_type NOT IN ('PERCENT', 'FIXED', 'MATRIX')
GROUP BY calculator_type;

-- ==================== dq.dim_inv_pool_df  库存池维度 质检 ====================
-- R0674 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_inv_pool_df WHERE travel_date = '${bizdate}';

-- R0675 [强][唯一性] 主键/粒度唯一（pool_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT pool_id, COUNT(*) AS c FROM dim.dim_inv_pool_df WHERE travel_date = '${bizdate}' GROUP BY pool_id HAVING COUNT(*) > 1
) x;

-- R0676 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_inv_pool_df WHERE travel_date = '${bizdate}' AND (pool_id IS NULL);

-- R0677 [弱][有效性] pool_type 取值在枚举内；期望：无返回行
SELECT pool_type, COUNT(*) AS cnt FROM dim.dim_inv_pool_df WHERE travel_date = '${bizdate}' AND pool_type IS NOT NULL
  AND pool_type NOT IN ('COUNTING', 'UNIT')
GROUP BY pool_type;

-- R0678 [弱][有效性] pool_status 取值在枚举内；期望：无返回行
SELECT pool_status, COUNT(*) AS cnt FROM dim.dim_inv_pool_df WHERE travel_date = '${bizdate}' AND pool_status IS NOT NULL
  AND pool_status NOT IN ('ON_SALE', 'STOP_SALE', 'EXPIRED')
GROUP BY pool_status;

-- ==================== dq.dim_inv_unit_df  座位/房间/舱位维度 质检 ====================
-- R0679 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_inv_unit_df WHERE travel_date = '${bizdate}';

-- R0680 [强][唯一性] 主键/粒度唯一（unit_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT unit_id, COUNT(*) AS c FROM dim.dim_inv_unit_df WHERE travel_date = '${bizdate}' GROUP BY unit_id HAVING COUNT(*) > 1
) x;

-- R0681 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_inv_unit_df WHERE travel_date = '${bizdate}' AND (unit_id IS NULL);

-- R0682 [弱][有效性] unit_status 取值在枚举内；期望：无返回行
SELECT unit_status, COUNT(*) AS cnt FROM dim.dim_inv_unit_df WHERE travel_date = '${bizdate}' AND unit_status IS NOT NULL
  AND unit_status NOT IN ('AVAILABLE', 'FROZEN', 'OCCUPIED')
GROUP BY unit_status;

-- ==================== dq.dim_inv_shared_pool_df  共享库存配额维度 质检 ====================
-- R0683 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_inv_shared_pool_df WHERE travel_date = '${bizdate}';

-- R0684 [强][唯一性] 主键/粒度唯一（shared_pool_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT shared_pool_id, COUNT(*) AS c FROM dim.dim_inv_shared_pool_df WHERE travel_date = '${bizdate}' GROUP BY shared_pool_id HAVING COUNT(*) > 1
) x;

-- R0685 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_inv_shared_pool_df WHERE travel_date = '${bizdate}' AND (shared_pool_id IS NULL);

-- R0686 [弱][有效性] quota_type 取值在枚举内；期望：无返回行
SELECT quota_type, COUNT(*) AS cnt FROM dim.dim_inv_shared_pool_df WHERE travel_date = '${bizdate}' AND quota_type IS NOT NULL
  AND quota_type NOT IN ('HARD', 'SOFT', 'ROLLING')
GROUP BY quota_type;

-- R0687 [弱][有效性] sharing_status 取值在枚举内；期望：无返回行
SELECT sharing_status, COUNT(*) AS cnt FROM dim.dim_inv_shared_pool_df WHERE travel_date = '${bizdate}' AND sharing_status IS NOT NULL
  AND sharing_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY sharing_status;

-- ==================== dq.dim_cus_customer_zip  游客维度 质检 ====================
-- R0688 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_cus_customer_zip WHERE travel_date = '${bizdate}';

-- R0689 [强][唯一性] 主键/粒度唯一（customer_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT customer_id, COUNT(*) AS c FROM dim.dim_cus_customer_zip WHERE end_date = '9999-12-31' GROUP BY customer_id HAVING COUNT(*) > 1
) x;

-- R0690 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_cus_customer_zip WHERE end_date = '9999-12-31' AND (customer_id IS NULL);

-- R0691 [强][一致性] 拉链区间不重叠；期望：overlap_cnt = 0
SELECT COUNT(*) AS overlap_cnt FROM (
  SELECT customer_id, start_date, end_date,
         LEAD(start_date) OVER (PARTITION BY customer_id ORDER BY start_date) AS next_start
  FROM dim.dim_cus_customer_zip
) x WHERE next_start IS NOT NULL AND next_start <= end_date;

-- R0692 [强][一致性] 每个主键恰有 1 条当前有效记录；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM (
  SELECT customer_id, SUM(CASE WHEN end_date = '9999-12-31' THEN 1 ELSE 0 END) AS cur
  FROM dim.dim_cus_customer_zip GROUP BY customer_id
) x WHERE cur <> 1;

-- R0693 [弱][有效性] customer_type 取值在枚举内；期望：无返回行
SELECT customer_type, COUNT(*) AS cnt FROM dim.dim_cus_customer_zip WHERE travel_date = '${bizdate}' AND customer_type IS NOT NULL
  AND customer_type NOT IN ('REAL', 'TENANT_DEFAULT', 'PLATFORM')
GROUP BY customer_type;

-- R0694 [弱][有效性] gender_type 取值在枚举内；期望：无返回行
SELECT gender_type, COUNT(*) AS cnt FROM dim.dim_cus_customer_zip WHERE travel_date = '${bizdate}' AND gender_type IS NOT NULL
  AND gender_type NOT IN ('MALE', 'FEMALE', 'UNKNOWN')
GROUP BY gender_type;

-- R0695 [弱][有效性] auth_status 取值在枚举内；期望：无返回行
SELECT auth_status, COUNT(*) AS cnt FROM dim.dim_cus_customer_zip WHERE travel_date = '${bizdate}' AND auth_status IS NOT NULL
  AND auth_status NOT IN ('UNAUTHENTICATED', 'PHONE_VERIFIED', 'PERSON_CERTIFIED')
GROUP BY auth_status;

-- R0696 [弱][有效性] customer_status 取值在枚举内；期望：无返回行
SELECT customer_status, COUNT(*) AS cnt FROM dim.dim_cus_customer_zip WHERE travel_date = '${bizdate}' AND customer_status IS NOT NULL
  AND customer_status NOT IN ('ACTIVE', 'BANNED', 'CANCELLED')
GROUP BY customer_status;

-- R0697 [弱][有效性] wechat_bind_type 取值在枚举内；期望：无返回行
SELECT wechat_bind_type, COUNT(*) AS cnt FROM dim.dim_cus_customer_zip WHERE travel_date = '${bizdate}' AND wechat_bind_type NOT IN (0, 1) GROUP BY wechat_bind_type;

-- R0698 [弱][有效性] alipay_bind_type 取值在枚举内；期望：无返回行
SELECT alipay_bind_type, COUNT(*) AS cnt FROM dim.dim_cus_customer_zip WHERE travel_date = '${bizdate}' AND alipay_bind_type NOT IN (0, 1) GROUP BY alipay_bind_type;

-- ==================== dq.dim_cus_identity_df  游客渠道身份维度 质检 ====================
-- R0699 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_cus_identity_df WHERE travel_date = '${bizdate}';

-- R0700 [强][唯一性] 主键/粒度唯一（customer_identity_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT customer_identity_id, COUNT(*) AS c FROM dim.dim_cus_identity_df WHERE travel_date = '${bizdate}' GROUP BY customer_identity_id HAVING COUNT(*) > 1
) x;

-- R0701 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_cus_identity_df WHERE travel_date = '${bizdate}' AND (customer_identity_id IS NULL);

-- R0702 [弱][有效性] identity_type 取值在枚举内；期望：无返回行
SELECT identity_type, COUNT(*) AS cnt FROM dim.dim_cus_identity_df WHERE travel_date = '${bizdate}' AND identity_type IS NOT NULL
  AND identity_type NOT IN ('WECHAT_OPENID', 'DOUYIN_OPENID', 'OTA_UID', 'ALIPAY_OPENID', 'OTHER')
GROUP BY identity_type;

-- R0703 [弱][有效性] identity_status 取值在枚举内；期望：无返回行
SELECT identity_status, COUNT(*) AS cnt FROM dim.dim_cus_identity_df WHERE travel_date = '${bizdate}' AND identity_status IS NOT NULL
  AND identity_status NOT IN ('ACTIVE', 'REVOKED')
GROUP BY identity_status;

-- ==================== dq.dim_sup_tenant_zip  租户（商户/供应商/分销商）维度 质检 ====================
-- R0704 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_sup_tenant_zip WHERE travel_date = '${bizdate}';

-- R0705 [强][唯一性] 主键/粒度唯一（tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, COUNT(*) AS c FROM dim.dim_sup_tenant_zip WHERE end_date = '9999-12-31' GROUP BY tenant_id HAVING COUNT(*) > 1
) x;

-- R0706 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_sup_tenant_zip WHERE end_date = '9999-12-31' AND (tenant_id IS NULL);

-- R0707 [强][一致性] 拉链区间不重叠；期望：overlap_cnt = 0
SELECT COUNT(*) AS overlap_cnt FROM (
  SELECT tenant_id, start_date, end_date,
         LEAD(start_date) OVER (PARTITION BY tenant_id ORDER BY start_date) AS next_start
  FROM dim.dim_sup_tenant_zip
) x WHERE next_start IS NOT NULL AND next_start <= end_date;

-- R0708 [强][一致性] 每个主键恰有 1 条当前有效记录；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM (
  SELECT tenant_id, SUM(CASE WHEN end_date = '9999-12-31' THEN 1 ELSE 0 END) AS cur
  FROM dim.dim_sup_tenant_zip GROUP BY tenant_id
) x WHERE cur <> 1;

-- R0709 [弱][有效性] tenant_type 取值在枚举内；期望：无返回行
SELECT tenant_type, COUNT(*) AS cnt FROM dim.dim_sup_tenant_zip WHERE travel_date = '${bizdate}' AND tenant_type IS NOT NULL
  AND tenant_type NOT IN ('INTERNAL', 'EXTERNAL')
GROUP BY tenant_type;

-- R0710 [弱][有效性] auth_status 取值在枚举内；期望：无返回行
SELECT auth_status, COUNT(*) AS cnt FROM dim.dim_sup_tenant_zip WHERE travel_date = '${bizdate}' AND auth_status IS NOT NULL
  AND auth_status NOT IN ('UNAUTHENTICATED', 'PENDING_REVIEW', 'CERTIFIED', 'REJECTED')
GROUP BY auth_status;

-- R0711 [弱][有效性] tenant_status 取值在枚举内；期望：无返回行
SELECT tenant_status, COUNT(*) AS cnt FROM dim.dim_sup_tenant_zip WHERE travel_date = '${bizdate}' AND tenant_status IS NOT NULL
  AND tenant_status NOT IN ('ACTIVE', 'BANNED', 'INACTIVE')
GROUP BY tenant_status;

-- ==================== dq.dim_sup_staff_zip  员工维度 质检 ====================
-- R0712 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_sup_staff_zip WHERE travel_date = '${bizdate}';

-- R0713 [强][唯一性] 主键/粒度唯一（staff_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT staff_id, COUNT(*) AS c FROM dim.dim_sup_staff_zip WHERE end_date = '9999-12-31' GROUP BY staff_id HAVING COUNT(*) > 1
) x;

-- R0714 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_sup_staff_zip WHERE end_date = '9999-12-31' AND (staff_id IS NULL);

-- R0715 [强][一致性] 拉链区间不重叠；期望：overlap_cnt = 0
SELECT COUNT(*) AS overlap_cnt FROM (
  SELECT staff_id, start_date, end_date,
         LEAD(start_date) OVER (PARTITION BY staff_id ORDER BY start_date) AS next_start
  FROM dim.dim_sup_staff_zip
) x WHERE next_start IS NOT NULL AND next_start <= end_date;

-- R0716 [强][一致性] 每个主键恰有 1 条当前有效记录；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM (
  SELECT staff_id, SUM(CASE WHEN end_date = '9999-12-31' THEN 1 ELSE 0 END) AS cur
  FROM dim.dim_sup_staff_zip GROUP BY staff_id
) x WHERE cur <> 1;

-- R0717 [弱][有效性] staff_status 取值在枚举内；期望：无返回行
SELECT staff_status, COUNT(*) AS cnt FROM dim.dim_sup_staff_zip WHERE travel_date = '${bizdate}' AND staff_status IS NOT NULL
  AND staff_status NOT IN ('ACTIVE', 'DISABLED', 'RESIGNED')
GROUP BY staff_status;

-- ==================== dq.dim_sup_org_df  部门维度 质检 ====================
-- R0718 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_sup_org_df WHERE travel_date = '${bizdate}';

-- R0719 [强][唯一性] 主键/粒度唯一（org_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT org_id, COUNT(*) AS c FROM dim.dim_sup_org_df WHERE travel_date = '${bizdate}' GROUP BY org_id HAVING COUNT(*) > 1
) x;

-- R0720 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_sup_org_df WHERE travel_date = '${bizdate}' AND (org_id IS NULL);

-- R0721 [弱][有效性] org_status 取值在枚举内；期望：无返回行
SELECT org_status, COUNT(*) AS cnt FROM dim.dim_sup_org_df WHERE travel_date = '${bizdate}' AND org_status IS NOT NULL
  AND org_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY org_status;

-- ==================== dq.dim_sup_position_df  岗位维度 质检 ====================
-- R0722 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_sup_position_df WHERE travel_date = '${bizdate}';

-- R0723 [强][唯一性] 主键/粒度唯一（position_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT position_id, COUNT(*) AS c FROM dim.dim_sup_position_df WHERE travel_date = '${bizdate}' GROUP BY position_id HAVING COUNT(*) > 1
) x;

-- R0724 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_sup_position_df WHERE travel_date = '${bizdate}' AND (position_id IS NULL);

-- R0725 [弱][有效性] position_status 取值在枚举内；期望：无返回行
SELECT position_status, COUNT(*) AS cnt FROM dim.dim_sup_position_df WHERE travel_date = '${bizdate}' AND position_status IS NOT NULL
  AND position_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY position_status;

-- ==================== dq.dim_sup_role_df  角色维度 质检 ====================
-- R0726 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_sup_role_df WHERE travel_date = '${bizdate}';

-- R0727 [强][唯一性] 主键/粒度唯一（role_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT role_id, COUNT(*) AS c FROM dim.dim_sup_role_df WHERE travel_date = '${bizdate}' GROUP BY role_id HAVING COUNT(*) > 1
) x;

-- R0728 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_sup_role_df WHERE travel_date = '${bizdate}' AND (role_id IS NULL);

-- R0729 [弱][有效性] role_status 取值在枚举内；期望：无返回行
SELECT role_status, COUNT(*) AS cnt FROM dim.dim_sup_role_df WHERE travel_date = '${bizdate}' AND role_status IS NOT NULL
  AND role_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY role_status;

-- ==================== dq.dim_trf_channel_df  渠道/接入端维度 质检 ====================
-- R0730 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_trf_channel_df WHERE travel_date = '${bizdate}';

-- R0731 [强][唯一性] 主键/粒度唯一（channel_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT channel_id, COUNT(*) AS c FROM dim.dim_trf_channel_df WHERE travel_date = '${bizdate}' GROUP BY channel_id HAVING COUNT(*) > 1
) x;

-- R0732 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_trf_channel_df WHERE travel_date = '${bizdate}' AND (channel_id IS NULL);

-- R0733 [弱][有效性] channel_type 取值在枚举内；期望：无返回行
SELECT channel_type, COUNT(*) AS cnt FROM dim.dim_trf_channel_df WHERE travel_date = '${bizdate}' AND channel_type IS NOT NULL
  AND channel_type NOT IN ('MP', 'API', 'OFFLINE')
GROUP BY channel_type;

-- R0734 [弱][有效性] channel_scope_type 取值在枚举内；期望：无返回行
SELECT channel_scope_type, COUNT(*) AS cnt FROM dim.dim_trf_channel_df WHERE travel_date = '${bizdate}' AND channel_scope_type IS NOT NULL
  AND channel_scope_type NOT IN ('PLATFORM', 'TENANT')
GROUP BY channel_scope_type;

-- R0735 [弱][有效性] channel_status 取值在枚举内；期望：无返回行
SELECT channel_status, COUNT(*) AS cnt FROM dim.dim_trf_channel_df WHERE travel_date = '${bizdate}' AND channel_status IS NOT NULL
  AND channel_status NOT IN ('ENABLED', 'DISABLED')
GROUP BY channel_status;

-- ==================== dq.dim_trf_channel_tenant_df  渠道-租户绑定维度 质检 ====================
-- R0736 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_trf_channel_tenant_df WHERE travel_date = '${bizdate}';

-- R0737 [强][唯一性] 主键/粒度唯一（channel_tenant_binding_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT channel_tenant_binding_id, COUNT(*) AS c FROM dim.dim_trf_channel_tenant_df WHERE travel_date = '${bizdate}' GROUP BY channel_tenant_binding_id HAVING COUNT(*) > 1
) x;

-- R0738 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_trf_channel_tenant_df WHERE travel_date = '${bizdate}' AND (channel_tenant_binding_id IS NULL);

-- R0739 [弱][有效性] binding_status 取值在枚举内；期望：无返回行
SELECT binding_status, COUNT(*) AS cnt FROM dim.dim_trf_channel_tenant_df WHERE travel_date = '${bizdate}' AND binding_status IS NOT NULL
  AND binding_status NOT IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')
GROUP BY binding_status;

-- R0740 [弱][有效性] channel_type 取值在枚举内；期望：无返回行
SELECT channel_type, COUNT(*) AS cnt FROM dim.dim_trf_channel_tenant_df WHERE travel_date = '${bizdate}' AND channel_type IS NOT NULL
  AND channel_type NOT IN ('MP', 'API', 'OFFLINE')
GROUP BY channel_type;

-- ==================== dq.dim_trf_mp_config_df  小程序配置维度 质检 ====================
-- R0741 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_trf_mp_config_df WHERE travel_date = '${bizdate}';

-- R0742 [强][唯一性] 主键/粒度唯一（mp_config_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT mp_config_id, COUNT(*) AS c FROM dim.dim_trf_mp_config_df WHERE travel_date = '${bizdate}' GROUP BY mp_config_id HAVING COUNT(*) > 1
) x;

-- R0743 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_trf_mp_config_df WHERE travel_date = '${bizdate}' AND (mp_config_id IS NULL);

-- R0744 [弱][有效性] mp_type 取值在枚举内；期望：无返回行
SELECT mp_type, COUNT(*) AS cnt FROM dim.dim_trf_mp_config_df WHERE travel_date = '${bizdate}' AND mp_type IS NOT NULL
  AND mp_type NOT IN ('WECHAT_MP', 'WECHAT_MINI', 'WECHAT_WORK', 'ALIPAY_MINI', 'DOUYIN_MINI')
GROUP BY mp_type;

-- R0745 [弱][有效性] config_status 取值在枚举内；期望：无返回行
SELECT config_status, COUNT(*) AS cnt FROM dim.dim_trf_mp_config_df WHERE travel_date = '${bizdate}' AND config_status IS NOT NULL
  AND config_status NOT IN ('ENABLED', 'DISABLED')
GROUP BY config_status;

-- ==================== dq.dim_trf_distribution_relation_zip  分销关系维度 质检 ====================
-- R0746 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_trf_distribution_relation_zip WHERE travel_date = '${bizdate}';

-- R0747 [强][唯一性] 主键/粒度唯一（relation_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT relation_id, COUNT(*) AS c FROM dim.dim_trf_distribution_relation_zip WHERE end_date = '9999-12-31' GROUP BY relation_id HAVING COUNT(*) > 1
) x;

-- R0748 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_trf_distribution_relation_zip WHERE end_date = '9999-12-31' AND (relation_id IS NULL);

-- R0749 [强][一致性] 拉链区间不重叠；期望：overlap_cnt = 0
SELECT COUNT(*) AS overlap_cnt FROM (
  SELECT relation_id, start_date, end_date,
         LEAD(start_date) OVER (PARTITION BY relation_id ORDER BY start_date) AS next_start
  FROM dim.dim_trf_distribution_relation_zip
) x WHERE next_start IS NOT NULL AND next_start <= end_date;

-- R0750 [强][一致性] 每个主键恰有 1 条当前有效记录；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM (
  SELECT relation_id, SUM(CASE WHEN end_date = '9999-12-31' THEN 1 ELSE 0 END) AS cur
  FROM dim.dim_trf_distribution_relation_zip GROUP BY relation_id
) x WHERE cur <> 1;

-- R0751 [弱][有效性] distribution_mode_type 取值在枚举内；期望：无返回行
SELECT distribution_mode_type, COUNT(*) AS cnt FROM dim.dim_trf_distribution_relation_zip WHERE travel_date = '${bizdate}' AND distribution_mode_type IS NOT NULL
  AND distribution_mode_type NOT IN ('PROFIT_SHARE', 'PURCHASE')
GROUP BY distribution_mode_type;

-- R0752 [弱][有效性] payment_mode_type 取值在枚举内；期望：无返回行
SELECT payment_mode_type, COUNT(*) AS cnt FROM dim.dim_trf_distribution_relation_zip WHERE travel_date = '${bizdate}' AND payment_mode_type IS NOT NULL
  AND payment_mode_type NOT IN ('CREDIT', 'BALANCE')
GROUP BY payment_mode_type;

-- R0753 [弱][有效性] relation_status 取值在枚举内；期望：无返回行
SELECT relation_status, COUNT(*) AS cnt FROM dim.dim_trf_distribution_relation_zip WHERE travel_date = '${bizdate}' AND relation_status IS NOT NULL
  AND relation_status NOT IN ('ACTIVE', 'SUSPENDED', 'TERMINATED')
GROUP BY relation_status;

-- ==================== dq.dim_fin_account_df  账户维度 质检 ====================
-- R0754 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_fin_account_df WHERE travel_date = '${bizdate}';

-- R0755 [强][唯一性] 主键/粒度唯一（account_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT account_id, COUNT(*) AS c FROM dim.dim_fin_account_df WHERE travel_date = '${bizdate}' GROUP BY account_id HAVING COUNT(*) > 1
) x;

-- R0756 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_fin_account_df WHERE travel_date = '${bizdate}' AND (account_id IS NULL);

-- R0757 [弱][有效性] account_type 取值在枚举内；期望：无返回行
SELECT account_type, COUNT(*) AS cnt FROM dim.dim_fin_account_df WHERE travel_date = '${bizdate}' AND account_type IS NOT NULL
  AND account_type NOT IN ('MERCHANT', 'DISTRIBUTOR', 'PLATFORM')
GROUP BY account_type;

-- ==================== dq.dim_fin_bank_card_df  银行卡维度（脱敏） 质检 ====================
-- R0758 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_fin_bank_card_df WHERE travel_date = '${bizdate}';

-- R0759 [强][唯一性] 主键/粒度唯一（bank_card_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT bank_card_id, COUNT(*) AS c FROM dim.dim_fin_bank_card_df WHERE travel_date = '${bizdate}' GROUP BY bank_card_id HAVING COUNT(*) > 1
) x;

-- R0760 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_fin_bank_card_df WHERE travel_date = '${bizdate}' AND (bank_card_id IS NULL);

-- R0761 [弱][有效性] card_type 取值在枚举内；期望：无返回行
SELECT card_type, COUNT(*) AS cnt FROM dim.dim_fin_bank_card_df WHERE travel_date = '${bizdate}' AND card_type IS NOT NULL
  AND card_type NOT IN ('DEBIT', 'CREDIT')
GROUP BY card_type;

-- R0762 [弱][有效性] card_status 取值在枚举内；期望：无返回行
SELECT card_status, COUNT(*) AS cnt FROM dim.dim_fin_bank_card_df WHERE travel_date = '${bizdate}' AND card_status IS NOT NULL
  AND card_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY card_status;

-- ==================== dq.dim_fin_pay_channel_df  支付渠道维度 质检 ====================
-- R0763 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_fin_pay_channel_df WHERE travel_date = '${bizdate}';

-- R0764 [强][唯一性] 主键/粒度唯一（pay_channel_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT pay_channel_id, COUNT(*) AS c FROM dim.dim_fin_pay_channel_df WHERE travel_date = '${bizdate}' GROUP BY pay_channel_id HAVING COUNT(*) > 1
) x;

-- R0765 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_fin_pay_channel_df WHERE travel_date = '${bizdate}' AND (pay_channel_id IS NULL);

-- R0766 [弱][有效性] scope_type 取值在枚举内；期望：无返回行
SELECT scope_type, COUNT(*) AS cnt FROM dim.dim_fin_pay_channel_df WHERE travel_date = '${bizdate}' AND scope_type IS NOT NULL
  AND scope_type NOT IN ('PLATFORM', 'TENANT')
GROUP BY scope_type;

-- R0767 [弱][有效性] channel_status 取值在枚举内；期望：无返回行
SELECT channel_status, COUNT(*) AS cnt FROM dim.dim_fin_pay_channel_df WHERE travel_date = '${bizdate}' AND channel_status IS NOT NULL
  AND channel_status NOT IN ('ACTIVE', 'INACTIVE', 'PENDING_APPROVAL')
GROUP BY channel_status;

-- R0768 [弱][有效性] collection_mode_type 取值在枚举内；期望：无返回行
SELECT collection_mode_type, COUNT(*) AS cnt FROM dim.dim_fin_pay_channel_df WHERE travel_date = '${bizdate}' AND collection_mode_type IS NOT NULL
  AND collection_mode_type NOT IN ('PLATFORM_COLLECT', 'INDEPENDENT')
GROUP BY collection_mode_type;

-- R0769 [弱][有效性] merchant_config_status 取值在枚举内；期望：无返回行
SELECT merchant_config_status, COUNT(*) AS cnt FROM dim.dim_fin_pay_channel_df WHERE travel_date = '${bizdate}' AND merchant_config_status IS NOT NULL
  AND merchant_config_status NOT IN ('ACTIVE', 'PENDING_APPROVAL', 'INACTIVE')
GROUP BY merchant_config_status;

-- ==================== dq.dim_fin_invoice_config_df  发票配置维度 质检 ====================
-- R0770 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_fin_invoice_config_df WHERE travel_date = '${bizdate}';

-- R0771 [强][唯一性] 主键/粒度唯一（invoice_config_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT invoice_config_id, COUNT(*) AS c FROM dim.dim_fin_invoice_config_df WHERE travel_date = '${bizdate}' GROUP BY invoice_config_id HAVING COUNT(*) > 1
) x;

-- R0772 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_fin_invoice_config_df WHERE travel_date = '${bizdate}' AND (invoice_config_id IS NULL);

-- R0773 [弱][有效性] config_status 取值在枚举内；期望：无返回行
SELECT config_status, COUNT(*) AS cnt FROM dim.dim_fin_invoice_config_df WHERE travel_date = '${bizdate}' AND config_status IS NOT NULL
  AND config_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY config_status;

-- ==================== dq.dim_opr_verify_point_df  核销点维度 质检 ====================
-- R0774 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_verify_point_df WHERE travel_date = '${bizdate}';

-- R0775 [强][唯一性] 主键/粒度唯一（verify_point_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT verify_point_id, COUNT(*) AS c FROM dim.dim_opr_verify_point_df WHERE travel_date = '${bizdate}' GROUP BY verify_point_id HAVING COUNT(*) > 1
) x;

-- R0776 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_verify_point_df WHERE travel_date = '${bizdate}' AND (verify_point_id IS NULL);

-- R0777 [弱][有效性] verify_point_type 取值在枚举内；期望：无返回行
SELECT verify_point_type, COUNT(*) AS cnt FROM dim.dim_opr_verify_point_df WHERE travel_date = '${bizdate}' AND verify_point_type IS NOT NULL
  AND verify_point_type NOT IN ('GATE', 'COUNTER', 'SELF_SERVICE', 'HANDHELD')
GROUP BY verify_point_type;

-- R0778 [弱][有效性] verify_point_status 取值在枚举内；期望：无返回行
SELECT verify_point_status, COUNT(*) AS cnt FROM dim.dim_opr_verify_point_df WHERE travel_date = '${bizdate}' AND verify_point_status IS NOT NULL
  AND verify_point_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY verify_point_status;

-- ==================== dq.dim_opr_code_pool_df  码池维度 质检 ====================
-- R0779 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_code_pool_df WHERE travel_date = '${bizdate}';

-- R0780 [强][唯一性] 主键/粒度唯一（code_pool_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT code_pool_id, COUNT(*) AS c FROM dim.dim_opr_code_pool_df WHERE travel_date = '${bizdate}' GROUP BY code_pool_id HAVING COUNT(*) > 1
) x;

-- R0781 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_code_pool_df WHERE travel_date = '${bizdate}' AND (code_pool_id IS NULL);

-- R0782 [弱][有效性] pool_type 取值在枚举内；期望：无返回行
SELECT pool_type, COUNT(*) AS cnt FROM dim.dim_opr_code_pool_df WHERE travel_date = '${bizdate}' AND pool_type IS NOT NULL
  AND pool_type NOT IN ('SINGLE_TICKET', 'COMBO_TICKET')
GROUP BY pool_type;

-- R0783 [弱][有效性] credential_type 取值在枚举内；期望：无返回行
SELECT credential_type, COUNT(*) AS cnt FROM dim.dim_opr_code_pool_df WHERE travel_date = '${bizdate}' AND credential_type IS NOT NULL
  AND credential_type NOT IN ('QR_CODE', 'BAR_CODE')
GROUP BY credential_type;

-- R0784 [弱][有效性] pool_status 取值在枚举内；期望：无返回行
SELECT pool_status, COUNT(*) AS cnt FROM dim.dim_opr_code_pool_df WHERE travel_date = '${bizdate}' AND pool_status IS NOT NULL
  AND pool_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY pool_status;

-- ==================== dq.dim_opr_device_df  设备维度 质检 ====================
-- R0785 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_device_df WHERE travel_date = '${bizdate}';

-- R0786 [强][唯一性] 主键/粒度唯一（device_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT device_id, COUNT(*) AS c FROM dim.dim_opr_device_df WHERE travel_date = '${bizdate}' GROUP BY device_id HAVING COUNT(*) > 1
) x;

-- R0787 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_device_df WHERE travel_date = '${bizdate}' AND (device_id IS NULL);

-- R0788 [弱][有效性] device_type 取值在枚举内；期望：无返回行
SELECT device_type, COUNT(*) AS cnt FROM dim.dim_opr_device_df WHERE travel_date = '${bizdate}' AND device_type IS NOT NULL
  AND device_type NOT IN ('GATE', 'POS', 'HANDHELD', 'SELF_SERVICE', 'KIOSK', 'FACE_RECOGNITION')
GROUP BY device_type;

-- R0789 [弱][有效性] device_status 取值在枚举内；期望：无返回行
SELECT device_status, COUNT(*) AS cnt FROM dim.dim_opr_device_df WHERE travel_date = '${bizdate}' AND device_status IS NOT NULL
  AND device_status NOT IN ('ACTIVE', 'OFFLINE', 'MAINTENANCE', 'INACTIVE')
GROUP BY device_status;

-- ==================== dq.dim_opr_risk_rule_df  风控规则维度 质检 ====================
-- R0790 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_risk_rule_df WHERE travel_date = '${bizdate}';

-- R0791 [强][唯一性] 主键/粒度唯一（risk_rule_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT risk_rule_id, COUNT(*) AS c FROM dim.dim_opr_risk_rule_df WHERE travel_date = '${bizdate}' GROUP BY risk_rule_id HAVING COUNT(*) > 1
) x;

-- R0792 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_risk_rule_df WHERE travel_date = '${bizdate}' AND (risk_rule_id IS NULL);

-- R0793 [弱][有效性] rule_type 取值在枚举内；期望：无返回行
SELECT rule_type, COUNT(*) AS cnt FROM dim.dim_opr_risk_rule_df WHERE travel_date = '${bizdate}' AND rule_type IS NOT NULL
  AND rule_type NOT IN ('BLACKLIST', 'PURCHASE_LIMIT', 'GEO_FENCE', 'ABNORMAL_OP', 'DEFAULT_BREAK')
GROUP BY rule_type;

-- R0794 [弱][有效性] scope_type 取值在枚举内；期望：无返回行
SELECT scope_type, COUNT(*) AS cnt FROM dim.dim_opr_risk_rule_df WHERE travel_date = '${bizdate}' AND scope_type IS NOT NULL
  AND scope_type NOT IN ('GLOBAL', 'TENANT')
GROUP BY scope_type;

-- R0795 [弱][有效性] dimension_type 取值在枚举内；期望：无返回行
SELECT dimension_type, COUNT(*) AS cnt FROM dim.dim_opr_risk_rule_df WHERE travel_date = '${bizdate}' AND dimension_type IS NOT NULL
  AND dimension_type NOT IN ('USER_ID', 'ID_CARD', 'PHONE', 'DEVICE_ID')
GROUP BY dimension_type;

-- R0796 [弱][有效性] action_type 取值在枚举内；期望：无返回行
SELECT action_type, COUNT(*) AS cnt FROM dim.dim_opr_risk_rule_df WHERE travel_date = '${bizdate}' AND action_type IS NOT NULL
  AND action_type NOT IN ('BLOCK', 'WARN', 'FREEZE')
GROUP BY action_type;

-- R0797 [弱][有效性] rule_status 取值在枚举内；期望：无返回行
SELECT rule_status, COUNT(*) AS cnt FROM dim.dim_opr_risk_rule_df WHERE travel_date = '${bizdate}' AND rule_status IS NOT NULL
  AND rule_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY rule_status;

-- R0798 [弱][有效性] created_by_type 取值在枚举内；期望：无返回行
SELECT created_by_type, COUNT(*) AS cnt FROM dim.dim_opr_risk_rule_df WHERE travel_date = '${bizdate}' AND created_by_type IS NOT NULL
  AND created_by_type NOT IN ('PLATFORM_ADMIN', 'TENANT_ADMIN', 'SYSTEM')
GROUP BY created_by_type;

-- ==================== dq.dim_opr_package_df  套餐维度 质检 ====================
-- R0799 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_package_df WHERE travel_date = '${bizdate}';

-- R0800 [强][唯一性] 主键/粒度唯一（package_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT package_id, COUNT(*) AS c FROM dim.dim_opr_package_df WHERE travel_date = '${bizdate}' GROUP BY package_id HAVING COUNT(*) > 1
) x;

-- R0801 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_package_df WHERE travel_date = '${bizdate}' AND (package_id IS NULL);

-- R0802 [弱][有效性] package_status 取值在枚举内；期望：无返回行
SELECT package_status, COUNT(*) AS cnt FROM dim.dim_opr_package_df WHERE travel_date = '${bizdate}' AND package_status IS NOT NULL
  AND package_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY package_status;

-- ==================== dq.dim_opr_app_df  应用维度 质检 ====================
-- R0803 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_app_df WHERE travel_date = '${bizdate}';

-- R0804 [强][唯一性] 主键/粒度唯一（app_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT app_id, COUNT(*) AS c FROM dim.dim_opr_app_df WHERE travel_date = '${bizdate}' GROUP BY app_id HAVING COUNT(*) > 1
) x;

-- R0805 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_app_df WHERE travel_date = '${bizdate}' AND (app_id IS NULL);

-- R0806 [弱][有效性] app_type 取值在枚举内；期望：无返回行
SELECT app_type, COUNT(*) AS cnt FROM dim.dim_opr_app_df WHERE travel_date = '${bizdate}' AND app_type IS NOT NULL
  AND app_type NOT IN ('BUILTIN', 'THIRD_PARTY')
GROUP BY app_type;

-- R0807 [弱][有效性] app_status 取值在枚举内；期望：无返回行
SELECT app_status, COUNT(*) AS cnt FROM dim.dim_opr_app_df WHERE travel_date = '${bizdate}' AND app_status IS NOT NULL
  AND app_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY app_status;

-- ==================== dq.dim_opr_approval_flow_df  审批流维度 质检 ====================
-- R0808 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_approval_flow_df WHERE travel_date = '${bizdate}';

-- R0809 [强][唯一性] 主键/粒度唯一（approval_flow_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT approval_flow_id, COUNT(*) AS c FROM dim.dim_opr_approval_flow_df WHERE travel_date = '${bizdate}' GROUP BY approval_flow_id HAVING COUNT(*) > 1
) x;

-- R0810 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_approval_flow_df WHERE travel_date = '${bizdate}' AND (approval_flow_id IS NULL);

-- R0811 [弱][有效性] scope_type 取值在枚举内；期望：无返回行
SELECT scope_type, COUNT(*) AS cnt FROM dim.dim_opr_approval_flow_df WHERE travel_date = '${bizdate}' AND scope_type IS NOT NULL
  AND scope_type NOT IN ('PLATFORM', 'TENANT')
GROUP BY scope_type;

-- R0812 [弱][有效性] flow_status 取值在枚举内；期望：无返回行
SELECT flow_status, COUNT(*) AS cnt FROM dim.dim_opr_approval_flow_df WHERE travel_date = '${bizdate}' AND flow_status IS NOT NULL
  AND flow_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY flow_status;

-- R0813 [弱][有效性] version_status 取值在枚举内；期望：无返回行
SELECT version_status, COUNT(*) AS cnt FROM dim.dim_opr_approval_flow_df WHERE travel_date = '${bizdate}' AND version_status IS NOT NULL
  AND version_status NOT IN ('DRAFT', 'ACTIVE', 'HISTORICAL')
GROUP BY version_status;

-- ==================== dq.dim_opr_notify_template_df  通知模板维度 质检 ====================
-- R0814 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_notify_template_df WHERE travel_date = '${bizdate}';

-- R0815 [强][唯一性] 主键/粒度唯一（notify_template_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT notify_template_id, COUNT(*) AS c FROM dim.dim_opr_notify_template_df WHERE travel_date = '${bizdate}' GROUP BY notify_template_id HAVING COUNT(*) > 1
) x;

-- R0816 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_notify_template_df WHERE travel_date = '${bizdate}' AND (notify_template_id IS NULL);

-- R0817 [弱][有效性] notify_channel_type 取值在枚举内；期望：无返回行
SELECT notify_channel_type, COUNT(*) AS cnt FROM dim.dim_opr_notify_template_df WHERE travel_date = '${bizdate}' AND notify_channel_type IS NOT NULL
  AND notify_channel_type NOT IN ('SMS', 'MINI_PROGRAM_MSG', 'EMAIL', 'WEBHOOK', 'IN_APP')
GROUP BY notify_channel_type;

-- R0818 [弱][有效性] scope_type 取值在枚举内；期望：无返回行
SELECT scope_type, COUNT(*) AS cnt FROM dim.dim_opr_notify_template_df WHERE travel_date = '${bizdate}' AND scope_type IS NOT NULL
  AND scope_type NOT IN ('PLATFORM', 'TENANT')
GROUP BY scope_type;

-- R0819 [弱][有效性] template_status 取值在枚举内；期望：无返回行
SELECT template_status, COUNT(*) AS cnt FROM dim.dim_opr_notify_template_df WHERE travel_date = '${bizdate}' AND template_status IS NOT NULL
  AND template_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY template_status;

-- ==================== dq.dim_opr_region_f  地区维度 质检 ====================
-- R0827 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_region_f WHERE 1 = 1;

-- R0828 [强][唯一性] 主键/粒度唯一（region_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT region_id, COUNT(*) AS c FROM dim.dim_opr_region_f WHERE 1 = 1 GROUP BY region_id HAVING COUNT(*) > 1
) x;

-- R0829 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_region_f WHERE 1 = 1 AND (region_id IS NULL);

-- R0830 [弱][有效性] region_status 取值在枚举内；期望：无返回行
SELECT region_status, COUNT(*) AS cnt FROM dim.dim_opr_region_f WHERE 1 = 1 AND region_status IS NOT NULL
  AND region_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY region_status;

-- ==================== dq.dim_opr_currency_f  币种维度 质检 ====================
-- R0831 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_currency_f WHERE 1 = 1;

-- R0832 [强][唯一性] 主键/粒度唯一（currency_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT currency_id, COUNT(*) AS c FROM dim.dim_opr_currency_f WHERE 1 = 1 GROUP BY currency_id HAVING COUNT(*) > 1
) x;

-- R0833 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_currency_f WHERE 1 = 1 AND (currency_id IS NULL);

-- R0834 [弱][有效性] currency_status 取值在枚举内；期望：无返回行
SELECT currency_status, COUNT(*) AS cnt FROM dim.dim_opr_currency_f WHERE 1 = 1 AND currency_status IS NOT NULL
  AND currency_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY currency_status;

-- ==================== dq.dim_opr_dict_f  枚举码表 质检 ====================
-- R0835 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_dict_f WHERE 1 = 1;

-- R0836 [强][唯一性] 主键/粒度唯一（dict_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT dict_id, COUNT(*) AS c FROM dim.dim_opr_dict_f WHERE 1 = 1 GROUP BY dict_id HAVING COUNT(*) > 1
) x;

-- R0837 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_dict_f WHERE 1 = 1 AND (dict_id IS NULL);

-- R0838 [弱][有效性] dict_status 取值在枚举内；期望：无返回行
SELECT dict_status, COUNT(*) AS cnt FROM dim.dim_opr_dict_f WHERE 1 = 1 AND dict_status IS NOT NULL
  AND dict_status NOT IN ('ACTIVE', 'INACTIVE')
GROUP BY dict_status;

-- R0839 [弱][有效性] scope_type 取值在枚举内；期望：无返回行
SELECT scope_type, COUNT(*) AS cnt FROM dim.dim_opr_dict_f WHERE 1 = 1 AND scope_type IS NOT NULL
  AND scope_type NOT IN ('PLATFORM', 'TENANT')
GROUP BY scope_type;

-- ==================== dq.dim_mkt_coupon_df  优惠券维度 质检 ====================
-- R0840 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_mkt_coupon_df WHERE travel_date = '${bizdate}';

-- R0841 [强][唯一性] 主键/粒度唯一（coupon_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT coupon_id, COUNT(*) AS c FROM dim.dim_mkt_coupon_df WHERE travel_date = '${bizdate}' GROUP BY coupon_id HAVING COUNT(*) > 1
) x;

-- R0842 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_mkt_coupon_df WHERE travel_date = '${bizdate}' AND (coupon_id IS NULL);

-- R0843 [弱][有效性] coupon_type 取值在枚举内；期望：无返回行
SELECT coupon_type, COUNT(*) AS cnt FROM dim.dim_mkt_coupon_df WHERE travel_date = '${bizdate}' AND coupon_type IS NOT NULL
  AND coupon_type NOT IN ('FIXED_AMOUNT', 'PERCENT_DISCOUNT', 'FREE_VERIFY')
GROUP BY coupon_type;

-- R0844 [弱][有效性] coupon_status 取值在枚举内；期望：无返回行
SELECT coupon_status, COUNT(*) AS cnt FROM dim.dim_mkt_coupon_df WHERE travel_date = '${bizdate}' AND coupon_status IS NOT NULL
  AND coupon_status NOT IN ('ACTIVE', 'INACTIVE', 'EXPIRED')
GROUP BY coupon_status;

-- ==================== dq.dws_ord_tenant_sku_channel_trade_di  商户×SKU×渠道 交易日汇总 质检 ====================
-- R0845 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_ord_tenant_sku_channel_trade_di WHERE travel_date = '${bizdate}';

-- R0846 [强][唯一性] 主键/粒度唯一（seller_tenant_id + sku_id + channel_id + app_ref_code + operator_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, sku_id, channel_id, app_ref_code, operator_type, COUNT(*) AS c FROM dws.dws_ord_tenant_sku_channel_trade_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, sku_id, channel_id, app_ref_code, operator_type HAVING COUNT(*) > 1
) x;

-- R0847 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_ord_tenant_sku_channel_trade_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR sku_id IS NULL OR channel_id IS NULL OR app_ref_code IS NULL OR operator_type IS NULL);

-- R0848 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_sku_channel_trade_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0849 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_sku_channel_trade_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0850 [弱][一致性] channel_id 能关联到 dim_trf_channel_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.channel_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_sku_channel_trade_di f
LEFT JOIN dim.dim_trf_channel_df d ON f.channel_id = d.channel_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.channel_id IS NOT NULL AND CAST(f.channel_id AS STRING) NOT IN ('0', '');

-- R0851 [弱][有效性] operator_type 取值在枚举内；期望：无返回行
SELECT operator_type, COUNT(*) AS cnt FROM dws.dws_ord_tenant_sku_channel_trade_di WHERE travel_date = '${bizdate}' AND operator_type IS NOT NULL
  AND operator_type NOT IN ('CUSTOMER', 'TENANT_STAFF')
GROUP BY operator_type;

-- R0852 [弱][有效性] 金额/数量非负（17 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN order_group_qty < 0 THEN 1 ELSE 0 END) AS order_group_qty_neg,
  SUM(CASE WHEN order_qty < 0 THEN 1 ELSE 0 END) AS order_qty_neg,
  SUM(CASE WHEN order_ticket_qty < 0 THEN 1 ELSE 0 END) AS order_ticket_qty_neg,
  SUM(CASE WHEN order_amt < 0 THEN 1 ELSE 0 END) AS order_amt_neg,
  SUM(CASE WHEN pay_order_qty < 0 THEN 1 ELSE 0 END) AS pay_order_qty_neg,
  SUM(CASE WHEN pay_ticket_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_qty_neg,
  SUM(CASE WHEN pay_amt < 0 THEN 1 ELSE 0 END) AS pay_amt_neg,
  SUM(CASE WHEN pay_buyer_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_qty_neg,
  SUM(CASE WHEN cancel_order_qty < 0 THEN 1 ELSE 0 END) AS cancel_order_qty_neg,
  SUM(CASE WHEN cancel_amt < 0 THEN 1 ELSE 0 END) AS cancel_amt_neg,
  SUM(CASE WHEN staff_order_qty < 0 THEN 1 ELSE 0 END) AS staff_order_qty_neg,
  SUM(CASE WHEN combo_order_qty < 0 THEN 1 ELSE 0 END) AS combo_order_qty_neg,
  SUM(CASE WHEN pay_order_group_qty < 0 THEN 1 ELSE 0 END) AS pay_order_group_qty_neg,
  SUM(CASE WHEN cost_amt < 0 THEN 1 ELSE 0 END) AS cost_amt_neg,
  SUM(CASE WHEN pay_minute_qty < 0 THEN 1 ELSE 0 END) AS pay_minute_qty_neg,
  SUM(CASE WHEN timeout_cancel_order_qty < 0 THEN 1 ELSE 0 END) AS timeout_cancel_order_qty_neg,
  SUM(CASE WHEN advance_book_day_qty < 0 THEN 1 ELSE 0 END) AS advance_book_day_qty_neg
FROM dws.dws_ord_tenant_sku_channel_trade_di WHERE travel_date = '${bizdate}';

-- R0853 [弱][及时性/波动] order_group_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(order_group_qty) AS v FROM dws.dws_ord_tenant_sku_channel_trade_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1298 [弱][一致性] 对账：order_ticket_qty 与 dwd_ord_order_di.buy_ticket_qty 合计一致；期望：|dws_v − dwd_v| ≤ 0.01
SELECT (SELECT SUM(order_ticket_qty) FROM dws.dws_ord_tenant_sku_channel_trade_di WHERE travel_date = '${bizdate}') AS dws_v,
       (SELECT SUM(buy_ticket_qty) FROM dwd.dwd_ord_order_di WHERE travel_date = '${bizdate}') AS dwd_v;

-- ==================== dq.dws_ord_sku_play_date_booking_df  SKU×游玩日 预订存量快照 质检 ====================
-- R0854 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_ord_sku_play_date_booking_df WHERE travel_date = '${bizdate}';

-- R0855 [强][唯一性] 主键/粒度唯一（sku_id + play_date + time_slot_code）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT sku_id, play_date, time_slot_code, COUNT(*) AS c FROM dws.dws_ord_sku_play_date_booking_df WHERE travel_date = '${bizdate}' GROUP BY sku_id, play_date, time_slot_code HAVING COUNT(*) > 1
) x;

-- R0856 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_ord_sku_play_date_booking_df WHERE travel_date = '${bizdate}' AND (sku_id IS NULL OR play_date IS NULL OR time_slot_code IS NULL);

-- R0857 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_sku_play_date_booking_df f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0858 [弱][有效性] 金额/数量非负（5 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_ticket_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_qty_neg,
  SUM(CASE WHEN refund_ticket_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_qty_neg,
  SUM(CASE WHEN verify_ticket_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_qty_neg,
  SUM(CASE WHEN advance_book_day_qty < 0 THEN 1 ELSE 0 END) AS advance_book_day_qty_neg,
  SUM(CASE WHEN stock_available_qty < 0 THEN 1 ELSE 0 END) AS stock_available_qty_neg
FROM dws.dws_ord_sku_play_date_booking_df WHERE travel_date = '${bizdate}';

-- R0859 [弱][及时性/波动] pay_ticket_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_ticket_qty) AS v FROM dws.dws_ord_sku_play_date_booking_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1242 [强][一致性] 勾稽：net_pay_ticket_qty = pay_ticket_qty − refund_ticket_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM dws.dws_ord_sku_play_date_booking_df WHERE travel_date = '${bizdate}' AND ABS(COALESCE(net_pay_ticket_qty, 0) - (COALESCE(pay_ticket_qty, 0) - COALESCE(refund_ticket_qty, 0))) > 0.01;

-- ==================== dq.dws_ord_tenant_sku_verify_di  商户×SKU×核销点 核销日汇总 质检 ====================
-- R0860 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_ord_tenant_sku_verify_di WHERE travel_date = '${bizdate}';

-- R0861 [强][唯一性] 主键/粒度唯一（seller_tenant_id + sku_id + verify_point_id + verify_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, sku_id, verify_point_id, verify_type, COUNT(*) AS c FROM dws.dws_ord_tenant_sku_verify_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, sku_id, verify_point_id, verify_type HAVING COUNT(*) > 1
) x;

-- R0862 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_ord_tenant_sku_verify_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR sku_id IS NULL OR verify_point_id IS NULL OR verify_type IS NULL);

-- R0863 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_sku_verify_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0864 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_sku_verify_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0865 [弱][一致性] verify_point_id 能关联到 dim_opr_verify_point_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.verify_point_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_sku_verify_di f
LEFT JOIN dim.dim_opr_verify_point_df d ON f.verify_point_id = d.verify_point_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.verify_point_id IS NOT NULL AND CAST(f.verify_point_id AS STRING) NOT IN ('0', '');

-- R0866 [弱][有效性] verify_type 取值在枚举内；期望：无返回行
SELECT verify_type, COUNT(*) AS cnt FROM dws.dws_ord_tenant_sku_verify_di WHERE travel_date = '${bizdate}' AND verify_type IS NOT NULL
  AND verify_type NOT IN ('ONLINE', 'OFFLINE')
GROUP BY verify_type;

-- R0867 [弱][有效性] 金额/数量非负（8 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN verify_ticket_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_qty_neg,
  SUM(CASE WHEN verify_entitlement_qty < 0 THEN 1 ELSE 0 END) AS verify_entitlement_qty_neg,
  SUM(CASE WHEN verify_person_qty < 0 THEN 1 ELSE 0 END) AS verify_person_qty_neg,
  SUM(CASE WHEN verify_fail_qty < 0 THEN 1 ELSE 0 END) AS verify_fail_qty_neg,
  SUM(CASE WHEN offline_verify_qty < 0 THEN 1 ELSE 0 END) AS offline_verify_qty_neg,
  SUM(CASE WHEN verify_amt < 0 THEN 1 ELSE 0 END) AS verify_amt_neg,
  SUM(CASE WHEN duplicate_verify_qty < 0 THEN 1 ELSE 0 END) AS duplicate_verify_qty_neg,
  SUM(CASE WHEN offline_conflict_qty < 0 THEN 1 ELSE 0 END) AS offline_conflict_qty_neg
FROM dws.dws_ord_tenant_sku_verify_di WHERE travel_date = '${bizdate}';

-- R0868 [弱][及时性/波动] verify_ticket_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(verify_ticket_qty) AS v FROM dws.dws_ord_tenant_sku_verify_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_ord_verify_point_flow_hrs  核销点分时客流 质检 ====================
-- R0869 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_ord_verify_point_flow_hrs WHERE travel_date = '${bizdate}';

-- R0870 [强][唯一性] 主键/粒度唯一（stat_hour_no + seller_tenant_id + verify_point_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT stat_hour_no, seller_tenant_id, verify_point_id, COUNT(*) AS c FROM dws.dws_ord_verify_point_flow_hrs WHERE travel_date = '${bizdate}' GROUP BY stat_hour_no, seller_tenant_id, verify_point_id HAVING COUNT(*) > 1
) x;

-- R0871 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_ord_verify_point_flow_hrs WHERE travel_date = '${bizdate}' AND (stat_hour_no IS NULL OR seller_tenant_id IS NULL OR verify_point_id IS NULL);

-- R0872 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_verify_point_flow_hrs f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0873 [弱][一致性] verify_point_id 能关联到 dim_opr_verify_point_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.verify_point_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_verify_point_flow_hrs f
LEFT JOIN dim.dim_opr_verify_point_df d ON f.verify_point_id = d.verify_point_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.verify_point_id IS NOT NULL AND CAST(f.verify_point_id AS STRING) NOT IN ('0', '');

-- R0874 [弱][有效性] 金额/数量非负（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN verify_person_qty < 0 THEN 1 ELSE 0 END) AS verify_person_qty_neg,
  SUM(CASE WHEN verify_fail_qty < 0 THEN 1 ELSE 0 END) AS verify_fail_qty_neg,
  SUM(CASE WHEN verify_entitlement_qty < 0 THEN 1 ELSE 0 END) AS verify_entitlement_qty_neg
FROM dws.dws_ord_verify_point_flow_hrs WHERE travel_date = '${bizdate}';

-- R0875 [弱][及时性/波动] verify_person_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(verify_person_qty) AS v FROM dws.dws_ord_verify_point_flow_hrs
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_ord_tenant_refund_di  商户×SKU 退款日汇总 质检 ====================
-- R0876 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}';

-- R0877 [强][唯一性] 主键/粒度唯一（seller_tenant_id + sku_id + refund_type + initiator_type + refund_reason_desc）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, sku_id, refund_type, initiator_type, refund_reason_desc, COUNT(*) AS c FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, sku_id, refund_type, initiator_type, refund_reason_desc HAVING COUNT(*) > 1
) x;

-- R0878 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR sku_id IS NULL OR refund_type IS NULL OR initiator_type IS NULL OR refund_reason_desc IS NULL);

-- R0879 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_refund_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0880 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_refund_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0881 [弱][有效性] refund_type 取值在枚举内；期望：无返回行
SELECT refund_type, COUNT(*) AS cnt FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}' AND refund_type IS NOT NULL
  AND refund_type NOT IN ('ORDER_REFUND', 'COMPENSATION', 'PARTIAL_REFUND')
GROUP BY refund_type;

-- R0882 [弱][有效性] initiator_type 取值在枚举内；期望：无返回行
SELECT initiator_type, COUNT(*) AS cnt FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}' AND initiator_type IS NOT NULL
  AND initiator_type NOT IN ('VISITOR', 'MERCHANT', 'PLATFORM', 'SYSTEM')
GROUP BY initiator_type;

-- R0883 [弱][有效性] 金额/数量非负（8 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN refund_apply_qty < 0 THEN 1 ELSE 0 END) AS refund_apply_qty_neg,
  SUM(CASE WHEN refund_success_qty < 0 THEN 1 ELSE 0 END) AS refund_success_qty_neg,
  SUM(CASE WHEN refund_ticket_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_qty_neg,
  SUM(CASE WHEN refund_amt < 0 THEN 1 ELSE 0 END) AS refund_amt_neg,
  SUM(CASE WHEN refund_process_hour_qty < 0 THEN 1 ELSE 0 END) AS refund_process_hour_qty_neg,
  SUM(CASE WHEN auto_approve_refund_qty < 0 THEN 1 ELSE 0 END) AS auto_approve_refund_qty_neg,
  SUM(CASE WHEN refund_reject_qty < 0 THEN 1 ELSE 0 END) AS refund_reject_qty_neg,
  SUM(CASE WHEN verified_refund_ticket_qty < 0 THEN 1 ELSE 0 END) AS verified_refund_ticket_qty_neg
FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}';

-- R0884 [弱][及时性/波动] refund_apply_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(refund_apply_qty) AS v FROM dws.dws_ord_tenant_refund_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_ord_tenant_entitlement_di  商户×权益类型 权益使用日汇总 质检 ====================
-- R0885 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_ord_tenant_entitlement_di WHERE travel_date = '${bizdate}';

-- R0886 [强][唯一性] 主键/粒度唯一（seller_tenant_id + sku_id + entitlement_type + binding_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, sku_id, entitlement_type, binding_type, COUNT(*) AS c FROM dws.dws_ord_tenant_entitlement_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, sku_id, entitlement_type, binding_type HAVING COUNT(*) > 1
) x;

-- R0887 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_ord_tenant_entitlement_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR sku_id IS NULL OR entitlement_type IS NULL OR binding_type IS NULL);

-- R0888 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_entitlement_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0889 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_entitlement_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0890 [弱][有效性] entitlement_type 取值在枚举内；期望：无返回行
SELECT entitlement_type, COUNT(*) AS cnt FROM dws.dws_ord_tenant_entitlement_di WHERE travel_date = '${bizdate}' AND entitlement_type IS NOT NULL
  AND entitlement_type NOT IN ('FIXED', 'COUNTED', 'SELECTABLE', 'TIMED', 'QUOTA', 'UNLIMITED')
GROUP BY entitlement_type;

-- R0891 [弱][有效性] binding_type 取值在枚举内；期望：无返回行
SELECT binding_type, COUNT(*) AS cnt FROM dws.dws_ord_tenant_entitlement_di WHERE travel_date = '${bizdate}' AND binding_type IS NOT NULL
  AND binding_type NOT IN ('EXCLUSIVE', 'SHARED', 'OPEN')
GROUP BY binding_type;

-- R0892 [弱][有效性] 金额/数量非负（7 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN entitlement_issue_qty < 0 THEN 1 ELSE 0 END) AS entitlement_issue_qty_neg,
  SUM(CASE WHEN entitlement_used_qty < 0 THEN 1 ELSE 0 END) AS entitlement_used_qty_neg,
  SUM(CASE WHEN entitlement_total_qty < 0 THEN 1 ELSE 0 END) AS entitlement_total_qty_neg,
  SUM(CASE WHEN quota_total_amt < 0 THEN 1 ELSE 0 END) AS quota_total_amt_neg,
  SUM(CASE WHEN activate_ticket_qty < 0 THEN 1 ELSE 0 END) AS activate_ticket_qty_neg,
  SUM(CASE WHEN activate_delay_day_qty < 0 THEN 1 ELSE 0 END) AS activate_delay_day_qty_neg,
  SUM(CASE WHEN pending_activate_ticket_qty < 0 THEN 1 ELSE 0 END) AS pending_activate_ticket_qty_neg
FROM dws.dws_ord_tenant_entitlement_di WHERE travel_date = '${bizdate}';

-- R0893 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_ord_tenant_entitlement_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_ord_tenant_ticket_stock_df  商户×SKU 票状态存量快照 质检 ====================
-- R0894 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_ord_tenant_ticket_stock_df WHERE travel_date = '${bizdate}';

-- R0895 [强][唯一性] 主键/粒度唯一（seller_tenant_id + sku_id + ticket_status + valid_end_date）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, sku_id, ticket_status, valid_end_date, COUNT(*) AS c FROM dws.dws_ord_tenant_ticket_stock_df WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, sku_id, ticket_status, valid_end_date HAVING COUNT(*) > 1
) x;

-- R0896 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_ord_tenant_ticket_stock_df WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR sku_id IS NULL OR ticket_status IS NULL OR valid_end_date IS NULL);

-- R0897 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_ticket_stock_df f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0898 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_ord_tenant_ticket_stock_df f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0899 [弱][有效性] ticket_status 取值在枚举内；期望：无返回行
SELECT ticket_status, COUNT(*) AS cnt FROM dws.dws_ord_tenant_ticket_stock_df WHERE travel_date = '${bizdate}' AND ticket_status IS NOT NULL
  AND ticket_status NOT IN ('AVAILABLE', 'PARTIALLY_USED', 'USED', 'EXPIRED', 'REFUNDED', 'CANCELLED')
GROUP BY ticket_status;

-- R0900 [弱][有效性] 金额/数量非负（9 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN ticket_stock_qty < 0 THEN 1 ELSE 0 END) AS ticket_stock_qty_neg,
  SUM(CASE WHEN unverified_ticket_qty < 0 THEN 1 ELSE 0 END) AS unverified_ticket_qty_neg,
  SUM(CASE WHEN unverified_amt < 0 THEN 1 ELSE 0 END) AS unverified_amt_neg,
  SUM(CASE WHEN expire_ticket_qty < 0 THEN 1 ELSE 0 END) AS expire_ticket_qty_neg,
  SUM(CASE WHEN realname_ticket_qty < 0 THEN 1 ELSE 0 END) AS realname_ticket_qty_neg,
  SUM(CASE WHEN pending_activate_ticket_qty < 0 THEN 1 ELSE 0 END) AS pending_activate_ticket_qty_neg,
  SUM(CASE WHEN issue_ticket_qty < 0 THEN 1 ELSE 0 END) AS issue_ticket_qty_neg,
  SUM(CASE WHEN pay_ticket_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_qty_neg,
  SUM(CASE WHEN verify_ticket_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_qty_neg
FROM dws.dws_ord_tenant_ticket_stock_df WHERE travel_date = '${bizdate}';

-- R0901 [弱][及时性/波动] pay_ticket_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_ticket_qty) AS v FROM dws.dws_ord_tenant_ticket_stock_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_ord_combo_sku_trade_di  套票×子项 交易日汇总 质检 ====================
-- R0902 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_ord_combo_sku_trade_di WHERE travel_date = '${bizdate}';

-- R0903 [强][唯一性] 主键/粒度唯一（combo_sku_id + sub_sku_id + sub_seller_tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT combo_sku_id, sub_sku_id, sub_seller_tenant_id, COUNT(*) AS c FROM dws.dws_ord_combo_sku_trade_di WHERE travel_date = '${bizdate}' GROUP BY combo_sku_id, sub_sku_id, sub_seller_tenant_id HAVING COUNT(*) > 1
) x;

-- R0904 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_ord_combo_sku_trade_di WHERE travel_date = '${bizdate}' AND (combo_sku_id IS NULL OR sub_sku_id IS NULL OR sub_seller_tenant_id IS NULL);

-- R0905 [弱][有效性] 金额/数量非负（7 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN combo_order_qty < 0 THEN 1 ELSE 0 END) AS combo_order_qty_neg,
  SUM(CASE WHEN pay_order_qty < 0 THEN 1 ELSE 0 END) AS pay_order_qty_neg,
  SUM(CASE WHEN pay_amt < 0 THEN 1 ELSE 0 END) AS pay_amt_neg,
  SUM(CASE WHEN refund_ticket_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_qty_neg,
  SUM(CASE WHEN refund_amt < 0 THEN 1 ELSE 0 END) AS refund_amt_neg,
  SUM(CASE WHEN verify_ticket_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_qty_neg,
  SUM(CASE WHEN pay_ticket_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_qty_neg
FROM dws.dws_ord_combo_sku_trade_di WHERE travel_date = '${bizdate}';

-- R0906 [弱][及时性/波动] pay_order_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_order_qty) AS v FROM dws.dws_ord_combo_sku_trade_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_cus_customer_trade_di  游客×商户 交易日汇总 质检 ====================
-- R0907 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_cus_customer_trade_di WHERE travel_date = '${bizdate}';

-- R0908 [强][唯一性] 主键/粒度唯一（buyer_customer_id + seller_tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT buyer_customer_id, seller_tenant_id, COUNT(*) AS c FROM dws.dws_cus_customer_trade_di WHERE travel_date = '${bizdate}' GROUP BY buyer_customer_id, seller_tenant_id HAVING COUNT(*) > 1
) x;

-- R0909 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_cus_customer_trade_di WHERE travel_date = '${bizdate}' AND (buyer_customer_id IS NULL OR seller_tenant_id IS NULL);

-- R0910 [弱][一致性] buyer_customer_id 能关联到 dim_cus_customer_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.customer_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_cus_customer_trade_di f
LEFT JOIN dim.dim_cus_customer_zip d ON f.buyer_customer_id = d.customer_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.buyer_customer_id IS NOT NULL AND CAST(f.buyer_customer_id AS STRING) NOT IN ('0', '');

-- R0911 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_cus_customer_trade_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0912 [弱][有效性] 金额/数量非负（5 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_order_qty < 0 THEN 1 ELSE 0 END) AS pay_order_qty_neg,
  SUM(CASE WHEN pay_ticket_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_qty_neg,
  SUM(CASE WHEN pay_amt < 0 THEN 1 ELSE 0 END) AS pay_amt_neg,
  SUM(CASE WHEN refund_amt < 0 THEN 1 ELSE 0 END) AS refund_amt_neg,
  SUM(CASE WHEN verify_ticket_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_qty_neg
FROM dws.dws_cus_customer_trade_di WHERE travel_date = '${bizdate}';

-- R0913 [弱][及时性/波动] pay_order_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_order_qty) AS v FROM dws.dws_cus_customer_trade_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_cus_customer_lifetime_df  游客累计至今汇总 质检 ====================
-- R0914 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_cus_customer_lifetime_df WHERE travel_date = '${bizdate}';

-- R0915 [强][唯一性] 主键/粒度唯一（buyer_customer_id + seller_tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT buyer_customer_id, seller_tenant_id, COUNT(*) AS c FROM dws.dws_cus_customer_lifetime_df WHERE travel_date = '${bizdate}' GROUP BY buyer_customer_id, seller_tenant_id HAVING COUNT(*) > 1
) x;

-- R0916 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_cus_customer_lifetime_df WHERE travel_date = '${bizdate}' AND (buyer_customer_id IS NULL OR seller_tenant_id IS NULL);

-- R0917 [弱][一致性] buyer_customer_id 能关联到 dim_cus_customer_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.customer_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_cus_customer_lifetime_df f
LEFT JOIN dim.dim_cus_customer_zip d ON f.buyer_customer_id = d.customer_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.buyer_customer_id IS NOT NULL AND CAST(f.buyer_customer_id AS STRING) NOT IN ('0', '');

-- R0918 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_cus_customer_lifetime_df f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0919 [弱][有效性] 金额/数量非负（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN total_pay_order_qty < 0 THEN 1 ELSE 0 END) AS total_pay_order_qty_neg,
  SUM(CASE WHEN total_pay_amt < 0 THEN 1 ELSE 0 END) AS total_pay_amt_neg,
  SUM(CASE WHEN pay_order_30d_qty < 0 THEN 1 ELSE 0 END) AS pay_order_30d_qty_neg,
  SUM(CASE WHEN pay_30d_amt < 0 THEN 1 ELSE 0 END) AS pay_30d_amt_neg,
  SUM(CASE WHEN pay_buyer_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_qty_neg,
  SUM(CASE WHEN repeat_buyer_qty < 0 THEN 1 ELSE 0 END) AS repeat_buyer_qty_neg
FROM dws.dws_cus_customer_lifetime_df WHERE travel_date = '${bizdate}';

-- R0920 [弱][及时性/波动] pay_order_30d_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_order_30d_qty) AS v FROM dws.dws_cus_customer_lifetime_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_cus_tourist_origin_di  游客客源画像日汇总 质检 ====================
-- R0921 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_cus_tourist_origin_di WHERE travel_date = '${bizdate}';

-- R0922 [强][唯一性] 主键/粒度唯一（seller_tenant_id + sku_id + origin_province_code + origin_city_code + age_band_code + gender_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, sku_id, origin_province_code, origin_city_code, age_band_code, gender_type, COUNT(*) AS c FROM dws.dws_cus_tourist_origin_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, sku_id, origin_province_code, origin_city_code, age_band_code, gender_type HAVING COUNT(*) > 1
) x;

-- R0923 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_cus_tourist_origin_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR sku_id IS NULL OR origin_province_code IS NULL OR origin_city_code IS NULL OR age_band_code IS NULL OR gender_type IS NULL);

-- R0924 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_cus_tourist_origin_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0925 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_cus_tourist_origin_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0926 [弱][有效性] gender_type 取值在枚举内；期望：无返回行
SELECT gender_type, COUNT(*) AS cnt FROM dws.dws_cus_tourist_origin_di WHERE travel_date = '${bizdate}' AND gender_type IS NOT NULL
  AND gender_type NOT IN ('MALE', 'FEMALE', 'UNKNOWN')
GROUP BY gender_type;

-- R0927 [弱][有效性] 金额/数量非负（5 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN tourist_qty < 0 THEN 1 ELSE 0 END) AS tourist_qty_neg,
  SUM(CASE WHEN verify_person_qty < 0 THEN 1 ELSE 0 END) AS verify_person_qty_neg,
  SUM(CASE WHEN person_linked_qty < 0 THEN 1 ELSE 0 END) AS person_linked_qty_neg,
  SUM(CASE WHEN realname_ticket_qty < 0 THEN 1 ELSE 0 END) AS realname_ticket_qty_neg,
  SUM(CASE WHEN issue_ticket_qty < 0 THEN 1 ELSE 0 END) AS issue_ticket_qty_neg
FROM dws.dws_cus_tourist_origin_di WHERE travel_date = '${bizdate}';

-- R0928 [弱][及时性/波动] verify_person_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(verify_person_qty) AS v FROM dws.dws_cus_tourist_origin_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_sup_tenant_trade_di  商户经营日汇总 质检 ====================
-- R0929 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}';

-- R0930 [强][唯一性] 主键/粒度唯一（seller_tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, COUNT(*) AS c FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id HAVING COUNT(*) > 1
) x;

-- R0931 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL);

-- R0932 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_sup_tenant_trade_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0933 [弱][有效性] 金额/数量非负（15 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_order_qty < 0 THEN 1 ELSE 0 END) AS pay_order_qty_neg,
  SUM(CASE WHEN pay_ticket_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_qty_neg,
  SUM(CASE WHEN pay_amt < 0 THEN 1 ELSE 0 END) AS pay_amt_neg,
  SUM(CASE WHEN refund_amt < 0 THEN 1 ELSE 0 END) AS refund_amt_neg,
  SUM(CASE WHEN verify_ticket_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_qty_neg,
  SUM(CASE WHEN verify_amt < 0 THEN 1 ELSE 0 END) AS verify_amt_neg,
  SUM(CASE WHEN pay_buyer_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_qty_neg,
  SUM(CASE WHEN new_customer_qty < 0 THEN 1 ELSE 0 END) AS new_customer_qty_neg,
  SUM(CASE WHEN on_sale_sku_qty < 0 THEN 1 ELSE 0 END) AS on_sale_sku_qty_neg,
  SUM(CASE WHEN cost_amt < 0 THEN 1 ELSE 0 END) AS cost_amt_neg,
  SUM(CASE WHEN sold_sku_qty < 0 THEN 1 ELSE 0 END) AS sold_sku_qty_neg,
  SUM(CASE WHEN first_pay_customer_qty < 0 THEN 1 ELSE 0 END) AS first_pay_customer_qty_neg,
  SUM(CASE WHEN pay_order_group_qty < 0 THEN 1 ELSE 0 END) AS pay_order_group_qty_neg,
  SUM(CASE WHEN refund_ticket_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_qty_neg,
  SUM(CASE WHEN order_qty < 0 THEN 1 ELSE 0 END) AS order_qty_neg
FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}';

-- R0934 [弱][有效性] 比率值域（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_conversion_rate < 0 THEN 1 ELSE 0 END) AS pay_conversion_rate_bad
FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}';

-- R0935 [弱][及时性/波动] pay_order_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_order_qty) AS v FROM dws.dws_sup_tenant_trade_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1243 [强][一致性] 勾稽：net_pay_amt = pay_amt − refund_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}' AND ABS(COALESCE(net_pay_amt, 0) - (COALESCE(pay_amt, 0) - COALESCE(refund_amt, 0))) > 0.01;

-- R1244 [弱][一致性] 勾稽：pay_conversion_rate = pay_order_qty × 100 / order_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}' AND order_qty <> 0
  AND ABS(pay_conversion_rate - ROUND(pay_order_qty * 100 / order_qty, 6)) > 0.000001;

-- ==================== dq.dws_sup_tenant_lifetime_df  商户累计至今汇总 质检 ====================
-- R0936 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_sup_tenant_lifetime_df WHERE travel_date = '${bizdate}';

-- R0937 [强][唯一性] 主键/粒度唯一（seller_tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, COUNT(*) AS c FROM dws.dws_sup_tenant_lifetime_df WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id HAVING COUNT(*) > 1
) x;

-- R0938 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_sup_tenant_lifetime_df WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL);

-- R0939 [弱][一致性] seller_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_sup_tenant_lifetime_df f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.seller_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.seller_tenant_id IS NOT NULL AND CAST(f.seller_tenant_id AS STRING) NOT IN ('0', '');

-- R0940 [弱][有效性] 金额/数量非负（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN total_pay_amt < 0 THEN 1 ELSE 0 END) AS total_pay_amt_neg,
  SUM(CASE WHEN pay_30d_amt < 0 THEN 1 ELSE 0 END) AS pay_30d_amt_neg,
  SUM(CASE WHEN active_day_30d_qty < 0 THEN 1 ELSE 0 END) AS active_day_30d_qty_neg,
  SUM(CASE WHEN active_tenant_qty < 0 THEN 1 ELSE 0 END) AS active_tenant_qty_neg
FROM dws.dws_sup_tenant_lifetime_df WHERE travel_date = '${bizdate}';

-- R0941 [弱][及时性/波动] pay_30d_amt 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_30d_amt) AS v FROM dws.dws_sup_tenant_lifetime_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_sup_staff_operate_di  员工操作日汇总（窗口/导游/核销员） 质检 ====================
-- R0942 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_sup_staff_operate_di WHERE travel_date = '${bizdate}';

-- R0943 [强][唯一性] 主键/粒度唯一（tenant_id + staff_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, staff_id, COUNT(*) AS c FROM dws.dws_sup_staff_operate_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, staff_id HAVING COUNT(*) > 1
) x;

-- R0944 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_sup_staff_operate_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR staff_id IS NULL);

-- R0945 [弱][一致性] staff_id 能关联到 dim_sup_staff_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.staff_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_sup_staff_operate_di f
LEFT JOIN dim.dim_sup_staff_zip d ON f.staff_id = d.staff_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.staff_id IS NOT NULL AND CAST(f.staff_id AS STRING) NOT IN ('0', '');

-- R0946 [弱][有效性] 金额/数量非负（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN staff_order_qty < 0 THEN 1 ELSE 0 END) AS staff_order_qty_neg,
  SUM(CASE WHEN staff_pay_amt < 0 THEN 1 ELSE 0 END) AS staff_pay_amt_neg,
  SUM(CASE WHEN staff_verify_qty < 0 THEN 1 ELSE 0 END) AS staff_verify_qty_neg,
  SUM(CASE WHEN staff_refund_qty < 0 THEN 1 ELSE 0 END) AS staff_refund_qty_neg
FROM dws.dws_sup_staff_operate_di WHERE travel_date = '${bizdate}';

-- R0947 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_sup_staff_operate_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_trf_distributor_trade_di  分销商×供应商×SKU×层级 分销日汇总 质检 ====================
-- R0948 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_trf_distributor_trade_di WHERE travel_date = '${bizdate}';

-- R0949 [强][唯一性] 主键/粒度唯一（distributor_tenant_id + supplier_tenant_id + sku_id + chain_level_no）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no, COUNT(*) AS c FROM dws.dws_trf_distributor_trade_di WHERE travel_date = '${bizdate}' GROUP BY distributor_tenant_id, supplier_tenant_id, sku_id, chain_level_no HAVING COUNT(*) > 1
) x;

-- R0950 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_trf_distributor_trade_di WHERE travel_date = '${bizdate}' AND (distributor_tenant_id IS NULL OR supplier_tenant_id IS NULL OR sku_id IS NULL OR chain_level_no IS NULL);

-- R0951 [弱][一致性] distributor_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_trf_distributor_trade_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.distributor_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.distributor_tenant_id IS NOT NULL AND CAST(f.distributor_tenant_id AS STRING) NOT IN ('0', '');

-- R0952 [弱][一致性] supplier_tenant_id 能关联到 dim_sup_tenant_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.tenant_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_trf_distributor_trade_di f
LEFT JOIN dim.dim_sup_tenant_zip d ON f.supplier_tenant_id = d.tenant_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.supplier_tenant_id IS NOT NULL AND CAST(f.supplier_tenant_id AS STRING) NOT IN ('0', '');

-- R0953 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_trf_distributor_trade_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0954 [弱][有效性] 金额/数量非负（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN distribution_ticket_qty < 0 THEN 1 ELSE 0 END) AS distribution_ticket_qty_neg,
  SUM(CASE WHEN distribution_sale_amt < 0 THEN 1 ELSE 0 END) AS distribution_sale_amt_neg,
  SUM(CASE WHEN distribution_purchase_amt < 0 THEN 1 ELSE 0 END) AS distribution_purchase_amt_neg,
  SUM(CASE WHEN refund_ticket_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_qty_neg,
  SUM(CASE WHEN chain_level_qty < 0 THEN 1 ELSE 0 END) AS chain_level_qty_neg,
  SUM(CASE WHEN active_distributor_qty < 0 THEN 1 ELSE 0 END) AS active_distributor_qty_neg
FROM dws.dws_trf_distributor_trade_di WHERE travel_date = '${bizdate}';

-- R0955 [弱][及时性/波动] refund_ticket_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(refund_ticket_qty) AS v FROM dws.dws_trf_distributor_trade_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_trf_distributor_credit_df  分销关系授信快照 质检 ====================
-- R0956 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_trf_distributor_credit_df WHERE travel_date = '${bizdate}';

-- R0957 [强][唯一性] 主键/粒度唯一（relation_no）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT relation_no, COUNT(*) AS c FROM dws.dws_trf_distributor_credit_df WHERE travel_date = '${bizdate}' GROUP BY relation_no HAVING COUNT(*) > 1
) x;

-- R0958 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_trf_distributor_credit_df WHERE travel_date = '${bizdate}' AND (relation_no IS NULL);

-- R0959 [弱][一致性] relation_no 能关联到 dim_trf_distribution_relation_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.relation_no IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_trf_distributor_credit_df f
LEFT JOIN dim.dim_trf_distribution_relation_zip d ON f.relation_no = d.relation_no AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.relation_no IS NOT NULL AND CAST(f.relation_no AS STRING) NOT IN ('0', '');

-- R0960 [弱][有效性] 金额/数量非负（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN credit_limit_amt < 0 THEN 1 ELSE 0 END) AS credit_limit_amt_neg,
  SUM(CASE WHEN credit_used_amt < 0 THEN 1 ELSE 0 END) AS credit_used_amt_neg,
  SUM(CASE WHEN new_distribution_relation_qty < 0 THEN 1 ELSE 0 END) AS new_distribution_relation_qty_neg
FROM dws.dws_trf_distributor_credit_df WHERE travel_date = '${bizdate}';

-- R0961 [弱][有效性] 比率值域（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN credit_usage_rate < 0 THEN 1 ELSE 0 END) AS credit_usage_rate_bad
FROM dws.dws_trf_distributor_credit_df WHERE travel_date = '${bizdate}';

-- R0962 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_trf_distributor_credit_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1245 [弱][一致性] 勾稽：credit_usage_rate = credit_used_amt × 100 / credit_limit_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM dws.dws_trf_distributor_credit_df WHERE travel_date = '${bizdate}' AND credit_limit_amt <> 0
  AND ABS(credit_usage_rate - ROUND(credit_used_amt * 100 / credit_limit_amt, 6)) > 0.000001;

-- ==================== dq.dws_fin_account_balance_df  账户余额日快照 质检 ====================
-- R0963 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_fin_account_balance_df WHERE travel_date = '${bizdate}';

-- R0964 [强][唯一性] 主键/粒度唯一（account_no）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT account_no, COUNT(*) AS c FROM dws.dws_fin_account_balance_df WHERE travel_date = '${bizdate}' GROUP BY account_no HAVING COUNT(*) > 1
) x;

-- R0965 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_fin_account_balance_df WHERE travel_date = '${bizdate}' AND (account_no IS NULL);

-- R0966 [弱][一致性] account_no 能关联到 dim_fin_account_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.account_no IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_fin_account_balance_df f
LEFT JOIN dim.dim_fin_account_df d ON f.account_no = d.account_no AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.account_no IS NOT NULL AND CAST(f.account_no AS STRING) NOT IN ('0', '');

-- R0967 [弱][有效性] 金额/数量非负（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN available_balance_amt < 0 THEN 1 ELSE 0 END) AS available_balance_amt_neg,
  SUM(CASE WHEN frozen_balance_amt < 0 THEN 1 ELSE 0 END) AS frozen_balance_amt_neg,
  SUM(CASE WHEN opening_balance_amt < 0 THEN 1 ELSE 0 END) AS opening_balance_amt_neg,
  SUM(CASE WHEN closing_balance_amt < 0 THEN 1 ELSE 0 END) AS closing_balance_amt_neg
FROM dws.dws_fin_account_balance_df WHERE travel_date = '${bizdate}';

-- R0968 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_fin_account_balance_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_fin_account_flow_di  账户×流水类型 资金日汇总 质检 ====================
-- R0969 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_fin_account_flow_di WHERE travel_date = '${bizdate}';

-- R0970 [强][唯一性] 主键/粒度唯一（account_no + flow_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT account_no, flow_type, COUNT(*) AS c FROM dws.dws_fin_account_flow_di WHERE travel_date = '${bizdate}' GROUP BY account_no, flow_type HAVING COUNT(*) > 1
) x;

-- R0971 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_fin_account_flow_di WHERE travel_date = '${bizdate}' AND (account_no IS NULL OR flow_type IS NULL);

-- R0972 [弱][一致性] account_no 能关联到 dim_fin_account_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.account_no IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_fin_account_flow_di f
LEFT JOIN dim.dim_fin_account_df d ON f.account_no = d.account_no AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.account_no IS NOT NULL AND CAST(f.account_no AS STRING) NOT IN ('0', '');

-- R0973 [弱][有效性] flow_type 取值在枚举内；期望：无返回行
SELECT flow_type, COUNT(*) AS cnt FROM dws.dws_fin_account_flow_di WHERE travel_date = '${bizdate}' AND flow_type IS NOT NULL
  AND flow_type NOT IN ('RECHARGE', 'PAYMENT', 'REFUND', 'FREEZE', 'UNFREEZE', 'WITHDRAW', 'FEE', 'RESOURCE', 'TRANSFER_OUT', 'TRANSFER_IN')
GROUP BY flow_type;

-- R0974 [弱][有效性] 金额/数量非负（7 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN fund_flow_qty < 0 THEN 1 ELSE 0 END) AS fund_flow_qty_neg,
  SUM(CASE WHEN fund_in_amt < 0 THEN 1 ELSE 0 END) AS fund_in_amt_neg,
  SUM(CASE WHEN fund_out_amt < 0 THEN 1 ELSE 0 END) AS fund_out_amt_neg,
  SUM(CASE WHEN fee_amt < 0 THEN 1 ELSE 0 END) AS fee_amt_neg,
  SUM(CASE WHEN withdraw_apply_amt < 0 THEN 1 ELSE 0 END) AS withdraw_apply_amt_neg,
  SUM(CASE WHEN withdraw_success_amt < 0 THEN 1 ELSE 0 END) AS withdraw_success_amt_neg,
  SUM(CASE WHEN withdraw_fail_qty < 0 THEN 1 ELSE 0 END) AS withdraw_fail_qty_neg
FROM dws.dws_fin_account_flow_di WHERE travel_date = '${bizdate}';

-- R0975 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_fin_account_flow_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_fin_account_frozen_di  账户×冻结类型 冻结日汇总 质检 ====================
-- R0976 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_fin_account_frozen_di WHERE travel_date = '${bizdate}';

-- R0977 [强][唯一性] 主键/粒度唯一（account_no + freeze_type + external_frozen_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT account_no, freeze_type, external_frozen_type, COUNT(*) AS c FROM dws.dws_fin_account_frozen_di WHERE travel_date = '${bizdate}' GROUP BY account_no, freeze_type, external_frozen_type HAVING COUNT(*) > 1
) x;

-- R0978 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_fin_account_frozen_di WHERE travel_date = '${bizdate}' AND (account_no IS NULL OR freeze_type IS NULL OR external_frozen_type IS NULL);

-- R0979 [弱][一致性] account_no 能关联到 dim_fin_account_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.account_no IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_fin_account_frozen_di f
LEFT JOIN dim.dim_fin_account_df d ON f.account_no = d.account_no AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.account_no IS NOT NULL AND CAST(f.account_no AS STRING) NOT IN ('0', '');

-- R0980 [弱][有效性] freeze_type 取值在枚举内；期望：无返回行
SELECT freeze_type, COUNT(*) AS cnt FROM dws.dws_fin_account_frozen_di WHERE travel_date = '${bizdate}' AND freeze_type IS NOT NULL
  AND freeze_type NOT IN ('PROFIT', 'SETTLEMENT', 'FULL')
GROUP BY freeze_type;

-- R0981 [弱][有效性] external_frozen_type 取值在枚举内；期望：无返回行
SELECT external_frozen_type, COUNT(*) AS cnt FROM dws.dws_fin_account_frozen_di WHERE travel_date = '${bizdate}' AND external_frozen_type NOT IN (0, 1) GROUP BY external_frozen_type;

-- R0982 [弱][有效性] 金额/数量非负（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN freeze_amt < 0 THEN 1 ELSE 0 END) AS freeze_amt_neg,
  SUM(CASE WHEN unfreeze_verify_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_verify_amt_neg,
  SUM(CASE WHEN unfreeze_refund_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_refund_amt_neg,
  SUM(CASE WHEN freeze_record_qty < 0 THEN 1 ELSE 0 END) AS freeze_record_qty_neg,
  SUM(CASE WHEN external_freeze_amt < 0 THEN 1 ELSE 0 END) AS external_freeze_amt_neg,
  SUM(CASE WHEN expire_release_amt < 0 THEN 1 ELSE 0 END) AS expire_release_amt_neg
FROM dws.dws_fin_account_frozen_di WHERE travel_date = '${bizdate}';

-- R0983 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_fin_account_frozen_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_fin_tenant_pay_method_di  商户×支付方式 收付款日汇总 质检 ====================
-- R0984 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}';

-- R0985 [强][唯一性] 主键/粒度唯一（tenant_id + pay_direction_type + pay_method_type + receive_channel_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, pay_direction_type, pay_method_type, receive_channel_type, COUNT(*) AS c FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, pay_direction_type, pay_method_type, receive_channel_type HAVING COUNT(*) > 1
) x;

-- R0986 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR pay_direction_type IS NULL OR pay_method_type IS NULL OR receive_channel_type IS NULL);

-- R0987 [弱][有效性] pay_direction_type 取值在枚举内；期望：无返回行
SELECT pay_direction_type, COUNT(*) AS cnt FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}' AND pay_direction_type IS NOT NULL
  AND pay_direction_type NOT IN ('INBOUND', 'OUTBOUND')
GROUP BY pay_direction_type;

-- R0988 [弱][有效性] pay_method_type 取值在枚举内；期望：无返回行
SELECT pay_method_type, COUNT(*) AS cnt FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}' AND pay_method_type IS NOT NULL
  AND pay_method_type NOT IN ('BALANCE', 'WECHAT', 'ALIPAY', 'CREDIT', 'OFFLINE', 'ZERO_FEE')
GROUP BY pay_method_type;

-- R0989 [弱][有效性] receive_channel_type 取值在枚举内；期望：无返回行
SELECT receive_channel_type, COUNT(*) AS cnt FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}' AND receive_channel_type IS NOT NULL
  AND receive_channel_type NOT IN ('CASH', 'WECHAT_QR', 'ALIPAY_QR', 'BANK_TRANSFER', 'OFFLINE_SYSTEM_OUT')
GROUP BY receive_channel_type;

-- R0990 [弱][有效性] 金额/数量非负（9 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_record_qty < 0 THEN 1 ELSE 0 END) AS pay_record_qty_neg,
  SUM(CASE WHEN inbound_pay_amt < 0 THEN 1 ELSE 0 END) AS inbound_pay_amt_neg,
  SUM(CASE WHEN outbound_pay_amt < 0 THEN 1 ELSE 0 END) AS outbound_pay_amt_neg,
  SUM(CASE WHEN refund_payment_amt < 0 THEN 1 ELSE 0 END) AS refund_payment_amt_neg,
  SUM(CASE WHEN zero_fee_order_qty < 0 THEN 1 ELSE 0 END) AS zero_fee_order_qty_neg,
  SUM(CASE WHEN credit_pay_amt < 0 THEN 1 ELSE 0 END) AS credit_pay_amt_neg,
  SUM(CASE WHEN invoice_amt < 0 THEN 1 ELSE 0 END) AS invoice_amt_neg,
  SUM(CASE WHEN invoice_order_qty < 0 THEN 1 ELSE 0 END) AS invoice_order_qty_neg,
  SUM(CASE WHEN pay_order_group_qty < 0 THEN 1 ELSE 0 END) AS pay_order_group_qty_neg
FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}';

-- R0991 [弱][及时性/波动] pay_record_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_record_qty) AS v FROM dws.dws_fin_tenant_pay_method_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_prd_sku_price_di  SKU×渠道 价格日汇总 质检 ====================
-- R0992 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_prd_sku_price_di WHERE travel_date = '${bizdate}';

-- R0993 [强][唯一性] 主键/粒度唯一（sku_id + price_channel_code）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT sku_id, price_channel_code, COUNT(*) AS c FROM dws.dws_prd_sku_price_di WHERE travel_date = '${bizdate}' GROUP BY sku_id, price_channel_code HAVING COUNT(*) > 1
) x;

-- R0994 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_prd_sku_price_di WHERE travel_date = '${bizdate}' AND (sku_id IS NULL OR price_channel_code IS NULL);

-- R0995 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_prd_sku_price_di f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R0996 [弱][有效性] 金额/数量非负（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN list_price_amt < 0 THEN 1 ELSE 0 END) AS list_price_amt_neg,
  SUM(CASE WHEN avg_deal_price_amt < 0 THEN 1 ELSE 0 END) AS avg_deal_price_amt_neg,
  SUM(CASE WHEN pay_amt < 0 THEN 1 ELSE 0 END) AS pay_amt_neg,
  SUM(CASE WHEN pay_ticket_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_qty_neg
FROM dws.dws_prd_sku_price_di WHERE travel_date = '${bizdate}';

-- R0997 [弱][有效性] 比率值域（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN discount_rate < 0 THEN 1 ELSE 0 END) AS discount_rate_bad
FROM dws.dws_prd_sku_price_di WHERE travel_date = '${bizdate}';

-- R0998 [弱][及时性/波动] pay_amt 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_amt) AS v FROM dws.dws_prd_sku_price_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1246 [弱][一致性] 勾稽：avg_deal_price_amt = pay_amt × 100 / pay_ticket_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM dws.dws_prd_sku_price_di WHERE travel_date = '${bizdate}' AND pay_ticket_qty <> 0
  AND ABS(avg_deal_price_amt - ROUND(pay_amt * 100 / pay_ticket_qty, 6)) > 0.000001;

-- R1247 [弱][一致性] 勾稽：discount_rate = avg_deal_price_amt × 100 / list_price_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM dws.dws_prd_sku_price_di WHERE travel_date = '${bizdate}' AND list_price_amt <> 0
  AND ABS(discount_rate - ROUND(avg_deal_price_amt * 100 / list_price_amt, 6)) > 0.000001;

-- ==================== dq.dws_inv_sku_stock_df  SKU×库存维度 库存日快照 质检 ====================
-- R0999 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_inv_sku_stock_df WHERE travel_date = '${bizdate}';

-- R1000 [强][唯一性] 主键/粒度唯一（sku_id + pool_no + play_date + room_type_code + show_time）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT sku_id, pool_no, play_date, room_type_code, show_time, COUNT(*) AS c FROM dws.dws_inv_sku_stock_df WHERE travel_date = '${bizdate}' GROUP BY sku_id, pool_no, play_date, room_type_code, show_time HAVING COUNT(*) > 1
) x;

-- R1001 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_inv_sku_stock_df WHERE travel_date = '${bizdate}' AND (sku_id IS NULL OR pool_no IS NULL OR play_date IS NULL OR room_type_code IS NULL OR show_time IS NULL);

-- R1002 [弱][一致性] sku_id 能关联到 dim_prd_sku_zip；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.sku_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_inv_sku_stock_df f
LEFT JOIN dim.dim_prd_sku_zip d ON f.sku_id = d.sku_id AND d.end_date = '9999-12-31'
WHERE f.travel_date = '${bizdate}' AND f.sku_id IS NOT NULL AND CAST(f.sku_id AS STRING) NOT IN ('0', '');

-- R1003 [弱][一致性] pool_no 能关联到 dim_inv_pool_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.pool_no IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_inv_sku_stock_df f
LEFT JOIN dim.dim_inv_pool_df d ON f.pool_no = d.pool_no AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.pool_no IS NOT NULL AND CAST(f.pool_no AS STRING) NOT IN ('0', '');

-- R1004 [弱][有效性] 金额/数量非负（10 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN stock_total_qty < 0 THEN 1 ELSE 0 END) AS stock_total_qty_neg,
  SUM(CASE WHEN stock_available_qty < 0 THEN 1 ELSE 0 END) AS stock_available_qty_neg,
  SUM(CASE WHEN stock_frozen_qty < 0 THEN 1 ELSE 0 END) AS stock_frozen_qty_neg,
  SUM(CASE WHEN stock_sold_qty < 0 THEN 1 ELSE 0 END) AS stock_sold_qty_neg,
  SUM(CASE WHEN sellout_pool_qty < 0 THEN 1 ELSE 0 END) AS sellout_pool_qty_neg,
  SUM(CASE WHEN unit_occupied_qty < 0 THEN 1 ELSE 0 END) AS unit_occupied_qty_neg,
  SUM(CASE WHEN unit_total_qty < 0 THEN 1 ELSE 0 END) AS unit_total_qty_neg,
  SUM(CASE WHEN prededuct_qty < 0 THEN 1 ELSE 0 END) AS prededuct_qty_neg,
  SUM(CASE WHEN prededuct_confirm_qty < 0 THEN 1 ELSE 0 END) AS prededuct_confirm_qty_neg,
  SUM(CASE WHEN prededuct_release_qty < 0 THEN 1 ELSE 0 END) AS prededuct_release_qty_neg
FROM dws.dws_inv_sku_stock_df WHERE travel_date = '${bizdate}';

-- R1005 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_inv_sku_stock_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_opr_device_di  设备日汇总 质检 ====================
-- R1006 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_opr_device_di WHERE travel_date = '${bizdate}';

-- R1007 [强][唯一性] 主键/粒度唯一（tenant_id + device_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, device_id, COUNT(*) AS c FROM dws.dws_opr_device_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, device_id HAVING COUNT(*) > 1
) x;

-- R1008 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_opr_device_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR device_id IS NULL);

-- R1009 [弱][一致性] device_id 能关联到 dim_opr_device_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.device_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_opr_device_di f
LEFT JOIN dim.dim_opr_device_df d ON f.device_id = d.device_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.device_id IS NOT NULL AND CAST(f.device_id AS STRING) NOT IN ('0', '');

-- R1010 [弱][有效性] 金额/数量非负（5 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN online_minute_qty < 0 THEN 1 ELSE 0 END) AS online_minute_qty_neg,
  SUM(CASE WHEN offline_times_qty < 0 THEN 1 ELSE 0 END) AS offline_times_qty_neg,
  SUM(CASE WHEN verify_entitlement_qty < 0 THEN 1 ELSE 0 END) AS verify_entitlement_qty_neg,
  SUM(CASE WHEN device_total_qty < 0 THEN 1 ELSE 0 END) AS device_total_qty_neg,
  SUM(CASE WHEN offline_verify_qty < 0 THEN 1 ELSE 0 END) AS offline_verify_qty_neg
FROM dws.dws_opr_device_di WHERE travel_date = '${bizdate}';

-- R1011 [弱][及时性/波动] verify_entitlement_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(verify_entitlement_qty) AS v FROM dws.dws_opr_device_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_opr_risk_rule_hit_di  风控规则命中日汇总 质检 ====================
-- R1012 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_opr_risk_rule_hit_di WHERE travel_date = '${bizdate}';

-- R1013 [强][唯一性] 主键/粒度唯一（rule_id + action_type + dimension_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT rule_id, action_type, dimension_type, COUNT(*) AS c FROM dws.dws_opr_risk_rule_hit_di WHERE travel_date = '${bizdate}' GROUP BY rule_id, action_type, dimension_type HAVING COUNT(*) > 1
) x;

-- R1014 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_opr_risk_rule_hit_di WHERE travel_date = '${bizdate}' AND (rule_id IS NULL OR action_type IS NULL OR dimension_type IS NULL);

-- R1015 [弱][一致性] rule_id 能关联到 dim_opr_risk_rule_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.risk_rule_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_opr_risk_rule_hit_di f
LEFT JOIN dim.dim_opr_risk_rule_df d ON f.rule_id = d.risk_rule_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.rule_id IS NOT NULL AND CAST(f.rule_id AS STRING) NOT IN ('0', '');

-- R1016 [弱][有效性] action_type 取值在枚举内；期望：无返回行
SELECT action_type, COUNT(*) AS cnt FROM dws.dws_opr_risk_rule_hit_di WHERE travel_date = '${bizdate}' AND action_type IS NOT NULL
  AND action_type NOT IN ('BLOCK', 'WARN', 'FREEZE')
GROUP BY action_type;

-- R1017 [弱][有效性] dimension_type 取值在枚举内；期望：无返回行
SELECT dimension_type, COUNT(*) AS cnt FROM dws.dws_opr_risk_rule_hit_di WHERE travel_date = '${bizdate}' AND dimension_type IS NOT NULL
  AND dimension_type NOT IN ('USER_ID', 'ID_CARD', 'PHONE', 'DEVICE_ID')
GROUP BY dimension_type;

-- R1018 [弱][有效性] 金额/数量非负（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN risk_hit_qty < 0 THEN 1 ELSE 0 END) AS risk_hit_qty_neg,
  SUM(CASE WHEN risk_block_qty < 0 THEN 1 ELSE 0 END) AS risk_block_qty_neg,
  SUM(CASE WHEN blacklist_add_qty < 0 THEN 1 ELSE 0 END) AS blacklist_add_qty_neg,
  SUM(CASE WHEN ban_qty < 0 THEN 1 ELSE 0 END) AS ban_qty_neg
FROM dws.dws_opr_risk_rule_hit_di WHERE travel_date = '${bizdate}';

-- R1019 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_opr_risk_rule_hit_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_opr_complaint_di  投诉日汇总 质检 ====================
-- R1020 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_opr_complaint_di WHERE travel_date = '${bizdate}';

-- R1021 [强][唯一性] 主键/粒度唯一（tenant_id + complaint_type + complainant_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, complaint_type, complainant_type, COUNT(*) AS c FROM dws.dws_opr_complaint_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, complaint_type, complainant_type HAVING COUNT(*) > 1
) x;

-- R1022 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_opr_complaint_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR complaint_type IS NULL OR complainant_type IS NULL);

-- R1023 [弱][有效性] complaint_type 取值在枚举内；期望：无返回行
SELECT complaint_type, COUNT(*) AS cnt FROM dws.dws_opr_complaint_di WHERE travel_date = '${bizdate}' AND complaint_type IS NOT NULL
  AND complaint_type NOT IN ('ORDER_ISSUE', 'SERVICE_ISSUE', 'BUG', 'OTHER')
GROUP BY complaint_type;

-- R1024 [弱][有效性] complainant_type 取值在枚举内；期望：无返回行
SELECT complainant_type, COUNT(*) AS cnt FROM dws.dws_opr_complaint_di WHERE travel_date = '${bizdate}' AND complainant_type IS NOT NULL
  AND complainant_type NOT IN ('VISITOR', 'MERCHANT')
GROUP BY complainant_type;

-- R1025 [弱][有效性] 金额/数量非负（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN complaint_qty < 0 THEN 1 ELSE 0 END) AS complaint_qty_neg,
  SUM(CASE WHEN complaint_resolved_qty < 0 THEN 1 ELSE 0 END) AS complaint_resolved_qty_neg,
  SUM(CASE WHEN complaint_overdue_qty < 0 THEN 1 ELSE 0 END) AS complaint_overdue_qty_neg
FROM dws.dws_opr_complaint_di WHERE travel_date = '${bizdate}';

-- R1026 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_opr_complaint_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_opr_notify_di  通知发送日汇总 质检 ====================
-- R1027 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_opr_notify_di WHERE travel_date = '${bizdate}';

-- R1028 [强][唯一性] 主键/粒度唯一（tenant_id + notify_channel_type + template_code）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, notify_channel_type, template_code, COUNT(*) AS c FROM dws.dws_opr_notify_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, notify_channel_type, template_code HAVING COUNT(*) > 1
) x;

-- R1029 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_opr_notify_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR notify_channel_type IS NULL OR template_code IS NULL);

-- R1030 [弱][有效性] notify_channel_type 取值在枚举内；期望：无返回行
SELECT notify_channel_type, COUNT(*) AS cnt FROM dws.dws_opr_notify_di WHERE travel_date = '${bizdate}' AND notify_channel_type IS NOT NULL
  AND notify_channel_type NOT IN ('SMS', 'MINI_PROGRAM_MSG', 'EMAIL', 'WEBHOOK', 'IN_APP')
GROUP BY notify_channel_type;

-- R1031 [弱][有效性] 金额/数量非负（5 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN notify_send_qty < 0 THEN 1 ELSE 0 END) AS notify_send_qty_neg,
  SUM(CASE WHEN notify_success_qty < 0 THEN 1 ELSE 0 END) AS notify_success_qty_neg,
  SUM(CASE WHEN sms_send_qty < 0 THEN 1 ELSE 0 END) AS sms_send_qty_neg,
  SUM(CASE WHEN notify_fail_qty < 0 THEN 1 ELSE 0 END) AS notify_fail_qty_neg,
  SUM(CASE WHEN resource_consume_qty < 0 THEN 1 ELSE 0 END) AS resource_consume_qty_neg
FROM dws.dws_opr_notify_di WHERE travel_date = '${bizdate}';

-- R1032 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_opr_notify_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_opr_audit_action_di  操作审计日汇总 质检 ====================
-- R1033 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_opr_audit_action_di WHERE travel_date = '${bizdate}';

-- R1034 [强][唯一性] 主键/粒度唯一（tenant_id + operator_type + operator_id + action_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, operator_type, operator_id, action_type, COUNT(*) AS c FROM dws.dws_opr_audit_action_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, operator_type, operator_id, action_type HAVING COUNT(*) > 1
) x;

-- R1035 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_opr_audit_action_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR operator_type IS NULL OR operator_id IS NULL OR action_type IS NULL);

-- R1036 [弱][有效性] operator_type 取值在枚举内；期望：无返回行
SELECT operator_type, COUNT(*) AS cnt FROM dws.dws_opr_audit_action_di WHERE travel_date = '${bizdate}' AND operator_type IS NOT NULL
  AND operator_type NOT IN ('CUSTOMER', 'TENANT_STAFF')
GROUP BY operator_type;

-- R1037 [弱][有效性] action_type 取值在枚举内；期望：无返回行
SELECT action_type, COUNT(*) AS cnt FROM dws.dws_opr_audit_action_di WHERE travel_date = '${bizdate}' AND action_type IS NOT NULL
  AND action_type NOT IN ('BLOCK', 'WARN', 'FREEZE')
GROUP BY action_type;

-- R1038 [弱][有效性] 金额/数量非负（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN audit_action_qty < 0 THEN 1 ELSE 0 END) AS audit_action_qty_neg,
  SUM(CASE WHEN night_action_qty < 0 THEN 1 ELSE 0 END) AS night_action_qty_neg
FROM dws.dws_opr_audit_action_di WHERE travel_date = '${bizdate}';

-- R1039 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_opr_audit_action_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_opr_approval_di  审批日汇总 质检 ====================
-- R1040 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_opr_approval_di WHERE travel_date = '${bizdate}';

-- R1041 [强][唯一性] 主键/粒度唯一（tenant_id + flow_code）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, flow_code, COUNT(*) AS c FROM dws.dws_opr_approval_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, flow_code HAVING COUNT(*) > 1
) x;

-- R1042 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_opr_approval_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR flow_code IS NULL);

-- R1043 [弱][有效性] 金额/数量非负（5 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN approval_qty < 0 THEN 1 ELSE 0 END) AS approval_qty_neg,
  SUM(CASE WHEN approval_pass_qty < 0 THEN 1 ELSE 0 END) AS approval_pass_qty_neg,
  SUM(CASE WHEN approval_reject_qty < 0 THEN 1 ELSE 0 END) AS approval_reject_qty_neg,
  SUM(CASE WHEN approval_minute_qty < 0 THEN 1 ELSE 0 END) AS approval_minute_qty_neg,
  SUM(CASE WHEN approval_timeout_qty < 0 THEN 1 ELSE 0 END) AS approval_timeout_qty_neg
FROM dws.dws_opr_approval_di WHERE travel_date = '${bizdate}';

-- R1044 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_opr_approval_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_opr_package_subscription_df  套餐订购存量快照 质检 ====================
-- R1045 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_opr_package_subscription_df WHERE travel_date = '${bizdate}';

-- R1046 [强][唯一性] 主键/粒度唯一（package_id + subscription_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT package_id, subscription_type, COUNT(*) AS c FROM dws.dws_opr_package_subscription_df WHERE travel_date = '${bizdate}' GROUP BY package_id, subscription_type HAVING COUNT(*) > 1
) x;

-- R1047 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_opr_package_subscription_df WHERE travel_date = '${bizdate}' AND (package_id IS NULL OR subscription_type IS NULL);

-- R1048 [弱][一致性] package_id 能关联到 dim_opr_package_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.package_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_opr_package_subscription_df f
LEFT JOIN dim.dim_opr_package_df d ON f.package_id = d.package_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.package_id IS NOT NULL AND CAST(f.package_id AS STRING) NOT IN ('0', '');

-- R1049 [弱][有效性] subscription_type 取值在枚举内；期望：无返回行
SELECT subscription_type, COUNT(*) AS cnt FROM dws.dws_opr_package_subscription_df WHERE travel_date = '${bizdate}' AND subscription_type IS NOT NULL
  AND subscription_type NOT IN ('NEW', 'RENEW', 'UPGRADE')
GROUP BY subscription_type;

-- R1050 [弱][有效性] 金额/数量非负（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN active_subscription_qty < 0 THEN 1 ELSE 0 END) AS active_subscription_qty_neg,
  SUM(CASE WHEN package_amt < 0 THEN 1 ELSE 0 END) AS package_amt_neg,
  SUM(CASE WHEN expiring_30d_subscription_qty < 0 THEN 1 ELSE 0 END) AS expiring_30d_subscription_qty_neg,
  SUM(CASE WHEN package_renew_qty < 0 THEN 1 ELSE 0 END) AS package_renew_qty_neg
FROM dws.dws_opr_package_subscription_df WHERE travel_date = '${bizdate}';

-- R1051 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_opr_package_subscription_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_cus_tenant_growth_di  商户×注册渠道 游客增长日汇总 质检 ====================
-- R1052 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_cus_tenant_growth_di WHERE travel_date = '${bizdate}';

-- R1053 [强][唯一性] 主键/粒度唯一（tenant_id + register_channel_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, register_channel_id, COUNT(*) AS c FROM dws.dws_cus_tenant_growth_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, register_channel_id HAVING COUNT(*) > 1
) x;

-- R1054 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_cus_tenant_growth_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR register_channel_id IS NULL);

-- R1055 [弱][一致性] register_channel_id 能关联到 dim_trf_channel_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.channel_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_cus_tenant_growth_di f
LEFT JOIN dim.dim_trf_channel_df d ON f.register_channel_id = d.channel_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.register_channel_id IS NOT NULL AND CAST(f.register_channel_id AS STRING) NOT IN ('0', '');

-- R1056 [弱][有效性] 金额/数量非负（8 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN new_customer_qty < 0 THEN 1 ELSE 0 END) AS new_customer_qty_neg,
  SUM(CASE WHEN certified_customer_qty < 0 THEN 1 ELSE 0 END) AS certified_customer_qty_neg,
  SUM(CASE WHEN face_register_qty < 0 THEN 1 ELSE 0 END) AS face_register_qty_neg,
  SUM(CASE WHEN first_pay_customer_qty < 0 THEN 1 ELSE 0 END) AS first_pay_customer_qty_neg,
  SUM(CASE WHEN register_pay_customer_qty < 0 THEN 1 ELSE 0 END) AS register_pay_customer_qty_neg,
  SUM(CASE WHEN repeat_buyer_qty < 0 THEN 1 ELSE 0 END) AS repeat_buyer_qty_neg,
  SUM(CASE WHEN pay_buyer_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_qty_neg,
  SUM(CASE WHEN identity_bind_qty < 0 THEN 1 ELSE 0 END) AS identity_bind_qty_neg
FROM dws.dws_cus_tenant_growth_di WHERE travel_date = '${bizdate}';

-- R1057 [弱][及时性/波动] pay_buyer_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_buyer_qty) AS v FROM dws.dws_cus_tenant_growth_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_sup_tenant_onboard_di  平台×地区×业态 商户入驻日汇总 质检 ====================
-- R1058 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_sup_tenant_onboard_di WHERE travel_date = '${bizdate}';

-- R1059 [强][唯一性] 主键/粒度唯一（country_code + region_id + business_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT country_code, region_id, business_type, COUNT(*) AS c FROM dws.dws_sup_tenant_onboard_di WHERE travel_date = '${bizdate}' GROUP BY country_code, region_id, business_type HAVING COUNT(*) > 1
) x;

-- R1060 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_sup_tenant_onboard_di WHERE travel_date = '${bizdate}' AND (country_code IS NULL OR region_id IS NULL OR business_type IS NULL);

-- R1061 [弱][有效性] business_type 取值在枚举内；期望：无返回行
SELECT business_type, COUNT(*) AS cnt FROM dws.dws_sup_tenant_onboard_di WHERE travel_date = '${bizdate}' AND business_type IS NOT NULL
  AND business_type NOT IN ('SCENIC', 'HOTEL', 'SHOW')
GROUP BY business_type;

-- R1062 [弱][有效性] 金额/数量非负（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN new_tenant_qty < 0 THEN 1 ELSE 0 END) AS new_tenant_qty_neg,
  SUM(CASE WHEN tenant_cert_apply_qty < 0 THEN 1 ELSE 0 END) AS tenant_cert_apply_qty_neg,
  SUM(CASE WHEN tenant_cert_pass_qty < 0 THEN 1 ELSE 0 END) AS tenant_cert_pass_qty_neg
FROM dws.dws_sup_tenant_onboard_di WHERE travel_date = '${bizdate}';

-- R1063 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_sup_tenant_onboard_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.dws_opr_code_pool_df  码池使用快照 质检 ====================
-- R1064 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dws.dws_opr_code_pool_df WHERE travel_date = '${bizdate}';

-- R1065 [强][唯一性] 主键/粒度唯一（tenant_id + code_pool_id + pool_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, code_pool_id, pool_type, COUNT(*) AS c FROM dws.dws_opr_code_pool_df WHERE travel_date = '${bizdate}' GROUP BY tenant_id, code_pool_id, pool_type HAVING COUNT(*) > 1
) x;

-- R1066 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dws.dws_opr_code_pool_df WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR code_pool_id IS NULL OR pool_type IS NULL);

-- R1067 [弱][一致性] code_pool_id 能关联到 dim_opr_code_pool_df；期望：miss_cnt / total_cnt ≤ 0.1%
SELECT SUM(CASE WHEN d.code_pool_id IS NULL THEN 1 ELSE 0 END) AS miss_cnt, COUNT(*) AS total_cnt
FROM dws.dws_opr_code_pool_df f
LEFT JOIN dim.dim_opr_code_pool_df d ON f.code_pool_id = d.code_pool_id AND d.travel_date = '${bizdate}'
WHERE f.travel_date = '${bizdate}' AND f.code_pool_id IS NOT NULL AND CAST(f.code_pool_id AS STRING) NOT IN ('0', '');

-- R1068 [弱][有效性] pool_type 取值在枚举内；期望：无返回行
SELECT pool_type, COUNT(*) AS cnt FROM dws.dws_opr_code_pool_df WHERE travel_date = '${bizdate}' AND pool_type IS NOT NULL
  AND pool_type NOT IN ('SINGLE_TICKET', 'COMBO_TICKET')
GROUP BY pool_type;

-- R1069 [弱][有效性] 金额/数量非负（5 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN code_capacity_qty < 0 THEN 1 ELSE 0 END) AS code_capacity_qty_neg,
  SUM(CASE WHEN code_allocated_qty < 0 THEN 1 ELSE 0 END) AS code_allocated_qty_neg,
  SUM(CASE WHEN code_recycled_qty < 0 THEN 1 ELSE 0 END) AS code_recycled_qty_neg,
  SUM(CASE WHEN issue_credential_qty < 0 THEN 1 ELSE 0 END) AS issue_credential_qty_neg,
  SUM(CASE WHEN revoke_credential_qty < 0 THEN 1 ELSE 0 END) AS revoke_credential_qty_neg
FROM dws.dws_opr_code_pool_df WHERE travel_date = '${bizdate}';

-- R1070 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM dws.dws_opr_code_pool_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.ads_ord_tenant_trade_overview_di  商户经营概览 质检 ====================
-- R1071 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}';

-- R1072 [强][唯一性] 主键/粒度唯一（seller_tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, COUNT(*) AS c FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id HAVING COUNT(*) > 1
) x;

-- R1073 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL);

-- R1074 [弱][有效性] 金额/数量非负（46 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_1d_amt < 0 THEN 1 ELSE 0 END) AS pay_1d_amt_neg,
  SUM(CASE WHEN pay_7d_amt < 0 THEN 1 ELSE 0 END) AS pay_7d_amt_neg,
  SUM(CASE WHEN pay_30d_amt < 0 THEN 1 ELSE 0 END) AS pay_30d_amt_neg,
  SUM(CASE WHEN pay_mtd_amt < 0 THEN 1 ELSE 0 END) AS pay_mtd_amt_neg,
  SUM(CASE WHEN pay_ytd_amt < 0 THEN 1 ELSE 0 END) AS pay_ytd_amt_neg,
  SUM(CASE WHEN pay_order_1d_qty < 0 THEN 1 ELSE 0 END) AS pay_order_1d_qty_neg,
  SUM(CASE WHEN pay_order_7d_qty < 0 THEN 1 ELSE 0 END) AS pay_order_7d_qty_neg,
  SUM(CASE WHEN pay_order_30d_qty < 0 THEN 1 ELSE 0 END) AS pay_order_30d_qty_neg,
  SUM(CASE WHEN pay_order_mtd_qty < 0 THEN 1 ELSE 0 END) AS pay_order_mtd_qty_neg,
  SUM(CASE WHEN pay_order_ytd_qty < 0 THEN 1 ELSE 0 END) AS pay_order_ytd_qty_neg,
  SUM(CASE WHEN pay_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_1d_qty_neg,
  SUM(CASE WHEN pay_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_7d_qty_neg,
  SUM(CASE WHEN pay_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_30d_qty_neg,
  SUM(CASE WHEN pay_ticket_mtd_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_mtd_qty_neg,
  SUM(CASE WHEN pay_ticket_ytd_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_ytd_qty_neg,
  SUM(CASE WHEN pay_buyer_1d_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_1d_qty_neg,
  SUM(CASE WHEN pay_buyer_7d_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_7d_qty_neg,
  SUM(CASE WHEN pay_buyer_30d_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_30d_qty_neg,
  SUM(CASE WHEN pay_buyer_mtd_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_mtd_qty_neg,
  SUM(CASE WHEN pay_buyer_ytd_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_ytd_qty_neg,
  SUM(CASE WHEN verify_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_1d_qty_neg,
  SUM(CASE WHEN verify_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_7d_qty_neg,
  SUM(CASE WHEN verify_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_30d_qty_neg,
  SUM(CASE WHEN verify_ticket_mtd_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_mtd_qty_neg,
  SUM(CASE WHEN verify_ticket_ytd_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_ytd_qty_neg,
  SUM(CASE WHEN verify_1d_amt < 0 THEN 1 ELSE 0 END) AS verify_1d_amt_neg,
  SUM(CASE WHEN verify_7d_amt < 0 THEN 1 ELSE 0 END) AS verify_7d_amt_neg,
  SUM(CASE WHEN verify_30d_amt < 0 THEN 1 ELSE 0 END) AS verify_30d_amt_neg,
  SUM(CASE WHEN verify_mtd_amt < 0 THEN 1 ELSE 0 END) AS verify_mtd_amt_neg,
  SUM(CASE WHEN verify_ytd_amt < 0 THEN 1 ELSE 0 END) AS verify_ytd_amt_neg,
  SUM(CASE WHEN refund_1d_amt < 0 THEN 1 ELSE 0 END) AS refund_1d_amt_neg,
  SUM(CASE WHEN refund_7d_amt < 0 THEN 1 ELSE 0 END) AS refund_7d_amt_neg,
  SUM(CASE WHEN refund_30d_amt < 0 THEN 1 ELSE 0 END) AS refund_30d_amt_neg,
  SUM(CASE WHEN refund_mtd_amt < 0 THEN 1 ELSE 0 END) AS refund_mtd_amt_neg,
  SUM(CASE WHEN refund_ytd_amt < 0 THEN 1 ELSE 0 END) AS refund_ytd_amt_neg,
  SUM(CASE WHEN cost_1d_amt < 0 THEN 1 ELSE 0 END) AS cost_1d_amt_neg,
  SUM(CASE WHEN cost_7d_amt < 0 THEN 1 ELSE 0 END) AS cost_7d_amt_neg,
  SUM(CASE WHEN cost_30d_amt < 0 THEN 1 ELSE 0 END) AS cost_30d_amt_neg,
  SUM(CASE WHEN cost_mtd_amt < 0 THEN 1 ELSE 0 END) AS cost_mtd_amt_neg,
  SUM(CASE WHEN cost_ytd_amt < 0 THEN 1 ELSE 0 END) AS cost_ytd_amt_neg
FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}';

-- R1075 [弱][有效性] 比率值域（9 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN verify_1d_rate < 0 THEN 1 ELSE 0 END) AS verify_1d_rate_bad,
  SUM(CASE WHEN verify_7d_rate < 0 THEN 1 ELSE 0 END) AS verify_7d_rate_bad,
  SUM(CASE WHEN verify_30d_rate < 0 THEN 1 ELSE 0 END) AS verify_30d_rate_bad,
  SUM(CASE WHEN refund_1d_rate < 0 THEN 1 ELSE 0 END) AS refund_1d_rate_bad,
  SUM(CASE WHEN refund_7d_rate < 0 THEN 1 ELSE 0 END) AS refund_7d_rate_bad,
  SUM(CASE WHEN refund_30d_rate < 0 THEN 1 ELSE 0 END) AS refund_30d_rate_bad,
  SUM(CASE WHEN pay_conversion_1d_rate < 0 THEN 1 ELSE 0 END) AS pay_conversion_1d_rate_bad,
  SUM(CASE WHEN pay_conversion_7d_rate < 0 THEN 1 ELSE 0 END) AS pay_conversion_7d_rate_bad,
  SUM(CASE WHEN pay_conversion_30d_rate < 0 THEN 1 ELSE 0 END) AS pay_conversion_30d_rate_bad
FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}';

-- R1076 [弱][及时性/波动] pay_1d_amt 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_1d_amt) AS v FROM ads.ads_ord_tenant_trade_overview_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1248 [强][一致性] 勾稽：net_pay_1d_amt = pay_1d_amt − refund_1d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND ABS(COALESCE(net_pay_1d_amt, 0) - (COALESCE(pay_1d_amt, 0) - COALESCE(refund_1d_amt, 0))) > 0.01;

-- R1249 [强][一致性] 勾稽：gross_profit_1d_amt = pay_1d_amt − cost_1d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND ABS(COALESCE(gross_profit_1d_amt, 0) - (COALESCE(pay_1d_amt, 0) - COALESCE(cost_1d_amt, 0))) > 0.01;

-- R1250 [弱][一致性] 勾稽：per_customer_1d_amt = pay_1d_amt × 100 / pay_buyer_1d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND pay_buyer_1d_qty <> 0
  AND ABS(per_customer_1d_amt - ROUND(pay_1d_amt * 100 / pay_buyer_1d_qty, 6)) > 0.000001;

-- R1251 [弱][一致性] 勾稽：avg_ticket_price_1d_amt = pay_1d_amt × 100 / pay_ticket_1d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND pay_ticket_1d_qty <> 0
  AND ABS(avg_ticket_price_1d_amt - ROUND(pay_1d_amt * 100 / pay_ticket_1d_qty, 6)) > 0.000001;

-- R1252 [弱][一致性] 勾稽：verify_1d_rate = verify_ticket_1d_qty × 100 / pay_ticket_1d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND pay_ticket_1d_qty <> 0
  AND ABS(verify_1d_rate - ROUND(verify_ticket_1d_qty * 100 / pay_ticket_1d_qty, 6)) > 0.000001;

-- R1253 [弱][一致性] 勾稽：gross_profit_1d_rate = gross_profit_1d_amt × 100 / pay_1d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND pay_1d_amt <> 0
  AND ABS(gross_profit_1d_rate - ROUND(gross_profit_1d_amt * 100 / pay_1d_amt, 6)) > 0.000001;

-- R1254 [强][一致性] 勾稽：net_pay_7d_amt = pay_7d_amt − refund_7d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND ABS(COALESCE(net_pay_7d_amt, 0) - (COALESCE(pay_7d_amt, 0) - COALESCE(refund_7d_amt, 0))) > 0.01;

-- R1255 [强][一致性] 勾稽：gross_profit_7d_amt = pay_7d_amt − cost_7d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND ABS(COALESCE(gross_profit_7d_amt, 0) - (COALESCE(pay_7d_amt, 0) - COALESCE(cost_7d_amt, 0))) > 0.01;

-- R1256 [弱][一致性] 勾稽：per_customer_7d_amt = pay_7d_amt × 100 / pay_buyer_7d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND pay_buyer_7d_qty <> 0
  AND ABS(per_customer_7d_amt - ROUND(pay_7d_amt * 100 / pay_buyer_7d_qty, 6)) > 0.000001;

-- R1257 [弱][一致性] 勾稽：avg_ticket_price_7d_amt = pay_7d_amt × 100 / pay_ticket_7d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND pay_ticket_7d_qty <> 0
  AND ABS(avg_ticket_price_7d_amt - ROUND(pay_7d_amt * 100 / pay_ticket_7d_qty, 6)) > 0.000001;

-- R1258 [弱][一致性] 勾稽：verify_7d_rate = verify_ticket_7d_qty × 100 / pay_ticket_7d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND pay_ticket_7d_qty <> 0
  AND ABS(verify_7d_rate - ROUND(verify_ticket_7d_qty * 100 / pay_ticket_7d_qty, 6)) > 0.000001;

-- R1259 [弱][一致性] 勾稽：gross_profit_7d_rate = gross_profit_7d_amt × 100 / pay_7d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}' AND pay_7d_amt <> 0
  AND ABS(gross_profit_7d_rate - ROUND(gross_profit_7d_amt * 100 / pay_7d_amt, 6)) > 0.000001;

-- R1299 [弱][一致性] 对账：pay_1d_amt 与 dws_sup_tenant_trade_di.pay_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(pay_1d_amt) FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(pay_amt) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1300 [弱][一致性] 对账：pay_order_1d_qty 与 dws_sup_tenant_trade_di.pay_order_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(pay_order_1d_qty) FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(pay_order_qty) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1301 [弱][一致性] 对账：pay_ticket_1d_qty 与 dws_sup_tenant_trade_di.pay_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(pay_ticket_1d_qty) FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(pay_ticket_qty) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1302 [弱][一致性] 对账：pay_buyer_1d_qty 与 dws_sup_tenant_trade_di.pay_buyer_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(pay_buyer_1d_qty) FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(pay_buyer_qty) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1303 [弱][一致性] 对账：verify_ticket_1d_qty 与 dws_sup_tenant_trade_di.verify_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(verify_ticket_1d_qty) FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(verify_ticket_qty) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1304 [弱][一致性] 对账：verify_1d_amt 与 dws_sup_tenant_trade_di.verify_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(verify_1d_amt) FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(verify_amt) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1305 [弱][一致性] 对账：refund_1d_amt 与 dws_sup_tenant_trade_di.refund_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(refund_1d_amt) FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(refund_amt) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1306 [弱][一致性] 对账：cost_1d_amt 与 dws_sup_tenant_trade_di.cost_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(cost_1d_amt) FROM ads.ads_ord_tenant_trade_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(cost_amt) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_ord_sku_sales_rank_di  SKU销售排行 质检 ====================
-- R1077 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}';

-- R1078 [强][唯一性] 主键/粒度唯一（seller_tenant_id + sku_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, sku_id, COUNT(*) AS c FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, sku_id HAVING COUNT(*) > 1
) x;

-- R1079 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR sku_id IS NULL);

-- R1080 [弱][有效性] 金额/数量非负（12 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_1d_amt < 0 THEN 1 ELSE 0 END) AS pay_1d_amt_neg,
  SUM(CASE WHEN pay_7d_amt < 0 THEN 1 ELSE 0 END) AS pay_7d_amt_neg,
  SUM(CASE WHEN pay_30d_amt < 0 THEN 1 ELSE 0 END) AS pay_30d_amt_neg,
  SUM(CASE WHEN pay_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_1d_qty_neg,
  SUM(CASE WHEN pay_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_7d_qty_neg,
  SUM(CASE WHEN pay_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_30d_qty_neg,
  SUM(CASE WHEN refund_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_1d_qty_neg,
  SUM(CASE WHEN refund_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_7d_qty_neg,
  SUM(CASE WHEN refund_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_30d_qty_neg,
  SUM(CASE WHEN avg_ticket_price_1d_amt < 0 THEN 1 ELSE 0 END) AS avg_ticket_price_1d_amt_neg,
  SUM(CASE WHEN avg_ticket_price_7d_amt < 0 THEN 1 ELSE 0 END) AS avg_ticket_price_7d_amt_neg,
  SUM(CASE WHEN avg_ticket_price_30d_amt < 0 THEN 1 ELSE 0 END) AS avg_ticket_price_30d_amt_neg
FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}';

-- R1081 [弱][有效性] 比率值域（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_conversion_1d_rate < 0 THEN 1 ELSE 0 END) AS pay_conversion_1d_rate_bad,
  SUM(CASE WHEN pay_conversion_7d_rate < 0 THEN 1 ELSE 0 END) AS pay_conversion_7d_rate_bad,
  SUM(CASE WHEN pay_conversion_30d_rate < 0 THEN 1 ELSE 0 END) AS pay_conversion_30d_rate_bad,
  SUM(CASE WHEN refund_1d_rate < 0 THEN 1 ELSE 0 END) AS refund_1d_rate_bad,
  SUM(CASE WHEN refund_7d_rate < 0 THEN 1 ELSE 0 END) AS refund_7d_rate_bad,
  SUM(CASE WHEN refund_30d_rate < 0 THEN 1 ELSE 0 END) AS refund_30d_rate_bad
FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}';

-- R1082 [弱][及时性/波动] pay_1d_amt 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_1d_amt) AS v FROM ads.ads_ord_sku_sales_rank_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1260 [弱][一致性] 勾稽：avg_ticket_price_1d_amt = pay_1d_amt × 100 / pay_ticket_1d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}' AND pay_ticket_1d_qty <> 0
  AND ABS(avg_ticket_price_1d_amt - ROUND(pay_1d_amt * 100 / pay_ticket_1d_qty, 6)) > 0.000001;

-- R1261 [弱][一致性] 勾稽：gross_profit_1d_rate = gross_profit_1d_amt × 100 / pay_1d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}' AND pay_1d_amt <> 0
  AND ABS(gross_profit_1d_rate - ROUND(gross_profit_1d_amt * 100 / pay_1d_amt, 6)) > 0.000001;

-- R1262 [弱][一致性] 勾稽：refund_1d_rate = refund_ticket_1d_qty × 100 / pay_ticket_1d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}' AND pay_ticket_1d_qty <> 0
  AND ABS(refund_1d_rate - ROUND(refund_ticket_1d_qty * 100 / pay_ticket_1d_qty, 6)) > 0.000001;

-- R1263 [弱][一致性] 勾稽：avg_ticket_price_7d_amt = pay_7d_amt × 100 / pay_ticket_7d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}' AND pay_ticket_7d_qty <> 0
  AND ABS(avg_ticket_price_7d_amt - ROUND(pay_7d_amt * 100 / pay_ticket_7d_qty, 6)) > 0.000001;

-- R1264 [弱][一致性] 勾稽：gross_profit_7d_rate = gross_profit_7d_amt × 100 / pay_7d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}' AND pay_7d_amt <> 0
  AND ABS(gross_profit_7d_rate - ROUND(gross_profit_7d_amt * 100 / pay_7d_amt, 6)) > 0.000001;

-- R1265 [弱][一致性] 勾稽：refund_7d_rate = refund_ticket_7d_qty × 100 / pay_ticket_7d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}' AND pay_ticket_7d_qty <> 0
  AND ABS(refund_7d_rate - ROUND(refund_ticket_7d_qty * 100 / pay_ticket_7d_qty, 6)) > 0.000001;

-- R1266 [弱][一致性] 勾稽：avg_ticket_price_30d_amt = pay_30d_amt × 100 / pay_ticket_30d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}' AND pay_ticket_30d_qty <> 0
  AND ABS(avg_ticket_price_30d_amt - ROUND(pay_30d_amt * 100 / pay_ticket_30d_qty, 6)) > 0.000001;

-- R1267 [弱][一致性] 勾稽：gross_profit_30d_rate = gross_profit_30d_amt × 100 / pay_30d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}' AND pay_30d_amt <> 0
  AND ABS(gross_profit_30d_rate - ROUND(gross_profit_30d_amt * 100 / pay_30d_amt, 6)) > 0.000001;

-- R1268 [弱][一致性] 勾稽：refund_30d_rate = refund_ticket_30d_qty × 100 / pay_ticket_30d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}' AND pay_ticket_30d_qty <> 0
  AND ABS(refund_30d_rate - ROUND(refund_ticket_30d_qty * 100 / pay_ticket_30d_qty, 6)) > 0.000001;

-- R1307 [弱][一致性] 对账：pay_1d_amt 与 dws_ord_tenant_sku_channel_trade_di.pay_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(pay_1d_amt) FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(pay_amt) FROM dws.dws_ord_tenant_sku_channel_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1308 [弱][一致性] 对账：pay_ticket_1d_qty 与 dws_ord_tenant_sku_channel_trade_di.pay_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(pay_ticket_1d_qty) FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(pay_ticket_qty) FROM dws.dws_ord_tenant_sku_channel_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1309 [弱][一致性] 对账：refund_ticket_1d_qty 与 dws_ord_tenant_refund_di.refund_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(refund_ticket_1d_qty) FROM ads.ads_ord_sku_sales_rank_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(refund_ticket_qty) FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_ord_channel_sales_structure_di  渠道销售结构 质检 ====================
-- R1083 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_ord_channel_sales_structure_di WHERE travel_date = '${bizdate}';

-- R1084 [强][唯一性] 主键/粒度唯一（seller_tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, COUNT(*) AS c FROM ads.ads_ord_channel_sales_structure_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id HAVING COUNT(*) > 1
) x;

-- R1085 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_ord_channel_sales_structure_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL);

-- R1086 [弱][有效性] 金额/数量非负（51 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN mp_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS mp_pay_1d_amt_neg,
  SUM(CASE WHEN mp_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS mp_pay_7d_amt_neg,
  SUM(CASE WHEN mp_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS mp_pay_30d_amt_neg,
  SUM(CASE WHEN h5_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS h5_pay_1d_amt_neg,
  SUM(CASE WHEN h5_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS h5_pay_7d_amt_neg,
  SUM(CASE WHEN h5_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS h5_pay_30d_amt_neg,
  SUM(CASE WHEN pc_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS pc_pay_1d_amt_neg,
  SUM(CASE WHEN pc_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS pc_pay_7d_amt_neg,
  SUM(CASE WHEN pc_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS pc_pay_30d_amt_neg,
  SUM(CASE WHEN offline_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS offline_pay_1d_amt_neg,
  SUM(CASE WHEN offline_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS offline_pay_7d_amt_neg,
  SUM(CASE WHEN offline_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS offline_pay_30d_amt_neg,
  SUM(CASE WHEN api_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS api_pay_1d_amt_neg,
  SUM(CASE WHEN api_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS api_pay_7d_amt_neg,
  SUM(CASE WHEN api_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS api_pay_30d_amt_neg,
  SUM(CASE WHEN mp_pay_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS mp_pay_ticket_1d_qty_neg,
  SUM(CASE WHEN mp_pay_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS mp_pay_ticket_7d_qty_neg,
  SUM(CASE WHEN mp_pay_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS mp_pay_ticket_30d_qty_neg,
  SUM(CASE WHEN h5_pay_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS h5_pay_ticket_1d_qty_neg,
  SUM(CASE WHEN h5_pay_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS h5_pay_ticket_7d_qty_neg,
  SUM(CASE WHEN h5_pay_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS h5_pay_ticket_30d_qty_neg,
  SUM(CASE WHEN pc_pay_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS pc_pay_ticket_1d_qty_neg,
  SUM(CASE WHEN pc_pay_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS pc_pay_ticket_7d_qty_neg,
  SUM(CASE WHEN pc_pay_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS pc_pay_ticket_30d_qty_neg,
  SUM(CASE WHEN offline_pay_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS offline_pay_ticket_1d_qty_neg,
  SUM(CASE WHEN offline_pay_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS offline_pay_ticket_7d_qty_neg,
  SUM(CASE WHEN offline_pay_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS offline_pay_ticket_30d_qty_neg,
  SUM(CASE WHEN api_pay_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS api_pay_ticket_1d_qty_neg,
  SUM(CASE WHEN api_pay_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS api_pay_ticket_7d_qty_neg,
  SUM(CASE WHEN api_pay_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS api_pay_ticket_30d_qty_neg,
  SUM(CASE WHEN mp_pay_order_1d_qty < 0 THEN 1 ELSE 0 END) AS mp_pay_order_1d_qty_neg,
  SUM(CASE WHEN mp_pay_order_7d_qty < 0 THEN 1 ELSE 0 END) AS mp_pay_order_7d_qty_neg,
  SUM(CASE WHEN mp_pay_order_30d_qty < 0 THEN 1 ELSE 0 END) AS mp_pay_order_30d_qty_neg,
  SUM(CASE WHEN h5_pay_order_1d_qty < 0 THEN 1 ELSE 0 END) AS h5_pay_order_1d_qty_neg,
  SUM(CASE WHEN h5_pay_order_7d_qty < 0 THEN 1 ELSE 0 END) AS h5_pay_order_7d_qty_neg,
  SUM(CASE WHEN h5_pay_order_30d_qty < 0 THEN 1 ELSE 0 END) AS h5_pay_order_30d_qty_neg,
  SUM(CASE WHEN pc_pay_order_1d_qty < 0 THEN 1 ELSE 0 END) AS pc_pay_order_1d_qty_neg,
  SUM(CASE WHEN pc_pay_order_7d_qty < 0 THEN 1 ELSE 0 END) AS pc_pay_order_7d_qty_neg,
  SUM(CASE WHEN pc_pay_order_30d_qty < 0 THEN 1 ELSE 0 END) AS pc_pay_order_30d_qty_neg,
  SUM(CASE WHEN offline_pay_order_1d_qty < 0 THEN 1 ELSE 0 END) AS offline_pay_order_1d_qty_neg
FROM ads.ads_ord_channel_sales_structure_di WHERE travel_date = '${bizdate}';

-- R1087 [弱][有效性] 比率值域（15 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN mp_channel_pay_share_1d_rate < 0 OR mp_channel_pay_share_1d_rate > 100 THEN 1 ELSE 0 END) AS mp_channel_pay_share_1d_rate_bad,
  SUM(CASE WHEN mp_channel_pay_share_7d_rate < 0 OR mp_channel_pay_share_7d_rate > 100 THEN 1 ELSE 0 END) AS mp_channel_pay_share_7d_rate_bad,
  SUM(CASE WHEN mp_channel_pay_share_30d_rate < 0 OR mp_channel_pay_share_30d_rate > 100 THEN 1 ELSE 0 END) AS mp_channel_pay_share_30d_rate_bad,
  SUM(CASE WHEN h5_channel_pay_share_1d_rate < 0 OR h5_channel_pay_share_1d_rate > 100 THEN 1 ELSE 0 END) AS h5_channel_pay_share_1d_rate_bad,
  SUM(CASE WHEN h5_channel_pay_share_7d_rate < 0 OR h5_channel_pay_share_7d_rate > 100 THEN 1 ELSE 0 END) AS h5_channel_pay_share_7d_rate_bad,
  SUM(CASE WHEN h5_channel_pay_share_30d_rate < 0 OR h5_channel_pay_share_30d_rate > 100 THEN 1 ELSE 0 END) AS h5_channel_pay_share_30d_rate_bad,
  SUM(CASE WHEN pc_channel_pay_share_1d_rate < 0 OR pc_channel_pay_share_1d_rate > 100 THEN 1 ELSE 0 END) AS pc_channel_pay_share_1d_rate_bad,
  SUM(CASE WHEN pc_channel_pay_share_7d_rate < 0 OR pc_channel_pay_share_7d_rate > 100 THEN 1 ELSE 0 END) AS pc_channel_pay_share_7d_rate_bad,
  SUM(CASE WHEN pc_channel_pay_share_30d_rate < 0 OR pc_channel_pay_share_30d_rate > 100 THEN 1 ELSE 0 END) AS pc_channel_pay_share_30d_rate_bad,
  SUM(CASE WHEN offline_channel_pay_share_1d_rate < 0 OR offline_channel_pay_share_1d_rate > 100 THEN 1 ELSE 0 END) AS offline_channel_pay_share_1d_rate_bad,
  SUM(CASE WHEN offline_channel_pay_share_7d_rate < 0 OR offline_channel_pay_share_7d_rate > 100 THEN 1 ELSE 0 END) AS offline_channel_pay_share_7d_rate_bad,
  SUM(CASE WHEN offline_channel_pay_share_30d_rate < 0 OR offline_channel_pay_share_30d_rate > 100 THEN 1 ELSE 0 END) AS offline_channel_pay_share_30d_rate_bad,
  SUM(CASE WHEN api_channel_pay_share_1d_rate < 0 OR api_channel_pay_share_1d_rate > 100 THEN 1 ELSE 0 END) AS api_channel_pay_share_1d_rate_bad,
  SUM(CASE WHEN api_channel_pay_share_7d_rate < 0 OR api_channel_pay_share_7d_rate > 100 THEN 1 ELSE 0 END) AS api_channel_pay_share_7d_rate_bad,
  SUM(CASE WHEN api_channel_pay_share_30d_rate < 0 OR api_channel_pay_share_30d_rate > 100 THEN 1 ELSE 0 END) AS api_channel_pay_share_30d_rate_bad
FROM ads.ads_ord_channel_sales_structure_di WHERE travel_date = '${bizdate}';

-- R1088 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_ord_channel_sales_structure_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1310 [弱][一致性] 对账：staff_order_1d_qty 与 dws_ord_tenant_sku_channel_trade_di.staff_order_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(staff_order_1d_qty) FROM ads.ads_ord_channel_sales_structure_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(staff_order_qty) FROM dws.dws_ord_tenant_sku_channel_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_ord_verify_flow_hrs  分时客流（入园人次） 质检 ====================
-- R1089 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_ord_verify_flow_hrs WHERE travel_date = '${bizdate}';

-- R1090 [强][唯一性] 主键/粒度唯一（stat_hour_no + seller_tenant_id + verify_point_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT stat_hour_no, seller_tenant_id, verify_point_id, COUNT(*) AS c FROM ads.ads_ord_verify_flow_hrs WHERE travel_date = '${bizdate}' GROUP BY stat_hour_no, seller_tenant_id, verify_point_id HAVING COUNT(*) > 1
) x;

-- R1091 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_ord_verify_flow_hrs WHERE travel_date = '${bizdate}' AND (stat_hour_no IS NULL OR seller_tenant_id IS NULL OR verify_point_id IS NULL);

-- R1092 [弱][有效性] 金额/数量非负（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN verify_person_1h_qty < 0 THEN 1 ELSE 0 END) AS verify_person_1h_qty_neg,
  SUM(CASE WHEN verify_fail_1h_qty < 0 THEN 1 ELSE 0 END) AS verify_fail_1h_qty_neg,
  SUM(CASE WHEN verify_person_1d_qty < 0 THEN 1 ELSE 0 END) AS verify_person_1d_qty_neg,
  SUM(CASE WHEN verify_person_7d_qty < 0 THEN 1 ELSE 0 END) AS verify_person_7d_qty_neg,
  SUM(CASE WHEN verify_person_30d_qty < 0 THEN 1 ELSE 0 END) AS verify_person_30d_qty_neg,
  SUM(CASE WHEN peak_hour_verify_qty < 0 THEN 1 ELSE 0 END) AS peak_hour_verify_qty_neg
FROM ads.ads_ord_verify_flow_hrs WHERE travel_date = '${bizdate}';

-- R1093 [弱][有效性] 比率值域（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN verify_fail_1h_rate < 0 THEN 1 ELSE 0 END) AS verify_fail_1h_rate_bad
FROM ads.ads_ord_verify_flow_hrs WHERE travel_date = '${bizdate}';

-- R1094 [弱][及时性/波动] verify_person_1h_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(verify_person_1h_qty) AS v FROM ads.ads_ord_verify_flow_hrs
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1311 [弱][一致性] 对账：verify_person_1d_qty 与 dws_ord_verify_point_flow_hrs.verify_person_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(verify_person_1d_qty) FROM ads.ads_ord_verify_flow_hrs WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(verify_person_qty) FROM dws.dws_ord_verify_point_flow_hrs WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_ord_play_date_booking_df  未来游玩日预订看板 质检 ====================
-- R1095 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_ord_play_date_booking_df WHERE travel_date = '${bizdate}';

-- R1096 [强][唯一性] 主键/粒度唯一（sku_id + play_date）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT sku_id, play_date, COUNT(*) AS c FROM ads.ads_ord_play_date_booking_df WHERE travel_date = '${bizdate}' GROUP BY sku_id, play_date HAVING COUNT(*) > 1
) x;

-- R1097 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_ord_play_date_booking_df WHERE travel_date = '${bizdate}' AND (sku_id IS NULL OR play_date IS NULL);

-- R1098 [弱][有效性] 金额/数量非负（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_ticket_td_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_td_qty_neg,
  SUM(CASE WHEN refund_ticket_td_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_td_qty_neg,
  SUM(CASE WHEN stock_available_td_qty < 0 THEN 1 ELSE 0 END) AS stock_available_td_qty_neg,
  SUM(CASE WHEN avg_advance_book_day_td_qty < 0 THEN 1 ELSE 0 END) AS avg_advance_book_day_td_qty_neg
FROM ads.ads_ord_play_date_booking_df WHERE travel_date = '${bizdate}';

-- R1099 [弱][有效性] 比率值域（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN stock_sell_through_td_rate < 0 OR stock_sell_through_td_rate > 100 THEN 1 ELSE 0 END) AS stock_sell_through_td_rate_bad
FROM ads.ads_ord_play_date_booking_df WHERE travel_date = '${bizdate}';

-- R1100 [弱][及时性/波动] pay_ticket_td_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_ticket_td_qty) AS v FROM ads.ads_ord_play_date_booking_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1269 [强][一致性] 勾稽：net_pay_ticket_td_qty = pay_ticket_td_qty − refund_ticket_td_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_play_date_booking_df WHERE travel_date = '${bizdate}' AND ABS(COALESCE(net_pay_ticket_td_qty, 0) - (COALESCE(pay_ticket_td_qty, 0) - COALESCE(refund_ticket_td_qty, 0))) > 0.01;

-- ==================== dq.ads_ord_refund_analysis_di  退款分析 质检 ====================
-- R1101 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}';

-- R1102 [强][唯一性] 主键/粒度唯一（seller_tenant_id + refund_reason_desc）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, refund_reason_desc, COUNT(*) AS c FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, refund_reason_desc HAVING COUNT(*) > 1
) x;

-- R1103 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR refund_reason_desc IS NULL);

-- R1104 [弱][有效性] 金额/数量非负（45 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN refund_apply_1d_qty < 0 THEN 1 ELSE 0 END) AS refund_apply_1d_qty_neg,
  SUM(CASE WHEN refund_apply_7d_qty < 0 THEN 1 ELSE 0 END) AS refund_apply_7d_qty_neg,
  SUM(CASE WHEN refund_apply_30d_qty < 0 THEN 1 ELSE 0 END) AS refund_apply_30d_qty_neg,
  SUM(CASE WHEN refund_success_1d_qty < 0 THEN 1 ELSE 0 END) AS refund_success_1d_qty_neg,
  SUM(CASE WHEN refund_success_7d_qty < 0 THEN 1 ELSE 0 END) AS refund_success_7d_qty_neg,
  SUM(CASE WHEN refund_success_30d_qty < 0 THEN 1 ELSE 0 END) AS refund_success_30d_qty_neg,
  SUM(CASE WHEN refund_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_1d_qty_neg,
  SUM(CASE WHEN refund_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_7d_qty_neg,
  SUM(CASE WHEN refund_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_30d_qty_neg,
  SUM(CASE WHEN refund_1d_amt < 0 THEN 1 ELSE 0 END) AS refund_1d_amt_neg,
  SUM(CASE WHEN refund_7d_amt < 0 THEN 1 ELSE 0 END) AS refund_7d_amt_neg,
  SUM(CASE WHEN refund_30d_amt < 0 THEN 1 ELSE 0 END) AS refund_30d_amt_neg,
  SUM(CASE WHEN refund_reject_1d_qty < 0 THEN 1 ELSE 0 END) AS refund_reject_1d_qty_neg,
  SUM(CASE WHEN refund_reject_7d_qty < 0 THEN 1 ELSE 0 END) AS refund_reject_7d_qty_neg,
  SUM(CASE WHEN refund_reject_30d_qty < 0 THEN 1 ELSE 0 END) AS refund_reject_30d_qty_neg,
  SUM(CASE WHEN auto_approve_refund_1d_qty < 0 THEN 1 ELSE 0 END) AS auto_approve_refund_1d_qty_neg,
  SUM(CASE WHEN auto_approve_refund_7d_qty < 0 THEN 1 ELSE 0 END) AS auto_approve_refund_7d_qty_neg,
  SUM(CASE WHEN auto_approve_refund_30d_qty < 0 THEN 1 ELSE 0 END) AS auto_approve_refund_30d_qty_neg,
  SUM(CASE WHEN verified_refund_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS verified_refund_ticket_1d_qty_neg,
  SUM(CASE WHEN verified_refund_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS verified_refund_ticket_7d_qty_neg,
  SUM(CASE WHEN verified_refund_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS verified_refund_ticket_30d_qty_neg,
  SUM(CASE WHEN visitor_refund_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS visitor_refund_ticket_1d_qty_neg,
  SUM(CASE WHEN visitor_refund_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS visitor_refund_ticket_7d_qty_neg,
  SUM(CASE WHEN visitor_refund_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS visitor_refund_ticket_30d_qty_neg,
  SUM(CASE WHEN merchant_refund_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS merchant_refund_ticket_1d_qty_neg,
  SUM(CASE WHEN merchant_refund_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS merchant_refund_ticket_7d_qty_neg,
  SUM(CASE WHEN merchant_refund_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS merchant_refund_ticket_30d_qty_neg,
  SUM(CASE WHEN ota_refund_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS ota_refund_ticket_1d_qty_neg,
  SUM(CASE WHEN ota_refund_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS ota_refund_ticket_7d_qty_neg,
  SUM(CASE WHEN ota_refund_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS ota_refund_ticket_30d_qty_neg,
  SUM(CASE WHEN system_refund_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS system_refund_ticket_1d_qty_neg,
  SUM(CASE WHEN system_refund_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS system_refund_ticket_7d_qty_neg,
  SUM(CASE WHEN system_refund_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS system_refund_ticket_30d_qty_neg,
  SUM(CASE WHEN visitor_refund_1d_amt < 0 THEN 1 ELSE 0 END) AS visitor_refund_1d_amt_neg,
  SUM(CASE WHEN visitor_refund_7d_amt < 0 THEN 1 ELSE 0 END) AS visitor_refund_7d_amt_neg,
  SUM(CASE WHEN visitor_refund_30d_amt < 0 THEN 1 ELSE 0 END) AS visitor_refund_30d_amt_neg,
  SUM(CASE WHEN merchant_refund_1d_amt < 0 THEN 1 ELSE 0 END) AS merchant_refund_1d_amt_neg,
  SUM(CASE WHEN merchant_refund_7d_amt < 0 THEN 1 ELSE 0 END) AS merchant_refund_7d_amt_neg,
  SUM(CASE WHEN merchant_refund_30d_amt < 0 THEN 1 ELSE 0 END) AS merchant_refund_30d_amt_neg,
  SUM(CASE WHEN ota_refund_1d_amt < 0 THEN 1 ELSE 0 END) AS ota_refund_1d_amt_neg
FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}';

-- R1105 [弱][有效性] 比率值域（12 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN refund_1d_rate < 0 THEN 1 ELSE 0 END) AS refund_1d_rate_bad,
  SUM(CASE WHEN refund_7d_rate < 0 THEN 1 ELSE 0 END) AS refund_7d_rate_bad,
  SUM(CASE WHEN refund_30d_rate < 0 THEN 1 ELSE 0 END) AS refund_30d_rate_bad,
  SUM(CASE WHEN refund_amt_1d_rate < 0 THEN 1 ELSE 0 END) AS refund_amt_1d_rate_bad,
  SUM(CASE WHEN refund_amt_7d_rate < 0 THEN 1 ELSE 0 END) AS refund_amt_7d_rate_bad,
  SUM(CASE WHEN refund_amt_30d_rate < 0 THEN 1 ELSE 0 END) AS refund_amt_30d_rate_bad,
  SUM(CASE WHEN cancel_1d_rate < 0 THEN 1 ELSE 0 END) AS cancel_1d_rate_bad,
  SUM(CASE WHEN cancel_7d_rate < 0 THEN 1 ELSE 0 END) AS cancel_7d_rate_bad,
  SUM(CASE WHEN cancel_30d_rate < 0 THEN 1 ELSE 0 END) AS cancel_30d_rate_bad,
  SUM(CASE WHEN timeout_cancel_1d_rate < 0 THEN 1 ELSE 0 END) AS timeout_cancel_1d_rate_bad,
  SUM(CASE WHEN timeout_cancel_7d_rate < 0 THEN 1 ELSE 0 END) AS timeout_cancel_7d_rate_bad,
  SUM(CASE WHEN timeout_cancel_30d_rate < 0 THEN 1 ELSE 0 END) AS timeout_cancel_30d_rate_bad
FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}';

-- R1106 [弱][及时性/波动] refund_apply_1d_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(refund_apply_1d_qty) AS v FROM ads.ads_ord_refund_analysis_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1312 [弱][一致性] 对账：refund_apply_1d_qty 与 dws_ord_tenant_refund_di.refund_apply_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(refund_apply_1d_qty) FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(refund_apply_qty) FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1313 [弱][一致性] 对账：refund_success_1d_qty 与 dws_ord_tenant_refund_di.refund_success_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(refund_success_1d_qty) FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(refund_success_qty) FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1314 [弱][一致性] 对账：refund_ticket_1d_qty 与 dws_ord_tenant_refund_di.refund_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(refund_ticket_1d_qty) FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(refund_ticket_qty) FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1315 [弱][一致性] 对账：refund_1d_amt 与 dws_ord_tenant_refund_di.refund_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(refund_1d_amt) FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(refund_amt) FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1316 [弱][一致性] 对账：refund_reject_1d_qty 与 dws_ord_tenant_refund_di.refund_reject_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(refund_reject_1d_qty) FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(refund_reject_qty) FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1317 [弱][一致性] 对账：auto_approve_refund_1d_qty 与 dws_ord_tenant_refund_di.auto_approve_refund_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(auto_approve_refund_1d_qty) FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(auto_approve_refund_qty) FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1318 [弱][一致性] 对账：verified_refund_ticket_1d_qty 与 dws_ord_tenant_refund_di.verified_refund_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(verified_refund_ticket_1d_qty) FROM ads.ads_ord_refund_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(verified_refund_ticket_qty) FROM dws.dws_ord_tenant_refund_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_ord_entitlement_usage_di  权益使用分析（年卡/次卡/计时/额度） 质检 ====================
-- R1107 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_ord_entitlement_usage_di WHERE travel_date = '${bizdate}';

-- R1108 [强][唯一性] 主键/粒度唯一（seller_tenant_id + sku_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, sku_id, COUNT(*) AS c FROM ads.ads_ord_entitlement_usage_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, sku_id HAVING COUNT(*) > 1
) x;

-- R1109 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_ord_entitlement_usage_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR sku_id IS NULL);

-- R1110 [弱][有效性] 金额/数量非负（31 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN fixed_entitlement_used_1d_qty < 0 THEN 1 ELSE 0 END) AS fixed_entitlement_used_1d_qty_neg,
  SUM(CASE WHEN fixed_entitlement_used_7d_qty < 0 THEN 1 ELSE 0 END) AS fixed_entitlement_used_7d_qty_neg,
  SUM(CASE WHEN fixed_entitlement_used_30d_qty < 0 THEN 1 ELSE 0 END) AS fixed_entitlement_used_30d_qty_neg,
  SUM(CASE WHEN selectable_entitlement_used_1d_qty < 0 THEN 1 ELSE 0 END) AS selectable_entitlement_used_1d_qty_neg,
  SUM(CASE WHEN selectable_entitlement_used_7d_qty < 0 THEN 1 ELSE 0 END) AS selectable_entitlement_used_7d_qty_neg,
  SUM(CASE WHEN selectable_entitlement_used_30d_qty < 0 THEN 1 ELSE 0 END) AS selectable_entitlement_used_30d_qty_neg,
  SUM(CASE WHEN counted_entitlement_used_1d_qty < 0 THEN 1 ELSE 0 END) AS counted_entitlement_used_1d_qty_neg,
  SUM(CASE WHEN counted_entitlement_used_7d_qty < 0 THEN 1 ELSE 0 END) AS counted_entitlement_used_7d_qty_neg,
  SUM(CASE WHEN counted_entitlement_used_30d_qty < 0 THEN 1 ELSE 0 END) AS counted_entitlement_used_30d_qty_neg,
  SUM(CASE WHEN timed_entitlement_used_1d_qty < 0 THEN 1 ELSE 0 END) AS timed_entitlement_used_1d_qty_neg,
  SUM(CASE WHEN timed_entitlement_used_7d_qty < 0 THEN 1 ELSE 0 END) AS timed_entitlement_used_7d_qty_neg,
  SUM(CASE WHEN timed_entitlement_used_30d_qty < 0 THEN 1 ELSE 0 END) AS timed_entitlement_used_30d_qty_neg,
  SUM(CASE WHEN unlimited_entitlement_used_1d_qty < 0 THEN 1 ELSE 0 END) AS unlimited_entitlement_used_1d_qty_neg,
  SUM(CASE WHEN unlimited_entitlement_used_7d_qty < 0 THEN 1 ELSE 0 END) AS unlimited_entitlement_used_7d_qty_neg,
  SUM(CASE WHEN unlimited_entitlement_used_30d_qty < 0 THEN 1 ELSE 0 END) AS unlimited_entitlement_used_30d_qty_neg,
  SUM(CASE WHEN quota_entitlement_used_1d_qty < 0 THEN 1 ELSE 0 END) AS quota_entitlement_used_1d_qty_neg,
  SUM(CASE WHEN quota_entitlement_used_7d_qty < 0 THEN 1 ELSE 0 END) AS quota_entitlement_used_7d_qty_neg,
  SUM(CASE WHEN quota_entitlement_used_30d_qty < 0 THEN 1 ELSE 0 END) AS quota_entitlement_used_30d_qty_neg,
  SUM(CASE WHEN activate_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS activate_ticket_1d_qty_neg,
  SUM(CASE WHEN activate_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS activate_ticket_7d_qty_neg,
  SUM(CASE WHEN activate_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS activate_ticket_30d_qty_neg,
  SUM(CASE WHEN avg_activate_delay_day_1d_qty < 0 THEN 1 ELSE 0 END) AS avg_activate_delay_day_1d_qty_neg,
  SUM(CASE WHEN avg_activate_delay_day_7d_qty < 0 THEN 1 ELSE 0 END) AS avg_activate_delay_day_7d_qty_neg,
  SUM(CASE WHEN avg_activate_delay_day_30d_qty < 0 THEN 1 ELSE 0 END) AS avg_activate_delay_day_30d_qty_neg,
  SUM(CASE WHEN expire_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS expire_ticket_1d_qty_neg,
  SUM(CASE WHEN expire_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS expire_ticket_7d_qty_neg,
  SUM(CASE WHEN expire_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS expire_ticket_30d_qty_neg,
  SUM(CASE WHEN unverified_ticket_td_qty < 0 THEN 1 ELSE 0 END) AS unverified_ticket_td_qty_neg,
  SUM(CASE WHEN unverified_td_amt < 0 THEN 1 ELSE 0 END) AS unverified_td_amt_neg,
  SUM(CASE WHEN pending_activate_ticket_td_qty < 0 THEN 1 ELSE 0 END) AS pending_activate_ticket_td_qty_neg,
  SUM(CASE WHEN quota_total_td_amt < 0 THEN 1 ELSE 0 END) AS quota_total_td_amt_neg
FROM ads.ads_ord_entitlement_usage_di WHERE travel_date = '${bizdate}';

-- R1111 [弱][有效性] 比率值域（24 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN fixed_entitlement_usage_1d_rate < 0 THEN 1 ELSE 0 END) AS fixed_entitlement_usage_1d_rate_bad,
  SUM(CASE WHEN fixed_entitlement_usage_7d_rate < 0 THEN 1 ELSE 0 END) AS fixed_entitlement_usage_7d_rate_bad,
  SUM(CASE WHEN fixed_entitlement_usage_30d_rate < 0 THEN 1 ELSE 0 END) AS fixed_entitlement_usage_30d_rate_bad,
  SUM(CASE WHEN selectable_entitlement_usage_1d_rate < 0 THEN 1 ELSE 0 END) AS selectable_entitlement_usage_1d_rate_bad,
  SUM(CASE WHEN selectable_entitlement_usage_7d_rate < 0 THEN 1 ELSE 0 END) AS selectable_entitlement_usage_7d_rate_bad,
  SUM(CASE WHEN selectable_entitlement_usage_30d_rate < 0 THEN 1 ELSE 0 END) AS selectable_entitlement_usage_30d_rate_bad,
  SUM(CASE WHEN counted_entitlement_usage_1d_rate < 0 THEN 1 ELSE 0 END) AS counted_entitlement_usage_1d_rate_bad,
  SUM(CASE WHEN counted_entitlement_usage_7d_rate < 0 THEN 1 ELSE 0 END) AS counted_entitlement_usage_7d_rate_bad,
  SUM(CASE WHEN counted_entitlement_usage_30d_rate < 0 THEN 1 ELSE 0 END) AS counted_entitlement_usage_30d_rate_bad,
  SUM(CASE WHEN timed_entitlement_usage_1d_rate < 0 THEN 1 ELSE 0 END) AS timed_entitlement_usage_1d_rate_bad,
  SUM(CASE WHEN timed_entitlement_usage_7d_rate < 0 THEN 1 ELSE 0 END) AS timed_entitlement_usage_7d_rate_bad,
  SUM(CASE WHEN timed_entitlement_usage_30d_rate < 0 THEN 1 ELSE 0 END) AS timed_entitlement_usage_30d_rate_bad,
  SUM(CASE WHEN unlimited_entitlement_usage_1d_rate < 0 THEN 1 ELSE 0 END) AS unlimited_entitlement_usage_1d_rate_bad,
  SUM(CASE WHEN unlimited_entitlement_usage_7d_rate < 0 THEN 1 ELSE 0 END) AS unlimited_entitlement_usage_7d_rate_bad,
  SUM(CASE WHEN unlimited_entitlement_usage_30d_rate < 0 THEN 1 ELSE 0 END) AS unlimited_entitlement_usage_30d_rate_bad,
  SUM(CASE WHEN quota_entitlement_usage_1d_rate < 0 THEN 1 ELSE 0 END) AS quota_entitlement_usage_1d_rate_bad,
  SUM(CASE WHEN quota_entitlement_usage_7d_rate < 0 THEN 1 ELSE 0 END) AS quota_entitlement_usage_7d_rate_bad,
  SUM(CASE WHEN quota_entitlement_usage_30d_rate < 0 THEN 1 ELSE 0 END) AS quota_entitlement_usage_30d_rate_bad,
  SUM(CASE WHEN activate_1d_rate < 0 THEN 1 ELSE 0 END) AS activate_1d_rate_bad,
  SUM(CASE WHEN activate_7d_rate < 0 THEN 1 ELSE 0 END) AS activate_7d_rate_bad,
  SUM(CASE WHEN activate_30d_rate < 0 THEN 1 ELSE 0 END) AS activate_30d_rate_bad,
  SUM(CASE WHEN expire_1d_rate < 0 THEN 1 ELSE 0 END) AS expire_1d_rate_bad,
  SUM(CASE WHEN expire_7d_rate < 0 THEN 1 ELSE 0 END) AS expire_7d_rate_bad,
  SUM(CASE WHEN expire_30d_rate < 0 THEN 1 ELSE 0 END) AS expire_30d_rate_bad
FROM ads.ads_ord_entitlement_usage_di WHERE travel_date = '${bizdate}';

-- R1112 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_ord_entitlement_usage_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1319 [弱][一致性] 对账：activate_ticket_1d_qty 与 dws_ord_tenant_entitlement_di.activate_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(activate_ticket_1d_qty) FROM ads.ads_ord_entitlement_usage_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(activate_ticket_qty) FROM dws.dws_ord_tenant_entitlement_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_ord_combo_analysis_di  套票分析（主子单/跨商户/部分退） 质检 ====================
-- R1113 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}';

-- R1114 [强][唯一性] 主键/粒度唯一（combo_sku_id + sub_sku_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT combo_sku_id, sub_sku_id, COUNT(*) AS c FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}' GROUP BY combo_sku_id, sub_sku_id HAVING COUNT(*) > 1
) x;

-- R1115 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}' AND (combo_sku_id IS NULL OR sub_sku_id IS NULL);

-- R1116 [弱][有效性] 金额/数量非负（18 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN combo_order_1d_qty < 0 THEN 1 ELSE 0 END) AS combo_order_1d_qty_neg,
  SUM(CASE WHEN combo_order_7d_qty < 0 THEN 1 ELSE 0 END) AS combo_order_7d_qty_neg,
  SUM(CASE WHEN combo_order_30d_qty < 0 THEN 1 ELSE 0 END) AS combo_order_30d_qty_neg,
  SUM(CASE WHEN pay_1d_amt < 0 THEN 1 ELSE 0 END) AS pay_1d_amt_neg,
  SUM(CASE WHEN pay_7d_amt < 0 THEN 1 ELSE 0 END) AS pay_7d_amt_neg,
  SUM(CASE WHEN pay_30d_amt < 0 THEN 1 ELSE 0 END) AS pay_30d_amt_neg,
  SUM(CASE WHEN pay_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_1d_qty_neg,
  SUM(CASE WHEN pay_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_7d_qty_neg,
  SUM(CASE WHEN pay_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS pay_ticket_30d_qty_neg,
  SUM(CASE WHEN verify_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_1d_qty_neg,
  SUM(CASE WHEN verify_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_7d_qty_neg,
  SUM(CASE WHEN verify_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_30d_qty_neg,
  SUM(CASE WHEN refund_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_1d_qty_neg,
  SUM(CASE WHEN refund_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_7d_qty_neg,
  SUM(CASE WHEN refund_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS refund_ticket_30d_qty_neg,
  SUM(CASE WHEN refund_1d_amt < 0 THEN 1 ELSE 0 END) AS refund_1d_amt_neg,
  SUM(CASE WHEN refund_7d_amt < 0 THEN 1 ELSE 0 END) AS refund_7d_amt_neg,
  SUM(CASE WHEN refund_30d_amt < 0 THEN 1 ELSE 0 END) AS refund_30d_amt_neg
FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}';

-- R1117 [弱][有效性] 比率值域（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN combo_refund_1d_rate < 0 THEN 1 ELSE 0 END) AS combo_refund_1d_rate_bad,
  SUM(CASE WHEN combo_refund_7d_rate < 0 THEN 1 ELSE 0 END) AS combo_refund_7d_rate_bad,
  SUM(CASE WHEN combo_refund_30d_rate < 0 THEN 1 ELSE 0 END) AS combo_refund_30d_rate_bad
FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}';

-- R1118 [弱][及时性/波动] pay_1d_amt 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_1d_amt) AS v FROM ads.ads_ord_combo_analysis_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1270 [弱][一致性] 勾稽：combo_refund_1d_rate = refund_ticket_1d_qty × 100 / pay_ticket_1d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}' AND pay_ticket_1d_qty <> 0
  AND ABS(combo_refund_1d_rate - ROUND(refund_ticket_1d_qty * 100 / pay_ticket_1d_qty, 6)) > 0.000001;

-- R1271 [弱][一致性] 勾稽：combo_refund_7d_rate = refund_ticket_7d_qty × 100 / pay_ticket_7d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}' AND pay_ticket_7d_qty <> 0
  AND ABS(combo_refund_7d_rate - ROUND(refund_ticket_7d_qty * 100 / pay_ticket_7d_qty, 6)) > 0.000001;

-- R1272 [弱][一致性] 勾稽：combo_refund_30d_rate = refund_ticket_30d_qty × 100 / pay_ticket_30d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}' AND pay_ticket_30d_qty <> 0
  AND ABS(combo_refund_30d_rate - ROUND(refund_ticket_30d_qty * 100 / pay_ticket_30d_qty, 6)) > 0.000001;

-- R1320 [弱][一致性] 对账：combo_order_1d_qty 与 dws_ord_combo_sku_trade_di.combo_order_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(combo_order_1d_qty) FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(combo_order_qty) FROM dws.dws_ord_combo_sku_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1321 [弱][一致性] 对账：pay_1d_amt 与 dws_ord_combo_sku_trade_di.pay_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(pay_1d_amt) FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(pay_amt) FROM dws.dws_ord_combo_sku_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1322 [弱][一致性] 对账：pay_ticket_1d_qty 与 dws_ord_combo_sku_trade_di.pay_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(pay_ticket_1d_qty) FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(pay_ticket_qty) FROM dws.dws_ord_combo_sku_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1323 [弱][一致性] 对账：verify_ticket_1d_qty 与 dws_ord_combo_sku_trade_di.verify_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(verify_ticket_1d_qty) FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(verify_ticket_qty) FROM dws.dws_ord_combo_sku_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1324 [弱][一致性] 对账：refund_ticket_1d_qty 与 dws_ord_combo_sku_trade_di.refund_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(refund_ticket_1d_qty) FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(refund_ticket_qty) FROM dws.dws_ord_combo_sku_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1325 [弱][一致性] 对账：refund_1d_amt 与 dws_ord_combo_sku_trade_di.refund_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(refund_1d_amt) FROM ads.ads_ord_combo_analysis_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(refund_amt) FROM dws.dws_ord_combo_sku_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_ord_trade_efficiency_di  交易时效分析 质检 ====================
-- R1119 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_ord_trade_efficiency_di WHERE travel_date = '${bizdate}';

-- R1120 [强][唯一性] 主键/粒度唯一（seller_tenant_id + sku_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, sku_id, COUNT(*) AS c FROM ads.ads_ord_trade_efficiency_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, sku_id HAVING COUNT(*) > 1
) x;

-- R1121 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_ord_trade_efficiency_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR sku_id IS NULL);

-- R1122 [弱][有效性] 金额/数量非负（12 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN avg_pay_minute_1d_qty < 0 THEN 1 ELSE 0 END) AS avg_pay_minute_1d_qty_neg,
  SUM(CASE WHEN avg_pay_minute_7d_qty < 0 THEN 1 ELSE 0 END) AS avg_pay_minute_7d_qty_neg,
  SUM(CASE WHEN avg_pay_minute_30d_qty < 0 THEN 1 ELSE 0 END) AS avg_pay_minute_30d_qty_neg,
  SUM(CASE WHEN avg_refund_process_hour_1d_qty < 0 THEN 1 ELSE 0 END) AS avg_refund_process_hour_1d_qty_neg,
  SUM(CASE WHEN avg_refund_process_hour_7d_qty < 0 THEN 1 ELSE 0 END) AS avg_refund_process_hour_7d_qty_neg,
  SUM(CASE WHEN avg_refund_process_hour_30d_qty < 0 THEN 1 ELSE 0 END) AS avg_refund_process_hour_30d_qty_neg,
  SUM(CASE WHEN avg_advance_book_day_1d_qty < 0 THEN 1 ELSE 0 END) AS avg_advance_book_day_1d_qty_neg,
  SUM(CASE WHEN avg_advance_book_day_7d_qty < 0 THEN 1 ELSE 0 END) AS avg_advance_book_day_7d_qty_neg,
  SUM(CASE WHEN avg_advance_book_day_30d_qty < 0 THEN 1 ELSE 0 END) AS avg_advance_book_day_30d_qty_neg,
  SUM(CASE WHEN timeout_cancel_order_1d_qty < 0 THEN 1 ELSE 0 END) AS timeout_cancel_order_1d_qty_neg,
  SUM(CASE WHEN timeout_cancel_order_7d_qty < 0 THEN 1 ELSE 0 END) AS timeout_cancel_order_7d_qty_neg,
  SUM(CASE WHEN timeout_cancel_order_30d_qty < 0 THEN 1 ELSE 0 END) AS timeout_cancel_order_30d_qty_neg
FROM ads.ads_ord_trade_efficiency_di WHERE travel_date = '${bizdate}';

-- R1123 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_ord_trade_efficiency_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1326 [弱][一致性] 对账：timeout_cancel_order_1d_qty 与 dws_ord_tenant_sku_channel_trade_di.timeout_cancel_order_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(timeout_cancel_order_1d_qty) FROM ads.ads_ord_trade_efficiency_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(timeout_cancel_order_qty) FROM dws.dws_ord_tenant_sku_channel_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_cus_tourist_portrait_di  游客客源画像 质检 ====================
-- R1124 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_cus_tourist_portrait_di WHERE travel_date = '${bizdate}';

-- R1125 [强][唯一性] 主键/粒度唯一（seller_tenant_id + origin_province_code + age_band_code + gender_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, origin_province_code, age_band_code, gender_type, COUNT(*) AS c FROM ads.ads_cus_tourist_portrait_di WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, origin_province_code, age_band_code, gender_type HAVING COUNT(*) > 1
) x;

-- R1126 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_cus_tourist_portrait_di WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR origin_province_code IS NULL OR age_band_code IS NULL OR gender_type IS NULL);

-- R1127 [弱][有效性] 金额/数量非负（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN tourist_1d_qty < 0 THEN 1 ELSE 0 END) AS tourist_1d_qty_neg,
  SUM(CASE WHEN tourist_7d_qty < 0 THEN 1 ELSE 0 END) AS tourist_7d_qty_neg,
  SUM(CASE WHEN tourist_30d_qty < 0 THEN 1 ELSE 0 END) AS tourist_30d_qty_neg,
  SUM(CASE WHEN verify_person_1d_qty < 0 THEN 1 ELSE 0 END) AS verify_person_1d_qty_neg,
  SUM(CASE WHEN verify_person_7d_qty < 0 THEN 1 ELSE 0 END) AS verify_person_7d_qty_neg,
  SUM(CASE WHEN verify_person_30d_qty < 0 THEN 1 ELSE 0 END) AS verify_person_30d_qty_neg
FROM ads.ads_cus_tourist_portrait_di WHERE travel_date = '${bizdate}';

-- R1128 [弱][有效性] 比率值域（9 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN tourist_origin_share_1d_rate < 0 OR tourist_origin_share_1d_rate > 100 THEN 1 ELSE 0 END) AS tourist_origin_share_1d_rate_bad,
  SUM(CASE WHEN tourist_origin_share_7d_rate < 0 OR tourist_origin_share_7d_rate > 100 THEN 1 ELSE 0 END) AS tourist_origin_share_7d_rate_bad,
  SUM(CASE WHEN tourist_origin_share_30d_rate < 0 OR tourist_origin_share_30d_rate > 100 THEN 1 ELSE 0 END) AS tourist_origin_share_30d_rate_bad,
  SUM(CASE WHEN realname_1d_rate < 0 OR realname_1d_rate > 100 THEN 1 ELSE 0 END) AS realname_1d_rate_bad,
  SUM(CASE WHEN realname_7d_rate < 0 OR realname_7d_rate > 100 THEN 1 ELSE 0 END) AS realname_7d_rate_bad,
  SUM(CASE WHEN realname_30d_rate < 0 OR realname_30d_rate > 100 THEN 1 ELSE 0 END) AS realname_30d_rate_bad,
  SUM(CASE WHEN person_link_1d_rate < 0 OR person_link_1d_rate > 100 THEN 1 ELSE 0 END) AS person_link_1d_rate_bad,
  SUM(CASE WHEN person_link_7d_rate < 0 OR person_link_7d_rate > 100 THEN 1 ELSE 0 END) AS person_link_7d_rate_bad,
  SUM(CASE WHEN person_link_30d_rate < 0 OR person_link_30d_rate > 100 THEN 1 ELSE 0 END) AS person_link_30d_rate_bad
FROM ads.ads_cus_tourist_portrait_di WHERE travel_date = '${bizdate}';

-- R1129 [弱][及时性/波动] verify_person_1d_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(verify_person_1d_qty) AS v FROM ads.ads_cus_tourist_portrait_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1327 [弱][一致性] 对账：tourist_1d_qty 与 dws_cus_tourist_origin_di.tourist_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(tourist_1d_qty) FROM ads.ads_cus_tourist_portrait_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(tourist_qty) FROM dws.dws_cus_tourist_origin_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1328 [弱][一致性] 对账：verify_person_1d_qty 与 dws_cus_tourist_origin_di.verify_person_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(verify_person_1d_qty) FROM ads.ads_cus_tourist_portrait_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(verify_person_qty) FROM dws.dws_cus_tourist_origin_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_cus_customer_rfm_df  会员RFM与复购 质检 ====================
-- R1130 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_cus_customer_rfm_df WHERE travel_date = '${bizdate}';

-- R1131 [强][唯一性] 主键/粒度唯一（seller_tenant_id + rfm_segment_code）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT seller_tenant_id, rfm_segment_code, COUNT(*) AS c FROM ads.ads_cus_customer_rfm_df WHERE travel_date = '${bizdate}' GROUP BY seller_tenant_id, rfm_segment_code HAVING COUNT(*) > 1
) x;

-- R1132 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_cus_customer_rfm_df WHERE travel_date = '${bizdate}' AND (seller_tenant_id IS NULL OR rfm_segment_code IS NULL);

-- R1133 [弱][有效性] 金额/数量非负（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_buyer_30d_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_30d_qty_neg,
  SUM(CASE WHEN repeat_buyer_30d_qty < 0 THEN 1 ELSE 0 END) AS repeat_buyer_30d_qty_neg,
  SUM(CASE WHEN per_customer_30d_amt < 0 THEN 1 ELSE 0 END) AS per_customer_30d_amt_neg,
  SUM(CASE WHEN pay_buyer_90d_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_90d_qty_neg,
  SUM(CASE WHEN repeat_buyer_90d_qty < 0 THEN 1 ELSE 0 END) AS repeat_buyer_90d_qty_neg,
  SUM(CASE WHEN per_customer_90d_amt < 0 THEN 1 ELSE 0 END) AS per_customer_90d_amt_neg
FROM ads.ads_cus_customer_rfm_df WHERE travel_date = '${bizdate}';

-- R1134 [弱][有效性] 比率值域（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN repurchase_30d_rate < 0 THEN 1 ELSE 0 END) AS repurchase_30d_rate_bad,
  SUM(CASE WHEN repurchase_90d_rate < 0 THEN 1 ELSE 0 END) AS repurchase_90d_rate_bad
FROM ads.ads_cus_customer_rfm_df WHERE travel_date = '${bizdate}';

-- R1135 [弱][及时性/波动] pay_buyer_30d_qty 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_buyer_30d_qty) AS v FROM ads.ads_cus_customer_rfm_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.ads_cus_customer_growth_di  游客增长 质检 ====================
-- R1136 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}';

-- R1137 [强][唯一性] 主键/粒度唯一（tenant_id + register_channel_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, register_channel_id, COUNT(*) AS c FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, register_channel_id HAVING COUNT(*) > 1
) x;

-- R1138 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR register_channel_id IS NULL);

-- R1139 [弱][有效性] 金额/数量非负（26 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN new_customer_1d_qty < 0 THEN 1 ELSE 0 END) AS new_customer_1d_qty_neg,
  SUM(CASE WHEN new_customer_7d_qty < 0 THEN 1 ELSE 0 END) AS new_customer_7d_qty_neg,
  SUM(CASE WHEN new_customer_30d_qty < 0 THEN 1 ELSE 0 END) AS new_customer_30d_qty_neg,
  SUM(CASE WHEN new_customer_mtd_qty < 0 THEN 1 ELSE 0 END) AS new_customer_mtd_qty_neg,
  SUM(CASE WHEN new_customer_ytd_qty < 0 THEN 1 ELSE 0 END) AS new_customer_ytd_qty_neg,
  SUM(CASE WHEN first_pay_customer_1d_qty < 0 THEN 1 ELSE 0 END) AS first_pay_customer_1d_qty_neg,
  SUM(CASE WHEN first_pay_customer_7d_qty < 0 THEN 1 ELSE 0 END) AS first_pay_customer_7d_qty_neg,
  SUM(CASE WHEN first_pay_customer_30d_qty < 0 THEN 1 ELSE 0 END) AS first_pay_customer_30d_qty_neg,
  SUM(CASE WHEN first_pay_customer_mtd_qty < 0 THEN 1 ELSE 0 END) AS first_pay_customer_mtd_qty_neg,
  SUM(CASE WHEN first_pay_customer_ytd_qty < 0 THEN 1 ELSE 0 END) AS first_pay_customer_ytd_qty_neg,
  SUM(CASE WHEN face_register_1d_qty < 0 THEN 1 ELSE 0 END) AS face_register_1d_qty_neg,
  SUM(CASE WHEN face_register_7d_qty < 0 THEN 1 ELSE 0 END) AS face_register_7d_qty_neg,
  SUM(CASE WHEN face_register_30d_qty < 0 THEN 1 ELSE 0 END) AS face_register_30d_qty_neg,
  SUM(CASE WHEN face_register_mtd_qty < 0 THEN 1 ELSE 0 END) AS face_register_mtd_qty_neg,
  SUM(CASE WHEN face_register_ytd_qty < 0 THEN 1 ELSE 0 END) AS face_register_ytd_qty_neg,
  SUM(CASE WHEN certified_customer_1d_qty < 0 THEN 1 ELSE 0 END) AS certified_customer_1d_qty_neg,
  SUM(CASE WHEN certified_customer_7d_qty < 0 THEN 1 ELSE 0 END) AS certified_customer_7d_qty_neg,
  SUM(CASE WHEN certified_customer_30d_qty < 0 THEN 1 ELSE 0 END) AS certified_customer_30d_qty_neg,
  SUM(CASE WHEN certified_customer_mtd_qty < 0 THEN 1 ELSE 0 END) AS certified_customer_mtd_qty_neg,
  SUM(CASE WHEN certified_customer_ytd_qty < 0 THEN 1 ELSE 0 END) AS certified_customer_ytd_qty_neg,
  SUM(CASE WHEN repeat_buyer_1d_qty < 0 THEN 1 ELSE 0 END) AS repeat_buyer_1d_qty_neg,
  SUM(CASE WHEN repeat_buyer_7d_qty < 0 THEN 1 ELSE 0 END) AS repeat_buyer_7d_qty_neg,
  SUM(CASE WHEN repeat_buyer_30d_qty < 0 THEN 1 ELSE 0 END) AS repeat_buyer_30d_qty_neg,
  SUM(CASE WHEN identity_bind_1d_qty < 0 THEN 1 ELSE 0 END) AS identity_bind_1d_qty_neg,
  SUM(CASE WHEN identity_bind_7d_qty < 0 THEN 1 ELSE 0 END) AS identity_bind_7d_qty_neg,
  SUM(CASE WHEN identity_bind_30d_qty < 0 THEN 1 ELSE 0 END) AS identity_bind_30d_qty_neg
FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}';

-- R1140 [弱][有效性] 比率值域（9 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN register_pay_conversion_1d_rate < 0 THEN 1 ELSE 0 END) AS register_pay_conversion_1d_rate_bad,
  SUM(CASE WHEN register_pay_conversion_7d_rate < 0 THEN 1 ELSE 0 END) AS register_pay_conversion_7d_rate_bad,
  SUM(CASE WHEN register_pay_conversion_30d_rate < 0 THEN 1 ELSE 0 END) AS register_pay_conversion_30d_rate_bad,
  SUM(CASE WHEN new_buyer_share_1d_rate < 0 OR new_buyer_share_1d_rate > 100 THEN 1 ELSE 0 END) AS new_buyer_share_1d_rate_bad,
  SUM(CASE WHEN new_buyer_share_7d_rate < 0 OR new_buyer_share_7d_rate > 100 THEN 1 ELSE 0 END) AS new_buyer_share_7d_rate_bad,
  SUM(CASE WHEN new_buyer_share_30d_rate < 0 OR new_buyer_share_30d_rate > 100 THEN 1 ELSE 0 END) AS new_buyer_share_30d_rate_bad,
  SUM(CASE WHEN face_register_1d_rate < 0 OR face_register_1d_rate > 100 THEN 1 ELSE 0 END) AS face_register_1d_rate_bad,
  SUM(CASE WHEN face_register_7d_rate < 0 OR face_register_7d_rate > 100 THEN 1 ELSE 0 END) AS face_register_7d_rate_bad,
  SUM(CASE WHEN face_register_30d_rate < 0 OR face_register_30d_rate > 100 THEN 1 ELSE 0 END) AS face_register_30d_rate_bad
FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}';

-- R1141 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_cus_customer_growth_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1273 [弱][一致性] 勾稽：face_register_1d_rate = face_register_1d_qty × 100 / new_customer_1d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}' AND new_customer_1d_qty <> 0
  AND ABS(face_register_1d_rate - ROUND(face_register_1d_qty * 100 / new_customer_1d_qty, 6)) > 0.000001;

-- R1274 [弱][一致性] 勾稽：face_register_7d_rate = face_register_7d_qty × 100 / new_customer_7d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}' AND new_customer_7d_qty <> 0
  AND ABS(face_register_7d_rate - ROUND(face_register_7d_qty * 100 / new_customer_7d_qty, 6)) > 0.000001;

-- R1275 [弱][一致性] 勾稽：face_register_30d_rate = face_register_30d_qty × 100 / new_customer_30d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}' AND new_customer_30d_qty <> 0
  AND ABS(face_register_30d_rate - ROUND(face_register_30d_qty * 100 / new_customer_30d_qty, 6)) > 0.000001;

-- R1329 [弱][一致性] 对账：new_customer_1d_qty 与 dws_cus_tenant_growth_di.new_customer_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(new_customer_1d_qty) FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(new_customer_qty) FROM dws.dws_cus_tenant_growth_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1330 [弱][一致性] 对账：first_pay_customer_1d_qty 与 dws_cus_tenant_growth_di.first_pay_customer_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(first_pay_customer_1d_qty) FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(first_pay_customer_qty) FROM dws.dws_cus_tenant_growth_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1331 [弱][一致性] 对账：face_register_1d_qty 与 dws_cus_tenant_growth_di.face_register_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(face_register_1d_qty) FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(face_register_qty) FROM dws.dws_cus_tenant_growth_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1332 [弱][一致性] 对账：certified_customer_1d_qty 与 dws_cus_tenant_growth_di.certified_customer_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(certified_customer_1d_qty) FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(certified_customer_qty) FROM dws.dws_cus_tenant_growth_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1333 [弱][一致性] 对账：repeat_buyer_1d_qty 与 dws_cus_tenant_growth_di.repeat_buyer_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(repeat_buyer_1d_qty) FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(repeat_buyer_qty) FROM dws.dws_cus_tenant_growth_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1334 [弱][一致性] 对账：identity_bind_1d_qty 与 dws_cus_tenant_growth_di.identity_bind_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(identity_bind_1d_qty) FROM ads.ads_cus_customer_growth_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(identity_bind_qty) FROM dws.dws_cus_tenant_growth_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_inv_stock_sellout_df  库存售罄与上座率 质检 ====================
-- R1142 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_inv_stock_sellout_df WHERE travel_date = '${bizdate}';

-- R1143 [强][唯一性] 主键/粒度唯一（sku_id + play_date）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT sku_id, play_date, COUNT(*) AS c FROM ads.ads_inv_stock_sellout_df WHERE travel_date = '${bizdate}' GROUP BY sku_id, play_date HAVING COUNT(*) > 1
) x;

-- R1144 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_inv_stock_sellout_df WHERE travel_date = '${bizdate}' AND (sku_id IS NULL OR play_date IS NULL);

-- R1145 [弱][有效性] 金额/数量非负（12 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN stock_total_td_qty < 0 THEN 1 ELSE 0 END) AS stock_total_td_qty_neg,
  SUM(CASE WHEN stock_available_td_qty < 0 THEN 1 ELSE 0 END) AS stock_available_td_qty_neg,
  SUM(CASE WHEN stock_frozen_td_qty < 0 THEN 1 ELSE 0 END) AS stock_frozen_td_qty_neg,
  SUM(CASE WHEN stock_sold_td_qty < 0 THEN 1 ELSE 0 END) AS stock_sold_td_qty_neg,
  SUM(CASE WHEN sellout_pool_td_qty < 0 THEN 1 ELSE 0 END) AS sellout_pool_td_qty_neg,
  SUM(CASE WHEN unit_occupied_td_qty < 0 THEN 1 ELSE 0 END) AS unit_occupied_td_qty_neg,
  SUM(CASE WHEN prededuct_1d_qty < 0 THEN 1 ELSE 0 END) AS prededuct_1d_qty_neg,
  SUM(CASE WHEN prededuct_7d_qty < 0 THEN 1 ELSE 0 END) AS prededuct_7d_qty_neg,
  SUM(CASE WHEN prededuct_30d_qty < 0 THEN 1 ELSE 0 END) AS prededuct_30d_qty_neg,
  SUM(CASE WHEN prededuct_release_1d_qty < 0 THEN 1 ELSE 0 END) AS prededuct_release_1d_qty_neg,
  SUM(CASE WHEN prededuct_release_7d_qty < 0 THEN 1 ELSE 0 END) AS prededuct_release_7d_qty_neg,
  SUM(CASE WHEN prededuct_release_30d_qty < 0 THEN 1 ELSE 0 END) AS prededuct_release_30d_qty_neg
FROM ads.ads_inv_stock_sellout_df WHERE travel_date = '${bizdate}';

-- R1146 [弱][有效性] 比率值域（5 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN stock_sell_through_td_rate < 0 OR stock_sell_through_td_rate > 100 THEN 1 ELSE 0 END) AS stock_sell_through_td_rate_bad,
  SUM(CASE WHEN stock_sellout_td_rate < 0 OR stock_sellout_td_rate > 100 THEN 1 ELSE 0 END) AS stock_sellout_td_rate_bad,
  SUM(CASE WHEN prededuct_convert_1d_rate < 0 THEN 1 ELSE 0 END) AS prededuct_convert_1d_rate_bad,
  SUM(CASE WHEN prededuct_convert_7d_rate < 0 THEN 1 ELSE 0 END) AS prededuct_convert_7d_rate_bad,
  SUM(CASE WHEN prededuct_convert_30d_rate < 0 THEN 1 ELSE 0 END) AS prededuct_convert_30d_rate_bad
FROM ads.ads_inv_stock_sellout_df WHERE travel_date = '${bizdate}';

-- R1147 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_inv_stock_sellout_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1276 [弱][一致性] 勾稽：stock_sell_through_td_rate = stock_sold_td_qty × 100 / stock_total_td_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_inv_stock_sellout_df WHERE travel_date = '${bizdate}' AND stock_total_td_qty <> 0
  AND ABS(stock_sell_through_td_rate - ROUND(stock_sold_td_qty * 100 / stock_total_td_qty, 6)) > 0.000001;

-- ==================== dq.ads_prd_price_discount_di  价格与折扣分析 质检 ====================
-- R1148 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_prd_price_discount_di WHERE travel_date = '${bizdate}';

-- R1149 [强][唯一性] 主键/粒度唯一（sku_id + price_channel_code）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT sku_id, price_channel_code, COUNT(*) AS c FROM ads.ads_prd_price_discount_di WHERE travel_date = '${bizdate}' GROUP BY sku_id, price_channel_code HAVING COUNT(*) > 1
) x;

-- R1150 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_prd_price_discount_di WHERE travel_date = '${bizdate}' AND (sku_id IS NULL OR price_channel_code IS NULL);

-- R1151 [弱][有效性] 金额/数量非负（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN list_price_1d_amt < 0 THEN 1 ELSE 0 END) AS list_price_1d_amt_neg,
  SUM(CASE WHEN avg_deal_price_1d_amt < 0 THEN 1 ELSE 0 END) AS avg_deal_price_1d_amt_neg,
  SUM(CASE WHEN avg_deal_price_7d_amt < 0 THEN 1 ELSE 0 END) AS avg_deal_price_7d_amt_neg,
  SUM(CASE WHEN avg_deal_price_30d_amt < 0 THEN 1 ELSE 0 END) AS avg_deal_price_30d_amt_neg
FROM ads.ads_prd_price_discount_di WHERE travel_date = '${bizdate}';

-- R1152 [弱][有效性] 比率值域（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN discount_1d_rate < 0 THEN 1 ELSE 0 END) AS discount_1d_rate_bad,
  SUM(CASE WHEN discount_7d_rate < 0 THEN 1 ELSE 0 END) AS discount_7d_rate_bad,
  SUM(CASE WHEN discount_30d_rate < 0 THEN 1 ELSE 0 END) AS discount_30d_rate_bad
FROM ads.ads_prd_price_discount_di WHERE travel_date = '${bizdate}';

-- R1153 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_prd_price_discount_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1277 [弱][一致性] 勾稽：discount_1d_rate = avg_deal_price_1d_amt × 100 / list_price_1d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_prd_price_discount_di WHERE travel_date = '${bizdate}' AND list_price_1d_amt <> 0
  AND ABS(discount_1d_rate - ROUND(avg_deal_price_1d_amt * 100 / list_price_1d_amt, 6)) > 0.000001;

-- R1335 [弱][一致性] 对账：list_price_1d_amt 与 dws_prd_sku_price_di.list_price_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(list_price_1d_amt) FROM ads.ads_prd_price_discount_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(list_price_amt) FROM dws.dws_prd_sku_price_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1336 [弱][一致性] 对账：price_change_1d_qty 与 dws_prd_sku_price_di.price_change_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(price_change_1d_qty) FROM ads.ads_prd_price_discount_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(price_change_qty) FROM dws.dws_prd_sku_price_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1337 [弱][一致性] 对账：sku_change_1d_qty 与 dws_prd_sku_price_di.sku_change_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(sku_change_1d_qty) FROM ads.ads_prd_price_discount_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(sku_change_qty) FROM dws.dws_prd_sku_price_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_trf_distributor_rank_di  分销商业绩排行 质检 ====================
-- R1154 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_trf_distributor_rank_di WHERE travel_date = '${bizdate}';

-- R1155 [强][唯一性] 主键/粒度唯一（supplier_tenant_id + distributor_tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT supplier_tenant_id, distributor_tenant_id, COUNT(*) AS c FROM ads.ads_trf_distributor_rank_di WHERE travel_date = '${bizdate}' GROUP BY supplier_tenant_id, distributor_tenant_id HAVING COUNT(*) > 1
) x;

-- R1156 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_trf_distributor_rank_di WHERE travel_date = '${bizdate}' AND (supplier_tenant_id IS NULL OR distributor_tenant_id IS NULL);

-- R1157 [弱][有效性] 金额/数量非负（12 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN distribution_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS distribution_ticket_1d_qty_neg,
  SUM(CASE WHEN distribution_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS distribution_ticket_7d_qty_neg,
  SUM(CASE WHEN distribution_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS distribution_ticket_30d_qty_neg,
  SUM(CASE WHEN distribution_sale_1d_amt < 0 THEN 1 ELSE 0 END) AS distribution_sale_1d_amt_neg,
  SUM(CASE WHEN distribution_sale_7d_amt < 0 THEN 1 ELSE 0 END) AS distribution_sale_7d_amt_neg,
  SUM(CASE WHEN distribution_sale_30d_amt < 0 THEN 1 ELSE 0 END) AS distribution_sale_30d_amt_neg,
  SUM(CASE WHEN active_distributor_1d_qty < 0 THEN 1 ELSE 0 END) AS active_distributor_1d_qty_neg,
  SUM(CASE WHEN active_distributor_7d_qty < 0 THEN 1 ELSE 0 END) AS active_distributor_7d_qty_neg,
  SUM(CASE WHEN active_distributor_30d_qty < 0 THEN 1 ELSE 0 END) AS active_distributor_30d_qty_neg,
  SUM(CASE WHEN new_distribution_relation_1d_qty < 0 THEN 1 ELSE 0 END) AS new_distribution_relation_1d_qty_neg,
  SUM(CASE WHEN new_distribution_relation_7d_qty < 0 THEN 1 ELSE 0 END) AS new_distribution_relation_7d_qty_neg,
  SUM(CASE WHEN new_distribution_relation_30d_qty < 0 THEN 1 ELSE 0 END) AS new_distribution_relation_30d_qty_neg
FROM ads.ads_trf_distributor_rank_di WHERE travel_date = '${bizdate}';

-- R1158 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_trf_distributor_rank_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1278 [弱][一致性] 勾稽：distribution_profit_1d_rate = distribution_profit_1d_amt × 100 / distribution_sale_1d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_trf_distributor_rank_di WHERE travel_date = '${bizdate}' AND distribution_sale_1d_amt <> 0
  AND ABS(distribution_profit_1d_rate - ROUND(distribution_profit_1d_amt * 100 / distribution_sale_1d_amt, 6)) > 0.000001;

-- R1279 [弱][一致性] 勾稽：distribution_profit_7d_rate = distribution_profit_7d_amt × 100 / distribution_sale_7d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_trf_distributor_rank_di WHERE travel_date = '${bizdate}' AND distribution_sale_7d_amt <> 0
  AND ABS(distribution_profit_7d_rate - ROUND(distribution_profit_7d_amt * 100 / distribution_sale_7d_amt, 6)) > 0.000001;

-- R1280 [弱][一致性] 勾稽：distribution_profit_30d_rate = distribution_profit_30d_amt × 100 / distribution_sale_30d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_trf_distributor_rank_di WHERE travel_date = '${bizdate}' AND distribution_sale_30d_amt <> 0
  AND ABS(distribution_profit_30d_rate - ROUND(distribution_profit_30d_amt * 100 / distribution_sale_30d_amt, 6)) > 0.000001;

-- R1338 [弱][一致性] 对账：distribution_ticket_1d_qty 与 dws_trf_distributor_trade_di.distribution_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(distribution_ticket_1d_qty) FROM ads.ads_trf_distributor_rank_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(distribution_ticket_qty) FROM dws.dws_trf_distributor_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1339 [弱][一致性] 对账：distribution_sale_1d_amt 与 dws_trf_distributor_trade_di.distribution_sale_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(distribution_sale_1d_amt) FROM ads.ads_trf_distributor_rank_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(distribution_sale_amt) FROM dws.dws_trf_distributor_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1340 [弱][一致性] 对账：distribution_profit_1d_amt 与 dws_trf_distributor_trade_di.distribution_profit_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(distribution_profit_1d_amt) FROM ads.ads_trf_distributor_rank_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(distribution_profit_amt) FROM dws.dws_trf_distributor_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1341 [弱][一致性] 对账：active_distributor_1d_qty 与 dws_trf_distributor_trade_di.active_distributor_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(active_distributor_1d_qty) FROM ads.ads_trf_distributor_rank_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(active_distributor_qty) FROM dws.dws_trf_distributor_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_trf_chain_profit_di  分销链利润分配 质检 ====================
-- R1159 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_trf_chain_profit_di WHERE travel_date = '${bizdate}';

-- R1160 [强][唯一性] 主键/粒度唯一（supplier_tenant_id + sku_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT supplier_tenant_id, sku_id, COUNT(*) AS c FROM ads.ads_trf_chain_profit_di WHERE travel_date = '${bizdate}' GROUP BY supplier_tenant_id, sku_id HAVING COUNT(*) > 1
) x;

-- R1161 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_trf_chain_profit_di WHERE travel_date = '${bizdate}' AND (supplier_tenant_id IS NULL OR sku_id IS NULL);

-- R1162 [弱][有效性] 金额/数量非负（15 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN l1_distribution_purchase_1d_amt < 0 THEN 1 ELSE 0 END) AS l1_distribution_purchase_1d_amt_neg,
  SUM(CASE WHEN l1_distribution_purchase_7d_amt < 0 THEN 1 ELSE 0 END) AS l1_distribution_purchase_7d_amt_neg,
  SUM(CASE WHEN l1_distribution_purchase_30d_amt < 0 THEN 1 ELSE 0 END) AS l1_distribution_purchase_30d_amt_neg,
  SUM(CASE WHEN l2_distribution_purchase_1d_amt < 0 THEN 1 ELSE 0 END) AS l2_distribution_purchase_1d_amt_neg,
  SUM(CASE WHEN l2_distribution_purchase_7d_amt < 0 THEN 1 ELSE 0 END) AS l2_distribution_purchase_7d_amt_neg,
  SUM(CASE WHEN l2_distribution_purchase_30d_amt < 0 THEN 1 ELSE 0 END) AS l2_distribution_purchase_30d_amt_neg,
  SUM(CASE WHEN l3_distribution_purchase_1d_amt < 0 THEN 1 ELSE 0 END) AS l3_distribution_purchase_1d_amt_neg,
  SUM(CASE WHEN l3_distribution_purchase_7d_amt < 0 THEN 1 ELSE 0 END) AS l3_distribution_purchase_7d_amt_neg,
  SUM(CASE WHEN l3_distribution_purchase_30d_amt < 0 THEN 1 ELSE 0 END) AS l3_distribution_purchase_30d_amt_neg,
  SUM(CASE WHEN l4_distribution_purchase_1d_amt < 0 THEN 1 ELSE 0 END) AS l4_distribution_purchase_1d_amt_neg,
  SUM(CASE WHEN l4_distribution_purchase_7d_amt < 0 THEN 1 ELSE 0 END) AS l4_distribution_purchase_7d_amt_neg,
  SUM(CASE WHEN l4_distribution_purchase_30d_amt < 0 THEN 1 ELSE 0 END) AS l4_distribution_purchase_30d_amt_neg,
  SUM(CASE WHEN avg_chain_level_1d_qty < 0 THEN 1 ELSE 0 END) AS avg_chain_level_1d_qty_neg,
  SUM(CASE WHEN avg_chain_level_7d_qty < 0 THEN 1 ELSE 0 END) AS avg_chain_level_7d_qty_neg,
  SUM(CASE WHEN avg_chain_level_30d_qty < 0 THEN 1 ELSE 0 END) AS avg_chain_level_30d_qty_neg
FROM ads.ads_trf_chain_profit_di WHERE travel_date = '${bizdate}';

-- R1163 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_trf_chain_profit_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.ads_fin_tenant_settlement_di  商户结算对账 质检 ====================
-- R1164 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}';

-- R1165 [强][唯一性] 主键/粒度唯一（tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, COUNT(*) AS c FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id HAVING COUNT(*) > 1
) x;

-- R1166 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL);

-- R1167 [弱][有效性] 金额/数量非负（53 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN inbound_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS inbound_pay_1d_amt_neg,
  SUM(CASE WHEN inbound_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS inbound_pay_7d_amt_neg,
  SUM(CASE WHEN inbound_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS inbound_pay_30d_amt_neg,
  SUM(CASE WHEN inbound_pay_mtd_amt < 0 THEN 1 ELSE 0 END) AS inbound_pay_mtd_amt_neg,
  SUM(CASE WHEN inbound_pay_ytd_amt < 0 THEN 1 ELSE 0 END) AS inbound_pay_ytd_amt_neg,
  SUM(CASE WHEN outbound_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS outbound_pay_1d_amt_neg,
  SUM(CASE WHEN outbound_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS outbound_pay_7d_amt_neg,
  SUM(CASE WHEN outbound_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS outbound_pay_30d_amt_neg,
  SUM(CASE WHEN outbound_pay_mtd_amt < 0 THEN 1 ELSE 0 END) AS outbound_pay_mtd_amt_neg,
  SUM(CASE WHEN outbound_pay_ytd_amt < 0 THEN 1 ELSE 0 END) AS outbound_pay_ytd_amt_neg,
  SUM(CASE WHEN refund_payment_1d_amt < 0 THEN 1 ELSE 0 END) AS refund_payment_1d_amt_neg,
  SUM(CASE WHEN refund_payment_7d_amt < 0 THEN 1 ELSE 0 END) AS refund_payment_7d_amt_neg,
  SUM(CASE WHEN refund_payment_30d_amt < 0 THEN 1 ELSE 0 END) AS refund_payment_30d_amt_neg,
  SUM(CASE WHEN refund_payment_mtd_amt < 0 THEN 1 ELSE 0 END) AS refund_payment_mtd_amt_neg,
  SUM(CASE WHEN refund_payment_ytd_amt < 0 THEN 1 ELSE 0 END) AS refund_payment_ytd_amt_neg,
  SUM(CASE WHEN freeze_1d_amt < 0 THEN 1 ELSE 0 END) AS freeze_1d_amt_neg,
  SUM(CASE WHEN freeze_7d_amt < 0 THEN 1 ELSE 0 END) AS freeze_7d_amt_neg,
  SUM(CASE WHEN freeze_30d_amt < 0 THEN 1 ELSE 0 END) AS freeze_30d_amt_neg,
  SUM(CASE WHEN freeze_mtd_amt < 0 THEN 1 ELSE 0 END) AS freeze_mtd_amt_neg,
  SUM(CASE WHEN freeze_ytd_amt < 0 THEN 1 ELSE 0 END) AS freeze_ytd_amt_neg,
  SUM(CASE WHEN unfreeze_verify_1d_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_verify_1d_amt_neg,
  SUM(CASE WHEN unfreeze_verify_7d_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_verify_7d_amt_neg,
  SUM(CASE WHEN unfreeze_verify_30d_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_verify_30d_amt_neg,
  SUM(CASE WHEN unfreeze_verify_mtd_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_verify_mtd_amt_neg,
  SUM(CASE WHEN unfreeze_verify_ytd_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_verify_ytd_amt_neg,
  SUM(CASE WHEN unfreeze_refund_1d_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_refund_1d_amt_neg,
  SUM(CASE WHEN unfreeze_refund_7d_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_refund_7d_amt_neg,
  SUM(CASE WHEN unfreeze_refund_30d_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_refund_30d_amt_neg,
  SUM(CASE WHEN unfreeze_refund_mtd_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_refund_mtd_amt_neg,
  SUM(CASE WHEN unfreeze_refund_ytd_amt < 0 THEN 1 ELSE 0 END) AS unfreeze_refund_ytd_amt_neg,
  SUM(CASE WHEN fee_1d_amt < 0 THEN 1 ELSE 0 END) AS fee_1d_amt_neg,
  SUM(CASE WHEN fee_7d_amt < 0 THEN 1 ELSE 0 END) AS fee_7d_amt_neg,
  SUM(CASE WHEN fee_30d_amt < 0 THEN 1 ELSE 0 END) AS fee_30d_amt_neg,
  SUM(CASE WHEN fee_mtd_amt < 0 THEN 1 ELSE 0 END) AS fee_mtd_amt_neg,
  SUM(CASE WHEN fee_ytd_amt < 0 THEN 1 ELSE 0 END) AS fee_ytd_amt_neg,
  SUM(CASE WHEN settlement_freeze_1d_amt < 0 THEN 1 ELSE 0 END) AS settlement_freeze_1d_amt_neg,
  SUM(CASE WHEN settlement_freeze_7d_amt < 0 THEN 1 ELSE 0 END) AS settlement_freeze_7d_amt_neg,
  SUM(CASE WHEN settlement_freeze_30d_amt < 0 THEN 1 ELSE 0 END) AS settlement_freeze_30d_amt_neg,
  SUM(CASE WHEN full_freeze_1d_amt < 0 THEN 1 ELSE 0 END) AS full_freeze_1d_amt_neg,
  SUM(CASE WHEN full_freeze_7d_amt < 0 THEN 1 ELSE 0 END) AS full_freeze_7d_amt_neg
FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}';

-- R1168 [弱][有效性] 比率值域（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN external_freeze_1d_rate < 0 THEN 1 ELSE 0 END) AS external_freeze_1d_rate_bad,
  SUM(CASE WHEN external_freeze_7d_rate < 0 THEN 1 ELSE 0 END) AS external_freeze_7d_rate_bad,
  SUM(CASE WHEN external_freeze_30d_rate < 0 THEN 1 ELSE 0 END) AS external_freeze_30d_rate_bad,
  SUM(CASE WHEN invoice_1d_rate < 0 THEN 1 ELSE 0 END) AS invoice_1d_rate_bad,
  SUM(CASE WHEN invoice_7d_rate < 0 THEN 1 ELSE 0 END) AS invoice_7d_rate_bad,
  SUM(CASE WHEN invoice_30d_rate < 0 THEN 1 ELSE 0 END) AS invoice_30d_rate_bad
FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}';

-- R1169 [弱][及时性/波动] refund_payment_1d_amt 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(refund_payment_1d_amt) AS v FROM ads.ads_fin_tenant_settlement_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1281 [弱][一致性] 勾稽：external_freeze_1d_rate = external_freeze_1d_amt × 100 / freeze_1d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}' AND freeze_1d_amt <> 0
  AND ABS(external_freeze_1d_rate - ROUND(external_freeze_1d_amt * 100 / freeze_1d_amt, 6)) > 0.000001;

-- R1282 [弱][一致性] 勾稽：external_freeze_7d_rate = external_freeze_7d_amt × 100 / freeze_7d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}' AND freeze_7d_amt <> 0
  AND ABS(external_freeze_7d_rate - ROUND(external_freeze_7d_amt * 100 / freeze_7d_amt, 6)) > 0.000001;

-- R1283 [弱][一致性] 勾稽：external_freeze_30d_rate = external_freeze_30d_amt × 100 / freeze_30d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}' AND freeze_30d_amt <> 0
  AND ABS(external_freeze_30d_rate - ROUND(external_freeze_30d_amt * 100 / freeze_30d_amt, 6)) > 0.000001;

-- R1342 [弱][一致性] 对账：inbound_pay_1d_amt 与 dws_fin_tenant_pay_method_di.inbound_pay_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(inbound_pay_1d_amt) FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(inbound_pay_amt) FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1343 [弱][一致性] 对账：outbound_pay_1d_amt 与 dws_fin_tenant_pay_method_di.outbound_pay_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(outbound_pay_1d_amt) FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(outbound_pay_amt) FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1344 [弱][一致性] 对账：refund_payment_1d_amt 与 dws_fin_tenant_pay_method_di.refund_payment_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(refund_payment_1d_amt) FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(refund_payment_amt) FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1345 [弱][一致性] 对账：freeze_1d_amt 与 dws_fin_account_frozen_di.freeze_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(freeze_1d_amt) FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(freeze_amt) FROM dws.dws_fin_account_frozen_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1346 [弱][一致性] 对账：unfreeze_verify_1d_amt 与 dws_fin_account_frozen_di.unfreeze_verify_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(unfreeze_verify_1d_amt) FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(unfreeze_verify_amt) FROM dws.dws_fin_account_frozen_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1347 [弱][一致性] 对账：unfreeze_refund_1d_amt 与 dws_fin_account_frozen_di.unfreeze_refund_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(unfreeze_refund_1d_amt) FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(unfreeze_refund_amt) FROM dws.dws_fin_account_frozen_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1348 [弱][一致性] 对账：fee_1d_amt 与 dws_fin_account_flow_di.fee_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(fee_1d_amt) FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(fee_amt) FROM dws.dws_fin_account_flow_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1349 [弱][一致性] 对账：external_freeze_1d_amt 与 dws_fin_account_frozen_di.external_freeze_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(external_freeze_1d_amt) FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(external_freeze_amt) FROM dws.dws_fin_account_frozen_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1350 [弱][一致性] 对账：expire_release_1d_amt 与 dws_fin_account_frozen_di.expire_release_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(expire_release_1d_amt) FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(expire_release_amt) FROM dws.dws_fin_account_frozen_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1351 [弱][一致性] 对账：invoice_1d_amt 与 dws_fin_tenant_pay_method_di.invoice_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(invoice_1d_amt) FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(invoice_amt) FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1352 [弱][一致性] 对账：invoice_order_1d_qty 与 dws_fin_tenant_pay_method_di.invoice_order_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(invoice_order_1d_qty) FROM ads.ads_fin_tenant_settlement_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(invoice_order_qty) FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_fin_account_fund_df  账户资金看板 质检 ====================
-- R1170 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}';

-- R1171 [强][唯一性] 主键/粒度唯一（account_no）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT account_no, COUNT(*) AS c FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}' GROUP BY account_no HAVING COUNT(*) > 1
) x;

-- R1172 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}' AND (account_no IS NULL);

-- R1173 [弱][有效性] 金额/数量非负（17 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN available_balance_td_amt < 0 THEN 1 ELSE 0 END) AS available_balance_td_amt_neg,
  SUM(CASE WHEN frozen_balance_td_amt < 0 THEN 1 ELSE 0 END) AS frozen_balance_td_amt_neg,
  SUM(CASE WHEN credit_limit_td_amt < 0 THEN 1 ELSE 0 END) AS credit_limit_td_amt_neg,
  SUM(CASE WHEN credit_used_td_amt < 0 THEN 1 ELSE 0 END) AS credit_used_td_amt_neg,
  SUM(CASE WHEN withdraw_apply_1d_amt < 0 THEN 1 ELSE 0 END) AS withdraw_apply_1d_amt_neg,
  SUM(CASE WHEN withdraw_apply_7d_amt < 0 THEN 1 ELSE 0 END) AS withdraw_apply_7d_amt_neg,
  SUM(CASE WHEN withdraw_apply_30d_amt < 0 THEN 1 ELSE 0 END) AS withdraw_apply_30d_amt_neg,
  SUM(CASE WHEN withdraw_apply_mtd_amt < 0 THEN 1 ELSE 0 END) AS withdraw_apply_mtd_amt_neg,
  SUM(CASE WHEN withdraw_apply_ytd_amt < 0 THEN 1 ELSE 0 END) AS withdraw_apply_ytd_amt_neg,
  SUM(CASE WHEN withdraw_success_1d_amt < 0 THEN 1 ELSE 0 END) AS withdraw_success_1d_amt_neg,
  SUM(CASE WHEN withdraw_success_7d_amt < 0 THEN 1 ELSE 0 END) AS withdraw_success_7d_amt_neg,
  SUM(CASE WHEN withdraw_success_30d_amt < 0 THEN 1 ELSE 0 END) AS withdraw_success_30d_amt_neg,
  SUM(CASE WHEN withdraw_success_mtd_amt < 0 THEN 1 ELSE 0 END) AS withdraw_success_mtd_amt_neg,
  SUM(CASE WHEN withdraw_success_ytd_amt < 0 THEN 1 ELSE 0 END) AS withdraw_success_ytd_amt_neg,
  SUM(CASE WHEN withdraw_fail_1d_qty < 0 THEN 1 ELSE 0 END) AS withdraw_fail_1d_qty_neg,
  SUM(CASE WHEN withdraw_fail_7d_qty < 0 THEN 1 ELSE 0 END) AS withdraw_fail_7d_qty_neg,
  SUM(CASE WHEN withdraw_fail_30d_qty < 0 THEN 1 ELSE 0 END) AS withdraw_fail_30d_qty_neg
FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}';

-- R1174 [弱][有效性] 比率值域（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN credit_usage_td_rate < 0 THEN 1 ELSE 0 END) AS credit_usage_td_rate_bad,
  SUM(CASE WHEN withdraw_success_1d_rate < 0 THEN 1 ELSE 0 END) AS withdraw_success_1d_rate_bad,
  SUM(CASE WHEN withdraw_success_7d_rate < 0 THEN 1 ELSE 0 END) AS withdraw_success_7d_rate_bad,
  SUM(CASE WHEN withdraw_success_30d_rate < 0 THEN 1 ELSE 0 END) AS withdraw_success_30d_rate_bad
FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}';

-- R1175 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_fin_account_fund_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1284 [弱][一致性] 勾稽：credit_usage_td_rate = credit_used_td_amt × 100 / credit_limit_td_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}' AND credit_limit_td_amt <> 0
  AND ABS(credit_usage_td_rate - ROUND(credit_used_td_amt * 100 / credit_limit_td_amt, 6)) > 0.000001;

-- R1285 [弱][一致性] 勾稽：withdraw_success_1d_rate = withdraw_success_1d_amt × 100 / withdraw_apply_1d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}' AND withdraw_apply_1d_amt <> 0
  AND ABS(withdraw_success_1d_rate - ROUND(withdraw_success_1d_amt * 100 / withdraw_apply_1d_amt, 6)) > 0.000001;

-- R1286 [弱][一致性] 勾稽：withdraw_success_7d_rate = withdraw_success_7d_amt × 100 / withdraw_apply_7d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}' AND withdraw_apply_7d_amt <> 0
  AND ABS(withdraw_success_7d_rate - ROUND(withdraw_success_7d_amt * 100 / withdraw_apply_7d_amt, 6)) > 0.000001;

-- R1287 [弱][一致性] 勾稽：withdraw_success_30d_rate = withdraw_success_30d_amt × 100 / withdraw_apply_30d_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}' AND withdraw_apply_30d_amt <> 0
  AND ABS(withdraw_success_30d_rate - ROUND(withdraw_success_30d_amt * 100 / withdraw_apply_30d_amt, 6)) > 0.000001;

-- R1353 [弱][一致性] 对账：withdraw_apply_1d_amt 与 dws_fin_account_flow_di.withdraw_apply_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(withdraw_apply_1d_amt) FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(withdraw_apply_amt) FROM dws.dws_fin_account_flow_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1354 [弱][一致性] 对账：withdraw_success_1d_amt 与 dws_fin_account_flow_di.withdraw_success_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(withdraw_success_1d_amt) FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(withdraw_success_amt) FROM dws.dws_fin_account_flow_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1355 [弱][一致性] 对账：withdraw_fail_1d_qty 与 dws_fin_account_flow_di.withdraw_fail_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(withdraw_fail_1d_qty) FROM ads.ads_fin_account_fund_df WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(withdraw_fail_qty) FROM dws.dws_fin_account_flow_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_fin_pay_method_di  支付方式结构 质检 ====================
-- R1176 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_fin_pay_method_di WHERE travel_date = '${bizdate}';

-- R1177 [强][唯一性] 主键/粒度唯一（tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, COUNT(*) AS c FROM ads.ads_fin_pay_method_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id HAVING COUNT(*) > 1
) x;

-- R1178 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_fin_pay_method_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL);

-- R1179 [弱][有效性] 金额/数量非负（33 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN wechat_inbound_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS wechat_inbound_pay_1d_amt_neg,
  SUM(CASE WHEN wechat_inbound_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS wechat_inbound_pay_7d_amt_neg,
  SUM(CASE WHEN wechat_inbound_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS wechat_inbound_pay_30d_amt_neg,
  SUM(CASE WHEN alipay_inbound_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS alipay_inbound_pay_1d_amt_neg,
  SUM(CASE WHEN alipay_inbound_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS alipay_inbound_pay_7d_amt_neg,
  SUM(CASE WHEN alipay_inbound_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS alipay_inbound_pay_30d_amt_neg,
  SUM(CASE WHEN balance_inbound_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS balance_inbound_pay_1d_amt_neg,
  SUM(CASE WHEN balance_inbound_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS balance_inbound_pay_7d_amt_neg,
  SUM(CASE WHEN balance_inbound_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS balance_inbound_pay_30d_amt_neg,
  SUM(CASE WHEN credit_inbound_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS credit_inbound_pay_1d_amt_neg,
  SUM(CASE WHEN credit_inbound_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS credit_inbound_pay_7d_amt_neg,
  SUM(CASE WHEN credit_inbound_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS credit_inbound_pay_30d_amt_neg,
  SUM(CASE WHEN offline_inbound_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS offline_inbound_pay_1d_amt_neg,
  SUM(CASE WHEN offline_inbound_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS offline_inbound_pay_7d_amt_neg,
  SUM(CASE WHEN offline_inbound_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS offline_inbound_pay_30d_amt_neg,
  SUM(CASE WHEN wechat_pay_record_1d_qty < 0 THEN 1 ELSE 0 END) AS wechat_pay_record_1d_qty_neg,
  SUM(CASE WHEN wechat_pay_record_7d_qty < 0 THEN 1 ELSE 0 END) AS wechat_pay_record_7d_qty_neg,
  SUM(CASE WHEN wechat_pay_record_30d_qty < 0 THEN 1 ELSE 0 END) AS wechat_pay_record_30d_qty_neg,
  SUM(CASE WHEN alipay_pay_record_1d_qty < 0 THEN 1 ELSE 0 END) AS alipay_pay_record_1d_qty_neg,
  SUM(CASE WHEN alipay_pay_record_7d_qty < 0 THEN 1 ELSE 0 END) AS alipay_pay_record_7d_qty_neg,
  SUM(CASE WHEN alipay_pay_record_30d_qty < 0 THEN 1 ELSE 0 END) AS alipay_pay_record_30d_qty_neg,
  SUM(CASE WHEN balance_pay_record_1d_qty < 0 THEN 1 ELSE 0 END) AS balance_pay_record_1d_qty_neg,
  SUM(CASE WHEN balance_pay_record_7d_qty < 0 THEN 1 ELSE 0 END) AS balance_pay_record_7d_qty_neg,
  SUM(CASE WHEN balance_pay_record_30d_qty < 0 THEN 1 ELSE 0 END) AS balance_pay_record_30d_qty_neg,
  SUM(CASE WHEN credit_pay_record_1d_qty < 0 THEN 1 ELSE 0 END) AS credit_pay_record_1d_qty_neg,
  SUM(CASE WHEN credit_pay_record_7d_qty < 0 THEN 1 ELSE 0 END) AS credit_pay_record_7d_qty_neg,
  SUM(CASE WHEN credit_pay_record_30d_qty < 0 THEN 1 ELSE 0 END) AS credit_pay_record_30d_qty_neg,
  SUM(CASE WHEN offline_pay_record_1d_qty < 0 THEN 1 ELSE 0 END) AS offline_pay_record_1d_qty_neg,
  SUM(CASE WHEN offline_pay_record_7d_qty < 0 THEN 1 ELSE 0 END) AS offline_pay_record_7d_qty_neg,
  SUM(CASE WHEN offline_pay_record_30d_qty < 0 THEN 1 ELSE 0 END) AS offline_pay_record_30d_qty_neg,
  SUM(CASE WHEN zero_fee_order_1d_qty < 0 THEN 1 ELSE 0 END) AS zero_fee_order_1d_qty_neg,
  SUM(CASE WHEN zero_fee_order_7d_qty < 0 THEN 1 ELSE 0 END) AS zero_fee_order_7d_qty_neg,
  SUM(CASE WHEN zero_fee_order_30d_qty < 0 THEN 1 ELSE 0 END) AS zero_fee_order_30d_qty_neg
FROM ads.ads_fin_pay_method_di WHERE travel_date = '${bizdate}';

-- R1180 [弱][有效性] 比率值域（15 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN wechat_pay_method_share_1d_rate < 0 OR wechat_pay_method_share_1d_rate > 100 THEN 1 ELSE 0 END) AS wechat_pay_method_share_1d_rate_bad,
  SUM(CASE WHEN wechat_pay_method_share_7d_rate < 0 OR wechat_pay_method_share_7d_rate > 100 THEN 1 ELSE 0 END) AS wechat_pay_method_share_7d_rate_bad,
  SUM(CASE WHEN wechat_pay_method_share_30d_rate < 0 OR wechat_pay_method_share_30d_rate > 100 THEN 1 ELSE 0 END) AS wechat_pay_method_share_30d_rate_bad,
  SUM(CASE WHEN alipay_pay_method_share_1d_rate < 0 OR alipay_pay_method_share_1d_rate > 100 THEN 1 ELSE 0 END) AS alipay_pay_method_share_1d_rate_bad,
  SUM(CASE WHEN alipay_pay_method_share_7d_rate < 0 OR alipay_pay_method_share_7d_rate > 100 THEN 1 ELSE 0 END) AS alipay_pay_method_share_7d_rate_bad,
  SUM(CASE WHEN alipay_pay_method_share_30d_rate < 0 OR alipay_pay_method_share_30d_rate > 100 THEN 1 ELSE 0 END) AS alipay_pay_method_share_30d_rate_bad,
  SUM(CASE WHEN balance_pay_method_share_1d_rate < 0 OR balance_pay_method_share_1d_rate > 100 THEN 1 ELSE 0 END) AS balance_pay_method_share_1d_rate_bad,
  SUM(CASE WHEN balance_pay_method_share_7d_rate < 0 OR balance_pay_method_share_7d_rate > 100 THEN 1 ELSE 0 END) AS balance_pay_method_share_7d_rate_bad,
  SUM(CASE WHEN balance_pay_method_share_30d_rate < 0 OR balance_pay_method_share_30d_rate > 100 THEN 1 ELSE 0 END) AS balance_pay_method_share_30d_rate_bad,
  SUM(CASE WHEN credit_pay_method_share_1d_rate < 0 OR credit_pay_method_share_1d_rate > 100 THEN 1 ELSE 0 END) AS credit_pay_method_share_1d_rate_bad,
  SUM(CASE WHEN credit_pay_method_share_7d_rate < 0 OR credit_pay_method_share_7d_rate > 100 THEN 1 ELSE 0 END) AS credit_pay_method_share_7d_rate_bad,
  SUM(CASE WHEN credit_pay_method_share_30d_rate < 0 OR credit_pay_method_share_30d_rate > 100 THEN 1 ELSE 0 END) AS credit_pay_method_share_30d_rate_bad,
  SUM(CASE WHEN offline_pay_method_share_1d_rate < 0 OR offline_pay_method_share_1d_rate > 100 THEN 1 ELSE 0 END) AS offline_pay_method_share_1d_rate_bad,
  SUM(CASE WHEN offline_pay_method_share_7d_rate < 0 OR offline_pay_method_share_7d_rate > 100 THEN 1 ELSE 0 END) AS offline_pay_method_share_7d_rate_bad,
  SUM(CASE WHEN offline_pay_method_share_30d_rate < 0 OR offline_pay_method_share_30d_rate > 100 THEN 1 ELSE 0 END) AS offline_pay_method_share_30d_rate_bad
FROM ads.ads_fin_pay_method_di WHERE travel_date = '${bizdate}';

-- R1181 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_fin_pay_method_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1356 [弱][一致性] 对账：zero_fee_order_1d_qty 与 dws_fin_tenant_pay_method_di.zero_fee_order_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(zero_fee_order_1d_qty) FROM ads.ads_fin_pay_method_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(zero_fee_order_qty) FROM dws.dws_fin_tenant_pay_method_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_sup_staff_performance_di  员工/窗口业绩 质检 ====================
-- R1182 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_sup_staff_performance_di WHERE travel_date = '${bizdate}';

-- R1183 [强][唯一性] 主键/粒度唯一（tenant_id + staff_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, staff_id, COUNT(*) AS c FROM ads.ads_sup_staff_performance_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, staff_id HAVING COUNT(*) > 1
) x;

-- R1184 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_sup_staff_performance_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR staff_id IS NULL);

-- R1185 [弱][有效性] 金额/数量非负（20 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN staff_order_1d_qty < 0 THEN 1 ELSE 0 END) AS staff_order_1d_qty_neg,
  SUM(CASE WHEN staff_order_7d_qty < 0 THEN 1 ELSE 0 END) AS staff_order_7d_qty_neg,
  SUM(CASE WHEN staff_order_30d_qty < 0 THEN 1 ELSE 0 END) AS staff_order_30d_qty_neg,
  SUM(CASE WHEN staff_order_mtd_qty < 0 THEN 1 ELSE 0 END) AS staff_order_mtd_qty_neg,
  SUM(CASE WHEN staff_order_ytd_qty < 0 THEN 1 ELSE 0 END) AS staff_order_ytd_qty_neg,
  SUM(CASE WHEN staff_pay_1d_amt < 0 THEN 1 ELSE 0 END) AS staff_pay_1d_amt_neg,
  SUM(CASE WHEN staff_pay_7d_amt < 0 THEN 1 ELSE 0 END) AS staff_pay_7d_amt_neg,
  SUM(CASE WHEN staff_pay_30d_amt < 0 THEN 1 ELSE 0 END) AS staff_pay_30d_amt_neg,
  SUM(CASE WHEN staff_pay_mtd_amt < 0 THEN 1 ELSE 0 END) AS staff_pay_mtd_amt_neg,
  SUM(CASE WHEN staff_pay_ytd_amt < 0 THEN 1 ELSE 0 END) AS staff_pay_ytd_amt_neg,
  SUM(CASE WHEN staff_verify_1d_qty < 0 THEN 1 ELSE 0 END) AS staff_verify_1d_qty_neg,
  SUM(CASE WHEN staff_verify_7d_qty < 0 THEN 1 ELSE 0 END) AS staff_verify_7d_qty_neg,
  SUM(CASE WHEN staff_verify_30d_qty < 0 THEN 1 ELSE 0 END) AS staff_verify_30d_qty_neg,
  SUM(CASE WHEN staff_verify_mtd_qty < 0 THEN 1 ELSE 0 END) AS staff_verify_mtd_qty_neg,
  SUM(CASE WHEN staff_verify_ytd_qty < 0 THEN 1 ELSE 0 END) AS staff_verify_ytd_qty_neg,
  SUM(CASE WHEN staff_refund_1d_qty < 0 THEN 1 ELSE 0 END) AS staff_refund_1d_qty_neg,
  SUM(CASE WHEN staff_refund_7d_qty < 0 THEN 1 ELSE 0 END) AS staff_refund_7d_qty_neg,
  SUM(CASE WHEN staff_refund_30d_qty < 0 THEN 1 ELSE 0 END) AS staff_refund_30d_qty_neg,
  SUM(CASE WHEN staff_refund_mtd_qty < 0 THEN 1 ELSE 0 END) AS staff_refund_mtd_qty_neg,
  SUM(CASE WHEN staff_refund_ytd_qty < 0 THEN 1 ELSE 0 END) AS staff_refund_ytd_qty_neg
FROM ads.ads_sup_staff_performance_di WHERE travel_date = '${bizdate}';

-- R1186 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_sup_staff_performance_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1357 [弱][一致性] 对账：staff_order_1d_qty 与 dws_sup_staff_operate_di.staff_order_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(staff_order_1d_qty) FROM ads.ads_sup_staff_performance_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(staff_order_qty) FROM dws.dws_sup_staff_operate_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1358 [弱][一致性] 对账：staff_pay_1d_amt 与 dws_sup_staff_operate_di.staff_pay_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(staff_pay_1d_amt) FROM ads.ads_sup_staff_performance_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(staff_pay_amt) FROM dws.dws_sup_staff_operate_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1359 [弱][一致性] 对账：staff_verify_1d_qty 与 dws_sup_staff_operate_di.staff_verify_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(staff_verify_1d_qty) FROM ads.ads_sup_staff_performance_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(staff_verify_qty) FROM dws.dws_sup_staff_operate_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1360 [弱][一致性] 对账：staff_refund_1d_qty 与 dws_sup_staff_operate_di.staff_refund_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(staff_refund_1d_qty) FROM ads.ads_sup_staff_performance_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(staff_refund_qty) FROM dws.dws_sup_staff_operate_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_sup_platform_overview_di  平台经营大盘 质检 ====================
-- R1187 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}';

-- R1188 [弱][有效性] 金额/数量非负（36 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_1d_amt < 0 THEN 1 ELSE 0 END) AS pay_1d_amt_neg,
  SUM(CASE WHEN pay_7d_amt < 0 THEN 1 ELSE 0 END) AS pay_7d_amt_neg,
  SUM(CASE WHEN pay_30d_amt < 0 THEN 1 ELSE 0 END) AS pay_30d_amt_neg,
  SUM(CASE WHEN pay_mtd_amt < 0 THEN 1 ELSE 0 END) AS pay_mtd_amt_neg,
  SUM(CASE WHEN pay_ytd_amt < 0 THEN 1 ELSE 0 END) AS pay_ytd_amt_neg,
  SUM(CASE WHEN verify_ticket_1d_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_1d_qty_neg,
  SUM(CASE WHEN verify_ticket_7d_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_7d_qty_neg,
  SUM(CASE WHEN verify_ticket_30d_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_30d_qty_neg,
  SUM(CASE WHEN verify_ticket_mtd_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_mtd_qty_neg,
  SUM(CASE WHEN verify_ticket_ytd_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_ytd_qty_neg,
  SUM(CASE WHEN active_tenant_1d_qty < 0 THEN 1 ELSE 0 END) AS active_tenant_1d_qty_neg,
  SUM(CASE WHEN active_tenant_7d_qty < 0 THEN 1 ELSE 0 END) AS active_tenant_7d_qty_neg,
  SUM(CASE WHEN active_tenant_30d_qty < 0 THEN 1 ELSE 0 END) AS active_tenant_30d_qty_neg,
  SUM(CASE WHEN active_tenant_mtd_qty < 0 THEN 1 ELSE 0 END) AS active_tenant_mtd_qty_neg,
  SUM(CASE WHEN active_tenant_ytd_qty < 0 THEN 1 ELSE 0 END) AS active_tenant_ytd_qty_neg,
  SUM(CASE WHEN new_tenant_1d_qty < 0 THEN 1 ELSE 0 END) AS new_tenant_1d_qty_neg,
  SUM(CASE WHEN new_tenant_7d_qty < 0 THEN 1 ELSE 0 END) AS new_tenant_7d_qty_neg,
  SUM(CASE WHEN new_tenant_30d_qty < 0 THEN 1 ELSE 0 END) AS new_tenant_30d_qty_neg,
  SUM(CASE WHEN new_tenant_mtd_qty < 0 THEN 1 ELSE 0 END) AS new_tenant_mtd_qty_neg,
  SUM(CASE WHEN new_tenant_ytd_qty < 0 THEN 1 ELSE 0 END) AS new_tenant_ytd_qty_neg,
  SUM(CASE WHEN new_customer_1d_qty < 0 THEN 1 ELSE 0 END) AS new_customer_1d_qty_neg,
  SUM(CASE WHEN new_customer_7d_qty < 0 THEN 1 ELSE 0 END) AS new_customer_7d_qty_neg,
  SUM(CASE WHEN new_customer_30d_qty < 0 THEN 1 ELSE 0 END) AS new_customer_30d_qty_neg,
  SUM(CASE WHEN new_customer_mtd_qty < 0 THEN 1 ELSE 0 END) AS new_customer_mtd_qty_neg,
  SUM(CASE WHEN new_customer_ytd_qty < 0 THEN 1 ELSE 0 END) AS new_customer_ytd_qty_neg,
  SUM(CASE WHEN pay_buyer_1d_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_1d_qty_neg,
  SUM(CASE WHEN pay_buyer_7d_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_7d_qty_neg,
  SUM(CASE WHEN pay_buyer_30d_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_30d_qty_neg,
  SUM(CASE WHEN pay_buyer_mtd_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_mtd_qty_neg,
  SUM(CASE WHEN pay_buyer_ytd_qty < 0 THEN 1 ELSE 0 END) AS pay_buyer_ytd_qty_neg,
  SUM(CASE WHEN tenant_cert_apply_1d_qty < 0 THEN 1 ELSE 0 END) AS tenant_cert_apply_1d_qty_neg,
  SUM(CASE WHEN tenant_cert_apply_7d_qty < 0 THEN 1 ELSE 0 END) AS tenant_cert_apply_7d_qty_neg,
  SUM(CASE WHEN tenant_cert_apply_30d_qty < 0 THEN 1 ELSE 0 END) AS tenant_cert_apply_30d_qty_neg,
  SUM(CASE WHEN tenant_cert_pass_1d_qty < 0 THEN 1 ELSE 0 END) AS tenant_cert_pass_1d_qty_neg,
  SUM(CASE WHEN tenant_cert_pass_7d_qty < 0 THEN 1 ELSE 0 END) AS tenant_cert_pass_7d_qty_neg,
  SUM(CASE WHEN tenant_cert_pass_30d_qty < 0 THEN 1 ELSE 0 END) AS tenant_cert_pass_30d_qty_neg
FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}';

-- R1189 [弱][有效性] 比率值域（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN tenant_cert_pass_1d_rate < 0 THEN 1 ELSE 0 END) AS tenant_cert_pass_1d_rate_bad,
  SUM(CASE WHEN tenant_cert_pass_7d_rate < 0 THEN 1 ELSE 0 END) AS tenant_cert_pass_7d_rate_bad,
  SUM(CASE WHEN tenant_cert_pass_30d_rate < 0 THEN 1 ELSE 0 END) AS tenant_cert_pass_30d_rate_bad,
  SUM(CASE WHEN sku_sell_1d_rate < 0 THEN 1 ELSE 0 END) AS sku_sell_1d_rate_bad,
  SUM(CASE WHEN sku_sell_7d_rate < 0 THEN 1 ELSE 0 END) AS sku_sell_7d_rate_bad,
  SUM(CASE WHEN sku_sell_30d_rate < 0 THEN 1 ELSE 0 END) AS sku_sell_30d_rate_bad
FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}';

-- R1190 [弱][及时性/波动] pay_1d_amt 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, SUM(pay_1d_amt) AS v FROM ads.ads_sup_platform_overview_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1288 [弱][一致性] 勾稽：tenant_cert_pass_1d_rate = tenant_cert_pass_1d_qty × 100 / tenant_cert_apply_1d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}' AND tenant_cert_apply_1d_qty <> 0
  AND ABS(tenant_cert_pass_1d_rate - ROUND(tenant_cert_pass_1d_qty * 100 / tenant_cert_apply_1d_qty, 6)) > 0.000001;

-- R1289 [弱][一致性] 勾稽：tenant_cert_pass_7d_rate = tenant_cert_pass_7d_qty × 100 / tenant_cert_apply_7d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}' AND tenant_cert_apply_7d_qty <> 0
  AND ABS(tenant_cert_pass_7d_rate - ROUND(tenant_cert_pass_7d_qty * 100 / tenant_cert_apply_7d_qty, 6)) > 0.000001;

-- R1290 [弱][一致性] 勾稽：tenant_cert_pass_30d_rate = tenant_cert_pass_30d_qty × 100 / tenant_cert_apply_30d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}' AND tenant_cert_apply_30d_qty <> 0
  AND ABS(tenant_cert_pass_30d_rate - ROUND(tenant_cert_pass_30d_qty * 100 / tenant_cert_apply_30d_qty, 6)) > 0.000001;

-- R1361 [弱][一致性] 对账：pay_1d_amt 与 dws_sup_tenant_trade_di.pay_amt 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(pay_1d_amt) FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(pay_amt) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1362 [弱][一致性] 对账：verify_ticket_1d_qty 与 dws_sup_tenant_trade_di.verify_ticket_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(verify_ticket_1d_qty) FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(verify_ticket_qty) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1363 [弱][一致性] 对账：new_tenant_1d_qty 与 dws_sup_tenant_onboard_di.new_tenant_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(new_tenant_1d_qty) FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(new_tenant_qty) FROM dws.dws_sup_tenant_onboard_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1364 [弱][一致性] 对账：new_customer_1d_qty 与 dws_sup_tenant_trade_di.new_customer_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(new_customer_1d_qty) FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(new_customer_qty) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1365 [弱][一致性] 对账：pay_buyer_1d_qty 与 dws_sup_tenant_trade_di.pay_buyer_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(pay_buyer_1d_qty) FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(pay_buyer_qty) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1366 [弱][一致性] 对账：tenant_cert_apply_1d_qty 与 dws_sup_tenant_onboard_di.tenant_cert_apply_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(tenant_cert_apply_1d_qty) FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(tenant_cert_apply_qty) FROM dws.dws_sup_tenant_onboard_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1367 [弱][一致性] 对账：tenant_cert_pass_1d_qty 与 dws_sup_tenant_onboard_di.tenant_cert_pass_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(tenant_cert_pass_1d_qty) FROM ads.ads_sup_platform_overview_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(tenant_cert_pass_qty) FROM dws.dws_sup_tenant_onboard_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_sup_tenant_lifecycle_df  商户生命周期（活跃/沉默/流失） 质检 ====================
-- R1191 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_sup_tenant_lifecycle_df WHERE travel_date = '${bizdate}';

-- R1192 [强][唯一性] 主键/粒度唯一（tenant_lifecycle_stage_code）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_lifecycle_stage_code, COUNT(*) AS c FROM ads.ads_sup_tenant_lifecycle_df WHERE travel_date = '${bizdate}' GROUP BY tenant_lifecycle_stage_code HAVING COUNT(*) > 1
) x;

-- R1193 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_sup_tenant_lifecycle_df WHERE travel_date = '${bizdate}' AND (tenant_lifecycle_stage_code IS NULL);

-- R1194 [弱][有效性] 金额/数量非负（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN active_tenant_30d_qty < 0 THEN 1 ELSE 0 END) AS active_tenant_30d_qty_neg,
  SUM(CASE WHEN silent_tenant_30d_qty < 0 THEN 1 ELSE 0 END) AS silent_tenant_30d_qty_neg,
  SUM(CASE WHEN churn_tenant_90d_qty < 0 THEN 1 ELSE 0 END) AS churn_tenant_90d_qty_neg
FROM ads.ads_sup_tenant_lifecycle_df WHERE travel_date = '${bizdate}';

-- R1195 [弱][有效性] 比率值域（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN tenant_active_30d_rate < 0 OR tenant_active_30d_rate > 100 THEN 1 ELSE 0 END) AS tenant_active_30d_rate_bad
FROM ads.ads_sup_tenant_lifecycle_df WHERE travel_date = '${bizdate}';

-- R1196 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_sup_tenant_lifecycle_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- ==================== dq.ads_opr_risk_monitor_di  风控监控 质检 ====================
-- R1202 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}';

-- R1203 [强][唯一性] 主键/粒度唯一（rule_id + action_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT rule_id, action_type, COUNT(*) AS c FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}' GROUP BY rule_id, action_type HAVING COUNT(*) > 1
) x;

-- R1204 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}' AND (rule_id IS NULL OR action_type IS NULL);

-- R1205 [弱][有效性] 金额/数量非负（18 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN risk_hit_1d_qty < 0 THEN 1 ELSE 0 END) AS risk_hit_1d_qty_neg,
  SUM(CASE WHEN risk_hit_7d_qty < 0 THEN 1 ELSE 0 END) AS risk_hit_7d_qty_neg,
  SUM(CASE WHEN risk_hit_30d_qty < 0 THEN 1 ELSE 0 END) AS risk_hit_30d_qty_neg,
  SUM(CASE WHEN risk_block_1d_qty < 0 THEN 1 ELSE 0 END) AS risk_block_1d_qty_neg,
  SUM(CASE WHEN risk_block_7d_qty < 0 THEN 1 ELSE 0 END) AS risk_block_7d_qty_neg,
  SUM(CASE WHEN risk_block_30d_qty < 0 THEN 1 ELSE 0 END) AS risk_block_30d_qty_neg,
  SUM(CASE WHEN blacklist_add_1d_qty < 0 THEN 1 ELSE 0 END) AS blacklist_add_1d_qty_neg,
  SUM(CASE WHEN blacklist_add_7d_qty < 0 THEN 1 ELSE 0 END) AS blacklist_add_7d_qty_neg,
  SUM(CASE WHEN blacklist_add_30d_qty < 0 THEN 1 ELSE 0 END) AS blacklist_add_30d_qty_neg,
  SUM(CASE WHEN ban_1d_qty < 0 THEN 1 ELSE 0 END) AS ban_1d_qty_neg,
  SUM(CASE WHEN ban_7d_qty < 0 THEN 1 ELSE 0 END) AS ban_7d_qty_neg,
  SUM(CASE WHEN ban_30d_qty < 0 THEN 1 ELSE 0 END) AS ban_30d_qty_neg,
  SUM(CASE WHEN night_action_1d_qty < 0 THEN 1 ELSE 0 END) AS night_action_1d_qty_neg,
  SUM(CASE WHEN night_action_7d_qty < 0 THEN 1 ELSE 0 END) AS night_action_7d_qty_neg,
  SUM(CASE WHEN night_action_30d_qty < 0 THEN 1 ELSE 0 END) AS night_action_30d_qty_neg,
  SUM(CASE WHEN duplicate_verify_1d_qty < 0 THEN 1 ELSE 0 END) AS duplicate_verify_1d_qty_neg,
  SUM(CASE WHEN duplicate_verify_7d_qty < 0 THEN 1 ELSE 0 END) AS duplicate_verify_7d_qty_neg,
  SUM(CASE WHEN duplicate_verify_30d_qty < 0 THEN 1 ELSE 0 END) AS duplicate_verify_30d_qty_neg
FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}';

-- R1206 [弱][有效性] 比率值域（3 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN risk_block_1d_rate < 0 THEN 1 ELSE 0 END) AS risk_block_1d_rate_bad,
  SUM(CASE WHEN risk_block_7d_rate < 0 THEN 1 ELSE 0 END) AS risk_block_7d_rate_bad,
  SUM(CASE WHEN risk_block_30d_rate < 0 THEN 1 ELSE 0 END) AS risk_block_30d_rate_bad
FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}';

-- R1207 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_opr_risk_monitor_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1291 [弱][一致性] 勾稽：risk_block_1d_rate = risk_block_1d_qty × 100 / risk_hit_1d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}' AND risk_hit_1d_qty <> 0
  AND ABS(risk_block_1d_rate - ROUND(risk_block_1d_qty * 100 / risk_hit_1d_qty, 6)) > 0.000001;

-- R1292 [弱][一致性] 勾稽：risk_block_7d_rate = risk_block_7d_qty × 100 / risk_hit_7d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}' AND risk_hit_7d_qty <> 0
  AND ABS(risk_block_7d_rate - ROUND(risk_block_7d_qty * 100 / risk_hit_7d_qty, 6)) > 0.000001;

-- R1293 [弱][一致性] 勾稽：risk_block_30d_rate = risk_block_30d_qty × 100 / risk_hit_30d_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}' AND risk_hit_30d_qty <> 0
  AND ABS(risk_block_30d_rate - ROUND(risk_block_30d_qty * 100 / risk_hit_30d_qty, 6)) > 0.000001;

-- R1368 [弱][一致性] 对账：risk_hit_1d_qty 与 dws_opr_risk_rule_hit_di.risk_hit_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(risk_hit_1d_qty) FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(risk_hit_qty) FROM dws.dws_opr_risk_rule_hit_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1369 [弱][一致性] 对账：risk_block_1d_qty 与 dws_opr_risk_rule_hit_di.risk_block_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(risk_block_1d_qty) FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(risk_block_qty) FROM dws.dws_opr_risk_rule_hit_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1370 [弱][一致性] 对账：blacklist_add_1d_qty 与 dws_opr_risk_rule_hit_di.blacklist_add_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(blacklist_add_1d_qty) FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(blacklist_add_qty) FROM dws.dws_opr_risk_rule_hit_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1371 [弱][一致性] 对账：ban_1d_qty 与 dws_opr_risk_rule_hit_di.ban_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(ban_1d_qty) FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(ban_qty) FROM dws.dws_opr_risk_rule_hit_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1372 [弱][一致性] 对账：night_action_1d_qty 与 dws_opr_audit_action_di.night_action_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(night_action_1d_qty) FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(night_action_qty) FROM dws.dws_opr_audit_action_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1373 [弱][一致性] 对账：duplicate_verify_1d_qty 与 dws_ord_tenant_sku_verify_di.duplicate_verify_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(duplicate_verify_1d_qty) FROM ads.ads_opr_risk_monitor_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(duplicate_verify_qty) FROM dws.dws_ord_tenant_sku_verify_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_opr_device_health_di  设备健康 质检 ====================
-- R1208 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_opr_device_health_di WHERE travel_date = '${bizdate}';

-- R1209 [强][唯一性] 主键/粒度唯一（tenant_id + device_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, device_type, COUNT(*) AS c FROM ads.ads_opr_device_health_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, device_type HAVING COUNT(*) > 1
) x;

-- R1210 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_opr_device_health_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR device_type IS NULL);

-- R1211 [弱][有效性] 金额/数量非负（7 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN offline_times_1d_qty < 0 THEN 1 ELSE 0 END) AS offline_times_1d_qty_neg,
  SUM(CASE WHEN offline_times_7d_qty < 0 THEN 1 ELSE 0 END) AS offline_times_7d_qty_neg,
  SUM(CASE WHEN offline_times_30d_qty < 0 THEN 1 ELSE 0 END) AS offline_times_30d_qty_neg,
  SUM(CASE WHEN offline_conflict_1d_qty < 0 THEN 1 ELSE 0 END) AS offline_conflict_1d_qty_neg,
  SUM(CASE WHEN offline_conflict_7d_qty < 0 THEN 1 ELSE 0 END) AS offline_conflict_7d_qty_neg,
  SUM(CASE WHEN offline_conflict_30d_qty < 0 THEN 1 ELSE 0 END) AS offline_conflict_30d_qty_neg,
  SUM(CASE WHEN device_total_td_qty < 0 THEN 1 ELSE 0 END) AS device_total_td_qty_neg
FROM ads.ads_opr_device_health_di WHERE travel_date = '${bizdate}';

-- R1212 [弱][有效性] 比率值域（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN device_online_1d_rate < 0 OR device_online_1d_rate > 100 THEN 1 ELSE 0 END) AS device_online_1d_rate_bad,
  SUM(CASE WHEN device_online_7d_rate < 0 OR device_online_7d_rate > 100 THEN 1 ELSE 0 END) AS device_online_7d_rate_bad,
  SUM(CASE WHEN device_online_30d_rate < 0 OR device_online_30d_rate > 100 THEN 1 ELSE 0 END) AS device_online_30d_rate_bad,
  SUM(CASE WHEN offline_verify_1d_rate < 0 THEN 1 ELSE 0 END) AS offline_verify_1d_rate_bad,
  SUM(CASE WHEN offline_verify_7d_rate < 0 THEN 1 ELSE 0 END) AS offline_verify_7d_rate_bad,
  SUM(CASE WHEN offline_verify_30d_rate < 0 THEN 1 ELSE 0 END) AS offline_verify_30d_rate_bad
FROM ads.ads_opr_device_health_di WHERE travel_date = '${bizdate}';

-- R1213 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_opr_device_health_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1374 [弱][一致性] 对账：offline_times_1d_qty 与 dws_opr_device_di.offline_times_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(offline_times_1d_qty) FROM ads.ads_opr_device_health_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(offline_times_qty) FROM dws.dws_opr_device_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1375 [弱][一致性] 对账：offline_conflict_1d_qty 与 dws_ord_tenant_sku_verify_di.offline_conflict_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(offline_conflict_1d_qty) FROM ads.ads_opr_device_health_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(offline_conflict_qty) FROM dws.dws_ord_tenant_sku_verify_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_opr_complaint_sla_di  投诉SLA与审批时效 质检 ====================
-- R1214 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_opr_complaint_sla_di WHERE travel_date = '${bizdate}';

-- R1215 [强][唯一性] 主键/粒度唯一（tenant_id + complaint_type）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, complaint_type, COUNT(*) AS c FROM ads.ads_opr_complaint_sla_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id, complaint_type HAVING COUNT(*) > 1
) x;

-- R1216 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_opr_complaint_sla_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR complaint_type IS NULL);

-- R1217 [弱][有效性] 金额/数量非负（18 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN complaint_1d_qty < 0 THEN 1 ELSE 0 END) AS complaint_1d_qty_neg,
  SUM(CASE WHEN complaint_7d_qty < 0 THEN 1 ELSE 0 END) AS complaint_7d_qty_neg,
  SUM(CASE WHEN complaint_30d_qty < 0 THEN 1 ELSE 0 END) AS complaint_30d_qty_neg,
  SUM(CASE WHEN complaint_resolved_1d_qty < 0 THEN 1 ELSE 0 END) AS complaint_resolved_1d_qty_neg,
  SUM(CASE WHEN complaint_resolved_7d_qty < 0 THEN 1 ELSE 0 END) AS complaint_resolved_7d_qty_neg,
  SUM(CASE WHEN complaint_resolved_30d_qty < 0 THEN 1 ELSE 0 END) AS complaint_resolved_30d_qty_neg,
  SUM(CASE WHEN complaint_overdue_1d_qty < 0 THEN 1 ELSE 0 END) AS complaint_overdue_1d_qty_neg,
  SUM(CASE WHEN complaint_overdue_7d_qty < 0 THEN 1 ELSE 0 END) AS complaint_overdue_7d_qty_neg,
  SUM(CASE WHEN complaint_overdue_30d_qty < 0 THEN 1 ELSE 0 END) AS complaint_overdue_30d_qty_neg,
  SUM(CASE WHEN approval_1d_qty < 0 THEN 1 ELSE 0 END) AS approval_1d_qty_neg,
  SUM(CASE WHEN approval_7d_qty < 0 THEN 1 ELSE 0 END) AS approval_7d_qty_neg,
  SUM(CASE WHEN approval_30d_qty < 0 THEN 1 ELSE 0 END) AS approval_30d_qty_neg,
  SUM(CASE WHEN approval_timeout_1d_qty < 0 THEN 1 ELSE 0 END) AS approval_timeout_1d_qty_neg,
  SUM(CASE WHEN approval_timeout_7d_qty < 0 THEN 1 ELSE 0 END) AS approval_timeout_7d_qty_neg,
  SUM(CASE WHEN approval_timeout_30d_qty < 0 THEN 1 ELSE 0 END) AS approval_timeout_30d_qty_neg,
  SUM(CASE WHEN avg_approval_minute_1d_qty < 0 THEN 1 ELSE 0 END) AS avg_approval_minute_1d_qty_neg,
  SUM(CASE WHEN avg_approval_minute_7d_qty < 0 THEN 1 ELSE 0 END) AS avg_approval_minute_7d_qty_neg,
  SUM(CASE WHEN avg_approval_minute_30d_qty < 0 THEN 1 ELSE 0 END) AS avg_approval_minute_30d_qty_neg
FROM ads.ads_opr_complaint_sla_di WHERE travel_date = '${bizdate}';

-- R1218 [弱][有效性] 比率值域（6 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN complaint_sla_1d_rate < 0 THEN 1 ELSE 0 END) AS complaint_sla_1d_rate_bad,
  SUM(CASE WHEN complaint_sla_7d_rate < 0 THEN 1 ELSE 0 END) AS complaint_sla_7d_rate_bad,
  SUM(CASE WHEN complaint_sla_30d_rate < 0 THEN 1 ELSE 0 END) AS complaint_sla_30d_rate_bad,
  SUM(CASE WHEN approval_pass_1d_rate < 0 THEN 1 ELSE 0 END) AS approval_pass_1d_rate_bad,
  SUM(CASE WHEN approval_pass_7d_rate < 0 THEN 1 ELSE 0 END) AS approval_pass_7d_rate_bad,
  SUM(CASE WHEN approval_pass_30d_rate < 0 THEN 1 ELSE 0 END) AS approval_pass_30d_rate_bad
FROM ads.ads_opr_complaint_sla_di WHERE travel_date = '${bizdate}';

-- R1219 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_opr_complaint_sla_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1376 [弱][一致性] 对账：complaint_1d_qty 与 dws_opr_complaint_di.complaint_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(complaint_1d_qty) FROM ads.ads_opr_complaint_sla_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(complaint_qty) FROM dws.dws_opr_complaint_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1377 [弱][一致性] 对账：complaint_resolved_1d_qty 与 dws_opr_complaint_di.complaint_resolved_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(complaint_resolved_1d_qty) FROM ads.ads_opr_complaint_sla_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(complaint_resolved_qty) FROM dws.dws_opr_complaint_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1378 [弱][一致性] 对账：complaint_overdue_1d_qty 与 dws_opr_complaint_di.complaint_overdue_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(complaint_overdue_1d_qty) FROM ads.ads_opr_complaint_sla_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(complaint_overdue_qty) FROM dws.dws_opr_complaint_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1379 [弱][一致性] 对账：approval_1d_qty 与 dws_opr_approval_di.approval_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(approval_1d_qty) FROM ads.ads_opr_complaint_sla_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(approval_qty) FROM dws.dws_opr_approval_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1380 [弱][一致性] 对账：approval_timeout_1d_qty 与 dws_opr_approval_di.approval_timeout_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(approval_timeout_1d_qty) FROM ads.ads_opr_complaint_sla_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(approval_timeout_qty) FROM dws.dws_opr_approval_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_opr_notify_cost_di  通知与短信消耗 质检 ====================
-- R1220 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_opr_notify_cost_di WHERE travel_date = '${bizdate}';

-- R1221 [强][唯一性] 主键/粒度唯一（tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, COUNT(*) AS c FROM ads.ads_opr_notify_cost_di WHERE travel_date = '${bizdate}' GROUP BY tenant_id HAVING COUNT(*) > 1
) x;

-- R1222 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_opr_notify_cost_di WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL);

-- R1223 [弱][有效性] 金额/数量非负（20 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN sms_notify_send_1d_qty < 0 THEN 1 ELSE 0 END) AS sms_notify_send_1d_qty_neg,
  SUM(CASE WHEN sms_notify_send_7d_qty < 0 THEN 1 ELSE 0 END) AS sms_notify_send_7d_qty_neg,
  SUM(CASE WHEN sms_notify_send_30d_qty < 0 THEN 1 ELSE 0 END) AS sms_notify_send_30d_qty_neg,
  SUM(CASE WHEN mini_notify_send_1d_qty < 0 THEN 1 ELSE 0 END) AS mini_notify_send_1d_qty_neg,
  SUM(CASE WHEN mini_notify_send_7d_qty < 0 THEN 1 ELSE 0 END) AS mini_notify_send_7d_qty_neg,
  SUM(CASE WHEN mini_notify_send_30d_qty < 0 THEN 1 ELSE 0 END) AS mini_notify_send_30d_qty_neg,
  SUM(CASE WHEN email_notify_send_1d_qty < 0 THEN 1 ELSE 0 END) AS email_notify_send_1d_qty_neg,
  SUM(CASE WHEN email_notify_send_7d_qty < 0 THEN 1 ELSE 0 END) AS email_notify_send_7d_qty_neg,
  SUM(CASE WHEN email_notify_send_30d_qty < 0 THEN 1 ELSE 0 END) AS email_notify_send_30d_qty_neg,
  SUM(CASE WHEN webhook_notify_send_1d_qty < 0 THEN 1 ELSE 0 END) AS webhook_notify_send_1d_qty_neg,
  SUM(CASE WHEN webhook_notify_send_7d_qty < 0 THEN 1 ELSE 0 END) AS webhook_notify_send_7d_qty_neg,
  SUM(CASE WHEN webhook_notify_send_30d_qty < 0 THEN 1 ELSE 0 END) AS webhook_notify_send_30d_qty_neg,
  SUM(CASE WHEN resource_consume_1d_qty < 0 THEN 1 ELSE 0 END) AS resource_consume_1d_qty_neg,
  SUM(CASE WHEN resource_consume_7d_qty < 0 THEN 1 ELSE 0 END) AS resource_consume_7d_qty_neg,
  SUM(CASE WHEN resource_consume_30d_qty < 0 THEN 1 ELSE 0 END) AS resource_consume_30d_qty_neg,
  SUM(CASE WHEN resource_consume_mtd_qty < 0 THEN 1 ELSE 0 END) AS resource_consume_mtd_qty_neg,
  SUM(CASE WHEN resource_consume_ytd_qty < 0 THEN 1 ELSE 0 END) AS resource_consume_ytd_qty_neg,
  SUM(CASE WHEN notify_fail_1d_qty < 0 THEN 1 ELSE 0 END) AS notify_fail_1d_qty_neg,
  SUM(CASE WHEN notify_fail_7d_qty < 0 THEN 1 ELSE 0 END) AS notify_fail_7d_qty_neg,
  SUM(CASE WHEN notify_fail_30d_qty < 0 THEN 1 ELSE 0 END) AS notify_fail_30d_qty_neg
FROM ads.ads_opr_notify_cost_di WHERE travel_date = '${bizdate}';

-- R1224 [弱][有效性] 比率值域（12 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN sms_notify_success_1d_rate < 0 THEN 1 ELSE 0 END) AS sms_notify_success_1d_rate_bad,
  SUM(CASE WHEN sms_notify_success_7d_rate < 0 THEN 1 ELSE 0 END) AS sms_notify_success_7d_rate_bad,
  SUM(CASE WHEN sms_notify_success_30d_rate < 0 THEN 1 ELSE 0 END) AS sms_notify_success_30d_rate_bad,
  SUM(CASE WHEN mini_notify_success_1d_rate < 0 THEN 1 ELSE 0 END) AS mini_notify_success_1d_rate_bad,
  SUM(CASE WHEN mini_notify_success_7d_rate < 0 THEN 1 ELSE 0 END) AS mini_notify_success_7d_rate_bad,
  SUM(CASE WHEN mini_notify_success_30d_rate < 0 THEN 1 ELSE 0 END) AS mini_notify_success_30d_rate_bad,
  SUM(CASE WHEN email_notify_success_1d_rate < 0 THEN 1 ELSE 0 END) AS email_notify_success_1d_rate_bad,
  SUM(CASE WHEN email_notify_success_7d_rate < 0 THEN 1 ELSE 0 END) AS email_notify_success_7d_rate_bad,
  SUM(CASE WHEN email_notify_success_30d_rate < 0 THEN 1 ELSE 0 END) AS email_notify_success_30d_rate_bad,
  SUM(CASE WHEN webhook_notify_success_1d_rate < 0 THEN 1 ELSE 0 END) AS webhook_notify_success_1d_rate_bad,
  SUM(CASE WHEN webhook_notify_success_7d_rate < 0 THEN 1 ELSE 0 END) AS webhook_notify_success_7d_rate_bad,
  SUM(CASE WHEN webhook_notify_success_30d_rate < 0 THEN 1 ELSE 0 END) AS webhook_notify_success_30d_rate_bad
FROM ads.ads_opr_notify_cost_di WHERE travel_date = '${bizdate}';

-- R1225 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_opr_notify_cost_di
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1381 [弱][一致性] 对账：resource_consume_1d_qty 与 dws_opr_notify_di.resource_consume_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(resource_consume_1d_qty) FROM ads.ads_opr_notify_cost_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(resource_consume_qty) FROM dws.dws_opr_notify_di WHERE travel_date = '${bizdate}') AS dws_v;

-- R1382 [弱][一致性] 对账：notify_fail_1d_qty 与 dws_opr_notify_di.notify_fail_qty 合计一致；期望：|ads_v − dws_v| ≤ 0.01
SELECT (SELECT SUM(notify_fail_1d_qty) FROM ads.ads_opr_notify_cost_di WHERE travel_date = '${bizdate}') AS ads_v,
       (SELECT SUM(notify_fail_qty) FROM dws.dws_opr_notify_di WHERE travel_date = '${bizdate}') AS dws_v;

-- ==================== dq.ads_opr_code_pool_usage_df  码池使用 质检 ====================
-- R1226 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_opr_code_pool_usage_df WHERE travel_date = '${bizdate}';

-- R1227 [强][唯一性] 主键/粒度唯一（tenant_id + code_pool_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT tenant_id, code_pool_id, COUNT(*) AS c FROM ads.ads_opr_code_pool_usage_df WHERE travel_date = '${bizdate}' GROUP BY tenant_id, code_pool_id HAVING COUNT(*) > 1
) x;

-- R1228 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_opr_code_pool_usage_df WHERE travel_date = '${bizdate}' AND (tenant_id IS NULL OR code_pool_id IS NULL);

-- R1229 [弱][有效性] 金额/数量非负（9 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN code_capacity_td_qty < 0 THEN 1 ELSE 0 END) AS code_capacity_td_qty_neg,
  SUM(CASE WHEN code_allocated_td_qty < 0 THEN 1 ELSE 0 END) AS code_allocated_td_qty_neg,
  SUM(CASE WHEN code_recycled_td_qty < 0 THEN 1 ELSE 0 END) AS code_recycled_td_qty_neg,
  SUM(CASE WHEN issue_credential_1d_qty < 0 THEN 1 ELSE 0 END) AS issue_credential_1d_qty_neg,
  SUM(CASE WHEN issue_credential_7d_qty < 0 THEN 1 ELSE 0 END) AS issue_credential_7d_qty_neg,
  SUM(CASE WHEN issue_credential_30d_qty < 0 THEN 1 ELSE 0 END) AS issue_credential_30d_qty_neg,
  SUM(CASE WHEN revoke_credential_1d_qty < 0 THEN 1 ELSE 0 END) AS revoke_credential_1d_qty_neg,
  SUM(CASE WHEN revoke_credential_7d_qty < 0 THEN 1 ELSE 0 END) AS revoke_credential_7d_qty_neg,
  SUM(CASE WHEN revoke_credential_30d_qty < 0 THEN 1 ELSE 0 END) AS revoke_credential_30d_qty_neg
FROM ads.ads_opr_code_pool_usage_df WHERE travel_date = '${bizdate}';

-- R1230 [弱][有效性] 比率值域（2 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN code_pool_usage_td_rate < 0 OR code_pool_usage_td_rate > 100 THEN 1 ELSE 0 END) AS code_pool_usage_td_rate_bad,
  SUM(CASE WHEN code_recycle_td_rate < 0 OR code_recycle_td_rate > 100 THEN 1 ELSE 0 END) AS code_recycle_td_rate_bad
FROM ads.ads_opr_code_pool_usage_df WHERE travel_date = '${bizdate}';

-- R1231 [弱][及时性/波动] 行数 与近 7 日均值相比波动 ≤ 50%；期望：avg7 = 0 或 |cur / avg7 − 1| ≤ 50%
WITH d AS (
  SELECT travel_date, COUNT(*) AS v FROM ads.ads_opr_code_pool_usage_df
  WHERE travel_date BETWEEN '${bizdate_minus_7}' AND '${bizdate}' GROUP BY travel_date
)
SELECT MAX(CASE WHEN travel_date = '${bizdate}' THEN v END) AS cur,
       AVG(CASE WHEN travel_date < '${bizdate}' THEN v END) AS avg7
FROM d;

-- R1294 [弱][一致性] 勾稽：code_pool_usage_td_rate = code_allocated_td_qty × 100 / code_capacity_td_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_opr_code_pool_usage_df WHERE travel_date = '${bizdate}' AND code_capacity_td_qty <> 0
  AND ABS(code_pool_usage_td_rate - ROUND(code_allocated_td_qty * 100 / code_capacity_td_qty, 6)) > 0.000001;

-- R1295 [弱][一致性] 勾稽：code_recycle_td_rate = code_recycled_td_qty × 100 / code_allocated_td_qty；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_opr_code_pool_usage_df WHERE travel_date = '${bizdate}' AND code_allocated_td_qty <> 0
  AND ABS(code_recycle_td_rate - ROUND(code_recycled_td_qty * 100 / code_allocated_td_qty, 6)) > 0.000001;

-- ==================== dq.recon.dws_ord_tenant_sku_trade_rt  实时/离线对账：商户×SKU 分钟级交易 ====================
-- R1383 [弱][一致性] 实时 dws_ord_tenant_sku_trade_rt.pay_amt 与离线 dws_sup_tenant_trade_di.pay_amt 对账；期望：|实时 − 离线| / 离线 ≤ 0.5%
-- StarRocks 实时
SELECT SUM(pay_amt) FROM dws.dws_ord_tenant_sku_trade_rt WHERE travel_date = '${bizdate}';
-- Hive 离线
SELECT SUM(pay_amt) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}';

-- R1384 [弱][一致性] 实时 dws_ord_tenant_sku_trade_rt.pay_order_qty 与离线 dws_sup_tenant_trade_di.pay_order_qty 对账；期望：|实时 − 离线| / 离线 ≤ 0.5%
-- StarRocks 实时
SELECT SUM(pay_order_qty) FROM dws.dws_ord_tenant_sku_trade_rt WHERE travel_date = '${bizdate}';
-- Hive 离线
SELECT SUM(pay_order_qty) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}';

-- R1385 [弱][一致性] 实时 dws_ord_tenant_sku_trade_rt.refund_amt 与离线 dws_sup_tenant_trade_di.refund_amt 对账；期望：|实时 − 离线| / 离线 ≤ 0.5%
-- StarRocks 实时
SELECT SUM(refund_amt) FROM dws.dws_ord_tenant_sku_trade_rt WHERE travel_date = '${bizdate}';
-- Hive 离线
SELECT SUM(refund_amt) FROM dws.dws_sup_tenant_trade_di WHERE travel_date = '${bizdate}';

-- ==================== dq.recon.dws_ord_verify_point_flow_rt  实时/离线对账：核销点 分钟级客流 ====================
-- R1386 [弱][一致性] 实时 dws_ord_verify_point_flow_rt.verify_person_qty 与离线 dws_ord_verify_point_flow_hrs.verify_person_qty 对账；期望：|实时 − 离线| / 离线 ≤ 0.5%
-- StarRocks 实时
SELECT SUM(verify_person_qty) FROM dws.dws_ord_verify_point_flow_rt WHERE travel_date = '${bizdate}';
-- Hive 离线
SELECT SUM(verify_person_qty) FROM dws.dws_ord_verify_point_flow_hrs WHERE travel_date = '${bizdate}';

-- ==================== dq.recon.dws_opr_risk_rule_hit_rt  实时/离线对账：风控规则 分钟级命中 ====================
-- R1387 [弱][一致性] 实时 dws_opr_risk_rule_hit_rt.risk_hit_qty 与离线 dws_opr_risk_rule_hit_di.risk_hit_qty 对账；期望：|实时 − 离线| / 离线 ≤ 0.5%
-- StarRocks 实时
SELECT SUM(risk_hit_qty) FROM dws.dws_opr_risk_rule_hit_rt WHERE travel_date = '${bizdate}';
-- Hive 离线
SELECT SUM(risk_hit_qty) FROM dws.dws_opr_risk_rule_hit_di WHERE travel_date = '${bizdate}';

-- ==================== dq.ads_sup_tenant_trade_wk  商户经营周报 质检 ====================
-- R1232 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_sup_tenant_trade_wk WHERE travel_date = '${bizdate}';

-- R1233 [强][唯一性] 主键/粒度唯一（stat_week_code + week_start_date + seller_tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT stat_week_code, week_start_date, seller_tenant_id, COUNT(*) AS c FROM ads.ads_sup_tenant_trade_wk WHERE travel_date = '${bizdate}' GROUP BY stat_week_code, week_start_date, seller_tenant_id HAVING COUNT(*) > 1
) x;

-- R1234 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_sup_tenant_trade_wk WHERE travel_date = '${bizdate}' AND (stat_week_code IS NULL OR week_start_date IS NULL OR seller_tenant_id IS NULL);

-- R1235 [弱][有效性] 金额/数量非负（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_1w_amt < 0 THEN 1 ELSE 0 END) AS pay_1w_amt_neg,
  SUM(CASE WHEN verify_ticket_1w_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_1w_qty_neg,
  SUM(CASE WHEN refund_1w_amt < 0 THEN 1 ELSE 0 END) AS refund_1w_amt_neg,
  SUM(CASE WHEN per_customer_1w_amt < 0 THEN 1 ELSE 0 END) AS per_customer_1w_amt_neg
FROM ads.ads_sup_tenant_trade_wk WHERE travel_date = '${bizdate}';

-- R1236 [弱][有效性] 比率值域（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN refund_1w_rate < 0 THEN 1 ELSE 0 END) AS refund_1w_rate_bad
FROM ads.ads_sup_tenant_trade_wk WHERE travel_date = '${bizdate}';

-- R1296 [强][一致性] 勾稽：net_pay_1w_amt = pay_1w_amt − refund_1w_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_sup_tenant_trade_wk WHERE travel_date = '${bizdate}' AND ABS(COALESCE(net_pay_1w_amt, 0) - (COALESCE(pay_1w_amt, 0) - COALESCE(refund_1w_amt, 0))) > 0.01;

-- ==================== dq.ads_opr_package_revenue_mo  套餐收入与续费（月） 质检 ====================
-- R1197 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_opr_package_revenue_mo WHERE travel_date = '${bizdate}';

-- R1198 [强][唯一性] 主键/粒度唯一（stat_month_code + package_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT stat_month_code, package_id, COUNT(*) AS c FROM ads.ads_opr_package_revenue_mo WHERE travel_date = '${bizdate}' GROUP BY stat_month_code, package_id HAVING COUNT(*) > 1
) x;

-- R1199 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_opr_package_revenue_mo WHERE travel_date = '${bizdate}' AND (stat_month_code IS NULL OR package_id IS NULL);

-- R1200 [弱][有效性] 金额/数量非负（5 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN package_1m_amt < 0 THEN 1 ELSE 0 END) AS package_1m_amt_neg,
  SUM(CASE WHEN package_renew_1m_qty < 0 THEN 1 ELSE 0 END) AS package_renew_1m_qty_neg,
  SUM(CASE WHEN active_subscription_1m_qty < 0 THEN 1 ELSE 0 END) AS active_subscription_1m_qty_neg,
  SUM(CASE WHEN expiring_30d_subscription_1m_qty < 0 THEN 1 ELSE 0 END) AS expiring_30d_subscription_1m_qty_neg,
  SUM(CASE WHEN package_ytd_amt < 0 THEN 1 ELSE 0 END) AS package_ytd_amt_neg
FROM ads.ads_opr_package_revenue_mo WHERE travel_date = '${bizdate}';

-- R1201 [弱][有效性] 比率值域（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN package_renew_1m_rate < 0 THEN 1 ELSE 0 END) AS package_renew_1m_rate_bad
FROM ads.ads_opr_package_revenue_mo WHERE travel_date = '${bizdate}';

-- ==================== dq.ads_sup_tenant_trade_mo  商户经营月报 质检 ====================
-- R1237 [强][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM ads.ads_sup_tenant_trade_mo WHERE travel_date = '${bizdate}';

-- R1238 [强][唯一性] 主键/粒度唯一（stat_month_code + seller_tenant_id）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT stat_month_code, seller_tenant_id, COUNT(*) AS c FROM ads.ads_sup_tenant_trade_mo WHERE travel_date = '${bizdate}' GROUP BY stat_month_code, seller_tenant_id HAVING COUNT(*) > 1
) x;

-- R1239 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM ads.ads_sup_tenant_trade_mo WHERE travel_date = '${bizdate}' AND (stat_month_code IS NULL OR seller_tenant_id IS NULL);

-- R1240 [弱][有效性] 金额/数量非负（4 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN pay_1m_amt < 0 THEN 1 ELSE 0 END) AS pay_1m_amt_neg,
  SUM(CASE WHEN verify_ticket_1m_qty < 0 THEN 1 ELSE 0 END) AS verify_ticket_1m_qty_neg,
  SUM(CASE WHEN refund_1m_amt < 0 THEN 1 ELSE 0 END) AS refund_1m_amt_neg,
  SUM(CASE WHEN per_customer_1m_amt < 0 THEN 1 ELSE 0 END) AS per_customer_1m_amt_neg
FROM ads.ads_sup_tenant_trade_mo WHERE travel_date = '${bizdate}';

-- R1241 [弱][有效性] 比率值域（1 个字段）；期望：全部为 0
SELECT
  SUM(CASE WHEN refund_1m_rate < 0 THEN 1 ELSE 0 END) AS refund_1m_rate_bad
FROM ads.ads_sup_tenant_trade_mo WHERE travel_date = '${bizdate}';

-- R1297 [强][一致性] 勾稽：net_pay_1m_amt = pay_1m_amt − refund_1m_amt；期望：bad_cnt = 0
SELECT COUNT(*) AS bad_cnt FROM ads.ads_sup_tenant_trade_mo WHERE travel_date = '${bizdate}' AND ABS(COALESCE(net_pay_1m_amt, 0) - (COALESCE(pay_1m_amt, 0) - COALESCE(refund_1m_amt, 0))) > 0.01;

-- ==================== dq.dim_opr_date_f  日期维度 质检 ====================
-- R0820 [弱][完整性] 当日分区有数据；期望：cnt > 0
SELECT COUNT(*) AS cnt FROM dim.dim_opr_date_f WHERE 1 = 1;

-- R0821 [强][唯一性] 主键/粒度唯一（date_code）；期望：dup_cnt = 0
SELECT COUNT(*) AS dup_cnt FROM (
  SELECT date_code, COUNT(*) AS c FROM dim.dim_opr_date_f WHERE 1 = 1 GROUP BY date_code HAVING COUNT(*) > 1
) x;

-- R0822 [强][完整性] 主键/粒度键非空；期望：null_cnt = 0
SELECT COUNT(*) AS null_cnt FROM dim.dim_opr_date_f WHERE 1 = 1 AND (date_code IS NULL);

-- R0823 [弱][有效性] weekend_type 取值在枚举内；期望：无返回行
SELECT weekend_type, COUNT(*) AS cnt FROM dim.dim_opr_date_f WHERE 1 = 1 AND weekend_type NOT IN (0, 1) GROUP BY weekend_type;

-- R0824 [弱][有效性] holiday_type 取值在枚举内；期望：无返回行
SELECT holiday_type, COUNT(*) AS cnt FROM dim.dim_opr_date_f WHERE 1 = 1 AND holiday_type NOT IN (0, 1, 2, 3) GROUP BY holiday_type;

-- R0825 [弱][有效性] vacation_type 取值在枚举内；期望：无返回行
SELECT vacation_type, COUNT(*) AS cnt FROM dim.dim_opr_date_f WHERE 1 = 1 AND vacation_type NOT IN (0, 1, 2) GROUP BY vacation_type;

-- R0826 [弱][有效性] season_type 取值在枚举内；期望：无返回行
SELECT season_type, COUNT(*) AS cnt FROM dim.dim_opr_date_f WHERE 1 = 1 AND season_type NOT IN (1, 2, 3) GROUP BY season_type;

-- ==================== dq.ods_ord_order_group_rt  聚合单 binlog 流 监控 ====================
-- R1388 [强][及时性] CDC 采集延迟 ≤ 60 秒；期望：连续 3 分钟 > 60000 告警并电话通知
Flink 指标：currentFetchEventTimeLag（毫秒），按作业 flink_job_ord_realtime_sales 的源算子 ods_ord_order_group_rt 采集

-- R1389 [强][完整性] CDC 全量快照完成且进入增量；期望：启动后 30 分钟内进入增量阶段
Flink 指标：isSnapshotSplitFinished / sourceIdleTime

-- ==================== dq.ods_ord_order_rt  子单 binlog 流 监控 ====================
-- R1390 [强][及时性] CDC 采集延迟 ≤ 60 秒；期望：连续 3 分钟 > 60000 告警并电话通知
Flink 指标：currentFetchEventTimeLag（毫秒），按作业 flink_job_ord_realtime_sales 的源算子 ods_ord_order_rt 采集

-- R1391 [强][完整性] CDC 全量快照完成且进入增量；期望：启动后 30 分钟内进入增量阶段
Flink 指标：isSnapshotSplitFinished / sourceIdleTime

-- ==================== dq.ods_ord_entitlement_rt  权益 binlog 流 监控 ====================
-- R1392 [强][及时性] CDC 采集延迟 ≤ 60 秒；期望：连续 3 分钟 > 60000 告警并电话通知
Flink 指标：currentFetchEventTimeLag（毫秒），按作业 flink_job_opr_risk_alert 的源算子 ods_ord_entitlement_rt 采集

-- R1393 [强][完整性] CDC 全量快照完成且进入增量；期望：启动后 30 分钟内进入增量阶段
Flink 指标：isSnapshotSplitFinished / sourceIdleTime

-- ==================== dq.ods_ord_verify_record_rt  核销记录 binlog 流 监控 ====================
-- R1394 [强][及时性] CDC 采集延迟 ≤ 60 秒；期望：连续 3 分钟 > 60000 告警并电话通知
Flink 指标：currentFetchEventTimeLag（毫秒），按作业 flink_job_opr_risk_alert 的源算子 ods_ord_verify_record_rt 采集

-- R1395 [强][完整性] CDC 全量快照完成且进入增量；期望：启动后 30 分钟内进入增量阶段
Flink 指标：isSnapshotSplitFinished / sourceIdleTime

-- ==================== dq.ods_ord_refund_order_rt  退款单 binlog 流 监控 ====================
-- R1396 [强][及时性] CDC 采集延迟 ≤ 60 秒；期望：连续 3 分钟 > 60000 告警并电话通知
Flink 指标：currentFetchEventTimeLag（毫秒），按作业 flink_job_ord_realtime_sales 的源算子 ods_ord_refund_order_rt 采集

-- R1397 [强][完整性] CDC 全量快照完成且进入增量；期望：启动后 30 分钟内进入增量阶段
Flink 指标：isSnapshotSplitFinished / sourceIdleTime

-- ==================== dq.ods_fin_payment_record_rt  支付记录 binlog 流 监控 ====================
-- R1398 [强][及时性] CDC 采集延迟 ≤ 60 秒；期望：连续 3 分钟 > 60000 告警并电话通知
Flink 指标：currentFetchEventTimeLag（毫秒），按作业 flink_job_ord_realtime_sales 的源算子 ods_fin_payment_record_rt 采集

-- R1399 [强][完整性] CDC 全量快照完成且进入增量；期望：启动后 30 分钟内进入增量阶段
Flink 指标：isSnapshotSplitFinished / sourceIdleTime

-- ==================== dq.ods_inv_inventory_pool_rt  库存池 binlog 流 监控 ====================
-- R1400 [强][及时性] CDC 采集延迟 ≤ 60 秒；期望：连续 3 分钟 > 60000 告警并电话通知
Flink 指标：currentFetchEventTimeLag（毫秒），按作业 flink_job_inv_realtime_stock 的源算子 ods_inv_inventory_pool_rt 采集

-- R1401 [强][完整性] CDC 全量快照完成且进入增量；期望：启动后 30 分钟内进入增量阶段
Flink 指标：isSnapshotSplitFinished / sourceIdleTime

-- ==================== dq.ods_inv_inventory_unit_rt  座位/房间 binlog 流 监控 ====================
-- R1402 [强][及时性] CDC 采集延迟 ≤ 60 秒；期望：连续 3 分钟 > 60000 告警并电话通知
Flink 指标：currentFetchEventTimeLag（毫秒），按作业 flink_job_inv_realtime_stock 的源算子 ods_inv_inventory_unit_rt 采集

-- R1403 [强][完整性] CDC 全量快照完成且进入增量；期望：启动后 30 分钟内进入增量阶段
Flink 指标：isSnapshotSplitFinished / sourceIdleTime

-- ==================== dq.ods_opr_risk_event_rt  风控事件 binlog 流 监控 ====================
-- R1404 [强][及时性] CDC 采集延迟 ≤ 60 秒；期望：连续 3 分钟 > 60000 告警并电话通知
Flink 指标：currentFetchEventTimeLag（毫秒），按作业 flink_job_opr_risk_alert 的源算子 ods_opr_risk_event_rt 采集

-- R1405 [强][完整性] CDC 全量快照完成且进入增量；期望：启动后 30 分钟内进入增量阶段
Flink 指标：isSnapshotSplitFinished / sourceIdleTime

-- ==================== dq.dwd_ord_order_rt  实时下单明细 监控 ====================
-- R1406 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(event_time), NOW()) AS lag_s FROM dwd.dwd_ord_order_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- ==================== dq.dwd_fin_payment_rt  实时支付明细 监控 ====================
-- R1407 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(event_time), NOW()) AS lag_s FROM dwd.dwd_fin_payment_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- ==================== dq.dwd_ord_verify_rt  实时核销明细 监控 ====================
-- R1408 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(event_time), NOW()) AS lag_s FROM dwd.dwd_ord_verify_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- ==================== dq.dwd_ord_refund_rt  实时退款明细 监控 ====================
-- R1409 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(event_time), NOW()) AS lag_s FROM dwd.dwd_ord_refund_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- ==================== dq.dwd_inv_pool_change_rt  实时库存变动 监控 ====================
-- R1410 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(event_time), NOW()) AS lag_s FROM dwd.dwd_inv_pool_change_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- ==================== dq.dwd_opr_risk_event_rt  实时风控事件 监控 ====================
-- R1411 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(event_time), NOW()) AS lag_s FROM dwd.dwd_opr_risk_event_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- ==================== dq.dws_ord_tenant_sku_trade_rt  商户×SKU 分钟级交易 监控 ====================
-- R1412 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(update_time), NOW()) AS lag_s FROM dws.dws_ord_tenant_sku_trade_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- R1413 [弱][有效性] 金额/数量非负；期望：0
SELECT COUNT(*) FROM dws.dws_ord_tenant_sku_trade_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d') AND (pay_amt < 0 OR pay_order_qty < 0 OR pay_ticket_qty < 0 OR pay_buyer_qty < 0 OR refund_amt < 0);

-- ==================== dq.dws_ord_verify_point_flow_rt  核销点 分钟级客流 监控 ====================
-- R1414 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(update_time), NOW()) AS lag_s FROM dws.dws_ord_verify_point_flow_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- R1415 [弱][有效性] 金额/数量非负；期望：0
SELECT COUNT(*) FROM dws.dws_ord_verify_point_flow_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d') AND (verify_person_qty < 0 OR verify_fail_qty < 0 OR verify_entitlement_qty < 0 OR duplicate_verify_qty < 0 OR offline_conflict_qty < 0);

-- ==================== dq.dws_inv_sku_stock_rt  SKU 实时库存 监控 ====================
-- R1416 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(update_time), NOW()) AS lag_s FROM dws.dws_inv_sku_stock_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- R1417 [弱][有效性] 金额/数量非负；期望：0
SELECT COUNT(*) FROM dws.dws_inv_sku_stock_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d') AND (stock_total_qty < 0 OR stock_available_qty < 0 OR stock_frozen_qty < 0 OR stock_sold_qty < 0 OR sellout_pool_qty < 0 OR prededuct_qty < 0 OR prededuct_release_qty < 0);

-- ==================== dq.dws_opr_risk_rule_hit_rt  风控规则 分钟级命中 监控 ====================
-- R1418 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(update_time), NOW()) AS lag_s FROM dws.dws_opr_risk_rule_hit_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- R1419 [弱][有效性] 金额/数量非负；期望：0
SELECT COUNT(*) FROM dws.dws_opr_risk_rule_hit_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d') AND (risk_hit_qty < 0 OR risk_block_qty < 0);

-- ==================== dq.ads_ord_realtime_sales_rt  实时销售看板（对应 DP08） 监控 ====================
-- R1420 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(update_time), NOW()) AS lag_s FROM ads.ads_ord_realtime_sales_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- R1421 [弱][有效性] 金额/数量非负；期望：0
SELECT COUNT(*) FROM ads.ads_ord_realtime_sales_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d') AND (pay_today_amt < 0 OR pay_1h_amt < 0 OR pay_5m_amt < 0 OR pay_order_today_qty < 0 OR pay_order_1h_qty < 0 OR pay_order_5m_qty < 0 OR pay_ticket_today_qty < 0 OR pay_ticket_1h_qty < 0 OR pay_ticket_5m_qty < 0 OR pay_buyer_today_qty < 0 OR pay_buyer_1h_qty < 0 OR pay_buyer_5m_qty < 0 OR refund_today_amt < 0 OR refund_1h_amt < 0 OR refund_5m_amt < 0 OR avg_ticket_price_today_amt < 0 OR avg_ticket_price_1h_amt < 0 OR avg_ticket_price_5m_amt < 0 OR mp_pay_today_amt < 0 OR h5_pay_today_amt < 0 OR pc_pay_today_amt < 0 OR offline_pay_today_amt < 0 OR api_pay_today_amt < 0);

-- ==================== dq.ads_inv_realtime_stock_rt  实时库存看板（对应 DP09） 监控 ====================
-- R1422 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(update_time), NOW()) AS lag_s FROM ads.ads_inv_realtime_stock_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- R1423 [弱][有效性] 金额/数量非负；期望：0
SELECT COUNT(*) FROM ads.ads_inv_realtime_stock_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d') AND (stock_available_now_qty < 0 OR stock_frozen_now_qty < 0 OR sellout_pool_now_qty < 0 OR prededuct_5m_qty < 0 OR prededuct_release_5m_qty < 0);

-- ==================== dq.ads_ord_realtime_flow_rt  实时客流大屏 监控 ====================
-- R1424 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(update_time), NOW()) AS lag_s FROM ads.ads_ord_realtime_flow_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- R1425 [弱][有效性] 金额/数量非负；期望：0
SELECT COUNT(*) FROM ads.ads_ord_realtime_flow_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d') AND (verify_person_today_qty < 0 OR verify_person_1h_qty < 0 OR verify_person_5m_qty < 0 OR verify_fail_today_qty < 0 OR verify_fail_1h_qty < 0 OR verify_fail_5m_qty < 0);

-- ==================== dq.ads_opr_risk_alert_rt  实时风控预警 监控 ====================
-- R1426 [强][及时性] 数据新鲜度 ≤ 5 分钟；期望：lag_s ≤ 300（营业时间 08:00–22:00）
SELECT TIMESTAMPDIFF(SECOND, MAX(update_time), NOW()) AS lag_s FROM ads.ads_opr_risk_alert_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d');

-- R1427 [弱][有效性] 金额/数量非负；期望：0
SELECT COUNT(*) FROM ads.ads_opr_risk_alert_rt WHERE travel_date = DATE_FORMAT(NOW(), '%Y%m%d') AND (risk_hit_5m_qty < 0 OR risk_hit_today_qty < 0 OR risk_block_5m_qty < 0 OR risk_block_today_qty < 0 OR duplicate_verify_5m_qty < 0 OR duplicate_verify_today_qty < 0 OR offline_conflict_5m_qty < 0 OR offline_conflict_today_qty < 0);

-- ==================== dq.flink_job_inv_realtime_stock  作业 flink_job_inv_realtime_stock 运行监控 ====================
-- R1428 [强][及时性] Checkpoint 成功；期望：连续 3 次失败或单次 > 5 分钟告警
Flink 指标：numberOfFailedCheckpoints、lastCheckpointDuration

-- R1429 [弱][及时性] 无持续反压；期望：任一算子 > 500 持续 5 分钟告警
Flink 指标：backPressuredTimeMsPerSecond

-- ==================== dq.flink_job_ord_realtime_sales  作业 flink_job_ord_realtime_sales 运行监控 ====================
-- R1430 [强][及时性] Checkpoint 成功；期望：连续 3 次失败或单次 > 5 分钟告警
Flink 指标：numberOfFailedCheckpoints、lastCheckpointDuration

-- R1431 [弱][及时性] 无持续反压；期望：任一算子 > 500 持续 5 分钟告警
Flink 指标：backPressuredTimeMsPerSecond

-- ==================== dq.flink_job_opr_risk_alert  作业 flink_job_opr_risk_alert 运行监控 ====================
-- R1432 [强][及时性] Checkpoint 成功；期望：连续 3 次失败或单次 > 5 分钟告警
Flink 指标：numberOfFailedCheckpoints、lastCheckpointDuration

-- R1433 [弱][及时性] 无持续反压；期望：任一算子 > 500 持续 5 分钟告警
Flink 指标：backPressuredTimeMsPerSecond

