# 数据表与导出 SQL

工作台（`tools/ctrip_poi_review`）用到的全部 MySQL 表、它们之间怎么关联、每种导出实际执行的 SQL。
表名都是默认名，括号里是改表名用的环境变量。可直接执行的 SQL 在 [`export_queries.sql`](../export_queries.sql)，参考资料表的建表语句在 [`schema_ref.sql`](../schema_ref.sql)。

## 一、表清单

### 1. 客户的表（工具只读，或只更新约定的字段）

| 表 | 主键 | 内容 | 工具怎么用 |
|---|---|---|---|
| `pft_ai_dim_prd_scenic_base_yr_f`（`SCENIC_TABLE`） | `scenic_id` | 客户景区表，一行一个景区（约 1.7 万） | 读景区信息；**写两列**：`ctrip_poi_info`（`POI_INFO_COL`，核对后保留的携程 POI，JSON 数组 `[{"poiId","poiName","poiUri"}]`）、`approval`（`APPROVAL_COL`，1-已审核 0-未审核）。新环境没有这张表时 `python import_scenic.py` 从 `data/scenic/` 建表导入 |
| `ods_prd_poi_image_di`（`ODS_IMAGE_TABLE`） | `record_id` + `travel_date`（按天分区） | 景点图片交付表（客户建好） | 采到图片同步写入（坐标换成 WGS84，当天没分区自动加）；人工删除图片时同步删；**图片交付导出从这里读** |
| `dwd_cus_cs_session_di`（`CS_SESSION_TABLE`） | `session_id` + `travel_date` | 智能客服对话：一行一通会话 | 生成时写入（同主键更新）；导出 / 数据查看读 |
| `dwd_cus_cs_session_turn_di`（`CS_TURN_TABLE`） | `session_id` + `turn_no` + `travel_date` | 智能客服对话：一行一句；`source` 列是这通会话的生成信息 JSON（每轮存同一份） | 同上；按生成方式 / 质检 / 生成日期筛选都看第 1 轮的 `source` |

### 2. 景区核对（工具自建，启动时自动建表）

| 表 | 主键 | 内容 |
|---|---|---|
| `scenic_ctrip_review_status`（`STATUS_TABLE`） | `scenic_id` | 核对进度：`done` 已核对 / `skip` 跳过，备注、核对人 |
| `scenic_ctrip_search_cache`（`CACHE_TABLE`） | `keyword` | 携程搜索结果缓存 |
| `ctrip_poi_address_cache`（`ADDR_TABLE`） | `ctrip_key`（`poi:<poiId>` / `biz:<businessId>`） | 携程详情页地址缓存 |
| `ctrip_attraction_master`（`CTRIP_MASTER_TABLE`） | `ctrip_poi_id` | 携程景区主档精简版（`import_ctrip_master.py` 从数据包导入，补地址用） |
| `scenic_ctrip_candidate`（`CANDIDATE_TABLE`） | `scenic_id` + `ctrip_poi_id` | 规则匹配的离线候选（`import_candidates.py` 导入，整表覆盖） |
| `scenic_ai_judge`（`AI_TABLE`） | `scenic_id` + `sig` | AI 辅助核对结果缓存（`sig` = 模型 + 候选集合签名） |
| `scenic_ctrip_poi_review`（`REVIEW_TABLE`） | — | 旧版明细表，只在启动时一次性迁移到 `ctrip_poi_info`，之后不再使用 |

### 3. 景点图片（工具自建）

| 表 | 主键 | 内容 |
|---|---|---|
| `scenic_poi_image`（`IMAGE_TABLE`） | `id` 自增；唯一键 `scenic_id + poi_id + image_id` | 工具自己的图片表，比交付表多存缩略图、点评内容 / 评分 / 发布时间、携程 imageId 等；交付表不存在时导出读这里 |
| `scenic_poi_image_crawl`（`CRAWL_TABLE`） | `scenic_id` + `poi_id` | 采集进度（断点续采）：状态、翻到第几页、读了多少点评、**那次新增了多少张**（历史记录，删图后不回减） |
| `scenic_poi_image_deleted`（`IMAGE_DELETED_TABLE`） | `record_id` | 人工删除的图片；删除时同时从图片表和交付表删掉，再采集时跳过这些 `record_id` |

### 4. 生成的训练数据（工具自建；客服对话两张表见上面客户的表）

| 表 | 主键 | 内容 |
|---|---|---|
| `dwd_guide_eval_sample_di`（`GUIDE_EVAL_TABLE`） | `eval_task_id` | 讲解内容评价样本：`record_json` 是完整样本（poi + kb_entry + guide_clip + eval_result + source），其余列为筛选冗余（城市、结论、总分、是否需复核…） |
| `dwd_guide_narration_sample_di`（`GUIDE_NARR_TABLE`） | `request_id` | 个性化讲解样本：`record_json` 是完整样本（请求 + reference_narration + source） |

### 5. 设置

| 表 | 主键 | 内容 |
|---|---|---|
| `hq_app_settings`（`SETTINGS_TABLE`） | `scope` + `name` | 工作台设置（AI 判断、核对、采集、浏览器、训练数据各模式参数）；`scope=migrations` 记录一次性数据修正做过没有 |

### 6. 参考资料（新增，`import_ref_data.py` 建表入库）

生成训练数据用的参考资料原来只在仓库 `data/` 的文件里，现在可以入库。建表语句见 `schema_ref.sql`。

| 组 | 表 | 主键 | 行数 | 内容 / 用途 |
|---|---|---|---|---|
| cs | `dim_prd_attraction_df` | `ctrip_poi_id` + `travel_date` | 7,888 | 七城携程景点主档（34 列：等级、票价、开放时间、简介、坐标、poiId / businessId…）。客服对话包里景点ID → poiId 的对应关系 |
| cs | `dwd_cus_service_dialogue_df` | `dialogue_id` + `travel_date` | 11,468 | 文旅客服对话，一行一通（真实 5,668 / 合成 4,784 / 改写 1,016）。改写模式的原始对话；扩展模式的问法参考（只用 真实 + train） |
| cs | `dwd_cus_service_dialogue_turn_df` | `dialogue_id` + `turn_seq` + `travel_date` | 47,618 | 上表的逐轮发言 |
| guide | `dwd_prd_scenic_guide_source_di` | `collect_batch_id` + `source_id` + `travel_date` | 3,135 | 讲解来源网页（网址、发布者、来源类型） |
| guide | `dwd_prd_scenic_guide_content_di` | `collect_batch_id` + `content_id` + `travel_date` | 3,165 | 讲解正文（215 个景区） |
| guide | `dwd_prd_scenic_guide_fact_di` | `collect_batch_id` + `content_id` + `fact_seq_no` + `travel_date` | 19,712 | 讲解拆出的事实（属性 - 值），扩展模式「景点讲解」主题和讲解评价 / 个性化讲解的知识 |
| guide | `dwd_prd_scenic_guide_content_source_rel_di` | 四列主键 | 5,920 | 正文 - 来源关联 |
| guide | `dwd_prd_scenic_guide_fact_source_rel_di` | 五列主键 | 21,646 | 事实 - 来源关联 |
| guide | `dwd_prd_scenic_guide_collect_task_di` | `collect_batch_id` + `scenic_id` + `travel_date` | 235 | 采集任务（每个景区每批次） |
| redqa | `dwd_ref_red_attraction_qa_df` | `qa_id` | 15,262 | RedAttractionQA（train 8,981 / validation 3,205 / test 3,076）。`qa_id` 格式 `RedAttractionQA:train:<序号>`，和生成数据 `source` 里的引用一致；生成只用 train |
| woz | `dwd_ref_woz_dialogue_df` | `dialogue_id` | 6,154 | RiSAWOZ（苏州 2,000）/ CrossWOZ（北京 4,154）train 的景点领域对话，一行一通；`dialogue_id` 和扩展客服对话 `source.style_refs` 里的一致 |
| woz | `dwd_ref_woz_dialogue_turn_df` | `dialogue_id` + `turn_seq` | 36,008 | 上表的逐轮发言 |

- 讲解包六表的结构和讲解包自带的 `data_2_database.py` 要求的完全一致（字段、类型、可空、主键、CHECK、`ingest_time DATETIME(3)`），库里已经用它导过的话，这里只做同主键更新，不改表结构。
- 客服对话包三张表的字段和注释照包里的 `03_建表DDL.sql`（Hive）转换：分区字段 `travel_date` 变成普通列并进主键；Hive 里的空串存 `NULL`；原本是字符串的数值（评分、票价、点评数）保持字符串，不做转换。
- 每张参考资料表都有 `ingest_time`（入库时间）。

## 二、表之间怎么关联

```
客户景区表 pft_ai_dim_prd_scenic_base_yr_f
  scenic_id ──┬── scenic_ctrip_review_status.scenic_id / scenic_ctrip_candidate.scenic_id / scenic_ai_judge.scenic_id
              ├── ctrip_poi_info[*].poiId ── 携程 poiId ── ctrip_attraction_master.ctrip_poi_id / dim_prd_attraction_df.ctrip_poi_id
              ├── scenic_poi_image.scenic_id + poi_id ── ods_prd_poi_image_di（record_id 相同）
              │       record_id = img_<景区ID>_<image_id>，image_id 由图片链接算出；删除的进 scenic_poi_image_deleted
              ├── dwd_cus_cs_session_di.scenic_id ── dwd_cus_cs_session_turn_di（session_id + travel_date）
              └── dwd_guide_eval_sample_di.scenic_id / dwd_guide_narration_sample_di.scenic_id

生成样本 → 参考资料（都记在样本的 source JSON 里）
  改写客服对话  source.dialogue_id            → dwd_cus_service_dialogue_df.dialogue_id
  扩展客服对话  source.style_refs[*].dialogue_id → dwd_ref_woz_dialogue_df / dwd_cus_service_dialogue_df
               source.knowledge.unit_id      → 讲解包 content_id 或 RedAttractionQA qa_id
  讲解评价 / 个性化讲解  source.unit_id / fact_sources → 讲解包 content / source
```

> 景区表和工具自建表的排序规则可能不同，跨表比较 `scenic_id` 报 `1267 Illegal mix of collations` 时，给一边加 `COLLATE`。
> 工具自己建表时会跟景区表对齐排序规则（参考资料表也是：景区表是 utf8mb4 时用它的排序规则）。

## 三、导出：入口、SQL、字段

可执行的完整 SQL 在 `export_queries.sql`，下面说明每种导出读哪些表、按什么条件、文件里是什么。
**所有导出都是导出那一刻从表里查的**，没有预先算好的统计；人工删除的图片、清理掉的样本都不会出现。

### 1. 景点图片交付（图片预览 → 交付导出；`GET /api/images/delivery`）

- 读 `ods_prd_poi_image_di`（不存在时读 `scenic_poi_image`），按 `scenic_id, poi_id, review_id, image_id` 排序。
- 只要「景区 `approval=1` 且 POI 仍在这个景区的 `ctrip_poi_info` 里」的图片——景区没审核、POI 被取消的都排除（`dropped_unconfirmed`）。
- 每个 POI 至少 `per_poi_min` 张，不够的整个 POI 不出（`dropped_small`）；`per_poi_max` 每个 POI 最多几张（0 不限）。
- 字段：`record_id poi_id poi_name scenic_id scenic_name image_url lon lat province city district total_count review_id image_id width height collect_time data_source is_modified`（不含 `travel_date`）。
- `total_count` 是携程页面上这个 POI 的图片总数（手册口径），不是我们采到 / 交付的张数，删图后不变；只保证不小于已采张数。
- 导出前的量级：`GET /api/images/delivery/stats`（SQL 见 1b）。
- 代码里「已审核 POI」是 Python 解析 `ctrip_poi_info` 得到的，SQL 里用 `JSON_TABLE` 展开，结果相同（需要 MySQL 8.0）。

### 2. 智能客服对话（训练数据 → 导出数据 → 从 MySQL 导出；数据查看；`GET /api/cs/export`）

- 会话表 JOIN 第 1 轮（`turn_no = 1`）拿 `source`，按条件筛选会话，再按会话取全部轮次。
- 条件：生成方式（`source` 里 `"generate_method": "llm_rewrite" / "llm_expand"`）、质检（`"needs_review": true / false`）、城市（先查景区表这个城市的 `scenic_id`）、景区 ID / 名称、会话日期 `travel_date`、生成日期（`source.generated_at` 那天）、会话 ID。
- 格式：

| 格式 | 内容 |
|---|---|
| 标注交付 L1 JSONL | `session_id channel visitor_id scenic_id scenic_name start_time related_order_id turns session_duration_sec`（不含答案 / 标签，给标注员） |
| 溯源 sidecar JSONL | `session_id end_type satisfaction_score source`（和 L1 用 `session_id` 关联） |
| 完整 JSONL / JSON | L1 + `end_type satisfaction_score source` |
| 会话表 CSV | 会话表各列 + `generate_method intent_type topic_name needs_review check_flags source` |
| 轮次表 CSV | `session_id turn_no role msg_type msg_text agent_id msg_ts travel_date source` |

### 3. 讲解内容评价 / 个性化讲解（同上入口；`GET /api/gd/export?task=eval|narr`）

- 单表查询，`record_json` 就是完整样本；条件：城市、景区、质检（`needs_review`）、结论（`verdict`，只对评价）、生成日期、样本 ID。
- 格式：

| 格式 | 讲解内容评价 | 个性化讲解 |
|---|---|---|
| 标注交付 L1 JSONL | `eval_task_id poi kb_entry guide_clip` | `request_id scene request_time poi sub_poi_knowledge visitor_profile task_params` |
| 溯源 sidecar JSONL | `eval_task_id eval_result source` | `request_id reference_narration source` |
| 完整 JSONL / JSON / CSV | `record_json` 全部（CSV 是表的各列 + `record_json`） | 同左 |

### 4. 景区核对结果（核对面板「导出」；`GET /api/export.csv`）

- 景区表里写过 `ctrip_poi_info` 的景区，每个一行：`scenic_id scenic_name city_name approval kept_qty ctrip_poi_id_list ctrip_poi_name_list ctrip_poi_info note`（列表用 `|` 分隔）。

### 5. 数据修正（`data_fix.py`）

- 读 `tools/q_data` 下客户交付的文件，结果写到 `out/` 目录的文件里，**不读写数据库**。

## 四、参考资料入库

```bash
cd tools/ctrip_poi_review
python import_ref_data.py --dry-run        # 只读文件、校验（主键不重复、必填不为空、不超长）、报条数，不连库
python import_ref_data.py                  # 全部：建表（已有不动）+ 写入，同主键的更新，可重复跑
python import_ref_data.py --only cs,guide  # 只导这几组：cs guide redqa woz
python import_ref_data.py --replace        # 先删掉本次文件涉及的批次再写（文件里删掉的行库里也删），不影响别的批次
python import_ref_data.py --print-ddl      # 打印建表语句（= schema_ref.sql）
```

- 连接同工作台（`MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD / MYSQL_DB`）。
- 每张表一个事务；写完按批次（`travel_date` / 采集批次 / split / 数据集）核对库里条数和文件一致，不一致整表回滚。
- 「批次」用来界定 `--replace` 删哪些：客服对话包按 `travel_date`，讲解包按 `collect_batch_id + travel_date`，RedAttractionQA 按 split，WOZ 按数据集。
- 讲解包读的是 `data/guide/*/data_all/`（三个批次合并的全量），用讲解包自带脚本的读取和校验逻辑（类型、枚举、关联完整性）。
- 客户景区表不在这里，用 `python import_scenic.py`。
- 工作台生成时目前仍读 `data/` 下的文件；入库是为了在库里查询、关联生成样本做溯源。
