import { useState, useRef, useEffect } from "react";
import BottomBar from "@/components/BottomBar";
import { KeyboardIcon, ChevronDownIcon } from "@/components/Icons";
import { keyboardLayouts, keyboardVariants, keyboardModels } from "@/data/mockKeyboards";
import { useInstaller } from "@/state/installerState";
import StatusNotice from "@/components/StatusNotice";

// La distribución elegida se aplica en vivo vía /api/apply-keyboard y queda
// registrada en /etc/default/keyboard del sistema instalado.

interface KeyboardScreenProps {
  onCancel: () => void;
}

interface KeyDef {
  label: string;
  value: string;
  width?: number;
  action?: "backspace" | "space" | "caps" | "shift";
}

const row0: KeyDef[] = [
  { label: "`", value: "`" }, { label: "1", value: "1" }, { label: "2", value: "2" },
  { label: "3", value: "3" }, { label: "4", value: "4" }, { label: "5", value: "5" },
  { label: "6", value: "6" }, { label: "7", value: "7" }, { label: "8", value: "8" },
  { label: "9", value: "9" }, { label: "0", value: "0" }, { label: "-", value: "-" },
  { label: "=", value: "=" }, { label: "⌫", value: "", action: "backspace", width: 1.6 },
];
const row1: KeyDef[] = [
  { label: "Tab", value: "\t", width: 1.5 },
  { label: "q", value: "q" }, { label: "w", value: "w" }, { label: "e", value: "e" },
  { label: "r", value: "r" }, { label: "t", value: "t" }, { label: "y", value: "y" },
  { label: "u", value: "u" }, { label: "i", value: "i" }, { label: "o", value: "o" },
  { label: "p", value: "p" }, { label: "[", value: "[" }, { label: "]", value: "]" },
  { label: "\\", value: "\\" },
];
const row2: KeyDef[] = [
  { label: "Caps", value: "", action: "caps", width: 1.8 },
  { label: "a", value: "a" }, { label: "s", value: "s" }, { label: "d", value: "d" },
  { label: "f", value: "f" }, { label: "g", value: "g" }, { label: "h", value: "h" },
  { label: "j", value: "j" }, { label: "k", value: "k" }, { label: "l", value: "l" },
  { label: "ñ", value: "ñ" }, { label: ";", value: ";" }, { label: "'", value: "'" },
  { label: "↵", value: "\n", width: 1.8 },
];
const row3: KeyDef[] = [
  { label: "⇧", value: "", action: "shift", width: 2.4 },
  { label: "z", value: "z" }, { label: "x", value: "x" }, { label: "c", value: "c" },
  { label: "v", value: "v" }, { label: "b", value: "b" }, { label: "n", value: "n" },
  { label: "m", value: "m" }, { label: ",", value: "," }, { label: ".", value: "." },
  { label: "/", value: "/" }, { label: "⇧", value: "", action: "shift", width: 2.4 },
];
const row4: KeyDef[] = [
  { label: "Ctrl", value: "", width: 1.4 }, { label: "Alt", value: "", width: 1.2 },
  { label: " ", value: " ", action: "space", width: 7 },
  { label: "Alt", value: "", width: 1.2 }, { label: "Ctrl", value: "", width: 1.4 },
];

const allRows = [row0, row1, row2, row3, row4];

const shiftMap: Record<string, string> = {
  "`":"~","1":"!","2":"@","3":"#","4":"$","5":"%","6":"^","7":"&","8":"*","9":"(","0":")","-":"_","=":"+",
  "[":"{","]":"}","\\":"|",";":":","'":"\"",",":"<",".":">","/":"?",
};

export default function KeyboardScreen({ onCancel }: KeyboardScreenProps) {
  const { state, dispatch } = useInstaller();
  const [modelOpen, setModelOpen] = useState(false);
  const [variantOpen, setVariantOpen] = useState(false);
  const [testText, setTestText] = useState("");
  const [caps, setCaps] = useState(false);
  const [shift, setShift] = useState(false);
  const [pressedKey, setPressedKey] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const currentVariants =
    keyboardVariants[state.keyboard.layout] ?? keyboardVariants["default"] ?? [state.keyboard.layout];

  const isUpper = caps !== shift;

  function handleVirtualKey(key: KeyDef) {
    if (key.action === "backspace") {
      setTestText(t => t.slice(0, -1));
    } else if (key.action === "caps") {
      setCaps(c => !c);
    } else if (key.action === "shift") {
      setShift(s => !s);
    } else if (key.value) {
      let ch = key.value;
      if (ch.length === 1) {
        if (isUpper && ch.match(/[a-z]/)) ch = ch.toUpperCase();
        else if (shift && shiftMap[ch]) ch = shiftMap[ch];
      }
      setTestText(t => t + ch);
      if (shift) setShift(false);
    }
    setPressedKey(key.label);
    setTimeout(() => setPressedKey(null), 120);
    inputRef.current?.focus();
  }

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      setPressedKey(e.key.toLowerCase());
      setTimeout(() => setPressedKey(null), 120);
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  // Aplica la distribución seleccionada al X del medio live (prueba real).
  useEffect(() => {
    fetch("/api/apply-keyboard", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        layout: state.keyboard.layout,
        variant: state.keyboard.variant,
        model: state.keyboard.model,
      }),
    }).catch(() => {});
  }, [state.keyboard.layout, state.keyboard.variant, state.keyboard.model]);

  function keyIsActive(key: KeyDef) {
    if (key.action === "caps" && caps) return true;
    if (key.action === "shift" && shift) return true;
    return false;
  }

  function keyDisplay(key: KeyDef) {
    if (!key.value || key.value.length !== 1) return key.label;
    if (isUpper && key.value.match(/[a-z]/)) return key.value.toUpperCase();
    if (shift && shiftMap[key.value]) return shiftMap[key.value];
    return key.label;
  }

  return (
    <div className="flex flex-col h-full screen-enter">
      <div className="flex-1 overflow-y-auto px-6 pt-8 pb-4">
        {/* Header */}
        <div className="flex items-start justify-between mb-5">
          <div>
            <h1 className="text-2xl font-bold text-white">Teclado</h1>
            <p className="text-sm mt-1" style={{ color: "#9ca3af" }}>
              Selecciona la distribución de teclado que mejor se adapte a tu configuración.
            </p>
          </div>
          <div
            className="w-14 h-14 rounded-xl flex items-center justify-center shrink-0"
            style={{ background: "rgba(220,38,38,0.1)", border: "1px solid rgba(220,38,38,0.2)" }}
          >
            <KeyboardIcon size={28} color="#dc2626" />
          </div>
        </div>

        {state.keyboardInvalid && <div className="mb-4"><StatusNotice title="Configuración de teclado inválida">Selecciona un modelo y una distribución compatibles para continuar.</StatusNotice></div>}

        {/* Model + Variant dropdowns */}
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div>
            <label className="text-xs font-medium mb-1.5 block" style={{ color: "#9ca3af" }}>
              Modelo de teclado:
            </label>
            <div className="relative">
              <button
                onClick={() => { setModelOpen(o => !o); setVariantOpen(false); }}
                className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-sm text-left"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)", color: "#d1d5db" }}
              >
                <span className="truncate">{state.keyboard.model}</span>
                <ChevronDownIcon size={14} color="#9ca3af" />
              </button>
              {modelOpen && (
                <div
                  className="absolute top-full left-0 right-0 mt-1 rounded-lg overflow-hidden z-40"
                  style={{ background: "#1a1a1a", border: "1px solid rgba(255,255,255,0.1)", maxHeight: 200, overflowY: "auto", boxShadow: "0 8px 24px rgba(0,0,0,0.5)" }}
                >
                  {keyboardModels.map(m => (
                    <button key={m}
                      onClick={() => { dispatch({ type: "SET_KEYBOARD", layout: state.keyboard.layout, variant: state.keyboard.variant, model: m }); setModelOpen(false); }}
                      className="w-full text-left px-4 py-2.5 text-sm"
                      style={{ background: state.keyboard.model === m ? "rgba(220,38,38,0.15)" : "transparent", color: state.keyboard.model === m ? "#ef4444" : "#d1d5db" }}
                      onMouseEnter={e => { if (state.keyboard.model !== m) (e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.05)"; }}
                      onMouseLeave={e => { if (state.keyboard.model !== m) (e.currentTarget as HTMLButtonElement).style.background = "transparent"; }}
                    >{m}</button>
                  ))}
                </div>
              )}
            </div>
          </div>

          <div>
            <label className="text-xs font-medium mb-1.5 block" style={{ color: "#9ca3af" }}>Variante:</label>
            <div className="relative">
              <button
                onClick={() => { setVariantOpen(o => !o); setModelOpen(false); }}
                className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-sm text-left"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)", color: "#d1d5db" }}
              >
                <span className="truncate">{state.keyboard.variant}</span>
                <ChevronDownIcon size={14} color="#9ca3af" />
              </button>
              {variantOpen && (
                <div
                  className="absolute top-full left-0 right-0 mt-1 rounded-lg overflow-hidden z-40"
                  style={{ background: "#1a1a1a", border: "1px solid rgba(255,255,255,0.1)", maxHeight: 200, overflowY: "auto", boxShadow: "0 8px 24px rgba(0,0,0,0.5)" }}
                >
                  {currentVariants.map(v => (
                    <button key={v}
                      onClick={() => { dispatch({ type: "SET_KEYBOARD", layout: state.keyboard.layout, variant: v, model: state.keyboard.model }); setVariantOpen(false); }}
                      className="w-full text-left px-4 py-2.5 text-sm"
                      style={{ background: state.keyboard.variant === v ? "#dc2626" : "transparent", color: state.keyboard.variant === v ? "#fff" : "#d1d5db" }}
                      onMouseEnter={e => { if (state.keyboard.variant !== v) (e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.05)"; }}
                      onMouseLeave={e => { if (state.keyboard.variant !== v) (e.currentTarget as HTMLButtonElement).style.background = "transparent"; }}
                    >{v}</button>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Distribution + Variants two-column */}
        <div className="rounded-xl mb-4 overflow-hidden" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
          <div className="grid" style={{ gridTemplateColumns: "1fr 1px 1fr" }}>
            <div>
              <div className="px-4 py-2 text-xs font-medium" style={{ color: "#6b7280" }}>Distribución:</div>
              <div className="overflow-y-auto" style={{ maxHeight: 160 }}>
                {keyboardLayouts.map(layout => (
                  <button key={layout}
                    onClick={() => { const variants = keyboardVariants[layout] ?? [layout]; dispatch({ type: "SET_KEYBOARD", layout, variant: variants[0], model: state.keyboard.model }); }}
                    className="w-full text-left px-4 py-2 text-sm transition-all"
                    style={{ background: state.keyboard.layout === layout ? "#dc2626" : "transparent", color: state.keyboard.layout === layout ? "#fff" : "#d1d5db" }}
                    onMouseEnter={e => { if (state.keyboard.layout !== layout) (e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.05)"; }}
                    onMouseLeave={e => { if (state.keyboard.layout !== layout) (e.currentTarget as HTMLButtonElement).style.background = "transparent"; }}
                  >{layout}</button>
                ))}
              </div>
            </div>
            <div style={{ background: "rgba(255,255,255,0.06)" }} />
            <div>
              <div className="px-4 py-2 text-xs font-medium" style={{ color: "#6b7280" }}>&nbsp;</div>
              <div className="overflow-y-auto" style={{ maxHeight: 160 }}>
                {currentVariants.map(v => (
                  <button key={v}
                    onClick={() => dispatch({ type: "SET_KEYBOARD", layout: state.keyboard.layout, variant: v, model: state.keyboard.model })}
                    className="w-full text-left px-4 py-2 text-sm transition-all"
                    style={{ background: state.keyboard.variant === v ? "#dc2626" : "transparent", color: state.keyboard.variant === v ? "#fff" : "#d1d5db" }}
                    onMouseEnter={e => { if (state.keyboard.variant !== v) (e.currentTarget as HTMLButtonElement).style.background = "rgba(255,255,255,0.05)"; }}
                    onMouseLeave={e => { if (state.keyboard.variant !== v) (e.currentTarget as HTMLButtonElement).style.background = "transparent"; }}
                  >{v}</button>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Keyboard tester */}
        <div className="mb-2">
          <div className="text-xs font-medium mb-2" style={{ color: "#d1d5db" }}>Prueba tu teclado:</div>

          <div
            className="rounded-xl p-4"
            style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.12)" }}
          >
            <input
              ref={inputRef}
              type="text"
              placeholder="Haz clic en una tecla o escribe aquí…"
              value={testText}
              onChange={e => setTestText(e.target.value)}
              className="w-full rounded-lg px-3 py-2 text-sm font-mono mb-4 outline-none"
              style={{
                background: "rgba(255,255,255,0.05)",
                border: "1px solid rgba(255,255,255,0.1)",
                color: "#d1d5db",
                caretColor: "#dc2626",
              }}
            />

            <div className="flex flex-col gap-1.5">
              {allRows.map((row, ri) => (
                <div key={ri} className="flex gap-1 justify-center">
                  {row.map((key, ki) => {
                    const active = keyIsActive(key);
                    const pressed = pressedKey === key.label.toLowerCase() || pressedKey === key.value.toLowerCase();
                    const isModifier = !!key.action;
                    return (
                      <button
                        key={ki}
                        onMouseDown={e => { e.preventDefault(); handleVirtualKey(key); }}
                        className="flex items-center justify-center rounded-lg text-xs font-mono select-none transition-all duration-75"
                        style={{
                          flex: key.width ?? 1,
                          height: 34,
                          minWidth: 0,
                          fontSize: key.action === "space" ? 11 : 12,
                          background: pressed
                            ? "#dc2626"
                            : active
                            ? "rgba(220,38,38,0.25)"
                            : isModifier
                            ? "rgba(255,255,255,0.08)"
                            : "rgba(255,255,255,0.06)",
                          border: pressed
                            ? "1px solid #dc2626"
                            : active
                            ? "1px solid rgba(220,38,38,0.5)"
                            : "1px solid rgba(255,255,255,0.1)",
                          color: pressed ? "#fff" : active ? "#ef4444" : "#c9cdd4",
                          boxShadow: pressed ? "0 0 8px rgba(220,38,38,0.4)" : "none",
                          cursor: "pointer",
                        }}
                      >
                        {keyDisplay(key)}
                      </button>
                    );
                  })}
                </div>
              ))}
            </div>
          </div>

          <p className="text-xs italic mt-2" style={{ color: "#6b7280" }}>
            Si no puedes escribir aquí, verifica tu conexión de teclado o elige otra distribución.
          </p>
        </div>
      </div>

      <BottomBar onCancel={onCancel} nextDisabled={state.keyboardInvalid} />
    </div>
  );
}
