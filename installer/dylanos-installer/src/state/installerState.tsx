
import { createContext, useContext, useReducer, type ReactNode } from "react";
import { mockErrorScenarios, type MockErrorScenario } from "@/data/mockValidation";

export type InstallerStep = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7;
export type PartitionError = "none" | "no-disk" | "insufficient-space" | "invalid" | "detection";
export type InstallationStatus = "running" | "paused" | "cancelled" | "error" | "complete";

// DYLANOS-MOCK: Query scenarios make exceptional prototype states reviewable without touching hardware.
const requestedScenario = new URLSearchParams(window.location.search).get("mock");
const mockScenario = mockErrorScenarios.includes(requestedScenario as MockErrorScenario) ? requestedScenario as MockErrorScenario : null;

export interface InstallerState {
  currentStep: InstallerStep;
  language: string;
  languageName: string;
  languageLoadError: boolean;
  keyboard: { layout: string; variant: string; model: string };
  keyboardInvalid: boolean;
  partitioning: { mode: "auto" | "manual"; disk: string };
  partitionError: PartitionError;
  user: { fullName: string; username: string; hostname: string; valid: boolean; password: string; rootPassword: string };
  installationProgress: number;
  installationPhase: number;
  installationPackage: string;
  installationStatus: InstallationStatus;
  installationError: string;
  installationComplete: boolean;
  needsReboot: boolean;
}

const initialState: InstallerState = {
  currentStep: mockScenario === "language-error" ? 1 : mockScenario?.startsWith("partition-") ? 3 : mockScenario?.startsWith("install-") ? 6 : mockScenario === "reboot-required" ? 7 : 0,
  language: "es_419", languageName: "Español (Latinoamérica)", languageLoadError: mockScenario === "language-error",
  keyboard: { layout: "Español (Latinoamérica)", variant: "Español (Latinoamérica)", model: "Genérico de 105 teclas (Internacional)" },
  keyboardInvalid: mockScenario === "keyboard-invalid",
  partitioning: { mode: "auto", disk: mockScenario === "partition-no-disk" ? "" : "/dev/sda" },
  partitionError: mockScenario === "partition-no-disk" ? "no-disk" : mockScenario === "partition-space" ? "insufficient-space" : mockScenario === "partition-invalid" ? "invalid" : mockScenario === "partition-detection" ? "detection" : "none",
  user: { fullName: "", username: "", hostname: "DylanOS-PC", valid: false, password: "", rootPassword: "" },
  installationProgress: mockScenario?.startsWith("install-") ? 52 : 0, installationPhase: 2, installationPackage: "plasma-desktop (287/1254)",
  installationStatus: mockScenario === "install-paused" ? "paused" : mockScenario === "install-cancelled" ? "cancelled" : mockScenario === "install-error" ? "error" : "running",
  installationError: "",
  installationComplete: false, needsReboot: mockScenario === "reboot-required",
};

type Action =
  | { type: "SET_STEP"; step: InstallerStep } | { type: "NEXT_STEP" } | { type: "PREV_STEP" }
  | { type: "SET_LANGUAGE"; code: string; name: string } | { type: "SET_LANGUAGE_LOAD_ERROR"; value: boolean }
  | { type: "SET_KEYBOARD"; layout: string; variant: string; model: string } | { type: "SET_KEYBOARD_INVALID"; value: boolean }
  | { type: "SET_PARTITIONING"; mode: "auto" | "manual"; disk: string } | { type: "SET_PARTITION_ERROR"; error: PartitionError }
  | { type: "SET_USER"; fullName: string; username: string; hostname: string; valid: boolean; password: string; rootPassword: string }
  | { type: "SET_INSTALLATION_PROGRESS"; progress: number; phase: number; pkg: string } | { type: "SET_INSTALLATION_STATUS"; status: InstallationStatus }
  | { type: "SET_INSTALLATION_ERROR"; error: string }
  | { type: "SET_INSTALLATION_COMPLETE" } | { type: "SET_NEEDS_REBOOT"; value: boolean };

function reducer(state: InstallerState, action: Action): InstallerState {
  switch (action.type) {
    case "SET_STEP": return { ...state, currentStep: action.step };
    case "NEXT_STEP": return { ...state, currentStep: Math.min(7, state.currentStep + 1) as InstallerStep };
    case "PREV_STEP": return { ...state, currentStep: Math.max(0, state.currentStep - 1) as InstallerStep };
    case "SET_LANGUAGE": return { ...state, language: action.code, languageName: action.name, languageLoadError: false };
    case "SET_LANGUAGE_LOAD_ERROR": return { ...state, languageLoadError: action.value };
    case "SET_KEYBOARD": return { ...state, keyboard: { layout: action.layout, variant: action.variant, model: action.model }, keyboardInvalid: false };
    case "SET_KEYBOARD_INVALID": return { ...state, keyboardInvalid: action.value };
    case "SET_PARTITIONING": return { ...state, partitioning: { mode: action.mode, disk: action.disk }, partitionError: action.disk ? "none" : "no-disk" };
    case "SET_PARTITION_ERROR": return { ...state, partitionError: action.error };
    case "SET_USER": return { ...state, user: { fullName: action.fullName, username: action.username, hostname: action.hostname, valid: action.valid, password: action.password, rootPassword: action.rootPassword } };
    case "SET_INSTALLATION_PROGRESS": return { ...state, installationProgress: action.progress, installationPhase: action.phase, installationPackage: action.pkg };
    case "SET_INSTALLATION_STATUS": return { ...state, installationStatus: action.status };
    case "SET_INSTALLATION_ERROR": return { ...state, installationError: action.error, installationStatus: "error" };
    case "SET_INSTALLATION_COMPLETE": return { ...state, installationComplete: true, installationStatus: "complete", installationProgress: 100 };
    case "SET_NEEDS_REBOOT": return { ...state, needsReboot: action.value };
    default: return state;
  }
}

const InstallerContext = createContext<{ state: InstallerState; dispatch: React.Dispatch<Action> } | null>(null);
export function InstallerProvider({ children }: { children: ReactNode }) { const [state, dispatch] = useReducer(reducer, initialState); return <InstallerContext.Provider value={{ state, dispatch }}>{children}</InstallerContext.Provider>; }
export function useInstaller() { const ctx = useContext(InstallerContext); if (!ctx) throw new Error("useInstaller must be used within InstallerProvider"); return ctx; }
