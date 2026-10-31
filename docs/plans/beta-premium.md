# DylanOS Beta Premium Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar una beta coherente y verificable con escritorio limpio, acciones universales de ventana, dock Crimson fluido, Flatpak funcional y aplicaciones DylanOS con ventanas propias.

**Architecture:** Mantener Plasma 6, KWin y las aplicaciones Qt/QML existentes. El shell seguirá compuesto por plasmoides pequeños; el dashboard dejará de enviarse, el applet de aplicación activa concentrará acciones KWin y la Store conservará libdiscover como única capa de paquetes.

**Tech Stack:** Debian 13, KDE Plasma 6, Qt 6.8/QML, KWin TaskManager, libdiscover, PackageKit, Flatpak y SDDM.

**Spec:** Solicitud del usuario del 31 de octubre de 2026 y `AGENTS.md` del repositorio.

## Global Constraints

- Mantener DylanOS Explorer, Configuration, Store, Calculator y Console como aplicaciones oficiales únicas.
- No mostrar Discover, Dolphin, KCalc, Konsole ni centros de configuración alternativos.
- Usar colores oficiales de `branding/colors/dylanos.conf`; colores QML de ocho dígitos en formato `#AARRGGBB`.
- Las acciones deben ejecutar operaciones reales; no se permiten controles simulados.
- Preservar `previews/`, documentos históricos y `.claude/worktrees/`.
- Conservar y extender los cambios locales existentes del usuario.

## Review Focus

- Perfil nuevo y chroot reutilizado: el dashboard no aparece ni sobrevive de un staging anterior.
- Aplicación sin capacidades KWin: los botones se muestran, pero quedan desactivados sin provocar errores.
- Aplicación activa con nombre o `app_id` incompleto: la barra conserva un nombre humano y las acciones correctas.
- Dock con tamaños configurados al límite: la ampliación no recorta iconos ni cambia el ancho por fotograma.
- Store sin red o sin Flathub: PackageKit sigue funcionando y Flatpak informa el estado real.

---

### Task 1: Escritorio limpio y tema de iconos

**Files:**
- Modify: `themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js`
- Modify: `scripts/stage.py`
- Create: `themes/icons/DylanIcons-Crimson/index.theme`
- Modify: `configs/plasma/skel/kdeglobals`
- Modify: `themes/lookandfeel/org.dylanos.crimson/contents/defaults`
- Modify: `packages/default/packages.list`
- Test: `scripts/tests/test_desktop.py`
- Test: `scripts/tests/test_staging.py`
- Test: `scripts/tests/test_packages.sh`

**Interfaces:**
- Consumes: layout Plasma y staging idempotente existentes.
- Produces: perfiles nuevos sin dashboard y `Theme=DylanIcons-Crimson` respaldado por `papirus-icon-theme`.

- [ ] Escribir pruebas que exijan cero widgets de dashboard, limpieza idempotente y tema DylanIcons.
- [ ] Ejecutar las pruebas y confirmar el fallo esperado.
- [ ] Retirar el dashboard del layout/staging y añadir el tema heredado de ePapirus.
- [ ] Ejecutar las pruebas específicas y confirmar que pasan.

### Task 2: Acciones universales en la barra superior

**Files:**
- Modify: `apps/com.dylanos.activeapp/contents/ui/main.qml`
- Modify: `apps/com.dylanos.activeapp/README.md`
- Test: `scripts/tests/test_activeapp_logic.js`
- Test: `scripts/tests/test_plasmoid_runtime.sh`

**Interfaces:**
- Consumes: `TaskManager.TasksModel` y el índice de la ventana activa.
- Produces: nueva instancia, minimizar, maximizar/restaurar, mantener encima, menú contextual y cerrar.

- [ ] Añadir una prueba de contrato para las cinco acciones directas y nombres accesibles.
- [ ] Ejecutarla y confirmar que falta nueva instancia/mantener encima directo.
- [ ] Implementar los controles con estado habilitado real y respuesta inmediata.
- [ ] Cargar el plasmoide en el runtime Plasma del chroot.

### Task 3: Dock premium y ampliación eficiente

**Files:**
- Modify: `apps/com.dylanos.dock/contents/ui/main.qml`
- Modify: `apps/com.dylanos.dock/contents/ui/DockItemDelegate.qml`
- Modify: `apps/com.dylanos.dock/contents/config/main.xml`
- Test: `scripts/tests/test_staging.py`
- Test: `scripts/tests/test_plasmoid_runtime.sh`

**Interfaces:**
- Consumes: modelo real de tareas y preferencias del plasmoide.
- Produces: dock negro compacto, indicador Crimson y ampliación por `scale` de icono y vecinos.

- [ ] Fijar en pruebas los límites de tamaño, indicador y rutas de lanzamiento válidas.
- [ ] Confirmar el fallo antes de cambiar el QML.
- [ ] Afinar geometría, material, animación y estados de presión/foco.
- [ ] Verificar carga QML y layout del panel.

### Task 4: Flatpak completo en DylanOS Store

**Files:**
- Modify: `scripts/build.sh`
- Modify: `scripts/tests/test_store.py`
- Modify: `scripts/tests/test_packages.sh`

**Interfaces:**
- Consumes: backend Flatpak de libdiscover ya compilado y paquete `flatpak`.
- Produces: remoto de sistema Flathub configurado idempotentemente durante la construcción.

- [ ] Escribir una prueba que exija `remote-add --system --if-not-exists`.
- [ ] Confirmar el fallo esperado.
- [ ] Añadir Flathub al chroot sin sustituir PackageKit.
- [ ] Ejecutar pruebas de Store y paquetes.

### Task 5: App Center superpuesto y acabado compartido

**Files:**
- Modify: `apps/dylanos-app-center/qml/Main.qml`
- Modify: `apps/dylanos-app-center/src/main.cpp`
- Review: `apps/dylanos-explorer/qml/Main.qml`
- Review: `apps/dylanos-configuration/qml/Main.qml`
- Review: `apps/calculator/qml/Main.qml`
- Test: `scripts/tests/test_app_center_ui.py`
- Test: `scripts/tests/test_explorer.py`
- Test: `scripts/tests/test_configuration.py`

**Interfaces:**
- Consumes: patrón frameless de DylanOS y `setDesktopFileName` canónico.
- Produces: App Center como superposición fullscreen sin semáforos; auditoría de identidad de las demás apps.

- [ ] Añadir pruebas de visibilidad fullscreen y ausencia de controles de ventana.
- [ ] Confirmar el fallo de la ventana Windowed con semáforos.
- [ ] Convertir App Center en una superposición fullscreen con búsqueda accesible.
- [ ] Verificar capturas offscreen y aparición del nombre de Explorer.

### Task 6: SDDM y validación de beta

**Files:**
- Review: `themes/sddm/DylanOS-Crimson/Main.qml`
- Review: `themes/sddm/DylanOS-Crimson/theme.conf`
- Test: `scripts/tests/test_sddm_theme.py`
- Test: `scripts/check.sh`

**Interfaces:**
- Consumes: `userModel`, AccountsService y métodos reales de SDDM.
- Produces: pantalla de acceso fiel a la referencia con wallpaper predeterminado, avatar real y contraseña real.

- [ ] Ejecutar el contrato SDDM actual y capturar cualquier diferencia real.
- [ ] Corregir solo diferencias comprobadas, con prueba fallando primero.
- [ ] Renderizar el greeter offscreen sin fallback, ReferenceError ni TypeError.
- [ ] Ejecutar `DYLANOS_PYTHON="$PWD/.venv/bin/python" bash scripts/check.sh` y reportar cualquier limitación del chroot.
