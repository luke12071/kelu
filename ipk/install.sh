#!/bin/sh
# ============================================================
#  kelu设备监控仪表盘 (devdash)  - ImmortalWrt 安装脚本
#  版本: 1.0.1-1  架构: all
#  用法: 进入本脚本所在目录执行  sh install.sh
# ============================================================
set -e

DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR"

echo "==> 检查系统"
. /etc/openwrt_release 2>/dev/null || true
[ -d /etc/config ] || { echo "错误: 非 OpenWrt 系系统"; exit 1; }
command -v opkg >/dev/null 2>&1 || { echo "错误: 未找到 opkg"; exit 1; }

echo "==> 更新软件源 (opkg update)"
opkg update || echo "警告: update 失败，尝试继续（本地依赖可能已存在）"

echo "==> 安装依赖 (luci-base tcpdump openssl-util)"
opkg install luci-base tcpdump openssl-util || echo "警告: 依赖安装不完整，继续尝试"

echo "==> 安装 devdash 功能包"
opkg install ./luci-app-devdash_1.0.1-1_all.ipk || { echo "错误: 功能包安装失败"; exit 1; }

echo "==> 安装 iStore 元信息包 (可选)"
if command -v is-opkg >/dev/null 2>&1; then
    is-opkg install ./app-meta-devdash_1.0.1-1_all.ipk || true
else
    opkg install ./app-meta-devdash_1.0.1-1_all.ipk || true
fi

echo "==> 初始化密码"
CFG=/etc/devdash.conf
if [ -f "$CFG" ] && grep -q '^DEVDASH_HASH=' "$CFG"; then
    PASS_HINT="已保留现有密码"
else
    NEWPASS=$(head -c8 /dev/urandom | od -An -tx1 | tr -d ' \n')
    HASH=$(printf '%s' "$NEWPASS" | openssl dgst -sha256 2>/dev/null | awk '{print $NF}')
    printf 'DEVDASH_HASH=%s\n' "$HASH" >> "$CFG"
    PASS_HINT="初始密码: $NEWPASS"
fi

echo "==> 启用服务"
/etc/init.d/devmon enable 2>/dev/null || true
/etc/init.d/devmon restart 2>/dev/null || true

echo "------------------------------------------------------------"
echo "  访问地址: http://<本机IP>/cgi-bin/devdash"
echo "  默认账号: admin"
echo "  $PASS_HINT   (登录后请点「🔑 修改密码」)"
echo "------------------------------------------------------------"
exit 0
