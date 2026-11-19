import { useEffect, useState } from "react";
import { XIcon } from "@/components/Icons";
import {
  FS_LABELS,
  GIB,
  ROLE_LABELS,
  ROLE_MINIMUMS,
  formatSize,
  fsForRole,
  type PartitionFs,
  type PartitionRole,
  type PlanPartition,
} from "@/state/planState";

interface PartitionDialogProps {
  // Partición a editar, o null para crear una nueva.
  partition: PlanPartition | null;
  diskBytes: number;
  plan: PlanPartition[];
  // Sistemas de archivos que este medio puede crear de verdad (mkfs presente).
  availableFilesystems: string[];
  onSave: (part: Omit<PlanPartition, "id">) => void;
  onClose: () => void;
}

const ROLE_ORDER: PartitionRole[] = ["root", "efi", "home", "swap", "data"];

// Una partición ya usada como raíz no puede repetirse: el backend rechaza un
// plan con dos raíces y es mejor no dejar ni siquiera escribirlo.
function availableRoles(plan: PlanPartition[], current: PlanPartition | null): PartitionRole[] {
  const used = new Set(plan.filter(p => p.id !== current?.id).map(p => p.role));
  return ROLE_ORDER.filter(role => {
    if (used.has(role)) return false;
    // Los roles únicos son raíz, EFI, /home y swap.
    return true;
  });
}

export default function PartitionDialog({
  partition,
  diskBytes,
  plan,
  availableFilesystems,
  onSave,
  onClose,
}: PartitionDialogProps) {
  const others = plan.filter(p => p.id !== partition?.id);
  const remainingBytes =
    diskBytes - others.reduce((sum, p) => sum + p.sizeBytes, 0) - 1024 ** 2;

  const [role, setRole] = useState<PartitionRole>(partition?.role ?? "root");
  const [fs, setFs] = useState<PartitionFs>(partition?.fs ?? "ext4");
  const [sizeGB, setSizeGB] = useState(() =>
    partition ? String(Math.round((partition.sizeBytes / GIB) * 10) / 10) : "40",
  );
  const [label, setLabel] = useState(partition?.label ?? "DylanOS");
  const [error, setError] = useState("");

  // Una partición EFI o swap impone su sistema de archivos; al cambiar de rol
  // se ajusta en vez de dejar una combinación que el backend rechazará.
  useEffect(() => {
    setFs(current => fsForRole(role, current));
    setLabel(current => current || ROLE_LABELS[role]);
  }, [role]);

  const roles = availableRoles(plan, partition);
  // Solo se ofrecen los sistemas de archivos cuyo mkfs existe en el medio: un
  // plan con un fs no disponible fallaría al aplicarse.
  const selectableFs: PartitionFs[] =
    role === "swap"
      ? (["swap"] as PartitionFs[])
      : (["ext4", "vfat"] as PartitionFs[]).filter(value => availableFilesystems.includes(value));
  const parsedGB = Number(sizeGB.replace(",", "."));
  const sizeBytes = Number.isFinite(parsedGB) ? Math.round(parsedGB * GIB) : 0;
  const minimum = ROLE_MINIMUMS[role];

  const submit = () => {
    if (!Number.isFinite(parsedGB) || parsedGB <= 0) {
      setError("Introduce un tamaño válido en GB.");
      return;
    }
    if (sizeBytes < minimum) {
      setError(`La partición ${ROLE_LABELS[role]} necesita al menos ${formatSize(minimum)}.`);
      return;
    }
    if (remainingBytes > 0 && sizeBytes > remainingBytes) {
      setError(
        `Solo quedan ${formatSize(remainingBytes)} libres en el disco. Reduce el tamaño.`,
      );
      return;
    }
    onSave({ role, fs: fsForRole(role, fs), sizeBytes, label: label.trim() });
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      style={{ background: "rgba(0,0,0,0.7)", backdropFilter: "blur(4px)" }}
      role="dialog"
      aria-modal="true"
      aria-labelledby="partition-dialog-title"
    >
      <div
        className="relative rounded-xl p-6 w-full max-w-md"
        style={{
          background: "#111",
          border: "1px solid rgba(255,255,255,0.1)",
          boxShadow: "0 24px 64px rgba(0,0,0,0.6)",
        }}
      >
        <button
          onClick={onClose}
          aria-label="Cerrar"
          className="absolute top-4 right-4 p-1 rounded-lg transition-colors"
          style={{ color: "#6b7280" }}
          onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.color = "#d1d5db")}
          onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.color = "#6b7280")}
        >
          <XIcon size={16} />
        </button>

        <h2 id="partition-dialog-title" className="text-white font-semibold text-lg mb-1">
          {partition ? "Editar partición" : "Nueva partición"}
        </h2>
        <p className="text-xs mb-5" style={{ color: "#9ca3af" }}>
          Espacio disponible en el disco:{" "}
          <span style={{ color: "#DC143C" }} className="font-semibold">
            {formatSize(Math.max(0, remainingBytes))}
          </span>
        </p>

        <div className="space-y-4">
          <div>
            <label className="text-xs font-medium mb-1.5 block" style={{ color: "#9ca3af" }}>
              Función
            </label>
            <select
              value={role}
              onChange={e => setRole(e.target.value as PartitionRole)}
              className="w-full px-3 py-2 rounded-lg text-sm text-white"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            >
              {(roles.length ? roles : [role]).map(value => (
                <option key={value} value={value} style={{ background: "#1a1a1a" }}>
                  {ROLE_LABELS[value]}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="text-xs font-medium mb-1.5 block" style={{ color: "#9ca3af" }}>
              Sistema de archivos
            </label>
            <select
              value={fs}
              onChange={e => setFs(e.target.value as PartitionFs)}
              disabled={role === "efi" || role === "swap"}
              className="w-full px-3 py-2 rounded-lg text-sm text-white disabled:opacity-60"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            >
              {(selectableFs.length ? selectableFs : [fs]).map(value => (
                <option key={value} value={value} style={{ background: "#1a1a1a" }}>
                  {FS_LABELS[value]}
                </option>
              ))}
            </select>
            {(role === "efi" || role === "swap") && (
              <p className="text-xs mt-1" style={{ color: "#6b7280" }}>
                {role === "efi"
                  ? "La partición de arranque EFI debe ser FAT32."
                  : "La partición de intercambio usa swap."}
              </p>
            )}
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium mb-1.5 block" style={{ color: "#9ca3af" }}>
                Tamaño (GB)
              </label>
              <input
                type="number"
                min={1}
                step="0.5"
                value={sizeGB}
                onChange={e => setSizeGB(e.target.value)}
                className="w-full px-3 py-2 rounded-lg text-sm text-white"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
              />
              <p className="text-xs mt-1" style={{ color: "#6b7280" }}>
                Mínimo {formatSize(minimum)}
              </p>
            </div>
            <div>
              <label className="text-xs font-medium mb-1.5 block" style={{ color: "#9ca3af" }}>
                Etiqueta
              </label>
              <input
                type="text"
                maxLength={16}
                value={label}
                onChange={e => setLabel(e.target.value)}
                className="w-full px-3 py-2 rounded-lg text-sm text-white"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
              />
            </div>
          </div>

          {error && (
            <div
              role="alert"
              className="rounded-lg px-3 py-2 text-xs"
              style={{ background: "rgba(220,20,60,0.08)", border: "1px solid rgba(220,20,60,0.3)", color: "#DC143C" }}
            >
              {error}
            </div>
          )}
        </div>

        <div className="flex gap-3 mt-6">
          <button
            onClick={onClose}
            className="flex-1 py-2.5 rounded-lg text-sm font-medium transition-all"
            style={{
              background: "rgba(255,255,255,0.06)",
              border: "1px solid rgba(255,255,255,0.1)",
              color: "#d1d5db",
            }}
            onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.1)")}
            onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.06)")}
          >
            Cancelar
          </button>
          <button
            onClick={submit}
            className="flex-1 py-2.5 rounded-lg text-sm font-semibold transition-all"
            style={{ background: "#DC143C", color: "#fff" }}
            onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = "#FF2A54")}
            onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = "#DC143C")}
          >
            {partition ? "Guardar cambios" : "Añadir partición"}
          </button>
        </div>
      </div>
    </div>
  );
}
