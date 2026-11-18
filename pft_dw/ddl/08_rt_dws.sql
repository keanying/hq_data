-- PFT 2.0 数仓 DDL：RT_DWS（4 张表）
-- 由 generator/make_all.py 生成，请勿手改

-- ========== dws.dws_ord_tenant_sku_trade_rt  商户×SKU 分钟级交易 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_ord_tenant_sku_trade_rt (
    `travel_date`        VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `window_start_time`  VARCHAR(32)    NOT NULL COMMENT '窗口开始时间，格式 yyyy-MM-dd HH:mm:ss',
    `window_end_time`    VARCHAR(32)    NOT NULL COMMENT '窗口结束时间，格式 yyyy-MM-dd HH:mm:ss',
    `seller_tenant_id`   BIGINT         NOT NULL COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    `sku_id`             BIGINT         NOT NULL COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    `pay_amt`            DECIMAL(18,2)  NULL     COMMENT '支付金额（GMV）：支付成功子单的成交金额，不扣退款，单位：元',
    `pay_order_qty`      BIGINT         NULL     COMMENT '支付子单数：统计周期内首次变为 PAID 的子单数，单位：单',
    `pay_ticket_qty`     BIGINT         NULL     COMMENT '支付票数：支付成功子单的购买数量合计，单位：张',
    `pay_buyer_qty`      BIGINT         NULL     COMMENT '支付买家数：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    `refund_amt`         DECIMAL(18,2)  NULL     COMMENT '退款金额：退款完成的金额，单位：元',
    `update_time`        VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `window_start_time`, `window_end_time`, `seller_tenant_id`, `sku_id`)
COMMENT '商户×SKU 分钟级交易（seller_tenant_id × sku_id × 窗口）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`seller_tenant_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dws.dws_ord_verify_point_flow_rt  核销点 分钟级客流 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_ord_verify_point_flow_rt (
    `travel_date`             VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `window_start_time`       VARCHAR(32)    NOT NULL COMMENT '窗口开始时间，格式 yyyy-MM-dd HH:mm:ss',
    `window_end_time`         VARCHAR(32)    NOT NULL COMMENT '窗口结束时间，格式 yyyy-MM-dd HH:mm:ss',
    `seller_tenant_id`        BIGINT         NOT NULL COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    `verify_point_id`         BIGINT         NOT NULL COMMENT '核销点ID，关联 dim_opr_verify_point_df',
    `verify_person_qty`       BIGINT         NULL     COMMENT '核销人次（入园人次）：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    `verify_fail_qty`         BIGINT         NULL     COMMENT '核销失败次数：核销结果为 FAILED/DUPLICATE 的次数，单位：次',
    `verify_entitlement_qty`  BIGINT         NULL     COMMENT '核销权益次数：成功核销记录条数（年卡/次卡每次都计），单位：次',
    `duplicate_verify_qty`    BIGINT         NULL     COMMENT '重复核销次数：核销结果为 DUPLICATE 的次数，单位：次',
    `offline_conflict_qty`    BIGINT         NULL     COMMENT '离线核销冲突次数：离线核销回连后仲裁为 DUPLICATE 的次数，单位：次',
    `update_time`             VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `window_start_time`, `window_end_time`, `seller_tenant_id`, `verify_point_id`)
COMMENT '核销点 分钟级客流（seller_tenant_id × verify_point_id × 窗口）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`seller_tenant_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dws.dws_inv_sku_stock_rt  SKU 实时库存 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_inv_sku_stock_rt (
    `travel_date`            VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `sku_id`                 BIGINT         NOT NULL COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    `pool_no`                VARCHAR(32)    NOT NULL COMMENT '库存池编号，关联 dim_inv_pool_df',
    `stock_total_qty`        BIGINT         NULL     COMMENT '库存总量：日终库存池总量，单位：个',
    `stock_available_qty`    BIGINT         NULL     COMMENT '可用库存：日终库存池可用量，单位：个',
    `stock_frozen_qty`       BIGINT         NULL     COMMENT '预扣库存：日终库存池预扣冻结量，单位：个',
    `stock_sold_qty`         BIGINT         NULL     COMMENT '已售库存：总量 − 可用 − 预扣，单位：个',
    `sellout_pool_qty`       BIGINT         NULL     COMMENT '售罄库存池数：可用量为0且在售的池数，单位：个',
    `prededuct_qty`          BIGINT         NULL     COMMENT '预扣量：下单预扣的库存数量，单位：个',
    `prededuct_release_qty`  BIGINT         NULL     COMMENT '预扣释放量：取消/超时释放的预扣数量，单位：个',
    `update_time`            VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `sku_id`, `pool_no`)
COMMENT 'SKU 实时库存（sku_id × pool_no）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`sku_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dws.dws_opr_risk_rule_hit_rt  风控规则 分钟级命中 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_opr_risk_rule_hit_rt (
    `travel_date`        VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `window_start_time`  VARCHAR(32)    NOT NULL COMMENT '窗口开始时间，格式 yyyy-MM-dd HH:mm:ss',
    `window_end_time`    VARCHAR(32)    NOT NULL COMMENT '窗口结束时间，格式 yyyy-MM-dd HH:mm:ss',
    `rule_id`            BIGINT         NOT NULL COMMENT '风控规则ID，关联 dim_opr_risk_rule_df',
    `action_type`        VARCHAR(32)    NOT NULL COMMENT '处置动作：BLOCK-拦截，WARN-预警，FREEZE-冻结',
    `risk_hit_qty`       BIGINT         NULL     COMMENT '风控命中次数：风控事件数，单位：次',
    `risk_block_qty`     BIGINT         NULL     COMMENT '风控拦截次数：风控规则命中后直接拦截（拒绝操作）的次数，单位：次',
    `update_time`        VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `window_start_time`, `window_end_time`, `rule_id`, `action_type`)
COMMENT '风控规则 分钟级命中（rule_id × action_type × 窗口）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`rule_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

