-- 参考资料表（import_ref_data.py 自动建表；这里是同样的语句，供查看 / 手工建表）。由 python import_ref_data.py --print-ddl 生成

CREATE TABLE IF NOT EXISTS `dim_prd_attraction_df` (
  `seq_no` INT NULL COMMENT '序号',
  `hot_rank` VARCHAR(255) NULL COMMENT '携程热度榜排名，空-不在热度榜',
  `collect_source_name` VARCHAR(255) NULL COMMENT '收录来源：热度榜-携程热度榜 筛选:xx-携程分类筛选（如 筛选:4A及以上）',
  `attraction_name` VARCHAR(255) NULL COMMENT '景区名称',
  `attraction_en_name` VARCHAR(255) NULL COMMENT '景区英文名称',
  `city_name` VARCHAR(255) NULL COMMENT '城市名称',
  `district_name` VARCHAR(255) NULL COMMENT '区县名称',
  `business_area_name` VARCHAR(255) NULL COMMENT '商圈/片区名称',
  `attraction_address` VARCHAR(500) NULL COMMENT '景区地址',
  `poi_type` VARCHAR(255) NULL COMMENT 'POI类型：景点/玩乐/娱乐/购物/校园/美食街区',
  `attraction_level` VARCHAR(255) NULL COMMENT '景区等级：5A-国家5A级 4A-国家4A级 空-无等级或未评级',
  `rating_score` VARCHAR(255) NULL COMMENT '携程评分（满分5）',
  `review_qty` VARCHAR(255) NULL COMMENT '点评数',
  `hot_score` VARCHAR(255) NULL COMMENT '携程热度值（满分10）',
  `rank_list_name` VARCHAR(500) NULL COMMENT '所在榜单名称',
  `ticket_min_price_amt` VARCHAR(255) NULL COMMENT '门票最低价（元），免费-免费开放',
  `price_type` VARCHAR(255) NULL COMMENT '价格类型：门票-售卖起价 门市价-门市价 空-无价格',
  `ticket_rack_price_amt` VARCHAR(255) NULL COMMENT '门市价（元）',
  `ticket_desc` TEXT NULL COMMENT '门票说明',
  `open_time_recent_desc` TEXT NULL COMMENT '近期开放时间',
  `open_time_detail_desc` TEXT NULL COMMENT '详细开放时间',
  `suggest_visit_duration_desc` VARCHAR(255) NULL COMMENT '建议游玩时长',
  `feature_desc` VARCHAR(500) NULL COMMENT '景区特色',
  `tag_names` VARCHAR(500) NULL COMMENT '景区标签，多值用、分隔',
  `attraction_brief_desc` TEXT NULL COMMENT '景区简要介绍',
  `contact_phone` VARCHAR(500) NULL COMMENT '联系电话',
  `gcj02_lng` VARCHAR(255) NULL COMMENT '经度（GCJ02）',
  `gcj02_lat` VARCHAR(255) NULL COMMENT '纬度（GCJ02）',
  `bd09_lng` VARCHAR(255) NULL COMMENT '经度（BD09，百度坐标）',
  `bd09_lat` VARCHAR(255) NULL COMMENT '纬度（BD09，百度坐标）',
  `ctrip_poi_id` VARCHAR(64) NOT NULL COMMENT '携程poiId',
  `ctrip_business_id` VARCHAR(64) NULL COMMENT '携程景点businessId，对应 attraction_id 去掉 ctrip_ 前缀',
  `ctrip_url` VARCHAR(1024) NULL COMMENT '携程景区页链接',
  `travel_date` INT NOT NULL COMMENT '分区字段：数据日期，格式YYYYMMDD',
  `ingest_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间',
  KEY `idx_business` (`ctrip_business_id`),
  KEY `idx_city` (`city_name`),
  PRIMARY KEY (`ctrip_poi_id`, `travel_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='景区维度表（七城景区主档，天级全量快照）';

CREATE TABLE IF NOT EXISTS `dwd_cus_service_dialogue_df` (
  `dialogue_id` VARCHAR(64) NOT NULL COMMENT '对话ID',
  `data_type` VARCHAR(255) NULL COMMENT '数据类型：真实-平台真实问答 合成-模板合成多轮（含工具调用） 改写-真实对话规则改写',
  `city_name` VARCHAR(255) NULL COMMENT '城市名称',
  `attraction_id` VARCHAR(64) NULL COMMENT '景区ID，格式 ctrip_<携程businessId>',
  `attraction_name` VARCHAR(255) NULL COMMENT '景区名称',
  `dataset_split_type` VARCHAR(255) NULL COMMENT '数据集划分：train-训练集 dev-验证集 test-测试集（与讲解按景区对齐；合成与改写仅在train）',
  `turn_qty` INT NULL COMMENT '对话轮次数',
  `is_tool_call` INT NULL COMMENT '是否含工具调用：0-否 1-是',
  `intent_type` VARCHAR(255) NULL COMMENT '用户意图：门票/门票价格/预约/预约购票/开放时间/交通/游玩建议/退改/退改规则/住宿/餐饮/其他',
  `scene_type` VARCHAR(255) NULL COMMENT '服务场景：游前咨询/预订购票/游中服务/订单售后/投诉建议',
  `business_action_type` VARCHAR(255) NULL COMMENT '业务操作：none-无操作 book_ticket-预订门票 refund_ticket-退票 reschedule-改期',
  `is_resolved` INT NULL COMMENT '是否解决：0-未解决 1-已解决',
  `is_transfer_human` VARCHAR(255) NULL COMMENT '是否转人工：0-否 1-是 空-不适用（真实问答）',
  `knowledge_ref_codes` VARCHAR(500) NULL COMMENT '引用的知识条目代码，多值用|分隔',
  `quality_weight_level` VARCHAR(255) NULL COMMENT '质量权重：normal-正常 low-降权（无知识引用等） 空-合成数据不设',
  `generate_method_type` VARCHAR(255) NULL COMMENT '生成方式：template_v2_from_ctrip_master-基于携程主档模板合成 rewrite_rule_v1-规则改写 空-真实数据',
  `source_site_name` VARCHAR(255) NULL COMMENT '来源站点：ctrip-携程 空-合成',
  `source_url` VARCHAR(1024) NULL COMMENT '来源网址',
  `crawl_time` VARCHAR(255) NULL COMMENT '抓取时间（ISO8601，含时区）',
  `first_question_content` TEXT NULL COMMENT '游客首问',
  `first_answer_content` TEXT NULL COMMENT '客服首答',
  `dialogue_content` MEDIUMTEXT NULL COMMENT '对话全文',
  `travel_date` INT NOT NULL COMMENT '分区字段：数据日期，格式YYYYMMDD',
  `ingest_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间',
  KEY `idx_attraction` (`attraction_id`),
  KEY `idx_type` (`data_type`, `dataset_split_type`),
  PRIMARY KEY (`dialogue_id`, `travel_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='文旅客服对话明细表（一行一通对话）';

CREATE TABLE IF NOT EXISTS `dwd_cus_service_dialogue_turn_df` (
  `dialogue_id` VARCHAR(64) NOT NULL COMMENT '对话ID，对应 dwd.dwd_cus_service_dialogue_df.dialogue_id',
  `turn_seq` INT NOT NULL COMMENT '发言序号',
  `role_type` VARCHAR(255) NULL COMMENT '角色：游客-游客发言 客服-客服回复 工具返回-工具调用结果',
  `turn_content` TEXT NULL COMMENT '发言内容',
  `knowledge_ref_codes` VARCHAR(500) NULL COMMENT '引用的知识条目代码，多值用|分隔',
  `tool_name` VARCHAR(255) NULL COMMENT '调用工具：query_availability-查余票 query_order-查订单 get_scenic_info-查景区信息 book_ticket-订票 refund_ticket-退票 reschedule_ticket-改期 transfer_to_human-转人工 空-无调用',
  `tool_args_content` TEXT NULL COMMENT '工具调用参数',
  `travel_date` INT NOT NULL COMMENT '分区字段：数据日期，格式YYYYMMDD',
  `ingest_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间',
  PRIMARY KEY (`dialogue_id`, `turn_seq`, `travel_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='文旅客服对话逐轮明细表（一行一轮发言）';

CREATE TABLE IF NOT EXISTS `dwd_prd_scenic_guide_source_di` (
  `collect_batch_id` VARCHAR(64) NOT NULL COMMENT '采集批次',
  `source_id` VARCHAR(64) NOT NULL COMMENT '来源ID',
  `scenic_id` VARCHAR(64) NOT NULL COMMENT '客户景区ID',
  `scenic_name` VARCHAR(255) NOT NULL,
  `source_url` VARCHAR(2048) NOT NULL,
  `source_title_name` VARCHAR(500) NOT NULL,
  `source_publisher_name` VARCHAR(255) NOT NULL,
  `source_type` TINYINT UNSIGNED NOT NULL COMMENT '来源类型：1-景区运营官网 2-政府 3-博物馆文物机构 4-UNESCO 5-其他可靠机构媒体学术 6-OTA平台 7-旅游社区 8-公开公众号文章 9-公开音视频讲解文字',
  `source_publish_date` DATE NULL,
  `collect_time` DATETIME(3) NOT NULL COMMENT '采集时间（UTC）',
  `source_access_type` TINYINT UNSIGNED NOT NULL,
  `source_evidence_flag` TINYINT UNSIGNED NOT NULL,
  `travel_date` INT UNSIGNED NOT NULL COMMENT '数据日期 YYYYMMDD',
  `ingest_time` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '入库时间',
  CONSTRAINT `ck_guide_source_source_type` CHECK (`source_type` IN (1,2,3,4,5,6,7,8,9)),
  CONSTRAINT `ck_guide_source_source_access_type` CHECK (`source_access_type` IN (1,2,3,4)),
  CONSTRAINT `ck_guide_source_source_evidence_flag` CHECK (`source_evidence_flag` IN (0,1)),
  PRIMARY KEY (`collect_batch_id`, `source_id`, `travel_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='景区讲解来源页面（一行一个来源网页）';

CREATE TABLE IF NOT EXISTS `dwd_prd_scenic_guide_content_di` (
  `collect_batch_id` VARCHAR(64) NOT NULL COMMENT '采集批次',
  `content_id` VARCHAR(64) NOT NULL COMMENT '讲解ID',
  `scenic_id` VARCHAR(64) NOT NULL COMMENT '客户景区ID',
  `scenic_name` VARCHAR(255) NOT NULL,
  `province_name` VARCHAR(255) NULL,
  `city_name` VARCHAR(255) NULL,
  `district_name` VARCHAR(255) NULL,
  `attraction_name` VARCHAR(255) NOT NULL,
  `attraction_relation_type` TINYINT UNSIGNED NOT NULL,
  `poi_id` VARCHAR(64) NULL,
  `poi_name` VARCHAR(255) NULL,
  `poi_namespace_type` TINYINT UNSIGNED NOT NULL,
  `poi_match_status` TINYINT UNSIGNED NOT NULL,
  `guide_topic_name` VARCHAR(255) NOT NULL,
  `guide_title_name` VARCHAR(500) NOT NULL,
  `guide_content_text` MEDIUMTEXT NOT NULL COMMENT '讲解正文',
  `guide_content_type` TINYINT UNSIGNED NOT NULL COMMENT '讲解正文类型：1-依据公开资料整理',
  `original_excerpt_text` TEXT NULL,
  `original_content_type` TINYINT UNSIGNED NOT NULL COMMENT '原文摘录类型：0-无摘录 1-景点文物介绍短摘录 2-真实公开讲解词短摘录 3-真实字幕转写短摘录',
  `excerpt_source_id` VARCHAR(64) NULL,
  `guide_fact_qty` INT UNSIGNED NOT NULL,
  `scope_desc` TEXT NULL,
  `note_desc` TEXT NULL,
  `copyright_auth_status` TINYINT UNSIGNED NOT NULL,
  `copyright_auth_desc` TEXT NULL,
  `collect_time` DATETIME(3) NOT NULL COMMENT '采集时间（UTC）',
  `travel_date` INT UNSIGNED NOT NULL COMMENT '数据日期 YYYYMMDD',
  `ingest_time` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '入库时间',
  CONSTRAINT `ck_guide_content_attraction_relation_type` CHECK (`attraction_relation_type` IN (1,2,3)),
  CONSTRAINT `ck_guide_content_poi_namespace_type` CHECK (`poi_namespace_type` IN (0,1,2,3)),
  CONSTRAINT `ck_guide_content_poi_match_status` CHECK (`poi_match_status` IN (0,1,2)),
  CONSTRAINT `ck_guide_content_guide_content_type` CHECK (`guide_content_type` IN (1,2,3)),
  CONSTRAINT `ck_guide_content_original_content_type` CHECK (`original_content_type` IN (0,1,2,3)),
  CONSTRAINT `ck_guide_content_copyright_auth_status` CHECK (`copyright_auth_status` IN (0,1,2,3)),
  PRIMARY KEY (`collect_batch_id`, `content_id`, `travel_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='景区讲解正文（一行一条讲解）';

CREATE TABLE IF NOT EXISTS `dwd_prd_scenic_guide_fact_di` (
  `collect_batch_id` VARCHAR(64) NOT NULL COMMENT '采集批次',
  `content_id` VARCHAR(64) NOT NULL COMMENT '讲解ID',
  `fact_seq_no` INT UNSIGNED NOT NULL COMMENT '事实序号（从1开始）',
  `scenic_id` VARCHAR(64) NOT NULL COMMENT '客户景区ID',
  `scenic_name` VARCHAR(255) NOT NULL,
  `attraction_name` VARCHAR(255) NOT NULL,
  `fact_attr_name` VARCHAR(255) NOT NULL COMMENT '事实属性',
  `fact_attr_value` TEXT NOT NULL COMMENT '事实值',
  `travel_date` INT UNSIGNED NOT NULL COMMENT '数据日期 YYYYMMDD',
  `ingest_time` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '入库时间',
  PRIMARY KEY (`collect_batch_id`, `content_id`, `fact_seq_no`, `travel_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='讲解事实（一条讲解拆出的属性-值）';

CREATE TABLE IF NOT EXISTS `dwd_prd_scenic_guide_content_source_rel_di` (
  `collect_batch_id` VARCHAR(64) NOT NULL COMMENT '采集批次',
  `content_id` VARCHAR(64) NOT NULL COMMENT '讲解ID',
  `source_id` VARCHAR(64) NOT NULL COMMENT '来源ID',
  `scenic_id` VARCHAR(64) NOT NULL COMMENT '客户景区ID',
  `excerpt_source_flag` TINYINT UNSIGNED NOT NULL,
  `travel_date` INT UNSIGNED NOT NULL COMMENT '数据日期 YYYYMMDD',
  `ingest_time` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '入库时间',
  CONSTRAINT `ck_guide_content_source_rel_excerpt_source_flag` CHECK (`excerpt_source_flag` IN (0,1)),
  PRIMARY KEY (`collect_batch_id`, `content_id`, `source_id`, `travel_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='讲解正文-来源关联';

CREATE TABLE IF NOT EXISTS `dwd_prd_scenic_guide_fact_source_rel_di` (
  `collect_batch_id` VARCHAR(64) NOT NULL COMMENT '采集批次',
  `content_id` VARCHAR(64) NOT NULL COMMENT '讲解ID',
  `fact_seq_no` INT UNSIGNED NOT NULL COMMENT '事实序号（从1开始）',
  `source_id` VARCHAR(64) NOT NULL COMMENT '来源ID',
  `scenic_id` VARCHAR(64) NOT NULL COMMENT '客户景区ID',
  `travel_date` INT UNSIGNED NOT NULL COMMENT '数据日期 YYYYMMDD',
  `ingest_time` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '入库时间',
  PRIMARY KEY (`collect_batch_id`, `content_id`, `fact_seq_no`, `source_id`, `travel_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='讲解事实-来源关联';

CREATE TABLE IF NOT EXISTS `dwd_prd_scenic_guide_collect_task_di` (
  `collect_batch_id` VARCHAR(64) NOT NULL COMMENT '采集批次',
  `scenic_id` VARCHAR(64) NOT NULL COMMENT '客户景区ID',
  `scenic_name` VARCHAR(255) NOT NULL,
  `province_name` VARCHAR(255) NULL,
  `city_name` VARCHAR(255) NULL,
  `district_name` VARCHAR(255) NULL,
  `collect_status` TINYINT UNSIGNED NOT NULL,
  `guide_content_qty` INT UNSIGNED NOT NULL,
  `source_page_qty` INT UNSIGNED NOT NULL,
  `guide_fact_qty` INT UNSIGNED NOT NULL,
  `note_desc` TEXT NULL,
  `travel_date` INT UNSIGNED NOT NULL COMMENT '数据日期 YYYYMMDD',
  `ingest_time` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '入库时间',
  CONSTRAINT `ck_guide_collect_task_collect_status` CHECK (`collect_status` IN (0,1,2,3,4)),
  PRIMARY KEY (`collect_batch_id`, `scenic_id`, `travel_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='讲解采集任务（一行一个景区一个批次）';

CREATE TABLE IF NOT EXISTS `dwd_ref_red_attraction_qa_df` (
  `qa_id` VARCHAR(64) NOT NULL COMMENT '问答ID：RedAttractionQA:<split>:<序号>，与生成数据 source 里的引用一致',
  `split_type` VARCHAR(16) NOT NULL COMMENT '数据集划分：train / validation / test（生成只用 train）',
  `item_seq` INT NOT NULL COMMENT '文件内序号（从0开始）',
  `question_content` TEXT NOT NULL COMMENT '问题',
  `answer_content` TEXT NULL COMMENT '答案',
  `passage_content` TEXT NULL COMMENT '段落（第一段）',
  `passage_qty` INT NOT NULL COMMENT '段落数',
  `passages_json` MEDIUMTEXT NULL COMMENT '多段时的全部段落 JSON（只有一段时为空）',
  `source_file_name` VARCHAR(128) NOT NULL COMMENT '来源文件',
  `ingest_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间',
  KEY `idx_split` (`split_type`, `item_seq`),
  PRIMARY KEY (`qa_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RedAttractionQA 红色景点阅读理解问答（公开研究数据集，景点讲解事实 / 问法参考）';

CREATE TABLE IF NOT EXISTS `dwd_ref_woz_dialogue_df` (
  `dialogue_id` VARCHAR(128) NOT NULL COMMENT '对话ID：<数据集>:<原ID>，与生成数据 source.style_refs 里的一致',
  `dataset_name` VARCHAR(32) NOT NULL COMMENT '数据集：RiSAWOZ（苏州）/ CrossWOZ（北京），均取 train 的景点领域',
  `turn_qty` INT NOT NULL COMMENT '发言条数',
  `attraction_names` VARCHAR(1000) NULL COMMENT '对话里的景点名，多值用|分隔',
  `topic_names` VARCHAR(255) NULL COMMENT '话题：ticket-门票 hours-开放时间 traffic-交通 plan-游玩建议 等，多值用|分隔',
  `first_question_content` TEXT NULL COMMENT '游客首问',
  `dialogue_content` MEDIUMTEXT NOT NULL COMMENT '对话全文（角色：内容，一行一句）',
  `source_file_name` VARCHAR(128) NOT NULL COMMENT '来源文件',
  `ingest_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间',
  KEY `idx_dataset` (`dataset_name`),
  PRIMARY KEY (`dialogue_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RiSAWOZ / CrossWOZ 景点领域对话（公开研究数据集，问法参考，一行一通）';

CREATE TABLE IF NOT EXISTS `dwd_ref_woz_dialogue_turn_df` (
  `dialogue_id` VARCHAR(128) NOT NULL COMMENT '对话ID，对应 dwd_ref_woz_dialogue_df.dialogue_id',
  `dataset_name` VARCHAR(32) NOT NULL COMMENT '数据集',
  `turn_seq` INT NOT NULL COMMENT '发言序号（从1开始）',
  `role_type` VARCHAR(16) NULL COMMENT '角色：游客 / 客服',
  `turn_content` TEXT NOT NULL COMMENT '发言内容',
  `ingest_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库时间',
  PRIMARY KEY (`dialogue_id`, `turn_seq`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RiSAWOZ / CrossWOZ 景点领域对话逐轮（一行一句）';
