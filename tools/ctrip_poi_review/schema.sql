-- 携程 POI 人工核对工具用到的表（review.py 启动时会自动 CREATE IF NOT EXISTS，并把排序规则对齐客户景区表；这里供 DBA 预建/审阅）
-- 客户景区表（只读）：pft_ai_dim_prd_scenic_base_yr_f，字段映射见 README

-- 结果直接写在客户景区表上（review.py 启动时没有会自动加）：
ALTER TABLE pft_ai_dim_prd_scenic_base_yr_f
  ADD COLUMN ctrip_poi_info LONGTEXT NULL COMMENT '携程POI列表 JSON：[{"poiId":123,"poiName":"名字","poiUri":"链接","addr":"地址","lat":30.86,"lon":121.59}]（GCJ02）；空=未核对，[]=核对过无匹配',
  ADD COLUMN approval TINYINT NOT NULL DEFAULT 0 COMMENT '审核状态：1-已审核 0-未审核';

CREATE TABLE IF NOT EXISTS scenic_ctrip_review_status (
  scenic_id VARCHAR(64) PRIMARY KEY,
  status VARCHAR(8) NOT NULL COMMENT 'done=已审核 skip=跳过（审核状态以客户景区表 approval 为准）',
  note VARCHAR(500) NULL,
  reviewer VARCHAR(64) NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COMMENT='景区核对进度：跳过/备注/核对人';

CREATE TABLE IF NOT EXISTS scenic_ctrip_search_cache (
  keyword VARCHAR(255) PRIMARY KEY COMMENT '搜索关键词',
  item_qty INT NULL,
  capture VARCHAR(16) NULL COMMENT 'network=页面自身请求的返回 dom=下拉DOM',
  result_json MEDIUMTEXT NULL COMMENT '解析后的结果列表',
  searched_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COMMENT='携程页面搜索结果缓存（预抓取/实时搜索都会写）';

CREATE TABLE IF NOT EXISTS ctrip_poi_address_cache (
  ctrip_key VARCHAR(128) PRIMARY KEY COMMENT 'poi:<poiId> 或 biz:<businessId>',
  ctrip_poi_id VARCHAR(32) NULL, ctrip_business_id VARCHAR(32) NULL,
  ctrip_poi_name VARCHAR(255) NULL,
  address VARCHAR(500) NULL COMMENT '携程详情页上的地址',
  page_url VARCHAR(512) NULL,
  fetched_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_poi (ctrip_poi_id), KEY idx_biz (ctrip_business_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='携程 POI 地址缓存（打开详情页读取）';

-- 可选：携程景区主档，由 import_ctrip_master.py 导入，用于显示地址/等级
CREATE TABLE IF NOT EXISTS ctrip_attraction_master (
  ctrip_poi_id VARCHAR(32) PRIMARY KEY, ctrip_business_id VARCHAR(32) NULL,
  attraction_name VARCHAR(255) NULL, city_name VARCHAR(64) NULL, district_name VARCHAR(64) NULL,
  business_area_name VARCHAR(255) NULL, attraction_address VARCHAR(500) NULL, poi_type VARCHAR(64) NULL,
  attraction_level VARCHAR(8) NULL, gcj02_lng DOUBLE NULL, gcj02_lat DOUBLE NULL, ctrip_url VARCHAR(512) NULL,
  KEY idx_biz (ctrip_business_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='携程景区主档（来自交付数据 dim.dim_prd_attraction_df，用于补地址）';

-- 可选：离线规则匹配的候选，由 import_candidates.py 导入
CREATE TABLE IF NOT EXISTS scenic_ctrip_candidate (
  scenic_id VARCHAR(64) NOT NULL, scenic_name VARCHAR(255), city_name VARCHAR(64),
  relation_type VARCHAR(64), confidence VARCHAR(8), match_evidence VARCHAR(255), triage_result VARCHAR(16),
  ctrip_poi_id VARCHAR(32) NOT NULL, ctrip_business_id VARCHAR(32), ctrip_poi_name VARCHAR(255),
  ctrip_district_name VARCHAR(64), dist_to_anchor_m INT, image_qty INT, ctrip_url VARCHAR(512),
  also_in_scenic_ids VARCHAR(500),
  PRIMARY KEY (scenic_id, ctrip_poi_id), KEY idx_poi (ctrip_poi_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='景区-携程POI 离线候选（规则匹配）';

-- 最终结果：SELECT scenic_id, approval, ctrip_poi_info FROM pft_ai_dim_prd_scenic_base_yr_f WHERE approval = 1;

-- ================================================================ 景点图像识别：携程点评图片
-- 交付表：ods_prd_poi_image_di（你们建好的分区天表）。review.py images / 服务采到的图片会同步写入；
-- 写入日期 >= 现有最大分区上界时自动 ADD PARTITION p<上界> VALUES LESS THAN (<次日>)（ODS_AUTO_PARTITION=0 可关）。
-- lon/lat：客户景区表坐标实为 GCJ02，按交付表注释换算成 WGS84 再写（ODS_COORD=gcj02 则原样写）。

-- 工具自己的图片表：去重（同一景区+POI+图片只存一条），并多存缩略图/点评分/发布时间
-- image_id  = 图片链接文件名（去尺寸后缀）的 SHA1 前 16 位十六进制转十进制，取 63 位：
--             CAST(CONV(LEFT(SHA1('0100v1200091giq9766D4'), 16), 16, 10) AS UNSIGNED) & 9223372036854775807
-- record_id = img_<景区ID>_<image_id>，同一景区同一张图永远相同，再次采集不会重复
CREATE TABLE IF NOT EXISTS scenic_poi_image (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  record_id VARCHAR(64) NULL COMMENT '记录ID：img_<景区ID>_<image_id>',
  poi_id BIGINT NOT NULL, poi_name VARCHAR(255) NULL,
  scenic_id VARCHAR(64) NOT NULL, scenic_name VARCHAR(255) NULL,
  image_url VARCHAR(512) NOT NULL, image_thumb_url VARCHAR(512) NULL,
  lon DOUBLE NULL, lat DOUBLE NULL, province VARCHAR(64) NULL, city VARCHAR(64) NULL, district VARCHAR(64) NULL,
  total_count BIGINT NULL COMMENT '该 POI 图片总数（主页 __NEXT_DATA__ poiDetail.imageInfo.imageCount）',
  comment_total INT NULL COMMENT '该 POI 点评总数（getCommentCollapseList.totalCount）',
  review_id BIGINT NULL, image_id BIGINT NOT NULL COMMENT '由图片链接算出', ctrip_image_id BIGINT NULL COMMENT '携程 imageId',
  old_record_id VARCHAR(64) NULL COMMENT '旧版 record_id（迁移时保留）', width INT NULL, height INT NULL,
  review_score DOUBLE NULL, review_publish_time DATETIME NULL,
  review_content TEXT NULL COMMENT '点评内容', review_url VARCHAR(512) NULL COMMENT '点评详情页', tourist_type VARCHAR(32) NULL COMMENT '出游类型',
  collect_time DATETIME NOT NULL, data_source VARCHAR(32) NOT NULL DEFAULT 'OTA-图片爬取', is_modified TINYINT NOT NULL DEFAULT 0,
  UNIQUE KEY uk_scenic_poi_image (scenic_id, poi_id, image_id), KEY idx_poi (poi_id), KEY idx_record (record_id), KEY idx_review (review_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='景点图像识别：携程点评图片';

-- 采集进度（断点续采）
CREATE TABLE IF NOT EXISTS scenic_poi_image_crawl (
  scenic_id VARCHAR(64) NOT NULL, poi_id BIGINT NOT NULL, poi_name VARCHAR(255) NULL, poi_uri VARCHAR(512) NULL,
  status VARCHAR(16) NULL COMMENT 'running / done / empty(无图) / partial / failed', pages_done INT NOT NULL DEFAULT 0,
  total_count INT NULL, review_qty INT NOT NULL DEFAULT 0, image_qty INT NOT NULL DEFAULT 0, message VARCHAR(500) NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (scenic_id, poi_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='点评图片采集进度';
