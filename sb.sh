#!/usr/bin/env bash
# 精简 sing-box：VLESS-Reality(443)；每天北京时间 05:00 自动检查更新（失败自动回滚）；最后打印 v2rayN 链接
# 再次运行 = 卸载本脚本装的旧版本并全新安装（密钥全部重新生成）
# 服务器是中国 IP 时，下载/查版本自动走 ghfast.top 或 gh-proxy.com 镜像（随机选，失败换另一个，最后直连）
# 可选环境变量：SNI=域名  SERVER_IP=公网IP  SB_VERSION=1.x.y
set -e
SNI=${SNI:-blog.lyrnox.com}
D=/etc/sing-box
SB=/usr/local/bin/sing-box

[ "$(id -u)" = 0 ] || { echo "请用 root 运行"; exit 1; }
for c in curl tar ss; do command -v $c >/dev/null || { echo "缺少 $c"; exit 1; }; done

# ---- 已装过则先卸载（只动本脚本装的，以 sb-update 为标记）----
if [ -e /usr/local/bin/sb-update ]; then
  systemctl disable --now sing-box sb-update.timer >/dev/null 2>&1 || true
  rm -rf $D $SB /usr/local/bin/sb-update /etc/systemd/system/sing-box.service /etc/systemd/system/sb-update.*
  systemctl daemon-reload
  echo "已卸载旧安装，重新安装中（密钥全部重新生成，请使用下面的新链接）..."
elif [ -e /etc/systemd/system/sing-box.service ]; then
  echo "检测到其他脚本安装的 sing-box，请先手动卸载"; exit 1
fi
ss -ltnH | grep -q ':443 ' && { echo "443 端口已被占用"; exit 1; }

# ---- 更新器（安装与每日更新共用）----
cat > /usr/local/bin/sb-update <<'EOF'
#!/bin/sh
B=/usr/local/bin/sing-box
case $(uname -m) in x86_64) A=amd64;; aarch64) A=arm64;; *) echo "不支持的架构"; exit 1;; esac
# 中国 IP：访问 GitHub 走镜像（随机选一个先试，失败换另一个，最后直连）
CTRY=$(curl -fsS --max-time 5 https://ipinfo.io/country 2>/dev/null || curl -fsS --max-time 5 https://ipapi.co/country 2>/dev/null)
case $CTRY in CN*) P=$(shuf -e https://ghfast.top/ https://gh-proxy.com/);; *) P=;; esac
V=$SB_VERSION
[ -n "$V" ] || for p in $P ""; do
  V=$(curl -fsSL --max-time 15 "${p}https://api.github.com/repos/SagerNet/sing-box/releases/latest" | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')
  [ -n "$V" ] && break
done
[ -n "$V" ] || { echo "获取版本失败"; exit 1; }
[ "$V" = "$($B version 2>/dev/null | sed -n '1s/^sing-box version //p')" ] && exit 0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
for p in $P ""; do
  curl -fsSL --max-time 180 "${p}https://github.com/SagerNet/sing-box/releases/download/v$V/sing-box-$V-linux-$A.tar.gz" -o "$T/sb.tgz" && tar xzf "$T/sb.tgz" -C "$T" --strip-components=1 2>/dev/null && [ -f "$T/sing-box" ] && break
done
[ -f "$T/sing-box" ] || { echo "下载失败"; exit 1; }
[ -s /etc/sing-box/config.json ] && ! "$T/sing-box" check -c /etc/sing-box/config.json && { echo "新版本与当前配置不兼容，跳过"; exit 1; }
[ -x $B ] && cp $B $B.bak
install -m755 "$T/sing-box" $B || { [ -f $B.bak ] && mv $B.bak $B; echo "安装失败"; exit 1; }
if systemctl is-enabled --quiet sing-box 2>/dev/null; then
  systemctl restart sing-box; sleep 3
  systemctl is-active --quiet sing-box || { [ -f $B.bak ] && mv $B.bak $B && systemctl restart sing-box; echo "更新失败，已回滚"; exit 1; }
fi
rm -f $B.bak
EOF
chmod +x /usr/local/bin/sb-update
/usr/local/bin/sb-update

# ---- 随机参数 ----
mkdir -p $D && cd $D
UUID=$($SB generate uuid)
K=$($SB generate reality-keypair)
PRIV=$(echo "$K" | awk '/PrivateKey/{print $2}')
PUB=$(echo "$K" | awk '/PublicKey/{print $2}')
SID=$($SB generate rand 8 --hex)
IP=${SERVER_IP:-$(curl -4fsS --max-time 6 https://api.ipify.org || curl -4fsS --max-time 6 https://ipinfo.io/ip || curl -4fsS --max-time 6 https://ip.sb || true)}
[ -n "$IP" ] || { echo "获取公网 IP 失败，请用 SERVER_IP=x.x.x.x 重试"; exit 1; }

# ---- 配置 ----
cat > config.json <<EOF
{
  "log": {"level": "warn"},
  "inbounds": [
    {
      "type": "vless", "tag": "reality", "listen": "::", "listen_port": 443,
      "users": [{"uuid": "$UUID", "flow": "xtls-rprx-vision"}],
      "tls": {
        "enabled": true, "server_name": "$SNI",
        "reality": {
          "enabled": true,
          "handshake": {"server": "$SNI", "server_port": 443},
          "private_key": "$PRIV", "short_id": ["$SID"]
        }
      }
    }
  ],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}
EOF
$SB check -c config.json

# ---- systemd：服务（启动时幂等放行本机 iptables 的 TCP 443）+ 每日更新（北京 05:00 = UTC 21:00）----
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box
After=network-online.target
Wants=network-online.target
[Service]
ExecStartPre=-/bin/sh -c 'iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport 443 -j ACCEPT'
ExecStart=$SB run -c $D/config.json
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/sb-update.service <<EOF
[Unit]
Description=sing-box update
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/sb-update
EOF
cat > /etc/systemd/system/sb-update.timer <<EOF
[Unit]
Description=sing-box daily update at 05:00 Beijing time
[Timer]
OnCalendar=*-*-* 21:00:00 UTC
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now sing-box sb-update.timer

# ---- v2rayN 链接 ----
cat > links.txt <<EOF
vless://$UUID@$IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=chrome&pbk=$PUB&sid=$SID&type=tcp&headerType=none#sb-reality
EOF
chmod 600 links.txt
echo; cat links.txt; echo
echo "云安全组/安全列表放行：TCP 443    再看链接：cat $D/links.txt    再次运行本脚本 = 卸载重装"
