-- 仅用于已按此前DDL建好的opinionhub六表。未自动执行。
-- 先备份并核对SHOW CREATE TABLE，确认CHECK名称一致；ALTER会隐式提交，可能取得元数据锁。
-- 只扩展既有枚举及说明，不删除业务数据，不改变主键、字段类型或表引擎。
ALTER TABLE opinionhub.dwd_prd_scenic_guide_source_di
    DROP CHECK ck_guide_source_type,
    ADD CONSTRAINT ck_guide_source_type CHECK (source_type IN (1,2,3,4,5,6,7,8,9)),
    MODIFY COLUMN source_type TINYINT UNSIGNED NOT NULL COMMENT '来源类型：1-景区运营官网 2-政府 3-博物馆文物机构 4-UNESCO 5-其他可靠机构媒体学术 6-OTA平台 7-旅游社区 8-公开公众号文章 9-公开音视频讲解文字；不表示所有来源均为官方或权威';
ALTER TABLE opinionhub.dwd_prd_scenic_guide_content_di
    DROP CHECK ck_guide_content_original,
    ADD CONSTRAINT ck_guide_content_original CHECK (original_content_type IN (0,1,2,3)),
    MODIFY COLUMN original_content_type TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '原文摘录类型：0-无摘录 1-景点文物介绍短摘录 2-真实公开讲解词短摘录 3-真实字幕转写短摘录；不得模拟ASR';
