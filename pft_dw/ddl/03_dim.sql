-- PFT 2.0 数仓 DDL：DIM（37 张表）
-- 由 generator/make_all.py 生成，请勿手改

-- ========== dim.dim_prd_spu_zip  产品(SPU)维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_prd_spu_zip (
    spu_id                BIGINT         COMMENT 'SPUID（源表主键 id）',
    spu_no                STRING         COMMENT 'SPU编号，格式SPU+yyyyMMdd+6位随机',
    tenant_id             BIGINT         COMMENT '归属商户ID',
    product_type          STRING         COMMENT '产品类型（平台字典）：SCENIC-景区门票，HOTEL-酒店，SHOW-演出，Cruise，RESTAURANT-餐饮，ANNUAL_PASS-年卡，SPECIALTY-旅游特产，TIMED-计时型，COUPON-旅游券，LINE-旅游线路',
    spu_name              STRING         COMMENT '产品名称',
    poi_id                BIGINT         COMMENT '关联POI ID',
    cover_image_url_desc  STRING         COMMENT '封面图URL',
    spu_status            STRING         COMMENT '状态：DRAFT-草稿，PUBLISHED-已发布，UNPUBLISHED-已下架',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    tenant_name           STRING         COMMENT '所属商户名称',
    start_date            STRING         COMMENT '拉链开始日期，格式 yyyy-MM-dd',
    end_date              STRING         COMMENT '拉链结束日期，格式 yyyy-MM-dd；9999-12-31 表示当前有效',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '产品(SPU)维度（1行=1个SPU×1个有效区间）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_prd_sku_zip  SKU维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_prd_sku_zip (
    sku_id                  BIGINT         COMMENT 'SKUID（源表主键 id）',
    sku_no                  STRING         COMMENT 'SKU编号，格式SKU+yyyyMMdd+6位随机',
    spu_id                  BIGINT         COMMENT '归属SPU ID',
    tenant_id               BIGINT         COMMENT '归属商户ID',
    sku_name                STRING         COMMENT 'SKU名称（如"成人票""VIP套票"）',
    cost_price_amt          DECIMAL(18,2)  COMMENT '成本价（元）——供应商商品属性，不在售价体系内；源字段单位为分，入仓 ÷100',
    sale_mode_type          STRING         COMMENT '售卖模式：FIXED_DATE-指定日期，TIMED_RESERVATION-分时预约，PRE_SALE-预售',
    version_no              INT            COMMENT '版本号，每次属性变更+1（下单时在t_order记录sku_version）',
    sku_status              STRING         COMMENT '状态：DRAFT-草稿，PUBLISHED-已发布，UNPUBLISHED-已下架',
    tag_list_desc           STRING         COMMENT '标签列表（商户自定义）',
    sale_channel_list_desc  STRING         COMMENT '销售渠道列表：[MINI_PROGRAM-小程序，WECHAT_SHOP-微信小店，PC，COUNTER-窗口，OTA_DOUYIN-抖音，OTA_MEITUAN-美团，OTA_CTRIP-携程]',
    create_time             STRING         COMMENT '创建时间',
    update_time             STRING         COMMENT '更新时间',
    spu_no                  STRING         COMMENT 'SPU 编号',
    spu_name                STRING         COMMENT '产品名称',
    product_type            STRING         COMMENT '产品业态：SCENIC-景区门票，HOTEL-酒店，SHOW-演出/…（13 种）',
    poi_id                  BIGINT         COMMENT 'POI ID（景区/场馆）',
    tenant_name             STRING         COMMENT '所属商户名称',
    sale_rule_qty           BIGINT         COMMENT '生效中的售卖规则数',
    real_name_policy_code   STRING         COMMENT '实名制策略',
    refund_policy_code      STRING         COMMENT '退改策略',
    start_date              STRING         COMMENT '拉链开始日期，格式 yyyy-MM-dd',
    end_date                STRING         COMMENT '拉链结束日期，格式 yyyy-MM-dd；9999-12-31 表示当前有效',
    etl_time                STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SKU维度（1行=1个SKU×1个有效区间）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_prd_sku_attr_df  SKU票属性维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_prd_sku_attr_df (
    sku_attr_id           BIGINT         COMMENT 'SKU票属性值ID（源表主键 id）',
    sku_id                BIGINT         COMMENT 'SKU ID',
    attribute_code        STRING         COMMENT '属性代码（引用t_ticket_meta）',
    attribute_value_code  STRING         COMMENT '属性值（POLICY_CHOICE-单选策略=选项code，TOGGLE-开关=0/1，NUMERIC-数值=数字，TEXT-文本=文本）',
    tenant_id             BIGINT         COMMENT '租户ID',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    attribute_name        STRING         COMMENT '属性名称',
    value_type            STRING         COMMENT '值类型：POLICY_CHOICE-单选策略，TOGGLE-开关，NUMERIC-数值，TEXT-文本，DATE_RANGE-日期范围',
    attribute_value_name  STRING         COMMENT '属性值中文含义',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT 'SKU票属性维度（1行=1个SKU×1个票属性）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_prd_ticket_meta_f  票属性元数据码表 ==========
CREATE TABLE IF NOT EXISTS dim.dim_prd_ticket_meta_f (
    ticket_meta_id                 BIGINT         COMMENT '票属性元数据ID（源表主键 id）',
    attribute_code                 STRING         COMMENT '属性代码（全局唯一Code）',
    attribute_name                 STRING         COMMENT '属性名称',
    value_type                     STRING         COMMENT '值类型：POLICY_CHOICE-单选策略，TOGGLE-开关，NUMERIC-数值，TEXT-文本，DATE_RANGE-日期范围',
    default_value_desc             STRING         COMMENT '默认值',
    applicable_business_list_desc  STRING         COMMENT '适用业态（逗号分隔）',
    impact_list_desc               STRING         COMMENT '影响链：[ORDER-订单，INVENTORY-库存，PRICING-价格，VERIFY-核销，REFUND-退款]',
    conflict_list_desc             STRING         COMMENT '互斥属性列表',
    depend_list_desc               STRING         COMMENT '依赖前置属性列表',
    enabled_when_desc              STRING         COMMENT '条件可用性：何条件下可用',
    disabled_when_desc             STRING         COMMENT '条件禁用：何条件下被禁用',
    attribute_status               STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time                    STRING         COMMENT '创建时间',
    update_time                    STRING         COMMENT '更新时间',
    etl_time                       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '票属性元数据码表（1行=1个票属性）'
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_prd_sale_rule_df  售卖规则维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_prd_sale_rule_df (
    sale_rule_item_id     BIGINT         COMMENT '售卖条件项ID（源表主键 id）',
    rule_id               BIGINT         COMMENT '归属售卖规则ID',
    rule_type             STRING         COMMENT '条件类型：DATE_RANGE-日期范围，TIME_SLOT-时段，PRE_SALE_DAYS-提前预售天数，DAILY_BUY_WINDOW-每日购买时段，PURCHASE_DEADLINE-购买截止时间，BLACKOUT_DATE-不可售日期，WEEKDAY_MASK-星期限制，REGION_LIMIT-地区限制，AGE_RANGE-年龄范围，CERT_TYPE-证件类型限制，MEMBER_LEVEL-会员等级，CUSTOMER_TAG-客户标签，GEO_FENCE-地理围栏，PURCHASE_POI-购买地点限制，MIN_PURCHASE-最小购买量，MAX_PURCHASE-最大购买量，DAILY_LIMIT_PER_USER-每人每日限购',
    rule_value_desc       STRING         COMMENT '条件值（按rule_type结构化，如DATE_RANGE-日期范围={from,to}，REGION_LIMIT-地区限制={regions:[MAINLAND-中国大陆]})',
    tenant_id             BIGINT         COMMENT '租户ID',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    rule_no               STRING         COMMENT '售卖规则编号',
    sku_id                BIGINT         COMMENT 'SKU ID',
    effective_start_time  STRING         COMMENT '规则生效开始时间',
    effective_end_time    STRING         COMMENT '规则生效结束时间',
    rule_status           STRING         COMMENT '规则状态：ACTIVE-有效，INACTIVE-停用',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '售卖规则维度（1行=1条规则×1个条件项）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_prd_pricing_rule_zip  定价规则维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_prd_pricing_rule_zip (
    pricing_rule_id       BIGINT         COMMENT '定价规则ID（源表主键 id）',
    rule_no               STRING         COMMENT '规则编号，格式PR+yyyyMMdd+6位随机',
    sku_id                BIGINT         COMMENT 'SKU ID',
    rule_type             STRING         COMMENT '规则类型：MARGIN-分销结算，SURCHARGE-预约加价，DISCOUNT-折扣，MEMBER_DISCOUNT-会员折扣',
    base_price_ref_type   STRING         COMMENT '基准价引用：RETAIL-零售价，COUNTER-窗口，BASE-期票基础价，CURRENT-当前价',
    calculator_type       STRING         COMMENT '计算方式：PERCENT-按比例，FIXED-固定，MATRIX-日历矩阵',
    rule_param_desc       STRING         COMMENT '计算参数（JSON，随ruleType+calculator变化）',
    priority_no           INT            COMMENT '优先级',
    effective_start_time  STRING         COMMENT '生效起始',
    effective_end_time    STRING         COMMENT '生效终止',
    tenant_id             BIGINT         COMMENT '租户ID（分库维度）',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    start_date            STRING         COMMENT '拉链开始日期，格式 yyyy-MM-dd',
    end_date              STRING         COMMENT '拉链结束日期，格式 yyyy-MM-dd；9999-12-31 表示当前有效',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '定价规则维度（1行=1条规则×1个有效区间）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_inv_pool_df  库存池维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_inv_pool_df (
    pool_id         BIGINT         COMMENT '库存池ID（源表主键 id）',
    pool_no         STRING         COMMENT '库存池编号，由流水号生成器生成',
    sku_id          BIGINT         COMMENT 'SKU ID',
    pool_type       STRING         COMMENT '池类型：COUNTING-可数池，UNIT-可标识池',
    pool_status     STRING         COMMENT '池状态：ON_SALE-在售，STOP_SALE-停售，EXPIRED-已过期',
    tenant_id       BIGINT         COMMENT '租户ID（分库维度）',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    play_date       STRING         COMMENT '库存日期',
    room_type_code  STRING         COMMENT '房型编码',
    show_time       STRING         COMMENT '场次时间',
    cabin_code      STRING         COMMENT '舱位编码',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '库存池维度（1行=1个库存池）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_inv_unit_df  座位/房间/舱位维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_inv_unit_df (
    unit_id          BIGINT         COMMENT 'UNIT池资源（座位/房间/舱位）ID（源表主键 id）',
    unit_no          STRING         COMMENT '资源个体编号（座位号/房号/舱位号）',
    pool_no          STRING         COMMENT '归属库存池编号',
    unit_status      STRING         COMMENT '状态：AVAILABLE-可用，FROZEN-冻结中，OCCUPIED-已占用',
    tenant_id        BIGINT         COMMENT '租户ID（分库维度）',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    sku_id           BIGINT         COMMENT 'SKU ID',
    seat_level_code  STRING         COMMENT '座位等级',
    room_type_code   STRING         COMMENT '房型编码',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '座位/房间/舱位维度（1行=1个UNIT资源）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_inv_shared_pool_df  共享库存配额维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_inv_shared_pool_df (
    shared_pool_id         BIGINT         COMMENT '共享库存池ID（源表主键 id）',
    relation_id            BIGINT         COMMENT '分销关系ID',
    source_pool_no         STRING         COMMENT '源库存池编号（供应商池）',
    shared_pool_no         DECIMAL(18,2)  COMMENT '共享池编号（分销商独立池，软配额模式）；源字段单位为分，入仓 ÷100',
    quota_type             STRING         COMMENT '配额类型：HARD-硬配额，SOFT-软配额，ROLLING-滚动配额',
    quota_qty              BIGINT         COMMENT '配额数量',
    quota_used_qty         BIGINT         COMMENT '已用配额',
    sharing_status         STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time            STRING         COMMENT '创建时间',
    update_time            STRING         COMMENT '更新时间',
    supplier_tenant_id     BIGINT         COMMENT '供应商租户ID',
    distributor_tenant_id  BIGINT         COMMENT '分销商租户ID',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '共享库存配额维度（1行=1条共享配额）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_cus_customer_zip  游客维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_cus_customer_zip (
    customer_id           BIGINT         COMMENT 'C端游客主账号ID（源表主键 id）',
    customer_no           STRING         COMMENT '客户编号，格式CUS+yyyyMMdd+6位随机',
    customer_type         STRING         COMMENT '账号类型：REAL-真人注册账号，TENANT_DEFAULT-业务租户代下单占位买家；PLATFORM-平台 租户下不设占位买家，故无 PLATFORM_DEFAULT 值',
    phone_no              STRING         COMMENT '联系电话+登录句柄（非唯一，可被本租户内多账号共用；手机登录匹配多个时弹身份选择器）（脱敏）',
    customer_name         STRING         COMMENT '姓名/昵称（脱敏）',
    gender_type           STRING         COMMENT '性别：MALE-男，FEMALE-女，UNKNOWN-未知',
    auth_status           STRING         COMMENT '认证状态：UNAUTHENTICATED-未认证，PHONE_VERIFIED-手机已验证，PERSON_CERTIFIED-已实名认证',
    customer_status       STRING         COMMENT '状态：ACTIVE-有效，BANNED-已封禁，CANCELLED-已取消',
    register_source_code  STRING         COMMENT '注册来源渠道编码（channel_code）',
    register_tenant_id    BIGINT         COMMENT '所属租户ID（self-tenant 隔离：该 customer 仅归属此租户，不跨租户复用；unionid/alipay 唯一键均带此列，phone 非唯一；证件号收敛改走 t_customer_credential 唯一键）',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    register_channel_id   BIGINT         COMMENT '注册渠道ID',
    age_band_code         STRING         COMMENT '年龄段：0_17-未成年，18_25-18~25岁，26_35-26~35岁，36_45-36~45岁，46_60-46~60岁，60_PLUS-60岁以上，UNKNOWN-未知（由生日计算，生日本身不入仓）',
    wechat_bind_type      INT            COMMENT '是否绑定微信：0-否，1-是',
    alipay_bind_type      INT            COMMENT '是否绑定支付宝：0-否，1-是',
    start_date            STRING         COMMENT '拉链开始日期，格式 yyyy-MM-dd',
    end_date              STRING         COMMENT '拉链结束日期，格式 yyyy-MM-dd；9999-12-31 表示当前有效',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '游客维度（1行=1个游客×1个有效区间）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_cus_identity_df  游客渠道身份维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_cus_identity_df (
    customer_identity_id  BIGINT         COMMENT '游客多渠道身份ID（源表主键 id）',
    customer_id           BIGINT         COMMENT '归属 Customer ID',
    identity_type         STRING         COMMENT '标识类型：WECHAT_OPENID-微信 openid，DOUYIN_OPENID-抖音 openid，OTA_UID-OTA 用户ID，ALIPAY_OPENID-支付宝 openid，OTHER-其他',
    identity_code         STRING         COMMENT '标识值（openid/OTA用户uid等）（脱敏）',
    bind_channel_id       BIGINT         COMMENT '产生该标识的接入端ID（指向 t_channel）',
    bind_tenant_id        BIGINT         COMMENT '产生该标识的租户ID（小程序openid必带；平台端=内部租户id,即 tenant_type=INTERNAL-内部运营主体 的租户数值 id）',
    identity_status       STRING         COMMENT '状态：ACTIVE-有效，REVOKED-已撤销',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '游客渠道身份维度（1行=1条渠道身份）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_sup_tenant_zip  租户（商户/供应商/分销商）维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_sup_tenant_zip (
    tenant_id                BIGINT         COMMENT '租户ID（源表主键 id）',
    tenant_no                STRING         COMMENT '租户编号,格式TNT+yyyyMMdd+6位随机;内部租户同样走此规则,不再用PLATFORM-平台约定',
    tenant_name              STRING         COMMENT '租户名称',
    tenant_type              STRING         COMMENT '租户类型: INTERNAL-内部运营主体，可多个，平级，EXTERNAL-外部业务租户',
    contact_phone_no         STRING         COMMENT '联系人手机号（脱敏）',
    country_code             STRING         COMMENT '国家码 ISO 3166-1(如 CN，US，JP),关联 t_country.country_code',
    region_id                BIGINT         COMMENT '最末级地区ID,关联 t_region.id;0表示未设置',
    region_path_desc         STRING         COMMENT '行政区划完整路径(冗余,取自 t_region.region_path),展示+检索用,如"中国/福建省/厦门市/思明区"',
    business_type_list_desc  STRING         COMMENT '业态列表(多选):[SCENIC-景区门票，HOTEL-酒店，SHOW-演出/...]',
    auth_status              STRING         COMMENT '认证状态: UNAUTHENTICATED-未认证，PENDING_REVIEW-审核中，CERTIFIED-已认证，REJECTED-已驳回',
    register_source_code     STRING         COMMENT '租户来源: SELF_REGISTER-自行注册，PLATFORM_CREATED-后台添加，IMPORT-批量导入，PARTNER_INVITE-合作伙伴邀请',
    tenant_status            STRING         COMMENT '状态: ACTIVE-有效，BANNED-已封禁，INACTIVE-停用',
    create_time              STRING         COMMENT '创建时间',
    update_time              STRING         COMMENT '更新时间',
    country_name             STRING         COMMENT '国家名称',
    province_name            STRING         COMMENT '省份名称',
    city_name                STRING         COMMENT '城市名称',
    currency_code            STRING         COMMENT '结算币种',
    locale_code              STRING         COMMENT '默认语言',
    package_id               BIGINT         COMMENT '当前生效套餐ID',
    package_expire_time      STRING         COMMENT '当前套餐到期时间',
    start_date               STRING         COMMENT '拉链开始日期，格式 yyyy-MM-dd',
    end_date                 STRING         COMMENT '拉链结束日期，格式 yyyy-MM-dd；9999-12-31 表示当前有效',
    etl_time                 STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '租户（商户/供应商/分销商）维度（1行=1个租户×1个有效区间）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_sup_staff_zip  员工维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_sup_staff_zip (
    staff_id             BIGINT         COMMENT 'B端员工ID（源表主键 id）',
    staff_no             STRING         COMMENT '员工编号(工号),格式yyMMdd+4位随机,纯数字短编号,不带前缀;员工日常使用,越短越好',
    tenant_id            BIGINT         COMMENT '所属租户ID（内部员工=tenant_type=INTERNAL-内部运营主体 租户id）',
    org_id               BIGINT         COMMENT '所属部门ID(0=未分配; FK→t_org.id); 一个员工只属于一个主部门,多部门数据访问走RBAC角色+数据范围',
    position_id          BIGINT         COMMENT '岗位ID(0=未分配; FK→t_tenant_position.id); 一个员工一个岗位(1:N),兼岗需求走RBAC角色',
    staff_name           STRING         COMMENT '姓名',
    phone_no             STRING         COMMENT '手机号(数据属性,非唯一;若支持手机号登录,录入时同时存一份到t_staff_credential;否则仅展示用)（脱敏）',
    staff_status         STRING         COMMENT '状态：ACTIVE-有效，DISABLED-已停用，RESIGNED-已离职',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    org_name             STRING         COMMENT '所属部门名称',
    org_path_desc        STRING         COMMENT '部门完整路径，如 总部/运营中心/票务部',
    position_name        STRING         COMMENT '岗位名称',
    role_code_list_desc  STRING         COMMENT '角色编码列表，逗号分隔',
    role_name_list_desc  STRING         COMMENT '角色名称列表，逗号分隔',
    start_date           STRING         COMMENT '拉链开始日期，格式 yyyy-MM-dd',
    end_date             STRING         COMMENT '拉链结束日期，格式 yyyy-MM-dd；9999-12-31 表示当前有效',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '员工维度（1行=1个员工×1个有效区间）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_sup_org_df  部门维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_sup_org_df (
    org_id           BIGINT         COMMENT '部门架构ID（源表主键 id）',
    org_no           STRING         COMMENT '部门编号,格式DEP+yyyyMMdd+6位随机',
    org_name         STRING         COMMENT '部门名称',
    parent_org_id    BIGINT         COMMENT '上级部门ID(0=顶级部门)',
    tenant_id        BIGINT         COMMENT '租户ID',
    org_status       STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    org_level_no     INT            COMMENT '部门层级：1-一级部门，依次递增',
    org_path_desc    STRING         COMMENT '部门完整路径',
    level1_org_id    BIGINT         COMMENT '一级部门ID',
    level1_org_name  STRING         COMMENT '一级部门名称',
    level2_org_id    BIGINT         COMMENT '二级部门ID',
    level2_org_name  STRING         COMMENT '二级部门名称',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '部门维度（1行=1个部门）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_sup_position_df  岗位维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_sup_position_df (
    position_id      BIGINT         COMMENT '岗位定义ID（源表主键 id）',
    position_no      STRING         COMMENT '岗位编号,格式POS-POS 机+yyyyMMdd+6位随机',
    tenant_id        BIGINT         COMMENT '租户ID',
    position_name    STRING         COMMENT '岗位名称（如"运营主管/安全员/财务审核"等）',
    position_code    STRING         COMMENT '岗位编码（租户内唯一，如OPS_MANAGER/SAFETY_INSPECTOR，便于代码引用）',
    position_status  STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '岗位维度（1行=1个岗位）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_sup_role_df  角色维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_sup_role_df (
    role_id                    BIGINT         COMMENT 'RBAC角色ID（源表主键 id）',
    role_code                  STRING         COMMENT '角色代码',
    role_name                  STRING         COMMENT '角色名称',
    tenant_id                  BIGINT         COMMENT '租户ID',
    role_status                STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time                STRING         COMMENT '创建时间',
    update_time                STRING         COMMENT '更新时间',
    permission_qty             BIGINT         COMMENT '拥有权限数',
    permission_code_list_desc  STRING         COMMENT '权限编码列表，逗号分隔',
    etl_time                   STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '角色维度（1行=1个角色）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_trf_channel_df  渠道/接入端维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_trf_channel_df (
    channel_id                 BIGINT         COMMENT '接入端/渠道ID（源表主键 id）',
    channel_code               STRING         COMMENT '渠道唯一编码：MP_TENANT_HOSTED-租户托管小程序，MP_PLATFORM-平台小程序，PC_TENANT-租户后台，PC_PLATFORM-平台后台，OFFLINE-线下或离线，API_XXX',
    channel_name               STRING         COMMENT '渠道展示名（"租户托管小程序"/"美团接入"）',
    partner_code               STRING         COMMENT '合作方ID（Partner 统一抽象：美团partnerId/微信appId/抖音appId/携程agentId，AI-AI 接入 Agent ID等）；每个外部合作方一个唯一partner_id',
    partner_name               STRING         COMMENT '合作方名称（冗余展示用：美团/微信/抖音/携程等）',
    channel_type               STRING         COMMENT '渠道类型：MP-小程序，PC，API-API 接口，OFFLINE-线下或离线，H5',
    channel_scope_type         STRING         COMMENT '渠道作用域：PLATFORM-平台运营方持有，全平台共用，TENANT-具体租户持有；详见§2.9.1',
    owner_tenant_id            BIGINT         COMMENT '渠道所有者租户ID（channel_scope=TENANT-租户时必填=持有该渠道的租户；channel_scope=PLATFORM-平台时=内部租户id,即 tenant_type=INTERNAL-内部运营主体 的租户数值 id）。注意：与渠道下挂载的租户(channel_tenant_binding.tenant_id)不同，前者表"持有"，后者表"使用"',
    default_operator_staff_id  BIGINT         COMMENT '默认操作员ID（channel_type=API-API 接口必填，请求未带staffCode时兜底）',
    channel_status             STRING         COMMENT '状态：ENABLED-启用，DISABLED-已停用',
    valid_start_time           STRING         COMMENT '生效开始时间',
    valid_end_time             STRING         COMMENT '生效结束时间',
    create_time                STRING         COMMENT '创建时间',
    update_time                STRING         COMMENT '更新时间',
    api_key_qty                BIGINT         COMMENT '有效 API-API 接口 Key 数',
    rate_limit_qps_qty         BIGINT         COMMENT 'API-API 接口 限流 QPS-取最大',
    etl_time                   STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '渠道/接入端维度（1行=1个渠道）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_trf_channel_tenant_df  渠道-租户绑定维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_trf_channel_tenant_df (
    channel_tenant_binding_id  BIGINT         COMMENT '渠道-租户绑定ID（源表主键 id）',
    binding_no                 STRING         COMMENT '绑定编号，格式CHB+yyyyMMdd+6位随机',
    channel_id                 BIGINT         COMMENT '渠道ID（FK→t_channel.id）',
    tenant_id                  BIGINT         COMMENT '租户ID（FK→t_tenant.id；此租户可通过该渠道下单/被下单）',
    partner_code               STRING         COMMENT '合作方ID（冗余便于查询，与t_channel.partner_id同步）',
    ota_merchant_code          STRING         COMMENT 'OTA侧商户ID（美团scenicId/抖音shopId/携程shopId，AI-AI 接入 Agent 商户id等）；推单/拉单路由时用于按租户维度识别订单归属',
    ota_sub_channel_code       STRING         COMMENT 'OTA子渠道枚举（可选；用于同渠道内细分场景，如美团"景点门票"vs"玩乐"）',
    binding_status             STRING         COMMENT '绑定状态：ACTIVE-有效，INACTIVE-停用，SUSPENDED-已暂停',
    valid_start_time           STRING         COMMENT '生效开始时间',
    valid_end_time             STRING         COMMENT '生效结束时间',
    create_time                STRING         COMMENT '创建时间',
    update_time                STRING         COMMENT '更新时间',
    channel_code               STRING         COMMENT '渠道编码',
    channel_type               STRING         COMMENT '渠道类型：MP-小程序，PC，API-API 接口，OFFLINE-线下或离线，H5',
    etl_time                   STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '渠道-租户绑定维度（1行=1条绑定）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_trf_mp_config_df  小程序配置维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_trf_mp_config_df (
    mp_config_id   BIGINT         COMMENT '租户小程序配置ID（源表主键 id）',
    tenant_id      BIGINT         COMMENT '归属租户ID',
    mp_type        STRING         COMMENT '小程序类型：WECHAT_MP-微信公众号，WECHAT_MINI-微信小程序，WECHAT_WORK-企业微信，ALIPAY_MINI-支付宝小程序，DOUYIN_MINI-抖音小程序',
    app_code       STRING         COMMENT '小程序 appId（微信/支付宝/抖音）',
    mch_code       STRING         COMMENT '微信支付商户号（可能共用）',
    remark_desc    STRING         COMMENT '备注',
    config_status  STRING         COMMENT '状态：ENABLED-启用，DISABLED-已停用',
    create_time    STRING         COMMENT '创建时间',
    update_time    STRING         COMMENT '更新时间',
    etl_time       STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '小程序配置维度（1行=1个小程序）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_trf_distribution_relation_zip  分销关系维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_trf_distribution_relation_zip (
    relation_id             BIGINT         COMMENT '分销关系ID（源表主键 id）',
    relation_no             STRING         COMMENT '分销关系编号，格式DR+yyyyMMdd+6位随机',
    supplier_tenant_id      BIGINT         COMMENT '供应商租户ID',
    distributor_tenant_id   BIGINT         COMMENT '分销商租户ID',
    parent_relation_id      BIGINT         COMMENT '上级分销关系ID（4级采购链）',
    distribution_mode_type  STRING         COMMENT '分销模式：PROFIT_SHARE-分润，PURCHASE-逐级采购',
    payment_mode_type       STRING         COMMENT '支付模式：CREDIT-授信，BALANCE-余额',
    credit_limit_amt        DECIMAL(18,2)  COMMENT '授信额度（元，payment_mode=CREDIT-授信时）；源字段单位为分，入仓 ÷100',
    credit_used_amt         DECIMAL(18,2)  COMMENT '已用授信（元）；源字段单位为分，入仓 ÷100',
    relation_status         STRING         COMMENT '状态：ACTIVE-有效，SUSPENDED-已暂停，TERMINATED-已终止',
    create_time             STRING         COMMENT '创建时间',
    update_time             STRING         COMMENT '更新时间',
    chain_level_no          INT            COMMENT '本关系在采购链中的层级：1~4',
    level1_tenant_id        BIGINT         COMMENT '1 级（源头供应商）租户ID',
    level2_tenant_id        BIGINT         COMMENT '2 级分销商租户ID',
    level3_tenant_id        BIGINT         COMMENT '3 级分销商租户ID',
    level4_tenant_id        BIGINT         COMMENT '4 级分销商租户ID',
    credit_available_amt    DECIMAL(18,2)  COMMENT '剩余授信额度（元）= 授信额度 - 已用授信',
    start_date              STRING         COMMENT '拉链开始日期，格式 yyyy-MM-dd',
    end_date                STRING         COMMENT '拉链结束日期，格式 yyyy-MM-dd；9999-12-31 表示当前有效',
    etl_time                STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '分销关系维度（1行=1条分销关系×1个有效区间）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_fin_account_df  账户维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_fin_account_df (
    account_id    BIGINT         COMMENT '统一账户ID（源表主键 id）',
    account_no    STRING         COMMENT '账户编号，由流水号生成器生成',
    subject_id    BIGINT         COMMENT '主体ID（商户/分销商/平台）',
    account_type  STRING         COMMENT '账户类型：MERCHANT-商户，DISTRIBUTOR-分销商，PLATFORM-平台',
    tenant_id     BIGINT         COMMENT '租户ID（分库维度）',
    create_time   STRING         COMMENT '创建时间',
    update_time   STRING         COMMENT '更新时间',
    subject_name  STRING         COMMENT '主体名称',
    etl_time      STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '账户维度（1行=1个账户）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_fin_bank_card_df  银行卡维度（脱敏） ==========
CREATE TABLE IF NOT EXISTS dim.dim_fin_bank_card_df (
    bank_card_id      BIGINT         COMMENT '银行卡ID（源表主键 id）',
    card_no           STRING         COMMENT '银行卡编号（系统内ID）',
    subject_id        BIGINT         COMMENT '归属主体ID（商户/分销商）',
    bank_name         STRING         COMMENT '银行名称',
    bank_code         STRING         COMMENT '银行代码',
    card_holder_name  STRING         COMMENT '持卡人姓名（脱敏）',
    card_type         STRING         COMMENT '卡类型：DEBIT-借记卡，CREDIT-授信',
    branch_name       STRING         COMMENT '开户支行',
    card_status       STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    tenant_id         BIGINT         COMMENT '租户ID（分库维度）',
    create_time       STRING         COMMENT '创建时间',
    update_time       STRING         COMMENT '更新时间',
    card_tail_no      STRING         COMMENT '卡号后 4 位（抽取时由 card_number 截取，完整卡号不落仓）',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '银行卡维度（脱敏）（1行=1张卡）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_fin_pay_channel_df  支付渠道维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_fin_pay_channel_df (
    pay_channel_id          BIGINT         COMMENT '支付渠道配置ID（源表主键 id）',
    channel_code            STRING         COMMENT '渠道代码：WECHAT-微信，ALIPAY-支付宝，YEEPAY-易宝，UNIONPAY-银联，BALANCE-余额，CREDIT-授信',
    channel_name            STRING         COMMENT '渠道名称',
    merchant_no             STRING         COMMENT '商户号/子商户号',
    app_code                STRING         COMMENT '应用ID',
    scope_type              STRING         COMMENT '配置范围：PLATFORM-平台，TENANT-租户',
    tenant_id               BIGINT         COMMENT '租户ID（scope=TENANT-租户时必填）',
    channel_status          STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用，PENDING_APPROVAL-待审批',
    create_time             STRING         COMMENT '创建时间',
    update_time             STRING         COMMENT '更新时间',
    collection_mode_type    STRING         COMMENT '商户收款模式：PLATFORM_COLLECT-平台代收，INDEPENDENT-商户独立收款',
    merchant_config_status  STRING         COMMENT '商户支付配置状态：ACTIVE-有效，PENDING_APPROVAL-待审批，INACTIVE-停用',
    etl_time                STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '支付渠道维度（1行=1个支付渠道配置）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_fin_invoice_config_df  发票配置维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_fin_invoice_config_df (
    invoice_config_id       BIGINT         COMMENT '商户发票配置ID（源表主键 id）',
    config_no               STRING         COMMENT '配置编号，格式IC+yyyyMMdd+6位随机',
    tenant_id               BIGINT         COMMENT '归属商户ID',
    invoice_title_name      STRING         COMMENT '发票抬头',
    tax_no                  STRING         COMMENT '税号',
    address_phone_desc      STRING         COMMENT '地址电话',
    bank_branch_name        STRING         COMMENT '开户行及账号',
    default_content_desc    STRING         COMMENT '默认开票内容',
    invoice_provider_code   STRING         COMMENT '开票服务商：BAIWANG-百望，HANGTIAN-航天信息，PIAOYITONG-票易通',
    provider_app_code       STRING         COMMENT '服务商AppID',
    provider_terminal_code  STRING         COMMENT '开票终端号',
    config_status           STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time             STRING         COMMENT '创建时间',
    update_time             STRING         COMMENT '更新时间',
    etl_time                STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '发票配置维度（1行=1个发票配置）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_verify_point_df  核销点维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_verify_point_df (
    verify_point_id        BIGINT         COMMENT '核销点ID（源表主键 id）',
    verify_point_no        STRING         COMMENT '核销点编号，格式VP+yyyyMMdd+6位随机',
    tenant_id              BIGINT         COMMENT '归属商户ID',
    poi_id                 BIGINT         COMMENT '关联POI ID',
    verify_point_name      STRING         COMMENT '核销点名称（如"东门闸机组"）',
    verify_point_type      STRING         COMMENT '类型：GATE-闸机，COUNTER-窗口，SELF_SERVICE-自助机，HANDHELD-手持机',
    verify_point_status    STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    allowed_sku_list_desc  STRING         COMMENT '允许核销的SKU列表（null=全部）',
    device_group_id        BIGINT         COMMENT '绑定设备分组ID',
    create_time            STRING         COMMENT '创建时间',
    update_time            STRING         COMMENT '更新时间',
    device_qty             BIGINT         COMMENT '绑定设备数',
    etl_time               STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '核销点维度（1行=1个核销点）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_code_pool_df  码池维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_code_pool_df (
    code_pool_id     BIGINT         COMMENT '码池ID（源表主键 id）',
    pool_no          STRING         COMMENT '码池编号，格式CP+yyyyMMdd+6位随机',
    tenant_id        BIGINT         COMMENT '归属商户ID',
    pool_type        STRING         COMMENT '池类型：SINGLE_TICKET-单票池，COMBO_TICKET-套票池',
    credential_type  STRING         COMMENT '凭证类型：QR_CODE-二维码，BAR_CODE-条形码',
    capacity_qty     BIGINT         COMMENT '池容量（最大并发码数）',
    allocated_qty    BIGINT         COMMENT '已分配码数',
    recycled_qty     BIGINT         COMMENT '已回收复用码数',
    pool_status      STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time      STRING         COMMENT '创建时间',
    update_time      STRING         COMMENT '更新时间',
    remain_qty       BIGINT         COMMENT '剩余可分配码数 = 容量 - 已分配 + 已回收',
    etl_time         STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '码池维度（1行=1个码池）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_device_df  设备维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_device_df (
    device_id             BIGINT         COMMENT '设备ID（源表主键 id）',
    device_no             STRING         COMMENT '设备编号，格式DEV+yyyyMMdd+6位随机',
    tenant_id             BIGINT         COMMENT '归属商户ID',
    device_type           STRING         COMMENT '设备类型：GATE-闸机，POS-POS 机，HANDHELD-手持机，SELF_SERVICE-自助机，KIOSK-自助终端，FACE_RECOGNITION-人脸识别机',
    device_name           STRING         COMMENT '设备名称（如"东门闸机#3"）',
    poi_id                BIGINT         COMMENT '绑定POI ID',
    device_group_id       BIGINT         COMMENT '设备分组ID',
    capability_list_desc  STRING         COMMENT '设备能力：[SELL-售票，PICKUP-取票，Verify，IDENTIFY-身份识别]',
    device_status         STRING         COMMENT '状态：ACTIVE-有效，OFFLINE-线下或离线，MAINTENANCE-维护中，INACTIVE-停用',
    last_heartbeat_time   STRING         COMMENT '最后心跳时间',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    device_group_no       STRING         COMMENT '设备分组编号',
    device_group_name     STRING         COMMENT '设备分组名称',
    verify_point_id       BIGINT         COMMENT '绑定核销点ID',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '设备维度（1行=1台设备）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_risk_rule_df  风控规则维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_risk_rule_df (
    risk_rule_id            BIGINT         COMMENT '风控规则ID（源表主键 id）',
    rule_no                 STRING         COMMENT '规则编号，格式RR+yyyyMMdd+6位随机',
    rule_name               STRING         COMMENT '规则名称（如"凌晨操作检测"）',
    rule_type               STRING         COMMENT '规则类型：BLACKLIST-黑名单，PURCHASE_LIMIT-购买限制，GEO_FENCE-地理围栏，ABNORMAL_OP-异常操作，DEFAULT_BREAK-爽约',
    scope_type              STRING         COMMENT '范围：GLOBAL-全局，TENANT-租户',
    dimension_type          STRING         COMMENT '维度：USER_ID-用户ID，ID_CARD-身份证，PHONE-手机号，IP，DEVICE_ID-设备ID',
    threshold_desc          STRING         COMMENT '阈值（如"1小时内3次"）',
    time_window_second_qty  INT            COMMENT '时间窗口（秒）',
    action_type             STRING         COMMENT '动作：BLOCK-拦截，WARN-预警，FREEZE-冻结',
    rule_status             STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    created_by_type         STRING         COMMENT '创建方：PLATFORM_ADMIN-平台管理员，TENANT_ADMIN-租户管理员，SYSTEM-系统',
    tenant_id               BIGINT         COMMENT '租户ID（scope=TENANT-租户时必填）',
    create_time             STRING         COMMENT '创建时间',
    update_time             STRING         COMMENT '更新时间',
    etl_time                STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '风控规则维度（1行=1条规则）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_package_df  套餐维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_package_df (
    package_id                    BIGINT         COMMENT '套餐包ID（源表主键 id）',
    package_no                    STRING         COMMENT '套餐编号，格式PKG+yyyyMMdd+6位随机',
    package_name                  STRING         COMMENT '套餐名称（如"基础版""专业版"）',
    package_price_amt             DECIMAL(18,2)  COMMENT '套餐价格（元/年）；源字段单位为分，入仓 ÷100',
    duration_day_qty              INT            COMMENT '有效期（天）',
    feature_permission_list_desc  STRING         COMMENT '功能权限项列表：[{featureCode, enabled}]',
    resource_limit_desc           STRING         COMMENT '资源额度：{smsCount, maxUsers, maxProducts, alarmQuota}',
    package_status                STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time                   STRING         COMMENT '创建时间',
    update_time                   STRING         COMMENT '更新时间',
    app_qty                       BIGINT         COMMENT '包含应用数',
    app_code_list_desc            STRING         COMMENT '包含应用编码列表，逗号分隔',
    etl_time                      STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '套餐维度（1行=1个套餐）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_app_df  应用维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_app_df (
    app_id       BIGINT         COMMENT '应用定义ID（源表主键 id）',
    app_no       STRING         COMMENT '应用编号，格式APP+yyyyMMdd+6位随机',
    app_name     STRING         COMMENT '应用名称',
    app_code     STRING         COMMENT '应用代码（唯一标识）',
    app_type     STRING         COMMENT '类型：BUILTIN-内置，THIRD_PARTY-第三方',
    app_status   STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time  STRING         COMMENT '创建时间',
    update_time  STRING         COMMENT '更新时间',
    etl_time     STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '应用维度（1行=1个应用）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_approval_flow_df  审批流维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_approval_flow_df (
    approval_flow_id  BIGINT         COMMENT '审批流定义ID（源表主键 id）',
    flow_no           STRING         COMMENT '审批流编号，格式AF+yyyyMMdd+8位UUID-自动生成',
    flow_code         STRING         COMMENT '审批流唯一标识码（手动输入，如MERCHANT_ONBOARDING），业务方按此启动审批流',
    flow_name         STRING         COMMENT '审批流名称',
    scope_type        STRING         COMMENT '范围：PLATFORM-平台，TENANT-租户',
    tenant_id         BIGINT         COMMENT '租户ID（scope=TENANT-租户时有效）',
    flow_status       STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    version_no        INT            COMMENT '版本号，同flowCode+scope+tenantId从1递增',
    version_status    STRING         COMMENT '版本状态：DRAFT-草稿，ACTIVE-有效，HISTORICAL-历史版本',
    create_time       STRING         COMMENT '创建时间',
    update_time       STRING         COMMENT '更新时间',
    node_qty          BIGINT         COMMENT '审批节点数',
    timeout_hour_qty  BIGINT         COMMENT '单节点超时时长（小时）',
    etl_time          STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '审批流维度（1行=1个审批流版本）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_notify_template_df  通知模板维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_notify_template_df (
    notify_template_id   BIGINT         COMMENT '通知模板ID（源表主键 id）',
    template_no          STRING         COMMENT '模板编号，格式NT+yyyyMMdd+6位随机',
    template_code        STRING         COMMENT '模板代码（如ORDER_PAID_SMS/VERIFY_NOTICE_MINI）',
    template_name        STRING         COMMENT '模板名称',
    notify_channel_type  STRING         COMMENT '通知渠道：SMS-短信，MINI_PROGRAM_MSG-小程序消息，EMAIL-邮件，WEBHOOK-Webhook，IN_APP-站内信',
    scope_type           STRING         COMMENT '范围：PLATFORM-平台，TENANT-租户',
    tenant_id            BIGINT         COMMENT '租户ID',
    template_status      STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '通知模板维度（1行=1个模板）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_date_f  日期维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_date_f (
    date_code          STRING         COMMENT '日期，格式 yyyy-MM-dd',
    date_no            STRING         COMMENT '日期，格式 YYYYMMDD-与分区一致',
    year_no            INT            COMMENT '年，如 2026',
    quarter_no         INT            COMMENT '季度：1~4',
    month_no           INT            COMMENT '月：1~12',
    week_of_year_no    INT            COMMENT 'ISO 周序号：1~53',
    weekday_no         INT            COMMENT '星期几：1-周一 … 7-周日',
    weekday_mask_code  STRING         COMMENT '星期位值：周一=1，周二=2，周三=4 … 周日=64（与价格点 weekday_mask 对应）',
    weekend_type       INT            COMMENT '是否周末：0-否，1-是',
    holiday_type       INT            COMMENT '日期类型：0-工作日，1-周末，2-法定节假日，3-调休上班日',
    holiday_name       STRING         COMMENT '节假日名称，如 国庆节；非节假日为空',
    vacation_type      INT            COMMENT '是否寒暑假：0-否，1-寒假，2-暑假',
    season_type        INT            COMMENT '旺淡季：1-旺季，2-平季，3-淡季',
    week_start_date    STRING         COMMENT '所在自然周周一日期',
    month_start_date   STRING         COMMENT '所在自然月第一天',
    etl_time           STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '日期维度（1行=1天）'
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_region_f  地区维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_region_f (
    region_id            BIGINT         COMMENT '地区字典ID（源表主键 id）',
    region_code          STRING         COMMENT '行政区划码(国标,如 350203=思明区)',
    parent_id            BIGINT         COMMENT '上级地区ID,0=顶级',
    country_code         STRING         COMMENT '所属国家码(冗余,便于按国过滤)',
    region_level_no      INT            COMMENT '层级: 1=一级行政区(省/州/都道府县),2=市/郡,3=区县,4=乡镇,5=街道;不固化层级',
    region_path_desc     STRING         COMMENT '完整路径含自身,如"中国/福建省/厦门市/思明区"',
    region_status        STRING         COMMENT '状态: ACTIVE-有效，INACTIVE-停用',
    sort_no              INT            COMMENT '排序权重',
    create_time          STRING         COMMENT '创建时间',
    update_time          STRING         COMMENT '更新时间',
    region_name          STRING         COMMENT '地区名称（中文）',
    country_name         STRING         COMMENT '国家名称',
    iso3_code            STRING         COMMENT '国家三位码',
    province_code        STRING         COMMENT '所属省份编码',
    province_name        STRING         COMMENT '所属省份名称',
    city_code            STRING         COMMENT '所属城市编码',
    city_name            STRING         COMMENT '所属城市名称',
    district_code        STRING         COMMENT '区县编码',
    district_name        STRING         COMMENT '区县名称',
    id_card_prefix_code  STRING         COMMENT '身份证前 6 位行政区划码（客源地解析用）',
    etl_time             STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '地区维度（1行=1个末级地区）'
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_currency_f  币种维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_currency_f (
    currency_id           BIGINT         COMMENT '支持币种ID（源表主键 id）',
    currency_code         STRING         COMMENT '币种代码（CNY-人民币，USD，JPY，KRW等）',
    currency_name         STRING         COMMENT '币种名称（中文）',
    currency_en_name      STRING         COMMENT '币种名称（英文）',
    currency_symbol_code  STRING         COMMENT '币种符号（¥/$/¥/₩等）',
    exchange_to_cny_rate  DECIMAL(12,6)  COMMENT '对CNY-人民币汇率',
    currency_status       STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    create_time           STRING         COMMENT '创建时间',
    update_time           STRING         COMMENT '更新时间',
    decimal_digit_qty     BIGINT         COMMENT '金额小数位数',
    etl_time              STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '币种维度（1行=1个币种）'
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_opr_dict_f  枚举码表 ==========
CREATE TABLE IF NOT EXISTS dim.dim_opr_dict_f (
    dict_id         BIGINT         COMMENT '平台字典ID（源表主键 id）',
    dict_type_code  STRING         COMMENT '字典类型（如product_type/verify_type/id_type）',
    dict_code       STRING         COMMENT '字典代码',
    dict_name       STRING         COMMENT '字典名称',
    dict_en_name    STRING         COMMENT '英文名称（i18n）',
    sort_no         INT            COMMENT '排序',
    dict_status     STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用',
    scope_type      STRING         COMMENT '范围：PLATFORM-平台，TENANT-租户',
    tenant_id       BIGINT         COMMENT '租户ID（scope=TENANT-租户时）',
    create_time     STRING         COMMENT '创建时间',
    update_time     STRING         COMMENT '更新时间',
    etl_time        STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '枚举码表（1行=1个枚举值）'
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- ========== dim.dim_mkt_coupon_df  优惠券维度 ==========
CREATE TABLE IF NOT EXISTS dim.dim_mkt_coupon_df (
    coupon_id                 BIGINT         COMMENT '优惠券ID（源表主键 id）',
    coupon_no                 STRING         COMMENT '优惠券编号，格式CPN+yyyyMMdd+6位随机',
    tenant_id                 BIGINT         COMMENT '归属商户ID',
    coupon_name               STRING         COMMENT '优惠券名称',
    coupon_type               STRING         COMMENT '类型：FIXED_AMOUNT-满减固定金额，PERCENT_DISCOUNT-百分比折扣，FREE_VERIFY-免费核销',
    coupon_value_num          BIGINT         COMMENT '优惠值（分或百分比）',
    applicable_sku_list_desc  STRING         COMMENT '适用SKU列表（null=全部）',
    total_qty                 INT            COMMENT '发行总量',
    used_qty                  INT            COMMENT '已使用数量',
    effective_start_time      STRING         COMMENT '生效起始',
    effective_end_time        STRING         COMMENT '生效终止',
    coupon_status             STRING         COMMENT '状态：ACTIVE-有效，INACTIVE-停用，EXPIRED-已过期',
    create_time               STRING         COMMENT '创建时间',
    update_time               STRING         COMMENT '更新时间',
    etl_time                  STRING         COMMENT 'ETL 加载时间，格式 yyyy-MM-dd HH:mm:ss'
)
COMMENT '优惠券维度（1行=1张券模板）'
PARTITIONED BY (travel_date STRING COMMENT '数据日期分区，格式 YYYYMMDD')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

