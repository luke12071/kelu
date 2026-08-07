
# kelu设备监控仪表盘（devdash）维护记录
<img width="1635" height="1348" alt="截屏2026-08-06 09 31 31" src="https://github.com/user-attachments/assets/0fd7983a-7e4c-4f11-ae2a-81affe775b2b" />

> 当前版本 **1.0.10**（2026-08-06）。访问 `http://<IP>/cgi-bin/devdash`，默认账号 `admin`（默认密码 `devdash`，登录后请修改）。
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
页面 60 秒后台无感刷新（fetch 原位替换，无整页重载/白屏，保留当前视图与滚动位置）；刷新视图由 `?v=` URL 参数 + localStorage 双重记忆，子页刷新直达当前页。登录后无操作按设定超时自动登出。

## 二、安装 / 卸载 / 依赖

### 依赖
**无硬依赖**（独立 CGI，不依赖 luci-base / luci）。可选：
- `tcpdump`：仅抓包功能需要，缺失时其余功能正常
- `openssl-util`：仅密码 sha256 计算需要，缺失自动回退 `sha256sum`/busybox

### 安装（iStoreOS / OpenWrt，ipk）
```sh
# 推荐：iStore 元信息包
is-opkg install /path/app-meta-devdash_1.0.10-1_all.ipk
# 或直接 opkg
opkg update && opkg install /path/luci-app-devdash_1.0.10-1_all.ipk
```
postinst 自动：enable+start `devmon`/`devflow`、建数据目录、追加 cron（`devprobe.sh` 每 10 分钟预热缓存、`devlogclean.sh` 每天 3:15 清理）、升级时保留 `/etc/devdash.conf`。

### 安装（ImmortalWrt 25.12+，apk）
```sh
# 方式一（推荐，离线可用，不依赖仓库）：
curl -o /tmp/d.run http://<IP>/download/devdash/immortalwrt/devdash-immortalwrt-1.0.10.run && sh /tmp/d.run
# 方式二（需仓库可用）：
apk add --force-non-repository --allow-untrusted ./luci-app-devdash_1.0.10-r1_all.apk
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
| `luci-app-devdash_1.0.10-1_all.ipk` / `app-meta-devdash_1.0.10-1_all.ipk` | 功能包 / iStore 元信息包（OpenWrt 新版 gzip tar 三层 ipk 格式） |
| `luci-app-devdash_1.0.10-r1_all.apk` | APK v3（ImmortalWrt 25.12 原生，`apk mkpkg` 构建） |
| `devdash-immortalwrt-1.0.10.run` | 自包含安装器（离线可用） |

> APK v2 未提供：目标机 25.12 用 v3；`openwrt-ipk2apk.py` 产出的 v2 仍兼容旧 25.12 rc，需要时再补。旧版产物（≤1.0.9）部署时同步删除。

## 七、变更记录

- **1.0.10（2026-08-06）** **60 秒整页刷新改后台无感刷新 + 子页刷新直达当前视图**：
  ① **无感刷新**：移除 `<meta http-equiv="refresh" content="60">` 整页重载，改为 `softReload()`——每 60 秒 `fetch` 后台拉取同 URL（`Cache-Control: no-store`），`DOMParser` 解析后 `body.innerHTML` 原位替换并重跑内联脚本，恢复滚动位置；替换与重绘在同一同步任务完成，无白屏/无跳页/无闪烁。`loadLive` 的 4s 轮询改 `__liveTimer` 守护，避免软刷新叠加定时器；会话过期时落到登录页。
  ② **子页刷新直达**：视图写进 URL——点击侧栏时 `updateUrl()` 用 `history.replaceState` 把 URL 更新为 `?v=<视图>`（保留该视图自身的 `fp/pg/dev/cap` 状态）；服务端 `case "$QUERY_STRING"` 按 `v=` 直接渲染目标视图为 active（并补 `dev=` 服务端强制定位），浏览器首帧即当前页，彻底消除“先主页后指定页”闪烁；`restoreDashView()` 增加解析 `?v=` 作为 localStorage 之上的优先来源。
  ③ **修复 `updateUrl()` 语法错误连锁失效**：对象字面量未加引号的连字符键名 `{v-capture:'cap',…}` 是非法 JS，导致整个 head `<script>` 块解析失败，主题切换 / admin 退出菜单 / 侧栏切换 / 折叠 / 密码弹窗 / 背景 / 无感刷新全部失效。修复为 `{'v-capture':'cap',…}`；新增可复用 JS 语法风险校验 `jscheck.py`（连字符键名/括号配平/字符串闭合/`</script>` 泄漏），已纳入构建流程步骤 7。
  ④ 已先热更 192.168.0.148（`/usr/sbin/devdash.sh` 直推），busybox `sh -n` 通过、sha 与本地一致、HTTP `?v=` 全视图 200。
- **1.0.9（2026-08-06）** **修复刷新时先显示主页再跳到指定页面（闪烁）**：原实现把侧边栏视图记忆（`dash-view`）恢复到 `DOMContentLoaded`（首帧绘制之后）→ 每次刷新先渲染服务端默认的「设备列表」再切换，出现“先主页后指定页”闪烁。修复：① 抽出 `restoreDashView()`；② 在 `</body>` 前增加同步内联脚本（`<script>` 阻止解析，浏览器首帧绘制前执行）恢复主题按钮/折叠分组状态并调用 `restoreDashView()` 切换视图，刷新直接停在指定页面，无闪跳。已在目标机实测：刷新保持当前视图、HTTP 200 正常。
- **1.0.8（2026-08-06）** **修复 ImmortalWrt 目标机“登录页正常、仪表盘 0 字节”**：根因是缓存新鲜度函数 `fresh()` 依赖 `stat -c %Y`，而目标机 ImmortalWrt 25.12 的 busybox 未编译 `stat` applet（`stat` 与 `busybox stat` 均 not found）→ 算术展开 `$(( $(date +%s) - $(stat -c %Y "$f") ))` 得空值 → `sh: arithmetic syntax error` → 整个 CGI 无输出（登录页/`do_flow` 不经过 `fresh()` 故正常）。修复：`fresh()` 改为多级回退 `stat -c %Y` → `date -r <file> +%s`（busybox/GNU date 均支持），文件缺失/非数值时返回 1。已在目标机实测：`gen()` 输出 363KB、HTTP 200 全板块正常。
- **1.0.7（2026-08-06）** **修复 ImmortalWrt 目标机页面全空白**：根因是脚本含非 POSIX 语法，ImmortalWrt 25.12 的 busybox ash（无 ASH_BASH_COMPAT）在解析阶段报错 → `. /usr/sbin/devdash.sh` 失败 → CGI 无输出 → 空白页。本机 iStoreOS busybox 带 bash 兼容故能通过 `sh -n`，未暴露。修复：① 移除 2 处进程替换 `done < <(...)`（图表聚合循环），改为 heredoc（`done <<EOF`）保持变量作用域且 POSIX 兼容；② 登录页错误提示的 `${var//&/...}` 参数展开替换为 `sed`；③ `$(seq 0 23)` 替换为 `while` 循环。全脚本已扫描无进程替换/`[[`/`<<<`/`${var//}`/数组等 bash 专属语法，任意 POSIX sh 可解析。
- **1.0.5（2026-08-05）** 修复流量页面空白根因（页面生成 15.5s 超 uhttpd CGI 超时被截断）→ TTL 磁盘缓存 + `buildcache` 预热，页面 1.5s；修复 devflow 重启流量清零（`lan_ips` 读错 ARP 列，`$4` 是 HWaddr，devices 在 `$NF`）→ `ip neigh` 首选 + ARP 回退；登录认证重做为自绘登录页 + HttpOnly Session Cookie（保留 Basic Auth 兜底）；修改密码模态表单（验旧密码）；默认密码统一 `admin/devdash`。
- **1.0.4（2026-08-04）** 新增各设备实时流量 + 上下行流量汇总（`devflow.sh` 守护，nftables/iptables 计数，5s 采样，按日累计），左侧导航新增「📊 流量」分组。
- **1.0.3（2026-08-03）** 左侧侧边栏导航（分组可折叠，`dash-view` 记忆，`?dev=/?cap=` 强制定位）；板块按权重重排。
- **1.0.2（2026-08-03）** 去掉硬依赖（tcpdump/openssl 降为可选）；`dev_sha256` 三级回退；自包含 `.run` 安装器；ImmortalWrt BASE 默认 `/etc/devdash-data`。
- **1.0.1（2026-08-03）** 修复背景上传自动刷新失效（localStorage 配额异常）→ canvas 压缩 + 服务端 `.bgimg` 兜底；图表 tooltip 绿底；设备列表可折叠；修改密码；备份导出/导入。
- **1.0.0（2026-08-02 起）** 设备监控/DNS 分析/抓包/趋势图表初版，更名 kelu设备监控仪表盘。
