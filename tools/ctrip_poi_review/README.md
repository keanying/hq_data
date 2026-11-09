# 携程 POI 人工核对工具（景区 ↔ 携程POI）

把 MySQL 里的客户景区（`pft_ai_dim_prd_scenic_base_yr_f`）逐个拿出来，**用 Playwright 打开真实浏览器，模拟人在携程搜索框里逐字输入景区名**，
读取下拉框里的结果，在页面右侧的核对面板上点「保留 / 不留」，结果直接写回 MySQL，最终得到 `scenic_id → ctrip_poi_id 列表`。

**不直接调用携程接口**：搜索请求都是携程页面在输入后自己发出的（和人工在搜索框打字一样），
工具只是旁路读取该请求的返回（`/restapi/soa2/30668/search`），读不到时退回读下拉框 DOM。

```
python review.py run
   └─ Playwright 打开浏览器 → you.ctrip.com
        ├─ 右侧注入核对面板（panel.js）
        ├─ 点关键词 → 程序点击携程搜索框、逐字输入 → 页面自己请求并弹出下拉框 → 读取结果
        └─ 保留 / 不留 / 完成 → 直接写 MySQL（db.py）
```

## 1. 安装

```bash
pip install -r requirements.txt
```

```bash
playwright install chromium
```

想用本机的 Chrome / Edge 而不是 Playwright 自带的 Chromium，运行时加 `--channel chrome`（或 `msedge`），就不需要上面第二步。

## 2. 配置 MySQL

```bash
export MYSQL_HOST=127.0.0.1 MYSQL_PORT=3306 MYSQL_USER=xxx MYSQL_PASSWORD=xxx MYSQL_DB=xxx
```

Windows PowerShell 用 `$env:MYSQL_HOST="127.0.0.1"` 这样逐个设置。

| 环境变量 | 默认值 | 说明 |
|---|---|---|
| `MYSQL_HOST` / `MYSQL_PORT` / `MYSQL_USER` / `MYSQL_PASSWORD` / `MYSQL_DB` | `127.0.0.1` / `3306` / `root` / 空 / `hq` | MySQL 连接 |
| `SCENIC_TABLE` | `pft_ai_dim_prd_scenic_base_yr_f` | 客户景区表（只读），可写 `库.表` |
| `SCENIC_COLS` | 见下 | 字段名不同时用 JSON 覆盖，如 `{"name":"scenic_nm"}` |
| `CITIES` | `北京市,上海市,广州市,深圳市,杭州市,成都市,西安市` | 默认只核对这些城市；设为空字符串 = 全部 |
| `REVIEW_TABLE` / `STATUS_TABLE` / `CACHE_TABLE` | `scenic_ctrip_poi_review` / `scenic_ctrip_review_status` / `scenic_ctrip_search_cache` | 结果 / 进度 / 搜索缓存，首次运行自动建表 |
| `CANDIDATE_TABLE` | `scenic_ctrip_candidate` | 离线候选表（可选） |

`SCENIC_COLS` 的逻辑名和默认字段：`id=scenic_id, name=scenic_name, alias=scenic_alias, province=province_name, city=city_name, district=district_name, address=scenic_address, lng=scenic_lng, lat=scenic_lat, grade=scenic_grade_level, core_spots=scenic_core_spots`。

可选：导入离线规则匹配的候选（CSV 含客户数据，不放仓库，单独提供）。导入后面板里会和携程搜索结果放在一起，可一键「采纳自动分流」。

```bash
python import_candidates.py scenic_ctrip_candidate.csv
```

## 3. 交互核对

```bash
python review.py run --channel chrome
```

- 会打开一个浏览器窗口（用户目录 `.pw-profile/`，携程登录态会保留，需要登录就在窗口里登录一次）。
- 右下角点「POI核对」打开面板，⚙ 里填核对人。
- 打开一个景区会自动搜景区名：你会看到程序点进携程搜索框、一个字一个字输入、下拉框弹出；面板里同步列出结果。
- 别名、「城市+名称」是现成的关键词按钮，也可以输入自定义关键词；搜过的关键词会缓存，再打开秒出，点「重新搜索」（`R`）会在页面上重新输入。
- 每条结果显示类型、poiId、景点ID（url 里的数字）、到客户坐标的距离（仅供参考）、是否也在离线候选里；酒店等非景点结果置灰，不能保留。
- 如果找不到搜索框（携程改版），在 ⚙ 里点「定位搜索框」，再到页面上点一下携程的搜索框即可。
- 出现验证码时直接在窗口里手动完成，然后继续。

| 快捷键 | 作用 |
|---|---|
| `1`–`9` | 保留第 n 条搜索结果（再按一次取消） |
| `Shift` + `1`–`9` | 第 n 条标记为不留 |
| `Enter` | 完成并下一个 |
| `S` | 跳过 |
| `R` | 在携程页面重新搜索当前关键词 |
| `←` / `→` | 上一个 / 下一个景区 |
| `/` | 输入自定义关键词 |
| `Esc` | 收起面板 |

## 4. 批量预搜索（可选，推荐）

核对前先让程序在后台把景区名都搜一遍，结果进缓存表，核对时直接显示，不用等输入：

```bash
python review.py prefetch --channel chrome --grade 5A,4A
```

参数：`--city 北京市,上海市`、`--grade`、`--status todo|done|skip|all`、`--alias`（别名也搜）、`--refresh`（已缓存也重搜）、`--limit N`、`--throttle-ms 2500`（两次搜索最小间隔，实际随机加 0–40%）、`--max-fail 5`（连续失败几次就停，通常是被限流或出验证码）。
默认有界面运行，`--headless` 可无界面但携程更容易弹验证。

## 5. 导出结果

面板上点「导出」（写到工具目录），或：

```bash
python review.py export -o scenic_ctrip_poi_mapping.csv
```

每个景区一行，`ctrip_poi_id_list` 为保留的 poiId（`|` 分隔）。明细在 `scenic_ctrip_poi_review`（`decision = keep / drop`，带携程原始条目 `raw_json`、关键词、核对人），进度在 `scenic_ctrip_review_status`。

字段对应：携程搜索返回的 `poiId` = 携程主档 `ctrip_poi_id`；`id` / url 中的数字 = `ctrip_business_id`。
同一景区下按 `poi:<poiId>` 去重；只从下拉 DOM 拿到景点ID 时，会尽量从候选表/历史记录补出 poiId。

## 其他参数

| 参数 | 说明 |
|---|---|
| `--profile` | 浏览器用户目录，默认 `./.pw-profile`（保存登录态，已在 .gitignore） |
| `--channel` | `chrome` / `msedge`：用本机浏览器 |
| `--executable-path` | 指定浏览器可执行文件 |
| `--start-url` | 默认 `https://you.ctrip.com/` |
| `--pattern` | 旁路读取的请求 URL 片段，默认 `/restapi/soa2/30668/search`，可多次指定 |

## 文件

| 文件 | 说明 |
|---|---|
| `review.py` | 主程序：Playwright 浏览器 + 模拟输入搜索 + 预搜索 + 导出 |
| `panel.js` | 注入携程页面的核对面板 |
| `db.py` | MySQL 读写 |
| `import_candidates.py` | 导入离线候选 CSV |
| `schema.sql` | 表结构（程序会自动建，供 DBA 审阅） |
