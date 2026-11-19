import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from "react";

export type PartitionRole = "root" | "efi" | "home" | "swap" | "data";
export type PartitionFs = "ext4" | "vfat" | "swap";

// Borrador de una partición del plan manual. Nada de esto toca el disco: el
// backend valida el plan y solo lo aplica cuando arranca la instalación real.
export interface PlanPartition {
  id: string;
  role: PartitionRole;
  fs: PartitionFs;
  sizeBytes: number;
  label: string;
}

export const GIB = 1024 ** 3;

// Mínimos alineados con validate_partition_plan en backend/server.py. Si allí
// cambian, aquí también: la interfaz avisa antes de llegar al servidor.
export const ROLE_MINIMUMS: Record<PartitionRole, number> = {
  root: 12 * GIB,
  efi: 300 * 1024 ** 2,
  home: 1 * GIB,
  swap: 64 * 1024 ** 2,
  data: 64 * 1024 ** 2,
};

export const ROLE_LABELS: Record<PartitionRole, string> = {
  root: "DylanOS (/)",
  efi: "Arranque EFI",
  home: "Datos (/home)",
  swap: "Swap",
  data: "Datos",
};

export const FS_LABELS: Record<PartitionFs, string> = {
  ext4: "ext4",
  vfat: "FAT32",
  swap: "swap",
};

// Una partición EFI y una swap tienen un sistema de archivos obligatorio; el
// resto se puede formatear en ext4 o FAT32.
export function fsForRole(role: PartitionRole, fallback: PartitionFs): PartitionFs {
  if (role === "efi") return "vfat";
  if (role === "swap") return "swap";
  return fallback === "swap" ? "ext4" : fallback;
}

export function formatSize(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 MB";
  if (bytes >= GIB) {
    const value = bytes / GIB;
    return `${value >= 100 ? Math.round(value) : value.toFixed(1)} GB`;
  }
  return `${Math.round(bytes / 1024 ** 2)} MB`;
}

// Total del plan más la guarda de 1 MiB que reserva el backend para la GPT.
const DISK_GUARD_BYTES = 1024 ** 2;

export function planTotalBytes(plan: PlanPartition[]): number {
  return plan.reduce((sum, part) => sum + part.sizeBytes, 0) + DISK_GUARD_BYTES;
}

export interface PlanProblem {
  message: string;
}

/**
 * Comprueba el plan localmente antes de preguntar al backend.
 *
 * Es la misma batería de reglas que aplica validate_partition_plan, para que el
 * usuario vea el problema al instante; el servidor sigue siendo la autoridad.
 */
export function checkPlan(plan: PlanPartition[], diskBytes: number): PlanProblem | null {
  if (plan.length === 0) {
    return { message: "Añade al menos una partición al plan manual." };
  }
  const count = (role: PartitionRole) => plan.filter(p => p.role === role).length;
  if (count("root") !== 1) {
    return { message: "El plan debe tener exactamente una partición raíz (DylanOS)." };
  }
  if (count("efi") > 1) return { message: "Solo puede haber una partición de arranque EFI." };
  if (count("swap") > 1) return { message: "Solo puede haber una partición de intercambio." };
  if (count("home") > 1) return { message: "Solo puede haber una partición /home." };

  for (const part of plan) {
    const minimum = ROLE_MINIMUMS[part.role];
    if (part.sizeBytes < minimum) {
      return { message: `La partición ${ROLE_LABELS[part.role]} necesita al menos ${formatSize(minimum)}.` };
    }
  }
  if (diskBytes > 0 && planTotalBytes(plan) > diskBytes) {
    return {
      message: `El plan ocupa ${formatSize(planTotalBytes(plan))} y el disco solo tiene ${formatSize(diskBytes)}. Reduce el tamaño de las particiones.`,
    };
  }
  return null;
}

/**
 * Reparte el disco: la raíz se lleva lo que sobra tras las demás particiones.
 *
 * Es el comportamiento que espera quien crea «una raíz y un poco de swap»: la
 * raíz no se queda con un tamaño fijo ridículo mientras el disco está vacío.
 */
export function planFromDisk(diskBytes: number): PlanPartition[] {
  const efi = 512 * 1024 ** 2;
  const swap = 4 * GIB;
  const home = 0;
  const root = Math.max(ROLE_MINIMUMS.root, diskBytes - efi - swap - home - DISK_GUARD_BYTES);
  return [
    { id: "plan-efi", role: "efi", fs: "vfat", sizeBytes: efi, label: "EFI" },
    { id: "plan-root", role: "root", fs: "ext4", sizeBytes: root, label: "DylanOS" },
    { id: "plan-swap", role: "swap", fs: "swap", sizeBytes: swap, label: "swap" },
  ];
}

interface PlanContextValue {
  plan: PlanPartition[];
  setPlan: (plan: PlanPartition[]) => void;
  addPartition: (part: Omit<PlanPartition, "id">) => void;
  updatePartition: (id: string, changes: Partial<Omit<PlanPartition, "id">>) => void;
  removePartition: (id: string) => void;
  revert: () => void;
  canRevert: boolean;
  resetForDisk: (diskBytes: number) => void;
}

const PlanContext = createContext<PlanContextValue | null>(null);

export function PlanProvider({ children }: { children: ReactNode }) {
  const [plan, setPlanState] = useState<PlanPartition[]>([]);
  // Copia del último plan confirmado: «Revertir» vuelve a ella.
  const [committed, setCommitted] = useState<PlanPartition[]>([]);

  const setPlan = useCallback((next: PlanPartition[]) => {
    setPlanState(next);
    setCommitted(next);
  }, []);

  const addPartition = useCallback((part: Omit<PlanPartition, "id">) => {
    setPlanState(current => [
      ...current,
      { ...part, id: `plan-${Date.now()}-${Math.random().toString(36).slice(2, 7)}` },
    ]);
  }, []);

  const updatePartition = useCallback((id: string, changes: Partial<Omit<PlanPartition, "id">>) => {
    setPlanState(current => current.map(part => (part.id === id ? { ...part, ...changes } : part)));
  }, []);

  const removePartition = useCallback((id: string) => {
    setPlanState(current => current.filter(part => part.id !== id));
  }, []);

  const revert = useCallback(() => setPlanState(committed), [committed]);

  const resetForDisk = useCallback((diskBytes: number) => {
    const next = diskBytes > 0 ? planFromDisk(diskBytes) : [];
    setPlanState(next);
    setCommitted(next);
  }, []);

  const value = useMemo<PlanContextValue>(
    () => ({
      plan,
      setPlan,
      addPartition,
      updatePartition,
      removePartition,
      revert,
      canRevert: JSON.stringify(plan) !== JSON.stringify(committed),
      resetForDisk,
    }),
    [plan, setPlan, addPartition, updatePartition, removePartition, revert, resetForDisk, committed],
  );

  return <PlanContext.Provider value={value}>{children}</PlanContext.Provider>;
}

export function usePlan(): PlanContextValue {
  const ctx = useContext(PlanContext);
  if (!ctx) throw new Error("usePlan debe usarse dentro de PlanProvider");
  return ctx;
}
