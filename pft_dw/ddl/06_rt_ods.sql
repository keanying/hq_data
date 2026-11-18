-- PFT 2.0 数仓 DDL：RT_ODS（9 张表）
-- 由 generator/make_all.py 生成，请勿手改

-- ========== ods.ods_ord_order_group_rt  聚合单 binlog 流 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE ods.ods_ord_order_group_rt (
    `id`                  BIGINT         COMMENT '主键ID',
    `order_group_no`      STRING         COMMENT '聚合单号，支付幂等键来源，由流水号生成器生成',
    `seller_tenant_id`    BIGINT         COMMENT '卖家租户ID（商品归属租户，聚合单层冗余，子单同值）',
    `channel_id`          BIGINT         COMMENT '入口端ID（指向 t_channel.id：MP_TENANT_HOSTED-租户托管小程序，MP_PLATFORM-平台小程序，PC_TENANT-租户后台，PC_PLATFORM-平台后台，OFFLINE-线下或离线，API_XXX）',
    `app_id`              STRING         COMMENT '对接端标识（指向t_channel.app_id，标识订单组创建来源端；空串=未指定，历史数据兼容）',
    `app_ref`             STRING         COMMENT '对接端自定义子标识（app_id对应）：小程序=tenant_mp_config_id字符串；API-API 接口=子渠道号；其他=空串',
    `operator_type`       STRING         COMMENT '操作人类型：CUSTOMER-C端会员，TENANT_STAFF-B端员工含平台员工',
    `operator_id`         BIGINT         COMMENT '操作人ID（多态：customer_id 或 tenant_staff_id）',
    `operator_tenant_id`  BIGINT         COMMENT '操作人所属租户ID（=会话tenant_context_id；C端时=渠道端所属租户或=seller_tenant_id）',
    `buyer_type`          STRING         COMMENT '付款方类型：CUSTOMER-会员或租户默认散客占位，ANONYMOUS-线下现金无主体',
    `buyer_id`            BIGINT         COMMENT '付款方ID（多态；ANONYMOUS-匿名时=0）',
    `buyer_customer_id`   BIGINT         COMMENT 'C端筛选冗余：buyer_type=CUSTOMER-C端游客时=buyer_id，否则0（带索引报表用）',
    `contact_name`        STRING         COMMENT '联系人姓名',
    `contact_phone`       STRING         COMMENT '联系人手机（脱敏）',
    `contact_id_type`     STRING         COMMENT '联系人证件类型：ID_CARD-身份证，PASSPORT-护照等',
    `contact_id_number`   STRING         COMMENT '联系人证件号（脱敏）',
    `total_amount`        BIGINT         COMMENT '总金额（分）',
    `currency`            STRING         COMMENT '币种（=商户配置币种；MVP不做换算）',
    `pay_status`          STRING         COMMENT '支付状态：UNPAID-未支付，PARTIAL_PAID-部分支付，PAID-已支付',
    `pay_timeout_at`      STRING         COMMENT '支付超时截止时间（SKU票属性PAY_TIMEOUT-支付超时驱动，毫秒精度）',
    `tenant_id`           BIGINT         COMMENT '租户ID（分库维度，=seller_tenant_id）',
    `create_time`         STRING         COMMENT '创建时间',
    `update_time`         STRING         COMMENT '更新时间',
    `create_by`           STRING         COMMENT '创建人',
    `update_by`           STRING         COMMENT '更新人',
    `deleted`             INT            COMMENT '软删除: 0未删/1已删',
    `binlog_op_type`      STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    `binlog_time`         STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`           AS PROCTIME()
) COMMENT '聚合单 binlog 流（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.ods_ord_order_group_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_ods_ord_order_group_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== ods.ods_ord_order_rt  子单 binlog 流 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE ods.ods_ord_order_rt (
    `id`                BIGINT         COMMENT '主键ID',
    `order_no`          STRING         COMMENT '子单号，由流水号生成器生成',
    `order_group_no`    STRING         COMMENT '归属聚合单号',
    `parent_order_no`   STRING         COMMENT '套票子单指向主单号，非套票=空串',
    `combo_flag`        INT            COMMENT '是否套票主单：1=套票主单，0=普通子单或套票子项',
    `seller_tenant_id`  BIGINT         COMMENT '卖家商户ID',
    `sku_id`            BIGINT         COMMENT 'SKU ID',
    `sku_name`          STRING         COMMENT 'SKU名称（下单时快照）',
    `sku_version`       INT            COMMENT '下单时SKU版本号（查订单商品属性时按sku_id+sku_version还原）',
    `quantity`          INT            COMMENT '购买数量',
    `unit_price`        BIGINT         COMMENT '单价（分）；套票主单=套餐总价，套票子单=分摊价',
    `sale_dims`         STRING         COMMENT '用户选择的售卖维度快照：{date:"2026-07-05", timeSlot:"10:00-11:00", seatZone:"VIP"}',
    `order_status`      STRING         COMMENT '状态：PENDING_PAY-待支付，PAID-已支付，PARTIALLY_VERIFIED-部分核销，FULLY_VERIFIED-已全部核销，REFUNDED-已退款，CANCELLED-已取消',
    `tenant_id`         BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`       STRING         COMMENT '创建时间',
    `update_time`       STRING         COMMENT '更新时间',
    `create_by`         STRING         COMMENT '创建人',
    `update_by`         STRING         COMMENT '更新人',
    `deleted`           INT            COMMENT '软删除: 0未删/1已删',
    `binlog_op_type`    STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    `binlog_time`       STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`         AS PROCTIME()
) COMMENT '子单 binlog 流（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.ods_ord_order_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_ods_ord_order_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== ods.ods_ord_entitlement_rt  权益 binlog 流 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE ods.ods_ord_entitlement_rt (
    `id`                  BIGINT         COMMENT '主键ID',
    `entitlement_no`      STRING         COMMENT '权益号，由流水号生成器生成',
    `ticket_no`           STRING         COMMENT '归属票号',
    `entitlement_type`    STRING         COMMENT '权益类型：FIXED-固定，SELECTABLE-选择型，COUNTED-计次型，TIMED-计时型，UNLIMITED-不限次型，QUOTA-额度型',
    `entitlement_name`    STRING         COMMENT '权益名称（如"成人入园""住宿1晚"）',
    `status`              STRING         COMMENT '权益状态：ACTIVE-有效，USED-已使用，EXPIRED-已过期，REFUNDED-已退款',
    `used_count`          INT            COMMENT '已用次数（所有类型共有）',
    `entitlement_detail`  STRING         COMMENT '权益详情（类型特有参数，JSON自描述，新增类型只需扩展schema不加DDL字段。示例：COUNTED-计次型→{"maxCount":5}；SELECTABLE-选择型→{"maxCount":2,"candidateRefs":["ENT-001"]}；TIMED-计时型→{"durationMinutes":480}；QUOTA-额度型→{"quotaAmount":50000}；FIXED-固定，UNLIMITED-不限次型→{}）',
    `valid_start`         STRING         COMMENT '权益有效期起始（可收窄于票有效期，毫秒精度）',
    `valid_end`           STRING         COMMENT '权益有效期终止（毫秒精度）',
    `tenant_id`           BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`         STRING         COMMENT '创建时间',
    `update_time`         STRING         COMMENT '更新时间',
    `create_by`           STRING         COMMENT '创建人',
    `update_by`           STRING         COMMENT '更新人',
    `deleted`             INT            COMMENT '软删除: 0未删/1已删',
    `binlog_op_type`      STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    `binlog_time`         STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`           AS PROCTIME()
) COMMENT '权益 binlog 流（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.ods_ord_entitlement_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_ods_ord_entitlement_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== ods.ods_ord_verify_record_rt  核销记录 binlog 流 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE ods.ods_ord_verify_record_rt (
    `id`                 BIGINT         COMMENT '主键ID',
    `verify_no`          STRING         COMMENT '核销记录号，格式VF+yyyyMMdd+6位随机',
    `ticket_no`          STRING         COMMENT '核销票号',
    `entitlement_no`     STRING         COMMENT '核销权益号',
    `verify_point_id`    BIGINT         COMMENT '核销点ID',
    `operator_id`        BIGINT         COMMENT '操作人ID',
    `device_id`          BIGINT         COMMENT '核销设备ID',
    `verify_type`        STRING         COMMENT '核销类型：ONLINE-在线，OFFLINE-线下或离线',
    `offline_timestamp`  BIGINT         COMMENT '离线时序戳（离线核销时设备时间）',
    `verify_result`      STRING         COMMENT '结果：SUCCESS-成功，FAILED-失败，DUPLICATE-重复',
    `tenant_id`          BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`        STRING         COMMENT '创建时间（在线=服务器时间，离线=回连时间）',
    `update_time`        STRING         COMMENT '更新时间',
    `create_by`          STRING         COMMENT '创建人',
    `update_by`          STRING         COMMENT '更新人',
    `deleted`            INT            COMMENT '软删除: 0未删/1已删',
    `binlog_op_type`     STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    `binlog_time`        STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`          AS PROCTIME()
) COMMENT '核销记录 binlog 流（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.ods_ord_verify_record_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_ods_ord_verify_record_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== ods.ods_ord_refund_order_rt  退款单 binlog 流 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE ods.ods_ord_refund_order_rt (
    `id`              BIGINT         COMMENT '主键ID',
    `refund_no`       STRING         COMMENT '退款单号，格式REF+yyyyMMdd+6位随机',
    `order_group_no`  STRING         COMMENT '归属聚合单号',
    `refund_type`     STRING         COMMENT '退款类型：ORDER_REFUND-订单退款，COMPENSATION-售后补偿，PARTIAL_REFUND-部分退款',
    `refund_reason`   STRING         COMMENT '退款原因',
    `refund_amount`   BIGINT         COMMENT '退款总金额（分）',
    `refund_status`   STRING         COMMENT '状态：PENDING-待处理，APPROVED-已通过，PROCESSING-处理中，COMPLETED-已完成，REJECTED-已拒绝',
    `refund_items`    STRING         COMMENT '退款明细：[{orderNo, ticketNos[], amount}]',
    `initiator_type`  STRING         COMMENT '发起方：VISITOR-游客，MERCHANT-商户，PLATFORM-平台，SYSTEM-系统，OTA',
    `initiator_id`    BIGINT         COMMENT '发起方ID',
    `approver_id`     BIGINT         COMMENT '审批人ID',
    `approve_time`    STRING         COMMENT '审批时间',
    `tenant_id`       BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`     STRING         COMMENT '创建时间',
    `update_time`     STRING         COMMENT '更新时间',
    `create_by`       STRING         COMMENT '创建人',
    `update_by`       STRING         COMMENT '更新人',
    `deleted`         INT            COMMENT '软删除: 0未删/1已删',
    `binlog_op_type`  STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    `binlog_time`     STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`       AS PROCTIME()
) COMMENT '退款单 binlog 流（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.ods_ord_refund_order_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_ods_ord_refund_order_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== ods.ods_fin_payment_record_rt  支付记录 binlog 流 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE ods.ods_fin_payment_record_rt (
    `id`                   BIGINT         COMMENT '主键ID',
    `payment_no`           STRING         COMMENT '支付流水号，由流水号生成器生成',
    `batch_no`             STRING         COMMENT '批量支付单号(同批共享),单条时空',
    `item_no`              STRING         COMMENT '批内项号(批内唯一,标识本条在批中的位置)',
    `depend_on_item`       STRING         COMMENT '依赖项号(必须在依赖项成功后执行,空=无依赖)',
    `order_group_no`       STRING         COMMENT '归属聚合单号',
    `pay_direction`        STRING         COMMENT '资金方向:INBOUND-收款，OUTBOUND-采购付款',
    `pay_method`           STRING         COMMENT '支付方式：BALANCE-余额，WECHAT-微信，ALIPAY-支付宝，CREDIT-授信，OFFLINE-线下或离线，ZERO_FEE-0元单等',
    `receive_channel`      STRING         COMMENT '收款渠道(INBOUND-收款时填):CASH-现金，WECHAT_QR-微信收款码，ALIPAY_QR-支付宝收款码，BANK_TRANSFER-银行转账，OFFLINE_SYSTEM_OUT-系统外已收',
    `amount`               BIGINT         COMMENT '支付金额（分）',
    `settle_amount`        BIGINT         COMMENT '结算金额(分,OUTBOUND-采购付款=向上采购价;INBOUND-收款=售价;利润=amount-settle_amount)',
    `transaction_no`       STRING         COMMENT '渠道流水号（第三方回调返回或内部渠道同步生成）',
    `payer_account_no`     STRING         COMMENT '付款方账户(OUTBOUND-采购付款=采购方;INBOUND-收款=空)',
    `payee_account_no`     STRING         COMMENT '收款方账户(INBOUND-收款=卖方;OUTBOUND-采购付款=供应商)',
    `ticket_no`            STRING         COMMENT '关联票号(用于关联冻结记录)',
    `freeze_instructions`  STRING         COMMENT '冻结指令快照:[{ticketNo,accountNo,amount,freezeType}]',
    `external_frozen`      INT            COMMENT '是否外部渠道冻结:1=第三方冻结(如易宝分账),0=平台内部冻结',
    `pay_time`             STRING         COMMENT '支付时间',
    `pay_status`           STRING         COMMENT '支付状态：CREATED-已创建，PAID-已支付，PARTIAL_REFUNDED-部分退款，REFUNDED-已退款',
    `tenant_id`            BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`          STRING         COMMENT '创建时间',
    `update_time`          STRING         COMMENT '更新时间',
    `create_by`            STRING         COMMENT '创建人',
    `update_by`            STRING         COMMENT '更新人',
    `deleted`              INT            COMMENT '软删除: 0未删/1已删',
    `binlog_op_type`       STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    `binlog_time`          STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`            AS PROCTIME()
) COMMENT '支付记录 binlog 流（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.ods_fin_payment_record_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_ods_fin_payment_record_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== ods.ods_inv_inventory_pool_rt  库存池 binlog 流 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE ods.ods_inv_inventory_pool_rt (
    `id`                  BIGINT         COMMENT '主键ID',
    `pool_no`             STRING         COMMENT '库存池编号，由流水号生成器生成',
    `sku_id`              BIGINT         COMMENT 'SKU ID',
    `pool_type`           STRING         COMMENT '池类型：COUNTING-可数池，UNIT-可标识池',
    `dimension_key`       STRING         COMMENT '维度键组合（如date/roomType/showTime等）',
    `total_quantity`      BIGINT         COMMENT '总量（COUNTING-可数池池）',
    `available_quantity`  BIGINT         COMMENT '可用量（实时）',
    `frozen_quantity`     BIGINT         COMMENT '预扣冻结量',
    `pool_status`         STRING         COMMENT '池状态：ON_SALE-在售，STOP_SALE-停售，EXPIRED-已过期',
    `tenant_id`           BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`         STRING         COMMENT '创建时间',
    `update_time`         STRING         COMMENT '更新时间',
    `create_by`           STRING         COMMENT '创建人',
    `update_by`           STRING         COMMENT '更新人',
    `deleted`             INT            COMMENT '软删除: 0未删/1已删',
    `binlog_op_type`      STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    `binlog_time`         STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`           AS PROCTIME()
) COMMENT '库存池 binlog 流（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.ods_inv_inventory_pool_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_ods_inv_inventory_pool_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== ods.ods_inv_inventory_unit_rt  座位/房间 binlog 流 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE ods.ods_inv_inventory_unit_rt (
    `id`              BIGINT         COMMENT '主键ID',
    `unit_no`         STRING         COMMENT '资源个体编号（座位号/房号/舱位号）',
    `pool_no`         STRING         COMMENT '归属库存池编号',
    `unit_status`     STRING         COMMENT '状态：AVAILABLE-可用，FROZEN-冻结中，OCCUPIED-已占用',
    `order_no`        STRING         COMMENT '锁定子单号（FROZEN-冻结中，OCCUPIED-已占用时）',
    `metadata`        STRING         COMMENT '资源属性（座位等级/房型等）',
    `tenant_id`       BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`     STRING         COMMENT '创建时间',
    `update_time`     STRING         COMMENT '更新时间',
    `create_by`       STRING         COMMENT '创建人',
    `update_by`       STRING         COMMENT '更新人',
    `deleted`         INT            COMMENT '软删除: 0未删/1已删',
    `binlog_op_type`  STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    `binlog_time`     STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`       AS PROCTIME()
) COMMENT '座位/房间 binlog 流（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.ods_inv_inventory_unit_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_ods_inv_inventory_unit_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== ods.ods_opr_risk_event_rt  风控事件 binlog 流 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE ods.ods_opr_risk_event_rt (
    `id`                BIGINT         COMMENT '主键ID',
    `event_no`          STRING         COMMENT '事件编号，格式RE+yyyyMMdd+6位随机',
    `event_type`        STRING         COMMENT '类型：RULE_HIT-规则命中，MANUAL_BAN-人工封禁，MANUAL_UNBAN-人工解封，ABNORMAL_OP_DETECTED-检测到异常操作',
    `subject_id`        BIGINT         COMMENT '主体ID（用户/商户）',
    `dimension_values`  STRING         COMMENT '触发维度值集合',
    `rule_id`           BIGINT         COMMENT '关联规则ID',
    `action`            STRING         COMMENT '执行动作：BLOCK-拦截，WARN-预警，FREEZE-冻结',
    `detail`            STRING         COMMENT '详细描述',
    `audit_log_id`      BIGINT         COMMENT '关联审计日志ID',
    `tenant_id`         BIGINT         COMMENT '租户ID',
    `create_time`       STRING         COMMENT '创建时间',
    `update_time`       STRING         COMMENT '更新时间',
    `create_by`         STRING         COMMENT '创建人',
    `update_by`         STRING         COMMENT '更新人',
    `deleted`           INT            COMMENT '软删除: 0未删/1已删',
    `binlog_op_type`    STRING         COMMENT '变更类型：I-新增，U-更新，D-删除（取自 binlog）',
    `binlog_time`       STRING         COMMENT 'binlog 变更时间，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`         AS PROCTIME()
) COMMENT '风控事件 binlog 流（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.ods_opr_risk_event_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_ods_opr_risk_event_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

