#!/usr/bin/env bash
# 仅供本地试用（不进 PR）：构建 PR2 预览版，并生成一个数据隔离的启动脚本。
# 在 Mac 上、仓库根目录执行：bash tools/pr2-preview/build.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(dirname "$REPO")"
PREVIEW="$WORK/pr2-preview"
LAUNCHER="$HOME/claude-chapter-output/启动PR2预览版.command"
export PATH="$HOME/.cargo/bin:$PATH"

cd "$REPO"
command -v pnpm >/dev/null || npm i -g pnpm
pnpm install --frozen-lockfile
# 换一个 identifier：不和已安装的 CC Switch 抢单实例，也不共用它在 Application Support 下的存储
pnpm tauri build --debug --no-bundle --config '{"identifier":"com.ccswitch.chapterpreview","productName":"CC Switch PR2 Preview"}'

mkdir -p "$PREVIEW/home"
BIN="$(ls -t src-tauri/target/debug/cc-switch src-tauri/target/debug/"CC Switch PR2 Preview" 2>/dev/null | head -1)"
[ -n "$BIN" ] || { echo "binary not found"; ls src-tauri/target/debug | head -30; exit 1; }
cp "$BIN" "$PREVIEW/cc-switch-pr2-preview"

mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" <<LAUNCH
#!/bin/bash
# CC Switch PR2 预览版（数据隔离）：
# - 它把 "$PREVIEW/home" 当作用户目录，自己的数据库和设置都写在那里，不碰 ~/.cc-switch
# - 每次启动把 ~/.claude/projects 克隆一份进去（APFS 克隆，不占额外空间），只读用
# - 你在 Claude desktop 里 pin 的章节从真实位置只读读取
ISO="$PREVIEW/home"
mkdir -p "\$ISO/.claude"
rm -rf "\$ISO/.claude/projects"
cp -Rc "\$HOME/.claude/projects" "\$ISO/.claude/projects"
CC_SWITCH_TEST_HOME="\$ISO" exec "$PREVIEW/cc-switch-pr2-preview"
LAUNCH
chmod +x "$LAUNCHER"
echo "launcher: $LAUNCHER"
