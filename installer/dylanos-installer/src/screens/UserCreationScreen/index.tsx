import { useState } from "react";
import BottomBar from "@/components/BottomBar";
import { UserIcon, LockIcon, ShieldIcon, MonitorIcon, CheckIcon, XIcon, EyeIcon, EyeOffIcon } from "@/components/Icons";
import { useInstaller } from "@/state/installerState";

// Los datos validados viajan al backend en el POST /api/install; el backend
// crea la cuenta con useradd/chpasswd (claves por stdin) en el sistema instalado.

interface UserCreationScreenProps {
  onCancel: () => void;
}

function passwordStrength(pw: string): { label: string; color: string; bars: number } {
  if (pw.length === 0) return { label: "", color: "", bars: 0 };
  if (pw.length < 6) return { label: "Débil", color: "#ef4444", bars: 1 };
  if (pw.length < 10) return { label: "Media", color: "#f59e0b", bars: 2 };
  if (pw.length < 14 || !/[^a-zA-Z0-9]/.test(pw)) return { label: "Fuerte", color: "#22c55e", bars: 3 };
  return { label: "Muy fuerte", color: "#10b981", bars: 4 };
}

function isValidUsername(u: string) {
  return /^[a-z][a-z0-9_-]{0,30}$/.test(u);
}

function isValidHostname(h: string) {
  return /^[a-zA-Z0-9-]{1,63}$/.test(h);
}

export default function UserCreationScreen({ onCancel }: UserCreationScreenProps) {
  const { state, dispatch } = useInstaller();
  const [fullName, setFullName] = useState(state.user.fullName);
  const [username, setUsername] = useState(state.user.username);
  const [password, setPassword] = useState("");
  const [confirmPw, setConfirmPw] = useState("");
  const [rootPw, setRootPw] = useState("");
  const [hostname, setHostname] = useState(state.user.hostname);
  const [showPw, setShowPw] = useState(false);
  const [showRootPw, setShowRootPw] = useState(false);
  const [attempted, setAttempted] = useState(false);
  const [usernameError, setUsernameError] = useState("");
  const [hostnameError, setHostnameError] = useState("");

  const pwStrength = passwordStrength(password);
  const rootPwStrength = passwordStrength(rootPw);
  const usernameValid = username.length === 0 || isValidUsername(username);
  const passwordsMatch = password.length > 0 && confirmPw.length > 0 && password === confirmPw;
  const passwordsMismatch = confirmPw.length > 0 && password !== confirmPw;
  const hostnameValid = hostname.length === 0 || isValidHostname(hostname);

  const canProceed =
    fullName.trim().length > 0 &&
    isValidUsername(username) &&
    password.length >= 6 &&
    passwordsMatch &&
    rootPw.length >= 6 &&
    isValidHostname(hostname);

  const handleNext = () => {
    setAttempted(true);
    if (!canProceed) return;
    const confirm = () => {
      dispatch({ type: "SET_USER", fullName: fullName.trim(), username, hostname, valid: true, password, rootPassword: rootPw });
      dispatch({ type: "NEXT_STEP" });
    };
    fetch("/api/validate-user", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username, hostname }),
    })
      .then(r => r.json())
      .then(result => {
        if (result && result.ok) {
          confirm();
        } else {
          setUsernameError((result && result.usernameError) || "");
          setHostnameError((result && result.hostnameError) || "");
        }
      })
      .catch(() => confirm());
  };

  const fields = [
    {
      icon: <UserIcon size={18} color="#dc2626" />,
      label: "Nombre completo",
      sub: "Tu nombre real.",
      input: (
        <div className="relative flex-1">
          <input
            type="text"
            className="dylan-input"
            value={fullName}
            onChange={e => setFullName(e.target.value)}
            placeholder="Dylan"
            onBlur={() => setAttempted(true)}
            aria-invalid={attempted && !fullName.trim()}
          />
          {attempted && !fullName.trim() && <div className="dylan-field-error">Introduce tu nombre.</div>}
          {fullName.trim().length > 0 && (
            <div className="absolute right-3 top-1/2 -translate-y-1/2">
              <CheckIcon size={14} color="#22c55e" />
            </div>
          )}
        </div>
      ),
    },
    {
      icon: <UserIcon size={18} color="#dc2626" />,
      label: "Nombre de usuario",
      sub: "El nombre que usarás para iniciar sesión.",
      input: (
        <div className="relative flex-1">
          <input
            type="text"
            className="dylan-input"
            value={username}
            onChange={e => setUsername(e.target.value.toLowerCase())}
            placeholder="dylan"
            onBlur={() => { setAttempted(true); setUsernameError(""); }}
            aria-invalid={attempted && (!username || !isValidUsername(username) || !!usernameError)}
            style={{ borderColor: attempted && (!usernameValid || !!usernameError) ? "#dc2626" : undefined }}
          />
          {attempted && !username && <div className="dylan-field-error">Introduce un nombre de usuario.</div>}
          {usernameError && <div className="dylan-field-error">{usernameError}</div>}
          {attempted && username.length > 0 && !isValidUsername(username) && <div className="dylan-field-error">El nombre de usuario no es válido.</div>}
          {username.length > 0 && (
            <div className="absolute right-3 top-1/2 -translate-y-1/2">
              {isValidUsername(username)
                ? <CheckIcon size={14} color="#22c55e" />
                : <XIcon size={14} color="#dc2626" />}
            </div>
          )}
        </div>
      ),
    },
    {
      icon: <LockIcon size={18} color="#dc2626" />,
      label: "Contraseña de usuario",
      sub: "Elige una contraseña segura.",
      input: (
        <div className="flex-1 space-y-1.5">
          <div className="relative">
            <input
              type={showPw ? "text" : "password"}
              className="dylan-input pr-10"
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="••••••••"
            onBlur={() => setAttempted(true)}
              aria-invalid={attempted && (!password || password.length < 6)}
            />
            <button
              type="button"
              onClick={() => setShowPw(o => !o)}
              className="absolute right-3 top-1/2 -translate-y-1/2"
              style={{ color: "#6b7280" }}
            >
              {showPw ? <EyeOffIcon size={15} /> : <EyeIcon size={15} />}
            </button>
          </div>
          {attempted && !password && <div className="dylan-field-error">Introduce una contraseña.</div>}
          {attempted && password.length > 0 && password.length < 6 && <div className="dylan-field-error">La contraseña es demasiado débil.</div>}
          {password.length > 0 && (
            <div>
              <div className="flex gap-1 mb-1">
                {[1,2,3,4].map(b => (
                  <div key={b} className="h-1 flex-1 rounded-full transition-all" style={{
                    background: b <= pwStrength.bars ? pwStrength.color : "rgba(255,255,255,0.1)",
                  }}/>
                ))}
              </div>
              <div className="text-xs">
                Seguridad: <span style={{ color: pwStrength.color }}>{pwStrength.label}</span>
              </div>
            </div>
          )}
          <div className="relative">
            <input
              type={showPw ? "text" : "password"}
              className="dylan-input pr-10"
              value={confirmPw}
              onChange={e => setConfirmPw(e.target.value)}
              placeholder="Confirmar contraseña"
            onBlur={() => setAttempted(true)}
              aria-invalid={attempted && (!confirmPw || passwordsMismatch)}
              style={{ borderColor: attempted && (passwordsMismatch || !confirmPw) ? "#dc2626" : undefined }}
            />
            {confirmPw.length > 0 && (
              <div className="absolute right-3 top-1/2 -translate-y-1/2">
                {passwordsMatch ? <CheckIcon size={14} color="#22c55e" /> : <XIcon size={14} color="#dc2626" />}
              </div>
            )}
          </div>
          {attempted && !confirmPw && <div className="dylan-field-error">Confirma tu contraseña.</div>}
          {passwordsMismatch && <div className="dylan-field-error">Las contraseñas no coinciden.</div>}
        </div>
      ),
    },
    {
      icon: <ShieldIcon size={18} color="#dc2626" />,
      label: "Contraseña de root",
      sub: "Contraseña para la cuenta de administrador.",
      input: (
        <div className="flex-1 space-y-1.5">
          <div className="relative">
            <input
              type={showRootPw ? "text" : "password"}
              className="dylan-input pr-10"
              value={rootPw}
              onChange={e => setRootPw(e.target.value)}
              placeholder="••••••••"
            onBlur={() => setAttempted(true)}
              aria-invalid={attempted && (!rootPw || rootPw.length < 6)}
            />
            <button
              type="button"
              onClick={() => setShowRootPw(o => !o)}
              className="absolute right-3 top-1/2 -translate-y-1/2"
              style={{ color: "#6b7280" }}
            >
              {showRootPw ? <EyeOffIcon size={15} /> : <EyeIcon size={15} />}
            </button>
          </div>
          {attempted && !rootPw && <div className="dylan-field-error">Introduce la contraseña de root.</div>}
          {attempted && rootPw.length > 0 && rootPw.length < 6 && <div className="dylan-field-error">La contraseña es demasiado débil.</div>}
          {rootPw.length > 0 && (
            <div>
              <div className="flex gap-1 mb-1">
                {[1,2,3,4].map(b => (
                  <div key={b} className="h-1 flex-1 rounded-full transition-all" style={{
                    background: b <= rootPwStrength.bars ? rootPwStrength.color : "rgba(255,255,255,0.1)",
                  }}/>
                ))}
              </div>
              <div className="text-xs">
                Seguridad: <span style={{ color: rootPwStrength.color }}>{rootPwStrength.label}</span>
              </div>
            </div>
          )}
        </div>
      ),
    },
    {
      icon: <MonitorIcon size={18} color="#dc2626" />,
      label: "Nombre de la máquina",
      sub: "Identifica tu equipo en la red.",
      input: (
        <div className="relative flex-1">
          <input
            type="text"
            className="dylan-input"
            value={hostname}
            onChange={e => setHostname(e.target.value)}
            placeholder="DylanOS-PC"
            onBlur={() => { setAttempted(true); setHostnameError(""); }}
            aria-invalid={attempted && (!hostname || !isValidHostname(hostname) || !!hostnameError)}
            style={{ borderColor: attempted && (!hostnameValid || !!hostnameError) ? "#dc2626" : undefined }}
          />
          {hostnameError && <div className="dylan-field-error">{hostnameError}</div>}
          {attempted && (!hostname || !isValidHostname(hostname)) && <div className="dylan-field-error">El nombre de la máquina no es válido.</div>}
          {hostname.length > 0 && (
            <div className="absolute right-3 top-1/2 -translate-y-1/2">
              {isValidHostname(hostname)
                ? <CheckIcon size={14} color="#22c55e" />
                : <XIcon size={14} color="#dc2626" />}
            </div>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="flex flex-col h-full screen-enter">
      <div className="flex-1 overflow-y-auto px-8 pt-8 pb-4">
        {/* Header */}
        <div className="flex items-start justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-white">Usuario</h1>
            <p className="text-sm mt-1" style={{ color: "#9ca3af" }}>
              Crea tu cuenta de usuario y configura el acceso al sistema.
              <br />
              Necesitarás esta información para iniciar sesión en tu sistema.
            </p>
          </div>
          <div
            className="w-14 h-14 rounded-xl flex items-center justify-center"
            style={{ background: "rgba(220,38,38,0.1)", border: "1px solid rgba(220,38,38,0.2)" }}
          >
            <UserIcon size={28} color="#dc2626" />
          </div>
        </div>

        {/* Form */}
        <div
          className="rounded-xl p-5 space-y-4"
          style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}
        >
          {fields.map((field, i) => (
            <div
              key={i}
              className="flex items-start gap-4 pb-4"
              style={{
                borderBottom: i < fields.length - 1 ? "1px solid rgba(255,255,255,0.05)" : "none",
              }}
            >
              <div
                className="w-10 h-10 rounded-lg flex items-center justify-center shrink-0 mt-0.5"
                style={{ background: "rgba(220,38,38,0.1)", border: "1px solid rgba(220,38,38,0.15)" }}
              >
                {field.icon}
              </div>

              <div style={{ width: 200, flexShrink: 0 }}>
                <div className="text-sm font-medium text-white">{field.label}</div>
                <div className="text-xs mt-0.5" style={{ color: "#6b7280" }}>{field.sub}</div>
              </div>

              {field.input}
            </div>
          ))}
        </div>
      </div>

      <BottomBar
        onCancel={onCancel}
        nextDisabled={!canProceed}
        onNext={handleNext}
      />
    </div>
  );
}
