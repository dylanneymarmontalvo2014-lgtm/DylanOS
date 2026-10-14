import { useState, useEffect } from "react";
import BottomBar from "@/components/BottomBar";
import { HardDriveIcon, ChevronDownIcon, PlusCircleIcon, EditIcon, TrashIcon, RefreshIcon } from "@/components/Icons";
import { mockDisks, type Disk } from "@/data/mockDiskInfo";
import { useInstaller } from "@/state/installerState";
import StatusNotice from "@/components/StatusNotice";

interface PartitioningScreenProps {
  onCancel: () => void;
}

export default function PartitioningScreen({ onCancel }: PartitioningScreenProps) {
  const { state, dispatch } = useInstaller();
  const [disks, setDisks] = useState<Disk[]>(mockDisks);
  const [selectedIdx, setSelectedIdx] = useState(0);
  const [dropdownOpen, setDropdownOpen] = useState(false);

  useEffect(() => {
    fetch("/api/disks")
      .then(r => r.json())
      .then(data => {
        if (Array.isArray(data) && data.length > 0) {
          setDisks(data);
          dispatch({ type: "SET_PARTITIONING", mode: state.partitioning.mode, disk: data[0].device });
        }
      })
      .catch(() => {});
  }, []);

  const disk = disks[selectedIdx] || disks[0] || mockDisks[0];
  const isAuto = state.partitioning.mode === "auto";
  const totalGB = disk.sizeGB || 512;
  const partitionMessages = {
    "no-disk": ["Selecciona un disco para continuar.", "Elige un dispositivo de almacenamiento para instalar DylanOS."],
    "insufficient-space": ["No hay espacio suficiente.", "El disco seleccionado no tiene espacio suficiente para instalar DylanOS."],
    invalid: ["Configuración de particiones inválida.", "Revisa los puntos de montaje y los cambios propuestos."],
    detection: ["No se pudieron detectar los dispositivos de almacenamiento.", "Vuelve a detectar los dispositivos antes de continuar."],
  } as const;
  const partitionNotice = state.partitionError === "none" ? null : partitionMessages[state.partitionError];

  return (
    <div className="flex flex-col h-full screen-enter">
      <div className="flex-1 overflow-y-auto px-8 pt-8 pb-4">
        {/* Header */}
        <div className="flex items-start justify-between mb-5">
          <div>
            <h1 className="text-2xl font-bold text-white">Particionado</h1>
            <p className="text-sm mt-1" style={{ color: "#9ca3af" }}>
              Selecciona cómo deseas particionar tu disco.
              <br />
              Puedes elegir una opción automática o crear particiones manualmente.
            </p>
          </div>
          <div
            className="w-14 h-14 rounded-xl flex items-center justify-center"
            style={{ background: "rgba(220,38,38,0.1)", border: "1px solid rgba(220,38,38,0.2)" }}
          >
            <HardDriveIcon size={28} color="#dc2626" />
          </div>
        </div>

        {partitionNotice && <div className="mb-4"><StatusNotice title={partitionNotice[0]} action={state.partitionError === "detection" ? <button onClick={() => dispatch({ type: "SET_PARTITION_ERROR", error: "none" })} className="text-xs font-medium" style={{ color: "#fff" }}>Reintentar</button> : undefined}>{partitionNotice[1]}</StatusNotice></div>}

        {/* Mode selector */}
        <div className="grid grid-cols-2 gap-3 mb-5">
          {[
            { mode: "auto" as const, title: "Borrado e instalación", desc: "Elimina todo en el disco y configura DylanOS automáticamente." },
            { mode: "manual" as const, title: "Particionado manual", desc: "Crea, elimina o redimensiona particiones tú mismo." },
          ].map(opt => (
            <button
              key={opt.mode}
              onClick={() => dispatch({ type: "SET_PARTITIONING", mode: opt.mode, disk: state.partitioning.disk })}
              className="flex items-start gap-3 p-4 rounded-xl text-left transition-all duration-150"
              style={{
                background: state.partitioning.mode === opt.mode ? "rgba(220,38,38,0.08)" : "rgba(255,255,255,0.03)",
                border: state.partitioning.mode === opt.mode ? "1px solid rgba(220,38,38,0.35)" : "1px solid rgba(255,255,255,0.07)",
              }}
            >
              <div
                className="w-4 h-4 rounded-full mt-0.5 shrink-0 flex items-center justify-center"
                style={{
                  border: state.partitioning.mode === opt.mode ? "5px solid #dc2626" : "2px solid rgba(255,255,255,0.25)",
                  background: state.partitioning.mode === opt.mode ? "#dc2626" : "transparent",
                }}
              />
              <div>
                <div className="text-sm font-semibold text-white">{opt.title}</div>
                <div className="text-xs mt-0.5" style={{ color: "#9ca3af" }}>{opt.desc}</div>
              </div>
            </button>
          ))}
        </div>

        {/* Device selector */}
        <div className="mb-4 relative">
          <label className="text-xs font-medium mb-1.5 block" style={{ color: "#9ca3af" }}>Dispositivo:</label>
          <button
            type="button"
            onClick={() => setDropdownOpen(o => !o)}
            className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-left"
            style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
          >
            <div className="flex items-center gap-2.5">
              <HardDriveIcon size={16} color="#9ca3af" />
              <span className="text-sm text-white">
                {disk.device} – {disk.size} – {disk.model}
              </span>
            </div>
            <ChevronDownIcon size={14} color="#9ca3af" className={dropdownOpen ? "rotate-180" : ""} />
          </button>
          {dropdownOpen && disks.length > 1 && (
            <div
              className="absolute left-0 right-0 top-full mt-1 rounded-lg overflow-hidden z-20 shadow-xl"
              style={{ background: "#1a1a1a", border: "1px solid rgba(255,255,255,0.15)" }}
            >
              {disks.map((d, idx) => (
                <button
                  key={d.device}
                  type="button"
                  onClick={() => {
                    setSelectedIdx(idx);
                    dispatch({ type: "SET_PARTITIONING", mode: state.partitioning.mode, disk: d.device });
                    setDropdownOpen(false);
                  }}
                  className="w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-white/10 text-white"
                  style={{ background: idx === selectedIdx ? "rgba(220,38,38,0.2)" : "transparent" }}
                >
                  <HardDriveIcon size={14} color="#dc2626" />
                  <span>{d.device} – {d.size} – {d.model}</span>
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Disk visualization */}
        <div className="mb-4">
          <label className="text-xs font-medium mb-2 block" style={{ color: "#9ca3af" }}>Distribución actual:</label>

          <div className="flex rounded-lg overflow-hidden mb-3" style={{ height: 28 }}>
            {disk.partitions.map((p, i) => (
              <div
                key={i}
                style={{
                  width: `${(p.sizeGB / totalGB) * 100}%`,
                  background: p.color,
                  opacity: p.device === "Espacio libre" ? 0.3 : 0.85,
                }}
              />
            ))}
          </div>

          <div className="flex flex-wrap gap-4 text-xs">
            {disk.partitions.map((p, i) => (
              p.device !== "Espacio libre" ? (
                <div key={i} className="flex items-center gap-1.5">
                  <div className="w-2.5 h-2.5 rounded-sm" style={{ background: p.color }} />
                  <span className="text-white font-medium">{p.mount === "/" ? "DylanOS (/)" : p.mount === "swap" ? "Swap" : `Datos (${p.mount})`}</span>
                  <span style={{ color: "#6b7280" }}>{p.size} {p.fs}</span>
                </div>
              ) : (
                <div key={i} className="flex items-center gap-1.5">
                  <div className="w-2.5 h-2.5 rounded-sm" style={{ background: p.color }} />
                  <span className="text-white font-medium">Espacio libre</span>
                  <span style={{ color: "#6b7280" }}>{p.size}</span>
                </div>
              )
            ))}
          </div>
        </div>

        {/* Partition table actions */}
        {!isAuto && (
          <div className="mb-3">
            <div className="flex items-center gap-2 mb-3">
              <button
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
                style={{ background: "#dc2626", color: "#fff" }}
                onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = "#ef4444")}
                onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = "#dc2626")}
              >
                <PlusCircleIcon size={13} color="#fff" />
                Nueva partición
              </button>
              {["Editar", "Eliminar", "Revertir"].map(label => (
                <button
                  key={label}
                  className="px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
                  style={{
                    background: "rgba(255,255,255,0.06)",
                    border: "1px solid rgba(255,255,255,0.1)",
                    color: "#d1d5db",
                  }}
                  onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.1)")}
                  onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.06)")}
                >
                  {label}
                </button>
              ))}

              <div className="flex-1" />
              <span className="text-xs" style={{ color: "#6b7280" }}>Tabla de particiones:</span>
            </div>
          </div>
        )}

        {/* Partition table */}
        <div
          className="rounded-xl overflow-hidden"
          style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}
        >
          <div
            className="grid text-xs font-medium px-4 py-2.5"
            style={{
              gridTemplateColumns: "1.6fr 0.8fr 1fr 0.8fr 0.7fr 0.7fr 0.5fr",
              color: "#6b7280",
              borderBottom: "1px solid rgba(255,255,255,0.06)",
            }}
          >
            <span>Dispositivo</span>
            <span>Tipo</span>
            <span>Punto de montaje</span>
            <span>Sistema de archivos</span>
            <span>Tamaño</span>
            <span>Usado</span>
            <span>Flags</span>
          </div>

          {disk.partitions.map((p, i) => (
            <div
              key={i}
              className="grid text-xs px-4 py-2.5 items-center transition-colors"
              style={{
                gridTemplateColumns: "1.6fr 0.8fr 1fr 0.8fr 0.7fr 0.7fr 0.5fr",
                borderBottom: i < disk.partitions.length - 1 ? "1px solid rgba(255,255,255,0.04)" : "none",
                color: "#d1d5db",
              }}
              onMouseEnter={e => ((e.currentTarget as HTMLDivElement).style.background = "rgba(255,255,255,0.03)")}
              onMouseLeave={e => ((e.currentTarget as HTMLDivElement).style.background = "transparent")}
            >
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full shrink-0" style={{ background: p.color }} />
                <span className="font-mono text-xs">{p.device}</span>
              </div>
              <span>{p.type}</span>
              <span className="font-mono">{p.mount}</span>
              <span>{p.fs}</span>
              <span className="font-semibold">{p.size}</span>
              <span>{p.used}</span>
              <span style={{ color: "#6b7280" }}>—</span>
            </div>
          ))}
        </div>

        <div className="flex items-center justify-between mt-3 text-xs" style={{ color: "#9ca3af" }}>
          <span>Dispositivo seleccionado: <span className="text-white font-medium">{disk.device} – {disk.size}</span></span>
          <span>Espacio libre total: <span style={{ color: "#dc2626" }} className="font-semibold">204 GB</span></span>
        </div>
      </div>

      <BottomBar onCancel={onCancel} nextDisabled={state.partitionError !== "none" || !state.partitioning.disk} />
    </div>
  );
}
