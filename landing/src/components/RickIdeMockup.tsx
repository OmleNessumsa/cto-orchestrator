/**
 * Pure CSS/HTML mockup of the Rick IDE desktop app.
 * Server component — no client JS, always retina-sharp, never outdated screenshots.
 * Terminal/UI strings are intentionally untranslated (they depict the app itself).
 */

function StatusDot({ color }: { color: string }) {
  return (
    <span
      className="inline-block w-1.5 h-1.5 rounded-full flex-shrink-0"
      style={{ backgroundColor: color }}
    />
  );
}

function KanbanCard({ label, tag }: { label: string; tag: string }) {
  return (
    <div className="rounded bg-white/5 border border-white/10 px-1.5 py-1">
      <p className="text-gray-300 truncate">{label}</p>
      <span className="text-[var(--portal-green)]/70">{tag}</span>
    </div>
  );
}

export default function RickIdeMockup() {
  return (
    <div className="relative max-w-4xl mx-auto">
      {/* Ambient glow behind the window */}
      <div className="absolute inset-4 rounded-3xl bg-[var(--portal-green)]/10 blur-3xl pointer-events-none" />

      <div className="relative rounded-xl overflow-hidden border border-white/10 bg-[#0d1010] shadow-[0_20px_80px_rgba(0,0,0,0.8),0_0_40px_rgba(57,255,20,0.08)] text-[10px] md:text-[11px] font-mono leading-relaxed select-none">
        {/* Title bar */}
        <div className="flex items-center gap-2 px-3 py-2 bg-[#1a1f1f] border-b border-white/5">
          <span className="w-2.5 h-2.5 rounded-full bg-[#ff5f57]" />
          <span className="w-2.5 h-2.5 rounded-full bg-[#febc2e]" />
          <span className="w-2.5 h-2.5 rounded-full bg-[#28c840]" />
          <span className="flex-1 text-center text-gray-400">
            Rick IDE — ZeasparkDashboard
          </span>
          <span className="text-[var(--portal-green)]/80">$4.20 · 312k tok</span>
        </div>

        <div className="flex">
          {/* Sidebar: sessions */}
          <div className="hidden sm:block w-36 md:w-44 border-r border-white/5 bg-[#111414] p-2 space-y-1">
            <p className="text-gray-500 uppercase tracking-wider text-[9px] mb-2">
              Sessions
            </p>
            <div className="flex items-center gap-1.5 rounded px-1.5 py-1 bg-[var(--portal-green)]/10 text-[var(--portal-green)]">
              <StatusDot color="#39ff14" />
              backend-morty
            </div>
            <div className="flex items-center gap-1.5 rounded px-1.5 py-1 text-gray-400">
              <StatusDot color="#febc2e" />
              frontend-morty
            </div>
            <div className="flex items-center gap-1.5 rounded px-1.5 py-1 text-gray-400">
              <StatusDot color="#5bcefa" />
              tester-morty
            </div>
            <div className="flex items-center gap-1.5 rounded px-1.5 py-1 text-gray-500">
              <StatusDot color="#666" />
              unity · idle
            </div>
            <p className="text-gray-500 uppercase tracking-wider text-[9px] pt-3 mb-1">
              Widgets
            </p>
            <p className="text-gray-400 px-1.5">📋 Rick Kanban</p>
            <p className="text-gray-400 px-1.5">⚡ Morty Feed</p>
            <p className="text-gray-400 px-1.5">🎯 AI Readiness 87</p>
          </div>

          {/* Main: terminal + kanban */}
          <div className="flex-1 grid md:grid-cols-5">
            {/* Terminal pane */}
            <div className="md:col-span-3 p-3 bg-[#0d1010] min-h-[220px]">
              <p>
                <span className="text-[#5bcefa]">rick@multiverse</span>
                <span className="text-gray-500">:~/zeaspark$</span>{" "}
                <span className="text-gray-200">rick sprint</span>
              </p>
              <p className="text-[var(--portal-green)] mt-1">
                *Burrrp* — deploying the Morty army...
              </p>
              <p className="text-gray-400">
                ▸ ZEAS-042 → backend-morty{" "}
                <span className="text-[var(--portal-green)]">⠿ working</span>
              </p>
              <p className="text-gray-500 pl-3">Edit src/api/auth.ts</p>
              <p className="text-gray-500 pl-3">Bash npm test — 28 passed</p>
              <p className="text-gray-400">
                ▸ ZEAS-043 → frontend-morty{" "}
                <span className="text-[#febc2e]">⠿ review</span>
              </p>
              <p className="text-gray-500 pl-3">
                &lt;handoff&gt; → security-morty
              </p>
              <p className="text-gray-400">
                ▸ counsel-of-ricks{" "}
                <span className="text-[#5bcefa]">verdict: consensus ✓</span>
              </p>
              <p className="mt-1">
                <span className="text-[#5bcefa]">rick@multiverse</span>
                <span className="text-gray-500">:~/zeaspark$</span>{" "}
                <span className="inline-block w-1.5 h-3 bg-[var(--portal-green)] align-middle animate-pulse" />
              </p>
            </div>

            {/* Mini Kanban */}
            <div className="hidden md:block md:col-span-2 border-l border-white/5 bg-[#101313] p-2">
              <p className="text-gray-500 uppercase tracking-wider text-[9px] mb-2">
                Kanban — Sprint #7
              </p>
              <div className="grid grid-cols-2 gap-1.5">
                <div className="space-y-1.5">
                  <p className="text-gray-400">In Progress</p>
                  <KanbanCard label="ZEAS-042 Auth API" tag="backend" />
                  <KanbanCard label="ZEAS-044 Push" tag="devops" />
                </div>
                <div className="space-y-1.5">
                  <p className="text-gray-400">Done</p>
                  <KanbanCard label="ZEAS-041 Schema" tag="backend" />
                  <KanbanCard label="ZEAS-040 Login UI" tag="frontend" />
                  <KanbanCard label="ZEAS-039 E2E" tag="tester" />
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Status bar */}
        <div className="flex items-center justify-between px-3 py-1.5 bg-[#1a1f1f] border-t border-white/5 text-gray-500">
          <span>
            <span className="text-[var(--portal-green)]">●</span> 3 sessions
            active · swarm mode
          </span>
          <span className="hidden sm:inline">context 41% · cache hit 92%</span>
          <span className="text-[#5bcefa]">P2P: sharing off</span>
        </div>
      </div>
    </div>
  );
}
