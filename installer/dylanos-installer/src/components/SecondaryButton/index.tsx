import type { ButtonHTMLAttributes, ReactNode } from "react";

interface SecondaryButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
}

export default function SecondaryButton({ children, className = "", style, ...rest }: SecondaryButtonProps) {
  return (
    <button
      className={`flex items-center justify-center gap-1.5 px-4 py-2 rounded-lg text-sm font-medium transition-all duration-150 ${className}`}
      style={{
        background: "rgba(255,255,255,0.06)",
        border: "1px solid rgba(255,255,255,0.1)",
        color: "#d1d5db",
        ...style,
      }}
      onMouseEnter={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.1)")}
      onMouseLeave={e => ((e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.06)")}
      {...rest}
    >
      {children}
    </button>
  );
}
