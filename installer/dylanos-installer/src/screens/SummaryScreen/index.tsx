import { useState, useEffect } from "react";
import BottomBar from "@/components/BottomBar";
import { GlobeIcon, KeyboardIcon, HardDriveIcon, UserIcon, MonitorIcon, CpuIcon, MemoryIcon, StorageIcon, GpuIcon, EditIcon } from "@/components/Icons";
import { mockSystemInfo } from "@/data/mockSystemInfo";
import { useInstaller, type InstallerStep } from "@/state/installerState";
import StatusNotice from "@/components/StatusNotice";

interface SummaryScreenProps {
  onCancel: () => void;
}

export default function SummaryScreen({ onCancel }: SummaryScreenProps) {
  const { state, dispatch } = useInstaller();
  const isComplete = Boolean(state.language && !state.languageLoadError && !state.keyboardInvalid && state.partitioning.disk && state.partitionError === "none" && state.user.valid);
  const [sysInfo, setSysInfo] = useState(mockSystemInfo);
  const [diskSummary, setDiskSummary] = useState(state.partitioning.disk);

  useEffect(() => {
    fetch("/api/system-info")
      .then(r => r.json())
      .then(data => { if (data && data.cpu) setSysInfo(data); })
      .catch(() => {});
    fetch("/api/disks")
      .then(r => r.json())
      .then(disks => {
        const match = Array.isArray(disks) ? disks.find((d: { device: string }) => d.device === state.partitioning.disk) : null;
        if (match) setDiskSummary(`${match.device} – ${match.size} (${match.model})`);
      })
      .catch(() => {});
  }, [state.partitioning.disk]);

  const configItems = [
    {
      icon: <GlobeIcon size={16} color="#9ca3af" />,
      label: "Idioma",
      value: state.languageName,
      editStep: 1 as InstallerStep,
    },
    {
      icon: <KeyboardIcon size={16} color="#9ca3af" />,
      label: "Teclado",
      value: `${state.keyboard.layout} — ${state.keyboard.variant}`,
      editStep: 2 as InstallerStep,
    },
    {
      icon: <HardDriveIcon size={16} color="#9ca3af" />,
      label: "Disco",
      value: diskSummary,
      editStep: 3 as InstallerStep,
    },
    {
      icon: <HardDriveIcon size={16} color="#9ca3af" />,
      label: "Particionado",
      value: state.partitioning.mode === "auto" ? "Instalación automática" : "Particionado manual",
      editStep: 3 as InstallerStep,
    },
    {
      icon: <UserIcon size={16} color="#9ca3af" />,
      label: "Usuario",
      value: state.user.username || "—",
      editStep: 4 as InstallerStep,
    },
    {
      icon: <MonitorIcon size={16} color="#9ca3af" />,
      label: "Nombre del equipo",
      value: state.user.hostname || "DylanOS-PC",
      editStep: 4 as InstallerStep,
    },
  ];

  const hwItems = [
    { icon: <MonitorIcon size={15} color="#9ca3af" />, label: "Dispositivo", value: sysInfo.device },
    { icon: <CpuIcon size={15} color="#9ca3af" />, label: "Procesador", value: sysInfo.cpu },
    { icon: <MemoryIcon size={15} color="#9ca3af" />, label: "RAM", value: sysInfo.ram },
    { icon: <StorageIcon size={15} color="#9ca3af" />, label: "Almacenamiento", value: sysInfo.storage },
    { icon: <GpuIcon size={15} color="#9ca3af" />, label: "Gráficos", value: sysInfo.gpu },
  ];

  return (
    <div className="flex flex-col h-full screen-enter">
      <div className="flex-1 overflow-y-auto px-8 pt-8 pb-4">
        {/* Header */}
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-white">Resumen</h1>
          <p className="text-sm mt-1" style={{ color: "#9ca3af" }}>
            Revisa tu configuración antes de iniciar la instalación.
          </p>
        </div>

        {!isComplete && <div className="mb-4"><StatusNotice title="Hay información pendiente.">Revisa los datos antes de comenzar la instalación.</StatusNotice></div>}

        <div className="grid grid-cols-2 gap-4">
          {/* Left: Installation config */}
          <div>
            <h3 className="text-xs font-semibold uppercase tracking-wider mb-3" style={{ color: "#6b7280" }}>
              Configuración de instalación
            </h3>
            <div
              className="rounded-xl overflow-hidden"
              style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}
            >
              {configItems.map((item, i) => (
                <div
                  key={i}
                  className="flex items-center gap-3 px-4 py-3 group transition-colors"
                  style={{ borderBottom: i < configItems.length - 1 ? "1px solid rgba(255,255,255,0.05)" : "none" }}
                  onMouseEnter={e => ((e.currentTarget as HTMLDivElement).style.background = "rgba(255,255,255,0.03)")}
                  onMouseLeave={e => ((e.currentTarget as HTMLDivElement).style.background = "transparent")}
                >
                  <div className="shrink-0">{item.icon}</div>
                  <div className="flex-1 min-w-0">
                    <div className="text-xs" style={{ color: "#6b7280" }}>{item.label}</div>
                    <div className="text-sm font-medium text-white truncate">{item.value}</div>
                  </div>
                  <button
                    onClick={() => dispatch({ type: "SET_STEP", step: item.editStep })}
                    className="opacity-0 group-hover:opacity-100 transition-opacity p-1.5 rounded-lg"
                    style={{ background: "rgba(255,255,255,0.06)", color: "#9ca3af" }}
                    onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.color = "#fff")}
                    onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.color = "#9ca3af")}
                  >
                    <EditIcon size={12} />
                  </button>
                </div>
              ))}
            </div>
          </div>

          {/* Right: Hardware info */}
          <div>
            <h3 className="text-xs font-semibold uppercase tracking-wider mb-3" style={{ color: "#6b7280" }}>
              Resumen de hardware
            </h3>
            <div
              className="rounded-xl overflow-hidden"
              style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}
            >
              {hwItems.map((item, i) => (
                <div
                  key={i}
                  className="flex items-center gap-3 px-4 py-3"
                  style={{ borderBottom: i < hwItems.length - 1 ? "1px solid rgba(255,255,255,0.05)" : "none" }}
                >
                  <div className="shrink-0">{item.icon}</div>
                  <div>
                    <div className="text-xs" style={{ color: "#6b7280" }}>{item.label}</div>
                    <div className="text-sm font-medium text-white">{item.value}</div>
                  </div>
                </div>
              ))}
            </div>

            {/* Warning card */}
            <div
              className="mt-4 rounded-xl p-4"
              style={{
                background: "rgba(220,38,38,0.06)",
                border: "1px solid rgba(220,38,38,0.2)",
              }}
            >
              <div className="text-xs font-semibold text-white mb-1">⚠ Advertencia</div>
              <p className="text-xs" style={{ color: "#9ca3af" }}>
                Al continuar, se realizarán cambios en el disco seleccionado. Esta operación no se puede deshacer.
                Asegúrate de tener copias de seguridad de tus datos importantes.
              </p>
            </div>
          </div>
        </div>
      </div>

      <BottomBar onCancel={onCancel} nextLabel="Iniciar instalación" nextDisabled={!isComplete} />
    </div>
  );
}
