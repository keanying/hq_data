-- PFT 2.0 数仓 DDL：ODS（81 张表）
-- 由 generator/make_all.py 生成，请勿手改

-- ========== ods.ods_ord_order_group_di  聚合单 ==========
CREATE TABLE IF NOT EXISTS ods.ods_ord_order_group_di (
    id                  BIGINT         COMMENT '主键ID',
    order_group_no      STRING         COMMENT '聚合单号，支付幂等键来源，由流水号生成器生成',
    seller_tenant_id    BIGINT         COMMENT '卖家租户ID（商品归属租户，聚合单层冗余，子单同值）',
    channel_id          BIGINT         COMMENT '入口端ID（指向 t_channel.id：MP_TENANT_HOSTED-租户托管小程序，MP_PLATFORM-平台小程序，PC_TENANT-租户后台，PC_PLATFORM-平台后台，OFFLINE-线下或离线，API_XXX）',
    app_id              STRING         COMMENT '对接端标识（指向t_channel.app_id，标识订单组创建来源端；空串=未指定，历史数据兼容）',
    app_ref             STRING         COMMENT '对接端自定义子标识（app_id对应）：小程序=tenant_mp_config_id字符串；API-API 接口=子渠道号；其他=空串',
    operator_type       STRING         COMMENT '操作人类型：CUSTOMER-C端会员，TENANT_STAFF-B端员工含平台员工',
    operator_id         BIGINT         COMMENT '操作人ID（多态：customer_id 或 tenant_staff_id）',
    operator_tenant_id  BIGINT         COMMENT '操作人所属租户ID（=会话tenant_context_id；C端时=渠道端所属租户或=seller_tenant_id）',
    buyer_type          STRING         COMMENT '付款方类型：CUSTOMER-会员或租户默认散客占位，ANONYMOUS-线下现金无主体',
    buyer_id            BIGINT         COMMENT '付款方ID（多态；ANONYMOUS-匿名时=0）',
    buyer_customer_id   BIGINT         COMMENT 'C端筛选冗余：buyer_type=CUSTOMER-C端游客时=buyer_id，否则0（带索引报表用）',
    contact_name        STRING         COMMENT '联系人姓名',
    contact_phone       STRING         COMMENT '联系人手机（脱敏）',
    contact_id_type     STRING         COMMENT '联系人证件类型：ID_CARD-身份证，PASSPORT-护照等',
    contact_id_number   STRING         COMMENT '联系人证件号（脱敏）',
    total_amount        BIGINT         COMMENT '总金额（分）',
    currency            STRING         COMMENT '币种（=商户配置币种；MVP不做换算）',
    pay_status          STRING         COMMENT '支付状态：UNPAID-未支付，PARTIAL_PAID-部分支付，PAID-已支付',
    pay_timeout_at      STRING         COMMENT '支付超时截止时间（SKU票属性PAY_TIMEOUT-支付超时驱动，毫秒精度）',
    tenant_id           BIGINT         COMMENT '租户ID（分库维度，=seller_tenant_id）',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    create_by           STRING         COMMENT '创建人',
    update_by           STRING         COMMENT '更新人',
    deleted             INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type      STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time         STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '聚合单（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_ord_order_di  子单 ==========
CREATE TABLE IF NOT EXISTS ods.ods_ord_order_di (
    id                BIGINT         COMMENT '主键ID',
    order_no          STRING         COMMENT '子单号，由流水号生成器生成',
    order_group_no    STRING         COMMENT '归属聚合单号',
    parent_order_no   STRING         COMMENT '套票子单指向主单号，非套票=空串',
    combo_flag        INT            COMMENT '是否套票主单：1=套票主单，0=普通子单或套票子项',
    seller_tenant_id  BIGINT         COMMENT '卖家商户ID',
    sku_id            BIGINT         COMMENT 'SKU ID',
    sku_name          STRING         COMMENT 'SKU名称（下单时快照）',
    sku_version       INT            COMMENT '下单时SKU版本号（查订单商品属性时按sku_id+sku_version还原）',
    quantity          INT            COMMENT '购买数量',
    unit_price        BIGINT         COMMENT '单价（分）；套票主单=套餐总价，套票子单=分摊价',
    sale_dims         STRING         COMMENT '用户选择的售卖维度快照：{date:"2026-07-05", timeSlot:"10:00-11:00", seatZone:"VIP"}',
    order_status      STRING         COMMENT '状态：PENDING_PAY-待支付，PAID-已支付，PARTIALLY_VERIFIED-部分核销，FULLY_VERIFIED-已全部核销，REFUNDED-已退款，CANCELLED-已取消',
    tenant_id         BIGINT         COMMENT '租户ID（分库维度）',
    create_time       STRING         COMMENT '创建时间',
    update_time       STRING         COMMENT '更新时间',
    create_by         STRING         COMMENT '创建人',
    update_by         STRING         COMMENT '更新人',
    deleted           INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type    STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time       STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '子单（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_ord_ticket_di  票 ==========
CREATE TABLE IF NOT EXISTS ods.ods_ord_ticket_di (
    id              BIGINT         COMMENT '主键ID',
    ticket_no       STRING         COMMENT '票号，格式TKT+yyyyMMdd+6位随机',
    order_no        STRING         COMMENT '归属子单号',
    ticket_status   STRING         COMMENT '票状态：AVAILABLE-可用，PARTIALLY_USED-部分使用，USED-已使用，EXPIRED-已过期，REFUNDED-已退款，CANCELLED-已取消',
    valid_start     STRING         COMMENT '有效期起始（出票时确定或首次核销时延迟确定，毫秒精度）',
    valid_end       STRING         COMMENT '有效期终止（毫秒精度）',
    pass_policy     STRING         COMMENT '放行策略（从SKU继承）：SINGLE-分批，BATCH-整批',
    metadata        STRING         COMMENT '业态扩展字段（seatInfo/cabinInfo等）',
    tenant_id       BIGINT         COMMENT '租户ID（分库维度）',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type  STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time     STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '票（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_ord_ticket_person_di  票上的人 ==========
CREATE TABLE IF NOT EXISTS ods.ods_ord_ticket_person_di (
    id                  BIGINT         COMMENT '主键ID',
    ticket_no           STRING         COMMENT '归属票号',
    person_id           STRING         COMMENT '人ID（票内唯一）',
    global_customer_id  BIGINT         COMMENT '关联 Customer 全局ID（首次登录才建 Customer，未登录=0）',
    name                STRING         COMMENT '姓名',
    id_type             STRING         COMMENT '证件类型：ID_CARD-身份证，PASSPORT-护照等',
    id_number           STRING         COMMENT '证件号（脱敏）',
    phone               STRING         COMMENT '手机号（脱敏）',
    is_primary          INT            COMMENT '是否主游客：0否/1是',
    tenant_id           BIGINT         COMMENT '租户ID（分库维度）',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    create_by           STRING         COMMENT '创建人',
    update_by           STRING         COMMENT '更新人',
    deleted             INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type      STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time         STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '票上的人（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_ord_entitlement_di  权益 ==========
CREATE TABLE IF NOT EXISTS ods.ods_ord_entitlement_di (
    id                  BIGINT         COMMENT '主键ID',
    entitlement_no      STRING         COMMENT '权益号，由流水号生成器生成',
    ticket_no           STRING         COMMENT '归属票号',
    entitlement_type    STRING         COMMENT '权益类型：FIXED-固定，SELECTABLE-选择型，COUNTED-计次型，TIMED-计时型，UNLIMITED-不限次型，QUOTA-额度型',
    entitlement_name    STRING         COMMENT '权益名称（如"成人入园""住宿1晚"）',
    status              STRING         COMMENT '权益状态：ACTIVE-有效，USED-已使用，EXPIRED-已过期，REFUNDED-已退款',
    used_count          INT            COMMENT '已用次数（所有类型共有）',
    entitlement_detail  STRING         COMMENT '权益详情（类型特有参数，JSON自描述，新增类型只需扩展schema不加DDL字段。示例：COUNTED-计次型→{"maxCount":5}；SELECTABLE-选择型→{"maxCount":2,"candidateRefs":["ENT-001"]}；TIMED-计时型→{"durationMinutes":480}；QUOTA-额度型→{"quotaAmount":50000}；FIXED-固定，UNLIMITED-不限次型→{}）',
    valid_start         STRING         COMMENT '权益有效期起始（可收窄于票有效期，毫秒精度）',
    valid_end           STRING         COMMENT '权益有效期终止（毫秒精度）',
    tenant_id           BIGINT         COMMENT '租户ID（分库维度）',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    create_by           STRING         COMMENT '创建人',
    update_by           STRING         COMMENT '更新人',
    deleted             INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type      STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time         STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '权益（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_ord_person_entitlement_binding_di  人-权益绑定 ==========
CREATE TABLE IF NOT EXISTS ods.ods_ord_person_entitlement_binding_di (
    id              BIGINT         COMMENT '主键ID',
    ticket_no       STRING         COMMENT '归属票号',
    person_id       STRING         COMMENT '人ID（空串=开放争抢，OPEN-开放争抢模式）',
    entitlement_no  STRING         COMMENT '权益号',
    binding_type    STRING         COMMENT '绑定类型：EXCLUSIVE-专属绑定，SHARED-共享绑定，OPEN-开放争抢',
    tenant_id       BIGINT         COMMENT '租户ID（分库维度）',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type  STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time     STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '人-权益绑定（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_ord_refund_order_di  退款单 ==========
CREATE TABLE IF NOT EXISTS ods.ods_ord_refund_order_di (
    id              BIGINT         COMMENT '主键ID',
    refund_no       STRING         COMMENT '退款单号，格式REF+yyyyMMdd+6位随机',
    order_group_no  STRING         COMMENT '归属聚合单号',
    refund_type     STRING         COMMENT '退款类型：ORDER_REFUND-订单退款，COMPENSATION-售后补偿，PARTIAL_REFUND-部分退款',
    refund_reason   STRING         COMMENT '退款原因',
    refund_amount   BIGINT         COMMENT '退款总金额（分）',
    refund_status   STRING         COMMENT '状态：PENDING-待处理，APPROVED-已通过，PROCESSING-处理中，COMPLETED-已完成，REJECTED-已拒绝',
    refund_items    STRING         COMMENT '退款明细：[{orderNo, ticketNos[], amount}]',
    initiator_type  STRING         COMMENT '发起方：VISITOR-游客，MERCHANT-商户，PLATFORM-平台，SYSTEM-系统，OTA',
    initiator_id    BIGINT         COMMENT '发起方ID',
    approver_id     BIGINT         COMMENT '审批人ID',
    approve_time    STRING         COMMENT '审批时间',
    tenant_id       BIGINT         COMMENT '租户ID（分库维度）',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type  STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time     STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '退款单（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_ord_refund_detail_di  退款明细（按支付记录） ==========
CREATE TABLE IF NOT EXISTS ods.ods_ord_refund_detail_di (
    id                     BIGINT         COMMENT '主键ID',
    refund_detail_no       STRING         COMMENT '退款明细号，由流水号生成器生成',
    refund_no              STRING         COMMENT '归属退款单号',
    payment_no             STRING         COMMENT '关联支付记录号（退款来源）',
    refund_amount          BIGINT         COMMENT '本次退款金额（分，来自该支付记录的退款部分）',
    refund_channel         STRING         COMMENT '退款渠道：WECHAT-微信，ALIPAY-支付宝，BALANCE-余额，CREDIT-授信等（与原支付渠道对应）',
    refund_transaction_no  STRING         COMMENT '支付中心返回的退款流水号（用于后续跟踪对账）',
    refund_detail_status   STRING         COMMENT '明细状态：PENDING-待处理，PROCESSING-处理中，SUCCESS-成功，FAILED-失败',
    tenant_id              BIGINT         COMMENT '租户ID（分库维度）',
    create_time            STRING         COMMENT '创建时间',
    update_time            STRING         COMMENT '更新时间',
    create_by              STRING         COMMENT '创建人',
    update_by              STRING         COMMENT '更新人',
    deleted                INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type         STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time            STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '退款明细（按支付记录）（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_ord_ticket_credential_di  票凭证 ==========
CREATE TABLE IF NOT EXISTS ods.ods_ord_ticket_credential_di (
    id               BIGINT         COMMENT '主键ID',
    credential_no    STRING         COMMENT '凭证号，由流水号生成器生成',
    ticket_no        STRING         COMMENT '归属票号',
    credential_type  STRING         COMMENT '凭证类型：QR_CODE-二维码，BAR_CODE-条形码，ID_CARD-身份证，FACE-人脸',
    code_value       STRING         COMMENT '码值（码池分配）（脱敏）',
    code_pool_id     BIGINT         COMMENT '归属码池ID',
    status           STRING         COMMENT '状态：ACTIVE-有效，EXPIRED-已过期，REVOKED-已撤销',
    tenant_id        BIGINT         COMMENT '租户ID（分库维度）',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type   STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time      STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '票凭证（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_ord_verify_record_di  核销记录 ==========
CREATE TABLE IF NOT EXISTS ods.ods_ord_verify_record_di (
    id                 BIGINT         COMMENT '主键ID',
    verify_no          STRING         COMMENT '核销记录号，格式VF+yyyyMMdd+6位随机',
    ticket_no          STRING         COMMENT '核销票号',
    entitlement_no     STRING         COMMENT '核销权益号',
    verify_point_id    BIGINT         COMMENT '核销点ID',
    operator_id        BIGINT         COMMENT '操作人ID',
    device_id          BIGINT         COMMENT '核销设备ID',
    verify_type        STRING         COMMENT '核销类型：ONLINE-在线，OFFLINE-线下或离线',
    offline_timestamp  BIGINT         COMMENT '离线时序戳（离线核销时设备时间）',
    verify_result      STRING         COMMENT '结果：SUCCESS-成功，FAILED-失败，DUPLICATE-重复',
    tenant_id          BIGINT         COMMENT '租户ID（分库维度）',
    create_time        STRING         COMMENT '创建时间（在线=服务器时间，离线=回连时间）',
    update_time        STRING         COMMENT '更新时间',
    create_by          STRING         COMMENT '创建人',
    update_by          STRING         COMMENT '更新人',
    deleted            INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type     STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time        STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '核销记录（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_fin_payment_record_di  支付记录 ==========
CREATE TABLE IF NOT EXISTS ods.ods_fin_payment_record_di (
    id                   BIGINT         COMMENT '主键ID',
    payment_no           STRING         COMMENT '支付流水号，由流水号生成器生成',
    batch_no             STRING         COMMENT '批量支付单号(同批共享),单条时空',
    item_no              STRING         COMMENT '批内项号(批内唯一,标识本条在批中的位置)',
    depend_on_item       STRING         COMMENT '依赖项号(必须在依赖项成功后执行,空=无依赖)',
    order_group_no       STRING         COMMENT '归属聚合单号',
    pay_direction        STRING         COMMENT '资金方向:INBOUND-收款，OUTBOUND-采购付款',
    pay_method           STRING         COMMENT '支付方式：BALANCE-余额，WECHAT-微信，ALIPAY-支付宝，CREDIT-授信，OFFLINE-线下或离线，ZERO_FEE-0元单等',
    receive_channel      STRING         COMMENT '收款渠道(INBOUND-收款时填):CASH-现金，WECHAT_QR-微信收款码，ALIPAY_QR-支付宝收款码，BANK_TRANSFER-银行转账，OFFLINE_SYSTEM_OUT-系统外已收',
    amount               BIGINT         COMMENT '支付金额（分）',
    settle_amount        BIGINT         COMMENT '结算金额(分,OUTBOUND-采购付款=向上采购价;INBOUND-收款=售价;利润=amount-settle_amount)',
    transaction_no       STRING         COMMENT '渠道流水号（第三方回调返回或内部渠道同步生成）',
    payer_account_no     STRING         COMMENT '付款方账户(OUTBOUND-采购付款=采购方;INBOUND-收款=空)',
    payee_account_no     STRING         COMMENT '收款方账户(INBOUND-收款=卖方;OUTBOUND-采购付款=供应商)',
    ticket_no            STRING         COMMENT '关联票号(用于关联冻结记录)',
    freeze_instructions  STRING         COMMENT '冻结指令快照:[{ticketNo,accountNo,amount,freezeType}]',
    external_frozen      INT            COMMENT '是否外部渠道冻结:1=第三方冻结(如易宝分账),0=平台内部冻结',
    pay_time             STRING         COMMENT '支付时间',
    pay_status           STRING         COMMENT '支付状态：CREATED-已创建，PAID-已支付，PARTIAL_REFUNDED-部分退款，REFUNDED-已退款',
    tenant_id            BIGINT         COMMENT '租户ID（分库维度）',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    create_by            STRING         COMMENT '创建人',
    update_by            STRING         COMMENT '更新人',
    deleted              INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type       STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time          STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '支付记录（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_fin_payment_channel_config_df  支付渠道配置 ==========
CREATE TABLE IF NOT EXISTS ods.ods_fin_payment_channel_config_df (
    id              BIGINT         COMMENT '主键ID',
    channel_code    STRING         COMMENT '渠道代码：WECHAT-微信，ALIPAY-支付宝，YEEPAY-易宝，UNIONPAY-银联，BALANCE-余额，CREDIT-授信',
    channel_name    STRING         COMMENT '渠道名称',
    merchant_no     STRING         COMMENT '商户号/子商户号',
    app_id          STRING         COMMENT '应用ID',
    callback_url    STRING         COMMENT '回调地址',
    scope           STRING         COMMENT '配置范围：PLATFORM-平台，TENANT-租户',
    tenant_id       BIGINT         COMMENT '租户ID（scope=TENANT-租户时必填）',
    channel_status  STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用，PENDING_APPROVAL-待审批',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '支付渠道配置（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_fin_merchant_payment_config_df  商户收款配置 ==========
CREATE TABLE IF NOT EXISTS ods.ods_fin_merchant_payment_config_df (
    id               BIGINT         COMMENT '主键ID',
    tenant_id        BIGINT         COMMENT '租户ID（商户）',
    collection_mode  STRING         COMMENT '收款模式：PLATFORM_COLLECT-平台代收，INDEPENDENT-独立收款',
    channel_code     STRING         COMMENT '独立收款渠道代码（collection_mode=INDEPENDENT-独立收款时必填）',
    merchant_no      STRING         COMMENT '独立收款商户号',
    config_status    STRING         COMMENT '状态：ACTIVE-有效，PENDING_APPROVAL-待审批，INACTIVE-停用',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户收款配置（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_fin_account_df  统一账户 ==========
CREATE TABLE IF NOT EXISTS ods.ods_fin_account_df (
    id                 BIGINT         COMMENT '主键ID',
    account_no         STRING         COMMENT '账户编号，由流水号生成器生成',
    subject_id         BIGINT         COMMENT '主体ID（商户/分销商/平台）',
    account_kind       STRING         COMMENT '账户类型：MERCHANT-商户，DISTRIBUTOR-分销商，PLATFORM-平台',
    available_balance  BIGINT         COMMENT '可用余额（分）',
    frozen_balance     BIGINT         COMMENT '冻结余额（分）',
    tenant_id          BIGINT         COMMENT '租户ID（分库维度）',
    create_time        STRING         COMMENT '创建时间',
    update_time        STRING         COMMENT '更新时间',
    create_by          STRING         COMMENT '创建人',
    update_by          STRING         COMMENT '更新人',
    deleted            INT            COMMENT '软删除: 0未删/1已删',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '统一账户（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_fin_frozen_record_di  冻结记录 ==========
CREATE TABLE IF NOT EXISTS ods.ods_fin_frozen_record_di (
    id                  BIGINT         COMMENT '主键ID',
    frozen_no           STRING         COMMENT '冻结记录编号，由流水号生成器生成',
    account_no          STRING         COMMENT '归属账户编号',
    ticket_no           STRING         COMMENT '关联票号（票级冻结）',
    amount              BIGINT         COMMENT '冻结金额（分）= 利润/采购款/全款',
    freeze_type         STRING         COMMENT '冻结类型:PROFIT-利润，SETTLEMENT-采购款，FULL-全款，供应商直销',
    frozen_status       STRING         COMMENT '状态：FROZEN-冻结中，RELEASED-已释放',
    frozen_event        STRING         COMMENT '冻结事件：VERIFY-核销，REFUND-退款',
    external_frozen     INT            COMMENT '是否外部渠道冻结:1=第三方冻结(解冻调第三方API-API 接口),0=平台内部冻结',
    external_channel    STRING         COMMENT '外部渠道(external_frozen=1时):YEEPAY-易宝，UNIONPAY-银联等',
    external_frozen_no  STRING         COMMENT '外部冻结单号(第三方返回的冻结流水号,解冻时用)',
    tenant_id           BIGINT         COMMENT '租户ID（分库维度）',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    create_by           STRING         COMMENT '创建人',
    update_by           STRING         COMMENT '更新人',
    deleted             INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type      STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time         STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '冻结记录（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_fin_fund_flow_di  资金流水 ==========
CREATE TABLE IF NOT EXISTS ods.ods_fin_fund_flow_di (
    id                BIGINT         COMMENT '主键ID',
    flow_no           STRING         COMMENT '流水号，格式FL+yyyyMMdd+6位随机',
    account_no        STRING         COMMENT '归属账户编号',
    flow_type         STRING         COMMENT '流水类型：RECHARGE-充值，PAYMENT-支付，REFUND-退款，FREEZE-冻结，UNFREEZE-解冻，WITHDRAW-提现，FEE-手续费，RESOURCE-资源包，TRANSFER_OUT-采购转出，TRANSFER_IN-采购转入',
    amount            BIGINT         COMMENT '变动金额（分，正=入，负=出）',
    balance_before    BIGINT         COMMENT '变动前余额（分）',
    balance_after     BIGINT         COMMENT '变动后余额（分）',
    related_no        STRING         COMMENT '关联业务号（订单号/退款号/提现号等）',
    payment_batch_no  STRING         COMMENT '关联支付批次号(追溯资金动作来源)',
    fee_item          STRING         COMMENT '费用项（短信费/提现手续费等）',
    remark            STRING         COMMENT '备注',
    tenant_id         BIGINT         COMMENT '租户ID（分库维度）',
    create_time       STRING         COMMENT '创建时间',
    update_time       STRING         COMMENT '更新时间',
    create_by         STRING         COMMENT '创建人',
    update_by         STRING         COMMENT '更新人',
    deleted           INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type    STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time       STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '资金流水（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_fin_withdraw_order_di  提现单 ==========
CREATE TABLE IF NOT EXISTS ods.ods_fin_withdraw_order_di (
    id               BIGINT         COMMENT '主键ID',
    withdraw_no      STRING         COMMENT '提现单号，格式WD+yyyyMMdd+6位随机',
    account_no       STRING         COMMENT '提现账户编号',
    subject_id       BIGINT         COMMENT '提现主体ID（商户/分销商）',
    withdraw_amount  BIGINT         COMMENT '提现金额（分）',
    bank_card_id     BIGINT         COMMENT '提现银行卡ID',
    withdraw_status  STRING         COMMENT '状态：PENDING-待处理，APPROVED-已通过，PROCESSING-处理中，COMPLETED-已完成，REJECTED-已拒绝，FAILED-失败',
    approval_no      STRING         COMMENT '审批实例号',
    transaction_no   STRING         COMMENT '第三方打款流水号',
    fail_reason      STRING         COMMENT '失败原因',
    tenant_id        BIGINT         COMMENT '租户ID（分库维度）',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type   STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time      STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '提现单（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_fin_bank_card_df  银行卡 ==========
CREATE TABLE IF NOT EXISTS ods.ods_fin_bank_card_df (
    id            BIGINT         COMMENT '主键ID',
    card_no       STRING         COMMENT '银行卡编号（系统内ID）',
    subject_id    BIGINT         COMMENT '归属主体ID（商户/分销商）',
    bank_name     STRING         COMMENT '银行名称',
    bank_code     STRING         COMMENT '银行代码',
    card_holder   STRING         COMMENT '持卡人姓名',
    card_type     STRING         COMMENT '卡类型：DEBIT-借记卡，CREDIT-授信',
    branch_name   STRING         COMMENT '开户支行',
    card_status   STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    tenant_id     BIGINT         COMMENT '租户ID（分库维度）',
    create_time   STRING         COMMENT '创建时间',
    update_time   STRING         COMMENT '更新时间',
    create_by     STRING         COMMENT '创建人',
    update_by     STRING         COMMENT '更新人',
    deleted       INT            COMMENT '软删除: 0未删/1已删',
    card_tail_no  STRING         COMMENT '卡号后 4 位（抽取时由 card_number 截取，完整卡号不落仓）',
    etl_time      STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '银行卡（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_fin_invoice_config_df  商户发票配置 ==========
CREATE TABLE IF NOT EXISTS ods.ods_fin_invoice_config_df (
    id                 BIGINT         COMMENT '主键ID',
    config_no          STRING         COMMENT '配置编号，格式IC+yyyyMMdd+6位随机',
    tenant_id          BIGINT         COMMENT '归属商户ID',
    invoice_title      STRING         COMMENT '发票抬头',
    tax_no             STRING         COMMENT '税号',
    address_phone      STRING         COMMENT '地址电话',
    bank_branch        STRING         COMMENT '开户行及账号',
    default_content    STRING         COMMENT '默认开票内容',
    invoice_provider   STRING         COMMENT '开票服务商：BAIWANG-百望，HANGTIAN-航天信息，PIAOYITONG-票易通',
    provider_app_id    STRING         COMMENT '服务商AppID',
    provider_terminal  STRING         COMMENT '开票终端号',
    config_status      STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time        STRING         COMMENT '创建时间',
    update_time        STRING         COMMENT '更新时间',
    create_by          STRING         COMMENT '创建人',
    update_by          STRING         COMMENT '更新人',
    deleted            INT            COMMENT '软删除: 0未删/1已删',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '商户发票配置（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_fin_invoice_order_di  发票单 ==========
CREATE TABLE IF NOT EXISTS ods.ods_fin_invoice_order_di (
    id                 BIGINT         COMMENT '主键ID',
    invoice_no         STRING         COMMENT '发票单号，格式INV+yyyyMMdd+6位随机',
    tenant_id          BIGINT         COMMENT '开票商户ID',
    invoice_type       STRING         COMMENT '发票类型：E_NORMAL-电子普票，E_SPECIAL-电子专票',
    invoice_subject    STRING         COMMENT '开票主体：MERCHANT_TO_VISITOR-商户给游客开票，PLATFORM_TO_MERCHANT-平台给商户开票',
    order_group_no     STRING         COMMENT '关联订单号（商户给游客开票）',
    fee_item           STRING         COMMENT '费用项（平台给商户开票时）',
    invoice_amount     BIGINT         COMMENT '开票金额（分）',
    invoice_config_id  BIGINT         COMMENT '发票配置ID（引用t_invoice_config）',
    invoice_status     STRING         COMMENT '状态：PENDING-待处理，APPROVED-已通过，INVOICED-已开票，RED_INVOICED-已红冲，REJECTED-已拒绝',
    invoice_file_url   STRING         COMMENT '发票文件URL-开票成功后存OSS',
    approval_no        STRING         COMMENT '审批实例号',
    create_time        STRING         COMMENT '创建时间',
    update_time        STRING         COMMENT '更新时间',
    create_by          STRING         COMMENT '创建人',
    update_by          STRING         COMMENT '更新人',
    deleted            INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type     STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time        STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '发票单（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_fin_resource_batch_df  资源批次（短信/积分） ==========
CREATE TABLE IF NOT EXISTS ods.ods_fin_resource_batch_df (
    id                  BIGINT         COMMENT '主键ID',
    batch_no            STRING         COMMENT '批次号，格式RB+yyyyMMdd+6位随机',
    tenant_id           BIGINT         COMMENT '归属商户ID',
    resource_type       STRING         COMMENT '资源类型：SMS-短信，POINTS-积分，ALARM_QUOTA-预警额度',
    total_quantity      BIGINT         COMMENT '总量（短信条数/积分点数/预警额度）',
    remaining_quantity  BIGINT         COMMENT '剩余量',
    unit                STRING         COMMENT '单位：COUNT-条，POINT-点，YUAN-元',
    expire_at           STRING         COMMENT '过期时间',
    batch_status        STRING         COMMENT '状态：ACTIVE-有效，EXPIRED-已过期，CONSUMED-已用完',
    purchase_no         STRING         COMMENT '购买流水号（引用资金流水）',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    create_by           STRING         COMMENT '创建人',
    update_by           STRING         COMMENT '更新人',
    deleted             INT            COMMENT '软删除: 0未删/1已删',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '资源批次（短信/积分）（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_prd_spu_df  SPU ==========
CREATE TABLE IF NOT EXISTS ods.ods_prd_spu_df (
    id            BIGINT         COMMENT '主键ID',
    spu_no        STRING         COMMENT 'SPU编号，格式SPU+yyyyMMdd+6位随机',
    tenant_id     BIGINT         COMMENT '归属商户ID',
    product_type  STRING         COMMENT '产品类型（平台字典）：SCENIC-景区门票，HOTEL-酒店，SHOW-演出，Cruise，RESTAURANT-餐饮，ANNUAL_PASS-年卡，SPECIALTY-旅游特产，TIMED-计时型，COUPON-旅游券，LINE-旅游线路',
    spu_name      STRING         COMMENT '产品名称',
    poi_id        BIGINT         COMMENT '关联POI ID',
    description   STRING         COMMENT '产品富文本描述',
    cover_image   STRING         COMMENT '封面图URL',
    spu_status    STRING         COMMENT '状态：DRAFT-草稿，PUBLISHED-已发布，UNPUBLISHED-已下架',
    create_time   STRING         COMMENT '创建时间',
    update_time   STRING         COMMENT '更新时间',
    create_by     STRING         COMMENT '创建人',
    update_by     STRING         COMMENT '更新人',
    deleted       INT            COMMENT '软删除: 0未删/1已删',
    etl_time      STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SPU（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_prd_sku_df  SKU ==========
CREATE TABLE IF NOT EXISTS ods.ods_prd_sku_df (
    id             BIGINT         COMMENT '主键ID',
    sku_no         STRING         COMMENT 'SKU编号，格式SKU+yyyyMMdd+6位随机',
    spu_id         BIGINT         COMMENT '归属SPU ID',
    tenant_id      BIGINT         COMMENT '归属商户ID',
    sku_name       STRING         COMMENT 'SKU名称（如"成人票""VIP套票"）',
    cost_price     BIGINT         COMMENT '成本价（分）——供应商商品属性，不在售价体系内',
    sale_mode      STRING         COMMENT '售卖模式：FIXED_DATE-指定日期，TIMED_RESERVATION-分时预约，PRE_SALE-预售',
    version        INT            COMMENT '版本号，每次属性变更+1（下单时在t_order记录sku_version）',
    sku_status     STRING         COMMENT '状态：DRAFT-草稿，PUBLISHED-已发布，UNPUBLISHED-已下架',
    tags           STRING         COMMENT '标签列表（商户自定义）',
    sale_channels  STRING         COMMENT '销售渠道列表：[MINI_PROGRAM-小程序，WECHAT_SHOP-微信小店，PC，COUNTER-窗口，OTA_DOUYIN-抖音，OTA_MEITUAN-美团，OTA_CTRIP-携程]',
    create_time    STRING         COMMENT '创建时间',
    update_time    STRING         COMMENT '更新时间',
    create_by      STRING         COMMENT '创建人',
    update_by      STRING         COMMENT '更新人',
    deleted        INT            COMMENT '软删除: 0未删/1已删',
    etl_time       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SKU（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_prd_sku_version_snapshot_di  SKU版本快照 ==========
CREATE TABLE IF NOT EXISTS ods.ods_prd_sku_version_snapshot_di (
    id              BIGINT         COMMENT '主键ID',
    snapshot_no     STRING         COMMENT '快照编号，格式SKVS+yyyyMMdd+6位随机',
    sku_id          BIGINT         COMMENT 'SKU ID',
    version         INT            COMMENT '版本号（变更前的版本号）',
    snapshot_data   STRING         COMMENT '商品属性快照：{spu:{name,poiId,productType,coverImage,description}, sku:{name,comboFlag,saleChannels,costPrice,saleMode}, attributes:[{code,name,value}], refundPolicy, verifyRules, priceChangeLog:{oldPrice,newPrice,changeReason}}',
    changed_by      STRING         COMMENT '变更操作人',
    change_reason   STRING         COMMENT '变更原因',
    tenant_id       BIGINT         COMMENT '租户ID（分库维度）',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type  STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time     STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SKU版本快照（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_prd_ticket_meta_df  票属性元数据 ==========
CREATE TABLE IF NOT EXISTS ods.ods_prd_ticket_meta_df (
    id                BIGINT         COMMENT '主键ID',
    attribute_code    STRING         COMMENT '属性代码（全局唯一Code）',
    attribute_name    STRING         COMMENT '属性名称',
    value_type        STRING         COMMENT '值类型：POLICY_CHOICE-单选策略，TOGGLE-开关，NUMERIC-数值，TEXT-文本，DATE_RANGE-日期范围',
    default_value     STRING         COMMENT '默认值',
    scope             STRING         COMMENT '适用业态（逗号分隔）',
    impacts           STRING         COMMENT '影响链：[ORDER-订单，INVENTORY-库存，PRICING-价格，VERIFY-核销，REFUND-退款]',
    conflicts         STRING         COMMENT '互斥属性列表',
    depends_on        STRING         COMMENT '依赖前置属性列表',
    ui_hint           STRING         COMMENT '前端联动规则：{group, show_if}',
    enabled_when      STRING         COMMENT '条件可用性：何条件下可用',
    disabled_when     STRING         COMMENT '条件禁用：何条件下被禁用',
    attribute_status  STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time       STRING         COMMENT '创建时间',
    update_time       STRING         COMMENT '更新时间',
    create_by         STRING         COMMENT '创建人',
    update_by         STRING         COMMENT '更新人',
    deleted           INT            COMMENT '软删除: 0未删/1已删',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '票属性元数据（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_prd_sku_meta_value_df  SKU票属性值 ==========
CREATE TABLE IF NOT EXISTS ods.ods_prd_sku_meta_value_df (
    id               BIGINT         COMMENT '主键ID',
    sku_id           BIGINT         COMMENT 'SKU ID',
    attribute_code   STRING         COMMENT '属性代码（引用t_ticket_meta）',
    attribute_value  STRING         COMMENT '属性值（POLICY_CHOICE-单选策略=选项code，TOGGLE-开关=0/1，NUMERIC-数值=数字，TEXT-文本=文本）',
    tenant_id        BIGINT         COMMENT '租户ID',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SKU票属性值（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_prd_sale_rule_df  售卖规则 ==========
CREATE TABLE IF NOT EXISTS ods.ods_prd_sale_rule_df (
    id              BIGINT         COMMENT '主键ID',
    rule_no         STRING         COMMENT '规则编号，格式SR+yyyyMMdd+6位随机',
    sku_id          BIGINT         COMMENT '归属SKU ID',
    tenant_id       BIGINT         COMMENT '租户ID',
    effective_from  STRING         COMMENT '规则生效时间',
    effective_to    STRING         COMMENT '规则失效时间',
    rule_status     STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '售卖规则（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_prd_sale_rule_item_df  售卖条件项 ==========
CREATE TABLE IF NOT EXISTS ods.ods_prd_sale_rule_item_df (
    id           BIGINT         COMMENT '主键ID',
    rule_id      BIGINT         COMMENT '归属售卖规则ID',
    rule_type    STRING         COMMENT '条件类型：DATE_RANGE-日期范围，TIME_SLOT-时段，PRE_SALE_DAYS-提前预售天数，DAILY_BUY_WINDOW-每日购买时段，PURCHASE_DEADLINE-购买截止时间，BLACKOUT_DATE-不可售日期，WEEKDAY_MASK-星期限制，REGION_LIMIT-地区限制，AGE_RANGE-年龄范围，CERT_TYPE-证件类型限制，MEMBER_LEVEL-会员等级，CUSTOMER_TAG-客户标签，GEO_FENCE-地理围栏，PURCHASE_POI-购买地点限制，MIN_PURCHASE-最小购买量，MAX_PURCHASE-最大购买量，DAILY_LIMIT_PER_USER-每人每日限购',
    rule_value   STRING         COMMENT '条件值（按rule_type结构化，如DATE_RANGE-日期范围={from,to}，REGION_LIMIT-地区限制={regions:[MAINLAND-中国大陆]})',
    tenant_id    BIGINT         COMMENT '租户ID',
    create_time  STRING         COMMENT '创建时间',
    update_time  STRING         COMMENT '更新时间',
    create_by    STRING         COMMENT '创建人',
    update_by    STRING         COMMENT '更新人',
    deleted      INT            COMMENT '软删除: 0未删/1已删',
    etl_time     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '售卖条件项（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_prd_price_point_di  价格点 ==========
CREATE TABLE IF NOT EXISTS ods.ods_prd_price_point_di (
    id              BIGINT         COMMENT '主键ID',
    price_no        STRING         COMMENT '价格点编号，由流水号生成器生成',
    sku_id          BIGINT         COMMENT 'SKU ID',
    channel         STRING         COMMENT '价格渠道: RETAIL-零售价，COUNTER-窗口，OTA_MEITUAN-美团等, NULL=L0默认价',
    date_single     STRING         COMMENT '单日精确匹配(节假日特殊价), NULL=不按单日',
    date_from       STRING         COMMENT '日期区间起始, NULL=不按区间',
    date_to         STRING         COMMENT '日期区间终止, NULL=不按区间',
    weekday_mask    INT            COMMENT '星期掩码 bit0=周一..bit6=周日(工作日=31/周末=96), NULL=不限',
    ext_dims        STRING         COMMENT '动态维度: {"roomType":"大床房","seatLevel":"A区"}',
    price           BIGINT         COMMENT '金额（分）',
    priority        INT            COMMENT '优先级（数值大优先）',
    effective_from  STRING         COMMENT '生效起始',
    effective_to    STRING         COMMENT '生效终止',
    tenant_id       BIGINT         COMMENT '租户ID（分库维度）',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type  STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time     STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '价格点（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_prd_pricing_rule_df  定价规则 ==========
CREATE TABLE IF NOT EXISTS ods.ods_prd_pricing_rule_df (
    id              BIGINT         COMMENT '主键ID',
    rule_no         STRING         COMMENT '规则编号，格式PR+yyyyMMdd+6位随机',
    sku_id          BIGINT         COMMENT 'SKU ID',
    rule_type       STRING         COMMENT '规则类型：MARGIN-分销结算，SURCHARGE-预约加价，DISCOUNT-折扣，MEMBER_DISCOUNT-会员折扣',
    base_price_ref  STRING         COMMENT '基准价引用：RETAIL-零售价，COUNTER-窗口，BASE-期票基础价，CURRENT-当前价',
    calculator      STRING         COMMENT '计算方式：PERCENT-按比例，FIXED-固定，MATRIX-日历矩阵',
    params          STRING         COMMENT '计算参数（JSON，随ruleType+calculator变化）',
    priority        INT            COMMENT '优先级',
    effective_from  STRING         COMMENT '生效起始',
    effective_to    STRING         COMMENT '生效终止',
    tenant_id       BIGINT         COMMENT '租户ID（分库维度）',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '定价规则（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_inv_inventory_pool_di  库存池 ==========
CREATE TABLE IF NOT EXISTS ods.ods_inv_inventory_pool_di (
    id                  BIGINT         COMMENT '主键ID',
    pool_no             STRING         COMMENT '库存池编号，由流水号生成器生成',
    sku_id              BIGINT         COMMENT 'SKU ID',
    pool_type           STRING         COMMENT '池类型：COUNTING-可数池，UNIT-可标识池',
    dimension_key       STRING         COMMENT '维度键组合（如date/roomType/showTime等）',
    total_quantity      BIGINT         COMMENT '总量（COUNTING-可数池池）',
    available_quantity  BIGINT         COMMENT '可用量（实时）',
    frozen_quantity     BIGINT         COMMENT '预扣冻结量',
    pool_status         STRING         COMMENT '池状态：ON_SALE-在售，STOP_SALE-停售，EXPIRED-已过期',
    tenant_id           BIGINT         COMMENT '租户ID（分库维度）',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    create_by           STRING         COMMENT '创建人',
    update_by           STRING         COMMENT '更新人',
    deleted             INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type      STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time         STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '库存池（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_inv_inventory_unit_di  UNIT池资源（座位/房间/舱位） ==========
CREATE TABLE IF NOT EXISTS ods.ods_inv_inventory_unit_di (
    id              BIGINT         COMMENT '主键ID',
    unit_no         STRING         COMMENT '资源个体编号（座位号/房号/舱位号）',
    pool_no         STRING         COMMENT '归属库存池编号',
    unit_status     STRING         COMMENT '状态：AVAILABLE-可用，FROZEN-冻结中，OCCUPIED-已占用',
    order_no        STRING         COMMENT '锁定子单号（FROZEN-冻结中，OCCUPIED-已占用时）',
    metadata        STRING         COMMENT '资源属性（座位等级/房型等）',
    tenant_id       BIGINT         COMMENT '租户ID（分库维度）',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type  STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time     STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'UNIT池资源（座位/房间/舱位）（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_inv_shared_inventory_pool_df  共享库存池 ==========
CREATE TABLE IF NOT EXISTS ods.ods_inv_shared_inventory_pool_df (
    id              BIGINT         COMMENT '主键ID',
    relation_id     BIGINT         COMMENT '分销关系ID',
    source_pool_no  STRING         COMMENT '源库存池编号（供应商池）',
    shared_pool_no  STRING         COMMENT '共享池编号（分销商独立池，软配额模式）',
    quota_type      STRING         COMMENT '配额类型：HARD-硬配额，SOFT-软配额，ROLLING-滚动配额',
    quota_quantity  BIGINT         COMMENT '配额数量',
    quota_used      BIGINT         COMMENT '已用配额',
    sharing_status  STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '共享库存池（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_cus_customer_di  C端游客主账号 ==========
CREATE TABLE IF NOT EXISTS ods.ods_cus_customer_di (
    id                  BIGINT         COMMENT '主键ID',
    customer_no         STRING         COMMENT '客户编号，格式CUS+yyyyMMdd+6位随机',
    customer_kind       STRING         COMMENT '账号类型：REAL-真人注册账号，TENANT_DEFAULT-业务租户代下单占位买家；PLATFORM-平台 租户下不设占位买家，故无 PLATFORM_DEFAULT 值',
    wechat_unionid      STRING         COMMENT '微信开放平台unionid（本租户内跨小程序/公众号/App识别；跨租户不收敛，由 (unionid, register_tenant_id) 复合唯一键保证）',
    alipay_user_id      STRING         COMMENT '支付宝uid',
    phone               STRING         COMMENT '联系电话+登录句柄（非唯一，可被本租户内多账号共用；手机登录匹配多个时弹身份选择器）（脱敏）',
    name                STRING         COMMENT '姓名/昵称',
    email               STRING         COMMENT '邮箱',
    gender              STRING         COMMENT '性别：MALE-男，FEMALE-女，UNKNOWN-未知',
    birthday            STRING         COMMENT '生日',
    avatar              STRING         COMMENT '头像URL',
    auth_status         STRING         COMMENT '认证状态：UNAUTHENTICATED-未认证，PHONE_VERIFIED-手机已验证，PERSON_CERTIFIED-已实名认证',
    customer_status     STRING         COMMENT '状态：ACTIVE-有效，BANNED-已封禁，CANCELLED-已取消',
    register_source     STRING         COMMENT '注册来源渠道编码（channel_code）',
    register_tenant_id  BIGINT         COMMENT '所属租户ID（self-tenant 隔离：该 customer 仅归属此租户，不跨租户复用；unionid/alipay 唯一键均带此列，phone 非唯一；证件号收敛改走 t_customer_credential 唯一键）',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    create_by           STRING         COMMENT '创建人',
    update_by           STRING         COMMENT '更新人',
    deleted             INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type      STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time         STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'C端游客主账号（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_cus_customer_identity_di  游客多渠道身份 ==========
CREATE TABLE IF NOT EXISTS ods.ods_cus_customer_identity_di (
    id               BIGINT         COMMENT '主键ID',
    customer_id      BIGINT         COMMENT '归属 Customer ID',
    identity_type    STRING         COMMENT '标识类型：WECHAT_OPENID-微信 openid，DOUYIN_OPENID-抖音 openid，OTA_UID-OTA 用户ID，ALIPAY_OPENID-支付宝 openid，OTHER-其他',
    identity_value   STRING         COMMENT '标识值（openid/OTA用户uid等）',
    bind_channel_id  BIGINT         COMMENT '产生该标识的接入端ID（指向 t_channel）',
    bind_tenant_id   BIGINT         COMMENT '产生该标识的租户ID（小程序openid必带；平台端=内部租户id,即 tenant_type=INTERNAL-内部运营主体 的租户数值 id）',
    extra_data       STRING         COMMENT '扩展数据（授权scope/首授时间等）',
    identity_status  STRING         COMMENT '状态：ACTIVE-有效，REVOKED-已撤销',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type   STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time      STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '游客多渠道身份（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_cus_customer_credential_di  游客个人凭证 ==========
CREATE TABLE IF NOT EXISTS ods.ods_cus_customer_credential_di (
    id                  BIGINT         COMMENT '主键ID',
    credential_no       STRING         COMMENT '凭证编号，格式PC+yyyyMMdd+6位随机',
    customer_id         BIGINT         COMMENT '归属 Customer ID',
    register_tenant_id  BIGINT         COMMENT '注册租户ID（冗余自t_customer.register_tenant_id,用于证件号收敛唯一键）',
    credential_type     STRING         COMMENT '凭证类型: ID_CARD-身份证，PASSPORT-护照，DRIVER_LICENSE-驾驶证，FACE-人脸/...(支持国际证件扩展)',
    code_value          STRING         COMMENT '码值（证件号/faceToken等）（脱敏）',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    create_by           STRING         COMMENT '创建人',
    update_by           STRING         COMMENT '更新人',
    deleted             INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type      STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time         STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '游客个人凭证（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_tenant_df  租户 ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_tenant_df (
    id               BIGINT         COMMENT '主键ID',
    tenant_no        STRING         COMMENT '租户编号,格式TNT+yyyyMMdd+6位随机;内部租户同样走此规则,不再用PLATFORM-平台约定',
    tenant_name      STRING         COMMENT '租户名称',
    tenant_type      STRING         COMMENT '租户类型: INTERNAL-内部运营主体，可多个，平级，EXTERNAL-外部业务租户',
    contact_phone    STRING         COMMENT '联系人手机号',
    country_code     STRING         COMMENT '国家码 ISO 3166-1(如 CN，US，JP),关联 t_country.country_code',
    region_id        BIGINT         COMMENT '最末级地区ID,关联 t_region.id;0表示未设置',
    region_path      STRING         COMMENT '行政区划完整路径(冗余,取自 t_region.region_path),展示+检索用,如"中国/福建省/厦门市/思明区"',
    business_types   STRING         COMMENT '业态列表(多选):[SCENIC-景区门票，HOTEL-酒店，SHOW-演出/...]',
    auth_status      STRING         COMMENT '认证状态: UNAUTHENTICATED-未认证，PENDING_REVIEW-审核中，CERTIFIED-已认证，REJECTED-已驳回',
    register_source  STRING         COMMENT '租户来源: SELF_REGISTER-自行注册，PLATFORM_CREATED-后台添加，IMPORT-批量导入，PARTNER_INVITE-合作伙伴邀请',
    tenant_status    STRING         COMMENT '状态: ACTIVE-有效，BANNED-已封禁，INACTIVE-停用',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '租户（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_tenant_config_df  租户配置KV ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_tenant_config_df (
    id            BIGINT         COMMENT '主键ID',
    tenant_id     BIGINT         COMMENT '租户ID',
    config_key    STRING         COMMENT '配置键(关联 t_config_meta WHERE config_scope=TENANT-租户,如 currency/locale/timezone/supported_pay_methods)',
    config_value  STRING         COMMENT '配置值(JSON统一承载,如 "CNY-人民币" / ["WECHAT-微信","ALIPAY-支付宝"] / {"decimal":2});由应用层 ConfigParser 按key注册负责录入校验与解释读取',
    create_time   STRING         COMMENT '创建时间',
    update_time   STRING         COMMENT '更新时间',
    create_by     STRING         COMMENT '创建人',
    update_by     STRING         COMMENT '更新人',
    deleted       INT            COMMENT '软删除: 0未删/1已删',
    etl_time      STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '租户配置KV（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_tenant_staff_df  B端员工 ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_tenant_staff_df (
    id            BIGINT         COMMENT '主键ID',
    staff_no      STRING         COMMENT '员工编号(工号),格式yyMMdd+4位随机,纯数字短编号,不带前缀;员工日常使用,越短越好',
    tenant_id     BIGINT         COMMENT '所属租户ID（内部员工=tenant_type=INTERNAL-内部运营主体 租户id）',
    org_id        BIGINT         COMMENT '所属部门ID(0=未分配; FK→t_org.id); 一个员工只属于一个主部门,多部门数据访问走RBAC角色+数据范围',
    position_id   BIGINT         COMMENT '岗位ID(0=未分配; FK→t_tenant_position.id); 一个员工一个岗位(1:N),兼岗需求走RBAC角色',
    name          STRING         COMMENT '姓名',
    phone         STRING         COMMENT '手机号(数据属性,非唯一;若支持手机号登录,录入时同时存一份到t_staff_credential;否则仅展示用)',
    email         STRING         COMMENT '邮箱',
    staff_status  STRING         COMMENT '状态：ACTIVE-有效，DISABLED-已停用，RESIGNED-已离职',
    create_time   STRING         COMMENT '创建时间',
    update_time   STRING         COMMENT '更新时间',
    create_by     STRING         COMMENT '创建人',
    update_by     STRING         COMMENT '更新人',
    deleted       INT            COMMENT '软删除: 0未删/1已删',
    etl_time      STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'B端员工（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_staff_config_df  员工配置KV ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_staff_config_df (
    id            BIGINT         COMMENT '主键ID',
    staff_id      BIGINT         COMMENT '员工ID（FK→t_tenant_staff.id）',
    tenant_id     BIGINT         COMMENT '租户ID（冗余,便于按租户批量查询）',
    config_key    STRING         COMMENT '配置键(关联 t_config_meta WHERE config_scope=STAFF): mfa_enabled(是否开启MFA)/login_2fa_confirm(登录二次确认)/session_timeout(会话超时秒数)/ip_whitelist(IP白名单)等',
    config_value  STRING         COMMENT '配置值(JSON承载,如 true / 3600 / ["10.0.0.1"])',
    create_time   STRING         COMMENT '创建时间',
    update_time   STRING         COMMENT '更新时间',
    create_by     STRING         COMMENT '创建人',
    update_by     STRING         COMMENT '更新人',
    deleted       INT            COMMENT '软删除: 0未删/1已删',
    etl_time      STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '员工配置KV（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_org_df  部门架构 ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_org_df (
    id             BIGINT         COMMENT '主键ID',
    org_no         STRING         COMMENT '部门编号,格式DEP+yyyyMMdd+6位随机',
    org_name       STRING         COMMENT '部门名称',
    parent_org_id  BIGINT         COMMENT '上级部门ID(0=顶级部门)',
    tenant_id      BIGINT         COMMENT '租户ID',
    org_status     STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time    STRING         COMMENT '创建时间',
    update_time    STRING         COMMENT '更新时间',
    create_by      STRING         COMMENT '创建人',
    update_by      STRING         COMMENT '更新人',
    deleted        INT            COMMENT '软删除: 0未删/1已删',
    etl_time       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '部门架构（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_tenant_position_df  岗位定义 ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_tenant_position_df (
    id               BIGINT         COMMENT '主键ID',
    position_no      STRING         COMMENT '岗位编号,格式POS-POS 机+yyyyMMdd+6位随机',
    tenant_id        BIGINT         COMMENT '租户ID',
    position_name    STRING         COMMENT '岗位名称（如"运营主管/安全员/财务审核"等）',
    position_code    STRING         COMMENT '岗位编码（租户内唯一，如OPS_MANAGER/SAFETY_INSPECTOR，便于代码引用）',
    position_status  STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '岗位定义（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_sys_role_df  RBAC角色 ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_sys_role_df (
    id           BIGINT         COMMENT '主键ID',
    role_code    STRING         COMMENT '角色代码',
    role_name    STRING         COMMENT '角色名称',
    tenant_id    BIGINT         COMMENT '租户ID',
    role_status  STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time  STRING         COMMENT '创建时间',
    update_time  STRING         COMMENT '更新时间',
    create_by    STRING         COMMENT '创建人',
    update_by    STRING         COMMENT '更新人',
    deleted      INT            COMMENT '软删除: 0未删/1已删',
    etl_time     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'RBAC角色（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_sys_permission_df  权限定义 ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_sys_permission_df (
    id                 BIGINT         COMMENT '主键ID',
    permission_code    STRING         COMMENT '权限编码：product:manage / order:refund / finance:report',
    permission_name    STRING         COMMENT '权限名称（对租户可见）：商品管理/订单退款/财务报表',
    permission_desc    STRING         COMMENT '权限描述',
    module             STRING         COMMENT '所属模块：product/order/finance/verification等',
    permission_status  STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time        STRING         COMMENT '创建时间',
    update_time        STRING         COMMENT '更新时间',
    create_by          STRING         COMMENT '创建人',
    update_by          STRING         COMMENT '更新人',
    deleted            INT            COMMENT '软删除: 0未删/1已删',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '权限定义（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_sys_resource_df  资源定义 ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_sys_resource_df (
    id               BIGINT         COMMENT '主键ID',
    resource_code    STRING         COMMENT '资源唯一编码：menu:product:list / button:order:refund / api:POST:/order/refund',
    resource_name    STRING         COMMENT '资源名称（商品列表菜单/退款按钮/退款接口）',
    resource_type    STRING         COMMENT '资源类型：MENU-菜单，BUTTON-按钮，API-接口，PAGE-页面，DATA_EXPORT-数据导出',
    resource_value   STRING         COMMENT '资源值：MENU-菜单=前端路由路径；BUTTON-按钮=按钮标识；API-API 接口=HTTP方法+路径（如 POST /order/refund）',
    parent_id        BIGINT         COMMENT '父资源ID（菜单树层级；0=顶级）',
    sort_order       INT            COMMENT '排序权重',
    resource_status  STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '资源定义（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_sys_role_permission_df  角色-权限绑定 ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_sys_role_permission_df (
    id             BIGINT         COMMENT '主键ID',
    role_id        BIGINT         COMMENT '角色ID',
    permission_id  BIGINT         COMMENT '权限ID（FK→t_sys_permission.id）',
    tenant_id      BIGINT         COMMENT '租户ID',
    create_time    STRING         COMMENT '创建时间',
    update_time    STRING         COMMENT '更新时间',
    create_by      STRING         COMMENT '创建人',
    update_by      STRING         COMMENT '更新人',
    deleted        INT            COMMENT '软删除: 0未删/1已删',
    etl_time       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '角色-权限绑定（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_sys_permission_resource_df  权限-资源映射 ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_sys_permission_resource_df (
    id             BIGINT         COMMENT '主键ID',
    permission_id  BIGINT         COMMENT '权限ID（FK→t_sys_permission.id）',
    resource_id    BIGINT         COMMENT '资源ID（FK→t_sys_resource.id）',
    create_time    STRING         COMMENT '创建时间',
    update_time    STRING         COMMENT '更新时间',
    create_by      STRING         COMMENT '创建人',
    update_by      STRING         COMMENT '更新人',
    deleted        INT            COMMENT '软删除: 0未删/1已删',
    etl_time       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '权限-资源映射（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_sys_user_role_df  员工-角色绑定 ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_sys_user_role_df (
    id           BIGINT         COMMENT '主键ID',
    user_id      BIGINT         COMMENT '员工ID（语义=t_tenant_staff.id；字段名保留 user_id 避免大范围联动）',
    role_id      BIGINT         COMMENT '角色ID',
    tenant_id    BIGINT         COMMENT '租户ID',
    create_time  STRING         COMMENT '创建时间',
    update_time  STRING         COMMENT '更新时间',
    create_by    STRING         COMMENT '创建人',
    update_by    STRING         COMMENT '更新人',
    deleted      INT            COMMENT '软删除: 0未删/1已删',
    etl_time     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '员工-角色绑定（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_sup_sys_data_permission_df  ABAC数据权限 ==========
CREATE TABLE IF NOT EXISTS ods.ods_sup_sys_data_permission_df (
    id                 BIGINT         COMMENT '主键ID',
    role_id            BIGINT         COMMENT '角色ID',
    tenant_id          BIGINT         COMMENT '租户ID',
    resource_type      STRING         COMMENT '资源类型：ORDER-订单，PRODUCT-商品，TICKET-票',
    attr_field         STRING         COMMENT '属性字段：creator_id/org_id/distributor_id',
    attr_value_source  STRING         COMMENT '值来源：SELF-本人，DEPT-本部门，CUSTOM-自定义',
    custom_values      STRING         COMMENT '自定义值列表（attr_value_source=CUSTOM-自定义时）',
    create_time        STRING         COMMENT '创建时间',
    update_time        STRING         COMMENT '更新时间',
    create_by          STRING         COMMENT '创建人',
    update_by          STRING         COMMENT '更新人',
    deleted            INT            COMMENT '软删除: 0未删/1已删',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'ABAC数据权限（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_trf_channel_df  接入端/渠道 ==========
CREATE TABLE IF NOT EXISTS ods.ods_trf_channel_df (
    id                         BIGINT         COMMENT '主键ID',
    channel_code               STRING         COMMENT '渠道唯一编码：MP_TENANT_HOSTED-租户托管小程序，MP_PLATFORM-平台小程序，PC_TENANT-租户后台，PC_PLATFORM-平台后台，OFFLINE-线下或离线，API_XXX',
    channel_name               STRING         COMMENT '渠道展示名（"租户托管小程序"/"美团接入"）',
    partner_id                 STRING         COMMENT '合作方ID（Partner 统一抽象：美团partnerId/微信appId/抖音appId/携程agentId，AI-AI 接入 Agent ID等）；每个外部合作方一个唯一partner_id',
    partner_name               STRING         COMMENT '合作方名称（冗余展示用：美团/微信/抖音/携程等）',
    channel_type               STRING         COMMENT '渠道类型：MP-小程序，PC，API-API 接口，OFFLINE-线下或离线，H5',
    channel_scope              STRING         COMMENT '渠道作用域：PLATFORM-平台运营方持有，全平台共用，TENANT-具体租户持有；详见§2.9.1',
    owner_tenant_id            BIGINT         COMMENT '渠道所有者租户ID（channel_scope=TENANT-租户时必填=持有该渠道的租户；channel_scope=PLATFORM-平台时=内部租户id,即 tenant_type=INTERNAL-内部运营主体 的租户数值 id）。注意：与渠道下挂载的租户(channel_tenant_binding.tenant_id)不同，前者表"持有"，后者表"使用"',
    app_key                    STRING         COMMENT '接入AppKey（API-API 接口端必填；一渠道一套；与t_api_key共享app_key全局唯一）；PC，MP-小程序端由 t_tenant_mp_config 承载小程序密钥',
    default_operator_staff_id  BIGINT         COMMENT '默认操作员ID（channel_type=API-API 接口必填，请求未带staffCode时兜底）',
    ip_whitelist               STRING         COMMENT 'IP白名单（逗号分隔；API-API 接口端使用）',
    callback_url               STRING         COMMENT '回调地址（API-API 接口端订单/退款通知）',
    extra_config               STRING         COMMENT '扩展配置：签名算法/协议版本/子渠道枚举/防重放窗口等（详细设计阶段再细化）',
    channel_status             STRING         COMMENT '状态：ENABLED-启用，DISABLED-已停用',
    valid_from                 STRING         COMMENT '生效开始时间',
    valid_to                   STRING         COMMENT '生效结束时间',
    create_time                STRING         COMMENT '创建时间',
    update_time                STRING         COMMENT '更新时间',
    create_by                  STRING         COMMENT '创建人',
    update_by                  STRING         COMMENT '更新人',
    deleted                    INT            COMMENT '软删除: 0未删/1已删',
    etl_time                   STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '接入端/渠道（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_trf_channel_tenant_binding_df  渠道-租户绑定 ==========
CREATE TABLE IF NOT EXISTS ods.ods_trf_channel_tenant_binding_df (
    id               BIGINT         COMMENT '主键ID',
    binding_no       STRING         COMMENT '绑定编号，格式CHB+yyyyMMdd+6位随机',
    channel_id       BIGINT         COMMENT '渠道ID（FK→t_channel.id）',
    tenant_id        BIGINT         COMMENT '租户ID（FK→t_tenant.id；此租户可通过该渠道下单/被下单）',
    partner_id       STRING         COMMENT '合作方ID（冗余便于查询，与t_channel.partner_id同步）',
    ota_merchant_id  STRING         COMMENT 'OTA侧商户ID（美团scenicId/抖音shopId/携程shopId，AI-AI 接入 Agent 商户id等）；推单/拉单路由时用于按租户维度识别订单归属',
    ota_sub_channel  STRING         COMMENT 'OTA子渠道枚举（可选；用于同渠道内细分场景，如美团"景点门票"vs"玩乐"）',
    binding_status   STRING         COMMENT '绑定状态：ACTIVE-有效，INACTIVE-停用，SUSPENDED-已暂停',
    extra_config     STRING         COMMENT '渠道×租户特有配置（如分账比例、特价生效、结算账户等）',
    valid_from       STRING         COMMENT '生效开始时间',
    valid_to         STRING         COMMENT '生效结束时间',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '渠道-租户绑定（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_trf_tenant_mp_config_df  租户小程序配置 ==========
CREATE TABLE IF NOT EXISTS ods.ods_trf_tenant_mp_config_df (
    id             BIGINT         COMMENT '主键ID',
    tenant_id      BIGINT         COMMENT '归属租户ID',
    mp_type        STRING         COMMENT '小程序类型：WECHAT_MP-微信公众号，WECHAT_MINI-微信小程序，WECHAT_WORK-企业微信，ALIPAY_MINI-支付宝小程序，DOUYIN_MINI-抖音小程序',
    app_id         STRING         COMMENT '小程序 appId（微信/支付宝/抖音）',
    mch_id         STRING         COMMENT '微信支付商户号（可能共用）',
    remark         STRING         COMMENT '备注',
    config_status  STRING         COMMENT '状态：ENABLED-启用，DISABLED-已停用',
    create_time    STRING         COMMENT '创建时间',
    update_time    STRING         COMMENT '更新时间',
    create_by      STRING         COMMENT '创建人',
    update_by      STRING         COMMENT '更新人',
    deleted        INT            COMMENT '软删除: 0未删/1已删',
    etl_time       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '租户小程序配置（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_trf_distribution_relation_df  分销关系 ==========
CREATE TABLE IF NOT EXISTS ods.ods_trf_distribution_relation_df (
    id                     BIGINT         COMMENT '主键ID',
    relation_no            STRING         COMMENT '分销关系编号，格式DR+yyyyMMdd+6位随机',
    supplier_tenant_id     BIGINT         COMMENT '供应商租户ID',
    distributor_tenant_id  BIGINT         COMMENT '分销商租户ID',
    parent_relation_id     BIGINT         COMMENT '上级分销关系ID（4级采购链）',
    distribution_mode      STRING         COMMENT '分销模式：PROFIT_SHARE-分润，PURCHASE-逐级采购',
    payment_mode           STRING         COMMENT '支付模式：CREDIT-授信，BALANCE-余额',
    credit_limit           BIGINT         COMMENT '授信额度（分，payment_mode=CREDIT-授信时）',
    credit_used            BIGINT         COMMENT '已用授信（分）',
    relation_status        STRING         COMMENT '状态：ACTIVE-有效，SUSPENDED-已暂停，TERMINATED-已终止',
    create_time            STRING         COMMENT '创建时间',
    update_time            STRING         COMMENT '更新时间',
    create_by              STRING         COMMENT '创建人',
    update_by              STRING         COMMENT '更新人',
    deleted                INT            COMMENT '软删除: 0未删/1已删',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '分销关系（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_trf_api_key_df  API密钥 ==========
CREATE TABLE IF NOT EXISTS ods.ods_trf_api_key_df (
    id                  BIGINT         COMMENT '主键ID',
    key_no              STRING         COMMENT '密钥编号，格式AK+yyyyMMdd+6位随机',
    channel_id          BIGINT         COMMENT '渠道ID（FK→t_channel.id；一渠道=一套AppKey；详见§2.9.1）',
    partner_id          STRING         COMMENT '合作方ID（冗余便于查询，与t_channel.partner_id同步；美团partnerId/微信appId等）',
    tenant_id           BIGINT         COMMENT '渠道所有者租户ID（nullable；PLATFORM-平台渠道此字段为NULL；TENANT-租户渠道=owner_tenant_id）。注意：与"渠道下挂载的租户"（t_channel_tenant_binding.tenant_id）不同',
    app_key             STRING         COMMENT 'AppKey（一渠道一套；与t_channel.app_key共享全局唯一索引）',
    allowed_interfaces  STRING         COMMENT '允许调用的接口列表',
    rate_limit_qps      INT            COMMENT 'QPS限制',
    key_status          STRING         COMMENT '状态：ACTIVE-有效，REVOKED-已撤销',
    expires_at          STRING         COMMENT '过期时间',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    create_by           STRING         COMMENT '创建人',
    update_by           STRING         COMMENT '更新人',
    deleted             INT            COMMENT '软删除: 0未删/1已删',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'API密钥（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_code_pool_df  码池 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_code_pool_df (
    id               BIGINT         COMMENT '主键ID',
    pool_no          STRING         COMMENT '码池编号，格式CP+yyyyMMdd+6位随机',
    tenant_id        BIGINT         COMMENT '归属商户ID',
    pool_type        STRING         COMMENT '池类型：SINGLE_TICKET-单票池，COMBO_TICKET-套票池',
    credential_type  STRING         COMMENT '凭证类型：QR_CODE-二维码，BAR_CODE-条形码',
    capacity         BIGINT         COMMENT '池容量（最大并发码数）',
    allocated_count  BIGINT         COMMENT '已分配码数',
    recycled_count   BIGINT         COMMENT '已回收复用码数',
    pool_status      STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '码池（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_verify_point_df  核销点 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_verify_point_df (
    id               BIGINT         COMMENT '主键ID',
    verify_point_no  STRING         COMMENT '核销点编号，格式VP+yyyyMMdd+6位随机',
    tenant_id        BIGINT         COMMENT '归属商户ID',
    poi_id           BIGINT         COMMENT '关联POI ID',
    point_name       STRING         COMMENT '核销点名称（如"东门闸机组"）',
    point_type       STRING         COMMENT '类型：GATE-闸机，COUNTER-窗口，SELF_SERVICE-自助机，HANDHELD-手持机',
    point_status     STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    allowed_sku_ids  STRING         COMMENT '允许核销的SKU列表（null=全部）',
    device_group_id  BIGINT         COMMENT '绑定设备分组ID',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '核销点（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_risk_rule_df  风控规则 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_risk_rule_df (
    id               BIGINT         COMMENT '主键ID',
    rule_no          STRING         COMMENT '规则编号，格式RR+yyyyMMdd+6位随机',
    rule_name        STRING         COMMENT '规则名称（如"凌晨操作检测"）',
    rule_type        STRING         COMMENT '规则类型：BLACKLIST-黑名单，PURCHASE_LIMIT-购买限制，GEO_FENCE-地理围栏，ABNORMAL_OP-异常操作，DEFAULT_BREAK-爽约',
    scope            STRING         COMMENT '范围：GLOBAL-全局，TENANT-租户',
    dimension        STRING         COMMENT '维度：USER_ID-用户ID，ID_CARD-身份证，PHONE-手机号，IP，DEVICE_ID-设备ID',
    threshold        STRING         COMMENT '阈值（如"1小时内3次"）',
    time_window      INT            COMMENT '时间窗口（秒）',
    action           STRING         COMMENT '动作：BLOCK-拦截，WARN-预警，FREEZE-冻结',
    rule_status      STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    created_by_type  STRING         COMMENT '创建方：PLATFORM_ADMIN-平台管理员，TENANT_ADMIN-租户管理员，SYSTEM-系统',
    tenant_id        BIGINT         COMMENT '租户ID（scope=TENANT-租户时必填）',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '风控规则（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_blacklist_di  黑名单 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_blacklist_di (
    id                BIGINT         COMMENT '主键ID',
    blacklist_no      STRING         COMMENT '黑名单记录编号',
    dimension         STRING         COMMENT '维度：USER_ID-用户ID，ID_CARD-身份证，PHONE-手机号，IP',
    dimension_value   STRING         COMMENT '维度值（身份证号/IP等）（脱敏）',
    reason            STRING         COMMENT '封禁原因',
    scope             STRING         COMMENT '范围：GLOBAL-全局，TENANT-租户',
    banned_actions    STRING         COMMENT '封禁动作组合：[PLACE_ORDER-下单，WITHDRAW-提现，VERIFY-核销，PUBLISH-发品，LOGIN-登录级]',
    expires_at        STRING         COMMENT '过期时间（null=永久）',
    blacklist_status  STRING         COMMENT '状态：ACTIVE-有效，EXPIRED-已过期，REVOKED-已撤销',
    created_by_type   STRING         COMMENT '创建方：RISK_RULE-风控规则，MANUAL-人工',
    rule_id           BIGINT         COMMENT '关联规则ID（规则触发时）',
    tenant_id         BIGINT         COMMENT '租户ID（scope=TENANT-租户时）',
    create_time       STRING         COMMENT '创建时间',
    update_time       STRING         COMMENT '更新时间',
    create_by         STRING         COMMENT '创建人',
    update_by         STRING         COMMENT '更新人',
    deleted           INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type    STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time       STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '黑名单（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_risk_event_di  风控事件 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_risk_event_di (
    id                BIGINT         COMMENT '主键ID',
    event_no          STRING         COMMENT '事件编号，格式RE+yyyyMMdd+6位随机',
    event_type        STRING         COMMENT '类型：RULE_HIT-规则命中，MANUAL_BAN-人工封禁，MANUAL_UNBAN-人工解封，ABNORMAL_OP_DETECTED-检测到异常操作',
    subject_id        BIGINT         COMMENT '主体ID（用户/商户）',
    dimension_values  STRING         COMMENT '触发维度值集合',
    rule_id           BIGINT         COMMENT '关联规则ID',
    action            STRING         COMMENT '执行动作：BLOCK-拦截，WARN-预警，FREEZE-冻结',
    detail            STRING         COMMENT '详细描述',
    audit_log_id      BIGINT         COMMENT '关联审计日志ID',
    tenant_id         BIGINT         COMMENT '租户ID',
    create_time       STRING         COMMENT '创建时间',
    update_time       STRING         COMMENT '更新时间',
    create_by         STRING         COMMENT '创建人',
    update_by         STRING         COMMENT '更新人',
    deleted           INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type    STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time       STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '风控事件（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_account_ban_di  账号封禁 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_account_ban_di (
    id              BIGINT         COMMENT '主键ID',
    ban_no          STRING         COMMENT '封禁编号',
    subject_id      BIGINT         COMMENT '被封禁主体（用户/商户）',
    ban_type        STRING         COMMENT '封禁类型：LOGIN-登录级，BUSINESS-业务操作级',
    banned_actions  STRING         COMMENT '封禁动作组合：[PLACE_ORDER-下单，WITHDRAW-提现，VERIFY-核销，PUBLISH-发品，LOGIN-登录级]',
    reason          STRING         COMMENT '封禁原因',
    ban_source      STRING         COMMENT '来源：RISK_RULE-风控规则，MANUAL-人工',
    rule_id         BIGINT         COMMENT '关联规则ID（规则自动触发时）',
    expires_at      STRING         COMMENT '过期时间',
    ban_status      STRING         COMMENT '状态：ACTIVE-有效，EXPIRED-已过期，REVOKED-已撤销',
    revoked_by      STRING         COMMENT '解封人',
    revoked_at      STRING         COMMENT '解封时间',
    tenant_id       BIGINT         COMMENT '租户ID',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type  STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time     STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '账号封禁（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_device_df  设备 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_device_df (
    id               BIGINT         COMMENT '主键ID',
    device_no        STRING         COMMENT '设备编号，格式DEV+yyyyMMdd+6位随机',
    tenant_id        BIGINT         COMMENT '归属商户ID',
    device_type      STRING         COMMENT '设备类型：GATE-闸机，POS-POS 机，HANDHELD-手持机，SELF_SERVICE-自助机，KIOSK-自助终端，FACE_RECOGNITION-人脸识别机',
    device_name      STRING         COMMENT '设备名称（如"东门闸机#3"）',
    poi_id           BIGINT         COMMENT '绑定POI ID',
    device_group_id  BIGINT         COMMENT '设备分组ID',
    capabilities     STRING         COMMENT '设备能力：[SELL-售票，PICKUP-取票，Verify，IDENTIFY-身份识别]',
    device_status    STRING         COMMENT '状态：ACTIVE-有效，OFFLINE-线下或离线，MAINTENANCE-维护中，INACTIVE-停用',
    last_heartbeat   STRING         COMMENT '最后心跳时间',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '设备（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_device_group_df  设备分组 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_device_group_df (
    id               BIGINT         COMMENT '主键ID',
    group_no         STRING         COMMENT '分组编号，格式DG+yyyyMMdd+6位随机',
    tenant_id        BIGINT         COMMENT '归属商户ID',
    group_name       STRING         COMMENT '分组名称（如"东门闸机组"）',
    poi_id           BIGINT         COMMENT '绑定POI ID',
    verify_point_id  BIGINT         COMMENT '绑定核销点ID',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '设备分组（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_sys_dict_df  平台字典 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_sys_dict_df (
    id            BIGINT         COMMENT '主键ID',
    dict_type     STRING         COMMENT '字典类型（如product_type/verify_type/id_type）',
    dict_code     STRING         COMMENT '字典代码',
    dict_name     STRING         COMMENT '字典名称',
    dict_name_en  STRING         COMMENT '英文名称（i18n）',
    dict_order    INT            COMMENT '排序',
    dict_status   STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    scope         STRING         COMMENT '范围：PLATFORM-平台，TENANT-租户',
    tenant_id     BIGINT         COMMENT '租户ID（scope=TENANT-租户时）',
    create_time   STRING         COMMENT '创建时间',
    update_time   STRING         COMMENT '更新时间',
    create_by     STRING         COMMENT '创建人',
    update_by     STRING         COMMENT '更新人',
    deleted       INT            COMMENT '软删除: 0未删/1已删',
    etl_time      STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '平台字典（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_package_df  套餐包 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_package_df (
    id                   BIGINT         COMMENT '主键ID',
    package_no           STRING         COMMENT '套餐编号，格式PKG+yyyyMMdd+6位随机',
    package_name         STRING         COMMENT '套餐名称（如"基础版""专业版"）',
    package_price        BIGINT         COMMENT '套餐价格（分/年）',
    duration_days        INT            COMMENT '有效期（天）',
    feature_permissions  STRING         COMMENT '功能权限项列表：[{featureCode, enabled}]',
    resource_limits      STRING         COMMENT '资源额度：{smsCount, maxUsers, maxProducts, alarmQuota}',
    package_status       STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    create_by            STRING         COMMENT '创建人',
    update_by            STRING         COMMENT '更新人',
    deleted              INT            COMMENT '软删除: 0未删/1已删',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '套餐包（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_package_subscription_di  套餐订购 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_package_subscription_di (
    id                   BIGINT         COMMENT '主键ID',
    subscription_no      STRING         COMMENT '订购编号，格式SUB+yyyyMMdd+6位随机',
    tenant_id            BIGINT         COMMENT '租户ID',
    package_id           BIGINT         COMMENT '套餐ID',
    subscription_type    STRING         COMMENT '类型：NEW-新购，RENEW-续费，UPGRADE-升级',
    start_at             STRING         COMMENT '生效时间',
    expire_at            STRING         COMMENT '到期时间',
    subscription_status  STRING         COMMENT '状态：ACTIVE-有效，EXPIRED-已过期，CANCELLED-已取消',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    create_by            STRING         COMMENT '创建人',
    update_by            STRING         COMMENT '更新人',
    deleted              INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type       STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time          STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '套餐订购（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_approval_flow_df  审批流定义 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_approval_flow_df (
    id               BIGINT         COMMENT '主键ID',
    flow_no          STRING         COMMENT '审批流编号，格式AF+yyyyMMdd+8位UUID-自动生成',
    flow_code        STRING         COMMENT '审批流唯一标识码（手动输入，如MERCHANT_ONBOARDING），业务方按此启动审批流',
    flow_name        STRING         COMMENT '审批流名称',
    flow_definition  STRING         COMMENT '审批节点定义JSON：{"steps":[{stepOrder,stepName,approverType(ROLE-角色，USER-用户，DEPT_LEADER-部门负责人),approverValue,condition(SpEL),timeoutHours,timeoutAction(AUTO_APPROVE-超时自动通过，AUTO_REJECT-超时自动拒绝，ESCALATE-超时升级)}]}',
    scope            STRING         COMMENT '范围：PLATFORM-平台，TENANT-租户',
    tenant_id        BIGINT         COMMENT '租户ID（scope=TENANT-租户时有效）',
    flow_status      STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    version          INT            COMMENT '版本号，同flowCode+scope+tenantId从1递增',
    version_status   STRING         COMMENT '版本状态：DRAFT-草稿，ACTIVE-有效，HISTORICAL-历史版本',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '审批流定义（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_approval_instance_di  审批实例 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_approval_instance_di (
    id                BIGINT         COMMENT '主键ID',
    instance_no       STRING         COMMENT '审批实例号，格式AI-AI 接入+yyyyMMdd+6位随机',
    flow_id           BIGINT         COMMENT '审批流ID（启动时绑定的具体审批流模板ID）',
    flow_code         STRING         COMMENT '审批流标识码（冗余，便于按code查询）',
    business_no       STRING         COMMENT '关联业务号（退款单号/提现单号等）',
    applicant_id      BIGINT         COMMENT '申请人ID',
    applicant_name    STRING         COMMENT '申请人姓名（快照，避免跨库查identity）',
    current_node      STRING         COMMENT '当前审批节点名称',
    business_context  STRING         COMMENT '审批内容快照JSON-业务方提供，前端审批工作台据此渲染审批详情：退什么/退多少/谁发起等',
    timeout_at        STRING         COMMENT '当前节点审批截止时间（XXL-JOB扫描超时处理）',
    instance_status   STRING         COMMENT '状态：PENDING-待处理，APPROVED-已通过，REJECTED-已拒绝，CANCELLED-已取消',
    tenant_id         BIGINT         COMMENT '租户ID',
    create_time       STRING         COMMENT '创建时间',
    update_time       STRING         COMMENT '更新时间',
    create_by         STRING         COMMENT '创建人',
    update_by         STRING         COMMENT '更新人',
    deleted           INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type    STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time       STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '审批实例（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_complaint_di  投诉工单 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_complaint_di (
    id                 BIGINT         COMMENT '主键ID',
    complaint_no       STRING         COMMENT '工单编号，格式CMP+yyyyMMdd+6位随机',
    complainant_type   STRING         COMMENT '投诉方：VISITOR-游客，MERCHANT-商户',
    complainant_id     BIGINT         COMMENT '投诉方ID',
    order_group_no     STRING         COMMENT '关联订单号（游客投诉时）',
    complaint_type     STRING         COMMENT '类型：ORDER_ISSUE-订单问题，SERVICE_ISSUE-服务问题，BUG-系统缺陷，OTHER-其他',
    complaint_content  STRING         COMMENT '投诉内容',
    handler_id         BIGINT         COMMENT '处理人ID',
    sla_deadline       STRING         COMMENT 'SLA截止时间',
    complaint_status   STRING         COMMENT '状态：PENDING-待处理，ASSIGNED-已分派，PROCESSING-处理中，RESOLVED-已解决，CLOSED-已关闭',
    tenant_id          BIGINT         COMMENT '租户ID',
    create_time        STRING         COMMENT '创建时间',
    update_time        STRING         COMMENT '更新时间',
    create_by          STRING         COMMENT '创建人',
    update_by          STRING         COMMENT '更新人',
    deleted            INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type     STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time        STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '投诉工单（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_i18n_language_df  支持语言 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_i18n_language_df (
    id                BIGINT         COMMENT '主键ID',
    locale_code       STRING         COMMENT '语言代码（zh-CN/en-US/ja-JP/ko-KR等）',
    language_name     STRING         COMMENT '语言名称（中文）',
    language_name_en  STRING         COMMENT '语言名称（英文）',
    language_status   STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    sort_order        INT            COMMENT '排序权重',
    create_time       STRING         COMMENT '创建时间',
    update_time       STRING         COMMENT '更新时间',
    create_by         STRING         COMMENT '创建人',
    update_by         STRING         COMMENT '更新人',
    deleted           INT            COMMENT '删除标记',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '支持语言（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_i18n_currency_df  支持币种 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_i18n_currency_df (
    id                    BIGINT         COMMENT '主键ID',
    currency_code         STRING         COMMENT '币种代码（CNY-人民币，USD，JPY，KRW等）',
    currency_name         STRING         COMMENT '币种名称（中文）',
    currency_name_en      STRING         COMMENT '币种名称（英文）',
    currency_symbol       STRING         COMMENT '币种符号（¥/$/¥/₩等）',
    exchange_rate_to_cny  DECIMAL(12,6)  COMMENT '对CNY-人民币汇率',
    currency_status       STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    create_by             STRING         COMMENT '创建人',
    update_by             STRING         COMMENT '更新人',
    deleted               INT            COMMENT '删除标记',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '支持币种（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_i18n_translation_df  翻译表 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_i18n_translation_df (
    id           BIGINT         COMMENT '主键ID',
    table_name   STRING         COMMENT '源表名（如t_spu/t_sku/t_sys_dict）',
    entity_id    BIGINT         COMMENT '源表实体ID',
    field_name   STRING         COMMENT '源表字段名（如spu_name/description）',
    locale       STRING         COMMENT '语言代码（zh-CN/en-US/ja-JP等）',
    field_value  STRING         COMMENT '翻译值',
    create_time  STRING         COMMENT '创建时间',
    update_time  STRING         COMMENT '更新时间',
    create_by    STRING         COMMENT '创建人',
    update_by    STRING         COMMENT '更新人',
    deleted      INT            COMMENT '删除标记',
    etl_time     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '翻译表（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_country_df  国家字典 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_country_df (
    id              BIGINT         COMMENT '主键ID',
    country_code    STRING         COMMENT '国家码 ISO 3166-1(如 CN，US，JP)',
    iso3_code       STRING         COMMENT '国家三字母码 ISO 3166-1(如 CHN，USA)',
    country_status  STRING         COMMENT '状态: ACTIVE-有效，INACTIVE-停用',
    sort_order      INT            COMMENT '排序权重',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '国家字典（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_region_df  地区字典 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_region_df (
    id             BIGINT         COMMENT '主键ID',
    region_code    STRING         COMMENT '行政区划码(国标,如 350203=思明区)',
    parent_id      BIGINT         COMMENT '上级地区ID,0=顶级',
    country_code   STRING         COMMENT '所属国家码(冗余,便于按国过滤)',
    region_level   INT            COMMENT '层级: 1=一级行政区(省/州/都道府县),2=市/郡,3=区县,4=乡镇,5=街道;不固化层级',
    region_path    STRING         COMMENT '完整路径含自身,如"中国/福建省/厦门市/思明区"',
    region_status  STRING         COMMENT '状态: ACTIVE-有效，INACTIVE-停用',
    sort_order     INT            COMMENT '排序权重',
    create_time    STRING         COMMENT '创建时间',
    update_time    STRING         COMMENT '更新时间',
    create_by      STRING         COMMENT '创建人',
    update_by      STRING         COMMENT '更新人',
    deleted        INT            COMMENT '软删除: 0未删/1已删',
    etl_time       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '地区字典（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_config_meta_df  配置元数据 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_config_meta_df (
    id               BIGINT         COMMENT '主键ID',
    config_scope     STRING         COMMENT '配置作用域: TENANT-租户配置，t_tenant_config，STAFF-员工配置，t_staff_config/...(未来扩展其他配置表时加枚举值)',
    config_key       STRING         COMMENT '配置键(TENANT-租户: currency/locale/timezone/supported_pay_methods; STAFF: mfa_enabled/login_2fa_confirm/session_timeout/ip_whitelist)',
    config_group     STRING         COMMENT '配置分组(不同scope下有不同分组): TENANT-租户→general/i18n/payment/notification/business; STAFF→security/session',
    value_type       STRING         COMMENT '值类型: STRING-字符串，BOOL-布尔，INT-整数，DECIMAL-小数，JSON-复杂结构或列表',
    validation_rule  STRING         COMMENT '校验规则(正则或枚举,如 "^(CNY-人民币|USD|JPY)$" 或 json schema 简述);由应用层 ConfigParser 执行',
    default_value    STRING         COMMENT '默认值(JSON编码)',
    description      STRING         COMMENT '配置说明',
    meta_status      STRING         COMMENT '状态: ACTIVE-有效，INACTIVE-停用',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    create_by        STRING         COMMENT '创建人',
    update_by        STRING         COMMENT '更新人',
    deleted          INT            COMMENT '软删除: 0未删/1已删',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '配置元数据（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_notify_template_df  通知模板 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_notify_template_df (
    id                   BIGINT         COMMENT '主键ID',
    template_no          STRING         COMMENT '模板编号，格式NT+yyyyMMdd+6位随机',
    template_code        STRING         COMMENT '模板代码（如ORDER_PAID_SMS/VERIFY_NOTICE_MINI）',
    template_name        STRING         COMMENT '模板名称',
    notify_channel       STRING         COMMENT '通知渠道：SMS-短信，MINI_PROGRAM_MSG-小程序消息，EMAIL-邮件，WEBHOOK-Webhook，IN_APP-站内信',
    template_content     STRING         COMMENT '模板内容（含变量占位符${xxx}）',
    template_content_en  STRING         COMMENT '英文模板内容（i18n）',
    scope                STRING         COMMENT '范围：PLATFORM-平台，TENANT-租户',
    tenant_id            BIGINT         COMMENT '租户ID',
    template_status      STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    create_by            STRING         COMMENT '创建人',
    update_by            STRING         COMMENT '更新人',
    deleted              INT            COMMENT '软删除: 0未删/1已删',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '通知模板（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_notify_record_di  通知记录 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_notify_record_di (
    id                   BIGINT         COMMENT '主键ID',
    notify_no            STRING         COMMENT '通知记录号，格式NR+yyyyMMdd+6位随机',
    template_id          BIGINT         COMMENT '模板ID',
    recipient_id         BIGINT         COMMENT '接收人ID',
    recipient_type       STRING         COMMENT '接收人类型：CUSTOMER-C端游客，TENANT_STAFF-B端员工，SYSTEM-系统',
    notify_channel       STRING         COMMENT '实际发送渠道',
    notify_content       STRING         COMMENT '实际发送内容（变量已替换）（脱敏）',
    related_business_no  STRING         COMMENT '关联业务号',
    send_status          STRING         COMMENT '状态：PENDING-待处理，SUCCESS-成功，FAILED-失败',
    send_time            STRING         COMMENT '发送时间',
    fail_reason          STRING         COMMENT '失败原因',
    tenant_id            BIGINT         COMMENT '租户ID',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    create_by            STRING         COMMENT '创建人',
    update_by            STRING         COMMENT '更新人',
    deleted              INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type       STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time          STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '通知记录（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_audit_log_di  审计日志 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_audit_log_di (
    id              BIGINT         COMMENT '主键ID',
    log_no          STRING         COMMENT '日志编号，格式AL+yyyyMMdd+6位随机',
    operator_id     BIGINT         COMMENT '操作人ID',
    operator_type   STRING         COMMENT '操作人类型：CUSTOMER-C端游客，TENANT_STAFF-B端员工，SYSTEM-系统，ANONYMOUS-匿名',
    action          STRING         COMMENT '操作动作（如PLACE_ORDER-下单，REFUND-退款，WITHDRAW-提现，MODIFY_BANK_CARD-修改银行卡）',
    resource_type   STRING         COMMENT '资源类型：ORDER-订单，PRODUCT-商品，ACCOUNT-账户，DEVICE-设备',
    resource_id     BIGINT         COMMENT '资源ID',
    detail          STRING         COMMENT '操作详情（变更前后对比等）',
    ip_address      STRING         COMMENT 'IP地址',
    tenant_id       BIGINT         COMMENT '租户ID',
    log_scope       STRING         COMMENT '日志范围：PLATFORM-平台，MERCHANT-商户',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    create_by       STRING         COMMENT '创建人',
    update_by       STRING         COMMENT '更新人',
    deleted         INT            COMMENT '软删除: 0未删/1已删',
    binlog_op_type  STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    binlog_time     STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '审计日志（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_app_definition_df  应用定义 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_app_definition_df (
    id           BIGINT         COMMENT '主键ID',
    app_no       STRING         COMMENT '应用编号，格式APP+yyyyMMdd+6位随机',
    app_name     STRING         COMMENT '应用名称',
    app_code     STRING         COMMENT '应用代码（唯一标识）',
    app_type     STRING         COMMENT '类型：BUILTIN-内置，THIRD_PARTY-第三方',
    description  STRING         COMMENT '应用描述',
    app_status   STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time  STRING         COMMENT '创建时间',
    update_time  STRING         COMMENT '更新时间',
    create_by    STRING         COMMENT '创建人',
    update_by    STRING         COMMENT '更新人',
    deleted      INT            COMMENT '软删除: 0未删/1已删',
    etl_time     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '应用定义（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_app_binding_df  套餐-应用绑定 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_app_binding_df (
    id           BIGINT         COMMENT '主键ID',
    package_id   BIGINT         COMMENT '套餐ID',
    app_id       BIGINT         COMMENT '应用ID',
    create_time  STRING         COMMENT '创建时间',
    update_time  STRING         COMMENT '更新时间',
    create_by    STRING         COMMENT '创建人',
    update_by    STRING         COMMENT '更新人',
    deleted      INT            COMMENT '软删除: 0未删/1已删',
    etl_time     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '套餐-应用绑定（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_opr_cdc_sync_task_df  CDC同步任务 ==========
CREATE TABLE IF NOT EXISTS ods.ods_opr_cdc_sync_task_df (
    id             BIGINT         COMMENT '主键ID',
    task_no        STRING         COMMENT '任务编号，格式CDC+yyyyMMdd+6位随机',
    source_table   STRING         COMMENT '源表名（如t_order/t_sku）',
    target_type    STRING         COMMENT '目标类型：ES-Elasticsearch，STARROCKS-StarRocks，KAFKA-Kafka',
    target_name    STRING         COMMENT '目标名称（ES-Elasticsearch索引/StarRocks表/Kafka Topic）',
    sync_mode      STRING         COMMENT '模式：REALTIME-实时，BATCH-整批',
    field_mapping  STRING         COMMENT '字段映射规则',
    task_status    STRING         COMMENT '状态：ACTIVE-有效，PAUSED-已暂停，ERROR-异常',
    last_sync_at   STRING         COMMENT '最后同步时间',
    create_time    STRING         COMMENT '创建时间',
    update_time    STRING         COMMENT '更新时间',
    create_by      STRING         COMMENT '创建人',
    update_by      STRING         COMMENT '更新人',
    deleted        INT            COMMENT '软删除: 0未删/1已删',
    etl_time       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'CDC同步任务（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== ods.ods_mkt_coupon_df  优惠券 ==========
CREATE TABLE IF NOT EXISTS ods.ods_mkt_coupon_df (
    id                  BIGINT         COMMENT '主键ID',
    coupon_no           STRING         COMMENT '优惠券编号，格式CPN+yyyyMMdd+6位随机',
    tenant_id           BIGINT         COMMENT '归属商户ID',
    coupon_name         STRING         COMMENT '优惠券名称',
    coupon_type         STRING         COMMENT '类型：FIXED_AMOUNT-满减固定金额，PERCENT_DISCOUNT-百分比折扣，FREE_VERIFY-免费核销',
    coupon_value        BIGINT         COMMENT '优惠值（分或百分比）',
    applicable_sku_ids  STRING         COMMENT '适用SKU列表（null=全部）',
    total_count         INT            COMMENT '发行总量',
    used_count          INT            COMMENT '已使用数量',
    effective_from      STRING         COMMENT '生效起始',
    effective_to        STRING         COMMENT '生效终止',
    coupon_status       STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用，EXPIRED-已过期',
    create_time         STRING         COMMENT '创建时间',
    update_time         STRING         COMMENT '更新时间',
    create_by           STRING         COMMENT '创建人',
    update_by           STRING         COMMENT '更新人',
    deleted             INT            COMMENT '软删除: 0未删/1已删',
    etl_time            STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '优惠券（同源表，1行=1条源记录）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

