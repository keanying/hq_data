-- =====================================================================================================
-- 导出数据的 SQL（MySQL 8.0+）。和工作台 / 命令行导出用的是同一套条件，按代码整理，方便直接在库里查、核对条数。
-- 表名都是默认名，改过环境变量的按实际表名替换。说明见 docs/数据表与导出SQL.md。
--
-- 用法：先改每段开头的 SET 变量（NULL = 不筛这个条件），再执行下面的 SELECT。
-- 景区表和自建表的排序规则不同时，跨表比较 scenic_id 会报 1267 Illegal mix of collations：
--   给比较的一边加 COLLATE，例如  i.scenic_id = k.scenic_id COLLATE utf8mb4_general_ci
-- =====================================================================================================


-- -----------------------------------------------------------------------------------------------------
-- 1. 景点图片交付（工作台「图片预览 → 交付导出」 / GET /api/images/delivery，代码 db.images_delivery）
--    口径：只要「景区已审核（approval=1）且这个 POI 仍在景区 ctrip_poi_info 保留列表里」的图片；
--          每个 POI 至少 @per_poi_min 张（不够的整个 POI 不出），@per_poi_max=0 不限；人工删除的图片已从表里删掉，不会出现。
--    交付表 ods_prd_poi_image_di 存在时读它（坐标已换成 WGS84），不存在时读工具表 scenic_poi_image（字段同名）。
--    输出字段 = 手册字段，不含分区字段 travel_date。
-- -----------------------------------------------------------------------------------------------------
SET @city = NULL, @province = NULL, @scenic = NULL, @per_poi_min = 1, @per_poi_max = 0;

WITH kept AS (            -- 已审核景区当前保留的 POI（景区 ↔ POI 强对应）
  SELECT s.scenic_id, j.poi_id
  FROM pft_ai_dim_prd_scenic_base_yr_f s
  CROSS JOIN JSON_TABLE(s.ctrip_poi_info, '$[*]' COLUMNS (poi_id VARCHAR(32) PATH '$.poiId')) j
  WHERE COALESCE(s.approval, 0) = 1 AND s.ctrip_poi_info IS NOT NULL AND j.poi_id IS NOT NULL AND j.poi_id <> ''
),
img AS (
  SELECT i.*,
         COUNT(*)     OVER (PARTITION BY i.scenic_id, i.poi_id)                              AS poi_img_qty,
         ROW_NUMBER() OVER (PARTITION BY i.scenic_id, i.poi_id ORDER BY i.review_id, i.image_id) AS rn
  FROM ods_prd_poi_image_di i
  JOIN kept k ON k.scenic_id = i.scenic_id AND k.poi_id = CAST(i.poi_id AS CHAR)
  WHERE i.record_id IS NOT NULL
    AND (@city IS NULL OR i.city = @city)
    AND (@province IS NULL OR i.province = @province)
    AND (@scenic IS NULL OR i.scenic_id = @scenic OR i.scenic_name LIKE CONCAT('%', @scenic, '%'))
)
SELECT record_id, poi_id, poi_name, scenic_id, scenic_name, image_url, lon, lat, province, city, district,
       total_count, review_id, image_id, width, height, collect_time, data_source, is_modified
FROM img
WHERE poi_img_qty >= @per_poi_min AND (@per_poi_max = 0 OR rn <= @per_poi_max)
ORDER BY scenic_id, poi_id, review_id, image_id;

-- 1b. 导出前的量级（GET /api/images/delivery/stats）：景区数 / POI 数 / 张数，以及被排除的张数
WITH kept AS (
  SELECT s.scenic_id, j.poi_id
  FROM pft_ai_dim_prd_scenic_base_yr_f s
  CROSS JOIN JSON_TABLE(s.ctrip_poi_info, '$[*]' COLUMNS (poi_id VARCHAR(32) PATH '$.poiId')) j
  WHERE COALESCE(s.approval, 0) = 1 AND s.ctrip_poi_info IS NOT NULL AND j.poi_id IS NOT NULL AND j.poi_id <> ''
),
img AS (
  SELECT i.scenic_id, i.poi_id, (k.poi_id IS NOT NULL) AS confirmed,
         SUM(k.poi_id IS NOT NULL) OVER (PARTITION BY i.scenic_id, i.poi_id) AS poi_img_qty
  FROM ods_prd_poi_image_di i
  LEFT JOIN kept k ON k.scenic_id = i.scenic_id AND k.poi_id = CAST(i.poi_id AS CHAR)
  WHERE i.record_id IS NOT NULL
    AND (@city IS NULL OR i.city = @city)
    AND (@province IS NULL OR i.province = @province)
    AND (@scenic IS NULL OR i.scenic_id = @scenic OR i.scenic_name LIKE CONCAT('%', @scenic, '%'))
)
SELECT COUNT(DISTINCT CASE WHEN confirmed AND poi_img_qty >= @per_poi_min THEN scenic_id END)                AS scenics,
       COUNT(DISTINCT CASE WHEN confirmed AND poi_img_qty >= @per_poi_min THEN CONCAT(scenic_id, '#', poi_id) END) AS pois,
       SUM(confirmed AND poi_img_qty >= @per_poi_min)                                                         AS images,
       SUM(NOT confirmed)                                                                                     AS dropped_unconfirmed,
       SUM(confirmed AND poi_img_qty < @per_poi_min)                                                          AS dropped_small
FROM img;
-- 注：images 不受 @per_poi_max 截断影响（和工作台的量级一样，per_poi_max 只在导出时截）。


-- -----------------------------------------------------------------------------------------------------
-- 2. 智能客服对话（「训练数据 → 导出数据 → 从 MySQL 导出」「数据查看」 / GET /api/cs/export，代码 cs_synth.export_iter）
--    会话表一行一通，轮次表一行一句；生成信息（生成方式、质检、生成时间、依据）在轮次表 source 列（JSON，每轮都存同一份），
--    筛选用第 1 轮的 source。会话表没有入库时间，「生成日期」看 source.generated_at。
-- -----------------------------------------------------------------------------------------------------
SET @method = NULL;        -- 'llm_rewrite' 改写真实对话 / 'llm_expand' 按景区数据扩展
SET @review = NULL;        -- 'ok' 质检通过 / 'review' 需复核
SET @city = NULL, @scenic = NULL;
SET @date_from = NULL, @date_to = NULL;    -- 会话日期 travel_date，如 20261101
SET @gen_date = NULL;                      -- 生成日期，如 '2026-11-17'

-- 2a. 会话（csv_sessions / L1 / sidecar / 完整 JSONL 都从这里出，最后一列 source 是生成信息）
SELECT s.*, t.source,
       JSON_UNQUOTE(JSON_EXTRACT(t.source, '$.generate_method')) AS generate_method,
       JSON_UNQUOTE(JSON_EXTRACT(t.source, '$.intent_type'))     AS intent_type,
       JSON_UNQUOTE(JSON_EXTRACT(t.source, '$.topic_name'))      AS topic_name,
       (t.source LIKE '%"needs_review": true%')                 AS needs_review,
       JSON_UNQUOTE(JSON_EXTRACT(t.source, '$.generated_at'))    AS generated_at
FROM dwd_cus_cs_session_di s
JOIN dwd_cus_cs_session_turn_di t ON t.session_id = s.session_id AND t.travel_date = s.travel_date AND t.turn_no = 1
WHERE (@method IS NULL OR t.source LIKE CONCAT('%"generate_method": "', @method, '"%'))
  AND (@review IS NULL OR t.source LIKE IF(@review = 'review', '%"needs_review": true%', '%"needs_review": false%'))
  AND (@city IS NULL OR s.scenic_id IN (SELECT scenic_id FROM pft_ai_dim_prd_scenic_base_yr_f WHERE city_name = @city))
  AND (@scenic IS NULL OR s.scenic_id = @scenic OR s.scenic_name LIKE CONCAT('%', @scenic, '%'))
  AND (@date_from IS NULL OR s.travel_date >= @date_from)
  AND (@date_to IS NULL OR s.travel_date <= @date_to)
  AND (@gen_date IS NULL OR t.source LIKE CONCAT('%"generated_at": "', @gen_date, '%'))
ORDER BY s.travel_date, s.session_id;

-- 2b. 这些会话的全部轮次（csv_turns；JSONL 里的 turns 数组就是按 turn_no 排好的这些行）
SELECT tt.session_id, tt.turn_no, tt.role, tt.msg_type, tt.msg_text, tt.agent_id, tt.msg_ts, tt.travel_date, tt.source
FROM dwd_cus_cs_session_di s
JOIN dwd_cus_cs_session_turn_di t  ON t.session_id = s.session_id AND t.travel_date = s.travel_date AND t.turn_no = 1
JOIN dwd_cus_cs_session_turn_di tt ON tt.session_id = s.session_id AND tt.travel_date = s.travel_date
WHERE (@method IS NULL OR t.source LIKE CONCAT('%"generate_method": "', @method, '"%'))
  AND (@review IS NULL OR t.source LIKE IF(@review = 'review', '%"needs_review": true%', '%"needs_review": false%'))
  AND (@city IS NULL OR s.scenic_id IN (SELECT scenic_id FROM pft_ai_dim_prd_scenic_base_yr_f WHERE city_name = @city))
  AND (@scenic IS NULL OR s.scenic_id = @scenic OR s.scenic_name LIKE CONCAT('%', @scenic, '%'))
  AND (@date_from IS NULL OR s.travel_date >= @date_from)
  AND (@date_to IS NULL OR s.travel_date <= @date_to)
  AND (@gen_date IS NULL OR t.source LIKE CONCAT('%"generated_at": "', @gen_date, '%'))
ORDER BY tt.session_id, tt.turn_no;

-- 2c. 条数（导出前看量级 / 核对：GET /api/cs/export/count）
SELECT COUNT(*) AS sessions, SUM(s.turn_cnt) AS turns
FROM dwd_cus_cs_session_di s
JOIN dwd_cus_cs_session_turn_di t ON t.session_id = s.session_id AND t.travel_date = s.travel_date AND t.turn_no = 1
WHERE (@method IS NULL OR t.source LIKE CONCAT('%"generate_method": "', @method, '"%'))
  AND (@review IS NULL OR t.source LIKE IF(@review = 'review', '%"needs_review": true%', '%"needs_review": false%'))
  AND (@gen_date IS NULL OR t.source LIKE CONCAT('%"generated_at": "', @gen_date, '%'));


-- -----------------------------------------------------------------------------------------------------
-- 3. 讲解内容评价 / 个性化讲解（GET /api/gd/export，代码 guide_synth.export_iter）
--    一行一条样本，record_json 是完整样本；其余列是为筛选冗余出来的。L1 / sidecar 拆分见文档。
-- -----------------------------------------------------------------------------------------------------
SET @city = NULL, @scenic = NULL, @review = NULL, @verdict = NULL, @gen_date = NULL;   -- @verdict：合格 / 需改进 / 不合格 / 拒答（只对评价）

-- 3a. 讲解内容评价
SELECT eval_task_id, scenic_id, scenic_name, poi_name, city_name, kb_id, kb_kind, issue_cnt, verdict, total_score, needs_review,
       record_json, travel_date, created_at
FROM dwd_guide_eval_sample_di
WHERE (@city IS NULL OR city_name = @city)
  AND (@scenic IS NULL OR scenic_id = @scenic OR scenic_name LIKE CONCAT('%', @scenic, '%'))
  AND (@review IS NULL OR needs_review = IF(@review = 'review', 1, 0))
  AND (@verdict IS NULL OR verdict = @verdict)
  AND (@gen_date IS NULL OR record_json LIKE CONCAT('%"generated_at": "', @gen_date, '%'))
ORDER BY travel_date, eval_task_id;

-- 3b. 个性化讲解
SELECT request_id, scenic_id, scenic_name, sub_poi_name, city_name, kb_id, kb_kind, visitor_group, char_limit, char_count, needs_review,
       record_json, travel_date, created_at
FROM dwd_guide_narration_sample_di
WHERE (@city IS NULL OR city_name = @city)
  AND (@scenic IS NULL OR scenic_id = @scenic OR scenic_name LIKE CONCAT('%', @scenic, '%'))
  AND (@review IS NULL OR needs_review = IF(@review = 'review', 1, 0))
  AND (@gen_date IS NULL OR record_json LIKE CONCAT('%"generated_at": "', @gen_date, '%'))
ORDER BY travel_date, request_id;

-- 3c. 不展开 JSON 也能直接看的几个关键字段（示例：评价的讲解文字、结论、总分）
SELECT eval_task_id, scenic_name,
       JSON_UNQUOTE(JSON_EXTRACT(record_json, '$.guide_clip.asr_text'))          AS guide_text,
       JSON_UNQUOTE(JSON_EXTRACT(record_json, '$.eval_result.verdict'))          AS verdict,
       JSON_EXTRACT(record_json, '$.eval_result.scores."总分"')                  AS total_score,
       JSON_LENGTH(JSON_EXTRACT(record_json, '$.eval_result.issues'))            AS issue_qty,
       JSON_UNQUOTE(JSON_EXTRACT(record_json, '$.source.generated_at'))          AS generated_at
FROM dwd_guide_eval_sample_di
ORDER BY created_at DESC
LIMIT 100;


-- -----------------------------------------------------------------------------------------------------
-- 4. 景区核对结果（核对面板「导出」 / GET /api/export.csv，代码 db.export_rows）
--    每个景区一行（只含写过 ctrip_poi_info 的）；kept_qty / 两个列表由 ctrip_poi_info（JSON 数组）展开。
-- -----------------------------------------------------------------------------------------------------
SELECT s.scenic_id, s.scenic_name, s.city_name, COALESCE(s.approval, 0) AS approval,
       JSON_LENGTH(s.ctrip_poi_info) AS kept_qty,
       (SELECT GROUP_CONCAT(j.poi_id ORDER BY j.n SEPARATOR '|')
          FROM JSON_TABLE(s.ctrip_poi_info, '$[*]' COLUMNS (n FOR ORDINALITY, poi_id VARCHAR(32) PATH '$.poiId')) j) AS ctrip_poi_id_list,
       (SELECT GROUP_CONCAT(COALESCE(j.poi_name, '') ORDER BY j.n SEPARATOR '|')
          FROM JSON_TABLE(s.ctrip_poi_info, '$[*]' COLUMNS (n FOR ORDINALITY, poi_name VARCHAR(255) PATH '$.poiName')) j) AS ctrip_poi_name_list,
       s.ctrip_poi_info, st.note
FROM pft_ai_dim_prd_scenic_base_yr_f s
LEFT JOIN scenic_ctrip_review_status st ON st.scenic_id = s.scenic_id
WHERE s.ctrip_poi_info IS NOT NULL
ORDER BY s.city_name, s.scenic_id;


-- -----------------------------------------------------------------------------------------------------
-- 5. 参考资料（import_ref_data.py 入库的表）常用查询
-- -----------------------------------------------------------------------------------------------------
-- 5a. 客服对话包：一通对话 + 逐轮（真实 + train 是生成时的问法参考）
SELECT d.dialogue_id, d.data_type, d.city_name, d.attraction_name, d.intent_type, d.scene_type, t.turn_seq, t.role_type, t.turn_content
FROM dwd_cus_service_dialogue_df d
JOIN dwd_cus_service_dialogue_turn_df t ON t.dialogue_id = d.dialogue_id AND t.travel_date = d.travel_date
WHERE d.data_type = '真实' AND d.dataset_split_type = 'train'
ORDER BY d.dialogue_id, t.turn_seq
LIMIT 200;

-- 5b. 讲解包：讲解正文 + 摘录来源（讲解包自带 export_all_current_opinionhub.sql 的写法）
SELECT c.content_id, c.scenic_id, c.scenic_name, c.attraction_name AS spot_name, c.guide_topic_name AS topic, c.guide_title_name AS guide_title,
       c.guide_content_text AS guide_text, c.original_excerpt_text AS original_excerpt, s.source_url AS excerpt_source_url,
       c.guide_content_type, c.collect_batch_id, c.travel_date
FROM dwd_prd_scenic_guide_content_di c
LEFT JOIN dwd_prd_scenic_guide_source_di s
  ON s.collect_batch_id = c.collect_batch_id AND s.travel_date = c.travel_date AND s.source_id = c.excerpt_source_id
ORDER BY c.scenic_id, c.content_id;

-- 5c. 讲解包：一条讲解的事实和每条事实的出处
SELECT f.content_id, f.fact_seq_no, f.fact_attr_name, f.fact_attr_value, s.source_publisher_name, s.source_url
FROM dwd_prd_scenic_guide_fact_di f
JOIN dwd_prd_scenic_guide_fact_source_rel_di r
  ON r.collect_batch_id = f.collect_batch_id AND r.content_id = f.content_id AND r.fact_seq_no = f.fact_seq_no AND r.travel_date = f.travel_date
JOIN dwd_prd_scenic_guide_source_di s
  ON s.collect_batch_id = r.collect_batch_id AND s.source_id = r.source_id AND s.travel_date = r.travel_date
ORDER BY f.content_id, f.fact_seq_no;

-- 5d. 生成样本反查参考资料：扩展客服对话引用了哪些问法参考（source.style_refs[*].dialogue_id）
SELECT s.session_id, j.dialogue_id AS ref_dialogue_id, COALESCE(w.dialogue_content, d.dialogue_content) AS ref_dialogue
FROM dwd_cus_cs_session_di s
JOIN dwd_cus_cs_session_turn_di t ON t.session_id = s.session_id AND t.travel_date = s.travel_date AND t.turn_no = 1
CROSS JOIN JSON_TABLE(t.source, '$.style_refs[*]' COLUMNS (dialogue_id VARCHAR(128) PATH '$.dialogue_id')) j
LEFT JOIN dwd_ref_woz_dialogue_df w ON w.dialogue_id = j.dialogue_id
LEFT JOIN dwd_cus_service_dialogue_df d ON d.dialogue_id = j.dialogue_id
WHERE t.source LIKE '%"generate_method": "llm_expand"%'
LIMIT 100;
