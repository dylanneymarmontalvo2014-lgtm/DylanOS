import { useState, useEffect } from "react";
import BottomBar from "@/components/BottomBar";
import { GlobeIcon, SearchIcon } from "@/components/Icons";
import { languages } from "@/data/mockLanguages";
import { useInstaller } from "@/state/installerState";
import StatusNotice from "@/components/StatusNotice";
import worldMapImg from "@/assets/illustrations/world-map.png";

// La lista se carga del backend (/api/locales) con el catálogo como respaldo.

interface LanguageScreenProps {
  onCancel: () => void;
}

export default function LanguageScreen({ onCancel }: LanguageScreenProps) {
  const { state, dispatch } = useInstaller();
  const [search, setSearch] = useState("");
  const [langList, setLangList] = useState(languages);

  useEffect(() => {
    fetch("/api/locales")
      .then(r => r.json())
      .then(data => { if (Array.isArray(data) && data.length) setLangList(data); })
      .catch(() => {});
  }, []);

  const filtered = langList.filter(l =>
    l.name.toLowerCase().includes(search.toLowerCase())
  );
  const languagesUnavailable = state.languageLoadError;

  const selected = langList.find(l => l.code === state.language) ?? langList[0];

  return (
    <div className="flex flex-col h-full screen-enter">
      <div className="flex-1 overflow-y-auto px-8 pt-8 pb-4">
        {/* Header */}
        <div className="flex items-start justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-white">Idioma</h1>
            <p className="text-sm mt-1" style={{ color: "#9ca3af" }}>
              Selecciona el idioma que deseas utilizar durante la instalación.
            </p>
          </div>
          <div
            className="w-14 h-14 rounded-xl flex items-center justify-center"
            style={{ background: "rgba(220,38,38,0.1)", border: "1px solid rgba(220,38,38,0.2)" }}
          >
            <GlobeIcon size={28} color="#dc2626" />
          </div>
        </div>

        {languagesUnavailable && (
          <div className="mb-4"><StatusNotice title="No se pudieron cargar los idiomas" action={<button onClick={() => dispatch({ type: "SET_LANGUAGE_LOAD_ERROR", value: false })} className="text-xs font-medium" style={{ color: "#fff" }}>Reintentar</button>}>Comprueba la conexión e inténtalo de nuevo.</StatusNotice></div>
        )}

        {/* Two column layout */}
        <div
          className="rounded-xl overflow-hidden"
          style={{
            background: "rgba(255,255,255,0.03)",
            border: "1px solid rgba(255,255,255,0.07)",
            minHeight: 380,
          }}
        >
          <div className="grid h-full" style={{ gridTemplateColumns: "1fr 1px 1fr" }}>
            {/* Left: language list */}
            <div className="flex flex-col">
              {/* Search */}
              <div
                className="flex items-center gap-2 px-3 py-2.5 m-3 rounded-lg"
                style={{
                  background: "rgba(255,255,255,0.05)",
                  border: "1px solid rgba(255,255,255,0.08)",
                }}
              >
                <SearchIcon size={14} color="#6b7280" />
                <input
                  type="text"
                  placeholder="Buscar idioma..."
                  value={search}
                  onChange={e => setSearch(e.target.value)}
                  className="flex-1 bg-transparent outline-none text-sm"
                  style={{ color: "#d1d5db" }}
                />
              </div>

              {/* Language list */}
              <div className="overflow-y-auto flex-1" style={{ maxHeight: 340 }}>
                {languagesUnavailable ? <div className="p-4 text-sm" style={{ color: "#6b7280" }}>La lista estará disponible cuando se vuelva a intentar.</div> : filtered.map(lang => (
                  <button
                    key={lang.code}
                    onClick={() => dispatch({ type: "SET_LANGUAGE", code: lang.code, name: lang.name })}
                    className="w-full text-left px-4 py-2.5 text-sm transition-all duration-100 flex items-center"
                    style={{
                      background:
                        state.language === lang.code ? "#dc2626" : "transparent",
                      color: state.language === lang.code ? "#fff" : "#d1d5db",
                      borderLeft:
                        state.language === lang.code
                          ? "3px solid rgba(255,255,255,0.3)"
                          : "3px solid transparent",
                    }}
                    onMouseEnter={e => {
                      if (state.language !== lang.code)
                        (e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.05)";
                    }}
                    onMouseLeave={e => {
                      if (state.language !== lang.code)
                        (e.currentTarget as HTMLButtonElement).style.background = "transparent";
                    }}
                  >
                    {lang.name}
                  </button>
                ))}
              </div>
            </div>

            {/* Divider */}
            <div style={{ background: "rgba(255,255,255,0.06)" }} />

            {/* Right: selected language info */}
            <div className="flex flex-col items-center justify-center p-8 text-center">
              <div
                className="w-16 h-16 rounded-full flex items-center justify-center mb-4"
                style={{ background: "rgba(220,38,38,0.12)", border: "1px solid rgba(220,38,38,0.25)" }}
              >
                <GlobeIcon size={30} color="#dc2626" />
              </div>
              <div className="text-lg font-semibold text-white mb-2">{selected.name}</div>
              <p className="text-sm" style={{ color: "#9ca3af" }}>
                El idioma seleccionado será utilizado durante todo el proceso de instalación.
              </p>

              {/* World map */}
              <div className="mt-4 w-full">
                <img
                  src={worldMapImg}
                  alt="Mapa mundial"
                  className="w-full object-contain"
                  style={{ opacity: 0.9, transform: "scale(1.15)", transformOrigin: "center center" }}
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <BottomBar onCancel={onCancel} />
    </div>
  );
}
