第三方前端库（本地副本，网页不依赖外网 CDN）。许可：htm 为 Apache-2.0，其余为 MIT（许可文件见 *.LICENSE）：

| 文件 | 来源 |
|---|---|
| react.production.min.js | react@18.3.1 |
| react-dom.production.min.js | react-dom@18.3.1 |
| htm.umd.js | htm@3.1.1 |
| semi-ui.min.js、semi.min.css | @douyinfe/semi-ui@2.104.0（dist/umd、dist/css） |
| semi-icons.min.js、semi-icons.min.css | @douyinfe/semi-icons@2.104.0 |

升级：`npm pack <包名>@<版本>`，解包后把上面对应的文件拷过来覆盖即可。
