import type { ReactNode } from "react";

interface FormFieldProps {
  label: string;
  hint?: string;
  icon?: ReactNode;
  children: ReactNode;
}

export default function FormField({ label, hint, icon, children }: FormFieldProps) {
  return (
    <div className="flex items-start gap-4 pb-4">
      {icon && (
        <div
          className="w-10 h-10 rounded-lg flex items-center justify-center shrink-0 mt-0.5"
          style={{ background: "rgba(220,38,38,0.1)", border: "1px solid rgba(220,38,38,0.15)" }}
        >
          {icon}
        </div>
      )}
      <div style={{ width: 200, flexShrink: 0 }}>
        <div className="text-sm font-medium text-white">{label}</div>
        {hint && <div className="text-xs mt-0.5" style={{ color: "#6b7280" }}>{hint}</div>}
      </div>
      <div className="flex-1">{children}</div>
    </div>
  );
}
