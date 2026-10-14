import HeroImage from "@/components/HeroImage";
import BottomBar from "@/components/BottomBar";
import { RocketIcon, ShieldIcon, SettingsIcon } from "@/components/Icons";
import { useInstaller } from "@/state/installerState";

const features = [
  {
    icon: <RocketIcon size={20} color="#dc2626" />,
    title: "Rápido",
    desc: "Ligero y optimizado para máximo rendimiento.",
  },
  {
    icon: <ShieldIcon size={20} color="#dc2626" />,
    title: "Seguro",
    desc: "Protegido desde el inicio para tu tranquilidad.",
  },
  {
    icon: <SettingsIcon size={20} color="#dc2626" />,
    title: "Personalizable",
    desc: "Hecho para adaptarse a tu estilo de trabajo.",
  },
];

interface WelcomeScreenProps {
  onCancel: () => void;
}

export default function WelcomeScreen({ onCancel }: WelcomeScreenProps) {
  const { dispatch } = useInstaller();

  return (
    <div className="flex flex-col h-full screen-enter">
      {/* Scrollable content */}
      <div className="flex-1 overflow-y-auto px-8 pt-8 pb-4">
        {/* Title */}
        <div className="mb-5">
          <h1 className="text-2xl font-bold text-white">
            Bienvenido a{" "}
            <span style={{ color: "#dc2626" }}>DylanOS</span>
          </h1>
          <p className="text-sm mt-1.5" style={{ color: "#9ca3af" }}>
            Este asistente te guiará durante el proceso de instalación.
            <br />
            Es rápido, sencillo y estarás listo para disfrutar de DylanOS en pocos minutos.
          </p>
        </div>

        {/* Hero image */}
        <HeroImage className="w-full mb-5" style={{ height: 260 }} compact />

        {/* Feature cards */}
        <div className="grid grid-cols-3 gap-3">
          {features.map((f, i) => (
            <div
              key={i}
              className="relative rounded-xl p-4 transition-all duration-200 group"
              style={{
                background: "rgba(255,255,255,0.04)",
                border: "1px solid rgba(255,255,255,0.07)",
              }}
              onMouseEnter={e => {
                (e.currentTarget as HTMLDivElement).style.background = "rgba(255,255,255,0.07)";
                (e.currentTarget as HTMLDivElement).style.borderColor = "rgba(220,38,38,0.2)";
              }}
              onMouseLeave={e => {
                (e.currentTarget as HTMLDivElement).style.background = "rgba(255,255,255,0.04)";
                (e.currentTarget as HTMLDivElement).style.borderColor = "rgba(255,255,255,0.07)";
              }}
            >
              <div className="mb-2">{f.icon}</div>
              <div className="text-sm font-semibold text-white mb-1">{f.title}</div>
              <div className="text-xs leading-relaxed" style={{ color: "#9ca3af" }}>
                {f.desc}
              </div>
              {/* Bottom accent line */}
              <div
                className="absolute bottom-0 left-4 right-4 h-0.5 rounded-full"
                style={{ background: "#dc2626", opacity: 0.5 }}
              />
            </div>
          ))}
        </div>
      </div>

      {/* Bottom nav */}
      <BottomBar
        onCancel={onCancel}
        hidePrev
        onNext={() => dispatch({ type: "NEXT_STEP" })}
      />
    </div>
  );
}
