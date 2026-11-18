#!/usr/bin/env sh
# 启动数据开发平台（Python 3.9+，无第三方依赖）
cd "$(dirname "$0")"
exec python3 server/app.py "$@"
