#!/bin/bash
# LisaSpeed / Hiddify 网络应急恢复脚本
# 用途：软件异常退出后整机断网、DNS 异常、代理残留时，一键清理并恢复本机网络。
# 用法：
#   sudo /Users/ldy/LisaSpeed/scripts/fix-network.sh
# 或双击 / 终端运行（会弹窗要管理员密码）：
#   /Users/ldy/LisaSpeed/scripts/fix-network.command

set -u

log() { echo "[fix-network] $*"; }

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "请用管理员权限运行，例如："
    echo "  sudo \"$0\""
    exit 1
  fi
}

kill_helpers() {
  log "结束残留进程..."
  pkill -9 -f '/Applications/LisaSpeed.app/Contents/MacOS/HiddifyCli' 2>/dev/null || true
  pkill -9 -f '/Applications/Hiddify.app/Contents/MacOS/HiddifyCli' 2>/dev/null || true
  pkill -9 -f 'HiddifyCli' 2>/dev/null || true
  pkill -9 -f 'HiddifyTunnelService' 2>/dev/null || true
  pkill -9 -f '/Library/Application Support/HiddifyTunnelService' 2>/dev/null || true
  # 不强制杀 LisaSpeed/Hiddify 主程序，避免误伤正在使用；如需一并退出可取消注释：
  # pkill -9 -x LisaSpeed 2>/dev/null || true
  # pkill -9 -x Hiddify 2>/dev/null || true
}

disable_launch_daemon() {
  log "停用 HiddifyTunnelService 守护进程..."
  local plist="/Library/LaunchDaemons/HiddifyTunnelService.plist"
  local disabled="/Library/LaunchDaemons/HiddifyTunnelService.plist.disabled"

  launchctl bootout system/HiddifyTunnelService 2>/dev/null || true
  launchctl unload "$plist" 2>/dev/null || true
  launchctl remove HiddifyTunnelService 2>/dev/null || true

  if [[ -f "$plist" ]]; then
    mv -f "$plist" "$disabled"
    log "已禁用: $plist -> $disabled"
  elif [[ -f "$disabled" ]]; then
    log "守护进程已处于禁用状态: $disabled"
  else
    log "未找到 HiddifyTunnelService LaunchDaemon"
  fi
}

destroy_orphan_utuns() {
  log "清理残留 TUN 接口..."
  # sing-box / Hiddify 常见残留：utunXXXX + 172.19.0.1
  local iface
  while read -r iface; do
    [[ -z "$iface" ]] && continue
    log "销毁 $iface"
    ifconfig "$iface" destroy 2>/dev/null || ifconfig "$iface" down 2>/dev/null || true
  done < <(ifconfig -l | tr ' ' '\n' | grep -E '^utun[0-9]+$' || true)

  # 再按地址兜底找一次
  while read -r iface; do
    [[ -z "$iface" ]] && continue
    if ifconfig "$iface" 2>/dev/null | grep -q '172.19.0.1'; then
      log "发现 172.19.0.1 在 $iface，尝试销毁"
      ifconfig "$iface" destroy 2>/dev/null || ifconfig "$iface" down 2>/dev/null || true
    fi
  done < <(ifconfig -l | tr ' ' '\n' | grep -E '^utun' || true)
}

flush_bad_routes() {
  log "删除指向隧道的异常路由..."
  # sing-box 常见分流默认路由
  local cidr
  for cidr in \
    0.0.0.0/1 \
    128.0.0.0/1 \
    1.0.0.0/8 \
    2.0.0.0/7 \
    4.0.0.0/6 \
    8.0.0.0/5 \
    16.0.0.0/4 \
    32.0.0.0/3 \
    64.0.0.0/2
  do
    route -n delete -net "$cidr" 2>/dev/null || true
  done

  # 删除仍指向 utun* / 172.19.0.1 的路由
  netstat -rn -f inet 2>/dev/null | awk '
    $1 ~ /^[0-9]/ && ($NF ~ /^utun/ || $(NF-1) == "172.19.0.1" || $2 == "172.19.0.1") {
      print $1
    }
  ' | while read -r dest; do
    [[ -z "$dest" || "$dest" == "default" ]] && continue
    route -n delete -net "$dest" 2>/dev/null || route -n delete -host "$dest" 2>/dev/null || true
  done

  route -n delete -host 172.19.0.1 2>/dev/null || true
}

reset_system_proxy_and_dns() {
  log "重置各网络服务的系统代理与 DNS..."
  local service
  # networksetup 列表首行是说明文字
  while IFS= read -r service; do
    [[ -z "$service" || "$service" == *"asterisk"* || "$service" == An* ]] && continue
    # 去掉禁用标记 *
    service="${service#\*}"
    networksetup -setwebproxystate "$service" off 2>/dev/null || true
    networksetup -setsecurewebproxystate "$service" off 2>/dev/null || true
    networksetup -setsocksfirewallproxystate "$service" off 2>/dev/null || true
    networksetup -setproxyautodiscovery "$service" off 2>/dev/null || true
    networksetup -setdnsservers "$service" Empty 2>/dev/null || true
    networksetup -setsearchdomains "$service" Empty 2>/dev/null || true
  done < <(networksetup -listallnetworkservices 2>/dev/null | tail -n +2)
}

flush_dns_cache() {
  log "刷新 DNS 缓存..."
  dscacheutil -flushcache 2>/dev/null || true
  killall -HUP mDNSResponder 2>/dev/null || true
  killall -HUP mDNSResponderHelper 2>/dev/null || true
}

print_status() {
  echo
  log "==== 当前状态 ===="
  echo "-- 默认路由 --"
  netstat -rn -f inet 2>/dev/null | grep -E '^default' || true
  echo "-- 仍含 utun / 172.19 的路由 --"
  netstat -rn -f inet 2>/dev/null | grep -E 'utun|172\.19' || echo "(无)"
  echo "-- DNS --"
  scutil --dns 2>/dev/null | head -12 || true
  echo "-- 连通性 --"
  if ping -c 1 -W 2000 223.5.5.5 >/dev/null 2>&1; then
    echo "ping 223.5.5.5: OK"
  else
    echo "ping 223.5.5.5: FAIL"
  fi
  if curl -I --max-time 8 https://www.baidu.com >/dev/null 2>&1; then
    echo "HTTPS www.baidu.com: OK"
  else
    echo "HTTPS www.baidu.com: FAIL（若公司网络本身受限，可能仍正常）"
  fi
  echo
  log "完成。若仍无网：先断开公司 VPN / 其它代理软件后，再运行本脚本一次。"
}

main() {
  require_root
  log "开始清理 LisaSpeed/Hiddify 网络残留..."
  kill_helpers
  disable_launch_daemon
  destroy_orphan_utuns
  flush_bad_routes
  reset_system_proxy_and_dns
  flush_dns_cache
  sleep 1
  print_status
}

main "$@"
