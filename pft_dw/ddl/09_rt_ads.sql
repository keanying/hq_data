-- PFT 2.0 数仓 DDL：RT_ADS（4 张表）
-- 由 generator/make_all.py 生成，请勿手改

-- ========== ads.ads_ord_realtime_sales_rt  实时销售看板（对应 DP08） ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS ads.ads_ord_realtime_sales_rt (
    `travel_date`                 VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `window_start_time`           VARCHAR(32)    NOT NULL COMMENT '窗口开始时间，格式 yyyy-MM-dd HH:mm:ss',
    `window_end_time`             VARCHAR(32)    NOT NULL COMMENT '窗口结束时间，格式 yyyy-MM-dd HH:mm:ss',
    `seller_tenant_id`            BIGINT         NOT NULL COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    `seller_tenant_name`          VARCHAR(256)   NULL     COMMENT '卖家租户名称',
    `pay_today_amt`               DECIMAL(18,2)  NULL     COMMENT '今日实时支付金额（GMV）：今日 00:00 至当前时刻：支付成功子单的成交金额，不扣退款，单位：元',
    `pay_1h_amt`                  DECIMAL(18,2)  NULL     COMMENT '近1小时支付金额（GMV）：当前时刻往前 1 小时的滑动窗口内：支付成功子单的成交金额，不扣退款，单位：元',
    `pay_5m_amt`                  DECIMAL(18,2)  NULL     COMMENT '近5分钟支付金额（GMV）：当前时刻往前 5 分钟的滑动窗口内：支付成功子单的成交金额，不扣退款，单位：元',
    `pay_order_today_qty`         BIGINT         NULL     COMMENT '今日实时支付子单数：今日 00:00 至当前时刻：首次变为 PAID 的子单数，单位：单',
    `pay_order_1h_qty`            BIGINT         NULL     COMMENT '近1小时支付子单数：当前时刻往前 1 小时的滑动窗口内：首次变为 PAID 的子单数，单位：单',
    `pay_order_5m_qty`            BIGINT         NULL     COMMENT '近5分钟支付子单数：当前时刻往前 5 分钟的滑动窗口内：首次变为 PAID 的子单数，单位：单',
    `pay_ticket_today_qty`        BIGINT         NULL     COMMENT '今日实时支付票数：今日 00:00 至当前时刻：支付成功子单的购买数量合计，单位：张',
    `pay_ticket_1h_qty`           BIGINT         NULL     COMMENT '近1小时支付票数：当前时刻往前 1 小时的滑动窗口内：支付成功子单的购买数量合计，单位：张',
    `pay_ticket_5m_qty`           BIGINT         NULL     COMMENT '近5分钟支付票数：当前时刻往前 5 分钟的滑动窗口内：支付成功子单的购买数量合计，单位：张',
    `pay_buyer_today_qty`         BIGINT         NULL     COMMENT '今日实时支付买家数：今日 00:00 至当前时刻：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    `pay_buyer_1h_qty`            BIGINT         NULL     COMMENT '近1小时支付买家数：当前时刻往前 1 小时的滑动窗口内：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    `pay_buyer_5m_qty`            BIGINT         NULL     COMMENT '近5分钟支付买家数：当前时刻往前 5 分钟的滑动窗口内：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    `refund_today_amt`            DECIMAL(18,2)  NULL     COMMENT '今日实时退款金额：今日 00:00 至当前时刻：退款完成的金额，单位：元',
    `refund_1h_amt`               DECIMAL(18,2)  NULL     COMMENT '近1小时退款金额：当前时刻往前 1 小时的滑动窗口内：退款完成的金额，单位：元',
    `refund_5m_amt`               DECIMAL(18,2)  NULL     COMMENT '近5分钟退款金额：当前时刻往前 5 分钟的滑动窗口内：退款完成的金额，单位：元',
    `avg_ticket_price_today_amt`  DECIMAL(18,2)  NULL     COMMENT '今日实时平均票价：今日 00:00 至当前时刻：支付金额 / 支付票数；分子分母取同一统计周期，单位：元',
    `avg_ticket_price_1h_amt`     DECIMAL(18,2)  NULL     COMMENT '近1小时平均票价：当前时刻往前 1 小时的滑动窗口内：支付金额 / 支付票数；分子分母取同一统计周期，单位：元',
    `avg_ticket_price_5m_amt`     DECIMAL(18,2)  NULL     COMMENT '近5分钟平均票价：当前时刻往前 5 分钟的滑动窗口内：支付金额 / 支付票数；分子分母取同一统计周期，单位：元',
    `mp_pay_today_amt`            DECIMAL(18,2)  NULL     COMMENT '今日实时小程序支付金额（GMV）：今日 00:00 至当前时刻，限定渠道类型为小程序：支付成功子单的成交金额，不扣退款，单位：元',
    `h5_pay_today_amt`            DECIMAL(18,2)  NULL     COMMENT '今日实时H5支付金额（GMV）：今日 00:00 至当前时刻，限定渠道类型为H5：支付成功子单的成交金额，不扣退款，单位：元',
    `pc_pay_today_amt`            DECIMAL(18,2)  NULL     COMMENT '今日实时PC后台代下支付金额（GMV）：今日 00:00 至当前时刻，限定渠道类型为PC后台代下：支付成功子单的成交金额，不扣退款，单位：元',
    `offline_pay_today_amt`       DECIMAL(18,2)  NULL     COMMENT '今日实时线下窗口支付金额（GMV）：今日 00:00 至当前时刻，限定渠道类型为线下窗口：支付成功子单的成交金额，不扣退款，单位：元',
    `api_pay_today_amt`           DECIMAL(18,2)  NULL     COMMENT '今日实时OTA/API支付金额（GMV）：今日 00:00 至当前时刻，限定渠道类型为OTA/API：支付成功子单的成交金额，不扣退款，单位：元',
    `update_time`                 VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `window_start_time`, `window_end_time`, `seller_tenant_id`)
COMMENT '实时销售看板（对应 DP08）（seller_tenant_id × 窗口）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`seller_tenant_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== ads.ads_inv_realtime_stock_rt  实时库存看板（对应 DP09） ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS ads.ads_inv_realtime_stock_rt (
    `travel_date`                  VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `sku_id`                       BIGINT         NOT NULL COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    `pool_no`                      VARCHAR(32)    NOT NULL COMMENT '库存池编号，关联 dim_inv_pool_df',
    `sku_name`                     VARCHAR(256)   NULL     COMMENT 'SKU 名称',
    `stock_available_now_qty`      BIGINT         NULL     COMMENT '当前可用库存：当前最新值的值：日终库存池可用量，单位：个',
    `stock_frozen_now_qty`         BIGINT         NULL     COMMENT '当前预扣库存：当前最新值的值：日终库存池预扣冻结量，单位：个',
    `stock_sell_through_now_rate`  DECIMAL(20,6)  NULL     COMMENT '当前库存去化率（上座率/入住率）：当前最新值：已售库存 / 库存总量；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    `sellout_pool_now_qty`         BIGINT         NULL     COMMENT '当前售罄库存池数：当前最新值的值：可用量为0且在售的池数，单位：个',
    `prededuct_5m_qty`             BIGINT         NULL     COMMENT '近5分钟预扣量：当前时刻往前 5 分钟的滑动窗口内：下单预扣的库存数量，单位：个',
    `prededuct_release_5m_qty`     BIGINT         NULL     COMMENT '近5分钟预扣释放量：当前时刻往前 5 分钟的滑动窗口内：取消/超时释放的预扣数量，单位：个',
    `update_time`                  VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `sku_id`, `pool_no`)
COMMENT '实时库存看板（对应 DP09）（sku_id × pool_no）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`sku_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== ads.ads_ord_realtime_flow_rt  实时客流大屏 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS ads.ads_ord_realtime_flow_rt (
    `travel_date`              VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `window_start_time`        VARCHAR(32)    NOT NULL COMMENT '窗口开始时间，格式 yyyy-MM-dd HH:mm:ss',
    `window_end_time`          VARCHAR(32)    NOT NULL COMMENT '窗口结束时间，格式 yyyy-MM-dd HH:mm:ss',
    `tenant_id`                BIGINT         NOT NULL COMMENT '租户ID，关联 dim_sup_tenant_zip',
    `verify_point_id`          BIGINT         NOT NULL COMMENT '核销点ID，关联 dim_opr_verify_point_df',
    `tenant_name`              VARCHAR(256)   NULL     COMMENT '租户名称',
    `verify_point_name`        VARCHAR(256)   NULL     COMMENT '核销点名称',
    `verify_person_today_qty`  BIGINT         NULL     COMMENT '今日实时核销人次（入园人次）：今日 00:00 至当前时刻：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    `verify_person_1h_qty`     BIGINT         NULL     COMMENT '近1小时核销人次（入园人次）：当前时刻往前 1 小时的滑动窗口内：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    `verify_person_5m_qty`     BIGINT         NULL     COMMENT '近5分钟核销人次（入园人次）：当前时刻往前 5 分钟的滑动窗口内：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    `verify_fail_today_qty`    BIGINT         NULL     COMMENT '今日实时核销失败次数：今日 00:00 至当前时刻：核销结果为 FAILED/DUPLICATE 的次数，单位：次',
    `verify_fail_1h_qty`       BIGINT         NULL     COMMENT '近1小时核销失败次数：当前时刻往前 1 小时的滑动窗口内：核销结果为 FAILED/DUPLICATE 的次数，单位：次',
    `verify_fail_5m_qty`       BIGINT         NULL     COMMENT '近5分钟核销失败次数：当前时刻往前 5 分钟的滑动窗口内：核销结果为 FAILED/DUPLICATE 的次数，单位：次',
    `verify_fail_today_rate`   DECIMAL(20,6)  NULL     COMMENT '今日实时核销失败率：今日 00:00 至当前时刻：失败次数 /（成功+失败次数）；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    `verify_fail_1h_rate`      DECIMAL(20,6)  NULL     COMMENT '近1小时核销失败率：当前时刻往前 1 小时的滑动窗口内：失败次数 /（成功+失败次数）；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    `verify_fail_5m_rate`      DECIMAL(20,6)  NULL     COMMENT '近5分钟核销失败率：当前时刻往前 5 分钟的滑动窗口内：失败次数 /（成功+失败次数）；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    `update_time`              VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `window_start_time`, `window_end_time`, `tenant_id`, `verify_point_id`)
COMMENT '实时客流大屏（tenant_id × verify_point_id × 窗口）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`tenant_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== ads.ads_opr_risk_alert_rt  实时风控预警 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS ads.ads_opr_risk_alert_rt (
    `travel_date`                 VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD',
    `window_start_time`           VARCHAR(32)    NOT NULL COMMENT '窗口开始时间，格式 yyyy-MM-dd HH:mm:ss',
    `window_end_time`             VARCHAR(32)    NOT NULL COMMENT '窗口结束时间，格式 yyyy-MM-dd HH:mm:ss',
    `rule_id`                     BIGINT         NOT NULL COMMENT '风控规则ID，关联 dim_opr_risk_rule_df',
    `rule_name`                   VARCHAR(256)   NULL     COMMENT '规则名称',
    `risk_hit_5m_qty`             BIGINT         NULL     COMMENT '近5分钟风控命中次数：当前时刻往前 5 分钟的滑动窗口内：风控事件数，单位：次',
    `risk_hit_today_qty`          BIGINT         NULL     COMMENT '今日实时风控命中次数：今日 00:00 至当前时刻：风控事件数，单位：次',
    `risk_block_5m_qty`           BIGINT         NULL     COMMENT '近5分钟风控拦截次数：当前时刻往前 5 分钟的滑动窗口内：风控规则命中后直接拦截（拒绝操作）的次数，单位：次',
    `risk_block_today_qty`        BIGINT         NULL     COMMENT '今日实时风控拦截次数：今日 00:00 至当前时刻：风控规则命中后直接拦截（拒绝操作）的次数，单位：次',
    `duplicate_verify_5m_qty`     BIGINT         NULL     COMMENT '近5分钟重复核销次数：当前时刻往前 5 分钟的滑动窗口内：核销结果为 DUPLICATE 的次数，单位：次',
    `duplicate_verify_today_qty`  BIGINT         NULL     COMMENT '今日实时重复核销次数：今日 00:00 至当前时刻：核销结果为 DUPLICATE 的次数，单位：次',
    `offline_conflict_5m_qty`     BIGINT         NULL     COMMENT '近5分钟离线核销冲突次数：当前时刻往前 5 分钟的滑动窗口内：离线核销回连后仲裁为 DUPLICATE 的次数，单位：次',
    `offline_conflict_today_qty`  BIGINT         NULL     COMMENT '今日实时离线核销冲突次数：今日 00:00 至当前时刻：离线核销回连后仲裁为 DUPLICATE 的次数，单位：次',
    `update_time`                 VARCHAR(32)    NULL     COMMENT '最近一次写入时间，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `window_start_time`, `window_end_time`, `rule_id`)
COMMENT '实时风控预警（rule_id × 窗口）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`rule_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

