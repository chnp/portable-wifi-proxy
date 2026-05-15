# Portable WiFi Proxy - 随身WiFi 翻墙方案

将高通 410（MSM8916）随身WiFi 刷入 Debian，部署 Xray VLESS+Reality 代理服务，实现从中国大陆通过美国家庭 IP 上网。

## 特点

- **VLESS + Reality 协议** — 目前抗 GFW 封锁最强的方案，无需域名和证书
- **Cloudflare Tunnel 备选** — 无需公网 IP、无需端口转发，出口仍是家庭原生 IP
- **全自动运行** — 开机自启 Xray、UPnP 自动端口映射、DDNS 自动更新、看门狗自动恢复
- **体积小巧** — U 盘大小，低功耗（~2W），随身携带
- **64 位 AArch64** — Cortex-A53 四核，性能优于玩客云 S805
- **双向使用** — 放美国翻墙出去，放中国翻墙回来，出口都是设备所在地的家庭 IP
- **WiFi 连接** — 无需网线，通过 WiFi 连接家庭路由器

## 硬件需求

- 高通 410（MSM8916）随身WiFi 一个（已刷 Debian / OpenStick）
- USB 电源（充电头 / 充电宝 / 电脑 USB 口）

## 整体架构

```
中国手机/电脑 --> GFW --> 美国家庭路由器 --> 随身WiFi(Xray) --> 目标网站
                              WiFi连接       (VLESS+Reality)
                          (UPnP自动映射)
```

---

## 第一步：刷 Debian 系统

### 1.1 准备工具

- 电脑安装 [QFIL](https://qfiltool.com/)（Qualcomm Flash Image Loader）
- 下载 [OpenStick](https://github.com/OpenStick/OpenStick) 固件或 Debian ARM64 镜像
- 安装高通 9008 驱动

### 1.2 刷机步骤

1. 短接随身WiFi 主板上的触点，进入 **9008 模式**
2. USB 连接电脑，QFIL 识别设备
3. 刷入 Debian / OpenStick 固件
4. 重启设备

> 搜索关键词 `MSM8916 随身WiFi 刷 Debian` 或 `OpenStick 刷机教程` 可找到大量教程。

### 1.3 首次登录

随身WiFi 插到电脑 USB 口，通过 USB 网络共享登录：

```bash
ssh root@192.168.68.1
# 默认密码：1（或根据固件不同可能是 root）
```

---

## 第二步：一键部署（推荐）
需要先连上wifi才能下载，过程中需要记录public key
将本项目克隆到随身WiFi 后，运行安装脚本即可自动完成所有配置：

```bash
apt update && apt install -y git
git clone https://github.com/你的用户名/portable-wifi-proxy.git
cd portable-wifi-proxy
chmod +x setup.sh
./setup.sh
```

脚本会自动完成：
- 修复 apt 软件源
- 安装 Xray
- 生成 UUID 和 Reality 密钥
- 写入配置文件
- 配置开机自启和看门狗
- 安装 UPnP 自动端口映射
- 可选：配置 Cloudflare DDNS

---

## 第三步：手动部署

如果你更喜欢手动操作，按以下步骤进行：

### 3.1 修复 apt 软件源

OpenStick 固件的 sources.list 可能格式有误，先修复：

```bash
cat > /etc/apt/sources.list << "EOF"
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free
EOF
apt update
```

### 3.2 安装依赖

```bash
apt install -y curl wget cron miniupnpc
```

### 3.3 安装 Xray

```bash
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
```

### 3.4 生成密钥

```bash
# 生成 UUID
xray uuid
# 输出示例：a1b2c3d4-5678-9abc-def0-123456789abc

# 生成 Reality 密钥对
xray x25519
# 记下 PrivateKey 和 PublicKey
```

### 3.5 写入配置

将 [config/xray-config.json](config/xray-config.json) 复制到 `/usr/local/etc/xray/config.json`，替换其中的 UUID 和 PrivateKey。

```bash
cp config/xray-config.json /usr/local/etc/xray/config.json
# 编辑并替换 YOUR_UUID 和 YOUR_PRIVATE_KEY
nano /usr/local/etc/xray/config.json
```

### 3.6 启动服务

```bash
xray run -test -config /usr/local/etc/xray/config.json  # 验证配置
systemctl enable xray
systemctl restart xray
```

### 3.7 配置自动重启

```bash
cp config/restart.conf /etc/systemd/system/xray.service.d/restart.conf
systemctl daemon-reload
```

### 3.8 安装看门狗

```bash
cp scripts/xray-watchdog.sh /usr/local/bin/
chmod +x /usr/local/bin/xray-watchdog.sh
(crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/xray-watchdog.sh") | crontab -
```

### 3.9 配置 UPnP

```bash
cp scripts/upnp-map.sh /usr/local/bin/
chmod +x /usr/local/bin/upnp-map.sh
cp config/upnp-map.service /etc/systemd/system/
cp config/upnp-map.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable upnp-map.service upnp-map.timer
```

### 3.10 配置 DDNS（可选）

如果你有 Cloudflare 域名：

```bash
cp scripts/ddns-update.sh /usr/local/bin/
chmod +x /usr/local/bin/ddns-update.sh
# 编辑填入你的 Cloudflare Zone ID、Record ID、API Token
nano /usr/local/bin/ddns-update.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/ddns-update.sh") | crontab -
```

---

## 第四步：连接美国家庭 WiFi

随身WiFi 只有一个无线网卡，WiFi 连接和热点**只能二选一**，因此需要通过 USB 方式配置。

### 到美国后操作（只需做一次）

1. **随身WiFi 插到电脑 USB 口**（供电 + USB 网络共享）
2. SSH 登录：
   ```bash
   ssh root@192.168.68.1
   ```
3. 扫描并连接家里 WiFi：
   ```bash
   nmcli dev wifi list                              # 扫描附近WiFi
   nmcli dev wifi connect "WiFi名" password "密码"   # 连接
   ```
4. 连好后拔掉 USB，**单独插电源即可**

WiFi 连接会永久保存，以后开机自动连接。

---

## 第五步：客户端配置

### 分享链接格式

```
vless://YOUR_UUID@你的域名或IP:8443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=YOUR_PUBLIC_KEY&sid=abcd1234&type=tcp#WiFi-US
```

### 推荐客户端

| 平台 | 客户端 |
|------|--------|
| Android | [v2rayNG](https://github.com/2dust/v2rayNG) |
| iOS | Shadowrocket（App Store 美区） |
| Windows | [v2rayN](https://github.com/2dust/v2rayN) |
| Mac | [Nekoray](https://github.com/MatsuriDayo/nekoray) / V2rayU |

### 客户端参数

| 参数 | 值 |
|------|-----|
| 协议 | VLESS |
| 地址 | 你的域名或公网 IP |
| 端口 | 8443 |
| UUID | 安装时生成的 UUID |
| 流控 | xtls-rprx-vision |
| 传输 | tcp |
| 安全 | reality |
| SNI | www.microsoft.com |
| Public Key | 安装时生成的公钥 |
| Short ID | abcd1234 |

---

## 远程维护（从中国 SSH 到随身WiFi）

代理连通后，可以通过代理 SSH 回设备进行维护：

```bash
# 通过本地 SOCKS5 代理 SSH
ssh -o ProxyCommand="nc -x 127.0.0.1:10808 %h %p" root@随身WiFi内网IP
```

### 故障兜底

- **Xray 崩溃** — 看门狗每分钟自动重启，systemd 也会自动重启
- **完全失联** — 请人拔掉电源再插上，或用智能插座远程断电重启
- **编辑配置前备份** — 使用 `xedit` 命令自动备份后再编辑

---

## 注意事项

### USB 口是 Device 模式

随身WiFi 的 USB 口是**从设备模式**（Device），不是主设备模式（Host），因此：
- ❌ 不能外接 USB 扩展坞、USB 网卡
- ✅ 可以插电脑获取供电和 USB 网络共享（192.168.68.1）

### WiFi 和热点只能二选一

设备只有一个无线网卡（wlan0），连接 WiFi 和发射热点不能同时进行。连接家庭 WiFi 后热点功能不可用。

### 内存较小

MSM8916 通常只有 512MB 或更少的内存，Xray 运行约占 20-30MB，日常使用没有问题，但不要运行其他重型服务。

---

## 自动化清单

| 功能 | 机制 | 频率 |
|------|------|------|
| Xray 自启 | systemctl enable | 开机 |
| Xray 崩溃重启 | systemd Restart=on-failure | 实时 |
| Xray 看门狗 | crontab | 每分钟 |
| UPnP 端口映射 | systemd timer | 开机30s + 每小时 |
| DDNS 更新 | crontab | 每5分钟 |
| WiFi 自动重连 | NetworkManager | 开机 |

---

## 与玩客云方案对比

| | 玩客云 S805 | 随身WiFi MSM8916 |
|--|------------|------------------|
| CPU | Cortex-A5 单核 32位 | Cortex-A53 四核 64位 |
| 内存 | 1GB | 382MB |
| 网络 | 有线网 | WiFi |
| 体积 | 较大 | U盘大小 |
| 功耗 | ~5W | ~2W |
| USB 外接 | 支持 | 不支持（Device模式） |
| 稳定性 | 有线更稳 | WiFi 偶尔可能断连 |

两个设备可以同时部署，互为备份。

---

## Cloudflare Tunnel 方案（无需公网 IP）

如果你的网络没有公网 IP（运营商 NAT），或路由器不支持端口转发/UPnP，可以使用 Cloudflare Tunnel。

### 工作原理

```
手机/电脑 --> Cloudflare --> 隧道 --> 随身WiFi(Xray) --> 本地互联网
                                                         ↑
                                                    出口是家庭IP ✅
```

Cloudflare Tunnel 只是传输通道，**出口 IP 仍然是设备所在地的家庭原生 IP**。

### 与直连方案的区别

| | 直连 Reality | Cloudflare Tunnel |
|--|-------------|-------------------|
| 需要公网 IP | 是 | **否** |
| 需要端口转发 | 是 | **否** |
| 出口 IP | 家庭 IP ✅ | 家庭 IP ✅ |
| 速度 | 快（一跳） | 稍慢（多一跳） |
| 传输协议 | TCP + Reality | WebSocket + TLS |

### 部署步骤

```bash
# 1. 安装 cloudflared
curl -L -o /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
chmod +x /usr/local/bin/cloudflared

# 2. 登录授权（浏览器打开给出的链接）
cloudflared tunnel login

# 3. 创建隧道
cloudflared tunnel create my-proxy

# 4. 替换 Xray 配置为 WebSocket 模式
cp config/xray-config-ws.json /usr/local/etc/xray/config.json
# 编辑替换 YOUR_UUID
nano /usr/local/etc/xray/config.json
systemctl restart xray

# 5. 配置 cloudflared
cat > ~/.cloudflared/config.yml << EOF
tunnel: YOUR_TUNNEL_ID
credentials-file: /root/.cloudflared/YOUR_TUNNEL_ID.json

ingress:
  - hostname: your.domain.com
    service: http://127.0.0.1:8443
  - service: http_status:404
EOF

# 6. 关联域名并启动
cloudflared tunnel route dns my-proxy your.domain.com
cloudflared service install
systemctl start cloudflared
```

### Tunnel 方案客户端参数

| 参数 | 值 |
|------|-----|
| 协议 | VLESS |
| 地址 | your.domain.com |
| 端口 | **443** |
| UUID | 安装时生成的 UUID |
| 传输 | **ws** |
| 路径 | **/proxy** |
| 安全 | **tls** |
| SNI | **your.domain.com** |

### 分享链接格式

```
vless://YOUR_UUID@your.domain.com:443?encryption=none&security=tls&sni=your.domain.com&type=ws&path=%2Fproxy#My-Proxy
```

### 双向使用场景

| 设备位置 | 用途 | 出口 IP |
|---------|------|---------|
| 放在美国家里 | 在中国翻墙到美国 | 美国家庭 IP |
| 放在中国家里 | 在美国访问中国内容 | 中国家庭 IP |

> **建议：** 有公网 IP 优先用直连 Reality 方案（速度快），没有公网 IP 用 Cloudflare Tunnel。两种方案出口 IP 都是家庭原生 IP。

## License

MIT
