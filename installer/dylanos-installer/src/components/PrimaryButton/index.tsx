import type { ButtonHTMLAttributes, ReactNode } from "react";

interface PrimaryButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
}

export default function PrimaryButton({ children, className = "", style, ...rest }: PrimaryButtonProps) {
  return (
    <button
      className={`flex items-center justify-center gap-1.5 px-5 py-2 rounded-lg text-sm font-semibold transition-all duration-150 ${className}`}
      style={{
        background: "#DC143C",
        color: "#fff",
        boxShadow: "0 0 16px rgba(220,20,60,0.25)",
        ...style,
      }}
      onMouseEnter={e => {
        if (!rest.disabled)
          (e.currentTarget as HTMLButtonElement).style.background = "#FF2A54";
      }}
      onMouseLeave={e => {
        if (!rest.disabled)
          (e.currentTarget as HTMLButtonElement).style.background = "#DC143C";
      }}
      {...rest}
    >
      {children}
    </button>
  );
}
