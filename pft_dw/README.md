# PFT 2.0 数仓蓝图

基于票付通 PFT 2.0 重构的 6 份设计文档（核心模型、数据库 DDL、应用架构、HLD、价格模型 v2、命名规范），按分层展开的离线与实时数仓模型：表清单、全表字段与 DDL、DWS 统计口径、ADS 业务指标、一致性维度总线矩阵、表级 / 指标级 / 字段级血缘、质量体检。

## 规模

| 分层 | 离线表 | 实时表 | 内容 |
|---|---|---|---|
| ODS | 81 | 17 | 业务库 1:1 镜像（剔除员工密码表，密钥不落仓，证件号/手机号脱敏） |
| DWD | 39 | 14 | 业务过程最细粒度，每张表写明度量字段与退化维度 |
| DIM | 37 | — | 一致性维度：拉链 `_zip` / 全量 `_df` / 码表 `_f` |
| DWS | 32 | 12 | 主题×粒度汇总，存 212 个统计口径（原子 145 / 派生 9 / 计算 58） |
| ADS | 30 | 11 | 913 个业务指标（离线 801 / 实时 112），由「口径 × 统计周期 × 修饰词」生成 |
| 合计 | 219 | 54 | 共 4,654 个字段，每张表都有 DDL |

## 目录

```
pft_dw/
├── web/                交互网页（静态，直接用任意 http 服务打开 index.html）
│   ├── index.html      血缘画布 / 质量体检 / 总线矩阵 / 表清单 / ADS 指标 / DWS 口径 / 待确认
│   ├── data.json       模型数据（由 generator 生成）
│   ├── schema.json     全表字段 + 字段级血缘 + DDL（网页按需加载）
│   └── workflow.json   调度工作流与质检规则（网页「调度工作流」页）
├── workflow/           调度工作流定义（调度器无关 YAML，可转 DolphinScheduler / Airflow）
│   ├── 01_pft_dw_daily.yaml … 04_pft_dw_yearly.yaml   日 / 周 / 月 / 年调度：任务、依赖、重试、质检规则
│   ├── 05_pft_dw_realtime.yaml                       实时：Flink CDC 源、写入表、监控项
│   └── dq_rules.sql                                  全部数据质量规则的检测 SQL
├── ddl/                全部 273 张表的建表语句，按分层一个文件
│   ├── 01_ods.sql … 05_ads.sql        离线：Hive ORC，PARTITIONED BY (travel_date)
│   ├── 06_rt_ods.sql                  实时源：Flink CDC（mysql-cdc）源表，直读 binlog，不经 Kafka
│   └── 07_rt_dwd.sql … 09_rt_ads.sql  实时明细 / 汇总：StarRocks 主键模型
├── output/
│   ├── pft_dw_v2.xlsx      表格版：分层汇总、表清单、字段清单、DWS口径、ADS业务指标、总线矩阵、质量体检、待确认事项
│   ├── PFT2.0_数仓分层表清单与指标字典.xlsx  与在线表格同一份：上面 10 页 + v1 历史 4 页
│   ├── pft_dw_v1.xlsx      v1 历史版本（表清单 / 指标字典）
│   └── pft_dw_fields.xlsx  只含字段清单，便于单独分发
└── generator/          生成脚本（Python 3 + openpyxl）
    ├── base_data.py    基础数据：ODS/DWD/DIM/DWS/ADS 表定义、原始口径、待确认事项
    ├── model.py        v2 模型：度量/退化维度、补充口径、维度关联、ADS 指标生成规则（周期、修饰词）
    ├── quality.py      五个维度的体检规则（规范度/复用度/完善度/易用度/扩展度）与总线矩阵
    ├── spec.py / formulas.py   业务口径、计算公式、时间口径、数据类型与精度
    ├── parse_source.py 解析客户数据库文档里的 MySQL DDL → source_ddl.json（83 张源表）
    ├── source_ddl.json 源表字段、注释、唯一键
    ├── enums.py        枚举值中文含义（约 300 个），用于补全 _type/_status 字段注释
    ├── schema.py       字段规则：源字段规范化改名、DWD/DIM 扩展字段、DWS/ADS 粒度键、DDL 模板
    ├── build_schema.py 组装全部表字段、字段级上下游、DDL，并做自检
    ├── workflow.py     由字段级血缘生成调度依赖、质检节点与规则
    └── make_all.py     入口：生成 web/data.json、web/schema.json、ddl/*.sql 与 output/*.xlsx
```

## 重新生成

```bash
pip install openpyxl
python3 pft_dw/generator/make_all.py
```

修改表或指标只改 `generator/` 下的脚本，再运行 `make_all.py`，网页数据和表格会同时更新。

本地查看网页：

```bash
cd pft_dw/web && python3 -m http.server 8000
# 打开 http://localhost:8000
```

`index.html` 通过 `fetch("data.json")` 读数据，直接双击打开文件会因浏览器限制读不到，需要起一个 http 服务。

## 字段与 DDL

- **ODS**：源表全字段原样落地（类型转 Hive），密钥类字段剔除、证件号/手机号等标注脱敏，`_di` 表加 `binlog_op_type / binlog_time`，统一加 `etl_time`
- **DWD**：源字段按规范改名（`amount→*_amt` 并由分转元、`*_kind→*_type`、`*_at→*_time`、`id→实体_id`），JSON 字段拆成明细列（如 `sale_dims → play_date / time_slot_code / seat_zone_code`），冗余常用外键（卖家、SKU、渠道、买家），补度量与派生字段
- **DIM**：同样规范化，补齐名称、层级、路径等描述属性；拉链表加 `start_date / end_date`
- **DWS / ADS**：粒度键 + 指标列；ADS 额外补维度名称（如 `seller_tenant_name`）方便业务直接用
- 每个字段都有注释；`_type / _status` 字段逐值写明含义，如 `pay_status：UNPAID-未支付，PARTIAL_PAID-部分支付，PAID-已支付`
- 每个字段都记录上游 `表.字段` 与加工说明，网页里点字段可看字段级全链路（ODS 字段追到业务库源字段）
- 实时：**Flink CDC 直读 MySQL binlog，不经 Kafka**。实时 ODS 是 `mysql-cdc` 源表（先全量快照再增量，`binlog_time` 取 CDC 元数据 `op_ts`，敏感列不声明即不读取），同一作业内加工成 DWD 并写入 StarRocks；DWD/DWS/ADS 均为 StarRocks 主键模型，按 `travel_date` 分区。DWD 主键 = `travel_date` + 实体ID（变动类表再加 `change_time`），DWS/ADS 主键 = `travel_date` + 窗口 + 粒度键
- **实时与离线分开建表，不合并**：实时表一律 `_rt`、落 StarRocks，离线表落 Hive；同一个指标两边都有时，共用同一个原子口径（口径编码相同、条件逐字一致，只差统计周期），日调度里对每个这样的口径做实时↔离线 T+1 对账，以离线为准。实时对离线的唯一依赖是 lookup 关联的维表（日调度产出）
- 实时覆盖：交易（今日支付/下单/退款/核销、SKU 排行、渠道结构、员工代下单）、客流、库存、账户资金与冻结、分销授信预警、游客增长、平台大盘、运营监控（设备离线、通知失败、投诉超时、码池余量）、风控预警
- 源库前提：`binlog_format=ROW`、`binlog_row_image=FULL`，CDC 账号需 REPLICATION SLAVE / REPLICATION CLIENT 等权限，每张源表独立 `server-id` 段；同库源表建议合并在一个作业里

## 调度工作流与数据质量

- **依赖来自字段级血缘**：一张表只等它真正读到的上游表（含维表），不按分层整批等待；`dwd_ord_ticket_di` 的首次核销时间回填读核销表上一周期分区，打断了同周期的互相依赖
- **每个任务后紧跟一个质检节点**，下游依赖的是上游的质检节点：
  - 强规则（失败阻断下游、电话告警）：核心交易表当日有数、主键/粒度唯一且非空、拉链区间不重叠且每个主键恰一条当前记录、核心 ODS 与业务库行数对账、同行勾稽（如 净成交 = 支付 − 退款）
  - 弱规则（只告警）：外键能关联到维表、枚举取值合法、金额数量非负、比率值域、与近 7 日均值波动 ≤ 50%、DWS↔DWD 与 ADS↔DWS 合计对账、实时与离线对账
- **流程**：日调度 00:30 处理 T-1（目标 ADS 07:30 前就绪）；周 / 月调度等日调度对应分区质检通过后启动；年调度生成日期维度；实时作业按 Flink 作业挂 CDC 延迟、Checkpoint、反压、数据新鲜度监控
- 结束节点写就绪标记并通知下游；任一强规则失败则不发布

## 命名约定

- 表名：`分层_业务域_实体名_粒度`，代码中写 `库.表`，如 `dwd.dwd_ord_verify_di`
- 业务域前缀按规范 9 个：`ord_ fin_ prd_ inv_ cus_ sup_ trf_ opr_ mkt_`；系统 18 个领域的映射见网页「质量体检 → 规范度」
- 字段以 `_id / _no / _code / _name / _type / _status / _date / _time / _amt / _qty / _rate` 结尾，文本类统一 `_desc`；ADS 指标周期插在关键字前、修饰词作前缀，如 `api_pay_7d_amt`
- 分区字段统一 `travel_date`（YYYYMMDD），按数据日期分区；业务游玩日期为 `play_date`

## 待确认（摘要，完整 22 条见网页「待确认」页）

- 实时表后缀：规范最细到 `_hrs`，当前用 `_rt`，需规范补充
- 离线 ODS 的同步工具是否也用 Flink CDC
- 公共维度（日期/地区/币种/码表）暂挂 `opr_`，建议规范补公共域前缀
- 金额单位：源库为分，DWD 起转元
- 毛利口径：当前按支付口径，未扣退款
- 源系统缺口：价格快照、核销扣减金额/项目、放行人数、额度已用、领券用券等表或字段无 DDL
