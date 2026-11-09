-- 携程 POI 人工核对工具用到的表（review.py 启动时会自动 CREATE IF NOT EXISTS，并把排序规则对齐客户景区表；这里供 DBA 预建/审阅）
-- 客户景区表（只读）：pft_ai_dim_prd_scenic_base_yr_f，字段映射见 README

-- 结果直接写在客户景区表上（review.py 启动时没有会自动加）：
ALTER TABLE pft_ai_dim_prd_scenic_base_yr_f
  ADD COLUMN ctrip_poi_info LONGTEXT NULL COMMENT '携程POI列表 JSON：[{"poiId":123,"poiName":"名字","poiUri":"链接"}]；空=未核对，[]=核对过无匹配',
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
