#!/bin/bash
# LisaSpeed 本机重新编译并安装到 /Applications
#
# 完整同步内容：
#   1) 重编 hiddify-core → bin/HiddifyCli + bin/hiddify-core.dylib
#      （HiddifyCli=隧道助手；dylib=GUI 侧 core，含启动超时/共存等 Go 改动）
#   2) flutter build macos（UI），并把新 HiddifyCli 与 dylib 强制打进 .app
#   3) 覆盖 /Applications，杀掉旧隧道进程后重开
#
# 用法：
#   1) 双击桌面快捷方式 / 无参数：交互式完整流程
#   2) rebuild-and-install.command compile
#        仅离线编译，不退出正在运行的应用（供应用内「立即更新」调用）
#   3) rebuild-and-install.command install
#        退出应用 → 覆盖安装 → 重新打开（应由分离进程调用）
#
# 环境变量：
#   ALLOW_ONLINE_PUB=1  离线缓存缺包时允许联网 pub get
#   SKIP_CORE=1         跳过 Go/HiddifyCli 重编（仅 UI，不推荐）

set -euo pipefail

APP_NAME="LisaSpeed"
ROOT_DIR="/Users/ldy/LisaSpeed"
PROJECT_DIR="$ROOT_DIR/hiddify-app"
CORE_DIR="$ROOT_DIR/hiddify-core"
FLUTTER_BIN="/Users/ldy/flutter/bin/flutter"
SRC_APP="$PROJECT_DIR/build/macos/Build/Products/Release/${APP_NAME}.app"
DEST_APP="/Applications/${APP_NAME}.app"
CLI_SRC="$CORE_DIR/bin/HiddifyCli"
DYLIB_SRC="$CORE_DIR/bin/hiddify-core.dylib"
LOG_FILE="$HOME/Library/Logs/LisaSpeed-rebuild.log"
PHASE="${1:-full}"

export PATH="/Users/ldy/flutter/bin:$HOME/.pub-cache/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export GIT_SSL_NO_VERIFY="${GIT_SSL_NO_VERIFY:-true}"
export COCOAPODS_DISABLE_STATS=true
export CP_HOME_DIR="${CP_HOME_DIR:-$HOME/.cocoapods}"

mkdir -p "$(dirname "$LOG_FILE")"
# Keep console streaming for in-app dialog; also tee to log file
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%F %T')] $*"; }
phase() { echo "[[PHASE:$*]]"; }

do_build_core() {
  phase "core"
  if [[ "${SKIP_CORE:-0}" == "1" ]]; then
    log "SKIP_CORE=1 → 跳过 HiddifyCli 重编"
    return 0
  fi
  if [[ ! -d "$CORE_DIR" ]]; then
    echo "[[ERROR]] 未找到 core 目录：$CORE_DIR"
    exit 1
  fi
  if ! command -v go >/dev/null 2>&1; then
    echo "[[ERROR]] 未找到 go，无法编译 HiddifyCli"
    exit 1
  fi

  log "[core] 编译 HiddifyCli（macos-arm64-cli，含隧道/共存改动）"
  cd "$CORE_DIR"
  make macos-arm64-cli

  if [[ ! -x "$CLI_SRC" ]]; then
    echo "[[ERROR]] HiddifyCli 编译后仍不存在：$CLI_SRC"
    exit 1
  fi
  log "[core] HiddifyCli 就绪：$(ls -la "$CLI_SRC" | awk '{print $5,$6,$7,$8,$9}')"

  # GUI 侧 core = hiddify-core.dylib（启动超时 Stop/Start 分离、EasyConnect 共存等
  # 改动都在这里）。只编 CLI 会让这些改动进不了 .app，必须一并重编 dylib。
  # 用 macos-arm64（不带 prepare/go mod tidy）保持离线可编。
  log "[core] 编译 hiddify-core.dylib（macos-arm64）"
  make macos-arm64
  if [[ ! -f "$CORE_DIR/bin/hiddify-core-arm64.dylib" ]]; then
    echo "[[ERROR]] hiddify-core-arm64.dylib 编译后不存在"
    exit 1
  fi
  cp -f "$CORE_DIR/bin/hiddify-core-arm64.dylib" "$DYLIB_SRC"
  log "[core] hiddify-core.dylib 就绪：$(ls -la "$DYLIB_SRC" | awk '{print $5,$6,$7,$8,$9}')"
  phase "core-done"
}

do_compile() {
  phase "compile"
  log "LisaSpeed 本地全量编译开始（core + Flutter，离线依赖）"
  restore_single_build_dir

  if [[ ! -x "$FLUTTER_BIN" ]]; then
    echo "[[ERROR]] 未找到 Flutter：$FLUTTER_BIN"
    exit 1
  fi
  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "[[ERROR]] 未找到项目目录：$PROJECT_DIR"
    exit 1
  fi

  do_build_core

  cd "$PROJECT_DIR"

  log "[app 1/2] flutter pub get --offline"
  if ! "$FLUTTER_BIN" pub get --offline; then
    if [[ "${ALLOW_ONLINE_PUB:-0}" == "1" ]]; then
      log "离线缓存不完整，ALLOW_ONLINE_PUB=1 → 联网 pub get"
      "$FLUTTER_BIN" pub get
    else
      echo "[[ERROR]] 离线依赖缓存不完整。请先保持网络可用执行：cd \"$PROJECT_DIR\" && flutter pub get"
      exit 1
    fi
  else
    log "离线依赖解析成功"
  fi

  log "[app 2/2] flutter build macos --release --no-pub"
  "$FLUTTER_BIN" build macos --release --no-pub --target lib/main_prod.dart --dart-define=sentry_dsn=

  if [[ ! -d "$SRC_APP" ]]; then
    echo "[[ERROR]] 编译完成但未找到产物：$SRC_APP"
    exit 1
  fi

  # Xcode Run Script 会从 core/bin 拷贝 CLI；再强制覆盖一次，避免漏拷。
  if [[ -x "$CLI_SRC" ]]; then
    mkdir -p "$SRC_APP/Contents/MacOS"
    cp -f "$CLI_SRC" "$SRC_APP/Contents/MacOS/HiddifyCli"
    chmod +x "$SRC_APP/Contents/MacOS/HiddifyCli"
    codesign --force --sign - "$SRC_APP/Contents/MacOS/HiddifyCli" >/dev/null 2>&1 || true
    log "已写入产物内 HiddifyCli"
  else
    echo "[[ERROR]] 缺少 HiddifyCli，无法产出可用安装包"
    exit 1
  fi

  # Xcode 的 Embed Frameworks 用 mtime 判断是否重拷；bin/dylib 若比已嵌入副本旧
  # 就会被跳过，导致 GUI 侧 core 改动进不了包。这里强制覆盖，确保 dylib 一定更新。
  if [[ -f "$DYLIB_SRC" ]]; then
    mkdir -p "$SRC_APP/Contents/Frameworks"
    cp -f "$DYLIB_SRC" "$SRC_APP/Contents/Frameworks/hiddify-core.dylib"
    codesign --force --sign - "$SRC_APP/Contents/Frameworks/hiddify-core.dylib" >/dev/null 2>&1 || true
    log "已写入产物内 hiddify-core.dylib"
  else
    echo "[[ERROR]] 缺少 hiddify-core.dylib，无法产出可用安装包"
    exit 1
  fi

  log "编译成功：$SRC_APP"
  hide_build_app_from_launch_services
  phase "compile-done"
}

# Never point `build` at `build.noindex`. Clang then loads the same PCM
# via two paths (symlink vs realpath) and fails with:
#   Module 'Foundation' is defined in both .../build/... and .../build.noindex/...
# Spotlight: unregister the Release .app after compile (see hide_build_app...).
restore_single_build_dir() {
  local build="$PROJECT_DIR/build"
  local hidden="$PROJECT_DIR/build.noindex"
  if [[ -L "$build" ]]; then
    rm -f "$build"
    if [[ -d "$hidden" ]]; then
      mv "$hidden" "$build"
      log "已把 build.noindex 还原为真实 build 目录（避免 Clang 双路径模块缓存）"
    fi
  elif [[ -d "$hidden" && ! -e "$build" ]]; then
    mv "$hidden" "$build"
    log "已把 build.noindex 还原为真实 build 目录"
  elif [[ -d "$hidden" && -d "$build" ]]; then
    rm -rf "$hidden"
    log "已删除多余的 build.noindex，只保留真实 build 目录"
  fi
  if [[ -d "$build/macos/ModuleCache.noindex" ]]; then
    rm -rf "$build/macos/ModuleCache.noindex"
    log "已清理 Xcode ModuleCache"
  fi
}

hide_build_app_from_launch_services() {
  if [[ ! -d "$SRC_APP" ]]; then
    return 0
  fi
  local lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  if [[ -x "$lsregister" ]]; then
    "$lsregister" -u "$SRC_APP" >/dev/null 2>&1 || true
  fi
}

do_install() {
  phase "install"
  log "开始覆盖安装到 $DEST_APP"

  if [[ ! -d "$SRC_APP" ]]; then
    echo "[[ERROR]] 找不到编译产物，请先 compile：$SRC_APP"
    exit 1
  fi

  # HiddifyCli 隧道常以 root 常驻（PPID=1）。UI「断开」只 Stop TUN，不退出进程；
  # 普通用户 pkill 也杀不掉 root。必须先发 Exit RPC，再必要时提权强杀。
  log "请求隧道服务退出（tunnel exit）…"
  for cli in \
    "$DEST_APP/Contents/MacOS/HiddifyCli" \
    "$SRC_APP/Contents/MacOS/HiddifyCli" \
    "$CLI_SRC"
  do
    if [[ -x "$cli" ]]; then
      "$cli" tunnel exit >/dev/null 2>&1 || true
      break
    fi
  done
  sleep 1

  killall LisaSpeed 2>/dev/null || true
  killall HiddifyTunnelService 2>/dev/null || true
  pkill -f '/Applications/LisaSpeed.app/Contents/MacOS/HiddifyCli' 2>/dev/null || true
  pkill -f 'HiddifyCli tunnel' 2>/dev/null || true
  sleep 1

  if pgrep -f 'HiddifyCli tunnel' >/dev/null 2>&1 || pgrep -x HiddifyCli >/dev/null 2>&1; then
    log "仍有 root 隧道残留，请求管理员权限强杀…"
    osascript <<'EOF' >/dev/null 2>&1 || true
do shell script "pkill -9 -f 'HiddifyCli tunnel' 2>/dev/null || true; pkill -9 -f '/Applications/LisaSpeed.app/Contents/MacOS/HiddifyCli' 2>/dev/null || true; killall -9 HiddifyTunnelService 2>/dev/null || true; killall -9 HiddifyCli 2>/dev/null || true" with administrator privileges
EOF
    sleep 1
  fi

  if pgrep -f 'HiddifyCli tunnel' >/dev/null 2>&1; then
    echo "[[ERROR]] 无法结束旧 HiddifyCli（多为 root 权限）。请手动执行：sudo pkill -9 -f 'HiddifyCli tunnel' 后再安装。"
    exit 1
  fi

  rm -rf "$DEST_APP"
  ditto "$SRC_APP" "$DEST_APP"

  if [[ -f "$CLI_SRC" ]]; then
    cp -f "$CLI_SRC" "$DEST_APP/Contents/MacOS/HiddifyCli"
    chmod +x "$DEST_APP/Contents/MacOS/HiddifyCli"
    codesign --force --sign - "$DEST_APP/Contents/MacOS/HiddifyCli" >/dev/null 2>&1 || true
  fi

  if [[ -f "$DYLIB_SRC" ]]; then
    mkdir -p "$DEST_APP/Contents/Frameworks"
    cp -f "$DYLIB_SRC" "$DEST_APP/Contents/Frameworks/hiddify-core.dylib"
    codesign --force --sign - "$DEST_APP/Contents/Frameworks/hiddify-core.dylib" >/dev/null 2>&1 || true
  fi

  xattr -cr "$DEST_APP" 2>/dev/null || true
  codesign --force --deep --sign - "$DEST_APP" >/dev/null 2>&1 || true

  log "安装完成，正在打开应用"
  phase "install-done"
  open -a "$DEST_APP"
}

case "$PHASE" in
  compile)
    do_compile
    echo "[[DONE:compile]]"
    ;;
  install)
    # Small delay so the UI process can detach cleanly
    sleep 1
    do_install
    echo "[[DONE:install]]"
    ;;
  core)
    do_build_core
    echo "[[DONE:core]]"
    ;;
  full|"")
    echo "========================================"
    log "LisaSpeed 重新编译安装开始（交互式，含 core）"
    echo "日志: $LOG_FILE"
    echo "========================================"
    do_compile

    if pgrep -x LisaSpeed >/dev/null 2>&1; then
      CHOICE=$(osascript <<'EOF'
try
  display dialog "编译已完成（含 HiddifyCli/隧道）。\n继续将退出正在运行的 LisaSpeed，并覆盖安装到 /Applications。\n\n建议先在应用内断开连接。" buttons {"取消", "安装"} default button "安装" with icon caution with title "LisaSpeed 安装确认"
  return "continue"
on error
  return "cancel"
end try
EOF
)
      if [[ "$CHOICE" != "continue" ]]; then
        log "用户取消安装；编译产物仍在：$SRC_APP"
        osascript -e 'display dialog "已取消安装。\n编译产物仍保留在工程 build 目录。" buttons {"好"} default button 1 with title "LisaSpeed"' || true
        exit 0
      fi
    fi

    do_install

    LAUNCH=$(osascript <<'EOF'
try
  display dialog "LisaSpeed 已重新编译并安装到 /Applications。\n是否现在打开？" buttons {"稍后打开", "打开"} default button "打开" with title "LisaSpeed 安装完成"
  return "open"
on error
  return "later"
end try
EOF
)
    if [[ "$LAUNCH" == "open" ]]; then
      open -a "$DEST_APP"
    fi
    echo "[[DONE:full]]"
    ;;
  *)
    echo "用法: $0 [full|compile|install|core]"
    exit 2
    ;;
esac

exit 0
