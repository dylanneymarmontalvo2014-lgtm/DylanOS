import { useInstaller } from "@/state/installerState";
import { ChevronRightIcon } from "@/components/Icons";

interface BottomBarProps {
  onCancel: () => void;
  onNext?: () => void;
  onPrev?: () => void;
  nextLabel?: string;
  nextDisabled?: boolean;
  hideNext?: boolean;
  hidePrev?: boolean;
  customNext?: React.ReactNode;
}

const TOTAL_STEPS = 8;

export default function BottomBar({
  onCancel,
  onNext,
  onPrev,
  nextLabel = "Siguiente",
  nextDisabled = false,
  hideNext = false,
  hidePrev = false,
  customNext,
}: BottomBarProps) {
  const { state, dispatch } = useInstaller();
  const { currentStep } = state;

  const handleNext = () => {
    if (onNext) {
      onNext();
    } else {
      dispatch({ type: "NEXT_STEP" });
    }
  };

  const handlePrev = () => {
    if (onPrev) {
      onPrev();
    } else {
      dispatch({ type: "PREV_STEP" });
    }
  };

  return (
    <div
      className="flex items-center px-6 py-4"
      style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}
    >
      {/* Cancel */}
      <button
        onClick={onCancel}
        className="text-sm font-medium transition-colors duration-150 px-2"
        style={{ color: "#9ca3af" }}
        onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.color = "#e5e7eb")}
        onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.color = "#9ca3af")}
      >
        Cancelar
      </button>

      {/* Step dots */}
      <div className="flex-1 flex items-center justify-center gap-2">
        {Array.from({ length: TOTAL_STEPS }).map((_, i) => (
          <div
            key={i}
            className="rounded-full transition-all duration-300"
            style={{
              width: i === currentStep ? 20 : 7,
              height: 7,
              background:
                i === currentStep
                  ? "#dc2626"
                  : i < currentStep
                  ? "rgba(220,38,38,0.4)"
                  : "rgba(255,255,255,0.15)",
            }}
          />
        ))}
      </div>

      {/* Back + Next */}
      <div className="flex items-center gap-3">
        {!hidePrev && currentStep > 0 && (
          <button
            onClick={handlePrev}
            className="px-4 py-2 rounded-lg text-sm font-medium transition-all duration-150"
            style={{
              background: "rgba(255,255,255,0.06)",
              border: "1px solid rgba(255,255,255,0.1)",
              color: "#d1d5db",
            }}
            onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.1)")}
            onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.06)")}
          >
            Atrás
          </button>
        )}

        {customNext
          ? customNext
          : !hideNext && (
              <button
                onClick={handleNext}
                disabled={nextDisabled}
                aria-disabled={nextDisabled}
                className="flex items-center gap-1.5 px-5 py-2 rounded-lg text-sm font-semibold transition-all duration-150"
                style={{
                  background: nextDisabled ? "rgba(220,38,38,0.3)" : "#dc2626",
                  color: nextDisabled ? "rgba(255,255,255,0.4)" : "#fff",
                  cursor: nextDisabled ? "not-allowed" : "pointer",
                  boxShadow: nextDisabled ? "none" : "0 0 16px rgba(220,38,38,0.25)",
                }}
                onMouseEnter={e => {
                  if (!nextDisabled)
                    (e.currentTarget as HTMLButtonElement).style.background = "#ef4444";
                }}
                onMouseLeave={e => {
                  if (!nextDisabled)
                    (e.currentTarget as HTMLButtonElement).style.background = "#dc2626";
                }}
              >
                {nextLabel}
                <ChevronRightIcon size={14} color="currentColor" />
              </button>
            )}
      </div>
    </div>
  );
}
