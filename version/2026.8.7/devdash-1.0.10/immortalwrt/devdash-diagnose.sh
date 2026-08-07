#!/bin/sh
# devdash - ImmortalWrt 目标机诊断脚本
echo "===== apk 版本 ====="
apk --version 2>&1
echo "===== 仓库配置 ====="
cat /etc/apk/repositories 2>/dev/null
echo "--- repositories.d ---"
cat /etc/apk/repositories.d/* 2>/dev/null
echo "===== apk update ====="
apk update 2>&1
echo "===== 搜索依赖包 ====="
apk search -r tcpdump 2>&1
apk search -r openssl-util 2>&1
apk search -r luci-base 2>&1
echo "===== 尝试安装依赖 ====="
apk add tcpdump openssl-util luci-base 2>&1
echo "===== 退出码: $? ====="
