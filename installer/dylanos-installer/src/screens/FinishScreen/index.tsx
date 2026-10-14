import { useState } from "react";
import HeroImage from "@/components/HeroImage";
import BottomBar from "@/components/BottomBar";
import { CheckIcon, RocketIcon } from "@/components/Icons";
import DylanOSLogo from "@/components/DylanOSLogo";
import { useInstaller } from "@/state/installerState";
import StatusNotice from "@/components/StatusNotice";

interface FinishScreenProps {
  onCancel: () => void;
}

export default function FinishScreen({ onCancel }: FinishScreenProps) {
  const { state } = useInstaller();
  const [showRebootDialog, setShowRebootDialog] = useState(false);

  const handleReboot = () => {
    fetch("/api/reboot", { method: "POST" }).catch(() => {});
    setShowRebootDialog(true);
  };

  return (
    <div className="flex flex-col h-full screen-enter">
      <div className="flex-1 overflow-y-auto px-8 pt-8 pb-4">
        {/* Header */}
        <div className="flex items-start justify-between mb-5">
          <div>
            <h1 className="text-2xl font-bold text-white">Finalizar</h1>
            <p className="text-sm mt-1" style={{ color: "#9ca3af" }}>
              La instalación ha finalizado correctamente.
              <br />
              Tu sistema está listo para usar.
            </p>
          </div>
          <div
            className="w-14 h-14 rounded-full flex items-center justify-center"
            style={{ background: "rgba(34,197,94,0.12)", border: "1px solid rgba(34,197,94,0.3)" }}
          >
            <CheckIcon size={26} color="#22c55e" />
          </div>
        </div>

        <div className="mb-5"><StatusNotice tone="success" title="DylanOS se instaló correctamente.">Tu sistema está listo para usar.</StatusNotice></div>
        {state.needsReboot && <div className="mb-5"><StatusNotice title="Es necesario reiniciar el equipo.">Reinicia para completar la configuración de DylanOS.</StatusNotice></div>}

        {/* Hero */}
        <HeroImage className="w-full mb-5" compact style={{ height: 200 }} />

        {/* Success card */}
        <div
          className="rounded-xl p-4 mb-4 flex items-start gap-4"
          style={{ background: "rgba(34,197,94,0.06)", border: "1px solid rgba(34,197,94,0.2)" }}
        >
          <div
            className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
            style={{ background: "rgba(34,197,94,0.15)", border: "1px solid rgba(34,197,94,0.3)" }}
          >
            <CheckIcon size={18} color="#22c55e" />
          </div>
          <div>
            <div className="text-sm font-semibold text-white mb-0.5">¡Instalación completada con éxito!</div>
            <p className="text-xs" style={{ color: "#9ca3af" }}>
              DylanOS se ha instalado correctamente en tu equipo.
              Puedes reiniciar para comenzar a disfrutar de tu nuevo sistema.
            </p>
          </div>
        </div>

        {/* Next steps + illustration */}
        <div
          className="rounded-xl p-4 flex items-start gap-4"
          style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}
        >
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-3">
              <RocketIcon size={16} color="#dc2626" />
              <span className="text-sm font-semibold text-white">Siguientes pasos recomendados:</span>
            </div>
            <ul className="space-y-2">
              {[
                "Retira el medio de instalación para evitar iniciar desde él.",
                "Reinicia tu equipo.",
                "Inicia sesión con tu usuario y contraseña.",
              ].map((step, i) => (
                <li key={i} className="flex items-center gap-2 text-xs" style={{ color: "#9ca3af" }}>
                  <div className="w-1.5 h-1.5 rounded-full shrink-0" style={{ background: "#dc2626" }} />
                  {step}
                </li>
              ))}
            </ul>
          </div>

          {/* Mini illustration */}
          <div
            className="w-28 h-24 rounded-xl flex items-center justify-center shrink-0"
            style={{ background: "rgba(220,38,38,0.08)", border: "1px solid rgba(220,38,38,0.15)" }}
          >
            <DylanOSLogo size={40} />
          </div>
        </div>
      </div>

      {/* Reboot dialog */}
      {showRebootDialog && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center"
          style={{ background: "rgba(0,0,0,0.7)", backdropFilter: "blur(4px)" }}
        >
          <div
            className="rounded-xl p-6 w-full max-w-sm"
            style={{ background: "#111", border: "1px solid rgba(255,255,255,0.1)" }}
          >
            <div className="flex items-center gap-3 mb-3">
              <DylanOSLogo size={32} />
              <h2 className="text-white font-semibold">Reiniciando el equipo</h2>
            </div>
            <p className="text-sm mb-5" style={{ color: "#9ca3af" }}>
              <strong className="text-white">DylanOS se instaló correctamente.</strong> El equipo se reiniciará en unos segundos; recuerda retirar el medio de instalación para iniciar tu nuevo sistema.
            </p>
            <button
              onClick={() => setShowRebootDialog(false)}
              className="w-full py-2.5 rounded-lg text-sm font-semibold"
              style={{ background: "#dc2626", color: "#fff" }}
              onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = "#ef4444")}
              onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = "#dc2626")}
            >
              Entendido
            </button>
          </div>
        </div>
      )}

      <BottomBar
        onCancel={onCancel}
        hidePrev
        hideNext
        customNext={
          <div className="flex flex-col items-end gap-1">
            <button
              onClick={handleReboot}
              className="flex items-center gap-2 px-5 py-2 rounded-lg text-sm font-semibold transition-all"
              style={{ background: "#dc2626", color: "#fff", boxShadow: "0 0 16px rgba(220,38,38,0.3)" }}
              onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = "#ef4444")}
              onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = "#dc2626")}
            >
              <RefreshCwIcon />
              Reiniciar ahora
            </button>
            <button
              className="text-xs"
              style={{ color: "#6b7280" }}
              onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.color = "#9ca3af")}
              onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.color = "#6b7280")}
            >
              Reiniciar manualmente después
            </button>
          </div>
        }
      />
    </div>
  );
}

function RefreshCwIcon() {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="23 4 23 10 17 10"/>
      <polyline points="1 20 1 14 7 14"/>
      <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>
    </svg>
  );
}
