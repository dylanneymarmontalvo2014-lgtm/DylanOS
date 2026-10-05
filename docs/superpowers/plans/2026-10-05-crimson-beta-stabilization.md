# Crimson Beta Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Estabilizar DylanOS Crimson 1.0 Beta en `development`, corrigiendo los fallos confirmados de App Center, staging, Archivos, temas, artefactos y QA sin cambiar la arquitectura ni tocar Calamares.

**Architecture:** Se conserva Workspace como implementación productiva de Archivos y `AppModel` como fuente de servicios KDE. App Center pasa de índices internos a `storageId()` estable; `stage.py` sigue siendo el único instalador del payload en un root explícito y adapta solamente los archivos generados en staging.

**Tech Stack:** C++17, Qt 6/QML, KDE Frameworks 6/KIO, CMake/ECM, Python 3, PySide6, Bash, Debian 13 trixie, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-05-crimson-beta-stabilization-design.md`

## Global Constraints

- No modificar archivos bajo `installer/calamares/`.
- No usar `git reset --hard`, `git clean -fd`, force push, `sudo` innecesario ni operaciones sobre discos reales.
- Trabajar exclusivamente en `development`; no modificar `main`.
- Conservar `#DC143C` como acento principal de DylanOS Crimson.
- Mantener `apps/workspace` como implementación real de Archivos.
- Mantener el prototipo antiguo de `apps/archivos/qml` separado y documentado como no productivo.
- No declarar `PASS` si una dependencia impide ejecutar una prueba; usar `NOT RUN` o `WARNING` con la causa.
- Cada commit debe terminar con `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.

## Mapa de archivos y responsabilidades

- `apps/dylanos-app-center/src/appmodel.h/.cpp`: contrato estable para enumerar y lanzar servicios KDE.
- `apps/dylanos-app-center/qml/Main.qml`: consumo QML del identificador `desktopId` y acento Crimson.
- `apps/dylanos-app-center/CMakeLists.txt`: una única instalación del binario, `.desktop` e icono.
- `apps/dylanos-app-center/dylanos-app-center.desktop`: entrada de escritorio portable mediante `PATH`.
- `scripts/tests/test_app_center.py`: pruebas estructurales del contrato de App Center y sus rutas.
- `scripts/stage.py`: copia segura del payload y adaptación de branding generado para staging.
- `scripts/tests/test_staging.py`: seguridad, repetibilidad, contenido y branding del staging.
- `apps/archivos/main.py`: launcher mínimo hacia Workspace, sin código inalcanzable.
- `apps/archivos/README.md`: separación explícita entre producción y prototipo histórico.
- `scripts/tests/test_archivos.py`: prueba de que el launcher no contiene el flujo QML muerto.
- `themes/gtk/DylanOS-Crimson/`: tema GTK instalable para GTK 3 y GTK 4.
- `configs/plasma/skel/gtk-3.0/settings.ini` y `gtk-4.0/settings.ini`: selección inicial del tema GTK.
- `themes/colors/DylanOSDark.colors` y `DylanOSLight.colors`: esquemas KDE con acento Crimson.
- `themes/sddm/DylanOS-Tahoe/Main.qml`: corrección sintáctica del campo de contraseña.
- `apps/calculator/qml/Main.qml` y `icons/com.dylanos.calculator.svg`: acento Crimson de Calculadora.
- `apps/com.dylanos.dock/contents/ui/DockItemDelegate.qml`: acento Crimson del dock.
- `apps/workspace/qml/{ActionButton.qml,Main.qml,SettingsPage.qml}`: acentos principales compartidos.
- `.gitignore`: exclusión explícita de artefactos CMake, Qt, Debian y Python.
- `scripts/check.sh`, workflows y listas de paquetes: ejecución reproducible de QA y dependencias.
- `branding/README.md`, `docs/architecture.md`, `docs/beta-status.md`, `README.md`: documentación final y estado verificable.

---

### Task 1: Migrar App Center a identificadores estables

**Files:**
- Modify: `apps/dylanos-app-center/src/appmodel.h:18`
- Modify: `apps/dylanos-app-center/src/appmodel.cpp:48-79`
- Modify: `apps/dylanos-app-center/qml/Main.qml:14,254-269`
- Modify: `apps/dylanos-app-center/CMakeLists.txt:67-111`
- Modify: `apps/dylanos-app-center/dylanos-app-center.desktop:4`
- Create: `scripts/tests/test_app_center.py`

**Interfaces:**
- Consumes: `KService::storageId()` desde `m_apps`.
- Produces: `Q_INVOKABLE void AppModel::launchApp(const QString &desktopId)` y objetos de página con `name`, `icon` y `desktopId`; CMake instala el binario en `${CMAKE_INSTALL_BINDIR}` una sola vez.

- [ ] **Step 1: Escribir la prueba estructural que inicialmente falla**

Crear `scripts/tests/test_app_center.py` con comprobaciones de contrato y de instalación:

```python
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODEL_H = (ROOT / "apps/dylanos-app-center/src/appmodel.h").read_text()
MODEL_CPP = (ROOT / "apps/dylanos-app-center/src/appmodel.cpp").read_text()
QML = (ROOT / "apps/dylanos-app-center/qml/Main.qml").read_text()
CMAKE = (ROOT / "apps/dylanos-app-center/CMakeLists.txt").read_text()
DESKTOP = (ROOT / "apps/dylanos-app-center/dylanos-app-center.desktop").read_text()


class AppCenterContractTest(unittest.TestCase):
    def test_launch_contract_uses_desktop_id(self):
        self.assertIn("launchApp(const QString &desktopId)", MODEL_H)
        self.assertIn('storageId() == desktopId', MODEL_CPP)
        self.assertNotIn("globalIndex", MODEL_CPP)
        self.assertNotIn("globalIndex", QML)
        self.assertRegex(QML, r"appModel\.launchApp\(\s*modelData\.desktopId\s*\)")

    def test_install_contract_is_not_duplicated(self):
        self.assertEqual(CMAKE.count("install(\n    TARGETS dylanos-app-center"), 1)
        self.assertEqual(CMAKE.count("FILES dylanos-app-center.desktop"), 1)
        self.assertEqual(CMAKE.count("FILES icons/dylanos-app-center.png"), 1)
        self.assertEqual(CMAKE.count("include(GNUInstallDirs)"), 1)

    def test_desktop_uses_path_resolved_executable(self):
        self.assertIn("Exec=dylanos-app-center", DESKTOP)
        self.assertNotIn("/usr/local/bin", DESKTOP)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Ejecutar la prueba y verificar que falla por los defectos conocidos**

Run: `python3 -m unittest discover -s scripts/tests -p 'test_app_center.py' -v`

Expected: FAIL por `launchApp(int index)`, `globalIndex`, las reglas CMake duplicadas y `Exec=/usr/local/bin/dylanos-app-center`.

- [ ] **Step 3: Cambiar el contrato C++ al identificador estable**

En `appmodel.h`, cambiar únicamente la declaración a:

```cpp
Q_INVOKABLE void launchApp(const QString &desktopId);
```

En `itemsForPage()`, conservar `item["desktopId"] = s->storageId();` y eliminar `item["globalIndex"] = m_apps.indexOf(s);`.

Reemplazar `launchApp(int index)` por:

```cpp
void AppModel::launchApp(const QString &desktopId)
{
    if (desktopId.isEmpty())
        return;

    const auto it = std::find_if(m_apps.cbegin(), m_apps.cend(),
                                 [&desktopId](const KService::Ptr &service) {
                                     return service->storageId() == desktopId;
                                 });
    if (it == m_apps.cend())
        return;

    auto *job = new KIO::ApplicationLauncherJob(*it);
    job->setUiDelegate(KIO::createDefaultJobUiDelegate(
        KJobUiDelegate::AutoHandlingEnabled, nullptr));
    job->start();
}
```

Actualizar `setFilter()` para normalizar espacios sin cambiar la semántica de búsqueda:

```cpp
void AppModel::setFilter(const QString &text) { m_filter = text.trimmed(); }
```

- [ ] **Step 4: Actualizar QML, CMake y el `.desktop`**

Cambiar el color principal de App Center a `#DC143C` y sustituir el clic por:

```qml
onClicked: appModel.launchApp(modelData.desktopId)
```

Eliminar desde el segundo `include(GNUInstallDirs)` hasta el final de la sección duplicada de CMake, dejando exactamente una instalación del objetivo, `.desktop` e icono.

Cambiar la entrada de escritorio a:

```ini
Exec=dylanos-app-center
```

- [ ] **Step 5: Ejecutar la prueba contractual**

Run: `python3 -m unittest discover -s scripts/tests -p 'test_app_center.py' -v`

Expected: PASS con tres pruebas.

- [ ] **Step 6: Compilar e instalar App Center en un prefijo temporal**

Run:

```bash
prefix="$(mktemp -d)"
build="$(mktemp -d)"
cmake -S apps/dylanos-app-center -B "$build" -GNinja \
  -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$build" --parallel 2
DESTDIR="$prefix" cmake --install "$build"
test -x "$prefix/usr/bin/dylanos-app-center"
test -f "$prefix/usr/share/applications/dylanos-app-center.desktop"
desktop-file-validate "$prefix/usr/share/applications/dylanos-app-center.desktop"
rm -rf "$build" "$prefix"
```

Expected: binario, `.desktop` e icono instalados sin rutas `/usr/local`; si falta Qt/KF6, registrar `NOT RUN` y continuar con la instalación de dependencias prevista en Task 6.

- [ ] **Step 7: Commit**

```bash
git add apps/dylanos-app-center scripts/tests/test_app_center.py
git commit -m "fix: estabilizar lanzamiento e instalacion del App Center" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Reparar branding y staging sin tocar Calamares fuente

**Files:**
- Modify: `scripts/stage.py:31-47,77-90`
- Modify: `scripts/tests/test_staging.py:19-39`
- Modify: `branding/README.md:7`
- Create: no files under `installer/calamares/`

**Interfaces:**
- Consumes: `branding/logo.png` y `installer/calamares/beta/branding.desc` existentes.
- Produces: icono general PNG en `/usr/share/icons/hicolor/512x512/apps/distributor-logo-dylanos.png`, branding Calamares staged con `logo.png`, y `branding.desc` staged coherente.

- [ ] **Step 1: Cambiar primero las expectativas del test de staging**

En `test_payload_and_repeat_staging`, reemplazar la expectativa del SVG por:

```python
"usr/share/icons/hicolor/512x512/apps/distributor-logo-dylanos.png",
"etc/calamares/branding/dylanos/logo.png",
```

Añadir después de las comprobaciones de rutas:

```python
branding_desc = (root / "etc/calamares/branding/dylanos/branding.desc").read_text()
self.assertIn("productLogo: logo.png", branding_desc)
self.assertIn("productIcon: logo.png", branding_desc)
self.assertNotIn("logo.svg", branding_desc)
```

- [ ] **Step 2: Ejecutar el test y comprobar el fallo por `branding/logo.svg` ausente**

Run: `python3 -m unittest scripts.tests.test_staging -v`

Expected: FAIL antes de completar `stage()` porque la implementación actual intenta copiar `branding/logo.svg`.

- [ ] **Step 3: Hacer que `stage.py` use PNG y adapte solo el destino staged**

En la lista principal reemplazar la entrada SVG por:

```python
("branding/logo.png", "/usr/share/icons/hicolor/512x512/apps/distributor-logo-dylanos.png"),
```

Después de copiar `installer/calamares/beta` y antes de copiar el fondo, usar:

```python
copy("branding/logo.png", "/etc/calamares/branding/dylanos/logo.png")
branding_desc = dest / "etc/calamares/branding/dylanos/branding.desc"
content = branding_desc.read_text(encoding="utf-8")
content = re.sub(r"(?m)^(\s*product(?:Logo|Icon):\s*)logo\.svg\s*$", r"\1logo.png", content)
branding_desc.write_text(content, encoding="utf-8")
```

Eliminar únicamente la llamada staged que copiaba `branding/logo.svg` como `logo.svg`. Mantener intactas las llamadas que copian `installer/calamares/beta`, la configuración de Calamares generada por `stage.py` y el contenido fuente de `installer/calamares/`.

- [ ] **Step 4: Actualizar branding documentado**

En `branding/README.md`, cambiar `#E50914` a `#DC143C` y documentar:

```markdown
El logotipo reutilizable es `branding/logo.png`. El staging lo instala como
icono PNG de hicolor y lo adapta al nombre `logo.png` que declara el branding
beta de Calamares; no se modifica ningún archivo del instalador fuente.
```

- [ ] **Step 5: Ejecutar staging repetible y sus tests**

Run: `python3 -m unittest scripts.tests.test_staging -v`

Expected: PASS, incluyendo rechazo de `/`, del repositorio y del padre del repositorio; dos ejecuciones producen el mismo `kdeglobals` y no alteran `installer/calamares`.

- [ ] **Step 6: Commit**

```bash
git add scripts/stage.py scripts/tests/test_staging.py branding/README.md
git commit -m "fix: reparar branding de staging de la beta" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Eliminar el flujo Python inalcanzable de Archivos

**Files:**
- Modify: `apps/archivos/main.py:1-40`
- Modify: `apps/archivos/README.md:1-19`
- Create: `scripts/tests/test_archivos.py`

**Interfaces:**
- Consumes: `apps/workspace/main.py` mediante `runpy.run_path` y `--page files`.
- Produces: launcher Python sin imports Qt/QML muertos, con el prototipo antiguo claramente no productivo.

- [ ] **Step 1: Escribir prueba de launcher mínimo**

Crear `scripts/tests/test_archivos.py`:

```python
import ast
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "apps/archivos/main.py"


class ArchivosLauncherTest(unittest.TestCase):
    def test_launcher_only_delegates_to_workspace(self):
        text = SOURCE.read_text()
        tree = ast.parse(text)
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
        calls = [node for node in ast.walk(main) if isinstance(node, ast.Call)]
        runpy_calls = [node for node in calls if isinstance(node.func, ast.Attribute) and node.func.attr == "run_path"]
        self.assertEqual(len(runpy_calls), 1)
        self.assertNotIn("QGuiApplication", text)
        self.assertNotIn("QQmlApplicationEngine", text)
        self.assertNotIn("QIcon", text)
        self.assertIn('sys.argv[1:1] = ["--page", "files"]', text)

    def test_prototype_is_explicitly_non_productive(self):
        readme = (ROOT / "apps/archivos/README.md").read_text()
        self.assertIn("prototipo", readme.lower())
        self.assertIn("no es la implementación", readme.lower())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Ejecutar el test y verificar que detecta los imports y el bloque muerto**

Run: `python3 -m unittest discover -s scripts/tests -p 'test_archivos.py' -v`

Expected: FAIL porque `main.py` todavía contiene imports y código después de `return`.

- [ ] **Step 3: Reducir `main.py` a un launcher ejecutable**

Dejar el archivo con esta implementación:

```python
#!/usr/bin/env python3
"""Launcher de Archivos; la implementación real vive en Workspace."""
import runpy
import sys
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent


def main():
    workspace = APP_DIR.parent / "workspace"
    sys.path.insert(0, str(workspace))
    sys.argv[1:1] = ["--page", "files"]
    runpy.run_path(str(workspace / "main.py"), run_name="__main__")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Documentar la separación producción/prototipo**

Mantener el README actual y añadir que `apps/archivos/main.py` no carga
`qml/Main.qml`, que el prototipo conserva datos simulados únicamente como
referencia visual y que cualquier cambio funcional debe hacerse en Workspace.

- [ ] **Step 5: Ejecutar prueba y compileall**

Run: `python3 -m unittest discover -s scripts/tests -p 'test_archivos.py' -v && python3 -m compileall -q apps/archivos apps/workspace`

Expected: PASS y ningún error de sintaxis Python.

- [ ] **Step 6: Commit**

```bash
git add apps/archivos/main.py apps/archivos/README.md scripts/tests/test_archivos.py
git commit -m "fix: eliminar flujo QML inalcanzable de Archivos" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Instalar un tema GTK Crimson real y alinear esquemas

**Files:**
- Delete: `themes/gtk/dylanos-gtk/dylanos-gtk.theme`
- Create: `themes/gtk/DylanOS-Crimson/index.theme`
- Create: `themes/gtk/DylanOS-Crimson/gtk-3.0/gtk.css`
- Create: `themes/gtk/DylanOS-Crimson/gtk-4.0/gtk.css`
- Modify: `configs/plasma/skel/gtk-3.0/settings.ini:2-4`
- Create: `configs/plasma/skel/gtk-4.0/settings.ini`
- Modify: `themes/colors/DylanOSDark.colors` y `themes/colors/DylanOSLight.colors`
- Modify: `scripts/stage.py:31-47`
- Modify: `scripts/tests/test_staging.py:25-33`
- Create: `scripts/tests/test_theme.py`

**Interfaces:**
- Consumes: tokens DylanOS `#DC143C`, `#0A0A0A`, `#1A1A1A`, `#FFFFFF`, `#B3B3B3`.
- Produces: `/usr/share/themes/DylanOS-Crimson/{gtk-3.0,gtk-4.0}/gtk.css`, selección de tema para usuarios nuevos y esquemas KDE sin el azul `10,132,255`.

- [ ] **Step 1: Escribir pruebas de estructura y paleta**

Crear `scripts/tests/test_theme.py`:

```python
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "themes/gtk/DylanOS-Crimson"


class CrimsonThemeTest(unittest.TestCase):
    def test_gtk_theme_has_both_css_targets(self):
        for version in ("gtk-3.0", "gtk-4.0"):
            css = THEME / version / "gtk.css"
            self.assertTrue(css.is_file(), css)
            text = css.read_text()
            self.assertIn("#DC143C", text)
            self.assertIn("#0A0A0A", text)

    def test_theme_metadata_matches_directory(self):
        index = (THEME / "index.theme").read_text()
        self.assertIn("Name=DylanOS Crimson", index)
        self.assertIn("GtkTheme=DylanOS-Crimson", index)

    def test_kde_schemes_no_longer_use_old_blue_accent(self):
        for name in ("DylanOSDark.colors", "DylanOSLight.colors"):
            text = (ROOT / "themes/colors" / name).read_text()
            self.assertNotIn("10,132,255", text)
            self.assertIn("220,20,60", text)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Ejecutar la prueba para confirmar que falta la estructura GTK**

Run: `python3 -m unittest discover -s scripts/tests -p 'test_theme.py' -v`

Expected: FAIL porque solo existe el archivo `.theme` no instalable y los esquemas aún tienen `10,132,255`.

- [ ] **Step 3: Crear metadatos y CSS funcionales**

Crear `index.theme`:

```ini
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=DylanOS Crimson
Comment=Tema GTK de DylanOS Crimson
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=DylanOS-Crimson
IconTheme=Adwaita
```

Crear ambos `gtk.css` con este conjunto mínimo común, ajustando únicamente el
selector de focus si GTK 4 lo requiere:

```css
@define-color theme_fg_color #F5F5F7;
@define-color theme_bg_color #0A0A0A;
@define-color theme_base_color #1A1A1A;
@define-color theme_selected_bg_color #DC143C;
@define-color theme_selected_fg_color #FFFFFF;
@define-color accent_color #DC143C;

window, dialog {
  background-color: @theme_bg_color;
  color: @theme_fg_color;
}

button, entry, spinbutton, combobox, scale trough {
  background-color: @theme_base_color;
  color: @theme_fg_color;
  border-color: #3A3A3C;
}

button:hover, button:focus, entry:focus, combobox:focus {
  border-color: @accent_color;
}

selection, progressbar progress, scale highlight {
  background-color: @theme_selected_bg_color;
  color: @theme_selected_fg_color;
}
```

- [ ] **Step 4: Seleccionar el tema desde el skeleton y staging**

Actualizar `configs/plasma/skel/gtk-3.0/settings.ini` a:

```ini
[Settings]
gtk-theme-name=DylanOS-Crimson
gtk-icon-theme-name=Adwaita
gtk-font-name=Inter 10
gtk-cursor-theme-name=breeze_cursors
gtk-application-prefer-dark-theme=1
```

Crear `configs/plasma/skel/gtk-4.0/settings.ini` con el mismo contenido.

Añadir a la lista de `stage.py`:

```python
("themes/gtk/DylanOS-Crimson", "/usr/share/themes/DylanOS-Crimson"),
```

Actualizar `test_staging.py` para exigir los dos CSS staged.

- [ ] **Step 5: Alinear esquemas KDE y acentos productivos**

Reemplazar únicamente `10,132,255` por `220,20,60` en ambos archivos de
`themes/colors`. Mantener `ForegroundNegative`, `ForegroundNeutral` y
`ForegroundPositive` como estados semánticos.

Cambiar `#e11d2a` por `#DC143C` en:

- `apps/calculator/qml/Main.qml` para `accentRed`.
- `apps/calculator/icons/com.dylanos.calculator.svg` para el gradiente y el borde Crimson.
- `apps/com.dylanos.dock/contents/ui/DockItemDelegate.qml` para hover.
- `apps/dylanos-app-center/qml/Main.qml` para `accent`.

Cambiar los usos de `#e3485b` que representan el acento principal de Workspace
por `#DC143C` en `ActionButton.qml`, `Main.qml` y `SettingsPage.qml`. Mantener
los colores más oscuros o claros usados exclusivamente como estados derivados.
No modificar el prototipo histórico de Archivos ni archivos bajo
`installer/calamares/`.

- [ ] **Step 6: Corregir sintaxis QML de SDDM**

En `themes/sddm/DylanOS-Tahoe/Main.qml`, cambiar:

```qml
selectionColor: #DC143C
```

por:

```qml
selectionColor: "#DC143C"
```

- [ ] **Step 7: Ejecutar pruebas de tema y staging**

Run: `python3 -m unittest discover -s scripts/tests -p 'test_theme.py' -v && python3 -m unittest scripts.tests.test_staging -v`

Expected: PASS; todos los CSS, settings, esquemas y destinos staged existen.

- [ ] **Step 8: Commit**

```bash
git add themes configs apps/calculator apps/com.dylanos.dock apps/dylanos-app-center apps/workspace themes/sddm scripts/stage.py scripts/tests/test_theme.py scripts/tests/test_staging.py
git commit -m "feat: completar tema GTK y paleta Crimson" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Limpiar artefactos y reforzar exclusiones

**Files:**
- Modify: `.gitignore`
- Remove only generated files/directories: `apps/*/build/`, `apps/archivos/.venv/`, `__pycache__/`, `.rcc/`, `.qt/`, `apps/dylanos-app-center/debian/.debhelper/`, `apps/dylanos-app-center/debian/files`, `apps/dylanos-app-center/debian/*.substvars`, `apps/dylanos-app-center/debian/debhelper-build-stamp`

**Interfaces:**
- Consumes: fuentes rastreadas del repositorio.
- Produces: árbol sin artefactos generados y reglas de ignore explícitas, sin eliminar ningún archivo fuente.

- [ ] **Step 1: Inventariar archivos generados rastreados**

Run:

```bash
git ls-files | grep -E '(^|/)(build|__pycache__|\.rcc|\.qt|\.debhelper)(/|$)|(^|/)(CMakeCache\.txt|CMakeFiles|cmake_install\.cmake|.*\.(deb|buildinfo|changes|substvars))$' || true
```

Expected: solo salidas que sean artefactos generados conocidos; no borrar coincidencias que sean fuentes o documentación.

- [ ] **Step 2: Añadir patrones explícitos a `.gitignore`**

Añadir:

```gitignore
# CMake, Ninja y Qt generados
CMakeCache.txt
CMakeFiles/
cmake_install.cmake
.rcc/
.qt/
_autogen/
.ninja_deps
.ninja_log

# Paquetes Debian generados
*.substvars
debian/.debhelper/
debian/debhelper-build-stamp
debian/files

# Entornos y cachés Python
.venv/
__pycache__/
*.py[cod]
```

Conservar los patrones existentes para `build/`, `work/`, ISO y artefactos.

- [ ] **Step 3: Eliminar artefactos solo de las rutas conocidas**

Usar un script Python temporal en `$CLAUDE_JOB_DIR/tmp` que quite directorios
`build`, `.venv`, `__pycache__`, `.rcc`, `.qt` bajo `apps/` y `scripts/`, y
archivos Debian generados bajo `apps/*/debian`; no recorrer `/`, `work/chroot`
ni rutas fuera del repositorio. Verificar con `git status --short` que no se
borró ninguna fuente.

- [ ] **Step 4: Verificar que las fuentes siguen presentes**

Run:

```bash
test -f apps/workspace/main.py
test -f apps/dylanos-app-center/src/appmodel.cpp
test -f apps/calculator/src/main.cpp
test -f installer/calamares/dylanos/squid.png
git status --short
```

Expected: las cuatro fuentes existen; solo aparecen cambios intencionales.

- [ ] **Step 5: Commit**

```bash
git add .gitignore
git add -u
git commit -m "chore: excluir y retirar artefactos generados" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Extender QA, dependencias y workflows

**Files:**
- Modify: `scripts/check.sh:6-32`
- Modify: `.github/workflows/lint.yml:13-15`
- Modify: `.github/workflows/release.yml:15-17`
- Modify: `apps/dylanos-app-center/debian/control:5`
- Modify: `packages/default/packages.list` y/o lista de build usada por `scripts/build.sh`
- Create: `docs/beta-status.md`

**Interfaces:**
- Consumes: tests de Tasks 1–5 y CMake de Calculator/App Center.
- Produces: `check.sh` que ejecuta pruebas de Python, staging, `.desktop`, compilaciones C++ disponibles y smoke tests QML; CI instala las dependencias que hacen reproducibles esas pruebas.

- [ ] **Step 1: Añadir dependencias CMake/KF6 al paquete Debian**

En `apps/dylanos-app-center/debian/control`, completar `Build-Depends` con:

```text
libkf6kio-dev, ninja-build
```

Conservar `qt6-base-dev`, `qt6-declarative-dev`, `extra-cmake-modules`,
`libkf6service-dev`, `libkf6coreaddons-dev` y `libplasma-dev`.

- [ ] **Step 2: Añadir dependencias al entorno de construcción de la ISO**

En la lista de paquetes instalada antes de compilar las apps, incluir:

```text
cmake
ninja-build
extra-cmake-modules
qt6-base-dev
qt6-declarative-dev
libkf6service-dev
libkf6coreaddons-dev
libkf6kio-dev
libplasma-dev
```

No eliminar paquetes existentes ni cambiar la lógica de `scripts/build.sh`.

- [ ] **Step 3: Instalar dependencias C++ en workflows de lint y release**

Extender el `apt-get install` de `.github/workflows/lint.yml` y
`.github/workflows/release.yml` con:

```text
cmake ninja-build extra-cmake-modules qt6-base-dev qt6-declarative-dev
libkf6service-dev libkf6coreaddons-dev libkf6kio-dev libplasma-dev
```

- [ ] **Step 4: Añadir compilación limpia al `check.sh`**

Después de validar los `.desktop` de staging, añadir un bloque que use un
subdirectorio temporal dentro de `$staging`:

```bash
build_root="$staging/cpp-build"
install_root="$staging/cpp-install"
for app in calculator dylanos-app-center; do
    cmake -S "apps/$app" -B "$build_root/$app" -GNinja \
        -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr
    cmake --build "$build_root/$app" --parallel 2
    DESTDIR="$install_root/$app" cmake --install "$build_root/$app"
done

test -x "$install_root/dylanos-app-center/usr/bin/dylanos-app-center"
test -x "$install_root/calculator/usr/bin/dylanos-calculator"
find "$install_root" -name '*.desktop' -exec desktop-file-validate '{}' +
```

El bloque debe fallar si CMake o una dependencia necesaria están ausentes; no
convertir un fallo de compilación en un mensaje de éxito.

- [ ] **Step 5: Ejecutar todos los tests Python y comprobar el nuevo bloque**

Run: `bash scripts/check.sh`

Expected: PASS en shellcheck, paquetes, unittest, compileall, staging,
`.desktop`, compilación C++ y smoke tests si PySide6/psutil están instalados.
Si el host no tiene las dependencias, registrar `NOT RUN` para la fase afectada
y ejecutar el mismo comando en un entorno con los paquetes de CI antes de
finalizar.

- [ ] **Step 6: Actualizar documentación de QA**

Crear `docs/beta-status.md` con el alcance de la beta, las restricciones de
Calamares y una tabla con estas columnas: `Área`, `Comando`, `Resultado`,
`Evidencia`. Rellenar `Resultado` únicamente con los estados obtenidos en la
última ejecución (`PASS`, `FAIL`, `NOT RUN`, `WARNING`) y enlazarlo desde
`README.md` sin mencionar pruebas no ejecutadas como exitosas.

Actualizar `docs/architecture.md` para documentar el tema GTK instalado,
`storageId()` del App Center, el launcher de Archivos y la ruta staged del
branding PNG.

- [ ] **Step 7: Commit**

```bash
git add scripts/check.sh .github/workflows/lint.yml .github/workflows/release.yml apps/dylanos-app-center/debian/control packages docs README.md
git commit -m "test: ampliar QA reproducible de la beta" -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Validación final, auditoría de alcance y publicación

**Files:**
- Modify only files required by failing validation; no planned changes under `installer/calamares/`.

**Interfaces:**
- Consumes: todos los commits anteriores y sus resultados de QA.
- Produces: rama `development` validada, árbol limpio y push normal a `origin/development`.

- [ ] **Step 1: Ejecutar auditoría de archivos prohibidos y referencias rotas**

Run:

```bash
test -z "$(git diff --name-only -- installer/calamares)"
test ! -e branding/logo.svg
test -f branding/logo.png
test -f installer/calamares/dylanos/squid.png
git grep -n 'globalIndex\|Exec=/usr/local/bin/dylanos-app-center\|selectionColor: #DC143C' -- ':!work/**' ':!apps/*/build/**' && exit 1 || true
git grep -n 'branding/logo.svg' -- scripts apps docs README.md && exit 1 || true
```

Expected: el primer `test` no imprime nada, las fuentes PNG existen y las
búsquedas de contratos rotos no devuelven coincidencias.

- [ ] **Step 2: Ejecutar la batería completa y recopilar evidencia**

Run:

```bash
bash scripts/check.sh
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
if [[ -f DylanOS-1.0-beta-amd64.iso ]]; then
    bash scripts/test.sh
else
    echo 'ISO: NOT RUN — no existe DylanOS-1.0-beta-amd64.iso'
fi
```

La validación de ISO queda en `NOT RUN` cuando no existe la imagen; no se
fabricará una ISO ni se declarará validación de arranque sin `xorriso`,
checksum y archivos internos comprobados.

- [ ] **Step 3: Revisar colores productivos y nombres técnicos**

Run:

```bash
git grep -n -E '#0a84ff|10,132,255|#E50914|#e50914|#e11d2a|#e3485b' -- themes configs apps scripts branding docs ':!apps/archivos/qml/Main.qml' || true
```

Expected: ninguna coincidencia productiva no justificada; cualquier coincidencia
restante debe ser un estado derivado documentado o un archivo excluido por las
restricciones, nunca el acento principal de una aplicación.

- [ ] **Step 4: Revisar commits y estado**

Run:

```bash
git diff --check
git status --short --branch
git diff HEAD~6..HEAD --stat
git diff --name-only HEAD~6..HEAD -- installer/calamares
```

Expected: sin errores de whitespace, solo `development`, lista de Calamares
vacía y commits separados por responsabilidad.

- [ ] **Step 5: Publicar únicamente el historial validado**

Run: `git push origin development`

Expected: push normal sin force; `origin/development` queda en el mismo commit
que `development`.

- [ ] **Step 6: Confirmar estado remoto y cerrar la tarea**

Run:

```bash
git status --short --branch
git log -8 --oneline --decorate
```

Expected: `## development...origin/development` sin cambios locales. Solo
entonces actualizar Task #5 a `completed` y entregar el informe final con
commits, resultados exactos, limitaciones y recomendaciones.
