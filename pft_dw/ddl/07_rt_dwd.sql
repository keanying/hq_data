-- PFT 2.0 数仓 DDL：RT_DWD（14 张表）
-- 由 generator/make_all.py 生成，请勿手改

-- ========== dwd.dwd_ord_order_rt  实时下单明细 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_order_rt (
    `travel_date`           VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取创建时间日期，保证同一主键始终落在同一分区',
    `order_id`              BIGINT         NOT NULL COMMENT '子单ID（源表主键 id）',
    `order_no`              VARCHAR(32)    NULL     COMMENT '子单号，由流水号生成器生成',
    `order_group_no`        VARCHAR(32)    NULL     COMMENT '归属聚合单号',
    `parent_order_no`       VARCHAR(32)    NULL     COMMENT '套票子单指向主单号，非套票=空串',
    `combo_type`            INT            NULL     COMMENT '是否套票主单：1=套票主单，0=普通子单或套票子项',
    `seller_tenant_id`      BIGINT         NULL     COMMENT '卖家商户ID',
    `sku_id`                BIGINT         NULL     COMMENT 'SKU ID',
    `sku_name`              VARCHAR(256)   NULL     COMMENT 'SKU名称（下单时快照）',
    `sku_version_no`        INT            NULL     COMMENT '下单时SKU版本号（查订单商品属性时按sku_id+sku_version还原）',
    `buy_ticket_qty`        INT            NULL     COMMENT '购买数量',
    `unit_price_amt`        DECIMAL(18,2)  NULL     COMMENT '单价（元）；套票主单=套餐总价，套票子单=分摊价；源字段单位为分，入仓 ÷100',
    `order_status`          VARCHAR(32)    NULL     COMMENT '状态：PENDING_PAY-待支付，PAID-已支付，PARTIALLY_VERIFIED-部分核销，FULLY_VERIFIED-已全部核销，REFUNDED-已退款，CANCELLED-已取消',
    `tenant_id`             BIGINT         NULL     COMMENT '租户ID（分库维度）',
    `create_time`           VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`           VARCHAR(32)    NULL     COMMENT '更新时间',
    `channel_id`            BIGINT         NULL     COMMENT '入口渠道ID，关联 dim_trf_channel_df',
    `channel_type`          VARCHAR(32)    NULL     COMMENT '入口渠道类型：MP-小程序，PC，API-API 接口，OFFLINE-线下或离线，H5',
    `app_code`              VARCHAR(32)    NULL     COMMENT '对接端标识（取自 t_channel.app_id）',
    `app_ref_code`          VARCHAR(32)    NULL     COMMENT '对接端引用',
    `operator_type`         VARCHAR(32)    NULL     COMMENT '操作人类型：CUSTOMER-C端游客，TENANT_STAFF-B端员工',
    `operator_id`           BIGINT         NULL     COMMENT '操作人ID（游客或员工）',
    `buyer_type`            VARCHAR(32)    NULL     COMMENT '付款方类型：CUSTOMER-C端游客，ANONYMOUS-匿名',
    `buyer_customer_id`     BIGINT         NULL     COMMENT '买家游客ID，关联 dim_cus_customer_zip',
    `currency_code`         VARCHAR(32)    NULL     COMMENT '币种编码，关联 dim_opr_currency_f',
    `spu_id`                BIGINT         NULL     COMMENT '产品(SPU)ID，关联 dim_prd_spu_zip',
    `product_type`          VARCHAR(32)    NULL     COMMENT '产品业态：SCENIC-景区门票，HOTEL-酒店，SHOW-演出/…',
    `play_date`             VARCHAR(32)    NULL     COMMENT '游玩日期，格式 yyyy-MM-dd',
    `time_slot_code`        VARCHAR(32)    NULL     COMMENT '游玩时段，如 10:00-11:00',
    `seat_zone_code`        VARCHAR(32)    NULL     COMMENT '座位区域，如 VIP',
    `order_amt`             DECIMAL(18,2)  NULL     COMMENT '子单金额（元）= 单价 × 购买数量',
    `cost_price_amt`        DECIMAL(18,2)  NULL     COMMENT '下单时 SKU 成本价（元）',
    `order_date`            VARCHAR(32)    NULL     COMMENT '下单日期，格式 yyyy-MM-dd',
    `pay_time`              VARCHAR(32)    NULL     COMMENT '支付成功时间；未支付为空',
    `cancel_time`           VARCHAR(32)    NULL     COMMENT '取消时间；未取消为空',
    `advance_book_day_qty`  BIGINT         NULL     COMMENT '提前预订天数 = 游玩日期 - 下单日期',
    `event_time`            VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `order_id`)
COMMENT '实时下单明细（1行=1个子单（order_no））'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`order_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_fin_payment_rt  实时支付明细 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_fin_payment_rt (
    `travel_date`           VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取创建时间日期，保证同一主键始终落在同一分区',
    `payment_id`            BIGINT         NOT NULL COMMENT '支付记录ID（源表主键 id）',
    `payment_no`            VARCHAR(32)    NULL     COMMENT '支付流水号，由流水号生成器生成',
    `batch_no`              VARCHAR(32)    NULL     COMMENT '批量支付单号(同批共享),单条时空',
    `item_no`               VARCHAR(32)    NULL     COMMENT '批内项号(批内唯一,标识本条在批中的位置)',
    `depend_on_item_no`     VARCHAR(32)    NULL     COMMENT '依赖项号(必须在依赖项成功后执行,空=无依赖)',
    `order_group_no`        VARCHAR(32)    NULL     COMMENT '归属聚合单号',
    `pay_direction_type`    VARCHAR(32)    NULL     COMMENT '资金方向:INBOUND-收款，OUTBOUND-采购付款',
    `pay_method_type`       VARCHAR(32)    NULL     COMMENT '支付方式：BALANCE-余额，WECHAT-微信，ALIPAY-支付宝，CREDIT-授信，OFFLINE-线下或离线，ZERO_FEE-0元单等',
    `receive_channel_type`  VARCHAR(32)    NULL     COMMENT '收款渠道(INBOUND-收款时填):CASH-现金，WECHAT_QR-微信收款码，ALIPAY_QR-支付宝收款码，BANK_TRANSFER-银行转账，OFFLINE_SYSTEM_OUT-系统外已收',
    `pay_amt`               DECIMAL(18,2)  NULL     COMMENT '支付金额（元）；源字段单位为分，入仓 ÷100',
    `settle_amt`            DECIMAL(18,2)  NULL     COMMENT '结算金额（元，OUTBOUND-采购付款=向上采购价;INBOUND-收款=售价;利润=amount-settle_amount)；源字段单位为分，入仓 ÷100',
    `transaction_no`        VARCHAR(32)    NULL     COMMENT '渠道流水号（第三方回调返回或内部渠道同步生成）',
    `payer_account_no`      VARCHAR(32)    NULL     COMMENT '付款方账户(OUTBOUND-采购付款=采购方;INBOUND-收款=空)',
    `payee_account_no`      VARCHAR(32)    NULL     COMMENT '收款方账户(INBOUND-收款=卖方;OUTBOUND-采购付款=供应商)',
    `ticket_no`             VARCHAR(32)    NULL     COMMENT '关联票号(用于关联冻结记录)',
    `external_frozen_type`  INT            NULL     COMMENT '是否外部渠道冻结:1=第三方冻结(如易宝分账),0=平台内部冻结',
    `pay_time`              VARCHAR(32)    NULL     COMMENT '支付时间',
    `pay_status`            VARCHAR(32)    NULL     COMMENT '支付状态：CREATED-已创建，PAID-已支付，PARTIAL_REFUNDED-部分退款，REFUNDED-已退款',
    `tenant_id`             BIGINT         NULL     COMMENT '租户ID（分库维度）',
    `create_time`           VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`           VARCHAR(32)    NULL     COMMENT '更新时间',
    `seller_tenant_id`      BIGINT         NULL     COMMENT '卖家租户ID',
    `payer_tenant_id`       BIGINT         NULL     COMMENT '付款方租户ID',
    `payee_tenant_id`       BIGINT         NULL     COMMENT '收款方租户ID',
    `sku_id`                BIGINT         NULL     COMMENT 'SKU ID（按票关联）',
    `freeze_type`           VARCHAR(32)    NULL     COMMENT '冻结类型：PROFIT-利润，SETTLEMENT-采购款，FULL-全款',
    `profit_amt`            DECIMAL(18,2)  NULL     COMMENT '本级利润（元）= 支付金额 - 结算金额',
    `pay_date`              VARCHAR(32)    NULL     COMMENT '支付日期，格式 yyyy-MM-dd',
    `event_time`            VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `payment_id`)
COMMENT '实时支付明细（1行=1条支付记录（payment_no））'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`payment_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_ord_verify_rt  实时核销明细 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_verify_rt (
    `travel_date`            VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取创建时间日期，保证同一主键始终落在同一分区',
    `verify_id`              BIGINT         NOT NULL COMMENT '核销记录ID（源表主键 id）',
    `verify_no`              VARCHAR(32)    NULL     COMMENT '核销记录号，格式VF+yyyyMMdd+6位随机',
    `ticket_no`              VARCHAR(32)    NULL     COMMENT '核销票号',
    `entitlement_no`         VARCHAR(32)    NULL     COMMENT '核销权益号',
    `verify_point_id`        BIGINT         NULL     COMMENT '核销点ID',
    `operator_id`            BIGINT         NULL     COMMENT '操作人ID',
    `device_id`              BIGINT         NULL     COMMENT '核销设备ID',
    `verify_type`            VARCHAR(32)    NULL     COMMENT '核销类型：ONLINE-在线，OFFLINE-线下或离线',
    `offline_device_time`    BIGINT         NULL     COMMENT '离线时序戳（离线核销时设备时间）',
    `verify_result_type`     VARCHAR(32)    NULL     COMMENT '结果：SUCCESS-成功，FAILED-失败，DUPLICATE-重复',
    `tenant_id`              BIGINT         NULL     COMMENT '租户ID（分库维度）',
    `create_time`            VARCHAR(32)    NULL     COMMENT '创建时间（在线=服务器时间，离线=回连时间）',
    `update_time`            VARCHAR(32)    NULL     COMMENT '更新时间',
    `order_no`               VARCHAR(32)    NULL     COMMENT '所属子单号',
    `seller_tenant_id`       BIGINT         NULL     COMMENT '卖家租户ID',
    `sku_id`                 BIGINT         NULL     COMMENT 'SKU ID',
    `spu_id`                 BIGINT         NULL     COMMENT '产品(SPU)ID',
    `play_date`              VARCHAR(32)    NULL     COMMENT '游玩日期',
    `entitlement_type`       VARCHAR(32)    NULL     COMMENT '权益类型：FIXED-固定，COUNTED-计次型，SELECTABLE-选择型，TIMED-计时型，QUOTA-额度型，UNLIMITED-不限次型',
    `verify_point_type`      VARCHAR(32)    NULL     COMMENT '核销点类型：GATE-闸机，COUNTER-窗口，SELF_SERVICE-自助机，HANDHELD-手持机',
    `device_type`            VARCHAR(32)    NULL     COMMENT '设备类型：GATE-闸机，POS-POS 机，HANDHELD-手持机，SELF_SERVICE-自助机，KIOSK-自助终端，FACE_RECOGNITION-人脸识别机',
    `verify_time`            VARCHAR(32)    NULL     COMMENT '核销时间，格式 yyyy-MM-dd HH:mm:ss',
    `verify_hour_no`         INT            NULL     COMMENT '核销小时：0~23',
    `verify_person_qty`      BIGINT         NULL     COMMENT '本次核销人数',
    `verify_qty`             BIGINT         NULL     COMMENT '核销次数，固定为 1',
    `verify_amt`             DECIMAL(18,2)  NULL     COMMENT '核销金额（元，按票分摊单价 ÷ 可核销次数）',
    `offline_conflict_type`  INT            NULL     COMMENT '是否离线冲突：0-否，1-是（离线核销回传时票已被核销）',
    `event_time`             VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `verify_id`)
COMMENT '实时核销明细（1行=1次核销（verify_no））'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`verify_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_ord_refund_rt  实时退款明细 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_ord_refund_rt (
    `travel_date`         VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取创建时间日期，保证同一主键始终落在同一分区',
    `refund_id`           BIGINT         NOT NULL COMMENT '退款单ID（源表主键 id）',
    `refund_no`           VARCHAR(32)    NULL     COMMENT '退款单号，格式REF+yyyyMMdd+6位随机',
    `order_group_no`      VARCHAR(32)    NULL     COMMENT '归属聚合单号',
    `refund_type`         VARCHAR(32)    NULL     COMMENT '退款类型：ORDER_REFUND-订单退款，COMPENSATION-售后补偿，PARTIAL_REFUND-部分退款',
    `refund_reason_desc`  VARCHAR(256)   NULL     COMMENT '退款原因',
    `refund_amt`          DECIMAL(18,2)  NULL     COMMENT '退款总金额（元）；源字段单位为分，入仓 ÷100',
    `refund_status`       VARCHAR(32)    NULL     COMMENT '状态：PENDING-待处理，APPROVED-已通过，PROCESSING-处理中，COMPLETED-已完成，REJECTED-已拒绝',
    `initiator_type`      VARCHAR(32)    NULL     COMMENT '发起方：VISITOR-游客，MERCHANT-商户，PLATFORM-平台，SYSTEM-系统，OTA',
    `initiator_id`        BIGINT         NULL     COMMENT '发起方ID',
    `approver_id`         BIGINT         NULL     COMMENT '审批人ID',
    `approve_time`        VARCHAR(32)    NULL     COMMENT '审批时间',
    `tenant_id`           BIGINT         NULL     COMMENT '租户ID（分库维度）',
    `create_time`         VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`         VARCHAR(32)    NULL     COMMENT '更新时间',
    `seller_tenant_id`    BIGINT         NULL     COMMENT '卖家租户ID',
    `channel_id`          BIGINT         NULL     COMMENT '入口渠道ID',
    `apply_time`          VARCHAR(32)    NULL     COMMENT '退款申请时间',
    `finish_time`         VARCHAR(32)    NULL     COMMENT '退款完成时间；未完成为空',
    `process_hour_qty`    DECIMAL(18,2)  NULL     COMMENT '退款处理时长（小时）= 完成时间 - 申请时间',
    `refund_ticket_qty`   BIGINT         NULL     COMMENT '退款票数',
    `event_time`          VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `refund_id`)
COMMENT '实时退款明细（1行=1个退款单（refund_no））'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`refund_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_inv_pool_change_rt  实时库存变动 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_inv_pool_change_rt (
    `travel_date`           VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取变动时间日期，保证同一主键始终落在同一分区',
    `pool_id`               BIGINT         NOT NULL COMMENT '库存池ID（源表主键 id）',
    `change_time`           VARCHAR(32)    NOT NULL COMMENT '变动时间',
    `pool_no`               VARCHAR(32)    NULL     COMMENT '库存池编号，由流水号生成器生成',
    `sku_id`                BIGINT         NULL     COMMENT 'SKU ID',
    `pool_type`             VARCHAR(32)    NULL     COMMENT '池类型：COUNTING-可数池，UNIT-可标识池',
    `pool_status`           VARCHAR(32)    NULL     COMMENT '池状态：ON_SALE-在售，STOP_SALE-停售，EXPIRED-已过期',
    `tenant_id`             BIGINT         NULL     COMMENT '租户ID（分库维度）',
    `create_time`           VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`           VARCHAR(32)    NULL     COMMENT '更新时间',
    `change_type`           VARCHAR(32)    NULL     COMMENT '变动类型：PRE_DEDUCT-预扣，CONFIRM-确认，ROLLBACK-回滚，ADJUST-调整',
    `order_no`              VARCHAR(32)    NULL     COMMENT '引起变动的子单号；人工调整为空',
    `play_date`             VARCHAR(32)    NULL     COMMENT '库存日期',
    `room_type_code`        VARCHAR(32)    NULL     COMMENT '房型编码（酒店）',
    `show_time`             VARCHAR(32)    NULL     COMMENT '场次时间（演出）',
    `before_total_qty`      BIGINT         NULL     COMMENT '变动前总库存',
    `after_total_qty`       BIGINT         NULL     COMMENT '变动后总库存',
    `total_change_qty`      BIGINT         NULL     COMMENT '总库存变化量',
    `available_change_qty`  BIGINT         NULL     COMMENT '可售库存变化量',
    `frozen_change_qty`     BIGINT         NULL     COMMENT '冻结库存变化量',
    `event_time`            VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `pool_id`, `change_time`)
COMMENT '实时库存变动（1行=1次库存池数量变化）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`pool_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_opr_risk_event_rt  实时风控事件 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_risk_event_rt (
    `travel_date`           VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取创建时间日期，保证同一主键始终落在同一分区',
    `risk_event_id`         BIGINT         NOT NULL COMMENT '风控事件ID（源表主键 id）',
    `event_no`              VARCHAR(32)    NULL     COMMENT '事件编号，格式RE+yyyyMMdd+6位随机',
    `event_type`            VARCHAR(32)    NULL     COMMENT '类型：RULE_HIT-规则命中，MANUAL_BAN-人工封禁，MANUAL_UNBAN-人工解封，ABNORMAL_OP_DETECTED-检测到异常操作',
    `subject_id`            BIGINT         NULL     COMMENT '主体ID（用户/商户）',
    `dimension_value_desc`  VARCHAR(256)   NULL     COMMENT '触发维度值集合',
    `rule_id`               BIGINT         NULL     COMMENT '关联规则ID',
    `action_type`           VARCHAR(32)    NULL     COMMENT '执行动作：BLOCK-拦截，WARN-预警，FREEZE-冻结',
    `audit_log_id`          BIGINT         NULL     COMMENT '关联审计日志ID',
    `tenant_id`             BIGINT         NULL     COMMENT '租户ID',
    `create_time`           VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`           VARCHAR(32)    NULL     COMMENT '更新时间',
    `rule_type`             VARCHAR(32)    NULL     COMMENT '规则类型：BLACKLIST-黑名单，PURCHASE_LIMIT-购买限制，GEO_FENCE-地理围栏，ABNORMAL_OP-异常操作，DEFAULT_BREAK-爽约',
    `dimension_type`        VARCHAR(32)    NULL     COMMENT '规则维度：USER_ID-用户ID，ID_CARD-身份证，PHONE-手机号，IP，DEVICE_ID-设备ID',
    `event_time`            VARCHAR(32)    NULL     COMMENT '事件发生时间',
    `event_qty`             BIGINT         NULL     COMMENT '事件数，固定为 1'
)
PRIMARY KEY (`travel_date`, `risk_event_id`)
COMMENT '实时风控事件（1行=1个风控事件）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`risk_event_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_fin_frozen_rt  实时冻结/解冻明细 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_fin_frozen_rt (
    `travel_date`            VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取创建时间日期，保证同一主键始终落在同一分区',
    `frozen_id`              BIGINT         NOT NULL COMMENT '冻结记录ID（源表主键 id）',
    `frozen_no`              VARCHAR(32)    NULL     COMMENT '冻结记录编号，由流水号生成器生成',
    `account_no`             VARCHAR(32)    NULL     COMMENT '归属账户编号',
    `ticket_no`              VARCHAR(32)    NULL     COMMENT '关联票号（票级冻结）',
    `freeze_amt`             DECIMAL(18,2)  NULL     COMMENT '冻结金额（元）= 利润/采购款/全款；源字段单位为分，入仓 ÷100',
    `freeze_type`            VARCHAR(32)    NULL     COMMENT '冻结类型:PROFIT-利润，SETTLEMENT-采购款，FULL-全款，供应商直销',
    `frozen_status`          VARCHAR(32)    NULL     COMMENT '状态：FROZEN-冻结中，RELEASED-已释放',
    `release_event_type`     VARCHAR(32)    NULL     COMMENT '冻结事件：VERIFY-核销，REFUND-退款',
    `external_frozen_type`   INT            NULL     COMMENT '是否外部渠道冻结:1=第三方冻结(解冻调第三方API-API 接口),0=平台内部冻结',
    `external_channel_code`  VARCHAR(32)    NULL     COMMENT '外部渠道(external_frozen=1时):YEEPAY-易宝，UNIONPAY-银联等',
    `external_frozen_no`     VARCHAR(32)    NULL     COMMENT '外部冻结单号(第三方返回的冻结流水号,解冻时用)',
    `tenant_id`              BIGINT         NULL     COMMENT '租户ID（分库维度）',
    `create_time`            VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`            VARCHAR(32)    NULL     COMMENT '更新时间',
    `account_type`           VARCHAR(32)    NULL     COMMENT '账户类型：MERCHANT-商户，DISTRIBUTOR-分销商，PLATFORM-平台',
    `subject_id`             BIGINT         NULL     COMMENT '账户主体ID',
    `sku_id`                 BIGINT         NULL     COMMENT 'SKU ID',
    `freeze_time`            VARCHAR(32)    NULL     COMMENT '冻结时间',
    `release_time`           VARCHAR(32)    NULL     COMMENT '解冻时间；未解冻为空',
    `freeze_hour_qty`        DECIMAL(18,2)  NULL     COMMENT '冻结时长（小时）',
    `event_time`             VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `frozen_id`)
COMMENT '实时冻结/解冻明细（1行=1条冻结记录（frozen_no））'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`frozen_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_fin_account_balance_rt  实时账户余额 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_fin_account_balance_rt (
    `travel_date`            VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取状态更新时间日期，同一主键每天一行',
    `account_id`             BIGINT         NOT NULL COMMENT '统一账户ID（源表主键 id）',
    `account_no`             VARCHAR(32)    NULL     COMMENT '账户编号，由流水号生成器生成',
    `subject_id`             BIGINT         NULL     COMMENT '主体ID（商户/分销商/平台）',
    `account_type`           VARCHAR(32)    NULL     COMMENT '账户类型：MERCHANT-商户，DISTRIBUTOR-分销商，PLATFORM-平台',
    `available_balance_amt`  DECIMAL(18,2)  NULL     COMMENT '可用余额（元）；源字段单位为分，入仓 ÷100',
    `frozen_balance_amt`     DECIMAL(18,2)  NULL     COMMENT '冻结余额（元）；源字段单位为分，入仓 ÷100',
    `tenant_id`              BIGINT         NULL     COMMENT '租户ID（分库维度）',
    `create_time`            VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`            VARCHAR(32)    NULL     COMMENT '更新时间',
    `total_balance_amt`      DECIMAL(18,2)  NULL     COMMENT '账户总余额（元）= 可用余额 + 冻结余额',
    `event_time`             VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `account_id`)
COMMENT '实时账户余额（1行=1个账户×1日）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`account_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_trf_distribution_credit_rt  实时分销授信 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_trf_distribution_credit_rt (
    `travel_date`             VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取状态更新时间日期，同一主键每天一行',
    `relation_id`             BIGINT         NOT NULL COMMENT '分销关系ID（源表主键 id）',
    `relation_no`             VARCHAR(32)    NULL     COMMENT '分销关系编号，格式DR+yyyyMMdd+6位随机',
    `supplier_tenant_id`      BIGINT         NULL     COMMENT '供应商租户ID',
    `distributor_tenant_id`   BIGINT         NULL     COMMENT '分销商租户ID',
    `parent_relation_id`      BIGINT         NULL     COMMENT '上级分销关系ID（4级采购链）',
    `distribution_mode_type`  VARCHAR(32)    NULL     COMMENT '分销模式：PROFIT_SHARE-分润，PURCHASE-逐级采购',
    `payment_mode_type`       VARCHAR(32)    NULL     COMMENT '支付模式：CREDIT-授信，BALANCE-余额',
    `credit_limit_amt`        DECIMAL(18,2)  NULL     COMMENT '授信额度（元，payment_mode=CREDIT-授信时）；源字段单位为分，入仓 ÷100',
    `credit_used_amt`         DECIMAL(18,2)  NULL     COMMENT '已用授信（元）；源字段单位为分，入仓 ÷100',
    `relation_status`         VARCHAR(32)    NULL     COMMENT '状态：ACTIVE-有效，SUSPENDED-已暂停，TERMINATED-已终止',
    `create_time`             VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`             VARCHAR(32)    NULL     COMMENT '更新时间',
    `chain_level_no`          INT            NULL     COMMENT '本关系在采购链中的层级：1~4',
    `level1_tenant_id`        BIGINT         NULL     COMMENT '1 级（源头供应商）租户ID',
    `level2_tenant_id`        BIGINT         NULL     COMMENT '2 级分销商租户ID',
    `level3_tenant_id`        BIGINT         NULL     COMMENT '3 级分销商租户ID',
    `level4_tenant_id`        BIGINT         NULL     COMMENT '4 级分销商租户ID',
    `credit_available_amt`    DECIMAL(18,2)  NULL     COMMENT '剩余授信额度（元）= 授信额度 - 已用授信',
    `event_time`              VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `relation_id`)
COMMENT '实时分销授信（1行=1条分销关系×1个有效区间）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`relation_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_cus_customer_register_rt  实时游客注册 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_cus_customer_register_rt (
    `travel_date`           VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取创建时间日期，保证同一主键始终落在同一分区',
    `customer_id`           BIGINT         NOT NULL COMMENT 'C端游客主账号ID（源表主键 id）',
    `customer_no`           VARCHAR(32)    NULL     COMMENT '客户编号，格式CUS+yyyyMMdd+6位随机',
    `customer_type`         VARCHAR(32)    NULL     COMMENT '账号类型：REAL-真人注册账号，TENANT_DEFAULT-业务租户代下单占位买家；PLATFORM-平台 租户下不设占位买家，故无 PLATFORM_DEFAULT 值',
    `gender_type`           VARCHAR(32)    NULL     COMMENT '性别：MALE-男，FEMALE-女，UNKNOWN-未知',
    `auth_status`           VARCHAR(32)    NULL     COMMENT '认证状态：UNAUTHENTICATED-未认证，PHONE_VERIFIED-手机已验证，PERSON_CERTIFIED-已实名认证',
    `customer_status`       VARCHAR(32)    NULL     COMMENT '状态：ACTIVE-有效，BANNED-已封禁，CANCELLED-已取消',
    `register_source_code`  VARCHAR(32)    NULL     COMMENT '注册来源渠道编码（channel_code）',
    `register_tenant_id`    BIGINT         NULL     COMMENT '所属租户ID（self-tenant 隔离：该 customer 仅归属此租户，不跨租户复用；unionid/alipay 唯一键均带此列，phone 非唯一；证件号收敛改走 t_customer_credential 唯一键）',
    `create_time`           VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`           VARCHAR(32)    NULL     COMMENT '更新时间',
    `register_channel_id`   BIGINT         NULL     COMMENT '注册渠道ID',
    `register_time`         VARCHAR(32)    NULL     COMMENT '注册时间',
    `register_qty`          BIGINT         NULL     COMMENT '注册人数，固定为 1；剔除 TENANT_DEFAULT-租户代下单占位买家 占位买家',
    `event_time`            VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `customer_id`)
COMMENT '实时游客注册（1行=1个新注册游客）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`customer_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_opr_device_status_log_rt  实时设备状态变更 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_device_status_log_rt (
    `travel_date`          VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取变动时间日期，保证同一主键始终落在同一分区',
    `device_id`            BIGINT         NOT NULL COMMENT '设备ID',
    `change_time`          VARCHAR(32)    NOT NULL COMMENT '状态变更时间',
    `device_no`            VARCHAR(32)    NULL     COMMENT '设备编号',
    `tenant_id`            BIGINT         NULL     COMMENT '租户ID',
    `device_type`          VARCHAR(32)    NULL     COMMENT '设备类型：GATE-闸机，POS-POS 机，HANDHELD-手持机，SELF_SERVICE-自助机，KIOSK-自助终端，FACE_RECOGNITION-人脸识别机',
    `device_group_id`      BIGINT         NULL     COMMENT '设备分组ID',
    `poi_id`               BIGINT         NULL     COMMENT '所属 POI ID',
    `before_status`        VARCHAR(32)    NULL     COMMENT '变更前状态：ACTIVE-有效，OFFLINE-线下或离线，MAINTENANCE-维护中，INACTIVE-停用',
    `after_status`         VARCHAR(32)    NULL     COMMENT '变更后状态：ACTIVE-有效，OFFLINE-线下或离线，MAINTENANCE-维护中，INACTIVE-停用',
    `last_heartbeat_time`  VARCHAR(32)    NULL     COMMENT '最后心跳时间',
    `status_minute_qty`    BIGINT         NULL     COMMENT '前一状态持续时长（分钟）',
    `event_time`           VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `device_id`, `change_time`)
COMMENT '实时设备状态变更（1行=1次设备状态/心跳变化）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`device_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_opr_notify_rt  实时通知发送 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_notify_rt (
    `travel_date`          VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取创建时间日期，保证同一主键始终落在同一分区',
    `notify_id`            BIGINT         NOT NULL COMMENT '通知记录ID（源表主键 id）',
    `notify_no`            VARCHAR(32)    NULL     COMMENT '通知记录号，格式NR+yyyyMMdd+6位随机',
    `template_id`          BIGINT         NULL     COMMENT '模板ID',
    `recipient_id`         BIGINT         NULL     COMMENT '接收人ID',
    `recipient_type`       VARCHAR(32)    NULL     COMMENT '接收人类型：CUSTOMER-C端游客，TENANT_STAFF-B端员工，SYSTEM-系统',
    `notify_channel_type`  VARCHAR(32)    NULL     COMMENT '实际发送渠道：SMS-短信，MINI_PROGRAM_MSG-小程序消息，EMAIL-邮件，WEBHOOK-Webhook，IN_APP-站内信',
    `related_business_no`  VARCHAR(32)    NULL     COMMENT '关联业务号',
    `send_status`          VARCHAR(32)    NULL     COMMENT '状态：PENDING-待处理，SUCCESS-成功，FAILED-失败',
    `send_time`            VARCHAR(32)    NULL     COMMENT '发送时间',
    `fail_reason_desc`     VARCHAR(256)   NULL     COMMENT '失败原因',
    `tenant_id`            BIGINT         NULL     COMMENT '租户ID',
    `create_time`          VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`          VARCHAR(32)    NULL     COMMENT '更新时间',
    `template_code`        VARCHAR(32)    NULL     COMMENT '模板编码',
    `send_success_type`    INT            NULL     COMMENT '是否发送成功：0-否，1-是',
    `notify_qty`           BIGINT         NULL     COMMENT '发送次数，固定为 1',
    `event_time`           VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `notify_id`)
COMMENT '实时通知发送（1行=1次通知发送）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`notify_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_opr_complaint_rt  实时投诉工单 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_complaint_rt (
    `travel_date`          VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取创建时间日期，保证同一主键始终落在同一分区',
    `complaint_id`         BIGINT         NOT NULL COMMENT '投诉工单ID（源表主键 id）',
    `complaint_no`         VARCHAR(32)    NULL     COMMENT '工单编号，格式CMP+yyyyMMdd+6位随机',
    `complainant_type`     VARCHAR(32)    NULL     COMMENT '投诉方：VISITOR-游客，MERCHANT-商户',
    `complainant_id`       BIGINT         NULL     COMMENT '投诉方ID',
    `order_group_no`       VARCHAR(32)    NULL     COMMENT '关联订单号（游客投诉时）',
    `complaint_type`       VARCHAR(32)    NULL     COMMENT '类型：ORDER_ISSUE-订单问题，SERVICE_ISSUE-服务问题，BUG-系统缺陷，OTHER-其他',
    `handler_id`           BIGINT         NULL     COMMENT '处理人ID',
    `sla_deadline_time`    VARCHAR(32)    NULL     COMMENT 'SLA截止时间',
    `complaint_status`     VARCHAR(32)    NULL     COMMENT '状态：PENDING-待处理，ASSIGNED-已分派，PROCESSING-处理中，RESOLVED-已解决，CLOSED-已关闭',
    `tenant_id`            BIGINT         NULL     COMMENT '租户ID',
    `create_time`          VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`          VARCHAR(32)    NULL     COMMENT '更新时间',
    `seller_tenant_id`     BIGINT         NULL     COMMENT '被投诉的卖家租户ID',
    `create_time_hour_no`  INT            NULL     COMMENT '投诉提交小时：0~23',
    `resolve_time`         VARCHAR(32)    NULL     COMMENT '处理完成时间；未完成为空',
    `resolve_hour_qty`     DECIMAL(18,2)  NULL     COMMENT '处理时长（小时）',
    `sla_timeout_type`     INT            NULL     COMMENT '是否超 SLA：0-否，1-是',
    `complaint_qty`        BIGINT         NULL     COMMENT '投诉数，固定为 1',
    `event_time`           VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `complaint_id`)
COMMENT '实时投诉工单（1行=1个投诉工单）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`complaint_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

-- ========== dwd.dwd_opr_code_pool_rt  实时码池状态 ==========
-- StarRocks 主键模型（Flink 实时 upsert）
CREATE TABLE IF NOT EXISTS dwd.dwd_opr_code_pool_rt (
    `travel_date`      VARCHAR(32)    NOT NULL COMMENT '数据日期，格式 YYYYMMDD；取状态更新时间日期，同一主键每天一行',
    `code_pool_id`     BIGINT         NOT NULL COMMENT '码池ID（源表主键 id）',
    `pool_no`          VARCHAR(32)    NULL     COMMENT '码池编号，格式CP+yyyyMMdd+6位随机',
    `tenant_id`        BIGINT         NULL     COMMENT '归属商户ID',
    `pool_type`        VARCHAR(32)    NULL     COMMENT '池类型：SINGLE_TICKET-单票池，COMBO_TICKET-套票池',
    `credential_type`  VARCHAR(32)    NULL     COMMENT '凭证类型：QR_CODE-二维码，BAR_CODE-条形码',
    `capacity_qty`     BIGINT         NULL     COMMENT '池容量（最大并发码数）',
    `allocated_qty`    BIGINT         NULL     COMMENT '已分配码数',
    `recycled_qty`     BIGINT         NULL     COMMENT '已回收复用码数',
    `pool_status`      VARCHAR(32)    NULL     COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    `create_time`      VARCHAR(32)    NULL     COMMENT '创建时间',
    `update_time`      VARCHAR(32)    NULL     COMMENT '更新时间',
    `remain_qty`       BIGINT         NULL     COMMENT '剩余可分配码数 = 容量 - 已分配 + 已回收',
    `event_time`       VARCHAR(32)    NULL     COMMENT '事件时间（binlog 时间），用于窗口计算与乱序处理，格式 yyyy-MM-dd HH:mm:ss'
)
PRIMARY KEY (`travel_date`, `code_pool_id`)
COMMENT '实时码池状态（1行=1个码池）'
PARTITION BY (`travel_date`)
DISTRIBUTED BY HASH(`code_pool_id`) BUCKETS 8
PROPERTIES ("replication_num" = "3");

