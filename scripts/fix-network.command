#!/bin/bash
# 双击或在终端直接运行即可（会弹出 macOS 管理员密码框）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIX_SCRIPT="$SCRIPT_DIR/fix-network.sh"

if [[ ! -f "$FIX_SCRIPT" ]]; then
  osascript -e 'display dialog "找不到 fix-network.sh" buttons {"好"} default button 1 with icon stop'
  exit 1
fi

osascript <<EOF
do shell script "/bin/bash $(printf %q "$FIX_SCRIPT")" with administrator privileges
EOF
STATUS=$?

if [[ $STATUS -eq 0 ]]; then
  osascript -e 'display dialog "网络清理完成。\n请再试打开网页；若仍异常，先断开其它 VPN 后再跑一次。" buttons {"好"} default button 1 with title "LisaSpeed 网络恢复"'
else
  osascript -e 'display dialog "清理失败或已取消（未输入密码）。\n也可在终端执行：\nsudo '"$FIX_SCRIPT"'" buttons {"好"} default button 1 with icon caution with title "LisaSpeed 网络恢复"'
fi

exit $STATUS
