-- PFT 2.0 数仓 DDL：DWD（39 张表）
-- 由 generator/make_all.py 生成，请勿手改

-- ========== dwd.dwd_ord_order_group_di  聚合单明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_order_group_di (
    order_group_id      BIGINT         COMMENT '聚合单ID（源表主键 id）',
    order_group_no      STRING         COMMENT '聚合单号，支付幂等键来源，由流水号生成器生成',
    seller_tenant_id    BIGINT         COMMENT '卖家租户ID（商品归属租户，聚合单层冗余，子单同值）',
    channel_id          BIGINT         COMMENT '入口端ID（指向 t_channel.id：MP_TENANT_HOSTED-租户托管小程序，MP_PLATFORM-平台小程序，PC_TENANT-租户后台，PC_PLATFORM-平台后台，OFFLINE-线下或离线，API_XXX）',
    app_code            STRING         COMMENT '对接端标识（指向t_channel.app_id，标识订单组创建来源端；空串=未指定，历史数据兼容）',
    app_ref_code        STRING         COMMENT '对接端自定义子标识（app_id对应）：小程序=tenant_mp_config_id字符串；API-API 接口=子渠道号；其他=空串',
    operator_type       STRING         COMMENT '操作人类型：CUSTOMER-C端会员，TENANT_STAFF-B端员工含平台员工',
    operator_id         BIGINT         COMMENT '操作人ID（多态：customer_id 或 tenant_staff_id）',
    operator_tenant_id  BIGINT         COMMENT '操作人所属租户ID（=会话tenant_context_id；C端时=渠道端所属租户或=seller_tenant_id）',
    buyer_type          STRING         COMMENT '付款方类型：CUSTOMER-会员或租户默认散客占位，ANONYMOUS-线下现金无主体',
    buyer_id            BIGINT         COMMENT '付款方ID（多态；ANONYMOUS-匿名时=0）',
    buyer_customer_id   BIGINT         COMMENT 'C端筛选冗余：buyer_type=CUSTOMER-C端游客时=buyer_id，否则0（带索引报表用）',
    contact_name        STRING         COMMENT '联系人姓名（脱敏）',
    contact_phone_no    STRING         COMMENT '联系人手机（脱敏）',
    contact_cert_type   STRING         COMMENT '联系人证件类型：ID_CARD-身份证，PASSPORT-护照等',
    contact_cert_no     STRING         COMMENT '联系人证件号（脱敏）',
    total_amt           DECIMAL(18,2)  COMMENT '总金额（元）；源字段单位为分，入仓 ÷100',
    currency_code       STRING         COMMENT '币种（=商户配置币种；MVP不做换算）',
    pay_status          STRING         COMMENT '支付状态：UNPAID-未支付，PARTIAL_PAID-部分支付，PAID-已支付',
    pay_timeout_time    STRING         COMMENT '支付超时截止时间（SKU票属性PAY_TIMEOUT-支付超时驱动，毫秒精度）',
    tenant_id           BIGINT         COMMENT '租户ID（分库维度，=seller_tenant_id）',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    order_date          STRING         COMMENT '下单日期，格式 yyyy-MM-dd',
    first_pay_time      STRING         COMMENT '首次支付成功时间，格式 yyyy-MM-dd HH:mm:ss；未支付为空',
    order_ticket_qty    BIGINT         COMMENT '聚合单内购买票数合计',
    sub_order_qty       BIGINT         COMMENT '聚合单内子单数（套票子项单除外）',
    channel_type        STRING         COMMENT '入口渠道类型：MP-小程序，PC，API-API 接口，OFFLINE-线下或离线，H5',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '聚合单明细（1行=1个聚合单（order_group_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_ord_order_di  子单明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_order_di (
    order_id              BIGINT         COMMENT '子单ID（源表主键 id）',
    order_no              STRING         COMMENT '子单号，由流水号生成器生成',
    order_group_no        STRING         COMMENT '归属聚合单号',
    parent_order_no       STRING         COMMENT '套票子单指向主单号，非套票=空串',
    combo_type            INT            COMMENT '是否套票主单：1=套票主单，0=普通子单或套票子项',
    seller_tenant_id      BIGINT         COMMENT '卖家商户ID',
    sku_id                BIGINT         COMMENT 'SKU ID',
    sku_name              STRING         COMMENT 'SKU名称（下单时快照）',
    sku_version_no        INT            COMMENT '下单时SKU版本号（查订单商品属性时按sku_id+sku_version还原）',
    buy_ticket_qty        INT            COMMENT '购买数量',
    unit_price_amt        DECIMAL(18,2)  COMMENT '单价（元）；套票主单=套餐总价，套票子单=分摊价；源字段单位为分，入仓 ÷100',
    order_status          STRING         COMMENT '状态：PENDING_PAY-待支付，PAID-已支付，PARTIALLY_VERIFIED-部分核销，FULLY_VERIFIED-已全部核销，REFUNDED-已退款，CANCELLED-已取消',
    tenant_id             BIGINT         COMMENT '租户ID（分库维度）',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    channel_id            BIGINT         COMMENT '入口渠道ID，关联 dim_trf_channel_df',
    channel_type          STRING         COMMENT '入口渠道类型：MP-小程序，PC，API-API 接口，OFFLINE-线下或离线，H5',
    app_code              STRING         COMMENT '对接端标识（取自 t_channel.app_id）',
    app_ref_code          STRING         COMMENT '对接端引用',
    operator_type         STRING         COMMENT '操作人类型：CUSTOMER-C端游客，TENANT_STAFF-B端员工',
    operator_id           BIGINT         COMMENT '操作人ID（游客或员工）',
    buyer_type            STRING         COMMENT '付款方类型：CUSTOMER-C端游客，ANONYMOUS-匿名',
    buyer_customer_id     BIGINT         COMMENT '买家游客ID，关联 dim_cus_customer_zip',
    currency_code         STRING         COMMENT '币种编码，关联 dim_opr_currency_f',
    spu_id                BIGINT         COMMENT '产品(SPU)ID，关联 dim_prd_spu_zip',
    product_type          STRING         COMMENT '产品业态：SCENIC-景区门票，HOTEL-酒店，SHOW-演出/…',
    play_date             STRING         COMMENT '游玩日期，格式 yyyy-MM-dd',
    time_slot_code        STRING         COMMENT '游玩时段，如 10:00-11:00',
    seat_zone_code        STRING         COMMENT '座位区域，如 VIP',
    order_amt             DECIMAL(18,2)  COMMENT '子单金额（元）= 单价 × 购买数量',
    cost_price_amt        DECIMAL(18,2)  COMMENT '下单时 SKU 成本价（元）',
    order_date            STRING         COMMENT '下单日期，格式 yyyy-MM-dd',
    pay_time              STRING         COMMENT '支付成功时间；未支付为空',
    cancel_time           STRING         COMMENT '取消时间；未取消为空',
    advance_book_day_qty  BIGINT         COMMENT '提前预订天数 = 游玩日期 - 下单日期',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '子单明细（1行=1个子单（order_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_ord_order_status_log_di  子单状态流转明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_order_status_log_di (
    order_no           STRING         COMMENT '子单号',
    order_group_no     STRING         COMMENT '所属聚合单号',
    seller_tenant_id   BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id             BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    before_status      STRING         COMMENT '变更前状态：PENDING_PAY-待支付，PAID-已支付，PARTIALLY_VERIFIED-部分核销，FULLY_VERIFIED-已全部核销，REFUNDED-已退款，CANCELLED-已取消',
    after_status       STRING         COMMENT '变更后状态：PENDING_PAY-待支付，PAID-已支付，PARTIALLY_VERIFIED-部分核销，FULLY_VERIFIED-已全部核销，REFUNDED-已退款，CANCELLED-已取消',
    change_time        STRING         COMMENT '状态变更时间，格式 yyyy-MM-dd HH:mm:ss',
    status_change_qty  BIGINT         COMMENT '状态变更次数，固定为 1',
    stay_minute_qty    BIGINT         COMMENT '前一状态停留时长（分钟）',
    tenant_id          BIGINT         COMMENT '租户ID（分库维度）',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '子单状态流转明细（1行=1次子单状态变更）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_ord_ticket_di  票明细（出票） ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_ticket_di (
    ticket_id          BIGINT         COMMENT '票ID（源表主键 id）',
    ticket_no          STRING         COMMENT '票号，格式TKT+yyyyMMdd+6位随机',
    order_no           STRING         COMMENT '归属子单号',
    ticket_status      STRING         COMMENT '票状态：AVAILABLE-可用，PARTIALLY_USED-部分使用，USED-已使用，EXPIRED-已过期，REFUNDED-已退款，CANCELLED-已取消',
    valid_start_time   STRING         COMMENT '有效期起始（出票时确定或首次核销时延迟确定，毫秒精度）',
    valid_end_time     STRING         COMMENT '有效期终止（毫秒精度）',
    pass_policy_type   STRING         COMMENT '放行策略（从SKU继承）：SINGLE-分批，BATCH-整批',
    tenant_id          BIGINT         COMMENT '租户ID（分库维度）',
    create_time        STRING         COMMENT '创建时间',
    update_time        STRING         COMMENT '更新时间',
    order_group_no     STRING         COMMENT '所属聚合单号',
    seller_tenant_id   BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id             BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    spu_id             BIGINT         COMMENT '产品(SPU)ID',
    channel_id         BIGINT         COMMENT '入口渠道ID',
    buyer_customer_id  BIGINT         COMMENT '买家游客ID',
    play_date          STRING         COMMENT '游玩日期，格式 yyyy-MM-dd',
    valid_end_date     STRING         COMMENT '有效期截止日期，格式 yyyy-MM-dd',
    seat_no            STRING         COMMENT '座位号（演出/场馆）',
    cabin_no           STRING         COMMENT '舱位号（游船）',
    schedule_time      STRING         COMMENT '场次/班次时间',
    unit_price_amt     DECIMAL(18,2)  COMMENT '票分摊单价（元）',
    ticket_qty         BIGINT         COMMENT '票数，固定为 1',
    delay_active_type  INT            COMMENT '是否延迟激活：0-否，1-是（首次核销后回填有效期）',
    first_verify_time  STRING         COMMENT '首次核销时间；未核销为空',
    issue_time         STRING         COMMENT '出票时间',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '票明细（出票）（1行=1张票（ticket_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_ord_ticket_status_log_di  票状态流转明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_ticket_status_log_di (
    ticket_no          STRING         COMMENT '票号',
    order_no           STRING         COMMENT '所属子单号',
    order_group_no     STRING         COMMENT '所属聚合单号',
    seller_tenant_id   BIGINT         COMMENT '卖家租户ID，关联 dim_sup_tenant_zip',
    sku_id             BIGINT         COMMENT 'SKU ID，关联 dim_prd_sku_zip',
    before_status      STRING         COMMENT '变更前状态：AVAILABLE-可用，PARTIALLY_USED-部分使用，USED-已使用，EXPIRED-已过期，REFUNDED-已退款，CANCELLED-已取消',
    after_status       STRING         COMMENT '变更后状态：AVAILABLE-可用，PARTIALLY_USED-部分使用，USED-已使用，EXPIRED-已过期，REFUNDED-已退款，CANCELLED-已取消',
    change_time        STRING         COMMENT '状态变更时间，格式 yyyy-MM-dd HH:mm:ss',
    status_change_qty  BIGINT         COMMENT '状态变更次数，固定为 1',
    stay_minute_qty    BIGINT         COMMENT '前一状态停留时长（分钟）',
    tenant_id          BIGINT         COMMENT '租户ID（分库维度）',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '票状态流转明细（1行=1次票状态变更）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_ord_ticket_person_di  票游客明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_ticket_person_di (
    person_id             BIGINT         COMMENT '票上的人ID（源表主键 id）',
    ticket_no             STRING         COMMENT '归属票号',
    person_code           STRING         COMMENT '人ID（票内唯一）',
    global_customer_id    BIGINT         COMMENT '关联 Customer 全局ID（首次登录才建 Customer，未登录=0）',
    person_name           STRING         COMMENT '姓名（脱敏）',
    cert_type             STRING         COMMENT '证件类型：ID_CARD-身份证，PASSPORT-护照等',
    cert_no               STRING         COMMENT '证件号（脱敏）',
    phone_no              STRING         COMMENT '手机号（脱敏）',
    primary_person_type   INT            COMMENT '是否主游客：0否/1是',
    tenant_id             BIGINT         COMMENT '租户ID（分库维度）',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    order_no              STRING         COMMENT '所属子单号',
    seller_tenant_id      BIGINT         COMMENT '卖家租户ID',
    sku_id                BIGINT         COMMENT 'SKU ID',
    play_date             STRING         COMMENT '游玩日期',
    origin_country_code   STRING         COMMENT '客源国家编码',
    origin_province_code  STRING         COMMENT '客源省份编码',
    origin_province_name  STRING         COMMENT '客源省份名称',
    origin_city_code      STRING         COMMENT '客源城市编码',
    origin_city_name      STRING         COMMENT '客源城市名称',
    age_year_qty          BIGINT         COMMENT '游玩时年龄（岁）',
    age_band_code         STRING         COMMENT '年龄段：0_17-未成年，18_25-18~25岁，26_35-26~35岁，36_45-36~45岁，46_60-46~60岁，60_PLUS-60岁以上，UNKNOWN-未知',
    gender_type           STRING         COMMENT '性别：MALE-男，FEMALE-女，UNKNOWN-未知',
    person_qty            BIGINT         COMMENT '游客人数，固定为 1',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '票游客明细（1行=1张票上1个人（ticket_no+person_id））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_ord_entitlement_di  权益明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_entitlement_di (
    entitlement_id       BIGINT         COMMENT '权益ID（源表主键 id）',
    entitlement_no       STRING         COMMENT '权益号，由流水号生成器生成',
    ticket_no            STRING         COMMENT '归属票号',
    entitlement_type     STRING         COMMENT '权益类型：FIXED-固定，SELECTABLE-选择型，COUNTED-计次型，TIMED-计时型，UNLIMITED-不限次型，QUOTA-额度型',
    entitlement_name     STRING         COMMENT '权益名称（如"成人入园""住宿1晚"）',
    entitlement_status   STRING         COMMENT '权益状态：ACTIVE-有效，USED-已使用，EXPIRED-已过期，REFUNDED-已退款',
    used_qty             INT            COMMENT '已用次数（所有类型共有）',
    valid_start_time     STRING         COMMENT '权益有效期起始（可收窄于票有效期，毫秒精度）',
    valid_end_time       STRING         COMMENT '权益有效期终止（毫秒精度）',
    tenant_id            BIGINT         COMMENT '租户ID（分库维度）',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    order_no             STRING         COMMENT '所属子单号',
    seller_tenant_id     BIGINT         COMMENT '卖家租户ID',
    sku_id               BIGINT         COMMENT 'SKU ID',
    project_id           BIGINT         COMMENT '权益对应项目ID',
    max_qty              BIGINT         COMMENT '最大可用次数（COUNTED-计次型，SELECTABLE-选择型）',
    candidate_qty        BIGINT         COMMENT '可选项目数（SELECTABLE-选择型）',
    duration_minute_qty  BIGINT         COMMENT '可用时长（分钟，TIMED-计时型）',
    quota_amt            DECIMAL(18,2)  COMMENT '额度（元，QUOTA-额度型）',
    remain_qty           BIGINT         COMMENT '剩余可用次数 = 最大可用次数 - 已使用次数',
    issue_time           STRING         COMMENT '发放时间',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '权益明细（1行=1个权益（entitlement_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_ord_entitlement_binding_di  人-权益绑定明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_entitlement_binding_di (
    binding_id        BIGINT         COMMENT '人-权益绑定ID（源表主键 id）',
    ticket_no         STRING         COMMENT '归属票号',
    person_code       STRING         COMMENT '人ID（空串=开放争抢，OPEN-开放争抢模式）',
    entitlement_no    STRING         COMMENT '权益号',
    binding_type      STRING         COMMENT '绑定类型：EXCLUSIVE-专属绑定，SHARED-共享绑定，OPEN-开放争抢',
    tenant_id         BIGINT         COMMENT '租户ID（分库维度）',
    create_time       STRING         COMMENT '创建时间',
    update_time       STRING         COMMENT '更新时间',
    seller_tenant_id  BIGINT         COMMENT '卖家租户ID',
    sku_id            BIGINT         COMMENT 'SKU ID',
    entitlement_type  STRING         COMMENT '权益类型：FIXED-固定，COUNTED-计次型，SELECTABLE-选择型，TIMED-计时型，QUOTA-额度型，UNLIMITED-不限次型',
    bind_time         STRING         COMMENT '绑定时间',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '人-权益绑定明细（1行=1条绑定（ticket_no+person_id+entitlement_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_ord_ticket_credential_di  凭证发码/撤销明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_ticket_credential_di (
    credential_id      BIGINT         COMMENT '票凭证ID（源表主键 id）',
    credential_no      STRING         COMMENT '凭证号，由流水号生成器生成',
    ticket_no          STRING         COMMENT '归属票号',
    credential_type    STRING         COMMENT '凭证类型：QR_CODE-二维码，BAR_CODE-条形码，ID_CARD-身份证，FACE-人脸',
    credential_code    STRING         COMMENT '码值（码池分配）（脱敏）',
    code_pool_id       BIGINT         COMMENT '归属码池ID',
    credential_status  STRING         COMMENT '状态：ACTIVE-有效，EXPIRED-已过期，REVOKED-已撤销',
    tenant_id          BIGINT         COMMENT '租户ID（分库维度）',
    create_time        STRING         COMMENT '创建时间',
    update_time        STRING         COMMENT '更新时间',
    order_no           STRING         COMMENT '所属子单号',
    seller_tenant_id   BIGINT         COMMENT '卖家租户ID',
    sku_id             BIGINT         COMMENT 'SKU ID',
    issue_time         STRING         COMMENT '发码时间',
    revoke_time        STRING         COMMENT '撤销时间；未撤销为空',
    credential_qty     BIGINT         COMMENT '凭证数，固定为 1',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '凭证发码/撤销明细（1行=1个凭证（credential_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_ord_verify_di  核销明细（权益级） ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_verify_di (
    verify_id              BIGINT         COMMENT '核销记录ID（源表主键 id）',
    verify_no              STRING         COMMENT '核销记录号，格式VF+yyyyMMdd+6位随机',
    ticket_no              STRING         COMMENT '核销票号',
    entitlement_no         STRING         COMMENT '核销权益号',
    verify_point_id        BIGINT         COMMENT '核销点ID',
    operator_id            BIGINT         COMMENT '操作人ID',
    device_id              BIGINT         COMMENT '核销设备ID',
    verify_type            STRING         COMMENT '核销类型：ONLINE-在线，OFFLINE-线下或离线',
    offline_device_time    BIGINT         COMMENT '离线时序戳（离线核销时设备时间）',
    verify_result_type     STRING         COMMENT '结果：SUCCESS-成功，FAILED-失败，DUPLICATE-重复',
    tenant_id              BIGINT         COMMENT '租户ID（分库维度）',
    create_time            STRING         COMMENT '创建时间（在线=服务器时间，离线=回连时间）',
    update_time            STRING         COMMENT '更新时间',
    order_no               STRING         COMMENT '所属子单号',
    seller_tenant_id       BIGINT         COMMENT '卖家租户ID',
    sku_id                 BIGINT         COMMENT 'SKU ID',
    spu_id                 BIGINT         COMMENT '产品(SPU)ID',
    play_date              STRING         COMMENT '游玩日期',
    entitlement_type       STRING         COMMENT '权益类型：FIXED-固定，COUNTED-计次型，SELECTABLE-选择型，TIMED-计时型，QUOTA-额度型，UNLIMITED-不限次型',
    verify_point_type      STRING         COMMENT '核销点类型：GATE-闸机，COUNTER-窗口，SELF_SERVICE-自助机，HANDHELD-手持机',
    device_type            STRING         COMMENT '设备类型：GATE-闸机，POS-POS 机，HANDHELD-手持机，SELF_SERVICE-自助机，KIOSK-自助终端，FACE_RECOGNITION-人脸识别机',
    verify_time            STRING         COMMENT '核销时间，格式 yyyy-MM-dd HH:mm:ss',
    verify_hour_no         INT            COMMENT '核销小时：0~23',
    verify_person_qty      BIGINT         COMMENT '本次核销人数',
    verify_qty             BIGINT         COMMENT '核销次数，固定为 1',
    verify_amt             DECIMAL(18,2)  COMMENT '核销金额（元，按票分摊单价 ÷ 可核销次数）',
    offline_conflict_type  INT            COMMENT '是否离线冲突：0-否，1-是（离线核销回传时票已被核销）',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '核销明细（权益级）（1行=1次核销（verify_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_ord_refund_di  退款单明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_refund_di (
    refund_id           BIGINT         COMMENT '退款单ID（源表主键 id）',
    refund_no           STRING         COMMENT '退款单号，格式REF+yyyyMMdd+6位随机',
    order_group_no      STRING         COMMENT '归属聚合单号',
    refund_type         STRING         COMMENT '退款类型：ORDER_REFUND-订单退款，COMPENSATION-售后补偿，PARTIAL_REFUND-部分退款',
    refund_reason_desc  STRING         COMMENT '退款原因',
    refund_amt          DECIMAL(18,2)  COMMENT '退款总金额（元）；源字段单位为分，入仓 ÷100',
    refund_status       STRING         COMMENT '状态：PENDING-待处理，APPROVED-已通过，PROCESSING-处理中，COMPLETED-已完成，REJECTED-已拒绝',
    initiator_type      STRING         COMMENT '发起方：VISITOR-游客，MERCHANT-商户，PLATFORM-平台，SYSTEM-系统，OTA',
    initiator_id        BIGINT         COMMENT '发起方ID',
    approver_id         BIGINT         COMMENT '审批人ID',
    approve_time        STRING         COMMENT '审批时间',
    tenant_id           BIGINT         COMMENT '租户ID（分库维度）',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    seller_tenant_id    BIGINT         COMMENT '卖家租户ID',
    channel_id          BIGINT         COMMENT '入口渠道ID',
    apply_time          STRING         COMMENT '退款申请时间',
    finish_time         STRING         COMMENT '退款完成时间；未完成为空',
    process_hour_qty    DECIMAL(18,2)  COMMENT '退款处理时长（小时）= 完成时间 - 申请时间',
    refund_ticket_qty   BIGINT         COMMENT '退款票数',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '退款单明细（1行=1个退款单（refund_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_ord_refund_ticket_di  退款票明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_refund_ticket_di (
    refund_no             STRING         COMMENT '退款单号',
    order_group_no        STRING         COMMENT '聚合单号',
    order_no              STRING         COMMENT '子单号',
    ticket_no             STRING         COMMENT '票号',
    seller_tenant_id      BIGINT         COMMENT '卖家租户ID',
    sku_id                BIGINT         COMMENT 'SKU ID',
    play_date             STRING         COMMENT '游玩日期',
    refund_type           STRING         COMMENT '退款类型：ORDER_REFUND-订单退款，COMPENSATION-售后补偿，PARTIAL_REFUND-部分退款',
    refund_status         STRING         COMMENT '退款状态：PENDING-待处理，APPROVED-已通过，PROCESSING-处理中，COMPLETED-已完成，REJECTED-已拒绝',
    initiator_type        STRING         COMMENT '发起方：VISITOR-游客，MERCHANT-商户，PLATFORM-平台，SYSTEM-系统，OTA',
    refund_reason_desc    STRING         COMMENT '退款原因',
    before_ticket_status  STRING         COMMENT '退票时票状态：AVAILABLE-可用，PARTIALLY_USED-部分使用',
    refund_ticket_qty     BIGINT         COMMENT '退款票数，固定为 1',
    refund_amt            DECIMAL(18,2)  COMMENT '本票分摊退款金额（元）',
    apply_time            STRING         COMMENT '退款申请时间',
    finish_time           STRING         COMMENT '退款完成时间',
    tenant_id             BIGINT         COMMENT '租户ID（分库维度）',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '退款票明细（1行=1个退款单里的1张票）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_fin_payment_di  支付明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_fin_payment_di (
    payment_id            BIGINT         COMMENT '支付记录ID（源表主键 id）',
    payment_no            STRING         COMMENT '支付流水号，由流水号生成器生成',
    batch_no              STRING         COMMENT '批量支付单号(同批共享),单条时空',
    item_no               STRING         COMMENT '批内项号(批内唯一,标识本条在批中的位置)',
    depend_on_item_no     STRING         COMMENT '依赖项号(必须在依赖项成功后执行,空=无依赖)',
    order_group_no        STRING         COMMENT '归属聚合单号',
    pay_direction_type    STRING         COMMENT '资金方向:INBOUND-收款，OUTBOUND-采购付款',
    pay_method_type       STRING         COMMENT '支付方式：BALANCE-余额，WECHAT-微信，ALIPAY-支付宝，CREDIT-授信，OFFLINE-线下或离线，ZERO_FEE-0元单等',
    receive_channel_type  STRING         COMMENT '收款渠道(INBOUND-收款时填):CASH-现金，WECHAT_QR-微信收款码，ALIPAY_QR-支付宝收款码，BANK_TRANSFER-银行转账，OFFLINE_SYSTEM_OUT-系统外已收',
    pay_amt               DECIMAL(18,2)  COMMENT '支付金额（元）；源字段单位为分，入仓 ÷100',
    settle_amt            DECIMAL(18,2)  COMMENT '结算金额（元，OUTBOUND-采购付款=向上采购价;INBOUND-收款=售价;利润=amount-settle_amount)；源字段单位为分，入仓 ÷100',
    transaction_no        STRING         COMMENT '渠道流水号（第三方回调返回或内部渠道同步生成）',
    payer_account_no      STRING         COMMENT '付款方账户(OUTBOUND-采购付款=采购方;INBOUND-收款=空)',
    payee_account_no      STRING         COMMENT '收款方账户(INBOUND-收款=卖方;OUTBOUND-采购付款=供应商)',
    ticket_no             STRING         COMMENT '关联票号(用于关联冻结记录)',
    external_frozen_type  INT            COMMENT '是否外部渠道冻结:1=第三方冻结(如易宝分账),0=平台内部冻结',
    pay_time              STRING         COMMENT '支付时间',
    pay_status            STRING         COMMENT '支付状态：CREATED-已创建，PAID-已支付，PARTIAL_REFUNDED-部分退款，REFUNDED-已退款',
    tenant_id             BIGINT         COMMENT '租户ID（分库维度）',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    seller_tenant_id      BIGINT         COMMENT '卖家租户ID',
    payer_tenant_id       BIGINT         COMMENT '付款方租户ID',
    payee_tenant_id       BIGINT         COMMENT '收款方租户ID',
    sku_id                BIGINT         COMMENT 'SKU ID（按票关联）',
    freeze_type           STRING         COMMENT '冻结类型：PROFIT-利润，SETTLEMENT-采购款，FULL-全款',
    profit_amt            DECIMAL(18,2)  COMMENT '本级利润（元）= 支付金额 - 结算金额',
    pay_date              STRING         COMMENT '支付日期，格式 yyyy-MM-dd',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '支付明细（1行=1条支付记录（payment_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_fin_refund_payment_di  退款资金明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_fin_refund_payment_di (
    refund_detail_id       BIGINT         COMMENT '退款明细（按支付记录）ID（源表主键 id）',
    refund_detail_no       STRING         COMMENT '退款明细号，由流水号生成器生成',
    refund_no              STRING         COMMENT '归属退款单号',
    payment_no             STRING         COMMENT '关联支付记录号（退款来源）',
    refund_amt             DECIMAL(18,2)  COMMENT '本次退款金额（元，来自该支付记录的退款部分）；源字段单位为分，入仓 ÷100',
    refund_channel_type    STRING         COMMENT '退款渠道：WECHAT-微信，ALIPAY-支付宝，BALANCE-余额，CREDIT-授信等（与原支付渠道对应）',
    refund_transaction_no  STRING         COMMENT '支付中心返回的退款流水号（用于后续跟踪对账）',
    refund_detail_status   STRING         COMMENT '明细状态：PENDING-待处理，PROCESSING-处理中，SUCCESS-成功，FAILED-失败',
    tenant_id              BIGINT         COMMENT '租户ID（分库维度）',
    create_time            STRING         COMMENT '创建时间',
    update_time            STRING         COMMENT '更新时间',
    order_group_no         STRING         COMMENT '聚合单号',
    pay_method_type        STRING         COMMENT '原支付方式：BALANCE-余额，WECHAT-微信，ALIPAY-支付宝，CREDIT-授信，OFFLINE-线下或离线，ZERO_FEE-0元单',
    pay_direction_type     STRING         COMMENT '原资金方向：INBOUND-收款，OUTBOUND-采购付款',
    finish_time            STRING         COMMENT '退款到账时间；未完成为空',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '退款资金明细（1行=1条退款明细（refund_detail_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_fin_frozen_di  冻结/解冻明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_fin_frozen_di (
    frozen_id              BIGINT         COMMENT '冻结记录ID（源表主键 id）',
    frozen_no              STRING         COMMENT '冻结记录编号，由流水号生成器生成',
    account_no             STRING         COMMENT '归属账户编号',
    ticket_no              STRING         COMMENT '关联票号（票级冻结）',
    freeze_amt             DECIMAL(18,2)  COMMENT '冻结金额（元）= 利润/采购款/全款；源字段单位为分，入仓 ÷100',
    freeze_type            STRING         COMMENT '冻结类型:PROFIT-利润，SETTLEMENT-采购款，FULL-全款，供应商直销',
    frozen_status          STRING         COMMENT '状态：FROZEN-冻结中，RELEASED-已释放',
    release_event_type     STRING         COMMENT '冻结事件：VERIFY-核销，REFUND-退款',
    external_frozen_type   INT            COMMENT '是否外部渠道冻结:1=第三方冻结(解冻调第三方API-API 接口),0=平台内部冻结',
    external_channel_code  STRING         COMMENT '外部渠道(external_frozen=1时):YEEPAY-易宝，UNIONPAY-银联等',
    external_frozen_no     STRING         COMMENT '外部冻结单号(第三方返回的冻结流水号,解冻时用)',
    tenant_id              BIGINT         COMMENT '租户ID（分库维度）',
    create_time            STRING         COMMENT '创建时间',
    update_time            STRING         COMMENT '更新时间',
    account_type           STRING         COMMENT '账户类型：MERCHANT-商户，DISTRIBUTOR-分销商，PLATFORM-平台',
    subject_id             BIGINT         COMMENT '账户主体ID',
    sku_id                 BIGINT         COMMENT 'SKU ID',
    freeze_time            STRING         COMMENT '冻结时间',
    release_time           STRING         COMMENT '解冻时间；未解冻为空',
    freeze_hour_qty        DECIMAL(18,2)  COMMENT '冻结时长（小时）',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '冻结/解冻明细（1行=1条冻结记录（frozen_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_fin_fund_flow_di  资金流水明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_fin_fund_flow_di (
    flow_id              BIGINT         COMMENT '资金流水ID（源表主键 id）',
    flow_no              STRING         COMMENT '流水号，格式FL+yyyyMMdd+6位随机',
    account_no           STRING         COMMENT '归属账户编号',
    flow_type            STRING         COMMENT '流水类型：RECHARGE-充值，PAYMENT-支付，REFUND-退款，FREEZE-冻结，UNFREEZE-解冻，WITHDRAW-提现，FEE-手续费，RESOURCE-资源包，TRANSFER_OUT-采购转出，TRANSFER_IN-采购转入',
    change_amt           DECIMAL(18,2)  COMMENT '变动金额（元，正=入，负=出）；源字段单位为分，入仓 ÷100',
    balance_before_amt   DECIMAL(18,2)  COMMENT '变动前余额（元）；源字段单位为分，入仓 ÷100',
    balance_after_amt    DECIMAL(18,2)  COMMENT '变动后余额（元）；源字段单位为分，入仓 ÷100',
    related_no           STRING         COMMENT '关联业务号（订单号/退款号/提现号等）',
    payment_batch_no     STRING         COMMENT '关联支付批次号(追溯资金动作来源)',
    fee_item_code        STRING         COMMENT '费用项（短信费/提现手续费等）',
    remark_desc          STRING         COMMENT '备注',
    tenant_id            BIGINT         COMMENT '租户ID（分库维度）',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    account_type         STRING         COMMENT '账户类型：MERCHANT-商户，DISTRIBUTOR-分销商，PLATFORM-平台',
    subject_id           BIGINT         COMMENT '账户主体ID',
    flow_direction_type  INT            COMMENT '资金方向：1-入账，2-出账',
    flow_time            STRING         COMMENT '流水发生时间',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '资金流水明细（1行=1条流水（flow_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_fin_withdraw_di  提现明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_fin_withdraw_di (
    withdraw_id       BIGINT         COMMENT '提现单ID（源表主键 id）',
    withdraw_no       STRING         COMMENT '提现单号，格式WD+yyyyMMdd+6位随机',
    account_no        STRING         COMMENT '提现账户编号',
    subject_id        BIGINT         COMMENT '提现主体ID（商户/分销商）',
    withdraw_amt      DECIMAL(18,2)  COMMENT '提现金额（元）；源字段单位为分，入仓 ÷100',
    bank_card_id      BIGINT         COMMENT '提现银行卡ID',
    withdraw_status   STRING         COMMENT '状态：PENDING-待处理，APPROVED-已通过，PROCESSING-处理中，COMPLETED-已完成，REJECTED-已拒绝，FAILED-失败',
    approval_no       STRING         COMMENT '审批实例号',
    transaction_no    STRING         COMMENT '第三方打款流水号',
    fail_reason_desc  STRING         COMMENT '失败原因',
    tenant_id         BIGINT         COMMENT '租户ID（分库维度）',
    create_time       STRING         COMMENT '创建时间',
    update_time       STRING         COMMENT '更新时间',
    account_type      STRING         COMMENT '账户类型：MERCHANT-商户，DISTRIBUTOR-分销商，PLATFORM-平台',
    bank_name         STRING         COMMENT '提现银行',
    apply_time        STRING         COMMENT '提现申请时间',
    finish_time       STRING         COMMENT '提现完成时间；未完成为空',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '提现明细（1行=1个提现单（withdraw_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_fin_invoice_di  发票明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_fin_invoice_di (
    invoice_id             BIGINT         COMMENT '发票单ID（源表主键 id）',
    invoice_no             STRING         COMMENT '发票单号，格式INV+yyyyMMdd+6位随机',
    tenant_id              BIGINT         COMMENT '开票商户ID',
    invoice_type           STRING         COMMENT '发票类型：E_NORMAL-电子普票，E_SPECIAL-电子专票',
    invoice_subject_type   STRING         COMMENT '开票主体：MERCHANT_TO_VISITOR-商户给游客开票，PLATFORM_TO_MERCHANT-平台给商户开票',
    order_group_no         STRING         COMMENT '关联订单号（商户给游客开票）',
    fee_item_code          STRING         COMMENT '费用项（平台给商户开票时）',
    invoice_amt            DECIMAL(18,2)  COMMENT '开票金额（元）；源字段单位为分，入仓 ÷100',
    invoice_config_id      BIGINT         COMMENT '发票配置ID（引用t_invoice_config）',
    invoice_status         STRING         COMMENT '状态：PENDING-待处理，APPROVED-已通过，INVOICED-已开票，RED_INVOICED-已红冲，REJECTED-已拒绝',
    invoice_file_url_desc  STRING         COMMENT '发票文件URL-开票成功后存OSS',
    approval_no            STRING         COMMENT '审批实例号',
    create_time            STRING         COMMENT '创建时间',
    update_time            STRING         COMMENT '更新时间',
    invoice_provider_code  STRING         COMMENT '开票服务商',
    apply_time             STRING         COMMENT '开票申请时间',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '发票明细（1行=1个发票单（invoice_no））'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_fin_resource_batch_di  资源包购买/消耗明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_fin_resource_batch_di (
    resource_batch_id  BIGINT         COMMENT '资源批次（短信/积分）ID（源表主键 id）',
    batch_no           STRING         COMMENT '批次号，格式RB+yyyyMMdd+6位随机',
    tenant_id          BIGINT         COMMENT '归属商户ID',
    resource_type      DECIMAL(18,2)  COMMENT '资源类型：SMS-短信，POINTS-积分，ALARM_QUOTA-预警额度；源字段单位为分，入仓 ÷100',
    total_qty          BIGINT         COMMENT '总量（短信条数/积分点数/预警额度）',
    remaining_qty      BIGINT         COMMENT '剩余量',
    unit_type          STRING         COMMENT '单位：COUNT-条，POINT-点，YUAN-元',
    expire_time        STRING         COMMENT '过期时间',
    batch_status       STRING         COMMENT '状态：ACTIVE-有效，EXPIRED-已过期，CONSUMED-已用完',
    purchase_no        STRING         COMMENT '购买流水号（引用资金流水）',
    create_time        STRING         COMMENT '创建时间',
    update_time        STRING         COMMENT '更新时间',
    package_id         BIGINT         COMMENT '来源套餐ID',
    consume_qty        BIGINT         COMMENT '当日消耗量 = 昨日剩余量 - 今日剩余量（不含新购）',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '资源包购买/消耗明细（1行=1个资源批次的1日状态）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_trf_distribution_settle_di  分销采购链明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_trf_distribution_settle_di (
    ticket_no              STRING         COMMENT '票号',
    order_no               STRING         COMMENT '子单号',
    order_group_no         STRING         COMMENT '聚合单号',
    batch_no               STRING         COMMENT '支付批次号',
    item_no                STRING         COMMENT '支付批次内明细号',
    payment_no             STRING         COMMENT '支付记录号',
    chain_level_no         INT            COMMENT '分销链层级：1-游客→末级分销商，2~4-逐级向上采购',
    relation_no            STRING         COMMENT '分销关系编号',
    supplier_tenant_id     BIGINT         COMMENT '本级供应商（收款方）租户ID',
    distributor_tenant_id  BIGINT         COMMENT '本级分销商（付款方）租户ID；第 1 级为空',
    payer_account_no       STRING         COMMENT '付款账户号',
    payee_account_no       STRING         COMMENT '收款账户号',
    sku_id                 BIGINT         COMMENT 'SKU ID',
    sale_amt               DECIMAL(18,2)  COMMENT '本级售价（元）',
    settle_amt             DECIMAL(18,2)  COMMENT '本级结算价（元）',
    profit_amt             DECIMAL(18,2)  COMMENT '本级利润（元）= 售价 - 结算价',
    freeze_type            STRING         COMMENT '冻结类型：PROFIT-利润，SETTLEMENT-采购款，FULL-全款',
    pay_method_type        STRING         COMMENT '支付方式：BALANCE-余额，WECHAT-微信，ALIPAY-支付宝，CREDIT-授信，OFFLINE-线下或离线，ZERO_FEE-0元单',
    pay_time               STRING         COMMENT '支付时间',
    tenant_id              BIGINT         COMMENT '租户ID（分库维度）',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '分销采购链明细（1行=1张票在分销链上的1个层级）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_prd_sku_version_di  SKU版本变更明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_prd_sku_version_di (
    snapshot_id           BIGINT         COMMENT 'SKU版本快照ID（源表主键 id）',
    snapshot_no           STRING         COMMENT '快照编号，格式SKVS+yyyyMMdd+6位随机',
    sku_id                BIGINT         COMMENT 'SKU ID',
    version_no            INT            COMMENT '版本号（变更前的版本号）',
    change_operator_name  STRING         COMMENT '变更操作人',
    change_reason_desc    STRING         COMMENT '变更原因',
    tenant_id             BIGINT         COMMENT '租户ID（分库维度）',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    new_version_no        INT            COMMENT '变更后版本号',
    old_price_amt         DECIMAL(18,2)  COMMENT '变更前价格（元）',
    new_price_amt         DECIMAL(18,2)  COMMENT '变更后价格（元）',
    price_change_type     INT            COMMENT '本次是否改价：0-否，1-是',
    change_time           STRING         COMMENT '变更时间',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SKU版本变更明细（1行=1次SKU版本变更）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_prd_price_point_log_di  价格点变更明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_prd_price_point_log_di (
    price_point_id        BIGINT         COMMENT '价格点ID（源表主键 id）',
    price_no              STRING         COMMENT '价格点编号，由流水号生成器生成',
    sku_id                BIGINT         COMMENT 'SKU ID',
    price_channel_code    STRING         COMMENT '价格渠道: RETAIL-零售价，COUNTER-窗口，OTA_MEITUAN-美团等, NULL=L0默认价',
    price_date            STRING         COMMENT '单日精确匹配(节假日特殊价), NULL=不按单日',
    price_start_date      STRING         COMMENT '日期区间起始, NULL=不按区间',
    price_end_date        STRING         COMMENT '日期区间终止, NULL=不按区间',
    weekday_mask_code     INT            COMMENT '星期掩码 bit0=周一..bit6=周日(工作日=31/周末=96), NULL=不限',
    ext_dim_desc          STRING         COMMENT '动态维度: {"roomType":"大床房","seatLevel":"A区"}',
    priority_no           INT            COMMENT '优先级（数值大优先）',
    effective_start_time  STRING         COMMENT '生效起始',
    effective_end_time    STRING         COMMENT '生效终止',
    tenant_id             BIGINT         COMMENT '租户ID（分库维度）',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    change_type           STRING         COMMENT '变更类型：I-新增，U-修改，D-删除',
    before_price_amt      DECIMAL(18,2)  COMMENT '变更前价格（元）；新增时为空',
    after_price_amt       DECIMAL(18,2)  COMMENT '变更后价格（元）；删除时为空',
    change_time           STRING         COMMENT '变更时间',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '价格点变更明细（1行=1次价格点新增/修改/删除）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_prd_sku_price_calendar_df  SKU每日生效价日历 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_prd_sku_price_calendar_df (
    sku_id              BIGINT         COMMENT 'SKU ID',
    price_date          STRING         COMMENT '价格日期（日历展开，未来 N 天），格式 yyyy-MM-dd',
    price_channel_code  STRING         COMMENT '价格渠道编码',
    ext_dim_desc        STRING         COMMENT '扩展维度组合（JSON 字符串，如场次/座位等级）',
    hit_price_no        STRING         COMMENT '命中的价格点编号',
    hit_priority_no     INT            COMMENT '命中优先级：10-单日价，5-区间价，3-星期价，0-默认价',
    list_price_amt      DECIMAL(18,2)  COMMENT '当日生效挂牌价（元）',
    pricing_rule_no     STRING         COMMENT '叠加的定价规则编号；无规则为空',
    rule_price_type     INT            COMMENT '是否 L2 规则价：0-否，1-是',
    final_price_amt     DECIMAL(18,2)  COMMENT '规则计算后成交参考价（元）',
    tenant_id           BIGINT         COMMENT '租户ID（分库维度）',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SKU每日生效价日历（1行=1个SKU×1个日期×1个渠道×1组扩展维度）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_inv_pool_change_di  库存池变动明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_inv_pool_change_di (
    pool_id               BIGINT         COMMENT '库存池ID（源表主键 id）',
    pool_no               STRING         COMMENT '库存池编号，由流水号生成器生成',
    sku_id                BIGINT         COMMENT 'SKU ID',
    pool_type             STRING         COMMENT '池类型：COUNTING-可数池，UNIT-可标识池',
    pool_status           STRING         COMMENT '池状态：ON_SALE-在售，STOP_SALE-停售，EXPIRED-已过期',
    tenant_id             BIGINT         COMMENT '租户ID（分库维度）',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    change_type           STRING         COMMENT '变动类型：PRE_DEDUCT-预扣，CONFIRM-确认，ROLLBACK-回滚，ADJUST-调整',
    order_no              STRING         COMMENT '引起变动的子单号；人工调整为空',
    play_date             STRING         COMMENT '库存日期',
    room_type_code        STRING         COMMENT '房型编码（酒店）',
    show_time             STRING         COMMENT '场次时间（演出）',
    before_total_qty      BIGINT         COMMENT '变动前总库存',
    after_total_qty       BIGINT         COMMENT '变动后总库存',
    total_change_qty      BIGINT         COMMENT '总库存变化量',
    available_change_qty  BIGINT         COMMENT '可售库存变化量',
    frozen_change_qty     BIGINT         COMMENT '冻结库存变化量',
    change_time           STRING         COMMENT '变动时间',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '库存池变动明细（1行=1次库存池数量变化）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_inv_unit_change_di  座位/房间锁定释放明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_inv_unit_change_di (
    unit_id          BIGINT         COMMENT 'UNIT池资源（座位/房间/舱位）ID（源表主键 id）',
    unit_no          STRING         COMMENT '资源个体编号（座位号/房号/舱位号）',
    pool_no          STRING         COMMENT '归属库存池编号',
    unit_status      STRING         COMMENT '状态：AVAILABLE-可用，FROZEN-冻结中，OCCUPIED-已占用',
    order_no         STRING         COMMENT '锁定子单号（FROZEN-冻结中，OCCUPIED-已占用时）',
    tenant_id        BIGINT         COMMENT '租户ID（分库维度）',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    sku_id           BIGINT         COMMENT 'SKU ID',
    seat_level_code  STRING         COMMENT '座位等级',
    room_type_code   STRING         COMMENT '房型编码',
    before_status    STRING         COMMENT '变更前状态：AVAILABLE-可用，FROZEN-冻结中，OCCUPIED-已占用',
    after_status     STRING         COMMENT '变更后状态：AVAILABLE-可用，FROZEN-冻结中，OCCUPIED-已占用',
    unit_change_qty  BIGINT         COMMENT '变更次数，固定为 1',
    change_time      STRING         COMMENT '变更时间',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '座位/房间锁定释放明细（1行=1次UNIT资源状态变化）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_inv_pool_snapshot_df  库存池日快照 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_inv_pool_snapshot_df (
    pool_id         BIGINT         COMMENT '库存池ID（源表主键 id）',
    pool_no         STRING         COMMENT '库存池编号，由流水号生成器生成',
    sku_id          BIGINT         COMMENT 'SKU ID',
    pool_type       STRING         COMMENT '池类型：COUNTING-可数池，UNIT-可标识池',
    total_qty       BIGINT         COMMENT '总量（COUNTING-可数池池）',
    available_qty   BIGINT         COMMENT '可用量（实时）',
    frozen_qty      BIGINT         COMMENT '预扣冻结量',
    pool_status     STRING         COMMENT '池状态：ON_SALE-在售，STOP_SALE-停售，EXPIRED-已过期',
    tenant_id       BIGINT         COMMENT '租户ID（分库维度）',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    play_date       STRING         COMMENT '库存日期',
    room_type_code  STRING         COMMENT '房型编码',
    show_time       STRING         COMMENT '场次时间',
    shared_pool_no  STRING         COMMENT '关联的共享配额池编号；无共享为空',
    sold_qty        BIGINT         COMMENT '已售库存 = 总库存 - 可售 - 冻结',
    sellout_type    INT            COMMENT '是否售罄：0-否，1-是',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '库存池日快照（1行=1个库存池×1日）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_cus_customer_register_di  游客注册明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_cus_customer_register_di (
    customer_id           BIGINT         COMMENT 'C端游客主账号ID（源表主键 id）',
    customer_no           STRING         COMMENT '客户编号，格式CUS+yyyyMMdd+6位随机',
    customer_type         STRING         COMMENT '账号类型：REAL-真人注册账号，TENANT_DEFAULT-业务租户代下单占位买家；PLATFORM-平台 租户下不设占位买家，故无 PLATFORM_DEFAULT 值',
    gender_type           STRING         COMMENT '性别：MALE-男，FEMALE-女，UNKNOWN-未知',
    auth_status           STRING         COMMENT '认证状态：UNAUTHENTICATED-未认证，PHONE_VERIFIED-手机已验证，PERSON_CERTIFIED-已实名认证',
    customer_status       STRING         COMMENT '状态：ACTIVE-有效，BANNED-已封禁，CANCELLED-已取消',
    register_source_code  STRING         COMMENT '注册来源渠道编码（channel_code）',
    register_tenant_id    BIGINT         COMMENT '所属租户ID（self-tenant 隔离：该 customer 仅归属此租户，不跨租户复用；unionid/alipay 唯一键均带此列，phone 非唯一；证件号收敛改走 t_customer_credential 唯一键）',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    register_channel_id   BIGINT         COMMENT '注册渠道ID',
    age_band_code         STRING         COMMENT '注册时年龄段：0_17-未成年，18_25-18~25岁，26_35-26~35岁，36_45-36~45岁，46_60-46~60岁，60_PLUS-60岁以上，UNKNOWN-未知',
    register_time         STRING         COMMENT '注册时间',
    register_qty          BIGINT         COMMENT '注册人数，固定为 1；剔除 TENANT_DEFAULT-租户代下单占位买家 占位买家',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '游客注册明细（1行=1个新注册游客）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_cus_identity_bind_di  渠道身份绑定明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_cus_identity_bind_di (
    customer_identity_id  BIGINT         COMMENT '游客多渠道身份ID（源表主键 id）',
    customer_id           BIGINT         COMMENT '归属 Customer ID',
    identity_type         STRING         COMMENT '标识类型：WECHAT_OPENID-微信 openid，DOUYIN_OPENID-抖音 openid，OTA_UID-OTA 用户ID，ALIPAY_OPENID-支付宝 openid，OTHER-其他',
    identity_code         STRING         COMMENT '标识值（openid/OTA用户uid等）（脱敏）',
    bind_channel_id       BIGINT         COMMENT '产生该标识的接入端ID（指向 t_channel）',
    bind_tenant_id        BIGINT         COMMENT '产生该标识的租户ID（小程序openid必带；平台端=内部租户id,即 tenant_type=INTERNAL-内部运营主体 的租户数值 id）',
    identity_status       STRING         COMMENT '状态：ACTIVE-有效，REVOKED-已撤销',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    bind_time             STRING         COMMENT '绑定时间',
    bind_qty              BIGINT         COMMENT '绑定次数，固定为 1',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '渠道身份绑定明细（1行=1条身份绑定）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_cus_credential_register_di  个人凭证注册明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_cus_credential_register_di (
    customer_credential_id  BIGINT         COMMENT '游客个人凭证ID（源表主键 id）',
    credential_no           STRING         COMMENT '凭证编号，格式PC+yyyyMMdd+6位随机',
    customer_id             BIGINT         COMMENT '归属 Customer ID',
    register_tenant_id      BIGINT         COMMENT '注册租户ID（冗余自t_customer.register_tenant_id,用于证件号收敛唯一键）',
    credential_type         STRING         COMMENT '凭证类型: ID_CARD-身份证，PASSPORT-护照，DRIVER_LICENSE-驾驶证，FACE-人脸/...(支持国际证件扩展)',
    create_time             STRING         COMMENT '创建时间',
    update_time             STRING         COMMENT '更新时间',
    register_time           STRING         COMMENT '凭证注册时间',
    register_qty            BIGINT         COMMENT '注册凭证数，固定为 1',
    etl_time                STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '个人凭证注册明细（1行=1条个人凭证）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_opr_risk_event_di  风控事件明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_risk_event_di (
    risk_event_id         BIGINT         COMMENT '风控事件ID（源表主键 id）',
    event_no              STRING         COMMENT '事件编号，格式RE+yyyyMMdd+6位随机',
    event_type            STRING         COMMENT '类型：RULE_HIT-规则命中，MANUAL_BAN-人工封禁，MANUAL_UNBAN-人工解封，ABNORMAL_OP_DETECTED-检测到异常操作',
    subject_id            BIGINT         COMMENT '主体ID（用户/商户）',
    dimension_value_desc  STRING         COMMENT '触发维度值集合',
    rule_id               BIGINT         COMMENT '关联规则ID',
    action_type           STRING         COMMENT '执行动作：BLOCK-拦截，WARN-预警，FREEZE-冻结',
    detail_desc           STRING         COMMENT '详细描述',
    audit_log_id          BIGINT         COMMENT '关联审计日志ID',
    tenant_id             BIGINT         COMMENT '租户ID',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    rule_type             STRING         COMMENT '规则类型：BLACKLIST-黑名单，PURCHASE_LIMIT-购买限制，GEO_FENCE-地理围栏，ABNORMAL_OP-异常操作，DEFAULT_BREAK-爽约',
    dimension_type        STRING         COMMENT '规则维度：USER_ID-用户ID，ID_CARD-身份证，PHONE-手机号，IP，DEVICE_ID-设备ID',
    event_time            STRING         COMMENT '事件发生时间',
    event_qty             BIGINT         COMMENT '事件数，固定为 1',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '风控事件明细（1行=1个风控事件）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_opr_blacklist_log_di  黑名单变更明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_blacklist_log_di (
    blacklist_id             BIGINT         COMMENT '黑名单ID（源表主键 id）',
    blacklist_no             STRING         COMMENT '黑名单记录编号',
    dimension_type           STRING         COMMENT '维度：USER_ID-用户ID，ID_CARD-身份证，PHONE-手机号，IP',
    dimension_value_desc     STRING         COMMENT '维度值（身份证号/IP等）（脱敏）',
    reason_desc              STRING         COMMENT '封禁原因',
    scope_type               STRING         COMMENT '范围：GLOBAL-全局，TENANT-租户',
    banned_action_list_desc  STRING         COMMENT '封禁动作组合：[PLACE_ORDER-下单，WITHDRAW-提现，VERIFY-核销，PUBLISH-发品，LOGIN-登录级]',
    expire_time              STRING         COMMENT '过期时间（null=永久）',
    blacklist_status         STRING         COMMENT '状态：ACTIVE-有效，EXPIRED-已过期，REVOKED-已撤销',
    created_by_type          STRING         COMMENT '创建方：RISK_RULE-风控规则，MANUAL-人工',
    rule_id                  BIGINT         COMMENT '关联规则ID（规则触发时）',
    tenant_id                BIGINT         COMMENT '租户ID（scope=TENANT-租户时）',
    create_time              STRING         COMMENT '创建时间',
    update_time              STRING         COMMENT '更新时间',
    change_type              STRING         COMMENT '变更类型：ADD-新增，EXPIRE-到期失效，REVOKE-撤销',
    change_time              STRING         COMMENT '变更时间',
    change_qty               BIGINT         COMMENT '变更次数，固定为 1',
    etl_time                 STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '黑名单变更明细（1行=1次黑名单新增/失效/撤销）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_opr_account_ban_di  账号封禁明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_account_ban_di (
    ban_id                   BIGINT         COMMENT '账号封禁ID（源表主键 id）',
    ban_no                   STRING         COMMENT '封禁编号',
    subject_id               BIGINT         COMMENT '被封禁主体（用户/商户）',
    ban_type                 STRING         COMMENT '封禁类型：LOGIN-登录级，BUSINESS-业务操作级',
    banned_action_list_desc  STRING         COMMENT '封禁动作组合：[PLACE_ORDER-下单，WITHDRAW-提现，VERIFY-核销，PUBLISH-发品，LOGIN-登录级]',
    reason_desc              STRING         COMMENT '封禁原因',
    ban_source_type          STRING         COMMENT '来源：RISK_RULE-风控规则，MANUAL-人工',
    rule_id                  BIGINT         COMMENT '关联规则ID（规则自动触发时）',
    expire_time              STRING         COMMENT '过期时间',
    ban_status               STRING         COMMENT '状态：ACTIVE-有效，EXPIRED-已过期，REVOKED-已撤销',
    revoke_operator_name     STRING         COMMENT '解封人',
    revoke_time              STRING         COMMENT '解封时间',
    tenant_id                BIGINT         COMMENT '租户ID',
    create_time              STRING         COMMENT '创建时间',
    update_time              STRING         COMMENT '更新时间',
    ban_time                 STRING         COMMENT '封禁时间',
    ban_hour_qty             DECIMAL(18,2)  COMMENT '封禁时长（小时）= 解封或到期时间 - 封禁时间',
    ban_qty                  BIGINT         COMMENT '封禁次数，固定为 1',
    etl_time                 STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '账号封禁明细（1行=1条封禁）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_opr_approval_di  审批实例明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_approval_di (
    instance_id          BIGINT         COMMENT '审批实例ID（源表主键 id）',
    instance_no          STRING         COMMENT '审批实例号，格式AI-AI 接入+yyyyMMdd+6位随机',
    flow_id              BIGINT         COMMENT '审批流ID（启动时绑定的具体审批流模板ID）',
    flow_code            STRING         COMMENT '审批流标识码（冗余，便于按code查询）',
    business_no          STRING         COMMENT '关联业务号（退款单号/提现单号等）',
    applicant_id         BIGINT         COMMENT '申请人ID',
    applicant_name       STRING         COMMENT '申请人姓名（快照，避免跨库查identity）',
    current_node_name    STRING         COMMENT '当前审批节点名称',
    timeout_time         STRING         COMMENT '当前节点审批截止时间（XXL-JOB扫描超时处理）',
    instance_status      STRING         COMMENT '状态：PENDING-待处理，APPROVED-已通过，REJECTED-已拒绝，CANCELLED-已取消',
    tenant_id            BIGINT         COMMENT '租户ID',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    flow_name            STRING         COMMENT '审批流名称',
    apply_time           STRING         COMMENT '发起时间',
    finish_time          STRING         COMMENT '审批结束时间；进行中为空',
    approval_minute_qty  BIGINT         COMMENT '审批耗时（分钟）',
    timeout_type         INT            COMMENT '是否超时：0-否，1-是',
    approval_qty         BIGINT         COMMENT '审批实例数，固定为 1',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '审批实例明细（1行=1个审批实例）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_opr_complaint_di  投诉工单明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_complaint_di (
    complaint_id         BIGINT         COMMENT '投诉工单ID（源表主键 id）',
    complaint_no         STRING         COMMENT '工单编号，格式CMP+yyyyMMdd+6位随机',
    complainant_type     STRING         COMMENT '投诉方：VISITOR-游客，MERCHANT-商户',
    complainant_id       BIGINT         COMMENT '投诉方ID',
    order_group_no       STRING         COMMENT '关联订单号（游客投诉时）',
    complaint_type       STRING         COMMENT '类型：ORDER_ISSUE-订单问题，SERVICE_ISSUE-服务问题，BUG-系统缺陷，OTHER-其他',
    handler_id           BIGINT         COMMENT '处理人ID',
    sla_deadline_time    STRING         COMMENT 'SLA截止时间',
    complaint_status     STRING         COMMENT '状态：PENDING-待处理，ASSIGNED-已分派，PROCESSING-处理中，RESOLVED-已解决，CLOSED-已关闭',
    tenant_id            BIGINT         COMMENT '租户ID',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    seller_tenant_id     BIGINT         COMMENT '被投诉的卖家租户ID',
    create_time_hour_no  INT            COMMENT '投诉提交小时：0~23',
    resolve_time         STRING         COMMENT '处理完成时间；未完成为空',
    resolve_hour_qty     DECIMAL(18,2)  COMMENT '处理时长（小时）',
    sla_timeout_type     INT            COMMENT '是否超 SLA：0-否，1-是',
    complaint_qty        BIGINT         COMMENT '投诉数，固定为 1',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '投诉工单明细（1行=1个投诉工单）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_opr_notify_di  通知发送明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_notify_di (
    notify_id            BIGINT         COMMENT '通知记录ID（源表主键 id）',
    notify_no            STRING         COMMENT '通知记录号，格式NR+yyyyMMdd+6位随机',
    template_id          BIGINT         COMMENT '模板ID',
    recipient_id         BIGINT         COMMENT '接收人ID',
    recipient_type       STRING         COMMENT '接收人类型：CUSTOMER-C端游客，TENANT_STAFF-B端员工，SYSTEM-系统',
    notify_channel_type  STRING         COMMENT '实际发送渠道：SMS-短信，MINI_PROGRAM_MSG-小程序消息，EMAIL-邮件，WEBHOOK-Webhook，IN_APP-站内信',
    related_business_no  STRING         COMMENT '关联业务号',
    send_status          STRING         COMMENT '状态：PENDING-待处理，SUCCESS-成功，FAILED-失败',
    send_time            STRING         COMMENT '发送时间',
    fail_reason_desc     STRING         COMMENT '失败原因',
    tenant_id            BIGINT         COMMENT '租户ID',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    template_code        STRING         COMMENT '模板编码',
    send_success_type    INT            COMMENT '是否发送成功：0-否，1-是',
    notify_qty           BIGINT         COMMENT '发送次数，固定为 1',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '通知发送明细（1行=1次通知发送）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_opr_audit_log_di  审计操作明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_audit_log_di (
    audit_log_id       BIGINT         COMMENT '审计日志ID（源表主键 id）',
    log_no             STRING         COMMENT '日志编号，格式AL+yyyyMMdd+6位随机',
    operator_id        BIGINT         COMMENT '操作人ID',
    operator_type      STRING         COMMENT '操作人类型：CUSTOMER-C端游客，TENANT_STAFF-B端员工，SYSTEM-系统，ANONYMOUS-匿名',
    action_type        STRING         COMMENT '操作动作（如PLACE_ORDER-下单，REFUND-退款，WITHDRAW-提现，MODIFY_BANK_CARD-修改银行卡）',
    resource_type      STRING         COMMENT '资源类型：ORDER-订单，PRODUCT-商品，ACCOUNT-账户，DEVICE-设备',
    resource_id        BIGINT         COMMENT '资源ID',
    client_ip_code     STRING         COMMENT 'IP地址',
    tenant_id          BIGINT         COMMENT '租户ID',
    log_scope_type     STRING         COMMENT '日志范围：PLATFORM-平台，MERCHANT-商户',
    create_time        STRING         COMMENT '创建时间',
    update_time        STRING         COMMENT '更新时间',
    action_time        STRING         COMMENT '操作时间',
    action_hour_no     INT            COMMENT '操作小时：0~23',
    night_action_type  INT            COMMENT '是否凌晨操作：0-否，1-是（0~6 点）',
    action_qty         BIGINT         COMMENT '操作次数，固定为 1',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '审计操作明细（1行=1条操作日志）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_opr_device_status_log_di  设备状态变更明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_device_status_log_di (
    device_id            BIGINT         COMMENT '设备ID',
    device_no            STRING         COMMENT '设备编号',
    tenant_id            BIGINT         COMMENT '租户ID',
    device_type          STRING         COMMENT '设备类型：GATE-闸机，POS-POS 机，HANDHELD-手持机，SELF_SERVICE-自助机，KIOSK-自助终端，FACE_RECOGNITION-人脸识别机',
    device_group_id      BIGINT         COMMENT '设备分组ID',
    poi_id               BIGINT         COMMENT '所属 POI ID',
    before_status        STRING         COMMENT '变更前状态：ACTIVE-有效，OFFLINE-线下或离线，MAINTENANCE-维护中，INACTIVE-停用',
    after_status         STRING         COMMENT '变更后状态：ACTIVE-有效，OFFLINE-线下或离线，MAINTENANCE-维护中，INACTIVE-停用',
    last_heartbeat_time  STRING         COMMENT '最后心跳时间',
    change_time          STRING         COMMENT '状态变更时间',
    status_minute_qty    BIGINT         COMMENT '前一状态持续时长（分钟）',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '设备状态变更明细（1行=1次设备状态/心跳变化）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_opr_package_subscription_di  套餐订购明细 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_package_subscription_di (
    subscription_id      BIGINT         COMMENT '套餐订购ID（源表主键 id）',
    subscription_no      STRING         COMMENT '订购编号，格式SUB+yyyyMMdd+6位随机',
    tenant_id            BIGINT         COMMENT '租户ID',
    package_id           BIGINT         COMMENT '套餐ID',
    subscription_type    STRING         COMMENT '类型：NEW-新购，RENEW-续费，UPGRADE-升级',
    start_time           STRING         COMMENT '生效时间',
    expire_time          STRING         COMMENT '到期时间',
    subscription_status  STRING         COMMENT '状态：ACTIVE-有效，EXPIRED-已过期，CANCELLED-已取消',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    package_name         STRING         COMMENT '套餐名称',
    package_amt          DECIMAL(18,2)  COMMENT '套餐价格（元）',
    duration_day_qty     BIGINT         COMMENT '订购时长（天）',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '套餐订购明细（1行=1笔套餐订购）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dwd.dwd_fin_account_balance_df  账户余额日快照 ==========
CREATE TABLE IF NOT EXISTS dwd.dwd_fin_account_balance_df (
    account_id             BIGINT         COMMENT '统一账户ID（源表主键 id）',
    account_no             STRING         COMMENT '账户编号，由流水号生成器生成',
    subject_id             BIGINT         COMMENT '主体ID（商户/分销商/平台）',
    account_type           STRING         COMMENT '账户类型：MERCHANT-商户，DISTRIBUTOR-分销商，PLATFORM-平台',
    available_balance_amt  DECIMAL(18,2)  COMMENT '可用余额（元）；源字段单位为分，入仓 ÷100',
    frozen_balance_amt     DECIMAL(18,2)  COMMENT '冻结余额（元）；源字段单位为分，入仓 ÷100',
    tenant_id              BIGINT         COMMENT '租户ID（分库维度）',
    create_time            STRING         COMMENT '创建时间',
    update_time            STRING         COMMENT '更新时间',
    total_balance_amt      DECIMAL(18,2)  COMMENT '账户总余额（元）= 可用余额 + 冻结余额',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '账户余额日快照（1行=1个账户×1日）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

