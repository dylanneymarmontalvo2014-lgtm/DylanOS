import { InfoIcon, CheckIcon } from "@/components/Icons";

interface StatusNoticeProps { title: string; children?: React.ReactNode; tone?: "error" | "success" | "neutral"; action?: React.ReactNode; }
export default function StatusNotice({ title, children, tone = "error", action }: StatusNoticeProps) {
  const success = tone === "success";
  const color = success ? "#22c55e" : tone === "neutral" ? "#9ca3af" : "#dc2626";
  const background = success ? "rgba(34,197,94,0.08)" : tone === "neutral" ? "rgba(255,255,255,0.04)" : "rgba(220,38,38,0.08)";
  const border = success ? "rgba(34,197,94,0.26)" : tone === "neutral" ? "rgba(255,255,255,0.1)" : "rgba(220,38,38,0.3)";
  return <div className="flex items-start gap-2.5 rounded-lg px-3 py-2.5 text-sm" style={{ background, border: `1px solid ${border}` }} role={tone === "error" ? "alert" : "status"}>
    <span className="mt-0.5">{success ? <CheckIcon size={15} color={color} /> : <InfoIcon size={15} color={color} />}</span>
    <div className="min-w-0 flex-1"><div className="font-medium" style={{ color }}>{title}</div>{children && <div className="text-xs mt-0.5" style={{ color: "#9ca3af" }}>{children}</div>}</div>{action}
  </div>;
}
