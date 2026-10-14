import DylanOSLogo from "@/components/DylanOSLogo";
import { CheckIcon, InfoIcon } from "@/components/Icons";
import { useInstaller, type InstallerStep } from "@/state/installerState";

const steps = [
  { label: "Bienvenido", sub: "Información general" },
  { label: "Idioma", sub: "Selecciona tu idioma" },
  { label: "Teclado", sub: "Distribución del teclado" },
  { label: "Particionado", sub: "Configura el almacenamiento" },
  { label: "Usuario", sub: "Crea tu cuenta de usuario" },
  { label: "Resumen", sub: "Revisa tus opciones" },
  { label: "Instalar", sub: "Instalando DylanOS" },
  { label: "Finalizar", sub: "¡Listo para usar!" },
];

interface SidebarProps {
  onAbout?: () => void;
}

export default function Sidebar({ onAbout }: SidebarProps) {
  const { state, dispatch } = useInstaller();
  const { currentStep } = state;

  const canNavigateTo = (stepIndex: number) => {
    if (currentStep === 6) return false;
    if (currentStep === 7) return false;
    return stepIndex <= currentStep;
  };

  return (
    <div
      className="flex flex-col h-full relative"
      style={{
        width: 270,
        minWidth: 270,
        background: "linear-gradient(180deg, #080808 0%, #0a0000 100%)",
        borderRight: "1px solid rgba(255,255,255,0.06)",
      }}
    >
      {/* Subtle red glow bottom-right */}
      <div
        className="absolute bottom-0 right-0 pointer-events-none"
        style={{
          width: 200,
          height: 200,
          background: "radial-gradient(circle, rgba(180,0,0,0.12) 0%, transparent 70%)",
        }}
      />

      {/* Logo & title */}
      <div className="flex flex-col items-center pt-8 pb-6 px-6">
        <DylanOSLogo size={60} />
        <div className="mt-4 text-center">
          <div className="font-semibold text-white text-base leading-tight">Instalar DylanOS</div>
          <div className="text-xs mt-1" style={{ color: "var(--text-muted)" }}>
            Versión 1.0.0
          </div>
        </div>
      </div>

      {/* Divider */}
      <div style={{ height: 1, background: "rgba(255,255,255,0.06)", margin: "0 20px" }} />

      {/* Steps */}
      <nav className="flex-1 overflow-y-auto py-4 px-3">
        {steps.map((step, i) => {
          const isActive = i === currentStep;
          const isCompleted = i < currentStep;
          const isClickable = canNavigateTo(i);

          return (
            <button
              key={i}
              onClick={() => isClickable ? dispatch({ type: "SET_STEP", step: i as InstallerStep }) : undefined}
              disabled={!isClickable || isActive}
              className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg mb-1 text-left transition-all duration-150"
              style={{
                background: isActive ? "rgba(220,38,38,0.12)" : "transparent",
                cursor: isClickable && !isActive ? "pointer" : "default",
              }}
              onMouseEnter={e => {
                if (isClickable && !isActive) {
                  (e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.04)";
                }
              }}
              onMouseLeave={e => {
                (e.currentTarget as HTMLButtonElement).style.background = isActive ? "rgba(220,38,38,0.12)" : "transparent";
              }}
            >
              {/* Step indicator */}
              <div
                className="flex items-center justify-center shrink-0 rounded-full text-xs font-semibold"
                style={{
                  width: 26,
                  height: 26,
                  background: isActive
                    ? "#dc2626"
                    : isCompleted
                    ? "rgba(220,38,38,0.7)"
                    : "rgba(255,255,255,0.08)",
                  color: isActive || isCompleted ? "#fff" : "#6b7280",
                  boxShadow: isActive ? "0 0 8px rgba(220,38,38,0.4)" : "none",
                }}
              >
                {isCompleted ? (
                  <CheckIcon size={12} color="#fff" />
                ) : (
                  <span>{i + 1}</span>
                )}
              </div>

              {/* Step label */}
              <div className="flex-1 min-w-0">
                <div
                  className="text-sm font-medium leading-tight truncate"
                  style={{
                    color: isActive ? "#dc2626" : isCompleted ? "rgba(255,255,255,0.75)" : "#6b7280",
                  }}
                >
                  {step.label}
                </div>
                <div
                  className="text-xs mt-0.5 truncate"
                  style={{ color: isActive ? "rgba(255,255,255,0.5)" : "#4b5563" }}
                >
                  {step.sub}
                </div>
              </div>
            </button>
          );
        })}
      </nav>

      {/* Divider */}
      <div style={{ height: 1, background: "rgba(255,255,255,0.06)", margin: "0 20px" }} />

      {/* About button */}
      <button
        onClick={onAbout}
        className="flex items-center gap-2.5 px-6 py-4 text-sm transition-colors duration-150 w-full text-left"
        style={{ color: "#6b7280" }}
        onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.color = "#9ca3af")}
        onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.color = "#6b7280")}
      >
        <InfoIcon size={16} />
        <span>Acerca de DylanOS</span>
      </button>
    </div>
  );
}
