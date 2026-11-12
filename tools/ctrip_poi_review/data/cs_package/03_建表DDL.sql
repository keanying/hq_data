-- 文旅训练数据 建表DDL（Hive），分区字段 travel_date=YYYYMMDD，本次快照 20261104
CREATE DATABASE IF NOT EXISTS dim;
CREATE DATABASE IF NOT EXISTS dwd;
CREATE DATABASE IF NOT EXISTS ads;

CREATE TABLE IF NOT EXISTS dim.dim_prd_attraction_df (
  `seq_no` INT COMMENT '序号',
  `hot_rank` STRING COMMENT '携程热度榜排名，空-不在热度榜',
  `collect_source_name` STRING COMMENT '收录来源：热度榜-携程热度榜 筛选:xx-携程分类筛选（如 筛选:4A及以上）',
  `attraction_name` STRING COMMENT '景区名称',
  `attraction_en_name` STRING COMMENT '景区英文名称',
  `city_name` STRING COMMENT '城市名称',
  `district_name` STRING COMMENT '区县名称',
  `business_area_name` STRING COMMENT '商圈/片区名称',
  `attraction_address` STRING COMMENT '景区地址',
  `poi_type` STRING COMMENT 'POI类型：景点/玩乐/娱乐/购物/校园/美食街区',
  `attraction_level` STRING COMMENT '景区等级：5A-国家5A级 4A-国家4A级 空-无等级或未评级',
  `rating_score` STRING COMMENT '携程评分（满分5）',
  `review_qty` STRING COMMENT '点评数',
  `hot_score` STRING COMMENT '携程热度值（满分10）',
  `rank_list_name` STRING COMMENT '所在榜单名称',
  `ticket_min_price_amt` STRING COMMENT '门票最低价（元），免费-免费开放',
  `price_type` STRING COMMENT '价格类型：门票-售卖起价 门市价-门市价 空-无价格',
  `ticket_rack_price_amt` STRING COMMENT '门市价（元）',
  `ticket_desc` STRING COMMENT '门票说明',
  `open_time_recent_desc` STRING COMMENT '近期开放时间',
  `open_time_detail_desc` STRING COMMENT '详细开放时间',
  `suggest_visit_duration_desc` STRING COMMENT '建议游玩时长',
  `feature_desc` STRING COMMENT '景区特色',
  `tag_names` STRING COMMENT '景区标签，多值用、分隔',
  `attraction_brief_desc` STRING COMMENT '景区简要介绍',
  `contact_phone` STRING COMMENT '联系电话',
  `gcj02_lng` STRING COMMENT '经度（GCJ02）',
  `gcj02_lat` STRING COMMENT '纬度（GCJ02）',
  `bd09_lng` STRING COMMENT '经度（BD09，百度坐标）',
  `bd09_lat` STRING COMMENT '纬度（BD09，百度坐标）',
  `ctrip_poi_id` STRING COMMENT '携程poiId',
  `ctrip_business_id` STRING COMMENT '携程景点businessId，对应 attraction_id 去掉 ctrip_ 前缀',
  `ctrip_url` STRING COMMENT '携程景区页链接'
) COMMENT '景区维度表（七城景区主档，天级全量快照）'
PARTITIONED BY (`travel_date` STRING COMMENT '分区字段：数据日期，格式YYYYMMDD')
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS dim.dim_prd_attraction_merge_log_df (
  `city_name` STRING COMMENT '城市名称',
  `removed_poi_id` STRING COMMENT '被移除条目的携程poiId',
  `removed_business_id` STRING COMMENT '被移除条目的携程businessId',
  `removed_attraction_name` STRING COMMENT '被移除条目的景区名称',
  `kept_poi_id` STRING COMMENT '保留的主条目携程poiId',
  `merge_reason_desc` STRING COMMENT '合并原因说明',
  `before_row_qty` INT COMMENT '合并前该城主档行数',
  `after_row_qty` INT COMMENT '合并后该城主档行数'
) COMMENT '景区主档重复条目合并记录（同一景区多条主档的去重日志）'
PARTITIONED BY (`travel_date` STRING COMMENT '分区字段：数据日期，格式YYYYMMDD')
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS dwd.dwd_prd_attraction_guide_df (
  `guide_id` STRING COMMENT '讲解ID，格式 景区ID#景点ID#讲解点ID',
  `city_name` STRING COMMENT '城市名称',
  `attraction_id` STRING COMMENT '景区ID，格式 ctrip_<携程businessId>',
  `attraction_name` STRING COMMENT '景区名称',
  `sub_attraction_id` STRING COMMENT '景区内景点ID，overview-景区总览',
  `sub_attraction_name` STRING COMMENT '景区内景点名称',
  `guide_point_id` STRING COMMENT '讲解点ID',
  `guide_point_name` STRING COMMENT '讲解点名称',
  `lat` STRING COMMENT '纬度（GCJ02）',
  `lng` STRING COMMENT '经度（GCJ02）',
  `visit_seq` STRING COMMENT '建议游览顺序，空-未定义',
  `guide_content` STRING COMMENT '讲解正文',
  `char_qty` INT COMMENT '讲解正文字数',
  `est_duration_sec` INT COMMENT '预估讲解时长（秒）',
  `target_traveler_type` STRING COMMENT '适合人群：亲子-亲子家庭 研学-研学学生 老年-老年游客，多值用|分隔，空-通用',
  `guide_style_type` STRING COMMENT '讲解风格：讲解-标准讲解',
  `copyright_status` STRING COMMENT '版权状态：unknown-第三方内容版权未确认 cc_by_sa-知识共享署名相同方式共享',
  `dataset_split_type` STRING COMMENT '数据集划分：train-训练集 dev-验证集 test-测试集（按景区8:1:1）',
  `source_site_name` STRING COMMENT '来源站点：visitbeijing-北京旅游网 visitbeijing_article-北京旅游网文章 yllhj-园林绿化局 ctrip-携程 dpm-故宫博物院 gov/bjdch.gov.cn-政府网站 official-景区官网 wikipedia-维基百科',
  `source_url` STRING COMMENT '来源网址',
  `crawl_time` STRING COMMENT '抓取时间（ISO8601，含时区）'
) COMMENT '景区讲解明细表（非百科来源，训练用讲解文本）'
PARTITIONED BY (`travel_date` STRING COMMENT '分区字段：数据日期，格式YYYYMMDD')
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS dwd.dwd_prd_attraction_guide_wiki_df (
  `guide_id` STRING COMMENT '讲解ID，格式 景区ID#景点ID#讲解点ID',
  `city_name` STRING COMMENT '城市名称',
  `attraction_id` STRING COMMENT '景区ID，格式 ctrip_<携程businessId>',
  `attraction_name` STRING COMMENT '景区名称',
  `sub_attraction_id` STRING COMMENT '景区内景点ID，overview-景区总览',
  `sub_attraction_name` STRING COMMENT '景区内景点名称',
  `guide_point_id` STRING COMMENT '讲解点ID',
  `guide_point_name` STRING COMMENT '讲解点名称',
  `lat` STRING COMMENT '纬度（GCJ02）',
  `lng` STRING COMMENT '经度（GCJ02）',
  `visit_seq` STRING COMMENT '建议游览顺序，空-未定义',
  `guide_content` STRING COMMENT '讲解正文',
  `char_qty` INT COMMENT '讲解正文字数',
  `est_duration_sec` INT COMMENT '预估讲解时长（秒）',
  `target_traveler_type` STRING COMMENT '适合人群：亲子-亲子家庭 研学-研学学生 老年-老年游客，多值用|分隔，空-通用',
  `guide_style_type` STRING COMMENT '讲解风格：讲解-标准讲解',
  `copyright_status` STRING COMMENT '版权状态：unknown-第三方内容版权未确认 cc_by_sa-知识共享署名相同方式共享',
  `dataset_split_type` STRING COMMENT '数据集划分：train-训练集 dev-验证集 test-测试集（按景区8:1:1）',
  `source_site_name` STRING COMMENT '来源站点：visitbeijing-北京旅游网 visitbeijing_article-北京旅游网文章 yllhj-园林绿化局 ctrip-携程 dpm-故宫博物院 gov/bjdch.gov.cn-政府网站 official-景区官网 wikipedia-维基百科',
  `source_url` STRING COMMENT '来源网址',
  `crawl_time` STRING COMMENT '抓取时间（ISO8601，含时区）'
) COMMENT '景区讲解百科补充明细表（维基百科CC BY-SA，待法务确认，不计入主口径）'
PARTITIONED BY (`travel_date` STRING COMMENT '分区字段：数据日期，格式YYYYMMDD')
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS dwd.dwd_cus_service_dialogue_df (
  `dialogue_id` STRING COMMENT '对话ID',
  `data_type` STRING COMMENT '数据类型：真实-平台真实问答 合成-模板合成多轮（含工具调用） 改写-真实对话规则改写',
  `city_name` STRING COMMENT '城市名称',
  `attraction_id` STRING COMMENT '景区ID，格式 ctrip_<携程businessId>',
  `attraction_name` STRING COMMENT '景区名称',
  `dataset_split_type` STRING COMMENT '数据集划分：train-训练集 dev-验证集 test-测试集（与讲解按景区对齐；合成与改写仅在train）',
  `turn_qty` INT COMMENT '对话轮次数',
  `is_tool_call` INT COMMENT '是否含工具调用：0-否 1-是',
  `intent_type` STRING COMMENT '用户意图：门票/门票价格/预约/预约购票/开放时间/交通/游玩建议/退改/退改规则/住宿/餐饮/其他',
  `scene_type` STRING COMMENT '服务场景：游前咨询/预订购票/游中服务/订单售后/投诉建议',
  `business_action_type` STRING COMMENT '业务操作：none-无操作 book_ticket-预订门票 refund_ticket-退票 reschedule-改期',
  `is_resolved` INT COMMENT '是否解决：0-未解决 1-已解决',
  `is_transfer_human` STRING COMMENT '是否转人工：0-否 1-是 空-不适用（真实问答）',
  `knowledge_ref_codes` STRING COMMENT '引用的知识条目代码，多值用|分隔',
  `quality_weight_level` STRING COMMENT '质量权重：normal-正常 low-降权（无知识引用等） 空-合成数据不设',
  `generate_method_type` STRING COMMENT '生成方式：template_v2_from_ctrip_master-基于携程主档模板合成 rewrite_rule_v1-规则改写 空-真实数据',
  `source_site_name` STRING COMMENT '来源站点：ctrip-携程 空-合成',
  `source_url` STRING COMMENT '来源网址',
  `crawl_time` STRING COMMENT '抓取时间（ISO8601，含时区）',
  `first_question_content` STRING COMMENT '游客首问',
  `first_answer_content` STRING COMMENT '客服首答',
  `dialogue_content` STRING COMMENT '对话全文'
) COMMENT '文旅客服对话明细表（一行一通对话）'
PARTITIONED BY (`travel_date` STRING COMMENT '分区字段：数据日期，格式YYYYMMDD')
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS dwd.dwd_cus_service_dialogue_turn_df (
  `dialogue_id` STRING COMMENT '对话ID，对应 dwd.dwd_cus_service_dialogue_df.dialogue_id',
  `turn_seq` INT COMMENT '发言序号',
  `role_type` STRING COMMENT '角色：游客-游客发言 客服-客服回复 工具返回-工具调用结果',
  `turn_content` STRING COMMENT '发言内容',
  `knowledge_ref_codes` STRING COMMENT '引用的知识条目代码，多值用|分隔',
  `tool_name` STRING COMMENT '调用工具：query_availability-查余票 query_order-查订单 get_scenic_info-查景区信息 book_ticket-订票 refund_ticket-退票 reschedule_ticket-改期 transfer_to_human-转人工 空-无调用',
  `tool_args_content` STRING COMMENT '工具调用参数'
) COMMENT '文旅客服对话逐轮明细表（一行一轮发言）'
PARTITIONED BY (`travel_date` STRING COMMENT '分区字段：数据日期，格式YYYYMMDD')
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS dwd.dwd_prd_attraction_image_df (
  `image_id` STRING COMMENT '图片ID',
  `city_name` STRING COMMENT '城市名称',
  `ctrip_poi_id` STRING COMMENT '携程poiId',
  `label_poi_id` STRING COMMENT '识别标签POI：重复景区条目统一映射到主POI，切分按此字段计算',
  `attraction_id` STRING COMMENT '景区ID，格式 ctrip_<携程businessId>',
  `attraction_name` STRING COMMENT '景区名称',
  `attraction_level` STRING COMMENT '景区等级：5A-国家5A级 4A-国家4A级 空-无等级或未评级',
  `sub_attraction_name` STRING COMMENT '图片所属景区内子景点名称',
  `image_url` STRING COMMENT '图片链接（仅存链接，未下载）',
  `local_path` STRING COMMENT '本地文件路径，空-未下载',
  `image_width` STRING COMMENT '图片宽度（像素），空-未知',
  `image_height` STRING COMMENT '图片高度（像素），空-未知',
  `source_site_name` STRING COMMENT '来源站点：携程/同程',
  `source_page_url` STRING COMMENT '图片所在来源页面链接',
  `image_caption_desc` STRING COMMENT '图片说明',
  `user_caption_desc` STRING COMMENT '用户配文',
  `author_name` STRING COMMENT '作者昵称',
  `copyright_status` STRING COMMENT '版权状态：unknown-第三方内容版权未确认',
  `ctrip_copyright_flag` STRING COMMENT '携程版权标记：是-携程标注有版权 否-无版权标注 空-非携程或未知',
  `related_guide_ids` STRING COMMENT '关联讲解ID，多值用|分隔，对应 dwd.dwd_prd_attraction_guide_df.guide_id',
  `phash_code` STRING COMMENT '感知哈希（pHash），空-下载时补',
  `content_type` STRING COMMENT '内容类型：景观/建筑/展品/人像/美食/门票/其他，空-下载时补',
  `image_text_split_type` STRING COMMENT '图文对切分：train-训练集 dev-验证集 test-测试集（跟随景区切分）',
  `recognition_split_type` STRING COMMENT '景点识别切分：train-训练集 dev-验证集 test-测试集（图文train景区内按图8:1:1） 仅评测-图文dev/test景区，仅作未见景点评测',
  `lng` STRING COMMENT '经度（GCJ02）',
  `lat` STRING COMMENT '纬度（GCJ02）',
  `district_name` STRING COMMENT '区县名称',
  `crawl_time` STRING COMMENT '抓取时间',
  `remark_desc` STRING COMMENT '备注'
) COMMENT '景区图片链接明细表（七城，携程+同程，仅存链接）'
PARTITIONED BY (`travel_date` STRING COMMENT '分区字段：数据日期，格式YYYYMMDD')
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS dwd.dwd_prd_attraction_image_pilot_df (
  `image_id` STRING COMMENT '图片ID',
  `ctrip_poi_id` STRING COMMENT '携程poiId',
  `attraction_id` STRING COMMENT '景区ID，格式 ctrip_<携程businessId>',
  `attraction_name` STRING COMMENT '景区名称',
  `attraction_level` STRING COMMENT '景区等级：5A-国家5A级 4A-国家4A级 空-无等级或未评级',
  `image_url` STRING COMMENT '图片链接（仅存链接，未下载）',
  `local_path` STRING COMMENT '本地文件路径，空-未下载',
  `image_width` STRING COMMENT '图片宽度（像素），空-未知',
  `image_height` STRING COMMENT '图片高度（像素），空-未知',
  `source_site_name` STRING COMMENT '来源站点：OTA-图片爬取',
  `source_page_url` STRING COMMENT '图片所在来源页面链接',
  `copyright_status` STRING COMMENT '版权状态：unknown-第三方内容版权未确认',
  `ctrip_copyright_flag` STRING COMMENT '携程版权标记：是-携程标注有版权 否-无版权标注 空-非携程或未知',
  `author_name` STRING COMMENT '作者昵称',
  `lng` STRING COMMENT '经度（GCJ02）',
  `lat` STRING COMMENT '纬度（GCJ02）',
  `district_name` STRING COMMENT '区县名称',
  `crawl_time` STRING COMMENT '抓取时间',
  `remark_desc` STRING COMMENT '备注'
) COMMENT '北京景区图片试点明细表（含部分已下载原图）'
PARTITIONED BY (`travel_date` STRING COMMENT '分区字段：数据日期，格式YYYYMMDD')
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS ads.ads_prd_attraction_image_missing_df (
  `ctrip_poi_id` STRING COMMENT '携程poiId',
  `city_name` STRING COMMENT '城市名称',
  `attraction_id` STRING COMMENT '景区ID',
  `attraction_name` STRING COMMENT '景区名称',
  `attraction_level` STRING COMMENT '景区等级：5A/4A/空-无等级',
  `missing_image_type` STRING COMMENT '无图类别：无相册-携程接口明确零图 有相册未抓到-截止前未抓到 同景区重复条目-图片挂在主条目下',
  `missing_reason_desc` STRING COMMENT '原因说明'
) COMMENT '无图景区清单（七城主档中无任何图片的景区及原因）'
PARTITIONED BY (`travel_date` STRING COMMENT '分区字段：数据日期，格式YYYYMMDD')
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS ads.ads_prd_attraction_image_url_check_df (
  `image_id` STRING COMMENT '图片ID',
  `city_name` STRING COMMENT '城市名称',
  `source_site_name` STRING COMMENT '来源站点：携程/同程',
  `image_url` STRING COMMENT '图片链接',
  `check_result_type` STRING COMMENT '抽测结果：可用-可打开 被限流，无法判断-请求被限流 未测（该站已限流停测）-该站限流后停测',
  `http_status_code` STRING COMMENT 'HTTP状态码：200/206-正常 超时-请求超时 空-未测'
) COMMENT '图片链接可用性抽测结果（分层抽样200条）'
PARTITIONED BY (`travel_date` STRING COMMENT '分区字段：数据日期，格式YYYYMMDD')
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS ads.ads_prd_attraction_guide_uncovered_df (
  `ctrip_poi_id` STRING COMMENT '携程poiId',
  `attraction_name` STRING COMMENT '景区名称',
  `attraction_level` STRING COMMENT '景区等级：5A/4A/空-无等级',
  `hot_rank` STRING COMMENT '携程热度排名',
  `current_char_qty` INT COMMENT '现有讲解字数合计',
  `existing_source_names` STRING COMMENT '已有来源站点，多值用|分隔，空-无来源',
  `uncovered_reason_type` STRING COMMENT '未覆盖原因：无任何来源-所有合规来源均无文本 有来源但不足200字-有文本但总字数<200'
) COMMENT '北京讲解未覆盖景区清单（非百科讲解不足200字的景区）'
PARTITIONED BY (`travel_date` STRING COMMENT '分区字段：数据日期，格式YYYYMMDD')
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;
