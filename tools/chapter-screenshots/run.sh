#!/usr/bin/env bash
# 仅供本地截图用（不进 PR）。在 Mac 上、仓库根目录执行：bash tools/chapter-screenshots/run.sh
# 只读 ~/.claude 和 Claude desktop 的 Local Storage；产物只写到仓库内 src/__data（已忽略）
# 和 ~/claude-chapter-output/screenshots。
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(dirname "$REPO")"
MAIN="$WORK/cc-switch-main"
TOOLS="$WORK/shot-tools"
OUT="$HOME/claude-chapter-output/screenshots"
PROJECTS="$HOME/.claude/projects"
HL="$PROJECTS/-Users-leeco-Documents-work-gluon-gluon-pro-app/20a0776e-8666-499a-bb16-87497bf1cd3d.jsonl"

cd "$REPO"
[ -f "$HL" ] || { echo "missing $HL"; exit 1; }

# PR1 的对比需要一个含模型章节（mark_chapter）的会话：在同一项目的会话里挑调用数 >= 3 且最小的
SAMPLE="$(node -e '
const fs=require("fs"),path=require("path");const root=process.argv[1];let best=null;
for(const d of fs.readdirSync(root)){ if(!d.includes("gluon")) continue; const dir=path.join(root,d);
  let files=[]; try{files=fs.readdirSync(dir)}catch{continue}
  for(const f of files){ if(!f.endsWith(".jsonl")) continue; const p=path.join(dir,f); const st=fs.statSync(p);
    if(st.size>40*1024*1024) continue; const n=(fs.readFileSync(p,"utf8").match(/"name":"mcp__ccd_session__mark_chapter"/g)||[]).length;
    if(n>=3 && (!best||st.size<best.size)) best={p,size:st.size,n}; } }
if(best) console.log(best.p);' "$PROJECTS")"
echo "sample session for PR1: ${SAMPLE:-none}"

mkdir -p dist src/__data/hyperliquid src/__data/sample
( cd src-tauri
  CHAPTER_DUMP_SOURCE="$HL" CHAPTER_DUMP_OUT="$REPO/src/__data/hyperliquid" cargo test --lib screenshot_dump -- --ignored --nocapture
  if [ -n "$SAMPLE" ]; then
    CHAPTER_DUMP_SOURCE="$SAMPLE" CHAPTER_DUMP_OUT="$REPO/src/__data/sample" cargo test --lib screenshot_dump -- --ignored --nocapture
  fi )
echo '{"title":"Hyperliquid 集成方案调研","projectDir":"gluon-pro-app"}' > src/__data/hyperliquid/info.json
echo '{"title":"含模型章节的会话","projectDir":"gluon-pro-app"}' > src/__data/sample/info.json

command -v pnpm >/dev/null || npm i -g pnpm
[ -d node_modules ] && [ node_modules -nt pnpm-lock.yaml ] || pnpm install --frozen-lockfile

# main 分支的工作区：改动前的真实渲染
git fetch -q https://github.com/farion1231/cc-switch.git main
[ -d "$MAIN" ] || git worktree add -f --detach "$MAIN" FETCH_HEAD
( cd "$MAIN" && git checkout -q --detach FETCH_HEAD 2>/dev/null || true
  [ -d node_modules ] || pnpm install --frozen-lockfile
  cp "$REPO/src/__harness.html" "$REPO/src/__harness.tsx" src/
  rm -rf src/__data && ln -s "$REPO/src/__data" src/__data )

mkdir -p "$TOOLS" && ( cd "$TOOLS" && [ -d node_modules/playwright-core ] || npm i --no-audit --no-fund playwright-core )

( cd "$REPO" && pnpm exec vite --port 3111 --strictPort >"$TOOLS/vite-after.log" 2>&1 ) & A=$!
( cd "$MAIN" && pnpm exec vite --port 3112 --strictPort >"$TOOLS/vite-before.log" 2>&1 ) & B=$!
trap 'kill $A $B 2>/dev/null; pkill -f "vite --port 311[12]" 2>/dev/null || true' EXIT
sleep 10

export NODE_PATH="$TOOLS/node_modules"
rm -rf "$OUT" && mkdir -p "$OUT"
node tools/chapter-screenshots/shot.cjs "$OUT/hyperliquid" hyperliquid 3111 3112 7
[ -z "$SAMPLE" ] || node tools/chapter-screenshots/shot.cjs "$OUT/pr1-sample" sample 3111 3112 4
rm -f "$MAIN/src/__harness.html" "$MAIN/src/__harness.tsx" "$MAIN/src/__data"
ls -R "$OUT"
