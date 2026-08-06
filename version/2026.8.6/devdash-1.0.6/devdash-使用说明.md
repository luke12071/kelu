# kelu设备监控仪表盘 (devdash) - ImmortalWrt 安装包

版本：1.0.6（架构 all，通用 x86_64 / aarch64 等）
适用：**ImmortalWrt 25.12 / OpenWrt 25.12+**（apk 包管理器，不支持 opkg）

## 文件说明
| 文件 | 说明 |
|---|---|
| `devdash-immortalwrt-1.0.6.run` | **推荐** 一键自解压安装器（自包含，不依赖软件仓库，离线可装） |
| `luci-app-devdash_1.0.6-r1_all.apk` | 功能包 **APK v3** 格式（ADB 容器，ImmortalWrt 25.12 原生） |
| `devdash-使用说明.md` | 本文档 |

> APK v3 为 ImmortalWrt 25.12 原生格式（文件头 `ADBd`），与官方仓库包一致。
> 1.0.6 不提供 APK v2（目标机 25.12 均用 v3）。

## 安装方法（ImmortalWrt 25.12+）
方式一（推荐）：`.run` 自解压（**无需 apk 仓库，仓库故障也能装**）
```sh
cd /tmp
# 把 <IP> 换成源设备 IP，或用 U 盘 / scp 拷贝后执行：
curl -o devdash-immortalwrt-1.0.6.run http://<IP>/download/devdash/immortalwrt/devdash-immortalwrt-1.0.6.run
sh devdash-immortalwrt-1.0.6.run
```

方式二：手动 apk 安装（需仓库可用）
```sh
cd /tmp
curl -o luci-app-devdash_1.0.6-r1_all.apk http://<IP>/download/devdash/immortalwrt/luci-app-devdash_1.0.6-r1_all.apk
apk add --force-non-repository --allow-untrusted ./luci-app-devdash_1.0.6-r1_all.apk
/etc/init.d/devmon enable && /etc/init.d/devmon start
```

## 卸载方法
```sh
apk del luci-app-devdash        # 自动停服务并移除 cron
# 若曾用 .run 安装：手动清理
/etc/init.d/devmon stop && /etc/init.d/devflow stop
rm -f /etc/init.d/devmon /etc/init.d/devflow
rm -f /usr/sbin/devdash.sh /usr/sbin/devmon.sh /usr/sbin/devflow.sh /usr/sbin/devprobe.sh /usr/sbin/devlogclean.sh
rm -f /www/cgi-bin/devdash
sed -i '/devprobe.sh/d; /devlogclean.sh/d' /etc/crontabs/root
```
> 数据目录（默认 `/etc/devdash-data`）与 `/etc/devdash.conf` 保留，重装不丢数据。

## 依赖
本包**无硬依赖**（devdash 为独立 CGI，不依赖 luci-base）。
- `tcpdump`：可选，仅抓包功能需要；缺失时其余功能正常。
- `openssl-util`：可选，用于密码 sha256 计算；缺失时自动回退 `sha256sum`/busybox。

> 若 `apk update` 报 `wget: exited with error 8`（仓库不可达），用方式一 `.run` 安装即可，
> 不受仓库影响。

## 功能
在线状态 / DNS 查询分析 / 抓包 / 在线时长排行 / 访问域名 Top5 / 网址屏蔽 /
**各设备实时流量 / 上下行流量汇总（当天/本周/本月/上月/近90天）** / 设备事件日志分页 /
主题与双端背景 / 登录超时自动登出 / 备份恢复 / 登录页与修改密码。
访问：`http://<本机IP>/cgi-bin/devdash`
默认账号 `admin`，初始密码由安装器随机生成并打印（登录后点「🔑 修改密码」）。

## 数据目录
默认 `/etc/devdash-data`；如需修改，编辑
`/etc/devdash.conf` 中的 `DEVDASH_BASE` / `DEVDASH_DNSDIR` 后
`/etc/init.d/devmon restart` 生效。
