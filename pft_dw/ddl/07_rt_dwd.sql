-- PFT 2.0 数仓 DDL：RT_DWD（6 张表）
-- 由 generator/make_all.py 生成，请勿手改

-- ========== dwd.dwd_ord_order_rt  实时下单明细 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE dwd.dwd_ord_order_rt (
    `order_id`              BIGINT         COMMENT '子单ID（源表主键 id）',
    `order_no`              STRING         COMMENT '子单号，由流水号生成器生成',
    `order_group_no`        STRING         COMMENT '归属聚合单号',
    `parent_order_no`       STRING         COMMENT '套票子单指向主单号，非套票=空串',
    `combo_type`            INT            COMMENT '是否套票主单：1=套票主单，0=普通子单或套票子项',
    `seller_tenant_id`      BIGINT         COMMENT '卖家商户ID',
    `sku_id`                BIGINT         COMMENT 'SKU ID',
    `sku_name`              STRING         COMMENT 'SKU名称（下单时快照）',
    `sku_version_no`        INT            COMMENT '下单时SKU版本号（查订单商品属性时按sku_id+sku_version还原）',
    `buy_ticket_qty`        INT            COMMENT '购买数量',
    `unit_price_amt`        DECIMAL(18,2)  COMMENT '单价（元）；套票主单=套餐总价，套票子单=分摊价；源字段单位为分，入仓 ÷100',
    `order_status`          STRING         COMMENT '状态：PENDING_PAY-待支付，PAID-已支付，PARTIALLY_VERIFIED-部分核销，FULLY_VERIFIED-已全部核销，REFUNDED-已退款，CANCELLED-已取消',
    `tenant_id`             BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`           STRING         COMMENT '创建时间',
    `update_time`           STRING         COMMENT '更新时间',
    `channel_id`            BIGINT         COMMENT '入口渠道ID，关联 dim_trf_channel_df',
    `channel_type`          STRING         COMMENT '入口渠道类型：MP-小程序，PC，API-API 接口，OFFLINE-线下或离线，H5',
    `app_code`              STRING         COMMENT '对接端标识（取自 t_channel.app_id）',
    `app_ref_code`          STRING         COMMENT '对接端引用',
    `operator_type`         STRING         COMMENT '操作人类型：CUSTOMER-C端游客，TENANT_STAFF-B端员工',
    `operator_id`           BIGINT         COMMENT '操作人ID（游客或员工）',
    `buyer_type`            STRING         COMMENT '付款方类型：CUSTOMER-C端游客，ANONYMOUS-匿名',
    `buyer_customer_id`     BIGINT         COMMENT '买家游客ID，关联 dim_cus_customer_zip',
    `currency_code`         STRING         COMMENT '币种编码，关联 dim_opr_currency_f',
    `spu_id`                BIGINT         COMMENT '产品(SPU)ID，关联 dim_prd_spu_zip',
    `product_type`          STRING         COMMENT '产品业态：SCENIC-景区门票，HOTEL-酒店，SHOW-演出/…',
    `play_date`             STRING         COMMENT '游玩日期，格式 yyyy-MM-dd',
    `time_slot_code`        STRING         COMMENT '游玩时段，如 10:00-11:00',
    `seat_zone_code`        STRING         COMMENT '座位区域，如 VIP',
    `order_amt`             DECIMAL(18,2)  COMMENT '子单金额（元）= 单价 × 购买数量',
    `cost_price_amt`        DECIMAL(18,2)  COMMENT '下单时 SKU 成本价（元）',
    `order_date`            STRING         COMMENT '下单日期，格式 yyyy-MM-dd',
    `pay_time`              STRING         COMMENT '支付成功时间；未支付为空',
    `cancel_time`           STRING         COMMENT '取消时间；未取消为空',
    `advance_book_day_qty`  BIGINT         COMMENT '提前预订天数 = 游玩日期 - 下单日期',
    `event_time`            STRING         COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`             AS PROCTIME()
) COMMENT '实时下单明细（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.dwd_ord_order_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_dwd_ord_order_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== dwd.dwd_fin_payment_rt  实时支付明细 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE dwd.dwd_fin_payment_rt (
    `payment_id`            BIGINT         COMMENT '支付记录ID（源表主键 id）',
    `payment_no`            STRING         COMMENT '支付流水号，由流水号生成器生成',
    `batch_no`              STRING         COMMENT '批量支付单号(同批共享),单条时空',
    `item_no`               STRING         COMMENT '批内项号(批内唯一,标识本条在批中的位置)',
    `depend_on_item_no`     STRING         COMMENT '依赖项号(必须在依赖项成功后执行,空=无依赖)',
    `order_group_no`        STRING         COMMENT '归属聚合单号',
    `pay_direction_type`    STRING         COMMENT '资金方向:INBOUND-收款，OUTBOUND-采购付款',
    `pay_method_type`       STRING         COMMENT '支付方式：BALANCE-余额，WECHAT-微信，ALIPAY-支付宝，CREDIT-授信，OFFLINE-线下或离线，ZERO_FEE-0元单等',
    `receive_channel_type`  STRING         COMMENT '收款渠道(INBOUND-收款时填):CASH-现金，WECHAT_QR-微信收款码，ALIPAY_QR-支付宝收款码，BANK_TRANSFER-银行转账，OFFLINE_SYSTEM_OUT-系统外已收',
    `pay_amt`               DECIMAL(18,2)  COMMENT '支付金额（元）；源字段单位为分，入仓 ÷100',
    `settle_amt`            DECIMAL(18,2)  COMMENT '结算金额（元，OUTBOUND-采购付款=向上采购价;INBOUND-收款=售价;利润=amount-settle_amount)；源字段单位为分，入仓 ÷100',
    `transaction_no`        STRING         COMMENT '渠道流水号（第三方回调返回或内部渠道同步生成）',
    `payer_account_no`      STRING         COMMENT '付款方账户(OUTBOUND-采购付款=采购方;INBOUND-收款=空)',
    `payee_account_no`      STRING         COMMENT '收款方账户(INBOUND-收款=卖方;OUTBOUND-采购付款=供应商)',
    `ticket_no`             STRING         COMMENT '关联票号(用于关联冻结记录)',
    `external_frozen_type`  INT            COMMENT '是否外部渠道冻结:1=第三方冻结(如易宝分账),0=平台内部冻结',
    `pay_time`              STRING         COMMENT '支付时间',
    `pay_status`            STRING         COMMENT '支付状态：CREATED-已创建，PAID-已支付，PARTIAL_REFUNDED-部分退款，REFUNDED-已退款',
    `tenant_id`             BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`           STRING         COMMENT '创建时间',
    `update_time`           STRING         COMMENT '更新时间',
    `seller_tenant_id`      BIGINT         COMMENT '卖家租户ID',
    `payer_tenant_id`       BIGINT         COMMENT '付款方租户ID',
    `payee_tenant_id`       BIGINT         COMMENT '收款方租户ID',
    `sku_id`                BIGINT         COMMENT 'SKU ID（按票关联）',
    `freeze_type`           STRING         COMMENT '冻结类型：PROFIT-利润，SETTLEMENT-采购款，FULL-全款',
    `profit_amt`            DECIMAL(18,2)  COMMENT '本级利润（元）= 支付金额 - 结算金额',
    `pay_date`              STRING         COMMENT '支付日期，格式 yyyy-MM-dd',
    `event_time`            STRING         COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`             AS PROCTIME()
) COMMENT '实时支付明细（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.dwd_fin_payment_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_dwd_fin_payment_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== dwd.dwd_ord_verify_rt  实时核销明细 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE dwd.dwd_ord_verify_rt (
    `verify_id`              BIGINT         COMMENT '核销记录ID（源表主键 id）',
    `verify_no`              STRING         COMMENT '核销记录号，格式VF+yyyyMMdd+6位随机',
    `ticket_no`              STRING         COMMENT '核销票号',
    `entitlement_no`         STRING         COMMENT '核销权益号',
    `verify_point_id`        BIGINT         COMMENT '核销点ID',
    `operator_id`            BIGINT         COMMENT '操作人ID',
    `device_id`              BIGINT         COMMENT '核销设备ID',
    `verify_type`            STRING         COMMENT '核销类型：ONLINE-在线，OFFLINE-线下或离线',
    `offline_device_time`    BIGINT         COMMENT '离线时序戳（离线核销时设备时间）',
    `verify_result_type`     STRING         COMMENT '结果：SUCCESS-成功，FAILED-失败，DUPLICATE-重复',
    `tenant_id`              BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`            STRING         COMMENT '创建时间（在线=服务器时间，离线=回连时间）',
    `update_time`            STRING         COMMENT '更新时间',
    `order_no`               STRING         COMMENT '所属子单号',
    `seller_tenant_id`       BIGINT         COMMENT '卖家租户ID',
    `sku_id`                 BIGINT         COMMENT 'SKU ID',
    `spu_id`                 BIGINT         COMMENT '产品(SPU)ID',
    `play_date`              STRING         COMMENT '游玩日期',
    `entitlement_type`       STRING         COMMENT '权益类型：FIXED-固定，COUNTED-计次型，SELECTABLE-选择型，TIMED-计时型，QUOTA-额度型，UNLIMITED-不限次型',
    `verify_point_type`      STRING         COMMENT '核销点类型：GATE-闸机，COUNTER-窗口，SELF_SERVICE-自助机，HANDHELD-手持机',
    `device_type`            STRING         COMMENT '设备类型：GATE-闸机，POS-POS 机，HANDHELD-手持机，SELF_SERVICE-自助机，KIOSK-自助终端，FACE_RECOGNITION-人脸识别机',
    `verify_time`            STRING         COMMENT '核销时间，格式 yyyy-MM-dd HH:mm:ss',
    `verify_hour_no`         INT            COMMENT '核销小时：0~23',
    `verify_person_qty`      BIGINT         COMMENT '本次核销人数',
    `verify_qty`             BIGINT         COMMENT '核销次数，固定为 1',
    `verify_amt`             DECIMAL(18,2)  COMMENT '核销金额（元，按票分摊单价 ÷ 可核销次数）',
    `offline_conflict_type`  INT            COMMENT '是否离线冲突：0-否，1-是（离线核销回传时票已被核销）',
    `event_time`             STRING         COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`              AS PROCTIME()
) COMMENT '实时核销明细（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.dwd_ord_verify_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_dwd_ord_verify_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== dwd.dwd_ord_refund_rt  实时退款明细 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE dwd.dwd_ord_refund_rt (
    `refund_id`           BIGINT         COMMENT '退款单ID（源表主键 id）',
    `refund_no`           STRING         COMMENT '退款单号，格式REF+yyyyMMdd+6位随机',
    `order_group_no`      STRING         COMMENT '归属聚合单号',
    `refund_type`         STRING         COMMENT '退款类型：ORDER_REFUND-订单退款，COMPENSATION-售后补偿，PARTIAL_REFUND-部分退款',
    `refund_reason_desc`  STRING         COMMENT '退款原因',
    `refund_amt`          DECIMAL(18,2)  COMMENT '退款总金额（元）；源字段单位为分，入仓 ÷100',
    `refund_status`       STRING         COMMENT '状态：PENDING-待处理，APPROVED-已通过，PROCESSING-处理中，COMPLETED-已完成，REJECTED-已拒绝',
    `initiator_type`      STRING         COMMENT '发起方：VISITOR-游客，MERCHANT-商户，PLATFORM-平台，SYSTEM-系统，OTA',
    `initiator_id`        BIGINT         COMMENT '发起方ID',
    `approver_id`         BIGINT         COMMENT '审批人ID',
    `approve_time`        STRING         COMMENT '审批时间',
    `tenant_id`           BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`         STRING         COMMENT '创建时间',
    `update_time`         STRING         COMMENT '更新时间',
    `seller_tenant_id`    BIGINT         COMMENT '卖家租户ID',
    `channel_id`          BIGINT         COMMENT '入口渠道ID',
    `apply_time`          STRING         COMMENT '退款申请时间',
    `finish_time`         STRING         COMMENT '退款完成时间；未完成为空',
    `process_hour_qty`    DECIMAL(18,2)  COMMENT '退款处理时长（小时）= 完成时间 - 申请时间',
    `refund_ticket_qty`   BIGINT         COMMENT '退款票数',
    `event_time`          STRING         COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`           AS PROCTIME()
) COMMENT '实时退款明细（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.dwd_ord_refund_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_dwd_ord_refund_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== dwd.dwd_inv_pool_change_rt  实时库存变动 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE dwd.dwd_inv_pool_change_rt (
    `pool_id`               BIGINT         COMMENT '库存池ID（源表主键 id）',
    `pool_no`               STRING         COMMENT '库存池编号，由流水号生成器生成',
    `sku_id`                BIGINT         COMMENT 'SKU ID',
    `pool_type`             STRING         COMMENT '池类型：COUNTING-可数池，UNIT-可标识池',
    `pool_status`           STRING         COMMENT '池状态：ON_SALE-在售，STOP_SALE-停售，EXPIRED-已过期',
    `tenant_id`             BIGINT         COMMENT '租户ID（分库维度）',
    `create_time`           STRING         COMMENT '创建时间',
    `update_time`           STRING         COMMENT '更新时间',
    `change_type`           STRING         COMMENT '变动类型：PRE_DEDUCT-预扣，CONFIRM-确认，ROLLBACK-回滚，ADJUST-调整',
    `order_no`              STRING         COMMENT '引起变动的子单号；人工调整为空',
    `play_date`             STRING         COMMENT '库存日期',
    `room_type_code`        STRING         COMMENT '房型编码（酒店）',
    `show_time`             STRING         COMMENT '场次时间（演出）',
    `before_total_qty`      BIGINT         COMMENT '变动前总库存',
    `after_total_qty`       BIGINT         COMMENT '变动后总库存',
    `total_change_qty`      BIGINT         COMMENT '总库存变化量',
    `available_change_qty`  BIGINT         COMMENT '可售库存变化量',
    `frozen_change_qty`     BIGINT         COMMENT '冻结库存变化量',
    `change_time`           STRING         COMMENT '变动时间',
    `event_time`            STRING         COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss',
    `proc_time`             AS PROCTIME()
) COMMENT '实时库存变动（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.dwd_inv_pool_change_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_dwd_inv_pool_change_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

-- ========== dwd.dwd_opr_risk_event_rt  实时风控事件 ==========
-- Flink SQL（Kafka 源/汇表）
CREATE TABLE dwd.dwd_opr_risk_event_rt (
    `risk_event_id`         BIGINT         COMMENT '风控事件ID（源表主键 id）',
    `event_no`              STRING         COMMENT '事件编号，格式RE+yyyyMMdd+6位随机',
    `event_type`            STRING         COMMENT '类型：RULE_HIT-规则命中，MANUAL_BAN-人工封禁，MANUAL_UNBAN-人工解封，ABNORMAL_OP_DETECTED-检测到异常操作',
    `subject_id`            BIGINT         COMMENT '主体ID（用户/商户）',
    `dimension_value_desc`  STRING         COMMENT '触发维度值集合',
    `rule_id`               BIGINT         COMMENT '关联规则ID',
    `action_type`           STRING         COMMENT '执行动作：BLOCK-拦截，WARN-预警，FREEZE-冻结',
    `detail_desc`           STRING         COMMENT '详细描述',
    `audit_log_id`          BIGINT         COMMENT '关联审计日志ID',
    `tenant_id`             BIGINT         COMMENT '租户ID',
    `create_time`           STRING         COMMENT '创建时间',
    `update_time`           STRING         COMMENT '更新时间',
    `rule_type`             STRING         COMMENT '规则类型：BLACKLIST-黑名单，PURCHASE_LIMIT-购买限制，GEO_FENCE-地理围栏，ABNORMAL_OP-异常操作，DEFAULT_BREAK-爽约',
    `dimension_type`        STRING         COMMENT '规则维度：USER_ID-用户ID，ID_CARD-身份证，PHONE-手机号，IP，DEVICE_ID-设备ID',
    `event_time`            STRING         COMMENT '事件发生时间',
    `event_qty`             BIGINT         COMMENT '事件数，固定为 1',
    `proc_time`             AS PROCTIME()
) COMMENT '实时风控事件（1行=1条事件/1个窗口）'
WITH (
    'connector' = 'kafka',
    'topic' = 'pft_dw.dwd_opr_risk_event_rt',
    'properties.bootstrap.servers' = '${kafka.servers}',
    'properties.group.id' = 'pft_dw_dwd_opr_risk_event_rt',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json'
);

