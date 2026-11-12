# 客服数据生成用的数据（随仓库提交）

工作台「客服数据」页的资料目录留空或点「用仓库自带数据」就用这里；命令行 `cs_synth.py` / `cs_expand.py` 的 `--data-dir` 默认也是这里。
**本仓库是公开的，这里的数据任何人都能下载**（按负责人决定提交）。

| 目录 | 内容 | 条数 | 怎么用 |
|---|---|---|---|
| `cs_package/` | 文旅客服对话包：`dwd.dwd_cus_service_dialogue_df.csv`（一通一行）、`dwd.dwd_cus_service_dialogue_turn_df.csv`（逐轮）、`dim.dim_prd_attraction_df.csv`（七城携程景点主档，景点ID → poiId），以及包里的说明 / 表清单 / 字段对照 / DDL | 11,468 通 / 47,618 轮 / 7,888 个景点 | 改写模式的原始对话；扩展模式的真实问法参考（只用 真实 + train） |
| `scenic/` | 客户景区表 `pft_ai_dim_prd_scenic_base_yr_f.csv`（不含核对结果；核对结果在你的 MySQL 里） | 17,167 个景区 | 扩展模式的事实来源（票价、开放时间、地址、电话……）。工作台读的是 MySQL 里的同名表；新环境用 `python import_scenic.py` 导入（只插入没有的，不覆盖） |
| `guide/景区讲解内容_合并_3165条/` | 景区讲解包：六表（`data_all/`）+ 合并宽表 + 采集说明 / 统计 / 导入脚本。没放 `data_p1_仅新增/`（是 `data_all` 的子集，避免重复导入） | 3,165 条讲解、19,712 条事实、215 个景区 | 扩展模式「景点讲解」主题的事实；只有 OTA / 社区出处的事实不用，原文摘录不进生成内容。包内标注「未确认完整内容转载授权」 |
| `redqa/` | RedAttractionQA（红色景点阅读理解问答）train / validation / test | 8,981 / 3,205 / 3,076 | 只用 train：能唯一对到景区的段落作「景点讲解」事实（约 194 组），问题作讲解问法参考 |
| `woz/` | 从 RiSAWOZ（苏州，多领域）、CrossWOZ（北京，多领域）**train** 提取的景点领域对话，jsonl 一行一通 | 2,000 / 4,154 通 | 只作问法参考。原文件 180 MB / 370 MB，超过 GitHub 单文件 100 MB，所以只放提取结果；重新提取：`python cs_sources.py export-refs <原文件目录> data/woz` |

没有放：数据包里的图片链接表（约 280 MB，客服数据用不到）、RiSAWOZ / CrossWOZ 原文件和 dev / test / val（不用于生成）。

**许可**：RiSAWOZ、CrossWOZ、RedAttractionQA 是公开研究数据集，讲解包是依据公开资料整理（未确认完整转载授权）；用于商用训练数据前请确认各自的许可。
