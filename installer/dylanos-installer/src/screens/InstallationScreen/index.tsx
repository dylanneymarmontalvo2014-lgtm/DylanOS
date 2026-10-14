import { useEffect } from "react";
import HeroImage from "@/components/HeroImage";
import BottomBar from "@/components/BottomBar";
import { CheckIcon, DownloadIcon, LocationIcon, ClockIcon, KeyboardIcon, HardDriveIcon, UserIcon, MonitorIcon } from "@/components/Icons";
import { mockInstallationSteps } from "@/data/mockInstallation";
import { useInstaller } from "@/state/installerState";
import StatusNotice from "@/components/StatusNotice";
import { startSimulatedInstallation } from "@/services/simulatedInstallation";

// El POST /api/install lanza la instalación real del backend (particionado,
// extracción del squashfs, usuarios y GRUB); este componente hace polling
// de /api/install/status. La simulación solo es respaldo de vista previa.

interface InstallationScreenProps {
  onCancel: () => void;
}

export default function InstallationScreen({ onCancel }: InstallationScreenProps) {
  const { state, dispatch } = useInstaller();

  useEffect(() => {
    if (state.installationComplete || state.installationStatus !== "running") return;

    let pollInterval: any = null;
    let fallbackStop: (() => void) | null = null;

    fetch("/api/install", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        disk: state.partitioning.disk,
        mode: state.partitioning.mode,
        language: state.language,
        keyboard: state.keyboard,
        user: state.user,
      }),
    })
      .then(res => res.json())
      .then(data => {
        if (data && data.ok) {
          pollInterval = setInterval(() => {
            fetch("/api/install/status")
              .then(r => r.json())
              .then(status => {
                if (status.status === "error") {
                  dispatch({ type: "SET_INSTALLATION_ERROR", error: status.error || "Error desconocido durante la instalación." });
                  clearInterval(pollInterval);
                  return;
                }
                dispatch({
                  type: "SET_INSTALLATION_PROGRESS",
                  progress: status.progress,
                  phase: status.phase,
                  pkg: status.pkg || status.phaseLabel,
                });
                if (status.complete || status.progress >= 100) {
                  clearInterval(pollInterval);
                  dispatch({ type: "SET_INSTALLATION_COMPLETE" });
                  setTimeout(() => dispatch({ type: "NEXT_STEP" }), 1200);
                }
              })
              .catch(() => {});
          }, 400);
        } else {
          fallbackStop = startSimulatedInstallation(({ progress, phase, pkg, complete }) => {
            dispatch({ type: "SET_INSTALLATION_PROGRESS", progress, phase, pkg });
            if (complete) {
              dispatch({ type: "SET_INSTALLATION_COMPLETE" });
              setTimeout(() => dispatch({ type: "NEXT_STEP" }), 1000);
            }
          });
        }
      })
      .catch(() => {
        fallbackStop = startSimulatedInstallation(({ progress, phase, pkg, complete }) => {
          dispatch({ type: "SET_INSTALLATION_PROGRESS", progress, phase, pkg });
          if (complete) {
            dispatch({ type: "SET_INSTALLATION_COMPLETE" });
            setTimeout(() => dispatch({ type: "NEXT_STEP" }), 1000);
          }
        });
      });

    return () => {
      if (pollInterval) clearInterval(pollInterval);
      if (fallbackStop) fallbackStop();
    };
  }, [state.installationComplete, state.installationStatus, dispatch]);

  const { installationProgress: progress, installationPhase: phase } = state;
  const exceptional = state.installationStatus === "cancelled" || state.installationStatus === "error";

  const infoItems = [
    { icon: <LocationIcon size={13} color="#9ca3af" />, label: "Ubicación:", value: "Bogotá, Colombia" },
    { icon: <ClockIcon size={13} color="#9ca3af" />, label: "Zona horaria:", value: "América/Bogotá" },
    { icon: <KeyboardIcon size={13} color="#9ca3af" />, label: "Teclado:", value: state.keyboard.layout },
    { icon: <HardDriveIcon size={13} color="#9ca3af" />, label: "Particionado:", value: `${state.partitioning.mode === "auto" ? "GPT automático" : "Manual"} en ${state.partitioning.disk}` },
    { icon: <UserIcon size={13} color="#9ca3af" />, label: "Usuario:", value: state.user.username || "dylan" },
    { icon: <MonitorIcon size={13} color="#9ca3af" />, label: "Nombre de la máquina:", value: state.user.hostname || "DylanOS-PC" },
  ];

  return (
    <div className="flex flex-col h-full screen-enter">
      <div className="flex-1 overflow-y-auto px-8 pt-8 pb-4">
        {/* Header */}
        <div className="flex items-start justify-between mb-5">
          <div>
            <h1 className="text-2xl font-bold text-white">
              Instalando{" "}
              <span style={{ color: "#dc2626" }}>DylanOS</span>
            </h1>
            <p className="text-sm mt-1" style={{ color: "#9ca3af" }}>
              Por favor espera mientras se instala DylanOS en tu equipo.
              <br />
              Esto puede tardar varios minutos.
            </p>
          </div>
          <div
            className="w-14 h-14 rounded-xl flex items-center justify-center"
            style={{ background: "rgba(220,38,38,0.1)", border: "1px solid rgba(220,38,38,0.2)" }}
          >
            <DownloadIcon size={28} color="#dc2626" />
          </div>
        </div>

        {state.installationStatus === "paused" && <div className="mb-4"><StatusNotice tone="neutral" title="Instalación pausada">El proceso se reanudará cuando selecciones continuar.</StatusNotice></div>}
        {state.installationStatus === "cancelled" && <div className="mb-4"><StatusNotice title="Instalación cancelada.">No se realizaron cambios en tu disco.</StatusNotice></div>}
        {state.installationStatus === "error" && <div className="mb-4"><StatusNotice title="Se produjo un error durante la instalación.">{state.installationError || "No se pudo completar la instalación. Puedes volver al resumen e intentarlo de nuevo."}</StatusNotice></div>}

        {/* Hero image - compact */}
        <HeroImage className="w-full mb-5" compact style={{ height: 180 }} />

        {/* Progress */}
        <div
          className="rounded-xl p-5 mb-4"
          style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}
        >
          <div className="flex items-center justify-between mb-2">
            <div>
              <div className="text-sm font-medium text-white">
                {mockInstallationSteps[phase]?.label ?? "Instalando paquetes..."}
              </div>
              <div className="text-xs mt-0.5" style={{ color: "#9ca3af" }}>
                {state.installationPackage}
              </div>
            </div>
            <div className="text-lg font-bold" style={{ color: "#dc2626" }}>
              {progress}%
            </div>
          </div>

          {/* Progress bar */}
          <div
            className="relative rounded-full overflow-hidden"
            style={{ height: 6, background: "rgba(255,255,255,0.08)" }}
          >
            <div
              className="absolute inset-y-0 left-0 rounded-full transition-all duration-300 progress-bar-animated"
              style={{ width: `${progress}%` }}
            />
          </div>

          {/* Info grid */}
          <div className="grid grid-cols-2 gap-x-8 gap-y-2 mt-4">
            {infoItems.map((item, i) => (
              <div key={i} className="flex items-center gap-2">
                {item.icon}
                <span className="text-xs" style={{ color: "#6b7280" }}>{item.label}</span>
                <span className="text-xs text-white font-medium truncate">{item.value}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Installation stages */}
        <div className="flex items-center justify-between px-2">
          {mockInstallationSteps.map((step, i) => {
            const isDone = i < phase;
            const isActive = i === phase;

            return (
              <div key={step.id} className="flex flex-col items-center gap-1.5 flex-1">
                <div className="flex items-center w-full">
                  {i > 0 && (
                    <div
                      className="flex-1 h-px transition-all duration-500"
                      style={{ background: isDone || isActive ? "#dc2626" : "rgba(255,255,255,0.1)" }}
                    />
                  )}

                  <div
                    className="w-8 h-8 rounded-full flex items-center justify-center shrink-0 transition-all duration-300"
                    style={{
                      background: isDone
                        ? "#dc2626"
                        : isActive
                        ? "rgba(220,38,38,0.2)"
                        : "rgba(255,255,255,0.06)",
                      border: isActive ? "2px solid #dc2626" : isDone ? "2px solid #dc2626" : "2px solid rgba(255,255,255,0.1)",
                      boxShadow: isActive ? "0 0 12px rgba(220,38,38,0.4)" : "none",
                    }}
                  >
                    {isDone ? (
                      <CheckIcon size={14} color="#fff" />
                    ) : isActive ? (
                      <div
                        className="w-2.5 h-2.5 rounded-full"
                        style={{
                          background: "#dc2626",
                          animation: "pulse-red 1.5s ease-in-out infinite",
                        }}
                      />
                    ) : (
                      <div className="w-2 h-2 rounded-full" style={{ background: "rgba(255,255,255,0.2)" }} />
                    )}
                  </div>

                  {i < mockInstallationSteps.length - 1 && (
                    <div
                      className="flex-1 h-px transition-all duration-500"
                      style={{ background: isDone ? "#dc2626" : "rgba(255,255,255,0.1)" }}
                    />
                  )}
                </div>

                <span
                  className="text-xs text-center"
                  style={{ color: isActive ? "#fff" : isDone ? "rgba(255,255,255,0.6)" : "#6b7280" }}
                >
                  {step.label}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      <BottomBar
        onCancel={onCancel}
        hidePrev
        hideNext
        customNext={
          exceptional ? <button onClick={() => dispatch({ type: "SET_STEP", step: 5 })} className="px-5 py-2 rounded-lg text-sm font-semibold" style={{ background: "#dc2626", color: "#fff" }}>Volver al resumen</button> :
          state.installationStatus === "paused" ? <button onClick={() => dispatch({ type: "SET_INSTALLATION_STATUS", status: "running" })} className="px-5 py-2 rounded-lg text-sm font-semibold" style={{ background: "#dc2626", color: "#fff" }}>Continuar</button> :
          <button disabled className="flex items-center gap-1.5 px-5 py-2 rounded-lg text-sm font-semibold" style={{ background: "rgba(220,38,38,0.25)", color: "rgba(255,255,255,0.3)", cursor: "not-allowed" }}>Siguiente</button>
        }
      />
    </div>
  );
}
