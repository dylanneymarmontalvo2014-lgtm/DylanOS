interface ProgressIndicatorProps {
  progress: number; // 0–100
  animated?: boolean;
  height?: number;
}

export default function ProgressIndicator({ progress, animated = true, height = 6 }: ProgressIndicatorProps) {
  return (
    <div
      className="relative rounded-full overflow-hidden"
      style={{ height, background: "rgba(255,255,255,0.08)" }}
    >
      <div
        className={`absolute inset-y-0 left-0 rounded-full transition-all duration-300 ${animated ? "progress-bar-animated" : ""}`}
        style={{
          width: `${progress}%`,
          background: animated ? undefined : "#dc2626",
        }}
      />
    </div>
  );
}
