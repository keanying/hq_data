-- 80条+2959条+126条三个批次（共3165条），不展开事实表以免重复正文。
SELECT c.content_id,c.scenic_id,c.scenic_name,c.attraction_name AS spot_name,
       c.guide_topic_name AS topic,c.guide_title_name AS guide_title,c.guide_content_text AS guide_text,
       c.original_excerpt_text AS original_excerpt,s.source_url AS excerpt_source_url,
       c.guide_content_type,c.collect_batch_id,c.travel_date
FROM opinionhub.dwd_prd_scenic_guide_content_di AS c
LEFT JOIN opinionhub.dwd_prd_scenic_guide_source_di AS s
  ON s.collect_batch_id=c.collect_batch_id AND s.travel_date=c.travel_date AND s.source_id=c.excerpt_source_id
WHERE c.travel_date=20261112
  AND c.collect_batch_id IN ('scenic_web_20261112_first20','scenic_expand_20261112_001','scenic_p1_20261112_001')
ORDER BY c.scenic_id,c.content_id;
