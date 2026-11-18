-- PFT 2.0 数仓 DDL：RT_DWS（12 张表）
-- 由 generator/make_all.py 生成，请勿手改

-- ========== dws.dws_ord_tenant_sku_trade_rt  商户×SKU 分钟级交易 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_ord_tenant_sku_trade_rt (
    `travel_date`        VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `window_start_time`  VARCHAR(32)    NOT NULL COMMENT '窗口开始时间，格式 yyyy-MM-dd HH:mm:ss',
    `window_end_time`    VARCHAR(32)    NOT NULL COMMENT '窗口结束时间，格式 yyyy-MM-dd HH:mm:ss',
    `seller_tenant_id`   BIGINT         NOT NULL COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    `sku_id`             BIGINT         NOT NULL COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    `channel_id`         BIGINT         NOT NULL COMMENT '入口渠道ID，关联 dim_trf_channel_df',
    `operator_type`      VARCHAR(32)    NOT NULL COMMENT '操作人类型：CUSTOMER-C端游客，TENANT_STAFF-B端员工',
    `pay_amt`            DECIMAL(18,2)  NULL     COMMENT '支付金额（GMV）：支付成功子单的成交金额，不扣退款，单位：元',
    `pay_order_qty`      BIGINT         NULL     COMMENT '支付子单数：统计周期内首次变为 PAID 的子单数，单位：单',
    `pay_ticket_qty`     BIGINT         NULL     COMMENT '支付票数：支付成功子单的购买数量合计，单位：张',
    `pay_buyer_qty`      BIGINT         NULL     COMMENT '支付买家数：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    `refund_amt`         DECIMAL(18,2)  NULL     COMMENT '退款金额：退款完成的金额，单位：元',
    `refund_ticket_qty`  BIGINT         NULL     COMMENT '退款票数：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    `order_qty`          BIGINT         NULL     COMMENT '下单子单数：统计周期内创建的子单数；套票只算主单，子项单另计，单位：单',
    `order_ticket_qty`   BIGINT         NULL     COMMENT '下单票数：下单购买数量合计，单位：张',
    `order_amt`          DECIMAL(18,2)  NULL     COMMENT '下单金额：下单时 单价×数量 合计，单位：元',
    `cancel_order_qty`   BIGINT         NULL     COMMENT '取消子单数：超时未付等原因变为 CANCELLED 的子单数，单位：单',
    `staff_order_qty`    BIGINT         NULL     COMMENT '员工代下单数：操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API），单位：单',
    `staff_pay_amt`      DECIMAL(18,2)  NULL     COMMENT '员工代下单支付金额：员工代下单且已支付的金额，单位：元',
    `update_time`        VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `window_start_time`, `window_end_time`, `seller_tenant_id`, `sku_id`, `channel_id`, `operator_type`)
COMMENT '商户×SKU 分钟级交易（seller_tenant_id × sku_id × channel_id × operator_type × 窗口）'
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

-- ========== dws.dws_ord_tenant_sku_verify_rt  商户×SKU 实时核销 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_ord_tenant_sku_verify_rt (
    `travel_date`             VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `window_start_time`       VARCHAR(32)    NOT NULL COMMENT '窗口开始时间，格式 yyyy-MM-dd HH:mm:ss',
    `window_end_time`         VARCHAR(32)    NOT NULL COMMENT '窗口结束时间，格式 yyyy-MM-dd HH:mm:ss',
    `seller_tenant_id`        BIGINT         NOT NULL COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    `sku_id`                  BIGINT         NOT NULL COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    `verify_ticket_qty`       BIGINT         NULL     COMMENT '核销票数：统计周期内有成功核销的票数（同票多次只算1），单位：张',
    `verify_amt`              DECIMAL(18,2)  NULL     COMMENT '核销金额：成功核销票对应的分摊单价（收入确认口径），单位：元',
    `verify_entitlement_qty`  BIGINT         NULL     COMMENT '核销权益次数：成功核销记录条数（年卡/次卡每次都计），单位：次',
    `verify_fail_qty`         BIGINT         NULL     COMMENT '核销失败次数：核销结果为 FAILED/DUPLICATE 的次数，单位：次',
    `update_time`             VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `window_start_time`, `window_end_time`, `seller_tenant_id`, `sku_id`)
COMMENT '商户×SKU 实时核销（seller_tenant_id × sku_id × 窗口）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`seller_tenant_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dws.dws_fin_account_fund_rt  账户实时资金 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_fin_account_fund_rt (
    `travel_date`            VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `account_no`             VARCHAR(32)    NOT NULL COMMENT '账户编号，关联 dim_fin_account_df',
    `available_balance_amt`  DECIMAL(18,2)  NULL     COMMENT '可用余额：日终账户可用余额，单位：元',
    `frozen_balance_amt`     DECIMAL(18,2)  NULL     COMMENT '冻结余额：日终账户冻结余额，单位：元',
    `freeze_amt`             DECIMAL(18,2)  NULL     COMMENT '冻结金额：统计周期内新建冻结记录金额，单位：元',
    `unfreeze_verify_amt`    DECIMAL(18,2)  NULL     COMMENT '核销解冻金额：因核销释放的冻结金额，单位：元',
    `unfreeze_refund_amt`    DECIMAL(18,2)  NULL     COMMENT '退款释放金额：因退款释放的冻结金额，单位：元',
    `update_time`            VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `account_no`)
COMMENT '账户实时资金（account_no）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`account_no`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dws.dws_trf_distributor_credit_rt  分销授信实时 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_trf_distributor_credit_rt (
    `travel_date`       VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `relation_no`       VARCHAR(32)    NOT NULL COMMENT '分销关系编号',
    `credit_limit_amt`  DECIMAL(18,2)  NULL     COMMENT '授信额度：分销关系授信额度，单位：元',
    `credit_used_amt`   DECIMAL(18,2)  NULL     COMMENT '已用授信：分销关系已用授信，单位：元',
    `update_time`       VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `relation_no`)
COMMENT '分销授信实时（relation_no）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`relation_no`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dws.dws_cus_tenant_growth_rt  游客实时增长 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_cus_tenant_growth_rt (
    `travel_date`          VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `window_start_time`    VARCHAR(32)    NOT NULL COMMENT '窗口开始时间，格式 yyyy-MM-dd HH:mm:ss',
    `window_end_time`      VARCHAR(32)    NOT NULL COMMENT '窗口结束时间，格式 yyyy-MM-dd HH:mm:ss',
    `tenant_id`            BIGINT         NOT NULL COMMENT '租户ID，关联 dim_sup_tenant_zip',
    `register_channel_id`  BIGINT         NOT NULL COMMENT '注册渠道ID，关联 dim_trf_channel_df',
    `new_customer_qty`     BIGINT         NULL     COMMENT '新注册游客数：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    `update_time`          VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `window_start_time`, `window_end_time`, `tenant_id`, `register_channel_id`)
COMMENT '游客实时增长（tenant_id × register_channel_id × 窗口）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`tenant_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dws.dws_opr_device_rt  设备实时状态 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_opr_device_rt (
    `travel_date`        VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `tenant_id`          BIGINT         NOT NULL COMMENT '租户ID，关联 dim_sup_tenant_zip',
    `device_id`          BIGINT         NOT NULL COMMENT '设备ID，关联 dim_opr_device_df',
    `offline_times_qty`  BIGINT         NULL     COMMENT '设备离线次数：变为 OFFLINE 的次数，单位：次',
    `device_total_qty`   BIGINT         NULL     COMMENT '设备数：状态非 INACTIVE 的设备数，单位：台',
    `update_time`        VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `tenant_id`, `device_id`)
COMMENT '设备实时状态（tenant_id × device_id）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`tenant_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dws.dws_opr_notify_rt  通知实时发送 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_opr_notify_rt (
    `travel_date`          VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `window_start_time`    VARCHAR(32)    NOT NULL COMMENT '窗口开始时间，格式 yyyy-MM-dd HH:mm:ss',
    `window_end_time`      VARCHAR(32)    NOT NULL COMMENT '窗口结束时间，格式 yyyy-MM-dd HH:mm:ss',
    `tenant_id`            BIGINT         NOT NULL COMMENT '租户ID，关联 dim_sup_tenant_zip',
    `notify_channel_type`  VARCHAR(32)    NOT NULL COMMENT '通知渠道：SMS-短信，MINI_PROGRAM_MSG-小程序消息，EMAIL-邮件，WEBHOOK-Webhook，IN_APP-站内信',
    `notify_send_qty`      BIGINT         NULL     COMMENT '通知发送数：通知记录数，单位：条',
    `notify_success_qty`   BIGINT         NULL     COMMENT '通知成功数：发送成功的通知条数，单位：条',
    `notify_fail_qty`      BIGINT         NULL     COMMENT '通知失败数：发送失败的通知条数，单位：条',
    `update_time`          VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `window_start_time`, `window_end_time`, `tenant_id`, `notify_channel_type`)
COMMENT '通知实时发送（tenant_id × notify_channel_type × 窗口）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`tenant_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dws.dws_opr_complaint_rt  投诉实时处理 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_opr_complaint_rt (
    `travel_date`             VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `tenant_id`               BIGINT         NOT NULL COMMENT '租户ID，关联 dim_sup_tenant_zip',
    `complaint_type`          VARCHAR(32)    NOT NULL COMMENT '投诉类型：ORDER_ISSUE-订单问题，SERVICE_ISSUE-服务问题，BUG-系统缺陷，OTHER-其他',
    `complaint_qty`           BIGINT         NULL     COMMENT '投诉数：新建投诉工单数，单位：单',
    `complaint_resolved_qty`  BIGINT         NULL     COMMENT '投诉解决数：状态为 RESOLVED/CLOSED 的工单数，单位：单',
    `complaint_overdue_qty`   BIGINT         NULL     COMMENT '投诉超SLA数：超过 SLA 截止时间才解决、或到截止时间仍未解决的投诉工单数，单位：单',
    `update_time`             VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `tenant_id`, `complaint_type`)
COMMENT '投诉实时处理（tenant_id × complaint_type）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`tenant_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dws.dws_opr_code_pool_rt  码池实时余量 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dws.dws_opr_code_pool_rt (
    `travel_date`         VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `tenant_id`           BIGINT         NOT NULL COMMENT '租户ID，关联 dim_sup_tenant_zip',
    `code_pool_id`        BIGINT         NOT NULL COMMENT '码池ID，关联 dim_opr_code_pool_df',
    `code_capacity_qty`   BIGINT         NULL     COMMENT '码池容量：码池最大并发码数，单位：个',
    `code_allocated_qty`  BIGINT         NULL     COMMENT '已分配码数：码池已分配码数，单位：个',
    `code_recycled_qty`   BIGINT         NULL     COMMENT '回收复用码数：码池已回收复用码数，单位：个',
    `update_time`         VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `tenant_id`, `code_pool_id`)
COMMENT '码池实时余量（tenant_id × code_pool_id）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`tenant_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

