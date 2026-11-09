-- 携程 POI 人工核对工具用到的表（server.py 启动时会自动 CREATE IF NOT EXISTS，这里供 DBA 预建/审阅）
-- 客户景区表（只读）：pft_ai_dim_prd_scenic_base_yr_f，字段映射见 README

CREATE TABLE IF NOT EXISTS scenic_ctrip_poi_review (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  scenic_id VARCHAR(64) NOT NULL COMMENT '客户景区ID',
  ctrip_key VARCHAR(128) NOT NULL COMMENT '去重键：poi:<poiId> 或 biz:<businessId>',
  ctrip_poi_id VARCHAR(32) NULL COMMENT '携程 poiId',
  ctrip_business_id VARCHAR(32) NULL COMMENT '携程景点 businessId（url 中的数字）',
  ctrip_poi_name VARCHAR(255) NULL COMMENT '携程名称',
  ctrip_type VARCHAR(64) NULL COMMENT '携程搜索结果 type，如 sight',
  ctrip_city_name VARCHAR(64) NULL,
  ctrip_district_name VARCHAR(64) NULL,
  ctrip_lat DOUBLE NULL, ctrip_lng DOUBLE NULL,
  ctrip_url VARCHAR(512) NULL,
  source VARCHAR(16) NOT NULL COMMENT 'search=携程实时搜索 candidate=离线候选',
  keyword VARCHAR(255) NULL COMMENT '搜索关键词',
  decision VARCHAR(8) NOT NULL COMMENT 'keep=保留 drop=不留',
  raw_json TEXT NULL COMMENT '携程返回的原始条目',
  reviewer VARCHAR(64) NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_scenic_ctrip (scenic_id, ctrip_key),
  KEY idx_poi (ctrip_poi_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='景区-携程POI 人工核对结果';

CREATE TABLE IF NOT EXISTS scenic_ctrip_review_status (
  scenic_id VARCHAR(64) PRIMARY KEY,
  status VARCHAR(8) NOT NULL COMMENT 'done=已核对 skip=跳过',
  note VARCHAR(500) NULL,
  reviewer VARCHAR(64) NULL,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4 COMMENT='景区核对进度';

-- 可选：离线规则匹配的候选，由 import_candidates.py 导入
CREATE TABLE IF NOT EXISTS scenic_ctrip_candidate (
  scenic_id VARCHAR(64) NOT NULL, scenic_name VARCHAR(255), city_name VARCHAR(64),
  relation_type VARCHAR(64), confidence VARCHAR(8), match_evidence VARCHAR(255), triage_result VARCHAR(16),
  ctrip_poi_id VARCHAR(32) NOT NULL, ctrip_business_id VARCHAR(32), ctrip_poi_name VARCHAR(255),
  ctrip_district_name VARCHAR(64), dist_to_anchor_m INT, image_qty INT, ctrip_url VARCHAR(512),
  also_in_scenic_ids VARCHAR(500),
  PRIMARY KEY (scenic_id, ctrip_poi_id), KEY idx_poi (ctrip_poi_id)
) DEFAULT CHARSET=utf8mb4 COMMENT='景区-携程POI 离线候选（规则匹配）';

-- 最终结果：景区 -> 携程 poiId 列表
-- SELECT scenic_id, GROUP_CONCAT(ctrip_poi_id SEPARATOR '|') FROM scenic_ctrip_poi_review WHERE decision='keep' GROUP BY scenic_id;
