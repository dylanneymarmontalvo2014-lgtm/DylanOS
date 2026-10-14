import { useState, useEffect } from "react";
import { MonitorIcon, CpuIcon, MemoryIcon, StorageIcon, GpuIcon, GlobeIcon, ChevronDownIcon, ExternalLinkIcon } from "@/components/Icons";
import { mockSystemInfo } from "@/data/mockSystemInfo";
import { languages } from "@/data/mockLanguages";
import { useInstaller } from "@/state/installerState";

export default function SystemInfo() {
  const { state, dispatch } = useInstaller();
  const [langOpen, setLangOpen] = useState(false);
  const [sysInfo, setSysInfo] = useState(mockSystemInfo);
  const [langList, setLangList] = useState(languages);

  useEffect(() => {
    fetch("/api/system-info")
      .then(r => r.json())
      .then(data => {
        if (data && data.cpu) {
          setSysInfo({
            device: data.device || mockSystemInfo.device,
            cpu: data.cpu || mockSystemInfo.cpu,
            ram: data.ram || mockSystemInfo.ram,
            storage: data.storage || mockSystemInfo.storage,
            gpu: data.gpu || mockSystemInfo.gpu,
          });
        }
      })
      .catch(() => {});
    fetch("/api/locales")
      .then(r => r.json())
      .then(data => { if (Array.isArray(data) && data.length) setLangList(data); })
      .catch(() => {});
  }, []);

  const hwItems = [
    { icon: <MonitorIcon size={15} color="#9ca3af" />, label: "Dispositivo", value: sysInfo.device },
    { icon: <CpuIcon size={15} color="#9ca3af" />, label: "Procesador", value: sysInfo.cpu },
    { icon: <MemoryIcon size={15} color="#9ca3af" />, label: "Memoria RAM", value: sysInfo.ram },
    { icon: <StorageIcon size={15} color="#9ca3af" />, label: "Almacenamiento", value: sysInfo.storage },
    { icon: <GpuIcon size={15} color="#9ca3af" />, label: "Gráficos", value: sysInfo.gpu },
  ];

  return (
    <div
      className="flex flex-col h-full relative overflow-hidden"
      style={{
        width: 300,
        minWidth: 300,
        background: "linear-gradient(180deg, #0a0a0a 0%, #0a0000 100%)",
        borderLeft: "1px solid rgba(255,255,255,0.06)",
      }}
    >
      {/* Subtle red glow */}
      <div
        className="absolute bottom-20 right-0 pointer-events-none"
        style={{
          width: 200,
          height: 200,
          background: "radial-gradient(circle, rgba(180,0,0,0.1) 0%, transparent 70%)",
        }}
      />

      <div className="flex-1 overflow-y-auto p-6">
        {/* System Summary */}
        <div className="mb-6">
          <h3 className="text-sm font-semibold text-white mb-4">Resumen del sistema</h3>
          <div className="space-y-3">
            {hwItems.map((item, i) => (
              <div key={i} className="flex items-start gap-3">
                <div className="mt-0.5 shrink-0">{item.icon}</div>
                <div>
                  <div className="text-xs" style={{ color: "var(--text-muted)" }}>
                    {item.label}
                  </div>
                  <div className="text-sm text-white font-medium leading-tight mt-0.5">
                    {item.value}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Divider */}
        <div style={{ height: 1, background: "rgba(255,255,255,0.06)", marginBottom: 24 }} />

        {/* What is DylanOS */}
        <div className="mb-6">
          <h3 className="text-sm font-semibold text-white mb-2">¿Qué es DylanOS?</h3>
          <p className="text-xs leading-relaxed" style={{ color: "var(--text-secondary)" }}>
            DylanOS es un sistema operativo moderno, seguro y personalizable, diseñado para ofrecer
            una experiencia fluida y productiva. Basado en tecnología de código abierto.
          </p>
          <button
            className="flex items-center gap-1.5 mt-3 text-xs font-medium transition-colors duration-150"
            style={{ color: "#dc2626" }}
            onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.color = "#ef4444")}
            onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.color = "#dc2626")}
          >
            Conocer más en dylanos.com
            <ExternalLinkIcon size={12} color="currentColor" />
          </button>
        </div>
      </div>

      {/* Language selector at bottom */}
      <div
        className="p-4 relative"
        style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}
      >
        <button
          onClick={() => setLangOpen(o => !o)}
          className="w-full flex items-center gap-2.5 px-3 py-2.5 rounded-lg transition-colors duration-150"
          style={{
            background: "rgba(255,255,255,0.04)",
            border: "1px solid rgba(255,255,255,0.08)",
          }}
          onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.07)")}
          onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.04)")}
        >
          <GlobeIcon size={15} color="#9ca3af" />
          <span className="flex-1 text-sm text-left text-white truncate">{state.languageName}</span>
          <ChevronDownIcon
            size={14}
            color="#9ca3af"
            className={`transition-transform duration-150 ${langOpen ? "rotate-180" : ""}`}
          />
        </button>

        {langOpen && (
          <div
            className="absolute bottom-full left-4 right-4 mb-1 rounded-lg overflow-hidden z-50"
            style={{
              background: "#1a1a1a",
              border: "1px solid rgba(255,255,255,0.1)",
              maxHeight: 220,
              overflowY: "auto",
              boxShadow: "0 -8px 24px rgba(0,0,0,0.5)",
            }}
          >
            {langList.map(lang => (
              <button
                key={lang.code}
                onClick={() => {
                  dispatch({ type: "SET_LANGUAGE", code: lang.code, name: lang.name });
                  setLangOpen(false);
                }}
                className="w-full text-left px-4 py-2.5 text-sm transition-colors duration-100"
                style={{
                  background: state.language === lang.code ? "rgba(220,38,38,0.15)" : "transparent",
                  color: state.language === lang.code ? "#ef4444" : "#d1d5db",
                }}
                onMouseEnter={e => {
                  if (state.language !== lang.code)
                    (e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.05)";
                }}
                onMouseLeave={e => {
                  (e.currentTarget as HTMLButtonElement).style.background =
                    state.language === lang.code ? "rgba(220,38,38,0.15)" : "transparent";
                }}
              >
                {lang.name}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
