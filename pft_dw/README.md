# PFT 2.0 数仓蓝图

基于票付通 PFT 2.0 重构的 6 份设计文档（核心模型、数据库 DDL、应用架构、HLD、价格模型 v2、命名规范），按分层展开的离线与实时数仓模型：表清单、DWS 统计口径、ADS 业务指标、一致性维度总线矩阵、表级与指标级血缘、质量体检。

## 规模

| 分层 | 离线表 | 实时表 | 内容 |
|---|---|---|---|
| ODS | 81 | 9 | 业务库 1:1 镜像（剔除员工密码表，密钥不落仓，证件号/手机号脱敏） |
| DWD | 39 | 6 | 业务过程最细粒度，每张表写明度量字段与退化维度 |
| DIM | 37 | — | 一致性维度：拉链 `_zip` / 全量 `_df` / 码表 `_f` |
| DWS | 32 | 4 | 主题×粒度汇总，存 212 个统计口径（原子 145 / 派生 9 / 计算 58） |
| ADS | 30 | 4 | 847 个业务指标（离线 801 / 实时 46），由「口径 × 统计周期 × 修饰词」生成 |
| 合计 | 219 | 23 | |

## 目录

```
pft_dw/
├── web/                交互网页（静态，直接用任意 http 服务打开 index.html）
│   ├── index.html      血缘画布 / 质量体检 / 总线矩阵 / 表清单 / ADS 指标 / DWS 口径 / 待确认
│   └── data.json       模型数据（由 generator 生成）
├── output/
│   └── pft_dw_v2.xlsx  同一份模型的表格版：分层汇总、表清单、DWS口径、ADS业务指标、总线矩阵、质量体检、待确认事项
└── generator/          生成脚本（Python 3 + openpyxl）
    ├── base_data.py    基础数据：ODS/DWD/DIM/DWS/ADS 表定义、原始口径、待确认事项
    ├── model.py        v2 模型：度量/退化维度、补充口径、维度关联、ADS 指标生成规则（周期、修饰词）
    ├── quality.py      五个维度的体检规则（规范度/复用度/完善度/易用度/扩展度）与总线矩阵
    └── make_all.py     入口：生成 web/data.json 与 output/pft_dw_v2.xlsx
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

## 命名约定

- 表名：`分层_业务域_实体名_粒度`，代码中写 `库.表`，如 `dwd.dwd_ord_verify_di`
- 业务域前缀按规范 9 个：`ord_ fin_ prd_ inv_ cus_ sup_ trf_ opr_ mkt_`；系统 18 个领域的映射见网页「质量体检 → 规范度」
- 字段以 `_amt / _qty / _rate / _date / _type` 结尾；ADS 指标周期插在关键字前、修饰词作前缀，如 `api_pay_7d_amt`
- 分区字段统一 `travel_date`（YYYYMMDD），按数据日期分区；业务游玩日期为 `play_date`

## 待确认（摘要，完整 19 条见网页「待确认」页）

- 实时表后缀：规范最细到 `_hrs`，当前用 `_rt`，需规范补充
- 公共维度（日期/地区/币种/码表）暂挂 `opr_`，建议规范补公共域前缀
- 金额单位：源库为分，DWD 起转元
- 毛利口径：当前按支付口径，未扣退款
- 源系统缺口：价格快照、核销扣减金额/项目、放行人数、额度已用、领券用券等表或字段无 DDL
