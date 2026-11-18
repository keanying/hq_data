-- PFT 2.0 数仓 DDL：ADS（30 张表）
-- 由 generator/make_all.py 生成，请勿手改

-- ========== ads.ads_ord_tenant_trade_overview_di  商户经营概览 ==========
CREATE TABLE IF NOT EXISTS ads.ads_ord_tenant_trade_overview_di (
    seller_tenant_id          BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    seller_tenant_name        STRING         COMMENT '卖家租户名称',
    pay_1d_amt                DECIMAL(18,2)  COMMENT '当日支付金额（GMV）：统计日当天（00:00–24:00）内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_7d_amt                DECIMAL(18,2)  COMMENT '近7日支付金额（GMV）：统计日及之前共 7 个自然日内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_30d_amt               DECIMAL(18,2)  COMMENT '近30日支付金额（GMV）：统计日及之前共 30 个自然日内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_mtd_amt               DECIMAL(18,2)  COMMENT '本月累计支付金额（GMV）：统计日所在自然月 1 日至统计日：支付成功子单的成交金额，不扣退款，单位：元',
    pay_ytd_amt               DECIMAL(18,2)  COMMENT '本年累计支付金额（GMV）：统计日所在自然年 1 月 1 日至统计日：支付成功子单的成交金额，不扣退款，单位：元',
    net_pay_1d_amt            DECIMAL(18,2)  COMMENT '当日净成交金额：统计日当天（00:00–24:00）内：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    net_pay_7d_amt            DECIMAL(18,2)  COMMENT '近7日净成交金额：统计日及之前共 7 个自然日内：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    net_pay_30d_amt           DECIMAL(18,2)  COMMENT '近30日净成交金额：统计日及之前共 30 个自然日内：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    net_pay_mtd_amt           DECIMAL(18,2)  COMMENT '本月累计净成交金额：统计日所在自然月 1 日至统计日：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    net_pay_ytd_amt           DECIMAL(18,2)  COMMENT '本年累计净成交金额：统计日所在自然年 1 月 1 日至统计日：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    pay_order_1d_qty          BIGINT         COMMENT '当日支付子单数：统计日当天（00:00–24:00）内：首次变为 PAID 的子单数，单位：单',
    pay_order_7d_qty          BIGINT         COMMENT '近7日支付子单数：统计日及之前共 7 个自然日内：首次变为 PAID 的子单数，单位：单',
    pay_order_30d_qty         BIGINT         COMMENT '近30日支付子单数：统计日及之前共 30 个自然日内：首次变为 PAID 的子单数，单位：单',
    pay_order_mtd_qty         BIGINT         COMMENT '本月累计支付子单数：统计日所在自然月 1 日至统计日：首次变为 PAID 的子单数，单位：单',
    pay_order_ytd_qty         BIGINT         COMMENT '本年累计支付子单数：统计日所在自然年 1 月 1 日至统计日：首次变为 PAID 的子单数，单位：单',
    pay_ticket_1d_qty         BIGINT         COMMENT '当日支付票数：统计日当天（00:00–24:00）内：支付成功子单的购买数量合计，单位：张',
    pay_ticket_7d_qty         BIGINT         COMMENT '近7日支付票数：统计日及之前共 7 个自然日内：支付成功子单的购买数量合计，单位：张',
    pay_ticket_30d_qty        BIGINT         COMMENT '近30日支付票数：统计日及之前共 30 个自然日内：支付成功子单的购买数量合计，单位：张',
    pay_ticket_mtd_qty        BIGINT         COMMENT '本月累计支付票数：统计日所在自然月 1 日至统计日：支付成功子单的购买数量合计，单位：张',
    pay_ticket_ytd_qty        BIGINT         COMMENT '本年累计支付票数：统计日所在自然年 1 月 1 日至统计日：支付成功子单的购买数量合计，单位：张',
    pay_buyer_1d_qty          BIGINT         COMMENT '当日支付买家数：统计日当天（00:00–24:00）内：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    pay_buyer_7d_qty          BIGINT         COMMENT '近7日支付买家数：统计日及之前共 7 个自然日内：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    pay_buyer_30d_qty         BIGINT         COMMENT '近30日支付买家数：统计日及之前共 30 个自然日内：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    pay_buyer_mtd_qty         BIGINT         COMMENT '本月累计支付买家数：统计日所在自然月 1 日至统计日：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    pay_buyer_ytd_qty         BIGINT         COMMENT '本年累计支付买家数：统计日所在自然年 1 月 1 日至统计日：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    verify_ticket_1d_qty      BIGINT         COMMENT '当日核销票数：统计日当天（00:00–24:00）内：有成功核销的票数（同票多次只算1），单位：张',
    verify_ticket_7d_qty      BIGINT         COMMENT '近7日核销票数：统计日及之前共 7 个自然日内：有成功核销的票数（同票多次只算1），单位：张',
    verify_ticket_30d_qty     BIGINT         COMMENT '近30日核销票数：统计日及之前共 30 个自然日内：有成功核销的票数（同票多次只算1），单位：张',
    verify_ticket_mtd_qty     BIGINT         COMMENT '本月累计核销票数：统计日所在自然月 1 日至统计日：有成功核销的票数（同票多次只算1），单位：张',
    verify_ticket_ytd_qty     BIGINT         COMMENT '本年累计核销票数：统计日所在自然年 1 月 1 日至统计日：有成功核销的票数（同票多次只算1），单位：张',
    verify_1d_amt             DECIMAL(18,2)  COMMENT '当日核销金额：统计日当天（00:00–24:00）内：成功核销票对应的分摊单价（收入确认口径），单位：元',
    verify_7d_amt             DECIMAL(18,2)  COMMENT '近7日核销金额：统计日及之前共 7 个自然日内：成功核销票对应的分摊单价（收入确认口径），单位：元',
    verify_30d_amt            DECIMAL(18,2)  COMMENT '近30日核销金额：统计日及之前共 30 个自然日内：成功核销票对应的分摊单价（收入确认口径），单位：元',
    verify_mtd_amt            DECIMAL(18,2)  COMMENT '本月累计核销金额：统计日所在自然月 1 日至统计日：成功核销票对应的分摊单价（收入确认口径），单位：元',
    verify_ytd_amt            DECIMAL(18,2)  COMMENT '本年累计核销金额：统计日所在自然年 1 月 1 日至统计日：成功核销票对应的分摊单价（收入确认口径），单位：元',
    refund_1d_amt             DECIMAL(18,2)  COMMENT '当日退款金额：统计日当天（00:00–24:00）内：退款完成的金额，单位：元',
    refund_7d_amt             DECIMAL(18,2)  COMMENT '近7日退款金额：统计日及之前共 7 个自然日内：退款完成的金额，单位：元',
    refund_30d_amt            DECIMAL(18,2)  COMMENT '近30日退款金额：统计日及之前共 30 个自然日内：退款完成的金额，单位：元',
    refund_mtd_amt            DECIMAL(18,2)  COMMENT '本月累计退款金额：统计日所在自然月 1 日至统计日：退款完成的金额，单位：元',
    refund_ytd_amt            DECIMAL(18,2)  COMMENT '本年累计退款金额：统计日所在自然年 1 月 1 日至统计日：退款完成的金额，单位：元',
    cost_1d_amt               DECIMAL(18,2)  COMMENT '当日成本金额：统计日当天（00:00–24:00）内：支付子单按下单时 SKU 版本成本价 × 数量，单位：元',
    cost_7d_amt               DECIMAL(18,2)  COMMENT '近7日成本金额：统计日及之前共 7 个自然日内：支付子单按下单时 SKU 版本成本价 × 数量，单位：元',
    cost_30d_amt              DECIMAL(18,2)  COMMENT '近30日成本金额：统计日及之前共 30 个自然日内：支付子单按下单时 SKU 版本成本价 × 数量，单位：元',
    cost_mtd_amt              DECIMAL(18,2)  COMMENT '本月累计成本金额：统计日所在自然月 1 日至统计日：支付子单按下单时 SKU 版本成本价 × 数量，单位：元',
    cost_ytd_amt              DECIMAL(18,2)  COMMENT '本年累计成本金额：统计日所在自然年 1 月 1 日至统计日：支付子单按下单时 SKU 版本成本价 × 数量，单位：元',
    gross_profit_1d_amt       DECIMAL(18,2)  COMMENT '当日毛利额：统计日当天（00:00–24:00）内：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    gross_profit_7d_amt       DECIMAL(18,2)  COMMENT '近7日毛利额：统计日及之前共 7 个自然日内：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    gross_profit_30d_amt      DECIMAL(18,2)  COMMENT '近30日毛利额：统计日及之前共 30 个自然日内：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    gross_profit_mtd_amt      DECIMAL(18,2)  COMMENT '本月累计毛利额：统计日所在自然月 1 日至统计日：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    gross_profit_ytd_amt      DECIMAL(18,2)  COMMENT '本年累计毛利额：统计日所在自然年 1 月 1 日至统计日：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    per_customer_1d_amt       DECIMAL(18,2)  COMMENT '当日客单价：统计日当天（00:00–24:00）内：支付金额 / 支付买家数；分子分母取同一统计周期，单位：元',
    per_customer_7d_amt       DECIMAL(18,2)  COMMENT '近7日客单价：统计日及之前共 7 个自然日内：支付金额 / 支付买家数；分子分母取同一统计周期，单位：元',
    per_customer_30d_amt      DECIMAL(18,2)  COMMENT '近30日客单价：统计日及之前共 30 个自然日内：支付金额 / 支付买家数；分子分母取同一统计周期，单位：元',
    avg_ticket_price_1d_amt   DECIMAL(18,2)  COMMENT '当日平均票价：统计日当天（00:00–24:00）内：支付金额 / 支付票数；分子分母取同一统计周期，单位：元',
    avg_ticket_price_7d_amt   DECIMAL(18,2)  COMMENT '近7日平均票价：统计日及之前共 7 个自然日内：支付金额 / 支付票数；分子分母取同一统计周期，单位：元',
    avg_ticket_price_30d_amt  DECIMAL(18,2)  COMMENT '近30日平均票价：统计日及之前共 30 个自然日内：支付金额 / 支付票数；分子分母取同一统计周期，单位：元',
    verify_1d_rate            DECIMAL(20,6)  COMMENT '当日核销率：统计日当天（00:00–24:00）内：支付成功的票中已经核销的比例，按支付日追踪（某天卖出的票后来核销了多少）；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    verify_7d_rate            DECIMAL(20,6)  COMMENT '近7日核销率：统计日及之前共 7 个自然日内：支付成功的票中已经核销的比例，按支付日追踪（某天卖出的票后来核销了多少）；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    verify_30d_rate           DECIMAL(20,6)  COMMENT '近30日核销率：统计日及之前共 30 个自然日内：支付成功的票中已经核销的比例，按支付日追踪（某天卖出的票后来核销了多少）；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    refund_1d_rate            DECIMAL(20,6)  COMMENT '当日退票率：统计日当天（00:00–24:00）内：退款票数 / 支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    refund_7d_rate            DECIMAL(20,6)  COMMENT '近7日退票率：统计日及之前共 7 个自然日内：退款票数 / 支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    refund_30d_rate           DECIMAL(20,6)  COMMENT '近30日退票率：统计日及之前共 30 个自然日内：退款票数 / 支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    gross_profit_1d_rate      DECIMAL(20,6)  COMMENT '当日毛利率：统计日当天（00:00–24:00）内：毛利额 / 支付金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    gross_profit_7d_rate      DECIMAL(20,6)  COMMENT '近7日毛利率：统计日及之前共 7 个自然日内：毛利额 / 支付金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    gross_profit_30d_rate     DECIMAL(20,6)  COMMENT '近30日毛利率：统计日及之前共 30 个自然日内：毛利额 / 支付金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pay_conversion_1d_rate    DECIMAL(20,6)  COMMENT '当日下单支付转化率：统计日当天（00:00–24:00）内：支付子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pay_conversion_7d_rate    DECIMAL(20,6)  COMMENT '近7日下单支付转化率：统计日及之前共 7 个自然日内：支付子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pay_conversion_30d_rate   DECIMAL(20,6)  COMMENT '近30日下单支付转化率：统计日及之前共 30 个自然日内：支付子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pay_amt_dod_rate          DECIMAL(20,6)  COMMENT '支付金额日环比：（当日 − 前一日）/ 前一日，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pay_amt_wow_rate          DECIMAL(20,6)  COMMENT '支付金额周同比：（当日 − 上周同日）/ 上周同日；周报为本周对上周，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    etl_time                  STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户经营概览（travel_date × seller_tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_ord_sku_sales_rank_di  SKU销售排行 ==========
CREATE TABLE IF NOT EXISTS ads.ads_ord_sku_sales_rank_di (
    seller_tenant_id          BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id                    BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    seller_tenant_name        STRING         COMMENT '卖家租户名称',
    sku_name                  STRING         COMMENT 'SKU 名称',
    pay_1d_amt                DECIMAL(18,2)  COMMENT '当日支付金额（GMV）：统计日当天（00:00–24:00）内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_7d_amt                DECIMAL(18,2)  COMMENT '近7日支付金额（GMV）：统计日及之前共 7 个自然日内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_30d_amt               DECIMAL(18,2)  COMMENT '近30日支付金额（GMV）：统计日及之前共 30 个自然日内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_ticket_1d_qty         BIGINT         COMMENT '当日支付票数：统计日当天（00:00–24:00）内：支付成功子单的购买数量合计，单位：张',
    pay_ticket_7d_qty         BIGINT         COMMENT '近7日支付票数：统计日及之前共 7 个自然日内：支付成功子单的购买数量合计，单位：张',
    pay_ticket_30d_qty        BIGINT         COMMENT '近30日支付票数：统计日及之前共 30 个自然日内：支付成功子单的购买数量合计，单位：张',
    net_pay_1d_amt            DECIMAL(18,2)  COMMENT '当日净成交金额：统计日当天（00:00–24:00）内：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    net_pay_7d_amt            DECIMAL(18,2)  COMMENT '近7日净成交金额：统计日及之前共 7 个自然日内：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    net_pay_30d_amt           DECIMAL(18,2)  COMMENT '近30日净成交金额：统计日及之前共 30 个自然日内：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    gross_profit_1d_amt       DECIMAL(18,2)  COMMENT '当日毛利额：统计日当天（00:00–24:00）内：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    gross_profit_7d_amt       DECIMAL(18,2)  COMMENT '近7日毛利额：统计日及之前共 7 个自然日内：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    gross_profit_30d_amt      DECIMAL(18,2)  COMMENT '近30日毛利额：统计日及之前共 30 个自然日内：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    refund_ticket_1d_qty      BIGINT         COMMENT '当日退款票数：统计日当天（00:00–24:00）内：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    refund_ticket_7d_qty      BIGINT         COMMENT '近7日退款票数：统计日及之前共 7 个自然日内：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    refund_ticket_30d_qty     BIGINT         COMMENT '近30日退款票数：统计日及之前共 30 个自然日内：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    avg_ticket_price_1d_amt   DECIMAL(18,2)  COMMENT '当日平均票价：统计日当天（00:00–24:00）内：支付金额 / 支付票数；分子分母取同一统计周期，单位：元',
    avg_ticket_price_7d_amt   DECIMAL(18,2)  COMMENT '近7日平均票价：统计日及之前共 7 个自然日内：支付金额 / 支付票数；分子分母取同一统计周期，单位：元',
    avg_ticket_price_30d_amt  DECIMAL(18,2)  COMMENT '近30日平均票价：统计日及之前共 30 个自然日内：支付金额 / 支付票数；分子分母取同一统计周期，单位：元',
    gross_profit_1d_rate      DECIMAL(20,6)  COMMENT '当日毛利率：统计日当天（00:00–24:00）内：毛利额 / 支付金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    gross_profit_7d_rate      DECIMAL(20,6)  COMMENT '近7日毛利率：统计日及之前共 7 个自然日内：毛利额 / 支付金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    gross_profit_30d_rate     DECIMAL(20,6)  COMMENT '近30日毛利率：统计日及之前共 30 个自然日内：毛利额 / 支付金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pay_conversion_1d_rate    DECIMAL(20,6)  COMMENT '当日下单支付转化率：统计日当天（00:00–24:00）内：支付子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pay_conversion_7d_rate    DECIMAL(20,6)  COMMENT '近7日下单支付转化率：统计日及之前共 7 个自然日内：支付子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pay_conversion_30d_rate   DECIMAL(20,6)  COMMENT '近30日下单支付转化率：统计日及之前共 30 个自然日内：支付子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    refund_1d_rate            DECIMAL(20,6)  COMMENT '当日退票率：统计日当天（00:00–24:00）内：退款票数 / 支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    refund_7d_rate            DECIMAL(20,6)  COMMENT '近7日退票率：统计日及之前共 7 个自然日内：退款票数 / 支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    refund_30d_rate           DECIMAL(20,6)  COMMENT '近30日退票率：统计日及之前共 30 个自然日内：退款票数 / 支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    etl_time                  STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SKU销售排行（travel_date × seller_tenant_id × sku_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_ord_channel_sales_structure_di  渠道销售结构 ==========
CREATE TABLE IF NOT EXISTS ads.ads_ord_channel_sales_structure_di (
    seller_tenant_id                    BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    seller_tenant_name                  STRING         COMMENT '卖家租户名称',
    mp_pay_1d_amt                       DECIMAL(18,2)  COMMENT '当日小程序支付金额（GMV）：统计日当天（00:00–24:00）内，限定渠道类型为小程序：支付成功子单的成交金额，不扣退款，单位：元',
    mp_pay_7d_amt                       DECIMAL(18,2)  COMMENT '近7日小程序支付金额（GMV）：统计日及之前共 7 个自然日内，限定渠道类型为小程序：支付成功子单的成交金额，不扣退款，单位：元',
    mp_pay_30d_amt                      DECIMAL(18,2)  COMMENT '近30日小程序支付金额（GMV）：统计日及之前共 30 个自然日内，限定渠道类型为小程序：支付成功子单的成交金额，不扣退款，单位：元',
    h5_pay_1d_amt                       DECIMAL(18,2)  COMMENT '当日H5支付金额（GMV）：统计日当天（00:00–24:00）内，限定渠道类型为H5：支付成功子单的成交金额，不扣退款，单位：元',
    h5_pay_7d_amt                       DECIMAL(18,2)  COMMENT '近7日H5支付金额（GMV）：统计日及之前共 7 个自然日内，限定渠道类型为H5：支付成功子单的成交金额，不扣退款，单位：元',
    h5_pay_30d_amt                      DECIMAL(18,2)  COMMENT '近30日H5支付金额（GMV）：统计日及之前共 30 个自然日内，限定渠道类型为H5：支付成功子单的成交金额，不扣退款，单位：元',
    pc_pay_1d_amt                       DECIMAL(18,2)  COMMENT '当日PC后台代下支付金额（GMV）：统计日当天（00:00–24:00）内，限定渠道类型为PC后台代下：支付成功子单的成交金额，不扣退款，单位：元',
    pc_pay_7d_amt                       DECIMAL(18,2)  COMMENT '近7日PC后台代下支付金额（GMV）：统计日及之前共 7 个自然日内，限定渠道类型为PC后台代下：支付成功子单的成交金额，不扣退款，单位：元',
    pc_pay_30d_amt                      DECIMAL(18,2)  COMMENT '近30日PC后台代下支付金额（GMV）：统计日及之前共 30 个自然日内，限定渠道类型为PC后台代下：支付成功子单的成交金额，不扣退款，单位：元',
    offline_pay_1d_amt                  DECIMAL(18,2)  COMMENT '当日线下窗口支付金额（GMV）：统计日当天（00:00–24:00）内，限定渠道类型为线下窗口：支付成功子单的成交金额，不扣退款，单位：元',
    offline_pay_7d_amt                  DECIMAL(18,2)  COMMENT '近7日线下窗口支付金额（GMV）：统计日及之前共 7 个自然日内，限定渠道类型为线下窗口：支付成功子单的成交金额，不扣退款，单位：元',
    offline_pay_30d_amt                 DECIMAL(18,2)  COMMENT '近30日线下窗口支付金额（GMV）：统计日及之前共 30 个自然日内，限定渠道类型为线下窗口：支付成功子单的成交金额，不扣退款，单位：元',
    api_pay_1d_amt                      DECIMAL(18,2)  COMMENT '当日OTA/API支付金额（GMV）：统计日当天（00:00–24:00）内，限定渠道类型为OTA/API：支付成功子单的成交金额，不扣退款，单位：元',
    api_pay_7d_amt                      DECIMAL(18,2)  COMMENT '近7日OTA/API支付金额（GMV）：统计日及之前共 7 个自然日内，限定渠道类型为OTA/API：支付成功子单的成交金额，不扣退款，单位：元',
    api_pay_30d_amt                     DECIMAL(18,2)  COMMENT '近30日OTA/API支付金额（GMV）：统计日及之前共 30 个自然日内，限定渠道类型为OTA/API：支付成功子单的成交金额，不扣退款，单位：元',
    mp_pay_ticket_1d_qty                BIGINT         COMMENT '当日小程序支付票数：统计日当天（00:00–24:00）内，限定渠道类型为小程序：支付成功子单的购买数量合计，单位：张',
    mp_pay_ticket_7d_qty                BIGINT         COMMENT '近7日小程序支付票数：统计日及之前共 7 个自然日内，限定渠道类型为小程序：支付成功子单的购买数量合计，单位：张',
    mp_pay_ticket_30d_qty               BIGINT         COMMENT '近30日小程序支付票数：统计日及之前共 30 个自然日内，限定渠道类型为小程序：支付成功子单的购买数量合计，单位：张',
    h5_pay_ticket_1d_qty                BIGINT         COMMENT '当日H5支付票数：统计日当天（00:00–24:00）内，限定渠道类型为H5：支付成功子单的购买数量合计，单位：张',
    h5_pay_ticket_7d_qty                BIGINT         COMMENT '近7日H5支付票数：统计日及之前共 7 个自然日内，限定渠道类型为H5：支付成功子单的购买数量合计，单位：张',
    h5_pay_ticket_30d_qty               BIGINT         COMMENT '近30日H5支付票数：统计日及之前共 30 个自然日内，限定渠道类型为H5：支付成功子单的购买数量合计，单位：张',
    pc_pay_ticket_1d_qty                BIGINT         COMMENT '当日PC后台代下支付票数：统计日当天（00:00–24:00）内，限定渠道类型为PC后台代下：支付成功子单的购买数量合计，单位：张',
    pc_pay_ticket_7d_qty                BIGINT         COMMENT '近7日PC后台代下支付票数：统计日及之前共 7 个自然日内，限定渠道类型为PC后台代下：支付成功子单的购买数量合计，单位：张',
    pc_pay_ticket_30d_qty               BIGINT         COMMENT '近30日PC后台代下支付票数：统计日及之前共 30 个自然日内，限定渠道类型为PC后台代下：支付成功子单的购买数量合计，单位：张',
    offline_pay_ticket_1d_qty           BIGINT         COMMENT '当日线下窗口支付票数：统计日当天（00:00–24:00）内，限定渠道类型为线下窗口：支付成功子单的购买数量合计，单位：张',
    offline_pay_ticket_7d_qty           BIGINT         COMMENT '近7日线下窗口支付票数：统计日及之前共 7 个自然日内，限定渠道类型为线下窗口：支付成功子单的购买数量合计，单位：张',
    offline_pay_ticket_30d_qty          BIGINT         COMMENT '近30日线下窗口支付票数：统计日及之前共 30 个自然日内，限定渠道类型为线下窗口：支付成功子单的购买数量合计，单位：张',
    api_pay_ticket_1d_qty               BIGINT         COMMENT '当日OTA/API支付票数：统计日当天（00:00–24:00）内，限定渠道类型为OTA/API：支付成功子单的购买数量合计，单位：张',
    api_pay_ticket_7d_qty               BIGINT         COMMENT '近7日OTA/API支付票数：统计日及之前共 7 个自然日内，限定渠道类型为OTA/API：支付成功子单的购买数量合计，单位：张',
    api_pay_ticket_30d_qty              BIGINT         COMMENT '近30日OTA/API支付票数：统计日及之前共 30 个自然日内，限定渠道类型为OTA/API：支付成功子单的购买数量合计，单位：张',
    mp_pay_order_1d_qty                 BIGINT         COMMENT '当日小程序支付子单数：统计日当天（00:00–24:00）内，限定渠道类型为小程序：首次变为 PAID 的子单数，单位：单',
    mp_pay_order_7d_qty                 BIGINT         COMMENT '近7日小程序支付子单数：统计日及之前共 7 个自然日内，限定渠道类型为小程序：首次变为 PAID 的子单数，单位：单',
    mp_pay_order_30d_qty                BIGINT         COMMENT '近30日小程序支付子单数：统计日及之前共 30 个自然日内，限定渠道类型为小程序：首次变为 PAID 的子单数，单位：单',
    h5_pay_order_1d_qty                 BIGINT         COMMENT '当日H5支付子单数：统计日当天（00:00–24:00）内，限定渠道类型为H5：首次变为 PAID 的子单数，单位：单',
    h5_pay_order_7d_qty                 BIGINT         COMMENT '近7日H5支付子单数：统计日及之前共 7 个自然日内，限定渠道类型为H5：首次变为 PAID 的子单数，单位：单',
    h5_pay_order_30d_qty                BIGINT         COMMENT '近30日H5支付子单数：统计日及之前共 30 个自然日内，限定渠道类型为H5：首次变为 PAID 的子单数，单位：单',
    pc_pay_order_1d_qty                 BIGINT         COMMENT '当日PC后台代下支付子单数：统计日当天（00:00–24:00）内，限定渠道类型为PC后台代下：首次变为 PAID 的子单数，单位：单',
    pc_pay_order_7d_qty                 BIGINT         COMMENT '近7日PC后台代下支付子单数：统计日及之前共 7 个自然日内，限定渠道类型为PC后台代下：首次变为 PAID 的子单数，单位：单',
    pc_pay_order_30d_qty                BIGINT         COMMENT '近30日PC后台代下支付子单数：统计日及之前共 30 个自然日内，限定渠道类型为PC后台代下：首次变为 PAID 的子单数，单位：单',
    offline_pay_order_1d_qty            BIGINT         COMMENT '当日线下窗口支付子单数：统计日当天（00:00–24:00）内，限定渠道类型为线下窗口：首次变为 PAID 的子单数，单位：单',
    offline_pay_order_7d_qty            BIGINT         COMMENT '近7日线下窗口支付子单数：统计日及之前共 7 个自然日内，限定渠道类型为线下窗口：首次变为 PAID 的子单数，单位：单',
    offline_pay_order_30d_qty           BIGINT         COMMENT '近30日线下窗口支付子单数：统计日及之前共 30 个自然日内，限定渠道类型为线下窗口：首次变为 PAID 的子单数，单位：单',
    api_pay_order_1d_qty                BIGINT         COMMENT '当日OTA/API支付子单数：统计日当天（00:00–24:00）内，限定渠道类型为OTA/API：首次变为 PAID 的子单数，单位：单',
    api_pay_order_7d_qty                BIGINT         COMMENT '近7日OTA/API支付子单数：统计日及之前共 7 个自然日内，限定渠道类型为OTA/API：首次变为 PAID 的子单数，单位：单',
    api_pay_order_30d_qty               BIGINT         COMMENT '近30日OTA/API支付子单数：统计日及之前共 30 个自然日内，限定渠道类型为OTA/API：首次变为 PAID 的子单数，单位：单',
    mp_channel_pay_share_1d_rate        DECIMAL(20,6)  COMMENT '当日小程序渠道销售占比：统计日当天（00:00–24:00）内，限定渠道类型为小程序：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    mp_channel_pay_share_7d_rate        DECIMAL(20,6)  COMMENT '近7日小程序渠道销售占比：统计日及之前共 7 个自然日内，限定渠道类型为小程序：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    mp_channel_pay_share_30d_rate       DECIMAL(20,6)  COMMENT '近30日小程序渠道销售占比：统计日及之前共 30 个自然日内，限定渠道类型为小程序：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    h5_channel_pay_share_1d_rate        DECIMAL(20,6)  COMMENT '当日H5渠道销售占比：统计日当天（00:00–24:00）内，限定渠道类型为H5：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    h5_channel_pay_share_7d_rate        DECIMAL(20,6)  COMMENT '近7日H5渠道销售占比：统计日及之前共 7 个自然日内，限定渠道类型为H5：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    h5_channel_pay_share_30d_rate       DECIMAL(20,6)  COMMENT '近30日H5渠道销售占比：统计日及之前共 30 个自然日内，限定渠道类型为H5：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pc_channel_pay_share_1d_rate        DECIMAL(20,6)  COMMENT '当日PC后台代下渠道销售占比：统计日当天（00:00–24:00）内，限定渠道类型为PC后台代下：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pc_channel_pay_share_7d_rate        DECIMAL(20,6)  COMMENT '近7日PC后台代下渠道销售占比：统计日及之前共 7 个自然日内，限定渠道类型为PC后台代下：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pc_channel_pay_share_30d_rate       DECIMAL(20,6)  COMMENT '近30日PC后台代下渠道销售占比：统计日及之前共 30 个自然日内，限定渠道类型为PC后台代下：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    offline_channel_pay_share_1d_rate   DECIMAL(20,6)  COMMENT '当日线下窗口渠道销售占比：统计日当天（00:00–24:00）内，限定渠道类型为线下窗口：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    offline_channel_pay_share_7d_rate   DECIMAL(20,6)  COMMENT '近7日线下窗口渠道销售占比：统计日及之前共 7 个自然日内，限定渠道类型为线下窗口：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    offline_channel_pay_share_30d_rate  DECIMAL(20,6)  COMMENT '近30日线下窗口渠道销售占比：统计日及之前共 30 个自然日内，限定渠道类型为线下窗口：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    api_channel_pay_share_1d_rate       DECIMAL(20,6)  COMMENT '当日OTA/API渠道销售占比：统计日当天（00:00–24:00）内，限定渠道类型为OTA/API：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    api_channel_pay_share_7d_rate       DECIMAL(20,6)  COMMENT '近7日OTA/API渠道销售占比：统计日及之前共 7 个自然日内，限定渠道类型为OTA/API：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    api_channel_pay_share_30d_rate      DECIMAL(20,6)  COMMENT '近30日OTA/API渠道销售占比：统计日及之前共 30 个自然日内，限定渠道类型为OTA/API：某渠道支付金额 / 全部支付金额；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    staff_order_1d_qty                  BIGINT         COMMENT '当日员工代下单数：统计日当天（00:00–24:00）内：操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API），单位：单',
    staff_order_7d_qty                  BIGINT         COMMENT '近7日员工代下单数：统计日及之前共 7 个自然日内：操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API），单位：单',
    staff_order_30d_qty                 BIGINT         COMMENT '近30日员工代下单数：统计日及之前共 30 个自然日内：操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API），单位：单',
    staff_pay_1d_amt                    DECIMAL(18,2)  COMMENT '当日员工代下单支付金额：统计日当天（00:00–24:00）内：员工代下单且已支付的金额，单位：元',
    staff_pay_7d_amt                    DECIMAL(18,2)  COMMENT '近7日员工代下单支付金额：统计日及之前共 7 个自然日内：员工代下单且已支付的金额，单位：元',
    staff_pay_30d_amt                   DECIMAL(18,2)  COMMENT '近30日员工代下单支付金额：统计日及之前共 30 个自然日内：员工代下单且已支付的金额，单位：元',
    etl_time                            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '渠道销售结构（travel_date × seller_tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_ord_verify_flow_hrs  分时客流（入园人次） ==========
CREATE TABLE IF NOT EXISTS ads.ads_ord_verify_flow_hrs (
    stat_hour_no           INT            COMMENT '统计小时：0~23',
    seller_tenant_id       BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    verify_point_id        BIGINT         COMMENT '核销点ID，关联 dim_opr_verify_point_df',
    seller_tenant_name     STRING         COMMENT '卖家租户名称',
    verify_point_name      STRING         COMMENT '核销点名称',
    verify_person_1h_qty   BIGINT         COMMENT '当小时核销人次（入园人次）：统计小时内：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    verify_fail_1h_qty     BIGINT         COMMENT '当小时核销失败次数：统计小时内：核销结果为 FAILED/DUPLICATE 的次数，单位：次',
    verify_fail_1h_rate    DECIMAL(20,6)  COMMENT '当小时核销失败率：统计小时内：失败次数 /（成功+失败次数）；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    verify_person_1d_qty   BIGINT         COMMENT '当日核销人次（入园人次）：统计日当天（00:00–24:00）内：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    verify_person_7d_qty   BIGINT         COMMENT '近7日核销人次（入园人次）：统计日及之前共 7 个自然日内：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    verify_person_30d_qty  BIGINT         COMMENT '近30日核销人次（入园人次）：统计日及之前共 30 个自然日内：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    peak_hour_verify_qty   BIGINT         COMMENT '峰值小时入园人次：当日各小时入园人次的最大值，单位：人次',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '分时客流（入园人次）（travel_date × stat_hour_no × seller_tenant_id × verify_point_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_ord_play_date_booking_df  未来游玩日预订看板 ==========
CREATE TABLE IF NOT EXISTS ads.ads_ord_play_date_booking_df (
    sku_id                       BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    play_date                    STRING         COMMENT '游玩日期，格式 yyyy-MM-dd',
    sku_name                     STRING         COMMENT 'SKU 名称',
    pay_ticket_td_qty            BIGINT         COMMENT '截至当日支付票数：截至统计日日终的值：支付成功子单的购买数量合计，单位：张',
    refund_ticket_td_qty         BIGINT         COMMENT '截至当日退款票数：截至统计日日终的值：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    net_pay_ticket_td_qty        BIGINT         COMMENT '截至当日净支付票数：截至统计日日终的值：支付票数 − 退款票数，单位：张',
    stock_available_td_qty       BIGINT         COMMENT '截至当日可用库存：截至统计日日终的值：日终库存池可用量，单位：个',
    stock_sell_through_td_rate   DECIMAL(20,6)  COMMENT '截至当日库存去化率（上座率/入住率）：截至统计日日终：已售库存 / 库存总量；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    avg_advance_book_day_td_qty  DECIMAL(18,2)  COMMENT '截至当日平均提前预订天数：截至统计日日终：提前预订天数按票加权平均；分子分母取同一统计周期，单位：天',
    etl_time                     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '未来游玩日预订看板（travel_date × sku_id × play_date）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_ord_refund_analysis_di  退款分析 ==========
CREATE TABLE IF NOT EXISTS ads.ads_ord_refund_analysis_di (
    seller_tenant_id                BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    refund_reason_desc              STRING         COMMENT '退款原因',
    seller_tenant_name              STRING         COMMENT '卖家租户名称',
    refund_apply_1d_qty             BIGINT         COMMENT '当日退款申请单数：统计日当天（00:00–24:00）内：创建的退款单数，单位：单',
    refund_apply_7d_qty             BIGINT         COMMENT '近7日退款申请单数：统计日及之前共 7 个自然日内：创建的退款单数，单位：单',
    refund_apply_30d_qty            BIGINT         COMMENT '近30日退款申请单数：统计日及之前共 30 个自然日内：创建的退款单数，单位：单',
    refund_success_1d_qty           BIGINT         COMMENT '当日退款完成单数：统计日当天（00:00–24:00）内：状态为 COMPLETED 的退款单数，单位：单',
    refund_success_7d_qty           BIGINT         COMMENT '近7日退款完成单数：统计日及之前共 7 个自然日内：状态为 COMPLETED 的退款单数，单位：单',
    refund_success_30d_qty          BIGINT         COMMENT '近30日退款完成单数：统计日及之前共 30 个自然日内：状态为 COMPLETED 的退款单数，单位：单',
    refund_ticket_1d_qty            BIGINT         COMMENT '当日退款票数：统计日当天（00:00–24:00）内：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    refund_ticket_7d_qty            BIGINT         COMMENT '近7日退款票数：统计日及之前共 7 个自然日内：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    refund_ticket_30d_qty           BIGINT         COMMENT '近30日退款票数：统计日及之前共 30 个自然日内：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    refund_1d_amt                   DECIMAL(18,2)  COMMENT '当日退款金额：统计日当天（00:00–24:00）内：退款完成的金额，单位：元',
    refund_7d_amt                   DECIMAL(18,2)  COMMENT '近7日退款金额：统计日及之前共 7 个自然日内：退款完成的金额，单位：元',
    refund_30d_amt                  DECIMAL(18,2)  COMMENT '近30日退款金额：统计日及之前共 30 个自然日内：退款完成的金额，单位：元',
    refund_reject_1d_qty            BIGINT         COMMENT '当日退款驳回单数：统计日当天（00:00–24:00）内：状态为 REJECTED 的退款单数，单位：单',
    refund_reject_7d_qty            BIGINT         COMMENT '近7日退款驳回单数：统计日及之前共 7 个自然日内：状态为 REJECTED 的退款单数，单位：单',
    refund_reject_30d_qty           BIGINT         COMMENT '近30日退款驳回单数：统计日及之前共 30 个自然日内：状态为 REJECTED 的退款单数，单位：单',
    auto_approve_refund_1d_qty      BIGINT         COMMENT '当日超时自动通过退款单数：统计日当天（00:00–24:00）内：审核超过 48 小时自动通过的退款单数，单位：单',
    auto_approve_refund_7d_qty      BIGINT         COMMENT '近7日超时自动通过退款单数：统计日及之前共 7 个自然日内：审核超过 48 小时自动通过的退款单数，单位：单',
    auto_approve_refund_30d_qty     BIGINT         COMMENT '近30日超时自动通过退款单数：统计日及之前共 30 个自然日内：审核超过 48 小时自动通过的退款单数，单位：单',
    verified_refund_ticket_1d_qty   BIGINT         COMMENT '当日核销后退款票数：统计日当天（00:00–24:00）内：退款时票状态为 PARTIALLY_USED/USED 的票数，单位：张',
    verified_refund_ticket_7d_qty   BIGINT         COMMENT '近7日核销后退款票数：统计日及之前共 7 个自然日内：退款时票状态为 PARTIALLY_USED/USED 的票数，单位：张',
    verified_refund_ticket_30d_qty  BIGINT         COMMENT '近30日核销后退款票数：统计日及之前共 30 个自然日内：退款时票状态为 PARTIALLY_USED/USED 的票数，单位：张',
    refund_1d_rate                  DECIMAL(20,6)  COMMENT '当日退票率：统计日当天（00:00–24:00）内：退款票数 / 支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    refund_7d_rate                  DECIMAL(20,6)  COMMENT '近7日退票率：统计日及之前共 7 个自然日内：退款票数 / 支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    refund_30d_rate                 DECIMAL(20,6)  COMMENT '近30日退票率：统计日及之前共 30 个自然日内：退款票数 / 支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    refund_amt_1d_rate              DECIMAL(20,6)  COMMENT '当日退款金额率：统计日当天（00:00–24:00）内：退款金额 / 支付金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    refund_amt_7d_rate              DECIMAL(20,6)  COMMENT '近7日退款金额率：统计日及之前共 7 个自然日内：退款金额 / 支付金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    refund_amt_30d_rate             DECIMAL(20,6)  COMMENT '近30日退款金额率：统计日及之前共 30 个自然日内：退款金额 / 支付金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    cancel_1d_rate                  DECIMAL(20,6)  COMMENT '当日取消率：统计日当天（00:00–24:00）内：取消子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    cancel_7d_rate                  DECIMAL(20,6)  COMMENT '近7日取消率：统计日及之前共 7 个自然日内：取消子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    cancel_30d_rate                 DECIMAL(20,6)  COMMENT '近30日取消率：统计日及之前共 30 个自然日内：取消子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    timeout_cancel_1d_rate          DECIMAL(20,6)  COMMENT '当日超时取消率：统计日当天（00:00–24:00）内：超时取消子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    timeout_cancel_7d_rate          DECIMAL(20,6)  COMMENT '近7日超时取消率：统计日及之前共 7 个自然日内：超时取消子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    timeout_cancel_30d_rate         DECIMAL(20,6)  COMMENT '近30日超时取消率：统计日及之前共 30 个自然日内：超时取消子单数 / 下单子单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    visitor_refund_ticket_1d_qty    BIGINT         COMMENT '当日游客发起退款票数：统计日当天（00:00–24:00）内，限定退款发起方为游客发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    visitor_refund_ticket_7d_qty    BIGINT         COMMENT '近7日游客发起退款票数：统计日及之前共 7 个自然日内，限定退款发起方为游客发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    visitor_refund_ticket_30d_qty   BIGINT         COMMENT '近30日游客发起退款票数：统计日及之前共 30 个自然日内，限定退款发起方为游客发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    merchant_refund_ticket_1d_qty   BIGINT         COMMENT '当日商户发起退款票数：统计日当天（00:00–24:00）内，限定退款发起方为商户发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    merchant_refund_ticket_7d_qty   BIGINT         COMMENT '近7日商户发起退款票数：统计日及之前共 7 个自然日内，限定退款发起方为商户发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    merchant_refund_ticket_30d_qty  BIGINT         COMMENT '近30日商户发起退款票数：统计日及之前共 30 个自然日内，限定退款发起方为商户发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    ota_refund_ticket_1d_qty        BIGINT         COMMENT '当日OTA发起退款票数：统计日当天（00:00–24:00）内，限定退款发起方为OTA发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    ota_refund_ticket_7d_qty        BIGINT         COMMENT '近7日OTA发起退款票数：统计日及之前共 7 个自然日内，限定退款发起方为OTA发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    ota_refund_ticket_30d_qty       BIGINT         COMMENT '近30日OTA发起退款票数：统计日及之前共 30 个自然日内，限定退款发起方为OTA发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    system_refund_ticket_1d_qty     BIGINT         COMMENT '当日系统发起退款票数：统计日当天（00:00–24:00）内，限定退款发起方为系统发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    system_refund_ticket_7d_qty     BIGINT         COMMENT '近7日系统发起退款票数：统计日及之前共 7 个自然日内，限定退款发起方为系统发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    system_refund_ticket_30d_qty    BIGINT         COMMENT '近30日系统发起退款票数：统计日及之前共 30 个自然日内，限定退款发起方为系统发起：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    visitor_refund_1d_amt           DECIMAL(18,2)  COMMENT '当日游客发起退款金额：统计日当天（00:00–24:00）内，限定退款发起方为游客发起：退款完成的金额，单位：元',
    visitor_refund_7d_amt           DECIMAL(18,2)  COMMENT '近7日游客发起退款金额：统计日及之前共 7 个自然日内，限定退款发起方为游客发起：退款完成的金额，单位：元',
    visitor_refund_30d_amt          DECIMAL(18,2)  COMMENT '近30日游客发起退款金额：统计日及之前共 30 个自然日内，限定退款发起方为游客发起：退款完成的金额，单位：元',
    merchant_refund_1d_amt          DECIMAL(18,2)  COMMENT '当日商户发起退款金额：统计日当天（00:00–24:00）内，限定退款发起方为商户发起：退款完成的金额，单位：元',
    merchant_refund_7d_amt          DECIMAL(18,2)  COMMENT '近7日商户发起退款金额：统计日及之前共 7 个自然日内，限定退款发起方为商户发起：退款完成的金额，单位：元',
    merchant_refund_30d_amt         DECIMAL(18,2)  COMMENT '近30日商户发起退款金额：统计日及之前共 30 个自然日内，限定退款发起方为商户发起：退款完成的金额，单位：元',
    ota_refund_1d_amt               DECIMAL(18,2)  COMMENT '当日OTA发起退款金额：统计日当天（00:00–24:00）内，限定退款发起方为OTA发起：退款完成的金额，单位：元',
    ota_refund_7d_amt               DECIMAL(18,2)  COMMENT '近7日OTA发起退款金额：统计日及之前共 7 个自然日内，限定退款发起方为OTA发起：退款完成的金额，单位：元',
    ota_refund_30d_amt              DECIMAL(18,2)  COMMENT '近30日OTA发起退款金额：统计日及之前共 30 个自然日内，限定退款发起方为OTA发起：退款完成的金额，单位：元',
    system_refund_1d_amt            DECIMAL(18,2)  COMMENT '当日系统发起退款金额：统计日当天（00:00–24:00）内，限定退款发起方为系统发起：退款完成的金额，单位：元',
    system_refund_7d_amt            DECIMAL(18,2)  COMMENT '近7日系统发起退款金额：统计日及之前共 7 个自然日内，限定退款发起方为系统发起：退款完成的金额，单位：元',
    system_refund_30d_amt           DECIMAL(18,2)  COMMENT '近30日系统发起退款金额：统计日及之前共 30 个自然日内，限定退款发起方为系统发起：退款完成的金额，单位：元',
    etl_time                        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '退款分析（travel_date × seller_tenant_id × refund_reason_desc）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_ord_entitlement_usage_di  权益使用分析（年卡/次卡/计时/额度） ==========
CREATE TABLE IF NOT EXISTS ads.ads_ord_entitlement_usage_di (
    seller_tenant_id                       BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id                                 BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    seller_tenant_name                     STRING         COMMENT '卖家租户名称',
    sku_name                               STRING         COMMENT 'SKU 名称',
    fixed_entitlement_used_1d_qty          BIGINT         COMMENT '当日固定型权益已用次数：统计日当天（00:00–24:00）内，限定权益类型为固定型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    fixed_entitlement_used_7d_qty          BIGINT         COMMENT '近7日固定型权益已用次数：统计日及之前共 7 个自然日内，限定权益类型为固定型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    fixed_entitlement_used_30d_qty         BIGINT         COMMENT '近30日固定型权益已用次数：统计日及之前共 30 个自然日内，限定权益类型为固定型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    selectable_entitlement_used_1d_qty     BIGINT         COMMENT '当日选择型权益已用次数：统计日当天（00:00–24:00）内，限定权益类型为选择型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    selectable_entitlement_used_7d_qty     BIGINT         COMMENT '近7日选择型权益已用次数：统计日及之前共 7 个自然日内，限定权益类型为选择型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    selectable_entitlement_used_30d_qty    BIGINT         COMMENT '近30日选择型权益已用次数：统计日及之前共 30 个自然日内，限定权益类型为选择型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    counted_entitlement_used_1d_qty        BIGINT         COMMENT '当日计次型权益已用次数：统计日当天（00:00–24:00）内，限定权益类型为计次型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    counted_entitlement_used_7d_qty        BIGINT         COMMENT '近7日计次型权益已用次数：统计日及之前共 7 个自然日内，限定权益类型为计次型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    counted_entitlement_used_30d_qty       BIGINT         COMMENT '近30日计次型权益已用次数：统计日及之前共 30 个自然日内，限定权益类型为计次型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    timed_entitlement_used_1d_qty          BIGINT         COMMENT '当日计时型权益已用次数：统计日当天（00:00–24:00）内，限定权益类型为计时型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    timed_entitlement_used_7d_qty          BIGINT         COMMENT '近7日计时型权益已用次数：统计日及之前共 7 个自然日内，限定权益类型为计时型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    timed_entitlement_used_30d_qty         BIGINT         COMMENT '近30日计时型权益已用次数：统计日及之前共 30 个自然日内，限定权益类型为计时型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    unlimited_entitlement_used_1d_qty      BIGINT         COMMENT '当日不限次型权益已用次数：统计日当天（00:00–24:00）内，限定权益类型为不限次型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    unlimited_entitlement_used_7d_qty      BIGINT         COMMENT '近7日不限次型权益已用次数：统计日及之前共 7 个自然日内，限定权益类型为不限次型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    unlimited_entitlement_used_30d_qty     BIGINT         COMMENT '近30日不限次型权益已用次数：统计日及之前共 30 个自然日内，限定权益类型为不限次型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    quota_entitlement_used_1d_qty          BIGINT         COMMENT '当日额度型权益已用次数：统计日当天（00:00–24:00）内，限定权益类型为额度型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    quota_entitlement_used_7d_qty          BIGINT         COMMENT '近7日额度型权益已用次数：统计日及之前共 7 个自然日内，限定权益类型为额度型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    quota_entitlement_used_30d_qty         BIGINT         COMMENT '近30日额度型权益已用次数：统计日及之前共 30 个自然日内，限定权益类型为额度型：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    fixed_entitlement_usage_1d_rate        DECIMAL(20,6)  COMMENT '当日固定型权益使用率：统计日当天（00:00–24:00）内，限定权益类型为固定型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    fixed_entitlement_usage_7d_rate        DECIMAL(20,6)  COMMENT '近7日固定型权益使用率：统计日及之前共 7 个自然日内，限定权益类型为固定型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    fixed_entitlement_usage_30d_rate       DECIMAL(20,6)  COMMENT '近30日固定型权益使用率：统计日及之前共 30 个自然日内，限定权益类型为固定型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    selectable_entitlement_usage_1d_rate   DECIMAL(20,6)  COMMENT '当日选择型权益使用率：统计日当天（00:00–24:00）内，限定权益类型为选择型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    selectable_entitlement_usage_7d_rate   DECIMAL(20,6)  COMMENT '近7日选择型权益使用率：统计日及之前共 7 个自然日内，限定权益类型为选择型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    selectable_entitlement_usage_30d_rate  DECIMAL(20,6)  COMMENT '近30日选择型权益使用率：统计日及之前共 30 个自然日内，限定权益类型为选择型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    counted_entitlement_usage_1d_rate      DECIMAL(20,6)  COMMENT '当日计次型权益使用率：统计日当天（00:00–24:00）内，限定权益类型为计次型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    counted_entitlement_usage_7d_rate      DECIMAL(20,6)  COMMENT '近7日计次型权益使用率：统计日及之前共 7 个自然日内，限定权益类型为计次型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    counted_entitlement_usage_30d_rate     DECIMAL(20,6)  COMMENT '近30日计次型权益使用率：统计日及之前共 30 个自然日内，限定权益类型为计次型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    timed_entitlement_usage_1d_rate        DECIMAL(20,6)  COMMENT '当日计时型权益使用率：统计日当天（00:00–24:00）内，限定权益类型为计时型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    timed_entitlement_usage_7d_rate        DECIMAL(20,6)  COMMENT '近7日计时型权益使用率：统计日及之前共 7 个自然日内，限定权益类型为计时型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    timed_entitlement_usage_30d_rate       DECIMAL(20,6)  COMMENT '近30日计时型权益使用率：统计日及之前共 30 个自然日内，限定权益类型为计时型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    unlimited_entitlement_usage_1d_rate    DECIMAL(20,6)  COMMENT '当日不限次型权益使用率：统计日当天（00:00–24:00）内，限定权益类型为不限次型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    unlimited_entitlement_usage_7d_rate    DECIMAL(20,6)  COMMENT '近7日不限次型权益使用率：统计日及之前共 7 个自然日内，限定权益类型为不限次型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    unlimited_entitlement_usage_30d_rate   DECIMAL(20,6)  COMMENT '近30日不限次型权益使用率：统计日及之前共 30 个自然日内，限定权益类型为不限次型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    quota_entitlement_usage_1d_rate        DECIMAL(20,6)  COMMENT '当日额度型权益使用率：统计日当天（00:00–24:00）内，限定权益类型为额度型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    quota_entitlement_usage_7d_rate        DECIMAL(20,6)  COMMENT '近7日额度型权益使用率：统计日及之前共 7 个自然日内，限定权益类型为额度型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    quota_entitlement_usage_30d_rate       DECIMAL(20,6)  COMMENT '近30日额度型权益使用率：统计日及之前共 30 个自然日内，限定权益类型为额度型：已用次数 / 可用总次数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    activate_ticket_1d_qty                 BIGINT         COMMENT '当日激活票数：统计日当天（00:00–24:00）内：延迟激活类票（年卡/入园后N天有效）首次核销回填有效期起始的票数，单位：张',
    activate_ticket_7d_qty                 BIGINT         COMMENT '近7日激活票数：统计日及之前共 7 个自然日内：延迟激活类票（年卡/入园后N天有效）首次核销回填有效期起始的票数，单位：张',
    activate_ticket_30d_qty                BIGINT         COMMENT '近30日激活票数：统计日及之前共 30 个自然日内：延迟激活类票（年卡/入园后N天有效）首次核销回填有效期起始的票数，单位：张',
    activate_1d_rate                       DECIMAL(20,6)  COMMENT '当日激活率：统计日当天（00:00–24:00）内：激活票数 /（激活票数 + 待激活票数）；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    activate_7d_rate                       DECIMAL(20,6)  COMMENT '近7日激活率：统计日及之前共 7 个自然日内：激活票数 /（激活票数 + 待激活票数）；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    activate_30d_rate                      DECIMAL(20,6)  COMMENT '近30日激活率：统计日及之前共 30 个自然日内：激活票数 /（激活票数 + 待激活票数）；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    avg_activate_delay_day_1d_qty          DECIMAL(18,2)  COMMENT '当日平均激活延迟天数：统计日当天（00:00–24:00）内：激活延迟天数合计 / 激活票数；分子分母取同一统计周期，单位：天',
    avg_activate_delay_day_7d_qty          DECIMAL(18,2)  COMMENT '近7日平均激活延迟天数：统计日及之前共 7 个自然日内：激活延迟天数合计 / 激活票数；分子分母取同一统计周期，单位：天',
    avg_activate_delay_day_30d_qty         DECIMAL(18,2)  COMMENT '近30日平均激活延迟天数：统计日及之前共 30 个自然日内：激活延迟天数合计 / 激活票数；分子分母取同一统计周期，单位：天',
    expire_ticket_1d_qty                   BIGINT         COMMENT '当日过期票数：统计日当天（00:00–24:00）内：变为 EXPIRED 的票数，单位：张',
    expire_ticket_7d_qty                   BIGINT         COMMENT '近7日过期票数：统计日及之前共 7 个自然日内：变为 EXPIRED 的票数，单位：张',
    expire_ticket_30d_qty                  BIGINT         COMMENT '近30日过期票数：统计日及之前共 30 个自然日内：变为 EXPIRED 的票数，单位：张',
    expire_1d_rate                         DECIMAL(20,6)  COMMENT '当日过期率：统计日当天（00:00–24:00）内：过期票数 / 出票张数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    expire_7d_rate                         DECIMAL(20,6)  COMMENT '近7日过期率：统计日及之前共 7 个自然日内：过期票数 / 出票张数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    expire_30d_rate                        DECIMAL(20,6)  COMMENT '近30日过期率：统计日及之前共 30 个自然日内：过期票数 / 出票张数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    unverified_ticket_td_qty               BIGINT         COMMENT '截至当日未核销在途票数：截至统计日日终的值：快照日状态为 AVAILABLE/PARTIALLY_USED 且未过期的票数，单位：张',
    unverified_td_amt                      DECIMAL(18,2)  COMMENT '截至当日未核销在途金额（预收）：截至统计日日终的值：在途票对应的分摊单价合计，单位：元',
    pending_activate_ticket_td_qty         BIGINT         COMMENT '截至当日待激活票数：截至统计日日终的值：快照日仍未激活的延迟激活类票数，单位：张',
    quota_total_td_amt                     DECIMAL(18,2)  COMMENT '截至当日额度型权益总额度：截至统计日日终的值：额度型权益（如园区消费金）的发放总额度；已用额度源系统暂未记录，单位：元',
    etl_time                               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '权益使用分析（年卡/次卡/计时/额度）（travel_date × seller_tenant_id × sku_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_ord_combo_analysis_di  套票分析（主子单/跨商户/部分退） ==========
CREATE TABLE IF NOT EXISTS ads.ads_ord_combo_analysis_di (
    combo_sku_id           BIGINT         COMMENT '套票主 SKU ID',
    sub_sku_id             BIGINT         COMMENT '套票子项 SKU ID',
    combo_sku_name         STRING         COMMENT '套票名称',
    sub_sku_name           STRING         COMMENT '子项 SKU 名称',
    combo_order_1d_qty     BIGINT         COMMENT '当日套票主单数：统计日当天（00:00–24:00）内：套票主单数（一单套票只算 1，子项单不计），单位：单',
    combo_order_7d_qty     BIGINT         COMMENT '近7日套票主单数：统计日及之前共 7 个自然日内：套票主单数（一单套票只算 1，子项单不计），单位：单',
    combo_order_30d_qty    BIGINT         COMMENT '近30日套票主单数：统计日及之前共 30 个自然日内：套票主单数（一单套票只算 1，子项单不计），单位：单',
    pay_1d_amt             DECIMAL(18,2)  COMMENT '当日支付金额（GMV）：统计日当天（00:00–24:00）内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_7d_amt             DECIMAL(18,2)  COMMENT '近7日支付金额（GMV）：统计日及之前共 7 个自然日内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_30d_amt            DECIMAL(18,2)  COMMENT '近30日支付金额（GMV）：统计日及之前共 30 个自然日内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_ticket_1d_qty      BIGINT         COMMENT '当日支付票数：统计日当天（00:00–24:00）内：支付成功子单的购买数量合计，单位：张',
    pay_ticket_7d_qty      BIGINT         COMMENT '近7日支付票数：统计日及之前共 7 个自然日内：支付成功子单的购买数量合计，单位：张',
    pay_ticket_30d_qty     BIGINT         COMMENT '近30日支付票数：统计日及之前共 30 个自然日内：支付成功子单的购买数量合计，单位：张',
    verify_ticket_1d_qty   BIGINT         COMMENT '当日核销票数：统计日当天（00:00–24:00）内：有成功核销的票数（同票多次只算1），单位：张',
    verify_ticket_7d_qty   BIGINT         COMMENT '近7日核销票数：统计日及之前共 7 个自然日内：有成功核销的票数（同票多次只算1），单位：张',
    verify_ticket_30d_qty  BIGINT         COMMENT '近30日核销票数：统计日及之前共 30 个自然日内：有成功核销的票数（同票多次只算1），单位：张',
    refund_ticket_1d_qty   BIGINT         COMMENT '当日退款票数：统计日当天（00:00–24:00）内：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    refund_ticket_7d_qty   BIGINT         COMMENT '近7日退款票数：统计日及之前共 7 个自然日内：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    refund_ticket_30d_qty  BIGINT         COMMENT '近30日退款票数：统计日及之前共 30 个自然日内：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    refund_1d_amt          DECIMAL(18,2)  COMMENT '当日退款金额：统计日当天（00:00–24:00）内：退款完成的金额，单位：元',
    refund_7d_amt          DECIMAL(18,2)  COMMENT '近7日退款金额：统计日及之前共 7 个自然日内：退款完成的金额，单位：元',
    refund_30d_amt         DECIMAL(18,2)  COMMENT '近30日退款金额：统计日及之前共 30 个自然日内：退款完成的金额，单位：元',
    combo_refund_1d_rate   DECIMAL(20,6)  COMMENT '当日套票部分退率：统计日当天（00:00–24:00）内：套票子项退款票数 / 套票子项支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    combo_refund_7d_rate   DECIMAL(20,6)  COMMENT '近7日套票部分退率：统计日及之前共 7 个自然日内：套票子项退款票数 / 套票子项支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    combo_refund_30d_rate  DECIMAL(20,6)  COMMENT '近30日套票部分退率：统计日及之前共 30 个自然日内：套票子项退款票数 / 套票子项支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '套票分析（主子单/跨商户/部分退）（travel_date × combo_sku_id × sub_sku_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_ord_trade_efficiency_di  交易时效分析 ==========
CREATE TABLE IF NOT EXISTS ads.ads_ord_trade_efficiency_di (
    seller_tenant_id                  BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id                            BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    seller_tenant_name                STRING         COMMENT '卖家租户名称',
    sku_name                          STRING         COMMENT 'SKU 名称',
    avg_pay_minute_1d_qty             DECIMAL(18,2)  COMMENT '当日平均支付时长：统计日当天（00:00–24:00）内：下单到支付总时长 / 支付子单数；分子分母取同一统计周期，单位：分钟',
    avg_pay_minute_7d_qty             DECIMAL(18,2)  COMMENT '近7日平均支付时长：统计日及之前共 7 个自然日内：下单到支付总时长 / 支付子单数；分子分母取同一统计周期，单位：分钟',
    avg_pay_minute_30d_qty            DECIMAL(18,2)  COMMENT '近30日平均支付时长：统计日及之前共 30 个自然日内：下单到支付总时长 / 支付子单数；分子分母取同一统计周期，单位：分钟',
    avg_refund_process_hour_1d_qty    DECIMAL(18,2)  COMMENT '当日平均退款处理时长：统计日当天（00:00–24:00）内：退款处理总时长 / 退款完成单数；分子分母取同一统计周期，单位：小时',
    avg_refund_process_hour_7d_qty    DECIMAL(18,2)  COMMENT '近7日平均退款处理时长：统计日及之前共 7 个自然日内：退款处理总时长 / 退款完成单数；分子分母取同一统计周期，单位：小时',
    avg_refund_process_hour_30d_qty   DECIMAL(18,2)  COMMENT '近30日平均退款处理时长：统计日及之前共 30 个自然日内：退款处理总时长 / 退款完成单数；分子分母取同一统计周期，单位：小时',
    avg_verify_after_pay_day_1d_qty   DECIMAL(18,2)  COMMENT '当日平均支付到核销天数：统计日当天（00:00–24:00）内：支付到首次核销天数合计 / 核销票数；分子分母取同一统计周期，单位：天',
    avg_verify_after_pay_day_7d_qty   DECIMAL(18,2)  COMMENT '近7日平均支付到核销天数：统计日及之前共 7 个自然日内：支付到首次核销天数合计 / 核销票数；分子分母取同一统计周期，单位：天',
    avg_verify_after_pay_day_30d_qty  DECIMAL(18,2)  COMMENT '近30日平均支付到核销天数：统计日及之前共 30 个自然日内：支付到首次核销天数合计 / 核销票数；分子分母取同一统计周期，单位：天',
    avg_advance_book_day_1d_qty       DECIMAL(18,2)  COMMENT '当日平均提前预订天数：统计日当天（00:00–24:00）内：提前预订天数按票加权平均；分子分母取同一统计周期，单位：天',
    avg_advance_book_day_7d_qty       DECIMAL(18,2)  COMMENT '近7日平均提前预订天数：统计日及之前共 7 个自然日内：提前预订天数按票加权平均；分子分母取同一统计周期，单位：天',
    avg_advance_book_day_30d_qty      DECIMAL(18,2)  COMMENT '近30日平均提前预订天数：统计日及之前共 30 个自然日内：提前预订天数按票加权平均；分子分母取同一统计周期，单位：天',
    timeout_cancel_order_1d_qty       BIGINT         COMMENT '当日超时取消子单数：统计日当天（00:00–24:00）内：因支付超时（PAY_TIMEOUT）取消的子单数，单位：单',
    timeout_cancel_order_7d_qty       BIGINT         COMMENT '近7日超时取消子单数：统计日及之前共 7 个自然日内：因支付超时（PAY_TIMEOUT）取消的子单数，单位：单',
    timeout_cancel_order_30d_qty      BIGINT         COMMENT '近30日超时取消子单数：统计日及之前共 30 个自然日内：因支付超时（PAY_TIMEOUT）取消的子单数，单位：单',
    etl_time                          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '交易时效分析（travel_date × seller_tenant_id × sku_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_cus_tourist_portrait_di  游客客源画像 ==========
CREATE TABLE IF NOT EXISTS ads.ads_cus_tourist_portrait_di (
    seller_tenant_id               BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    origin_province_code           STRING         COMMENT '客源省份编码',
    age_band_code                  STRING         COMMENT '年龄段：0_17-未成年，18_25-18~25岁，26_35-26~35岁，36_45-36~45岁，46_60-46~60岁，60_PLUS-60岁以上，UNKNOWN-未知',
    gender_type                    STRING         COMMENT '性别：MALE-男，FEMALE-女，UNKNOWN-未知',
    seller_tenant_name             STRING         COMMENT '卖家租户名称',
    origin_province_name           STRING         COMMENT '客源省份名称',
    tourist_1d_qty                 BIGINT         COMMENT '当日游客人数：统计日当天（00:00–24:00）内：票上登记的游客人数，单位：人',
    tourist_7d_qty                 BIGINT         COMMENT '近7日游客人数：统计日及之前共 7 个自然日内：票上登记的游客人数，单位：人',
    tourist_30d_qty                BIGINT         COMMENT '近30日游客人数：统计日及之前共 30 个自然日内：票上登记的游客人数，单位：人',
    verify_person_1d_qty           BIGINT         COMMENT '当日核销人次（入园人次）：统计日当天（00:00–24:00）内：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    verify_person_7d_qty           BIGINT         COMMENT '近7日核销人次（入园人次）：统计日及之前共 7 个自然日内：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    verify_person_30d_qty          BIGINT         COMMENT '近30日核销人次（入园人次）：统计日及之前共 30 个自然日内：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    tourist_origin_share_1d_rate   DECIMAL(20,6)  COMMENT '当日客源地占比：统计日当天（00:00–24:00）内：某客源地游客数 / 全部游客数；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    tourist_origin_share_7d_rate   DECIMAL(20,6)  COMMENT '近7日客源地占比：统计日及之前共 7 个自然日内：某客源地游客数 / 全部游客数；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    tourist_origin_share_30d_rate  DECIMAL(20,6)  COMMENT '近30日客源地占比：统计日及之前共 30 个自然日内：某客源地游客数 / 全部游客数；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    realname_1d_rate               DECIMAL(20,6)  COMMENT '当日实名率：统计日当天（00:00–24:00）内：实名票数 / 出票张数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    realname_7d_rate               DECIMAL(20,6)  COMMENT '近7日实名率：统计日及之前共 7 个自然日内：实名票数 / 出票张数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    realname_30d_rate              DECIMAL(20,6)  COMMENT '近30日实名率：统计日及之前共 30 个自然日内：实名票数 / 出票张数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    person_link_1d_rate            DECIMAL(20,6)  COMMENT '当日游客会员关联率：统计日当天（00:00–24:00）内：已关联会员的游客数 / 游客人数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    person_link_7d_rate            DECIMAL(20,6)  COMMENT '近7日游客会员关联率：统计日及之前共 7 个自然日内：已关联会员的游客数 / 游客人数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    person_link_30d_rate           DECIMAL(20,6)  COMMENT '近30日游客会员关联率：统计日及之前共 30 个自然日内：已关联会员的游客数 / 游客人数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    etl_time                       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '游客客源画像（travel_date × seller_tenant_id × origin_province_code × age_band_code × gender_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_cus_customer_rfm_df  会员RFM与复购 ==========
CREATE TABLE IF NOT EXISTS ads.ads_cus_customer_rfm_df (
    seller_tenant_id      BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    rfm_segment_code      STRING         COMMENT 'RFM 分层：HIGH_VALUE-重要价值，HIGH_KEEP-重要保持，HIGH_DEVELOP-重要发展，HIGH_RETAIN-重要挽留，GENERAL-一般',
    seller_tenant_name    STRING         COMMENT '卖家租户名称',
    pay_buyer_30d_qty     BIGINT         COMMENT '近30日支付买家数：统计日及之前共 30 个自然日内：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    repeat_buyer_30d_qty  BIGINT         COMMENT '近30日老客买家数：统计日及之前共 30 个自然日内：支付且此前已有支付的买家数，单位：人',
    repurchase_30d_rate   DECIMAL(20,6)  COMMENT '近30日复购率：统计日及之前共 30 个自然日内：复购买家数 / 支付买家数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    per_customer_30d_amt  DECIMAL(18,2)  COMMENT '近30日客单价：统计日及之前共 30 个自然日内：支付金额 / 支付买家数；分子分母取同一统计周期，单位：元',
    pay_buyer_90d_qty     BIGINT         COMMENT '近90日支付买家数：统计日及之前共 90 个自然日内：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    repeat_buyer_90d_qty  BIGINT         COMMENT '近90日老客买家数：统计日及之前共 90 个自然日内：支付且此前已有支付的买家数，单位：人',
    repurchase_90d_rate   DECIMAL(20,6)  COMMENT '近90日复购率：统计日及之前共 90 个自然日内：复购买家数 / 支付买家数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    per_customer_90d_amt  DECIMAL(18,2)  COMMENT '近90日客单价：统计日及之前共 90 个自然日内：支付金额 / 支付买家数；分子分母取同一统计周期，单位：元',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '会员RFM与复购（travel_date × seller_tenant_id × rfm_segment_code）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_cus_customer_growth_di  游客增长 ==========
CREATE TABLE IF NOT EXISTS ads.ads_cus_customer_growth_di (
    tenant_id                         BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    register_channel_id               BIGINT         COMMENT '注册渠道ID，关联 dim_trf_channel_df',
    tenant_name                       STRING         COMMENT '租户名称',
    register_channel_name             STRING         COMMENT '注册渠道名称',
    new_customer_1d_qty               BIGINT         COMMENT '当日新注册游客数：统计日当天（00:00–24:00）内：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    new_customer_7d_qty               BIGINT         COMMENT '近7日新注册游客数：统计日及之前共 7 个自然日内：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    new_customer_30d_qty              BIGINT         COMMENT '近30日新注册游客数：统计日及之前共 30 个自然日内：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    new_customer_mtd_qty              BIGINT         COMMENT '本月累计新注册游客数：统计日所在自然月 1 日至统计日：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    new_customer_ytd_qty              BIGINT         COMMENT '本年累计新注册游客数：统计日所在自然年 1 月 1 日至统计日：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    first_pay_customer_1d_qty         BIGINT         COMMENT '当日首单买家数：统计日当天（00:00–24:00）内：首次支付的真实买家数，单位：人',
    first_pay_customer_7d_qty         BIGINT         COMMENT '近7日首单买家数：统计日及之前共 7 个自然日内：首次支付的真实买家数，单位：人',
    first_pay_customer_30d_qty        BIGINT         COMMENT '近30日首单买家数：统计日及之前共 30 个自然日内：首次支付的真实买家数，单位：人',
    first_pay_customer_mtd_qty        BIGINT         COMMENT '本月累计首单买家数：统计日所在自然月 1 日至统计日：首次支付的真实买家数，单位：人',
    first_pay_customer_ytd_qty        BIGINT         COMMENT '本年累计首单买家数：统计日所在自然年 1 月 1 日至统计日：首次支付的真实买家数，单位：人',
    face_register_1d_qty              BIGINT         COMMENT '当日人脸注册数：统计日当天（00:00–24:00）内：新增 FACE 类型个人凭证数，单位：个',
    face_register_7d_qty              BIGINT         COMMENT '近7日人脸注册数：统计日及之前共 7 个自然日内：新增 FACE 类型个人凭证数，单位：个',
    face_register_30d_qty             BIGINT         COMMENT '近30日人脸注册数：统计日及之前共 30 个自然日内：新增 FACE 类型个人凭证数，单位：个',
    face_register_mtd_qty             BIGINT         COMMENT '本月累计人脸注册数：统计日所在自然月 1 日至统计日：新增 FACE 类型个人凭证数，单位：个',
    face_register_ytd_qty             BIGINT         COMMENT '本年累计人脸注册数：统计日所在自然年 1 月 1 日至统计日：新增 FACE 类型个人凭证数，单位：个',
    certified_customer_1d_qty         BIGINT         COMMENT '当日新增实名认证游客数：统计日当天（00:00–24:00）内：认证状态变为 PERSON_CERTIFIED 的游客数，单位：人',
    certified_customer_7d_qty         BIGINT         COMMENT '近7日新增实名认证游客数：统计日及之前共 7 个自然日内：认证状态变为 PERSON_CERTIFIED 的游客数，单位：人',
    certified_customer_30d_qty        BIGINT         COMMENT '近30日新增实名认证游客数：统计日及之前共 30 个自然日内：认证状态变为 PERSON_CERTIFIED 的游客数，单位：人',
    certified_customer_mtd_qty        BIGINT         COMMENT '本月累计新增实名认证游客数：统计日所在自然月 1 日至统计日：认证状态变为 PERSON_CERTIFIED 的游客数，单位：人',
    certified_customer_ytd_qty        BIGINT         COMMENT '本年累计新增实名认证游客数：统计日所在自然年 1 月 1 日至统计日：认证状态变为 PERSON_CERTIFIED 的游客数，单位：人',
    register_pay_conversion_1d_rate   DECIMAL(20,6)  COMMENT '当日注册下单转化率：统计日当天（00:00–24:00）内：注册当期下单新客数 / 新注册游客数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    register_pay_conversion_7d_rate   DECIMAL(20,6)  COMMENT '近7日注册下单转化率：统计日及之前共 7 个自然日内：注册当期下单新客数 / 新注册游客数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    register_pay_conversion_30d_rate  DECIMAL(20,6)  COMMENT '近30日注册下单转化率：统计日及之前共 30 个自然日内：注册当期下单新客数 / 新注册游客数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    new_buyer_share_1d_rate           DECIMAL(20,6)  COMMENT '当日新客占比：统计日当天（00:00–24:00）内：首单买家数 / 支付买家数；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    new_buyer_share_7d_rate           DECIMAL(20,6)  COMMENT '近7日新客占比：统计日及之前共 7 个自然日内：首单买家数 / 支付买家数；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    new_buyer_share_30d_rate          DECIMAL(20,6)  COMMENT '近30日新客占比：统计日及之前共 30 个自然日内：首单买家数 / 支付买家数；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    face_register_1d_rate             DECIMAL(20,6)  COMMENT '当日人脸注册率：统计日当天（00:00–24:00）内：人脸注册数 / 新注册游客数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    face_register_7d_rate             DECIMAL(20,6)  COMMENT '近7日人脸注册率：统计日及之前共 7 个自然日内：人脸注册数 / 新注册游客数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    face_register_30d_rate            DECIMAL(20,6)  COMMENT '近30日人脸注册率：统计日及之前共 30 个自然日内：人脸注册数 / 新注册游客数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    repeat_buyer_1d_qty               BIGINT         COMMENT '当日老客买家数：统计日当天（00:00–24:00）内：支付且此前已有支付的买家数，单位：人',
    repeat_buyer_7d_qty               BIGINT         COMMENT '近7日老客买家数：统计日及之前共 7 个自然日内：支付且此前已有支付的买家数，单位：人',
    repeat_buyer_30d_qty              BIGINT         COMMENT '近30日老客买家数：统计日及之前共 30 个自然日内：支付且此前已有支付的买家数，单位：人',
    identity_bind_1d_qty              BIGINT         COMMENT '当日渠道身份绑定数：统计日当天（00:00–24:00）内：新增的游客渠道身份（微信/抖音/支付宝/OTA），单位：个',
    identity_bind_7d_qty              BIGINT         COMMENT '近7日渠道身份绑定数：统计日及之前共 7 个自然日内：新增的游客渠道身份（微信/抖音/支付宝/OTA），单位：个',
    identity_bind_30d_qty             BIGINT         COMMENT '近30日渠道身份绑定数：统计日及之前共 30 个自然日内：新增的游客渠道身份（微信/抖音/支付宝/OTA），单位：个',
    etl_time                          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '游客增长（travel_date × tenant_id × register_channel_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_inv_stock_sellout_df  库存售罄与上座率 ==========
CREATE TABLE IF NOT EXISTS ads.ads_inv_stock_sellout_df (
    sku_id                      BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    play_date                   STRING         COMMENT '游玩日期，格式 yyyy-MM-dd',
    sku_name                    STRING         COMMENT 'SKU 名称',
    stock_total_td_qty          BIGINT         COMMENT '截至当日库存总量：截至统计日日终的值：日终库存池总量，单位：个',
    stock_available_td_qty      BIGINT         COMMENT '截至当日可用库存：截至统计日日终的值：日终库存池可用量，单位：个',
    stock_frozen_td_qty         BIGINT         COMMENT '截至当日预扣库存：截至统计日日终的值：日终库存池预扣冻结量，单位：个',
    stock_sold_td_qty           BIGINT         COMMENT '截至当日已售库存：截至统计日日终的值：总量 − 可用 − 预扣，单位：个',
    sellout_pool_td_qty         BIGINT         COMMENT '截至当日售罄库存池数：截至统计日日终的值：可用量为0且在售的池数，单位：个',
    stock_sell_through_td_rate  DECIMAL(20,6)  COMMENT '截至当日库存去化率（上座率/入住率）：截至统计日日终：已售库存 / 库存总量；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    stock_sellout_td_rate       DECIMAL(20,6)  COMMENT '截至当日售罄率：截至统计日日终：售罄池数 / 在售池数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    unit_occupied_td_qty        BIGINT         COMMENT '截至当日已占用座位/房间数：截至统计日日终的值：UNIT 资源状态为 OCCUPIED 的数量，单位：个',
    prededuct_1d_qty            BIGINT         COMMENT '当日预扣量：统计日当天（00:00–24:00）内：下单预扣的库存数量，单位：个',
    prededuct_7d_qty            BIGINT         COMMENT '近7日预扣量：统计日及之前共 7 个自然日内：下单预扣的库存数量，单位：个',
    prededuct_30d_qty           BIGINT         COMMENT '近30日预扣量：统计日及之前共 30 个自然日内：下单预扣的库存数量，单位：个',
    prededuct_release_1d_qty    BIGINT         COMMENT '当日预扣释放量：统计日当天（00:00–24:00）内：取消/超时释放的预扣数量，单位：个',
    prededuct_release_7d_qty    BIGINT         COMMENT '近7日预扣释放量：统计日及之前共 7 个自然日内：取消/超时释放的预扣数量，单位：个',
    prededuct_release_30d_qty   BIGINT         COMMENT '近30日预扣释放量：统计日及之前共 30 个自然日内：取消/超时释放的预扣数量，单位：个',
    prededuct_convert_1d_rate   DECIMAL(20,6)  COMMENT '当日预扣转化率：统计日当天（00:00–24:00）内：预扣确认量 / 预扣量；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    prededuct_convert_7d_rate   DECIMAL(20,6)  COMMENT '近7日预扣转化率：统计日及之前共 7 个自然日内：预扣确认量 / 预扣量；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    prededuct_convert_30d_rate  DECIMAL(20,6)  COMMENT '近30日预扣转化率：统计日及之前共 30 个自然日内：预扣确认量 / 预扣量；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    etl_time                    STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '库存售罄与上座率（travel_date × sku_id × play_date）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_prd_price_discount_di  价格与折扣分析 ==========
CREATE TABLE IF NOT EXISTS ads.ads_prd_price_discount_di (
    sku_id                  BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    price_channel_code      STRING         COMMENT '价格渠道编码',
    sku_name                STRING         COMMENT 'SKU 名称',
    list_price_1d_amt       DECIMAL(18,2)  COMMENT '当日生效标价：统计日当天（00:00–24:00）内：当日按价格点优先级命中的售价，单位：元',
    avg_deal_price_1d_amt   DECIMAL(18,2)  COMMENT '当日平均成交价：统计日当天（00:00–24:00）内：支付金额 / 支付票数（按 SKU×渠道）；分子分母取同一统计周期，单位：元',
    avg_deal_price_7d_amt   DECIMAL(18,2)  COMMENT '近7日平均成交价：统计日及之前共 7 个自然日内：支付金额 / 支付票数（按 SKU×渠道）；分子分母取同一统计周期，单位：元',
    avg_deal_price_30d_amt  DECIMAL(18,2)  COMMENT '近30日平均成交价：统计日及之前共 30 个自然日内：支付金额 / 支付票数（按 SKU×渠道）；分子分母取同一统计周期，单位：元',
    discount_1d_rate        DECIMAL(20,6)  COMMENT '当日成交折扣率：统计日当天（00:00–24:00）内：平均成交价 / 生效标价；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    discount_7d_rate        DECIMAL(20,6)  COMMENT '近7日成交折扣率：统计日及之前共 7 个自然日内：平均成交价 / 生效标价；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    discount_30d_rate       DECIMAL(20,6)  COMMENT '近30日成交折扣率：统计日及之前共 30 个自然日内：平均成交价 / 生效标价；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    price_change_1d_qty     BIGINT         COMMENT '当日调价次数：统计日当天（00:00–24:00）内：价格点新增/修改/删除次数，单位：次',
    price_change_7d_qty     BIGINT         COMMENT '近7日调价次数：统计日及之前共 7 个自然日内：价格点新增/修改/删除次数，单位：次',
    price_change_30d_qty    BIGINT         COMMENT '近30日调价次数：统计日及之前共 30 个自然日内：价格点新增/修改/删除次数，单位：次',
    sku_change_1d_qty       BIGINT         COMMENT '当日SKU属性变更次数：统计日当天（00:00–24:00）内：SKU 版本号变化次数（属性/成本价/退改等变更），单位：次',
    sku_change_7d_qty       BIGINT         COMMENT '近7日SKU属性变更次数：统计日及之前共 7 个自然日内：SKU 版本号变化次数（属性/成本价/退改等变更），单位：次',
    sku_change_30d_qty      BIGINT         COMMENT '近30日SKU属性变更次数：统计日及之前共 30 个自然日内：SKU 版本号变化次数（属性/成本价/退改等变更），单位：次',
    etl_time                STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '价格与折扣分析（travel_date × sku_id × price_channel_code）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_trf_distributor_rank_di  分销商业绩排行 ==========
CREATE TABLE IF NOT EXISTS ads.ads_trf_distributor_rank_di (
    supplier_tenant_id                 BIGINT         COMMENT '供应商租户ID，关联 dim_sup_tenant_zip',
    distributor_tenant_id              BIGINT         COMMENT '分销商租户ID，关联 dim_sup_tenant_zip',
    supplier_tenant_name               STRING         COMMENT '供应商名称',
    distributor_tenant_name            STRING         COMMENT '分销商名称',
    distribution_ticket_1d_qty         BIGINT         COMMENT '当日分销票数：统计日当天（00:00–24:00）内：经过分销链（有 OUTBOUND 采购）的票数，单位：张',
    distribution_ticket_7d_qty         BIGINT         COMMENT '近7日分销票数：统计日及之前共 7 个自然日内：经过分销链（有 OUTBOUND 采购）的票数，单位：张',
    distribution_ticket_30d_qty        BIGINT         COMMENT '近30日分销票数：统计日及之前共 30 个自然日内：经过分销链（有 OUTBOUND 采购）的票数，单位：张',
    distribution_sale_1d_amt           DECIMAL(18,2)  COMMENT '当日分销售出金额：统计日当天（00:00–24:00）内：本级卖出价（下级付给本级的金额），单位：元',
    distribution_sale_7d_amt           DECIMAL(18,2)  COMMENT '近7日分销售出金额：统计日及之前共 7 个自然日内：本级卖出价（下级付给本级的金额），单位：元',
    distribution_sale_30d_amt          DECIMAL(18,2)  COMMENT '近30日分销售出金额：统计日及之前共 30 个自然日内：本级卖出价（下级付给本级的金额），单位：元',
    distribution_profit_1d_amt         DECIMAL(18,2)  COMMENT '当日分销利润：统计日当天（00:00–24:00）内：本级售出 − 本级采购，单位：元',
    distribution_profit_7d_amt         DECIMAL(18,2)  COMMENT '近7日分销利润：统计日及之前共 7 个自然日内：本级售出 − 本级采购，单位：元',
    distribution_profit_30d_amt        DECIMAL(18,2)  COMMENT '近30日分销利润：统计日及之前共 30 个自然日内：本级售出 − 本级采购，单位：元',
    distribution_profit_1d_rate        DECIMAL(20,6)  COMMENT '当日分销利润率：统计日当天（00:00–24:00）内：分销利润 / 分销售出金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    distribution_profit_7d_rate        DECIMAL(20,6)  COMMENT '近7日分销利润率：统计日及之前共 7 个自然日内：分销利润 / 分销售出金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    distribution_profit_30d_rate       DECIMAL(20,6)  COMMENT '近30日分销利润率：统计日及之前共 30 个自然日内：分销利润 / 分销售出金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    active_distributor_1d_qty          BIGINT         COMMENT '当日动销分销商数：统计日当天（00:00–24:00）内：有分销票的分销商数，单位：家',
    active_distributor_7d_qty          BIGINT         COMMENT '近7日动销分销商数：统计日及之前共 7 个自然日内：有分销票的分销商数，单位：家',
    active_distributor_30d_qty         BIGINT         COMMENT '近30日动销分销商数：统计日及之前共 30 个自然日内：有分销票的分销商数，单位：家',
    new_distribution_relation_1d_qty   BIGINT         COMMENT '当日新建分销关系数：统计日当天（00:00–24:00）内：新建的分销关系数，单位：条',
    new_distribution_relation_7d_qty   BIGINT         COMMENT '近7日新建分销关系数：统计日及之前共 7 个自然日内：新建的分销关系数，单位：条',
    new_distribution_relation_30d_qty  BIGINT         COMMENT '近30日新建分销关系数：统计日及之前共 30 个自然日内：新建的分销关系数，单位：条',
    etl_time                           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '分销商业绩排行（travel_date × supplier_tenant_id × distributor_tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_trf_chain_profit_di  分销链利润分配 ==========
CREATE TABLE IF NOT EXISTS ads.ads_trf_chain_profit_di (
    supplier_tenant_id                BIGINT         COMMENT '供应商租户ID，关联 dim_sup_tenant_zip',
    sku_id                            BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    supplier_tenant_name              STRING         COMMENT '供应商名称',
    sku_name                          STRING         COMMENT 'SKU 名称',
    l1_distribution_purchase_1d_amt   DECIMAL(18,2)  COMMENT '当日一级分销采购金额：统计日当天（00:00–24:00）内，限定分销层级为一级：本级向上级采购的金额，单位：元',
    l1_distribution_purchase_7d_amt   DECIMAL(18,2)  COMMENT '近7日一级分销采购金额：统计日及之前共 7 个自然日内，限定分销层级为一级：本级向上级采购的金额，单位：元',
    l1_distribution_purchase_30d_amt  DECIMAL(18,2)  COMMENT '近30日一级分销采购金额：统计日及之前共 30 个自然日内，限定分销层级为一级：本级向上级采购的金额，单位：元',
    l2_distribution_purchase_1d_amt   DECIMAL(18,2)  COMMENT '当日二级分销采购金额：统计日当天（00:00–24:00）内，限定分销层级为二级：本级向上级采购的金额，单位：元',
    l2_distribution_purchase_7d_amt   DECIMAL(18,2)  COMMENT '近7日二级分销采购金额：统计日及之前共 7 个自然日内，限定分销层级为二级：本级向上级采购的金额，单位：元',
    l2_distribution_purchase_30d_amt  DECIMAL(18,2)  COMMENT '近30日二级分销采购金额：统计日及之前共 30 个自然日内，限定分销层级为二级：本级向上级采购的金额，单位：元',
    l3_distribution_purchase_1d_amt   DECIMAL(18,2)  COMMENT '当日三级分销采购金额：统计日当天（00:00–24:00）内，限定分销层级为三级：本级向上级采购的金额，单位：元',
    l3_distribution_purchase_7d_amt   DECIMAL(18,2)  COMMENT '近7日三级分销采购金额：统计日及之前共 7 个自然日内，限定分销层级为三级：本级向上级采购的金额，单位：元',
    l3_distribution_purchase_30d_amt  DECIMAL(18,2)  COMMENT '近30日三级分销采购金额：统计日及之前共 30 个自然日内，限定分销层级为三级：本级向上级采购的金额，单位：元',
    l4_distribution_purchase_1d_amt   DECIMAL(18,2)  COMMENT '当日四级分销采购金额：统计日当天（00:00–24:00）内，限定分销层级为四级：本级向上级采购的金额，单位：元',
    l4_distribution_purchase_7d_amt   DECIMAL(18,2)  COMMENT '近7日四级分销采购金额：统计日及之前共 7 个自然日内，限定分销层级为四级：本级向上级采购的金额，单位：元',
    l4_distribution_purchase_30d_amt  DECIMAL(18,2)  COMMENT '近30日四级分销采购金额：统计日及之前共 30 个自然日内，限定分销层级为四级：本级向上级采购的金额，单位：元',
    l1_distribution_profit_1d_amt     DECIMAL(18,2)  COMMENT '当日一级分销利润：统计日当天（00:00–24:00）内，限定分销层级为一级：本级售出 − 本级采购，单位：元',
    l1_distribution_profit_7d_amt     DECIMAL(18,2)  COMMENT '近7日一级分销利润：统计日及之前共 7 个自然日内，限定分销层级为一级：本级售出 − 本级采购，单位：元',
    l1_distribution_profit_30d_amt    DECIMAL(18,2)  COMMENT '近30日一级分销利润：统计日及之前共 30 个自然日内，限定分销层级为一级：本级售出 − 本级采购，单位：元',
    l2_distribution_profit_1d_amt     DECIMAL(18,2)  COMMENT '当日二级分销利润：统计日当天（00:00–24:00）内，限定分销层级为二级：本级售出 − 本级采购，单位：元',
    l2_distribution_profit_7d_amt     DECIMAL(18,2)  COMMENT '近7日二级分销利润：统计日及之前共 7 个自然日内，限定分销层级为二级：本级售出 − 本级采购，单位：元',
    l2_distribution_profit_30d_amt    DECIMAL(18,2)  COMMENT '近30日二级分销利润：统计日及之前共 30 个自然日内，限定分销层级为二级：本级售出 − 本级采购，单位：元',
    l3_distribution_profit_1d_amt     DECIMAL(18,2)  COMMENT '当日三级分销利润：统计日当天（00:00–24:00）内，限定分销层级为三级：本级售出 − 本级采购，单位：元',
    l3_distribution_profit_7d_amt     DECIMAL(18,2)  COMMENT '近7日三级分销利润：统计日及之前共 7 个自然日内，限定分销层级为三级：本级售出 − 本级采购，单位：元',
    l3_distribution_profit_30d_amt    DECIMAL(18,2)  COMMENT '近30日三级分销利润：统计日及之前共 30 个自然日内，限定分销层级为三级：本级售出 − 本级采购，单位：元',
    l4_distribution_profit_1d_amt     DECIMAL(18,2)  COMMENT '当日四级分销利润：统计日当天（00:00–24:00）内，限定分销层级为四级：本级售出 − 本级采购，单位：元',
    l4_distribution_profit_7d_amt     DECIMAL(18,2)  COMMENT '近7日四级分销利润：统计日及之前共 7 个自然日内，限定分销层级为四级：本级售出 − 本级采购，单位：元',
    l4_distribution_profit_30d_amt    DECIMAL(18,2)  COMMENT '近30日四级分销利润：统计日及之前共 30 个自然日内，限定分销层级为四级：本级售出 − 本级采购，单位：元',
    l1_distribution_profit_1d_rate    DECIMAL(20,6)  COMMENT '当日一级分销利润率：统计日当天（00:00–24:00）内，限定分销层级为一级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    l1_distribution_profit_7d_rate    DECIMAL(20,6)  COMMENT '近7日一级分销利润率：统计日及之前共 7 个自然日内，限定分销层级为一级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    l1_distribution_profit_30d_rate   DECIMAL(20,6)  COMMENT '近30日一级分销利润率：统计日及之前共 30 个自然日内，限定分销层级为一级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    l2_distribution_profit_1d_rate    DECIMAL(20,6)  COMMENT '当日二级分销利润率：统计日当天（00:00–24:00）内，限定分销层级为二级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    l2_distribution_profit_7d_rate    DECIMAL(20,6)  COMMENT '近7日二级分销利润率：统计日及之前共 7 个自然日内，限定分销层级为二级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    l2_distribution_profit_30d_rate   DECIMAL(20,6)  COMMENT '近30日二级分销利润率：统计日及之前共 30 个自然日内，限定分销层级为二级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    l3_distribution_profit_1d_rate    DECIMAL(20,6)  COMMENT '当日三级分销利润率：统计日当天（00:00–24:00）内，限定分销层级为三级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    l3_distribution_profit_7d_rate    DECIMAL(20,6)  COMMENT '近7日三级分销利润率：统计日及之前共 7 个自然日内，限定分销层级为三级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    l3_distribution_profit_30d_rate   DECIMAL(20,6)  COMMENT '近30日三级分销利润率：统计日及之前共 30 个自然日内，限定分销层级为三级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    l4_distribution_profit_1d_rate    DECIMAL(20,6)  COMMENT '当日四级分销利润率：统计日当天（00:00–24:00）内，限定分销层级为四级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    l4_distribution_profit_7d_rate    DECIMAL(20,6)  COMMENT '近7日四级分销利润率：统计日及之前共 7 个自然日内，限定分销层级为四级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    l4_distribution_profit_30d_rate   DECIMAL(20,6)  COMMENT '近30日四级分销利润率：统计日及之前共 30 个自然日内，限定分销层级为四级：分销利润 / 分销售出金额；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    avg_chain_level_1d_qty            DECIMAL(18,2)  COMMENT '当日平均分销层级：统计日当天（00:00–24:00）内：分销层级合计 / 分销票数；分子分母取同一统计周期，单位：级',
    avg_chain_level_7d_qty            DECIMAL(18,2)  COMMENT '近7日平均分销层级：统计日及之前共 7 个自然日内：分销层级合计 / 分销票数；分子分母取同一统计周期，单位：级',
    avg_chain_level_30d_qty           DECIMAL(18,2)  COMMENT '近30日平均分销层级：统计日及之前共 30 个自然日内：分销层级合计 / 分销票数；分子分母取同一统计周期，单位：级',
    etl_time                          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '分销链利润分配（travel_date × supplier_tenant_id × sku_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_fin_tenant_settlement_di  商户结算对账 ==========
CREATE TABLE IF NOT EXISTS ads.ads_fin_tenant_settlement_di (
    tenant_id                  BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    tenant_name                STRING         COMMENT '租户名称',
    inbound_pay_1d_amt         DECIMAL(18,2)  COMMENT '当日收款金额：统计日当天（00:00–24:00）内：INBOUND 方向已支付金额，单位：元',
    inbound_pay_7d_amt         DECIMAL(18,2)  COMMENT '近7日收款金额：统计日及之前共 7 个自然日内：INBOUND 方向已支付金额，单位：元',
    inbound_pay_30d_amt        DECIMAL(18,2)  COMMENT '近30日收款金额：统计日及之前共 30 个自然日内：INBOUND 方向已支付金额，单位：元',
    inbound_pay_mtd_amt        DECIMAL(18,2)  COMMENT '本月累计收款金额：统计日所在自然月 1 日至统计日：INBOUND 方向已支付金额，单位：元',
    inbound_pay_ytd_amt        DECIMAL(18,2)  COMMENT '本年累计收款金额：统计日所在自然年 1 月 1 日至统计日：INBOUND 方向已支付金额，单位：元',
    outbound_pay_1d_amt        DECIMAL(18,2)  COMMENT '当日采购付款金额：统计日当天（00:00–24:00）内：OUTBOUND 方向已支付金额，单位：元',
    outbound_pay_7d_amt        DECIMAL(18,2)  COMMENT '近7日采购付款金额：统计日及之前共 7 个自然日内：OUTBOUND 方向已支付金额，单位：元',
    outbound_pay_30d_amt       DECIMAL(18,2)  COMMENT '近30日采购付款金额：统计日及之前共 30 个自然日内：OUTBOUND 方向已支付金额，单位：元',
    outbound_pay_mtd_amt       DECIMAL(18,2)  COMMENT '本月累计采购付款金额：统计日所在自然月 1 日至统计日：OUTBOUND 方向已支付金额，单位：元',
    outbound_pay_ytd_amt       DECIMAL(18,2)  COMMENT '本年累计采购付款金额：统计日所在自然年 1 月 1 日至统计日：OUTBOUND 方向已支付金额，单位：元',
    refund_payment_1d_amt      DECIMAL(18,2)  COMMENT '当日退款资金金额：统计日当天（00:00–24:00）内：退款明细状态 SUCCESS 的金额，单位：元',
    refund_payment_7d_amt      DECIMAL(18,2)  COMMENT '近7日退款资金金额：统计日及之前共 7 个自然日内：退款明细状态 SUCCESS 的金额，单位：元',
    refund_payment_30d_amt     DECIMAL(18,2)  COMMENT '近30日退款资金金额：统计日及之前共 30 个自然日内：退款明细状态 SUCCESS 的金额，单位：元',
    refund_payment_mtd_amt     DECIMAL(18,2)  COMMENT '本月累计退款资金金额：统计日所在自然月 1 日至统计日：退款明细状态 SUCCESS 的金额，单位：元',
    refund_payment_ytd_amt     DECIMAL(18,2)  COMMENT '本年累计退款资金金额：统计日所在自然年 1 月 1 日至统计日：退款明细状态 SUCCESS 的金额，单位：元',
    freeze_1d_amt              DECIMAL(18,2)  COMMENT '当日冻结金额：统计日当天（00:00–24:00）内：新建冻结记录金额，单位：元',
    freeze_7d_amt              DECIMAL(18,2)  COMMENT '近7日冻结金额：统计日及之前共 7 个自然日内：新建冻结记录金额，单位：元',
    freeze_30d_amt             DECIMAL(18,2)  COMMENT '近30日冻结金额：统计日及之前共 30 个自然日内：新建冻结记录金额，单位：元',
    freeze_mtd_amt             DECIMAL(18,2)  COMMENT '本月累计冻结金额：统计日所在自然月 1 日至统计日：新建冻结记录金额，单位：元',
    freeze_ytd_amt             DECIMAL(18,2)  COMMENT '本年累计冻结金额：统计日所在自然年 1 月 1 日至统计日：新建冻结记录金额，单位：元',
    unfreeze_verify_1d_amt     DECIMAL(18,2)  COMMENT '当日核销解冻金额：统计日当天（00:00–24:00）内：因核销释放的冻结金额，单位：元',
    unfreeze_verify_7d_amt     DECIMAL(18,2)  COMMENT '近7日核销解冻金额：统计日及之前共 7 个自然日内：因核销释放的冻结金额，单位：元',
    unfreeze_verify_30d_amt    DECIMAL(18,2)  COMMENT '近30日核销解冻金额：统计日及之前共 30 个自然日内：因核销释放的冻结金额，单位：元',
    unfreeze_verify_mtd_amt    DECIMAL(18,2)  COMMENT '本月累计核销解冻金额：统计日所在自然月 1 日至统计日：因核销释放的冻结金额，单位：元',
    unfreeze_verify_ytd_amt    DECIMAL(18,2)  COMMENT '本年累计核销解冻金额：统计日所在自然年 1 月 1 日至统计日：因核销释放的冻结金额，单位：元',
    unfreeze_refund_1d_amt     DECIMAL(18,2)  COMMENT '当日退款释放金额：统计日当天（00:00–24:00）内：因退款释放的冻结金额，单位：元',
    unfreeze_refund_7d_amt     DECIMAL(18,2)  COMMENT '近7日退款释放金额：统计日及之前共 7 个自然日内：因退款释放的冻结金额，单位：元',
    unfreeze_refund_30d_amt    DECIMAL(18,2)  COMMENT '近30日退款释放金额：统计日及之前共 30 个自然日内：因退款释放的冻结金额，单位：元',
    unfreeze_refund_mtd_amt    DECIMAL(18,2)  COMMENT '本月累计退款释放金额：统计日所在自然月 1 日至统计日：因退款释放的冻结金额，单位：元',
    unfreeze_refund_ytd_amt    DECIMAL(18,2)  COMMENT '本年累计退款释放金额：统计日所在自然年 1 月 1 日至统计日：因退款释放的冻结金额，单位：元',
    fee_1d_amt                 DECIMAL(18,2)  COMMENT '当日手续费金额：统计日当天（00:00–24:00）内：账户被扣的手续费金额（提现手续费、短信费等），单位：元',
    fee_7d_amt                 DECIMAL(18,2)  COMMENT '近7日手续费金额：统计日及之前共 7 个自然日内：账户被扣的手续费金额（提现手续费、短信费等），单位：元',
    fee_30d_amt                DECIMAL(18,2)  COMMENT '近30日手续费金额：统计日及之前共 30 个自然日内：账户被扣的手续费金额（提现手续费、短信费等），单位：元',
    fee_mtd_amt                DECIMAL(18,2)  COMMENT '本月累计手续费金额：统计日所在自然月 1 日至统计日：账户被扣的手续费金额（提现手续费、短信费等），单位：元',
    fee_ytd_amt                DECIMAL(18,2)  COMMENT '本年累计手续费金额：统计日所在自然年 1 月 1 日至统计日：账户被扣的手续费金额（提现手续费、短信费等），单位：元',
    profit_freeze_1d_amt       DECIMAL(18,2)  COMMENT '当日利润冻结冻结金额：统计日当天（00:00–24:00）内，限定冻结类型为利润冻结：新建冻结记录金额，单位：元',
    profit_freeze_7d_amt       DECIMAL(18,2)  COMMENT '近7日利润冻结冻结金额：统计日及之前共 7 个自然日内，限定冻结类型为利润冻结：新建冻结记录金额，单位：元',
    profit_freeze_30d_amt      DECIMAL(18,2)  COMMENT '近30日利润冻结冻结金额：统计日及之前共 30 个自然日内，限定冻结类型为利润冻结：新建冻结记录金额，单位：元',
    settlement_freeze_1d_amt   DECIMAL(18,2)  COMMENT '当日采购款冻结冻结金额：统计日当天（00:00–24:00）内，限定冻结类型为采购款冻结：新建冻结记录金额，单位：元',
    settlement_freeze_7d_amt   DECIMAL(18,2)  COMMENT '近7日采购款冻结冻结金额：统计日及之前共 7 个自然日内，限定冻结类型为采购款冻结：新建冻结记录金额，单位：元',
    settlement_freeze_30d_amt  DECIMAL(18,2)  COMMENT '近30日采购款冻结冻结金额：统计日及之前共 30 个自然日内，限定冻结类型为采购款冻结：新建冻结记录金额，单位：元',
    full_freeze_1d_amt         DECIMAL(18,2)  COMMENT '当日全款冻结冻结金额：统计日当天（00:00–24:00）内，限定冻结类型为全款冻结：新建冻结记录金额，单位：元',
    full_freeze_7d_amt         DECIMAL(18,2)  COMMENT '近7日全款冻结冻结金额：统计日及之前共 7 个自然日内，限定冻结类型为全款冻结：新建冻结记录金额，单位：元',
    full_freeze_30d_amt        DECIMAL(18,2)  COMMENT '近30日全款冻结冻结金额：统计日及之前共 30 个自然日内，限定冻结类型为全款冻结：新建冻结记录金额，单位：元',
    external_freeze_1d_amt     DECIMAL(18,2)  COMMENT '当日外部渠道冻结金额：统计日当天（00:00–24:00）内：由第三方支付渠道（如易宝分账）原生冻结的金额，单位：元',
    external_freeze_7d_amt     DECIMAL(18,2)  COMMENT '近7日外部渠道冻结金额：统计日及之前共 7 个自然日内：由第三方支付渠道（如易宝分账）原生冻结的金额，单位：元',
    external_freeze_30d_amt    DECIMAL(18,2)  COMMENT '近30日外部渠道冻结金额：统计日及之前共 30 个自然日内：由第三方支付渠道（如易宝分账）原生冻结的金额，单位：元',
    external_freeze_1d_rate    DECIMAL(20,6)  COMMENT '当日外部冻结占比：统计日当天（00:00–24:00）内：外部渠道冻结金额 / 冻结金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    external_freeze_7d_rate    DECIMAL(20,6)  COMMENT '近7日外部冻结占比：统计日及之前共 7 个自然日内：外部渠道冻结金额 / 冻结金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    external_freeze_30d_rate   DECIMAL(20,6)  COMMENT '近30日外部冻结占比：统计日及之前共 30 个自然日内：外部渠道冻结金额 / 冻结金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    expire_release_1d_amt      DECIMAL(18,2)  COMMENT '当日过期兜底释放金额：统计日当天（00:00–24:00）内：票过期 30 天后由定时任务释放的冻结金额，单位：元',
    expire_release_7d_amt      DECIMAL(18,2)  COMMENT '近7日过期兜底释放金额：统计日及之前共 7 个自然日内：票过期 30 天后由定时任务释放的冻结金额，单位：元',
    expire_release_30d_amt     DECIMAL(18,2)  COMMENT '近30日过期兜底释放金额：统计日及之前共 30 个自然日内：票过期 30 天后由定时任务释放的冻结金额，单位：元',
    invoice_1d_amt             DECIMAL(18,2)  COMMENT '当日开票金额：统计日当天（00:00–24:00）内：状态 INVOICED 的发票金额，单位：元',
    invoice_7d_amt             DECIMAL(18,2)  COMMENT '近7日开票金额：统计日及之前共 7 个自然日内：状态 INVOICED 的发票金额，单位：元',
    invoice_30d_amt            DECIMAL(18,2)  COMMENT '近30日开票金额：统计日及之前共 30 个自然日内：状态 INVOICED 的发票金额，单位：元',
    invoice_order_1d_qty       BIGINT         COMMENT '当日开票订单数：统计日当天（00:00–24:00）内：已开票的聚合单数（商户给游客），单位：单',
    invoice_order_7d_qty       BIGINT         COMMENT '近7日开票订单数：统计日及之前共 7 个自然日内：已开票的聚合单数（商户给游客），单位：单',
    invoice_order_30d_qty      BIGINT         COMMENT '近30日开票订单数：统计日及之前共 30 个自然日内：已开票的聚合单数（商户给游客），单位：单',
    invoice_1d_rate            DECIMAL(20,6)  COMMENT '当日开票率：统计日当天（00:00–24:00）内：开票订单数 / 支付聚合单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    invoice_7d_rate            DECIMAL(20,6)  COMMENT '近7日开票率：统计日及之前共 7 个自然日内：开票订单数 / 支付聚合单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    invoice_30d_rate           DECIMAL(20,6)  COMMENT '近30日开票率：统计日及之前共 30 个自然日内：开票订单数 / 支付聚合单数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    etl_time                   STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户结算对账（travel_date × tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_fin_account_fund_df  账户资金看板 ==========
CREATE TABLE IF NOT EXISTS ads.ads_fin_account_fund_df (
    account_no                 STRING         COMMENT '账户编号，关联 dim_fin_account_df',
    available_balance_td_amt   DECIMAL(18,2)  COMMENT '截至当日可用余额：截至统计日日终的值：日终账户可用余额，单位：元',
    frozen_balance_td_amt      DECIMAL(18,2)  COMMENT '截至当日冻结余额：截至统计日日终的值：日终账户冻结余额，单位：元',
    credit_limit_td_amt        DECIMAL(18,2)  COMMENT '截至当日授信额度：截至统计日日终的值：分销关系授信额度，单位：元',
    credit_used_td_amt         DECIMAL(18,2)  COMMENT '截至当日已用授信：截至统计日日终的值：分销关系已用授信，单位：元',
    credit_usage_td_rate       DECIMAL(20,6)  COMMENT '截至当日授信使用率：截至统计日日终：已用授信 / 授信额度；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    withdraw_apply_1d_amt      DECIMAL(18,2)  COMMENT '当日提现申请金额：统计日当天（00:00–24:00）内：发起的提现金额，单位：元',
    withdraw_apply_7d_amt      DECIMAL(18,2)  COMMENT '近7日提现申请金额：统计日及之前共 7 个自然日内：发起的提现金额，单位：元',
    withdraw_apply_30d_amt     DECIMAL(18,2)  COMMENT '近30日提现申请金额：统计日及之前共 30 个自然日内：发起的提现金额，单位：元',
    withdraw_apply_mtd_amt     DECIMAL(18,2)  COMMENT '本月累计提现申请金额：统计日所在自然月 1 日至统计日：发起的提现金额，单位：元',
    withdraw_apply_ytd_amt     DECIMAL(18,2)  COMMENT '本年累计提现申请金额：统计日所在自然年 1 月 1 日至统计日：发起的提现金额，单位：元',
    withdraw_success_1d_amt    DECIMAL(18,2)  COMMENT '当日提现成功金额：统计日当天（00:00–24:00）内：状态 COMPLETED 的提现金额，单位：元',
    withdraw_success_7d_amt    DECIMAL(18,2)  COMMENT '近7日提现成功金额：统计日及之前共 7 个自然日内：状态 COMPLETED 的提现金额，单位：元',
    withdraw_success_30d_amt   DECIMAL(18,2)  COMMENT '近30日提现成功金额：统计日及之前共 30 个自然日内：状态 COMPLETED 的提现金额，单位：元',
    withdraw_success_mtd_amt   DECIMAL(18,2)  COMMENT '本月累计提现成功金额：统计日所在自然月 1 日至统计日：状态 COMPLETED 的提现金额，单位：元',
    withdraw_success_ytd_amt   DECIMAL(18,2)  COMMENT '本年累计提现成功金额：统计日所在自然年 1 月 1 日至统计日：状态 COMPLETED 的提现金额，单位：元',
    withdraw_fail_1d_qty       BIGINT         COMMENT '当日提现失败笔数：统计日当天（00:00–24:00）内：状态 FAILED/REJECTED 的提现单数，单位：笔',
    withdraw_fail_7d_qty       BIGINT         COMMENT '近7日提现失败笔数：统计日及之前共 7 个自然日内：状态 FAILED/REJECTED 的提现单数，单位：笔',
    withdraw_fail_30d_qty      BIGINT         COMMENT '近30日提现失败笔数：统计日及之前共 30 个自然日内：状态 FAILED/REJECTED 的提现单数，单位：笔',
    withdraw_success_1d_rate   DECIMAL(20,6)  COMMENT '当日提现成功率：统计日当天（00:00–24:00）内：提现成功金额 / 提现申请金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    withdraw_success_7d_rate   DECIMAL(20,6)  COMMENT '近7日提现成功率：统计日及之前共 7 个自然日内：提现成功金额 / 提现申请金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    withdraw_success_30d_rate  DECIMAL(20,6)  COMMENT '近30日提现成功率：统计日及之前共 30 个自然日内：提现成功金额 / 提现申请金额；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    etl_time                   STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '账户资金看板（travel_date × account_no）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_fin_pay_method_di  支付方式结构 ==========
CREATE TABLE IF NOT EXISTS ads.ads_fin_pay_method_di (
    tenant_id                          BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    tenant_name                        STRING         COMMENT '租户名称',
    wechat_inbound_pay_1d_amt          DECIMAL(18,2)  COMMENT '当日微信收款金额：统计日当天（00:00–24:00）内，限定支付方式为微信：INBOUND 方向已支付金额，单位：元',
    wechat_inbound_pay_7d_amt          DECIMAL(18,2)  COMMENT '近7日微信收款金额：统计日及之前共 7 个自然日内，限定支付方式为微信：INBOUND 方向已支付金额，单位：元',
    wechat_inbound_pay_30d_amt         DECIMAL(18,2)  COMMENT '近30日微信收款金额：统计日及之前共 30 个自然日内，限定支付方式为微信：INBOUND 方向已支付金额，单位：元',
    alipay_inbound_pay_1d_amt          DECIMAL(18,2)  COMMENT '当日支付宝收款金额：统计日当天（00:00–24:00）内，限定支付方式为支付宝：INBOUND 方向已支付金额，单位：元',
    alipay_inbound_pay_7d_amt          DECIMAL(18,2)  COMMENT '近7日支付宝收款金额：统计日及之前共 7 个自然日内，限定支付方式为支付宝：INBOUND 方向已支付金额，单位：元',
    alipay_inbound_pay_30d_amt         DECIMAL(18,2)  COMMENT '近30日支付宝收款金额：统计日及之前共 30 个自然日内，限定支付方式为支付宝：INBOUND 方向已支付金额，单位：元',
    balance_inbound_pay_1d_amt         DECIMAL(18,2)  COMMENT '当日余额收款金额：统计日当天（00:00–24:00）内，限定支付方式为余额：INBOUND 方向已支付金额，单位：元',
    balance_inbound_pay_7d_amt         DECIMAL(18,2)  COMMENT '近7日余额收款金额：统计日及之前共 7 个自然日内，限定支付方式为余额：INBOUND 方向已支付金额，单位：元',
    balance_inbound_pay_30d_amt        DECIMAL(18,2)  COMMENT '近30日余额收款金额：统计日及之前共 30 个自然日内，限定支付方式为余额：INBOUND 方向已支付金额，单位：元',
    credit_inbound_pay_1d_amt          DECIMAL(18,2)  COMMENT '当日授信收款金额：统计日当天（00:00–24:00）内，限定支付方式为授信：INBOUND 方向已支付金额，单位：元',
    credit_inbound_pay_7d_amt          DECIMAL(18,2)  COMMENT '近7日授信收款金额：统计日及之前共 7 个自然日内，限定支付方式为授信：INBOUND 方向已支付金额，单位：元',
    credit_inbound_pay_30d_amt         DECIMAL(18,2)  COMMENT '近30日授信收款金额：统计日及之前共 30 个自然日内，限定支付方式为授信：INBOUND 方向已支付金额，单位：元',
    offline_inbound_pay_1d_amt         DECIMAL(18,2)  COMMENT '当日线下收款收款金额：统计日当天（00:00–24:00）内，限定支付方式为线下收款：INBOUND 方向已支付金额，单位：元',
    offline_inbound_pay_7d_amt         DECIMAL(18,2)  COMMENT '近7日线下收款收款金额：统计日及之前共 7 个自然日内，限定支付方式为线下收款：INBOUND 方向已支付金额，单位：元',
    offline_inbound_pay_30d_amt        DECIMAL(18,2)  COMMENT '近30日线下收款收款金额：统计日及之前共 30 个自然日内，限定支付方式为线下收款：INBOUND 方向已支付金额，单位：元',
    wechat_pay_record_1d_qty           BIGINT         COMMENT '当日微信支付笔数：统计日当天（00:00–24:00）内，限定支付方式为微信：状态为 PAID 的支付记录数，单位：笔',
    wechat_pay_record_7d_qty           BIGINT         COMMENT '近7日微信支付笔数：统计日及之前共 7 个自然日内，限定支付方式为微信：状态为 PAID 的支付记录数，单位：笔',
    wechat_pay_record_30d_qty          BIGINT         COMMENT '近30日微信支付笔数：统计日及之前共 30 个自然日内，限定支付方式为微信：状态为 PAID 的支付记录数，单位：笔',
    alipay_pay_record_1d_qty           BIGINT         COMMENT '当日支付宝支付笔数：统计日当天（00:00–24:00）内，限定支付方式为支付宝：状态为 PAID 的支付记录数，单位：笔',
    alipay_pay_record_7d_qty           BIGINT         COMMENT '近7日支付宝支付笔数：统计日及之前共 7 个自然日内，限定支付方式为支付宝：状态为 PAID 的支付记录数，单位：笔',
    alipay_pay_record_30d_qty          BIGINT         COMMENT '近30日支付宝支付笔数：统计日及之前共 30 个自然日内，限定支付方式为支付宝：状态为 PAID 的支付记录数，单位：笔',
    balance_pay_record_1d_qty          BIGINT         COMMENT '当日余额支付笔数：统计日当天（00:00–24:00）内，限定支付方式为余额：状态为 PAID 的支付记录数，单位：笔',
    balance_pay_record_7d_qty          BIGINT         COMMENT '近7日余额支付笔数：统计日及之前共 7 个自然日内，限定支付方式为余额：状态为 PAID 的支付记录数，单位：笔',
    balance_pay_record_30d_qty         BIGINT         COMMENT '近30日余额支付笔数：统计日及之前共 30 个自然日内，限定支付方式为余额：状态为 PAID 的支付记录数，单位：笔',
    credit_pay_record_1d_qty           BIGINT         COMMENT '当日授信支付笔数：统计日当天（00:00–24:00）内，限定支付方式为授信：状态为 PAID 的支付记录数，单位：笔',
    credit_pay_record_7d_qty           BIGINT         COMMENT '近7日授信支付笔数：统计日及之前共 7 个自然日内，限定支付方式为授信：状态为 PAID 的支付记录数，单位：笔',
    credit_pay_record_30d_qty          BIGINT         COMMENT '近30日授信支付笔数：统计日及之前共 30 个自然日内，限定支付方式为授信：状态为 PAID 的支付记录数，单位：笔',
    offline_pay_record_1d_qty          BIGINT         COMMENT '当日线下收款支付笔数：统计日当天（00:00–24:00）内，限定支付方式为线下收款：状态为 PAID 的支付记录数，单位：笔',
    offline_pay_record_7d_qty          BIGINT         COMMENT '近7日线下收款支付笔数：统计日及之前共 7 个自然日内，限定支付方式为线下收款：状态为 PAID 的支付记录数，单位：笔',
    offline_pay_record_30d_qty         BIGINT         COMMENT '近30日线下收款支付笔数：统计日及之前共 30 个自然日内，限定支付方式为线下收款：状态为 PAID 的支付记录数，单位：笔',
    wechat_pay_method_share_1d_rate    DECIMAL(20,6)  COMMENT '当日微信支付方式占比：统计日当天（00:00–24:00）内，限定支付方式为微信：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    wechat_pay_method_share_7d_rate    DECIMAL(20,6)  COMMENT '近7日微信支付方式占比：统计日及之前共 7 个自然日内，限定支付方式为微信：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    wechat_pay_method_share_30d_rate   DECIMAL(20,6)  COMMENT '近30日微信支付方式占比：统计日及之前共 30 个自然日内，限定支付方式为微信：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    alipay_pay_method_share_1d_rate    DECIMAL(20,6)  COMMENT '当日支付宝支付方式占比：统计日当天（00:00–24:00）内，限定支付方式为支付宝：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    alipay_pay_method_share_7d_rate    DECIMAL(20,6)  COMMENT '近7日支付宝支付方式占比：统计日及之前共 7 个自然日内，限定支付方式为支付宝：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    alipay_pay_method_share_30d_rate   DECIMAL(20,6)  COMMENT '近30日支付宝支付方式占比：统计日及之前共 30 个自然日内，限定支付方式为支付宝：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    balance_pay_method_share_1d_rate   DECIMAL(20,6)  COMMENT '当日余额支付方式占比：统计日当天（00:00–24:00）内，限定支付方式为余额：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    balance_pay_method_share_7d_rate   DECIMAL(20,6)  COMMENT '近7日余额支付方式占比：统计日及之前共 7 个自然日内，限定支付方式为余额：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    balance_pay_method_share_30d_rate  DECIMAL(20,6)  COMMENT '近30日余额支付方式占比：统计日及之前共 30 个自然日内，限定支付方式为余额：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    credit_pay_method_share_1d_rate    DECIMAL(20,6)  COMMENT '当日授信支付方式占比：统计日当天（00:00–24:00）内，限定支付方式为授信：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    credit_pay_method_share_7d_rate    DECIMAL(20,6)  COMMENT '近7日授信支付方式占比：统计日及之前共 7 个自然日内，限定支付方式为授信：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    credit_pay_method_share_30d_rate   DECIMAL(20,6)  COMMENT '近30日授信支付方式占比：统计日及之前共 30 个自然日内，限定支付方式为授信：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    offline_pay_method_share_1d_rate   DECIMAL(20,6)  COMMENT '当日线下收款支付方式占比：统计日当天（00:00–24:00）内，限定支付方式为线下收款：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    offline_pay_method_share_7d_rate   DECIMAL(20,6)  COMMENT '近7日线下收款支付方式占比：统计日及之前共 7 个自然日内，限定支付方式为线下收款：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    offline_pay_method_share_30d_rate  DECIMAL(20,6)  COMMENT '近30日线下收款支付方式占比：统计日及之前共 30 个自然日内，限定支付方式为线下收款：某支付方式收款 / 全部收款；分子按限定条件统计，分母为同周期全部，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    zero_fee_order_1d_qty              BIGINT         COMMENT '当日0元单数：统计日当天（00:00–24:00）内：0 元单笔数（走支付流程但不产生资金），单位：笔',
    zero_fee_order_7d_qty              BIGINT         COMMENT '近7日0元单数：统计日及之前共 7 个自然日内：0 元单笔数（走支付流程但不产生资金），单位：笔',
    zero_fee_order_30d_qty             BIGINT         COMMENT '近30日0元单数：统计日及之前共 30 个自然日内：0 元单笔数（走支付流程但不产生资金），单位：笔',
    etl_time                           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '支付方式结构（travel_date × tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_sup_staff_performance_di  员工/窗口业绩 ==========
CREATE TABLE IF NOT EXISTS ads.ads_sup_staff_performance_di (
    tenant_id             BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    staff_id              BIGINT         COMMENT '员工ID，关联 dim_sup_staff_zip',
    tenant_name           STRING         COMMENT '租户名称',
    staff_name            STRING         COMMENT '员工姓名',
    staff_order_1d_qty    BIGINT         COMMENT '当日员工代下单数：统计日当天（00:00–24:00）内：操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API），单位：单',
    staff_order_7d_qty    BIGINT         COMMENT '近7日员工代下单数：统计日及之前共 7 个自然日内：操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API），单位：单',
    staff_order_30d_qty   BIGINT         COMMENT '近30日员工代下单数：统计日及之前共 30 个自然日内：操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API），单位：单',
    staff_order_mtd_qty   BIGINT         COMMENT '本月累计员工代下单数：统计日所在自然月 1 日至统计日：操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API），单位：单',
    staff_order_ytd_qty   BIGINT         COMMENT '本年累计员工代下单数：统计日所在自然年 1 月 1 日至统计日：操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API），单位：单',
    staff_pay_1d_amt      DECIMAL(18,2)  COMMENT '当日员工代下单支付金额：统计日当天（00:00–24:00）内：员工代下单且已支付的金额，单位：元',
    staff_pay_7d_amt      DECIMAL(18,2)  COMMENT '近7日员工代下单支付金额：统计日及之前共 7 个自然日内：员工代下单且已支付的金额，单位：元',
    staff_pay_30d_amt     DECIMAL(18,2)  COMMENT '近30日员工代下单支付金额：统计日及之前共 30 个自然日内：员工代下单且已支付的金额，单位：元',
    staff_pay_mtd_amt     DECIMAL(18,2)  COMMENT '本月累计员工代下单支付金额：统计日所在自然月 1 日至统计日：员工代下单且已支付的金额，单位：元',
    staff_pay_ytd_amt     DECIMAL(18,2)  COMMENT '本年累计员工代下单支付金额：统计日所在自然年 1 月 1 日至统计日：员工代下单且已支付的金额，单位：元',
    staff_verify_1d_qty   BIGINT         COMMENT '当日员工核销次数：统计日当天（00:00–24:00）内：员工（核销员/窗口）操作的成功核销次数，单位：次',
    staff_verify_7d_qty   BIGINT         COMMENT '近7日员工核销次数：统计日及之前共 7 个自然日内：员工（核销员/窗口）操作的成功核销次数，单位：次',
    staff_verify_30d_qty  BIGINT         COMMENT '近30日员工核销次数：统计日及之前共 30 个自然日内：员工（核销员/窗口）操作的成功核销次数，单位：次',
    staff_verify_mtd_qty  BIGINT         COMMENT '本月累计员工核销次数：统计日所在自然月 1 日至统计日：员工（核销员/窗口）操作的成功核销次数，单位：次',
    staff_verify_ytd_qty  BIGINT         COMMENT '本年累计员工核销次数：统计日所在自然年 1 月 1 日至统计日：员工（核销员/窗口）操作的成功核销次数，单位：次',
    staff_refund_1d_qty   BIGINT         COMMENT '当日员工发起退款单数：统计日当天（00:00–24:00）内：商户员工发起的退款单数，单位：单',
    staff_refund_7d_qty   BIGINT         COMMENT '近7日员工发起退款单数：统计日及之前共 7 个自然日内：商户员工发起的退款单数，单位：单',
    staff_refund_30d_qty  BIGINT         COMMENT '近30日员工发起退款单数：统计日及之前共 30 个自然日内：商户员工发起的退款单数，单位：单',
    staff_refund_mtd_qty  BIGINT         COMMENT '本月累计员工发起退款单数：统计日所在自然月 1 日至统计日：商户员工发起的退款单数，单位：单',
    staff_refund_ytd_qty  BIGINT         COMMENT '本年累计员工发起退款单数：统计日所在自然年 1 月 1 日至统计日：商户员工发起的退款单数，单位：单',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '员工/窗口业绩（travel_date × tenant_id × staff_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_sup_platform_overview_di  平台经营大盘 ==========
CREATE TABLE IF NOT EXISTS ads.ads_sup_platform_overview_di (
    pay_1d_amt                 DECIMAL(18,2)  COMMENT '当日支付金额（GMV）：统计日当天（00:00–24:00）内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_7d_amt                 DECIMAL(18,2)  COMMENT '近7日支付金额（GMV）：统计日及之前共 7 个自然日内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_30d_amt                DECIMAL(18,2)  COMMENT '近30日支付金额（GMV）：统计日及之前共 30 个自然日内：支付成功子单的成交金额，不扣退款，单位：元',
    pay_mtd_amt                DECIMAL(18,2)  COMMENT '本月累计支付金额（GMV）：统计日所在自然月 1 日至统计日：支付成功子单的成交金额，不扣退款，单位：元',
    pay_ytd_amt                DECIMAL(18,2)  COMMENT '本年累计支付金额（GMV）：统计日所在自然年 1 月 1 日至统计日：支付成功子单的成交金额，不扣退款，单位：元',
    net_pay_1d_amt             DECIMAL(18,2)  COMMENT '当日净成交金额：统计日当天（00:00–24:00）内：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    net_pay_7d_amt             DECIMAL(18,2)  COMMENT '近7日净成交金额：统计日及之前共 7 个自然日内：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    net_pay_30d_amt            DECIMAL(18,2)  COMMENT '近30日净成交金额：统计日及之前共 30 个自然日内：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    net_pay_mtd_amt            DECIMAL(18,2)  COMMENT '本月累计净成交金额：统计日所在自然月 1 日至统计日：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    net_pay_ytd_amt            DECIMAL(18,2)  COMMENT '本年累计净成交金额：统计日所在自然年 1 月 1 日至统计日：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    verify_ticket_1d_qty       BIGINT         COMMENT '当日核销票数：统计日当天（00:00–24:00）内：有成功核销的票数（同票多次只算1），单位：张',
    verify_ticket_7d_qty       BIGINT         COMMENT '近7日核销票数：统计日及之前共 7 个自然日内：有成功核销的票数（同票多次只算1），单位：张',
    verify_ticket_30d_qty      BIGINT         COMMENT '近30日核销票数：统计日及之前共 30 个自然日内：有成功核销的票数（同票多次只算1），单位：张',
    verify_ticket_mtd_qty      BIGINT         COMMENT '本月累计核销票数：统计日所在自然月 1 日至统计日：有成功核销的票数（同票多次只算1），单位：张',
    verify_ticket_ytd_qty      BIGINT         COMMENT '本年累计核销票数：统计日所在自然年 1 月 1 日至统计日：有成功核销的票数（同票多次只算1），单位：张',
    gross_profit_1d_amt        DECIMAL(18,2)  COMMENT '当日毛利额：统计日当天（00:00–24:00）内：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    gross_profit_7d_amt        DECIMAL(18,2)  COMMENT '近7日毛利额：统计日及之前共 7 个自然日内：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    gross_profit_30d_amt       DECIMAL(18,2)  COMMENT '近30日毛利额：统计日及之前共 30 个自然日内：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    gross_profit_mtd_amt       DECIMAL(18,2)  COMMENT '本月累计毛利额：统计日所在自然月 1 日至统计日：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    gross_profit_ytd_amt       DECIMAL(18,2)  COMMENT '本年累计毛利额：统计日所在自然年 1 月 1 日至统计日：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    active_tenant_1d_qty       BIGINT         COMMENT '当日动销商户数：统计日当天（00:00–24:00）内：有支付的卖家租户数，单位：家',
    active_tenant_7d_qty       BIGINT         COMMENT '近7日动销商户数：统计日及之前共 7 个自然日内：有支付的卖家租户数，单位：家',
    active_tenant_30d_qty      BIGINT         COMMENT '近30日动销商户数：统计日及之前共 30 个自然日内：有支付的卖家租户数，单位：家',
    active_tenant_mtd_qty      BIGINT         COMMENT '本月累计动销商户数：统计日所在自然月 1 日至统计日：有支付的卖家租户数，单位：家',
    active_tenant_ytd_qty      BIGINT         COMMENT '本年累计动销商户数：统计日所在自然年 1 月 1 日至统计日：有支付的卖家租户数，单位：家',
    new_tenant_1d_qty          BIGINT         COMMENT '当日新入驻商户数：统计日当天（00:00–24:00）内：新建的外部租户数，单位：家',
    new_tenant_7d_qty          BIGINT         COMMENT '近7日新入驻商户数：统计日及之前共 7 个自然日内：新建的外部租户数，单位：家',
    new_tenant_30d_qty         BIGINT         COMMENT '近30日新入驻商户数：统计日及之前共 30 个自然日内：新建的外部租户数，单位：家',
    new_tenant_mtd_qty         BIGINT         COMMENT '本月累计新入驻商户数：统计日所在自然月 1 日至统计日：新建的外部租户数，单位：家',
    new_tenant_ytd_qty         BIGINT         COMMENT '本年累计新入驻商户数：统计日所在自然年 1 月 1 日至统计日：新建的外部租户数，单位：家',
    new_customer_1d_qty        BIGINT         COMMENT '当日新注册游客数：统计日当天（00:00–24:00）内：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    new_customer_7d_qty        BIGINT         COMMENT '近7日新注册游客数：统计日及之前共 7 个自然日内：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    new_customer_30d_qty       BIGINT         COMMENT '近30日新注册游客数：统计日及之前共 30 个自然日内：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    new_customer_mtd_qty       BIGINT         COMMENT '本月累计新注册游客数：统计日所在自然月 1 日至统计日：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    new_customer_ytd_qty       BIGINT         COMMENT '本年累计新注册游客数：统计日所在自然年 1 月 1 日至统计日：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    pay_buyer_1d_qty           BIGINT         COMMENT '当日支付买家数：统计日当天（00:00–24:00）内：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    pay_buyer_7d_qty           BIGINT         COMMENT '近7日支付买家数：统计日及之前共 7 个自然日内：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    pay_buyer_30d_qty          BIGINT         COMMENT '近30日支付买家数：统计日及之前共 30 个自然日内：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    pay_buyer_mtd_qty          BIGINT         COMMENT '本月累计支付买家数：统计日所在自然月 1 日至统计日：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    pay_buyer_ytd_qty          BIGINT         COMMENT '本年累计支付买家数：统计日所在自然年 1 月 1 日至统计日：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    tenant_cert_apply_1d_qty   BIGINT         COMMENT '当日提交认证商户数：统计日当天（00:00–24:00）内：认证状态变为 PENDING_REVIEW 的租户数，单位：家',
    tenant_cert_apply_7d_qty   BIGINT         COMMENT '近7日提交认证商户数：统计日及之前共 7 个自然日内：认证状态变为 PENDING_REVIEW 的租户数，单位：家',
    tenant_cert_apply_30d_qty  BIGINT         COMMENT '近30日提交认证商户数：统计日及之前共 30 个自然日内：认证状态变为 PENDING_REVIEW 的租户数，单位：家',
    tenant_cert_pass_1d_qty    BIGINT         COMMENT '当日认证通过商户数：统计日当天（00:00–24:00）内：认证状态变为 CERTIFIED 的租户数，单位：家',
    tenant_cert_pass_7d_qty    BIGINT         COMMENT '近7日认证通过商户数：统计日及之前共 7 个自然日内：认证状态变为 CERTIFIED 的租户数，单位：家',
    tenant_cert_pass_30d_qty   BIGINT         COMMENT '近30日认证通过商户数：统计日及之前共 30 个自然日内：认证状态变为 CERTIFIED 的租户数，单位：家',
    tenant_cert_pass_1d_rate   DECIMAL(20,6)  COMMENT '当日商户认证通过率：统计日当天（00:00–24:00）内：认证通过商户数 / 提交认证商户数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    tenant_cert_pass_7d_rate   DECIMAL(20,6)  COMMENT '近7日商户认证通过率：统计日及之前共 7 个自然日内：认证通过商户数 / 提交认证商户数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    tenant_cert_pass_30d_rate  DECIMAL(20,6)  COMMENT '近30日商户认证通过率：统计日及之前共 30 个自然日内：认证通过商户数 / 提交认证商户数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    sku_sell_1d_rate           DECIMAL(20,6)  COMMENT '当日SKU动销率：统计日当天（00:00–24:00）内：动销SKU数 / 在售SKU数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    sku_sell_7d_rate           DECIMAL(20,6)  COMMENT '近7日SKU动销率：统计日及之前共 7 个自然日内：动销SKU数 / 在售SKU数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    sku_sell_30d_rate          DECIMAL(20,6)  COMMENT '近30日SKU动销率：统计日及之前共 30 个自然日内：动销SKU数 / 在售SKU数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pay_amt_dod_rate           DECIMAL(20,6)  COMMENT '支付金额日环比：（当日 − 前一日）/ 前一日，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pay_amt_wow_rate           DECIMAL(20,6)  COMMENT '支付金额周同比：（当日 − 上周同日）/ 上周同日；周报为本周对上周，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    etl_time                   STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '平台经营大盘（travel_date）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_sup_tenant_lifecycle_df  商户生命周期（活跃/沉默/流失） ==========
CREATE TABLE IF NOT EXISTS ads.ads_sup_tenant_lifecycle_df (
    tenant_lifecycle_stage_code  STRING         COMMENT '租户生命周期：NEW-新入驻，ACTIVE-活跃，SILENT-沉默，CHURN-流失',
    active_tenant_30d_qty        BIGINT         COMMENT '近30日动销商户数：统计日及之前共 30 个自然日内：有支付的卖家租户数，单位：家',
    tenant_active_30d_rate       DECIMAL(20,6)  COMMENT '近30日商户动销率：统计日及之前共 30 个自然日内：动销商户数 / 有效商户数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    silent_tenant_30d_qty        BIGINT         COMMENT '近30日沉默商户数：统计日及之前共 30 个自然日内：近30天无支付但历史有支付的商户数，单位：家',
    churn_tenant_90d_qty         BIGINT         COMMENT '近90日流失商户数：统计日及之前共 90 个自然日内：近90天无支付且套餐已到期的商户数（阈值待定），单位：家',
    etl_time                     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户生命周期（活跃/沉默/流失）（travel_date × tenant_lifecycle_stage_code）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_opr_package_revenue_mo  套餐收入与续费（月） ==========
CREATE TABLE IF NOT EXISTS ads.ads_opr_package_revenue_mo (
    stat_month_code                   STRING         COMMENT '统计自然月，格式 YYYYMM',
    package_id                        BIGINT         COMMENT '套餐ID，关联 dim_opr_package_df',
    package_name                      STRING         COMMENT '套餐名称',
    package_1m_amt                    DECIMAL(18,2)  COMMENT '本月套餐金额：统计月（自然月）内：订购对应套餐价格，单位：元',
    package_renew_1m_qty              BIGINT         COMMENT '本月续费订购数：统计月（自然月）内：续费类套餐订购笔数，单位：个',
    package_renew_1m_rate             DECIMAL(20,6)  COMMENT '本月套餐续费率：统计月（自然月）内：到期后续费的订购数 / 到期订购数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    active_subscription_1m_qty        BIGINT         COMMENT '本月生效套餐订购数：统计月（自然月）内：快照日处于生效期的订购数，单位：个',
    expiring_30d_subscription_1m_qty  BIGINT         COMMENT '本月30天内到期订购数：统计月（自然月）内：到期时间在未来30天内的生效订购数，单位：个',
    package_ytd_amt                   DECIMAL(18,2)  COMMENT '本年累计套餐金额：统计日所在自然年 1 月 1 日至统计日：订购对应套餐价格，单位：元',
    etl_time                          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '套餐收入与续费（月）（月 × package_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_opr_risk_monitor_di  风控监控 ==========
CREATE TABLE IF NOT EXISTS ads.ads_opr_risk_monitor_di (
    rule_id                   BIGINT         COMMENT '风控规则ID，关联 dim_opr_risk_rule_df',
    action_type               STRING         COMMENT '处置动作：BLOCK-拦截，WARN-预警，FREEZE-冻结',
    rule_name                 STRING         COMMENT '规则名称',
    risk_hit_1d_qty           BIGINT         COMMENT '当日风控命中次数：统计日当天（00:00–24:00）内：风控事件数，单位：次',
    risk_hit_7d_qty           BIGINT         COMMENT '近7日风控命中次数：统计日及之前共 7 个自然日内：风控事件数，单位：次',
    risk_hit_30d_qty          BIGINT         COMMENT '近30日风控命中次数：统计日及之前共 30 个自然日内：风控事件数，单位：次',
    risk_block_1d_qty         BIGINT         COMMENT '当日风控拦截次数：统计日当天（00:00–24:00）内：风控规则命中后直接拦截（拒绝操作）的次数，单位：次',
    risk_block_7d_qty         BIGINT         COMMENT '近7日风控拦截次数：统计日及之前共 7 个自然日内：风控规则命中后直接拦截（拒绝操作）的次数，单位：次',
    risk_block_30d_qty        BIGINT         COMMENT '近30日风控拦截次数：统计日及之前共 30 个自然日内：风控规则命中后直接拦截（拒绝操作）的次数，单位：次',
    risk_block_1d_rate        DECIMAL(20,6)  COMMENT '当日风控拦截率：统计日当天（00:00–24:00）内：拦截次数 / 命中次数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    risk_block_7d_rate        DECIMAL(20,6)  COMMENT '近7日风控拦截率：统计日及之前共 7 个自然日内：拦截次数 / 命中次数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    risk_block_30d_rate       DECIMAL(20,6)  COMMENT '近30日风控拦截率：统计日及之前共 30 个自然日内：拦截次数 / 命中次数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    blacklist_add_1d_qty      BIGINT         COMMENT '当日新增黑名单数：统计日当天（00:00–24:00）内：新增黑名单记录数，单位：条',
    blacklist_add_7d_qty      BIGINT         COMMENT '近7日新增黑名单数：统计日及之前共 7 个自然日内：新增黑名单记录数，单位：条',
    blacklist_add_30d_qty     BIGINT         COMMENT '近30日新增黑名单数：统计日及之前共 30 个自然日内：新增黑名单记录数，单位：条',
    ban_1d_qty                BIGINT         COMMENT '当日封禁数：统计日当天（00:00–24:00）内：新增封禁记录数，单位：条',
    ban_7d_qty                BIGINT         COMMENT '近7日封禁数：统计日及之前共 7 个自然日内：新增封禁记录数，单位：条',
    ban_30d_qty               BIGINT         COMMENT '近30日封禁数：统计日及之前共 30 个自然日内：新增封禁记录数，单位：条',
    night_action_1d_qty       BIGINT         COMMENT '当日凌晨操作次数：统计日当天（00:00–24:00）内：0~6点的写操作次数（风控关注），单位：次',
    night_action_7d_qty       BIGINT         COMMENT '近7日凌晨操作次数：统计日及之前共 7 个自然日内：0~6点的写操作次数（风控关注），单位：次',
    night_action_30d_qty      BIGINT         COMMENT '近30日凌晨操作次数：统计日及之前共 30 个自然日内：0~6点的写操作次数（风控关注），单位：次',
    duplicate_verify_1d_qty   BIGINT         COMMENT '当日重复核销次数：统计日当天（00:00–24:00）内：核销结果为 DUPLICATE 的次数，单位：次',
    duplicate_verify_7d_qty   BIGINT         COMMENT '近7日重复核销次数：统计日及之前共 7 个自然日内：核销结果为 DUPLICATE 的次数，单位：次',
    duplicate_verify_30d_qty  BIGINT         COMMENT '近30日重复核销次数：统计日及之前共 30 个自然日内：核销结果为 DUPLICATE 的次数，单位：次',
    etl_time                  STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '风控监控（travel_date × rule_id × action_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_opr_device_health_di  设备健康 ==========
CREATE TABLE IF NOT EXISTS ads.ads_opr_device_health_di (
    tenant_id                 BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    device_type               STRING         COMMENT '设备类型：GATE-闸机，POS-POS 机，HANDHELD-手持机，SELF_SERVICE-自助机，KIOSK-自助终端，FACE_RECOGNITION-人脸识别机',
    tenant_name               STRING         COMMENT '租户名称',
    device_online_1d_rate     DECIMAL(20,6)  COMMENT '当日设备在线率：统计日当天（00:00–24:00）内：在线时长 / 自然时长；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    device_online_7d_rate     DECIMAL(20,6)  COMMENT '近7日设备在线率：统计日及之前共 7 个自然日内：在线时长 / 自然时长；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    device_online_30d_rate    DECIMAL(20,6)  COMMENT '近30日设备在线率：统计日及之前共 30 个自然日内：在线时长 / 自然时长；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    offline_times_1d_qty      BIGINT         COMMENT '当日设备离线次数：统计日当天（00:00–24:00）内：变为 OFFLINE 的次数，单位：次',
    offline_times_7d_qty      BIGINT         COMMENT '近7日设备离线次数：统计日及之前共 7 个自然日内：变为 OFFLINE 的次数，单位：次',
    offline_times_30d_qty     BIGINT         COMMENT '近30日设备离线次数：统计日及之前共 30 个自然日内：变为 OFFLINE 的次数，单位：次',
    offline_verify_1d_rate    DECIMAL(20,6)  COMMENT '当日离线核销占比：统计日当天（00:00–24:00）内：离线核销次数 / 核销次数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    offline_verify_7d_rate    DECIMAL(20,6)  COMMENT '近7日离线核销占比：统计日及之前共 7 个自然日内：离线核销次数 / 核销次数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    offline_verify_30d_rate   DECIMAL(20,6)  COMMENT '近30日离线核销占比：统计日及之前共 30 个自然日内：离线核销次数 / 核销次数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    offline_conflict_1d_qty   BIGINT         COMMENT '当日离线核销冲突次数：统计日当天（00:00–24:00）内：离线核销回连后仲裁为 DUPLICATE 的次数，单位：次',
    offline_conflict_7d_qty   BIGINT         COMMENT '近7日离线核销冲突次数：统计日及之前共 7 个自然日内：离线核销回连后仲裁为 DUPLICATE 的次数，单位：次',
    offline_conflict_30d_qty  BIGINT         COMMENT '近30日离线核销冲突次数：统计日及之前共 30 个自然日内：离线核销回连后仲裁为 DUPLICATE 的次数，单位：次',
    device_total_td_qty       BIGINT         COMMENT '截至当日设备数：截至统计日日终的值：状态非 INACTIVE 的设备数，单位：台',
    etl_time                  STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '设备健康（travel_date × tenant_id × device_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_opr_complaint_sla_di  投诉SLA与审批时效 ==========
CREATE TABLE IF NOT EXISTS ads.ads_opr_complaint_sla_di (
    tenant_id                    BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    complaint_type               STRING         COMMENT '投诉类型：ORDER_ISSUE-订单问题，SERVICE_ISSUE-服务问题，BUG-系统缺陷，OTHER-其他',
    tenant_name                  STRING         COMMENT '租户名称',
    complaint_1d_qty             BIGINT         COMMENT '当日投诉数：统计日当天（00:00–24:00）内：新建投诉工单数，单位：单',
    complaint_7d_qty             BIGINT         COMMENT '近7日投诉数：统计日及之前共 7 个自然日内：新建投诉工单数，单位：单',
    complaint_30d_qty            BIGINT         COMMENT '近30日投诉数：统计日及之前共 30 个自然日内：新建投诉工单数，单位：单',
    complaint_resolved_1d_qty    BIGINT         COMMENT '当日投诉解决数：统计日当天（00:00–24:00）内：状态为 RESOLVED/CLOSED 的工单数，单位：单',
    complaint_resolved_7d_qty    BIGINT         COMMENT '近7日投诉解决数：统计日及之前共 7 个自然日内：状态为 RESOLVED/CLOSED 的工单数，单位：单',
    complaint_resolved_30d_qty   BIGINT         COMMENT '近30日投诉解决数：统计日及之前共 30 个自然日内：状态为 RESOLVED/CLOSED 的工单数，单位：单',
    complaint_overdue_1d_qty     BIGINT         COMMENT '当日投诉超SLA数：统计日当天（00:00–24:00）内：超过 SLA 截止时间才解决、或到截止时间仍未解决的投诉工单数，单位：单',
    complaint_overdue_7d_qty     BIGINT         COMMENT '近7日投诉超SLA数：统计日及之前共 7 个自然日内：超过 SLA 截止时间才解决、或到截止时间仍未解决的投诉工单数，单位：单',
    complaint_overdue_30d_qty    BIGINT         COMMENT '近30日投诉超SLA数：统计日及之前共 30 个自然日内：超过 SLA 截止时间才解决、或到截止时间仍未解决的投诉工单数，单位：单',
    complaint_sla_1d_rate        DECIMAL(20,6)  COMMENT '当日投诉SLA达成率：统计日当天（00:00–24:00）内：1 − 超SLA数 / 投诉数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    complaint_sla_7d_rate        DECIMAL(20,6)  COMMENT '近7日投诉SLA达成率：统计日及之前共 7 个自然日内：1 − 超SLA数 / 投诉数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    complaint_sla_30d_rate       DECIMAL(20,6)  COMMENT '近30日投诉SLA达成率：统计日及之前共 30 个自然日内：1 − 超SLA数 / 投诉数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    approval_1d_qty              BIGINT         COMMENT '当日审批发起数：统计日当天（00:00–24:00）内：新建审批实例数，单位：个',
    approval_7d_qty              BIGINT         COMMENT '近7日审批发起数：统计日及之前共 7 个自然日内：新建审批实例数，单位：个',
    approval_30d_qty             BIGINT         COMMENT '近30日审批发起数：统计日及之前共 30 个自然日内：新建审批实例数，单位：个',
    approval_pass_1d_rate        DECIMAL(20,6)  COMMENT '当日审批通过率：统计日当天（00:00–24:00）内：审批通过数 / 审批发起数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    approval_pass_7d_rate        DECIMAL(20,6)  COMMENT '近7日审批通过率：统计日及之前共 7 个自然日内：审批通过数 / 审批发起数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    approval_pass_30d_rate       DECIMAL(20,6)  COMMENT '近30日审批通过率：统计日及之前共 30 个自然日内：审批通过数 / 审批发起数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    approval_timeout_1d_qty      BIGINT         COMMENT '当日审批超时数：统计日当天（00:00–24:00）内：超过节点截止时间的审批实例数，单位：个',
    approval_timeout_7d_qty      BIGINT         COMMENT '近7日审批超时数：统计日及之前共 7 个自然日内：超过节点截止时间的审批实例数，单位：个',
    approval_timeout_30d_qty     BIGINT         COMMENT '近30日审批超时数：统计日及之前共 30 个自然日内：超过节点截止时间的审批实例数，单位：个',
    avg_approval_minute_1d_qty   DECIMAL(18,2)  COMMENT '当日平均审批耗时：统计日当天（00:00–24:00）内：审批总耗时 /（通过数 + 拒绝数）；分子分母取同一统计周期，单位：分钟',
    avg_approval_minute_7d_qty   DECIMAL(18,2)  COMMENT '近7日平均审批耗时：统计日及之前共 7 个自然日内：审批总耗时 /（通过数 + 拒绝数）；分子分母取同一统计周期，单位：分钟',
    avg_approval_minute_30d_qty  DECIMAL(18,2)  COMMENT '近30日平均审批耗时：统计日及之前共 30 个自然日内：审批总耗时 /（通过数 + 拒绝数）；分子分母取同一统计周期，单位：分钟',
    etl_time                     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '投诉SLA与审批时效（travel_date × tenant_id × complaint_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_opr_notify_cost_di  通知与短信消耗 ==========
CREATE TABLE IF NOT EXISTS ads.ads_opr_notify_cost_di (
    tenant_id                        BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    tenant_name                      STRING         COMMENT '租户名称',
    sms_notify_send_1d_qty           BIGINT         COMMENT '当日短信通知发送数：统计日当天（00:00–24:00）内，限定通知渠道为短信：通知记录数，单位：条',
    sms_notify_send_7d_qty           BIGINT         COMMENT '近7日短信通知发送数：统计日及之前共 7 个自然日内，限定通知渠道为短信：通知记录数，单位：条',
    sms_notify_send_30d_qty          BIGINT         COMMENT '近30日短信通知发送数：统计日及之前共 30 个自然日内，限定通知渠道为短信：通知记录数，单位：条',
    mini_notify_send_1d_qty          BIGINT         COMMENT '当日小程序消息通知发送数：统计日当天（00:00–24:00）内，限定通知渠道为小程序消息：通知记录数，单位：条',
    mini_notify_send_7d_qty          BIGINT         COMMENT '近7日小程序消息通知发送数：统计日及之前共 7 个自然日内，限定通知渠道为小程序消息：通知记录数，单位：条',
    mini_notify_send_30d_qty         BIGINT         COMMENT '近30日小程序消息通知发送数：统计日及之前共 30 个自然日内，限定通知渠道为小程序消息：通知记录数，单位：条',
    email_notify_send_1d_qty         BIGINT         COMMENT '当日邮件通知发送数：统计日当天（00:00–24:00）内，限定通知渠道为邮件：通知记录数，单位：条',
    email_notify_send_7d_qty         BIGINT         COMMENT '近7日邮件通知发送数：统计日及之前共 7 个自然日内，限定通知渠道为邮件：通知记录数，单位：条',
    email_notify_send_30d_qty        BIGINT         COMMENT '近30日邮件通知发送数：统计日及之前共 30 个自然日内，限定通知渠道为邮件：通知记录数，单位：条',
    webhook_notify_send_1d_qty       BIGINT         COMMENT '当日Webhook通知发送数：统计日当天（00:00–24:00）内，限定通知渠道为Webhook：通知记录数，单位：条',
    webhook_notify_send_7d_qty       BIGINT         COMMENT '近7日Webhook通知发送数：统计日及之前共 7 个自然日内，限定通知渠道为Webhook：通知记录数，单位：条',
    webhook_notify_send_30d_qty      BIGINT         COMMENT '近30日Webhook通知发送数：统计日及之前共 30 个自然日内，限定通知渠道为Webhook：通知记录数，单位：条',
    sms_notify_success_1d_rate       DECIMAL(20,6)  COMMENT '当日短信通知成功率：统计日当天（00:00–24:00）内，限定通知渠道为短信：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    sms_notify_success_7d_rate       DECIMAL(20,6)  COMMENT '近7日短信通知成功率：统计日及之前共 7 个自然日内，限定通知渠道为短信：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    sms_notify_success_30d_rate      DECIMAL(20,6)  COMMENT '近30日短信通知成功率：统计日及之前共 30 个自然日内，限定通知渠道为短信：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    mini_notify_success_1d_rate      DECIMAL(20,6)  COMMENT '当日小程序消息通知成功率：统计日当天（00:00–24:00）内，限定通知渠道为小程序消息：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    mini_notify_success_7d_rate      DECIMAL(20,6)  COMMENT '近7日小程序消息通知成功率：统计日及之前共 7 个自然日内，限定通知渠道为小程序消息：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    mini_notify_success_30d_rate     DECIMAL(20,6)  COMMENT '近30日小程序消息通知成功率：统计日及之前共 30 个自然日内，限定通知渠道为小程序消息：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    email_notify_success_1d_rate     DECIMAL(20,6)  COMMENT '当日邮件通知成功率：统计日当天（00:00–24:00）内，限定通知渠道为邮件：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    email_notify_success_7d_rate     DECIMAL(20,6)  COMMENT '近7日邮件通知成功率：统计日及之前共 7 个自然日内，限定通知渠道为邮件：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    email_notify_success_30d_rate    DECIMAL(20,6)  COMMENT '近30日邮件通知成功率：统计日及之前共 30 个自然日内，限定通知渠道为邮件：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    webhook_notify_success_1d_rate   DECIMAL(20,6)  COMMENT '当日Webhook通知成功率：统计日当天（00:00–24:00）内，限定通知渠道为Webhook：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    webhook_notify_success_7d_rate   DECIMAL(20,6)  COMMENT '近7日Webhook通知成功率：统计日及之前共 7 个自然日内，限定通知渠道为Webhook：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    webhook_notify_success_30d_rate  DECIMAL(20,6)  COMMENT '近30日Webhook通知成功率：统计日及之前共 30 个自然日内，限定通知渠道为Webhook：通知成功数 / 通知发送数；分子分母取同一统计周期、同一限定条件，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    resource_consume_1d_qty          BIGINT         COMMENT '当日资源包消耗量：统计日当天（00:00–24:00）内：资源批次剩余量日差，单位：条/点',
    resource_consume_7d_qty          BIGINT         COMMENT '近7日资源包消耗量：统计日及之前共 7 个自然日内：资源批次剩余量日差，单位：条/点',
    resource_consume_30d_qty         BIGINT         COMMENT '近30日资源包消耗量：统计日及之前共 30 个自然日内：资源批次剩余量日差，单位：条/点',
    resource_consume_mtd_qty         BIGINT         COMMENT '本月累计资源包消耗量：统计日所在自然月 1 日至统计日：资源批次剩余量日差，单位：条/点',
    resource_consume_ytd_qty         BIGINT         COMMENT '本年累计资源包消耗量：统计日所在自然年 1 月 1 日至统计日：资源批次剩余量日差，单位：条/点',
    notify_fail_1d_qty               BIGINT         COMMENT '当日通知失败数：统计日当天（00:00–24:00）内：发送失败的通知条数，单位：条',
    notify_fail_7d_qty               BIGINT         COMMENT '近7日通知失败数：统计日及之前共 7 个自然日内：发送失败的通知条数，单位：条',
    notify_fail_30d_qty              BIGINT         COMMENT '近30日通知失败数：统计日及之前共 30 个自然日内：发送失败的通知条数，单位：条',
    etl_time                         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '通知与短信消耗（travel_date × tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_opr_code_pool_usage_df  码池使用 ==========
CREATE TABLE IF NOT EXISTS ads.ads_opr_code_pool_usage_df (
    tenant_id                  BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    code_pool_id               BIGINT         COMMENT '码池ID，关联 dim_opr_code_pool_df',
    tenant_name                STRING         COMMENT '租户名称',
    code_pool_no               STRING         COMMENT '码池编号',
    code_capacity_td_qty       BIGINT         COMMENT '截至当日码池容量：截至统计日日终的值：码池最大并发码数，单位：个',
    code_allocated_td_qty      BIGINT         COMMENT '截至当日已分配码数：截至统计日日终的值：码池已分配码数，单位：个',
    code_recycled_td_qty       BIGINT         COMMENT '截至当日回收复用码数：截至统计日日终的值：码池已回收复用码数，单位：个',
    code_pool_usage_td_rate    DECIMAL(20,6)  COMMENT '截至当日码池使用率：截至统计日日终：已分配码数 / 码池容量；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    code_recycle_td_rate       DECIMAL(20,6)  COMMENT '截至当日码回收复用率：截至统计日日终：回收复用码数 / 已分配码数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    issue_credential_1d_qty    BIGINT         COMMENT '当日发码数：统计日当天（00:00–24:00）内：发放的票凭证数，单位：个',
    issue_credential_7d_qty    BIGINT         COMMENT '近7日发码数：统计日及之前共 7 个自然日内：发放的票凭证数，单位：个',
    issue_credential_30d_qty   BIGINT         COMMENT '近30日发码数：统计日及之前共 30 个自然日内：发放的票凭证数，单位：个',
    revoke_credential_1d_qty   BIGINT         COMMENT '当日凭证撤销数：统计日当天（00:00–24:00）内：状态变为 REVOKED 的凭证数，单位：个',
    revoke_credential_7d_qty   BIGINT         COMMENT '近7日凭证撤销数：统计日及之前共 7 个自然日内：状态变为 REVOKED 的凭证数，单位：个',
    revoke_credential_30d_qty  BIGINT         COMMENT '近30日凭证撤销数：统计日及之前共 30 个自然日内：状态变为 REVOKED 的凭证数，单位：个',
    etl_time                   STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '码池使用（travel_date × tenant_id × code_pool_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_sup_tenant_trade_wk  商户经营周报 ==========
CREATE TABLE IF NOT EXISTS ads.ads_sup_tenant_trade_wk (
    stat_week_code        STRING         COMMENT '统计自然周，格式 YYYY-Www，如 2026-W46',
    week_start_date       STRING         COMMENT '自然周开始日期（周一）',
    seller_tenant_id      BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    seller_tenant_name    STRING         COMMENT '卖家租户名称',
    pay_1w_amt            DECIMAL(18,2)  COMMENT '本周支付金额（GMV）：统计日所在自然周（周一至周日）内：支付成功子单的成交金额，不扣退款，单位：元',
    net_pay_1w_amt        DECIMAL(18,2)  COMMENT '本周净成交金额：统计日所在自然周（周一至周日）内：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    verify_ticket_1w_qty  BIGINT         COMMENT '本周核销票数：统计日所在自然周（周一至周日）内：有成功核销的票数（同票多次只算1），单位：张',
    refund_1w_amt         DECIMAL(18,2)  COMMENT '本周退款金额：统计日所在自然周（周一至周日）内：退款完成的金额，单位：元',
    refund_1w_rate        DECIMAL(20,6)  COMMENT '本周退票率：统计日所在自然周（周一至周日）内：退款票数 / 支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    gross_profit_1w_amt   DECIMAL(18,2)  COMMENT '本周毛利额：统计日所在自然周（周一至周日）内：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    per_customer_1w_amt   DECIMAL(18,2)  COMMENT '本周客单价：统计日所在自然周（周一至周日）内：支付金额 / 支付买家数；分子分母取同一统计周期，单位：元',
    pay_amt_wow_rate      DECIMAL(20,6)  COMMENT '支付金额周同比：（当日 − 上周同日）/ 上周同日；周报为本周对上周，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户经营周报（自然周 × seller_tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ads.ads_sup_tenant_trade_mo  商户经营月报 ==========
CREATE TABLE IF NOT EXISTS ads.ads_sup_tenant_trade_mo (
    stat_month_code       STRING         COMMENT '统计自然月，格式 YYYYMM',
    seller_tenant_id      BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    seller_tenant_name    STRING         COMMENT '卖家租户名称',
    pay_1m_amt            DECIMAL(18,2)  COMMENT '本月支付金额（GMV）：统计月（自然月）内：支付成功子单的成交金额，不扣退款，单位：元',
    net_pay_1m_amt        DECIMAL(18,2)  COMMENT '本月净成交金额：统计月（自然月）内：支付金额 − 退款金额；分子分母取同一统计周期，单位：元',
    verify_ticket_1m_qty  BIGINT         COMMENT '本月核销票数：统计月（自然月）内：有成功核销的票数（同票多次只算1），单位：张',
    refund_1m_amt         DECIMAL(18,2)  COMMENT '本月退款金额：统计月（自然月）内：退款完成的金额，单位：元',
    refund_1m_rate        DECIMAL(20,6)  COMMENT '本月退票率：统计月（自然月）内：退款票数 / 支付票数；分子分母取同一统计周期，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    gross_profit_1m_amt   DECIMAL(18,2)  COMMENT '本月毛利额：统计月（自然月）内：支付金额 − 成本金额（支付口径，未扣退款）；分子分母取同一统计周期，单位：元',
    per_customer_1m_amt   DECIMAL(18,2)  COMMENT '本月客单价：统计月（自然月）内：支付金额 / 支付买家数；分子分母取同一统计周期，单位：元',
    pay_amt_mom_rate      DECIMAL(20,6)  COMMENT '支付金额月环比：（本月 − 上月）/ 上月，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户经营月报（自然月 × seller_tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

