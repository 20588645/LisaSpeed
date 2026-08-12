# LisaSpeed 开发约定

## macOS 应用安装与验收

正在使用的软件是本机 `/Applications/LisaSpeed.app`。

- **代理 / AI 助手默认只改源码**，不要自动退出应用、不要自动重编译并覆盖安装。
- 推荐在应用内更新：设置 → 关于 → **立即更新**（弹窗显示编译日志；安装阶段自动退出并重开）
- 亦可双击桌面脚本：
  - `重新编译安装LisaSpeed.command`（编译 + 安装到 `/Applications`）
  - `恢复LisaSpeed网络.command`（TUN/代理残留导致断网时应急恢复）
- 重编译脚本约定：
  - **全量同步**：先 `make macos-arm64-cli` 重编 `HiddifyCli`（隧道/共存等 Go 改动），再 `flutter build macos`，安装时强制覆盖 `.app` 内 CLI 并杀掉旧隧道进程
  - **编译过程中不退出**正在运行的 LisaSpeed（避免断代理导致依赖解析失败）
  - 仅在覆盖 `/Applications` 前才退出（`install` 阶段会 `killall`/`pkill` 旧 LisaSpeed 与 HiddifyCli）
  - `pub get` **强制离线**（`flutter pub get --offline`）；缺包时脚本中止并提示，不擅自联网
- `flutter build` 使用 `--no-pub`，避免构建阶段再次 Downloading packages
- 桌面快捷方式必须与 `scripts/rebuild-and-install.command` 保持同步；旧版只编 Flutter、不重编 core

- 对应仓库脚本：
  - [`scripts/rebuild-and-install.command`](scripts/rebuild-and-install.command)
  - [`scripts/fix-network.command`](scripts/fix-network.command)
  - [`scripts/fix-network.sh`](scripts/fix-network.sh)

Cursor 侧持久规则见 [`.cursor/rules/macos-app-install.mdc`](.cursor/rules/macos-app-install.mdc)（`alwaysApply: true`）。
