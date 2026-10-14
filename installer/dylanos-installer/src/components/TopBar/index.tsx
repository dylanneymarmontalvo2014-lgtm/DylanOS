import type { ReactNode } from "react";

interface TopBarProps {
  children?: ReactNode;
  title?: string;
}

export default function TopBar({ children, title }: TopBarProps) {
  return (
    <div
      className="flex items-center px-6 py-3 shrink-0"
      style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}
    >
      {title && <span className="text-sm font-semibold text-white">{title}</span>}
      {children}
    </div>
  );
}
