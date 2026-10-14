import { useState } from "react";
import { InstallerProvider, useInstaller } from "@/state/installerState";
import Sidebar from "@/components/Sidebar";
import SystemInfo from "@/components/SystemInfo";
import CancelDialog from "@/components/CancelDialog";
import WelcomeScreen from "@/screens/WelcomeScreen";
import LanguageScreen from "@/screens/LanguageScreen";
import KeyboardScreen from "@/screens/KeyboardScreen";
import PartitioningScreen from "@/screens/PartitioningScreen";
import UserCreationScreen from "@/screens/UserCreationScreen";
import SummaryScreen from "@/screens/SummaryScreen";
import InstallationScreen from "@/screens/InstallationScreen";
import FinishScreen from "@/screens/FinishScreen";

function InstallerApp() {
  const { state } = useInstaller();
  const [showCancel, setShowCancel] = useState(false);
  const [showAbout, setShowAbout] = useState(false);

  const handleCancelConfirm = () => {
    setShowCancel(false);
    // Cierra el instalador: el backend cierra la ventana nativa y su servicio.
    fetch("/api/quit", { method: "POST" }).catch(() => {});
    window.close();
  };

  const screenProps = { onCancel: () => setShowCancel(true) };

  const screens = [
    <WelcomeScreen key="welcome" {...screenProps} />,
    <LanguageScreen key="language" {...screenProps} />,
    <KeyboardScreen key="keyboard" {...screenProps} />,
    <PartitioningScreen key="partitioning" {...screenProps} />,
    <UserCreationScreen key="user" {...screenProps} />,
    <SummaryScreen key="summary" {...screenProps} />,
    <InstallationScreen key="installation" {...screenProps} />,
    <FinishScreen key="finish" {...screenProps} />,
  ];

  return (
    <div
      className="w-full h-full flex flex-col select-none"
      style={{ background: "#0d0d0d", fontFamily: "'Inter', sans-serif" }}
    >
      {/* Window chrome */}
      <div className="flex items-center justify-end px-4 py-2.5 shrink-0" style={{ borderBottom: "1px solid rgba(255,255,255,0.04)" }}>
        <div className="flex items-center gap-1.5">
          {[
            { color: "#374151", hoverColor: "#6b7280", title: "Minimizar", symbol: "—" },
            { color: "#374151", hoverColor: "#6b7280", title: "Maximizar", symbol: "□" },
            { color: "#374151", hoverColor: "#dc2626", title: "Cerrar", symbol: "×" },
          ].map(btn => (
            <button
              key={btn.title}
              title={btn.title}
              className="w-3 h-3 rounded-full transition-colors duration-150 flex items-center justify-center"
              style={{ background: btn.color, fontSize: 0 }}
              onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = btn.hoverColor)}
              onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = btn.color)}
              onClick={btn.title === "Cerrar" ? () => setShowCancel(true) : undefined}
            />
          ))}
        </div>
      </div>

      {/* Main layout */}
      <div className="flex flex-1 overflow-hidden">
        {/* Sidebar */}
        <Sidebar onAbout={() => setShowAbout(true)} />

        {/* Main content */}
        <div
          className="flex-1 flex flex-col overflow-hidden"
          style={{ background: "#0d0d0d" }}
        >
          {screens[state.currentStep]}
        </div>

        {/* System info panel */}
        <SystemInfo />
      </div>

      {/* Cancel dialog */}
      {showCancel && (
        <CancelDialog
          onConfirm={handleCancelConfirm}
          onClose={() => setShowCancel(false)}
        />
      )}

      {/* About dialog */}
      {showAbout && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center"
          style={{ background: "rgba(0,0,0,0.7)", backdropFilter: "blur(4px)" }}
        >
          <div
            className="rounded-xl p-6 w-full max-w-sm"
            style={{ background: "#111", border: "1px solid rgba(255,255,255,0.1)" }}
          >
            <div className="flex items-center gap-3 mb-3">
              <div
                className="w-10 h-10 rounded-lg flex items-center justify-center"
                style={{ background: "rgba(220,38,38,0.12)", border: "1px solid rgba(220,38,38,0.2)" }}
              >
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#dc2626" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10"/>
                  <line x1="12" y1="16" x2="12" y2="12"/>
                  <line x1="12" y1="8" x2="12.01" y2="8"/>
                </svg>
              </div>
              <div>
                <div className="text-white font-semibold">DylanOS Installer</div>
                <div className="text-xs" style={{ color: "#6b7280" }}>Versión 1.0.0</div>
              </div>
            </div>
            <p className="text-sm mb-5" style={{ color: "#9ca3af" }}>
              Instalador oficial de DylanOS. Detecta tu hardware, particiona el disco,
              copia el sistema y configura el arranque y tu cuenta de usuario, todo desde esta interfaz.
            </p>
            <button
              onClick={() => setShowAbout(false)}
              className="w-full py-2.5 rounded-lg text-sm font-medium transition-all"
              style={{ background: "rgba(255,255,255,0.07)", border: "1px solid rgba(255,255,255,0.1)", color: "#d1d5db" }}
              onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.1)")}
              onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.07)")}
            >
              Cerrar
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default function App() {
  return (
    <InstallerProvider>
      <InstallerApp />
    </InstallerProvider>
  );
}
