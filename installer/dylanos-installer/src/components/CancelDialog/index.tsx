import { XIcon } from "@/components/Icons";

interface CancelDialogProps {
  onConfirm: () => void;
  onClose: () => void;
}

export default function CancelDialog({ onConfirm, onClose }: CancelDialogProps) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      style={{ background: "rgba(0,0,0,0.7)", backdropFilter: "blur(4px)" }}
    >
      <div
        className="relative rounded-xl p-6 w-full max-w-sm"
        style={{
          background: "#111",
          border: "1px solid rgba(255,255,255,0.1)",
          boxShadow: "0 24px 64px rgba(0,0,0,0.6)",
        }}
      >
        <button
          onClick={onClose}
          className="absolute top-4 right-4 p-1 rounded-lg transition-colors"
          style={{ color: "#6b7280" }}
          onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.color = "#d1d5db")}
          onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.color = "#6b7280")}
        >
          <XIcon size={16} />
        </button>

        <div
          className="w-12 h-12 rounded-full flex items-center justify-center mb-4"
          style={{ background: "rgba(220,38,38,0.15)", border: "1px solid rgba(220,38,38,0.3)" }}
        >
          <XIcon size={20} color="#dc2626" />
        </div>

        <h2 className="text-white font-semibold text-lg mb-2">¿Cancelar la instalación?</h2>
        <p className="text-sm mb-6" style={{ color: "#9ca3af" }}>
          Si cancelas ahora, perderás todos los cambios realizados en el asistente. El sistema no será modificado.
        </p>

        <div className="flex gap-3">
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
            Continuar instalación
          </button>
          <button
            onClick={onConfirm}
            className="flex-1 py-2.5 rounded-lg text-sm font-semibold transition-all"
            style={{ background: "#dc2626", color: "#fff" }}
            onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = "#ef4444")}
            onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = "#dc2626")}
          >
            Sí, cancelar
          </button>
        </div>
      </div>
    </div>
  );
}
