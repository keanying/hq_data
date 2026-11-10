# 携程 POI 人工核对工具（景区 ↔ 携程POI）

把 MySQL 里的客户景区（`pft_ai_dim_prd_scenic_base_yr_f`）逐个拿出来，**用 Playwright 打开真实浏览器，模拟人在携程搜索框里逐字输入景区名**，
读取下拉框里的结果，在页面右侧的核对面板上点「保留」，结果直接写回客户景区表的两个字段：

- `ctrip_poi_info`（LONGTEXT）：保留的携程 POI 列表；NULL=还没核对，`[]`=审核过但没有匹配的 POI

  ```json
  [{"poiId":91765,"poiName":"召稼楼古镇","poiUri":"https://you.ctrip.com/sight/shanghai2/110249.html",
    "addr":"上海市闵行区沈杜公路2059号","lat":31.073066,"lon":121.549441}]
  ```

  `addr` / `lat` / `lon` 优先取携程搜索结果，缺的用携程主档补；坐标是携程的 GCJ02（与携程主档一致）。
  保留后再「查地址」读到的地址会自动写回；启动时会给已有记录补齐缺的 addr/lat/lon。
- `approval`（TINYINT）：审核状态，1-已审核 0-未审核

两个字段首次运行时自动 `ALTER TABLE … ADD COLUMN`（没有 ALTER 权限时，终端会打印要请 DBA 执行的 SQL）。

**不直接调用携程接口**：搜索请求都是携程页面在输入后自己发出的（和人工在搜索框打字一样），
工具只是旁路读取页面在输入期间收到的响应（xhr / fetch / JSONP 都支持），挑出含完整关键词、带结果列表的那个解析；
`/restapi/soa2/30668/search` 只是优先匹配，不同页面用不同接口也能识别。都读不到时退回读下拉框文字（这时没有ID，不能保存）。

```
python review.py run
   └─ Playwright 打开浏览器 → you.ctrip.com
        ├─ 右侧注入核对面板（panel.js）
        ├─ 点关键词 → 程序点击携程搜索框、逐字输入 → 页面自己请求并弹出下拉框 → 读取结果
        └─ 保留 / 审核完成 → 直接写客户景区表的 ctrip_poi_info / approval（db.py）
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
| `CITIES` | `北京市,上海市,广州市,深圳市,杭州市,成都市,西安市` | 默认只核对这些城市；`CITIES=ALL`（或运行时加 `--all-cities`）= 全国 |
| `POI_INFO_COL` / `APPROVAL_COL` | `ctrip_poi_info` / `approval` | 客户景区表上存结果 / 审核状态的字段名，没有会自动新增 |
| `STATUS_TABLE` / `CACHE_TABLE` / `ADDR_TABLE` | `scenic_ctrip_review_status` / `scenic_ctrip_search_cache` / `ctrip_poi_address_cache` | 跳过与备注 / 搜索缓存 / 地址缓存，首次运行自动建表 |
| `REVIEW_TABLE` | `scenic_ctrip_poi_review` | 旧版的结果明细表；存在时启动会把其中「保留」的记录迁移到 `ctrip_poi_info`（只迁字段为空的景区），之后不再使用 |
| `CANDIDATE_TABLE` | `scenic_ctrip_candidate` | 离线候选表（可选） |

`SCENIC_COLS` 的逻辑名和默认字段：`id=scenic_id, name=scenic_name, alias=scenic_alias, province=province_name, city=city_name, district=district_name, address=scenic_address, lng=scenic_lng, lat=scenic_lat, grade=scenic_grade_level, core_spots=scenic_core_spots`。

可选：导入离线规则匹配的候选（CSV 含客户数据，不放仓库，单独提供）。导入后面板里会和携程搜索结果放在一起，可一键「采纳自动分流」。

```bash
python import_candidates.py scenic_ctrip_candidate.csv
```

### 推荐：导入携程主档，用来显示每条结果的地址

携程搜索接口只给城市/区和坐标，不给地址。把交付数据里的携程景区主档导进 MySQL 后，搜索结果和离线候选都会按 poiId / 景点ID 直接显示地址、等级：

```bash
python import_ctrip_master.py dim.dim_prd_attraction_df.csv
```

主档里没有的 POI，面板上点「查地址」（或「补全地址」一次补完当前所有缺地址的条目），程序会在后台标签页打开该 POI 的携程详情页，读出页面上的「地址」，结果缓存到 `ctrip_poi_address_cache`。

## 3. 交互核对

启动时会先自检 MySQL：连不上、找不到客户景区表、缺字段都会直接在终端说明原因并退出（找不到表时会列出库里名字相近的表）。
自检通过会打印「MySQL 正常：客户景区表 … 共 N 行」。

```bash
python review.py run --channel chrome
```

- 会打开一个浏览器窗口（用户目录 `.pw-profile/`，携程登录态会保留，需要登录就在窗口里登录一次）。
- 右下角点「POI核对」打开面板，⚙ 里填核对人。
- 打开一个景区会自动搜景区名：你会看到程序点进携程搜索框、一个字一个字输入、下拉框弹出；面板里同步列出结果。
- **依次搜索**：景区名没搜到「名称一致且地址相近」的结果时，自动接着搜别名、「城市+名称」（⚙ 里可再开「搜核心景点」，默认只用来比对），
  能自动通过就停，每个景区最多再搜 8 个词；多次搜索的结果合并去重显示，每条标出是搜哪个词得到的。关键词按钮上 ✓ 表示已搜过（后面是 POI 条数）。
  依次搜索中可点「停止」；⚙ 里可关掉「接着搜别名」或「再搜核心景点」。与核心景点同名的结果标「核心景点」（只提示，不作为自动通过的条件）。
- 别名、「城市+名称」、核心景点都是现成的关键词按钮，也可以输入自定义关键词；搜过的关键词会缓存，再打开秒出，点「重新搜索」（`R`）会在页面上重新输入。
- 每条结果三行：名称 + 类型/等级/离线候选标签；📍 地址（与客户地址比对，标「同区」「地址相近」或「不同区」，并注明来自主档/详情页/搜索结果）；城市、poiId、景点ID、距客户坐标。
- 景点（sight）、购物（shop）、玩乐、美食等带 poiId 的结果都算 POI，参与核对，编号对应数字快捷键；酒店、目的地等非 POI 折叠在「其他结果」里。
- **自动审核通过**：至少一条携程 POI「名称一致」，且满足「地址相近 / 门牌一致 / 同省市区」之一时，面板显示倒计时提示，
  2 秒后把应保留的 POI 写进 `ctrip_poi_info`、`approval=1`，备注写「自动审核：名称「…」与景区名一致，门牌一致（…）」，自动进入下一个。
  倒计时中按 `Esc` / 点「取消」或手动点任何「保留」都会取消。判定逻辑在 `match.py`，和批量命令同一套：
  - 名称一致：去掉省市区前缀和「景区/旅游区…」后缀后与景区名或别名相同（分店「xx(某某店)」不算），标「名称一致」
  - 子景点：「景区名-xx / 景区名·xx」，或名字里直接带景区名/别名（如「颐和园博物馆」），标「子景点」
  - 门牌一致：两边地址的「路/街/巷… + 门牌号」相同（如都是「虎坊路3号」），算地址相近，标「门牌一致」
  - 同省市区：城市、区县都一致（区县看携程主档或地址）；判断不出区县时，同城且坐标 ≤ 3km 也算
  - 多个同名 POI：有「门牌一致 / 地址相近」的就以它为准，其余只是同区的同名 POI 不保留、标「同名·别处」；
    多个同名又定不下来（都只是同区、彼此不在一处）时拿不准，标「同名多个」，不自动保留、不自动通过，交给人
  - 筛选「自动通过」可以抽查这批；⚙ 里可关闭。
- **自动保留**：「地址相近 / 门牌一致」的，以及与景区同省市区的「名称一致」「子景点」，自动保留并标「自动」（「同名多个」「同名·别处」除外）；
  其他城市/区县的同名结果（如深圳的「阳台山」、重庆的「湖广会馆」）不保留。只对未审核的景区生效；手动取消过的不再自动选；⚙ 里可关闭。
- **依次搜索**：景区名没搜到「名称一致且地址相近」的结果时，自动接着搜别名、「城市+名称」（⚙ 里可再开「搜核心景点」，默认只用来比对），
  能自动通过就停，每个景区最多再搜 8 个词；多次搜索的结果合并去重显示，每条标出是搜哪个词得到的。关键词按钮上 ✓ 表示已搜过（后面是 POI 条数）。
  依次搜索中可点「停止」；⚙ 里可关掉「接着搜别名」或「再搜核心景点」。与核心景点同名的结果标「核心景点」（只提示，不作为自动通过的条件）。
- 别名、「城市+名称」、核心景点都是现成的关键词按钮，也可以输入自定义关键词；搜过的关键词会缓存，再打开秒出，点「重新搜索」（`R`）会在页面上重新输入。
- 每条结果三行：名称 + 类型/等级/离线候选标签；📍 地址（与客户地址比对，标「同区」「地址相近」或「不同区」，并注明来自主档/详情页/搜索结果）；城市、poiId、景点ID、距客户坐标。
- 景点（sight）、购物（shop）、玩乐、美食等带 poiId 的结果都算 POI，参与核对，编号对应数字快捷键；酒店、目的地等非 POI 折叠在「其他结果」里。
- **无人接管自动跳过**：依次搜索完仍不能自动通过时，显示「需要人工审核…10 秒内无人操作将跳过」；
  10 秒内有人点击（面板或携程页面）、按键、滚动面板或点「我来处理」即视为接管，这个景区不再自动跳过；
  无人接管则记为跳过（`approval` 仍为 0，备注「无人接管，自动跳过：原因」）并进入下一个，之后在筛选「已跳过」里集中处理。
  已审核的、以及在「已跳过」里复看的景区不会自动跳过；⚙ 里可关闭或改秒数。这样面板可以无人值守地跑：能过的自动过，过不了的跳过留给人。
- **全国模式**：`run` / `auto` / `prefetch` 加 `--all-cities`（或设 `CITIES=ALL`），核对客户表全国所有景区（约 1.7 万），
  城市下拉按省分组，待核对按省→市依次跑。携程主档和离线候选只覆盖 7 城，其他城市的地址/坐标来自携程搜索结果或「查地址」。
- **城市依次跑完**：待核对列表按 `CITIES` 的顺序（北京→上海→广州→深圳→杭州→成都→西安）排，城市内 5A→4A→…；选「全部城市」时一个城市跑完自动接下一个；
  选了单个城市时，这个城市的待核对跑完会自动切到下一个还有待核对景区的城市（提示「北京市 已跑完，切到 上海市」）。`review.py auto` 也按这个顺序跑。
- 顶部进度条显示当前城市范围内已审核（`approval=1`）的比例；城市下拉只列 `CITIES` 里的城市，带「已审核/景区数」。
- 面板宽度可拖动左边缘调整（会记住）；⚙ 里可开「把携程页面往左挤」和「搜索后自动补全缺失地址」。
- 如果找不到搜索框（携程改版），在 ⚙ 里点「定位搜索框」，再到页面上点一下携程的搜索框即可。
- 出现验证码时直接在窗口里手动完成，然后继续。
- 每次搜索终端会打印「[hq] 「关键词」采用 <接口地址> → N 条」；收到的所有响应写在 `debug/last_search.json`。
  面板提示「只读到下拉框文字（没有ID）」时，按 `R` 重搜；仍不行把这个文件发给开发排查。只有下拉文字的结果不进缓存。
- 右下角按钮变红「POI核对（出错，点我看原因）」：点开能看到具体错误，终端里也会打印 `[面板调用 … 出错]`。
- 只有 `review.py run` 打开的那个窗口里才有面板；自己另开的浏览器窗口没有。

| 快捷键 | 作用 |
|---|---|
| `1`–`9` | 保留第 n 条搜索结果（再按一次取消） |
| `Shift` + `1`–`9` | 取消保留第 n 条 |
| `Enter` | 审核完成（`approval=1`）并下一个 |
| `S` | 跳过（`approval` 保持 0，记入跳过列表） |
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

## 5. 批量自动审核（推荐先跑一遍）

名称一致且地址相近的景区直接通过，剩下的再人工看：

```bash
python review.py auto --channel chrome --grade 5A,4A -v
```

- 搜索结果优先用缓存（`prefetch` 或之前核对时搜过的），没缓存才打开浏览器现搜。
- 景区名没通过时默认接着用别名搜（`--no-alias` 关掉）；`--spots`：别名也不行再用核心景点搜；`--max-extra 8`：每个景区最多再搜几个词。
- `--cache-only`：只用缓存、不开浏览器；`--dry-run`：只打印判定不写库；`-v`：也打印留给人工的原因。
- 通过的景区：`ctrip_poi_info` 写入所有地址相近的 POI，`approval=1`，进度表备注「自动审核：…」，核对人 `auto`。

## 6. 结果

- 结果就在客户景区表上：`ctrip_poi_info`（保留的 POI JSON 数组）和 `approval`（1-已审核 0-未审核）。
- 「待核对」= `approval=0` 且没跳过；「已审核」= `approval=1`；「已跳过」记在 `scenic_ctrip_review_status`（同时存备注和核对人）。
- 面板上点「导出」（写到工具目录），或：

```bash
python review.py export -o scenic_ctrip_poi_mapping.csv
```

导出每个景区一行（只含 `ctrip_poi_info` 不为空的）：`approval`、`kept_qty`、`ctrip_poi_id_list`（`|` 分隔）、`ctrip_poi_name_list`、`ctrip_poi_info`、`note`。

字段对应：携程搜索返回的 `poiId` = 携程主档 `ctrip_poi_id`；只有景点ID（url 中的数字）时会从携程主档 / 候选表补出 poiId，补不出的不能保存。

## 7. 景点图像识别：采集点评图片

对已审核（`approval=1`）景区 `ctrip_poi_info` 里的每个 POI：打开它的携程主页 → 第一页点评直接读页面里服务端渲染的 `__NEXT_DATA__`
（`initialState.commentList`，这一页不会发请求）→ 一页页点「下一页」，旁路读取页面自己发出的 `getCommentCollapseList` 返回，
把点评里的图片写进 MySQL。不自己调接口。页面上的 `poiDetail.poiId` 和 `ctrip_poi_info` 的 poiId 不一致时不采集（记录原因）。

```bash
python review.py images --channel chrome --grade 5A,4A
```

- 每个 POI 默认最多 20 页、300 张（`--max-pages` / `--max-images`），页间随机停 1.5–3 秒；`--limit` 限制 POI 数，`--refresh` 重采已采完的。
- 连续 10 页没有新图片（没图或都已采过）就换下一个 POI（`--empty-pages`，0 = 不按这个规则）。
- 断点续采：进度在 `scenic_poi_image_crawl`，已采完的 POI 下次自动跳过；同一景区+POI+图片只存一条。
- 遇到登录/验证会停下，在浏览器里处理后重跑即可。

写入两张表：

| 表 | 说明 |
|---|---|
| `ods_prd_poi_image_di`（交付表，你们建好的分区天表） | 字段与样例一致；`travel_date` = 采集日期；`lon/lat` 按表注释换算成 WGS84（客户景区坐标实为 GCJ02；`ODS_COORD=gcj02` 则原样写）；当天没有分区时自动 `ADD PARTITION p<次日> VALUES LESS THAN (<次日>)`（`ODS_AUTO_PARTITION=0` 关闭）|
| `scenic_poi_image`（工具自己的表） | 去重、生成 `record_id`（`img_<采集日期>_<序号>`），多存缩略图、点评分、点评发布时间、点评总数 |

字段来源：`poi_id/poi_name` 来自 `ctrip_poi_info`；`scenic_*`、省市区、`lon/lat` 来自客户景区表；`review_id`=commentId，`image_id/width/height/image_url`=点评图片；
`total_count` = POI 图片总数（主页 `__NEXT_DATA__` 的 `poiDetail.imageInfo.imageCount`）；`collect_time` 采集时间，`data_source`=`OTA-图片爬取`，`is_modified`=0。

交付表不存在时只写 `scenic_poi_image`；之后建好交付表，用下面的命令补写（重复的会被忽略）：

```bash
python review.py sync-ods
```

### 抓页面结构（规则对不上时）

```bash
python dump_page.py https://you.ctrip.com/sight/beijing1/229.html --channel chrome
```

打开页面、滚到点评区、点一次「下一页」，保存整页 HTML、截图、点评接口请求/返回、「下一页」附近的 HTML、像「图片总数」的文字，
打包成 `debug/page_dump_<时间>.zip` 发给开发即可（不含请求头和 Cookie，请求体里 token 之类字段已打码）。

## 8. 服务化：数据工作台（推荐的日常用法）

```bash
python service.py --channel chrome
```

浏览器打开 <http://127.0.0.1:8800>。服务自己开一个 Chrome（携程登录态保存在 `.pw-profile-service`，第一次在那个窗口里登录一下即可），
网页上的所有操作都通过这个浏览器完成：在携程搜索框里模拟输入、读下拉框结果（F12 式被动感知）、进 POI 主页点「下一页」读点评图片。不直接调用携程接口。

网页用 React + [Semi Design](https://semi.design/zh-CN) 的本地副本（`web/vendor/`），不需要构建、不依赖外网 CDN。
每个页面固定一屏：表格和图片在各自的区域里滚动，滚到底自动加载下一页；窄屏（< 1440px）左侧菜单自动收起。

| 页面 | 说明 |
|---|---|
| 总览 | 景区总数、已审核（自动/人工）、待核对、已跳过、已采 POI、图片数；各城市进度；正在采集的 POI；最近任务 |
| 核对 | 原来的核对面板嵌在工作台里：规则、自动选中、自动通过、10 秒无人接管跳过、按城市依次跑完、快捷键都一样。顶部一条显示边核对边采集的状态和正在采的 POI（可点「下一个 POI」）。`#/review?scenic_id=PFTSCB01001668` 直接打开某个景区 |
| 图片采集 | 批量采集（城市 / 等级 / 景区、每个 POI 最多页数 / 张数、连续几页无新图换下一个）；正在采集的 POI（进度 + 「下一个 POI」）和日志；POI 采集记录（状态、页数、点评、新增图片、停止原因） |
| 数据预览 | 客户景区表 + `ctrip_poi_info` + `approval`，按城市 / 状态 / 等级 / 名称筛选；点一行看详情：保留的 POI、每个 POI 的图片数、去核对 / 看图片 |
| 图片预览 | 按城市、景区名 / POI 名、景区ID、poiId 浏览已采图片；点开看大图，← → 翻页、Esc 关闭 |
| 任务中心 | 提交「自动审核」「采集点评图片」任务，看进度和日志、取消；采集任务运行时也能点「下一个 POI」 |

顶栏：全局搜索（跳到数据预览）、提醒（任务需要人工 / 边核对边采集暂停）、核对人设置、接口文档、导出 CSV。

### 边核对边采集

核对页里点「审核完成」（或自动通过）后，这个景区会自动排进图片采集队列，服务在另一个标签页里打开保留的每个 POI 主页、翻点评、写库
（`scenic_poi_image` + 同步到 `ods_prd_poi_image_di`）。任务中心里跑的「自动审核」通过的景区也一样会排进去（试运行除外）。

- 开关、暂停 / 继续：总览、核对页、图片采集页上都有；也可 `POST /api/follow {"enabled":false}`
- **手动换下一个 POI**：「正在采集」里的「下一个 POI」按钮（边核对边采集和采集任务都可以）；当前 POI 记为完成，不会再自动重采
- **连续 10 页没有新图片就换下一个 POI**（默认 10；批量采集 / 任务里可改，填 0 不按这个规则；边核对边采集用 `hq_prefs.json` 的 `collect_empty_pages`）
- 每个 POI 最多翻几页、最多几张：默认 20 页 / 300 张，可改 `.pw-profile-service/hq_prefs.json` 的 `collect_max_pages` / `collect_max_images`，或 `POST /api/rpc/prefs {"collect_max_pages":30}`
- 页面上的 poiId 和链接里的不一致时不采（日志里会提示「poiUri 可能指向了别的 POI」）
- 遇到登录 / 验证会暂停并在顶栏提醒里提示，在服务打开的浏览器里处理完点「继续」

参数：`--port 8800`、`--host 127.0.0.1`（默认只本机可访问）、`--all-cities`、`--headless`（不建议）、`--profile`（默认 `.pw-profile-service`，和 `review.py run` 分开，可以同时开）。
接口文档：<http://127.0.0.1:8800/docs>。

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/health` | 服务状态、当前任务、排队数、是否需要人工 |
| GET | `/api/overview` | 总览数字：总数、已审核（自动/人工）、跳过、待核对、图片数、ODS 行数、各城市 |
| GET | `/api/stats` | 各城市审核进度、图片采集统计 |
| GET | `/api/scenic_table?city=&status=&grade=&q=&offset=&limit=` | 景区 + 保留 POI + 每个 POI 的图片数（分页） |
| GET | `/api/scenic/{scenic_id}` | 景区详情和已保留的 POI |
| GET | `/api/images?city=&q=&scenic_id=&poi_id=&limit=&offset=` | 已采图片（分页） |
| GET | `/api/crawl_records?status=&q=&limit=&offset=` | 每个 POI 的采集记录（分页） |
| GET | `/api/crawl` | 正在采集的 POI：来源、页数、新增图片、连续无新图页数 |
| POST | `/api/crawl/skip` | 手动跳到下一个 POI：`{"source":"follow"}` / `{"source":"job"}`，不传则全部 |
| GET | `/api/export.csv` | 导出核对结果 |
| POST | `/api/rpc/{method}` | 核对面板用的接口（list / detail / search / poi / status / prefs …） |
| GET/POST | `/api/follow` | 边核对边采集：状态 / `{"enabled":true\|false}`、`{"pause":true}`、`{"resume":true}` |
| POST | `/api/jobs` | 提交任务：`{"type":"images","params":{"city":"北京市","grade":"5A","max_pages":20,"empty_pages":10}}`；`type` 可为 `auto_review` / `images` |
| GET | `/api/jobs`、`/api/jobs/{id}` | 任务列表 / 详情（含日志） |
| POST | `/api/jobs/{id}/cancel` | 取消任务 |

## 其他参数

| 参数 | 说明 |
|---|---|
| `--profile` | 浏览器用户目录，默认 `./.pw-profile`（保存登录态，已在 .gitignore） |
| `--channel` | `chrome` / `msedge`：用本机浏览器 |
| `--executable-path` | 指定浏览器可执行文件 |
| `--start-url` | 默认 `https://you.ctrip.com/` |
| `--pattern` | 优先采用的请求 URL 片段，默认 `/restapi/soa2/30668/search`，可多次指定（不在列表里的接口也会自动识别） |

## 文件

| 文件 | 说明 |
|---|---|
| `review.py` | 主程序：Playwright 浏览器 + 模拟输入搜索 + 预搜索 + 导出 |
| `panel.js` | 核对面板（注入携程页面，或嵌在工作台里） |
| `db.py` | MySQL 读写 |
| `import_candidates.py` | 导入离线候选 CSV |
| `import_ctrip_master.py` | 导入携程景区主档（用于显示地址/等级） |
| `match.py` | 名称/地址比对与自动审核判定、坐标换算 |
| `crawler.py` | 点评图片采集（翻页、解析、入库） |
| `service.py` | 常驻服务（FastAPI）：核对接口、任务队列、边核对边采集 |
| `web/` | 数据工作台前端（`index.html` / `app.css` / `app.js`；`vendor/` 为 React、Semi Design 的本地副本，无需构建） |
| `dump_page.py` | 抓 POI 主页结构，供核对采集规则 |
| `schema.sql` | 表结构（程序会自动建，供 DBA 审阅） |
