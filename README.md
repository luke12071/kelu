# kelu
路由器插件

功能介绍:实现统计设备上网时长 、dns请求 、网络过滤、抓包分析; 支持自定义背景、数据保存时间修改、支持数据导入恢复,导出备份、修改密码等功能.
目前仅仅支持2024.12 istore/openwrt (opkg),待后续完善

# kelu设备监控仪表盘维护记录:
<img width="1507" height="1309" alt="截屏2026-08-03 12 17 04" src="https://github.com/user-attachments/assets/c5e6e6c3-0d5d-4b90-93e3-a3af9eb50490" />
> 2026-08-03 更名：局域网设备监控仪表盘 → **kelu设备监控仪表盘**；页眉已嵌入作者邮箱 `xinkeji139577@sina.com`

> 2026-08-03 二改：浏览器标题改为「kelu监控」；页面板块按权重重排（设备列表/DNS 概览/趋势图表在前，抓包/过滤/保存设置在后）；「生成」行字体改深黑色 `#111`
> 
> 2026-08-03 三改：新增「备份导出 / 导入恢复」（.blocklist、.retention、devices.tsv、events.log、.bgimg 打包 tar.gz）；新增「设为默认背景」将当前背景持久化到服务端 `.bgimg`，页面自动加载；新增「备份与恢复」面板；CGI 入口增加 `export=1`/`import=1`/`bgset=1` 动作分发
> 
> 2026-08-03 四改（1.0.1）：修复「设置背景图片后自动刷新失效」。原因：背景以 base64 data-URL 存浏览器 `localStorage`，大图超配额（约 5MB）时 `setItem` 抛异常，上传后 60s 自动刷新即丢失。修复：上传时用 canvas 压缩（最长边 1920px、JPEG 0.82；≤300KB 原样保留），并自动 `POST ?bgset=1` 持久化到服务端 `.bgimg`，刷新由服务端兜底恢复；`applyBg` 对 localStorage 写入加 try/catch 防配额异常。打包 1.0.1-1 并已重装。
> 
> 2026-08-03 五改（1.0.1）：① 图表 tooltip 改为绿底（#4caf50）黑字加粗；② 顶栏移除「备份导出/导入恢复」（移至「备份与恢复」面板，功能不变），按钮包入 `.topbtns` flex 容器统一 10px 间距；③ 设备列表可折叠（点击标题，状态存 `localStorage.dash-devfold`）；④ 新增「🔑 修改密码」按钮（`?passwd=1` POST 新密码 → sha256 → 写入 `/etc/devdash.conf` 的 `DEVDASH_HASH`，下次登录生效）。

## 一、功能总览

通过 `/cgi-bin/devdash` 访问（需 Basic Auth），展示局域网设备在线状态、DNS 查询分析、流量抓包、在线时长排行等 9 个面板，60 秒自动刷新。

| 面板 | 数据来源 | 说明 |
|---|---|---|
| 各设备 DNS 请求 | DNS 日志 | 每设备查询总数 + Top3 域名 |
| 抓包分析（br-lan） | tcpdump 实时抓包 | 可触发 10s/30s 抓包，Top10 连接 + 各设备 Top2 目标 |
| 数据保存设置 | `.retention` | 7/15/30/60/90 天日志保留 |
| 设备列表 | `devices.tsv` | 在线状态 / MAC / 主机名 / IP / 在线时长 |
| 最近 7 天访问趋势 | `.trend` | **按设备多色折线** |
| 今日 24 小时查询分布 | `.trend` | **按设备多色堆叠柱状** |
| 在线时长排行 Top10 | `.topdur` | **按设备配色** |
| 各设备访问域名 Top5 | DNS 日志 | 分页（每页 10 设备） |
| 网络过滤（网址屏蔽） | `.blocklist` + dnsmasq | 输入域名屏蔽/解除，热重启 dnsmasq |
| 最近设备事件 | `events.log` | 上下线记录 |
| 备份与恢复 | 配置文件打包 | 导出/导入备份，含屏蔽列表、保留天数、设备台账、事件日志、默认背景 |

顶栏按钮：☀/🌙 主题、🔑 修改密码、🖼 背景图、✕ 清除、📌 设为默认、🗑 清除默认、背景透明滑条（备份导出/导入在下方面板）。
设备列表标题可点击折叠/展开（状态存 `localStorage.dash-devfold`）。
修改密码：`?passwd=1` POST 新密码 → sha256 写入 `/etc/devdash.conf` 的 `DEVDASH_HASH`，下次访问生效。

## 二、涉及文件

| 文件 | 作用 |
|---|---|
| `/www/cgi-bin/devdash` | CGI 入口（Basic Auth 校验，sha256） |
| `/usr/sbin/devdash.sh` | 页面生成主逻辑（`gen()` 函数） |
| `/usr/sbin/devmon.sh` | 设备在线监控守护（procd 运行，30s 周期） |
| `/usr/sbin/devprobe.sh` | 设备型号探测（avahi/iwinfo，cron 每 10 分钟） |
| `/usr/sbin/devlogclean.sh` | DNS 日志保留清理（cron 每天 3:15） |
| `/etc/init.d/devmon` | devmon 服务启停（`/etc/init.d/devmon enable/start`） |

数据目录：`/mnt/usb2_2-4/Public/device-monitor/`
DNS 日志：`/mnt/usb2_2-4/Public/Downloads/access.log*`

## 三、Cron 任务（/etc/crontabs/root）

```
0 3 * * 1   轮转 access.log → access.log.$(date +%Y%m%d) 并 killall -HUP dnsmasq
*/10 * * * * /usr/sbin/devprobe.sh >/dev/null 2>&1
0 */3 * * *  /usr/local/bin/pika-watchdog.sh >/dev/null 2>&1   # pika-agent 看门狗，与本面板无关
15 3 * * *   /usr/sbin/devlogclean.sh >/dev/null 2>&1
```

## 四、图表优化说明（本次改动）

### 1. 数据管道改为按设备维度
原 `.trend` 只有整体汇总（`D 日期 总数` / `H 小时 总数`），现按设备拆分：

```
D 08-02 192.168.9.100 703      # 每行含 IP
H 03 192.168.9.100 68
```

`gen()` 中从 `$TREND` 聚合出 `DEVTOT`（每设备总查询 Top6），为每个设备生成独立序列：
- `D7S`：最近 7 天每天查询数（折线）
- `H24S`：今天每小时查询数（堆叠柱状）
- `DURI`：在线时长排行每个设备对应 IP（用于配色）

### 2. 设备配色
- JS 中定义 12 色 `PAL` 调色板，`devColor(ip)` 按 `DEVIPS` 索引取色
- 同一设备在三个图表中颜色一致（在线时长、7 天趋势、24 小时分布）

### 3. 图表结构
- 7 天趋势：多设备多折线 + `legend` 图例（scroll 模式），每设备 `areaStyle` 渐变
- 24 小时分布：`stack:'total'` 堆叠柱状，可对比各设备占比
- 在线时长 Top10：每根柱子按设备 IP 着色，`borderRadius` 圆角

## 五、主题背景图按钮（本次新增）

(1)页面右上角新增两个按钮：
- **🖼 背景图**：点击选择本地图片上传，作为整页背景
- **✕ 清除背景**：恢复默认纯色背景
- **📌 设为默认背景**：把当前浏览器背景图持久化到服务端 `$BASE/.bgimg`，所有访问者刷新后自动加载
- **🗑 清除默认背景**：删除服务端 `.bgimg`，恢复纯色背景

实现：
- 上传图片经 `FileReader.readAsDataURL` 转 base64，写入 `localStorage['dash-bg']`
- 页面刷新时 `localStorage` 恢复背景（`#bgimg` 层）；无本地背景时加载服务端默认 `.bgimg`
- `#bgveil` 半透明遮罩层保证前景文字可读（暗色 0.72 / 亮色 0.76）
- 背景仅存于浏览器本地，不写服务器文件

(2)、备份导出 / 导入恢复（本次新增）

页面右上角及「备份与恢复」面板提供：
- **💾 备份导出**：`?export=1`，把 `.blocklist .retention devices.tsv events.log .bgimg` 打包为 `devdash-backup-YYYYMMDD-HHMMSS.tar.gz` 下载（`Content-Disposition: attachment`）
- **📥 导入恢复**：上传备份包，`?import=1` 走 POST body（`CONTENT_LENGTH` 从 stdin 读取）→ 校验 tar → 解压到临时目录 → 覆盖匹配文件 → 自动 `/etc/init.d/dnsmasq restart` + `devlogclean.sh`

CGI 动作分发：`/www/cgi-bin/devdash` 在 Basic Auth 通过后按 `QUERY_STRING` 分发：
```
?export=1  → do_export    （二进制下载，Content-Type: application/x-targz）
?import=1  → do_import    （text/plain 结果）
?bgset=1   → do_bgset     （text/plain 结果，POST body 写入 .bgimg，空体=清除）
其他       → gen()        （HTML 页面）
```

## 六、数据保留天数（上次改动）

- 通过 `?ret=N`（7/15/30/60/90）设置，写入 `$BASE/.retention`，立即触发 `devlogclean.sh`
- `dns_files()` 按保留天数过滤日志文件（按文件 mtime 计算年龄）
- `devlogclean.sh` 删除超过保留天数的 `access.log.*` 并记入 events.log

## 七、维护命令

(1)sh
# 重启 devmon 守护
/etc/init.d/devmon restart

# 手动触发日志轮转
mv /mnt/usb2_2-4/Public/Downloads/access.log /mnt/usb2_2-4/Public/Downloads/access.log.$(date +%Y%m%d) && killall -HUP dnsmasq

# 手动清理过期日志（按 .retention 天数）
/usr/sbin/devlogclean.sh

# 验证页面脚本语法
sh -n /usr/sbin/devdash.sh

# 本地渲染测试
unset QUERY_STRING; . /usr/sbin/devdash.sh && gen > /tmp/test.html

# 屏蔽/解除网址（等效页面操作）
QUERY_STRING="block=example.com"; . /usr/sbin/devdash.sh && gen >/dev/null
QUERY_STRING="unblock=example.com"; . /usr/sbin/devdash.sh && gen >/dev/null

# 命令行备份导出（等价页面「导出备份」，纯 tar.gz 不含 HTTP 头）
cd /mnt/usb2_2-4/Public/device-monitor && tar czf /tmp/devdash-backup.tar.gz .blocklist .retention devices.tsv events.log .bgimg 2>/dev/null || true

# 命令行导入恢复（从备份文件读取，等价页面「导入恢复」）
cd /mnt/usb2_2-4/Public/device-monitor && CONTENT_LENGTH=$(wc -c < /tmp/devdash-backup.tar.gz) sh -c '. /usr/sbin/devdash.sh; do_import' < /tmp/devdash-backup.tar.gz

# 设置/清除默认背景（等效页面操作）
echo -n 'url(data:image/png;base64,...)' | CONTENT_LENGTH=<长度> sh -c '. /usr/sbin/devdash.sh; do_bgset'
CONTENT_LENGTH=0 sh -c '. /usr/sbin/devdash.sh; do_bgset'
```

(2)、网址屏蔽机制

- 屏蔽列表：`$BASE/.blocklist`（每行一个域名）
- 屏蔽规则写入 dnsmasq conf-dir（`/tmp/dnsmasq.cfg*.d/devdash-block.conf`）：
  - `address=/example.com/0.0.0.0` 与 `address=/example.com/::` 双重屏蔽 IPv4/IPv6
- 添加/删除后 `/etc/init.d/dnsmasq restart` 生效（HUP 不加载 conf-dir 新文件，必须 restart）
- 域名规范化：`norm_dom()` 自动剥掉 `https://`、路径、端口、大小写；校验非法字符（`..`、`--`、首尾点）直接拒绝
- 已知坑：BusyBox `tr '[:upper:]' '[:lower:]'` 字符类会乱码（`p`→`w`），必须用 `tr 'A-Z' 'a-z'`

##  八、CGI 认证

`/www/cgi-bin/devdash` 内置 Basic Auth：
- 用户名 `admin`，密码为 `AUTH_HASH` 对应的 sha256（当前值 `ab23e13367...`）
- 页面修改密码：顶栏「🔑 修改密码」→ `?passwd=1` POST 新密码 → `do_passwd()` 计算 sha256 并写入 `/etc/devdash.conf` 的 `DEVDASH_HASH`（无则追加），下次登录生效
- 命令行修改密码：`AUTH_HASH=$(printf '%s' '新密码' | openssl dgst -sha256 | awk '{print $NF}')`，再写入 `/etc/devdash.conf` 的 `DEVDASH_HASH`

## 九、打包为 iStore/OpenWrt 插件（本次新增）

生成两个 `.ipk`，存放在 `/mnt/usb2_2-4/Public/device-monitor/packages/`：

| 包 | 说明 |
|---|---|
| `luci-app-devdash_1.0.0-1_all.ipk` | 实际功能包（脚本 + CGI + init.d） |
| `app-meta-devdash_1.0.0-1_all.ipk` | iStore 元信息包（安装到 `/usr/lib/opkg/meta/devdash.json`，依赖功能包） |

### 安装方式
```sh
# 方式一：iStore / is-opkg 安装（推荐）
is-opkg install /mnt/usb2_2-4/Public/device-monitor/packages/app-meta-devdash_1.0.0-1_all.ipk

# 方式二：直接 opkg 安装
opkg install /mnt/usb2_2-4/Public/device-monitor/packages/luci-app-devdash_1.0.0-1_all.ipk
```
安装后：`devmon` 服务自动 enable+start，cron 自动追加 `devprobe.sh`（每 10 分钟）与 `devlogclean.sh`（每天 3:15），iStore 已安装列表出现「局域网设备监控」。

### 重新打包（修改后）
```sh
# 1. 编辑 /usr/sbin/devdash.sh 等源文件
# 2. 重新生成 ipk（构建脚本 /tmp/opencode/build-ipk.sh）
#    格式：gzip tar 内含 debian-binary + control.tar.gz + data.tar.gz（OpenWrt 新版 ipk 格式，非 ar）
```

### 配置（/etc/devdash.conf，由 postinst 自动生成）
```
DEVDASH_BASE=/mnt/usb2_2-4/Public/device-monitor   # 数据目录
DEVDASH_DNSDIR=/mnt/usb2_2-4/Public/Downloads      # DNS 日志目录
DEVDASH_IFACE=br-lan                               # 抓包网卡
DEVDASH_USER=admin                                 # 网页登录用户名
DEVDASH_HASH=<sha256>                              # 网页登录密码 sha256
```
默认值即本机配置；装到其它设备时编辑该文件后 `/etc/init.d/devmon restart` 即可。

