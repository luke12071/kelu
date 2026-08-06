# kelu设备监控仪表盘（devdash）维护记录

> 当前版本 **1.0.6**（2026-08-06）。访问 `http://<IP>/cgi-bin/devdash`，默认账号 `admin`（默认密码 `devdash`，登录后请修改）。
>
> 简体中文 · 单文件 CGI 自包含应用，无 luci 菜单依赖。

## 一、功能总览

| 分组 | 功能 |
|---|---|
| 总览 | 设备列表（在线/在线率/在线时长）、DNS 各设备查询数 + Top3、7 天趋势折线、24 小时分布堆叠柱、在线时长 Top10、域名 Top5 |
| 流量 | **实时流量**（每设备速率 + 今日累计，4 秒轮询 `?flow=1`）；**流量统计**（当天/本周/本月/上月/近90天 周期切换，上下行条形图 + 逐日双柱 + 设备汇总表） |
| 抓包 | 10s/30s 抓包分析，Top10 连接 + 各设备 Top2 目标 |
| 安全 | **日志**（设备上下线事件，每页 20 条分页）；**网址屏蔽**（dnsmasq 域名屏蔽，热重启生效） |
| 设置 | 数据保存（7/15/30/60/90 天清理）、备份导出/导入、外观与账户 |

顶部栏：GitHub 按钮、🌙/☀ 主题切换（高亮当前主题）、`👤 admin ▾` 下拉退出登录。
外观与账户：整页/登录页背景图上传与设默认（双端一键设默认）、背景透明滑条、修改密码（模态验旧密码）、登录超时（0=关闭/1/2/5/10/30/60 分钟，默认 2 分钟）、退出登录。
页面 60 秒自动刷新；登录后无操作按设定超时自动登出。

## 二、安装 / 卸载 / 依赖

### 依赖
**无硬依赖**（独立 CGI，不依赖 luci-base / luci）。可选：
- `tcpdump`：仅抓包功能需要，缺失时其余功能正常
- `openssl-util`：仅密码 sha256 计算需要，缺失自动回退 `sha256sum`/busybox

### 安装（iStoreOS / OpenWrt，ipk）
```sh
# 推荐：iStore 元信息包
is-opkg install /path/app-meta-devdash_1.0.6-1_all.ipk
# 或直接 opkg
opkg update && opkg install /path/luci-app-devdash_1.0.6-1_all.ipk
```
postinst 自动：enable+start `devmon`/`devflow`、建数据目录、追加 cron（`devprobe.sh` 每 10 分钟预热缓存、`devlogclean.sh` 每天 3:15 清理）、升级时保留 `/etc/devdash.conf`。

### 安装（ImmortalWrt 25.12+，apk）
```sh
# 方式一（推荐，离线可用，不依赖仓库）：
curl -o /tmp/d.run http://<IP>/download/devdash/immortalwrt/devdash-immortalwrt-1.0.6.run && sh /tmp/d.run
# 方式二（需仓库可用）：
apk add --force-non-repository --allow-untrusted ./luci-app-devdash_1.0.6-r1_all.apk
```
`.run` 安装器：自包含部署到 /usr/sbin /www/cgi-bin /etc/init.d，首次安装生成随机密码并打印，自动启用服务 + 追加 cron。

### 卸载
```sh
# ipk（iStoreOS / OpenWrt）
is-opkg remove luci-app-devdash      # 或 opkg remove luci-app-devdash
# apk（ImmortalWrt 25.12+）
apk del luci-app-devdash
# .run 安装方式：手动清理
/etc/init.d/devmon stop && /etc/init.d/devflow stop
rm -f /etc/init.d/devmon /etc/init.d/devflow
rm -f /usr/sbin/devdash.sh /usr/sbin/devmon.sh /usr/sbin/devflow.sh /usr/sbin/devprobe.sh /usr/sbin/devlogclean.sh
rm -f /www/cgi-bin/devdash
sed -i '/devprobe.sh/d; /devlogclean.sh/d' /etc/crontabs/root
```
> 数据目录（`$BASE`）与 `/etc/devdash.conf` 卸载时**保留**，重装不丢数据。确认不再需要可手动删除。

## 三、涉及文件与数据

| 文件 | 作用 |
|---|---|
| `/www/cgi-bin/devdash` | CGI 入口：登录页 + Session Cookie 认证（Basic Auth 兜底）；分发 `login/logout/export/import/bgset/loginset/timeout/passwd/flow` |
| `/usr/sbin/devdash.sh` | 页面生成主逻辑（`gen()`）+ JSON 接口 + 登录/认证 + TTL 缓存与 `buildcache` 预热 |
| `/usr/sbin/devmon.sh` | 设备在线监控守护（30s 周期） |
| `/usr/sbin/devflow.sh` | 各设备流量守护（5s 周期，nftables/iptables 计数 + 按日累计，fw4 重载自愈） |
| `/usr/sbin/devprobe.sh` | 设备型号探测 + 调用 `buildcache` 预热（cron 每 10 分钟） |
| `/usr/sbin/devlogclean.sh` | 日志与 `.flow_day` 按保留天数清理（cron 每天 3:15） |
| `/etc/init.d/devmon` `/etc/init.d/devflow` | 服务启停 |
| `/etc/devdash.conf` | `DEVDASH_BASE/DNSDIR/IFACE/USER/HASH/TIMEOUT` |

数据目录 `$BASE`（本机 `/mnt/usb2_2-4/Public/device-monitor`；ImmortalWrt 默认 `/etc/devdash-data`）：
`devices.tsv`、`events.log`、`.blocklist`、`.retention`、`.bgimg`、`.loginbg`、`.session`、`.trend/.topdur`、`.flow_now/.flow_today/.flow_day/.flow_last/.flow_ips`、`.queries.cache/.dnsrows.cache/.topdom.cache`。
DNS 日志：`$DNSDIR/access.log*`（本机 `/mnt/usb2_2-4/Public/Downloads/`）。

## 四、守护与定时任务

- 服务：`/etc/init.d/devmon`（procd）、`/etc/init.d/devflow`（procd）
- cron（`/etc/crontabs/root`）：`*/10 * * * * devprobe.sh`；`15 3 * * * devlogclean.sh`；`0 3 * * 1` 轮转 access.log + HUP dnsmasq

## 五、维护命令

```sh
/etc/init.d/devmon restart && /etc/init.d/devflow restart   # 重启守护
sh -n /usr/sbin/devdash.sh && sh -n /www/cgi-bin/devdash   # 语法检查
unset QUERY_STRING; . /usr/sbin/devdash.sh && gen > /tmp/test.html   # 本地渲染
/usr/sbin/devlogclean.sh                                   # 手动清理过期日志
# 命令行改密：先算 sha256 再写入 /etc/devdash.conf 的 DEVDASH_HASH
printf '%s' '新密码' | openssl dgst -sha256 | awk '{print $NF}'
# 命令行备份/恢复（等价页面操作，纯 tar.gz 不含 HTTP 头）
cd "$BASE" && tar czf /tmp/devdash-backup.tar.gz .blocklist .retention devices.tsv events.log .bgimg .loginbg
CONTENT_LENGTH=$(wc -c < /tmp/devdash-backup.tar.gz) sh -c '. /usr/sbin/devdash.sh; do_import' < /tmp/devdash-backup.tar.gz
```

## 六、打包产物与部署

`/mnt/usb2_2-4/Public/device-monitor/packages/` 与 `/www/download/devdash/`：

| 文件 | 说明 |
|---|---|
| `luci-app-devdash_1.0.6-1_all.ipk` / `app-meta-devdash_1.0.6-1_all.ipk` | 功能包 / iStore 元信息包（OpenWrt 新版 gzip tar 三层 ipk 格式） |
| `luci-app-devdash_1.0.6-r1_all.apk` | APK v3（ImmortalWrt 25.12 原生，`apk mkpkg` 构建） |
| `devdash-immortalwrt-1.0.6.run` | 自包含安装器（离线可用） |

> APK v2 未提供：目标机 25.12 用 v3；`openwrt-ipk2apk.py` 产出的 v2 仍兼容旧 25.12 rc，需要时再补。旧版产物（≤1.0.5）部署时同步删除。

## 七、变更记录

- **1.0.6（2026-08-06）** 新增：90 天流量统计周期（`fp=90d`，日汇总 `awk` 预生成 + 每天 1 次 date 优化）；登录页背景自定义（`.loginbg` + `do_loginset`）；无操作自动登出（`.session` 3 字段 `token|expiry|lastactive`，超时白名单 0/1/2/5/10/30/60 分钟，30s 节流刷新防 flash 磨损）；日志分页（每页 20 条 `pg=`，首页/上/下/末页控件）；默认背景双端一键（`bgset`+`loginset` 并行）；顶部 GitHub 按钮；**修复主题切换按钮丢失**（CSS/JS 引用了 `.themetgl` 但顶部未渲染按钮）；admin 下拉退出（`👤 用户名 ▾`）；页尾名言。**安全修复**：`?logout=1` 未认证可清空全部会话（无 Cookie `rm -f` + Cookie 正则注入 `^.*|` 全删）→ 改为 awk 精确匹配仅删当前 token；`.session` 重写后丢 600 权限 → 每次重写后 `chmod 600`；`bgset/loginset` 原始写入可注入 CSS → 写/读双端校验 `url(data:*` 前缀，非图片内容拒绝；`do_import` 符号链接（tar 可指向 `/etc/shadow` 被 cp 跟随泄漏）→ 跳过 symlink；失败登录延迟 1s 防爆破。
- **1.0.5（2026-08-05）** 修复流量页面空白根因（页面生成 15.5s 超 uhttpd CGI 超时被截断）→ TTL 磁盘缓存 + `buildcache` 预热，页面 1.5s；修复 devflow 重启流量清零（`lan_ips` 读错 ARP 列，`$4` 是 HWaddr，devices 在 `$NF`）→ `ip neigh` 首选 + ARP 回退；登录认证重做为自绘登录页 + HttpOnly Session Cookie（保留 Basic Auth 兜底）；修改密码模态表单（验旧密码）；默认密码统一 `admin/devdash`。
- **1.0.4（2026-08-04）** 新增各设备实时流量 + 上下行流量汇总（`devflow.sh` 守护，nftables/iptables 计数，5s 采样，按日累计），左侧导航新增「📊 流量」分组。
- **1.0.3（2026-08-03）** 左侧侧边栏导航（分组可折叠，`dash-view` 记忆，`?dev=/?cap=` 强制定位）；板块按权重重排。
- **1.0.2（2026-08-03）** 去掉硬依赖（tcpdump/openssl 降为可选）；`dev_sha256` 三级回退；自包含 `.run` 安装器；ImmortalWrt BASE 默认 `/etc/devdash-data`。
- **1.0.1（2026-08-03）** 修复背景上传自动刷新失效（localStorage 配额异常）→ canvas 压缩 + 服务端 `.bgimg` 兜底；图表 tooltip 绿底；设备列表可折叠；修改密码；备份导出/导入。
- **1.0.0（2026-08-02 起）** 设备监控/DNS 分析/抓包/趋势图表初版，更名 kelu设备监控仪表盘。
