# PFT 2.0 数据开发平台（devui）

在数据开发平台 demo 的基础上接入 PFT 2.0 数仓：后端改为 **Python 标准库 + SQLite**，项目里预置了 “PFT 2.0 数仓项目”。项目中包含全部开发任务、调度工作流、数据质量规则和字段血缘。

## 启动

```bash
cd pft_dw/devui
python3 server/app.py              # 打开 http://127.0.0.1:4180
python3 server/app.py --port 8080 --host 0.0.0.0
python3 server/app.py --reseed     # 数仓生成器更新后，用最新结果重建 PFT 项目
```

Windows 双击 `启动.bat`。需要 Python 3.9 或更高版本，不依赖第三方包，也不需要 Node。数据库文件在 `data/devui.db`，首次启动时自动创建；该目录不进 git。

## 项目内容

| 位置 | 内容 |
|---|---|
| 工作流 / 日调度 · 主流程 | `源库就绪 → ODS → DWD → DWS → ADS → 发布`。DIM 是一条分支，放在主线下方：ODS → DIM → DWD/DWS/ADS。主线右侧还有一列「实时/离线对账」。每个“分层 × 数据域”是一个分组，默认折叠。组内的任务和它的质检节点成对排列 |
| 工作流 / 实时 · Flink 作业 | `ODS(CDC) → DWD → DWS → ADS`，加一列 Flink 作业监控。实时任务查询的离线维表作为分支放在下方 |
| 工作流 / 周、月、年调度 | 开始 → 任务 → 质检 → 结束 |
| ODS / DIM / DWD / DWS / ADS | 离线任务，按数据域分子目录，共 219 个 |
| 实时作业 | 实时任务，按分层分目录，共 54 个 |
| 数据质量 | 质检任务，按分层分目录，另有「对账」「实时监控」「作业监控」 |
| 调度控制 | 各调度的开始节点（源库就绪检查）和结束节点（数据就绪发布），Shell 任务 |
| 数据运维 / 周期任务 | 已配置日、周、月、年四个周期调度 |

- 分组折叠或展开后，同一列的分组会自动重新堆叠，展开的分组不会压到相邻分组上。工具栏的「自动排布」也按这套泳道规则执行。
- 双击任务进入开发页。顶部五个标签：
  - **开发代码**：可编辑、可保存。
  - **表 DDL**：建表语句。
  - **字段与血缘**：每个字段的类型、角色、加工口径，以及上下游字段。点击表名直接打开对应任务。
  - **质量规则**：每条规则的 SQL、期望值、强弱级别。
  - **调度依赖**：所属调度、cron、SLA、重试、上下游节点。

## 任务代码怎么来的

`server/codegen.py` 按字段血缘和口径文字为每张表生成代码：

| 分层 | 代码 |
|---|---|
| 离线 ODS | Spark SQL：JDBC 临时视图读业务库（`_di` 按 update_time 增量，`_df` 全量），再 `INSERT OVERWRITE` 分区；证件号、手机号脱敏 |
| 离线 DIM / DWD | 主表加关联表，逐字段翻译口径（改名、÷100 转元、取日期、JSON 展开、按 X 汇总等）。关联键从口径里的“按 X 关联”推断，主表上找不到时沿已关联的表链式推断。`_zip` 表生成闭链/开链模板 |
| 离线 DWS | 每个来源表一段聚合 CTE，`UNION ALL` 后按粒度汇总，再关联维度属性 |
| 离线 ADS | 把 DWS 字段按统计周期（1d / 7d / 30d / mtd / ytd / td）开窗求和作为基数，再组合成派生指标（比率、差值、均值） |
| 实时 ODS | Flink CDC 源表定义 |
| 实时 DWD / DWS / ADS | Flink SQL：临时视图加 StarRocks 结果表。维表用 `FOR SYSTEM_TIME AS OF` 查询 Hive 维表。分钟窗口按事件时间取整后分组聚合，写入主键模型（upsert） |
| 质检 / 对账 | 规则 SQL 逐条列出，并写明期望值和强弱级别 |

口径文字无法确定的字段，生成器不会猜。这类字段写成 `CAST(NULL …)`，并加注释 `-- TODO 口径：<原口径>`，目前共 676 处。主要有三类：

- 状态变化与镜像类，如“首次变为 PAID 的时间”“binlog 前镜像”。
- 去重人数跨天累加：这类指标不能直接求和，需要回到 DWD 去重。
- 同一个 DWS 字段被 ADS 按不同业务条件拆分（例如退款发起方），DWS 的粒度不足以区分。

另有 8 处关联键无法推断，生成了 `ON 1 = 0 /* TODO 关联键 */`。

参数约定：`${bizdate}` 为 YYYYMMDD，此外还有 `${bizdate_dash}`、`${bizdate_prev}`、`${bizdate_begin}` / `${bizdate_end}` 和 `${bizdate_minus_7}`。这些参数已写在各离线工作流的参数里。数据源连接（`${jdbc.*}`、`${mysql.*}`、`${cdc.*}`、`${starrocks.*}`）属于环境配置，不放在任务参数中。

## 后端

| 接口 | 说明 |
|---|---|
| `GET /api/kv` | 页面启动时取回全部存储键：项目列表、各项目开发草稿、定时运行、即席查询草稿 |
| `PUT /api/kv/<key>` / `DELETE` | 写入一个键 |
| `GET /api/meta/task/<任务标识>` | 开发页的 DDL、字段血缘、质量规则、调度依赖 |
| `GET /api/meta/summary` | 元数据概况 |
| `POST /api/jars?name=x.jar` / `GET /api/jars/<id>` | JAR 程序包上传（≤50 MB）与下载 |

前端原本把数据存在 localStorage。`web/backend.js` 在页面启动时从后端取回全部数据，之后对 `dataflow-*` 键的读写都转发到后端；后端不可用时自动退回浏览器存储。其中两类键在 SQLite 里拆成关系表存储：

- 项目列表 → `project`
- 开发草稿 → `folder` / `task` / `flow` / `flow_node` / `flow_edge` / `flow_group`

其余键存在 `kv` 表。数仓元数据存在 `dw_table` / `dw_column` / `dw_flow` / `dw_node` / `dw_rule` 表，每次启动时从 `pft_dw/web/*.json` 刷新，只读。

测试：`python3 -m unittest discover -s tests`

## 改了 demo 的哪些地方

- `web/backend.js`：新增，负责存储转发。
- `web/pft-meta.js`、`web/pft-meta.css`：新增，开发页的数仓信息标签。
- `web/project-storage.js`：引入后端；空项目增加 ODS 目录。
- `web/model.mjs`：分层增加 ODS；新增 `relayout`（泳道排布）。
- `web/app.js`：折叠分组和自动排布时调用 `relayout`；打开任务时广播事件；支持从血缘标签跳转任务；保存提示改为“服务器 · SQLite”。
- `web/development.js`：切换项目前先等待未完成的保存写完。
- 删除 `serve.mjs` / `package.json`，由 `server/app.py` 提供静态文件和接口。
