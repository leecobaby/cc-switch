// 仅供本地截图用（不进 PR）：用导出的真实会话数据挂载阅读页。
// ?data=<src/__data 下的子目录>&mode=after|before&expand=1
// before = 不返回桌面端章节，并把 mark_chapter 调用还原成 main 分支解析出的样子。
import ReactDOM from "react-dom/client";
import "./index.css";
import "./i18n";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { TooltipProvider } from "@/components/ui/tooltip";
import { SessionReader } from "@/components/sessions/reader/SessionReader";

const params = new URLSearchParams(location.search);
const data = params.get("data") ?? "session";
const before = params.get("mode") === "before";
if (params.get("expand"))
  localStorage.setItem("cc-switch.sessionReader.expandTimelines", "1");
else localStorage.removeItem("cc-switch.sessionReader.expandTimelines");

const load = async (name: string) =>
  (await fetch(`/__data/${data}/${name}.json`)).json();

(async () => {
  const [messages, chapters, info] = await Promise.all([
    load("messages"),
    load("chapters"),
    load("info"),
  ]);
  if (before) {
    for (const message of messages) {
      for (const block of message.blocks ?? []) {
        if (
          block.type === "tool_call" &&
          typeof block.rawName === "string" &&
          block.rawName.endsWith("__mark_chapter")
        ) {
          block.detail = block.title;
          block.title = `${block.server ?? "ccd_session"}.mark_chapter`;
        }
      }
    }
  }
  (window as any).__TAURI_INTERNALS__ = {
    invoke: async (cmd: string) =>
      cmd === "get_session_desktop_chapters" ? (before ? [] : chapters) : null,
    transformCallback: () => 0,
    metadata: {
      currentWindow: { label: "main" },
      currentWebview: { label: "main" },
    },
  };
  const noop = () => {};
  const Reader = SessionReader as any;
  ReactDOM.createRoot(document.getElementById("root")!).render(
    <QueryClientProvider client={new QueryClient()}>
      <TooltipProvider>
        <Reader
          session={{
            providerId: "claude",
            sessionId: "session",
            title: info.title,
            projectDir: info.projectDir,
            createdAt: messages[0]?.ts,
            lastActiveAt: messages[messages.length - 1]?.ts,
            sourcePath: "/mock/session.jsonl",
            resumeCommand: "claude --resume session",
          }}
          appName="Claude Code"
          transcript={{
            header: null,
            messages,
            isStreaming: false,
            progress: { loaded: messages.length, total: messages.length },
            isLoading: false,
            isError: false,
            error: null,
            refetch: async () => undefined,
          }}
          listQuery=""
          launchTerminal={null}
          hasPrev={false}
          hasNext={false}
          onPrev={noop}
          onNext={noop}
          onBack={noop}
          onLaunch={noop}
          onCopy={noop}
          onOpenTerminalSettings={noop}
          onReload={noop}
          onDelete={noop}
        />
      </TooltipProvider>
    </QueryClientProvider>,
  );
  (window as any).__ready = true;
})();
