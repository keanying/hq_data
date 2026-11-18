-- PFT 2.0 数仓 DDL：DWS（32 张表）
-- 由 generator/make_all.py 生成，请勿手改

-- ========== dws.dws_ord_tenant_sku_channel_trade_di  商户×SKU×渠道 交易日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_ord_tenant_sku_channel_trade_di (
    seller_tenant_id          BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id                    BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    channel_id                BIGINT         COMMENT '入口渠道ID，关联 dim_trf_channel_df',
    app_ref_code              STRING         COMMENT '对接端引用',
    operator_type             STRING         COMMENT '操作人类型：CUSTOMER-C端游客，TENANT_STAFF-B端员工',
    order_group_qty           BIGINT         COMMENT '下单聚合单数：统计周期内创建的聚合单数（一次购物车结算），单位：单',
    order_qty                 BIGINT         COMMENT '下单子单数：统计周期内创建的子单数；套票只算主单，子项单另计，单位：单',
    order_ticket_qty          BIGINT         COMMENT '下单票数：下单购买数量合计，单位：张',
    order_amt                 DECIMAL(18,2)  COMMENT '下单金额：下单时 单价×数量 合计，单位：元',
    pay_order_qty             BIGINT         COMMENT '支付子单数：统计周期内首次变为 PAID 的子单数，单位：单',
    pay_ticket_qty            BIGINT         COMMENT '支付票数：支付成功子单的购买数量合计，单位：张',
    pay_amt                   DECIMAL(18,2)  COMMENT '支付金额（GMV）：支付成功子单的成交金额，不扣退款，单位：元',
    pay_buyer_qty             BIGINT         COMMENT '支付买家数：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    cancel_order_qty          BIGINT         COMMENT '取消子单数：超时未付等原因变为 CANCELLED 的子单数，单位：单',
    cancel_amt                DECIMAL(18,2)  COMMENT '取消金额：取消子单的下单金额，单位：元',
    staff_order_qty           BIGINT         COMMENT '员工代下单数：操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API），单位：单',
    combo_order_qty           BIGINT         COMMENT '套票主单数：套票主单数（一单套票只算 1，子项单不计），单位：单',
    pay_order_group_qty       BIGINT         COMMENT '支付聚合单数：统计周期内支付成功的聚合单数，单位：单',
    cost_amt                  DECIMAL(18,2)  COMMENT '成本金额：支付子单按下单时 SKU 版本成本价 × 数量，单位：元',
    pay_minute_qty            BIGINT         COMMENT '下单到支付总时长：支付子单从创建到支付的分钟数合计，单位：分钟',
    timeout_cancel_order_qty  BIGINT         COMMENT '超时取消子单数：因支付超时（PAY_TIMEOUT）取消的子单数，单位：单',
    advance_book_day_qty      BIGINT         COMMENT '提前预订天数合计：每张支付票的（游玩日 − 支付日）合计，单位：天',
    etl_time                  STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户×SKU×渠道 交易日汇总（travel_date × seller_tenant_id × sku_id × channel_id × app_ref_code × operator_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_ord_sku_play_date_booking_df  SKU×游玩日 预订存量快照 ==========
CREATE TABLE IF NOT EXISTS dws.dws_ord_sku_play_date_booking_df (
    sku_id                BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    play_date             STRING         COMMENT '游玩日期，格式 yyyy-MM-dd',
    time_slot_code        STRING         COMMENT '游玩时段，如 10:00-11:00',
    pay_ticket_qty        BIGINT         COMMENT '支付票数：支付成功子单的购买数量合计，单位：张',
    refund_ticket_qty     BIGINT         COMMENT '退款票数：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    net_pay_ticket_qty    BIGINT         COMMENT '净支付票数：支付票数 − 退款票数，单位：张',
    verify_ticket_qty     BIGINT         COMMENT '核销票数：统计周期内有成功核销的票数（同票多次只算1），单位：张',
    advance_book_day_qty  BIGINT         COMMENT '提前预订天数合计：每张支付票的（游玩日 − 支付日）合计，单位：天',
    stock_available_qty   BIGINT         COMMENT '可用库存：日终库存池可用量，单位：个',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SKU×游玩日 预订存量快照（travel_date（快照日）× sku_id × play_date × time_slot_code）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_ord_tenant_sku_verify_di  商户×SKU×核销点 核销日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_ord_tenant_sku_verify_di (
    seller_tenant_id          BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id                    BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    verify_point_id           BIGINT         COMMENT '核销点ID，关联 dim_opr_verify_point_df',
    verify_type               STRING         COMMENT '核销类型：ONLINE-在线，OFFLINE-线下或离线',
    verify_ticket_qty         BIGINT         COMMENT '核销票数：统计周期内有成功核销的票数（同票多次只算1），单位：张',
    verify_entitlement_qty    BIGINT         COMMENT '核销权益次数：成功核销记录条数（年卡/次卡每次都计），单位：次',
    verify_person_qty         BIGINT         COMMENT '核销人次（入园人次）：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    verify_fail_qty           BIGINT         COMMENT '核销失败次数：核销结果为 FAILED/DUPLICATE 的次数，单位：次',
    offline_verify_qty        BIGINT         COMMENT '离线核销次数：闸机/手持机离线状态下完成、回连后确认成功的核销次数，单位：次',
    verify_amt                DECIMAL(18,2)  COMMENT '核销金额：成功核销票对应的分摊单价（收入确认口径），单位：元',
    duplicate_verify_qty      BIGINT         COMMENT '重复核销次数：核销结果为 DUPLICATE 的次数，单位：次',
    offline_conflict_qty      BIGINT         COMMENT '离线核销冲突次数：离线核销回连后仲裁为 DUPLICATE 的次数，单位：次',
    verify_after_pay_day_qty  BIGINT         COMMENT '支付到首次核销天数合计：首次核销日 − 支付日，按票合计，单位：天',
    etl_time                  STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户×SKU×核销点 核销日汇总（travel_date × seller_tenant_id × sku_id × verify_point_id × verify_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_ord_verify_point_flow_hrs  核销点分时客流 ==========
CREATE TABLE IF NOT EXISTS dws.dws_ord_verify_point_flow_hrs (
    stat_hour_no            INT            COMMENT '统计小时：0~23',
    seller_tenant_id        BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    verify_point_id         BIGINT         COMMENT '核销点ID，关联 dim_opr_verify_point_df',
    verify_person_qty       BIGINT         COMMENT '核销人次（入园人次）：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    verify_fail_qty         BIGINT         COMMENT '核销失败次数：核销结果为 FAILED/DUPLICATE 的次数，单位：次',
    verify_entitlement_qty  BIGINT         COMMENT '核销权益次数：成功核销记录条数（年卡/次卡每次都计），单位：次',
    etl_time                STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '核销点分时客流（travel_date × stat_hour_no × seller_tenant_id × verify_point_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_ord_tenant_refund_di  商户×SKU 退款日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_ord_tenant_refund_di (
    seller_tenant_id            BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id                      BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    refund_type                 STRING         COMMENT '退款类型：ORDER_REFUND-订单退款，COMPENSATION-售后补偿，PARTIAL_REFUND-部分退款',
    initiator_type              STRING         COMMENT '发起方：VISITOR-游客，MERCHANT-商户，PLATFORM-平台，SYSTEM-系统，OTA',
    refund_reason_desc          STRING         COMMENT '退款原因',
    refund_apply_qty            BIGINT         COMMENT '退款申请单数：统计周期内创建的退款单数，单位：单',
    refund_success_qty          BIGINT         COMMENT '退款完成单数：状态为 COMPLETED 的退款单数，单位：单',
    refund_ticket_qty           BIGINT         COMMENT '退款票数：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    refund_amt                  DECIMAL(18,2)  COMMENT '退款金额：退款完成的金额，单位：元',
    refund_process_hour_qty     BIGINT         COMMENT '退款处理总时长：已完成退款单从申请到完成的小时数合计，单位：小时',
    auto_approve_refund_qty     BIGINT         COMMENT '超时自动通过退款单数：审核超过 48 小时自动通过的退款单数，单位：单',
    refund_reject_qty           BIGINT         COMMENT '退款驳回单数：状态为 REJECTED 的退款单数，单位：单',
    verified_refund_ticket_qty  BIGINT         COMMENT '核销后退款票数：退款时票状态为 PARTIALLY_USED/USED 的票数，单位：张',
    etl_time                    STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户×SKU 退款日汇总（travel_date × seller_tenant_id × sku_id × refund_type × initiator_type × refund_reason_desc）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_ord_tenant_entitlement_di  商户×权益类型 权益使用日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_ord_tenant_entitlement_di (
    seller_tenant_id             BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id                       BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    entitlement_type             STRING         COMMENT '权益类型：FIXED-固定，COUNTED-计次型，SELECTABLE-选择型，TIMED-计时型，QUOTA-额度型，UNLIMITED-不限次型',
    binding_type                 STRING         COMMENT '绑定方式：EXCLUSIVE-专属绑定，SHARED-共享绑定，OPEN-开放争抢',
    entitlement_issue_qty        BIGINT         COMMENT '发放权益数：统计周期内生成的权益数，单位：个',
    entitlement_used_qty         BIGINT         COMMENT '权益已用次数：权益已被使用的次数合计（年卡、次卡每入园一次计 1 次），单位：次',
    entitlement_total_qty        BIGINT         COMMENT '权益可用总次数：权益可用总次数合计：计次型、选择型按可用次数，固定型按 1 次，不限次型不计，单位：次',
    quota_total_amt              DECIMAL(18,2)  COMMENT '额度型权益总额度：额度型权益（如园区消费金）的发放总额度；已用额度源系统暂未记录，单位：元',
    activate_ticket_qty          BIGINT         COMMENT '激活票数：延迟激活类票（年卡/入园后N天有效）首次核销回填有效期起始的票数，单位：张',
    activate_delay_day_qty       BIGINT         COMMENT '激活延迟天数合计：激活日 − 支付日，按票合计，单位：天',
    pending_activate_ticket_qty  BIGINT         COMMENT '待激活票数：快照日仍未激活的延迟激活类票数，单位：张',
    etl_time                     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户×权益类型 权益使用日汇总（travel_date × seller_tenant_id × sku_id × entitlement_type × binding_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_ord_tenant_ticket_stock_df  商户×SKU 票状态存量快照 ==========
CREATE TABLE IF NOT EXISTS dws.dws_ord_tenant_ticket_stock_df (
    seller_tenant_id             BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id                       BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    ticket_status                STRING         COMMENT '票状态：AVAILABLE-可用，PARTIALLY_USED-部分使用，USED-已使用，EXPIRED-已过期，REFUNDED-已退款，CANCELLED-已取消',
    valid_end_date               STRING         COMMENT '有效期截止日期，格式 yyyy-MM-dd',
    ticket_stock_qty             BIGINT         COMMENT '票存量：快照日各状态票数，单位：张',
    unverified_ticket_qty        BIGINT         COMMENT '未核销在途票数：快照日状态为 AVAILABLE/PARTIALLY_USED 且未过期的票数，单位：张',
    unverified_amt               DECIMAL(18,2)  COMMENT '未核销在途金额（预收）：在途票对应的分摊单价合计，单位：元',
    expire_ticket_qty            BIGINT         COMMENT '过期票数：统计周期内变为 EXPIRED 的票数，单位：张',
    realname_ticket_qty          BIGINT         COMMENT '实名票数：票上至少登记1名游客的票数，单位：张',
    pending_activate_ticket_qty  BIGINT         COMMENT '待激活票数：快照日仍未激活的延迟激活类票数，单位：张',
    issue_ticket_qty             BIGINT         COMMENT '出票张数：统计周期内生成的票数，单位：张',
    pay_ticket_qty               BIGINT         COMMENT '支付票数：支付成功子单的购买数量合计，单位：张',
    verify_ticket_qty            BIGINT         COMMENT '核销票数：统计周期内有成功核销的票数（同票多次只算1），单位：张',
    etl_time                     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户×SKU 票状态存量快照（travel_date × seller_tenant_id × sku_id × ticket_status × valid_end_date）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_ord_combo_sku_trade_di  套票×子项 交易日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_ord_combo_sku_trade_di (
    combo_sku_id          BIGINT         COMMENT '套票主 SKU ID',
    sub_sku_id            BIGINT         COMMENT '套票子项 SKU ID',
    sub_seller_tenant_id  BIGINT         COMMENT '套票子项卖家租户ID',
    combo_order_qty       BIGINT         COMMENT '套票主单数：套票主单数（一单套票只算 1，子项单不计），单位：单',
    pay_order_qty         BIGINT         COMMENT '支付子单数：统计周期内首次变为 PAID 的子单数，单位：单',
    pay_amt               DECIMAL(18,2)  COMMENT '支付金额（GMV）：支付成功子单的成交金额，不扣退款，单位：元',
    refund_ticket_qty     BIGINT         COMMENT '退款票数：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    refund_amt            DECIMAL(18,2)  COMMENT '退款金额：退款完成的金额，单位：元',
    verify_ticket_qty     BIGINT         COMMENT '核销票数：统计周期内有成功核销的票数（同票多次只算1），单位：张',
    pay_ticket_qty        BIGINT         COMMENT '支付票数：支付成功子单的购买数量合计，单位：张',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '套票×子项 交易日汇总（travel_date × combo_sku_id × sub_sku_id × sub_seller_tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_cus_customer_trade_di  游客×商户 交易日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_cus_customer_trade_di (
    buyer_customer_id  BIGINT         COMMENT '买家游客ID，关联 dim_cus_customer_zip',
    seller_tenant_id   BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    pay_order_qty      BIGINT         COMMENT '支付子单数：统计周期内首次变为 PAID 的子单数，单位：单',
    pay_ticket_qty     BIGINT         COMMENT '支付票数：支付成功子单的购买数量合计，单位：张',
    pay_amt            DECIMAL(18,2)  COMMENT '支付金额（GMV）：支付成功子单的成交金额，不扣退款，单位：元',
    refund_amt         DECIMAL(18,2)  COMMENT '退款金额：退款完成的金额，单位：元',
    verify_ticket_qty  BIGINT         COMMENT '核销票数：统计周期内有成功核销的票数（同票多次只算1），单位：张',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '游客×商户 交易日汇总（travel_date × buyer_customer_id × seller_tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_cus_customer_lifetime_df  游客累计至今汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_cus_customer_lifetime_df (
    buyer_customer_id    BIGINT         COMMENT '买家游客ID，关联 dim_cus_customer_zip',
    seller_tenant_id     BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    first_pay_date       STRING         COMMENT '首次支付日期：游客/商户首次有支付的日期',
    last_pay_date        STRING         COMMENT '最近支付日期：游客/商户最近一次支付的日期',
    total_pay_order_qty  BIGINT         COMMENT '累计支付单数：截至快照日累计支付子单数，单位：单',
    total_pay_amt        DECIMAL(18,2)  COMMENT '累计支付金额：截至快照日累计支付金额，单位：元',
    pay_order_30d_qty    BIGINT         COMMENT '近30天支付单数：近30天支付子单数，单位：单',
    pay_30d_amt          DECIMAL(18,2)  COMMENT '近30天支付金额：近30天支付金额，单位：元',
    buyer_type           TINYINT        COMMENT '买家类型：0-首购 1-复购（近30天支付子单数≥2 记为复购），单位：0/1',
    pay_buyer_qty        BIGINT         COMMENT '支付买家数：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    repeat_buyer_qty     BIGINT         COMMENT '老客买家数：统计周期内支付且此前已有支付的买家数，单位：人',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '游客累计至今汇总（travel_date（快照日）× buyer_customer_id × seller_tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_cus_tourist_origin_di  游客客源画像日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_cus_tourist_origin_di (
    seller_tenant_id      BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id                BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    origin_province_code  STRING         COMMENT '客源省份编码',
    origin_city_code      STRING         COMMENT '客源城市编码',
    age_band_code         STRING         COMMENT '年龄段：0_17-未成年，18_25-18~25岁，26_35-26~35岁，36_45-36~45岁，46_60-46~60岁，60_PLUS-60岁以上，UNKNOWN-未知',
    gender_type           STRING         COMMENT '性别：MALE-男，FEMALE-女，UNKNOWN-未知',
    tourist_qty           BIGINT         COMMENT '游客人数：票上登记的游客人数，单位：人',
    verify_person_qty     BIGINT         COMMENT '核销人次（入园人次）：核销成功后放行入园的人次；源系统暂未记录放行人数，暂按成功核销次数计，待补放行人数字段，单位：人次',
    person_linked_qty     BIGINT         COMMENT '已关联会员的游客数：票上登记的游客中，已关联到会员账号的人数，单位：人',
    realname_ticket_qty   BIGINT         COMMENT '实名票数：票上至少登记1名游客的票数，单位：张',
    issue_ticket_qty      BIGINT         COMMENT '出票张数：统计周期内生成的票数，单位：张',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '游客客源画像日汇总（travel_date × seller_tenant_id × sku_id × origin_province_code × origin_city_code × age_band_code × gender_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_sup_tenant_trade_di  商户经营日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_sup_tenant_trade_di (
    seller_tenant_id        BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    pay_order_qty           BIGINT         COMMENT '支付子单数：统计周期内首次变为 PAID 的子单数，单位：单',
    pay_ticket_qty          BIGINT         COMMENT '支付票数：支付成功子单的购买数量合计，单位：张',
    pay_amt                 DECIMAL(18,2)  COMMENT '支付金额（GMV）：支付成功子单的成交金额，不扣退款，单位：元',
    refund_amt              DECIMAL(18,2)  COMMENT '退款金额：退款完成的金额，单位：元',
    net_pay_amt             DECIMAL(18,2)  COMMENT '净成交金额：支付金额 − 退款金额，单位：元',
    verify_ticket_qty       BIGINT         COMMENT '核销票数：统计周期内有成功核销的票数（同票多次只算1），单位：张',
    verify_amt              DECIMAL(18,2)  COMMENT '核销金额：成功核销票对应的分摊单价（收入确认口径），单位：元',
    pay_buyer_qty           BIGINT         COMMENT '支付买家数：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    new_customer_qty        BIGINT         COMMENT '新注册游客数：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    on_sale_sku_qty         BIGINT         COMMENT '在售SKU数：快照日状态为 PUBLISHED 的SKU数，单位：个',
    cost_amt                DECIMAL(18,2)  COMMENT '成本金额：支付子单按下单时 SKU 版本成本价 × 数量，单位：元',
    sold_sku_qty            BIGINT         COMMENT '动销SKU数：统计周期内有支付的 SKU 数，单位：个',
    first_pay_customer_qty  BIGINT         COMMENT '首单买家数：统计周期内首次支付的真实买家数，单位：人',
    pay_order_group_qty     BIGINT         COMMENT '支付聚合单数：统计周期内支付成功的聚合单数，单位：单',
    refund_ticket_qty       BIGINT         COMMENT '退款票数：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    order_qty               BIGINT         COMMENT '下单子单数：统计周期内创建的子单数；套票只算主单，子项单另计，单位：单',
    pay_conversion_rate     DECIMAL(20,6)  COMMENT '下单支付转化率：支付子单数 / 下单子单数，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    etl_time                STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户经营日汇总（travel_date × seller_tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_sup_tenant_lifetime_df  商户累计至今汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_sup_tenant_lifetime_df (
    seller_tenant_id    BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    first_pay_date      STRING         COMMENT '首次支付日期：游客/商户首次有支付的日期',
    last_pay_date       STRING         COMMENT '最近支付日期：游客/商户最近一次支付的日期',
    total_pay_amt       DECIMAL(18,2)  COMMENT '累计支付金额：截至快照日累计支付金额，单位：元',
    pay_30d_amt         DECIMAL(18,2)  COMMENT '近30天支付金额：近30天支付金额，单位：元',
    active_day_30d_qty  BIGINT         COMMENT '近30天动销天数：近30天有支付的天数，单位：天',
    active_tenant_qty   BIGINT         COMMENT '动销商户数：统计周期内有支付的卖家租户数，单位：家',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户累计至今汇总（travel_date（快照日）× seller_tenant_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_sup_staff_operate_di  员工操作日汇总（窗口/导游/核销员） ==========
CREATE TABLE IF NOT EXISTS dws.dws_sup_staff_operate_di (
    tenant_id         BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    staff_id          BIGINT         COMMENT '员工ID，关联 dim_sup_staff_zip',
    staff_order_qty   BIGINT         COMMENT '员工代下单数：操作人类型为 TENANT_STAFF 的子单数（窗口/分销员工/OTA API），单位：单',
    staff_pay_amt     DECIMAL(18,2)  COMMENT '员工代下单支付金额：员工代下单且已支付的金额，单位：元',
    staff_verify_qty  BIGINT         COMMENT '员工核销次数：员工（核销员/窗口）操作的成功核销次数，单位：次',
    staff_refund_qty  BIGINT         COMMENT '员工发起退款单数：商户员工发起的退款单数，单位：单',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '员工操作日汇总（窗口/导游/核销员）（travel_date × tenant_id × staff_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_trf_distributor_trade_di  分销商×供应商×SKU×层级 分销日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_trf_distributor_trade_di (
    distributor_tenant_id      BIGINT         COMMENT '分销商租户ID，关联 dim_sup_tenant_zip',
    supplier_tenant_id         BIGINT         COMMENT '供应商租户ID，关联 dim_sup_tenant_zip',
    sku_id                     BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    chain_level_no             INT            COMMENT '分销链层级：1~4',
    distribution_ticket_qty    BIGINT         COMMENT '分销票数：经过分销链（有 OUTBOUND 采购）的票数，单位：张',
    distribution_sale_amt      DECIMAL(18,2)  COMMENT '分销售出金额：本级卖出价（下级付给本级的金额），单位：元',
    distribution_purchase_amt  DECIMAL(18,2)  COMMENT '分销采购金额：本级向上级采购的金额，单位：元',
    distribution_profit_amt    DECIMAL(18,2)  COMMENT '分销利润：本级售出 − 本级采购，单位：元',
    refund_ticket_qty          BIGINT         COMMENT '退款票数：退款完成的票张数（一张退款单可含多张票，按票计），单位：张',
    chain_level_qty            BIGINT         COMMENT '分销层级合计：分销票所在最大层级合计（求平均层级用），单位：级',
    active_distributor_qty     BIGINT         COMMENT '动销分销商数：统计周期内有分销票的分销商数，单位：家',
    etl_time                   STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '分销商×供应商×SKU×层级 分销日汇总（travel_date × distributor_tenant_id × supplier_tenant_id × sku_id × chain_level_no）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_trf_distributor_credit_df  分销关系授信快照 ==========
CREATE TABLE IF NOT EXISTS dws.dws_trf_distributor_credit_df (
    relation_no                    STRING         COMMENT '分销关系编号',
    credit_limit_amt               DECIMAL(18,2)  COMMENT '授信额度：分销关系授信额度，单位：元',
    credit_used_amt                DECIMAL(18,2)  COMMENT '已用授信：分销关系已用授信，单位：元',
    credit_usage_rate              DECIMAL(20,6)  COMMENT '授信使用率：已用授信 / 授信额度，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    new_distribution_relation_qty  BIGINT         COMMENT '新建分销关系数：统计周期内新建的分销关系数，单位：条',
    etl_time                       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '分销关系授信快照（travel_date × relation_no）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_fin_account_balance_df  账户余额日快照 ==========
CREATE TABLE IF NOT EXISTS dws.dws_fin_account_balance_df (
    account_no             STRING         COMMENT '账户编号，关联 dim_fin_account_df',
    available_balance_amt  DECIMAL(18,2)  COMMENT '可用余额：日终账户可用余额，单位：元',
    frozen_balance_amt     DECIMAL(18,2)  COMMENT '冻结余额：日终账户冻结余额，单位：元',
    opening_balance_amt    DECIMAL(18,2)  COMMENT '期初余额：当日第一条流水的变动前余额，单位：元',
    closing_balance_amt    DECIMAL(18,2)  COMMENT '期末余额：当日最后一条流水的变动后余额，单位：元',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '账户余额日快照（travel_date × account_no）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_fin_account_flow_di  账户×流水类型 资金日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_fin_account_flow_di (
    account_no            STRING         COMMENT '账户编号，关联 dim_fin_account_df',
    flow_type             STRING         COMMENT '流水类型：RECHARGE-充值，PAYMENT-支付，REFUND-退款，FREEZE-冻结，UNFREEZE-解冻，WITHDRAW-提现，FEE-手续费，RESOURCE-资源包，TRANSFER_OUT-采购转出，TRANSFER_IN-采购转入',
    fund_flow_qty         BIGINT         COMMENT '资金流水笔数：流水条数，单位：笔',
    fund_in_amt           DECIMAL(18,2)  COMMENT '资金流入：账户资金流入金额（充值、收款、转入、解冻等入账），单位：元',
    fund_out_amt          DECIMAL(18,2)  COMMENT '资金流出：账户资金流出金额（提现、退款、采购转出、手续费等出账），单位：元',
    fee_amt               DECIMAL(18,2)  COMMENT '手续费金额：账户被扣的手续费金额（提现手续费、短信费等），单位：元',
    withdraw_apply_amt    DECIMAL(18,2)  COMMENT '提现申请金额：统计周期内发起的提现金额，单位：元',
    withdraw_success_amt  DECIMAL(18,2)  COMMENT '提现成功金额：状态 COMPLETED 的提现金额，单位：元',
    withdraw_fail_qty     BIGINT         COMMENT '提现失败笔数：状态 FAILED/REJECTED 的提现单数，单位：笔',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '账户×流水类型 资金日汇总（travel_date × account_no × flow_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_fin_account_frozen_di  账户×冻结类型 冻结日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_fin_account_frozen_di (
    account_no            STRING         COMMENT '账户编号，关联 dim_fin_account_df',
    freeze_type           STRING         COMMENT '冻结类型：PROFIT-利润，SETTLEMENT-采购款，FULL-全款',
    external_frozen_type  INT            COMMENT '是否外部渠道冻结：0-否，1-是',
    freeze_amt            DECIMAL(18,2)  COMMENT '冻结金额：统计周期内新建冻结记录金额，单位：元',
    unfreeze_verify_amt   DECIMAL(18,2)  COMMENT '核销解冻金额：因核销释放的冻结金额，单位：元',
    unfreeze_refund_amt   DECIMAL(18,2)  COMMENT '退款释放金额：因退款释放的冻结金额，单位：元',
    freeze_record_qty     BIGINT         COMMENT '冻结记录数：新建冻结记录条数，单位：条',
    external_freeze_amt   DECIMAL(18,2)  COMMENT '外部渠道冻结金额：由第三方支付渠道（如易宝分账）原生冻结的金额，单位：元',
    expire_release_amt    DECIMAL(18,2)  COMMENT '过期兜底释放金额：票过期 30 天后由定时任务释放的冻结金额，单位：元',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '账户×冻结类型 冻结日汇总（travel_date × account_no × freeze_type × external_frozen_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_fin_tenant_pay_method_di  商户×支付方式 收付款日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_fin_tenant_pay_method_di (
    tenant_id             BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    pay_direction_type    STRING         COMMENT '资金方向：INBOUND-收款，OUTBOUND-采购付款',
    pay_method_type       STRING         COMMENT '支付方式：BALANCE-余额，WECHAT-微信，ALIPAY-支付宝，CREDIT-授信，OFFLINE-线下或离线，ZERO_FEE-0元单',
    receive_channel_type  STRING         COMMENT '收款渠道：CASH-现金，WECHAT_QR-微信收款码，ALIPAY_QR-支付宝收款码，BANK_TRANSFER-银行转账，OFFLINE_SYSTEM_OUT-系统外已收款',
    pay_record_qty        BIGINT         COMMENT '支付笔数：状态为 PAID 的支付记录数，单位：笔',
    inbound_pay_amt       DECIMAL(18,2)  COMMENT '收款金额：INBOUND 方向已支付金额，单位：元',
    outbound_pay_amt      DECIMAL(18,2)  COMMENT '采购付款金额：OUTBOUND 方向已支付金额，单位：元',
    refund_payment_amt    DECIMAL(18,2)  COMMENT '退款资金金额：退款明细状态 SUCCESS 的金额，单位：元',
    zero_fee_order_qty    BIGINT         COMMENT '0元单数：0 元单笔数（走支付流程但不产生资金），单位：笔',
    credit_pay_amt        DECIMAL(18,2)  COMMENT '授信支付金额：分销商用授信额度支付的金额，单位：元',
    invoice_amt           DECIMAL(18,2)  COMMENT '开票金额：状态 INVOICED 的发票金额，单位：元',
    invoice_order_qty     BIGINT         COMMENT '开票订单数：已开票的聚合单数（商户给游客），单位：单',
    pay_order_group_qty   BIGINT         COMMENT '支付聚合单数：统计周期内支付成功的聚合单数，单位：单',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户×支付方式 收付款日汇总（travel_date × tenant_id × pay_direction_type × pay_method_type × receive_channel_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_prd_sku_price_di  SKU×渠道 价格日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_prd_sku_price_di (
    sku_id              BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    price_channel_code  STRING         COMMENT '价格渠道编码',
    list_price_amt      DECIMAL(18,2)  COMMENT '生效标价：当日按价格点优先级命中的售价，单位：元',
    price_change_qty    BIGINT         COMMENT '调价次数：价格点新增/修改/删除次数，单位：次',
    avg_deal_price_amt  DECIMAL(18,2)  COMMENT '平均成交价：支付金额 / 支付票数（按 SKU×渠道），单位：元',
    discount_rate       DECIMAL(20,6)  COMMENT '成交折扣率：平均成交价 / 生效标价，单位：%（百分数数值，已乘 100，保留 6 位小数）',
    pay_amt             DECIMAL(18,2)  COMMENT '支付金额（GMV）：支付成功子单的成交金额，不扣退款，单位：元',
    pay_ticket_qty      BIGINT         COMMENT '支付票数：支付成功子单的购买数量合计，单位：张',
    sku_change_qty      BIGINT         COMMENT 'SKU属性变更次数：SKU 版本号变化次数（属性/成本价/退改等变更），单位：次',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SKU×渠道 价格日汇总（travel_date × sku_id × price_channel_code）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_inv_sku_stock_df  SKU×库存维度 库存日快照 ==========
CREATE TABLE IF NOT EXISTS dws.dws_inv_sku_stock_df (
    sku_id                 BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    pool_no                STRING         COMMENT '库存池编号，关联 dim_inv_pool_df',
    play_date              STRING         COMMENT '游玩日期，格式 yyyy-MM-dd',
    room_type_code         STRING         COMMENT '房型编码',
    show_time              STRING         COMMENT '场次时间',
    stock_total_qty        BIGINT         COMMENT '库存总量：日终库存池总量，单位：个',
    stock_available_qty    BIGINT         COMMENT '可用库存：日终库存池可用量，单位：个',
    stock_frozen_qty       BIGINT         COMMENT '预扣库存：日终库存池预扣冻结量，单位：个',
    stock_sold_qty         BIGINT         COMMENT '已售库存：总量 − 可用 − 预扣，单位：个',
    sellout_pool_qty       BIGINT         COMMENT '售罄库存池数：可用量为0且在售的池数，单位：个',
    unit_occupied_qty      BIGINT         COMMENT '已占用座位/房间数：UNIT 资源状态为 OCCUPIED 的数量，单位：个',
    unit_total_qty         BIGINT         COMMENT '座位/房间总数：UNIT 资源总数，单位：个',
    prededuct_qty          BIGINT         COMMENT '预扣量：下单预扣的库存数量，单位：个',
    prededuct_confirm_qty  BIGINT         COMMENT '预扣确认量：预扣转正式扣减的数量，单位：个',
    prededuct_release_qty  BIGINT         COMMENT '预扣释放量：取消/超时释放的预扣数量，单位：个',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SKU×库存维度 库存日快照（travel_date × sku_id × pool_no × play_date × room_type_code/show_time）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_opr_device_di  设备日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_opr_device_di (
    tenant_id               BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    device_id               BIGINT         COMMENT '设备ID，关联 dim_opr_device_df',
    online_minute_qty       BIGINT         COMMENT '设备在线时长：状态为 ACTIVE 的累计分钟数，单位：分钟',
    offline_times_qty       BIGINT         COMMENT '设备离线次数：变为 OFFLINE 的次数，单位：次',
    verify_entitlement_qty  BIGINT         COMMENT '核销权益次数：成功核销记录条数（年卡/次卡每次都计），单位：次',
    device_total_qty        BIGINT         COMMENT '设备数：状态非 INACTIVE 的设备数，单位：台',
    offline_verify_qty      BIGINT         COMMENT '离线核销次数：闸机/手持机离线状态下完成、回连后确认成功的核销次数，单位：次',
    etl_time                STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '设备日汇总（travel_date × tenant_id × device_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_opr_risk_rule_hit_di  风控规则命中日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_opr_risk_rule_hit_di (
    rule_id            BIGINT         COMMENT '风控规则ID，关联 dim_opr_risk_rule_df',
    action_type        STRING         COMMENT '处置动作：BLOCK-拦截，WARN-预警，FREEZE-冻结',
    dimension_type     STRING         COMMENT '规则维度：USER_ID-用户ID，ID_CARD-身份证，PHONE-手机号，IP，DEVICE_ID-设备ID',
    risk_hit_qty       BIGINT         COMMENT '风控命中次数：风控事件数，单位：次',
    risk_block_qty     BIGINT         COMMENT '风控拦截次数：风控规则命中后直接拦截（拒绝操作）的次数，单位：次',
    blacklist_add_qty  BIGINT         COMMENT '新增黑名单数：新增黑名单记录数，单位：条',
    ban_qty            BIGINT         COMMENT '封禁数：新增封禁记录数，单位：条',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '风控规则命中日汇总（travel_date × rule_id × action_type × dimension_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_opr_complaint_di  投诉日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_opr_complaint_di (
    tenant_id               BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    complaint_type          STRING         COMMENT '投诉类型：ORDER_ISSUE-订单问题，SERVICE_ISSUE-服务问题，BUG-系统缺陷，OTHER-其他',
    complainant_type        STRING         COMMENT '投诉方：VISITOR-游客，MERCHANT-商户',
    complaint_qty           BIGINT         COMMENT '投诉数：新建投诉工单数，单位：单',
    complaint_resolved_qty  BIGINT         COMMENT '投诉解决数：状态为 RESOLVED/CLOSED 的工单数，单位：单',
    complaint_overdue_qty   BIGINT         COMMENT '投诉超SLA数：超过 SLA 截止时间才解决、或到截止时间仍未解决的投诉工单数，单位：单',
    etl_time                STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '投诉日汇总（travel_date × tenant_id × complaint_type × complainant_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_opr_notify_di  通知发送日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_opr_notify_di (
    tenant_id             BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    notify_channel_type   STRING         COMMENT '通知渠道：SMS-短信，MINI_PROGRAM_MSG-小程序消息，EMAIL-邮件，WEBHOOK-Webhook，IN_APP-站内信',
    template_code         STRING         COMMENT '通知模板编码',
    notify_send_qty       BIGINT         COMMENT '通知发送数：通知记录数，单位：条',
    notify_success_qty    BIGINT         COMMENT '通知成功数：发送成功的通知条数，单位：条',
    sms_send_qty          BIGINT         COMMENT '短信发送数：通过短信渠道发送的通知条数，单位：条',
    notify_fail_qty       BIGINT         COMMENT '通知失败数：发送失败的通知条数，单位：条',
    resource_consume_qty  BIGINT         COMMENT '资源包消耗量：资源批次剩余量日差，单位：条/点',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '通知发送日汇总（travel_date × tenant_id × notify_channel_type × template_code）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_opr_audit_action_di  操作审计日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_opr_audit_action_di (
    tenant_id         BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    operator_type     STRING         COMMENT '操作人类型：CUSTOMER-C端游客，TENANT_STAFF-B端员工',
    operator_id       BIGINT         COMMENT '操作人ID',
    action_type       STRING         COMMENT '处置动作：BLOCK-拦截，WARN-预警，FREEZE-冻结',
    audit_action_qty  BIGINT         COMMENT '操作次数：审计日志条数，单位：次',
    night_action_qty  BIGINT         COMMENT '凌晨操作次数：0~6点的写操作次数（风控关注），单位：次',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '操作审计日汇总（travel_date × tenant_id × operator_type × operator_id × action_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_opr_approval_di  审批日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_opr_approval_di (
    tenant_id             BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    flow_code             STRING         COMMENT '审批流编码',
    approval_qty          BIGINT         COMMENT '审批发起数：新建审批实例数，单位：个',
    approval_pass_qty     BIGINT         COMMENT '审批通过数：状态 APPROVED 的实例数，单位：个',
    approval_reject_qty   BIGINT         COMMENT '审批拒绝数：状态 REJECTED 的实例数，单位：个',
    approval_minute_qty   BIGINT         COMMENT '审批总耗时：已结束审批实例的耗时合计（分钟），单位：分钟',
    approval_timeout_qty  BIGINT         COMMENT '审批超时数：超过节点截止时间的审批实例数，单位：个',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '审批日汇总（travel_date × tenant_id × flow_code）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_opr_package_subscription_df  套餐订购存量快照 ==========
CREATE TABLE IF NOT EXISTS dws.dws_opr_package_subscription_df (
    package_id                     BIGINT         COMMENT '套餐ID，关联 dim_opr_package_df',
    subscription_type              STRING         COMMENT '订购类型：NEW-新购，RENEW-续费，UPGRADE-升级',
    active_subscription_qty        BIGINT         COMMENT '生效套餐订购数：快照日处于生效期的订购数，单位：个',
    package_amt                    DECIMAL(18,2)  COMMENT '套餐金额：订购对应套餐价格，单位：元',
    expiring_30d_subscription_qty  BIGINT         COMMENT '30天内到期订购数：到期时间在未来30天内的生效订购数，单位：个',
    package_renew_qty              BIGINT         COMMENT '续费订购数：续费类套餐订购笔数，单位：个',
    etl_time                       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '套餐订购存量快照（travel_date × package_id × subscription_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_cus_tenant_growth_di  商户×注册渠道 游客增长日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_cus_tenant_growth_di (
    tenant_id                  BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    register_channel_id        BIGINT         COMMENT '注册渠道ID，关联 dim_trf_channel_df',
    new_customer_qty           BIGINT         COMMENT '新注册游客数：首次登录建档的真实游客数（剔除 TENANT_DEFAULT），单位：人',
    certified_customer_qty     BIGINT         COMMENT '新增实名认证游客数：认证状态变为 PERSON_CERTIFIED 的游客数，单位：人',
    face_register_qty          BIGINT         COMMENT '人脸注册数：新增 FACE 类型个人凭证数，单位：个',
    first_pay_customer_qty     BIGINT         COMMENT '首单买家数：统计周期内首次支付的真实买家数，单位：人',
    register_pay_customer_qty  BIGINT         COMMENT '注册当期下单新客数：统计周期内注册且在同周期内支付的游客数，单位：人',
    repeat_buyer_qty           BIGINT         COMMENT '老客买家数：统计周期内支付且此前已有支付的买家数，单位：人',
    pay_buyer_qty              BIGINT         COMMENT '支付买家数：有支付的真实买家数，剔除 ANONYMOUS 与 TENANT_DEFAULT 占位买家，单位：人',
    identity_bind_qty          BIGINT         COMMENT '渠道身份绑定数：新增的游客渠道身份（微信/抖音/支付宝/OTA），单位：个',
    etl_time                   STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户×注册渠道 游客增长日汇总（travel_date × tenant_id × register_channel_id）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_sup_tenant_onboard_di  平台×地区×业态 商户入驻日汇总 ==========
CREATE TABLE IF NOT EXISTS dws.dws_sup_tenant_onboard_di (
    country_code           STRING         COMMENT '国家编码',
    region_id              BIGINT         COMMENT '地区ID，关联 dim_opr_region_f',
    business_type          STRING         COMMENT '业态：SCENIC-景区门票，HOTEL-酒店，SHOW-演出/…',
    new_tenant_qty         BIGINT         COMMENT '新入驻商户数：统计周期内新建的外部租户数，单位：家',
    tenant_cert_apply_qty  BIGINT         COMMENT '提交认证商户数：认证状态变为 PENDING_REVIEW 的租户数，单位：家',
    tenant_cert_pass_qty   BIGINT         COMMENT '认证通过商户数：认证状态变为 CERTIFIED 的租户数，单位：家',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '平台×地区×业态 商户入驻日汇总（travel_date × country_code × region_id × business_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dws.dws_opr_code_pool_df  码池使用快照 ==========
CREATE TABLE IF NOT EXISTS dws.dws_opr_code_pool_df (
    tenant_id              BIGINT         COMMENT '租户ID，关联 dim_sup_tenant_zip',
    code_pool_id           BIGINT         COMMENT '码池ID，关联 dim_opr_code_pool_df',
    pool_type              STRING         COMMENT '码池类型：SINGLE_TICKET-单票码池，COMBO_TICKET-套票码池',
    code_capacity_qty      BIGINT         COMMENT '码池容量：码池最大并发码数，单位：个',
    code_allocated_qty     BIGINT         COMMENT '已分配码数：码池已分配码数，单位：个',
    code_recycled_qty      BIGINT         COMMENT '回收复用码数：码池已回收复用码数，单位：个',
    issue_credential_qty   BIGINT         COMMENT '发码数：统计周期内发放的票凭证数，单位：个',
    revoke_credential_qty  BIGINT         COMMENT '凭证撤销数：状态变为 REVOKED 的凭证数，单位：个',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '码池使用快照（travel_date × tenant_id × code_pool_id × pool_type）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

