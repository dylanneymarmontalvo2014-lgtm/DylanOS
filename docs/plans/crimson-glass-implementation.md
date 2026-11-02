# Crimson Glass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrar Crimson Glass como perfil visual global, reversible y configurable desde DylanOS Configuration.

**Architecture:** `CrimsonGlassService` conserva preferencias propias, detecta capacidades y coordina adaptadores KWin, Plasma, Qt y GTK sin daemon residente. Un tema Plasma/Aurorae Glass aporta el material visual; la página QML muestra controles reales y el estado efectivo con degradación segura.

**Tech Stack:** C++17, Qt 6 Core/Gui/QML/DBus/Test, QML, KWin 6.3.6, Plasma 6, SVG, GTK CSS, Python unittest para staging.

**Spec:** `docs/design/crimson-glass.md`

## Global Constraints

- Mantener negro `#0A0A0A`, Crimson `#DC143C`, blanco `#FFFFFF` y reflejo `#ff5274`.
- No crear otro centro de configuración ni un daemon permanente.
- No inyectar código en aplicaciones de terceros ni forzar transparencia que vuelva ilegible una ventana.
- Aplicar cambios con permisos de usuario y conservar por clave la configuración anterior.
- Mantener X11 y Wayland; el live debe seguir funcionando sin aceleración gráfica.
- Toda UI y comentario nuevo debe estar en español.
- No modificar `previews/`, documentación histórica, `.superpowers/` ni `.claude/worktrees/`.

## Review Focus

- Valor persistido corrupto o fuera de rango: debe volver a un valor seguro y nunca escribir una clave inválida de KWin.
- KWin/D-Bus ausente: debe persistir, informar “se aplicará al iniciar sesión” y finalizar sin error fatal.
- Renderizado `llvmpipe`/software: debe desactivar blur/contraste efectivos aunque el usuario los haya solicitado.
- Respaldo de una clave originalmente ausente: restaurar debe eliminar solo esa clave, no el fichero ni otros cambios.
- Repetir staging/aplicar/restaurar: debe ser idempotente y no crear duplicados o degradar el tema.

---

### Task 1: Núcleo persistente y validado

**Files:**
- Create: `apps/dylanos-configuration/src/services/CrimsonGlassService.h`
- Create: `apps/dylanos-configuration/src/services/CrimsonGlassService.cpp`
- Create: `apps/dylanos-configuration/tests/tst_crimsonglass.cpp`
- Modify: `apps/dylanos-configuration/CMakeLists.txt`

**Interfaces:**
- Produces: `CrimsonGlassService(QObject*)`, properties `settings`, `capabilities`, `effectiveEffects`, `lastMessage`; invocables `setOption(QString,QVariant)`, `apply()`, `restorePrevious()`, `resetDefaults()`, `detectCapabilities()`.

- [x] **Step 1: Write failing QtTest cases**

Add tests named `defaultsAreComplete`, `invalidValuesAreRejected`, `settingsPersist`, `softwareRenderingDegradesSafely` and `restoreRemovesOriginallyMissingKey`. Redirect all XDG paths with `DYLANOS_CRIMSON_TEST_ROOT`.

- [x] **Step 2: Run the test target and confirm failure**

Run: `cmake -S apps/dylanos-configuration -B /tmp/dylanos-config-test -GNinja -DBUILD_TESTING=ON && cmake --build /tmp/dylanos-config-test --target tst_crimsonglass`

Expected: FAIL because `CrimsonGlassService` does not exist.

- [x] **Step 3: Implement persistence, validation, capability calculation and key-level backup**

Defaults: enabled `true`, global effects `true`, glass `72`, transparency `68`, blur `70`, reflections `64`, shadows `66`, radius `18`, accent `#DC143C`, mode `automatic`, panel `72`, dock `78`, menus `70`, window effects/background blur/animations/extras `true`, duration `180`, low power `false`, autodetect `true`.

- [x] **Step 4: Run QtTest**

Run: `ctest --test-dir /tmp/dylanos-config-test --output-on-failure -R crimsonglass`

Expected: PASS.

### Task 2: Adaptadores KWin, Plasma y toolkits

**Files:**
- Modify: `apps/dylanos-configuration/src/services/CrimsonGlassService.cpp`
- Modify: `apps/dylanos-configuration/tests/tst_crimsonglass.cpp`

**Interfaces:**
- Consumes: service API from Task 1.
- Produces: actual `apply()` and `restorePrevious()` mappings plus D-Bus reload helpers.

- [x] **Step 1: Add failing tests for exact KWin and toolkit mappings**

Assert `[Effect-blur] BlurStrength` maps 0–100 to 1–15, low power writes `blurEnabled=false`, durations map to `Effect-glide/Duration` and GTK mode writes both GTK 3/4 settings. Assert a second apply is idempotent.

- [x] **Step 2: Run QtTest and confirm mapping failures**

Run: `ctest --test-dir /tmp/dylanos-config-test --output-on-failure -R crimsonglass`

Expected: FAIL on missing applied keys.

- [x] **Step 3: Implement adapters and live reload**

Write only documented KWin 6.3.6 keys, switch Plasma theme, set accent/mode/GTK preferences, update panel opacity through `org.kde.PlasmaShell.evaluateScript`, and reconfigure KWin effects through session D-Bus. In test-root mode skip D-Bus.

- [x] **Step 4: Run QtTest**

Expected: PASS with the command from Step 2.

### Task 3: Recursos Crimson Glass y staging

**Files:**
- Create: `themes/plasma/DylanOS-Crimson-Glass/metadata.json`
- Create: `themes/plasma/DylanOS-Crimson-Glass/metadata.desktop`
- Create: `themes/plasma/DylanOS-Crimson-Glass/{widgets,translucent/widgets,dialogs,translucent/dialogs}/...`
- Create: `themes/aurorae/DylanOS-Crimson-Glass/*`
- Modify: `scripts/stage.py`
- Modify: `configs/plasma/skel/kwinrc`
- Modify: `scripts/tests/test_staging.py`

**Interfaces:**
- Produces: installed theme ids `DylanOS-Crimson-Glass` and `__aurorae__svg__DylanOS-Crimson-Glass`; autostart `org.dylanos.crimsonglass.desktop`.

- [x] **Step 1: Add failing staging assertions**

Assert the two themes, SVG element ids, default KWin plugins and headless autostart command exist after staging and remain unchanged on a second stage.

- [x] **Step 2: Run staging test and confirm failure**

Run: `.venv/bin/python -m unittest scripts.tests.test_staging.StagingTests.test_stage_into_root`

Expected: FAIL on missing Glass resources.

- [x] **Step 3: Add Glass themes and staging copies**

Use original resources with dark translucent fill, Crimson active border, white top specular line and safe opaque fallback; do not replace the base theme.

- [x] **Step 4: Run staging and SVG tests**

Run: `.venv/bin/python -m unittest scripts.tests.test_staging`

Expected: PASS.

### Task 4: Página funcional en DylanOS Configuration

**Files:**
- Create: `apps/dylanos-configuration/qml/pages/CrimsonGlassPage.qml`
- Create: `apps/dylanos-configuration/qml/components/GlassPreview.qml`
- Modify: `apps/dylanos-configuration/qml/Main.qml`
- Modify: `apps/dylanos-configuration/qml/pages/PersonalizationPage.qml`
- Modify: `apps/dylanos-configuration/qml/theme/Theme.qml`
- Modify: `apps/dylanos-configuration/src/main.cpp`
- Modify: `apps/dylanos-configuration/CMakeLists.txt`
- Modify: `scripts/tests/test_configuration.py`

**Interfaces:**
- Consumes: `CrimsonGlass` context object from Task 1.
- Produces: route `crimson-glass`, CLI `--page crimson-glass` and `--apply-crimson-glass --headless`.

- [x] **Step 1: Add failing static/QML contract tests**

Assert the route, search entries, Personalization entry point, all requested controls, capability labels and restore actions are present and no control is marked as demo.

- [x] **Step 2: Run configuration tests and confirm failure**

Run: `.venv/bin/python -m unittest scripts.tests.test_configuration`

Expected: FAIL on missing page and service registration.

- [x] **Step 3: Implement route, page and preview**

Group controls as General, Efectos, Compatibilidad and Recuperación. Apply sliders with a 160 ms debounce and show `effectiveEffects` separately from requested settings.

- [x] **Step 4: Build and smoke-test QML**

Run: `cmake --build /tmp/dylanos-config-test && QT_QPA_PLATFORM=offscreen /tmp/dylanos-config-test/dylanos-configuration --page crimson-glass --smoke`

Expected: exit 0 and empty stderr.

### Task 5: Adaptación visual de aplicaciones propias y GTK

**Files:**
- Modify: `apps/dylanos-configuration/qml/components/DToggle.qml`
- Modify: `apps/dylanos-configuration/qml/components/DSlider.qml`
- Modify: `apps/dylanos-configuration/qml/components/DSelect.qml`
- Modify: `themes/gtk/DylanOS-Crimson/gtk-3.0/gtk.css`
- Modify: `themes/gtk/DylanOS-Crimson/gtk-4.0/gtk.css`
- Modify: light variants only where the same selector exists.

**Interfaces:**
- Consumes: Theme glass tokens and duration from Task 4.
- Produces: specular borders, safe translucency and short control motion.

- [ ] **Step 1: Add visual-contract assertions**

Extend configuration/theme tests to require explicit glass border, safe minimum opacity and reduced-motion duration path.

- [ ] **Step 2: Run tests and confirm failure**

Run: `.venv/bin/python -m unittest scripts.tests.test_configuration scripts.tests.test_staging`

- [ ] **Step 3: Implement component and GTK polish**

Keep text surfaces opaque enough for WCAG contrast; animate only transform/position/color for 120–180 ms.

- [ ] **Step 4: Render the page**

Run: `QT_QPA_PLATFORM=offscreen /tmp/dylanos-config-test/dylanos-configuration --page crimson-glass --screenshot /tmp/crimson-glass.png --size 1280x800`

Expected: 1280×800 non-empty image and empty stderr.

### Task 6: Documentación, QA y límites comprobados

**Files:**
- Modify: `docs/architecture.md`
- Modify: `apps/dylanos-configuration/README.md`
- Create: `docs/crimson-glass.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: all implemented behavior and test results.
- Produces: installation/configuration/recovery/compatibility documentation without untested claims.

- [ ] **Step 1: Document architecture, settings, recovery and compatibility matrix**

Mark X11/Wayland compositor rendering as requiring QEMU/manual verification and distinguish tested static/offscreen behavior.

- [ ] **Step 2: Run focused tests**

Run: `.venv/bin/python -m unittest scripts.tests.test_configuration scripts.tests.test_staging scripts.tests.test_desktop`

Expected: PASS.

- [ ] **Step 3: Run repository QA**

Run: `DYLANOS_PYTHON="$PWD/.venv/bin/python" bash scripts/check.sh`

Expected: exit 0.

- [ ] **Step 4: Rebuild/test in the Debian 13 chroot**

Run the Configuration CMake build and `ctest` in `work/chroot`; then execute the 16 existing page captures plus `crimson-glass`.

Expected: all tests pass; every screenshot is non-empty; stderr contains no QML ReferenceError/TypeError.

- [ ] **Step 5: Record only executed results**

Update `docs/crimson-glass.md` with commands and outcomes. Leave compositor/QEMU items explicitly pending if no graphical session was run.
