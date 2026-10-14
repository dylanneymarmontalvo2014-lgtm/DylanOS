# DylanOS Installer

Instalador oficial de DylanOS: la interfaz del prototipo Figma (React + Vite +
Tailwind CSS v4) funcionando sobre un backend REST propio que instala el
sistema de verdad.

## Overview

The DylanOS Installer provides a step-by-step installation wizard with the following screens:

1. **Welcome** — Introduction and feature highlights
2. **Language** — System language selection with search
3. **Keyboard** — Keyboard layout, variant, and model selection with a live virtual keyboard tester
4. **Partitioning** — Disk partitioning (automatic or manual)
5. **User Creation** — Account setup with password strength validation
6. **Summary** — Configuration review before installation begins
7. **Installation** — Simulated installation progress with stage tracking
8. **Finish** — Completion screen with reboot option

## Project Structure

```
src/
├── screens/       # One subfolder per installer screen
├── components/    # Shared UI components
├── data/          # Mock data split by domain
├── state/         # Global installer state (React context + useReducer)
├── services/      # Business logic (simulated installation)
├── assets/        # Static assets (logos, backgrounds, illustrations)
└── styles/        # CSS split by concern (colors, typography, spacing, borders, effects)
```

## Development

The dev server runs on `$PORT` (default 8443) via Vite. Hot reload is enabled.

```bash
pnpm run dev
pnpm run build
```

## Notes

El backend (`backend/server.py`) expone `/api/system-info`, `/api/disks`,
`/api/locales`, `/api/apply-keyboard`, `/api/validate-user`, `/api/install`,
`/api/install/status`, `/api/reboot` y `/api/quit`. La instalación real
(particionado con parted, extracción del squashfs con progreso medido,
usuarios, locale, teclado, GRUB) solo se ejecuta cuando el backend corre como
root sobre un disco real; en caso contrario funciona en modo vista previa sin
escribir nada. Los catálogos de `src/data/` actúan como respaldo si el backend
no responde.
