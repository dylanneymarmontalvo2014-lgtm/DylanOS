// DYLANOS-MOCK: Simulates the installation progress over time.
// DYLANOS-INTEGRATION: Replace with real Calamares installation event listener.

import { mockInstallationSteps } from "@/data/mockInstallation";

export const TOTAL_DURATION_MS = 18000;

export interface InstallationTick {
  progress: number;
  phase: number;
  pkg: string;
  complete: boolean;
}

/**
 * Starts a simulated installation timer that calls `onTick` periodically.
 * Returns a cleanup function that stops the simulation.
 */
export function startSimulatedInstallation(
  onTick: (tick: InstallationTick) => void,
  intervalMs = 200,
): () => void {
  const startTime = Date.now();

  const id = setInterval(() => {
    const elapsed = Date.now() - startTime;
    const progress = Math.min(100, Math.floor((elapsed / TOTAL_DURATION_MS) * 100));

    let phase = 0;
    let pkg = "";
    if (progress < 5) {
      phase = 0;
      pkg = mockInstallationSteps[0].packages[0];
    } else if (progress < 20) {
      phase = 1;
      pkg = mockInstallationSteps[1].packages[Math.floor((progress - 5) / 7.5) % mockInstallationSteps[1].packages.length];
    } else if (progress < 80) {
      phase = 2;
      const pkgIdx = Math.floor(((progress - 20) / 60) * mockInstallationSteps[2].packages.length);
      pkg = mockInstallationSteps[2].packages[Math.min(pkgIdx, mockInstallationSteps[2].packages.length - 1)];
    } else if (progress < 95) {
      phase = 3;
      pkg = mockInstallationSteps[3].packages[Math.floor((progress - 80) / 5) % mockInstallationSteps[3].packages.length];
    } else {
      phase = 4;
      pkg = mockInstallationSteps[4].packages[0];
    }

    onTick({ progress, phase, pkg, complete: progress >= 100 });

    if (progress >= 100) {
      clearInterval(id);
    }
  }, intervalMs);

  return () => clearInterval(id);
}
