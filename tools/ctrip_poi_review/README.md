# 携程 POI 人工核对工具（景区 ↔ 携程POI）

用途：把 MySQL 里的客户景区（`pft_ai_dim_prd_scenic_base_yr_f`）逐个拿出来，**在你自己的浏览器里实时调用携程搜索**（`m.ctrip.com/restapi/soa2/30668/search`），
在面板上点「保留 / 不留」，结果直接写回 MySQL，最终得到 `scenic_id → ctrip_poi_id 列表`。

```
┌──────────────── 浏览器（you.ctrip.com 页面）────────────────┐
│  油猴脚本 ctrip_poi_review.user.js（右侧核对面板）            │
│   ├─ 携程搜索：用页面自己的 fetch + 你的登录态（同源，无跨域）  │
│   └─ 读写数据：GM_xmlhttpRequest → 本地后端                    │
└──────────────────────────────┬──────────────────────────────┘
                               │ http://127.0.0.1:8765
                     server.py（Flask）──── MySQL
```

搜索走浏览器而不是服务器，是为了用你本机的 IP 和登录态、和你在携程页面上手工搜索完全一样，不需要绕过任何风控。

## 1. 启动本地后端

```bash
pip install -r requirements.txt
```

```bash
export MYSQL_HOST=127.0.0.1 MYSQL_PORT=3306 MYSQL_USER=xxx MYSQL_PASSWORD=xxx MYSQL_DB=xxx
```

```bash
python server.py
```

启动时会自动建两张结果表（见 `schema.sql`），客户景区表只读。浏览器打开 <http://127.0.0.1:8765/api/health> 能看到 `"ok": true` 即可。

| 环境变量 | 默认值 | 说明 |
|---|---|---|
| `MYSQL_HOST` / `MYSQL_PORT` / `MYSQL_USER` / `MYSQL_PASSWORD` / `MYSQL_DB` | `127.0.0.1` / `3306` / `root` / 空 / `hq` | MySQL 连接 |
| `SCENIC_TABLE` | `pft_ai_dim_prd_scenic_base_yr_f` | 客户景区表，可写 `库.表` |
| `SCENIC_COLS` | 见下 | 字段名不同时用 JSON 覆盖，如 `{"name":"scenic_nm"}` |
| `CITIES` | `北京市,上海市,广州市,深圳市,杭州市,成都市,西安市` | 默认只核对这些城市；设为空字符串 = 全部 |
| `REVIEW_TABLE` | `scenic_ctrip_poi_review` | 核对结果表 |
| `STATUS_TABLE` | `scenic_ctrip_review_status` | 景区核对进度表 |
| `CANDIDATE_TABLE` | `scenic_ctrip_candidate` | 离线候选表（可选） |
| `HOST` / `PORT` | `127.0.0.1` / `8765` | 后端监听地址 |

`SCENIC_COLS` 的逻辑名和默认字段：`id=scenic_id, name=scenic_name, alias=scenic_alias, province=province_name, city=city_name, district=district_name, address=scenic_address, lng=scenic_lng, lat=scenic_lat, grade=scenic_grade_level, core_spots=scenic_core_spots`。

### 可选：导入离线候选

离线规则匹配的结果（候选 CSV，含客户数据，不放仓库，单独提供）导入后，面板会把它和携程实时搜索结果放在一起显示，并支持一键「采纳自动分流」。

```bash
python import_candidates.py scenic_ctrip_candidate.csv
```

## 2. 安装油猴脚本

1. Chrome / Edge 安装 Tampermonkey 扩展（Chrome 新版需在扩展详情里打开「允许用户脚本」）。
2. Tampermonkey → 添加新脚本 → 把 `ctrip_poi_review.user.js` 全部内容粘贴进去 → 保存。
3. 第一次连本地后端时 Tampermonkey 会弹窗询问是否允许访问 `127.0.0.1`，选「总是允许」。

## 3. 配置携程搜索请求（只需一次，失效了再抓）

1. 打开 <https://you.ctrip.com/>，按 F12 → Network，过滤 `30668`。
2. 在携程搜索框输入一个景区名（例如 `上海野生动物园`）。
3. 选中 `search` 请求 → 右键 → **Copy → Copy as fetch**。
4. 页面右下角点「POI核对」→ ⚙，把内容粘贴到文本框，下面填你刚才搜的关键词 `上海野生动物园`，点「保存并测试搜索」。

脚本会把请求里的这个关键词替换成占位符，之后每次搜索只换关键词，其他参数（headers、body 里的 head 等）原样复用。

- 测试显示 `✗ 携程返回 Ack=...` 或非 JSON：令牌过期，重新抓一次。
- 返回结果条数少（例如 `total=15` 但只回了 1 条）：看抓到的 body 里有没有类似 pageSize / count 的参数，粘贴前改大。
- 请求间隔默认 1200ms，别调太小，避免被携程限流。

## 4. 核对

- 顶部筛选城市、等级（可选 `5A,4A`）、状态（待核对 / 已完成 / 已跳过 / 全部）、景区名或 ID。
- 打开一个景区会自动用景区名搜索；也可以点别名、「城市+名称」等关键词，或输入自定义关键词。
- 每条携程结果显示类型、poiId、景点ID（url 里的数字）、到客户坐标的距离（仅供参考），以及是否也在离线候选里。
- 非景点结果（酒店、目的地等）没有 poiId / 景点ID，置灰，不能保留。
- 「离线候选」区：规则匹配的候选，带关系类型、置信度、自动分流结果；「采纳自动分流」= 自动保留→保留、自动删除→不留（已人工判过的不覆盖）。
- 底部写备注，点「完成」或「跳过」进入下一个。

| 快捷键 | 作用 |
|---|---|
| `1`–`9` | 保留第 n 条搜索结果（再按一次取消） |
| `Shift` + `1`–`9` | 第 n 条标记为不留 |
| `Enter` | 完成并下一个 |
| `S` | 跳过 |
| `←` / `→` | 上一个 / 下一个景区 |
| `/` | 输入自定义关键词 |
| `Esc` | 收起面板 |

## 5. 结果

- 明细：`scenic_ctrip_poi_review`，一行一个「景区 × 携程POI」，`decision = keep / drop`，带携程原始返回 `raw_json`、关键词、核对人。
- 进度：`scenic_ctrip_review_status`。
- 面板「导出」或 <http://127.0.0.1:8765/api/export.csv>：每个景区一行，`ctrip_poi_id_list` 为保留的 poiId（`|` 分隔）。

字段对应：携程搜索返回的 `poiId` = 携程主档 `ctrip_poi_id`；`id` / url 中的数字 = `ctrip_business_id`。同一景区下按 `poi:<poiId>`（没有 poiId 时用 `biz:<businessId>`）去重。

## 文件

| 文件 | 说明 |
|---|---|
| `server.py` | 本地后端（Flask + PyMySQL） |
| `ctrip_poi_review.user.js` | 油猴脚本：核对面板 + 携程搜索 |
| `import_candidates.py` | 导入离线候选 CSV |
| `schema.sql` | 结果表 / 候选表 DDL（后端会自动建） |
